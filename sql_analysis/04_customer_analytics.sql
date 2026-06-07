-- =============================================================================
-- FILE: 04_customer_analytics.sql
-- PROJECT: Shopify E-Commerce Analytics Data Warehouse
-- LAYER: Analytics — Customer Intelligence
-- DESCRIPTION: CLV, RFM Segmentation, Repeat Purchase, Revenue Contribution
-- =============================================================================

-- =============================================================================
-- SECTION 1: RFM BASE METRICS
-- RFM = Recency, Frequency, Monetary
-- Industry-standard customer segmentation framework
-- =============================================================================

CREATE OR REPLACE VIEW rfm_base AS
WITH snapshot_date AS (
    -- Use max order date + 1 day as analysis snapshot date
    SELECT MAX(order_date) + INTERVAL '1 day' AS snapshot_dt
    FROM raw_shopify_sales
),
rfm_raw AS (
    SELECT
        r.customer_id,
        dc.customer_key,
        dc.customer_country,
        -- Recency: days since last purchase
        (SELECT snapshot_dt FROM snapshot_date) - MAX(r.order_date)    AS recency_days,
        -- Frequency: number of distinct orders
        COUNT(DISTINCT r.order_id)                                      AS frequency,
        -- Monetary: total net revenue
        ROUND(SUM(r.revenue), 2)                                        AS monetary
    FROM raw_shopify_sales r
    JOIN dim_customer dc ON r.customer_id = dc.customer_id
    GROUP BY r.customer_id, dc.customer_key, dc.customer_country
)
SELECT
    customer_id,
    customer_key,
    customer_country,
    recency_days,
    frequency,
    monetary,
    -- RFM Scores: 5 = best, 1 = worst (quintile-based scoring)
    NTILE(5) OVER (ORDER BY recency_days ASC)  AS r_score,   -- Lower recency = better
    NTILE(5) OVER (ORDER BY frequency   DESC)  AS f_score,   -- Higher frequency = better
    NTILE(5) OVER (ORDER BY monetary    DESC)  AS m_score    -- Higher monetary = better
FROM rfm_raw;

COMMENT ON VIEW rfm_base IS
    'RFM base layer. Each customer scored 1–5 on Recency, Frequency, Monetary.
     Recency scored inversely (fewer days = score 5). Join to rfm_segments for labels.';


-- =============================================================================
-- SECTION 2: RFM SEGMENTATION
-- Segment definitions aligned with industry standard (Klaviyo / HubSpot model)
-- =============================================================================

CREATE OR REPLACE VIEW rfm_segments AS
SELECT
    customer_id,
    customer_key,
    customer_country,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    -- Composite RFM score (simple average × 100 for readability)
    ROUND((r_score + f_score + m_score)::NUMERIC / 3, 2)    AS rfm_composite_score,
    -- Concatenated score string for pattern matching
    CONCAT(r_score, f_score, m_score)                       AS rfm_cell,
    -- Segment logic
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
            THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3
            THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2
            THEN 'Potential Loyalists'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score <= 2
            THEN 'Promising'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3
            THEN 'At Risk'
        WHEN r_score = 1 AND f_score >= 2
            THEN 'Lost Customers'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2
            THEN 'Hibernating'
        ELSE 'Need Attention'
    END                                                     AS customer_segment
FROM rfm_base;

COMMENT ON VIEW rfm_segments IS
    'RFM segmented customer base. Use for targeted marketing campaigns and
     retention strategy execution. Segments: Champions, Loyal, Potential Loyalists,
     Promising, At Risk, Lost Customers, Hibernating, Need Attention.';


-- =============================================================================
-- SECTION 3: SEGMENT SUMMARY (for executive reporting)
-- =============================================================================

