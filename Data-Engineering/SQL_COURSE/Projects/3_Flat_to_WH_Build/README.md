# Flat to Warehouse Build: Star Schema from Raw CSV

This project takes a single flat CSV file — where skills are crammed into Python-style list strings like `['SQL', 'Python', 'AWS']` — and transforms it into a proper normalized star schema. It's the kind of messy-to-clean transformation that data engineers deal with constantly, and I wanted to build the whole pipeline from scratch.

This was a bonus project I did on my own outside the course material. The goal was to prove I could take genuinely messy source data and design a warehouse around it, not just load pre-formatted CSVs into tables someone else designed.

![Data Warehouse Schema](../../Resources/images/1_2_Data_Warehouse.png)

---

## The Problem

The source CSV has everything jammed into one table — company names repeated thousands of times, skills stored as embedded Python lists inside a VARCHAR column. You can't `JOIN ON` a string like `['SQL', 'Python']`. You can't deduplicate companies without extracting them. You can't do proper skill-level analysis without normalizing those lists into individual rows.

The flat file is fine for a quick look in Excel. It's terrible for analytical queries.

---

## What the Pipeline Does

Seven scripts run in sequence to transform the flat CSV into a four-table star schema:

| Step | File | What it does |
|------|------|-------------|
| 0 | [00_load_data.sql](./00_load_data.sql) | Pulls the CSV from GCS into a landing table — loose types, no normalization |
| 1 | [01_create_tables.sql](./01_create_tables.sql) | Creates the target star schema (2 dims + 1 fact + 1 bridge) with FK constraints |
| 2 | [02_populate_company_dim.sql](./02_populate_company_dim.sql) | Extracts unique companies, assigns surrogate keys with `ROW_NUMBER()` |
| 3 | [03_populate_skills_dim.sql](./03_populate_skills_dim.sql) | Parses `['skill1', 'skill2']` strings into normalized rows via REPLACE + SPLIT + UNNEST |
| 4 | [04_populate_fact_table.sql](./04_populate_fact_table.sql) | Loads fact table, replaces company_name with company_id via LEFT JOIN |
| 5 | [05_populate_bridge_table.sql](./05_populate_bridge_table.sql) | Resolves the many-to-many job-to-skill relationship |
| 6 | [06_verify_schema.sql](./06_verify_schema.sql) | Record counts, sample data, and an end-to-end JOIN test |

---

## Quick Start

```bash
# Option 1: Master SQL script (runs all 7 steps)
duckdb -c ".read build_warehouse.sql"

# Option 2: Shell script with error handling
chmod +x build_warehouse.sh
./build_warehouse.sh
```

---

## The Interesting Part: Parsing Embedded Lists

The hardest step was Step 3. The CSV stores skills like this:

```
['SQL', 'Python', 'AWS']
```

That's a Python list literal stored as a plain string. To normalize it, I had to:

1. Strip the brackets: `REPLACE(REPLACE(job_skills, '[', ''), ']', '')`
2. Strip the quotes: `REPLACE(..., '''', '')`
3. Split on commas: `STRING_SPLIT(..., ',')`
4. Flatten to rows: `UNNEST(...)`
5. Trim whitespace: `TRIM(skill)`
6. Deduplicate: `SELECT DISTINCT`

Each step peels off one layer of the mess. The result is a clean `skills_dim` table with one row per unique skill and a surrogate key.

---

## Project Structure

```
3_Flat_to_WH_Build/
├── 00_load_data.sql             # Landing zone — raw CSV into DuckDB
├── 01_create_tables.sql         # Star schema DDL with FK constraints
├── 02_populate_company_dim.sql  # Dedup companies + surrogate keys
├── 03_populate_skills_dim.sql   # Parse Python list strings into rows
├── 04_populate_fact_table.sql   # Load fact table with company_id lookup
├── 05_populate_bridge_table.sql # Many-to-many job-skill resolution
├── 06_verify_schema.sql         # Validation queries
├── build_warehouse.sql          # Master SQL orchestration
├── build_warehouse.sh           # Shell wrapper with set -e
└── README.md
```

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| DuckDB | OLAP engine with `httpfs` for direct GCS reads, no server needed |
| SQL | All ETL logic — DDL, DML, string parsing, window functions |
| Star schema | Fact + dimension + bridge for normalized dimensional model |
| Google Cloud Storage | Source CSV hosted publicly |
| Shell (bash) | Build script with error handling via `set -e` |
| Git/GitHub | Version control |

---

## What I Learned

**On data transformation:** The skills column was the real challenge. It looked like JSON but wasn't — it was a Python `repr()` string. I couldn't use `JSON_EXTRACT` because single quotes aren't valid JSON. The REPLACE + SPLIT + UNNEST chain was ugly but it works, and I suspect this kind of "parse whatever format the source team gave you" work is 80% of real data engineering.

**On surrogate keys:** Using `ROW_NUMBER() OVER (ORDER BY ...)` gives deterministic, sequential IDs. The ORDER BY makes the assignment repeatable — same input always produces the same keys. I used this for both `company_dim` and `skills_dim`.

**On load order:** Dimensions must be populated before the fact table (foreign keys won't validate otherwise). The bridge table comes last because it references both the fact table and the skills dimension.

**On the bridge table challenge:** Step 5 was tricky because the landing table and the fact table don't share a natural key. I had to join on `job_title + job_posted_date` to link them, then re-parse the skills column to resolve skill names back to skill_ids. Not elegant, but it maintains referential integrity.

---

## SQL Techniques Used

- **String parsing** — `REPLACE`, `STRING_SPLIT`, `UNNEST`, `TRIM` for embedded list extraction
- **Window functions** — `ROW_NUMBER()` for surrogate key generation
- **CTEs** — Multi-step transforms for skill parsing and bridge resolution
- **DDL** — `CREATE TABLE` with primary keys, foreign keys, `UNIQUE NOT NULL` constraints
- **DML** — `INSERT INTO ... SELECT` with explicit column mapping and JOIN-based lookups
- **COPY** — `COPY ... FROM` with CSV format options for GCS data import
- **Verification** — `UNION ALL` record counts, sample queries, cross-table JOIN tests