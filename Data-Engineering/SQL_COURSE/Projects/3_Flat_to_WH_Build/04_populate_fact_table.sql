-- =============================================================
-- Step 4: Populate the Fact Table
-- =============================================================
-- Author:  Aman Panchal
-- Project: Flat-to-Warehouse Build (Project 3)
--
-- Goal:
--   Move every job posting from the flat landing table into the
--   normalized fact table. The key transformation here is swapping
--   the raw company_name string for the integer company_id from
--   company_dim — that's the whole point of dimensional modeling.
--
-- What I learned:
--   I used LEFT JOIN instead of INNER JOIN on purpose. If a posting
--   somehow has a NULL company_name (which I already filtered in
--   company_dim), the LEFT JOIN keeps the row with company_id = NULL
--   rather than silently dropping it. Losing data without noticing
--   is the worst kind of bug in a pipeline.
-- =============================================================

-- Insert every posting, replacing company_name with company_id.
-- ROW_NUMBER gives each job a unique surrogate key.
INSERT INTO job_postings_fact (
    job_id, company_id, job_title_short, job_title, job_location, 
    job_via, job_schedule_type, job_work_from_home, search_location,
    job_posted_date, job_no_degree_mention, job_health_insurance, 
    job_country, salary_rate, salary_year_avg, salary_hour_avg
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY job_posted_date) as job_id,
    cd.company_id,                 -- resolved via the dimension table
    jp.job_title_short,
    jp.job_title,
    jp.job_location,
    jp.job_via,
    jp.job_schedule_type,
    jp.job_work_from_home,
    jp.search_location,
    jp.job_posted_date,
    jp.job_no_degree_mention,
    jp.job_health_insurance,
    jp.job_country,
    jp.salary_rate,
    jp.salary_year_avg,
    jp.salary_hour_avg
FROM job_postings jp
LEFT JOIN company_dim cd ON jp.company_name = cd.company_name;

-- Did every row make it? Compare this count to the landing table.
SELECT COUNT(*) as job_count FROM job_postings_fact;
SELECT * FROM job_postings_fact LIMIT 5;
