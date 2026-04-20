DELETE FROM presentation.warehouse_delivery_daily
WHERE shipment_date = CAST('{{ ti.xcom_pull(task_ids="resolve_business_date") }}' AS date);

WITH src AS (
    SELECT
        ssd.dispatched_date::date AS shipment_date,
        DENSE_RANK() OVER (ORDER BY hw.warehouse_code) AS warehouse_id,
        COALESCE(swd.warehouse_name, hw.warehouse_code) AS warehouse_name,
        ho.hub_order_id,
        lou.hub_user_id,
        COALESCE(ssd.package_count, 0)::numeric AS package_count,
        CASE
            WHEN ssd.dispatched_date IS NOT NULL AND sod.order_date IS NOT NULL
            THEN EXTRACT(EPOCH FROM (ssd.dispatched_date - sod.order_date)) / 60.0
            ELSE NULL
        END AS processing_time_min,
        CASE
            WHEN ssd.actual_delivery_date IS NOT NULL
             AND ssd.estimated_delivery_date IS NOT NULL
             AND ssd.actual_delivery_date::date > ssd.estimated_delivery_date::date
            THEN 1
            WHEN ssd.actual_delivery_date IS NULL
             AND ssd.estimated_delivery_date IS NOT NULL
             AND ssd.estimated_delivery_date::date < CAST('{{ ti.xcom_pull(task_ids="resolve_business_date") }}' AS date)
             AND ssd.status IN ('failed_delivery', 'cancelled')
            THEN 1
            ELSE 0
        END AS delayed_flag
    FROM dwh_detailed.sat_shipment_details ssd
    JOIN dwh_detailed.hub_shipment hs
      ON hs.hub_shipment_id = ssd.hub_shipment_id
    JOIN dwh_detailed.link_shipment_warehouse lsw
      ON lsw.hub_shipment_id = hs.hub_shipment_id
    JOIN dwh_detailed.hub_warehouse hw
      ON hw.hub_warehouse_id = lsw.hub_warehouse_id
    LEFT JOIN dwh_detailed.sat_warehouse_details swd
      ON swd.hub_warehouse_id = hw.hub_warehouse_id
     AND swd.is_current = TRUE
    JOIN dwh_detailed.link_shipment_order lso
      ON lso.hub_shipment_id = hs.hub_shipment_id
    JOIN dwh_detailed.hub_order ho
      ON ho.hub_order_id = lso.hub_order_id
    JOIN dwh_detailed.sat_order_details sod
      ON sod.hub_order_id = ho.hub_order_id
     AND sod.is_current = TRUE
    LEFT JOIN dwh_detailed.link_order_user lou
      ON lou.hub_order_id = ho.hub_order_id
    WHERE ssd.is_current = TRUE
      AND ssd.dispatched_date::date = CAST('{{ ti.xcom_pull(task_ids="resolve_business_date") }}' AS date)
)
INSERT INTO presentation.warehouse_delivery_daily (
    shipment_date,
    warehouse_id,
    warehouse_name,
    order_count,
    total_shipment_qty,
    avg_processing_time_min,
    delayed_orders_count,
    unique_customers_count
)
SELECT
    shipment_date,
    warehouse_id,
    warehouse_name,
    COUNT(DISTINCT hub_order_id)::int AS order_count,
    SUM(package_count) AS total_shipment_qty,
    AVG(processing_time_min) AS avg_processing_time_min,
    SUM(delayed_flag)::int AS delayed_orders_count,
    COUNT(DISTINCT hub_user_id)::int AS unique_customers_count
FROM src
GROUP BY shipment_date, warehouse_id, warehouse_name;