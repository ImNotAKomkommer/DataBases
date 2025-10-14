-- Lab Work 5: Database Constraints - Part 1: CHECK Constraints
-- Author: Егор Горохводацкий
-- DBMS: PostgreSQL


-- Task 1.1: Basic CHECK Constraint
-- Create a table employees where:
--   - age must be between 18 and 65
--   - salary must be greater than 0


CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    age INTEGER CHECK (age BETWEEN 18 AND 65),
    salary NUMERIC CHECK (salary > 0)
);

-- Valid Inserts
INSERT INTO employees (first_name, last_name, age, salary)
VALUES ('John', 'Doe', 30, 4000),
       ('Alice', 'Smith', 45, 7200);

-- Invalid Inserts 
-- INSERT INTO employees (first_name, last_name, age, salary)
-- VALUES ('Bob', 'Young', 16, 3000); -- Violates CHECK (age BETWEEN 18 AND 65)
-- INSERT INTO employees (first_name, last_name, age, salary)
-- VALUES ('Eva', 'Low', 25, -500); -- Violates CHECK (salary > 0)


-- Task 1.2: Named CHECK Constraint
-- Create a table products_catalog with named constraint valid_discount
-- Ensures:
--   - regular_price > 0
--   - discount_price > 0
--   - discount_price < regular_price


CREATE TABLE products_catalog (
    product_id SERIAL PRIMARY KEY,
    product_name TEXT,
    regular_price NUMERIC,
    discount_price NUMERIC,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0 AND
        discount_price > 0 AND
        discount_price < regular_price
    )
);

-- Valid Inserts
INSERT INTO products_catalog (product_name, regular_price, discount_price)
VALUES ('Laptop', 1500, 1200),
       ('Headphones', 200, 150);

-- Invalid Inserts 
-- INSERT INTO products_catalog (product_name, regular_price, discount_price)
-- VALUES ('Smartwatch', 300, 400); -- Violates valid_discount (discount_price < regular_price)
-- INSERT INTO products_catalog (product_name, regular_price, discount_price)
-- VALUES ('Mouse', -100, 80); -- Violates valid_discount (regular_price > 0)


-- Task 1.3: Multiple Column CHECK
-- Create a table bookings with:
--   - num_guests between 1 and 10
--   - check_out_date must be after check_in_date

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    check_in_date DATE,
    check_out_date DATE,
    num_guests INTEGER,
    CHECK (num_guests BETWEEN 1 AND 10),
    CHECK (check_out_date > check_in_date)
);

-- Valid Inserts
INSERT INTO bookings (check_in_date, check_out_date, num_guests)
VALUES ('2025-05-01', '2025-05-05', 2),
       ('2025-07-10', '2025-07-15', 4);

-- Invalid Inserts 
-- INSERT INTO bookings (check_in_date, check_out_date, num_guests)
-- VALUES ('2025-06-10', '2025-06-08', 3); -- Violates CHECK (check_out_date > check_in_date)
-- INSERT INTO bookings (check_in_date, check_out_date, num_guests)
-- VALUES ('2025-06-20', '2025-06-25', 12); -- Violates CHECK (num_guests BETWEEN 1 AND 10)


-- Task 1.4: Testing CHECK Constraints
-- Each INSERT above demonstrates the difference between valid and invalid data.
-- The invalid examples, when uncommented, will produce error messages like:
--   ERROR: new row for relation "employees" violates check constraint "employees_age_check"


