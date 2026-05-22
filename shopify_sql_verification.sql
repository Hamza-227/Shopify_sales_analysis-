-- ============================================================
-- 🛒 E-COMMERCE DASHBOARD — SQL VERIFICATION QUERIES
-- Table  : table_shopify_sales_analysis
-- Engine : MySQL / PostgreSQL / SQLite compatible
-- Purpose: Verify every KPI and chart in the dashboard
-- ============================================================
-- COLUMNS:
--   order_id, order_date, customer_id, product_id,
--   product_category, product_price, discount_percent,
--   quantity, customer_country, traffic_source,
--   payment_method, shipping_cost, rating, is_returned,
--   discounted_price, revenue, profit
-- ============================================================


-- ══════════════════════════════════════════════════════════
--  🎯 SECTION 1 — KPI VERIFICATION (10 Queries)
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- Q1 · KPI 1: Total Revenue
--      Dashboard should show: $XX.XXM
-- ─────────────────────────────────────────────────────────
SELECT
    SUM(revenue)                          AS total_revenue_exact,
    ROUND(SUM(revenue) / 1000000.0, 2)   AS total_revenue_M,
    COUNT(*)                              AS total_rows
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q2 · KPI 2: Total Quantity Sold
--      Dashboard should show: XXK
-- ─────────────────────────────────────────────────────────
SELECT
    SUM(quantity)                         AS total_quantity,
    ROUND(SUM(quantity) / 1000.0, 1)     AS total_quantity_K
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q3 · KPI 3: Return Rate (%)
--      Formula: SUM(is_returned) / COUNT(order_date) * 100
-- ─────────────────────────────────────────────────────────
SELECT
    COUNT(*)                                        AS total_orders,
    SUM(is_returned)                                AS total_returned,
    ROUND(SUM(is_returned) * 100.0 / COUNT(*), 2)  AS return_rate_pct
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q4 · KPI 4: Lost Revenue (revenue from returned orders)
-- ─────────────────────────────────────────────────────────
SELECT
    SUM(revenue)                                    AS lost_revenue_exact,
    ROUND(SUM(revenue) / 1000.0, 1)               AS lost_revenue_K,
    COUNT(*)                                        AS returned_orders
FROM table_shopify_sales_analysis
WHERE is_returned = 1;


-- ─────────────────────────────────────────────────────────
-- Q5 · KPI 5: Average Rating
-- ─────────────────────────────────────────────────────────
SELECT
    ROUND(AVG(rating), 2)   AS avg_rating,
    MIN(rating)             AS min_rating,
    MAX(rating)             AS max_rating,
    COUNT(*)                AS rated_orders
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q6 · KPI 6: Total Orders
-- ─────────────────────────────────────────────────────────
SELECT
    COUNT(*)                                AS total_orders,
    COUNT(DISTINCT order_id)               AS unique_order_ids,
    MIN(order_date)                         AS first_order_date,
    MAX(order_date)                         AS last_order_date
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q7 · KPI 7: Total Customers (Distinct)
-- ─────────────────────────────────────────────────────────
SELECT
    COUNT(DISTINCT customer_id)             AS total_customers,
    COUNT(*)                                AS total_rows,
    ROUND(COUNT(*) * 1.0 /
          COUNT(DISTINCT customer_id), 2)   AS avg_orders_per_customer
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q8 · KPI 8: Total Profit
-- ─────────────────────────────────────────────────────────
SELECT
    SUM(profit)                             AS total_profit_exact,
    ROUND(SUM(profit) / 1000000.0, 2)      AS total_profit_M,
    ROUND(SUM(profit) / SUM(revenue) * 100, 2) AS profit_margin_pct,
    COUNT(CASE WHEN profit < 0 THEN 1 END) AS negative_profit_rows
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q9 · KPI 9: Total Discount Value
--      Formula: SUM(product_price - discounted_price)
-- ─────────────────────────────────────────────────────────
SELECT
    ROUND(SUM(product_price - discounted_price), 2)        AS total_discount_value,
    ROUND(SUM(product_price - discounted_price)/1000.0, 1) AS total_discount_K,
    ROUND(AVG(discount_percent), 2)                         AS avg_discount_pct,
    COUNT(CASE WHEN discount_percent > 0 THEN 1 END)       AS discounted_orders
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q10 · KPI 10: Avg Shipping Cost
-- ─────────────────────────────────────────────────────────
SELECT
    ROUND(AVG(shipping_cost), 2)    AS avg_shipping_cost,
    MIN(shipping_cost)              AS min_shipping,
    MAX(shipping_cost)              AS max_shipping,
    ROUND(SUM(shipping_cost), 2)    AS total_shipping_cost
