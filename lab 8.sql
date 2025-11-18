
-- Lab 8

-- Part 2: Basic Indexes

-- 2.1 Simple B-tree index on salary
CREATE INDEX emp_salary_idx ON employees(salary);

-- Optional check
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'employees';

-- 2.2 Index on foreign key dept_id
CREATE INDEX emp_dept_idx ON employees(dept_id);

-- Optional test
-- SELECT * FROM employees WHERE dept_id = 101;

-- 2.3 View all indexes in public schema (optional helper)
-- SELECT 
--     tablename,
--     indexname,
--     indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
-- ORDER BY tablename, indexname;

-- Part 3: Multicolumn Indexes

-- 3.1 Multicolumn index (dept_id, salary)
CREATE INDEX emp_dept_salary_idx ON employees(dept_id, salary);

-- 3.2 Multicolumn index with reversed order
CREATE INDEX emp_salary_dept_idx ON employees(salary, dept_id);

-- Optional test
-- SELECT emp_name, salary
-- FROM employees
-- WHERE dept_id = 101 AND salary > 52000;

-- SELECT * FROM employees
-- WHERE dept_id = 102 AND salary > 50000;

-- SELECT * FROM employees
-- WHERE salary > 50000 AND dept_id = 102;

-- Part 4: Unique Indexes

-- 4.1 Add email column and populate
ALTER TABLE employees ADD COLUMN IF NOT EXISTS email VARCHAR(100);

UPDATE employees SET email = 'john.smith@company.com'   WHERE emp_id = 1;
UPDATE employees SET email = 'jane.doe@company.com'     WHERE emp_id = 2;
UPDATE employees SET email = 'mike.johnson@company.com' WHERE emp_id = 3;
UPDATE employees SET email = 'sarah.williams@company.com' WHERE emp_id = 4;
UPDATE employees SET email = 'tom.brown@company.com'    WHERE emp_id = 5;

-- Unique index on email
CREATE UNIQUE INDEX emp_email_unique_idx ON employees(email);

-- supposed to fail:
-- INSERT INTO employees (emp_id, emp_name, dept_id, salary, email)
-- VALUES (6, 'New Employee', 101, 55000, 'john.smith@company.com');

-- 4.2 UNIQUE constraint on phone
ALTER TABLE employees ADD COLUMN IF NOT EXISTS phone VARCHAR(20) UNIQUE;

-- Optional check
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'employees' AND indexname LIKE '%phone%';

-- Part 5: Indexes and Sorting

-- 5.1 Index optimized for descending salary
CREATE INDEX emp_salary_desc_idx ON employees(salary DESC);

-- ptional test
-- SELECT emp_name, salary
-- FROM employees
-- ORDER BY salary DESC;

-- 5.2 Index with NULLS FIRST on projects.budget
CREATE INDEX proj_budget_nulls_first_idx ON projects(budget NULLS FIRST);

-- Optional test
-- SELECT proj_name, budget 
-- FROM projects
-- ORDER BY budget NULLS FIRST;

-- Part 6: Expression / Function Indexes

-- 6.1 Index for case-insensitive name search
CREATE INDEX emp_name_lower_idx ON employees(LOWER(emp_name));

-- Optional test
-- SELECT * FROM employees
-- WHERE LOWER(emp_name) = 'john smith';

-- 6.2 Index on calculated hire year
ALTER TABLE employees ADD COLUMN IF NOT EXISTS hire_date DATE;

UPDATE employees SET hire_date = '2020-01-15' WHERE emp_id = 1;
UPDATE employees SET hire_date = '2019-06-20' WHERE emp_id = 2;
UPDATE employees SET hire_date = '2021-03-10' WHERE emp_id = 3;
UPDATE employees SET hire_date = '2020-11-05' WHERE emp_id = 4;
UPDATE employees SET hire_date = '2018-08-25' WHERE emp_id = 5;

CREATE INDEX emp_hire_year_idx ON employees(EXTRACT(YEAR FROM hire_date));

