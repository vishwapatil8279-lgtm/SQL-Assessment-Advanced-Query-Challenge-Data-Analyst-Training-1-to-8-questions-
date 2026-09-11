create database sql_assessment;

use sql_assessment;

CREATE TABLE UserLogins (user_id INTEGER, login_date TEXT);
INSERT INTO UserLogins VALUES
(1,'2024-03-01'),(1,'2024-03-02'),(1,'2024-03-03'),(1,'2024-03-05'),(1,'2024-03-06'),
(2,'2024-03-01'),(2,'2024-03-02'),(2,'2024-03-03'),(2,'2024-03-04'),(2,'2024-03-05'),
(2,'2024-03-09'),
(3,'2024-03-04'),
(4,'2024-03-01'),(4,'2024-03-03'),(4,'2024-03-05'),(4,'2024-03-07');

CREATE TABLE Employees (
  emp_id INTEGER PRIMARY KEY, name TEXT, department TEXT,
  salary INTEGER, manager_id INTEGER
);
INSERT INTO Employees VALUES
(1,'Arjun','Sales',120000,NULL),
(2,'Priya','Sales',110000,1),
(3,'Rahul','Sales',110000,1),
(4,'Kiran','Sales',95000,2),
(5,'Divya','Sales',80000,2),
(6,'Sneha','Engineering',150000,NULL),
(7,'Vikram','Engineering',140000,6),
(8,'Meera','Engineering',130000,6),
(9,'Ravi','Engineering',130000,7),
(10,'Tara','Engineering',100000,7),
(11,'Aman','Marketing',90000,NULL),
(12,'Zoya','Marketing',85000,11),
(13,'Farhan','Marketing',75000,11),
(14,'Nikita','Marketing',70000,12),
-- circular chain for Q7: 15 -> 16 -> 15
(15,'Loop A','Ops',60000,16),
(16,'Loop B','Ops',60000,15);

CREATE TABLE Clickstream (user_id INTEGER, event_time TEXT);
INSERT INTO Clickstream VALUES
(1,'2024-05-01 09:00:00'),(1,'2024-05-01 09:05:00'),(1,'2024-05-01 09:20:00'),
(1,'2024-05-01 10:15:00'),(1,'2024-05-01 10:25:00'),
(1,'2024-05-01 14:00:00'),
(2,'2024-05-01 11:00:00'),(2,'2024-05-01 11:10:00'),(2,'2024-05-01 11:35:00'),
(2,'2024-05-01 13:00:00'),
(3,'2024-05-01 08:00:00');

CREATE TABLE Scores (student_id INTEGER, subject TEXT, score INTEGER);
INSERT INTO Scores VALUES
(1,'Math',88),(1,'Science',92),(1,'English',75),
(2,'Math',67),(2,'Science',80),
(3,'Math',95),(3,'English',89),
(4,'Science',70),(4,'English',65);

CREATE TABLE Contacts (id INTEGER PRIMARY KEY, email TEXT, created_at TEXT);
INSERT INTO Contacts VALUES
(1,'a@x.com','2024-01-05 10:00:00'),
(2,'b@x.com','2024-01-06 09:00:00'),
(3,'a@x.com','2024-02-11 12:30:00'),
(4,'c@x.com','2024-01-07 08:15:00'),
(5,'a@x.com','2024-03-02 16:45:00'),
(6,'b@x.com','2024-02-20 11:20:00'),
(7,'d@x.com','2024-01-09 07:00:00');

CREATE TABLE DailySales (sale_date TEXT, sales INTEGER);
INSERT INTO DailySales VALUES
('2024-04-01',100),('2024-04-02',300),('2024-04-03',200),
('2024-04-04',500),('2024-04-05',400),('2024-04-06',700),('2024-04-07',600);

