-- =============================================================
-- Step 3: Populate the Skills Dimension
-- =============================================================
-- Author:  Aman Panchal
-- Project: Flat-to-Warehouse Build (Project 3)
--
-- Goal:
--   The raw job_skills column is a Python-style list stored as a
--   string (e.g. "['python', 'sql', 'spark']"). I need to explode
--   that into individual rows so each unique skill gets exactly one
--   row and one surrogate ID in skills_dim.
--
-- What I learned:
--   This was the hardest parsing step. The string isn't real JSON,
--   so I couldn't use json_extract. Instead I strip the brackets
--   and quotes with nested REPLACE calls, split on commas, UNNEST
--   into rows, TRIM whitespace, and finally de-duplicate. Each
--   layer peels off one piece of the formatting junk.
-- =============================================================

-- Parse the ugly Python-list string into clean, distinct skill rows.
-- Pipeline: strip [ ] ' → split on comma → unnest → trim → dedupe
INSERT INTO skills_dim (skill_id, skill)
SELECT DISTINCT
    ROW_NUMBER() OVER (ORDER BY skill) as skill_id,
    skill
FROM (
    SELECT DISTINCT TRIM(skill) as skill
    FROM (
        -- REPLACE x3 strips brackets and single-quotes, then split on comma
        SELECT UNNEST(STRING_SPLIT(REPLACE(REPLACE(REPLACE(job_skills, '[', ''), ']', ''), '''', ''), ',')) as skill
        FROM job_postings 
        WHERE job_skills IS NOT NULL 
        AND job_skills != '[]'        -- skip explicitly empty lists
    )
    WHERE skill != '' AND skill IS NOT NULL   -- drop empty tokens left after split
);

-- How many unique skills did we end up with?
SELECT COUNT(*) as skills_count FROM skills_dim;
SELECT * FROM skills_dim LIMIT 10;
