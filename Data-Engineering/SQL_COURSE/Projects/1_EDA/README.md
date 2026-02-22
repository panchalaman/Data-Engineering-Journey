# Exploratory Data Analysis: Data Engineer Job Market

A SQL-based analysis of the data engineer job market using real-world job posting data. Three queries that answer the questions I actually had when planning what to learn next — which skills are most in-demand, which pay the best, and which give you the best return on investment.

![EDA Project Overview](../../Resources/images/1_1_Project1_EDA.png)

---

## What This Project Does

I wrote three analytical queries against a star-schema data warehouse of job postings. Each query builds on the last:

| # | Query | What it answers |
|---|-------|----------------|
| 1 | [EDA_1_top_demanded_skills.sql](./EDA_1_top_demanded_skills.sql) | Which skills show up the most in remote DE job postings? |
| 2 | [EDA_2_highest_paying_skills.sql](./EDA_2_highest_paying_skills.sql) | Which skills actually pay the best (using MEDIAN, not AVG)? |
| 3 | [EDA_3_optimal_skills.sql](./EDA_3_optimal_skills.sql) | Which skills balance both demand and salary? (custom scoring formula) |

If you only have a minute, start with Query 3 — it combines the insights from the first two into a single composite score.

---

## The Data

The queries run against a star schema warehouse with four tables:

![Data Warehouse Schema](../../Resources/images/1_2_Data_Warehouse.png)

- **Fact table:** `job_postings_fact` — one row per job posting with salary, location, dates
- **Dimensions:** `company_dim` (employer info), `skills_dim` (skill names + categories)
- **Bridge table:** `skills_job_dim` — resolves the many-to-many between jobs and skills

All queries filter to `job_title_short = 'Data Engineer'` and `job_work_from_home = True` to focus on remote data engineering roles specifically.

---

## Key Findings

**The foundation is non-negotiable:** SQL (29K postings) and Python (29K) are nearly double the next skill. These aren't "nice to have" — they're entry requirements.

**Cloud is the new default:** AWS (18K), Azure (14K), and GCP (6K) collectively show that cloud-native data engineering is the norm, not the exception. Most job descriptions list at least one.

**The highest-paying skills aren't always the most common:** Rust pays $210K median but has only 232 postings. Terraform ($184K, 3,248 postings) and Kubernetes ($150K, 4,202 postings) offer the best blend of pay and availability.

**My composite score revealed the "learn these" list:** Python, SQL, AWS, Airflow, Spark, and Terraform scored highest when balancing demand against salary. That's essentially the modern DE stack.

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| DuckDB | OLAP query engine — fast analytical queries without a server |
| SQL | All analysis written in ANSI-style SQL with DuckDB extensions |
| Star schema | Fact + dimension + bridge tables for clean joins |
| VS Code + Terminal | Development environment |
| Git/GitHub | Version control |

---

## SQL Techniques Used

- **Multi-table JOINs** — Three-table INNER JOINs across fact, bridge, and dimension tables
- **Aggregation functions** — `COUNT()`, `MEDIAN()`, `ROUND()` for demand and salary metrics
- **HAVING clause** — Filtering aggregated results (minimum 100 postings per skill)
- **Mathematical functions** — `LN()` for natural log transformation to normalize demand across skills
- **Composite scoring** — Custom formula combining salary and log-demand into a single ranking metric
- **Boolean filtering** — Using `job_work_from_home = True` to isolate remote positions

---

## How to Run

```bash
# Connect to the shared dataset
duckdb

# Inside DuckDB, attach the shared database
ATTACH 'md:_share/data_jobs/87603155-cdc7-4c80-85ad-3a6b0d760d93' AS data_jobs;
USE data_jobs;

# Run any query
.read EDA_1_top_demanded_skills.sql
.read EDA_2_highest_paying_skills.sql
.read EDA_3_optimal_skills.sql
```

---

## Project Structure

```
1_EDA/
├── EDA_1_top_demanded_skills.sql    # Demand analysis — top 10 skills by posting count
├── EDA_2_highest_paying_skills.sql  # Salary analysis — top 25 skills by median pay
├── EDA_3_optimal_skills.sql         # Combined score — demand × salary optimization
└── README.md
```
- **Calculated Metrics**: Derived optimal score combining log-transformed demand with median salary
- **HAVING Clause**: Filtering aggregated results (skills with >= 100 postings)
- **NULL Handling**: Proper filtering of incomplete records (`salary_year_avg IS NOT NULL`)