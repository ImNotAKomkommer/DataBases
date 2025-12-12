/*
KBTU | Database Systems | Bonus Laboratory Work (Advanced)
Complete Banking Transaction System for KazFinance Bank
- Tables + sample data (10+ rows each main table)
- Stored procedures: process_transfer, process_salary_batch
- Views: customer_balance_summary, daily_transaction_report, suspicious_activity_view (security_barrier)
- Index strategy: B-tree, Hash, GIN, partial, composite, covering, expression
- EXPLAIN ANALYZE statements included (run them after data load)
- Concurrency demo scripts included
*/

-- Recommended for dev runs
SET client_min_messages = NOTICE;
SET search_path = public;

BEGIN;

-- Drop in dependency order (safe re-run)
DROP MATERIALIZED VIEW IF EXISTS salary_batch_summary_mv CASCADE;
DROP VIEW IF EXISTS suspicious_activity_view CASCADE;
DROP VIEW IF EXISTS daily_transaction_report CASCADE;
DROP VIEW IF EXISTS customer_balance_summary CASCADE;

DROP TABLE IF EXISTS salary_batch_runs CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS exchange_rates CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- 1) DDL: Core schema

CREATE TABLE customers (
    customer_id        SERIAL PRIMARY KEY,
    iin                CHAR(12) UNIQUE NOT NULL,
    full_name          TEXT NOT NULL,
    phone              TEXT,
    email              TEXT,
    status             TEXT NOT NULL CHECK (status IN ('active','blocked','frozen')),
    created_at         TIMESTAMP NOT NULL DEFAULT now(),
    daily_limit_kzt    NUMERIC(18,2) NOT NULL DEFAULT 1000000
);

CREATE TABLE accounts (
    account_id      SERIAL PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(customer_id),
    account_number  TEXT UNIQUE NOT NULL, -- IBAN-like format
    currency        TEXT NOT NULL CHECK (currency IN ('KZT','USD','EUR','RUB')),
    balance         NUMERIC(18,2) NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    opened_at       TIMESTAMP NOT NULL DEFAULT now(),
    closed_at       TIMESTAMP
);

CREATE TABLE exchange_rates (
    rate_id        SERIAL PRIMARY KEY,
    from_currency  TEXT NOT NULL CHECK (from_currency IN ('KZT','USD','EUR','RUB')),
    to_currency    TEXT NOT NULL CHECK (to_currency   IN ('KZT','USD','EUR','RUB')),
    rate           NUMERIC(18,6) NOT NULL CHECK (rate > 0),
    valid_from     TIMESTAMP NOT NULL,
    valid_to       TIMESTAMP NOT NULL,
    CHECK (valid_to > valid_from)
);

CREATE TABLE transactions (
    transaction_id    SERIAL PRIMARY KEY,
    from_account_id   INT REFERENCES accounts(account_id),
    to_account_id     INT REFERENCES accounts(account_id),
    amount            NUMERIC(18,2) NOT NULL CHECK (amount > 0), -- in transaction currency (p_currency)
    currency          TEXT NOT NULL CHECK (currency IN ('KZT','USD','EUR','RUB')),
    exchange_rate     NUMERIC(18,6), -- currency -> KZT rate used at time of tx
    amount_kzt        NUMERIC(18,2), -- computed KZT equivalent
    type              TEXT NOT NULL CHECK (type IN ('transfer','deposit','withdrawal','salary')),
    status            TEXT NOT NULL CHECK (status IN ('pending','completed','failed','reversed')),
    created_at        TIMESTAMP NOT NULL DEFAULT now(),
    completed_at      TIMESTAMP,
    description       TEXT
);

CREATE TABLE audit_log (
    log_id       SERIAL PRIMARY KEY,
    table_name   TEXT NOT NULL,
    record_id    INT,
    action       TEXT NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE','FAILED','INFO')),
    old_values   JSONB,
    new_values   JSONB,
    changed_by   TEXT NOT NULL DEFAULT current_user,
    changed_at   TIMESTAMP NOT NULL DEFAULT now(),
    ip_address   TEXT
);

-- Salary batch run log (needed to build a materialized summary report)
CREATE TABLE salary_batch_runs (
    batch_id              SERIAL PRIMARY KEY,
    company_account_id    INT NOT NULL REFERENCES accounts(account_id),
    started_at            TIMESTAMP NOT NULL DEFAULT now(),
    finished_at           TIMESTAMP,
    total_requested_kzt   NUMERIC(18,2) NOT NULL DEFAULT 0,
    successful_count      INT NOT NULL DEFAULT 0,
    failed_count          INT NOT NULL DEFAULT 0,
    failed_details        JSONB NOT NULL DEFAULT '[]'::jsonb
);

COMMIT;

-- 2) Helpers: FX + audit logger

CREATE OR REPLACE FUNCTION fx_rate(p_from TEXT, p_to TEXT, p_at TIMESTAMP DEFAULT now())
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    r_direct NUMERIC;
    r_from_kzt NUMERIC;
    r_kzt_to NUMERIC;
