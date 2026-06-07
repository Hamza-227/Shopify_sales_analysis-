-- =============================================================================
-- FILE: 03_kpi_layer.sql
-- PROJECT: Shopify E-Commerce Analytics Data Warehouse
-- LAYER: Analytics / KPI Layer
-- DESCRIPTION: Reusable business metrics views — single source of truth for BI
-- =============================================================================

-- =============================================================================
-- SECTION 1: CORE REVENUE & PROFIT KPIs
-- =============================================================================

-- Overall business health summary
CREATE OR REPLACE VIEW kpi_business_summary AS
SELECT
    COUNT(DISTINCT fs.order_id)                                     AS total_orders,
    COUNT(DISTINCT fs.customer_key)                                 AS total_customers,
    SUM(fs.revenue)                                                 AS total_revenue,
    SUM(fs.gross_revenue)                                           AS total_gross_revenue,
    SUM(fs.profit)                                                  AS total_profit,
    SUM(fs.discount_amount)                                         AS total_discount_given,
    SUM(fs.shipping_cost)                                           AS total_shipping_cost,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2)
                                                                    AS average_order_value,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS overall_profit_margin_pct,
    ROUND(SUM(fs.discount_amount) / NULLIF(SUM(fs.gross_revenue), 0) * 100, 2)
                                                                    AS overall_discount_rate_pct,
    ROUND(
        SUM(CASE WHEN fs.is_returned = 1 THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                               AS return_rate_pct,
    MIN(dd.full_date)                                               AS data_start_date,
    MAX(dd.full_date)                                               AS data_end_date
FROM fact_sales fs
JOIN dim_date dd ON fs.date_key = dd.date_key;

COMMENT ON VIEW kpi_business_summary IS 'Single-row executive summary of all core KPIs across full dataset history.';


-- =============================================================================
-- SECTION 2: REVENUE KPIs
-- =============================================================================

-- Monthly revenue trend
CREATE OR REPLACE VIEW kpi_monthly_revenue AS
SELECT
    dd.year,
    dd.month,
    dd.month_label,
    dd.quarter_label,
    COUNT(DISTINCT fs.order_id)                                     AS orders,
    COUNT(DISTINCT fs.customer_key)                                 AS unique_customers,
    ROUND(SUM(fs.revenue), 2)                                       AS revenue,
    ROUND(SUM(fs.gross_revenue), 2)                                 AS gross_revenue,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov
FROM fact_sales fs
JOIN dim_date dd ON fs.date_key = dd.date_key
GROUP BY dd.year, dd.month, dd.month_label, dd.quarter_label
ORDER BY dd.year, dd.month;

-- Quarterly revenue
CREATE OR REPLACE VIEW kpi_quarterly_revenue AS
SELECT
    dd.year,
    dd.quarter,
    dd.quarter_label,
    ROUND(SUM(fs.revenue), 2)                                       AS revenue,
    ROUND(SUM(fs.profit), 2)                                        AS profit,
    COUNT(DISTINCT fs.order_id)                                     AS orders,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS profit_margin_pct
FROM fact_sales fs
JOIN dim_date dd ON fs.date_key = dd.date_key
GROUP BY dd.year, dd.quarter, dd.quarter_label
ORDER BY dd.year, dd.quarter;

-- Annual revenue
CREATE OR REPLACE VIEW kpi_annual_revenue AS
SELECT
    dd.year,
    ROUND(SUM(fs.revenue), 2)                                       AS revenue,
    ROUND(SUM(fs.profit), 2)                                        AS profit,
    COUNT(DISTINCT fs.order_id)                                     AS orders,
    COUNT(DISTINCT fs.customer_key)                                 AS customers,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS profit_margin_pct
FROM fact_sales fs
JOIN dim_date dd ON fs.date_key = dd.date_key
GROUP BY dd.year
ORDER BY dd.year;


-- =============================================================================
-- SECTION 3: PROFIT KPIs
-- =============================================================================

-- Profit by category
CREATE OR REPLACE VIEW kpi_profit_by_category AS
SELECT
    dp.product_category,
    COUNT(DISTINCT fs.order_id)                                     AS orders,
    SUM(fs.quantity)                                                AS units_sold,
    ROUND(SUM(fs.revenue), 2)                                       AS revenue,
    ROUND(SUM(fs.profit), 2)                                        AS profit,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS profit_margin_pct,
    ROUND(AVG(fs.discount_percent), 2)                              AS avg_discount_pct,
    ROUND(
        SUM(CASE WHEN fs.is_returned = 1 THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                               AS return_rate_pct
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
GROUP BY dp.product_category
ORDER BY profit DESC;


-- =============================================================================
-- SECTION 4: AVERAGE ORDER VALUE (AOV)
-- =============================================================================

CREATE OR REPLACE VIEW kpi_aov_by_channel AS
SELECT
    dts.traffic_source,
    dts.channel_type,
    dts.is_paid,
    COUNT(DISTINCT fs.order_id)                                     AS orders,
    ROUND(SUM(fs.revenue), 2)                                       AS total_revenue,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS profit_margin_pct
FROM fact_sales fs
JOIN dim_traffic_source dts ON fs.traffic_source_key = dts.traffic_source_key
GROUP BY dts.traffic_source, dts.channel_type, dts.is_paid
ORDER BY aov DESC;


-- =============================================================================
-- SECTION 5: RETURN RATE KPIs
-- =============================================================================

CREATE OR REPLACE VIEW kpi_return_rate AS
SELECT
    dp.product_category,
    COUNT(*)                                                        AS total_orders,
    SUM(fs.is_returned)                                             AS returned_orders,
    ROUND(SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2)
                                                                    AS return_rate_pct,
    ROUND(SUM(CASE WHEN fs.is_returned = 1 THEN fs.revenue ELSE 0 END), 2)
                                                                    AS returned_revenue,
    ROUND(AVG(CASE WHEN fs.is_returned = 1 THEN fs.rating END), 2) AS avg_rating_returned,
    ROUND(AVG(CASE WHEN fs.is_returned = 0 THEN fs.rating END), 2) AS avg_rating_kept
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
GROUP BY dp.product_category
ORDER BY return_rate_pct DESC;


-- =============================================================================
-- SECTION 6: DISCOUNT IMPACT KPIs
-- =============================================================================

CREATE OR REPLACE VIEW kpi_discount_impact AS
SELECT
    CASE
        WHEN fs.discount_percent = 0          THEN '0% (No Discount)'
        WHEN fs.discount_percent BETWEEN 1 AND 10   THEN '1–10%'
        WHEN fs.discount_percent BETWEEN 11 AND 20  THEN '11–20%'
        WHEN fs.discount_percent BETWEEN 21 AND 30  THEN '21–30%'
        WHEN fs.discount_percent BETWEEN 31 AND 40  THEN '31–40%'
        ELSE '40%+'
    END                                                             AS discount_band,
    COUNT(*)                                                        AS orders,
    ROUND(SUM(fs.revenue), 2)                                       AS revenue,
    ROUND(SUM(fs.profit), 2)                                        AS profit,
    ROUND(SUM(fs.discount_amount), 2)                               AS total_discount_given,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS profit_margin_pct,
    ROUND(AVG(fs.rating), 2)                                        AS avg_rating,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                               AS return_rate_pct
FROM fact_sales fs
GROUP BY 1
ORDER BY MIN(fs.discount_percent);


-- =============================================================================
-- SECTION 7: COUNTRY / GEO KPIs
-- =============================================================================

CREATE OR REPLACE VIEW kpi_country_performance AS
SELECT
    dc.country_name,
    dc.region,
    COUNT(DISTINCT fs.order_id)                                     AS orders,
    COUNT(DISTINCT fs.customer_key)                                 AS customers,
    ROUND(SUM(fs.revenue), 2)                                       AS revenue,
    ROUND(SUM(fs.profit), 2)                                        AS profit,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS profit_margin_pct,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                               AS return_rate_pct
FROM fact_sales fs
JOIN dim_country dc ON fs.country_key = dc.country_key
GROUP BY dc.country_name, dc.region
ORDER BY revenue DESC;


-- =============================================================================
-- SECTION 8: PAYMENT METHOD KPIs
-- =============================================================================

CREATE OR REPLACE VIEW kpi_payment_performance AS
SELECT
    dpm.payment_method,
    dpm.payment_type,
    dpm.is_digital_wallet,
    COUNT(DISTINCT fs.order_id)                                     AS orders,
    ROUND(SUM(fs.revenue), 2)                                       AS revenue,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS profit_margin_pct,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                               AS return_rate_pct
FROM fact_sales fs
JOIN dim_payment_method dpm ON fs.payment_method_key = dpm.payment_method_key
GROUP BY dpm.payment_method, dpm.payment_type, dpm.is_digital_wallet
ORDER BY revenue DESC;
