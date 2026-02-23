-- ============================================================
-- LESSON 1.08: Subqueries & CTEs
-- ============================================================
-- Sometimes you need the result of one query to feed into
-- another query. That's what subqueries and CTEs do.
--
-- CTEs (Common Table Expressions) changed how I write SQL.
-- Once you learn them, you'll never go back to writing
-- giant nested queries.
-- ============================================================


-- ============================================================
-- SUBQUERIES — A Query Inside a Query
-- ============================================================

-- Subquery in WHERE
-- "Show me jobs with salary above the overall average"
SELECT
    job_id,
    job_title,
    salary_year_avg
FROM data_jobs.job_postings_fact
WHERE salary_year_avg > (
    SELECT AVG(salary_year_avg)
    FROM data_jobs.job_postings_fact
    WHERE salary_year_avg IS NOT NULL
)
ORDER BY salary_year_avg DESC
LIMIT 10;
/*

┌─────────┬───────────────────────────────────────────────────────────────────────────────────────────┬─────────────────┐
│ job_id  │                                         job_title                                         │ salary_year_avg │
│  int32  │                                          varchar                                          │     double      │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────┼─────────────────┤
│  296745 │ Data Scientist                                                                            │        960000.0 │
│ 1231950 │ Data Science Manager - Messaging and Inferred Identity DSE at Netflix in Los Gatos, Cal…  │        920000.0 │
│  673003 │ Senior Data Scientist                                                                     │        890000.0 │
│ 1575798 │ Machine Learning Engineer                                                                 │        875000.0 │
│ 1007105 │ Machine Learning Engineer/Data Scientist                                                  │        870000.0 │
│  856772 │ Data Scientist                                                                            │        850000.0 │
│ 1443865 │ Senior Data Engineer (MDM team), DTG                                                      │        800000.0 │
│ 1591743 │ AI/ML (Artificial Intelligence/Machine Learning) Engineer                                 │        800000.0 │
│ 1574285 │ Data Scientist , Games [Remote]                                                           │        680000.0 │
│  142665 │ Data Analyst                                                                              │        650000.0 │
├─────────┴───────────────────────────────────────────────────────────────────────────────────────────┴─────────────────┤
│ 10 rows                                                                                                     3 columns │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

*/

-- The inner query runs first, calculates the average salary,
-- then the outer query uses that value as a filter.


-- Subquery in WHERE with IN
-- "Show me jobs from the top 5 highest-hiring companies"
SELECT
    job_id,
    job_title,
    company_id
FROM data_jobs.job_postings_fact
WHERE company_id IN (
    SELECT company_id
    FROM data_jobs.job_postings_fact
    GROUP BY company_id
    ORDER BY COUNT(*) DESC
    LIMIT 5
)
LIMIT 20;
/*

┌────────┬─────────────────────────────────────────────────────────────────┬────────────┐
│ job_id │                            job_title                            │ company_id │
│ int32  │                             varchar                             │   int32    │
├────────┼─────────────────────────────────────────────────────────────────┼────────────┤
│ 472193 │ Electrical Design Engineer, APAC Data Center Design Engineering │       5429 │
│ 472895 │ Senior Data Engineer                                            │       4830 │
│ 472907 │ Principal Data Scientist - DataML, Enterprise Data Science      │       4830 │
│ 473186 │ Business Intelligence Analyst                                   │     212463 │
│ 473187 │ Consultoría : Ssr Data Analyst : Olivos                         │     212463 │
│ 473188 │ Data and Business Intelligence Associate Director               │     212463 │
│ 473189 │ Product and Data Specialist                                     │     212463 │
│ 473190 │ Senior Data Engineer                                            │     212463 │
│ 473191 │ Business Intelligence Analyst                                   │     212463 │
│ 473192 │ Business Analyst                                                │     212463 │
│ 473193 │ Business Analyst                                                │     212463 │
│ 473194 │ Business Analyst Specialist                                     │     212463 │
│ 473195 │ Regional Data Scientist                                         │     212463 │
│ 473196 │ Analista Data Engineer                                          │     212463 │
│ 473197 │ Azure Data Modeler Senior                                       │     212463 │
│ 473198 │ Growth Analyst                                                  │     212463 │
│ 473199 │ Lead Generation Data Entry Position                             │     212463 │
│ 473200 │ Data Science Manager                                            │     212463 │
│ 473201 │ Practicante de Data Analytics                                   │     212463 │
│ 473202 │ Analyst- Insurance Operations                                   │     212463 │
├────────┴─────────────────────────────────────────────────────────────────┴────────────┤
│ 20 rows                                                                     3 columns │
└───────────────────────────────────────────────────────────────────────────────────────┘

*/