BEGIN
    IF p_from = p_to THEN
        RETURN 1;
    END IF;

    -- Try direct rate
    SELECT er.rate INTO r_direct
    FROM exchange_rates er
    WHERE er.from_currency = p_from
      AND er.to_currency   = p_to
      AND p_at BETWEEN er.valid_from AND er.valid_to
    ORDER BY er.valid_from DESC
    LIMIT 1;

    IF r_direct IS NOT NULL THEN
        RETURN r_direct;
    END IF;

    -- Fallback via KZT
    IF p_from <> 'KZT' THEN
        SELECT er.rate INTO r_from_kzt
        FROM exchange_rates er
        WHERE er.from_currency = p_from
          AND er.to_currency   = 'KZT'
          AND p_at BETWEEN er.valid_from AND er.valid_to
        ORDER BY er.valid_from DESC
        LIMIT 1;
    ELSE
        r_from_kzt := 1;
    END IF;

    IF p_to <> 'KZT' THEN
        SELECT er.rate INTO r_kzt_to
        FROM exchange_rates er
        WHERE er.from_currency = 'KZT'
          AND er.to_currency   = p_to
          AND p_at BETWEEN er.valid_from AND er.valid_to
        ORDER BY er.valid_from DESC
        LIMIT 1;
    ELSE
        r_kzt_to := 1;
    END IF;

    IF r_from_kzt IS NULL OR r_kzt_to IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = format('E_FX01: Missing FX path for %s -> %s at %s', p_from, p_to, p_at);
    END IF;

    RETURN r_from_kzt * r_kzt_to;
END;
$$;

CREATE OR REPLACE PROCEDURE audit_write(
    p_table_name TEXT,
    p_record_id  INT,
    p_action     TEXT,
    p_old        JSONB,
    p_new        JSONB,
    p_ip         TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_log(table_name, record_id, action, old_values, new_values, changed_by, ip_address)
    VALUES (p_table_name, p_record_id, p_action, p_old, p_new, current_user, p_ip);
END;
$$;

-- 3) Sample Data (10+ meaningful records)

BEGIN;

-- Customers (10)
INSERT INTO customers(iin, full_name, phone, email, status, daily_limit_kzt)
VALUES
('990101123456','Aruzhan Sarsembayeva','+7 701 111 1111','aruzhan@mail.kz','active', 1500000),
('980202234567','Daniyar Nurgaliyev','+7 702 222 2222','daniyar@mail.kz','active', 1000000),
('970303345678','Madina Tulegenova','+7 703 333 3333','madina@mail.kz','active', 800000),
('960404456789','Timur Zhaksylyk','+7 704 444 4444','timur@mail.kz','blocked', 500000),
('950505567890','Aigerim Bekova','+7 705 555 5555','aigerim@mail.kz','active', 2000000),
('940606678901','Rustem Orazbay','+7 706 666 6666','rustem@mail.kz','frozen', 700000),
('930707789012','Zarina Alimova','+7 707 777 7777','zarina@mail.kz','active', 1200000),
('920808890123','Ilyas Kassym','+7 708 888 8888','ilyas@mail.kz','active', 900000),
('910909901234','Dana Asylbek','+7 709 999 9999','dana@mail.kz','active', 600000),
('900101012345','Company: QazTech LLP','+7 700 000 0000','payroll@qaztech.kz','active', 999999999);

-- Accounts (>=10; here 14)
INSERT INTO accounts(customer_id, account_number, currency, balance, is_active)
VALUES
(1,'KZ11KFBK000000000001','KZT',  850000, true),
(1,'KZ11KFBK000000000002','USD',    1200, true),
(2,'KZ11KFBK000000000003','KZT',  250000, true),
(2,'KZ11KFBK000000000004','EUR',     900, true),
(3,'KZ11KFBK000000000005','KZT',  125000, true),
(3,'KZ11KFBK000000000006','RUB',   70000, true),
(4,'KZ11KFBK000000000007','KZT',  900000, true), -- blocked customer
(5,'KZ11KFBK000000000008','KZT', 2300000, true),
(5,'KZ11KFBK000000000009','USD',    5000, true),
(6,'KZ11KFBK000000000010','KZT',  400000, true), -- frozen customer
(7,'KZ11KFBK000000000011','KZT',  310000, true),
(8,'KZ11KFBK000000000012','EUR',     250, true),
(9,'KZ11KFBK000000000013','KZT',   90000, true),
(10,'KZ11KFBK000000009999','KZT', 10000000, true); -- company payroll account

