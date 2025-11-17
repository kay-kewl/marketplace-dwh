\connect order_service_db
SET search_path = public;

CREATE TABLE IF NOT EXISTS products (
    product_id                      SERIAL PRIMARY KEY,
    product_sku                     VARCHAR UNIQUE NOT NULL,
    product_name                    VARCHAR,
    category                        VARCHAR,
    brand                           VARCHAR,
    price                           DECIMAL,
    currency                        VARCHAR,
    weight_grams                    INTEGER,
    dimensions_length_cm            DECIMAL,
    dimensions_width_cm             DECIMAL,
    dimensions_height_cm            DECIMAL,
    is_active                       BOOLEAN,
    effective_from                  TIMESTAMP,
    effective_to                    TIMESTAMP,
    is_current                      BOOLEAN,
    created_at                      TIMESTAMP,
    updated_at                      TIMESTAMP,
    created_by                      VARCHAR,
    updated_by                      VARCHAR
);

CREATE TABLE IF NOT EXISTS orders (
    order_id                        SERIAL PRIMARY KEY,
    order_external_id               UUID UNIQUE NOT NULL,
    user_external_id                UUID NOT NULL,
    order_number                    VARCHAR UNIQUE,
    order_date                      TIMESTAMP,
    status                          VARCHAR,
    subtotal                        DECIMAL,
    tax_amount                      DECIMAL,
    shipping_cost                   DECIMAL,
    discount_amount                 DECIMAL,
    total_amount                    DECIMAL,
    currency                        VARCHAR,
    delivery_address_external_id    UUID NOT NULL,
    delivery_type                   VARCHAR,
    expected_delivery_date          DATE,
    actual_delivery_date            DATE,
    payment_method                  VARCHAR,
    payment_status                  VARCHAR,
    effective_from                  TIMESTAMP,
    effective_to                    TIMESTAMP,
    is_current                      BOOLEAN,
    created_at                      TIMESTAMP,
    updated_at                      TIMESTAMP,
    created_by                      VARCHAR,
    updated_by                      VARCHAR
);

CREATE TABLE IF NOT EXISTS order_status_history (
    history_id                      SERIAL PRIMARY KEY,
    order_external_id               UUID NOT NULL,
    old_status                      VARCHAR,
    new_status                      VARCHAR,
    change_reason                   VARCHAR,
    changed_at                      TIMESTAMP,
    changed_by                      VARCHAR,
    session_id                      VARCHAR,
    ip_address                      INET,
    notes                           TEXT,

    CONSTRAINT fk_order_status_history_to_orders
        FOREIGN KEY(order_external_id)
        REFERENCES orders(order_external_id)
);

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id                   SERIAL PRIMARY KEY,
    order_external_id               UUID NOT NULL,
    product_sku                     VARCHAR NOT NULL,
    quantity                        INTEGER,
    unit_price                      DECIMAL,
    total_price                     DECIMAL,
    product_name_snapshot           VARCHAR,
    product_category_snapshot       VARCHAR,
    product_brand_snapshot          VARCHAR,
    created_at                      TIMESTAMP,
    updated_at                      TIMESTAMP,
    created_by                      VARCHAR,
    updated_by                      VARCHAR,

    CONSTRAINT fk_order_items_to_orders
        FOREIGN KEY(order_external_id)
        REFERENCES orders(order_external_id),

    CONSTRAINT fk_order_items_to_products
        FOREIGN KEY(product_sku)
        REFERENCES products(product_sku)
);