-- Subquery in SELECT
-- "Show each job's salary vs the average for its title"
SELECT
    job_id,
    job_title_short,
    salary_year_avg,
    (SELECT ROUND(AVG(salary_year_avg), 0)
     FROM data_jobs.job_postings_fact sub
     WHERE sub.job_title_short = main.job_title_short
       AND sub.salary_year_avg IS NOT NULL
    ) AS title_avg_salary,
    ROUND(salary_year_avg - (
        SELECT AVG(salary_year_avg)
        FROM data_jobs.job_postings_fact sub
        WHERE sub.job_title_short = main.job_title_short
          AND sub.salary_year_avg IS NOT NULL
    ), 0) AS diff_from_avg
FROM data_jobs.job_postings_fact AS main
WHERE salary_year_avg IS NOT NULL
ORDER BY diff_from_avg DESC
LIMIT 10;
/*

┌─────────┬───────────────────────────┬─────────────────┬──────────────────┬───────────────┐
│ job_id  │      job_title_short      │ salary_year_avg │ title_avg_salary │ diff_from_avg │
│  int32  │          varchar          │     double      │      double      │    double     │
├─────────┼───────────────────────────┼─────────────────┼──────────────────┼───────────────┤
│  296745 │ Data Scientist            │        960000.0 │         134324.0 │      825676.0 │
│ 1231950 │ Data Scientist            │        920000.0 │         134324.0 │      785676.0 │
│ 1575798 │ Machine Learning Engineer │        875000.0 │         137332.0 │      737668.0 │
│ 1007105 │ Data Scientist            │        870000.0 │         134324.0 │      735676.0 │
│  673003 │ Senior Data Scientist     │        890000.0 │         156391.0 │      733609.0 │
│  856772 │ Data Scientist            │        850000.0 │         134324.0 │      715676.0 │
│ 1591743 │ Machine Learning Engineer │        800000.0 │         137332.0 │      662668.0 │
│ 1443865 │ Senior Data Engineer      │        800000.0 │         149222.0 │      650778.0 │
│  142665 │ Data Analyst              │        650000.0 │          93223.0 │      556777.0 │
│ 1574285 │ Data Scientist            │        680000.0 │         134324.0 │      545676.0 │
├─────────┴───────────────────────────┴─────────────────┴──────────────────┴───────────────┤
│ 10 rows                                                                        5 columns │
└──────────────────────────────────────────────────────────────────────────────────────────┘

*/

-- This works but it's getting hard to read. Also, that subquery
-- runs for EVERY row, which can be slow. Enter CTEs...


-- ============================================================
-- CTEs — Common Table Expressions
-- ============================================================
-- A CTE is a named temporary result set. You define it at the
-- top with WITH, then use it like a regular table below.
--
-- Think of it as: "first calculate this, then use it."

-- Same query as above, but readable:
WITH title_averages AS (
    SELECT
        job_title_short,
        ROUND(AVG(salary_year_avg), 0) AS avg_salary
    FROM data_jobs.job_postings_fact
    WHERE salary_year_avg IS NOT NULL
    GROUP BY job_title_short
)
SELECT
    jpf.job_id,
    jpf.job_title_short,
    jpf.salary_year_avg,
    ta.avg_salary AS title_avg_salary,
    ROUND(jpf.salary_year_avg - ta.avg_salary, 0) AS diff_from_avg
FROM data_jobs.job_postings_fact AS jpf
INNER JOIN title_averages AS ta
    ON jpf.job_title_short = ta.job_title_short
