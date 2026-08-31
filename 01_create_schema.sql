-- ====================================================================
-- Project: Retail Sales Analytics (PostgreSQL)
-- Script:  01_create_schema.sql
-- Description: DDL schema definition and index creation for the orders table.
-- ====================================================================

-- 1. Drop existing table and related objects if they exist
DROP TABLE IF EXISTS orders CASCADE;

-- 2. Create the primary orders transactional table
CREATE TABLE orders (
    order_id        VARCHAR(20)     PRIMARY KEY,
    order_date      DATE            NOT NULL,
    customer_id     VARCHAR(20)     NOT NULL,
    customer_name   VARCHAR(100)    NOT NULL,
    age             INT             CHECK (age >= 0),
    gender          VARCHAR(10),
    city            VARCHAR(50),
    region          VARCHAR(50)     NOT NULL,
    product         VARCHAR(100)    NOT NULL,
    category        VARCHAR(50)     NOT NULL,
    quantity        INT             NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10, 2)  NOT NULL CHECK (unit_price >= 0),
    discount_pct    NUMERIC(5, 2)   DEFAULT 0.00 CHECK (discount_pct >= 0 AND discount_pct <= 100),
    total_amount    NUMERIC(10, 2)  NOT NULL CHECK (total_amount >= 0),
    payment_method  VARCHAR(50),
    order_status    VARCHAR(20)     NOT NULL CHECK (order_status IN ('Delivered', 'Cancelled', 'Returned'))
);

-- 3. Add column documentation comments for database maintainability
COMMENT ON TABLE orders IS 'Consolidated transactional retail sales dataset (600 records)';
COMMENT ON COLUMN orders.order_id IS 'Unique identifier for each transaction order';
COMMENT ON COLUMN orders.customer_id IS 'Unique identifier for the purchasing customer';
COMMENT ON COLUMN orders.order_status IS 'Fulfillment status: Delivered, Cancelled, or Returned';
COMMENT ON COLUMN orders.total_amount IS 'Final transaction revenue after discount';

-- 4. Create performance indexes for frequent analytical filters and aggregations
-- Speeds up time-series and month-over-month trend queries (Q3)
CREATE INDEX idx_orders_order_date ON orders (order_date);

-- Speeds up status-based revenue filtering across all delivered orders (Q1 - Q12)
CREATE INDEX idx_orders_status ON orders (order_status);

-- Speeds up regional performance analysis and grouping (Q4, Q9)
CREATE INDEX idx_orders_region ON orders (region);

-- Speeds up category-level revenue and window function partitioning (Q2, Q6, Q9, Q12)
CREATE INDEX idx_orders_category ON orders (category);

-- Speeds up customer spend aggregations and repeat buyer CTEs (Q5, Q11)
CREATE INDEX idx_orders_customer_id ON orders (customer_id);

-- Composite index for optimized regional and categorical slicing
CREATE INDEX idx_orders_region_category ON orders (region, category);
