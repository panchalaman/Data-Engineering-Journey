-- ============================================================
-- LESSON 1.06: CASE WHEN — Conditional Logic
-- ============================================================
-- CASE WHEN is SQL's version of if/else. It lets you create
-- new columns based on conditions — categorizing data,
-- creating flags, bucketing values. You'll use this constantly
-- in data transformations.
-- ============================================================


-- ============================================================
-- BASIC CASE WHEN
-- ============================================================

-- Categorize jobs by salary level
SELECT
    job_id,
    job_title,
    salary_year_avg,
    CASE
        WHEN salary_year_avg >= 200000 THEN 'Very High'
        WHEN salary_year_avg >= 150000 THEN 'High'
        WHEN salary_year_avg >= 100000 THEN 'Medium'
        WHEN salary_year_avg >= 70000 THEN 'Low'
        ELSE 'Entry Level'
    END AS salary_tier
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
ORDER BY salary_year_avg DESC
LIMIT 20;
/*

┌─────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────┬─────────────────┬─────────────┐
│ job_id  │                                               job_title                                               │ salary_year_avg │ salary_tier │
│  int32  │                                                varchar                                                │     double      │   varchar   │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────┼─────────────┤
│  296745 │ Data Scientist                                                                                        │        960000.0 │ Very High   │
│ 1231950 │ Data Science Manager - Messaging and Inferred Identity DSE at Netflix in Los Gatos, California, Uni…  │        920000.0 │ Very High   │
│  673003 │ Senior Data Scientist                                                                                 │        890000.0 │ Very High   │
│ 1575798 │ Machine Learning Engineer                                                                             │        875000.0 │ Very High   │
│ 1007105 │ Machine Learning Engineer/Data Scientist                                                              │        870000.0 │ Very High   │
│  856772 │ Data Scientist                                                                                        │        850000.0 │ Very High   │
│ 1443865 │ Senior Data Engineer (MDM team), DTG                                                                  │        800000.0 │ Very High   │
│ 1591743 │ AI/ML (Artificial Intelligence/Machine Learning) Engineer                                             │        800000.0 │ Very High   │
│ 1574285 │ Data Scientist , Games [Remote]                                                                       │        680000.0 │ Very High   │
│  142665 │ Data Analyst                                                                                          │        650000.0 │ Very High   │
│  871759 │ Manager, Content Data Engineering                                                                     │        640000.0 │ Very High   │
│ 1335282 │ Data Science Manager - Engineering                                                                    │        640000.0 │ Very High   │
│  785438 │ Geographic Information Systems Analyst - GIS Analyst                                                  │        585000.0 │ Very High   │
│  499552 │ Staff Data Scientist/Quant Researcher                                                                 │        550000.0 │ Very High   │
│  234407 │ Hybrid - Data Engineer - Up to $600k                                                                  │        525000.0 │ Very High   │
│  543480 │ Staff Data Scientist - Business Analytics                                                             │        525000.0 │ Very High   │
│ 1218524 │ VP of Data Science - Monetization Signal Growth & Privacy                                             │        475000.0 │ Very High   │
│   95558 │ Senior Data Scientist                                                                                 │        475000.0 │ Very High   │
│  685280 │ VP Data Science & Research                                                                            │        463500.0 │ Very High   │
│  494444 │ Data Engineer (L4) - Games                                                                            │        450000.0 │ Very High   │
├─────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────┴─────────────────┴─────────────┤
│ 20 rows                                                                                                                               4 columns │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/


-- How it works:
-- SQL checks each WHEN condition top to bottom.
-- As soon as one is TRUE, it uses that THEN value and stops.
-- If nothing matches, it uses ELSE.
-- ELSE is optional, but without it you get NULL for non-matches.


-- ============================================================
-- CASE WHEN WITH GROUP BY
-- ============================================================
-- This is where CASE WHEN gets really useful — combining it
-- with aggregation to create summary reports.

-- Count of jobs per salary tier
SELECT
    CASE
        WHEN salary_year_avg >= 200000 THEN 'Very High (200k+)'
        WHEN salary_year_avg >= 150000 THEN 'High (150-200k)'
        WHEN salary_year_avg >= 100000 THEN 'Medium (100-150k)'
        WHEN salary_year_avg >= 70000 THEN 'Low (70-100k)'
        ELSE 'Entry (<70k)'
    END AS salary_tier,
    COUNT(*) AS job_count,
    ROUND(AVG(salary_year_avg), 0) AS avg_salary_in_tier
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
GROUP BY salary_tier
ORDER BY avg_salary_in_tier DESC;
/*
┌───────────────────┬───────────┬────────────────────┐
│    salary_tier    │ job_count │ avg_salary_in_tier │
│      varchar      │   int64   │       double       │
├───────────────────┼───────────┼────────────────────┤
│ Very High (200k+) │      3594 │           237375.0 │
│ High (150-200k)   │      9916 │           167931.0 │
│ Medium (100-150k) │     20323 │           122311.0 │
│ Low (70-100k)     │     12133 │            84836.0 │
│ Entry (<70k)      │      5060 │            55944.0 │
└───────────────────┴───────────┴────────────────────┘
*/