WHERE jpf.salary_year_avg IS NOT NULL
ORDER BY diff_from_avg DESC
LIMIT 10;
/*

┌─────────┬───────────────────────────┬─────────────────┬──────────────────┬───────────────┐
│ job_id  │      job_title_short      │ salary_year_avg │ title_avg_salary │ diff_from_avg │
│  int32  │          varchar          │     double      │      double      │    double     │
├─────────┼───────────────────────────┼─────────────────┼──────────────────┼───────────────┤
│  296745 │ Data Scientist            │        960000.0 │         134324.0 │      825676.0 │
│ 1231950 │ Data Scientist            │        920000.0 │         134324.0 │      785676.0 │
│ 1575798 │ Machine Learning Engineer │        875000.0 │         137332.0 │      737668.0 │
│ 1007105 │ Data Scientist            │        870000.0 │         134324.0 │      735676.0 │
│  673003 │ Senior Data Scientist     │        890000.0 │         156391.0 │      733609.0 │
│  856772 │ Data Scientist            │        850000.0 │         134324.0 │      715676.0 │
│ 1591743 │ Machine Learning Engineer │        800000.0 │         137332.0 │      662668.0 │
│ 1443865 │ Senior Data Engineer      │        800000.0 │         149222.0 │      650778.0 │
│  142665 │ Data Analyst              │        650000.0 │          93223.0 │      556777.0 │
│ 1574285 │ Data Scientist            │        680000.0 │         134324.0 │      545676.0 │
├─────────┴───────────────────────────┴─────────────────┴──────────────────┴───────────────┤
│ 10 rows                                                                        5 columns │
└──────────────────────────────────────────────────────────────────────────────────────────┘

*/

-- SO much cleaner. The CTE calculates title averages once,
-- and then we just join to it.


-- ============================================================
-- MULTIPLE CTEs
-- ============================================================
-- You can chain multiple CTEs. Each one can reference the
-- ones defined before it.

WITH skill_demand AS (
    -- Step 1: Count demand per skill
    SELECT
        sd.skills AS skill_name,
        COUNT(*) AS demand_count
    FROM data_jobs.job_postings_fact AS jpf
    INNER JOIN data_jobs.skills_job_dim AS sjd ON jpf.job_id = sjd.job_id
    INNER JOIN data_jobs.skills_dim AS sd ON sjd.skill_id = sd.skill_id
    WHERE jpf.job_title_short = 'Data Engineer'
    GROUP BY sd.skills
),
skill_salary AS (
    -- Step 2: Average salary per skill
    SELECT
        sd.skills AS skill_name,
        ROUND(AVG(jpf.salary_year_avg), 0) AS avg_salary
    FROM data_jobs.job_postings_fact AS jpf
    INNER JOIN data_jobs.skills_job_dim AS sjd ON jpf.job_id = sjd.job_id
    INNER JOIN data_jobs.skills_dim AS sd ON sjd.skill_id = sd.skill_id
    WHERE jpf.job_title_short = 'Data Engineer'
      AND jpf.salary_year_avg IS NOT NULL
    GROUP BY sd.skills
)
-- Step 3: Combine demand and salary
SELECT
    d.skill_name,
    d.demand_count,
    s.avg_salary
FROM skill_demand AS d
INNER JOIN skill_salary AS s
    ON d.skill_name = s.skill_name
WHERE d.demand_count >= 100
ORDER BY s.avg_salary DESC
LIMIT 15;
/*

┌─────────────────┬──────────────┬────────────┐
│   skill_name    │ demand_count │ avg_salary │
│     varchar     │    int64     │   double   │
├─────────────────┼──────────────┼────────────┤
│ solidity        │          174 │   183450.0 │
│ node            │         1084 │   180953.0 │
│ rust            │         1317 │   180912.0 │
│ mongo           │         3795 │   174563.0 │
│ scikit-learn    │         3676 │   166541.0 │
│ pytorch         │         4400 │   165803.0 │
│ vue             │         1107 │   159167.0 │
│ microsoft teams │          252 │   155573.0 │
│ codecommit      │          292 │   155000.0 │
│ tensorflow      │         5038 │   152903.0 │
│ groovy          │          813 │   152525.0 │
│ nltk            │          316 │   152167.0 │
│ puppet          │         1066 │   151582.0 │
│ gdpr            │         4535 │   151306.0 │
│ asana           │          128 │   151207.0 │
├─────────────────┴──────────────┴────────────┤
│ 15 rows                           3 columns │
└─────────────────────────────────────────────┘

*/

