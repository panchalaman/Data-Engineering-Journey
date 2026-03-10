-- ============================================================
-- LESSON 1.10: Window Functions
-- ============================================================
-- Window functions are probably the single most important
-- concept that separates "I know SQL" from "I actually build
-- data pipelines with SQL." They let you do calculations
-- ACROSS rows without collapsing them into groups.
--
-- GROUP BY gives you one row per group.
-- Window functions keep every row but add computed columns.
--
-- Every window function follows this pattern:
--   FUNCTION() OVER (PARTITION BY ... ORDER BY ...)
-- ============================================================


-- ============================================================
-- ROW_NUMBER — Assign Sequential Numbers
-- ============================================================

-- Number each job posting by salary (highest first)
SELECT
    job_title_short,
    salary_year_avg,
    ROW_NUMBER() OVER (ORDER BY salary_year_avg DESC) AS salary_rank
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 15;
/*

┌───────────────────────────┬─────────────────┬─────────────┐
│      job_title_short      │ salary_year_avg │ salary_rank │
│          varchar          │     double      │    int64    │
├───────────────────────────┼─────────────────┼─────────────┤
│ Data Scientist            │        960000.0 │           1 │
│ Data Scientist            │        920000.0 │           2 │
│ Senior Data Scientist     │        890000.0 │           3 │
│ Machine Learning Engineer │        875000.0 │           4 │
│ Data Scientist            │        870000.0 │           5 │
│ Data Scientist            │        850000.0 │           6 │
│ Senior Data Engineer      │        800000.0 │           7 │
│ Machine Learning Engineer │        800000.0 │           8 │
│ Data Scientist            │        680000.0 │           9 │
│ Data Analyst              │        650000.0 │          10 │
│ Data Scientist            │        640000.0 │          11 │
│ Data Engineer             │        640000.0 │          12 │
│ Data Scientist            │        585000.0 │          13 │
│ Data Scientist            │        550000.0 │          14 │
│ Data Engineer             │        525000.0 │          15 │
├───────────────────────────┴─────────────────┴─────────────┤
│ 15 rows                                         3 columns │
└───────────────────────────────────────────────────────────┘
*/

