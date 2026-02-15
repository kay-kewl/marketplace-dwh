
CREATE TABLE IF NOT EXISTS dwh_detailed.link_order_address (
    link_order_address_id BIGINT PRIMARY KEY,
    hub_order_id BIGINT NOT NULL,
    hub_address_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_link_order_address_hub_order 
        FOREIGN KEY (hub_order_id) 
        REFERENCES dwh_detailed.hub_order(hub_order_id),
    
    CONSTRAINT fk_link_order_address_hub_address 
        FOREIGN KEY (hub_address_id) 
        REFERENCES dwh_detailed.hub_address(hub_address_id), 
    CONSTRAINT fk_link_order_address_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);


CREATE INDEX IF NOT EXISTS idx_link_order_address_hub_order 
    ON dwh_detailed.link_order_address(hub_order_id);
CREATE INDEX IF NOT EXISTS idx_link_order_address_hub_address 
    ON dwh_detailed.link_order_address(hub_address_id);
CREATE INDEX IF NOT EXISTS idx_link_order_address_created 
    ON dwh_detailed.link_order_address(created_at);


CREATE TABLE IF NOT EXISTS dwh_detailed.link_order_product (
    link_order_product_id BIGINT PRIMARY KEY,
    hub_order_id BIGINT NOT NULL,
    hub_product_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_link_order_product_hub_order 
        FOREIGN KEY (hub_order_id) 
        REFERENCES dwh_detailed.hub_order(hub_order_id),
    
    CONSTRAINT fk_link_order_product_hub_product 
        FOREIGN KEY (hub_product_id) 
        REFERENCES dwh_detailed.hub_product(hub_product_id), 
    CONSTRAINT fk_link_order_product_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_link_order_product UNIQUE(hub_order_id, hub_product_id, source_system_id)
);


CREATE INDEX IF NOT EXISTS idx_link_order_product_hub_order 
    ON dwh_detailed.link_order_product(hub_order_id);
CREATE INDEX IF NOT EXISTS idx_link_order_product_hub_product 
    ON dwh_detailed.link_order_product(hub_product_id);
CREATE INDEX IF NOT EXISTS idx_link_order_product_created 
    ON dwh_detailed.link_order_product(created_at);


CREATE TABLE IF NOT EXISTS dwh_detailed.link_order_user (
    link_order_user_id BIGINT PRIMARY KEY,
    hub_order_id BIGINT NOT NULL,
    hub_user_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_link_order_user_hub_order 
        FOREIGN KEY (hub_order_id) 
        REFERENCES dwh_detailed.hub_order(hub_order_id),
    
    CONSTRAINT fk_link_order_user_hub_user 
        FOREIGN KEY (hub_user_id) 
        REFERENCES dwh_detailed.hub_user(hub_user_id), 
    CONSTRAINT fk_link_order_user_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_link_order_user UNIQUE(hub_order_id, hub_user_id, source_system_id)
);


CREATE INDEX IF NOT EXISTS idx_link_order_user_hub_order 
    ON dwh_detailed.link_order_user(hub_order_id);
CREATE INDEX IF NOT EXISTS idx_link_order_user_hub_user 
    ON dwh_detailed.link_order_user(hub_user_id);
CREATE INDEX IF NOT EXISTS idx_link_order_user_created 
    ON dwh_detailed.link_order_user(created_at);


CREATE TABLE IF NOT EXISTS dwh_detailed.link_shipment_order (
    link_shipment_order_id BIGINT PRIMARY KEY,
    hub_shipment_id BIGINT NOT NULL,
    hub_order_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_link_shipment_order_hub_shipment 
        FOREIGN KEY (hub_shipment_id) 
        REFERENCES dwh_detailed.hub_shipment(hub_shipment_id),
    
    CONSTRAINT fk_link_shipment_order_hub_order 
        FOREIGN KEY (hub_order_id) 
        REFERENCES dwh_detailed.hub_order(hub_order_id), 
    CONSTRAINT fk_link_shipment_order_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_link_shipment_order UNIQUE(hub_shipment_id, hub_order_id, source_system_id)
);


