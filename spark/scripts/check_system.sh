#!/bin/bash
set -e
set -o pipefail

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! command_exists jq; then
    echo "jq is required but not installed. Please install jq."
    exit 1
fi

get_kafka_total_offsets() {
    topics=$(docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list | grep -E "(user_service|order_service|logistics_service)\." || true)
    total=0
    for topic in $topics; do
        count=$(docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
            --broker-list localhost:9092 \
            --topic "$topic" \
            --time -1 2>/dev/null | awk -F ":" '{sum+=$3} END {print sum+0}')
        total=$((total + count))
    done
    echo "$total"
}

get_iceberg_count() {
    if [ "$table_exists" -eq 0 ]; then
        echo 0
    else
        output=$(docker exec spark-iceberg spark-sql \
            --conf spark.sql.catalog.iceberg=org.apache.iceberg.spark.SparkCatalog \
            --conf spark.sql.catalog.iceberg.type=hadoop \
            --conf spark.sql.catalog.iceberg.warehouse=s3a://warehouse/ \
            --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
            --conf spark.hadoop.fs.s3a.access.key=minioadmin \
            --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
            --conf spark.hadoop.fs.s3a.path.style.access=true \
            --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
            --conf spark.sql.catalogImplementation=in-memory \
            --conf spark.driver.extraJavaOptions="-Dderby.system.home=/home/spark/metastore_db" \
            -e "SELECT COUNT(*) FROM iceberg.default.events_raw;" 2>/dev/null || true)
        echo "$output" | awk '/^[0-9]+$/ {v=$1} END{print v+0}'
    fi
}

echo -e "\n1. Checking service availability:"

if docker exec patroni-1 psql postgresql://postgres:postgres@haproxy:5000/postgres -c "SELECT 1" &>/dev/null; then
    echo "PostgreSQL master is available via HAProxy"
else
    echo "PostgreSQL master is not available"
    exit 1
fi

if docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list &>/dev/null; then
    echo "Kafka is available"
else
    echo "Kafka is not available"
    exit 1
fi

if curl -s -f http://localhost:8083 > /dev/null; then
    echo "Debezium API is available"
else
    echo "Debezium API is not available"
    exit 1
fi

if docker exec dwh-postgres pg_isready -U dwh_user &>/dev/null; then
    echo "DWH PostgreSQL is available"
else
    echo "DWH PostgreSQL is not available"
    exit 1
fi

if curl -s -f http://localhost:9000/minio/health/live > /dev/null; then
    echo "MinIO is available"
else
    echo "MinIO is not available"
    exit 1
fi

if curl -s -f http://localhost:8080 > /dev/null; then
    echo "Spark Master UI is available"
else
    echo "Spark Master UI is not available"
    exit 1
fi

echo -e "\nBaseline metrics:"
initial_kafka_counts=$(get_kafka_total_offsets)
echo "Kafka total offsets: $initial_kafka_counts"

initial_stg_count=$(docker exec dwh-postgres psql -U dwh_user -d dwh -t -c "SELECT COUNT(*) FROM dwh_detailed.stg_kafka_events;" 2>/dev/null | tr -d ' ')
echo "Staging rows in DWH: $initial_stg_count"

table_check_output=$(docker exec spark-iceberg spark-sql \
    --conf spark.sql.catalog.iceberg=org.apache.iceberg.spark.SparkCatalog \
    --conf spark.sql.catalog.iceberg.type=hadoop \
    --conf spark.sql.catalog.iceberg.warehouse=s3a://warehouse/ \
    --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
    --conf spark.hadoop.fs.s3a.access.key=minioadmin \
    --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
    --conf spark.hadoop.fs.s3a.path.style.access=true \
    --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
    --conf spark.sql.catalogImplementation=in-memory \
    --conf spark.driver.extraJavaOptions="-Dderby.system.home=/home/spark/metastore_db" \
    -e "SELECT COUNT(*) FROM iceberg.default.events_raw;" 2>/dev/null || true)

if [ -z "$table_check_output" ] || echo "$table_check_output" | grep -qi "Table or view not found\|NoSuchTableException\|AnalysisException\|Missing database in table identifier\|UNSUPPORTED_DATASOURCE_FOR_DIRECT_QUERY"; then
    table_exists=0
else
    table_exists=1
fi

if [ "$table_exists" -gt 0 ]; then
    initial_iceberg_count=$(get_iceberg_count)
else
    initial_iceberg_count=0
fi

echo "Iceberg events_raw rows: $initial_iceberg_count (table exists: $table_exists)"

