-- ============================================================
-- LESSON 1.02: SELECT — Your First Query
-- ============================================================
-- SELECT is the most fundamental SQL statement. It's how you
-- ask the database to show you data. Every query you'll ever
-- write starts here.
-- ============================================================


-- The simplest possible query: "show me everything"
-- The * means "all columns"

SELECT *
FROM job_postings_fact;

-- That probably returned a LOT of rows. Let's limit it.
-- LIMIT restricts how many rows come back.

SELECT *
FROM job_postings_fact
LIMIT 10;

/*
┌────────┬────────────┬─────────────────────┬──────────────────────┬───────────────────┬───┬──────────────────────┬───────────────┬─────────────┬─────────────────┬─────────────────┐
│ job_id │ company_id │   job_title_short   │      job_title       │   job_location    │ … │ job_health_insurance │  job_country  │ salary_rate │ salary_year_avg │ salary_hour_avg │
│ int32  │   int32    │       varchar       │       varchar        │      varchar      │   │       boolean        │    varchar    │   varchar   │     double      │     double      │
├────────┼────────────┼─────────────────────┼──────────────────────┼───────────────────┼───┼──────────────────────┼───────────────┼─────────────┼─────────────────┼─────────────────┤
│   4593 │       4593 │ Data Analyst        │ Data Analyst         │ New York, NY      │ … │ false                │ United States │ NULL        │            NULL │            NULL │
│   4594 │       4594 │ Data Analyst        │ Data Analyst         │ Washington, DC    │ … │ true                 │ United States │ NULL        │            NULL │            NULL │
│   4595 │       4595 │ Data Analyst        │ Data Analyst         │ Fairfax, VA       │ … │ false                │ United States │ NULL        │            NULL │            NULL │
│   4596 │       4596 │ Senior Data Analyst │ Senior Data Analys…  │ Worcester, MA     │ … │ true                 │ United States │ NULL        │            NULL │            NULL │
│   4597 │       4597 │ Data Analyst        │ Data Analyst         │ Sunnyvale, CA     │ … │ false                │ United States │ NULL        │            NULL │            NULL │
│   4598 │       4598 │ Data Analyst        │ Jr. Data Analyst     │ Torrance, CA      │ … │ false                │ United States │ NULL        │            NULL │            NULL │
│   4599 │       4599 │ Data Analyst        │ Data Analyst         │ San Francisco, CA │ … │ false                │ United States │ NULL        │            NULL │            NULL │
│   4600 │       4600 │ Data Analyst        │ Loyalty Data Analy…  │ Pleasanton, CA    │ … │ false                │ United States │ NULL        │            NULL │            NULL │
│   4601 │       4601 │ Senior Data Analyst │ Senior data analyst  │ Rosemead, CA      │ … │ true                 │ United States │ NULL        │            NULL │            NULL │
│   4602 │       4602 │ Business Analyst    │ Business Analyst -…  │ Thousand Oaks, CA │ … │ false                │ United States │ NULL        │            NULL │            NULL │
├────────┴────────────┴─────────────────────┴──────────────────────┴───────────────────┴───┴──────────────────────┴───────────────┴─────────────┴─────────────────┴─────────────────┤
│ 10 rows                                                                                                                                                     16 columns (10 shown) │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
-- Much better. Now let's pick specific columns instead of *.
-- In real work, you almost never use * — you pick what you need.

SELECT
    job_id,
    job_title,
    job_location,
    salary_year_avg
FROM job_postings_fact
LIMIT 10;
 /*
┌────────┬───────────────────────────────────────────┬───────────────────┬─────────────────┐
│ job_id │                 job_title                 │   job_location    │ salary_year_avg │
│ int32  │                  varchar                  │      varchar      │     double      │
├────────┼───────────────────────────────────────────┼───────────────────┼─────────────────┤
│   4593 │ Data Analyst                              │ New York, NY      │            NULL │
│   4594 │ Data Analyst                              │ Washington, DC    │            NULL │
│   4595 │ Data Analyst                              │ Fairfax, VA       │            NULL │
│   4596 │ Senior Data Analyst / Platform Experience │ Worcester, MA     │            NULL │
│   4597 │ Data Analyst                              │ Sunnyvale, CA     │            NULL │
│   4598 │ Jr. Data Analyst                          │ Torrance, CA      │            NULL │
│   4599 │ Data Analyst                              │ San Francisco, CA │            NULL │
│   4600 │ Loyalty Data Analyst III                  │ Pleasanton, CA    │            NULL │
│   4601 │ Senior data analyst                       │ Rosemead, CA      │            NULL │
│   4602 │ Business Analyst - Taxonomy/Ontology      │ Thousand Oaks, CA │            NULL │
├────────┴───────────────────────────────────────────┴───────────────────┴─────────────────┤
│ 10 rows                                                                        4 columns │
└──────────────────────────────────────────────────────────────────────────────────────────┘
 */

