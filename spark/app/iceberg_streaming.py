#!/usr/bin/env python3
import os
from datetime import datetime
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit
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
            event_timestamp TIMESTAMP,
            event_type STRING,
            source_db STRING,
            source_table STRING,
            record_json STRING,
            load_timestamp TIMESTAMP
        ) USING iceberg
        PARTITIONED BY (days(event_timestamp))
        LOCATION 's3a://warehouse/events_raw'
    """)
    logger.info("Iceberg tables initialized")

def main():
    logger.info("Spark Iceberg Writer Started")
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")
    init_iceberg_tables(spark)

    df = spark.readStream \
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
            "CAST(value AS STRING) as record_json"
        )

    final_df = df.withColumn("event_timestamp", lit(None).cast("timestamp")) \
                 .withColumn("event_type", lit("UNKNOWN")) \
                 .withColumn("source_db", lit(None)) \
                 .withColumn("source_table", lit(None)) \
                 .withColumn("load_timestamp", lit(datetime.now()))

    def write_to_iceberg(df, epoch_id):
        count = df.count()
        logger.info(f"Writing epoch {epoch_id} with {count} records")
        if count > 0:
            df.show(5, truncate=False)
            df.write.format("iceberg").mode("append").save("iceberg.events_raw")

    query = final_df.writeStream \
        .foreachBatch(write_to_iceberg) \
        .outputMode("update") \
        .trigger(processingTime="10 seconds") \
        .option("checkpointLocation", "s3a://warehouse/checkpoints/iceberg") \
        .start()

    logger.info("Streaming query started. Waiting for termination...")
    query.awaitTermination()

if __name__ == "__main__":
    main()