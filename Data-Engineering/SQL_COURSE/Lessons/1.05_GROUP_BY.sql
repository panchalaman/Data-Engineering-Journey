-- ============================================================
-- LESSON 1.05: GROUP BY & Aggregate Functions
-- ============================================================
-- This is where SQL gets powerful. Instead of looking at
-- individual rows, you start asking questions about groups
-- of rows: "How many?", "What's the average?", "What's
-- the highest?"
--
-- If you've ever made a pivot table in Excel, GROUP BY
-- is the SQL version of that.
-- ============================================================


-- ============================================================
-- AGGREGATE FUNCTIONS — The Building Blocks
-- ============================================================
-- These functions take many rows and collapse them into one value.

-- How many job postings are there total?
SELECT COUNT(*) AS total_postings
FROM job_postings_fact;
/*

┌────────────────┐
│ total_postings │
│     int64      │
├────────────────┤
│    1615930     │
│ (1.62 million) │
└────────────────┘  
*/

-- How many have salaries listed?
SELECT COUNT(salary_year_avg) AS postings_with_salary
FROM job_postings_fact;
/*
┌──────────────────────┐
│ postings_with_salary │
│        int64         │
├──────────────────────┤
│        51026         │
└──────────────────────┘
*/
-- COUNT(*) counts all rows
-- COUNT(column) counts rows where that column is NOT NULL
-- This difference matters!

-- Basic aggregate functions
SELECT
    COUNT(*) AS total_jobs,
    COUNT(salary_year_avg) AS jobs_with_salary,
    AVG(salary_year_avg) AS avg_salary,
    MIN(salary_year_avg) AS min_salary,
    MAX(salary_year_avg) AS max_salary,
    SUM(salary_year_avg) AS sum_salary
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL;
/*

┌────────────┬──────────────────┬────────────────────┬────────────┬────────────┬───────────────────┐
│ total_jobs │ jobs_with_salary │     avg_salary     │ min_salary │ max_salary │    sum_salary     │
│   int64    │      int64       │       double       │   double   │   double   │      double       │
├────────────┼──────────────────┼────────────────────┼────────────┼────────────┼───────────────────┤
│   51026    │      51026       │ 123788.58142141996 │  15000.0   │  960000.0  │ 6316436155.609375 │
└────────────┴──────────────────┴────────────────────┴────────────┴────────────┴───────────────────┘
*/

-- MEDIAN (available in DuckDB, not all databases)
SELECT
    MEDIAN(salary_year_avg) AS median_salary
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL;
/*

┌───────────────┐
│ median_salary │
│    double     │
├───────────────┤
│   116950.0    │
└───────────────┘
*/


-- ROUND — because nobody wants to see 134,276.384729
SELECT
    ROUND(AVG(salary_year_avg), 2) AS avg_salary,
    ROUND(MEDIAN(salary_year_avg), 0) AS median_salary
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL;
/*

┌────────────┬───────────────┐
│ avg_salary │ median_salary │
│   double   │    double     │
├────────────┼───────────────┤
│ 123788.58  │   116950.0    │
└────────────┴───────────────┘
*/


-- ============================================================
-- GROUP BY — Aggregating by Category
-- ============================================================
-- "Count/average/sum... PER WHAT?"
-- GROUP BY answers that question.

-- How many jobs per job title?
SELECT
    job_title_short,
    COUNT(*) AS job_count
FROM job_postings_fact
GROUP BY job_title_short
ORDER BY job_count DESC;
/*

┌───────────────────────────┬───────────┐
│      job_title_short      │ job_count │
│          varchar          │   int64   │
├───────────────────────────┼───────────┤
│ Data Analyst              │    408640 │
│ Data Engineer             │    391957 │
│ Data Scientist            │    331002 │
│ Business Analyst          │    101167 │
│ Software Engineer         │     92271 │
│ Senior Data Engineer      │     91295 │
│ Senior Data Scientist     │     70877 │
│ Senior Data Analyst       │     59383 │
│ Machine Learning Engineer │     39628 │
│ Cloud Engineer            │     29710 │
├───────────────────────────┴───────────┤
│ 10 rows                     2 columns │
└───────────────────────────────────────┘
*/

