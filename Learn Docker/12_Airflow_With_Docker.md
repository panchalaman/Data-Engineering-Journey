# Airflow with Docker

Apache Airflow is the most widely used orchestration tool in data engineering. It schedules and monitors your data pipelines — think of it as cron on steroids, with a web UI, dependency management, retries, and alerting.

The best part? The Airflow team provides an official Docker Compose setup. You can have a production-grade Airflow environment running locally in minutes.

## What Airflow Does

Without orchestration:
```
"Did the daily ETL run?"
"I think so... let me check the cron logs"
"It failed at 3am because the source database was down"
"When did you find out?"
"Just now, 9 hours later"
```

With Airflow:
```
- DAG scheduled for 3am
- Source database unavailable → task retried 3 times
- Still failing → email alert sent at 3:15am
- Fixed the issue → Airflow automatically retried and caught up
- Full history visible in the web UI
```

## Core Concepts (Quick Version)

| Concept | What It Is |
|---------|-----------|
| **DAG** | Directed Acyclic Graph — defines your pipeline's tasks and their order |
| **Task** | A single unit of work (run a SQL query, execute a Python function, etc.) |
| **Operator** | Template for a task (PythonOperator, BashOperator, PostgresOperator, etc.) |
| **Schedule** | How often the DAG runs (`@daily`, `@hourly`, cron expression) |
| **Executor** | How tasks are run (Local, Celery, Kubernetes) |

## Setting Up Airflow with Docker Compose

### Step 1: Get the Official docker-compose.yml

```bash
mkdir airflow-docker && cd airflow-docker

# Download the official Compose file
curl -LfO 'https://airflow.apache.org/docs/apache-airflow/2.8.0/docker-compose.yaml'
```

This compose file sets up:
- **airflow-webserver** — The web UI (port 8080)
- **airflow-scheduler** — Triggers DAGs on schedule
- **airflow-worker** — Runs the actual tasks (Celery executor)
- **airflow-triggerer** — Handles deferred tasks
- **postgres** — Airflow's metadata database
- **redis** — Message broker for Celery

That's a lot of containers. For local development, we can simplify.

### Step 2: Simplified Local Setup

For learning and development, you don't need Celery workers and Redis. Here's a simpler setup:

```yaml
# docker-compose.yml
x-airflow-common: &airflow-common
  image: apache/airflow:2.8.0-python3.11
  environment: &airflow-common-env
    AIRFLOW__CORE__EXECUTOR: LocalExecutor
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
    AIRFLOW__CORE__FERNET_KEY: ''
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
    AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
    AIRFLOW__API__AUTH_BACKENDS: 'airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session'
  volumes:
    - ./dags:/opt/airflow/dags
    - ./logs:/opt/airflow/logs
    - ./plugins:/opt/airflow/plugins
  depends_on:
    postgres:
      condition: service_healthy

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    volumes:
      - postgres-db-volume:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "airflow"]
      interval: 10s
      retries: 5
      start_period: 5s

  airflow-init:
    <<: *airflow-common
    entrypoint: /bin/bash
    command:
      - -c
      - |
        airflow db migrate
        airflow users create \
          --username admin \
          --password admin \
          --firstname Admin \
          --lastname User \
          --role Admin \
          --email admin@example.com
    depends_on:
      postgres:
        condition: service_healthy

  airflow-webserver:
    <<: *airflow-common
    command: webserver
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

  airflow-scheduler:
    <<: *airflow-common
    command: scheduler
    healthcheck:
      test: ["CMD", "airflow", "jobs", "check", "--job-type", "SchedulerJob", "--hostname", "$${HOSTNAME}"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

volumes:
  postgres-db-volume:
```

Let me break down the key parts:

**YAML Anchors (`&airflow-common`, `<<: *airflow-common`)**

This is YAML's way of avoiding repetition. `&airflow-common` defines a template. `<<: *airflow-common` copies it into a service. All Airflow services share the same image, environment, and volume mounts.

**LocalExecutor**

`AIRFLOW__CORE__EXECUTOR: LocalExecutor` means tasks run directly on the scheduler (no separate workers). Simpler, fewer containers, perfect for development and small workloads.

**Volume Mounts**

```
./dags    → /opt/airflow/dags      # Your DAG files go here
./logs    → /opt/airflow/logs      # Airflow writes logs here
./plugins → /opt/airflow/plugins   # Custom plugins
```

This means you edit DAGs in `./dags/` on your machine, and Airflow picks them up automatically.

