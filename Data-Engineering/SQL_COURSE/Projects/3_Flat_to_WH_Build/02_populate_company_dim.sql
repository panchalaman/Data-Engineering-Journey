-- =============================================================
-- Step 2: Populate the Company Dimension
-- =============================================================
-- Author:  Aman Panchal
-- Project: Flat-to-Warehouse Build (Project 3)
--
-- Goal:
--   Extract every unique company from the flat landing table and
--   assign each one a surrogate integer key. This is the first
--   dimension I populate because the fact table's INSERT (Step 4)
--   needs company_id to exist already.
--
-- What I learned:
--   ROW_NUMBER() is perfect for generating surrogate keys on the
--   fly — no need for auto-increment sequences. I also had to
--   filter out NULLs here; otherwise I'd get a mystery row with
--   no company name, which would mess up JOINs later.
-- =============================================================

-- Pull distinct companies and mint a sequential ID for each one.
-- ORDER BY company_name keeps the IDs deterministic across reruns.
INSERT INTO company_dim (company_id, company_name)
SELECT 
    ROW_NUMBER() OVER (ORDER BY company_name) as company_id,
    company_name
FROM (
    SELECT DISTINCT company_name 
    FROM job_postings 
    WHERE company_name IS NOT NULL   -- skip rows with missing company
);

-- Sanity check: how many companies did we capture?
SELECT COUNT(*) as company_count FROM company_dim;
SELECT * FROM company_dim LIMIT 5;
