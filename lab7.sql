-- lab7

BEGIN;

-- Part 2
-- 2.1 employee_details: employees joined with departments; only assigned employees
CREATE OR REPLACE VIEW employee_details AS
SELECT 
    e.emp_id,
    e.emp_name,
    e.salary,
    d.dept_name,
    d.location
FROM employees e
JOIN departments d ON d.dept_id = e.dept_id;

-- 2.2 dept_statistics: include all departments (even those with 0 employees)
CREATE OR REPLACE VIEW dept_statistics AS
SELECT
    d.dept_id,
    d.dept_name,
    COUNT(e.emp_id)           AS employee_count,
    AVG(e.salary)             AS avg_salary,
    MAX(e.salary)             AS max_salary,
    MIN(e.salary)             AS min_salary
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name;

-- 2.3 project_overview: project info + dept info + team size (employees in that dept)
CREATE OR REPLACE VIEW project_overview AS
SELECT
    p.project_id,
    p.project_name,
    p.budget,
    d.dept_name,
    d.location,
    (SELECT COUNT(*) FROM employees e WHERE e.dept_id = d.dept_id) AS team_size
FROM projects p
LEFT JOIN departments d ON d.dept_id = p.dept_id;

-- 2.4 high_earners: employees with salary > 55,000
CREATE OR REPLACE VIEW high_earners AS
SELECT
    e.emp_name,
    e.salary,
    d.dept_name
FROM employees e
LEFT JOIN departments d ON d.dept_id = e.dept_id
WHERE e.salary > 55000;

-- Part 3

-- 3.1 Replace employee_details to include salary_grade
CREATE OR REPLACE VIEW employee_details AS
SELECT 
    e.emp_id,
    e.emp_name,
    e.salary,
    CASE 
        WHEN e.salary > 60000 THEN 'High'
        WHEN e.salary > 50000 THEN 'Medium'
        ELSE 'Standard'
    END AS salary_grade,
    d.dept_name,
    d.location
FROM employees e
JOIN departments d ON d.dept_id = e.dept_id;

-- 3.2 Rename high_earners to top_performers
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'high_earners') THEN
        EXECUTE 'ALTER VIEW high_earners RENAME TO top_performers';
    END IF;
END $$;

-- 3.3 Create then drop a temporary view for employees with salary < 50,000
CREATE OR REPLACE VIEW temp_view AS
SELECT * FROM employees WHERE salary < 50000;
DROP VIEW IF EXISTS temp_view;

-- Part 4

-- 4.1 Updatable view on employees
CREATE OR REPLACE VIEW employee_salaries AS
SELECT emp_id, emp_name, dept_id, salary
FROM employees;

-- 4.2 Update via the view
UPDATE employee_salaries
   SET salary = 52000
 WHERE emp_name = 'John Smith';

-- 4.3 Insert via the view
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM employees WHERE emp_id = 6) THEN
        INSERT INTO employee_salaries (emp_id, emp_name, dept_id, salary)
        VALUES (6, 'Alice Johnson', 102, 58000);
    END IF;
END $$;

-- 4.4 View with CHECK OPTION (IT-only employees)
DROP VIEW IF EXISTS it_employees;
CREATE VIEW it_employees AS
SELECT emp_id, emp_name, dept_id, salary
FROM employees
WHERE dept_id = 101
WITH LOCAL CHECK OPTION;

-- Part 5

-- 5.1 dept_summary_mv (WITH DATA)
DROP MATERIALIZED VIEW IF EXISTS dept_summary_mv;
CREATE MATERIALIZED VIEW dept_summary_mv AS
SELECT
    d.dept_id,
    d.dept_name,
    COALESCE(COUNT(e.emp_id), 0)                              AS total_employees,
    COALESCE(SUM(e.salary), 0)::numeric(12,2)                 AS total_salaries,
    COALESCE(COUNT(DISTINCT p.project_id), 0)                 AS total_projects,
    COALESCE(SUM(p.budget), 0)::numeric(12,2)                 AS total_project_budget
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
LEFT JOIN projects  p ON p.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
WITH DATA;