FROM table_shopify_sales_analysis;


-- ══════════════════════════════════════════════════════════
--  📊 SECTION 2 — CHART VERIFICATION (12 Queries)
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- Q11 · Chart 1: Revenue Trend — Monthly Aggregation
-- ─────────────────────────────────────────────────────────
SELECT
    DATE_FORMAT(order_date, '%Y-%m')        AS year_month,
    ROUND(SUM(revenue), 2)                  AS monthly_revenue,
    ROUND(SUM(profit), 2)                   AS monthly_profit,
    COUNT(*)                                AS monthly_orders,
    SUM(quantity)                           AS monthly_qty
FROM table_shopify_sales_analysis
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY year_month;


-- ─────────────────────────────────────────────────────────
-- Q12 · Chart 1 (Alt): Month-over-Month Growth %
-- ─────────────────────────────────────────────────────────
SELECT
    year_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY year_month) AS prev_month_revenue,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY year_month))
        / LAG(monthly_revenue) OVER (ORDER BY year_month) * 100, 2
    ) AS growth_pct
FROM (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m') AS year_month,
        ROUND(SUM(revenue), 2) AS monthly_revenue
    FROM table_shopify_sales_analysis
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
) t
ORDER BY year_month;


-- ─────────────────────────────────────────────────────────
-- Q13 · Chart 3: Revenue & Profit by Category
-- ─────────────────────────────────────────────────────────
SELECT
    product_category,
    ROUND(SUM(revenue), 2)      AS total_revenue,
    ROUND(SUM(profit), 2)       AS total_profit,
    COUNT(*)                    AS total_orders,
    ROUND(AVG(revenue), 2)      AS avg_revenue_per_order,
    ROUND(SUM(profit)/SUM(revenue)*100, 2) AS profit_margin_pct
FROM table_shopify_sales_analysis
GROUP BY product_category
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- Q14 · Chart 4: Return Analysis — Donut
-- ─────────────────────────────────────────────────────────
SELECT
    CASE WHEN is_returned = 1 THEN 'Returned' ELSE 'Not Returned' END AS status,
    COUNT(*)                                    AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
    ROUND(SUM(revenue), 2)                      AS revenue_sum
FROM table_shopify_sales_analysis
GROUP BY is_returned
ORDER BY is_returned DESC;


-- ─────────────────────────────────────────────────────────
-- Q15 · Chart 5: Revenue by Country
-- ─────────────────────────────────────────────────────────
SELECT
    customer_country,
    ROUND(SUM(revenue), 2)      AS total_revenue,
    COUNT(*)                    AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(AVG(revenue), 2)      AS avg_order_value
FROM table_shopify_sales_analysis
GROUP BY customer_country
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- Q16 · Chart 6: Profit by Traffic Source
-- ─────────────────────────────────────────────────────────
SELECT
    traffic_source,
    ROUND(SUM(profit), 2)   AS total_profit,
    ROUND(SUM(revenue), 2)  AS total_revenue,
    COUNT(*)                AS total_orders,
    ROUND(AVG(profit), 2)   AS avg_profit_per_order
FROM table_shopify_sales_analysis
GROUP BY traffic_source
ORDER BY total_profit DESC;


-- ─────────────────────────────────────────────────────────
-- Q17 · Chart 7: Discount % vs Avg Profit (Banded)
-- ─────────────────────────────────────────────────────────
SELECT
    CASE
        WHEN discount_percent = 0        THEN '0%'
        WHEN discount_percent <= 10      THEN '1-10%'
        WHEN discount_percent <= 20      THEN '11-20%'
        WHEN discount_percent <= 30      THEN '21-30%'
        WHEN discount_percent <= 40      THEN '31-40%'
        ELSE '41%+'
    END                             AS discount_band,
    COUNT(*)                        AS orders,
    ROUND(AVG(profit), 2)          AS avg_profit,
    ROUND(SUM(profit), 2)          AS total_profit,
    ROUND(AVG(revenue), 2)         AS avg_revenue
FROM table_shopify_sales_analysis
GROUP BY
    CASE
        WHEN discount_percent = 0   THEN '0%'
        WHEN discount_percent <= 10 THEN '1-10%'
        WHEN discount_percent <= 20 THEN '11-20%'
        WHEN discount_percent <= 30 THEN '21-30%'
        WHEN discount_percent <= 40 THEN '31-40%'
        ELSE '41%+'
    END
ORDER BY MIN(discount_percent);


