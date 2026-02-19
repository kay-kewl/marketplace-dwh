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
    local connector_file=$1
    local connector_name=$(basename "$connector_file" .json)
        
    if curl -s -f "$DEBEZIUM_URL/connectors/$connector_name" > /dev/null 2>&1; then
        curl -X DELETE "$DEBEZIUM_URL/connectors/$connector_name"
        sleep 2
    fi
    
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data @"$connector_file" \
        "$DEBEZIUM_URL/connectors")
}

main() {
    wait_for_debezium

    for connector_file in /connectors/register-*.json; do
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