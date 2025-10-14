-- Lab Work 5: Database Constraints - Part 2: NOT NULL Constraints
-- Author: Егор Горохводацкий
-- DBMS: PostgreSQL


-- Task 2.1: NOT NULL Implementation
-- Create a table customers where:
--   - customer_id, email, registration_date are NOT NULL
--   - phone can be NULL

CREATE TABLE customers (
    customer_id SERIAL NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

-- Valid Inserts
INSERT INTO customers (email, phone, registration_date)
VALUES ('alice@example.com', '+77015551122', '2025-05-01'),
       ('bob@example.com', NULL, '2025-06-10');

-- Invalid Inserts 
-- INSERT INTO customers (email, phone, registration_date)
-- VALUES (NULL, '+77017772233', '2025-06-10'); -- Violates NOT NULL on email
-- INSERT INTO customers (email, phone, registration_date)
-- VALUES ('carol@example.com', '+77018883344', NULL); -- Violates NOT NULL on registration_date


-- Task 2.2: Combining Constraints
-- Create a table inventory where:
--   - quantity >= 0
--   - unit_price > 0
--   - All columns except item_id must be NOT NULL

CREATE TABLE inventory (
    item_id SERIAL NOT NULL,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
    last_updated TIMESTAMP NOT NULL
);

-- Valid Inserts
INSERT INTO inventory (item_name, quantity, unit_price, last_updated)
VALUES ('Laptop', 5, 1500, NOW()),
       ('Keyboard', 20, 45, NOW());

-- Invalid Inserts 
-- INSERT INTO inventory (item_name, quantity, unit_price, last_updated)
-- VALUES ('Mouse', NULL, 25, NOW()); -- Violates NOT NULL on quantity
-- INSERT INTO inventory (item_name, quantity, unit_price, last_updated)
-- VALUES ('Monitor', 10, -100, NOW()); -- Violates CHECK (unit_price > 0)
-- INSERT INTO inventory (item_name, quantity, unit_price, last_updated)
-- VALUES (NULL, 3, 300, NOW()); -- Violates NOT NULL on item_name


-- Task 2.3: Testing NOT NULL
-- Demonstrates which fields accept NULL and which do not.
-- NULL is allowed only in nullable columns (like phone).

-- Nullable column test
INSERT INTO customers (email, phone, registration_date)
VALUES ('diana@example.com', NULL, '2025-07-01');

-- Non-nullable column test 
-- INSERT INTO inventory (item_name, quantity, unit_price, last_updated)
-- VALUES ('Charger', 5, NULL, NOW()); -- Violates NOT NULL on unit_price