-- 5.2 Insert then observe before/after refresh
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM employees WHERE emp_id = 8) THEN
        INSERT INTO employees (emp_id, emp_name, dept_id, salary)
        VALUES (8, 'Charlie Brown', 101, 54000);
    END IF;
END $$;

-- 5.3 Unique index + CONCURRENT refresh
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_index i ON i.indexrelid = c.oid 
                   WHERE c.relname = 'dept_summary_mv_dept_id_uidx') THEN
        EXECUTE 'CREATE UNIQUE INDEX dept_summary_mv_dept_id_uidx ON dept_summary_mv (dept_id)';
    END IF;
END $$;

END;  
BEGIN;

-- 5.4 project_stats_mv WITH NO DATA
DROP MATERIALIZED VIEW IF EXISTS project_stats_mv;
CREATE MATERIALIZED VIEW project_stats_mv AS
SELECT 
    p.project_name,
    p.budget,
    d.dept_name,
    (SELECT COUNT(*) FROM employees e WHERE e.dept_id = d.dept_id) AS assigned_employees
FROM projects p
LEFT JOIN departments d ON d.dept_id = p.dept_id
WITH NO DATA;

-- Part 6: Database Roles

-- 6.1 Basic roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analyst') THEN
        CREATE ROLE analyst; -- no login
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'data_viewer') THEN
        CREATE ROLE data_viewer LOGIN PASSWORD 'viewer123';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'report_user') THEN
        CREATE ROLE report_user LOGIN PASSWORD 'report456';
    END IF;
END $$;

-- 6.2 Roles with attributes
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'db_creator') THEN
        CREATE ROLE db_creator LOGIN CREATEDB PASSWORD 'creator789';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'user_manager') THEN
        CREATE ROLE user_manager LOGIN CREATEROLE PASSWORD 'manager101';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_user') THEN
        CREATE ROLE admin_user SUPERUSER LOGIN PASSWORD 'admin999';
    END IF;
END $$;

-- 6.3 Grants
GRANT SELECT ON employees, departments, projects TO analyst;
GRANT ALL PRIVILEGES ON employee_details TO data_viewer;
GRANT SELECT, INSERT ON employees TO report_user;

-- 6.4 Group roles + members + object privileges
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hr_team') THEN
        CREATE ROLE hr_team;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'finance_team') THEN
        CREATE ROLE finance_team;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'it_team') THEN
        CREATE ROLE it_team;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hr_user1') THEN
        CREATE ROLE hr_user1 LOGIN PASSWORD 'hr001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hr_user2') THEN
        CREATE ROLE hr_user2 LOGIN PASSWORD 'hr002';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'finance_user1') THEN
        CREATE ROLE finance_user1 LOGIN PASSWORD 'fin001';
    END IF;
END $$;

GRANT hr_team TO hr_user1, hr_user2;
GRANT finance_team TO finance_user1;

GRANT SELECT, UPDATE ON employees TO hr_team;
GRANT SELECT ON dept_statistics TO finance_team;

-- 6.5 Revokes
REVOKE UPDATE ON employees FROM hr_team;
REVOKE hr_team FROM hr_user2;
REVOKE ALL PRIVILEGES ON employee_details FROM data_viewer;

-- 6.6 Modify role attributes
ALTER ROLE analyst LOGIN PASSWORD 'analyst123';
ALTER ROLE user_manager SUPERUSER;
ALTER ROLE analyst PASSWORD NULL;
ALTER ROLE data_viewer CONNECTION LIMIT 5;

-- Part 7: Advanced Role Management

-- 7.1 Role hierarchy
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'read_only') THEN
        CREATE ROLE read_only;
    END IF;
END $$;

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT SELECT ON TABLE public.%I TO read_only', r.tablename);
    END LOOP;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'junior_analyst') THEN
        CREATE ROLE junior_analyst LOGIN PASSWORD 'junior123';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'senior_analyst') THEN
        CREATE ROLE senior_analyst LOGIN PASSWORD 'senior123';
    END IF;
END $$;

