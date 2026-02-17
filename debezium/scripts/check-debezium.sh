#!/bin/bash

if curl -s -f http://localhost:8083 > /dev/null; then
    echo "Debezium is available"
else
    echo "Debezium is not available"
    exit 1
fi

echo "Reistered connectors:"
curl -s http://localhost:8083/connectors | jq . 2>/dev/null || curl -s http://localhost:8083/connectors

echo "Kafka topics:"
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list | grep -E "user_service|order_service|logistics_service" || echo "  Not found"