CREATE TABLE Transactions (
  txn_id INTEGER PRIMARY KEY, account_id INTEGER,
  txn_time TEXT, amount REAL
);
INSERT INTO Transactions VALUES
(1,101,'2024-06-01 10:00:00',1000.00),
(2,101,'2024-06-01 10:00:30',1005.00),   -- pair with 1: 30s, 0.5% diff
(3,101,'2024-06-01 10:05:00',1000.00),   -- too far in time
(4,102,'2024-06-01 12:00:00',500.00),
(5,102,'2024-06-01 12:00:45',700.00),    -- within 60s but 40% diff
(6,103,'2024-06-01 14:00:00',2000.00),
(7,103,'2024-06-01 14:00:20',2010.00),   -- pair with 6: 20s, 0.5% diff
(8,103,'2024-06-01 14:00:50',2015.00);   -- pairs with 7 (30s, 0.25%) and 6 (50s, 0.75%)

-- SQL ASSESSMENT
-- Runned the supplied SETUP SCRIPT.

-- Q1 — GAPS AND ISLANDS

WITH numbered AS (
    SELECT
        user_id,
        CAST(login_date AS DATE) AS login_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS rn
    FROM UserLogins
),
islands AS (
    SELECT
        user_id,
        login_date,
        DATE_SUB(login_date, INTERVAL rn DAY) AS island_group
    FROM numbered
),
streaks AS (
    SELECT
        user_id,
        MIN(login_date) AS streak_start,
        MAX(login_date) AS streak_end,
        COUNT(*) AS streak_length
    FROM islands
    GROUP BY user_id, island_group
),
ranked AS (
    SELECT
        user_id,
        streak_start,
        streak_end,
        streak_length,
        RANK() OVER (
            PARTITION BY user_id
            ORDER BY streak_length DESC
        ) AS streak_rank
    FROM streaks
)
SELECT
    user_id,
    streak_start,
    streak_end,
    streak_length
FROM ranked
WHERE streak_rank = 1
ORDER BY user_id, streak_start;

-- Q2 — NTH HIGHEST PER GROUP

WITH ranked_salaries AS (
    SELECT
        department,
        salary,
        DENSE_RANK() OVER (
            PARTITION BY department
            ORDER BY salary DESC
        ) AS salary_rank
    FROM Employees
)
SELECT
    department,
    salary AS third_highest_salary
FROM ranked_salaries
WHERE salary_rank = 3
ORDER BY department;

-- Q3 — SESSION RECONSTRUCTION

WITH ordered_events AS (
    SELECT
        user_id,
        STR_TO_DATE(event_time, '%Y-%m-%d %H:%i:%s') AS event_time,
        LAG(
            STR_TO_DATE(event_time, '%Y-%m-%d %H:%i:%s')
        ) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS previous_event_time
    FROM Clickstream
),
session_flags AS (
    SELECT
        user_id,
        event_time,
        CASE
            WHEN previous_event_time IS NULL THEN 1
            WHEN TIMESTAMPDIFF(
                MINUTE,
                previous_event_time,
                event_time
            ) >= 30 THEN 1
            ELSE 0
        END AS new_session
    FROM ordered_events
),
session_numbers AS (
    SELECT
        user_id,
        event_time,
        SUM(new_session) OVER (
            PARTITION BY user_id
            ORDER BY event_time
            ROWS UNBOUNDED PRECEDING
        ) AS session_id
    FROM session_flags
)
SELECT
    user_id,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end,
    TIMESTAMPDIFF(
        SECOND,
        MIN(event_time),
        MAX(event_time)
    ) AS duration_seconds
FROM session_numbers
GROUP BY user_id, session_id
ORDER BY user_id, session_start;

-- Q4 — PIVOTING WITHOUT PIVOT

SELECT
    student_id,
    SUM(CASE WHEN subject = 'Math'
             THEN score ELSE 0 END) AS Math,
    SUM(CASE WHEN subject = 'Science'
             THEN score ELSE 0 END) AS Science,
    SUM(CASE WHEN subject = 'English'
             THEN score ELSE 0 END) AS English
FROM Scores
GROUP BY student_id
ORDER BY student_id;

-- Q5 — DEDUPLICATE KEEPING LATEST