-- Exchange rates (>=10)
-- valid window: last week .. next week
INSERT INTO exchange_rates(from_currency,to_currency,rate,valid_from,valid_to)
VALUES
('USD','KZT', 510.000000, now() - interval '7 days', now() + interval '7 days'),
('EUR','KZT', 560.000000, now() - interval '7 days', now() + interval '7 days'),
('RUB','KZT',   5.600000, now() - interval '7 days', now() + interval '7 days'),
('KZT','USD', 1/510.000000, now() - interval '7 days', now() + interval '7 days'),
('KZT','EUR', 1/560.000000, now() - interval '7 days', now() + interval '7 days'),
('KZT','RUB', 1/5.600000,   now() - interval '7 days', now() + interval '7 days'),
('USD','EUR', 0.910000, now() - interval '7 days', now() + interval '7 days'),
('EUR','USD', 1/0.910000, now() - interval '7 days', now() + interval '7 days'),
('USD','RUB', 90.000000, now() - interval '7 days', now() + interval '7 days'),
('RUB','USD', 1/90.000000, now() - interval '7 days', now() + interval '7 days'),
('EUR','RUB', 98.000000, now() - interval '7 days', now() + interval '7 days'),
('RUB','EUR', 1/98.000000, now() - interval '7 days', now() + interval '7 days');

-- Seed some historical transactions (>=10; here 12)
INSERT INTO transactions(from_account_id,to_account_id,amount,currency,exchange_rate,amount_kzt,type,status,created_at,completed_at,description)
VALUES
(1,3, 50000,'KZT', fx_rate('KZT','KZT'), 50000,'transfer','completed', now()-interval '2 days', now()-interval '2 days'+interval '1 minute','rent split'),
(8,11,120000,'KZT', fx_rate('KZT','KZT'),120000,'transfer','completed', now()-interval '1 day',  now()-interval '1 day'+interval '2 minutes','family help'),
(9,13, 20000,'KZT', fx_rate('KZT','KZT'), 20000,'transfer','completed', now()-interval '1 day',  now()-interval '1 day'+interval '3 minutes','food'),
(1,5,  10000,'KZT', fx_rate('KZT','KZT'), 10000,'transfer','completed', now()-interval '3 hours', now()-interval '3 hours'+interval '1 minute','coffee'),
(3,5,   5000,'KZT', fx_rate('KZT','KZT'),  5000,'transfer','completed', now()-interval '2 hours', now()-interval '2 hours'+interval '1 minute','taxi'),
(2,5,   7000,'KZT', fx_rate('KZT','KZT'),  7000,'transfer','completed', now()-interval '90 minutes', now()-interval '90 minutes'+interval '1 minute','gift'),
(1,3,   3000,'KZT', fx_rate('KZT','KZT'),  3000,'transfer','completed', now()-interval '40 minutes', now()-interval '40 minutes'+interval '1 minute','snack'),
(1,3,   3100,'KZT', fx_rate('KZT','KZT'),  3100,'transfer','completed', now()-interval '39 minutes', now()-interval '39 minutes'+interval '1 minute','snack 2'),
(1,3,   3200,'KZT', fx_rate('KZT','KZT'),  3200,'transfer','completed', now()-interval '38 minutes', now()-interval '38 minutes'+interval '1 minute','snack 3'),
(1,3,   3300,'KZT', fx_rate('KZT','KZT'),  3300,'transfer','completed', now()-interval '37 minutes', now()-interval '37 minutes'+interval '1 minute','snack 4'),
(14,11,500000,'KZT',fx_rate('KZT','KZT'),500000,'transfer','completed', now()-interval '10 days', now()-interval '10 days'+interval '5 minutes','company charity'),
(14,1, 100000,'KZT',fx_rate('KZT','KZT'),100000,'transfer','completed', now()-interval '9 days',  now()-interval '9 days'+interval '5 minutes','bonus');

COMMIT;

-- 4) Task 1: process_transfer (ACID + locks + savepoints + error messages/codes + audit)

/*
Error codes (message prefix):
E001 account not found / inactive
E002 recipient not found / inactive
E003 sender customer not active
E004 insufficient balance
E005 daily limit exceeded
E006 missing FX
E007 invalid amount
*/

