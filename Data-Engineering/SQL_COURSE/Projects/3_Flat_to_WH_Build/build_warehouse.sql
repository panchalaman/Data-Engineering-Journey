-- =============================================================
-- Master Build Script — Flat-to-Warehouse Pipeline
-- =============================================================
-- Author:  Aman Panchal
-- Project: Flat-to-Warehouse Build (Project 3)
--
-- Goal:
--   Run the entire warehouse build from a single command.
--   This is the "one-click deploy" approach — each .read call
--   executes a step file in dependency order so nothing breaks.
--
-- Usage:
--   duckdb < build_warehouse.sql        (in-memory)
--   duckdb my_db.duckdb < build_warehouse.sql  (persistent)
--
-- What I learned:
--   DuckDB's .read command is like SQL Server's :r or psql's \i.
--   Chaining them in order is the simplest orchestration pattern —
--   no Airflow, no Makefile, just sequential execution with the
--   database engine itself. Good enough for small-to-medium builds.
-- =============================================================

-- Step 0 — Land the raw CSV into a flat staging table
.read 00_load_data.sql

-- Step 1 — Create the empty star-schema tables (dims → fact → bridge)
.read 01_create_tables.sql

-- Step 2 — Fill company_dim with distinct companies
.read 02_populate_company_dim.sql

-- Step 3 — Parse skills out of the raw string and fill skills_dim
.read 03_populate_skills_dim.sql

-- Step 4 — Load fact table, resolving company_name → company_id
.read 04_populate_fact_table.sql

-- Step 5 — Wire up the many-to-many bridge (skills ↔ jobs)
.read 05_populate_bridge_table.sql

-- Step 6 — Run verification queries to confirm everything is wired up
.read 06_verify_schema.sql

-- If we got here without errors, we're golden
SELECT 'Warehouse build completed successfully!' as status;
