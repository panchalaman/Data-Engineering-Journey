-- ============================================================
-- LESSON 1.09: Date & String Functions
-- ============================================================
-- Data rarely arrives in the format you need it. Dates come
-- as timestamps when you want months. Strings have extra
-- whitespace. Skills are stored as Python lists. These
-- functions are how you clean and reshape that data.
-- ============================================================


-- ============================================================
-- DATE FUNCTIONS
-- ============================================================

-- CURRENT_DATE / CURRENT_TIMESTAMP
SELECT
    CURRENT_DATE AS today,
    CURRENT_TIMESTAMP AS right_now;
/*

┌────────────┬───────────────────────────────┐
│   today    │           right_now           │
│    date    │   timestamp with time zone    │
├────────────┼───────────────────────────────┤
│ 2026-02-27 │ 2026-02-27 00:12:10.247251+01 │
└────────────┴───────────────────────────────┘

*/


-- DATE_TRUNC — Round Down to a Time Period
-- This is probably the most useful date function in data
-- engineering. It groups dates into months, quarters, years.

SELECT
    job_posted_date,
    DATE_TRUNC('month', job_posted_date) AS posted_month,
    DATE_TRUNC('quarter', job_posted_date) AS posted_quarter,
    DATE_TRUNC('year', job_posted_date) AS posted_year
FROM job_postings_fact
LIMIT 5;
/*

┌─────────────────────┬──────────────┬────────────────┬─────────────┐
│   job_posted_date   │ posted_month │ posted_quarter │ posted_year │
│      timestamp      │     date     │      date      │    date     │
├─────────────────────┼──────────────┼────────────────┼─────────────┤
│ 2023-01-01 00:00:04 │ 2023-01-01   │ 2023-01-01     │ 2023-01-01  │
│ 2023-01-01 00:00:22 │ 2023-01-01   │ 2023-01-01     │ 2023-01-01  │
│ 2023-01-01 00:00:24 │ 2023-01-01   │ 2023-01-01     │ 2023-01-01  │
│ 2023-01-01 00:00:27 │ 2023-01-01   │ 2023-01-01     │ 2023-01-01  │
│ 2023-01-01 00:00:38 │ 2023-01-01   │ 2023-01-01     │ 2023-01-01  │
└─────────────────────┴──────────────┴────────────────┴─────────────┘

*/
-- This is how I built the date dimension in Project 3. It allows me to group by month or quarter without extra date math. It also
-- gives me nice labels like "2023-Q1" for charts and dashboards.


-- Real use: monthly job posting trends
SELECT
    DATE_TRUNC('month', job_posted_date) AS month,
    COUNT(*) AS jobs_posted
FROM job_postings_fact
GROUP BY DATE_TRUNC('month', job_posted_date)
ORDER BY month;
/*

┌────────────┬─────────────┐
│   month    │ jobs_posted │
│    date    │    int64    │
├────────────┼─────────────┤
│ 2023-01-01 │       91872 │
│ 2023-02-01 │       64475 │
│ 2023-03-01 │       64209 │
│ 2023-04-01 │       62937 │
│ 2023-05-01 │       52042 │
│ 2023-06-01 │       61545 │
│ 2023-07-01 │       63760 │
│ 2023-08-01 │       75236 │
│ 2023-09-01 │       62363 │
│ 2023-10-01 │       66732 │
│ 2023-11-01 │       64385 │
│ 2023-12-01 │       57800 │
│ 2024-01-01 │       53145 │
│ 2024-02-01 │       55272 │
│ 2024-03-01 │       48442 │
│ 2024-04-01 │       43755 │
│ 2024-05-01 │       45555 │
│ 2024-06-01 │       41727 │
│ 2024-07-01 │       51152 │
│ 2024-08-01 │       47748 │
│ 2024-09-01 │       30215 │
│ 2024-10-01 │       19052 │
│ 2024-11-01 │       13779 │
│ 2024-12-01 │       34117 │
│ 2025-01-01 │       67650 │
│ 2025-02-01 │       84548 │
│ 2025-03-01 │       73505 │
│ 2025-04-01 │       44880 │
│ 2025-05-01 │       40404 │
│ 2025-06-01 │       33628 │
├────────────┴─────────────┤
│ 30 rows        2 columns │
└──────────────────────────┘

*/
-- This is a common pattern in data engineering: use DATE_TRUNC to group by time periods without worrying about the specific date math. It also gives you nice, clean date values to work with in downstream queries and dashboards.    

