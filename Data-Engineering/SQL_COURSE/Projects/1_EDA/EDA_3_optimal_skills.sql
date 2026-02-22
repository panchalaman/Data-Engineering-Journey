-- =============================================================================
-- EDA Query 3: Optimal Skills — Balancing Demand and Salary
-- =============================================================================
-- Author: Aman Panchal
--
-- Goal:
--   Queries 1 and 2 each told half the story — demand OR salary. Here I wanted
--   a single score that captures both: "If I learn this skill, how likely am I
--   to get hired AND get paid well?"
--
-- The scoring formula:
--   optimal_score = MEDIAN(salary) * LN(COUNT) / 1,000,000
--
--   Why LN (natural log)?
--   Raw demand counts are wildly different (SQL has 1,128 postings vs. Go at 113).
--   If I just multiplied salary × count, high-demand skills would dominate even
--   with average pay. LN compresses that range:
--     LN(113)  ≈ 5     LN(1128) ≈ 7
--   Now the gap is 5 vs 7 instead of 113 vs 1128 — much fairer comparison.
--   A skill still needs decent demand to score well, but a niche skill with
--   amazing pay can compete.
--
-- Filter:
--   HAVING >= 100 removes statistical noise from rare skills.
--   Only remote DE roles with salary data reported.
-- =============================================================================

SELECT
    sd.skills,
    ROUND(MEDIAN(jpf.salary_year_avg), 0) AS median_salary,
    COUNT(jpf.salary_year_avg) AS demand_count,

    -- Compressed demand for scoring (keeps scale manageable)
    ROUND(LN(COUNT(jpf.*)), 0) AS ln_demand_count,

    -- The composite score: higher = better overall value
    ROUND(
        (MEDIAN(jpf.salary_year_avg) * LN(COUNT(jpf.*))) / 1000000,
        2
    ) AS optimal_score

FROM job_postings_fact jpf

INNER JOIN skills_job_dim sjd
    ON jpf.job_id = sjd.job_id

INNER JOIN skills_dim sd
    ON sjd.skill_id = sd.skill_id

WHERE
    jpf.job_title_short = 'Data Engineer'
    AND jpf.job_work_from_home = True
    AND jpf.salary_year_avg IS NOT NULL      -- salary must be reported

GROUP BY sd.skills

HAVING COUNT(sd.skills) >= 100               -- minimum sample size

ORDER BY optimal_score DESC
LIMIT 25;


/*
Results & Takeaways
--------------------
Terraform (0.97) edges out Python (0.95) and SQL (0.91) for the top spot.
That's surprising — but it makes sense. Terraform has both a high salary
($184K) and meaningful demand (193 postings). The LN transform rewards
that balance.

The "learn these first" tier (score >= 0.85):
  Terraform, Python, SQL, AWS, Airflow, Spark
  These six skills cover infrastructure, code, cloud, orchestration, and
  processing — basically the full DE stack.

The "learn these next" tier (score 0.70-0.84):
  Kafka, Snowflake, Azure, Java, Scala, Git, Kubernetes, Databricks
  All solid additions that either boost salary or open more job listings.

The "nice to have" tier (score 0.65-0.69):
  Docker, MongoDB, R, Go, BigQuery, GitHub
  Competitive pay, smaller demand pools. Good for specialization.

Bottom line: Python + SQL + AWS + Airflow + Spark + Terraform gives you
the highest combined return on learning investment for data engineering.

┌────────────┬───────────────┬──────────────┬─────────────────┬───────────────┐
│   skills   │ median_salary │ demand_count │ ln_demand_count │ optimal_score │
│  varchar   │    double     │    int64     │     double      │    double     │
├────────────┼───────────────┼──────────────┼─────────────────┼───────────────┤
│ terraform  │      184000.0 │          193 │             5.0 │          0.97 │
│ python     │      135000.0 │         1133 │             7.0 │          0.95 │
│ sql        │      130000.0 │         1128 │             7.0 │          0.91 │
│ aws        │      137320.0 │          783 │             7.0 │          0.91 │
│ airflow    │      150000.0 │          386 │             6.0 │          0.89 │
│ spark      │      140000.0 │          503 │             6.0 │          0.87 │
│ kafka      │      145000.0 │          292 │             6.0 │          0.82 │
│ snowflake  │      135500.0 │          438 │             6.0 │          0.82 │
│ azure      │      128000.0 │          475 │             6.0 │          0.79 │
│ java       │      135000.0 │          303 │             6.0 │          0.77 │
│ scala      │      137290.0 │          247 │             6.0 │          0.76 │
│ git        │      140000.0 │          208 │             5.0 │          0.75 │
│ kubernetes │      150500.0 │          147 │             5.0 │          0.75 │
│ databricks │      132750.0 │          266 │             6.0 │          0.74 │
│ redshift   │      130000.0 │          274 │             6.0 │          0.73 │
│ gcp        │      136000.0 │          196 │             5.0 │          0.72 │
│ hadoop     │      135000.0 │          198 │             5.0 │          0.71 │
│ nosql      │      134415.0 │          193 │             5.0 │          0.71 │
│ pyspark    │      140000.0 │          152 │             5.0 │           0.7 │
│ docker     │      135000.0 │          144 │             5.0 │          0.67 │
│ mongodb    │      135750.0 │          136 │             5.0 │          0.67 │
│ r          │      134775.0 │          133 │             5.0 │          0.66 │
│ go         │      140000.0 │          113 │             5.0 │          0.66 │
│ bigquery   │      135000.0 │          123 │             5.0 │          0.65 │
│ github     │      135000.0 │          127 │             5.0 │          0.65 │
├────────────┴───────────────┴──────────────┴─────────────────┴───────────────┤
│ 25 rows                                                           5 columns │
└─────────────────────────────────────────────────────────────────────────────┘
*/