DELETE FROM Contacts
WHERE id IN (
    SELECT id
    FROM (
        SELECT
            id,
            ROW_NUMBER() OVER (
                PARTITION BY email
                ORDER BY created_at DESC, id DESC
            ) AS rn
        FROM Contacts
    ) AS ranked_contacts
    WHERE rn > 1
);

-- Q6 — RUNNING MEDIAN

WITH running_values AS (
    SELECT
        d1.sale_date AS sale_dt,   -- avoid reserved keyword
        d2.sales,
        ROW_NUMBER() OVER (
            PARTITION BY d1.sale_date
            ORDER BY d2.sales
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY d1.sale_date
        ) AS cnt
    FROM DailySales AS d1
    JOIN DailySales AS d2
        ON d2.sale_date <= d1.sale_date
),
running_medians AS (
    SELECT
        sale_dt,
        AVG(sales) AS running_median
    FROM running_values
    WHERE rn IN (
        FLOOR((cnt + 1) / 2),
        FLOOR((cnt + 2) / 2)
    )
    GROUP BY sale_dt
)
SELECT
    sale_dt AS sale_date,
    running_median
FROM running_medians
ORDER BY sale_dt;

-- Q7 — RECURSIVE HIERARCHY

WITH RECURSIVE hierarchy AS (
    -- Direct reports
    SELECT
        e.manager_id AS root_manager,
        e.emp_id AS report_id,
        CAST(
            CONCAT(e.manager_id, ',', e.emp_id)
            AS CHAR(1000)
        ) AS path,
        0 AS cycle_found
    FROM Employees AS e
    WHERE e.manager_id IS NOT NULL

    UNION ALL

    -- Indirect reports
    SELECT
        h.root_manager,
        e.emp_id AS report_id,
        CONCAT(h.path, ',', e.emp_id) AS path,
        CASE
            WHEN FIND_IN_SET(e.emp_id, h.path) > 0 THEN 1
            ELSE 0
        END AS cycle_found
    FROM hierarchy AS h
    JOIN Employees AS e
        ON e.manager_id = h.report_id
    WHERE h.cycle_found = 0
      AND FIND_IN_SET(e.emp_id, h.path) = 0
),
report_counts AS (
    SELECT
        root_manager,
        COUNT(DISTINCT report_id) AS total_reports
    FROM hierarchy
    WHERE report_id <> root_manager
    GROUP BY root_manager
),
cycle_managers AS (
    SELECT DISTINCT
        root_manager
    FROM hierarchy
    WHERE cycle_found = 1
)
SELECT
    e.emp_id AS manager_id,
    e.name,
    COALESCE(rc.total_reports, 0) AS total_reports,
    CASE
        WHEN cm.root_manager IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END AS circular_chain
FROM Employees AS e
LEFT JOIN report_counts AS rc
    ON e.emp_id = rc.root_manager
LEFT JOIN cycle_managers AS cm
    ON e.emp_id = cm.root_manager
WHERE EXISTS (
    SELECT 1
    FROM Employees AS sub
    WHERE sub.manager_id = e.emp_id
)
ORDER BY e.emp_id;

-- Q8 — SELF-JOIN ANOMALY DETECTION

SELECT
    t1.txn_id AS txn_id_1,
    t2.txn_id AS txn_id_2,
    t1.account_id,
    t1.txn_time AS time_1,
    t2.txn_time AS time_2,
    t1.amount AS amount_1,
    t2.amount AS amount_2,
    ROUND(
        ABS(t1.amount - t2.amount)
        / NULLIF(t1.amount, 0) * 100,
        2
    ) AS pct_difference
FROM Transactions AS t1
JOIN Transactions AS t2
    ON t1.account_id = t2.account_id
    AND t1.txn_id < t2.txn_id
    AND ABS(
        TIMESTAMPDIFF(
            SECOND,
            t1.txn_time,
            t2.txn_time
        )
    ) < 60
WHERE ABS(t1.amount - t2.amount)
      / NULLIF(t1.amount, 0) < 0.01
ORDER BY
    t1.account_id,
    t1.txn_time,
    t2.txn_time;

