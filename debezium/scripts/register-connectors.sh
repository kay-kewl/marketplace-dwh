#!/bin/sh
set -eu

DEBEZIUM_URL="http://debezium:8083"
MAX_RETRIES=30
RETRY_INTERVAL=2

wait_for_debezium() {
    retries=0
    until curl -s -f "$DEBEZIUM_URL" > /dev/null 2>&1; do
        retries=$((retries + 1))
        if [ $retries -ge $MAX_RETRIES ]; then
            exit 1
        fi
        sleep $RETRY_INTERVAL
    done
}

register_connector() {
    connector_file=$1
    connector_name=$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$connector_file" | head -n 1)
    if [ -z "$connector_name" ]; then
        echo "Connector name not found in $connector_file"
        return 1
    fi
        
    if curl -s -f "$DEBEZIUM_URL/connectors/$connector_name" > /dev/null 2>&1; then
        curl -X DELETE "$DEBEZIUM_URL/connectors/$connector_name"
        sleep 2
    fi
    
    http_code=$(curl -s -o /tmp/connector_response.json -w "%{http_code}" -X POST -H "Content-Type: application/json" \
        --data @"$connector_file" \
        "$DEBEZIUM_URL/connectors")

    if [ "$http_code" != "201" ]; then
        echo "Failed to register connector $connector_name with HTTP code $http_code"
        cat /tmp/connector_response.json
        return 1
    fi
}

main() {
    wait_for_debezium

    for connector_file in /connectors/*-connector.json; do
        if [ -f "$connector_file" ]; then
            register_connector "$connector_file"
            sleep 2
        fi
    done
    
    curl -s "$DEBEZIUM_URL/connectors" | sed 's/[][]//g' | sed 's/,/\n/g' | sed 's/"//g' | while read connector; do
        if [ ! -z "$connector" ]; then
            status=$(curl -s "$DEBEZIUM_URL/connectors/$connector/status")
            state=$(echo "$status" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
            echo "  $connector: $state"
        fi
    done   
}

main