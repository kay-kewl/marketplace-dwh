import os
import signal
import logging
from confluent_kafka import Consumer, TopicPartition
from src.config import ConfigLoader
from src.db import DBManager
from src.debezium import parse_message
from src.logging_conf import setup_logging

setup_logging()
logger = logging.getLogger(__name__)
running = {"status": True}

HUB_FIELD_CANDIDATES = {
    "hub_user": ["user_external_id"],
    "hub_order": ["order_external_id"],
    "hub_address": ["address_external_id", "delivery_address_external_id", "destination_address_external_id"],
    "hub_product": ["product_sku"],
    "hub_warehouse": ["warehouse_code", "origin_warehouse_code", "location_code"],
    "hub_pickup_point": ["pickup_point_code", "destination_pickup_point_code", "location_code"],
    "hub_shipment": ["shipment_external_id"],
}

HUB_BK_COLUMNS = {
    "hub_user": "user_external_id",
    "hub_order": "order_external_id",
    "hub_address": "address_external_id",
    "hub_product": "product_sku",
    "hub_warehouse": "warehouse_code",
    "hub_pickup_point": "pickup_point_code",
    "hub_shipment": "shipment_external_id",
}

def signal_handler(signal, frame):
    running["status"] = False

def resolve_parent_value(row, field_name, hub_name):
    if field_name and row.get(field_name) is not None:
        return row.get(field_name), field_name

    candidates = HUB_FIELD_CANDIDATES.get(hub_name, [])
    for candidate in candidates:
        if row.get(candidate) is not None:
            return row.get(candidate), candidate

    return None, field_name

def main():
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    cfg = ConfigLoader(os.environ["CONFIG_PATH"])
    db_manager = DBManager(os.environ["PG_DESTINATION"])

    consumer = Consumer({
        'bootstrap.servers': os.environ["KAFKA_BOOTSTRAP"],
        'group.id': os.environ.get("KAFKA_GROUP_ID", "dmp_consumer_group"),
        'auto.offset.reset': 'earliest',
        'enable.auto.commit': False,
        'enable.auto.offset.store': False
    })

    consumer.subscribe(cfg.get_topics())
    logger.info(f"DMP started. Subscribed to topics: {cfg.get_topics()}")

    try:
        while running["status"]:
            messages = consumer.consume(num_messages=int(os.environ.get("BATCH_SIZE", 500)), timeout=1.0)
            if not messages:
                continue

            parsed_messages = []
            max_offsets = {}

            for message in messages:
                if message.error():
                    continue

                parsed = parse_message(message)
                parsed_messages.append({
                    "message": message,
                    "parsed": parsed
                })

                tp = (parsed.topic, parsed.partition)
                if tp not in max_offsets or parsed.offset > max_offsets[tp]:
                    max_offsets[tp] = parsed.offset

            if not parsed_messages:
                continue

            with db_manager.conn.cursor() as cursor:
                inserted = db_manager.insert_records(cursor, parsed_messages)
                inserted_keys = set(inserted)

                for item in parsed_messages:
                    parsed = item['parsed']
                    if (parsed.topic, parsed.partition, parsed.offset) not in inserted_keys:
                        continue

                    if parsed.error or not parsed.payload:
                        continue

                    conf = cfg.get_conf(parsed.topic)
                    if not conf:
                        continue

                    cursor.execute("SAVEPOINT msg_sp")
                    try:                        
                        is_deleted = parsed.op == 'd'
                        row = parsed.payload.get('before') if is_deleted else parsed.payload.get('after')
                        if not row:
                            cursor.execute("RELEASE SAVEPOINT msg_sp")
                            continue

                        src = conf['source_name']

                        bk = row.get(conf['business_key']) if conf['business_key'] else None
                        if conf['hub_target']:
                            db_manager.load_hub(cursor, conf['hub_target'], conf['business_key'], bk, src)

                            if conf['sat_target']:
                                db_manager.load_satellite(cursor, conf['sat_target'], conf['hub_target'], 
                                                        bk, src, conf['attributes'], row, is_deleted)
                                
                        link_defs = conf.get('link_defs', [])
                        if not link_defs and conf.get('link_target') and conf.get('link_parents'):
                            link_defs = [{
                                "target": conf['link_target'],
                                "parents": conf['link_parents']
                            }]

                        for link_def in link_defs:
                            link_target = link_def.get('target')
                            link_parents = link_def.get('parents', [])
                            if not link_target or not link_parents:
                                continue

                            parents = []
                            for lp in link_parents:
                                hub_name = lp.get("hub")
                                field_name = lp.get("field")
                                if not hub_name:
                                    continue

                                value, resolved_field = resolve_parent_value(row, field_name, hub_name)
                                if value is None:
                                    continue

                                hub_bk_column = HUB_BK_COLUMNS.get(hub_name, resolved_field)
                                db_manager.load_hub(cursor, hub_name, hub_bk_column, value, src)
                                parents.append({
                                    "hub": hub_name,
                                    "val": value
                                })

                            if len(parents) != len(link_parents):
                                continue

                            link_bk = db_manager.load_link(cursor, link_target, parents, src)
                            if conf['sat_target'] and link_bk and not conf.get('hub_target'):
                                db_manager.load_satellite(
                                    cursor, 
                                    conf['sat_target'], 
                                    link_target, 
                                    link_bk, 
                                    src, 
                                    conf['attributes'], 
                                    row, 
                                    is_deleted
                                )
                        cursor.execute("RELEASE SAVEPOINT msg_sp")
                    except Exception as e:
                        logger.exception(f"Error processing message from topic {parsed.topic}, partition {parsed.partition}, offset {parsed.offset}: {e}")
                        cursor.execute("ROLLBACK TO SAVEPOINT msg_sp")
                        cursor.execute("RELEASE SAVEPOINT msg_sp")
            db_manager.conn.commit()

            for (t, p), offset in max_offsets.items():
                consumer.store_offsets(offsets=[TopicPartition(t, p, offset + 1)])

            consumer.commit(asynchronous=True)

    finally:
        consumer.close()
        db_manager.close()

if __name__ == "__main__":
    main()