CREATE OR REPLACE PROCEDURE process_transfer(
    p_from_account_number TEXT,
    p_to_account_number   TEXT,
    p_amount              NUMERIC,
    p_currency            TEXT,
    p_description         TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from accounts%ROWTYPE;
    v_to   accounts%ROWTYPE;
    v_sender customers%ROWTYPE;

    v_rate_to_kzt NUMERIC;
    v_amount_kzt  NUMERIC;

    v_debit_in_from_currency NUMERIC;
    v_credit_in_to_currency  NUMERIC;

    v_used_today_kzt NUMERIC;
    v_limit_kzt NUMERIC;

    v_tx_id INT;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        CALL audit_write('transactions', NULL, 'FAILED', NULL,
            jsonb_build_object('code','E007','msg','Amount must be > 0','from',p_from_account_number,'to',p_to_account_number,'amount',p_amount,'currency',p_currency,'desc',p_description),
            NULL);
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E007: invalid amount';
    END IF;

    -- Lock accounts to prevent race conditions
    SELECT * INTO v_from
    FROM accounts
    WHERE account_number = p_from_account_number
      AND is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN
        CALL audit_write('transactions', NULL, 'FAILED', NULL,
            jsonb_build_object('code','E001','msg','Sender account not found or inactive','from',p_from_account_number),
            NULL);
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E001: sender account not found or inactive';
    END IF;

    SELECT * INTO v_to
    FROM accounts
    WHERE account_number = p_to_account_number
      AND is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN
        CALL audit_write('transactions', NULL, 'FAILED', NULL,
            jsonb_build_object('code','E002','msg','Recipient account not found or inactive','to',p_to_account_number),
            NULL);
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E002: recipient account not found or inactive';
    END IF;

    -- Lock sender customer row too (stability for status/limit)
    SELECT * INTO v_sender
    FROM customers
    WHERE customer_id = v_from.customer_id
    FOR UPDATE;

    IF v_sender.status <> 'active' THEN
        CALL audit_write('customers', v_sender.customer_id, 'FAILED', NULL,
            jsonb_build_object('code','E003','msg','Sender customer not active','status',v_sender.status,'iin',v_sender.iin),
            NULL);
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E003: sender customer status not active';
    END IF;

    -- FX for tx currency to KZT (for limits + reporting)
    BEGIN
        v_rate_to_kzt := fx_rate(p_currency, 'KZT', now());
    EXCEPTION WHEN OTHERS THEN
        CALL audit_write('exchange_rates', NULL, 'FAILED', NULL,
            jsonb_build_object('code','E006','msg','Missing FX to KZT','currency',p_currency,'err',SQLERRM),
            NULL);
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E006: missing FX';
    END;

    v_amount_kzt := round(p_amount * v_rate_to_kzt, 2);
    v_limit_kzt  := v_sender.daily_limit_kzt;

    -- Daily limit: sum of today's completed outgoing transfers (customer-wide) + current <= limit
    SELECT COALESCE(SUM(t.amount_kzt),0)
    INTO v_used_today_kzt
    FROM transactions t
    JOIN accounts a ON a.account_id = t.from_account_id
    WHERE a.customer_id = v_sender.customer_id
      AND t.status = 'completed'
      AND t.type IN ('transfer','withdrawal')  -- outgoing only
      AND t.created_at::date = current_date;

    IF v_used_today_kzt + v_amount_kzt > v_limit_kzt THEN
        CALL audit_write('transactions', NULL, 'FAILED', NULL,
            jsonb_build_object('code','E005','msg','Daily limit exceeded',
                'used_today_kzt',v_used_today_kzt,'attempt_kzt',v_amount_kzt,'limit_kzt',v_limit_kzt),
            NULL);
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E005: daily limit exceeded';
    END IF;

    -- Convert tx amount into from/to account currencies for balance movements
    -- debit(from) = amount * fx_rate(tx_currency -> from_currency)
    -- credit(to)  = amount * fx_rate(tx_currency -> to_currency)
    v_debit_in_from_currency := round(p_amount * fx_rate(p_currency, v_from.currency, now()), 2);
    v_credit_in_to_currency  := round(p_amount * fx_rate(p_currency, v_to.currency,   now()), 2);

    IF v_from.balance < v_debit_in_from_currency THEN
        CALL audit_write('accounts', v_from.account_id, 'FAILED', NULL,
            jsonb_build_object('code','E004','msg','Insufficient funds',
                'balance',v_from.balance,'need',v_debit_in_from_currency,'currency',v_from.currency),
            NULL);
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E004: insufficient funds';
    END IF;

    -- Create transaction row as pending first (audit trail even if later steps fail)
    INSERT INTO transactions(from_account_id,to_account_id,amount,currency,exchange_rate,amount_kzt,type,status,description)
    VALUES (v_from.account_id, v_to.account_id, p_amount, p_currency, v_rate_to_kzt, v_amount_kzt, 'transfer', 'pending', p_description)
    RETURNING transaction_id INTO v_tx_id;

    CALL audit_write('transactions', v_tx_id, 'INFO', NULL,
        jsonb_build_object('stage','created_pending','from',p_from_account_number,'to',p_to_account_number,
            'amount',p_amount,'currency',p_currency,'amount_kzt',v_amount_kzt,
            'debit',v_debit_in_from_currency,'debit_currency',v_from.currency,
            'credit',v_credit_in_to_currency,'credit_currency',v_to.currency),
        NULL);

    -- Savepoint: partial rollback scenario (keep pending tx row and audit, but rollback balance updates)
    SAVEPOINT sp_balance;

    UPDATE accounts
    SET balance = balance - v_debit_in_from_currency
    WHERE account_id = v_from.account_id;

    UPDATE accounts
    SET balance = balance + v_credit_in_to_currency
    WHERE account_id = v_to.account_id;

    UPDATE transactions
    SET status='completed', completed_at=now()
    WHERE transaction_id = v_tx_id;

    CALL audit_write('transactions', v_tx_id, 'UPDATE', NULL,
        jsonb_build_object('stage','completed','status','completed','completed_at',now()),
        NULL);

EXCEPTION WHEN OTHERS THEN
    -- Roll back balance changes but keep pending/failed tx row + audit trail
    BEGIN
        ROLLBACK TO SAVEPOINT sp_balance;
    EXCEPTION WHEN OTHERS THEN
        -- if savepoint not created, ignore
        NULL;
    END;

    IF v_tx_id IS NOT NULL THEN
        UPDATE transactions
        SET status='failed', completed_at=now()
        WHERE transaction_id = v_tx_id;

        CALL audit_write('transactions', v_tx_id, 'FAILED', NULL,
            jsonb_build_object('stage','failed','err',SQLERRM),
            NULL);
    ELSE
        CALL audit_write('transactions', NULL, 'FAILED', NULL,
            jsonb_build_object('stage','failed_before_tx_row','err',SQLERRM),
            NULL);
    END IF;

    RAISE;
END;
$$;

-- 5) Task 4: process_salary_batch
-- Requirements covered:
-- - params: company_account_number, JSONB array [{iin, amount, description}, ...]
-- - validate total batch vs company balance BEFORE starting
-- - single transaction, savepoints for partial completion
-- - advisory lock to prevent concurrent batch for same company
-- - bypass daily limits (salary exception)
-- - update balances atomically at the end (single updates, not one-by-one)
-- - return detailed results: successful_count, failed_count, failed_details (JSONB)
-- - generate summary report viewable through a materialized view

