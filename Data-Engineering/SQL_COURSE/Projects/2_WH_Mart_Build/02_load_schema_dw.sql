-- =====================================================================
-- 02_load_schema_dw.sql   |   Load Star Schema from GCS
-- =====================================================================
-- Author:  Aman Panchal
-- Step:    2 of 7
--
-- Goal:
--   Populate the four tables I created in Step 1 with real data.
--   The CSVs live in a public Google Cloud Storage bucket, and
--   DuckDB's read_csv() can pull them over HTTPS — no SDK needed.
--   Loading order matters: dims first, then the fact, then the
--   bridge, so foreign-key constraints are satisfied at each step.
--
-- What I learned:
--   DuckDB's AUTO_DETECT=true handles type inference really well,
--   but I still specify HEADER=true explicitly because I've been
--   bitten by headerless files before.  The referential integrity
--   checks at the bottom saved me once when a CSV had stale IDs.
-- =====================================================================

-- == Dimension loads (no FK dependencies) =============================

INSERT INTO company_dim (company_id, name, link, link_google, thumbnail)
SELECT company_id, name, link, link_google, thumbnail
FROM read_csv('https://storage.googleapis.com/sql_de/company_dim.csv', 
    AUTO_DETECT=true,
    HEADER=true);

INSERT INTO skills_dim (skill_id, skills, type)
SELECT skill_id, skills, type
FROM read_csv('https://storage.googleapis.com/sql_de/skills_dim.csv', 
    AUTO_DETECT=true,
    HEADER=true)
WHERE skills IS NOT NULL;  -- a few rows have NULL skill names; skip them

-- == Fact table load (references company_dim) =========================

INSERT INTO job_postings_fact (
    job_id, company_id, job_title_short, job_title, job_location, 
    job_via, job_schedule_type, job_work_from_home, search_location,
    job_posted_date, job_no_degree_mention, job_health_insurance, 
    job_country, salary_rate, salary_year_avg, salary_hour_avg
)
SELECT 
    job_id, company_id, job_title_short, job_title, job_location, 
    job_via, job_schedule_type, job_work_from_home, search_location,
    job_posted_date, job_no_degree_mention, job_health_insurance, 
    job_country, salary_rate, salary_year_avg, salary_hour_avg
FROM read_csv('https://storage.googleapis.com/sql_de/job_postings_fact.csv', 
    AUTO_DETECT=true,
    HEADER=true);

-- == Bridge table load (references both dims and the fact) ============

INSERT INTO skills_job_dim (skill_id, job_id)
SELECT skill_id, job_id
FROM read_csv('https://storage.googleapis.com/sql_de/skills_job_dim.csv', 
    AUTO_DETECT=true,
    HEADER=true);

-- == Verification: row counts across all four tables ==================

SELECT 'Company Dimension' AS table_name, COUNT(*) as record_count FROM company_dim
UNION ALL
SELECT 'Skills Dimension', COUNT(*) FROM skills_dim
UNION ALL
SELECT 'Job Postings Fact', COUNT(*) FROM job_postings_fact
UNION ALL
SELECT 'Skills Job Bridge', COUNT(*) FROM skills_job_dim;

-- == Referential integrity checks (each should return 0) ==============
-- If any of these return a non-zero count, the load has orphaned rows
-- and I need to investigate the source CSVs.

SELECT '=== Referential Integrity Check ===' AS info;
SELECT 
    'Orphaned company_ids in job_postings_fact' AS check_type,
    COUNT(*) AS orphaned_count
FROM job_postings_fact 
WHERE company_id NOT IN (SELECT company_id FROM company_dim);

SELECT 
    'Orphaned skill_ids in skills_job_dim' AS check_type,
    COUNT(*) AS orphaned_count
FROM skills_job_dim 
WHERE skill_id NOT IN (SELECT skill_id FROM skills_dim);

SELECT 
    'Orphaned job_ids in skills_job_dim' AS check_type,
    COUNT(*) AS orphaned_count
FROM skills_job_dim 
WHERE job_id NOT IN (SELECT job_id FROM job_postings_fact);

-- == Sample data (quick eyeball test) =================================

SELECT '=== Company Dimension Sample ===' AS info;
SELECT * FROM company_dim LIMIT 5;

SELECT '=== Skills Dimension Sample ===' AS info;
SELECT * FROM skills_dim LIMIT 5;

SELECT '=== Job Postings Fact Sample ===' AS info;
SELECT * FROM job_postings_fact LIMIT 5;

SELECT '=== Skills Job Bridge Sample ===' AS info;
SELECT * FROM skills_job_dim LIMIT 5;