CREATE OR REPLACE VIEW rfm_segment_summary AS
SELECT
    customer_segment,
    COUNT(*)                                                AS customer_count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2)
                                                            AS pct_of_customers,
    ROUND(AVG(monetary), 2)                                 AS avg_monetary_value,
    ROUND(SUM(monetary), 2)                                 AS total_segment_revenue,
    ROUND(SUM(monetary)::NUMERIC / SUM(SUM(monetary)) OVER () * 100, 2)
                                                            AS pct_of_revenue,
    ROUND(AVG(frequency), 2)                                AS avg_frequency,
    ROUND(AVG(recency_days::NUMERIC), 1)                    AS avg_recency_days
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;


-- =============================================================================
-- SECTION 4: CUSTOMER LIFETIME VALUE (CLV)
-- Model: Historical CLV = Total Revenue per Customer
-- Predictive proxy: Avg Order Value × Purchase Frequency × Estimated Lifespan
-- =============================================================================

CREATE OR REPLACE VIEW customer_clv AS
WITH customer_orders AS (
    SELECT
        r.customer_id,
        COUNT(DISTINCT r.order_id)              AS total_orders,
        SUM(r.revenue)                          AS total_revenue,
        SUM(r.profit)                           AS total_profit,
        MIN(r.order_date)                       AS first_order_date,
        MAX(r.order_date)                       AS last_order_date,
        MAX(r.order_date) - MIN(r.order_date)   AS customer_lifespan_days,
        AVG(r.revenue)                          AS avg_order_value,
        AVG(r.profit)                           AS avg_profit_per_order
    FROM raw_shopify_sales r
    GROUP BY r.customer_id
)
SELECT
    co.customer_id,
    dc.customer_country,
    co.total_orders,
    ROUND(co.total_revenue, 2)                  AS historical_clv,
    ROUND(co.total_profit, 2)                   AS total_profit,
    ROUND(co.avg_order_value, 2)                AS avg_order_value,
    co.first_order_date,
    co.last_order_date,
    co.customer_lifespan_days,
    -- Annualized purchase frequency (orders per year)
    ROUND(
        co.total_orders::NUMERIC
        / NULLIF(co.customer_lifespan_days, 0) * 365, 2
    )                                           AS annual_purchase_frequency,
    -- Predictive CLV proxy (3-year horizon)
    ROUND(
        co.avg_order_value
        * GREATEST(co.total_orders::NUMERIC / NULLIF(co.customer_lifespan_days, 0) * 365, 1)
        * 3, 2
    )                                           AS clv_3yr_projection,
    -- CLV tier
    CASE
        WHEN co.total_revenue >= 10000  THEN 'Platinum'
        WHEN co.total_revenue >= 5000   THEN 'Gold'
        WHEN co.total_revenue >= 1000   THEN 'Silver'
        ELSE 'Bronze'
    END                                         AS clv_tier,
    rs.customer_segment                         AS rfm_segment
FROM customer_orders co
JOIN dim_customer dc     ON co.customer_id = dc.customer_id
JOIN rfm_segments rs     ON co.customer_id = rs.customer_id
ORDER BY historical_clv DESC;

COMMENT ON VIEW customer_clv IS
    'Customer Lifetime Value model. historical_clv = sum of all revenue.
     clv_3yr_projection = forward-looking estimate using purchase velocity.
     Join to rfm_segments for behavioral context.';


-- =============================================================================
-- SECTION 5: TOP CUSTOMERS
-- =============================================================================

