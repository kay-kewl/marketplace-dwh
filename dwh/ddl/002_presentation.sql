CREATE SCHEMA IF NOT EXISTS presentation;

CREATE TABLE IF NOT EXISTS presentation.purchase_analytics (
    purchase_date DATE NOT NULL,
    product_id INT NOT NULL,
    product_name TEXT NOT NULL,
    category TEXT NOT NULL,
    supplier_id INT NOT NULL,
    supplier_name TEXT NOT NULL,
    purchase_qty NUMERIC NOT NULL,
    total_purchase_amount NUMERIC NOT NULL,
    avg_unit_price NUMERIC NOT NULL,
    loaded_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (purchase_date, product_id, supplier_id)
);

CREATE INDEX IF NOT EXISTS idx_purchase_analytics_purchase_date
    ON presentation.purchase_analytics (purchase_date);

CREATE INDEX IF NOT EXISTS idx_purchase_analytics_product_supplier
    ON presentation.purchase_analytics (product_id, supplier_id);

CREATE TABLE IF NOT EXISTS presentation.warehouse_delivery_daily (
    shipment_date DATE NOT NULL,
    warehouse_id INT NOT NULL,
    warehouse_name TEXT NOT NULL,
    order_count INT NOT NULL,
    total_shipment_qty NUMERIC NOT NULL,
    avg_processing_time_min NUMERIC,
    delayed_orders_count INT NOT NULL,
    unique_customers_count INT NOT NULL,
    loaded_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (shipment_date, warehouse_id)
);

CREATE INDEX IF NOT EXISTS idx_warehouse_delivery_daily_date
    ON presentation.warehouse_delivery_daily (shipment_date);

CREATE INDEX IF NOT EXISTS idx_warehouse_delivery_daily_wh_date
    ON presentation.warehouse_delivery_daily (warehouse_id, shipment_date);