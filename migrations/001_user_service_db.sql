\connect user_service_db
SET search_path = public;

CREATE TABLE IF NOT EXISTS users (
    user_id             SERIAL PRIMARY KEY,
    user_external_id    UUID UNIQUE,
    email               VARCHAR,
    first_name          VARCHAR,
    last_name           VARCHAR,
    phone               VARCHAR,
    date_of_birth       DATE,
    registration_date   TIMESTAMP,
    status              VARCHAR,
    effective_from      TIMESTAMP,
    effective_to        TIMESTAMP,
    is_current          BOOLEAN,
    created_at          TIMESTAMP,
    updated_at          TIMESTAMP,
    created_by          VARCHAR,
    updated_by          VARCHAR
);

CREATE TABLE IF NOT EXISTS user_status_history (
    history_id          SERIAL PRIMARY KEY,
    user_external_id    UUID,
    old_status          VARCHAR,
    new_status          VARCHAR,
    change_reason       VARCHAR,
    changed_at          TIMESTAMP,
    changed_by          VARCHAR,
    session_id          VARCHAR,
    ip_address          INET,
    user_agent          TEXT,

    CONSTRAINT fk_user_status_history_to_users
        FOREIGN KEY(user_external_id)
        REFERENCES users(user_external_id)
);

CREATE TABLE IF NOT EXISTS user_addresses (
    address_id          SERIAL PRIMARY KEY,
    address_external_id UUID UNIQUE,
    user_external_id    UUID,
    address_type        VARCHAR,
    country             VARCHAR,
    region              VARCHAR,
    city                VARCHAR,
    street_address      VARCHAR,
    postal_code         VARCHAR,
    apartment           VARCHAR,
    is_default          BOOLEAN,
    effective_from      TIMESTAMP,
    effective_to        TIMESTAMP,
    is_current          BOOLEAN,
    created_at          TIMESTAMP,
    updated_at          TIMESTAMP,
    created_by          VARCHAR,
    updated_by          VARCHAR,

    CONSTRAINT fk_user_addresses_to_user
        FOREIGN KEY(user_external_id)
        REFERENCES users(user_external_id)
);
