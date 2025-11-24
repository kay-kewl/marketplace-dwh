#!/bin/bash
set -e

DATA_DIR="${PATRONI_POSTGRESQL_DATA_DIR:-/var/lib/postgresql/data/patroni}"

mkdir -p "$DATA_DIR"
chown -R postgres:postgres "$DATA_DIR"
chmod 0700 "$DATA_DIR"

exec gosu postgres "$@"