-- ============================================================
-- ALIASES: Renaming Columns with AS
-- ============================================================
-- Column names from databases are often ugly or unclear.
-- AS lets you rename them in the output.

SELECT
    job_id,
    job_title AS title,
    job_location AS location,
    salary_year_avg AS avg_salary
FROM job_postings_fact
LIMIT 10;

/*

┌────────┬───────────────────────────────────────────┬───────────────────┬────────────┐
│ job_id │                   title                   │     location      │ avg_salary │
│ int32  │                  varchar                  │      varchar      │   double   │
├────────┼───────────────────────────────────────────┼───────────────────┼────────────┤
│   4593 │ Data Analyst                              │ New York, NY      │       NULL │
│   4594 │ Data Analyst                              │ Washington, DC    │       NULL │
│   4595 │ Data Analyst                              │ Fairfax, VA       │       NULL │
│   4596 │ Senior Data Analyst / Platform Experience │ Worcester, MA     │       NULL │
│   4597 │ Data Analyst                              │ Sunnyvale, CA     │       NULL │
│   4598 │ Jr. Data Analyst                          │ Torrance, CA      │       NULL │
│   4599 │ Data Analyst                              │ San Francisco, CA │       NULL │
│   4600 │ Loyalty Data Analyst III                  │ Pleasanton, CA    │       NULL │
│   4601 │ Senior data analyst                       │ Rosemead, CA      │       NULL │
│   4602 │ Business Analyst - Taxonomy/Ontology      │ Thousand Oaks, CA │       NULL │
├────────┴───────────────────────────────────────────┴───────────────────┴────────────┤
│ 10 rows                                                                   4 columns │
└─────────────────────────────────────────────────────────────────────────────────────┘
*/
-- You can also skip the AS keyword — it's optional.
-- But I always use it because it's clearer.

SELECT
    job_id,
    job_title title           -- works, but less readable
FROM job_postings_fact
LIMIT 5;

/*

┌────────┬───────────────────────────────────────────┐
│ job_id │                   title                   │
│ int32  │                  varchar                  │
├────────┼───────────────────────────────────────────┤
│   4593 │ Data Analyst                              │
│   4594 │ Data Analyst                              │
│   4595 │ Data Analyst                              │
│   4596 │ Senior Data Analyst / Platform Experience │
│   4597 │ Data Analyst                              │
└────────┴───────────────────────────────────────────┘
*/

-- ============================================================
-- TABLE ALIASES
-- ============================================================
-- When table names are long, you give them short aliases.
-- This becomes essential when you start joining tables.

SELECT
    jpf.job_id,
    jpf.job_title,
    jpf.job_location
FROM job_postings_fact AS jpf
LIMIT 5;

-- "jpf" is just a shorthand for "job_postings_fact"
-- You'll see this pattern everywhere in these lessons.


-- ============================================================
-- DISTINCT — Remove Duplicates
-- ============================================================
-- Sometimes you want to see unique values only.

-- What job title categories exist?
SELECT DISTINCT job_title_short
FROM job_postings_fact;

/*

┌───────────────────────────┐
│      job_title_short      │
│          varchar          │
├───────────────────────────┤
│ Senior Data Analyst       │
│ Machine Learning Engineer │
│ Cloud Engineer            │
│ Data Engineer             │
│ Data Scientist            │
│ Business Analyst          │
│ Data Analyst              │
│ Software Engineer         │
│ Senior Data Engineer      │
│ Senior Data Scientist     │
├───────────────────────────┤
│          10 rows          │
└───────────────────────────┘
*/

-- What countries have job postings?
SELECT DISTINCT job_country
FROM job_postings_fact
LIMIT 20;
/*

┌─────────────┐
│ job_country │
│   varchar   │
├─────────────┤
│ Denmark     │
│ Hungary     │
│ Oman        │
│ Nicaragua   │
│ Kuwait      │
│ Afghanistan │
│ Guam        │
│ Rwanda      │
│ Hong Kong   │
│ Ecuador     │
│ Argentina   │
│ Slovakia    │
│ Norway      │
│ New Zealand │
│ Moldova     │
│ Philippines │
│ Nigeria     │
│ Serbia      │
│ Cameroon    │
│ Guinea      │
├─────────────┤
│   20 rows   │
└─────────────┘
*/