### Step 3: Start Airflow

```bash
# Create required directories
mkdir -p dags logs plugins

# Initialize the database and create admin user
docker compose up airflow-init

# Start Airflow
docker compose up -d

# Check status
docker compose ps
```

Open http://localhost:8080. Login with `admin` / `admin`.

## Your First DAG

Create a file in the `dags/` directory:

```python
# dags/my_first_dag.py
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'data-engineer',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='my_first_pipeline',
    default_args=default_args,
    description='A simple ETL pipeline',
    schedule='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['example'],
) as dag:

    def extract(**kwargs):
        """Simulate extracting data."""
        import json
        data = [
            {'id': 1, 'name': 'Python', 'category': 'programming'},
            {'id': 2, 'name': 'SQL', 'category': 'query'},
            {'id': 3, 'name': 'Docker', 'category': 'devops'},
        ]
        # Push to XCom for downstream tasks
        kwargs['ti'].xcom_push(key='raw_data', value=json.dumps(data))
        print(f"Extracted {len(data)} records")

    def transform(**kwargs):
        """Transform the extracted data."""
        import json
        ti = kwargs['ti']
        raw = json.loads(ti.xcom_pull(key='raw_data', task_ids='extract'))
        
        # Add uppercase name
        for record in raw:
            record['name_upper'] = record['name'].upper()
        
        ti.xcom_push(key='transformed_data', value=json.dumps(raw))
        print(f"Transformed {len(raw)} records")

    def load(**kwargs):
        """Load data (simulate)."""
        import json
        ti = kwargs['ti']
        data = json.loads(ti.xcom_pull(key='transformed_data', task_ids='transform'))
        
        for record in data:
            print(f"Loading: {record}")
        print(f"Loaded {len(data)} records to warehouse")

    extract_task = PythonOperator(
        task_id='extract',
        python_callable=extract,
    )

    transform_task = PythonOperator(
        task_id='transform',
        python_callable=transform,
    )

    load_task = PythonOperator(
        task_id='load',
        python_callable=load,
    )

    # Define dependencies
    extract_task >> transform_task >> load_task
```

Save this file. Within ~30 seconds, it appears in the Airflow UI. Toggle it ON and trigger a run.

## DAG with Database Connection

A more practical example — connecting to a database from Airflow:

### Step 1: Add a Data Warehouse to Compose

```yaml
services:
  # ... (airflow services from above)

  warehouse:
    image: postgres:16
    environment:
      POSTGRES_DB: warehouse
      POSTGRES_PASSWORD: wh_pass
    volumes:
      - wh-data:/var/lib/postgresql/data
    ports:
      - "5433:5432"    # Different port to avoid conflict with Airflow's postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres-db-volume:
  wh-data:
```

### Step 2: Set Up the Connection in Airflow

You can do this via the UI (Admin → Connections) or via environment variable:

```yaml
# Add to airflow-common environment
environment:
  AIRFLOW_CONN_WAREHOUSE_DB: postgresql://postgres:wh_pass@warehouse:5432/warehouse
```

### Step 3: Use it in a DAG

```python
# dags/warehouse_pipeline.py
from datetime import datetime
from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.operators.python import PythonOperator

with DAG(
    dag_id='warehouse_pipeline',
    schedule='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
) as dag:

    create_table = PostgresOperator(
        task_id='create_table',
        postgres_conn_id='warehouse_db',
        sql="""
            CREATE TABLE IF NOT EXISTS daily_metrics (
                metric_date DATE PRIMARY KEY,
                total_jobs INTEGER,
                avg_salary NUMERIC,
                created_at TIMESTAMP DEFAULT NOW()
            );
        """,
    )

    def calculate_metrics(**kwargs):
        from airflow.hooks.postgres_hook import PostgresHook
        hook = PostgresHook(postgres_conn_id='warehouse_db')
        
        hook.run("""
            INSERT INTO daily_metrics (metric_date, total_jobs, avg_salary)
            VALUES (CURRENT_DATE, 1500, 95000)
            ON CONFLICT (metric_date) DO UPDATE
            SET total_jobs = EXCLUDED.total_jobs,
                avg_salary = EXCLUDED.avg_salary;
        """)
        print("Metrics loaded for today")

    load_metrics = PythonOperator(
        task_id='load_metrics',
        python_callable=calculate_metrics,
    )

    create_table >> load_metrics
```

## Installing Extra Python Packages

Your DAGs usually need packages that aren't in the base Airflow image. There are several ways to add them:

