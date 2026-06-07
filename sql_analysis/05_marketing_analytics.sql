-- =============================================================================
-- FILE: 05_marketing_analytics.sql
-- PROJECT: Shopify E-Commerce Analytics Data Warehouse
-- LAYER: Analytics — Marketing & Channel Intelligence
-- DESCRIPTION: Channel performance, traffic source ROI, conversion proxies
-- =============================================================================

-- =============================================================================
-- SECTION 1: CHANNEL PERFORMANCE OVERVIEW
-- =============================================================================

CREATE OR REPLACE VIEW mkt_channel_performance AS
SELECT
    dts.traffic_source,
    dts.channel_type,
    dts.is_paid,
    COUNT(DISTINCT fs.order_id)                                         AS total_orders,
    COUNT(DISTINCT fs.customer_key)                                     AS unique_customers,
    SUM(fs.quantity)                                                    AS units_sold,
    ROUND(SUM(fs.revenue), 2)                                           AS total_revenue,
    ROUND(SUM(fs.gross_revenue), 2)                                     AS gross_revenue,
    ROUND(SUM(fs.profit), 2)                                            AS total_profit,
    ROUND(SUM(fs.discount_amount), 2)                                   AS total_discounts,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    ROUND(
        SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS return_rate_pct,
    ROUND(AVG(fs.rating), 2)                                            AS avg_rating,
    -- Revenue share
    ROUND(
        SUM(fs.revenue) / SUM(SUM(fs.revenue)) OVER () * 100, 2
    )                                                                   AS revenue_share_pct
FROM fact_sales fs
JOIN dim_traffic_source dts ON fs.traffic_source_key = dts.traffic_source_key
GROUP BY dts.traffic_source, dts.channel_type, dts.is_paid
ORDER BY total_revenue DESC;

COMMENT ON VIEW mkt_channel_performance IS
    'Full channel performance scorecard. revenue_share_pct shows channel mix.
     Compare profit_margin_pct across channels to find most efficient acquisition.';


-- =============================================================================
-- SECTION 2: CHANNEL PERFORMANCE BY MONTH (Trend)
-- =============================================================================

CREATE OR REPLACE VIEW mkt_channel_monthly_trend AS
SELECT
    dd.year,
    dd.month,
    dd.month_label,
    dts.traffic_source,
    dts.channel_type,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    ROUND(SUM(fs.revenue), 2)                                           AS revenue,
    ROUND(SUM(fs.profit), 2)                                            AS profit,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct
FROM fact_sales fs
JOIN dim_date           dd  ON fs.date_key          = dd.date_key
JOIN dim_traffic_source dts ON fs.traffic_source_key = dts.traffic_source_key
GROUP BY dd.year, dd.month, dd.month_label, dts.traffic_source, dts.channel_type
ORDER BY dd.year, dd.month, revenue DESC;


-- =============================================================================
-- SECTION 3: CHANNEL × CATEGORY CROSS ANALYSIS
-- Identifies which channels drive which product categories
-- =============================================================================

CREATE OR REPLACE VIEW mkt_channel_category_matrix AS
SELECT
    dts.traffic_source,
    dp.product_category,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    ROUND(SUM(fs.revenue), 2)                                           AS revenue,
    ROUND(SUM(fs.profit), 2)                                            AS profit,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct,
    ROUND(AVG(fs.discount_percent), 2)                                  AS avg_discount_pct
FROM fact_sales fs
JOIN dim_traffic_source dts ON fs.traffic_source_key = dts.traffic_source_key
JOIN dim_product         dp  ON fs.product_key        = dp.product_key
GROUP BY dts.traffic_source, dp.product_category
ORDER BY revenue DESC;


-- =============================================================================
-- SECTION 4: CHANNEL × COUNTRY CROSS ANALYSIS
-- =============================================================================

CREATE OR REPLACE VIEW mkt_channel_country_matrix AS
SELECT
    dts.traffic_source,
    dc.country_name,
    dc.region,
    COUNT(DISTINCT fs.order_id)                                         AS orders,
    ROUND(SUM(fs.revenue), 2)                                           AS revenue,
    ROUND(SUM(fs.profit), 2)                                            AS profit,
    ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov
FROM fact_sales fs
JOIN dim_traffic_source dts ON fs.traffic_source_key = dts.traffic_source_key
JOIN dim_country         dc  ON fs.country_key        = dc.country_key
GROUP BY dts.traffic_source, dc.country_name, dc.region
ORDER BY revenue DESC;


-- =============================================================================
-- SECTION 5: NEW vs RETURNING CUSTOMER ACQUISITION BY CHANNEL
-- New = first ever order | Returning = subsequent orders
-- =============================================================================

CREATE OR REPLACE VIEW mkt_channel_new_vs_returning AS
WITH customer_first_order AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date
    FROM raw_shopify_sales
    GROUP BY customer_id
),
order_type AS (
    SELECT
        r.order_id,
        r.customer_id,
        r.order_date,
        r.traffic_source,
        r.revenue,
        r.profit,
        CASE
            WHEN r.order_date = cfo.first_order_date THEN 'New Customer'
            ELSE 'Returning Customer'
        END AS customer_type
    FROM raw_shopify_sales r
    JOIN customer_first_order cfo ON r.customer_id = cfo.customer_id
)
SELECT
    traffic_source,
    customer_type,
    COUNT(DISTINCT order_id)                                            AS orders,
    COUNT(DISTINCT customer_id)                                         AS customers,
    ROUND(SUM(revenue), 2)                                              AS revenue,
    ROUND(SUM(profit), 2)                                               AS profit,
    ROUND(SUM(revenue) / NULLIF(COUNT(DISTINCT order_id), 0), 2)       AS aov,
    ROUND(SUM(revenue)::NUMERIC / SUM(SUM(revenue)) OVER (
        PARTITION BY traffic_source
    ) * 100, 2)                                                         AS pct_channel_revenue
