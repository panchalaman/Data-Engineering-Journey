-- =====================================================================
-- build_dw_marts.sql   |   Master Pipeline Orchestration Script
-- =====================================================================
-- Author:  Aman Panchal
--
-- Goal:
--   One command to rule them all.  This script runs every step
--   (01 through 07) in the correct order so I can stand up the
--   entire data warehouse and all four marts from a cold start.
--   I use this after resetting the database or when onboarding
--   someone who wants to reproduce my setup.
--
-- What I learned:
--   DuckDB's .read command is like a poor man's orchestrator --
--   it sources each file sequentially and inherits the same
--   connection.  The order matters because later steps reference
--   objects created by earlier ones.
--
-- Usage (local DuckDB file):
--   duckdb dw_marts.duckdb -c ".read build_dw_marts.sql"
--
-- Usage (MotherDuck cloud):
--   export MOTHERDUCK_TOKEN="your_token_here"
--   duckdb "md:dw_marts" -c ".read build_dw_marts.sql"
--
-- Prerequisites:
--   - DuckDB CLI installed (v0.9+)
--   - Internet access (Step 2 pulls CSVs from a GCS bucket)
--   - For MotherDuck: MOTHERDUCK_TOKEN exported in your shell
--
-- What gets built:
--   Step 1  01_create_tables_dw.sql      Star schema DDL
--   Step 2  02_load_schema_dw.sql        Load data from GCS CSVs
--   Step 3  03_create_flat_mart.sql       Denormalized flat mart
--   Step 4  04_create_skills_mart.sql     Monthly skills demand mart
--   Step 5  05_create_priority_mart.sql   Priority roles snapshot
--   Step 6  06_update_priority_mart.sql   Incremental MERGE update
--   Step 7  07_create_company_mart.sql    Company prospecting mart
-- =====================================================================

-- Uncomment below to connect to MotherDuck after building locally:
-- ATTACH 'md:dw_marts';

-- Step 1: Create the star schema tables (DDL only, no data yet)
.read 01_create_tables_dw.sql

-- Step 2: Load CSVs from GCS into the star schema
.read 02_load_schema_dw.sql

-- Step 3: Flatten the star schema into one analyst-friendly table
.read 03_create_flat_mart.sql

-- Step 4: Build the monthly skills demand mart (additive measures)
.read 04_create_skills_mart.sql

-- Step 5: Create the priority roles snapshot mart
.read 05_create_priority_mart.sql

-- Step 6: Run an incremental MERGE to update the priority mart
.read 06_update_priority_mart.sql

-- Step 7: Build the company prospecting mart (bonus, most complex)
.read 07_create_company_mart.sql

-- Final verification
SELECT '=== Pipeline Build Complete ===' AS status;
SELECT 'All warehouse tables and marts created successfully' AS message;