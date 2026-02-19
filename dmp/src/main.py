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

            valid_messages = []
            max_offsets = {}

            for message in messages:
                if message.error():
                    continue

                parsed = parse_message(message)
                message.parsed = parsed

                valid_messages.append(message)

                tp = (parsed.topic, parsed.partition)
                if tp not in max_offsets or parsed.offset > max_offsets[tp]:
                    max_offsets[tp] = parsed.offset

            if not valid_messages:
                continue

            with db_manager.conn.cursor() as cursor:
                inserted = db_manager.insert_staging(cursor, valid_messages)
                inserted_keys = set(inserted)

                for message in valid_messages:
                    parsed = message.parsed
                    if (p.topic, p.partition, p.offset) not in inserted_keys:
                        continue

                    if parsed.error or not parsed.payload:
                        continue

                    conf = cfg.get_conf(parsed.topic)
                    if not conf:
                        continue

                    is_deleted = parsed.op == 'd'
                    row = parsed.payload.get('before') if is_deleted else parsed.payload.get('after')
                    if not row:
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
                            value = row.get(lp['field'])
                            db_manager.load_hub(cursor, lp['hub'], lp['field'], val, src)
                            parents.append({
                                "hub": lp['hub'],
                                "val": value
                            })

                        db_manager.load_link(cursor, conf['link_target'], parents, src)
            db_manager.conn.commit()

            for (t, p), offset in max_offsets.items():
                consumer.store_offsets(offsets=[TopicPartition(t, p, offset + 1)])

            consumer.commit(asynchronous=True)

    finally:
        consumer.close()
        db_manager.close()

if __name__ == "__main__":
    main()
