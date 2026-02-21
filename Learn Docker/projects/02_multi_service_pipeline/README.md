# Project 2: Multi-Service Data Pipeline

## Overview

Build a data pipeline with multiple services: a source database, a target warehouse, a Python ETL container, and a monitoring dashboard. This simulates a real production setup where data flows between systems.

This project covers: Docker Compose, multi-container networking, health checks, secrets, resource limits, multiple databases.

## What You'll Build

```
┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│  Source DB   │────>│  Python ETL │────>│  Warehouse   │
│  (PostgreSQL)│     │  Container  │     │  (PostgreSQL) │
└──────────────┘     └─────────────┘     └──────────────┘
  Init with              Extracts,           Stores
  seed data              transforms,         clean data
                         loads
                            │
                    ┌───────▼────────┐
                    │    pgAdmin     │
                    │  (port 8080)   │
                    └────────────────┘
```

## Project Structure

```
project-2-multi-service/
├── docker-compose.yml
├── docker-compose.dev.yml
├── Dockerfile
├── .env
├── .env.example
├── .dockerignore
├── requirements.txt
├── src/
│   ├── config.py
│   ├── extract.py
│   ├── transform.py
│   ├── load.py
│   └── pipeline.py
├── init/
│   ├── source/
│   │   ├── 01-schema.sql
│   │   └── 02-seed-data.sql
│   └── warehouse/
│       └── 01-schema.sql
└── logs/
```

## Requirements

### Source Database
- PostgreSQL with sample data (auto-loaded)
- Contains tables: `users`, `orders`, `products`
- At least 50 rows of realistic data
- NOT exposed to host (internal network only)

### Warehouse Database
- Empty PostgreSQL (schema loaded from init SQL)
- Contains a star schema: `dim_users`, `dim_products`, `fact_orders`
- Exposed on port 5432 for DBeaver/pgAdmin

### ETL Container
- Extracts from source database
- Transforms (denormalize, calculate metrics, add timestamps)
- Loads to warehouse in star schema format
- Retry logic for database connections
- Structured logging (JSON)

### Monitoring
- pgAdmin accessible on port 8080
- Only starts with `--profile ui` flag

### Security
- No hardcoded passwords (use `.env`)
- Health checks on all databases
- Resource limits on all containers

## Step-by-Step Instructions

### 1. Design the source schema

```sql
-- Source: transactional tables
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(200),
    city VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2)
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id),
    product_id INT REFERENCES products(product_id),
    quantity INT,
    order_date DATE,
    total DECIMAL(10,2)
);
```

### 2. Design the warehouse schema

```sql
-- Warehouse: star schema
CREATE TABLE dim_users (...);
CREATE TABLE dim_products (...);
CREATE TABLE fact_orders (...);
```

### 3. Write seed data (02-seed-data.sql)

Insert realistic sample data — users, products, and orders.

### 4. Write the ETL

- `config.py`: Read all config from environment variables, validate required vars
- `extract.py`: Read from source PostgreSQL
- `transform.py`: Reshape into star schema, add calculated fields
- `load.py`: Write to warehouse PostgreSQL (upsert for dimensions, append for facts)
- `pipeline.py`: Orchestrate with logging and error handling

### 5. Create dev and prod compose overrides

- `docker-compose.yml`: Base configuration
- `docker-compose.dev.yml`: Expose all ports, bind mount source code

## Success Criteria

- [ ] Source DB starts with seed data
- [ ] Warehouse DB starts with empty schema
- [ ] ETL extracts from source, transforms, loads to warehouse
- [ ] Star schema is properly populated
- [ ] pgAdmin works on port 8080 (with `--profile ui`)
- [ ] No passwords in compose files or Dockerfiles
- [ ] Health checks pass for all services
- [ ] Data persists across restarts

## Bonus Challenges

- Add incremental loading (only new orders since last run)
- Add data quality checks (row counts match, no nulls in required fields)
- Add a Redis cache for frequently accessed dimension data
- Create a `docker-compose.test.yml` that runs pytest against the pipeline
- Add a cron schedule to run the pipeline hourly