-- ─────────────────────────────────────────────────────────
-- Q18 · Chart 8: Avg Rating vs Return Status
-- ─────────────────────────────────────────────────────────
SELECT
    CASE WHEN is_returned = 1 THEN 'Returned' ELSE 'Not Returned' END AS status,
    ROUND(AVG(rating), 2)   AS avg_rating,
    COUNT(*)                AS order_count,
    MIN(rating)             AS min_rating,
    MAX(rating)             AS max_rating
FROM table_shopify_sales_analysis
GROUP BY is_returned
ORDER BY is_returned DESC;


-- ─────────────────────────────────────────────────────────
-- Q19 · Chart 9: Payment Method Analysis
-- ─────────────────────────────────────────────────────────
SELECT
    payment_method,
    ROUND(SUM(revenue), 2)                      AS total_revenue,
    COUNT(*)                                    AS total_orders,
    ROUND(SUM(revenue) / COUNT(*), 2)           AS avg_order_value,
    ROUND(SUM(profit), 2)                       AS total_profit,
    ROUND(SUM(profit)/SUM(revenue)*100, 2)      AS profit_margin_pct
FROM table_shopify_sales_analysis
GROUP BY payment_method
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- Q20 · Chart 10: Shipping Cost vs Avg Profit (Banded)
-- ─────────────────────────────────────────────────────────
SELECT
    CASE
        WHEN shipping_cost <= 5  THEN '$0-5'
        WHEN shipping_cost <= 10 THEN '$5-10'
        WHEN shipping_cost <= 15 THEN '$10-15'
        WHEN shipping_cost <= 20 THEN '$15-20'
        WHEN shipping_cost <= 25 THEN '$20-25'
        ELSE '$25+'
    END                         AS shipping_band,
    COUNT(*)                    AS orders,
    ROUND(AVG(profit), 2)      AS avg_profit,
    ROUND(SUM(profit), 2)      AS total_profit,
    ROUND(AVG(shipping_cost), 2) AS avg_shipping_in_band
FROM table_shopify_sales_analysis
GROUP BY
    CASE
        WHEN shipping_cost <= 5  THEN '$0-5'
        WHEN shipping_cost <= 10 THEN '$5-10'
        WHEN shipping_cost <= 15 THEN '$10-15'
        WHEN shipping_cost <= 20 THEN '$15-20'
        WHEN shipping_cost <= 25 THEN '$20-25'
        ELSE '$25+'
    END
ORDER BY MIN(shipping_cost);


-- ─────────────────────────────────────────────────────────
-- Q21 · Chart: Top 10 Products by Revenue
-- ─────────────────────────────────────────────────────────
SELECT
    product_id,
    product_category,
    ROUND(SUM(revenue), 2)      AS total_revenue,
    ROUND(SUM(profit), 2)       AS total_profit,
    COUNT(*)                    AS total_orders,
    ROUND(SUM(revenue)/SUM(profit), 2) AS revenue_to_profit_ratio
FROM table_shopify_sales_analysis
GROUP BY product_id, product_category
ORDER BY total_revenue DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────
-- Q22 · Revenue vs Quantity (Dual Axis) — Monthly
-- ─────────────────────────────────────────────────────────
SELECT
    DATE_FORMAT(order_date, '%Y-%m')  AS year_month,
    ROUND(SUM(revenue), 2)            AS monthly_revenue,
    SUM(quantity)                     AS monthly_quantity,
    COUNT(*)                          AS monthly_orders,
    ROUND(AVG(revenue), 2)            AS avg_order_revenue
FROM table_shopify_sales_analysis
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY year_month;


