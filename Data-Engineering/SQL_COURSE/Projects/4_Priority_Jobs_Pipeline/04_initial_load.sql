-- ============================================================
-- 04_initial_load.sql
-- ============================================================
-- This is the INITIATION script — run it ONCE to create and
-- populate the priority_jobs_snapshot table for the first time.
--
-- After this, you use 05_incremental_refresh.sql for updates.
-- That's the standard pattern:
--   04 = full load (destroy and rebuild)
--   05 = incremental (update what changed, insert what's new)
--
-- Prerequisites:
--   - data_jobs database attached (MotherDuck)
--   - 01_setup_database.sql has been run
--   - 02_create_priority_roles.sql has been run
--
-- Run: .read Data-types/4_Priority_Jobs_Pipeline/04_initial_load.sql
-- ============================================================

USE jobs_mart;

-- ============================================================
-- STEP 1: Create the snapshot table
-- ============================================================
-- We define the schema explicitly (not with CTAS) because we
-- want control over types, constraints, and the PRIMARY KEY.
-- In production, you always define your target table explicitly.

CREATE OR REPLACE TABLE main.priority_jobs_snapshot (
    job_id          INTEGER PRIMARY KEY,
    job_title_short VARCHAR,
    company_name    VARCHAR,
    job_posted_date TIMESTAMP,
    salary_year_avg DOUBLE,
    priority_lvl    INTEGER,
    updated_at      TIMESTAMP
);

-- ============================================================
-- STEP 2: Load the data
-- ============================================================
-- This is the part I got wrong at first. I wrote a bare SELECT
-- and expected the table to be populated. A SELECT just prints
-- results to screen — you need INSERT INTO to actually write
-- data into the table.
--
-- The query joins three sources:
--   job_postings_fact  — the raw job postings (from MotherDuck)
--   company_dim        — company names (LEFT JOIN because some
--                        postings might not have a company)
--   priority_roles     — our config table (INNER JOIN because
--                        we only want roles we're tracking)

INSERT INTO main.priority_jobs_snapshot
SELECT
    jpf.job_id,
    jpf.job_title_short,
    cd.name AS company_name,
    jpf.job_posted_date,
    jpf.salary_year_avg,
    r.priority_lvl,
    CURRENT_TIMESTAMP AS updated_at
FROM
    data_jobs.job_postings_fact AS jpf
    LEFT JOIN data_jobs.company_dim AS cd
        ON jpf.company_id = cd.company_id
    INNER JOIN staging.priority_roles AS r
        ON jpf.job_title_short = r.role_name;

-- ============================================================
-- STEP 3: Verify the load
-- ============================================================

-- How many rows per role?
SELECT
    job_title_short,
    COUNT(*) AS job_count,
    MIN(priority_lvl) AS priority_lvl,
    MIN(updated_at) AS first_loaded
FROM main.priority_jobs_snapshot
GROUP BY job_title_short
ORDER BY job_count DESC;

-- Spot check — does the data look right?
SELECT *
FROM main.priority_jobs_snapshot
WHERE salary_year_avg IS NOT NULL
ORDER BY salary_year_avg DESC
LIMIT 10;

-- Total row count
SELECT COUNT(*) AS total_rows FROM main.priority_jobs_snapshot;