-- EXTRACT — Pull Out Date Parts
SELECT
    job_posted_date,
    EXTRACT(YEAR FROM job_posted_date) AS year,
    EXTRACT(MONTH FROM job_posted_date) AS month,
    EXTRACT(DAY FROM job_posted_date) AS day,
    EXTRACT(DOW FROM job_posted_date) AS day_of_week
    -- 0=Sunday, 1=Monday, ..., 6=Saturday
FROM job_postings_fact
LIMIT 5;
/*

┌─────────────────────┬───────┬───────┬───────┬─────────────┐
│   job_posted_date   │ year  │ month │  day  │ day_of_week │
│      timestamp      │ int64 │ int64 │ int64 │    int64    │
├─────────────────────┼───────┼───────┼───────┼─────────────┤
│ 2023-01-01 00:00:04 │  2023 │     1 │     1 │           0 │
│ 2023-01-01 00:00:22 │  2023 │     1 │     1 │           0 │
│ 2023-01-01 00:00:24 │  2023 │     1 │     1 │           0 │
│ 2023-01-01 00:00:27 │  2023 │     1 │     1 │           0 │
│ 2023-01-01 00:00:38 │  2023 │     1 │     1 │           0 │
└─────────────────────┴───────┴───────┴───────┴─────────────┘

*/
-- This is how I built the date dimension in Project 3. It allows me to group by month or quarter without extra date math. It also gives me nice labels like "2023-Q1" for charts and dashboards.

-- Which day of the week gets the most postings?
SELECT
    EXTRACT(DOW FROM job_posted_date) AS day_of_week,
    CASE EXTRACT(DOW FROM job_posted_date)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(*) AS job_count
FROM job_postings_fact
GROUP BY day_of_week
ORDER BY day_of_week;
/*

┌─────────────┬───────────┬───────────┐
│ day_of_week │ day_name  │ job_count │
│    int64    │  varchar  │   int64   │
├─────────────┼───────────┼───────────┤
│           0 │ Sunday    │    163698 │
│           1 │ Monday    │    229040 │
│           2 │ Tuesday   │    263832 │
│           3 │ Wednesday │    261925 │
│           4 │ Thursday  │    261468 │
│           5 │ Friday    │    255544 │
│           6 │ Saturday  │    180423 │
└─────────────┴───────────┴───────────┘

*/
-- Interesting! Tuesday and Wednesday are the most popular days for job postings, while Sunday is the least popular. This could be useful for timing your job search or understanding hiring patterns.


-- DATE_DIFF — Time Between Dates (DuckDB syntax)
SELECT
    job_posted_date,
    CURRENT_DATE AS today,
    DATE_DIFF('day', job_posted_date, CURRENT_DATE) AS days_ago,
    DATE_DIFF('month', job_posted_date, CURRENT_DATE) AS months_ago
FROM job_postings_fact
LIMIT 5;
/*

┌─────────────────────┬────────────┬──────────┬────────────┐
│   job_posted_date   │   today    │ days_ago │ months_ago │
│      timestamp      │    date    │  int64   │   int64    │
├─────────────────────┼────────────┼──────────┼────────────┤
│ 2023-01-01 00:00:04 │ 2026-02-27 │     1153 │         37 │
│ 2023-01-01 00:00:22 │ 2026-02-27 │     1153 │         37 │
│ 2023-01-01 00:00:24 │ 2026-02-27 │     1153 │         37 │
│ 2023-01-01 00:00:27 │ 2026-02-27 │     1153 │         37 │
│ 2023-01-01 00:00:38 │ 2026-02-27 │     1153 │         37 │
└─────────────────────┴────────────┴──────────┴────────────┘

*/
-- This is how you calculate the "age" of a job posting, which can be useful for understanding how long positions stay open or for prioritizing newer postings in a job search.     


-- Date Arithmetic
SELECT
    job_posted_date,
    job_posted_date + INTERVAL '30 days' AS plus_30_days,
    job_posted_date - INTERVAL '1 month' AS minus_1_month
