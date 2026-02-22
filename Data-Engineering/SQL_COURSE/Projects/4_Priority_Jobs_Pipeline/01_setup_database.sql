-- ============================================================
-- 01_setup_database.sql
-- ============================================================
-- First step: set up the database and schemas.
--
-- Why separate schemas? Same reason you don't throw groceries,
-- tools, and clothes into one drawer. Each schema holds a
-- different "stage" of data:
--   staging.    — intermediate work area (temp, disposable)
--   main.       — production-ready tables (the real stuff)
--
-- Run: .read Data-types/4_Priority_Jobs_Pipeline/01_setup_database.sql
-- ============================================================

-- Create the database (if you're running locally)
-- If you connected with `duckdb md:data_jobs`, you already
-- have data_jobs attached. We just need our working schemas.

CREATE DATABASE IF NOT EXISTS jobs_mart;

-- Switch to our working database
USE jobs_mart;

-- Drop-and-recreate schemas so this script is idempotent
-- (you can run it 100 times and get the same result)
DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA IF NOT EXISTS staging;

-- Verify what we built
SHOW DATABASES;
SELECT *
FROM information_schema.schemata
WHERE catalog_name = 'jobs_mart';

-- At this point we have:
--   jobs_mart.staging   — where our priority_roles config will live
--   jobs_mart.main      — where the final snapshot table will live
--
-- The data_jobs database from MotherDuck is still attached
-- and read-only. We'll SELECT from it but never write to it.
