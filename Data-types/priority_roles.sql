--Batch Processing
--.read Data-types/priority_roles.sql

CREATE OR REPLACE TABLE staging.priority_roles (
    role_id INTEGER PRIMARY KEY,
    role_name VARCHAR,
    priority_lvl INTEGER
);

INSERT INTO staging.priority_roles (role_id, role_name, priority_lvl)
VALUES
(1, 'Data Engineer', 1),
(2, 'Senior Data Engineer', 1),
(3, 'Software Engineer', 3);

SELECT * FROM staging.priority_roles;