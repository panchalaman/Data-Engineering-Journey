# Project 1: Containerized Python ETL Pipeline

## Overview

Build a complete ETL pipeline that extracts data from a CSV file, transforms it with Python/pandas, and loads it into a PostgreSQL database — all running in Docker containers.

This project covers: Dockerfile, Docker Compose, volumes, networking, health checks, environment variables.

## What You'll Build

```
┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│  CSV File    │────>│  Python ETL │────>│  PostgreSQL  │
│  (raw data)  │     │  Container  │     │  Warehouse   │
└──────────────┘     └─────────────┘     └──────────────┘
     bind mount         builds from          named volume
                        Dockerfile
```

## Project Structure

```
project-1-etl/
├── docker-compose.yml
├── Dockerfile
├── .env
├── .env.example
├── .dockerignore
├── requirements.txt
├── src/
│   ├── extract.py
│   ├── transform.py
│   ├── load.py
│   └── pipeline.py
├── data/
│   └── raw/
│       └── sample_jobs.csv
├── init/
│   └── 01-schema.sql
└── logs/
```

## Step-by-Step Instructions

### 1. Create the sample data

Create `data/raw/sample_jobs.csv`:

```csv
job_id,title,company,salary_min,salary_max,skills,location,posted_date
1,Data Engineer,Google,120000,180000,"Python,SQL,Spark",Mountain View,2024-01-15
2,Senior Data Engineer,Meta,140000,200000,"Python,Airflow,Docker",Menlo Park,2024-01-16
3,Data Engineer,Amazon,115000,170000,"SQL,Python,AWS",Seattle,2024-01-15
4,Analytics Engineer,Stripe,130000,190000,"SQL,dbt,Python",San Francisco,2024-01-17
5,Data Engineer,Netflix,150000,220000,"Python,Spark,Kafka",Los Gatos,2024-01-18
6,Junior Data Engineer,Spotify,90000,130000,"Python,SQL",New York,2024-01-16
7,Staff Data Engineer,Airbnb,160000,240000,"Python,Spark,Airflow,Docker",San Francisco,2024-01-19
8,Data Engineer II,Microsoft,125000,185000,"Python,SQL,Azure",Redmond,2024-01-17
9,Data Engineer,Uber,130000,195000,"Python,Spark,Kafka",San Francisco,2024-01-20
10,Senior Data Engineer,Apple,145000,210000,"Python,SQL,Spark",Cupertino,2024-01-18
```

### 2. Create the init SQL

Create `init/01-schema.sql`:

```sql
CREATE TABLE IF NOT EXISTS jobs_cleaned (
    job_id INTEGER PRIMARY KEY,
    title VARCHAR(200),
    company VARCHAR(200),
    salary_min INTEGER,
    salary_max INTEGER,
    salary_avg INTEGER,
    skills TEXT,
    location VARCHAR(200),
    posted_date DATE,
    loaded_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS skills_summary (
    skill VARCHAR(100) PRIMARY KEY,
    job_count INTEGER,
    avg_salary_min NUMERIC,
    avg_salary_max NUMERIC,
    avg_salary NUMERIC
);
```

### 3. Write the Python ETL code

Implement `extract.py`, `transform.py`, `load.py`, and `pipeline.py`:

- **extract.py**: Read the CSV with pandas
- **transform.py**: Clean data (drop duplicates, calculate salary_avg, normalize strings)
- **load.py**: Insert into PostgreSQL using SQLAlchemy
- **pipeline.py**: Orchestrate E → T → L with logging and error handling

### 4. Write the Dockerfile

Requirements:
- Based on `python:3.11-slim`
- Install system dependencies for psycopg2
- Install Python packages from requirements.txt
- Use layer caching properly
- Create non-root user (bonus)

### 5. Write docker-compose.yml

Requirements:
- PostgreSQL service with named volume and health check
- ETL service that builds from Dockerfile
- Init SQL mounted to PostgreSQL's `/docker-entrypoint-initdb.d/`
- Data directory bind-mounted to ETL container
- Logs directory bind-mounted
- `depends_on` with `service_healthy`
- Environment variables from `.env` file

### 6. Run it

```bash
docker compose up --build
```

## Success Criteria

- [ ] PostgreSQL starts and creates tables from init SQL
- [ ] ETL waits for PostgreSQL to be healthy
- [ ] CSV data is extracted, transformed, and loaded
- [ ] `jobs_cleaned` table has all 10 rows with `salary_avg` calculated
- [ ] `skills_summary` table has aggregated skill statistics
- [ ] Logs are saved to `./logs/` on your machine
- [ ] Data persists after `docker compose down` and `docker compose up`
- [ ] Data is gone after `docker compose down -v`

## Bonus Challenges

- Add a pgAdmin service to visually inspect the database
- Add retry logic for the database connection
- Add data validation (check for nulls, valid salary ranges)
- Make the input file path configurable via environment variable