FROM job_postings_fact
LIMIT 5;
/*

┌─────────────────────┬─────────────────────┬─────────────────────┐
│   job_posted_date   │    plus_30_days     │    minus_1_month    │
│      timestamp      │      timestamp      │      timestamp      │
├─────────────────────┼─────────────────────┼─────────────────────┤
│ 2023-01-01 00:00:04 │ 2023-01-31 00:00:04 │ 2022-12-01 00:00:04 │
│ 2023-01-01 00:00:22 │ 2023-01-31 00:00:22 │ 2022-12-01 00:00:22 │
│ 2023-01-01 00:00:24 │ 2023-01-31 00:00:24 │ 2022-12-01 00:00:24 │
│ 2023-01-01 00:00:27 │ 2023-01-31 00:00:27 │ 2022-12-01 00:00:27 │
│ 2023-01-01 00:00:38 │ 2023-01-31 00:00:38 │ 2022-12-01 00:00:38 │
└─────────────────────┴─────────────────────┴─────────────────────┘

*/


-- CASTING strings to dates
SELECT
    CAST('2024-03-15' AS DATE) AS date_value,
    CAST('2024-03-15 10:30:00' AS TIMESTAMP) AS timestamp_value;
/*

┌────────────┬─────────────────────┐
│ date_value │   timestamp_value   │
│    date    │      timestamp      │
├────────────┼─────────────────────┤
│ 2024-03-15 │ 2024-03-15 10:30:00 │
└────────────┴─────────────────────┘

*/


-- ============================================================
-- STRING FUNCTIONS
-- ============================================================

-- LENGTH
SELECT
    job_title,
    LENGTH(job_title) AS title_length
FROM job_postings_fact
LIMIT 5;
/*

┌───────────────────────────────────────────┬──────────────┐
│                 job_title                 │ title_length │
│                  varchar                  │    int64     │
├───────────────────────────────────────────┼──────────────┤
│ Data Analyst                              │           12 │
│ Data Analyst                              │           12 │
│ Data Analyst                              │           12 │
│ Senior Data Analyst / Platform Experience │           41 │
│ Data Analyst                              │           12 │
└───────────────────────────────────────────┴──────────────┘

*/


-- UPPER / LOWER
SELECT
    job_title,
    UPPER(job_title) AS screaming,
    LOWER(job_title) AS whisper
FROM job_postings_fact
LIMIT 5;
/*

┌───────────────────────────────┬───────────────────────────────────────────┬───────────────────────────────────────────┐
│           job_title           │                 screaming                 │                  whisper                  │
│            varchar            │                  varchar                  │                  varchar                  │
├───────────────────────────────┼───────────────────────────────────────────┼───────────────────────────────────────────┤
│ Data Analyst                  │ DATA ANALYST                              │ data analyst                              │
│ Data Analyst                  │ DATA ANALYST                              │ data analyst                              │
│ Data Analyst                  │ DATA ANALYST                              │ data analyst                              │
│ Senior Data Analyst / Platf…  │ SENIOR DATA ANALYST / PLATFORM EXPERIENCE │ senior data analyst / platform experience │
│ Data Analyst                  │ DATA ANALYST                              │ data analyst                              │
└───────────────────────────────┴───────────────────────────────────────────┴───────────────────────────────────────────┘

*/


-- TRIM — Remove Whitespace
SELECT
    TRIM('   hello   ') AS trimmed,
    LTRIM('   hello   ') AS left_trimmed,
    RTRIM('   hello   ') AS right_trimmed;
/*

┌─────────┬──────────────┬───────────────┐
│ trimmed │ left_trimmed │ right_trimmed │
│ varchar │   varchar    │    varchar    │
├─────────┼──────────────┼───────────────┤
│ hello   │ hello        │    hello      │
└─────────┴──────────────┴───────────────┘

*/

-- You'd be surprised how often string data has trailing
-- spaces. Trim everything when loading data.


-- REPLACE
SELECT
    job_location,
    REPLACE(job_location, 'United States', 'US') AS short_location
FROM job_postings_fact
WHERE job_location LIKE '%United States%'
LIMIT 5;
/*

┌───────────────┬────────────────┐
│ job_location  │ short_location │
│    varchar    │    varchar     │
├───────────────┼────────────────┤
│ United States │ US             │
│ United States │ US             │
│ United States │ US             │
│ United States │ US             │
│ United States │ US             │
└───────────────┴────────────────┘

*/
-- Handy for standardizing country names or fixing common typos.

-- SUBSTRING / LEFT / RIGHT
SELECT
    job_title,
    SUBSTRING(job_title, 1, 20) AS first_20_chars,
    LEFT(job_title, 10) AS first_10,
    RIGHT(job_title, 5) AS last_5