CREATE INDEX IF NOT EXISTS idx_link_shipment_order_hub_shipment 
    ON dwh_detailed.link_shipment_order(hub_shipment_id);
CREATE INDEX IF NOT EXISTS idx_link_shipment_order_hub_order 
    ON dwh_detailed.link_shipment_order(hub_order_id);
CREATE INDEX IF NOT EXISTS idx_link_shipment_order_created 
    ON dwh_detailed.link_shipment_order(created_at);


CREATE TABLE IF NOT EXISTS dwh_detailed.link_shipment_pickup_point (
    link_shipment_pickup_point_id BIGINT PRIMARY KEY,
    hub_shipment_id BIGINT NOT NULL,
    hub_pickup_point_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_link_shipment_pickup_point_hub_shipment 
        FOREIGN KEY (hub_shipment_id) 
        REFERENCES dwh_detailed.hub_shipment(hub_shipment_id),
    
    CONSTRAINT fk_link_shipment_pickup_point_hub_pickup_point 
        FOREIGN KEY (hub_pickup_point_id) 
        REFERENCES dwh_detailed.hub_pickup_point(hub_pickup_point_id), 
    CONSTRAINT fk_link_shipment_pickup_point_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);


CREATE INDEX IF NOT EXISTS idx_link_shipment_pickup_point_hub_shipment 
    ON dwh_detailed.link_shipment_pickup_point(hub_shipment_id);
CREATE INDEX IF NOT EXISTS idx_link_shipment_pickup_point_hub_pickup_point 
    ON dwh_detailed.link_shipment_pickup_point(hub_pickup_point_id);
CREATE INDEX IF NOT EXISTS idx_link_shipment_pickup_point_created 
    ON dwh_detailed.link_shipment_pickup_point(created_at);


CREATE TABLE IF NOT EXISTS dwh_detailed.link_shipment_warehouse (
    link_shipment_warehouse_id BIGINT PRIMARY KEY,
    hub_shipment_id BIGINT NOT NULL,
    hub_warehouse_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_link_shipment_warehouse_hub_shipment 
        FOREIGN KEY (hub_shipment_id) 
        REFERENCES dwh_detailed.hub_shipment(hub_shipment_id),
    
    CONSTRAINT fk_link_shipment_warehouse_hub_warehouse 
        FOREIGN KEY (hub_warehouse_id) 
        REFERENCES dwh_detailed.hub_warehouse(hub_warehouse_id), 
    CONSTRAINT fk_link_shipment_warehouse_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);


CREATE INDEX IF NOT EXISTS idx_link_shipment_warehouse_hub_shipment 
    ON dwh_detailed.link_shipment_warehouse(hub_shipment_id);
CREATE INDEX IF NOT EXISTS idx_link_shipment_warehouse_hub_warehouse 
    ON dwh_detailed.link_shipment_warehouse(hub_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_link_shipment_warehouse_created 
    ON dwh_detailed.link_shipment_warehouse(created_at);


CREATE TABLE IF NOT EXISTS dwh_detailed.link_user_address (
    link_user_address_id BIGINT PRIMARY KEY,
    hub_user_id BIGINT NOT NULL,
    hub_address_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_link_user_address_hub_user 
        FOREIGN KEY (hub_user_id) 
        REFERENCES dwh_detailed.hub_user(hub_user_id),
    
    CONSTRAINT fk_link_user_address_hub_address 
        FOREIGN KEY (hub_address_id) 
        REFERENCES dwh_detailed.hub_address(hub_address_id), 
    CONSTRAINT fk_link_user_address_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_link_user_address UNIQUE(hub_user_id, hub_address_id, source_system_id)
);


CREATE INDEX IF NOT EXISTS idx_link_user_address_hub_user 
    ON dwh_detailed.link_user_address(hub_user_id);
CREATE INDEX IF NOT EXISTS idx_link_user_address_hub_address 
    ON dwh_detailed.link_user_address(hub_address_id);
CREATE INDEX IF NOT EXISTS idx_link_user_address_created 
    ON dwh_detailed.link_user_address(created_at);

