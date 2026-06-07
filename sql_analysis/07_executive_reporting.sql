-- =============================================================================
-- FILE: 07_executive_reporting.sql
-- PROJECT: Shopify E-Commerce Analytics Data Warehouse
-- LAYER: Analytics — Executive Reporting
-- DESCRIPTION: Board-ready queries for monthly reviews, QBRs, and BI dashboards
-- Designed for direct consumption by Power BI / Tableau / Looker
-- =============================================================================

-- =============================================================================
-- REPORT 1: EXECUTIVE SCORECARD — Full Business Health
-- Single query powering the top KPI tiles in any BI dashboard
-- =============================================================================

SELECT
    -- Volume metrics
    COUNT(DISTINCT fs.order_id)                                         AS total_orders,
    COUNT(DISTINCT fs.customer_key)                                     AS total_customers,
    SUM(fs.quantity)                                                    AS total_units_sold,

    -- Revenue metrics
    ROUND(SUM(fs.revenue), 2)                                           AS net_revenue,
    ROUND(SUM(fs.gross_revenue), 2)                                     AS gross_revenue,
    ROUND(SUM(fs.discount_amount), 2)                                   AS total_discounts,
    ROUND(SUM(fs.shipping_cost), 2)                                     AS total_shipping,

    -- Profitability
    ROUND(SUM(fs.profit), 2)                                            AS net_profit,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,

    -- Efficiency metrics
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS avg_order_value,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.customer_key), 0), 2)
                                                                        AS avg_revenue_per_customer,
    ROUND(SUM(fs.discount_amount) / NULLIF(SUM(fs.gross_revenue), 0) * 100, 2)
                                                                        AS discount_rate_pct,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS return_rate_pct,
    ROUND(AVG(fs.rating), 2)                                            AS avg_product_rating,

    -- Date range
    MIN(dd.full_date)                                                   AS period_start,
    MAX(dd.full_date)                                                   AS period_end
FROM fact_sales fs
JOIN dim_date dd ON fs.date_key = dd.date_key;


-- =============================================================================
-- REPORT 2: MONTHLY REVENUE & PROFIT TREND
-- Primary time-series for executive line charts
-- =============================================================================