FROM job_postings_fact
LIMIT 5;
/*
┌───────────────────────────────────────────┬──────────────────────┬────────────┬─────────┐
│                 job_title                 │    first_20_chars    │  first_10  │ last_5  │
│                  varchar                  │       varchar        │  varchar   │ varchar │
├───────────────────────────────────────────┼──────────────────────┼────────────┼─────────┤
│ Data Analyst                              │ Data Analyst         │ Data Analy │ alyst   │
│ Data Analyst                              │ Data Analyst         │ Data Analy │ alyst   │
│ Data Analyst                              │ Data Analyst         │ Data Analy │ alyst   │
│ Senior Data Analyst / Platform Experience │ Senior Data Analyst  │ Senior Dat │ ience   │
│ Data Analyst                              │ Data Analyst         │ Data Analy │ alyst   │
└───────────────────────────────────────────┴──────────────────────┴────────────┴─────────┘

*/
-- Useful for parsing structured strings or creating abbreviated versions of text fields.


-- SPLIT_PART — Split a string by delimiter
SELECT
    job_location,
    SPLIT_PART(job_location, ',', 1) AS city,
    SPLIT_PART(job_location, ',', 2) AS state_or_country
FROM job_postings_fact
WHERE job_location LIKE '%,%'
LIMIT 10;
/*

┌───────────────────┬───────────────┬──────────────────┐
│   job_location    │     city      │ state_or_country │
│      varchar      │    varchar    │     varchar      │
├───────────────────┼───────────────┼──────────────────┤
│ New York, NY      │ New York      │  NY              │
│ Washington, DC    │ Washington    │  DC              │
│ Fairfax, VA       │ Fairfax       │  VA              │
│ Worcester, MA     │ Worcester     │  MA              │
│ Sunnyvale, CA     │ Sunnyvale     │  CA              │
│ Torrance, CA      │ Torrance      │  CA              │
│ San Francisco, CA │ San Francisco │  CA              │
│ Pleasanton, CA    │ Pleasanton    │  CA              │
│ Rosemead, CA      │ Rosemead      │  CA              │
│ Thousand Oaks, CA │ Thousand Oaks │  CA              │
├───────────────────┴───────────────┴──────────────────┤
│ 10 rows                                    3 columns │
└──────────────────────────────────────────────────────┘

*/
-- Handy for parsing "City, State" formatted locations.


-- CONCAT / ||
SELECT
    job_title_short || ' | ' || job_location AS combined,
    CONCAT(job_title_short, ' at ', job_location) AS also_combined
FROM job_postings_fact
LIMIT 5;
/*

┌─────────────────────────────────────┬──────────────────────────────────────┐
│              combined               │            also_combined             │
│               varchar               │               varchar                │
├─────────────────────────────────────┼──────────────────────────────────────┤
│ Data Analyst | New York, NY         │ Data Analyst at New York, NY         │
│ Data Analyst | Washington, DC       │ Data Analyst at Washington, DC       │
│ Data Analyst | Fairfax, VA          │ Data Analyst at Fairfax, VA          │
│ Senior Data Analyst | Worcester, MA │ Senior Data Analyst at Worcester, MA │
│ Data Analyst | Sunnyvale, CA        │ Data Analyst at Sunnyvale, CA        │
└─────────────────────────────────────┴──────────────────────────────────────┘

*/


-- ============================================================
-- STRING_SPLIT + UNNEST — Parsing Lists
-- ============================================================
-- This is the technique I used in Project 3.
-- Skills were stored as Python lists: "['SQL', 'Python', 'AWS']"
-- We need to parse that into individual rows.

-- Simulate it:
SELECT UNNEST(STRING_SPLIT('SQL,Python,AWS,Spark', ',')) AS skill;

-- More realistic — cleaning up Python list format:
SELECT
    TRIM(
        REPLACE(
            REPLACE(
                UNNEST(STRING_SPLIT('["SQL", "Python", "AWS"]', ',')),
                '[', ''
            ),
            ']', ''
        )
    ) AS skill;
    /*

┌──────────┐
│  skill   │
│ varchar  │
├──────────┤
│ "SQL"    │
│ "Python" │
│ "AWS"    │
└──────────┘

*/

-- In the real pipeline, this goes from:
--   one row with skills = "['SQL', 'Python', 'AWS']"
-- to:
--   three rows: SQL, Python, AWS
-- That's normalization via string parsing.


