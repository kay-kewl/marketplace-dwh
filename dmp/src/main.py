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

def signal_handler(signal, frame):
    running["status"] = False

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

                        bk = row.get(conf['business_key'])
                        if conf['hub_target']:
                            db_manager.load_hub(cursor, conf['hub_target'], conf['business_key'], bk, src)

                            if conf['sat_target']:
                                db_manager.load_satellite(cursor, conf['sat_target'], conf['hub_target'], 
                                                        bk, src, conf['attributes'], row, is_deleted)
                                
                        if conf['link_target'] and conf['link_parents']:
                            parents = []
                            for lp in conf['link_parents']:
                                hub_name = lp.get("hub")
                                field_name = lp.get("field")
                                if not hub_name or not field_name:
                                    continue

                                value = row.get(field_name)
                                db_manager.load_hub(cursor, hub_name, field_name, value, src)
                                parents.append({
                                    "hub": hub_name,
                                    "val": value
                                })

                            if parents:
                                db_manager.load_link(cursor, conf['link_target'], parents, src)
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