-- ============================================================
-- CONDITIONAL AGGREGATION (Pivot-style)
-- ============================================================
-- This is a powerful technique — use CASE inside aggregate
-- functions to create pivot table-like output.

-- Remote vs on-site counts per job title
SELECT
    job_title_short,
    COUNT(*) AS total_jobs,
    COUNT(CASE WHEN job_work_from_home = TRUE THEN 1 END) AS remote_jobs,
    COUNT(CASE WHEN job_work_from_home = FALSE THEN 1 END) AS onsite_jobs
FROM job_postings_fact
GROUP BY job_title_short
ORDER BY total_jobs DESC;
/*

┌───────────────────────────┬────────────┬─────────────┬─────────────┐
│      job_title_short      │ total_jobs │ remote_jobs │ onsite_jobs │
│          varchar          │   int64    │    int64    │    int64    │
├───────────────────────────┼────────────┼─────────────┼─────────────┤
│ Data Analyst              │     408640 │       27185 │      381455 │
│ Data Engineer             │     391957 │       43853 │      348104 │
│ Data Scientist            │     331002 │       29331 │      301671 │
│ Business Analyst          │     101167 │        6218 │       94949 │
│ Software Engineer         │      92271 │        6980 │       85291 │
│ Senior Data Engineer      │      91295 │       13115 │       78180 │
│ Senior Data Scientist     │      70877 │        7403 │       63474 │
│ Senior Data Analyst       │      59383 │        4709 │       54674 │
│ Machine Learning Engineer │      39628 │        4416 │       35212 │
│ Cloud Engineer            │      29710 │        1322 │       28388 │
├───────────────────────────┴────────────┴─────────────┴─────────────┤
│ 10 rows                                                  4 columns │
└────────────────────────────────────────────────────────────────────┘
*/

-- Percentage of remote jobs per title
SELECT
    job_title_short,
    COUNT(*) AS total_jobs,
    ROUND(
        100.0 * COUNT(CASE WHEN job_work_from_home = TRUE THEN 1 END)
        / COUNT(*),
        1
    ) AS remote_pct
FROM job_postings_fact
GROUP BY job_title_short
ORDER BY remote_pct DESC;
/*
┌───────────────────────────┬────────────┬────────────┐
│      job_title_short      │ total_jobs │ remote_pct │
│          varchar          │   int64    │   double   │
├───────────────────────────┼────────────┼────────────┤
│ Senior Data Engineer      │      91295 │       14.4 │
│ Data Engineer             │     391957 │       11.2 │
│ Machine Learning Engineer │      39628 │       11.1 │
│ Senior Data Scientist     │      70877 │       10.4 │
│ Data Scientist            │     331002 │        8.9 │
│ Senior Data Analyst       │      59383 │        7.9 │
│ Software Engineer         │      92271 │        7.6 │
│ Data Analyst              │     408640 │        6.7 │
│ Business Analyst          │     101167 │        6.1 │
│ Cloud Engineer            │      29710 │        4.4 │
├───────────────────────────┴────────────┴────────────┤
│ 10 rows                                   3 columns │
└─────────────────────────────────────────────────────┘
*/


-- This is how I built boolean flag conversions in the
-- data mart projects. Instead of TRUE/FALSE, you convert
-- to 1/0 for aggregation:

