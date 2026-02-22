-- =====================================================================
-- 05_create_priority_mart.sql   |   Priority Roles Snapshot Mart
-- =====================================================================
-- Author:  Aman Panchal
-- Step:    5 of 7
--
-- Goal:
--   Create a focused mart for the roles I personally care about.
--   Instead of querying across 700k+ postings every time, I define
--   a small config table (priority_roles) with the job titles and
--   priority levels that matter to me, then snapshot only those
--   jobs.  This matters because it makes my daily "what's new in
--   Data Engineering?" query near-instant.
--
-- What I learned:
--   Using a config/dimension table (priority_roles) to drive which
--   rows land in the snapshot is a pattern I see a lot in production
--   pipelines.  It decouples the "what do I care about" question
--   from the ETL logic.  When I want to add a new role, I just
--   INSERT a row -- I don't touch the pipeline code.
-- =====================================================================

-- Wipe and recreate for idempotency
DROP SCHEMA IF EXISTS priority_mart CASCADE;
CREATE SCHEMA priority_mart;

-- == Config table: which roles do I care about? =======================
-- priority_lvl is arbitrary: 1 = top priority, higher = lower priority
CREATE TABLE priority_mart.priority_roles (
  role_id      INTEGER PRIMARY KEY,
  role_name    VARCHAR,
  priority_lvl INTEGER
);

-- Seed with my initial set of target roles
INSERT INTO priority_mart.priority_roles (role_id, role_name, priority_lvl)
VALUES
  (1, 'Data Engineer',       2),
  (2, 'Senior Data Engineer', 1),
  (3, 'Software Engineer',   3);

-- == Snapshot table: filtered view of job postings ====================
-- Only contains postings that match a priority role name
CREATE TABLE priority_mart.priority_jobs_snapshot (
  job_id              INTEGER PRIMARY KEY,
  job_title_short     VARCHAR,
  company_name        VARCHAR,
  job_posted_date     TIMESTAMP,
  salary_year_avg     DOUBLE,
  priority_lvl        INTEGER,
  updated_at          TIMESTAMP       -- tracks when this row was last written
);

-- INNER JOIN on role_name ensures only priority-matched jobs make it in
INSERT INTO priority_mart.priority_jobs_snapshot (
  job_id,
  job_title_short,
  company_name,
  job_posted_date,
  salary_year_avg,
  priority_lvl,
  updated_at
)
SELECT 
  jpf.job_id,
  jpf.job_title_short,
  cd.name AS company_name,
  jpf.job_posted_date,
  jpf.salary_year_avg,
  r.priority_lvl,
  CURRENT_TIMESTAMP
FROM
    job_postings_fact AS jpf
LEFT JOIN company_dim AS cd
    ON jpf.company_id = cd.company_id
INNER JOIN priority_mart.priority_roles AS r
    ON jpf.job_title_short = r.role_name;

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