#!/usr/bin/env python3
import os
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, 
    current_timestamp,
    coalesce,
    split,
    get_json_object,
    from_unixtime,
    to_timestamp
)
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID", "minioadmin")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "minioadmin")
AWS_ENDPOINT = os.getenv("AWS_ENDPOINT", "http://minio:9000")
KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "kafka:29092")

TOPICS = [
    "user_service.public.users",
    "user_service.public.user_addresses",
    "user_service.public.user_status_history",
    "order_service.public.products",
    "order_service.public.orders",
    "order_service.public.order_status_history",
    "order_service.public.order_items",
    "logistics_service.public.warehouses",
    "logistics_service.public.pickup_points",
    "logistics_service.public.shipments",
    "logistics_service.public.shipment_movements",
    "logistics_service.public.shipment_status_history"
]

ICEBERG_TABLE = "iceberg.events_raw"

def create_spark_session():
    return SparkSession.builder \
        .appName("Kafka to Iceberg Writer") \
        .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.iceberg.type", "hadoop") \
        .config("spark.sql.catalog.iceberg.warehouse", "s3a://warehouse/") \
        .config("spark.hadoop.fs.s3a.endpoint", AWS_ENDPOINT) \
        .config("spark.hadoop.fs.s3a.access.key", AWS_ACCESS_KEY) \
        .config("spark.hadoop.fs.s3a.secret.key", AWS_SECRET_KEY) \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.adaptive.enabled", "false") \
        .config("spark.sql.streaming.schemaInference", "true") \
        .config("spark.sql.catalogImplementation", "in-memory") \
        .config("spark.driver.extraJavaOptions", "-Dderby.system.home=/home/spark/metastore_db -Dderby.stream.error.file=/home/spark/derby.log") \
        .getOrCreate()

def init_iceberg_tables(spark):
    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.events_raw (
            topic STRING,
            partition INT,
            offset BIGINT,
            kafka_timestamp TIMESTAMP,
            event_ts_ms BIGINT,
            event_timestamp TIMESTAMP,
            event_type STRING,
            source_db STRING,
            source_table STRING,
            key_json STRING,
            before_json STRING,
            after_json STRING,
            record_json STRING,
            load_timestamp TIMESTAMP
        ) USING iceberg
        PARTITIONED BY (days(kafka_timestamp), source_db)
        LOCATION 's3a://warehouse/events_raw'
    """)
    logger.info("Iceberg tables initialized")

def main():
    logger.info("Spark Iceberg Writer Started")
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")
    init_iceberg_tables(spark)

    raw_df = spark.readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP) \
        .option("subscribe", ",".join(TOPICS)) \
        .option("startingOffsets", "earliest") \
        .option("failOnDataLoss", "false") \
        .option("maxOffsetsPerTrigger", "10000") \
        .load() \
        .filter(col("value").isNotNull()) \
        .selectExpr(
            "topic",
            "partition",
            "offset",
            "timestamp as kafka_timestamp",
            "CAST(key AS STRING) as key_json",
            "CAST(value AS STRING) as record_json"
        )

    parsed_df = raw_df \
        .withColumn("source_db", split(col("topic"), "\\.").getItem(0)) \
        .withColumn("source_table", split(col("topic"), "\\.").getItem(2)) \
        .withColumn("event_type", get_json_object(col("record_json"), "$.payload.op")) \
        .withColumn("event_ts_ms", coalesce(
            get_json_object(col("record_json"), "$.payload.source.ts_ms").cast("bigint"),
            get_json_object(col("record_json"), "$.payload.ts_ms").cast("bigint"),
        )) \
        .withColumn("event_timestamp", coalesce(
            to_timestamp(from_unixtime((col("event_ts_ms") / 1000.0))),
            col("kafka_timestamp")
        )) \
        .withColumn("before_json", get_json_object(col("record_json"), "$.payload.before")) \
        .withColumn("after_json", get_json_object(col("record_json"), "$.payload.after")) \
        .withColumn("load_timestamp", current_timestamp())

    final_df = parsed_df.select(
        "topic",
        "partition",
        "offset",
        "kafka_timestamp",
        "event_ts_ms",
        "event_timestamp",
        "event_type",
        "source_db",
        "source_table",
        "key_json",
        "before_json",
        "after_json",
        "record_json",
        "load_timestamp"
    )

    def write_to_iceberg(df, epoch_id):
        count = df.count()
        logger.info(f"Writing epoch {epoch_id} with {count} records")
        if count > 0:
            df.select("topic", "event_type", "source_db", "source_table", "offset").show(5, truncate=False)
            df.write.format("iceberg").mode("append").save(ICEBERG_TABLE)

    query = final_df.writeStream \
        .foreachBatch(write_to_iceberg) \
        .outputMode("append") \
        .trigger(processingTime="10 seconds") \
        .option("checkpointLocation", "s3a://warehouse/checkpoints/iceberg") \
        .start()

    logger.info("Streaming query started. Waiting for termination...")
    query.awaitTermination()

if __name__ == "__main__":
    main()