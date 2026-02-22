# Data Warehouse and Mart Build

An end-to-end pipeline that takes raw CSV files sitting in Google Cloud Storage and turns them into a proper star schema data warehouse, then builds four specialized data marts on top. This was my first time designing a full warehouse-to-mart architecture from scratch, and it taught me more about dimensional modeling than any textbook chapter could.

![Data Pipeline Architecture](../../Resources/images/1_2_Project2_Data_Pipeline.png)

---

## Why I Built This

Raw CSVs aren't a data warehouse. They can't enforce relationships, they duplicate data everywhere, and joining across flat files is a maintenance nightmare. I wanted to take messy source data and build something that a real analytics team could actually query against — with proper dimensions, foreign keys, and pre-aggregated marts for common business questions.

The pipeline goes through three layers:
1. **Extract + Load** — Pull CSVs from GCS into a normalized star schema
2. **Transform into marts** — Build purpose-built analytical tables for different use cases
3. **Incremental updates** — Show that this isn't a one-shot load; it can be maintained over time

---

## Quick Start

```bash
# One command runs the entire pipeline (7 steps)
duckdb dw_marts.duckdb -c ".read build_dw_marts.sql"

# Or with MotherDuck
duckdb "md:dw_marts" -c ".read build_dw_marts.sql"
```

---

## Pipeline Architecture

![Data Pipeline Architecture](../../Resources/images/1_2_Project2_Data_Pipeline.png)

CSVs from Google Cloud Storage flow into a star schema warehouse. From there, four marts serve different analytical needs. BI tools (Excel, Power BI, Tableau, Python) can consume from either the warehouse directly or from the pre-built marts.

### Layer 1: Star Schema Warehouse

![Data Warehouse Schema](../../Resources/images/1_2_Data_Warehouse.png)

The foundation. Four tables that normalize the raw data into proper dimensional form:

| File | What it does |
|------|-------------|
| [01_create_tables_dw.sql](./01_create_tables_dw.sql) | DDL for the star schema — 2 dims, 1 fact, 1 bridge table with FK constraints |
| [02_load_schema_dw.sql](./02_load_schema_dw.sql) | Loads CSVs from GCS via `read_csv()`, dims first then fact then bridge (FK order matters) |

**Grain:** One row per job posting in `job_postings_fact`

### Layer 2: Analytical Marts

#### Flat Mart — for ad-hoc queries

![Flat Mart Schema](../../Resources/images/1_2_Flat_Mart.png)

| File | What it does |
|------|-------------|
| [03_create_flat_mart.sql](./03_create_flat_mart.sql) | Denormalizes the star schema back into a single wide table with `ARRAY_AGG` for skills |

Sometimes analysts just want one table they can throw into Excel without thinking about joins. This mart pre-joins everything and packs skills into an array-of-structs column. It's the "I just need quick answers" table.

#### Skills Mart — trend analysis over time

![Skills Mart Schema](../../Resources/images/1_2_Skills_Mart.png)

| File | What it does |
|------|-------------|
| [04_create_skills_mart.sql](./04_create_skills_mart.sql) | Monthly skill demand with additive measures (counts, not ratios) |

**Grain:** `skill_id + month_start_date + job_title_short`

All measures are additive — posting counts, remote counts, insurance counts. This means you can roll up to quarter or year without breaking the math. I learned that putting ratios in a fact table is a common modeling mistake because you can't re-aggregate them correctly.

#### Priority Mart — role tracking with incremental updates

![Priority Mart Schema](../../Resources/images/1_2_Priority_Mart.png)

| File | What it does |
|------|-------------|
| [05_create_priority_mart.sql](./05_create_priority_mart.sql) | Initial snapshot — config table defines which roles matter and at what priority |
| [06_update_priority_mart.sql](./06_update_priority_mart.sql) | Incremental refresh using `MERGE INTO` with all three clauses |

This is where it gets interesting. The MERGE operation handles inserts (new jobs), updates (priority changes), and deletes (jobs no longer matching) — all in a single statement. This is how production pipelines handle delta loads without full rebuilds.