-- ============================================================
-- TYPE CASTING
-- ============================================================
-- Converting between data types.

SELECT
    CAST(salary_year_avg AS INTEGER) AS salary_int,
    CAST(salary_year_avg AS VARCHAR) AS salary_text,
    CAST('2024-01-15' AS DATE) AS date_val,
    CAST('42' AS INTEGER) AS number_val
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 5;
/*

┌────────────┬─────────────┬────────────┬────────────┐
│ salary_int │ salary_text │  date_val  │ number_val │
│   int32    │   varchar   │    date    │   int32    │
├────────────┼─────────────┼────────────┼────────────┤
│     110000 │ 110000.0    │ 2024-01-15 │         42 │
│      65000 │ 65000.0     │ 2024-01-15 │         42 │
│      90000 │ 90000.0     │ 2024-01-15 │         42 │
│      55000 │ 55000.0     │ 2024-01-15 │         42 │
│     120531 │ 120531.0    │ 2024-01-15 │         42 │
└────────────┴─────────────┴────────────┴────────────┘  

*/

-- DuckDB shorthand (also works in PostgreSQL):
SELECT
    salary_year_avg::INTEGER AS salary_int,
    salary_year_avg::VARCHAR AS salary_text
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 5;
/*

┌────────────┬─────────────┐
│ salary_int │ salary_text │
│   int32    │   varchar   │
├────────────┼─────────────┤
│     110000 │ 110000.0    │
│      65000 │ 65000.0     │
│      90000 │ 90000.0     │
│      55000 │ 55000.0     │
│     120531 │ 120531.0    │
└────────────┴─────────────┘

*/


-- ============================================================
-- MATH FUNCTIONS
-- ============================================================

SELECT
    salary_year_avg,
    ROUND(salary_year_avg, 0) AS rounded,
    ROUND(salary_year_avg, -3) AS rounded_to_thousands,
    CEIL(salary_year_avg) AS ceiling,
    FLOOR(salary_year_avg) AS floor,
    ABS(-42) AS absolute_value,
    LN(salary_year_avg) AS natural_log
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 5;
/*

┌─────────────────┬──────────┬──────────────────────┬──────────┬──────────┬────────────────┬────────────────────┐
│ salary_year_avg │ rounded  │ rounded_to_thousands │ ceiling  │  floor   │ absolute_value │    natural_log     │
│     double      │  double  │        double        │  double  │  double  │     int32      │       double       │
├─────────────────┼──────────┼──────────────────────┼──────────┼──────────┼────────────────┼────────────────────┤
│        110000.0 │ 110000.0 │             110000.0 │ 110000.0 │ 110000.0 │             42 │ 11.608235644774552 │
│         65000.0 │  65000.0 │              65000.0 │  65000.0 │  65000.0 │             42 │ 11.082142548877775 │
│         90000.0 │  90000.0 │              90000.0 │  90000.0 │  90000.0 │             42 │ 11.407564949312402 │
│         55000.0 │  55000.0 │              55000.0 │  55000.0 │  55000.0 │             42 │ 10.915088464214607 │
│        120531.0 │ 120531.0 │             121000.0 │ 120531.0 │ 120531.0 │             42 │ 11.699662260237593 │
└─────────────────┴──────────┴──────────────────────┴──────────┴──────────┴────────────────┴────────────────────┘

*/
-- I used LN() in the EDA project to create an "optimal score"
-- that combined log-transformed demand with median salary.
-- Log transformation helps normalize skewed distributions.


-- ============================================================
-- PUTTING IT TOGETHER: A Real Data Cleaning Pipeline
-- ============================================================

