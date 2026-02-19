CREATE TABLE IF NOT EXISTS dwh_detailed;

CREATE TABLE IF NOT EXISTS dwh_detailed.stg_kafka_events {
    topic           TEXT NOT NULL,
    partition       INT NOT NULL,
    "offset"        BIGINT NOT NULL,

    kafka_ts_ms     BIGINT,
    key_bytes       BYTEA,
    value_bytes     BYTEA,

    payload_json    JSONB,
    op              TEXT,
    source_ts_ms    BIGINT,

    loaded_at       TIMESTAMPTZ DEFAULT NOW(),
    error_msg       TEXT,

    CONSTRAINT pk_stg_kafka_events PRIMARY KEY (topic, partition, "offset")
}