FROM order_type
GROUP BY traffic_source, customer_type
ORDER BY traffic_source, customer_type;

COMMENT ON VIEW mkt_channel_new_vs_returning IS
    'Shows whether each channel acquires new customers or re-engages existing ones.
     Channels with high "New Customer" share are top-of-funnel.
     Channels with high "Returning" share are retention/loyalty drivers.';


-- =============================================================================
-- SECTION 6: CHANNEL EFFICIENCY RANKING
-- Combines multiple metrics into a channel score
-- =============================================================================

CREATE OR REPLACE VIEW mkt_channel_efficiency_ranking AS
WITH base AS (
    SELECT
        dts.traffic_source,
        dts.is_paid,
        ROUND(SUM(fs.revenue), 2)                                       AS revenue,
        ROUND(SUM(fs.profit), 2)                                        AS profit,
        ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)    AS margin_pct,
        ROUND(SUM(fs.revenue) / NULLIF(COUNT(DISTINCT fs.order_id), 0), 2) AS aov,
        ROUND(
            SUM(fs.is_returned)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
        )                                                               AS return_rate_pct,
        ROUND(AVG(fs.discount_percent), 2)                              AS avg_discount_pct
    FROM fact_sales fs
    JOIN dim_traffic_source dts ON fs.traffic_source_key = dts.traffic_source_key
    GROUP BY dts.traffic_source, dts.is_paid
)
SELECT
    traffic_source,
    is_paid,
    revenue,
    profit,
    margin_pct,
    aov,
    return_rate_pct,
    avg_discount_pct,
    -- Efficiency rank (by profit margin, lower return rate preferred)
    RANK() OVER (ORDER BY margin_pct DESC)          AS margin_rank,
    RANK() OVER (ORDER BY aov DESC)                 AS aov_rank,
    RANK() OVER (ORDER BY return_rate_pct ASC)      AS return_rank,
    RANK() OVER (ORDER BY profit DESC)              AS profit_rank
FROM base
ORDER BY profit DESC;


-- =============================================================================
-- SECTION 7: DISCOUNT USAGE BY CHANNEL
-- Are paid channels over-discounting to drive volume?
-- =============================================================================

CREATE OR REPLACE VIEW mkt_channel_discount_analysis AS
SELECT
    dts.traffic_source,
    dts.is_paid,
    COUNT(*)                                                            AS total_orders,
    SUM(CASE WHEN fs.discount_percent > 0 THEN 1 ELSE 0 END)          AS discounted_orders,
    ROUND(
        SUM(CASE WHEN fs.discount_percent > 0 THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                   AS discount_usage_rate_pct,
    ROUND(AVG(CASE WHEN fs.discount_percent > 0 THEN fs.discount_percent END), 2)
                                                                        AS avg_discount_when_applied,
    ROUND(SUM(fs.discount_amount), 2)                                   AS total_discount_cost,
    ROUND(SUM(fs.profit), 2)                                            AS total_profit,
    ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2)        AS profit_margin_pct
FROM fact_sales fs
JOIN dim_traffic_source dts ON fs.traffic_source_key = dts.traffic_source_key
GROUP BY dts.traffic_source, dts.is_paid
ORDER BY total_discount_cost DESC;