SELECT
    job_title_short,
    SUM(CASE WHEN job_work_from_home = TRUE THEN 1 ELSE 0 END) AS remote_count,
    SUM(CASE WHEN job_no_degree_mention = TRUE THEN 1 ELSE 0 END) AS no_degree_count,
    SUM(CASE WHEN job_health_insurance = TRUE THEN 1 ELSE 0 END) AS has_insurance_count
FROM job_postings_fact
GROUP BY job_title_short
ORDER BY job_title_short;
/*

┌───────────────────────────┬──────────────┬─────────────────┬─────────────────────┐
│      job_title_short      │ remote_count │ no_degree_count │ has_insurance_count │
│          varchar          │    int128    │     int128      │       int128        │
├───────────────────────────┼──────────────┼─────────────────┼─────────────────────┤
│ Business Analyst          │         6218 │           28566 │                7776 │
│ Cloud Engineer            │         1322 │           15591 │                 569 │
│ Data Analyst              │        27185 │          166277 │               53333 │
│ Data Engineer             │        43853 │          181981 │               34391 │
│ Data Scientist            │        29331 │           28256 │               48013 │
│ Machine Learning Engineer │         4416 │            2421 │                2116 │
│ Senior Data Analyst       │         4709 │           23098 │               10591 │
│ Senior Data Engineer      │        13115 │           42296 │               11395 │
│ Senior Data Scientist     │         7403 │            6378 │               12452 │
│ Software Engineer         │         6980 │           46446 │                2851 │
├───────────────────────────┴──────────────┴─────────────────┴─────────────────────┤
│ 10 rows                                                                4 columns │
└──────────────────────────────────────────────────────────────────────────────────┘
*/


-- ============================================================
-- SIMPLE CASE (Matching a Single Value)
-- ============================================================
-- When you're just checking one column against specific values,
-- you can use the simpler syntax:

SELECT
    job_title_short,
    CASE job_title_short
        WHEN 'Data Engineer' THEN 'Engineering'
        WHEN 'Data Scientist' THEN 'Science'
        WHEN 'Data Analyst' THEN 'Analytics'
        WHEN 'Machine Learning Engineer' THEN 'ML/AI'
        ELSE 'Other'
    END AS department,
    COUNT(*) AS job_count
FROM job_postings_fact
GROUP BY job_title_short
ORDER BY job_count DESC;
/*

┌───────────────────────────┬─────────────┬───────────┐
│      job_title_short      │ department  │ job_count │
│          varchar          │   varchar   │   int64   │
├───────────────────────────┼─────────────┼───────────┤
│ Data Analyst              │ Analytics   │    408640 │
│ Data Engineer             │ Engineering │    391957 │
│ Data Scientist            │ Science     │    331002 │
│ Business Analyst          │ Other       │    101167 │
│ Software Engineer         │ Other       │     92271 │
│ Senior Data Engineer      │ Other       │     91295 │
│ Senior Data Scientist     │ Other       │     70877 │
│ Senior Data Analyst       │ Other       │     59383 │
│ Machine Learning Engineer │ ML/AI       │     39628 │
│ Cloud Engineer            │ Other       │     29710 │
├───────────────────────────┴─────────────┴───────────┤
│ 10 rows                                   3 columns │
└─────────────────────────────────────────────────────┘
*/


-- ============================================================
-- NULL HANDLING WITH CASE & COALESCE
-- ============================================================

-- Replace NULL salaries with a message
SELECT
    job_id,
    job_title,
    CASE
        WHEN salary_year_avg IS NULL THEN 'Not disclosed'
        ELSE CAST(salary_year_avg AS VARCHAR)
    END AS salary_display
