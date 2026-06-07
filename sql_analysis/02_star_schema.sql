-- =============================================================================
-- FILE: 02_star_schema.sql
-- PROJECT: Shopify E-Commerce Analytics Data Warehouse
-- LAYER: Data Warehouse (Star Schema)
-- DESCRIPTION: Dimensional model — fact and dimension table definitions
-- GRAIN: fact_sales → one row per order_id (single product per order)
-- =============================================================================

-- =============================================================================
-- DIMENSION: dim_date
-- Type: Static / Pre-populated date spine
-- =============================================================================

DROP TABLE IF EXISTS dim_date CASCADE;

CREATE TABLE dim_date (
    date_key            INTEGER         NOT NULL,   -- Surrogate key: YYYYMMDD
    full_date           DATE            NOT NULL,
    year                SMALLINT        NOT NULL,
    quarter             SMALLINT        NOT NULL,   -- 1-4
    quarter_label       VARCHAR(6)      NOT NULL,   -- e.g., 'Q1 2023'
    month               SMALLINT        NOT NULL,   -- 1-12
    month_name          VARCHAR(10)     NOT NULL,
    month_label         VARCHAR(8)      NOT NULL,   -- e.g., 'Jan 2023'
    week_of_year        SMALLINT        NOT NULL,
    day_of_month        SMALLINT        NOT NULL,
    day_of_week         SMALLINT        NOT NULL,   -- 1=Sunday, 7=Saturday
    day_name            VARCHAR(10)     NOT NULL,
    is_weekend          BOOLEAN         NOT NULL,
    is_weekday          BOOLEAN         NOT NULL,
    fiscal_year         SMALLINT,
    fiscal_quarter      SMALLINT,

    CONSTRAINT pk_dim_date PRIMARY KEY (date_key)
);

