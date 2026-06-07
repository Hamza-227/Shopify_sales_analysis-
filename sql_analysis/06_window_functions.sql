-- =============================================================================
-- FILE: 06_window_functions.sql
-- PROJECT: Shopify E-Commerce Analytics Data Warehouse
-- LAYER: Analytics — Advanced SQL (Window Functions)
-- DESCRIPTION: Enterprise-grade analytical queries using window functions
--              for ranking, trending, growth, and comparative analysis
-- =============================================================================

-- =============================================================================
-- SECTION 1: ROW_NUMBER() — Deduplicate & Rank within partitions
-- Business use: Identify the single best product per category
-- =============================================================================

-- Top product by revenue within each category (no ties)
SELECT
    dp.product_category,
    fs.product_key,
    dp.product_id,
    ROUND(SUM(fs.revenue), 2)                           AS category_revenue,
    ROUND(SUM(fs.profit), 2)                            AS category_profit,
    ROW_NUMBER() OVER (
        PARTITION BY dp.product_category
        ORDER BY SUM(fs.revenue) DESC
    )                                                   AS row_num_in_category
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
GROUP BY dp.product_category, fs.product_key, dp.product_id
ORDER BY dp.product_category, row_num_in_category;

-- Use as subquery to extract rank-1 products only:
-- SELECT * FROM (...) t WHERE row_num_in_category = 1;


-- =============================================================================
-- SECTION 2: RANK() & DENSE_RANK() — Revenue Rankings
-- Business use: Customer revenue leaderboard (with tie handling)
-- RANK() skips numbers on ties; DENSE_RANK() does not
-- =============================================================================

SELECT
    dc.customer_id,
    dc.customer_country,
    ROUND(SUM(fs.revenue), 2)                           AS total_revenue,
    ROUND(SUM(fs.profit), 2)                            AS total_profit,
    COUNT(DISTINCT fs.order_id)                         AS orders,
    -- RANK: gaps after ties (e.g., 1,1,3,4)
    RANK() OVER (
        ORDER BY SUM(fs.revenue) DESC
    )                                                   AS revenue_rank,
    -- DENSE_RANK: no gaps (e.g., 1,1,2,3)
    DENSE_RANK() OVER (
        ORDER BY SUM(fs.revenue) DESC
    )                                                   AS revenue_dense_rank,
    -- Rank within country
    RANK() OVER (
        PARTITION BY dc.customer_country
        ORDER BY SUM(fs.revenue) DESC
    )                                                   AS country_revenue_rank
FROM fact_sales fs
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_id, dc.customer_country
ORDER BY revenue_rank
LIMIT 50;


-- =============================================================================
-- SECTION 3: LAG() — Period-over-Period Comparison
-- Business use: Month-over-month revenue growth
-- =============================================================================

WITH monthly_revenue AS (
    SELECT
        dd.year,
        dd.month,
        dd.month_label,
        ROUND(SUM(fs.revenue), 2)                       AS revenue,
        ROUND(SUM(fs.profit), 2)                        AS profit,
        COUNT(DISTINCT fs.order_id)                     AS orders
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    GROUP BY dd.year, dd.month, dd.month_label
)
SELECT
    year,
    month,
    month_label,
    revenue,
    profit,
    orders,
    -- Previous month revenue
    LAG(revenue, 1) OVER (ORDER BY year, month)         AS prev_month_revenue,
    -- Month-over-Month Revenue Change ($)
    ROUND(
        revenue - LAG(revenue, 1) OVER (ORDER BY year, month), 2
    )                                                   AS mom_revenue_change,
    -- Month-over-Month Revenue Growth (%)
    ROUND(
        (revenue - LAG(revenue, 1) OVER (ORDER BY year, month))
        / NULLIF(LAG(revenue, 1) OVER (ORDER BY year, month), 0) * 100, 2
    )                                                   AS mom_revenue_growth_pct,
    -- Previous year same month (YoY)
    LAG(revenue, 12) OVER (ORDER BY year, month)        AS prev_year_same_month_revenue,
    ROUND(
        (revenue - LAG(revenue, 12) OVER (ORDER BY year, month))
        / NULLIF(LAG(revenue, 12) OVER (ORDER BY year, month), 0) * 100, 2
    )                                                   AS yoy_revenue_growth_pct
FROM monthly_revenue
ORDER BY year, month;


-- =============================================================================
-- SECTION 4: LEAD() — Forward-Looking Analysis
-- Business use: Compare each month's revenue to the NEXT month
-- Useful for identifying seasonal acceleration/deceleration
-- =============================================================================

WITH monthly AS (
    SELECT
        dd.year,
        dd.month,
        dd.month_label,
        ROUND(SUM(fs.revenue), 2)                       AS revenue
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    GROUP BY dd.year, dd.month, dd.month_label
)
SELECT
    year,
    month,
    month_label,
    revenue                                             AS current_revenue,
    LEAD(revenue, 1) OVER (ORDER BY year, month)        AS next_month_revenue,
    -- Revenue gap: current vs next (positive = about to decline)
    ROUND(
        revenue - LEAD(revenue, 1) OVER (ORDER BY year, month), 2
    )                                                   AS revenue_gap_to_next,
    -- Forecast signal
    CASE
        WHEN LEAD(revenue, 1) OVER (ORDER BY year, month) > revenue
            THEN 'Upward trend expected'
        WHEN LEAD(revenue, 1) OVER (ORDER BY year, month) < revenue
            THEN 'Downward trend expected'
        ELSE 'Flat'
    END                                                 AS trend_signal
FROM monthly
ORDER BY year, month;


