#!/bin/bash
set -e

MASTER=${MASTER:-postgres}
USER=${USER:-replicator}
PASSWORD=${PASSWORD:-replicator}
NAME=${NAME:-replication_slot_1}

mkdir -p "$PGDATA"
chmod 0700 "$PGDATA" # full access

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "init_replica.sh: PGDATA is empty, starting setup"
    until PGPASSWORD="$PASSWORD" pg_isready -h "$MASTER" -U "$USER" -d "${POSTGRES_DB}"; do
        sleep 1
    done

    echo "init_replica.sh: doing a backup"
    PGPASSWORD="$PASSWORD" pg_basebackup \
        -h "$MASTER" \
        -U "$USER" \
        --slot="$NAME" \
        -C \
        -R \
        -D "$PGDATA" \
        -P

    echo "init_replica.sh: backup is done"
    chmod 0700 "$PGDATA" # full access
else
    echo "init_replica.sh: PGDATA exists, proceeding"
fi

exec docker-entrypoint.sh "$@"
