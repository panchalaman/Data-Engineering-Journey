-- =============================================================================
-- EDA Query 2: Top 25 Highest-Paying Skills for Data Engineers
-- =============================================================================
-- Author: Aman Panchal
--
-- Goal:
--   Query 1 showed me what's in-demand, but demand doesn't always mean
--   well-paid. Here I wanted to find which skills actually pay the most.
--   I used MEDIAN instead of AVG to avoid skew from extreme outliers.
--
-- Approach:
--   Same three-table join as Query 1, but this time I'm measuring compensation.
--   HAVING >= 100 filters out niche skills with tiny sample sizes — I only want
--   skills where there's enough data to trust the salary figure.
--
-- Design decision — why MEDIAN over AVG:
--   Salary distributions are right-skewed (a few $500K+ offers pull the average
--   way up). MEDIAN gives me the "typical" salary, which is more honest.
-- =============================================================================

SELECT
    sd.skills,
    ROUND(MEDIAN(jpf.salary_year_avg), 0) AS median_salary,
    COUNT(jpf.*) AS skill_count

FROM job_postings_fact jpf

INNER JOIN skills_job_dim sjd
    ON jpf.job_id = sjd.job_id

INNER JOIN skills_dim sd
    ON sjd.skill_id = sd.skill_id

WHERE
    jpf.job_title_short = 'Data Engineer'
    AND jpf.job_work_from_home = True

GROUP BY sd.skills

-- Only include skills with meaningful sample size
HAVING COUNT(sd.skills) >= 100

ORDER BY median_salary DESC
LIMIT 25;

/*
Results & Takeaways
--------------------
Rust tops the list at $210K median — but only 232 postings. High pay, niche demand.

The real sweet spots are skills with BOTH high pay and solid demand:
  - Terraform ($184K, 3,248 postings) — infrastructure-as-code is clearly valued
  - Golang ($184K, 912 postings) — performance-critical backend work
  - Kubernetes ($150.5K, 4,202 postings) — container orchestration is everywhere
  - Airflow ($150K, 9,996 postings) — the most demanded AND well-paid combo

Interesting mid-tier finds:
  - Spring ($175.5K) and Neo4j ($170K) pay well but have smaller demand
  - GDPR knowledge ($169.6K) — compliance skills carry a premium
  - GraphQL ($167.5K) — API layer skills aren't just for frontend devs

The lesson here: don't chase the highest-paying skill blindly. Look at skill_count
too. Terraform + Kubernetes + Airflow give both income and job security.

┌────────────┬───────────────┬─────────────┐
│   skills   │ median_salary │ skill_count │
│  varchar   │    double     │    int64    │
├────────────┼───────────────┼─────────────┤
│ rust       │      210000.0 │         232 │
│ terraform  │      184000.0 │        3248 │
│ golang     │      184000.0 │         912 │
│ spring     │      175500.0 │         364 │
│ neo4j      │      170000.0 │         277 │
│ gdpr       │      169616.0 │         582 │
│ zoom       │      168438.0 │         127 │
│ graphql    │      167500.0 │         445 │
│ mongo      │      162250.0 │         265 │
│ fastapi    │      157500.0 │         204 │
│ django     │      155000.0 │         265 │
│ bitbucket  │      155000.0 │         478 │
│ crystal    │      154224.0 │         129 │
│ atlassian  │      151500.0 │         249 │
│ c          │      151500.0 │         444 │
│ typescript │      151000.0 │         388 │
│ kubernetes │      150500.0 │        4202 │
│ node       │      150000.0 │         179 │
│ ruby       │      150000.0 │         736 │
│ airflow    │      150000.0 │        9996 │
│ css        │      150000.0 │         262 │
│ redis      │      149000.0 │         605 │
│ ansible    │      148798.0 │         475 │
│ vmware     │      148798.0 │         136 │
│ jupyter    │      147500.0 │         400 │
├────────────┴───────────────┴─────────────┤
│ 25 rows                        3 columns │
└──────────────────────────────────────────┘
*/