-- =============================================================================
-- SECTION 5: SUM() OVER() — Running Totals & Cumulative Analysis
-- Business use: Cumulative revenue to track annual targets
-- =============================================================================

WITH monthly AS (
    SELECT
        dd.year,
        dd.month,
        dd.month_label,
        ROUND(SUM(fs.revenue), 2)                       AS monthly_revenue,
        ROUND(SUM(fs.profit), 2)                        AS monthly_profit
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    GROUP BY dd.year, dd.month, dd.month_label
)
SELECT
    year,
    month,
    month_label,
    monthly_revenue,
    monthly_profit,
    -- Cumulative revenue within the same year
    SUM(monthly_revenue) OVER (
        PARTITION BY year
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                   AS ytd_revenue,
    -- Cumulative profit within the same year
    SUM(monthly_profit) OVER (
        PARTITION BY year
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                   AS ytd_profit,
    -- Cumulative revenue across all time
    SUM(monthly_revenue) OVER (
        ORDER BY year, month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                   AS all_time_cumulative_revenue,
    -- YTD Revenue as % of full year total
    ROUND(
        SUM(monthly_revenue) OVER (
            PARTITION BY year
            ORDER BY month
        ) / SUM(monthly_revenue) OVER (PARTITION BY year) * 100, 2
    )                                                   AS ytd_pct_of_annual
FROM monthly
ORDER BY year, month;


-- =============================================================================
-- SECTION 6: AVG() OVER() — Moving Averages
-- Business use: Smooth out revenue volatility with 3-month rolling average
-- =============================================================================

WITH monthly AS (
    SELECT
        dd.year,
        dd.month,
        dd.month_label,
        ROUND(SUM(fs.revenue), 2)                       AS monthly_revenue,
        ROUND(SUM(fs.profit), 2)                        AS monthly_profit
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    GROUP BY dd.year, dd.month, dd.month_label
)
SELECT
    year,
    month,
    month_label,
    monthly_revenue,
    monthly_profit,
    -- 3-month rolling average revenue
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY year, month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                               AS rolling_3m_avg_revenue,
    -- 3-month rolling average profit
    ROUND(AVG(monthly_profit) OVER (
        ORDER BY year, month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                               AS rolling_3m_avg_profit,
    -- Full-window average (benchmark)
    ROUND(AVG(monthly_revenue) OVER (), 2)              AS overall_avg_monthly_revenue,
    -- Is this month above or below long-run average?
    CASE
        WHEN monthly_revenue > AVG(monthly_revenue) OVER ()
            THEN 'Above Average'
        ELSE 'Below Average'
    END                                                 AS vs_avg_signal
FROM monthly
ORDER BY year, month;


-- =============================================================================
-- SECTION 7: PERCENT_RANK() & NTILE() — Distribution Analysis
-- Business use: Categorize products into performance quartiles
-- =============================================================================

WITH product_revenue AS (
    SELECT
        dp.product_id,
        dp.product_category,
        ROUND(SUM(fs.revenue), 2)                       AS total_revenue,
        ROUND(SUM(fs.profit), 2)                        AS total_profit,
        ROUND(SUM(fs.profit) / NULLIF(SUM(fs.revenue), 0) * 100, 2) AS margin_pct,
        COUNT(DISTINCT fs.order_id)                     AS orders
    FROM fact_sales fs
    JOIN dim_product dp ON fs.product_key = dp.product_key
    GROUP BY dp.product_id, dp.product_category
)
SELECT
    product_id,
    product_category,
    total_revenue,
    total_profit,
    margin_pct,
    orders,
    -- Percentile rank among all products (0.0 to 1.0)
    ROUND(PERCENT_RANK() OVER (ORDER BY total_revenue DESC)::NUMERIC, 4)
                                                        AS revenue_percent_rank,
    -- Revenue quartile (1=top 25%, 4=bottom 25%)
    NTILE(4) OVER (ORDER BY total_revenue DESC)         AS revenue_quartile,
    -- Margin quartile
    NTILE(4) OVER (ORDER BY margin_pct DESC)            AS margin_quartile,
    -- Label
    CASE NTILE(4) OVER (ORDER BY total_revenue DESC)
        WHEN 1 THEN 'Top Performer'
        WHEN 2 THEN 'Strong Performer'
        WHEN 3 THEN 'Average Performer'
        WHEN 4 THEN 'Underperformer'
    END                                                 AS performance_tier
FROM product_revenue
ORDER BY total_revenue DESC;


-- =============================================================================
-- SECTION 8: FIRST_VALUE() / LAST_VALUE() — Baseline Comparisons
-- Business use: Compare each month's performance to Jan of the same year
-- =============================================================================

WITH monthly AS (
    SELECT
        dd.year,
        dd.month,
        dd.month_label,
        ROUND(SUM(fs.revenue), 2)                       AS revenue
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    GROUP BY dd.year, dd.month, dd.month_label
)
SELECT
    year,
    month,
    month_label,
    revenue,
    -- First month of year (baseline)
    FIRST_VALUE(revenue) OVER (
        PARTITION BY year ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                                   AS year_start_revenue,
    -- Last recorded month of year
    LAST_VALUE(revenue) OVER (
        PARTITION BY year ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                                   AS year_end_revenue,
    -- Growth vs year start
    ROUND(
        (revenue - FIRST_VALUE(revenue) OVER (
            PARTITION BY year ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )) / NULLIF(FIRST_VALUE(revenue) OVER (
            PARTITION BY year ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ), 0) * 100, 2
    )                                                   AS growth_vs_year_start_pct
FROM monthly
ORDER BY year, month;