-- Average salary per job title
SELECT
    job_title_short,
    ROUND(AVG(salary_year_avg), 0) AS avg_salary,
    COUNT(*) AS job_count
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
GROUP BY job_title_short
ORDER BY avg_salary DESC;
/*

┌───────────────────────────┬────────────┬───────────┐
│      job_title_short      │ avg_salary │ job_count │
│          varchar          │   double   │   int64   │
├───────────────────────────┼────────────┼───────────┤
│ Senior Data Scientist     │   156391.0 │      3271 │
│ Senior Data Engineer      │   149222.0 │      3283 │
│ Software Engineer         │   141513.0 │      1578 │
│ Machine Learning Engineer │   137332.0 │      1334 │
│ Data Engineer             │   134867.0 │     10551 │
│ Data Scientist            │   134324.0 │     12625 │
│ Cloud Engineer            │   122464.0 │       219 │
│ Senior Data Analyst       │   115800.0 │      2603 │
│ Business Analyst          │    98660.0 │      1962 │
│ Data Analyst              │    93223.0 │     13600 │
├───────────────────────────┴────────────┴───────────┤
│ 10 rows                                  3 columns │
└────────────────────────────────────────────────────┘
*/


-- THE GOLDEN RULE:
-- Every column in SELECT must either:
--   1. Be in the GROUP BY clause, OR
--   2. Be inside an aggregate function (COUNT, AVG, etc.)
--
-- This won't work:
--   SELECT job_title_short, job_location, COUNT(*)
--   FROM job_postings_fact
--   GROUP BY job_title_short
--
-- Because job_location isn't grouped or aggregated.
-- The database wouldn't know WHICH location to show.


-- ============================================================
-- GROUP BY Multiple Columns
-- ============================================================
-- You can group by more than one column to get more specific
-- breakdowns.

-- Jobs per title AND location
SELECT
    job_title_short,
    job_location,
    COUNT(*) AS job_count
FROM job_postings_fact
GROUP BY job_title_short, job_location
ORDER BY job_count DESC
LIMIT 20;
/*

┌───────────────────────┬─────────────────────────────┬───────────┐
│    job_title_short    │        job_location         │ job_count │
│        varchar        │           varchar           │   int64   │
├───────────────────────┼─────────────────────────────┼───────────┤
│ Data Engineer         │ Anywhere                    │     43890 │
│ Data Scientist        │ Anywhere                    │     29345 │
│ Data Analyst          │ Anywhere                    │     27201 │
│ Senior Data Engineer  │ Anywhere                    │     13118 │
│ Data Analyst          │ Singapore                   │     10476 │
│ Data Engineer         │ Singapore                   │      9334 │
│ Data Engineer         │ Bengaluru, Karnataka, India │      8906 │
│ Senior Data Scientist │ Anywhere                    │      7457 │
│ Software Engineer     │ Anywhere                    │      6984 │
│ Data Analyst          │ New York, NY                │      6513 │
│ Data Scientist        │ Singapore                   │      6264 │
│ Business Analyst      │ Anywhere                    │      6223 │
│ Data Analyst          │ Paris, France               │      5911 │
│ Data Scientist        │ United States               │      5826 │
│ Data Engineer         │ London, UK                  │      5611 │
│ Data Scientist        │ New York, NY                │      5503 │
│ Data Analyst          │ United Kingdom              │      5354 │
│ Data Scientist        │ London, UK                  │      5333 │
│ Data Engineer         │ Paris, France               │      5294 │
│ Data Scientist        │ Bengaluru, Karnataka, India │      5274 │
├───────────────────────┴─────────────────────────────┴───────────┤
│ 20 rows                                               3 columns │
└─────────────────────────────────────────────────────────────────┘
*/

-- Remote vs non-remote breakdown per title
SELECT
    job_title_short,
    job_work_from_home,
    COUNT(*) AS job_count,
    ROUND(AVG(salary_year_avg), 0) AS avg_salary
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
GROUP BY job_title_short, job_work_from_home
ORDER BY job_title_short, job_work_from_home;
/*

┌───────────────────────────┬────────────────────┬───────────┬────────────┐
│      job_title_short      │ job_work_from_home │ job_count │ avg_salary │
│          varchar          │      boolean       │   int64   │   double   │
├───────────────────────────┼────────────────────┼───────────┼────────────┤
│ Business Analyst          │ false              │      1692 │    98449.0 │
│ Business Analyst          │ true               │       270 │    99985.0 │
│ Cloud Engineer            │ false              │       174 │   118899.0 │
│ Cloud Engineer            │ true               │        45 │   136248.0 │
│ Data Analyst              │ false              │     12388 │    92899.0 │
│ Data Analyst              │ true               │      1212 │    96535.0 │
│ Data Engineer             │ false              │      8975 │   134255.0 │
│ Data Engineer             │ true               │      1576 │   138351.0 │
│ Data Scientist            │ false              │     10676 │   133753.0 │
│ Data Scientist            │ true               │      1949 │   137454.0 │
│ Machine Learning Engineer │ false              │      1165 │   136564.0 │
│ Machine Learning Engineer │ true               │       169 │   142625.0 │
│ Senior Data Analyst       │ false              │      2292 │   116310.0 │
│ Senior Data Analyst       │ true               │       311 │   112036.0 │
│ Senior Data Engineer      │ false              │      2765 │   149409.0 │
│ Senior Data Engineer      │ true               │       518 │   148224.0 │
│ Senior Data Scientist     │ false              │      2636 │   155243.0 │
│ Senior Data Scientist     │ true               │       635 │   161155.0 │
│ Software Engineer         │ false              │      1130 │   135506.0 │
│ Software Engineer         │ true               │       448 │   156667.0 │
├───────────────────────────┴────────────────────┴───────────┴────────────┤
│ 20 rows                                                       4 columns │
└─────────────────────────────────────────────────────────────────────────┘ 
*/



