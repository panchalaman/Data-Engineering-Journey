-- =============================================================
-- Step 0: Load Raw Data from Google Cloud Storage
-- =============================================================
-- Author:  Aman Panchal
-- Project: Flat-to-Warehouse Build (Project 3)
--
-- Goal:
--   This is the very first step — before I can normalize anything
--   into a star schema, I need the raw flat CSV sitting in a local
--   DuckDB table. Think of this as the "landing zone." Every column
--   from the source CSV gets dumped here as-is, no transformations.
--
-- What I learned:
--   DuckDB can pull CSVs straight from a URL, which is awesome.
--   I didn't need to download anything locally first. Also, keeping
--   job_skills as a raw VARCHAR here (even though it holds a list)
--   was intentional — I parse it later in the skills steps.
-- =============================================================

-- Landing table: mirrors the CSV schema exactly.
-- I'm using loose types (VARCHAR, DOUBLE) so nothing breaks on import.
CREATE TABLE job_postings (
    job_title_short VARCHAR,
    job_title VARCHAR,
    job_location VARCHAR,
    job_via VARCHAR,
    job_schedule_type VARCHAR,
    job_work_from_home BOOLEAN,
    search_location VARCHAR,
    job_posted_date TIMESTAMP,
    job_no_degree_mention BOOLEAN,
    job_health_insurance BOOLEAN,
    job_country VARCHAR,
    salary_rate VARCHAR,
    salary_year_avg DOUBLE,
    salary_hour_avg DOUBLE,
    company_name VARCHAR,
    job_skills VARCHAR,          -- raw Python-style list string, parsed later
    job_type_skills VARCHAR      -- same deal — raw string for now
);

-- Pull the flat file straight from GCS into our landing table.
-- DuckDB's httpfs extension handles this transparently.
COPY job_postings 
FROM 'https://storage.googleapis.com/sql_de/job_postings_flat.csv'
WITH (
    FORMAT CSV,
    HEADER true,
    DELIMITER ','
);

-- Quick sanity checks: did every row land? Do the columns look right?
SELECT COUNT(*) as total_records FROM job_postings;
SELECT * FROM job_postings LIMIT 5;

-- Show column names & types so I can plan the star-schema mapping
DESCRIBE job_postings;