-- ══════════════════════════════════════════════════════════
--  🔬 SECTION 3 — DATA INTEGRITY CHECKS (8 Queries)
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- Q23 · Data Integrity: Discounted Price Formula
--      Expected: discounted_price = product_price * (1 - discount_percent/100)
-- ─────────────────────────────────────────────────────────
SELECT
    COUNT(*) AS total_rows,
    COUNT(CASE
        WHEN ABS(discounted_price - product_price * (1 - discount_percent / 100.0)) > 0.05
        THEN 1 END
    ) AS formula_mismatches,
    ROUND(
        COUNT(CASE
            WHEN ABS(discounted_price - product_price * (1 - discount_percent / 100.0)) <= 0.05
            THEN 1 END
        ) * 100.0 / COUNT(*), 2
    ) AS match_rate_pct
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q24 · Data Integrity: Revenue Formula
--      Expected: revenue = discounted_price * quantity
-- ─────────────────────────────────────────────────────────
SELECT
    COUNT(*) AS total_rows,
    COUNT(CASE
        WHEN ABS(revenue - discounted_price * quantity) > 0.10
        THEN 1 END
    ) AS formula_mismatches,
    ROUND(MAX(ABS(revenue - discounted_price * quantity)), 4) AS max_diff
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q25 · Data Integrity: Duplicate Order IDs
-- ─────────────────────────────────────────────────────────
SELECT
    COUNT(*)            AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicates
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q26 · Data Integrity: NULL / Zero Value Check
-- ─────────────────────────────────────────────────────────
SELECT
    COUNT(CASE WHEN order_id IS NULL      THEN 1 END) AS null_order_id,
    COUNT(CASE WHEN order_date IS NULL    THEN 1 END) AS null_date,
    COUNT(CASE WHEN revenue IS NULL       THEN 1 END) AS null_revenue,
    COUNT(CASE WHEN profit IS NULL        THEN 1 END) AS null_profit,
    COUNT(CASE WHEN revenue = 0           THEN 1 END) AS zero_revenue,
    COUNT(CASE WHEN quantity <= 0         THEN 1 END) AS zero_qty,
    COUNT(CASE WHEN product_price <= 0    THEN 1 END) AS zero_price
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q27 · Outlier Detection: Revenue Extremes
-- ─────────────────────────────────────────────────────────
SELECT
    MIN(revenue)                AS min_revenue,
    MAX(revenue)                AS max_revenue,
    ROUND(AVG(revenue), 2)      AS avg_revenue,
    ROUND(STDDEV(revenue), 2)   AS stddev_revenue,
    COUNT(CASE WHEN revenue > AVG(revenue) + 3*STDDEV(revenue) THEN 1 END) AS high_outliers,
    COUNT(CASE WHEN revenue < AVG(revenue) - 3*STDDEV(revenue) THEN 1 END) AS low_outliers
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q28 · Date Range & Distribution
-- ─────────────────────────────────────────────────────────
SELECT
    MIN(order_date)                     AS earliest_order,
    MAX(order_date)                     AS latest_order,
    DATEDIFF(MAX(order_date), MIN(order_date)) AS date_span_days,
    COUNT(DISTINCT DATE_FORMAT(order_date,'%Y-%m')) AS active_months,
    COUNT(DISTINCT DATE(order_date))    AS active_days
FROM table_shopify_sales_analysis;


-- ─────────────────────────────────────────────────────────
-- Q29 · Category & Country Distribution (row count check)
-- ─────────────────────────────────────────────────────────
SELECT
    product_category,
    customer_country,
    COUNT(*)                        AS orders,
    ROUND(SUM(revenue), 2)         AS revenue,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (), 2)  AS pct_of_total
FROM table_shopify_sales_analysis
GROUP BY product_category, customer_country
ORDER BY orders DESC
LIMIT 20;


-- ─────────────────────────────────────────────────────────
-- Q30 · MASTER AUDIT QUERY — All 10 KPIs in One Shot
--      Run this single query and compare directly to dashboard
-- ─────────────────────────────────────────────────────────
SELECT
    -- KPI 1
    ROUND(SUM(revenue), 2)                                  AS kpi1_total_revenue,
    -- KPI 2
    SUM(quantity)                                           AS kpi2_total_quantity,
    -- KPI 3
    ROUND(SUM(is_returned) * 100.0 / COUNT(*), 2)          AS kpi3_return_rate_pct,
    -- KPI 4
    ROUND(SUM(CASE WHEN is_returned=1 THEN revenue ELSE 0 END), 2) AS kpi4_lost_revenue,
    -- KPI 5
    ROUND(AVG(rating), 2)                                   AS kpi5_avg_rating,
    -- KPI 6
    COUNT(*)                                                AS kpi6_total_orders,
    -- KPI 7
    COUNT(DISTINCT customer_id)                             AS kpi7_total_customers,
    -- KPI 8
    ROUND(SUM(profit), 2)                                   AS kpi8_total_profit,
    -- KPI 9
    ROUND(SUM(product_price - discounted_price), 2)        AS kpi9_total_discount_value,
    -- KPI 10
    ROUND(AVG(shipping_cost), 2)                           AS kpi10_avg_shipping_cost
FROM table_shopify_sales_analysis;

-- ═══════════════════════════════════════════════════════════
-- END OF VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════
-- HOW TO USE:
-- 1. Import your CSV into MySQL/PostgreSQL as:
--    table_shopify_sales_analysis
-- 2. Run Q30 first → compare all 10 values to the dashboard
-- 3. Run Q11–Q22 → compare each chart's data
-- 4. Run Q23–Q29 → validate data integrity
-- 5. Any mismatch? Check filters applied in the dashboard
-- ═══════════════════════════════════════════════════════════
