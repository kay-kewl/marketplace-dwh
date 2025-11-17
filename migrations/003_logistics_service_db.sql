\connect logistics_service_db
SET search_path = public;

CREATE TABLE IF NOT EXISTS warehouses (
    warehouse_id                    SERIAL PRIMARY KEY,
    warehouse_code                  VARCHAR UNIQUE NOT NULL,
    warehouse_name                  VARCHAR,
    warehouse_type                  VARCHAR,
    country                         VARCHAR,
    region                          VARCHAR,
    city                            VARCHAR,
    street_address                  VARCHAR,
    postal_code                     VARCHAR,
    is_active                       BOOLEAN,
    max_capacity_cubic_meters       DECIMAL,
    operating_hours                 VARCHAR,
    contact_phone                   VARCHAR,
    manager_name                    VARCHAR,
    effective_from                  TIMESTAMP,
    effective_to                    TIMESTAMP,
    is_current                      BOOLEAN,
    created_at                      TIMESTAMP,
    updated_at                      TIMESTAMP,
    created_by                      VARCHAR,
    updated_by                      VARCHAR
);

CREATE TABLE IF NOT EXISTS pickup_points (
    pickup_point_id                 SERIAL PRIMARY KEY,
    pickup_point_code               VARCHAR UNIQUE NOT NULL,
    pickup_point_name               VARCHAR,
    pickup_point_type               VARCHAR,
    country                         VARCHAR,
    region                          VARCHAR,
    city                            VARCHAR,
    street_address                  VARCHAR,
    postal_code                     VARCHAR,
    is_active                       BOOLEAN,
    max_capacity_packages           INTEGER,
    operating_hours                 VARCHAR,
    contact_phone                   VARCHAR,
    partner_name                    VARCHAR,
    effective_from                  TIMESTAMP,
    effective_to                    TIMESTAMP,
    is_current                      BOOLEAN,
    created_at                      TIMESTAMP,
    updated_at                      TIMESTAMP,
    created_by                      VARCHAR,
    updated_by                      VARCHAR
);

CREATE TABLE IF NOT EXISTS shipments (
    shipment_id                     SERIAL PRIMARY KEY,
    shipment_external_id            UUID UNIQUE NOT NULL,
    order_external_id               UUID NOT NULL,
    tracking_number                 VARCHAR UNIQUE,
    status                          VARCHAR,
    weight_grams                    INTEGER,
    volume_cubic_cm                 INTEGER,
    package_count                   INTEGER,
    origin_warehouse_code           VARCHAR,
    destination_type                VARCHAR,
    destination_pickup_point_code   VARCHAR,
    -- destination_address_external_id UUID NOT NULL, could not parse mock data with not null
    destination_address_external_id UUID,
    created_date                    TIMESTAMP,
    dispatched_date                 TIMESTAMP,
    estimated_delivery_date         TIMESTAMP,
    actual_delivery_date            TIMESTAMP,
    delivery_notes                  TEXT,
    recipient_name                  VARCHAR,
    delivery_signature              VARCHAR,
    effective_from                  TIMESTAMP,
    effective_to                    TIMESTAMP,
    is_current                      BOOLEAN,
    created_at                      TIMESTAMP,
    updated_at                      TIMESTAMP,
    created_by                      VARCHAR,
    updated_by                      VARCHAR,

    CONSTRAINT fk_shipments_to_warehouses
        FOREIGN KEY(origin_warehouse_code)
        REFERENCES warehouses(warehouse_code),

    CONSTRAINT fk_shipments_to_pickup_points
        FOREIGN KEY(destination_pickup_point_code)
        REFERENCES pickup_points(pickup_point_code)
);

CREATE TABLE IF NOT EXISTS shipment_movements (
    movement_id                     SERIAL PRIMARY KEY,
    shipment_external_id            UUID NOT NULL,
    movement_type                   VARCHAR,
    location_type                   VARCHAR,
    location_code                   VARCHAR,
    movement_datetime               TIMESTAMP,
    operator_name                   VARCHAR,
    notes                           TEXT,
    latitude                        DECIMAL,
    longitude                      DECIMAL,
    created_at                      TIMESTAMP,
    created_by                      VARCHAR,

    CONSTRAINT fk_shipment_movements_to_shipments
        FOREIGN KEY(shipment_external_id)
        REFERENCES shipments(shipment_external_id)
);

CREATE TABLE IF NOT EXISTS shipment_status_history (
    history_id                      SERIAL PRIMARY KEY,
    shipment_external_id            UUID NOT NULL,
    old_status                      VARCHAR,
    new_status                      VARCHAR,
    change_reason                   VARCHAR,
    changed_at                      TIMESTAMP,
    changed_by                      VARCHAR,
    location_type                   VARCHAR,
    location_code                   VARCHAR,
    notes                           TEXT,
    customer_notified               BOOLEAN,

    CONSTRAINT fk_shipment_status_history_to_shipments
        FOREIGN KEY(shipment_external_id)
        REFERENCES shipments(shipment_external_id)
);

