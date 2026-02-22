--.read Data-types/priority_jobs_snapshot_INITIATION.sql
-- Step 1: Create the table
CREATE OR REPLACE TABLE main.priority_jobs_snapshot (
    job_id  INTEGER PRIMARY KEY,
    job_title_short VARCHAR,
    company_name    VARCHAR,
    job_posted_date TIMESTAMP,
    salary_year_avg DOUBLE,
    priority_lvl    INTEGER,
    updated_at  TIMESTAMP
);

-- Step 2: INSERT INTO — this actually loads data into the table
-- (A bare SELECT just prints to screen, it doesn't insert anything)
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

-- Step 3: Verify the load
SELECT
    job_title_short,
    COUNT(*) AS job_count,
    MIN(priority_lvl) AS priority_lvl,
    MIN(updated_at) AS updated_at
FROM priority_jobs_snapshot
GROUP BY job_title_short
ORDER BY job_count DESC;


