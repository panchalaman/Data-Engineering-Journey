# Project 3: Airflow Data Pipeline

## Overview

Set up Apache Airflow with Docker Compose and build a DAG that orchestrates a complete data pipeline — extracting data from a source, transforming it, loading it to a warehouse, and running data quality checks.

This project covers: Airflow in Docker, DAG development, database connections, task dependencies, error handling, scheduling.

## What You'll Build

```
┌─────────────────────────────────────────────────┐
│              Apache Airflow (Docker)             │
│                                                  │
│  ┌──────┐   ┌───────────┐   ┌──────┐   ┌─────┐ │
│  │Extract│──>│ Transform │──>│ Load │──>│Check│ │
│  └──────┘   └───────────┘   └──────┘   └─────┘ │
│                                                  │
│  Webserver (8080)  │  Scheduler  │  Metadata DB  │
└─────────────────────────────────────────────────┘
         │                              │
         │                    ┌─────────▼──────────┐
         │                    │  Data Warehouse    │
         │                    │  (PostgreSQL)      │
         └                    └────────────────────┘
     UI Access
```

## Project Structure

```
project-3-airflow/
├── docker-compose.yml
├── Dockerfile                    # Custom Airflow image
├── requirements.txt              # Extra Python packages
├── .env
├── dags/
│   ├── data_pipeline_dag.py      # Main pipeline DAG
│   ├── data_quality_dag.py       # Quality checks DAG
│   └── sql/
│       ├── create_tables.sql
│       ├── transform.sql
│       └── quality_checks.sql
├── init/
│   ├── source/
│   │   ├── 01-schema.sql
│   │   └── 02-seed.sql
│   └── warehouse/
│       └── 01-schema.sql
├── plugins/                      # Custom Airflow plugins
├── logs/
└── scripts/
    └── entrypoint.sh
```

## Requirements

### Airflow Setup
- Custom Airflow image with pandas, sqlalchemy, psycopg2
- LocalExecutor (simpler than Celery for this project)
- Airflow metadata database (PostgreSQL)
- Admin user auto-created on startup
- Example DAGs disabled

### Data Pipeline DAG
Schedule: `@daily`

Tasks:
1. **check_source**: Sensor/check that source database is available
2. **extract_users**: Extract users table to XCom or temp storage
3. **extract_orders**: Extract orders table (runs parallel with users)
4. **extract_products**: Extract products table (runs parallel)  
5. **transform_and_load**: Join, transform, and load to warehouse
6. **data_quality_check**: Verify row counts, null checks, value ranges
7. **report**: Print summary of the pipeline run

```
                 ┌──────────────┐
                 │ check_source │
                 └──────┬───────┘
                        │
           ┌────────────┼────────────┐
           │            │            │
    ┌──────▼───┐  ┌─────▼────┐ ┌────▼─────┐
    │ extract  │  │ extract  │ │ extract  │
    │ _users   │  │ _orders  │ │_products │
    └──────┬───┘  └─────┬────┘ └────┬─────┘
           │            │            │
           └────────────┼────────────┘
                        │
              ┌─────────▼──────────┐
              │ transform_and_load │
              └─────────┬──────────┘
                        │
              ┌─────────▼──────────┐
              │ data_quality_check │
              └─────────┬──────────┘
                        │
                  ┌─────▼────┐
                  │  report  │
                  └──────────┘
```

### Database Services
- **Source PostgreSQL**: Seed data loaded automatically
- **Warehouse PostgreSQL**: Empty, schema created by DAG
- **Airflow PostgreSQL**: Metadata database (separate from warehouse)

### Connections
Configure Airflow connections via environment variables:
- `AIRFLOW_CONN_SOURCE_DB`: Connection to source database
- `AIRFLOW_CONN_WAREHOUSE_DB`: Connection to warehouse

## Step-by-Step Instructions

### 1. Create the custom Airflow Dockerfile

Extend `apache/airflow:2.8.0-python3.11` with your required packages.

### 2. Write docker-compose.yml

Services needed:
- `postgres` (Airflow metadata)
- `source-db` (source data)
- `warehouse` (target warehouse)
- `airflow-init` (database migration + user creation)
- `airflow-webserver`
- `airflow-scheduler`

### 3. Write the main DAG

`dags/data_pipeline_dag.py` should:
- Use `PythonOperator` for extract tasks
- Use `PostgresOperator` for SQL transforms  
- Pass data between tasks using XCom or file-based approach
- Have proper retry settings (`retries=2, retry_delay=timedelta(minutes=5)`)
- Use Airflow connections (not hardcoded connection strings)

### 4. Write the data quality DAG

`dags/data_quality_dag.py` should:
- Run after the main pipeline
- Check row counts (warehouse should have >= source rows)
- Check for unexpected nulls
- Check value ranges (no negative salaries, dates in expected range)
- Alert (print/log) on failures

### 5. Start everything

```bash
mkdir -p dags logs plugins
docker compose up airflow-init
docker compose up -d
```

### 6. Access Airflow UI

Open http://localhost:8080, login with admin/admin. Enable your DAGs and trigger them.

## Success Criteria

- [ ] Airflow UI accessible on port 8080
- [ ] Main pipeline DAG shows correct task dependencies in graph view
- [ ] All tasks complete successfully (green)
- [ ] Parallel extract tasks actually run in parallel
- [ ] Data appears in warehouse database
- [ ] Data quality checks pass
- [ ] DAG can be re-run without errors (idempotent)
- [ ] Pipeline logs are detailed and useful
- [ ] Connections use Airflow's connection management (not hardcoded)

## Bonus Challenges

- Add email alerting on task failure (configure SMTP)
- Add a BranchPythonOperator that skips loading if data quality fails
- Create a "backfill" DAG that loads historical data
- Add a FileSensor that waits for a new data file before triggering
- Set up Celery executor with Redis and 2 workers
- Create a custom Airflow plugin/hook for your specific pipeline logic
- Add SLAs (mark tasks late if they take too long)
