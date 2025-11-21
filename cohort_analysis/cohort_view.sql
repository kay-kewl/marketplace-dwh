CREATE OR REPLACE VIEW cohort_analysis_view AS
WITH user_cohorts AS (
    SELECT 
        user_external_id,
        DATE_TRUNC('month', MIN(order_date)) AS cohort_month
    FROM orders
    GROUP BY user_external_id
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(user_external_id) AS cohort_size
    FROM user_cohorts
    GROUP BY cohort_month
),

user_activity AS (
    SELECT
        uc.user_external_id,
        uc.cohort_month,
        DATE_TRUNC('month', o.order_date) AS activity_month,
        EXTRACT(MONTH FROM AGE(o.order_date, uc.cohort_month)) AS period_number,
        o.total_amount
    FROM user_cohorts uc
    JOIN orders o ON uc.user_external_id = o.user_external_id
    WHERE o.order_date >= uc.cohort_month 
      AND o.order_date < uc.cohort_month + INTERVAL '6 months'
),

cohort_data AS (
    SELECT
        uc.cohort_month,
        cs.cohort_size,
        period.period_num,
        COUNT(DISTINCT ua.user_external_id) AS active_users,
        ROUND(
            COUNT(DISTINCT ua.user_external_id) * 100.0 / cs.cohort_size, 
            2
        ) AS retention_pct
    FROM user_cohorts uc
    CROSS JOIN (VALUES (0), (1), (2), (3), (4), (5)) AS period(period_num)
    LEFT JOIN user_activity ua ON uc.user_external_id = ua.user_external_id AND ua.period_number = period.period_num
    JOIN cohort_sizes cs ON uc.cohort_month = cs.cohort_month
    GROUP BY uc.cohort_month, cs.cohort_size, period.period_num
),

cohort_pivot AS (
    SELECT
        cd.cohort_month,
        cd.cohort_size,
        MAX(CASE WHEN cd.period_num = 0 THEN cd.retention_pct END) AS period_0_pct,
        MAX(CASE WHEN cd.period_num = 1 THEN cd.retention_pct END) AS period_1_pct,
        MAX(CASE WHEN cd.period_num = 2 THEN cd.retention_pct END) AS period_2_pct,
        MAX(CASE WHEN cd.period_num = 3 THEN cd.retention_pct END) AS period_3_pct,
        MAX(CASE WHEN cd.period_num = 4 THEN cd.retention_pct END) AS period_4_pct,
        MAX(CASE WHEN cd.period_num = 5 THEN cd.retention_pct END) AS period_5_pct
    FROM cohort_data cd
    GROUP BY cd.cohort_month, cd.cohort_size
),

cohort_revenue AS (
    SELECT
        uc.cohort_month,
        SUM(ua.total_amount) AS total_cohort_revenue,
        ROUND(SUM(ua.total_amount) / COUNT(DISTINCT uc.user_external_id), 2) AS avg_revenue_per_customer
    FROM user_cohorts uc
    JOIN user_activity ua ON uc.user_external_id = ua.user_external_id
    GROUP BY uc.cohort_month
)

SELECT
    cp.cohort_month,
    cp.cohort_size,
    cp.period_0_pct,
    cp.period_1_pct,
    cp.period_2_pct,
    cp.period_3_pct,
    cp.period_4_pct,
    cp.period_5_pct,
    cr.total_cohort_revenue,
    cr.avg_revenue_per_customer
FROM cohort_pivot cp
JOIN cohort_revenue cr ON cp.cohort_month = cr.cohort_month
ORDER BY cp.cohort_month;
