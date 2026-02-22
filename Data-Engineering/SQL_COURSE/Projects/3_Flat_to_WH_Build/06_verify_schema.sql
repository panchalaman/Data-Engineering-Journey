-- =============================================================
-- Step 6: Verify the Star Schema
-- =============================================================
-- Author:  Aman Panchal
-- Project: Flat-to-Warehouse Build (Project 3)
--
-- Goal:
--   This is my "trust but verify" step. After all the inserts I
--   want to confirm: (a) every table has rows, (b) samples look
--   sane, and (c) a multi-table JOIN actually works end-to-end.
--   If this step passes, the warehouse is ready for analytics.
--
-- What I learned:
--   Writing verification queries isn't optional — I caught a
--   zero-row bridge table once because the skill parsing silently
--   failed. This step would've surfaced that immediately. Always
--   build a health-check into your pipeline.
-- =============================================================

-- 1. Record counts — one row per table, easy to eyeball
SELECT 'job_postings_fact' as table_name, COUNT(*) as record_count FROM job_postings_fact
UNION ALL
SELECT 'company_dim', COUNT(*) FROM company_dim
UNION ALL
SELECT 'skills_dim', COUNT(*) FROM skills_dim
UNION ALL
SELECT 'skills_job_dim', COUNT(*) FROM skills_job_dim;

-- 2. Sample rows — spot-check data quality in each table
SELECT 'job_postings_fact sample:' as info;
SELECT * FROM job_postings_fact LIMIT 3;

SELECT 'company_dim sample:' as info;
SELECT * FROM company_dim LIMIT 3;

SELECT 'skills_dim sample:' as info;
SELECT * FROM skills_dim LIMIT 3;

SELECT 'skills_job_dim sample:' as info;
SELECT * FROM skills_job_dim LIMIT 3;

-- 3. End-to-end JOIN test
-- If this returns meaningful rows, the foreign keys are wired correctly.
SELECT 
    jpf.job_title,
    cd.company_name,
    sd.skill
FROM job_postings_fact jpf
JOIN company_dim cd ON jpf.company_id = cd.company_id
JOIN skills_job_dim sjd ON jpf.job_id = sjd.job_id
JOIN skills_dim sd ON sjd.skill_id = sd.skill_id
LIMIT 5;