### Method 1: Custom Dockerfile (Recommended)

```dockerfile
# Dockerfile
FROM apache/airflow:2.8.0-python3.11

# Install system dependencies if needed
USER root
RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*
USER airflow

# Install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
```

```txt
# requirements.txt
pandas==2.1.4
sqlalchemy==2.0.23
requests==2.31.0
apache-airflow-providers-postgres==5.10.0
```

Update the compose file to build instead of pull:

```yaml
x-airflow-common: &airflow-common
  build:
    context: .
    dockerfile: Dockerfile
  # ... rest stays the same
```

```bash
docker compose up -d --build
```

### Method 2: _PIP_ADDITIONAL_REQUIREMENTS (Quick and Dirty)

```yaml
environment:
  _PIP_ADDITIONAL_REQUIREMENTS: 'pandas==2.1.4 requests==2.31.0'
```

This installs packages on every container start. Slow, unreliable, but works for quick testing.

## Airflow Architecture in Docker

```
┌─────────────────────────────────────────────────────┐
│                  Docker Network                      │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐                 │
│  │  Webserver   │  │  Scheduler   │                 │
│  │  (port 8080) │  │              │                 │
│  │              │  │  Triggers    │                 │
│  │  UI + API    │  │  DAG runs    │                 │
│  └──────┬───────┘  └──────┬───────┘                 │
│         │                 │                          │
│         └────────┬────────┘                          │
│                  │                                   │
│         ┌────────▼────────┐                          │
│         │   Metadata DB   │    ┌─────────────────┐  │
│         │   (PostgreSQL)  │    │   Data Warehouse │  │
│         │                 │    │   (PostgreSQL)   │  │
│         └─────────────────┘    └─────────────────┘  │
│                                                      │
│  Volumes:                                            │
│    ./dags  → DAG files (your pipeline code)          │
│    ./logs  → Airflow logs                            │
└─────────────────────────────────────────────────────┘
```

## Common DAG Patterns for Data Engineering

### Pattern 1: ELT Pipeline

```python
with DAG('elt_pipeline', schedule='@daily', ...) as dag:

    extract = PythonOperator(task_id='extract', python_callable=extract_func)
    load_raw = PythonOperator(task_id='load_raw', python_callable=load_raw_func)
    transform = PostgresOperator(
        task_id='transform',
        sql='sql/transform.sql',   # SQL file in dags/sql/ directory
    )
    test = PythonOperator(task_id='data_quality', python_callable=run_tests)

    extract >> load_raw >> transform >> test
```

### Pattern 2: Parallel Extraction

```python
with DAG('parallel_extract', schedule='@hourly', ...) as dag:

    start = EmptyOperator(task_id='start')

    extract_users = PythonOperator(task_id='extract_users', ...)
    extract_orders = PythonOperator(task_id='extract_orders', ...)
    extract_products = PythonOperator(task_id='extract_products', ...)

    merge = PythonOperator(task_id='merge_data', ...)
    load = PythonOperator(task_id='load_warehouse', ...)

    start >> [extract_users, extract_orders, extract_products] >> merge >> load
```

Three extractions run in parallel, then merge, then load.

### Pattern 3: Conditional Branching

```python
from airflow.operators.python import BranchPythonOperator

def choose_path(**kwargs):
    """Decide which path based on data size."""
    row_count = kwargs['ti'].xcom_pull(key='row_count')
    if row_count > 10000:
        return 'full_load'
    return 'incremental_load'

with DAG('branching_pipeline', ...) as dag:
    extract = PythonOperator(task_id='extract', ...)
    check = BranchPythonOperator(task_id='check_size', python_callable=choose_path)
    full = PythonOperator(task_id='full_load', ...)
    incremental = PythonOperator(task_id='incremental_load', ...)

    extract >> check >> [full, incremental]
```

### Pattern 4: Sensor (Wait for Condition)

```python
from airflow.sensors.filesystem import FileSensor

with DAG('file_triggered', ...) as dag:

    wait_for_file = FileSensor(
        task_id='wait_for_csv',
        filepath='/opt/airflow/data/daily_export.csv',
        poke_interval=60,        # Check every 60 seconds
        timeout=3600,            # Give up after 1 hour
        mode='poke',
    )

    process = PythonOperator(task_id='process_file', ...)

    wait_for_file >> process
```

## Useful Airflow CLI Commands (in Docker)