CREATE OR REPLACE PROCEDURE process_salary_batch(
    p_company_account_number TEXT,
    p_payments JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_company accounts%ROWTYPE;
    v_total_kzt NUMERIC := 0;

    v_item JSONB;
    v_iin TEXT;
    v_amount NUMERIC;
    v_desc TEXT;

    v_recipient_customer_id INT;
    v_recipient_account_id INT;
    v_recipient_account_number TEXT;

    v_success INT := 0;
    v_failed  INT := 0;
    v_failed_details JSONB := '[]'::jsonb;

    v_batch_id INT;

    -- temp accumulation
    v_company_debit_kzt NUMERIC := 0;

BEGIN
    -- basic validation
    IF jsonb_typeof(p_payments) <> 'array' THEN
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E_SAL01: payments must be a JSONB array';
    END IF;

    -- prevent concurrent batches for same company account
    PERFORM pg_advisory_lock(hashtext(p_company_account_number));

    -- lock company account row
    SELECT * INTO v_company
    FROM accounts
    WHERE account_number = p_company_account_number
      AND is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM pg_advisory_unlock(hashtext(p_company_account_number));
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E_SAL02: company account not found or inactive';
    END IF;

    IF v_company.currency <> 'KZT' THEN
        PERFORM pg_advisory_unlock(hashtext(p_company_account_number));
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E_SAL03: company account must be KZT for salary batch (simplified rule)';
    END IF;

    -- Create run record early (audit trail)
    INSERT INTO salary_batch_runs(company_account_id, started_at)
    VALUES (v_company.account_id, now())
    RETURNING batch_id INTO v_batch_id;

    CALL audit_write('salary_batch_runs', v_batch_id, 'INSERT', NULL,
        jsonb_build_object('stage','started','company_account',p_company_account_number,'payments_count',jsonb_array_length(p_payments)),
        NULL);

    -- Temp table to accumulate valid recipient credits (atomic update later)
    CREATE TEMP TABLE tmp_salary_valid(
        recipient_account_id INT PRIMARY KEY,
        recipient_account_number TEXT,
        iin TEXT,
        amount_kzt NUMERIC(18,2),
        description TEXT
    ) ON COMMIT DROP;

    -- Pre-calc total requested in KZT + validate amounts shape
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        v_amount := NULLIF(v_item->>'amount','')::numeric;
        IF v_amount IS NULL OR v_amount <= 0 THEN
            v_failed := v_failed + 1;
            v_failed_details := v_failed_details || jsonb_build_object(
                'iin', COALESCE(v_item->>'iin',''),
                'amount', COALESCE(v_item->>'amount',''),
                'error', 'E_SAL04: invalid amount'
            );
        ELSE
            v_total_kzt := v_total_kzt + round(v_amount,2);
        END IF;
    END LOOP;

    -- Validate company balance BEFORE processing
    IF v_total_kzt > v_company.balance THEN
        UPDATE salary_batch_runs
        SET finished_at = now(),
            total_requested_kzt = v_total_kzt,
            successful_count = 0,
            failed_count = jsonb_array_length(p_payments),
            failed_details = jsonb_build_object('error','E_SAL05: insufficient company balance for total batch')
        WHERE batch_id = v_batch_id;

        CALL audit_write('salary_batch_runs', v_batch_id, 'FAILED', NULL,
            jsonb_build_object('stage','rejected','reason','insufficient_balance','needed',v_total_kzt,'balance',v_company.balance),
            NULL);

        PERFORM pg_advisory_unlock(hashtext(p_company_account_number));
        RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E_SAL05: insufficient company balance for total batch';
    END IF;

    -- Now validate each payment individually (savepoint allows continue)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        SAVEPOINT sp_one;

        BEGIN
            v_iin  := v_item->>'iin';
            v_amount := round((v_item->>'amount')::numeric, 2);
            v_desc := COALESCE(v_item->>'description','salary');

            IF v_iin IS NULL OR length(v_iin) <> 12 THEN
                RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E_SAL06: invalid iin';
            END IF;

            IF v_amount <= 0 THEN
                RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E_SAL04: invalid amount';
            END IF;

            -- Find recipient (must have active KZT account)
            SELECT c.customer_id INTO v_recipient_customer_id
            FROM customers c
            WHERE c.iin = v_iin;

            IF v_recipient_customer_id IS NULL THEN
                RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E_SAL07: recipient customer not found';
            END IF;

            SELECT a.account_id, a.account_number
            INTO v_recipient_account_id, v_recipient_account_number
            FROM accounts a
            WHERE a.customer_id = v_recipient_customer_id
              AND a.currency = 'KZT'
              AND a.is_active = true
            ORDER BY a.account_id
            LIMIT 1
            FOR UPDATE;

            IF v_recipient_account_id IS NULL THEN
                RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='E_SAL08: recipient KZT account not found or inactive';
            END IF;

            -- Store valid line (avoid duplicates by summing later)
            INSERT INTO tmp_salary_valid(recipient_account_id, recipient_account_number, iin, amount_kzt, description)
            VALUES (v_recipient_account_id, v_recipient_account_number, v_iin, v_amount, v_desc)
            ON CONFLICT (recipient_account_id)
            DO UPDATE SET amount_kzt = tmp_salary_valid.amount_kzt + EXCLUDED.amount_kzt;

            v_success := v_success + 1;

        EXCEPTION WHEN OTHERS THEN
            ROLLBACK TO SAVEPOINT sp_one;
            v_failed := v_failed + 1;
            v_failed_details := v_failed_details || jsonb_build_object(
                'iin', COALESCE(v_item->>'iin',''),
                'amount', COALESCE(v_item->>'amount',''),
                'error', SQLERRM
            );
        END;
    END LOOP;

    -- Atomic balances update at end (NOT one-by-one):
    -- 1) company debit = sum(valid)
    SELECT COALESCE(SUM(amount_kzt),0) INTO v_company_debit_kzt FROM tmp_salary_valid;

    IF v_company_debit_kzt > 0 THEN
        -- debit company (one statement)
        UPDATE accounts
        SET balance = balance - v_company_debit_kzt
        WHERE account_id = v_company.account_id;

        -- credit recipients (one statement using derived aggregation)
        UPDATE accounts a
        SET balance = a.balance + v.sum_amount
        FROM (
            SELECT recipient_account_id, SUM(amount_kzt) AS sum_amount
            FROM tmp_salary_valid
            GROUP BY recipient_account_id
        ) v
        WHERE a.account_id = v.recipient_account_id;

        -- insert completed salary transactions for each valid recipient
        INSERT INTO transactions(from_account_id,to_account_id,amount,currency,exchange_rate,amount_kzt,type,status,created_at,completed_at,description)
        SELECT
            v_company.account_id,
            t.recipient_account_id,
            t.amount_kzt,
            'KZT',
            1,
            t.amount_kzt,
            'salary',
            'completed',
            now(),
            now(),
            t.description
        FROM tmp_salary_valid t;
    END IF;

    UPDATE salary_batch_runs
    SET finished_at = now(),
        total_requested_kzt = v_total_kzt,
        successful_count = v_success,
        failed_count = v_failed,
        failed_details = v_failed_details
    WHERE batch_id = v_batch_id;

    CALL audit_write('salary_batch_runs', v_batch_id, 'UPDATE', NULL,
        jsonb_build_object('stage','finished','total_requested_kzt',v_total_kzt,'company_debited_kzt',v_company_debit_kzt,
            'success',v_success,'failed',v_failed,'failed_details',v_failed_details),
        NULL);

    PERFORM pg_advisory_unlock(hashtext(p_company_account_number));

    -- Return-style output via NOTICE (since it's a PROCEDURE)
    RAISE NOTICE 'Salary batch % done. success=%, failed=%, failed_details=%',
        v_batch_id, v_success, v_failed, v_failed_details;

END;
$$;

-- 6) Task 2: Views for reporting

