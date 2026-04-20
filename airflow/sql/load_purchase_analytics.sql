TRUNCATE TABLE presentation.purchase_analytics;

WITH base AS (
    SELECT
        sod.order_date::date AS purchase_date,
        DENSE_RANK() OVER (ORDER BY hp.product_sku) AS product_id,
        COALESCE(soi.product_name_snapshot, spd.product_name, hp.product_sku) AS product_name,
        COALESCE(soi.product_category_snapshot, spd.category, 'unknown') AS category,
        COALESCE(NULLIF(soi.product_brand_snapshot, ''), NULLIF(spd.brand, ''), 'Unknown Supplier') AS supplier_name,
        soi.quantity::numeric AS quantity,
        soi.total_price::numeric AS total_price
    FROM dwh_detailed.link_order_product lop
    JOIN dwh_detailed.hub_product hp
      ON hp.hub_product_id = lop.hub_product_id
    JOIN dwh_detailed.hub_order ho
      ON ho.hub_order_id = lop.hub_order_id
    JOIN dwh_detailed.sat_order_details sod
      ON sod.hub_order_id = ho.hub_order_id
     AND sod.is_current = TRUE
    JOIN dwh_detailed.sat_order_item_details soi
      ON soi.link_order_product_id = lop.link_order_product_id
     AND soi.is_current = TRUE
    LEFT JOIN dwh_detailed.sat_product_details spd
      ON spd.hub_product_id = hp.hub_product_id
     AND spd.is_current = TRUE
), grouped AS (
    SELECT
        purchase_date,
        product_id,
        product_name,
        category,
        supplier_name,
        SUM(quantity) AS purchase_qty,
        SUM(total_price) AS total_purchase_amount,
        SUM(total_price) / NULLIF(SUM(quantity), 0) AS avg_unit_price
    FROM base
    GROUP BY
        purchase_date,
        product_id,
        product_name,
        category,
        supplier_name
)
INSERT INTO presentation.purchase_analytics (
    purchase_date,
    product_id,
    product_name,
    category,
    supplier_id,
    supplier_name,
    purchase_qty,
    total_purchase_amount,
    avg_unit_price
)
SELECT
    purchase_date,
    product_id,
    product_name,
    category,
    DENSE_RANK() OVER (ORDER BY supplier_name) AS supplier_id,
    supplier_name,
    purchase_qty,
    total_purchase_amount,
    avg_unit_price
FROM grouped;