```bash
# List DAGs
docker compose exec airflow-scheduler airflow dags list

# Trigger a DAG manually
docker compose exec airflow-scheduler airflow dags trigger my_first_pipeline

# Check task status
docker compose exec airflow-scheduler airflow tasks states-for-dag-run my_first_pipeline <run_id>

# Test a specific task (without recording in metadata)
docker compose exec airflow-scheduler airflow tasks test my_first_pipeline extract 2024-01-01

# View logs for a task
docker compose logs airflow-scheduler | grep "extract"

# Open a shell in the scheduler container
docker compose exec airflow-scheduler bash
```

## Troubleshooting

### DAG not showing up in the UI

```bash
# Check for syntax errors
docker compose exec airflow-scheduler python /opt/airflow/dags/my_dag.py

# Check scheduler logs
docker compose logs airflow-scheduler | tail -50

# List what Airflow sees
docker compose exec airflow-scheduler airflow dags list
```

Common causes:
- Python syntax error in the DAG file
- Missing imports (package not installed)
- File is in wrong directory
- DAG isn't inside a `with DAG(...) as dag:` block

### Task fails with ModuleNotFoundError

The package isn't installed in the Airflow image. Use the custom Dockerfile approach (Method 1 above).

### Webserver won't start

```bash
# Check if the port is in use
lsof -i :8080

# Check logs
docker compose logs airflow-webserver
```

### Database connection errors

Make sure:
- The warehouse container is on the same Docker network (it is, if in the same compose file)
- The connection ID matches (`postgres_conn_id='warehouse_db'`)
- The connection is configured (via UI or environment variable)

## Stopping Airflow

```bash
# Stop all services (data preserved in volumes)
docker compose down

# Stop and remove everything including data
docker compose down -v

# Remove all Airflow-related images
docker rmi $(docker images | grep airflow | awk '{print $3}')
```

---

## Practice Problems

### Beginner

1. Set up Airflow using the simplified docker-compose.yml from this lesson. Log into the web UI at localhost:8080. Explore the interface — find where DAGs, connections, and variables are configured.

2. Create a simple DAG with three `BashOperator` tasks that run `echo` commands. Set up dependencies so they run sequentially. Trigger it manually and check the logs for each task.

3. Create a DAG with a `PythonOperator` that prints all environment variables available to it. This helps you understand what context Airflow provides to tasks.

### Intermediate

4. Build an ETL DAG that:
   - Extracts: reads a CSV file from `/opt/airflow/dags/data/`
   - Transforms: cleans the data with Python
   - Loads: inserts into a PostgreSQL warehouse (add warehouse service to compose)
   - Uses XCom to pass data between tasks
   - Has proper error handling and retries

5. Create a DAG with parallel tasks:
   - 3 extract tasks that run simultaneously
   - A merge task that waits for all 3 to complete
   - A load task that runs after merge
   - Visualize the DAG in the Airflow UI

6. Add custom Python packages to Airflow:
   - Create a Dockerfile extending the Airflow image
   - Install pandas, requests, and sqlalchemy
   - Update the compose file to build your custom image
   - Create a DAG that uses these packages

### Advanced

7. Build a production-like Airflow setup:
   - Custom Airflow image with your packages
   - PostgreSQL as both metadata DB and data warehouse
   - DAG that runs daily, extracts from an API (use a free public API), loads to warehouse
   - Email alerting on failure (configure SMTP in Airflow)
   - Connection credentials managed via environment variables

8. Create a DAG with branching:
   - Extract data from a source
   - Branch based on data quality (if < 95% complete, go to alert path; if >= 95%, go to load path)
   - Alert path sends a notification and skips loading
   - Load path loads to warehouse and creates a summary report
   - Both paths join at a final cleanup task

9. Set up Airflow with CeleryExecutor:
   - Use the full official docker-compose.yaml
   - Add Redis as message broker
   - Add 2 worker containers
   - Create a DAG with many parallel tasks and observe them distributed across workers
   - Compare execution time vs LocalExecutor

---

**Up next:** [CI/CD and Container Registry](13_CI_CD_And_Registry.md) — automate your image builds and deployments.

## Resources

- [Airflow Docker Quick Start](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html) — Official Docker setup guide
- [Airflow Documentation](https://airflow.apache.org/docs/) — Complete Airflow docs
- [Airflow Best Practices](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html) — Writing good DAGs
- [Airflow Providers](https://airflow.apache.org/docs/apache-airflow-providers/) — Integrations (PostgreSQL, AWS, GCP, etc.)
- [Astronomer Learning](https://www.astronomer.io/docs/learn/) — Excellent Airflow tutorials
