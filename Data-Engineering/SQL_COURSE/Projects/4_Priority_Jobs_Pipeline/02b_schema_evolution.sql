-- ============================================================
-- 02b_schema_evolution.sql  (OPTIONAL — learning reference)
-- ============================================================
-- This file shows the journey of how priority_roles evolved.
-- You don't need to run this — it's here to document what I
-- learned about ALTER TABLE, RENAME, and type changes.
--
-- In production, schema changes happen ALL the time. A PM says
-- "I want a boolean flag" on Monday, then by Friday they want
-- priority levels instead. Knowing ALTER TABLE is how you
-- handle that without rebuilding everything.
--
-- Run: .read Data-types/4_Priority_Jobs_Pipeline/02b_schema_evolution.sql
-- ============================================================

USE jobs_mart;

-- ============================================================
-- PHASE 1: Started with a simple preferred_roles table
-- ============================================================
-- The first version was just "do we care about this role? yes/no"

CREATE TABLE IF NOT EXISTS staging.preferred_roles (
    role_id       INTEGER PRIMARY KEY,
    role_name     VARCHAR
);

INSERT INTO staging.preferred_roles (role_id, role_name)
VALUES
    (1, 'Data Engineer'),
    (2, 'Senior Data Engineer'),
    (3, 'Software Engineer');

SELECT * FROM staging.preferred_roles;

-- Then the ask came in: "Can we flag which ones we actually prefer?"
-- Sure — let's add a boolean column.
ALTER TABLE staging.preferred_roles
ADD COLUMN preferred_role BOOLEAN;

-- Set priorities
UPDATE staging.preferred_roles
SET preferred_role = TRUE
WHERE role_id IN (1, 2);

UPDATE staging.preferred_roles
SET preferred_role = FALSE
WHERE role_id = 3;

SELECT * FROM staging.preferred_roles;
-- Looks good. But then...

-- ============================================================
-- PHASE 2: Boolean wasn't enough. Need priority LEVELS.
-- ============================================================
-- A week later: "Can we have high/medium/low instead of yes/no?"
-- This is why experienced engineers push back on booleans for
-- things that might need more granularity later.

-- Rename the table — it's not about "preferred" anymore
ALTER TABLE staging.preferred_roles
RENAME TO priority_roles;

-- Rename the column to match the new meaning
ALTER TABLE staging.priority_roles
RENAME COLUMN preferred_role TO priority_lvl;

-- Change the type from BOOLEAN to INTEGER
-- 1 = critical, 2 = important, 3 = monitor
ALTER TABLE staging.priority_roles
ALTER COLUMN priority_lvl TYPE INTEGER;

-- Update the values to use the new scale
UPDATE staging.priority_roles
SET priority_lvl = 1
WHERE role_id IN (1, 2);

UPDATE staging.priority_roles
SET priority_lvl = 3
WHERE role_id = 3;

SELECT * FROM staging.priority_roles;

-- ============================================================
-- LESSONS LEARNED
-- ============================================================
-- 1. ALTER TABLE ADD COLUMN  — adding fields is cheap
-- 2. ALTER TABLE RENAME      — renaming tables/columns is free
-- 3. ALTER TABLE ALTER TYPE   — changing types can break things
--    (boolean → integer works, but varchar → integer might not
--    if the data doesn't convert cleanly)
-- 4. Booleans feel simple but often need to become enums/integers
--    later. If there's ANY chance of "maybe" or "levels",
--    start with an integer.
-- 5. These operations are DDL — they change structure, not data.
--    The UPDATE statements that followed are DML.

-- Clean up — this was just for learning
DROP TABLE IF EXISTS staging.priority_roles;
-- (02_create_priority_roles.sql rebuilds it properly)