-- test:
-- SELECT emp_name, hire_date
-- FROM employees
-- WHERE EXTRACT(YEAR FROM hire_date) = 2020;

-- Part 7: Managing Indexes

-- 7.1 Rename emp_salary_idx -> employees_salary_index
ALTER INDEX emp_salary_idx RENAME TO employees_salary_index;

-- Optional verify:
-- SELECT indexname FROM pg_indexes WHERE tablename = 'employees';

-- 7.2 Drop redundant multicolumn index
DROP INDEX IF EXISTS emp_salary_dept_idx;

-- 7.3 Rebuild index
REINDEX INDEX employees_salary_index;

-- Part 8: Practical Scenarios

-- 8.1 Optimize slow query, partial index on salary
CREATE INDEX emp_salary_filter_idx
ON employees(salary)
WHERE salary > 50000;

-- 8.2 Partial index for high-budget projects
CREATE INDEX proj_high_budget_idx
ON projects(budget)
WHERE budget > 80000;

-- Optional test:
-- SELECT proj_name, budget
-- FROM projects
-- WHERE budget > 80000;

-- 8.3 EXPLAIN usage (run manually, not inside script if you want plans)
-- EXPLAIN SELECT * FROM employees WHERE salary > 52000;

-- Part 9: Index Types Comparison

-- NOTE: In your Lab 7, projects table uses project_name, not proj_name.
-- Adjust column name here if your schema differs.

-- 9.1 Hash index on departments.dept_name
CREATE INDEX dept_name_hash_idx
ON departments USING HASH (dept_name);

-- (Optional test)
-- SELECT * FROM departments WHERE dept_name = 'IT';

-- 9.2 B-tree and hash on project_name
CREATE INDEX proj_name_btree_idx
ON projects(project_name);

CREATE INDEX proj_name_hash_idx
ON projects USING HASH (project_name);

-- Optional tests:
-- SELECT * FROM projects WHERE project_name = 'Website Redesign';
-- SELECT * FROM projects WHERE project_name > 'Database';

-- Part 10: Cleanup and Best Practices

-- 10.1 Review all indexes (run manually)
-- SELECT 
--     schemaname,
--     tablename,
--     indexname,
--     pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
-- FROM pg_indexes
-- WHERE schemaname = 'public'
-- ORDER BY tablename, indexname;

-- 10.2 Drop unnecessary / duplicate indexes
DROP INDEX IF EXISTS proj_name_hash_idx;

-- Keep others depending on your use-case

-- 10.3 View documenting salary-related indexes
CREATE OR REPLACE VIEW index_documentation AS
SELECT 
    tablename,
    indexname,
    indexdef,
    'Improves salary-based queries' AS purpose
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE '%salary%';

-- Optional:
-- SELECT * FROM index_documentation;

-- Additional Challenges (optional)

-- 1. Index to find employees by hire month (month + year)
CREATE INDEX emp_hire_year_month_idx
ON employees(EXTRACT(YEAR FROM hire_date), EXTRACT(MONTH FROM hire_date));

-- Example query:
-- SELECT emp_name, hire_date
-- FROM employees
-- WHERE EXTRACT(YEAR FROM hire_date) = 2020
--   AND EXTRACT(MONTH FROM hire_date) = 1;

-- 2. Composite unique index on (dept_id, email)
-- Assumes email is NOT NULL or you accept uniqueness on non-null combos only
CREATE UNIQUE INDEX emp_dept_email_uidx
ON employees(dept_id, email);

-- 3. For EXPLAIN ANALYZE comparison, run manually, e.g.:
-- EXPLAIN ANALYZE
-- SELECT e.emp_name, e.salary, d.dept_name
-- FROM employees e
-- JOIN departments d ON e.dept_id = d.dept_id
-- WHERE e.salary > 50000
-- ORDER BY e.salary DESC;

-- 4. Covering index (includes all columns for a frequent query)
-- Example: query needs emp_name, salary, dept_id for salary filters
CREATE INDEX emp_salary_covering_idx
ON employees(salary, dept_id, emp_name);