FROM job_postings_fact
LIMIT 20;
/*
┌────────┬───────────────────────────────────────────────────────────┬────────────────┐
│ job_id │                         job_title                         │ salary_display │
│ int32  │                          varchar                          │    varchar     │
├────────┼───────────────────────────────────────────────────────────┼────────────────┤
│   4593 │ Data Analyst                                              │ Not disclosed  │
│   4594 │ Data Analyst                                              │ Not disclosed  │
│   4595 │ Data Analyst                                              │ Not disclosed  │
│   4596 │ Senior Data Analyst / Platform Experience                 │ Not disclosed  │
│   4597 │ Data Analyst                                              │ Not disclosed  │
│   4598 │ Jr. Data Analyst                                          │ Not disclosed  │
│   4599 │ Data Analyst                                              │ Not disclosed  │
│   4600 │ Loyalty Data Analyst III                                  │ Not disclosed  │
│   4601 │ Senior data analyst                                       │ Not disclosed  │
│   4602 │ Business Analyst - Taxonomy/Ontology                      │ Not disclosed  │
│   4603 │ Technical Data Analyst / Designer -- 2207/2000            │ Not disclosed  │
│   4604 │ Neuroscience Research Data Analyst                        │ Not disclosed  │
│   4605 │ Data Analyst                                              │ Not disclosed  │
│   4606 │ BI Data Analyst                                           │ Not disclosed  │
│   4607 │ EDI Data Analyst                                          │ Not disclosed  │
│   4608 │ Data Analyst for Member Contact Center                    │ Not disclosed  │
│   4609 │ BI Data Analyst                                           │ Not disclosed  │
│   4610 │ Data Analyst, Partner Operations (Ecosystem Partnerships) │ Not disclosed  │
│   4611 │ Guidewire Policy Data Analyst                             │ Not disclosed  │
│   4612 │ Sr. Data Analyst                                          │ Not disclosed  │
├────────┴───────────────────────────────────────────────────────────┴────────────────┤
│ 20 rows                                                                   3 columns │
└─────────────────────────────────────────────────────────────────────────────────────┘
*/

-- COALESCE is a shortcut for the "replace NULL" pattern.
-- It returns the first non-NULL value from a list.

SELECT
    job_id,
    job_title,
    COALESCE(salary_year_avg, 0) AS salary_or_zero,
    COALESCE(salary_hour_avg, salary_year_avg / 2080, 0) AS hourly_rate
FROM job_postings_fact
LIMIT 20;
/*

┌────────┬───────────────────────────────────────────────────────────┬────────────────┬─────────────┐
│ job_id │                         job_title                         │ salary_or_zero │ hourly_rate │
│ int32  │                          varchar                          │     double     │   double    │
├────────┼───────────────────────────────────────────────────────────┼────────────────┼─────────────┤
│   4593 │ Data Analyst                                              │            0.0 │         0.0 │
│   4594 │ Data Analyst                                              │            0.0 │         0.0 │
│   4595 │ Data Analyst                                              │            0.0 │         0.0 │
│   4596 │ Senior Data Analyst / Platform Experience                 │            0.0 │         0.0 │
│   4597 │ Data Analyst                                              │            0.0 │         0.0 │
│   4598 │ Jr. Data Analyst                                          │            0.0 │         0.0 │
│   4599 │ Data Analyst                                              │            0.0 │         0.0 │
│   4600 │ Loyalty Data Analyst III                                  │            0.0 │         0.0 │
│   4601 │ Senior data analyst                                       │            0.0 │         0.0 │
│   4602 │ Business Analyst - Taxonomy/Ontology                      │            0.0 │         0.0 │
│   4603 │ Technical Data Analyst / Designer -- 2207/2000            │            0.0 │         0.0 │
│   4604 │ Neuroscience Research Data Analyst                        │            0.0 │         0.0 │
│   4605 │ Data Analyst                                              │            0.0 │         0.0 │
│   4606 │ BI Data Analyst                                           │            0.0 │         0.0 │
│   4607 │ EDI Data Analyst                                          │            0.0 │         0.0 │
│   4608 │ Data Analyst for Member Contact Center                    │            0.0 │         0.0 │
│   4609 │ BI Data Analyst                                           │            0.0 │         0.0 │
│   4610 │ Data Analyst, Partner Operations (Ecosystem Partnerships) │            0.0 │        20.0 │
│   4611 │ Guidewire Policy Data Analyst                             │            0.0 │         0.0 │
│   4612 │ Sr. Data Analyst                                          │            0.0 │         0.0 │
├────────┴───────────────────────────────────────────────────────────┴────────────────┴─────────────┤
│ 20 rows                                                                                 4 columns │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

-- COALESCE(a, b, c) = use a if not NULL, else b, else c
-- Super handy when you have multiple fallback columns.


-- ============================================================
-- DATA ENGINEERING USE CASE: Creating Flags for a Mart
-- ============================================================
-- This pattern shows up all the time when building data marts.
-- You transform raw boolean/text data into useful categories.

SELECT
    job_title_short AS role,
    CASE
        WHEN job_work_from_home = TRUE THEN 'Remote'
        WHEN job_location LIKE '%Anywhere%' THEN 'Remote'
        ELSE 'On-site'
    END AS work_type,
    CASE
        WHEN salary_year_avg >= 150000 THEN 'Senior'
        WHEN salary_year_avg >= 100000 THEN 'Mid'
        WHEN salary_year_avg IS NOT NULL THEN 'Junior'
        ELSE 'Unknown'
    END AS seniority_guess,
    salary_year_avg
FROM job_postings_fact
WHERE job_title_short = 'Data Engineer'
  AND salary_year_avg IS NOT NULL
ORDER BY salary_year_avg DESC
LIMIT 20;
/*

┌───────────────┬───────────┬─────────────────┬─────────────────┐
│     role      │ work_type │ seniority_guess │ salary_year_avg │
│    varchar    │  varchar  │     varchar     │     double      │
├───────────────┼───────────┼─────────────────┼─────────────────┤
│ Data Engineer │ On-site   │ Senior          │        640000.0 │
│ Data Engineer │ On-site   │ Senior          │        525000.0 │
│ Data Engineer │ On-site   │ Senior          │        450000.0 │
│ Data Engineer │ On-site   │ Senior          │        445000.0 │
│ Data Engineer │ Remote    │ Senior          │        445000.0 │
│ Data Engineer │ Remote    │ Senior          │        445000.0 │
│ Data Engineer │ On-site   │ Senior          │        445000.0 │
│ Data Engineer │ On-site   │ Senior          │        445000.0 │
│ Data Engineer │ Remote    │ Senior          │        445000.0 │
│ Data Engineer │ Remote    │ Senior          │        445000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
│ Data Engineer │ On-site   │ Senior          │        410000.0 │
├───────────────┴───────────┴─────────────────┴─────────────────┤
│ 20 rows                                             4 columns │
└───────────────────────────────────────────────────────────────┘
*/