-- Populate dim_date with the full range of the dataset (2023-2025)
INSERT INTO dim_date (
    date_key, full_date, year, quarter, quarter_label,
    month, month_name, month_label, week_of_year,
    day_of_month, day_of_week, day_name, is_weekend, is_weekday,
    fiscal_year, fiscal_quarter
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER                         AS date_key,
    d                                                       AS full_date,
    EXTRACT(YEAR FROM d)::SMALLINT                         AS year,
    EXTRACT(QUARTER FROM d)::SMALLINT                      AS quarter,
    'Q' || EXTRACT(QUARTER FROM d) || ' ' || EXTRACT(YEAR FROM d) AS quarter_label,
    EXTRACT(MONTH FROM d)::SMALLINT                        AS month,
    TO_CHAR(d, 'Month')                                    AS month_name,
    TO_CHAR(d, 'Mon YYYY')                                 AS month_label,
    EXTRACT(WEEK FROM d)::SMALLINT                         AS week_of_year,
    EXTRACT(DAY FROM d)::SMALLINT                          AS day_of_month,
    EXTRACT(DOW FROM d)::SMALLINT + 1                      AS day_of_week,
    TO_CHAR(d, 'Day')                                      AS day_name,
    EXTRACT(DOW FROM d) IN (0, 6)                          AS is_weekend,
    EXTRACT(DOW FROM d) NOT IN (0, 6)                      AS is_weekday,
    CASE
        WHEN EXTRACT(MONTH FROM d) >= 4
        THEN EXTRACT(YEAR FROM d)::SMALLINT
        ELSE (EXTRACT(YEAR FROM d) - 1)::SMALLINT
    END                                                     AS fiscal_year,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (4,5,6)   THEN 1
        WHEN EXTRACT(MONTH FROM d) IN (7,8,9)   THEN 2
        WHEN EXTRACT(MONTH FROM d) IN (10,11,12) THEN 3
        ELSE 4
    END                                                     AS fiscal_quarter
FROM GENERATE_SERIES('2023-01-01'::DATE, '2025-12-31'::DATE, '1 day') AS g(d);

CREATE INDEX idx_dim_date_year       ON dim_date(year);
CREATE INDEX idx_dim_date_month      ON dim_date(year, month);
CREATE INDEX idx_dim_date_quarter    ON dim_date(year, quarter);
COMMENT ON TABLE dim_date IS 'Date dimension. Grain: one row per calendar day. Pre-populated 2023–2025.';


-- =============================================================================
-- DIMENSION: dim_customer
-- Type: Slowly Changing Dimension (Type 1 — overwrite)
-- =============================================================================

DROP TABLE IF EXISTS dim_customer CASCADE;

CREATE TABLE dim_customer (
    customer_key        SERIAL          NOT NULL,   -- Surrogate key
    customer_id         INTEGER         NOT NULL,   -- Natural key from Shopify
    customer_country    VARCHAR(100)    NOT NULL,
    first_order_date    DATE,
    last_order_date     DATE,
    total_orders        INTEGER         DEFAULT 0,
    total_revenue       NUMERIC(14, 2)  DEFAULT 0,
    total_profit        NUMERIC(14, 2)  DEFAULT 0,
    avg_order_value     NUMERIC(10, 2)  DEFAULT 0,
    is_repeat_customer  BOOLEAN         DEFAULT FALSE,
    customer_segment    VARCHAR(50),    -- Populated by RFM analysis
    _created_at         TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    _updated_at         TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_dim_customer      PRIMARY KEY (customer_key),
    CONSTRAINT uq_dim_customer_id   UNIQUE (customer_id)
);

INSERT INTO dim_customer (
    customer_id, customer_country,
    first_order_date, last_order_date,
    total_orders, total_revenue, total_profit,
    avg_order_value, is_repeat_customer
)
SELECT
    customer_id,
    -- Take the country from the most recent order (SCD Type 1)
    (ARRAY_AGG(customer_country ORDER BY order_date DESC))[1]   AS customer_country,
    MIN(order_date)                                              AS first_order_date,
    MAX(order_date)                                             AS last_order_date,
    COUNT(DISTINCT order_id)                                    AS total_orders,
    SUM(revenue)                                                AS total_revenue,
    SUM(profit)                                                 AS total_profit,
    ROUND(SUM(revenue) / COUNT(DISTINCT order_id), 2)           AS avg_order_value,
    COUNT(DISTINCT order_id) > 1                                AS is_repeat_customer
FROM raw_shopify_sales
GROUP BY customer_id;

CREATE INDEX idx_dim_customer_id      ON dim_customer(customer_id);
CREATE INDEX idx_dim_customer_country ON dim_customer(customer_country);
COMMENT ON TABLE dim_customer IS 'Customer dimension. Grain: one row per unique customer. Aggregated profile attributes from transaction history.';


-- =============================================================================
-- DIMENSION: dim_product
-- Type: Slowly Changing Dimension (Type 1)
-- =============================================================================

DROP TABLE IF EXISTS dim_product CASCADE;

CREATE TABLE dim_product (
    product_key         SERIAL          NOT NULL,   -- Surrogate key
    product_id          INTEGER         NOT NULL,   -- Natural key
    product_category    VARCHAR(100)    NOT NULL,
    avg_list_price      NUMERIC(10, 2),
    avg_discount_pct    NUMERIC(5, 2),
    total_units_sold    INTEGER         DEFAULT 0,
    total_revenue       NUMERIC(14, 2)  DEFAULT 0,
    total_profit        NUMERIC(14, 2)  DEFAULT 0,
    return_rate         NUMERIC(5, 4)   DEFAULT 0,  -- e.g., 0.0520 = 5.20%
    avg_rating          NUMERIC(3, 2),
    _created_at         TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_dim_product       PRIMARY KEY (product_key),
    CONSTRAINT uq_dim_product_id    UNIQUE (product_id)
);

INSERT INTO dim_product (
    product_id, product_category,
    avg_list_price, avg_discount_pct,
    total_units_sold, total_revenue, total_profit,
    return_rate, avg_rating
)
SELECT
    product_id,
    product_category,
    ROUND(AVG(product_price), 2)                                AS avg_list_price,
    ROUND(AVG(discount_percent), 2)                             AS avg_discount_pct,
    SUM(quantity)                                               AS total_units_sold,
    SUM(revenue)                                                AS total_revenue,
    SUM(profit)                                                 AS total_profit,
    ROUND(SUM(is_returned)::NUMERIC / COUNT(*), 4)              AS return_rate,
    ROUND(AVG(rating), 2)                                       AS avg_rating
FROM raw_shopify_sales
GROUP BY product_id, product_category;

CREATE INDEX idx_dim_product_id       ON dim_product(product_id);
CREATE INDEX idx_dim_product_category ON dim_product(product_category);
COMMENT ON TABLE dim_product IS 'Product dimension. Grain: one row per unique product_id.';


-- =============================================================================
-- DIMENSION: dim_country
-- =============================================================================

DROP TABLE IF EXISTS dim_country CASCADE;

CREATE TABLE dim_country (
    country_key         SERIAL          NOT NULL,
    country_name        VARCHAR(100)    NOT NULL,
    region              VARCHAR(50),    -- Manually mapped
    currency_code       VARCHAR(5),

    CONSTRAINT pk_dim_country       PRIMARY KEY (country_key),
    CONSTRAINT uq_dim_country_name  UNIQUE (country_name)
);

INSERT INTO dim_country (country_name, region, currency_code)
SELECT DISTINCT
    customer_country,
    CASE customer_country
        WHEN 'USA'     THEN 'North America'
        WHEN 'Canada'  THEN 'North America'
        WHEN 'UK'      THEN 'Europe'
        WHEN 'UAE'     THEN 'Middle East'
        WHEN 'India'   THEN 'South Asia'
        WHEN 'Germany' THEN 'Europe'
        WHEN 'France'  THEN 'Europe'
        WHEN 'Australia' THEN 'Oceania'
        ELSE 'Other'
    END,
    CASE customer_country
        WHEN 'USA'     THEN 'USD'
        WHEN 'Canada'  THEN 'CAD'
        WHEN 'UK'      THEN 'GBP'
        WHEN 'UAE'     THEN 'AED'
        WHEN 'India'   THEN 'INR'
        WHEN 'Germany' THEN 'EUR'
        WHEN 'France'  THEN 'EUR'
        WHEN 'Australia' THEN 'AUD'
        ELSE 'USD'
    END
FROM raw_shopify_sales;

CREATE INDEX idx_dim_country_name ON dim_country(country_name);
COMMENT ON TABLE dim_country IS 'Country/Geography dimension. Grain: one row per unique country.';


-- =============================================================================
-- DIMENSION: dim_traffic_source
-- =============================================================================

DROP TABLE IF EXISTS dim_traffic_source CASCADE;

CREATE TABLE dim_traffic_source (
    traffic_source_key  SERIAL          NOT NULL,
    traffic_source      VARCHAR(100)    NOT NULL,
    channel_type        VARCHAR(50),    -- Paid vs Organic
    is_paid             BOOLEAN,

    CONSTRAINT pk_dim_traffic_source        PRIMARY KEY (traffic_source_key),
    CONSTRAINT uq_dim_traffic_source_name   UNIQUE (traffic_source)
);

INSERT INTO dim_traffic_source (traffic_source, channel_type, is_paid)
SELECT DISTINCT
    traffic_source,
    CASE traffic_source
        WHEN 'Paid Ads'     THEN 'Paid'
        WHEN 'Email'        THEN 'Owned'
        WHEN 'Social Media' THEN 'Paid/Organic'
        WHEN 'Organic'      THEN 'Organic'
        WHEN 'Direct'       THEN 'Direct'
        ELSE 'Other'
    END,
    traffic_source IN ('Paid Ads', 'Social Media') AS is_paid
FROM raw_shopify_sales;

COMMENT ON TABLE dim_traffic_source IS 'Traffic source / marketing channel dimension.';


-- =============================================================================
-- DIMENSION: dim_payment_method
-- =============================================================================

DROP TABLE IF EXISTS dim_payment_method CASCADE;

CREATE TABLE dim_payment_method (
    payment_method_key  SERIAL          NOT NULL,
    payment_method      VARCHAR(100)    NOT NULL,
    payment_type        VARCHAR(50),    -- Card, Digital Wallet, COD, etc.
    is_digital_wallet   BOOLEAN,

    CONSTRAINT pk_dim_payment_method        PRIMARY KEY (payment_method_key),
    CONSTRAINT uq_dim_payment_method_name   UNIQUE (payment_method)
);

INSERT INTO dim_payment_method (payment_method, payment_type, is_digital_wallet)
SELECT DISTINCT
    payment_method,
    CASE payment_method
        WHEN 'Credit Card'      THEN 'Card'
        WHEN 'Debit Card'       THEN 'Card'
        WHEN 'PayPal'           THEN 'Digital Wallet'
        WHEN 'Apple Pay'        THEN 'Digital Wallet'
        WHEN 'Cash on Delivery' THEN 'COD'
        ELSE 'Other'
    END,
    payment_method IN ('PayPal', 'Apple Pay') AS is_digital_wallet
FROM raw_shopify_sales;

COMMENT ON TABLE dim_payment_method IS 'Payment method dimension. Classifies payment instruments by type.';


-- =============================================================================
-- FACT TABLE: fact_sales
-- GRAIN: One row per order_id (each order contains one product line item)
-- Additive measures: revenue, profit, quantity, shipping_cost
-- Semi-additive: rating (do not SUM; use AVG)
-- Non-additive: discount_percent (use weighted average)
-- =============================================================================

DROP TABLE IF EXISTS fact_sales CASCADE;

CREATE TABLE fact_sales (
    -- Surrogate key
    sales_key           BIGSERIAL       NOT NULL,

    -- Degenerate dimension (order identifier — no dim table needed)
    order_id            INTEGER         NOT NULL,

    -- Foreign keys to dimensions
    date_key            INTEGER         NOT NULL,   -- FK → dim_date
    customer_key        INTEGER         NOT NULL,   -- FK → dim_customer
    product_key         INTEGER         NOT NULL,   -- FK → dim_product
    country_key         INTEGER         NOT NULL,   -- FK → dim_country
    traffic_source_key  INTEGER         NOT NULL,   -- FK → dim_traffic_source
    payment_method_key  INTEGER         NOT NULL,   -- FK → dim_payment_method

    -- Additive measures
    quantity            INTEGER         NOT NULL,
    product_price       NUMERIC(10, 2)  NOT NULL,   -- List price (pre-discount)
    discounted_price    NUMERIC(10, 2)  NOT NULL,   -- Unit price after discount
    discount_percent    NUMERIC(5, 2)   NOT NULL,
    discount_amount     NUMERIC(10, 2)  NOT NULL,   -- Absolute discount per unit
    shipping_cost       NUMERIC(10, 2)  NOT NULL,
    revenue             NUMERIC(12, 2)  NOT NULL,   -- discounted_price × quantity
    profit              NUMERIC(12, 2)  NOT NULL,   -- revenue - shipping_cost

    -- Derived / calculated measures
    gross_revenue       NUMERIC(12, 2)  NOT NULL,   -- product_price × quantity (no discount)
    profit_margin_pct   NUMERIC(7, 4),              -- profit / revenue

    -- Semi-additive
    rating              NUMERIC(3, 1),

    -- Flag
    is_returned         SMALLINT        NOT NULL DEFAULT 0,

    -- Audit
    _loaded_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_fact_sales        PRIMARY KEY (sales_key),
    CONSTRAINT uq_fact_sales_order  UNIQUE (order_id),

    -- Referential integrity
    CONSTRAINT fk_fact_date         FOREIGN KEY (date_key)           REFERENCES dim_date(date_key),
    CONSTRAINT fk_fact_customer     FOREIGN KEY (customer_key)       REFERENCES dim_customer(customer_key),
    CONSTRAINT fk_fact_product      FOREIGN KEY (product_key)        REFERENCES dim_product(product_key),
    CONSTRAINT fk_fact_country      FOREIGN KEY (country_key)        REFERENCES dim_country(country_key),
    CONSTRAINT fk_fact_traffic      FOREIGN KEY (traffic_source_key) REFERENCES dim_traffic_source(traffic_source_key),
    CONSTRAINT fk_fact_payment      FOREIGN KEY (payment_method_key) REFERENCES dim_payment_method(payment_method_key)
);

INSERT INTO fact_sales (
    order_id,
    date_key, customer_key, product_key, country_key,
    traffic_source_key, payment_method_key,
    quantity, product_price, discounted_price,
    discount_percent, discount_amount, shipping_cost,
    revenue, profit, gross_revenue, profit_margin_pct,
    rating, is_returned
)
SELECT
    r.order_id,
    -- Date key
    TO_CHAR(r.order_date, 'YYYYMMDD')::INTEGER,
    -- Customer surrogate key
    dc.customer_key,
    -- Product surrogate key
    dp.product_key,
    -- Country surrogate key
    dco.country_key,
    -- Traffic source surrogate key
    dt.traffic_source_key,
    -- Payment method surrogate key
    dpm.payment_method_key,
    -- Measures
    r.quantity,
    r.product_price,
    r.discounted_price,
    r.discount_percent,
    ROUND((r.product_price - r.discounted_price) * r.quantity, 2)  AS discount_amount,
    r.shipping_cost,
    r.revenue,
    r.profit,
    ROUND(r.product_price * r.quantity, 2)                         AS gross_revenue,
    ROUND(r.profit / NULLIF(r.revenue, 0), 4)                      AS profit_margin_pct,
    r.rating,
    r.is_returned
FROM raw_shopify_sales r
JOIN dim_customer         dc  ON r.customer_id     = dc.customer_id
JOIN dim_product          dp  ON r.product_id      = dp.product_id
JOIN dim_country          dco ON r.customer_country = dco.country_name
JOIN dim_traffic_source   dt  ON r.traffic_source   = dt.traffic_source
JOIN dim_payment_method   dpm ON r.payment_method   = dpm.payment_method;

-- Indexes on fact table for common query patterns
CREATE INDEX idx_fact_date_key      ON fact_sales(date_key);
CREATE INDEX idx_fact_customer_key  ON fact_sales(customer_key);
CREATE INDEX idx_fact_product_key   ON fact_sales(product_key);
CREATE INDEX idx_fact_country_key   ON fact_sales(country_key);
CREATE INDEX idx_fact_traffic_key   ON fact_sales(traffic_source_key);
CREATE INDEX idx_fact_returned      ON fact_sales(is_returned);
-- Composite index for time-series revenue queries
CREATE INDEX idx_fact_date_revenue  ON fact_sales(date_key, revenue);

COMMENT ON TABLE fact_sales IS
    'Central fact table. Grain: one row per order_id.
     All revenue and profit figures are post-discount.
     Connects to six dimension tables via surrogate keys.
     Use gross_revenue to analyze discount impact vs actual revenue.';
