-- =============================================================================
-- FILE: 01_schema.sql
-- PROJECT: Shopify E-Commerce Analytics Data Warehouse
-- LAYER: Raw / Source Layer
-- DESCRIPTION: Base table definition for ingested Shopify sales data
-- AUTHOR: Analytics Engineering Team
-- =============================================================================

-- Drop if exists (idempotent execution)
DROP TABLE IF EXISTS raw_shopify_sales;

-- =============================================================================
-- RAW SOURCE TABLE
-- Represents direct ingestion from Shopify export (untransformed)
-- This is the single source of truth before dimensional modeling
-- =============================================================================

CREATE TABLE raw_shopify_sales (
    order_id            INTEGER         NOT NULL,
    order_date          DATE            NOT NULL,
    customer_id         INTEGER         NOT NULL,
    product_id          INTEGER         NOT NULL,
    product_category    VARCHAR(100)    NOT NULL,
    product_price       NUMERIC(10, 2)  NOT NULL,
    discount_percent    NUMERIC(5, 2)   NOT NULL DEFAULT 0,
    quantity            INTEGER         NOT NULL DEFAULT 1,
    customer_country    VARCHAR(100)    NOT NULL,
    traffic_source      VARCHAR(100)    NOT NULL,
    payment_method      VARCHAR(100)    NOT NULL,
    shipping_cost       NUMERIC(10, 2)  NOT NULL DEFAULT 0,
    rating              NUMERIC(3, 1),
    is_returned         SMALLINT        NOT NULL DEFAULT 0,  -- 0 = Not Returned, 1 = Returned
    discounted_price    NUMERIC(10, 2)  NOT NULL,
    revenue             NUMERIC(12, 2)  NOT NULL,
    profit              NUMERIC(12, 2)  NOT NULL,

    -- Audit columns
    _ingested_at        TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    _source             VARCHAR(50)     DEFAULT 'shopify_export'
);

-- =============================================================================
-- CONSTRAINTS
-- =============================================================================

ALTER TABLE raw_shopify_sales
    ADD CONSTRAINT pk_raw_shopify_sales PRIMARY KEY (order_id);

ALTER TABLE raw_shopify_sales
    ADD CONSTRAINT chk_quantity_positive CHECK (quantity > 0);

ALTER TABLE raw_shopify_sales
    ADD CONSTRAINT chk_discount_range CHECK (discount_percent BETWEEN 0 AND 100);

ALTER TABLE raw_shopify_sales
    ADD CONSTRAINT chk_is_returned CHECK (is_returned IN (0, 1));

ALTER TABLE raw_shopify_sales
    ADD CONSTRAINT chk_revenue_non_negative CHECK (revenue >= 0);

-- =============================================================================
-- INDEXES (Performance for downstream transformation queries)
-- =============================================================================

CREATE INDEX idx_raw_order_date        ON raw_shopify_sales(order_date);
CREATE INDEX idx_raw_customer_id       ON raw_shopify_sales(customer_id);
CREATE INDEX idx_raw_product_id        ON raw_shopify_sales(product_id);
CREATE INDEX idx_raw_product_category  ON raw_shopify_sales(product_category);
CREATE INDEX idx_raw_country           ON raw_shopify_sales(customer_country);
CREATE INDEX idx_raw_traffic_source    ON raw_shopify_sales(traffic_source);
CREATE INDEX idx_raw_payment_method    ON raw_shopify_sales(payment_method);
CREATE INDEX idx_raw_is_returned       ON raw_shopify_sales(is_returned);

-- =============================================================================
-- DOCUMENTATION COMMENT
-- =============================================================================

COMMENT ON TABLE raw_shopify_sales IS
    'Source/Raw layer: Direct ingestion from Shopify transactional export.
     One row = one line item (order × product).
     Do not query this table directly for analytics; use warehouse layer views.
     Grain: order_id (each order contains one product, confirmed by schema).';

COMMENT ON COLUMN raw_shopify_sales.is_returned IS
    'Binary flag: 1 = order was returned, 0 = not returned. Source: Shopify fulfillment status.';

COMMENT ON COLUMN raw_shopify_sales.profit IS
    'Calculated as: (discounted_price × quantity) - shipping_cost. Pre-computed in source.';

COMMENT ON COLUMN raw_shopify_sales.revenue IS
    'Gross revenue after discount: discounted_price × quantity. Excludes shipping.';
