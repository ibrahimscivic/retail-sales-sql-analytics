-- ====================================================================
-- Project: Retail Sales Analytics (PostgreSQL)
-- Script:  02_analysis_queries.sql
-- Dataset: 600 Orders | retail_sales_orders.csv
-- Database: PostgreSQL 14+ / DBeaver
-- Description: 12 Business Analysis Queries covering Core Financials,
--              Category Trends, Regional Affinity, Customer Demographics,
--              Fulfillment Rates, and Advanced Window Functions.
-- ====================================================================


-- ====================================================================
-- Q1: Overall Revenue, Order Volume & Average Order Value (AOV)
-- Business Context: Calculate the net realized revenue and basket size
-- by filtering only successfully completed ('Delivered') transactions.
-- ====================================================================
SELECT 
    COUNT(order_id) AS total_delivered_orders,
    SUM(total_amount) AS total_net_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value
FROM orders
WHERE order_status = 'Delivered';


-- ====================================================================
-- Q2: Product Category Performance & Revenue Contribution %
-- Business Context: Determine which product categories drive the highest
-- sales volume and their percentage share of overall realized revenue.
-- ====================================================================
SELECT 
    category,
    SUM(quantity) AS total_units_sold,
    SUM(total_amount) AS total_revenue,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER(), 2) AS revenue_share_pct
FROM orders
WHERE order_status = 'Delivered'
GROUP BY category
ORDER BY total_revenue DESC;


-- ====================================================================
-- Q3: Month-over-Month (MoM) Revenue Growth Trend
-- Business Context: Track sales momentum across monthly cohorts and
-- calculate MoM percentage changes using the LAG() window function.
-- ====================================================================
WITH monthly_metrics AS (
    SELECT 
        TO_CHAR(order_date, 'YYYY-MM') AS sales_month,
        COUNT(order_id) AS total_orders,
        SUM(total_amount) AS monthly_revenue
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY TO_CHAR(order_date, 'YYYY-MM')
)
SELECT 
    sales_month,
    total_orders,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY sales_month) AS prior_month_revenue,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY sales_month)) 
        / NULLIF(LAG(monthly_revenue) OVER (ORDER BY sales_month), 0) * 100.0, 
        2
    ) AS mom_growth_pct
FROM monthly_metrics
ORDER BY sales_month;


-- ====================================================================
-- Q4: Regional Performance Breakdown (Revenue & Order Density)
-- Business Context: Identify geographic revenue hubs and evaluate whether
-- top regions win on high order volume or higher Average Order Value (AOV).
-- ====================================================================
SELECT 
    region,
    COUNT(order_id) AS total_orders,
    SUM(quantity) AS total_units_sold,
    SUM(total_amount) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER(), 2) AS regional_revenue_pct
FROM orders
WHERE order_status = 'Delivered'
GROUP BY region
ORDER BY total_revenue DESC;


-- ====================================================================
-- Q5: Top 10 High-Value Customers (LTV / Total Spend)
-- Business Context: Identify top individual contributors to revenue for
-- targeted VIP retention and loyalty campaigns.
-- ====================================================================
SELECT 
    customer_id,
    customer_name,
    city,
    region,
    COUNT(order_id) AS total_orders_placed,
    SUM(total_amount) AS total_lifetime_spend,
    ROUND(AVG(total_amount), 2) AS avg_spend_per_order
FROM orders
WHERE order_status = 'Delivered'
GROUP BY customer_id, customer_name, city, region
ORDER BY total_lifetime_spend DESC
LIMIT 10;


-- ====================================================================
-- Q6: Top 5 Best-Selling Products by Net Revenue
-- Business Context: Identify core revenue-generating inventory items
-- to inform supply chain restocking priorities.
-- ====================================================================
SELECT 
    product,
    category,
    SUM(quantity) AS total_units_sold,
    SUM(total_amount) AS total_revenue,
    ROUND(AVG(unit_price), 2) AS avg_unit_price
FROM orders
WHERE order_status = 'Delivered'
GROUP BY product, category
ORDER BY total_revenue DESC
LIMIT 5;


