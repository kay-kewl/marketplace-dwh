
CREATE TABLE IF NOT EXISTS dwh_detailed.hub_address (
    hub_address_id BIGINT PRIMARY KEY,
    address_external_id UUID NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_hub_address_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_hub_address_business_key 
        UNIQUE(address_external_id, source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_hub_address_nk 
    ON dwh_detailed.hub_address(address_external_id);
    
CREATE INDEX IF NOT EXISTS idx_hub_address_source 
    ON dwh_detailed.hub_address(source_system_id);


CREATE TABLE IF NOT EXISTS dwh_detailed.hub_order (
    hub_order_id BIGINT PRIMARY KEY,
    order_external_id UUID NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_hub_order_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_hub_order_business_key 
        UNIQUE(order_external_id, source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_hub_order_nk 
    ON dwh_detailed.hub_order(order_external_id);
    
CREATE INDEX IF NOT EXISTS idx_hub_order_source 
    ON dwh_detailed.hub_order(source_system_id);


CREATE TABLE IF NOT EXISTS dwh_detailed.hub_pickup_point (
    hub_pickup_point_id BIGINT PRIMARY KEY,
    pickup_point_code VARCHAR(50) NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_hub_pickup_point_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_hub_pickup_point_business_key 
        UNIQUE(pickup_point_code, source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_hub_pickup_point_nk 
    ON dwh_detailed.hub_pickup_point(pickup_point_code);
    
CREATE INDEX IF NOT EXISTS idx_hub_pickup_point_source 
    ON dwh_detailed.hub_pickup_point(source_system_id);


CREATE TABLE IF NOT EXISTS dwh_detailed.hub_product (
    hub_product_id BIGINT PRIMARY KEY,
    product_sku VARCHAR(100) NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_hub_product_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_hub_product_business_key 
        UNIQUE(product_sku, source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_hub_product_nk 
    ON dwh_detailed.hub_product(product_sku);
    
CREATE INDEX IF NOT EXISTS idx_hub_product_source 
    ON dwh_detailed.hub_product(source_system_id);


CREATE TABLE IF NOT EXISTS dwh_detailed.hub_shipment (
    hub_shipment_id BIGINT PRIMARY KEY,
    shipment_external_id UUID NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_hub_shipment_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_hub_shipment_business_key 
        UNIQUE(shipment_external_id, source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_hub_shipment_nk 
    ON dwh_detailed.hub_shipment(shipment_external_id);
    
CREATE INDEX IF NOT EXISTS idx_hub_shipment_source 
    ON dwh_detailed.hub_shipment(source_system_id);


CREATE TABLE IF NOT EXISTS dwh_detailed.hub_user (
    hub_user_id BIGINT PRIMARY KEY,
    user_external_id UUID NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_hub_user_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_hub_user_business_key 
        UNIQUE(user_external_id, source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_hub_user_nk 
    ON dwh_detailed.hub_user(user_external_id);
    
CREATE INDEX IF NOT EXISTS idx_hub_user_source 
    ON dwh_detailed.hub_user(source_system_id);


CREATE TABLE IF NOT EXISTS dwh_detailed.hub_warehouse (
    hub_warehouse_id BIGINT PRIMARY KEY,
    warehouse_code VARCHAR(50) NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_hub_warehouse_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_hub_warehouse_business_key 
        UNIQUE(warehouse_code, source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_hub_warehouse_nk 
    ON dwh_detailed.hub_warehouse(warehouse_code);
    
CREATE INDEX IF NOT EXISTS idx_hub_warehouse_source 
    ON dwh_detailed.hub_warehouse(source_system_id);

