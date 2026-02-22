-- =============================================================================
-- EDA Query 1: Top 10 Most In-Demand Skills for Remote Data Engineers
-- =============================================================================
-- Author: Aman Panchal
--
-- Goal:
--   I wanted to find out which skills show up the most in remote data engineer
--   job postings. If I'm going to invest time learning something, I want to know
--   what the market actually wants — not just what blog posts recommend.
--
-- Approach:
--   Three-table INNER JOIN across the star schema:
--     job_postings_fact → skills_job_dim (bridge) → skills_dim
--   Filtered to remote-only Data Engineer roles, then counted skill frequency.
--
-- What I learned:
--   SQL and Python aren't optional — they're table stakes. Everything else
--   (cloud, Spark, orchestration) builds on top of those two.
-- =============================================================================

SELECT
    sd.skills,
    COUNT(jpf.*) AS demand_count

FROM job_postings_fact AS jpf

-- Bridge table connects jobs to skills (many-to-many)
INNER JOIN skills_job_dim AS sjd
    ON jpf.job_id = sjd.job_id

-- Skill names live in the dimension table
INNER JOIN skills_dim AS sd
    ON sjd.skill_id = sd.skill_id

WHERE
    jpf.job_title_short = 'Data Engineer'
    AND jpf.job_work_from_home = True       -- remote positions only

GROUP BY sd.skills
ORDER BY demand_count DESC
LIMIT 10;

/*
Results & Takeaways
--------------------
SQL and Python each appear in ~29K postings — nearly double the next skill.
That gap is massive. If you're starting out, these two are non-negotiable.

Cloud platforms (AWS, Azure) and Spark round out the top 5, which makes sense:
modern data engineering is cloud-native and batch/stream processing is core work.

The middle tier (Airflow, Snowflake, Databricks) tells me orchestration and
managed warehouses are where the industry is headed. Java and GCP close out
the top 10 — solid but not as dominant as the leaders.

┌────────────┬──────────────┐
│   skills   │ demand_count │
│  varchar   │    int64     │
├────────────┼──────────────┤
│ sql        │        29221 │
│ python     │        28776 │
│ aws        │        17823 │
│ azure      │        14143 │
│ spark      │        12799 │
│ airflow    │         9996 │
│ snowflake  │         8639 │
│ databricks │         8183 │
│ java       │         7267 │
│ gcp        │         6446 │
├────────────┴──────────────┤
│ 10 rows         2 columns │
└───────────────────────────┘
*/