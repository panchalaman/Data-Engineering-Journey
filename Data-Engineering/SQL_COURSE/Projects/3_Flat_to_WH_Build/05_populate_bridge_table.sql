-- =============================================================
-- Step 5: Populate the Bridge Table (Skills <-> Jobs)
-- =============================================================
-- Author:  Aman Panchal
-- Project: Flat-to-Warehouse Build (Project 3)
--
-- Goal:
--   This is the many-to-many glue. Each row says "job X requires
--   skill Y." I have to go back to the raw landing table to
--   re-parse job_skills, match each parsed skill to its surrogate
--   ID in skills_dim, and pair it with the job_id from the fact
--   table.
--
-- What I learned:
--   The tricky part was joining the fact table back to the landing
--   table — there's no shared primary key between them, so I match
--   on (job_title, job_posted_date). Not perfectly unique in theory,
--   but DISTINCT in the CTE handles any duplicates that slip through.
--   I also had to cast the UNNEST struct output to VARCHAR explicitly
--   because DuckDB wraps it in a struct column.
-- =============================================================

-- CTE: re-parse skills from the raw table and pair with fact job_id
WITH parsed_skills AS (
    SELECT DISTINCT 
        jpf.job_id,
        TRIM(skill.unnest::VARCHAR) as skill      -- cast struct → plain string
    FROM job_postings_fact jpf
    -- Join back to landing table to access the raw skills string
    JOIN job_postings jp ON jpf.job_title = jp.job_title 
        AND jpf.job_posted_date = jp.job_posted_date
    CROSS JOIN UNNEST(STRING_SPLIT(REPLACE(REPLACE(REPLACE(jp.job_skills, '[', ''), ']', ''), '''', ''), ',')) as skill
    WHERE jp.job_skills IS NOT NULL 
    AND jp.job_skills != '[]'
    AND skill IS NOT NULL
    AND LENGTH(TRIM(skill.unnest::VARCHAR)) > 0   -- skip empty tokens
)
-- Now resolve each skill string to its surrogate skill_id
INSERT INTO skills_job_dim (skill_id, job_id)
SELECT DISTINCT
    sd.skill_id,
    ps.job_id
FROM parsed_skills ps
JOIN skills_dim sd ON ps.skill = sd.skill;

-- How many skill-job pairings did we create?
SELECT COUNT(*) as bridge_count FROM skills_job_dim;
SELECT * FROM skills_job_dim LIMIT 10;