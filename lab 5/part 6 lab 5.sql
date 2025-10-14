
-- Lab Work 5: Database Constraints - Part 6: E-commerce Database
-- Author: Егор Горохводацкий
-- DBMS: PostgreSQL
-- This section designs a complete e-commerce database schema.
-- Demonstrates PRIMARY KEY, FOREIGN KEY, CHECK, UNIQUE, and NOT NULL constraints.


-- Schema Overview
-- Tables:
--   1. customers
--   2. products
--   3. orders
--   4. order_details


-- customers
-- Constraints:
--   - customer_id: PRIMARY KEY
--   - email: UNIQUE and NOT NULL
--   - name, registration_date: NOT NULL

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

-- Valid Inserts
INSERT INTO customers (name, email, phone, registration_date)
VALUES ('Alice Johnson', 'alice@example.com', '+77015550001', '2025-03-01'),
       ('Bob Smith', 'bob@example.com', '+77015550002', '2025-03-05'),
       ('Charlie Brown', 'charlie@example.com', NULL, '2025-03-10'),
       ('Diana Prince', 'diana@example.com', '+77015550004', '2025-03-12'),
       ('Egor K.', 'egor@example.com', '+77015550005', '2025-03-15');

-- Invalid Insert (commented out)
-- INSERT INTO customers (name, email, registration_date)
-- VALUES ('Fake User', 'alice@example.com', '2025-03-20'); -- Violates UNIQUE (duplicate email)


-- products
-- Constraints:
--   - product_id: PRIMARY KEY
--   - price >= 0
--   - stock_quantity >= 0

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC CHECK (price >= 0),
    stock_quantity INTEGER CHECK (stock_quantity >= 0)
);

-- Valid Inserts
INSERT INTO products (name, description, price, stock_quantity)
VALUES ('Laptop', 'Powerful gaming laptop', 2000, 5),
       ('Smartphone', '5G smartphone with AMOLED display', 1000, 10),
       ('Headphones', 'Noise-cancelling over-ear headphones', 300, 15),
       ('Smartwatch', 'Waterproof smartwatch', 250, 20),
       ('Tablet', '10-inch tablet with stylus support', 800, 8);

-- Invalid Insert (commented out)
-- INSERT INTO products (name, description, price, stock_quantity)
-- VALUES ('Broken Item', 'Defective', -100, 3); -- Violates CHECK (price >= 0)


-- orders
-- Constraints:
--   - order_id: PRIMARY KEY
--   - customer_id: FOREIGN KEY REFERENCES customers
--   - total_amount >= 0
--   - status -> ('pending', 'processing', 'shipped', 'delivered', 'cancelled')

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id) ON DELETE CASCADE,
    order_date DATE NOT NULL,
    total_amount NUMERIC CHECK (total_amount >= 0),
    status TEXT CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
);

-- Valid Inserts
INSERT INTO orders (customer_id, order_date, total_amount, status)
VALUES (1, '2025-04-01', 3000, 'pending'),
       (2, '2025-04-03', 1000, 'processing'),
       (3, '2025-04-05', 550, 'shipped'),
       (4, '2025-04-06', 250, 'delivered'),
       (5, '2025-04-07', 0, 'cancelled');

-- Invalid Insert (commented out)
-- INSERT INTO orders (customer_id, order_date, total_amount, status)
-- VALUES (1, '2025-04-10', 150, 'unknown'); -- Violates CHECK (status in predefined set)


-- order_details
-- Constraints:
--   - order_detail_id: PRIMARY KEY
--   - order_id: FOREIGN KEY REFERENCES orders
--   - product_id: FOREIGN KEY REFERENCES products
--   - quantity > 0
--   - unit_price >= 0

CREATE TABLE order_details (
    order_detail_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(product_id),
    quantity INTEGER CHECK (quantity > 0),
    unit_price NUMERIC CHECK (unit_price >= 0)
);

-- Valid Inserts
INSERT INTO order_details (order_id, product_id, quantity, unit_price)
VALUES (1, 1, 1, 2000),
       (1, 2, 1, 1000),
       (2, 3, 2, 300),
       (3, 4, 1, 250),
       (4, 5, 1, 800);

-- Invalid Inserts (commented out)
-- INSERT INTO order_details (order_id, product_id, quantity, unit_price)
-- VALUES (1, 3, 0, 300); -- Violates CHECK (quantity > 0)
-- INSERT INTO order_details (order_id, product_id, quantity, unit_price)
-- VALUES (99, 1, 1, 2000); -- Violates FK: order_id=99 doesn’t exist


-- Testing Relationships
-- - Deleting a customer deletes their orders (ON DELETE CASCADE)
-- - Deleting an order deletes its order_details (ON DELETE CASCADE)

-- DELETE FROM customers WHERE customer_id = 1;
-- After deletion:
--   - Orders for customer_id=1 are removed
--   - Related order_details also deleted automatically

-- Summary
-- This schema enforces full data integrity:
--   + PRIMARY KEY: unique identifiers for every table
--   + FOREIGN KEY: referential links between tables
--   + CHECK: validates numeric and enum-like fields
--   + UNIQUE: prevents duplicate customer emails
--   + NOT NULL: ensures essential fields are always filled

-- End of Part 6


