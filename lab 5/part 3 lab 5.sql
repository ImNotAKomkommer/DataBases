-- Lab Work 5: Database Constraints - Part 3: UNIQUE Constraints
-- Author: Егор Горохводацкий
-- DBMS: PostgreSQL
-- This section practices UNIQUE constraints (single, multi-column, named).


-- Task 3.1: Single Column UNIQUE
-- Create a table users with unique username and email.

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username TEXT UNIQUE,
    email TEXT UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Valid Inserts
INSERT INTO users (username, email)
VALUES ('egor', 'egor@example.com'),
       ('alex', 'alex@example.com');

-- Invalid Inserts 
-- INSERT INTO users (username, email)
-- VALUES ('egor', 'newmail@example.com'); -- Violates UNIQUE on username
-- INSERT INTO users (username, email)
-- VALUES ('newuser', 'alex@example.com'); -- Violates UNIQUE on email


-- Task 3.2: Multi-Column UNIQUE
-- Create a table course_enrollments with a composite UNIQUE constraint on
-- (student_id, course_code, semester) to prevent duplicate enrollments.

CREATE TABLE course_enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INTEGER,
    course_code TEXT,
    semester TEXT,
    CONSTRAINT unique_enrollment UNIQUE (student_id, course_code, semester)
);

-- Valid Inserts
INSERT INTO course_enrollments (student_id, course_code, semester)
VALUES (1, 'CS101', 'Spring2025'),
       (1, 'CS102', 'Spring2025'),
       (2, 'CS101', 'Spring2025');

-- Invalid Insert 
-- INSERT INTO course_enrollments (student_id, course_code, semester)
-- VALUES (1, 'CS101', 'Spring2025'); -- Violates UNIQUE (student_id, course_code, semester)


-- Task 3.3: Named UNIQUE Constraints
-- Modify the users table to include explicitly named UNIQUE constraints.
-- Note: PostgreSQL doesnt allow direct renaming of anonymous constraints,
-- so we create a new version with names for clarity.

DROP TABLE IF EXISTS users_named;

CREATE TABLE users_named (
    user_id SERIAL PRIMARY KEY,
    username TEXT CONSTRAINT unique_username UNIQUE,
    email TEXT CONSTRAINT unique_email UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Valid Inserts
INSERT INTO users_named (username, email)
VALUES ('kate', 'kate@example.com'),
       ('mike', 'mike@example.com');

-- Invalid Inserts 
-- INSERT INTO users_named (username, email)
-- VALUES ('kate', 'another@example.com'); -- Violates CONSTRAINT unique_username
-- INSERT INTO users_named (username, email)
-- VALUES ('luke', 'mike@example.com'); -- Violates CONSTRAINT unique_email


-- Summary
-- UNIQUE ensures no duplicate values appear in one or more columns.
-- - Single-column UNIQUE: enforces uniqueness per column.
-- - Multi-column UNIQUE: enforces uniqueness across a combination.
-- - Named UNIQUE: lets you easily identify the violated constraint.