-- View 1: customer_balance_summary
-- - all accounts and balances
-- - total balance in KZT
-- - daily limit utilization %
-- - rank customers by total balance (window)
CREATE OR REPLACE VIEW customer_balance_summary AS
WITH acct AS (
    SELECT
        c.customer_id,
        c.full_name,
        c.iin,
        c.status,
        c.daily_limit_kzt,
        a.account_id,
        a.account_number,
        a.currency,
        a.balance,
        round(a.balance * fx_rate(a.currency,'KZT',now()),2) AS balance_kzt
    FROM customers c
    JOIN accounts a ON a.customer_id = c.customer_id
),
tot AS (
    SELECT
        customer_id,
        round(SUM(balance_kzt),2) AS total_balance_kzt
    FROM acct
    GROUP BY customer_id
),
used AS (
    SELECT
        c.customer_id,
        COALESCE(SUM(t.amount_kzt),0) AS used_today_kzt
    FROM customers c
    LEFT JOIN accounts a ON a.customer_id = c.customer_id
    LEFT JOIN transactions t ON t.from_account_id = a.account_id
        AND t.status='completed'
        AND t.type IN ('transfer','withdrawal')
        AND t.created_at::date = current_date
    GROUP BY c.customer_id
)
SELECT
    a.customer_id,
    a.full_name,
    a.iin,
    a.status,
    a.account_number,
    a.currency,
    a.balance,
    a.balance_kzt,
    t.total_balance_kzt,
    round((u.used_today_kzt / NULLIF(a.daily_limit_kzt,0)) * 100, 2) AS daily_limit_utilization_percent,
    RANK() OVER (ORDER BY t.total_balance_kzt DESC) AS rank_by_total_balance_kzt