WITH cleaned_data AS (
    SELECT
        job_id,
        TRIM(job_title) AS job_title,
        LOWER(job_title_short) AS role,
        SPLIT_PART(job_location, ',', 1) AS city,
        TRIM(SPLIT_PART(job_location, ',', 2)) AS state_or_country,
        DATE_TRUNC('month', job_posted_date) AS posted_month,
        EXTRACT(YEAR FROM job_posted_date) AS posted_year,
        COALESCE(salary_year_avg, 0) AS salary,
        CASE
            WHEN salary_year_avg IS NULL THEN 'Not Disclosed'
            WHEN salary_year_avg >= 150000 THEN 'High'
            WHEN salary_year_avg >= 100000 THEN 'Mid'
            ELSE 'Entry'
        END AS salary_band
    FROM job_postings_fact
)
SELECT *
FROM cleaned_data
WHERE salary > 0
ORDER BY salary DESC
LIMIT 20;
/*  

┌─────────┬──────────────────────┬──────────────────────┬───┬──────────────┬─────────────┬──────────┬─────────────┐
│ job_id  │      job_title       │         role         │ … │ posted_month │ posted_year │  salary  │ salary_band │
│  int32  │       varchar        │       varchar        │   │     date     │    int64    │  double  │   varchar   │
├─────────┼──────────────────────┼──────────────────────┼───┼──────────────┼─────────────┼──────────┼─────────────┤
│  296745 │ Data Scientist       │ data scientist       │ … │ 2023-05-01   │        2023 │ 960000.0 │ High        │
│ 1231950 │ Data Science Manag…  │ data scientist       │ … │ 2024-11-01   │        2024 │ 920000.0 │ High        │
│  673003 │ Senior Data Scient…  │ senior data scient…  │ … │ 2023-11-01   │        2023 │ 890000.0 │ High        │
│ 1575798 │ Machine Learning E…  │ machine learning e…  │ … │ 2025-05-01   │        2025 │ 875000.0 │ High        │
│ 1007105 │ Machine Learning E…  │ data scientist       │ … │ 2024-05-01   │        2024 │ 870000.0 │ High        │
│  856772 │ Data Scientist       │ data scientist       │ … │ 2024-02-01   │        2024 │ 850000.0 │ High        │
│ 1591743 │ AI/ML (Artificial …  │ machine learning e…  │ … │ 2025-06-01   │        2025 │ 800000.0 │ High        │
│ 1443865 │ Senior Data Engine…  │ senior data engineer │ … │ 2025-03-01   │        2025 │ 800000.0 │ High        │
│ 1574285 │ Data Scientist , G…  │ data scientist       │ … │ 2025-05-01   │        2025 │ 680000.0 │ High        │
│  142665 │ Data Analyst         │ data analyst         │ … │ 2023-02-01   │        2023 │ 650000.0 │ High        │
│  871759 │ Manager, Content D…  │ data engineer        │ … │ 2024-02-01   │        2024 │ 640000.0 │ High        │
│ 1335282 │ Data Science Manag…  │ data scientist       │ … │ 2025-01-01   │        2025 │ 640000.0 │ High        │
│  785438 │ Geographic Informa…  │ data scientist       │ … │ 2023-12-01   │        2023 │ 585000.0 │ High        │
│  499552 │ Staff Data Scienti…  │ data scientist       │ … │ 2023-08-01   │        2023 │ 550000.0 │ High        │
│  234407 │ Hybrid - Data Engi…  │ data engineer        │ … │ 2023-04-01   │        2023 │ 525000.0 │ High        │
│  543480 │ Staff Data Scienti…  │ data scientist       │ … │ 2023-09-01   │        2023 │ 525000.0 │ High        │
│   95558 │ Senior Data Scient…  │ senior data scient…  │ … │ 2023-01-01   │        2023 │ 475000.0 │ High        │
│ 1218524 │ VP of Data Science…  │ data scientist       │ … │ 2024-10-01   │        2024 │ 475000.0 │ High        │
│  685280 │ VP Data Science & …  │ senior data scient…  │ … │ 2023-11-01   │        2023 │ 463500.0 │ High        │
│  494444 │ Data Engineer (L4)…  │ data engineer        │ … │ 2023-08-01   │        2023 │ 450000.0 │ High        │
├─────────┴──────────────────────┴──────────────────────┴───┴──────────────┴─────────────┴──────────┴─────────────┤
│ 20 rows                                                                                     9 columns (7 shown) │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

*/
-- This is a real data cleaning pipeline that I might use in a production ETL job. It standardizes job titles, parses locations, extracts date parts, and creates salary bands. The cleaned data can then be used for analysis, reporting, or feeding into a machine learning model.


-- ============================================================
-- TRY THIS
-- ============================================================
-- 1. Find the monthly trend of Data Engineer postings
--    (month, count) sorted by month
--
-- 2. Parse job_location into city and state/country columns,
--    and find the top 10 cities by posting count
--
-- 3. Calculate how many days each job has been posted
--    (from job_posted_date to CURRENT_DATE), and find
--    the average "age" of open positions by job title
