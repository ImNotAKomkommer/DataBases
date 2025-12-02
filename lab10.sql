-- setup
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    balance DECIMAL(10, 2) DEFAULT 0.00
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    shop VARCHAR(100) NOT NULL,
    product VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

INSERT INTO accounts (name, balance) VALUES
    ('Alice', 1000.00),
    ('Bob', 500.00),
    ('Wally', 750.00);

INSERT INTO products (shop, product, price) VALUES
    ('Joe''s Shop', 'Coke', 2.50),
    ('Joe''s Shop', 'Pepsi', 3.00);

-- test setup
SELECT * FROM accounts;
SELECT * FROM products;

-- task 1: basic transaction with COMMIT
BEGIN;
UPDATE accounts
SET balance = balance - 100.00
WHERE name = 'Alice';

UPDATE accounts
SET balance = balance + 100.00
WHERE name = 'Bob';
COMMIT;

-- test 1
SELECT * FROM accounts WHERE name IN ('Alice','Bob');

-- task 2: using ROLLBACK
BEGIN;
UPDATE accounts
SET balance = balance - 500.00
WHERE name = 'Alice';

-- test 2 before rollback
SELECT * FROM accounts WHERE name = 'Alice';

ROLLBACK;

-- test 2 after rollback
SELECT * FROM accounts WHERE name = 'Alice';

-- task 3: working with SAVEPOINTs
BEGIN;
UPDATE accounts
SET balance = balance - 100.00
WHERE name = 'Alice';

SAVEPOINT my_savepoint;

UPDATE accounts
SET balance = balance + 100.00
WHERE name = 'Bob';

ROLLBACK TO my_savepoint;

UPDATE accounts
SET balance = balance + 100.00
WHERE name = 'Wally';

COMMIT;

-- test 3
SELECT * FROM accounts
WHERE name IN ('Alice','Bob','Wally');

-- task 4: isolation level demonstration
-- scenario A: READ COMMITTED
-- task 4 scenario A terminal 1
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- run terminal 2 part, then:
SELECT * FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

-- task 4 scenario A terminal 2
BEGIN;
DELETE FROM products WHERE shop = 'Joe''s Shop';
INSERT INTO products (shop, product, price)
VALUES ('Joe''s Shop', 'Fanta', 3.50);
COMMIT;

-- test 4
SELECT * FROM products WHERE shop = 'Joe''s Shop';

-- task 4: scenario B: SERIALIZABLE
-- reset products for scenario B if needed
TRUNCATE products RESTART IDENTITY;
INSERT INTO products (shop, product, price) VALUES
    ('Joe''s Shop', 'Coke', 2.50),
    ('Joe''s Shop', 'Pepsi', 3.00);

-- task 4 scenario B terminal 1
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- run terminal 2 part, then:
SELECT * FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

-- task 4 scenario B terminal 2
BEGIN;
DELETE FROM products WHERE shop = 'Joe''s Shop';
INSERT INTO products (shop, product, price)
VALUES ('Joe''s Shop', 'Fanta', 3.50);
COMMIT;

-- task 5: phantom read demonstration (REPEATABLE READ)
-- ensure products in base state
TRUNCATE products RESTART IDENTITY;
INSERT INTO products (shop, product, price) VALUES
    ('Joe''s Shop', 'Coke', 2.50),
    ('Joe''s Shop', 'Pepsi', 3.00),
    ('Joe''s Shop', 'Fanta', 3.50);

-- task 5 terminal 1
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT MAX(price), MIN(price)
FROM products
WHERE shop = 'Joe''s Shop';
-- run terminal 2 part, then:
SELECT MAX(price), MIN(price)
FROM products
WHERE shop = 'Joe''s Shop';
COMMIT;

-- task 5 terminal 2
BEGIN;
INSERT INTO products (shop, product, price)
VALUES ('Joe''s Shop', 'Sprite', 4.00);
COMMIT;

-- test 5
SELECT * FROM products WHERE shop = 'Joe''s Shop';

-- task 6: dirty read demonstration (READ UNCOMMITTED)
-- make sure Fanta exists
TRUNCATE products RESTART IDENTITY;
INSERT INTO products (shop, product, price) VALUES
    ('Joe''s Shop', 'Coke', 2.50),
    ('Joe''s Shop', 'Pepsi', 3.00),
    ('Joe''s Shop', 'Fanta', 3.50);

-- task 6 terminal 1
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- run terminal 2 update, then:
SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- run terminal 2 rollback, then:
SELECT * FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