-- ====================================================================
-- Q7: Payment Method Distribution & Transaction Value
-- Business Context: Analyze customer checkout preferences (COD vs Digital)
-- to optimize payment gateway integrations and reduce collection risk.
-- ====================================================================
SELECT 
    payment_method,
    COUNT(order_id) AS transaction_count,
    ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS volume_share_pct,
    SUM(total_amount) AS total_processed_value,
    ROUND(AVG(total_amount), 2) AS avg_ticket_size
FROM orders
GROUP BY payment_method
ORDER BY transaction_count DESC;


-- ====================================================================
-- Q8: Order Fulfillment Pipeline (Delivered vs Cancelled vs Returned)
-- Business Context: Assess operational fulfillment health and revenue
-- leakage caused by cancellations and post-delivery returns.
-- ====================================================================
SELECT 
    order_status,
    COUNT(order_id) AS order_count,
    ROUND(COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER(), 2) AS pct_of_total_orders,
    SUM(total_amount) AS gross_nominal_value
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- ====================================================================
-- Q9: Regional Category Affinity Matrix
-- Business Context: Determine which product lines dominate specific
-- geographic markets to tailor localized catalog promotions.
-- ====================================================================
SELECT 
    region,
    category,
    COUNT(order_id) AS orders_placed,
    SUM(quantity) AS units_sold,
    SUM(total_amount) AS category_revenue
FROM orders
WHERE order_status = 'Delivered'
GROUP BY region, category
ORDER BY region ASC, category_revenue DESC;


-- ====================================================================
-- Q10: Age Demographic Spending Patterns
-- Business Context: Segment customers into age cohorts to identify
-- high-converting customer profiles and purchasing behavior.
-- ====================================================================
SELECT 
    CASE 
        WHEN age < 25 THEN '1. Gen Z (<25)'
        WHEN age BETWEEN 25 AND 39 THEN '2. Millennials (25-39)'
        WHEN age BETWEEN 40 AND 54 THEN '3. Gen X (40-54)'
        ELSE '4. Boomers+ (55+)'
    END AS age_cohort,
    COUNT(order_id) AS total_orders,
    SUM(total_amount) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value
FROM orders
WHERE order_status = 'Delivered'
GROUP BY 1
ORDER BY age_cohort ASC;


-- ====================================================================
-- Q11: Repeat vs. One-Time Customer Revenue Contribution (CTE)
-- Business Context: Measure customer retention strength by isolating
-- one-time purchasers against repeat buyers and their revenue shares.
-- ====================================================================
WITH customer_order_summary AS (
    SELECT 
        customer_id,
        COUNT(order_id) AS lifetime_orders,
        SUM(total_amount) AS total_customer_spend
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT 
    CASE 
        WHEN lifetime_orders > 1 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS customer_tier,
    COUNT(customer_id) AS unique_customer_count,
    SUM(total_customer_spend) AS tier_total_revenue,
    ROUND(SUM(total_customer_spend) * 100.0 / SUM(SUM(total_customer_spend)) OVER(), 2) AS revenue_pct,
    ROUND(AVG(total_customer_spend), 2) AS avg_spend_per_customer
FROM customer_order_summary
GROUP BY 1
ORDER BY tier_total_revenue DESC;


-- ====================================================================
-- Q12: Highest-Value Order per Category (Window Function: DENSE_RANK)
-- Business Context: Identify peak transaction tickets per category
-- using window partitioning without expensive self-joins.
-- ====================================================================
WITH ranked_category_orders AS (
    SELECT 
        order_id,
        order_date,
        customer_id,
        customer_name,
        category,
        product,
        quantity,
        total_amount,
        DENSE_RANK() OVER (
            PARTITION BY category 
            ORDER BY total_amount DESC
        ) AS rank_within_category
    FROM orders
    WHERE order_status = 'Delivered'
)
SELECT 
    category,
    rank_within_category,
    order_id,
    order_date,
    customer_name,
    product,
    quantity,
    total_amount AS peak_order_amount
FROM ranked_category_orders
WHERE rank_within_category = 1
ORDER BY peak_order_amount DESC;
