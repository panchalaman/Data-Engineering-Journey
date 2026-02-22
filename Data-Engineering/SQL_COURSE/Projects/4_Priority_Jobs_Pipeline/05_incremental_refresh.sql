-- ============================================================
-- 05_incremental_refresh.sql
-- ============================================================
-- This is the REFRESH script — run it whenever priority_roles
-- changes or you want to pick up new job postings.
--
-- The pattern here is called "upsert" (UPDATE + INSERT):
--   1. Pull fresh data into a temp table (staging area)
--   2. UPDATE existing rows where values changed
--   3. INSERT new rows that don't exist yet
--
-- This is how real ETL pipelines work. You don't rebuild the
-- whole table every time — you only touch what changed. For a
-- table with millions of rows, this is the difference between
-- a 5-second refresh and a 5-minute full rebuild.
--
-- Prerequisites:
--   - 04_initial_load.sql has been run at least once
--   - data_jobs database attached (MotherDuck)
--
-- Run: .read Data-types/4_Priority_Jobs_Pipeline/05_incremental_refresh.sql
-- ============================================================

USE jobs_mart;

-- ============================================================
-- STEP 1: Stage the fresh data
-- ============================================================
-- Temp table = scratch pad. It exists only for this session.
-- We pull the latest data here, compare it against what we
-- already have, and apply the differences.

CREATE OR REPLACE TEMP TABLE src_priority_jobs AS
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

-- Quick sanity check — how many rows are we working with?
SELECT COUNT(*) AS staged_rows FROM src_priority_jobs;

-- ============================================================
-- STEP 2: UPDATE existing rows where priority changed
-- ============================================================
-- IS DISTINCT FROM handles NULLs properly:
--   NULL IS DISTINCT FROM 1  → TRUE  (they're different)
--   NULL IS DISTINCT FROM NULL → FALSE (both null = same)
-- Regular != would return NULL (not TRUE) for null comparisons,
-- which means the row would be skipped. A subtle but real bug.

UPDATE main.priority_jobs_snapshot AS tgt
SET
    priority_lvl = src.priority_lvl,
    updated_at   = src.updated_at
FROM src_priority_jobs AS src
WHERE tgt.job_id = src.job_id
    AND tgt.priority_lvl IS DISTINCT FROM src.priority_lvl;

-- ============================================================
-- STEP 3: INSERT new rows that don't exist yet
-- ============================================================
-- LEFT JOIN + WHERE tgt.job_id IS NULL = "find rows in source
-- that have no match in target." Classic pattern for detecting
-- new records.

INSERT INTO main.priority_jobs_snapshot
SELECT src.*
FROM src_priority_jobs AS src
LEFT JOIN main.priority_jobs_snapshot AS tgt
    ON src.job_id = tgt.job_id
WHERE tgt.job_id IS NULL;

-- ============================================================
-- STEP 4: Verify the refresh
-- ============================================================

SELECT
    job_title_short,
    COUNT(*) AS job_count,
    MIN(priority_lvl) AS priority_lvl,
    MAX(updated_at) AS last_refreshed
FROM main.priority_jobs_snapshot
GROUP BY job_title_short
ORDER BY job_count DESC;

-- How many rows total now?
SELECT COUNT(*) AS total_rows FROM main.priority_jobs_snapshot;

-- Temp table gets dropped automatically when the session ends,
-- but let's be explicit about cleanup.
DROP TABLE IF EXISTS src_priority_jobs;
