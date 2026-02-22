-- ============================================================
-- 03_data_type_exploration.sql
-- ============================================================
-- Before building the snapshot table, let's understand the data
-- types we're working with. This matters because CTAS inherits
-- types from the source query — if you don't understand what's
-- coming in, you'll get surprised by what comes out.
--
-- I ran into this exact problem: salary_year_avg is a DOUBLE
-- (not DECIMAL), and job_posted_date is a TIMESTAMP (not DATE).
-- Small differences, big implications for downstream queries.
--
-- Run: .read Data-types/4_Priority_Jobs_Pipeline/03_data_type_exploration.sql
-- ============================================================

-- Look at the raw data first — what are we working with?
SELECT
    job_id,
    job_work_from_home,
    job_posted_date,
    salary_year_avg
FROM data_jobs.job_postings_fact
LIMIT 10;

-- Now look at the TYPES of those columns
DESCRIBE data_jobs.job_postings_fact;

-- Notice:
--   job_work_from_home → BOOLEAN
--   job_posted_date    → TIMESTAMP (not DATE!)
--   salary_year_avg    → DOUBLE (not DECIMAL!)

-- ============================================================
-- TYPE CASTING
-- ============================================================
-- Sometimes you need to convert types for presentation or
-- downstream compatibility.

SELECT
    job_id,

    -- Boolean → Integer (useful for SUM/COUNT aggregations)
    CAST(job_work_from_home AS INT) AS work_from_home_int,

    -- Timestamp → Date (drop the time portion)
    CAST(job_posted_date AS DATE) AS job_posted_date_clean,

    -- Double → Decimal (exact representation, good for reports)
    CAST(salary_year_avg AS DECIMAL(10, 0)) AS salary_rounded

FROM data_jobs.job_postings_fact
WHERE salary_year_avg IS NOT NULL
LIMIT 10;

-- ============================================================
-- WHY THIS MATTERS FOR OUR PIPELINE
-- ============================================================
-- When we build the snapshot table, we chose these types:
--
--   job_id          INTEGER     — matches source
--   job_title_short VARCHAR     — matches source
--   company_name    VARCHAR     — from company_dim.name
--   job_posted_date TIMESTAMP   — kept as TIMESTAMP (not DATE)
--                                  because time of posting matters
--   salary_year_avg DOUBLE      — matches source, good enough
--                                  for analytics (not financial)
--   priority_lvl    INTEGER     — from our config table
--   updated_at      TIMESTAMP   — when we last refreshed
--
-- The key lesson: don't blindly trust CTAS types. Know what
-- you're getting and whether it's what you actually NEED.