-- DISTINCT on multiple columns means unique COMBINATIONS
SELECT DISTINCT
    job_title_short,
    job_country
FROM job_postings_fact
LIMIT 20;
/*

┌───────────────────────┬───────────────┐
│    job_title_short    │  job_country  │
│        varchar        │    varchar    │
├───────────────────────┼───────────────┤
│ Data Analyst          │ Japan         │
│ Senior Data Scientist │ United States │
│ Data Analyst          │ Spain         │
│ Business Analyst      │ Denmark       │
│ Senior Data Engineer  │ Ireland       │
│ Senior Data Scientist │ India         │
│ Data Analyst          │ Mexico        │
│ Software Engineer     │ France        │
│ Data Analyst          │ Netherlands   │
│ Data Scientist        │ Slovakia      │
│ Business Analyst      │ Oman          │
│ Software Engineer     │ Canada        │
│ Data Analyst          │ Belgium       │
│ Software Engineer     │ Qatar         │
│ Data Scientist        │ Argentina     │
│ Data Analyst          │ Russia        │
│ Senior Data Scientist │ Germany       │
│ Data Engineer         │ Lithuania     │
│ Data Scientist        │ New Zealand   │
│ Software Engineer     │ China         │
├───────────────────────┴───────────────┤
│ 20 rows                     2 columns │
└───────────────────────────────────────┘
*/

-- ============================================================
-- EXPRESSIONS & CALCULATIONS
-- ============================================================
-- You can do math and transformations right in SELECT.

-- Convert annual salary to monthly
SELECT
    job_id,
    job_title,
    salary_year_avg AS annual_salary,
    salary_year_avg / 12 AS monthly_salary
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 10;
/*

┌────────┬───────────────────────────────────┬───────────────┬────────────────────┐
│ job_id │             job_title             │ annual_salary │   monthly_salary   │
│ int32  │              varchar              │    double     │       double       │
├────────┼───────────────────────────────────┼───────────────┼────────────────────┤
│   4651 │ Data Scientist                    │      110000.0 │  9166.666666666666 │
│   4699 │ Data Engineer                     │       65000.0 │  5416.666666666667 │
│   4804 │ Hospitality Operations Analyst    │       90000.0 │             7500.0 │
│   4810 │ Data Analytics Professional       │       55000.0 │  4583.333333333333 │
│   4833 │ Lead Data Scientist (Hybrid)      │      120531.0 │           10044.25 │
│   4846 │ Data Engineer - Revenue Platforms │      300000.0 │            25000.0 │
│   5089 │ Junior Data Analyst               │       51000.0 │             4250.0 │
│   5123 │ Data Science Manager              │      133500.0 │            11125.0 │
│   5321 │ HR Data Analyst                   │       77500.0 │  6458.333333333333 │
│   5325 │ Data Scientist                    │      125000.0 │ 10416.666666666666 │
├────────┴───────────────────────────────────┴───────────────┴────────────────────┤
│ 10 rows                                                               4 columns │
└─────────────────────────────────────────────────────────────────────────────────┘
*/

-- String concatenation (joining text together)
SELECT
    job_id,
    job_title_short || ' at ' || job_location AS job_summary
FROM job_postings_fact
LIMIT 10;
/*

┌────────┬───────────────────────────────────────┐
│ job_id │              job_summary              │
│ int32  │                varchar                │
├────────┼───────────────────────────────────────┤
│   4593 │ Data Analyst at New York, NY          │
│   4594 │ Data Analyst at Washington, DC        │
│   4595 │ Data Analyst at Fairfax, VA           │
│   4596 │ Senior Data Analyst at Worcester, MA  │
│   4597 │ Data Analyst at Sunnyvale, CA         │
│   4598 │ Data Analyst at Torrance, CA          │
│   4599 │ Data Analyst at San Francisco, CA     │
│   4600 │ Data Analyst at Pleasanton, CA        │
│   4601 │ Senior Data Analyst at Rosemead, CA   │
│   4602 │ Business Analyst at Thousand Oaks, CA │
├────────┴───────────────────────────────────────┤
│ 10 rows                              2 columns │
└────────────────────────────────────────────────┘
*/