CREATE OR REPLACE VIEW top_customers AS
SELECT
    clv.customer_id,
    clv.customer_country,
    clv.total_orders,
    clv.historical_clv,
    clv.total_profit,
    clv.avg_order_value,
    clv.clv_tier,
    clv.rfm_segment,
    -- Revenue rank
    RANK() OVER (ORDER BY clv.historical_clv DESC)          AS revenue_rank,
    -- Cumulative revenue contribution
    ROUND(
        SUM(clv.historical_clv) OVER (ORDER BY clv.historical_clv DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / SUM(clv.historical_clv) OVER () * 100, 2
    )                                                       AS cumulative_revenue_pct
FROM customer_clv clv;


-- =============================================================================
-- SECTION 6: PARETO (80/20) ANALYSIS
-- Identify what % of customers drive 80% of revenue
-- =============================================================================

CREATE OR REPLACE VIEW customer_pareto AS
WITH ranked AS (
    SELECT
        customer_id,
        historical_clv,
        RANK() OVER (ORDER BY historical_clv DESC)          AS revenue_rank,
        COUNT(*) OVER ()                                    AS total_customers,
        SUM(historical_clv) OVER ()                         AS total_revenue
    FROM customer_clv
),
cumulative AS (
    SELECT
        customer_id,
        historical_clv,
        revenue_rank,
        total_customers,
        total_revenue,
        SUM(historical_clv) OVER (ORDER BY revenue_rank
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                            AS cumulative_revenue,
        ROUND(revenue_rank::NUMERIC / total_customers * 100, 2)
                                                            AS customer_percentile,
        ROUND(
            SUM(historical_clv) OVER (ORDER BY revenue_rank
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / total_revenue * 100, 2
        )                                                   AS cumulative_revenue_pct
    FROM ranked
)
SELECT
    customer_id,
    historical_clv,
    revenue_rank,
    customer_percentile,
    cumulative_revenue_pct,
    CASE WHEN cumulative_revenue_pct <= 80 THEN 'Top 80% Revenue' ELSE 'Bottom 20% Revenue' END
                                                            AS pareto_group
FROM cumulative;


-- =============================================================================
-- SECTION 7: REPEAT PURCHASE BEHAVIOR
-- =============================================================================

CREATE OR REPLACE VIEW repeat_purchase_analysis AS
SELECT
    is_repeat_customer,
    COUNT(*)                                                AS customer_count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2)
                                                            AS pct_of_customers,
    ROUND(AVG(total_revenue), 2)                            AS avg_revenue_per_customer,
    ROUND(AVG(avg_order_value), 2)                          AS avg_order_value,
    ROUND(SUM(total_revenue), 2)                            AS total_revenue_contribution,
    ROUND(SUM(total_revenue)::NUMERIC / SUM(SUM(total_revenue)) OVER () * 100, 2)
                                                            AS pct_of_total_revenue
FROM dim_customer
GROUP BY is_repeat_customer;


-- =============================================================================
-- SECTION 8: COHORT RETENTION ANALYSIS
-- Cohort = Month of first purchase; tracks re-purchase in subsequent months
-- =============================================================================

CREATE OR REPLACE VIEW cohort_retention AS
WITH cohort_base AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::DATE          AS cohort_month
    FROM raw_shopify_sales
    GROUP BY customer_id
),
order_months AS (
    SELECT
        r.customer_id,
        DATE_TRUNC('month', r.order_date)::DATE             AS order_month
    FROM raw_shopify_sales r
),
cohort_data AS (
    SELECT
        cb.cohort_month,
        om.order_month,
        EXTRACT(
            YEAR FROM AGE(om.order_month, cb.cohort_month)
        ) * 12 +
        EXTRACT(
            MONTH FROM AGE(om.order_month, cb.cohort_month)
        )                                                   AS period_number,
        COUNT(DISTINCT om.customer_id)                      AS customers
    FROM cohort_base cb
    JOIN order_months om ON cb.customer_id = om.customer_id
    GROUP BY cb.cohort_month, om.order_month
)
SELECT
    cohort_month,
    period_number,
    customers,
    FIRST_VALUE(customers) OVER (
        PARTITION BY cohort_month
        ORDER BY period_number
    )                                                       AS cohort_size,
    ROUND(
        customers::NUMERIC /
        FIRST_VALUE(customers) OVER (
            PARTITION BY cohort_month ORDER BY period_number
        ) * 100, 2
    )                                                       AS retention_rate_pct
FROM cohort_data
ORDER BY cohort_month, period_number;

COMMENT ON VIEW cohort_retention IS
    'Monthly cohort retention. period_number=0 is the acquisition month.
     retention_rate_pct = customers active in period / cohort size.
     Use to identify how long acquired customers remain active.';
