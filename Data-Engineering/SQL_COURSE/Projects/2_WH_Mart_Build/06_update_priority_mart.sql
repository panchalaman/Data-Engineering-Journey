-- =====================================================================
-- 06_update_priority_mart.sql   |   Incremental Merge into Priority Mart
-- =====================================================================
-- Author:  Aman Panchal
-- Step:    6 of 7
--
-- Goal:
--   Demonstrate how to incrementally update the priority mart
--   without rebuilding it from scratch.  In a real pipeline this
--   would run on a schedule (daily, hourly, etc.) and only touch
--   rows that changed.  The MERGE statement is the workhorse here:
--   it handles updates, inserts, AND deletes in a single atomic
--   operation.
--
-- What I learned:
--   MERGE INTO is incredibly powerful.  Before I learned it, I was
--   doing DELETE + INSERT which is slower and not atomic.  The
--   three clauses (MATCHED, NOT MATCHED, NOT MATCHED BY SOURCE)
--   cover every case: changed rows get updated, new rows get
--   inserted, and stale rows get deleted.  The IS DISTINCT FROM
--   operator in the MATCHED clause is a nice touch -- it avoids
--   unnecessary updates when nothing actually changed.
-- =====================================================================

-- == Step 1: Update an existing priority level ========================
-- Scenario: I decided Data Engineer should be priority 1, not 2
UPDATE priority_mart.priority_roles
SET priority_lvl = 1
WHERE role_name = 'Data Engineer';

-- == Step 2: Add a new role to track ==================================
-- Scenario: I now want to monitor Data Scientist postings too
INSERT INTO priority_mart.priority_roles (role_id, role_name, priority_lvl)
VALUES (4, 'Data Scientist', 2);

-- == Step 3: Build the source snapshot (temp table) ===================
-- This captures the current state of all priority-matched jobs.
-- I use a temp table so the MERGE reads a stable source.
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
    job_postings_fact AS jpf
LEFT JOIN company_dim AS cd
    ON jpf.company_id = cd.company_id
INNER JOIN priority_mart.priority_roles AS r
    ON jpf.job_title_short = r.role_name;

-- == Step 4: MERGE -- the heart of the incremental update =============
-- Three cases handled atomically:
--   MATCHED + priority changed  -> UPDATE the row
--   NOT MATCHED                 -> INSERT new jobs (e.g. Data Scientist)
--   NOT MATCHED BY SOURCE       -> DELETE jobs that no longer qualify
MERGE INTO priority_mart.priority_jobs_snapshot AS tgt
USING src_priority_jobs AS src
ON tgt.job_id = src.job_id

WHEN MATCHED AND tgt.priority_lvl IS DISTINCT FROM src.priority_lvl THEN
    UPDATE SET
        priority_lvl = src.priority_lvl,
        updated_at = src.updated_at

WHEN NOT MATCHED THEN
    INSERT (
        job_id,
        job_title_short,
        company_name,
        job_posted_date,
        salary_year_avg,
        priority_lvl,
        updated_at
    )
    VALUES (
        src.job_id,
        src.job_title_short,
        src.company_name,
        src.job_posted_date,
        src.salary_year_avg,
        src.priority_lvl,
        src.updated_at
    )

WHEN NOT MATCHED BY SOURCE THEN DELETE;

-- == Verification =====================================================
SELECT 'Priority Roles Dimension' AS table_name, COUNT(*) as record_count FROM priority_mart.priority_roles
UNION ALL
SELECT 'Priority Jobs Snapshot', COUNT(*) FROM priority_mart.priority_jobs_snapshot;

SELECT '=== Priority Roles Dimension Sample ===' AS info;
SELECT * FROM priority_mart.priority_roles;

SELECT '=== Priority Jobs Snapshot Sample ===' AS info;
SELECT 
    job_title_short,
    COUNT(*) AS job_count,
    MIN(priority_lvl) AS priority_lvl,
    MIN(updated_at) AS updated_at
FROM priority_mart.priority_jobs_snapshot
GROUP BY job_title_short
ORDER BY job_count DESC;