echo -e "\n2. Checking Debezium connectors:"
connectors=$(curl -s http://localhost:8083/connectors | jq -r '.[]' 2>/dev/null)
if [ -z "$connectors" ]; then
    echo "No registered connectors"
else
    for connector in $connectors; do
        state=$(curl -s "http://localhost:8083/connectors/$connector/status" | jq -r '.connector.state' 2>/dev/null)
        tasks_state=$(curl -s "http://localhost:8083/connectors/$connector/status" | jq -r '.tasks[0].state' 2>/dev/null)
        if [ "$state" = "RUNNING" ] && [ "$tasks_state" = "RUNNING" ]; then
            echo "$connector: RUNNING"
        else
            echo "$connector: connector=$state, tasks=$tasks_state"
        fi
    done
fi

echo -e "\n3. Generating test data..."

master_node=""
for node in patroni-1 patroni-2 patroni-3; do
    if docker exec $node psql postgresql://postgres:postgres@localhost:5432/postgres -t -c "SELECT NOT pg_is_in_recovery();" 2>/dev/null | grep -q t; then
        master_node=$node
        break
    fi
done

if [ -z "$master_node" ]; then
    echo "Could not determine PostgreSQL master"
    exit 1
fi
echo "Master node: $master_node"

user_id=$(docker exec $master_node psql postgresql://postgres:postgres@localhost:5432/user_service_db -tA -c "
WITH v AS (
    SELECT (
        substr(md5(random()::text || clock_timestamp()::text), 1, 8) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 9, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 13, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 17, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 21, 12)
    )::uuid AS id
)
INSERT INTO users (user_external_id, email, first_name, last_name, phone, status)
SELECT id, 'test.data.$(date +%s)@example.com', 'Test', 'Data', '+1234567890', 'ACTIVE' FROM v
RETURNING user_external_id;
" | head -1 | tr -d ' ')
[ -n "$user_id" ] || { echo "Failed to created user test record"; exit 1; }
echo "Created user: $user_id"

order_id=$(docker exec $master_node psql postgresql://postgres:postgres@localhost:5432/order_service_db -tA -c "
WITH v AS (
    SELECT (
        substr(md5(random()::text || clock_timestamp()::text), 1, 8) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 9, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 13, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 17, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 21, 12)
    )::uuid AS id
)
INSERT INTO orders (order_external_id, user_external_id, order_number, status, total_amount, currency)
SELECT id, '$user_id', 'TEST-ORDER-$(date +%s)', 'NEW', 99.99, 'RUB' FROM v
RETURNING order_external_id;
" | head -1 | tr -d ' ')
[ -n "$order_id" ] || { echo "Failed to created order test record"; exit 1; }
echo "Created order: $order_id"

shipment_id=$(docker exec $master_node psql postgresql://postgres:postgres@localhost:5432/logistics_service_db -tA -c "
WITH v AS (
    SELECT (
        substr(md5(random()::text || clock_timestamp()::text), 1, 8) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 9, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 13, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 17, 4) || '-' ||
        substr(md5(random()::text || clock_timestamp()::text), 21, 12)
    )::uuid AS id
)
INSERT INTO shipments (shipment_external_id, order_external_id, tracking_number, status, weight_grams, package_count)
SELECT id, '$order_id', 'TRK-$(date +%s)', 'CREATED', 500, 1 FROM v
RETURNING shipment_external_id;
" | head -1 | tr -d ' ')
[ -n "$shipment_id" ] || { echo "Failed to created shipment test record"; exit 1; }
echo "Created shipment: $shipment_id"


echo "Waiting for data to propagate through Kafka and DWH..."
final_kafka_counts=$initial_kafka_counts
final_stg_count=$initial_stg_count
for _ in {1..9}; do
    sleep 10
    final_kafka_counts=$(get_kafka_total_offsets)
    final_stg_count=$(docker exec dwh-postgres psql -U dwh_user -d dwh -t -c "SELECT COUNT(*) FROM dwh_detailed.stg_kafka_events;" 2>/dev/null | tr -d ' ')
    kafka_delta=$((final_kafka_counts - initial_kafka_counts))
    stg_delta=$((final_stg_count - initial_stg_count))
    if [ "$kafka_delta" -ge 3 ] && [ "$stg_delta" -ge 3 ]; then
        break
    fi
done

echo -e "\n4. Kafka topics:"
kafka_delta=$((final_kafka_counts - initial_kafka_counts))
echo "Kafka total offsets: $final_kafka_counts (+$kafka_delta new)"

echo -e "\n5. DWH PostgreSQL:"
increase=$((final_stg_count - initial_stg_count))
if [ "$increase" -gt 0 ]; then
    echo "Records in staging: $final_stg_count (+$increase new)"
else
    echo "Records in staging: $final_stg_count (no increase)"
fi

echo -e "\n6. Iceberg table events_raw:"
if [ "$table_exists" -eq 0 ]; then
    echo "Table iceberg.default.events_raw still not found"
else
    final_iceberg_count=$(get_iceberg_count)
    increase=$((final_iceberg_count - initial_iceberg_count))
    if [ "$increase" -gt 0 ]; then
        echo "Records in Iceberg: $final_iceberg_count (+$increase new)"
    else
        echo "Records in Iceberg: $final_iceberg_count (no increase)"
    fi
fi

echo -e "\n7. Checking Spark Streaming logs:"
spark_logs=$(docker logs spark-iceberg --tail 20 2>&1 | grep -E "Writing epoch|records" || true)
if [ -n "$spark_logs" ]; then
    echo "Spark is writing data:"
    echo "$spark_logs" | while read line; do
        echo "    $line"
    done
else
    echo "No write messages in Spark logs"
fi

echo -e "\n8. Checking MinIO buckets:"
if docker exec mc mc ls myminio/warehouse/ &>/dev/null; then
    echo "Bucket warehouse exists"
    docker exec mc mc ls myminio/warehouse/ | while read line; do
        echo "    $line"
    done
else
    echo "Bucket warehouse not found"
fi

if docker exec mc mc ls myminio/checkpoints/ &>/dev/null; then
    echo "Bucket checkpoints exists"
else
    echo "Bucket checkpoints not found"
fi