GRANT read_only TO junior_analyst, senior_analyst;
GRANT INSERT, UPDATE ON employees TO senior_analyst;

-- 7.2 Object ownership transfers
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'project_manager') THEN
        CREATE ROLE project_manager LOGIN PASSWORD 'pm123';
    END IF;
END $$;

ALTER VIEW IF EXISTS dept_statistics OWNER TO project_manager;
ALTER TABLE IF EXISTS projects OWNER TO project_manager;

-- 7.3 Reassign and drop roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'temp_owner') THEN
        CREATE ROLE temp_owner LOGIN;
    END IF;
END $$;

DROP TABLE IF EXISTS temp_table;
CREATE TABLE temp_table (id INT);
ALTER TABLE temp_table OWNER TO temp_owner;

REASSIGN OWNED BY temp_owner TO postgres;
DROP OWNED BY temp_owner;
DROP ROLE IF EXISTS temp_owner;

-- 7.4 Row-level security style via role-specific views (no true RLS policy here)
CREATE OR REPLACE VIEW hr_employee_view AS
SELECT *
FROM employees
WHERE dept_id = 102;

GRANT SELECT ON hr_employee_view TO hr_team;

CREATE OR REPLACE VIEW finance_employee_view AS
SELECT emp_id, emp_name, salary
FROM employees;

GRANT SELECT ON finance_employee_view TO finance_team;

-- Part 8: Practical Scenarios

-- 8.1 Department dashboard view
CREATE OR REPLACE VIEW dept_dashboard AS
WITH emp_agg AS (
    SELECT d.dept_id,
           COUNT(e.emp_id) AS employee_count,
           ROUND(COALESCE(AVG(e.salary),0)::numeric, 2) AS avg_salary
    FROM departments d
    LEFT JOIN employees e ON e.dept_id = d.dept_id
    GROUP BY d.dept_id
),
proj_agg AS (
    SELECT d.dept_id,
           COUNT(p.project_id) AS active_projects,
           COALESCE(SUM(p.budget),0)::numeric(12,2) AS total_project_budget
    FROM departments d
    LEFT JOIN projects p ON p.dept_id = d.dept_id
    GROUP BY d.dept_id
)
SELECT 
    d.dept_name,
    d.location,
    ea.employee_count,
    ea.avg_salary,
    pa.active_projects,
    pa.total_project_budget,
    ROUND(
        CASE 
            WHEN ea.employee_count = 0 THEN 0
            ELSE (pa.total_project_budget / ea.employee_count)::numeric
        END
    , 2) AS budget_per_employee
FROM departments d
LEFT JOIN emp_agg ea ON ea.dept_id = d.dept_id
LEFT JOIN proj_agg pa ON pa.dept_id = d.dept_id;

-- 8.2 Audit view: add created_date + derived approval_status
ALTER TABLE IF EXISTS projects
    ADD COLUMN IF NOT EXISTS created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE OR REPLACE VIEW high_budget_projects AS
SELECT 
    p.project_name,
    p.budget,
    d.dept_name,
    p.created_date,
    CASE 
        WHEN p.budget > 150000 THEN 'Critical Review Required'
        WHEN p.budget > 100000 THEN 'Management Approval Needed'
        ELSE 'Standard Process'
    END AS approval_status
FROM projects p
LEFT JOIN departments d ON d.dept_id = p.dept_id
WHERE p.budget > 75000;

-- 8.3 Access Control System
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'viewer_role') THEN
        CREATE ROLE viewer_role;
    END IF;
END $$;

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN 
        (SELECT 'TABLE' AS kind, tablename AS name FROM pg_tables WHERE schemaname='public'
         UNION ALL
         SELECT 'VIEW', viewname FROM pg_views WHERE schemaname='public')
    LOOP
        IF r.kind = 'TABLE' THEN
            EXECUTE format('GRANT SELECT ON TABLE public.%I TO viewer_role', r.name);
        ELSE
            EXECUTE format('GRANT SELECT ON TABLE public.%I TO viewer_role', r.name);
        END IF;
    END LOOP;
END $$;


COMMIT;