-- ROW_NUMBER + PARTITION BY
-- Rank salaries WITHIN each job title
SELECT
    job_title_short,
    company_id,
    salary_year_avg,
    ROW_NUMBER() OVER (
        PARTITION BY job_title_short
        ORDER BY salary_year_avg DESC
    ) AS rank_within_role
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
ORDER BY job_title_short, rank_within_role
LIMIT 20;
/*

┌──────────────────┬────────────┬─────────────────┬──────────────────┐
│ job_title_short  │ company_id │ salary_year_avg │ rank_within_role │
│     varchar      │   int32    │     double      │      int64       │
├──────────────────┼────────────┼─────────────────┼──────────────────┤
│ Business Analyst │     951196 │        390000.0 │                1 │
│ Business Analyst │       5987 │        387460.0 │                2 │
│ Business Analyst │       6334 │        286000.0 │                3 │
│ Business Analyst │       5429 │        268500.0 │                4 │
│ Business Analyst │     365247 │        264000.0 │                5 │
│ Business Analyst │     365247 │        264000.0 │                6 │
│ Business Analyst │     365247 │        264000.0 │                7 │
│ Business Analyst │     324715 │        257937.0 │                8 │
│ Business Analyst │     301981 │        257500.0 │                9 │
│ Business Analyst │       6334 │        250000.0 │               10 │
│ Business Analyst │     722748 │        250000.0 │               11 │
│ Business Analyst │      13226 │        243500.0 │               12 │
│ Business Analyst │    1089315 │        230000.0 │               13 │
│ Business Analyst │      18678 │        229000.0 │               14 │
│ Business Analyst │     928629 │        226000.0 │               15 │
│ Business Analyst │     252621 │        220000.0 │               16 │
│ Business Analyst │      39393 │        220000.0 │               17 │
│ Business Analyst │       5765 │        214500.0 │               18 │
│ Business Analyst │       5765 │        214500.0 │               19 │
│ Business Analyst │       9445 │        214000.0 │               20 │
├──────────────────┴────────────┴─────────────────┴──────────────────┤
│ 20 rows                                                  4 columns │
└────────────────────────────────────────────────────────────────────┘
*/
-- The classic pattern: "Top N per group"
-- Get the highest-paying posting for each role
WITH ranked AS (
    SELECT
        job_title_short,
        job_title,
        salary_year_avg,
        ROW_NUMBER() OVER (
            PARTITION BY job_title_short
            ORDER BY salary_year_avg DESC
        ) AS rn
    FROM job_postings_fact
    WHERE salary_year_avg IS NOT NULL
)
SELECT *
FROM ranked
WHERE rn = 1
ORDER BY salary_year_avg DESC;
/*

┌───────────────────────────┬────────────────────────────────────────────────┬─────────────────┬───────┐
│      job_title_short      │                   job_title                    │ salary_year_avg │  rn   │
│          varchar          │                    varchar                     │     double      │ int64 │
├───────────────────────────┼────────────────────────────────────────────────┼─────────────────┼───────┤
│ Data Scientist            │ Data Scientist                                 │        960000.0 │     1 │
│ Senior Data Scientist     │ Senior Data Scientist                          │        890000.0 │     1 │
│ Machine Learning Engineer │ Machine Learning Engineer                      │        875000.0 │     1 │
│ Senior Data Engineer      │ Senior Data Engineer (MDM team), DTG           │        800000.0 │     1 │
│ Data Analyst              │ Data Analyst                                   │        650000.0 │     1 │
│ Data Engineer             │ Manager, Content Data Engineering              │        640000.0 │     1 │
│ Software Engineer         │ PhD Computer Scientist/Software Developer $1M+ │        425000.0 │     1 │
│ Senior Data Analyst       │ SVP, Data Analytics                            │        425000.0 │     1 │
│ Business Analyst          │ Старший продуктовый аналитик                   │        390000.0 │     1 │
│ Cloud Engineer            │ Platform and Technical Communications Lead     │        305000.0 │     1 │
├───────────────────────────┴────────────────────────────────────────────────┴─────────────────┴───────┤
│ 10 rows                                                                                    4 columns │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
-- This "Top N per group" pattern is super common in analytics:
-- - Top 3 products by sales in each category
-- - Top 5 customers by revenue in each region
-- - Highest-rated movies in each genre
-- - etc.

-- This pattern comes up ALL THE TIME:
--   1. Assign row numbers within partitions
--   2. Wrap in CTE
--   3. Filter where rn = 1 (or rn <= 3 for top 3, etc.)
-- I used this in almost every analytics project.


-- ============================================================
-- RANK vs DENSE_RANK vs ROW_NUMBER
-- ============================================================

-- The difference matters when there are ties:
--   ROW_NUMBER: 1, 2, 3, 4    (no ties, always unique)
--   RANK:       1, 2, 2, 4    (ties skip numbers)
--   DENSE_RANK: 1, 2, 2, 3    (ties don't skip)

SELECT
    job_title_short,
    salary_year_avg,
    ROW_NUMBER() OVER (ORDER BY salary_year_avg DESC) AS row_num,
    RANK()       OVER (ORDER BY salary_year_avg DESC) AS rank,
    DENSE_RANK() OVER (ORDER BY salary_year_avg DESC) AS dense_rank
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 15;

-- For "top N per group" queries, I almost always use
-- ROW_NUMBER because I want exactly N results.
-- RANK/DENSE_RANK are better when you want to handle
-- ties explicitly (like "everyone tied for 3rd place").


-- ============================================================
-- LAG and LEAD — Access Previous/Next Rows
-- ============================================================

-- LAG looks at the PREVIOUS row, LEAD looks NEXT.
-- This is how you calculate period-over-period changes.

-- Monthly posting counts with month-over-month change
WITH monthly_counts AS (
    SELECT
        DATE_TRUNC('month', job_posted_date) AS month,
        COUNT(*) AS job_count
    FROM job_postings_fact
    GROUP BY DATE_TRUNC('month', job_posted_date)
)
SELECT
    month,
    job_count,
    LAG(job_count) OVER (ORDER BY month) AS prev_month_count,
    job_count - LAG(job_count) OVER (ORDER BY month) AS mom_change,
    ROUND(
        100.0 * (job_count - LAG(job_count) OVER (ORDER BY month))
        / LAG(job_count) OVER (ORDER BY month),
        1
    ) AS mom_pct_change
FROM monthly_counts
ORDER BY month;

-- LEAD example — what's the NEXT month look like?
WITH monthly_counts AS (
    SELECT
        DATE_TRUNC('month', job_posted_date) AS month,
        COUNT(*) AS job_count
    FROM job_postings_fact
    GROUP BY DATE_TRUNC('month', job_posted_date)
)
SELECT
    month,
    job_count,
    LEAD(job_count) OVER (ORDER BY month) AS next_month_count
FROM monthly_counts
ORDER BY month;

-- LAG/LEAD with offset > 1
-- Compare to 3 months ago:
WITH monthly_counts AS (
    SELECT
        DATE_TRUNC('month', job_posted_date) AS month,
        COUNT(*) AS job_count
    FROM job_postings_fact
    GROUP BY DATE_TRUNC('month', job_posted_date)
)
SELECT
    month,
    job_count,
    LAG(job_count, 3) OVER (ORDER BY month) AS three_months_ago,
    job_count - LAG(job_count, 3) OVER (ORDER BY month) AS qoq_change
FROM monthly_counts
ORDER BY month;


-- ============================================================
-- Running Totals and Moving Averages
-- ============================================================

-- SUM() OVER — Running Total
WITH monthly_counts AS (
    SELECT
        DATE_TRUNC('month', job_posted_date) AS month,
        COUNT(*) AS job_count
    FROM job_postings_fact
    GROUP BY DATE_TRUNC('month', job_posted_date)
)
SELECT
    month,
    job_count,
    SUM(job_count) OVER (ORDER BY month) AS running_total,
    AVG(job_count) OVER (ORDER BY month) AS running_avg
FROM monthly_counts
ORDER BY month;

-- Moving Average (3-month window)
-- This is huge in time-series analysis.
WITH monthly_counts AS (
    SELECT
        DATE_TRUNC('month', job_posted_date) AS month,
        COUNT(*) AS job_count
    FROM job_postings_fact
    GROUP BY DATE_TRUNC('month', job_posted_date)
)
SELECT
    month,
    job_count,
    AVG(job_count) OVER (
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3m
FROM monthly_counts
ORDER BY month;
-- ROWS BETWEEN defines the "window frame."
-- "2 PRECEDING AND CURRENT ROW" means:
--   current row + 2 rows before it = 3 rows total.


-- ============================================================
-- Window Frame Clauses (ROWS vs RANGE)
-- ============================================================
-- By default, window functions use:
--   RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--
-- You can control this:
--   ROWS BETWEEN ... — physical row count
--   RANGE BETWEEN ... — logical value range
--
-- Common frames:
--   UNBOUNDED PRECEDING AND CURRENT ROW  — everything up to here
--   2 PRECEDING AND CURRENT ROW          — last 3 rows
--   1 PRECEDING AND 1 FOLLOWING          — 3-row centered window
--   UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING  — entire partition


-- ============================================================
-- Aggregate Window Functions
-- ============================================================

-- Regular aggregates as window functions — they don't collapse rows.
SELECT
    job_title_short,
    salary_year_avg,
    COUNT(*) OVER (PARTITION BY job_title_short) AS role_count,
    AVG(salary_year_avg) OVER (PARTITION BY job_title_short) AS role_avg_salary,
    MIN(salary_year_avg) OVER (PARTITION BY job_title_short) AS role_min_salary,
    MAX(salary_year_avg) OVER (PARTITION BY job_title_short) AS role_max_salary
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
ORDER BY job_title_short, salary_year_avg DESC
LIMIT 20;

-- How does each posting compare to its role average?
SELECT
    job_title_short,
    salary_year_avg,
    AVG(salary_year_avg) OVER (PARTITION BY job_title_short) AS role_avg,
    salary_year_avg - AVG(salary_year_avg) OVER (PARTITION BY job_title_short) AS diff_from_avg,
    ROUND(
        100.0 * salary_year_avg /
        AVG(salary_year_avg) OVER (PARTITION BY job_title_short),
        1
    ) AS pct_of_avg
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
ORDER BY pct_of_avg DESC
LIMIT 20;


-- ============================================================
-- NTILE — Split Into Buckets
-- ============================================================

-- Divide salaries into quartiles
SELECT
    job_title_short,
    salary_year_avg,
    NTILE(4) OVER (ORDER BY salary_year_avg) AS salary_quartile
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 20;

-- Salary quartiles within each role
SELECT
    job_title_short,
    salary_year_avg,
    NTILE(4) OVER (
        PARTITION BY job_title_short
        ORDER BY salary_year_avg
    ) AS salary_quartile
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
ORDER BY job_title_short, salary_quartile
LIMIT 20;


-- ============================================================
-- FIRST_VALUE / LAST_VALUE
-- ============================================================

-- What's the highest salary for each role?
-- (without collapsing rows)
SELECT
    job_title_short,
    salary_year_avg,
    FIRST_VALUE(salary_year_avg) OVER (
        PARTITION BY job_title_short
        ORDER BY salary_year_avg DESC
    ) AS highest_in_role,
    salary_year_avg / FIRST_VALUE(salary_year_avg) OVER (
        PARTITION BY job_title_short
        ORDER BY salary_year_avg DESC
    ) AS pct_of_highest
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
ORDER BY job_title_short, salary_year_avg DESC
LIMIT 20;


-- ============================================================
-- REAL PATTERN: De-duplication with Window Functions
-- ============================================================
-- This is probably the #1 use of window functions in data
-- engineering. You get duplicate records and need to keep
-- only the latest one.

-- Scenario: keep only the most recent posting per company per role
WITH deduped AS (
    SELECT
        company_id,
        job_title_short,
        job_title,
        salary_year_avg,
        job_posted_date,
        ROW_NUMBER() OVER (
            PARTITION BY company_id, job_title_short
            ORDER BY job_posted_date DESC
        ) AS rn
    FROM job_postings_fact
    WHERE salary_year_avg IS NOT NULL
)
SELECT
    company_id,
    job_title_short,
    job_title,
    salary_year_avg,
    job_posted_date
FROM deduped
WHERE rn = 1
ORDER BY salary_year_avg DESC
LIMIT 20;

-- In real ETL pipelines, this pattern is everywhere:
--   1. Data arrives with duplicates
--   2. Use ROW_NUMBER() PARTITION BY the unique key
--      ORDER BY the "freshness" column (date, version, etc.)
--   3. Filter rn = 1


-- ============================================================
-- REAL PATTERN: Percentile Ranking
-- ============================================================

SELECT
    job_title_short,
    salary_year_avg,
    PERCENT_RANK() OVER (
        PARTITION BY job_title_short
        ORDER BY salary_year_avg
    ) AS percentile
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
ORDER BY job_title_short, percentile DESC
LIMIT 20;

-- Find the 90th percentile salary for each role
WITH ranked AS (
    SELECT
        job_title_short,
        salary_year_avg,
        PERCENT_RANK() OVER (
            PARTITION BY job_title_short
            ORDER BY salary_year_avg
        ) AS percentile
    FROM job_postings_fact
    WHERE salary_year_avg IS NOT NULL
)
SELECT
    job_title_short,
    MIN(salary_year_avg) AS p90_salary
FROM ranked
WHERE percentile >= 0.90
GROUP BY job_title_short
ORDER BY p90_salary DESC;


-- ============================================================
-- MULTIPLE WINDOW DEFINITIONS (WINDOW clause)
-- ============================================================
-- When you use the same OVER clause multiple times,
-- you can define it once with WINDOW.

SELECT
    job_title_short,
    salary_year_avg,
    ROW_NUMBER() OVER w AS row_num,
    RANK() OVER w AS rank,
    AVG(salary_year_avg) OVER w AS running_avg
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
WINDOW w AS (PARTITION BY job_title_short ORDER BY salary_year_avg DESC)
LIMIT 20;

-- Cleaner than repeating the same OVER clause 3 times.


-- ============================================================
-- CHEAT SHEET
-- ============================================================
-- ROW_NUMBER()  — unique sequential number per partition
-- RANK()        — same rank for ties, gaps after
-- DENSE_RANK()  — same rank for ties, no gaps
-- NTILE(n)      — split into n equal buckets
-- LAG(col, n)   — value from n rows back (default 1)
-- LEAD(col, n)  — value from n rows ahead
-- FIRST_VALUE() — first value in window frame
-- LAST_VALUE()  — last value in window frame (careful with frame!)
-- SUM/AVG/etc.  — aggregate over window without collapsing
-- PERCENT_RANK()— percentile ranking (0 to 1)
--
-- Key patterns:
-- - Top N per group: ROW_NUMBER + CTE + WHERE rn <= N
-- - Dedup: ROW_NUMBER + CTE + WHERE rn = 1
-- - Period-over-period: LAG/LEAD
-- - Running totals: SUM() OVER (ORDER BY ...)
-- - Moving average: AVG() OVER (ROWS BETWEEN ... AND ...)


-- ============================================================
-- TRY THIS
-- ============================================================
-- 1. Find the top 3 highest-paying job postings for each role
--    (use ROW_NUMBER + CTE)
--
-- 2. Calculate the month-over-month percentage change in
--    Data Engineer postings specifically
--
-- 3. For each job posting, show the salary and what percentile
--    it falls in within its role. Filter to only show postings
--    that are in the top 10% (percentile >= 0.9)
--
-- 4. Calculate a 3-month moving average of average salary
--    for Data Analyst postings
