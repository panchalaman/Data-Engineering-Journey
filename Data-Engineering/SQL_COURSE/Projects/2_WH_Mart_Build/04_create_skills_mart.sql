-- =====================================================================
-- 04_create_skills_mart.sql   |   Skills Demand Mart
-- =====================================================================
-- Author:  Aman Panchal
-- Step:    4 of 7
--
-- Goal:
--   Build a proper dimensional mart that lets me track how demand
--   for individual skills changes month over month.  The grain of
--   the fact table is (skill_id, month, job_title_short), and
--   every measure is an additive count -- meaning I can safely
--   roll up to quarter or year without double-counting.
--   This matters because trend analysis ("Is Python growing?")
--   needs time-series data at a consistent grain.
--
-- What I learned:
--   Storing boolean-to-integer conversions inside a CTE keeps the
--   final SELECT clean -- I just SUM the 1/0 flags.  I also learned
--   that making all measures additive (counts, not ratios) is a
--   best practice for fact tables.  Ratios can always be derived
--   at query time; baking them in would break re-aggregation.
-- =====================================================================

-- Wipe and recreate for idempotency
DROP SCHEMA IF EXISTS skills_mart CASCADE;
CREATE SCHEMA skills_mart;

-- == Dimension: Skills ================================================
-- Straight copy from the warehouse; keeps the mart self-contained
CREATE TABLE skills_mart.dim_skill (
    skill_id INTEGER PRIMARY KEY,
    skills VARCHAR,
    type VARCHAR
);

INSERT INTO skills_mart.dim_skill (skill_id, skills, type)
SELECT
    skill_id,
    skills,
    type
FROM skills_dim;

-- == Dimension: Date (month grain) ====================================
-- I enrich the raw month with quarter info so downstream queries
-- can group by quarter without extra date math
CREATE TABLE skills_mart.dim_date_month (
    month_start_date DATE PRIMARY KEY,
    year INTEGER,
    month INTEGER,
    quarter INTEGER,
    quarter_name VARCHAR,      -- e.g. "Q1"
    year_quarter VARCHAR       -- e.g. "2023-Q1" -- handy for labels
);

INSERT INTO skills_mart.dim_date_month (
    month_start_date,
    year,
    month,
    quarter,
    quarter_name,
    year_quarter
)
SELECT DISTINCT
    DATE_TRUNC('month', job_posted_date)::DATE AS month_start_date,
    EXTRACT(year FROM job_posted_date) AS year,
    EXTRACT(month FROM job_posted_date) AS month,
    EXTRACT(quarter FROM job_posted_date) AS quarter,
    'Q' || CAST(EXTRACT(quarter FROM job_posted_date) AS VARCHAR) AS quarter_name,
    CAST(EXTRACT(year FROM job_posted_date) AS VARCHAR) || '-Q' || 
    CAST(EXTRACT(quarter FROM job_posted_date) AS VARCHAR) AS year_quarter
FROM job_postings_fact
WHERE job_posted_date IS NOT NULL;

-- == Fact: Monthly skill demand =======================================
-- Grain: skill_id + month_start_date + job_title_short
-- All measures are additive counts -- safe to roll up to any time grain
CREATE TABLE skills_mart.fact_skill_demand_monthly (
    skill_id INTEGER,
    month_start_date DATE,
    job_title_short VARCHAR,
    postings_count INTEGER,              -- total postings mentioning this skill
    remote_postings_count INTEGER,       -- how many of those are remote
    health_insurance_postings_count INTEGER,
    no_degree_mention_count INTEGER,     -- postings that don't require a degree
    PRIMARY KEY (skill_id, month_start_date, job_title_short),
    FOREIGN KEY (skill_id) REFERENCES skills_mart.dim_skill(skill_id),
    FOREIGN KEY (month_start_date) REFERENCES skills_mart.dim_date_month(month_start_date)
);

INSERT INTO skills_mart.fact_skill_demand_monthly (
    skill_id,
    month_start_date,
    job_title_short,
    postings_count,
    remote_postings_count,
    health_insurance_postings_count,
    no_degree_mention_count
)
WITH job_postings_prepared AS (
    -- CTE: convert booleans to integers so I can SUM them in the outer query
    SELECT
        sj.skill_id,
        DATE_TRUNC('month', jp.job_posted_date)::DATE AS month_start_date,
        jp.job_title_short,
        CASE WHEN jp.job_work_from_home = TRUE THEN 1 ELSE 0 END AS is_remote,
        CASE WHEN jp.job_health_insurance = TRUE THEN 1 ELSE 0 END AS has_health_insurance,
        CASE WHEN jp.job_no_degree_mention = TRUE THEN 1 ELSE 0 END AS no_degree_mention
    FROM
        job_postings_fact jp
    INNER JOIN
        skills_job_dim sj
        ON jp.job_id = sj.job_id
    WHERE
        jp.job_posted_date IS NOT NULL
)
SELECT
    skill_id,
    month_start_date,
    job_title_short,
    COUNT(*) AS postings_count,
    SUM(is_remote) AS remote_postings_count,
    SUM(has_health_insurance) AS health_insurance_postings_count,
    SUM(no_degree_mention) AS no_degree_mention_count
FROM
    job_postings_prepared
GROUP BY
    skill_id,
    month_start_date,
    job_title_short;

-- == Verification =====================================================
SELECT 'Skill Dimension' AS table_name, COUNT(*) as record_count FROM skills_mart.dim_skill
UNION ALL
SELECT 'Date Month Dimension', COUNT(*) FROM skills_mart.dim_date_month
UNION ALL
SELECT 'Skill Demand Fact', COUNT(*) FROM skills_mart.fact_skill_demand_monthly;

SELECT '=== Skill Dimension Sample ===' AS info;
SELECT * FROM skills_mart.dim_skill LIMIT 10;

SELECT '=== Date Month Dimension Sample ===' AS info;
SELECT * FROM skills_mart.dim_date_month ORDER BY month_start_date DESC LIMIT 10;

SELECT '=== Skill Demand Fact Sample ===' AS info;
SELECT 
    fdsm.skill_id,
    ds.skills,
    ds.type AS skill_type,
    fdsm.job_title_short,
    fdsm.month_start_date,
    fdsm.postings_count,
    fdsm.remote_postings_count,
    fdsm.health_insurance_postings_count,
    fdsm.no_degree_mention_count,
    -- Derived metric: ratio of remote postings (calculated at query time, not stored)
    CASE 
        WHEN fdsm.postings_count > 0 
        THEN fdsm.remote_postings_count::DOUBLE / fdsm.postings_count 
        ELSE 0.0 
    END AS remote_share
FROM skills_mart.fact_skill_demand_monthly fdsm
JOIN skills_mart.dim_skill ds ON fdsm.skill_id = ds.skill_id
ORDER BY fdsm.postings_count DESC, fdsm.month_start_date DESC
LIMIT 10;