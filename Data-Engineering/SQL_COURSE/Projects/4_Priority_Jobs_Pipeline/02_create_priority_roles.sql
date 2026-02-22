-- ============================================================
-- 02_create_priority_roles.sql
-- ============================================================
-- Build and populate the priority_roles config table.
--
-- This table is the "input" to our pipeline — it defines which
-- job roles we care about and how urgent they are. Think of it
-- as a lookup table that a hiring manager or team lead would
-- maintain. Priority 1 = "we need this yesterday", 3 = "nice
-- to have, keep an eye on it."
--
-- I went through several iterations of this table. Started with
-- a BOOLEAN column (preferred_role), then realized priority
-- levels give more flexibility. That evolution is documented
-- in 02b_schema_evolution.sql if you want to see the ALTER
-- TABLE journey.
--
-- Run: .read Data-types/4_Priority_Jobs_Pipeline/02_create_priority_roles.sql
-- ============================================================

USE jobs_mart;

-- Create the table fresh every time (idempotent)
CREATE OR REPLACE TABLE staging.priority_roles (
    role_id      INTEGER PRIMARY KEY,
    role_name    VARCHAR NOT NULL,
    priority_lvl INTEGER NOT NULL    -- 1 = critical, 2 = important, 3 = monitor
);

-- Load our priority definitions
-- In a real pipeline, this might come from a Google Sheet,
-- a YAML config file, or an internal tool. Here we just
-- hardcode the roles we're tracking.
INSERT INTO staging.priority_roles (role_id, role_name, priority_lvl)
VALUES
    (1, 'Data Engineer',        1),
    (2, 'Senior Data Engineer', 1),
    (3, 'Software Engineer',    3);

-- Verify
SELECT * FROM staging.priority_roles;

/*
Expected output:
┌─────────┬──────────────────────┬──────────────┐
│ role_id │      role_name       │ priority_lvl │
├─────────┼──────────────────────┼──────────────┤
│       1 │ Data Engineer        │            1 │
│       2 │ Senior Data Engineer │            1 │
│       3 │ Software Engineer    │            3 │
└─────────┴──────────────────────┴──────────────┘
*/
