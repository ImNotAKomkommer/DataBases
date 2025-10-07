-- Part 1: Basic SELECT Queries

SELECT first_name || ' ' || last_name AS full_name,
       department,
       salary
FROM employees;

SELECT DISTINCT department
FROM employees;

SELECT project_name,
       budget,
       CASE
         WHEN budget > 150000 THEN 'Large'
         WHEN budget BETWEEN 100000 AND 150000 THEN 'Medium'
         ELSE 'Small'
       END AS budget_category
FROM projects;

SELECT first_name || ' ' || last_name AS full_name,
       COALESCE(email, 'No email provided') AS email_address
FROM employees;

-- Part 2: WHERE Clause and Comparisons

SELECT *
FROM employees
WHERE hire_date > '2020-01-01';

SELECT *
FROM employees
WHERE salary BETWEEN 60000 AND 70000;

SELECT *
FROM employees
WHERE last_name LIKE 'S%' OR last_name LIKE 'J%';

SELECT *
FROM employees
WHERE manager_id IS NOT NULL
  AND department = 'IT';

-- Part 3: String and Mathematical Functions

SELECT UPPER(first_name || ' ' || last_name) AS name_upper,
       LENGTH(last_name) AS last_name_length,
       SUBSTRING(email FROM 1 FOR 3) AS email_prefix
FROM employees;

SELECT first_name || ' ' || last_name AS full_name,
       salary * 12 AS annual_salary,
       ROUND(salary / 12, 2) AS monthly_salary,
       salary * 0.10 AS raise_amount
FROM employees;

SELECT FORMAT('Project: %s - Budget: $%s - Status: %s',
              project_name, budget, status) AS project_info
FROM projects;

SELECT first_name || ' ' || last_name AS full_name,
       EXTRACT(YEAR FROM AGE(CURRENT_DATE, hire_date)) AS years_with_company
FROM employees;

-- Part 4: Aggregate Functions and GROUP BY

SELECT department,
       AVG(salary) AS avg_salary
FROM employees
GROUP BY department;

SELECT p.project_name,
       SUM(a.hours_worked) AS total_hours
FROM assignments a
JOIN projects p ON a.project_id = p.project_id
GROUP BY p.project_name;

SELECT department,
       COUNT(*) AS num_employees
FROM employees
GROUP BY department
HAVING COUNT(*) > 1;

SELECT MAX(salary) AS max_salary,
       MIN(salary) AS min_salary,
       SUM(salary) AS total_payroll
FROM employees;

-- Part 5: Set Operations

SELECT employee_id, first_name || ' ' || last_name AS full_name, salary
FROM employees
WHERE salary > 65000
UNION
SELECT employee_id, first_name || ' ' || last_name, salary
FROM employees
WHERE hire_date > '2020-01-01';

SELECT employee_id, first_name || ' ' || last_name AS full_name, salary
FROM employees
WHERE department = 'IT'
INTERSECT
SELECT employee_id, first_name || ' ' || last_name, salary
FROM employees
WHERE salary > 65000;

SELECT e.employee_id, e.first_name || ' ' || e.last_name AS full_name
FROM employees e
EXCEPT
SELECT a.employee_id, e.first_name || ' ' || e.last_name
FROM assignments a
JOIN employees e ON a.employee_id = e.employee_id;

-- Part 6: Subqueries

SELECT *
FROM employees e
WHERE EXISTS (
    SELECT 1
    FROM assignments a
    WHERE a.employee_id = e.employee_id
);

SELECT *
FROM employees
WHERE employee_id IN (
    SELECT a.employee_id
    FROM assignments a
    JOIN projects p ON a.project_id = p.project_id
    WHERE p.status = 'Active'
);

SELECT *
FROM employees
WHERE salary > ANY (
    SELECT salary
    FROM employees
    WHERE department = 'Sales'
);

-- Part 7: Complex Queries

SELECT e.first_name || ' ' || e.last_name AS full_name,
       e.department,
       AVG(a.hours_worked) AS avg_hours,
       RANK() OVER (PARTITION BY e.department ORDER BY e.salary DESC) AS dept_rank
FROM employees e
LEFT JOIN assignments a ON e.employee_id = a.employee_id
GROUP BY e.employee_id, e.first_name, e.last_name, e.department, e.salary;

SELECT p.project_name,
       SUM(a.hours_worked) AS total_hours,
       COUNT(DISTINCT a.employee_id) AS num_employees
FROM projects p
JOIN assignments a ON p.project_id = a.project_id
GROUP BY p.project_name
HAVING SUM(a.hours_worked) > 150;

SELECT e.department,
       COUNT(*) AS total_employees,
       AVG(salary) AS avg_salary,
       (SELECT first_name || ' ' || last_name
        FROM employees e2
        WHERE e2.department = e.department
        ORDER BY e2.salary DESC
        LIMIT 1) AS highest_paid
FROM employees e
GROUP BY e.department;
