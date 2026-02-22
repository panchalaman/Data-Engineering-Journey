# Data Engineering

SQL course and hands-on projects covering the full data engineering workflow — from writing your first query to building production data warehouses.

## SQL Course

The [SQL Lessons](SQL_COURSE/Lessons/) folder is a complete course that takes you from zero to data-engineer-ready SQL. 15 lessons split into two parts:

**Part 1 — Querying**: SELECT, WHERE, JOINs, GROUP BY, subqueries, CTEs, window functions, date/string functions  
**Part 2 — Building**: DDL, data modeling (star schema), DML, ETL patterns, query optimization, advanced SQL

Every lesson uses a real dataset of tech job postings and is designed to run in DuckDB. Follow the [Setup Guide](SQL_COURSE/Lessons/00_Setup.md) to install DuckDB and connect to the database.

→ [Start the course](SQL_COURSE/Lessons/README.md)
→ [Data 101 (University of California ): Notes](https://data101.org/notes/sql/review/)

## Projects

These are the hands-on projects I built while learning SQL for data engineering. Each one tackles a different part of the DE workflow — from exploratory analysis to full warehouse builds with incremental updates.

### [1_EDA/](SQL_COURSE/Projects/1_EDA) — Job Market EDA
![EDA Project Overview](SQL_COURSE/Projects/Resources/images/1_1_Project1_EDA.png)

Three analytical queries that answer the questions I had when planning what to learn: which skills are most in-demand, which pay the best, and which give the best return on investment. Includes a custom scoring formula using `LN()` to balance demand against salary.

**Techniques**: Multi-table JOINs, MEDIAN aggregation, HAVING filters, LN() transformation, composite scoring

### [2_WH_Mart_Build/](SQL_COURSE/Projects/2_WH_Mart_Build) — Data Warehouse + Mart Pipeline
![Data Pipeline Architecture](SQL_COURSE/Projects/Resources/images/1_2_Project2_Data_Pipeline.png)

End-to-end pipeline that extracts CSVs from Google Cloud Storage, loads them into a star schema warehouse, then builds four specialized data marts (flat, skills demand, priority roles, company hiring). The priority mart demonstrates incremental updates with MERGE.

**Techniques**: Star schema DDL, GCS extraction, MERGE upserts, additive measures, bridge tables, schema separation

### [3_Flat_to_WH_Build/](SQL_COURSE/Projects/3_Flat_to_WH_Build) — Flat CSV to Star Schema

Self-directed project (not from the course). Takes a flat CSV with skills embedded as Python-style list strings and transforms it into a normalized star schema. The main challenge was parsing `['SQL', 'Python', 'AWS']` into relational rows.

**Techniques**: String parsing (REPLACE/SPLIT/UNNEST), surrogate keys with ROW_NUMBER(), bridge table population, FK constraints

### [4_Priority_Jobs_Pipeline/](../Data-types/4_Priority_Jobs_Pipeline) — Priority Jobs Snapshot Pipeline

Incremental ETL pipeline that tracks job postings by role priority with upsert patterns and schema evolution.

**Techniques**: DDL/DML, INSERT INTO vs CTAS, upsert pattern, staging tables, ALTER TABLE, data types, idempotency