-- This is the same approach I used in the EDA project.
-- Break complex analysis into clear, named steps.


-- ============================================================
-- CTEs vs SUBQUERIES — When to Use Which
-- ============================================================
/*
   USE CTEs WHEN:
   - You need the same result in multiple places
   - The query has multiple logical steps
   - You want readable, maintainable code
   - You're building data pipelines (always CTEs)

   USE SUBQUERIES WHEN:
   - It's a simple one-off filter (WHERE x IN (subquery))
   - The subquery is short and self-contained
   - You're doing a quick ad-hoc check

   In practice, I use CTEs about 90% of the time.
   They make code easier to debug — you can run each CTE
   independently to check its output.
*/


-- ============================================================
-- EXISTS — Does a Match Exist?
-- ============================================================
-- EXISTS is a special subquery that returns TRUE/FALSE.
-- It's faster than IN for large datasets.

-- Find companies that have at least one Data Engineer posting
SELECT
    cd.company_id,
    cd.name AS company_name
FROM company_dim AS cd
WHERE EXISTS (
    SELECT 1
    FROM job_postings_fact AS jpf
    WHERE jpf.company_id = cd.company_id
      AND jpf.job_title_short = 'Data Engineer'
)
LIMIT 10;

-- NOT EXISTS — find companies with NO Data Engineer postings
SELECT
    cd.company_id,
    cd.name AS company_name
FROM company_dim AS cd
WHERE NOT EXISTS (
    SELECT 1
    FROM job_postings_fact AS jpf
    WHERE jpf.company_id = cd.company_id
      AND jpf.job_title_short = 'Data Engineer'
)
LIMIT 10;


-- ============================================================
-- DERIVED TABLES (Subquery in FROM)
-- ============================================================
-- You can put a subquery in the FROM clause. It acts as
-- a temporary table.

SELECT
    title_stats.job_title_short,
    title_stats.avg_salary,
    title_stats.job_count
FROM (
    SELECT
        job_title_short,
        ROUND(AVG(salary_year_avg), 0) AS avg_salary,
        COUNT(*) AS job_count
    FROM job_postings_fact
    WHERE salary_year_avg IS NOT NULL
    GROUP BY job_title_short
) AS title_stats
WHERE title_stats.job_count > 100
ORDER BY title_stats.avg_salary DESC;

-- This is basically a CTE written inline. CTEs are almost
-- always more readable, but you'll see this pattern in older
-- SQL code.


-- ============================================================
-- REAL PATTERN: Incremental Analysis with CTEs
-- ============================================================
-- Here's how I use CTEs in actual data engineering work.
-- Each step transforms data a bit more.

WITH raw_data AS (
    -- Step 1: Get the base data we need
    SELECT
        jpf.job_id,
        jpf.job_title_short,
        jpf.salary_year_avg,
        jpf.job_posted_date,
        cd.name AS company_name
    FROM job_postings_fact AS jpf
    LEFT JOIN company_dim AS cd
        ON jpf.company_id = cd.company_id
    WHERE jpf.salary_year_avg IS NOT NULL
      AND jpf.job_title_short = 'Data Engineer'
),
monthly_stats AS (
    -- Step 2: Aggregate by month
    SELECT
        DATE_TRUNC('month', job_posted_date) AS month,
        COUNT(*) AS jobs_posted,
        ROUND(AVG(salary_year_avg), 0) AS avg_salary
    FROM raw_data
    GROUP BY DATE_TRUNC('month', job_posted_date)
)
-- Step 3: Final output
SELECT
    month,
    jobs_posted,
    avg_salary
FROM monthly_stats
ORDER BY month;


-- ============================================================
-- TRY THIS
-- ============================================================
-- 1. Use a subquery to find all jobs with salaries above
--    the median salary (MEDIAN function in DuckDB)
--
-- 2. Write a CTE that finds the top 10 skills by demand count,
--    then join it with salary data to see each skill's
--    average salary alongside its demand rank
--
-- 3. Use EXISTS to find skills that appear in Data Engineer
--    postings but NOT in Data Analyst postings