FROM acct a
JOIN tot t USING(customer_id)
JOIN used u USING(customer_id);

-- View 2: daily_transaction_report
-- - aggregate by date and type
-- - total volume, count, avg
-- - running totals (window)
-- - day-over-day growth %
CREATE OR REPLACE VIEW daily_transaction_report AS
WITH agg AS (
    SELECT
        created_at::date AS tx_date,
        type,
        COUNT(*) AS tx_count,
        round(SUM(amount_kzt),2) AS total_volume_kzt,
        round(AVG(amount_kzt),2) AS avg_amount_kzt
    FROM transactions
    WHERE status='completed'
    GROUP BY created_at::date, type
)
SELECT
    tx_date,
    type,
    tx_count,
    total_volume_kzt,
    avg_amount_kzt,
    round(SUM(total_volume_kzt) OVER (PARTITION BY type ORDER BY tx_date),2) AS running_total_kzt,
    round(
        (total_volume_kzt - LAG(total_volume_kzt) OVER (PARTITION BY type ORDER BY tx_date))
        / NULLIF(LAG(total_volume_kzt) OVER (PARTITION BY type ORDER BY tx_date),0) * 100
    ,2) AS day_over_day_growth_percent
FROM agg
ORDER BY tx_date, type;

-- View 3: suspicious_activity_view (SECURITY BARRIER)
-- - over 5,000,000 KZT equivalent
-- - customers with >10 transactions in single hour
-- - rapid sequential transfers (same sender, <1 minute apart)
CREATE OR REPLACE VIEW suspicious_activity_view
WITH (security_barrier = true) AS
WITH base AS (
    SELECT
        t.*,
        a_from.customer_id AS sender_customer_id
    FROM transactions t
    LEFT JOIN accounts a_from ON a_from.account_id = t.from_account_id
),
hour_counts AS (
    SELECT
        sender_customer_id,
        date_trunc('hour', created_at) AS hr,
        COUNT(*) AS cnt
    FROM base
    WHERE status='completed'
    GROUP BY sender_customer_id, date_trunc('hour', created_at)
),
rapid AS (
    SELECT
        b.transaction_id,
        EXISTS (
            SELECT 1
            FROM base b2
            WHERE b2.from_account_id = b.from_account_id
              AND b2.status='completed'
              AND b2.transaction_id <> b.transaction_id
              AND b2.created_at BETWEEN b.created_at - interval '1 minute' AND b.created_at
        ) AS is_rapid
    FROM base b
)
SELECT
    b.transaction_id,
    b.created_at,
    b.from_account_id,
    b.to_account_id,
    b.amount,
    b.currency,
    b.amount_kzt,
    b.type,
    b.status,
    b.description,
    -- reasons as a compact array
    ARRAY_REMOVE(ARRAY[
        CASE WHEN b.amount_kzt > 5000000 THEN 'OVER_5M_KZT' END,
        CASE WHEN hc.cnt > 10 THEN 'MORE_THAN_10_PER_HOUR' END,
        CASE WHEN r.is_rapid THEN 'RAPID_SEQUENTIAL_LT_1MIN' END
    ], NULL) AS reasons
FROM base b
LEFT JOIN hour_counts hc
  ON hc.sender_customer_id = b.sender_customer_id
 AND hc.hr = date_trunc('hour', b.created_at)
LEFT JOIN rapid r ON r.transaction_id = b.transaction_id
WHERE
    b.status='completed'
    AND (
        b.amount_kzt > 5000000
        OR hc.cnt > 10
        OR r.is_rapid = true
    );

-- Materialized summary view for salary batches
CREATE MATERIALIZED VIEW salary_batch_summary_mv AS
SELECT
    s.batch_id,
    a.account_number AS company_account_number,
    s.started_at,
    s.finished_at,
    s.total_requested_kzt,
    s.successful_count,
    s.failed_count,
    s.failed_details
FROM salary_batch_runs s
JOIN accounts a ON a.account_id = s.company_account_id;

-- 7) Task 3: Index Strategy (5+ types + covering + partial + expression + GIN)

