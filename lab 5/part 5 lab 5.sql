
-- Lab Work 5: Database Constraints - Part 5: FOREIGN KEY Constraints
-- Author: Егор Горохводацкий
-- DBMS: PostgreSQL
-- This section practices FOREIGN KEY relationships and ON DELETE behaviors.


-- Task 5.1: Basic Foreign Key
-- Create employees_dept linked to departments table via dept_id.

CREATE TABLE employees_dept (
    emp_id SERIAL PRIMARY KEY,
    emp_name TEXT NOT NULL,
    dept_id INTEGER REFERENCES departments(dept_id),
    hire_date DATE
);

-- Valid Inserts (departments already exist from Part 4)
INSERT INTO employees_dept (emp_name, dept_id, hire_date)
VALUES ('John Doe', 1, '2025-03-01'),
       ('Alice Smith', 2, '2025-04-12');

-- Invalid Insert 
-- INSERT INTO employees_dept (emp_name, dept_id, hire_date)
-- VALUES ('Bob Ghost', 99, '2025-05-10'); -- Violates FK: no dept_id=99 in departments


-- Task 5.2: Multiple Foreign Keys - Library System
-- Design schema: authors -> books <- publishers

CREATE TABLE authors (
    author_id SERIAL PRIMARY KEY,
    author_name TEXT NOT NULL,
    country TEXT
);

CREATE TABLE publishers (
    publisher_id SERIAL PRIMARY KEY,
    publisher_name TEXT NOT NULL,
    city TEXT
);

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    author_id INTEGER REFERENCES authors(author_id),
    publisher_id INTEGER REFERENCES publishers(publisher_id),
    publication_year INTEGER,
    isbn TEXT UNIQUE
);

-- Valid Inserts
INSERT INTO authors (author_name, country)
VALUES ('Fyodor Dostoevsky', 'Russia'),
       ('George Orwell', 'UK');

INSERT INTO publishers (publisher_name, city)
VALUES ('Penguin Classics', 'London'),
       ('Eksmo', 'Moscow');

INSERT INTO books (title, author_id, publisher_id, publication_year, isbn)
VALUES ('Crime and Punishment', 1, 2, 1866, '978-5-699-12014-4'),
       ('1984', 2, 1, 1949, '978-0-14-103614-4');

-- Invalid Insert 
-- INSERT INTO books (title, author_id, publisher_id, publication_year, isbn)
-- VALUES ('Fake Book', 99, 1, 2025, '000-0-00-000000-0'); -- Violates FK (author_id=99 doesn't exist)


-- Task 5.3: ON DELETE Options
-- Demonstrate RESTRICT vs CASCADE delete behaviors.

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name TEXT NOT NULL
);

CREATE TABLE products_fk (
    product_id SERIAL PRIMARY KEY,
    product_name TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    order_date DATE NOT NULL
);

CREATE TABLE order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products_fk(product_id),
    quantity INTEGER CHECK (quantity > 0)
);

-- Valid Inserts
INSERT INTO categories (category_name)
VALUES ('Electronics'), ('Home Appliances');

INSERT INTO products_fk (product_name, category_id)
VALUES ('Smartphone', 1), ('Microwave', 2);

INSERT INTO orders (order_date) VALUES ('2025-07-01');

INSERT INTO order_items (order_id, product_id, quantity)
VALUES (1, 1, 2), (1, 2, 1);

-- Test 1: Try to delete category that has products (RESTRICT)
-- DELETE FROM categories WHERE category_id = 1;
-- ERROR: update or delete on table "categories" violates foreign key constraint 
--        on table "products_fk" (ON DELETE RESTRICT)

-- Test 2: Delete order (CASCADE)
-- Deleting an order automatically deletes related order_items
DELETE FROM orders WHERE order_id = 1;

-- Check: SELECT * FROM order_items; -> should be empty

-- Explanation
-- - ON DELETE RESTRICT: prevents deletion if dependent rows exist.
-- - ON DELETE CASCADE: automatically deletes related child rows.


