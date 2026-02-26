#!/bin/bash
set -eu

SPARK_MASTER="spark://spark-iceberg:7077"
KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-kafka:29092}"

echo "Waiting for Spark master to be ready..."
sleep 20

echo "Checking Kafka connection..."
for i in {1..10}; do
    if nc -z kafka 29092 2>/dev/null; then
        echo "Kafka is available"
        break
    fi
    echo "Error. Trying... ($i/10)"
    sleep 2
done

# Creating directories for metastore db
mkdir -p /home/spark/metastore_db /tmp/derby /tmp/spark-warehouse 2>/dev/null || true
chmod 755 /home/spark/metastore_db /tmp/derby /tmp/spark-warehouse 2>/dev/null || true

echo "Creating Kafka topics..."
python3 << EOF
import time
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import TopicAlreadyExistsError, NoBrokersAvailable

topics = [
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

max_retries = 5
for attempt in range(max_retries):
    try:
        admin = KafkaAdminClient(bootstrap_servers='kafka:29092', client_id='topic-creator')
        existing_topics = admin.list_topics()
        new_topics = [NewTopic(name=t, num_partitions=1, replication_factor=1) for t in topics if t not in existing_topics]
        if new_topics:
            admin.create_topics(new_topics=new_topics, validate_only=False)
            print(f"Created {len(new_topics)} topics")
        else:
            print("Topics have already existed")
        admin.close()
        break
    except NoBrokersAvailable:
        if attempt < max_retries - 1:
            print(f"Kafka not ready, retrying in 5s... (attempt {attempt+1}/{max_retries})")
            time.sleep(5)
        else:
            print("Cannot connect to Kafka")
            raise
    except Exception as e:
        print(f"Error creating topics: {e}")
        raise
EOF

echo "Starting Spark application..."
/opt/spark/bin/spark-submit \
  --master ${SPARK_MASTER} \
  --deploy-mode client \
  --name "Iceberg Parallel Writer" \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.0,org.apache.hadoop:hadoop-aws:3.3.4,org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1 \
  --repositories https://repo1.maven.org/maven2 \
  --conf spark.sql.catalog.iceberg=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.iceberg.type=hadoop \
  --conf spark.sql.catalog.iceberg.warehouse=s3a://warehouse/ \
  --conf spark.hadoop.fs.s3a.endpoint=${AWS_ENDPOINT} \
  --conf spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID} \
  --conf spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY} \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog \
  --conf spark.sql.catalog.spark_catalog.type=hadoop \
  --conf spark.sql.catalog.spark_catalog.warehouse=s3a://warehouse/ \
  --conf spark.sql.adaptive.enabled=false \
  --conf spark.sql.streaming.schemaInference=true \
  --conf spark.sql.streaming.stopTimeout=60000 \
  --conf spark.sql.warehouse.dir=/tmp/spark-warehouse \
  --conf spark.driver.extraJavaOptions="-Dderby.system.home=/home/spark/metastore_db -Dderby.stream.error.file=/home/spark/derby.log" \
  --conf spark.executor.extraJavaOptions="-Dderby.system.home=/home/spark/metastore_db" \
  --conf spark.sql.catalogImplementation=in-memory \
  /app/iceberg_streaming.py

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "Spark job submitted successfully"
else
  echo "Error submitting Spark job ($EXIT_CODE)"
  tail -f /dev/null
fi