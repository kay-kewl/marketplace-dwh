### Hubs

- hub_user
- hub_address
- hub_product
- hub_order
- hub_warehouse
- hub_shipment
- hub_pickup_point

### Links
- link_order_user
    Много заказов - один пользователь
- link_user_address 
    Один пользователь - много адресов
- link_order_address
    Много заказов - один адрес
- link_order_product
    Один заказ - много товаров
- link_shipment_order
    Одна посылка - один заказ
- link_shipment_warehouse
    Много посылок - один склад
- link_shipment_pickup_point
    Много посылок - один пвз назначения

### Satellites
- sat_user_details
    - **hub:** hub_user
    - **attributes:** email, first_name, last_name, phone, date_of_birth, registration_date, status 
    - **ключи SCD2:** status, email, phone
    - **частота изменений:** низкая
- sat_user_status_history
    - **hub:** hub_user
    - **attributes:** old_status, new_status, change_reason, changed_at, changed_by, session_id, ip_address, user_agent
    - **type:** insert-only
- sat_address_details
    - **hub:** hub_address
    - **attributes:** address_type, country, region, city, street_address, postal_code, apartment, is_default
    - **ключи SCD2:** все атрибуты
    - **частота изменений:** низкая
- sat_product_details
    - **hub:** hub_product
    - **attributes:** product_name, category, brand, price, currency, weight_grams, dimensions_length_cm, dimensions_width_cm, dimensions_height_cm, is_active
    - **ключи SCD2:** price, is_active, product_name
    - **частота изменений:** средняя
- sat_order_details
    - **hub:** hub_order
    - **attributes:** order_number, order_date, status, subtotal, tax_amount, shipping_cost, discount_amount, total_amount, currency, delivery_type, expected_delivery_date, actual_delivery_date, payment_method, payment_status
    - **ключи SCD2:** status, payment_status, total_amount
    - **частота изменений:** средняя
- sat_order_status_history
    - **hub:** hub_order
    - **attributes:** old_status, new_status, change_reason, changed_at, changed_by, session_id, ip_address, notes
    - **type:** insert-only
- sat_order_item_details
    - **link:** link_order_product
    - **attributes:** quantity, unit_price, total_price, product_name_snapshot, product_category_snapshot, product_brand_snapshot, created_at, updated_at
    - **type:** insert-only
- sat_warehouse_details
    - **hub:** hub_warehouse
    - **attributes:** warehouse_name, warehouse_type, country, region, city, street_address, postal_code, is_active, max_capacity_cubic_meters, operating_hours, contact_phone, manager_name
    - **ключи SCD2:** is_active, max_capacity, manager_name
    - **частота изменений:** низкая
- sat_pickup_point_details
    - **hub:** hub_pickup_point
    - **attributes:** pickup_point_name, pickup_point_type, country, region, city, street_address, postal_code, is_active, max_capacity_packages, operating_hours, contact_phone, partner_name
    - **ключи SCD2:** is_active, max_capacity_packages
    - **частота изменений:** низкая
- sat_shipment_details
    - **hub:** hub_shipment
    - **attributes:** tracking_number, status, weight_grams, volume_cubic_cm, package_count, created_date, dispatched_date, estimated_delivery_date, actual_delivery_date, delivery_notes, recipient_name, delivery_signature
    - **ключи SCD2:** status, actual_delivery_date
    - **частота изменений:** средняя
- sat_shipment_status_history
    - **hub:** hub_shipment
    - **attributes:** old_status, new_status, change_reason, changed_at, changed_by, location_type, location_code, notes, customer_notified
    - **type:** insert-only
- sat_shipment_movements
    - **hub:** hub_shipment
    - **attributes:** movement_type, location_type, location_code, movement_datetime, operator_name, notes, latitude, longitude
    - **type:** insert-only