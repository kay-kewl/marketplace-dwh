
CREATE TABLE IF NOT EXISTS dwh_detailed.sat_user_details (
    sat_user_details_id BIGSERIAL,
    hub_user_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    email VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    date_of_birth DATE,
    registration_date TIMESTAMP,
    status VARCHAR(50),
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_user_details_id),
    
    CONSTRAINT fk_sat_user_details_hub_user 
        FOREIGN KEY (hub_user_id) 
        REFERENCES dwh_detailed.hub_user(hub_user_id),
    
    CONSTRAINT fk_sat_user_details_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_user_details_parent 
    ON dwh_detailed.sat_user_details(hub_user_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_user_details_current 
    ON dwh_detailed.sat_user_details(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_user_details_dates 
    ON dwh_detailed.sat_user_details(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_user_details_hash(

    p_email VARCHAR(255),
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_phone VARCHAR(20),
    p_date_of_birth DATE,
    p_registration_date TIMESTAMP,
    p_status VARCHAR(50)
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_email::TEXT || '|' || p_first_name::TEXT || '|' || p_last_name::TEXT || '|' || p_phone::TEXT || '|' || p_date_of_birth::TEXT || '|' || p_registration_date::TEXT || '|' || p_status::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_user_status_history (
    sat_user_status_history_id BIGSERIAL,
    hub_user_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    change_reason VARCHAR(200),
    changed_at TIMESTAMP,
    changed_by VARCHAR(100),
    session_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_user_status_history_id),
    
    CONSTRAINT fk_sat_user_status_history_hub_user 
        FOREIGN KEY (hub_user_id) 
        REFERENCES dwh_detailed.hub_user(hub_user_id),
    
    CONSTRAINT fk_sat_user_status_history_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_user_status_history_parent 
    ON dwh_detailed.sat_user_status_history(hub_user_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_user_status_history_current 
    ON dwh_detailed.sat_user_status_history(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_user_status_history_dates 
    ON dwh_detailed.sat_user_status_history(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_user_status_history_hash(

    p_old_status VARCHAR(50),
    p_new_status VARCHAR(50),
    p_change_reason VARCHAR(200),
    p_changed_at TIMESTAMP,
    p_changed_by VARCHAR(100),
    p_session_id VARCHAR(100),
    p_ip_address INET,
    p_user_agent TEXT
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_old_status::TEXT || '|' || p_new_status::TEXT || '|' || p_change_reason::TEXT || '|' || p_changed_at::TEXT || '|' || p_changed_by::TEXT || '|' || p_session_id::TEXT || '|' || p_ip_address::TEXT || '|' || p_user_agent::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_address_details (
    sat_address_details_id BIGSERIAL,
    hub_address_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    address_type VARCHAR(50),
    country VARCHAR(100),
    region VARCHAR(100),
    city VARCHAR(100),
    street_address VARCHAR(200),
    postal_code VARCHAR(20),
    apartment VARCHAR(50),
    is_default BOOLEAN,
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_address_details_id),
    
    CONSTRAINT fk_sat_address_details_hub_address 
        FOREIGN KEY (hub_address_id) 
        REFERENCES dwh_detailed.hub_address(hub_address_id),
    
    CONSTRAINT fk_sat_address_details_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_address_details_parent 
    ON dwh_detailed.sat_address_details(hub_address_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_address_details_current 
    ON dwh_detailed.sat_address_details(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_address_details_dates 
    ON dwh_detailed.sat_address_details(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_address_details_hash(

    p_address_type VARCHAR(50),
    p_country VARCHAR(100),
    p_region VARCHAR(100),
    p_city VARCHAR(100),
    p_street_address VARCHAR(200),
    p_postal_code VARCHAR(20),
    p_apartment VARCHAR(50),
    p_is_default BOOLEAN
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_address_type::TEXT || '|' || p_country::TEXT || '|' || p_region::TEXT || '|' || p_city::TEXT || '|' || p_street_address::TEXT || '|' || p_postal_code::TEXT || '|' || p_apartment::TEXT || '|' || p_is_default::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_product_details (
    sat_product_details_id BIGSERIAL,
    hub_product_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    product_name VARCHAR(200),
    category VARCHAR(100),
    brand VARCHAR(100),
    price DECIMAL(10,2),
    currency VARCHAR(3),
    weight_grams INTEGER,
    dimensions_length_cm DECIMAL(10,2),
    dimensions_width_cm DECIMAL(10,2),
    dimensions_height_cm DECIMAL(10,2),
    is_active BOOLEAN,
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_product_details_id),
    
    CONSTRAINT fk_sat_product_details_hub_product 
        FOREIGN KEY (hub_product_id) 
        REFERENCES dwh_detailed.hub_product(hub_product_id),
    
    CONSTRAINT fk_sat_product_details_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_product_details_parent 
    ON dwh_detailed.sat_product_details(hub_product_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_product_details_current 
    ON dwh_detailed.sat_product_details(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_product_details_dates 
    ON dwh_detailed.sat_product_details(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_product_details_hash(

    p_product_name VARCHAR(200),
    p_category VARCHAR(100),
    p_brand VARCHAR(100),
    p_price DECIMAL(10,2),
    p_currency VARCHAR(3),
    p_weight_grams INTEGER,
    p_dimensions_length_cm DECIMAL(10,2),
    p_dimensions_width_cm DECIMAL(10,2),
    p_dimensions_height_cm DECIMAL(10,2),
    p_is_active BOOLEAN
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_product_name::TEXT || '|' || p_category::TEXT || '|' || p_brand::TEXT || '|' || p_price::TEXT || '|' || p_currency::TEXT || '|' || p_weight_grams::TEXT || '|' || p_dimensions_length_cm::TEXT || '|' || p_dimensions_width_cm::TEXT || '|' || p_dimensions_height_cm::TEXT || '|' || p_is_active::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_order_details (
    sat_order_details_id BIGSERIAL,
    hub_order_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    order_number VARCHAR(50),
    order_date TIMESTAMP,
    status VARCHAR(50),
    subtotal DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    shipping_cost DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    currency VARCHAR(3),
    delivery_type VARCHAR(50),
    expected_delivery_date DATE,
    actual_delivery_date DATE,
    payment_method VARCHAR(50),
    payment_status VARCHAR(50),
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_order_details_id),
    
    CONSTRAINT fk_sat_order_details_hub_order 
        FOREIGN KEY (hub_order_id) 
        REFERENCES dwh_detailed.hub_order(hub_order_id),
    
    CONSTRAINT fk_sat_order_details_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_order_details_parent 
    ON dwh_detailed.sat_order_details(hub_order_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_order_details_current 
    ON dwh_detailed.sat_order_details(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_order_details_dates 
    ON dwh_detailed.sat_order_details(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_order_details_hash(

    p_order_number VARCHAR(50),
    p_order_date TIMESTAMP,
    p_status VARCHAR(50),
    p_subtotal DECIMAL(10,2),
    p_tax_amount DECIMAL(10,2),
    p_shipping_cost DECIMAL(10,2),
    p_discount_amount DECIMAL(10,2),
    p_total_amount DECIMAL(10,2),
    p_currency VARCHAR(3),
    p_delivery_type VARCHAR(50),
    p_expected_delivery_date DATE,
    p_actual_delivery_date DATE,
    p_payment_method VARCHAR(50),
    p_payment_status VARCHAR(50)
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_order_number::TEXT || '|' || p_order_date::TEXT || '|' || p_status::TEXT || '|' || p_subtotal::TEXT || '|' || p_tax_amount::TEXT || '|' || p_shipping_cost::TEXT || '|' || p_discount_amount::TEXT || '|' || p_total_amount::TEXT || '|' || p_currency::TEXT || '|' || p_delivery_type::TEXT || '|' || p_expected_delivery_date::TEXT || '|' || p_actual_delivery_date::TEXT || '|' || p_payment_method::TEXT || '|' || p_payment_status::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_order_status_history (
    sat_order_status_history_id BIGSERIAL,
    hub_order_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    change_reason VARCHAR(200),
    changed_at TIMESTAMP,
    changed_by VARCHAR(100),
    session_id VARCHAR(100),
    ip_address INET,
    notes TEXT,
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_order_status_history_id),
    
    CONSTRAINT fk_sat_order_status_history_hub_order 
        FOREIGN KEY (hub_order_id) 
        REFERENCES dwh_detailed.hub_order(hub_order_id),
    
    CONSTRAINT fk_sat_order_status_history_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_order_status_history_parent 
    ON dwh_detailed.sat_order_status_history(hub_order_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_order_status_history_current 
    ON dwh_detailed.sat_order_status_history(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_order_status_history_dates 
    ON dwh_detailed.sat_order_status_history(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_order_status_history_hash(

    p_old_status VARCHAR(50),
    p_new_status VARCHAR(50),
    p_change_reason VARCHAR(200),
    p_changed_at TIMESTAMP,
    p_changed_by VARCHAR(100),
    p_session_id VARCHAR(100),
    p_ip_address INET,
    p_notes TEXT
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_old_status::TEXT || '|' || p_new_status::TEXT || '|' || p_change_reason::TEXT || '|' || p_changed_at::TEXT || '|' || p_changed_by::TEXT || '|' || p_session_id::TEXT || '|' || p_ip_address::TEXT || '|' || p_notes::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_order_item_details (
    sat_order_item_details_id BIGSERIAL,
    link_order_product_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    quantity INTEGER,
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2),
    product_name_snapshot VARCHAR(200),
    product_category_snapshot VARCHAR(100),
    product_brand_snapshot VARCHAR(100),
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_order_item_details_id),
    
    CONSTRAINT fk_sat_order_item_details_link_order_product 
        FOREIGN KEY (link_order_product_id) 
        REFERENCES dwh_detailed.link_order_product(link_order_product_id),
    
    CONSTRAINT fk_sat_order_item_details_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_order_item_details_parent 
    ON dwh_detailed.sat_order_item_details(link_order_product_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_order_item_details_current 
    ON dwh_detailed.sat_order_item_details(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_order_item_details_dates 
    ON dwh_detailed.sat_order_item_details(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_order_item_details_hash(

    p_quantity INTEGER,
    p_unit_price DECIMAL(10,2),
    p_total_price DECIMAL(10,2),
    p_product_name_snapshot VARCHAR(200),
    p_product_category_snapshot VARCHAR(100),
    p_product_brand_snapshot VARCHAR(100)
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_quantity::TEXT || '|' || p_unit_price::TEXT || '|' || p_total_price::TEXT || '|' || p_product_name_snapshot::TEXT || '|' || p_product_category_snapshot::TEXT || '|' || p_product_brand_snapshot::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_warehouse_details (
    sat_warehouse_details_id BIGSERIAL,
    hub_warehouse_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    warehouse_name VARCHAR(200),
    warehouse_type VARCHAR(50),
    country VARCHAR(100),
    region VARCHAR(100),
    city VARCHAR(100),
    street_address VARCHAR(200),
    postal_code VARCHAR(20),
    is_active BOOLEAN,
    max_capacity_cubic_meters DECIMAL(10,2),
    operating_hours VARCHAR(100),
    contact_phone VARCHAR(20),
    manager_name VARCHAR(100),
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_warehouse_details_id),
    
    CONSTRAINT fk_sat_warehouse_details_hub_warehouse 
        FOREIGN KEY (hub_warehouse_id) 
        REFERENCES dwh_detailed.hub_warehouse(hub_warehouse_id),
    
    CONSTRAINT fk_sat_warehouse_details_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_warehouse_details_parent 
    ON dwh_detailed.sat_warehouse_details(hub_warehouse_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_warehouse_details_current 
    ON dwh_detailed.sat_warehouse_details(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_warehouse_details_dates 
    ON dwh_detailed.sat_warehouse_details(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_warehouse_details_hash(

    p_warehouse_name VARCHAR(200),
    p_warehouse_type VARCHAR(50),
    p_country VARCHAR(100),
    p_region VARCHAR(100),
    p_city VARCHAR(100),
    p_street_address VARCHAR(200),
    p_postal_code VARCHAR(20),
    p_is_active BOOLEAN,
    p_max_capacity_cubic_meters DECIMAL(10,2),
    p_operating_hours VARCHAR(100),
    p_contact_phone VARCHAR(20),
    p_manager_name VARCHAR(100)
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_warehouse_name::TEXT || '|' || p_warehouse_type::TEXT || '|' || p_country::TEXT || '|' || p_region::TEXT || '|' || p_city::TEXT || '|' || p_street_address::TEXT || '|' || p_postal_code::TEXT || '|' || p_is_active::TEXT || '|' || p_max_capacity_cubic_meters::TEXT || '|' || p_operating_hours::TEXT || '|' || p_contact_phone::TEXT || '|' || p_manager_name::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_pickup_point_details (
    sat_pickup_point_details_id BIGSERIAL,
    hub_pickup_point_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    pickup_point_name VARCHAR(200),
    pickup_point_type VARCHAR(50),
    country VARCHAR(100),
    region VARCHAR(100),
    city VARCHAR(100),
    street_address VARCHAR(200),
    postal_code VARCHAR(20),
    is_active BOOLEAN,
    max_capacity_packages INTEGER,
    operating_hours VARCHAR(100),
    contact_phone VARCHAR(20),
    partner_name VARCHAR(100),
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_pickup_point_details_id),
    
    CONSTRAINT fk_sat_pickup_point_details_hub_pickup_point 
        FOREIGN KEY (hub_pickup_point_id) 
        REFERENCES dwh_detailed.hub_pickup_point(hub_pickup_point_id),
    
    CONSTRAINT fk_sat_pickup_point_details_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_pickup_point_details_parent 
    ON dwh_detailed.sat_pickup_point_details(hub_pickup_point_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_pickup_point_details_current 
    ON dwh_detailed.sat_pickup_point_details(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_pickup_point_details_dates 
    ON dwh_detailed.sat_pickup_point_details(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_pickup_point_details_hash(

    p_pickup_point_name VARCHAR(200),
    p_pickup_point_type VARCHAR(50),
    p_country VARCHAR(100),
    p_region VARCHAR(100),
    p_city VARCHAR(100),
    p_street_address VARCHAR(200),
    p_postal_code VARCHAR(20),
    p_is_active BOOLEAN,
    p_max_capacity_packages INTEGER,
    p_operating_hours VARCHAR(100),
    p_contact_phone VARCHAR(20),
    p_partner_name VARCHAR(100)
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_pickup_point_name::TEXT || '|' || p_pickup_point_type::TEXT || '|' || p_country::TEXT || '|' || p_region::TEXT || '|' || p_city::TEXT || '|' || p_street_address::TEXT || '|' || p_postal_code::TEXT || '|' || p_is_active::TEXT || '|' || p_max_capacity_packages::TEXT || '|' || p_operating_hours::TEXT || '|' || p_contact_phone::TEXT || '|' || p_partner_name::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_shipment_details (
    sat_shipment_details_id BIGSERIAL,
    hub_shipment_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    tracking_number VARCHAR(100),
    status VARCHAR(50),
    weight_grams INTEGER,
    volume_cubic_cm INTEGER,
    package_count INTEGER,
    created_date TIMESTAMP,
    dispatched_date TIMESTAMP,
    estimated_delivery_date TIMESTAMP,
    actual_delivery_date TIMESTAMP,
    delivery_notes TEXT,
    recipient_name VARCHAR(200),
    delivery_signature VARCHAR(100),
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_shipment_details_id),
    
    CONSTRAINT fk_sat_shipment_details_hub_shipment 
        FOREIGN KEY (hub_shipment_id) 
        REFERENCES dwh_detailed.hub_shipment(hub_shipment_id),
    
    CONSTRAINT fk_sat_shipment_details_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_shipment_details_parent 
    ON dwh_detailed.sat_shipment_details(hub_shipment_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_shipment_details_current 
    ON dwh_detailed.sat_shipment_details(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_shipment_details_dates 
    ON dwh_detailed.sat_shipment_details(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_shipment_details_hash(

    p_tracking_number VARCHAR(100),
    p_status VARCHAR(50),
    p_weight_grams INTEGER,
    p_volume_cubic_cm INTEGER,
    p_package_count INTEGER,
    p_created_date TIMESTAMP,
    p_dispatched_date TIMESTAMP,
    p_estimated_delivery_date TIMESTAMP,
    p_actual_delivery_date TIMESTAMP,
    p_delivery_notes TEXT,
    p_recipient_name VARCHAR(200),
    p_delivery_signature VARCHAR(100)
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_tracking_number::TEXT || '|' || p_status::TEXT || '|' || p_weight_grams::TEXT || '|' || p_volume_cubic_cm::TEXT || '|' || p_package_count::TEXT || '|' || p_created_date::TEXT || '|' || p_dispatched_date::TEXT || '|' || p_estimated_delivery_date::TEXT || '|' || p_actual_delivery_date::TEXT || '|' || p_delivery_notes::TEXT || '|' || p_recipient_name::TEXT || '|' || p_delivery_signature::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_shipment_movements (
    sat_shipment_movements_id BIGSERIAL,
    hub_shipment_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    movement_type VARCHAR(50),
    location_type VARCHAR(50),
    location_code VARCHAR(50),
    movement_datetime TIMESTAMP,
    operator_name VARCHAR(100),
    notes TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_shipment_movements_id),
    
    CONSTRAINT fk_sat_shipment_movements_hub_shipment 
        FOREIGN KEY (hub_shipment_id) 
        REFERENCES dwh_detailed.hub_shipment(hub_shipment_id),
    
    CONSTRAINT fk_sat_shipment_movements_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_shipment_movements_parent 
    ON dwh_detailed.sat_shipment_movements(hub_shipment_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_shipment_movements_current 
    ON dwh_detailed.sat_shipment_movements(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_shipment_movements_dates 
    ON dwh_detailed.sat_shipment_movements(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_shipment_movements_hash(

    p_movement_type VARCHAR(50),
    p_location_type VARCHAR(50),
    p_location_code VARCHAR(50),
    p_movement_datetime TIMESTAMP,
    p_operator_name VARCHAR(100),
    p_notes TEXT,
    p_latitude DECIMAL(10,8),
    p_longitude DECIMAL(11,8)
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_movement_type::TEXT || '|' || p_location_type::TEXT || '|' || p_location_code::TEXT || '|' || p_movement_datetime::TEXT || '|' || p_operator_name::TEXT || '|' || p_notes::TEXT || '|' || p_latitude::TEXT || '|' || p_longitude::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE IF NOT EXISTS dwh_detailed.sat_shipment_status_history (
    sat_shipment_status_history_id BIGSERIAL,
    hub_shipment_id BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    change_reason VARCHAR(200),
    changed_at TIMESTAMP,
    changed_by VARCHAR(100),
    location_type VARCHAR(50),
    location_code VARCHAR(50),
    notes TEXT,
    customer_notified BOOLEAN,
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY (sat_shipment_status_history_id),
    
    CONSTRAINT fk_sat_shipment_status_history_hub_shipment 
        FOREIGN KEY (hub_shipment_id) 
        REFERENCES dwh_detailed.hub_shipment(hub_shipment_id),
    
    CONSTRAINT fk_sat_shipment_status_history_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_sat_shipment_status_history_parent 
    ON dwh_detailed.sat_shipment_status_history(hub_shipment_id);
    
CREATE INDEX IF NOT EXISTS idx_sat_shipment_status_history_current 
    ON dwh_detailed.sat_shipment_status_history(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_sat_shipment_status_history_dates 
    ON dwh_detailed.sat_shipment_status_history(effective_from, effective_to);

CREATE OR REPLACE FUNCTION dwh_detailed.calc_sat_shipment_status_history_hash(

    p_old_status VARCHAR(50),
    p_new_status VARCHAR(50),
    p_change_reason VARCHAR(200),
    p_changed_at TIMESTAMP,
    p_changed_by VARCHAR(100),
    p_location_type VARCHAR(50),
    p_location_code VARCHAR(50),
    p_notes TEXT,
    p_customer_notified BOOLEAN
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE(p_old_status::TEXT || '|' || p_new_status::TEXT || '|' || p_change_reason::TEXT || '|' || p_changed_at::TEXT || '|' || p_changed_by::TEXT || '|' || p_location_type::TEXT || '|' || p_location_code::TEXT || '|' || p_notes::TEXT || '|' || p_customer_notified::TEXT, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