-- 1) B-tree (frequent lookups)
CREATE INDEX idx_accounts_account_number_btree ON accounts(account_number);

-- 2) Composite B-tree for common filters / reporting
CREATE INDEX idx_transactions_date_type_status ON transactions(created_at, type, status);

-- 3) Covering index for frequent pattern (e.g., customer outgoing tx by date)
-- (Include to allow index-only scans)
CREATE INDEX idx_tx_from_date_cover
ON transactions(from_account_id, created_at)
INCLUDE (amount_kzt, status, type);

-- 4) Partial index for active accounts only
CREATE INDEX idx_accounts_active_only
ON accounts(customer_id, account_number)
WHERE is_active = true;

-- 5) Expression index for case-insensitive email search
CREATE INDEX idx_customers_lower_email
ON customers (LOWER(email));

-- 6) GIN index on audit_log JSONB columns
CREATE INDEX idx_audit_log_new_values_gin
ON audit_log USING gin (new_values);

CREATE INDEX idx_audit_log_old_values_gin
ON audit_log USING gin (old_values);

-- 7) Hash index (different type)
CREATE INDEX idx_customers_iin_hash
ON customers USING hash (iin);

-- Extra: Exchange rates access
CREATE INDEX idx_exchange_rates_pair_window
ON exchange_rates(from_currency, to_currency, valid_from DESC);

-- 8) EXPLAIN ANALYZE (run after load; keep in file as required)

/*
Run these after everything is created + data exists.
They document performance and index usage.

NOTE: EXPLAIN ANALYZE executes the query; safe here because they are SELECTs.
*/

EXPLAIN ANALYZE
SELECT * FROM accounts WHERE account_number = 'KZ11KFBK000000000001';

EXPLAIN ANALYZE
SELECT *
FROM transactions
WHERE from_account_id = 1
  AND created_at >= now() - interval '7 days'
ORDER BY created_at DESC
LIMIT 20;

EXPLAIN ANALYZE
SELECT * FROM customer_balance_summary ORDER BY rank_by_total_balance_kzt LIMIT 10;

EXPLAIN ANALYZE
SELECT * FROM daily_transaction_report WHERE tx_date >= current_date - 7 ORDER BY tx_date;

EXPLAIN ANALYZE
SELECT * FROM audit_log WHERE new_values @> '{"stage":"finished"}';

-- 9) Test cases (successful + failure scenarios)

-- Success: same-currency transfer
CALL process_transfer('KZ11KFBK000000000001','KZ11KFBK000000000003', 10000, 'KZT', 'test success KZT');

-- Success: tx currency differs, balances move via FX conversions
CALL process_transfer('KZ11KFBK000000000002','KZ11KFBK000000000004', 50, 'USD', 'test success USD->EUR account credit');

-- Fail: blocked customer
-- (customer 4 is blocked, account 7 belongs to them)
DO $$
BEGIN
  BEGIN
    CALL process_transfer('KZ11KFBK000000000007','KZ11KFBK000000000003', 1000, 'KZT', 'should fail: blocked');
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected failure: %', SQLERRM;
  END;
END $$;

-- Fail: insufficient funds
DO $$
BEGIN
  BEGIN
    CALL process_transfer('KZ11KFBK000000000005','KZ11KFBK000000000003', 999999999, 'KZT', 'should fail: insufficient');
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected failure: %', SQLERRM;
  END;
END $$;

-- Salary batch: mix success + failures (invalid IIN / missing user)
CALL process_salary_batch(
  'KZ11KFBK000000009999',
  '[
     {"iin":"990101123456","amount":120000,"description":"Salary A"},
     {"iin":"980202234567","amount":150000,"description":"Salary B"},
     {"iin":"000000000000","amount":100000,"description":"Invalid IIN"},
     {"iin":"111111111111","amount":50000,"description":"Unknown customer"},
     {"iin":"970303345678","amount":90000,"description":"Salary C"}
   ]'::jsonb
);

-- Refresh materialized view after batch run(s)
REFRESH MATERIALIZED VIEW salary_batch_summary_mv;

-- 10) Concurrency demo (two sessions)

/*
SESSION 1:
-----------
BEGIN;
-- Lock sender account row:
SELECT * FROM accounts WHERE account_number='KZ11KFBK000000000001' FOR UPDATE;
-- keep transaction open (don’t commit yet)

SESSION 2 (while session 1 holds lock):
-------------------------------------
BEGIN;
CALL process_transfer('KZ11KFBK000000000001','KZ11KFBK000000000003', 1000, 'KZT', 'concurrency test');
-- This will WAIT until Session 1 releases lock
COMMIT;

SESSION 1:
----------
COMMIT;
*/

-- Done

-- Quick sanity queries
-- SELECT * FROM suspicious_activity_view;
-- SELECT * FROM salary_batch_summary_mv ORDER BY batch_id DESC;
-- SELECT * FROM audit_log ORDER BY changed_at DESC LIMIT 50;