-- ============================================================
-- HAVING — Filtering Groups
-- ============================================================
-- WHERE filters individual rows BEFORE grouping.
-- HAVING filters groups AFTER aggregation.
--
-- Think of it this way:
--   WHERE  = "which rows go into the groups?"
--   HAVING = "which groups do I want to see?"

-- Job titles with more than 1000 postings
SELECT
    job_title_short,
    COUNT(*) AS job_count
FROM job_postings_fact
GROUP BY job_title_short
HAVING COUNT(*) > 1000
ORDER BY job_count DESC;
/*

┌───────────────────────────┬───────────┐
│      job_title_short      │ job_count │
│          varchar          │   int64   │
├───────────────────────────┼───────────┤
│ Data Analyst              │    408640 │
│ Data Engineer             │    391957 │
│ Data Scientist            │    331002 │
│ Business Analyst          │    101167 │
│ Software Engineer         │     92271 │
│ Senior Data Engineer      │     91295 │
│ Senior Data Scientist     │     70877 │
│ Senior Data Analyst       │     59383 │
│ Machine Learning Engineer │     39628 │
│ Cloud Engineer            │     29710 │
├───────────────────────────┴───────────┤
│ 10 rows                     2 columns │
└───────────────────────────────────────┘
*/


-- Titles where the average salary is above 120k
SELECT
    job_title_short,
    ROUND(AVG(salary_year_avg), 0) AS avg_salary,
    COUNT(*) AS job_count
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
GROUP BY job_title_short
HAVING AVG(salary_year_avg) > 120000
ORDER BY avg_salary DESC;
/*

┌───────────────────────────┬────────────┬───────────┐
│      job_title_short      │ avg_salary │ job_count │
│          varchar          │   double   │   int64   │
├───────────────────────────┼────────────┼───────────┤
│ Senior Data Scientist     │   156391.0 │      3271 │
│ Senior Data Engineer      │   149222.0 │      3283 │
│ Software Engineer         │   141513.0 │      1578 │
│ Machine Learning Engineer │   137332.0 │      1334 │
│ Data Engineer             │   134867.0 │     10551 │
│ Data Scientist            │   134324.0 │     12625 │
│ Cloud Engineer            │   122464.0 │       219 │
└───────────────────────────┴────────────┴───────────┘
*/


-- WHERE + HAVING together
-- "For remote jobs only, which titles have avg salary > 130k?"
SELECT
    job_title_short,
    ROUND(AVG(salary_year_avg), 0) AS avg_salary,
    COUNT(*) AS job_count
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
  AND job_work_from_home = TRUE
GROUP BY job_title_short
HAVING AVG(salary_year_avg) > 130000
ORDER BY avg_salary DESC;
/*
┌───────────────────────────┬────────────┬───────────┐
│      job_title_short      │ avg_salary │ job_count │
│          varchar          │   double   │   int64   │
├───────────────────────────┼────────────┼───────────┤
│ Senior Data Scientist     │   161155.0 │       635 │
│ Software Engineer         │   156667.0 │       448 │
│ Senior Data Engineer      │   148224.0 │       518 │
│ Machine Learning Engineer │   142625.0 │       169 │
│ Data Engineer             │   138351.0 │      1576 │
│ Data Scientist            │   137454.0 │      1949 │
│ Cloud Engineer            │   136248.0 │        45 │
└───────────────────────────┴────────────┴───────────┘
*/


-- ============================================================
-- COUNT DISTINCT
-- ============================================================
-- COUNT(*) counts rows. COUNT(DISTINCT column) counts
-- unique values.

-- How many unique companies are posting jobs?
SELECT
    COUNT(DISTINCT company_id) AS unique_companies
FROM job_postings_fact;
/*
┌──────────────────┐
│ unique_companies │
│      int64       │
├──────────────────┤
│      215940      │
└──────────────────┘
*/

-- Unique companies per job title
SELECT
    job_title_short,
    COUNT(DISTINCT company_id) AS unique_companies,
    COUNT(*) AS total_postings