-- ============================================================
-- NULL VALUES
-- ============================================================
-- NULL means "unknown" or "missing." It's not zero, it's not
-- an empty string — it's the absence of a value.
--
-- This matters A LOT in data engineering. Many salary fields
-- or optional fields will be NULL.

-- Find rows where salary is missing
SELECT
    job_id,
    job_title,
    salary_year_avg
FROM job_postings_fact
WHERE salary_year_avg IS NULL
LIMIT 10;

/*

┌────────┬───────────────────────────────────────────┬─────────────────┐
│ job_id │                 job_title                 │ salary_year_avg │
│ int32  │                  varchar                  │     double      │
├────────┼───────────────────────────────────────────┼─────────────────┤
│   4593 │ Data Analyst                              │            NULL │
│   4594 │ Data Analyst                              │            NULL │
│   4595 │ Data Analyst                              │            NULL │
│   4596 │ Senior Data Analyst / Platform Experience │            NULL │
│   4597 │ Data Analyst                              │            NULL │
│   4598 │ Jr. Data Analyst                          │            NULL │
│   4599 │ Data Analyst                              │            NULL │
│   4600 │ Loyalty Data Analyst III                  │            NULL │
│   4601 │ Senior data analyst                       │            NULL │
│   4602 │ Business Analyst - Taxonomy/Ontology      │            NULL │
├────────┴───────────────────────────────────────────┴─────────────────┤
│ 10 rows                                                    3 columns │
└──────────────────────────────────────────────────────────────────────┘
*/

-- Find rows where salary EXISTS
SELECT
    job_id,
    job_title,
    salary_year_avg
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 10;
/*

┌────────┬───────────────────────────────────┬─────────────────┐
│ job_id │             job_title             │ salary_year_avg │
│ int32  │              varchar              │     double      │
├────────┼───────────────────────────────────┼─────────────────┤
│   4651 │ Data Scientist                    │        110000.0 │
│   4699 │ Data Engineer                     │         65000.0 │
│   4804 │ Hospitality Operations Analyst    │         90000.0 │
│   4810 │ Data Analytics Professional       │         55000.0 │
│   4833 │ Lead Data Scientist (Hybrid)      │        120531.0 │
│   4846 │ Data Engineer - Revenue Platforms │        300000.0 │
│   5089 │ Junior Data Analyst               │         51000.0 │
│   5123 │ Data Science Manager              │        133500.0 │
│   5321 │ HR Data Analyst                   │         77500.0 │
│   5325 │ Data Scientist                    │        125000.0 │
├────────┴───────────────────────────────────┴─────────────────┤
│ 10 rows                                            3 columns │
└──────────────────────────────────────────────────────────────┘
*/

-- IMPORTANT: You can NOT use = NULL or != NULL
-- These don't work:
--   WHERE salary_year_avg = NULL     ← WRONG
--   WHERE salary_year_avg != NULL    ← WRONG
-- Always use IS NULL / IS NOT NULL


-- ============================================================
-- TRY THIS
-- ============================================================
-- 1. Select just the job_title and job_country columns,
--    limited to 15 rows
--
-- 2. Find all DISTINCT values of job_title_short
--
-- 3. Select job_id, job_title, and calculate what a 10% raise
--    on salary_year_avg would be (only where salary exists)
SELECT
    job_id,
    job_title,
    salary_year_avg * 1.10 AS salary_with_raise
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 10;

/*

┌────────┬───────────────────────────────────┬────────────────────┐
│ job_id │             job_title             │ salary_with_raise  │
│ int32  │              varchar              │       double       │
├────────┼───────────────────────────────────┼────────────────────┤
│   4651 │ Data Scientist                    │ 121000.00000000001 │
│   4699 │ Data Engineer                     │            71500.0 │
│   4804 │ Hospitality Operations Analyst    │  99000.00000000001 │
│   4810 │ Data Analytics Professional       │  60500.00000000001 │
│   4833 │ Lead Data Scientist (Hybrid)      │           132584.1 │
│   4846 │ Data Engineer - Revenue Platforms │           330000.0 │
│   5089 │ Junior Data Analyst               │  56100.00000000001 │
│   5123 │ Data Science Manager              │           146850.0 │
│   5321 │ HR Data Analyst                   │            85250.0 │
│   5325 │ Data Scientist                    │           137500.0 │
├────────┴───────────────────────────────────┴────────────────────┤
│ 10 rows                                               3 columns │
└─────────────────────────────────────────────────────────────────┘
*/
--Practise these basics until they feel natural. In the next lesson, we'll start joining tables together to combine data from multiple sources.