-- task 6 terminal 2
BEGIN;
UPDATE products
SET price = 99.99
WHERE product = 'Fanta';
-- wait here, then:
ROLLBACK;

-- test 6
SELECT * FROM products WHERE shop = 'Joe''s Shop';

-- independent exercise 1
-- transfer $200 from Bob to Wally with error handling
DO $$
DECLARE
    v_balance DECIMAL(10,2);
BEGIN
    SELECT balance
    INTO v_balance
    FROM accounts
    WHERE name = 'Bob'
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Bob account not found';
    END IF;

    IF v_balance < 200.00 THEN
        RAISE EXCEPTION 'Insufficient funds for Bob: %', v_balance;
    END IF;

    UPDATE accounts
    SET balance = balance - 200.00
    WHERE name = 'Bob';

    UPDATE accounts
    SET balance = balance + 200.00
    WHERE name = 'Wally';
END $$;

-- test ex1
SELECT * FROM accounts WHERE name IN ('Bob','Wally');

-- independent exercise 2
-- transaction with multiple savepoints
BEGIN;
INSERT INTO products (shop, product, price)
VALUES ('Joe''s Shop', 'TempProduct', 5.00);

SAVEPOINT sp_insert;

UPDATE products
SET price = 6.50
WHERE shop = 'Joe''s Shop' AND product = 'TempProduct';

SAVEPOINT sp_update;

DELETE FROM products
WHERE shop = 'Joe''s Shop' AND product = 'TempProduct';

ROLLBACK TO sp_insert;

COMMIT;

-- test ex2
SELECT * FROM products
WHERE shop = 'Joe''s Shop' AND product = 'TempProduct';

-- independent exercise 3
-- concurrent withdrawals from same account
-- ex3 setup
DELETE FROM accounts WHERE name = 'Shared';
INSERT INTO accounts (name, balance)
VALUES ('Shared', 300.00);

-- ex3 read committed terminal 1
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE name = 'Shared';
UPDATE accounts
SET balance = balance - 200.00
WHERE name = 'Shared';
-- keep uncommitted for now

-- ex3 read committed terminal 2
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE name = 'Shared';
UPDATE accounts
SET balance = balance - 200.00
WHERE name = 'Shared';
COMMIT;

-- now commit terminal 1
COMMIT;

-- test ex3 read committed
SELECT * FROM accounts WHERE name = 'Shared';

-- ex3 serializable reset
UPDATE accounts
SET balance = 300.00
WHERE name = 'Shared';

-- ex3 serializable terminal 1
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT balance FROM accounts WHERE name = 'Shared';
UPDATE accounts
SET balance = balance - 200.00
WHERE name = 'Shared';
-- keep open

-- ex3 serializable terminal 2
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT balance FROM accounts WHERE name = 'Shared';
UPDATE accounts
SET balance = balance - 200.00
WHERE name = 'Shared';
-- depending on DB, this may block or raise error
COMMIT;

-- commit terminal 1
COMMIT;

-- test ex3 serializable
SELECT * FROM accounts WHERE name = 'Shared';

-- independent exercise 4
-- MAX < MIN anomaly and fix using transactions
DROP TABLE IF EXISTS sells;

CREATE TABLE sells (
    shop VARCHAR(100) NOT NULL,
    product VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL
);

INSERT INTO sells (shop, product, price) VALUES
    ('Shop1', 'A', 100.00),
    ('Shop1', 'B', 200.00);

-- ex4 anomaly (no proper transactions)
-- sally terminal 1
SELECT MAX(price) AS max_price_before
FROM sells
WHERE shop = 'Shop1';

-- joe terminal 2
UPDATE sells
SET price = 300.00
WHERE shop = 'Shop1' AND product = 'A';

-- sally terminal 1
SELECT MIN(price) AS min_price_after
FROM sells
WHERE shop = 'Shop1';

-- depending on timing, logic can lead to MAX < MIN perception

-- ex4 fixed using transaction for Sally
-- reset data
TRUNCATE sells;
INSERT INTO sells (shop, product, price) VALUES
    ('Shop1', 'A', 100.00),
    ('Shop1', 'B', 200.00);

-- sally terminal 1
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT MAX(price) AS max_price_rr
FROM sells
WHERE shop = 'Shop1';

-- joe terminal 2
BEGIN;
UPDATE sells
SET price = 300.00
WHERE shop = 'Shop1' AND product = 'A';
COMMIT;

-- sally terminal 1
SELECT MIN(price) AS min_price_rr
FROM sells
WHERE shop = 'Shop1';
COMMIT;

-- test ex4
SELECT * FROM sells WHERE shop = 'Shop1';
