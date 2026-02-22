-- =============================================================
-- Step 1: Create Star-Schema Tables
-- =============================================================
-- Author:  Aman Panchal
-- Project: Flat-to-Warehouse Build (Project 3)
--
-- Goal:
--   Define the empty skeleton of the star schema BEFORE any data
--   goes in. Order matters here — dimension tables first, then the
--   fact table, then the bridge table — because of foreign-key
--   dependencies.
--
-- What I learned:
--   The tricky part was realizing that skills_job_dim is a *bridge*
--   table, not a regular dimension. A single job can require many
--   skills, and a single skill appears in many jobs. That many-to-many
--   relationship is exactly what the bridge table resolves.
-- =============================================================

-- -----------------------------------------------
-- Dimension 1: Companies
-- One row per unique company. The surrogate key
-- (company_id) replaces the raw company_name string
-- everywhere else in the schema.
-- -----------------------------------------------
CREATE TABLE company_dim (
    company_id INTEGER PRIMARY KEY,
    company_name VARCHAR UNIQUE NOT NULL
);

-- -----------------------------------------------
-- Dimension 2: Skills
-- Same idea — one row per distinct skill so we can
-- reference it by ID instead of repeating strings.
-- -----------------------------------------------
CREATE TABLE skills_dim (
    skill_id INTEGER PRIMARY KEY,
    skill VARCHAR UNIQUE NOT NULL
);

-- -----------------------------------------------
-- Fact table: Job Postings
-- The grain is one row per job posting. company_id
-- is a foreign key into company_dim. I kept salary
-- and metadata columns here because they describe
-- the individual posting event.
-- Must be created BEFORE the bridge table.
-- -----------------------------------------------
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

-- -----------------------------------------------
-- Bridge table: Skills <-> Jobs  (many-to-many)
-- Composite PK ensures no duplicate pairings.
-- Both FKs point back to their parent tables.
-- -----------------------------------------------
CREATE TABLE skills_job_dim (
    skill_id INTEGER,
    job_id INTEGER,
    PRIMARY KEY (skill_id, job_id),
    FOREIGN KEY (skill_id) REFERENCES skills_dim(skill_id),
    FOREIGN KEY (job_id) REFERENCES job_postings_fact(job_id)
);

-- Quick check — I should see all four tables listed
SHOW TABLES;
