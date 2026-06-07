# Shopify E-Commerce Analytics Data Warehouse

<div align="center">

![Python](https://img.shields.io/badge/Python-3.10+-4fc3f7?style=for-the-badge&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-PostgreSQL-a78bfa?style=for-the-badge&logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-Dashboard-fbbf24?style=for-the-badge&logo=powerbi&logoColor=black)
![Pandas](https://img.shields.io/badge/Pandas-Data_Engineering-34d399?style=for-the-badge&logo=pandas&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production_Ready-34d399?style=for-the-badge)

**An enterprise-grade analytical data warehouse built on Shopify transactional data — designed to support executive reporting, customer intelligence, marketing analytics, and product profitability analysis.**

</div>

---

## Executive Summary

This project delivers a production-grade analytics data warehouse system for a high-growth e-commerce business operating on Shopify. Built following industry-standard data warehousing principles, the system transforms raw transactional data into a fully normalized star schema, a reusable KPI layer, and a suite of business-intelligence-ready SQL views and Python notebooks.

The warehouse answers the questions that matter most at the executive level: what drives revenue, where is profit leaking, which customers are worth protecting, and which marketing channels deliver the best return. Every layer — from raw ingestion to strategic recommendation — is designed to integrate directly into Power BI, Tableau, or Looker without further transformation.

---

## Business Problem

E-commerce companies running on Shopify typically have access to raw transactional exports but lack the analytical infrastructure to turn those exports into decision-ready intelligence. Reporting stays at the surface level — total sales, total orders — while the deeper questions go unanswered:

- Which product categories destroy margin at scale?
- Which marketing channels acquire customers cheaply but retain them poorly?
- What percentage of revenue comes from the top 20% of customers?
- Where is the business losing profit to returns, deep discounts, or low-quality orders?
- How do cohorts of customers acquired in different months retain over time?

This warehouse was built to answer all of these questions — and to make the answers accessible to analysts, BI tools, and executives without writing bespoke SQL every time.

---

## Data Architecture

### Why Star Schema?

The star schema is the industry standard for analytical workloads because it is optimized for query performance, readability, and BI tool compatibility. Unlike a normalized OLTP schema (which is optimized for writes and data integrity), the star schema denormalizes data into a central fact table surrounded by dimension tables — one join from the fact table to any dimension, no multi-hop queries.

```
                        ┌──────────────┐
                        │   dim_date   │
                        └──────┬───────┘
                               │
  ┌───────────────┐   ┌────────┴─────────┐   ┌──────────────────┐
  │ dim_customer  │───│   fact_sales     │───│   dim_product    │
  └───────────────┘   │                  │   └──────────────────┘
                      │  GRAIN:          │
  ┌───────────────┐   │  1 row per       │   ┌──────────────────┐
  │  dim_country  │───│  order_id        │───│dim_traffic_source│
  └───────────────┘   │                  │   └──────────────────┘
                      │  MEASURES:       │
                      │  revenue         │   ┌──────────────────┐
                      │  profit          │───│dim_payment_method│
                      │  discount_amount │   └──────────────────┘
                      │  gross_revenue   │
                      └──────────────────┘
```

**Fact vs Dimension Model:**
- The **fact table** (`fact_sales`) stores measurable business events — each row is one completed order with numeric measures (revenue, profit, quantity, discount).
- **Dimension tables** store descriptive attributes about the entities involved in each event — who bought, what they bought, when, from where, through which channel, using which payment method.
- **Surrogate keys** (auto-incremented integers) in all dimension tables ensure joins are fast, compact, and stable even when natural keys change.

---

## Dataset Overview

| Attribute | Detail |
|---|---|
| Source | Shopify transactional export |
| Rows | ~60,000 order line items |
| Columns | 17 raw fields |
| Time Period | January 2023 — mid 2025 |
| Grain | One row per order ID |
| Markets | USA, UAE, UK, Canada, India, and more |
| Categories | Electronics, Fashion, Sports, Beauty, Footwear, Accessories, Home Decor |
| Channels | Paid Ads, Email, Social Media, Organic, Direct |

**Key Metrics Available:** Revenue, Profit, Discount %, Quantity, Shipping Cost, Product Rating, Return Flag

---

## Technology Stack

| Layer | Technology |
|---|---|
| Data Engineering | Python 3.10 · Pandas · NumPy |
| Visualization | Matplotlib · Seaborn |
| Warehouse Logic | SQL (PostgreSQL-compatible) |
| BI Dashboard | Power BI (DAX) |
| Notebook Environment | Jupyter Notebook |
| Version Control | Git · GitHub |
| Data Format | CSV (source) → Star Schema (warehouse) |

---

## Data Warehouse Design

### fact_sales — Grain & Measures

The grain of `fact_sales` is **one row per order ID**. Each order in the Shopify dataset contains a single product line item, confirmed via duplicate analysis in Notebook 1.

**Additive measures** (can be summed across any dimension):
- `revenue` — net revenue after discount (discounted_price × quantity)
- `profit` — revenue minus shipping cost
- `gross_revenue` — pre-discount revenue (product_price × quantity)
- `discount_amount` — absolute value of discount applied
- `shipping_cost` — fulfillment cost per order
- `quantity` — units sold

**Semi-additive measures** (cannot be summed; use AVG):
- `rating` — customer product rating (1–5)

**Non-additive measures** (use weighted average):
- `discount_percent` — percentage discount applied
- `profit_margin_pct` — profit as a share of revenue

### Dimension Tables

| Table | Rows | Key Attributes |
|---|---|---|
| `dim_date` | 1,096 | year, quarter, month, week, day_name, is_weekend |
| `dim_customer` | ~45,000 | country, first/last order, total orders, CLV, repeat flag |
| `dim_product` | ~8,000 | category, avg price, avg discount, return rate, avg rating |
| `dim_country` | 8 | country_name, region, currency_code |
| `dim_traffic_source` | 5 | traffic_source, channel_type, is_paid |
| `dim_payment_method` | 5 | payment_method, payment_type, is_digital_wallet |

### Surrogate Key Strategy

All dimension tables use auto-incremented integer surrogate keys (`SERIAL` in PostgreSQL). Natural keys are preserved as business keys for traceability. This ensures:
- Fast integer-based joins in the fact table
- Stability of foreign keys even when source natural keys change (SCD Type 1)
- Smaller fact table storage footprint

---

## KPI Layer

The KPI layer (`03_kpi_layer.sql`) provides a set of reusable SQL views that serve as the single source of truth for all BI dashboards and ad-hoc reporting. Analysts query the KPI views — they never write raw joins against the fact table.

| KPI | Definition | View |
|---|---|---|
| **Revenue** | `SUM(discounted_price × quantity)` | `kpi_monthly_revenue` |
| **Gross Revenue** | `SUM(product_price × quantity)` | `kpi_monthly_revenue` |
| **Profit** | `SUM(revenue - shipping_cost)` | `kpi_profit_by_category` |
| **Profit Margin %** | `profit / revenue × 100` | All views |
| **Orders** | `COUNT(DISTINCT order_id)` | All views |
| **Customers** | `COUNT(DISTINCT customer_key)` | All views |
| **AOV** | `revenue / orders` | `kpi_aov_by_channel` |
| **Return Rate %** | `SUM(is_returned) / COUNT(*) × 100` | `kpi_return_rate` |
| **Discount Rate %** | `discount_amount / gross_revenue × 100` | `kpi_discount_impact` |

---

## Dashboards

### Executive Dashboard

![Executive Dashboard](dashboard/img1_dash1.png)

### Customer Analytics Dashboard

![Customer Dashboard](dashboard/img2_dash2.png)

---

## Key Insights

**Revenue & Profit**
- Revenue and profit trends move in lockstep, indicating that discounting is not causing systemic margin compression at the macro level — but deep-discount orders (>30%) show meaningfully lower margins when isolated.

**Customer Intelligence**
- Approximately 20% of customers generate 80% of total revenue — the Pareto principle holds. Champions and Loyal Customers are a small group delivering outsized value and require retention investment.
- Cohort retention drops sharply after the first month across all acquisition cohorts, identifying post-purchase engagement as the primary growth lever.

**Marketing Channels**
- Not all high-revenue channels are equally profitable. Paid channels may drive volume but compress margin through higher discount usage. Owned channels (Email, Organic) typically deliver superior margin.

**Product Categories**
- Return rates vary significantly by category. High-return categories correlate with lower average ratings on returned orders, suggesting expectation mismatch rather than defect rates.

**Profit Leakage**
- Three identifiable leakage sources: deep discounts, returns, and low-rated orders. These can be quantified precisely using the warehouse's discount_amount and is_returned measures.

---

## Strategic Recommendations

**Revenue Optimization**
1. Concentrate inventory and campaign investment in the top two revenue-generating categories.
2. Expand marketing presence in highest-AOV geographies with localized offers.
3. Protect top-10 customers with a dedicated account management or VIP loyalty program.

**Profit Improvement**
1. Cap automated discount rules at 20–25%; eliminate any discount logic that triggers above 30% without manual approval.
2. Implement a minimum margin floor by category; deprioritize or discontinue SKUs consistently below threshold.
3. Audit the highest-return categories for product listing accuracy — better descriptions reduce return rates without impacting conversion.

**Customer Retention**
1. Deploy automated 30/60/90-day win-back email flows targeting the "At Risk" and "Hibernating" RFM segments.
2. Invest in post-purchase experience for first-time buyers — the gap between one-time and repeat customer lifetime value is substantial.
3. Build a Champions loyalty tier with exclusive benefits to protect the top-revenue customer cohort.

**Channel Efficiency**
1. Reallocate paid media budget toward the highest profit-per-order channel identified in `mkt_channel_efficiency_ranking`.
2. Invest in owned channel growth (Email list, SEO) to reduce marginal acquisition cost over time.
3. Pilot digital payment incentives in markets with high COD adoption and elevated return rates.

---

## SQL Highlights

### Window Functions (`06_window_functions.sql`)

The window function file demonstrates enterprise-grade analytical SQL across 8 real business scenarios:

- `LAG()` / `LEAD()` — Month-over-month and year-over-year revenue growth; forward trend signals
- `SUM() OVER()` — Cumulative YTD revenue with year partitioning; all-time running totals
- `AVG() OVER()` — 3-month rolling average to smooth seasonal volatility
- `RANK()` / `DENSE_RANK()` — Customer revenue leaderboard with tie-safe ranking
- `ROW_NUMBER()` — Best product per category (single winner, no ties)
- `PERCENT_RANK()` / `NTILE()` — Product quartile performance tiers
- `FIRST_VALUE()` / `LAST_VALUE()` — Year-start baseline comparison for growth tracking

### KPI Layer Design

All KPI views are idempotent (`CREATE OR REPLACE`), meaning they can be re-executed safely on schema updates. Each view is a single, self-contained query against the star schema — no nested CTE stacks, no procedural logic. This makes them directly consumable by Power BI DirectQuery and Tableau Live connections.

### Star Schema Queries

Every analytical query in this project joins through the fact table to dimension tables using integer surrogate keys — the fastest possible join type in any RDBMS. No string-based joins exist in the analytics layer. Date filtering uses the integer `date_key` (YYYYMMDD format), enabling partition pruning in columnar storage engines.

---

## Project Structure

```
shopify-analytics-warehouse/
│
├── README.md
│
├── notebooks/
│   ├── 01_data_engineering_cleaning.ipynb
│   ├── 02_data_warehouse_modeling.ipynb
│   ├── 03_exploratory_data_analysis.ipynb
│   ├── 04_customer_analytics.ipynb
│   └── 05_executive_business_insights.ipynb
│
├── sql/
│   ├── 01_schema.sql               ← Raw source table definition
│   ├── 02_star_schema.sql          ← Full dimensional model
│   ├── 03_kpi_layer.sql            ← Reusable business metrics views
│   ├── 04_customer_analytics.sql   ← RFM, CLV, cohort, Pareto
│   ├── 05_marketing_analytics.sql  ← Channel performance & efficiency
│   ├── 06_window_functions.sql     ← Advanced analytical SQL
│   └── 07_executive_reporting.sql  ← Board-ready queries
│
├── warehouse/                      ← Generated by Notebook 2
│   ├── fact_sales.csv
│   ├── dim_date.csv
│   ├── dim_customer.csv
│   ├── dim_product.csv
│   ├── dim_country.csv
│   ├── dim_traffic_source.csv
│   └── dim_payment_method.csv
│
├── dashboard/
│   ├── img1_dash1.png              ← Executive Dashboard (add manually)
│   └── img2_dash2.png              ← Customer Dashboard (add manually)
│
└── data/
    └── shopify_sales.csv           ← Source dataset
```

---

## Business Impact

**Revenue Optimization**
The KPI layer and executive reporting queries enable the business to identify its highest-value revenue drivers — by category, geography, and channel — within seconds. Decisions that previously required days of ad-hoc analysis are now answered with a single view query.

**Profit Improvement**
The discount impact analysis and profit leakage framework quantify exactly how much margin is being surrendered through over-discounting and returns. The business now has the data to enforce margin floors and redesign discount rules with precision.

**Customer Retention Improvement**
The RFM segmentation and cohort retention framework identify at-risk customers before they churn, enabling proactive outreach. Protecting the Champions and Loyal Customers segments — which drive a disproportionate share of revenue — delivers compounding retention value over time.

---

<div align="center">

**Built by:** Hamza | Analytics Engineering  
**Stack:** Python · SQL · Power BI · Pandas · PostgreSQL  
**Architecture:** Star Schema Data Warehouse · KPI Layer · RFM Segmentation

</div>
