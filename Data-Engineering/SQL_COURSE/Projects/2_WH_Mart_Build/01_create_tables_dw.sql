-- =====================================================================
-- 01_create_tables_dw.sql   |   Star Schema DDL
-- =====================================================================
-- Author:  Aman Panchal
-- Step:    1 of 7
--
-- Goal:
--   Stand up the four tables that make up my star schema.
--   I'm doing this before anything else because every later step
--   (loading, marts, merges) depends on these tables existing.
--   Dropping first makes the script idempotent — I can re-run it
--   without worrying about leftover state.
--
-- What I learned:
--   Drop order matters when foreign keys are in play.  The bridge
--   table (skills_job_dim) references both skills_dim and
--   job_postings_fact, so it has to be dropped first.  I originally
--   got constraint errors until I reversed the drop sequence.
-- =====================================================================

-- DuckDB quality-of-life settings
PRAGMA enable_progress_bar;           -- shows a progress bar for long-running loads
PRAGMA enable_checkpoint_on_shutdown; -- ensures data is flushed to disk on exit

-- Drop tables in reverse dependency order so FK constraints don't block us
DROP TABLE IF EXISTS skills_job_dim;
DROP TABLE IF EXISTS job_postings_fact;
DROP TABLE IF EXISTS skills_dim;
DROP TABLE IF EXISTS company_dim;

-- Company dimension — one row per hiring company
CREATE TABLE company_dim (
    company_id INTEGER PRIMARY KEY,
    name VARCHAR,
    link VARCHAR,             -- direct company URL
    link_google VARCHAR,      -- Google search link (fallback)
    thumbnail VARCHAR         -- logo thumbnail URL
);

-- Skills dimension — master list of every skill tag in the dataset
CREATE TABLE skills_dim (
    skill_id INTEGER PRIMARY KEY,
    skills VARCHAR,           -- skill name (e.g. "Python", "SQL")
    type VARCHAR              -- category (e.g. "programming", "cloud")
);

-- Fact table — one row per job posting (the grain of the warehouse)
-- Must be created before the bridge table because skills_job_dim references it
CREATE TABLE job_postings_fact (
    job_id INTEGER PRIMARY KEY,
    company_id INTEGER,
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
    FOREIGN KEY (company_id) REFERENCES company_dim(company_id)
);

-- Bridge table — resolves the many-to-many between jobs and skills
-- Composite PK keeps duplicates out; FKs enforce referential integrity
CREATE TABLE skills_job_dim (
    skill_id INTEGER,
    job_id INTEGER,
    PRIMARY KEY (skill_id, job_id),
    FOREIGN KEY (skill_id) REFERENCES skills_dim(skill_id),
    FOREIGN KEY (job_id) REFERENCES job_postings_fact(job_id)
);

-- Quick sanity check — I should see all four tables listed
SHOW TABLES;