SELECT
    dd.year,
    dd.month,
    dd.month_label,
    dd.quarter_label,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    COUNT(DISTINCT fs.customer_key)                                     AS customers,
    ROUND(SUM(fs.revenue), 2)                                           AS revenue,
    ROUND(SUM(fs.profit), 2)                                            AS profit,
    ROUND(SUM(fs.discount_amount), 2)                                   AS discounts,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    -- MoM Growth
    ROUND(
        (SUM(fs.revenue) - LAG(SUM(fs.revenue)) OVER (ORDER BY dd.year, dd.month))
        / NULLIF(LAG(SUM(fs.revenue)) OVER (ORDER BY dd.year, dd.month), 0) * 100, 2
    )                                                                   AS mom_revenue_growth_pct,
    -- Cumulative YTD
    SUM(SUM(fs.revenue)) OVER (
        PARTITION BY dd.year ORDER BY dd.month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                                   AS ytd_revenue
FROM fact_sales fs
JOIN dim_date dd ON fs.date_key = dd.date_key
GROUP BY dd.year, dd.month, dd.month_label, dd.quarter_label
ORDER BY dd.year, dd.month;


-- =============================================================================
-- REPORT 3: TOP 10 PRODUCTS BY REVENUE
-- =============================================================================

SELECT
    RANK() OVER (ORDER BY SUM(fs.revenue) DESC)                         AS rank,
    dp.product_id,
    dp.product_category,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    SUM(fs.quantity)                                                    AS units_sold,
    ROUND(SUM(fs.revenue), 2)                                           AS revenue,
    ROUND(SUM(fs.profit), 2)                                            AS profit,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    ROUND(AVG(fs.discount_percent), 2)                                  AS avg_discount_pct,
    ROUND(AVG(fs.rating), 2)                                            AS avg_rating,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS return_rate_pct,
    -- Revenue share of total
    ROUND(SUM(fs.revenue) / SUM(SUM(fs.revenue)) OVER () * 100, 2)     AS revenue_share_pct
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
GROUP BY dp.product_id, dp.product_category
ORDER BY revenue DESC
LIMIT 10;


-- =============================================================================
-- REPORT 4: CATEGORY PERFORMANCE SCORECARD
-- =============================================================================

SELECT
    dp.product_category,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    SUM(fs.quantity)                                                    AS units_sold,
    COUNT(DISTINCT fs.customer_key)                                     AS unique_customers,
    ROUND(SUM(fs.revenue), 2)                                           AS revenue,
    ROUND(SUM(fs.gross_revenue), 2)                                     AS gross_revenue,
    ROUND(SUM(fs.profit), 2)                                            AS profit,
    ROUND(SUM(fs.discount_amount), 2)                                   AS total_discounts,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    ROUND(AVG(fs.discount_percent), 2)                                  AS avg_discount_pct,
    ROUND(AVG(fs.rating), 2)                                            AS avg_rating,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS return_rate_pct,
    -- Category revenue share
    ROUND(SUM(fs.revenue) / SUM(SUM(fs.revenue)) OVER () * 100, 2)     AS revenue_share_pct,
    DENSE_RANK() OVER (ORDER BY SUM(fs.revenue) DESC)                  AS revenue_rank
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
GROUP BY dp.product_category
ORDER BY revenue DESC;


-- =============================================================================
-- REPORT 5: TOP 10 CUSTOMERS BY REVENUE
-- =============================================================================

SELECT
    RANK() OVER (ORDER BY SUM(fs.revenue) DESC)                         AS rank,
    dc.customer_id,
    dc.customer_country,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    ROUND(SUM(fs.revenue), 2)                                           AS lifetime_revenue,
    ROUND(SUM(fs.profit), 2)                                            AS lifetime_profit,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    MIN(dd.full_date)                                                   AS first_order_date,
    MAX(dd.full_date)                                                   AS last_order_date,
    -- Revenue share
    ROUND(SUM(fs.revenue) / SUM(SUM(fs.revenue)) OVER () * 100, 2)     AS revenue_share_pct,
    -- Cumulative share
    ROUND(
        SUM(SUM(fs.revenue)) OVER (
            ORDER BY SUM(fs.revenue) DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / SUM(SUM(fs.revenue)) OVER () * 100, 2
    )                                                                   AS cumulative_revenue_pct
FROM fact_sales fs
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
JOIN dim_date     dd ON fs.date_key      = dd.date_key
GROUP BY dc.customer_id, dc.customer_country
ORDER BY lifetime_revenue DESC
LIMIT 10;


-- =============================================================================
-- REPORT 6: TOP COUNTRIES BY REVENUE
-- =============================================================================

SELECT
    RANK() OVER (ORDER BY SUM(fs.revenue) DESC)                         AS rank,
    dco.country_name,
    dco.region,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    COUNT(DISTINCT fs.customer_key)                                     AS customers,
    ROUND(SUM(fs.revenue), 2)                                           AS revenue,
    ROUND(SUM(fs.profit), 2)                                            AS profit,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS return_rate_pct,
    ROUND(SUM(fs.revenue) / SUM(SUM(fs.revenue)) OVER () * 100, 2)     AS revenue_share_pct
FROM fact_sales fs
JOIN dim_country dco ON fs.country_key = dco.country_key
GROUP BY dco.country_name, dco.region
ORDER BY revenue DESC;


-- =============================================================================
-- REPORT 7: TOP CHANNELS (Marketing Mix)
-- =============================================================================

SELECT
    RANK() OVER (ORDER BY SUM(fs.revenue) DESC)                         AS rank,
    dts.traffic_source,
    dts.channel_type,
    dts.is_paid,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    COUNT(DISTINCT fs.customer_key)                                     AS customers,
    ROUND(SUM(fs.revenue), 2)                                           AS revenue,
    ROUND(SUM(fs.profit), 2)                                            AS profit,
    ROUND(SUM(fs.discount_amount), 2)                                   AS discounts,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS return_rate_pct,
    ROUND(SUM(fs.revenue) / SUM(SUM(fs.revenue)) OVER () * 100, 2)     AS revenue_share_pct
FROM fact_sales fs
JOIN dim_traffic_source dts ON fs.traffic_source_key = dts.traffic_source_key
GROUP BY dts.traffic_source, dts.channel_type, dts.is_paid
ORDER BY revenue DESC;


-- =============================================================================
-- REPORT 8: QUARTERLY BUSINESS REVIEW (QBR) TABLE
-- Full P&L-style summary by quarter for board presentations
-- =============================================================================

SELECT
    dd.year,
    dd.quarter,
    dd.quarter_label,
    -- Revenue block
    ROUND(SUM(fs.gross_revenue), 2)                                     AS gross_revenue,
    ROUND(SUM(fs.discount_amount), 2)                                   AS less_discounts,
    ROUND(SUM(fs.revenue), 2)                                           AS net_revenue,
    -- Cost block
    ROUND(SUM(fs.shipping_cost), 2)                                     AS shipping_costs,
    -- Profit
    ROUND(SUM(fs.profit), 2)                                            AS operating_profit,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    -- Volume
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    COUNT(DISTINCT fs.customer_key)                                     AS active_customers,
    -- Quality
    ROUND(AVG(fs.rating), 2)                                            AS avg_rating,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS return_rate_pct,
    -- QoQ growth
    ROUND(
        (SUM(fs.revenue) - LAG(SUM(fs.revenue)) OVER (ORDER BY dd.year, dd.quarter))
        / NULLIF(LAG(SUM(fs.revenue)) OVER (ORDER BY dd.year, dd.quarter), 0) * 100, 2
    )                                                                   AS qoq_revenue_growth_pct
FROM fact_sales fs
JOIN dim_date dd ON fs.date_key = dd.date_key
GROUP BY dd.year, dd.quarter, dd.quarter_label
ORDER BY dd.year, dd.quarter;


-- =============================================================================
-- REPORT 9: RETURNS ANALYSIS — What is costing us margin?
-- =============================================================================

SELECT
    dp.product_category,
    COUNT(*)                                                            AS total_orders,
    SUM(fs.is_returned)                                                 AS returned_orders,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS return_rate_pct,
    ROUND(SUM(CASE WHEN fs.is_returned = 1 THEN fs.revenue ELSE 0 END), 2)
                                                                        AS returned_revenue,
    ROUND(SUM(CASE WHEN fs.is_returned = 1 THEN fs.profit  ELSE 0 END), 2)
                                                                        AS returned_profit_lost,
    ROUND(AVG(CASE WHEN fs.is_returned = 1 THEN fs.rating  END), 2)    AS avg_rating_returned,
    ROUND(AVG(CASE WHEN fs.is_returned = 0 THEN fs.rating  END), 2)    AS avg_rating_kept,
    ROUND(AVG(CASE WHEN fs.is_returned = 1 THEN fs.discount_percent END), 2)
                                                                        AS avg_discount_on_returns
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
GROUP BY dp.product_category
ORDER BY return_rate_pct DESC;


-- =============================================================================
-- REPORT 10: PROFIT LEAKAGE ANALYSIS
-- Identifies where the business is losing margin
-- =============================================================================

SELECT
    'High Discount (>30%)' AS leakage_type,
    COUNT(*)               AS affected_orders,
    ROUND(SUM(fs.discount_amount), 2)    AS discount_cost,
    ROUND(SUM(fs.profit), 2)             AS profit_generated,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2) AS margin_pct
FROM fact_sales fs WHERE fs.discount_percent > 30

UNION ALL

SELECT
    'Returns' AS leakage_type,
    SUM(fs.is_returned)::INTEGER AS affected_orders,
    0                            AS discount_cost,
    ROUND(SUM(CASE WHEN fs.is_returned=1 THEN fs.profit ELSE 0 END), 2) AS profit_generated,
    ROUND(
        SUM(CASE WHEN fs.is_returned=1 THEN fs.profit ELSE 0 END)
        / NULLIF(SUM(CASE WHEN fs.is_returned=1 THEN fs.revenue ELSE 0 END), 0) * 100, 2
    )                            AS margin_pct
FROM fact_sales fs

UNION ALL

SELECT
    'Low Rating Orders (<=2.0)' AS leakage_type,
    COUNT(*)                    AS affected_orders,
    ROUND(SUM(fs.discount_amount), 2)    AS discount_cost,
    ROUND(SUM(fs.profit), 2)             AS profit_generated,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2) AS margin_pct
FROM fact_sales fs WHERE fs.rating <= 2.0

ORDER BY profit_generated ASC;
