-- Lab Work 5: Database Constraints - Part 4: PRIMARY KEY Constraints
-- Author: Егор Горохводацкий
-- DBMS: PostgreSQL
-- This section practices PRIMARY KEY constraints, single and composite.


-- Task 4.1: Single Column Primary Key
-- Create a table departments with dept_id as PRIMARY KEY.

CREATE TABLE departments (
    dept_id INTEGER PRIMARY KEY,
    dept_name TEXT NOT NULL,
    location TEXT
);

-- Valid Inserts
INSERT INTO departments (dept_id, dept_name, location)
VALUES (1, 'IT', 'Almaty'),
       (2, 'HR', 'Astana'),
       (3, 'Finance', 'Shymkent');

-- Invalid Inserts 
-- INSERT INTO departments (dept_id, dept_name, location)
-- VALUES (1, 'Marketing', 'Almaty'); -- Violates PRIMARY KEY (duplicate dept_id)
-- INSERT INTO departments (dept_id, dept_name, location)
-- VALUES (NULL, 'Security', 'Atyrau'); -- Violates NOT NULL implied by PRIMARY KEY


-- Task 4.2: Composite Primary Key
-- Create a table student_courses where PRIMARY KEY is (student_id, course_id).
-- Prevents duplicate pairs of student/course combinations.

CREATE TABLE student_courses (
    student_id INTEGER,
    course_id INTEGER,
    enrollment_date DATE,
    grade TEXT,
    PRIMARY KEY (student_id, course_id)
);

-- Valid Inserts
INSERT INTO student_courses (student_id, course_id, enrollment_date, grade)
VALUES (1, 101, '2025-03-01', 'A'),
       (1, 102, '2025-03-02', 'B'),
       (2, 101, '2025-03-05', 'A');

-- Invalid Insert 
-- INSERT INTO student_courses (student_id, course_id, enrollment_date, grade)
-- VALUES (1, 101, '2025-03-10', 'C'); -- Violates composite PRIMARY KEY


-- Task 4.3: Comparison Exercise (Theory Section)
-- 1. Difference between UNIQUE and PRIMARY KEY:
--    - PRIMARY KEY uniquely identifies a record and automatically implies NOT NULL.
--    - UNIQUE only ensures all values are distinct, but allows NULL unless stated otherwise.
--
-- 2. When to use:
--    - Use a single-column PRIMARY KEY when one field (like id) uniquely identifies a row.
--    - Use a composite PRIMARY KEY when uniqueness depends on multiple fields 
--      (e.g., student_id + course_id).
--
-- 3. Why only one PRIMARY KEY but multiple UNIQUE constraints:
--    - A table can have only one PRIMARY KEY because it represents the main unique identifier.
--    - However, it can have several UNIQUE constraints for additional uniqueness rules 
--      (like unique email, username, etc.).