#### Company Mart — hiring intelligence (bonus)

![Company Mart Schema](../../Resources/images/1_2_Company_Mart.png)

| File | What it does |
|------|-------------|
| [07_create_company_mart.sql](./07_create_company_mart.sql) | 5 dimensions, 2 bridge tables, 1 monthly fact table |

The most complex mart in the pipeline. It tracks company hiring patterns by role, location, and month. Pre-computed shares (remote %, insurance %, no-degree %) let analysts compare companies without re-calculating from raw data every time. The bridge tables handle the many-to-many relationships between companies and locations, and between job title categories and specific job titles.

### Orchestration

| File | What it does |
|------|-------------|
| [build_dw_marts.sql](./build_dw_marts.sql) | Master script — runs all 7 steps in sequence with `.read` |

---

## Project Structure

```
2_WH_Mart_Build/
├── 01_create_tables_dw.sql        # Star schema DDL (dims → fact → bridge)
├── 02_load_schema_dw.sql          # Extract CSVs from GCS, load in FK order
├── 03_create_flat_mart.sql        # Denormalized flat table for ad-hoc queries
├── 04_create_skills_mart.sql      # Monthly skill demand with additive measures
├── 05_create_priority_mart.sql    # Config-driven priority role snapshot
├── 06_update_priority_mart.sql    # Incremental MERGE (insert/update/delete)
├── 07_create_company_mart.sql     # Company hiring trends mart (bonus)
├── build_dw_marts.sql             # Master orchestration script
└── README.md
```

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| DuckDB | File-based OLAP engine with `httpfs` for direct GCS reads |
| SQL | DDL for schemas, DML for ETL, MERGE for incremental loads |
| Star schema | Fact + dimension + bridge tables for clean dimensional modeling |
| Google Cloud Storage | Source CSV files hosted publicly |
| VS Code + Terminal | Development and execution |
| Git/GitHub | Version control for pipeline scripts |

---

## What I Learned Building This

### On dimensional modeling
- Drop order matters — you can't drop a dimension while a fact table still references it via FK. I learned this the hard way.
- Bridge tables are how you solve many-to-many (jobs have multiple skills, companies hire in multiple locations). Without them, you either duplicate fact rows or lose data.
- Additive measures (counts, sums) in fact tables are safe to roll up. Ratios and averages are not — compute those at query time.

### On ETL patterns
- Load order is the inverse of drop order: dims first, then fact, then bridge. FKs won't validate otherwise.
- Idempotency isn't optional. Every script uses `DROP IF EXISTS` or `CREATE OR REPLACE` so you can safely re-run the whole pipeline.
- MERGE is powerful — one statement handles inserts, updates, and deletes. But the `IS DISTINCT FROM` operator (not `!=`) is critical because it handles NULLs correctly.

### On mart design
- Different users need different shapes of data. Analysts want flat tables. Time-series dashboards want pre-aggregated monthly grains. The warehouse is the single source of truth; marts are optimized views of it.
- Schema separation (`flat_mart`, `skills_mart`, `priority_mart`, `company_mart`) keeps things clean and lets you rebuild one mart without touching others.

---

## SQL Techniques Used

- **DDL** — `CREATE TABLE`, `CREATE SCHEMA`, `DROP ... CASCADE`, `PRAGMA` settings
- **DML** — `INSERT INTO ... SELECT` with explicit column mapping, `read_csv()` for GCS extraction
- **MERGE** — Full three-clause upsert: `WHEN MATCHED`, `WHEN NOT MATCHED`, `WHEN NOT MATCHED BY SOURCE`
- **CTEs** — Boolean-to-integer conversion, complex multi-step transforms
- **Aggregation** — `COUNT`, `MEDIAN`, `AVG`, `ARRAY_AGG` with `STRUCT_PACK`
- **Date functions** — `DATE_TRUNC('month')`, `EXTRACT(quarter)` for temporal dimensions
- **Window functions** — Surrogate key generation via self-join counting (company mart)
- **Group operations** — `GROUP BY ALL` for DuckDB shorthand, `HAVING` for post-aggregate filtering