FROM job_postings_fact
GROUP BY job_title_short
ORDER BY unique_companies DESC;
/*

┌───────────────────────────┬──────────────────┬────────────────┐
│      job_title_short      │ unique_companies │ total_postings │
│          varchar          │      int64       │     int64      │
├───────────────────────────┼──────────────────┼────────────────┤
│ Data Analyst              │            92879 │         408640 │
│ Data Engineer             │            75374 │         391957 │
│ Data Scientist            │            70618 │         331002 │
│ Business Analyst          │            35578 │         101167 │
│ Software Engineer         │            28671 │          92271 │
│ Senior Data Engineer      │            24498 │          91295 │
│ Senior Data Scientist     │            19712 │          70877 │
│ Senior Data Analyst       │            18545 │          59383 │
│ Machine Learning Engineer │            14601 │          39628 │
│ Cloud Engineer            │            12110 │          29710 │
├───────────────────────────┴──────────────────┴────────────────┤
│ 10 rows                                             3 columns │
└───────────────────────────────────────────────────────────────┘
*/


-- ============================================================
-- STRING_AGG — Concatenating Grouped Values
-- ============================================================
-- Sometimes you want to combine text values in a group.

-- List all locations for each job title (comma-separated)
SELECT
    job_title_short,
    STRING_AGG(DISTINCT job_country, ', ') AS countries
FROM job_postings_fact
GROUP BY job_title_short;
/*

┌──────────────────────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│   job_title_short    │                                                        countries                                                         │
│       varchar        │                                                         varchar                                                          │
├──────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Cloud Engineer       │ Romania, Singapore, Sweden, Portugal, Thailand, Bulgaria, Suriname, Mozambique, Paraguay, Albania, Philippines, Serbia…  │
│ Machine Learning E…  │ Czechia, Nepal, Morocco, Myanmar, Cyprus, South Africa, Croatia, United Kingdom, Sri Lanka, Kazakhstan, Montenegro, Ba…  │
│ Senior Data Analyst  │ Austria, Greece, Macedonia (FYROM), Iraq, Zimbabwe, Colombia, Switzerland, Israel, Panama, Kyrgyzstan, Belarus, Jordan…  │
│ Data Engineer        │ Latvia, United Arab Emirates, Taiwan, Uruguay, Honduras, Somalia, Bhutan, Australia, Vietnam, Pakistan, Ghana, Haiti, …  │
│ Senior Data Scient…  │ Ireland, Hong Kong, Puerto Rico, Namibia, Luxembourg, Armenia, Malta, Estonia, Venezuela, Slovenia, Cambodia, Papua Ne…  │
│ Senior Data Engineer │ United States, India, Germany, Malaysia, Ukraine, Saudi Arabia, Malawi, Dominican Republic, Indonesia, Canada, Egypt, …  │
│ Software Engineer    │ Argentina, Slovakia, Moldova, Ecuador, Norway, New Zealand, Puerto Rico, Namibia, Ireland, Hong Kong, Malta, Luxembour…  │
│ Data Analyst         │ Vietnam, Australia, Pakistan, Ghana, Tajikistan, Palestine, Haiti, Uruguay, United Arab Emirates, Taiwan, Latvia, Hond…  │
│ Data Scientist       │ Canada, France, Egypt, Turkey, Indonesia, Qatar, China, Côte d'Ivoire, Guatemala, Jamaica, Senegal, Zambia, El Salvado…  │
│ Business Analyst     │ Singapore, Bulgaria, Thailand, Sweden, Portugal, Romania, Albania, Paraguay, Suriname, Mozambique, Philippines, Serbia…  │
├──────────────────────┴──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 10 rows                                                                                                                               2 columns │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

-- This is really useful in data engineering when you need
-- to denormalize data — turning multiple rows into one.


-- ============================================================
-- COMMON MISTAKES WITH GROUP BY
-- ============================================================

-- 1. Forgetting GROUP BY when using aggregates with other columns
--    WRONG:  SELECT job_title_short, COUNT(*) FROM job_postings_fact;
--    RIGHT:  SELECT job_title_short, COUNT(*) FROM job_postings_fact GROUP BY job_title_short;

-- 2. Using WHERE instead of HAVING for aggregate conditions
--    WRONG:  WHERE COUNT(*) > 10
--    RIGHT:  HAVING COUNT(*) > 10

-- 3. Using column alias in HAVING (varies by database)
--    In DuckDB/PostgreSQL: HAVING job_count > 10  ← works
--    In MySQL/others: HAVING COUNT(*) > 10         ← safer


-- ============================================================
-- TRY THIS
-- ============================================================
-- 1. Find the average salary for each job_country (top 10 by avg salary)

-- 2. Which job locations have more than 500 postings?
--    (Show location and count, sorted by count descending)
--
-- 3. For Data Engineer jobs only, find the average and median
--    salary per country, but only countries with 50+ postings