-- ============================================================
-- TRY THIS
-- ============================================================
-- 1. Create salary buckets ($50k increments) and count jobs
--    in each bucket
SELECT
    CASE
        WHEN salary_year_avg >= 200000 THEN '200k+'
        WHEN salary_year_avg >= 150000 THEN '150-200k'
        WHEN salary_year_avg >= 100000 THEN '100-150k'
        WHEN salary_year_avg >= 50000 THEN '50-100k'
        ELSE '<50k'
    END AS salary_bucket,
    COUNT(*) AS job_count
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
GROUP BY salary_bucket
ORDER BY salary_bucket DESC;
--
-- 2. For each job_title_short, calculate the percentage of jobs
--    that have a salary listed vs. not listed
SELECT
    job_title_short,
    COUNT(*) AS total_jobs,
    COUNT(CASE WHEN salary_year_avg IS NOT NULL THEN 1 END) AS jobs_with_salary,
    ROUND(
        100.0 * COUNT(CASE WHEN salary_year_avg IS NOT NULL THEN 1 END)
        / COUNT(*),
        1
    ) AS pct_with_salary
FROM job_postings_fact
GROUP BY job_title_short
ORDER BY pct_with_salary DESC;
--
-- 3. Create a "job_quality_score" column that awards:
--    +1 for having health insurance
--    +1 for being remote
--    +1 for not requiring a degree
--    +1 for salary > 100k
--    Then group by score and count jobs
SELECT
    job_title_short,
    (CASE WHEN job_health_insurance = TRUE THEN 1 ELSE 0 END) +
    (CASE WHEN job_work_from_home = TRUE THEN 1 ELSE 0 END) +
    (CASE WHEN job_no_degree_mention = TRUE THEN 1 ELSE 0 END) +
    (CASE WHEN salary_year_avg > 100000 THEN 1 ELSE 0 END) AS job_quality_score,
    COUNT(*) AS job_count
FROM job_postings_fact
GROUP BY job_title_short, job_quality_score
ORDER BY job_quality_score DESC;
/*
