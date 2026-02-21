# Data Engineering Pipelines in Docker

This is where the course shifts. Up to now, we've been learning Docker features — containers, images, volumes, networks, compose. Now we put all of that together to build real data engineering pipelines.

By the end of this lesson, you'll be able to containerize any Python-based data pipeline and run it with a single command.

## Why Containerize Pipelines?

Think about what happens without Docker:

```
You: "Here's the ETL script, just run `python pipeline.py`"
Teammate: "I get an ImportError for pandas"
You: "Install it with pip"
Teammate: "Now I get a psycopg2 error about libpq"
You: "Oh you need to install PostgreSQL client libraries"
Teammate: "Which version?"
You: "Whatever I have... let me check"
(45 minutes later, still debugging dependencies)
```

With Docker:

```
You: "Here's the pipeline. Run `docker compose up`"
Teammate: "Done. It's running."
```

Same environment, every time, on every machine. That's the pitch, and it actually delivers.

## Project Structure

Here's how a well-organized containerized pipeline looks:

```
my-pipeline/
├── docker-compose.yml       # Orchestration
├── Dockerfile               # Build instructions
├── .env                     # Secrets (gitignored)
├── .env.example             # Template for secrets
├── .dockerignore            # Exclude unnecessary files
├── requirements.txt         # Python dependencies
├── src/
│   ├── __init__.py
│   ├── extract.py           # Extract from source
│   ├── transform.py         # Transform data
│   ├── load.py              # Load to target
│   └── pipeline.py          # Main entry point
├── config/
│   └── pipeline_config.yml  # Pipeline configuration
├── data/
│   ├── raw/                 # Raw input data
│   └── processed/           # Output data
├── logs/                    # Log files
└── tests/
    └── test_pipeline.py
```

## Building a Complete ELT Pipeline

Let's build a pipeline that:
1. Extracts data from a CSV file
2. Transforms it (clean, aggregate)
3. Loads it into PostgreSQL

### Step 1: The Python Code

```python
# src/extract.py
import pandas as pd
import logging

logger = logging.getLogger(__name__)

def extract_csv(filepath):
    """Extract data from a CSV file."""
    logger.info(f"Extracting data from {filepath}")
    df = pd.read_csv(filepath)
    logger.info(f"Extracted {len(df)} rows")
    return df

def extract_from_db(connection_string, query):
    """Extract data from a database."""
    logger.info(f"Running query: {query[:100]}...")
    df = pd.read_sql(query, connection_string)
    logger.info(f"Extracted {len(df)} rows from database")
    return df
```

```python
# src/transform.py
import pandas as pd
import logging

logger = logging.getLogger(__name__)

def clean_data(df):
    """Clean the raw data."""
    initial_rows = len(df)

    # Drop duplicates
    df = df.drop_duplicates()

    # Drop rows with all nulls
    df = df.dropna(how='all')

    # Standardize column names
    df.columns = [col.strip().lower().replace(' ', '_') for col in df.columns]

    logger.info(f"Cleaned data: {initial_rows} -> {len(df)} rows")
    return df

def aggregate_data(df, group_col, agg_col):
    """Aggregate data by a column."""
    result = df.groupby(group_col)[agg_col].agg(['count', 'mean', 'sum']).reset_index()
    result.columns = [group_col, f'{agg_col}_count', f'{agg_col}_avg', f'{agg_col}_total']
    logger.info(f"Aggregated to {len(result)} groups")
    return result
```

```python
# src/load.py
import pandas as pd
from sqlalchemy import create_engine
import logging

logger = logging.getLogger(__name__)

def load_to_postgres(df, table_name, connection_string, if_exists='replace'):
    """Load dataframe to PostgreSQL."""
    engine = create_engine(connection_string)
    logger.info(f"Loading {len(df)} rows to {table_name}...")

    df.to_sql(table_name, engine, if_exists=if_exists, index=False)
    logger.info(f"Successfully loaded to {table_name}")

def load_to_csv(df, filepath):
    """Load dataframe to CSV."""
    df.to_csv(filepath, index=False)
    logger.info(f"Saved {len(df)} rows to {filepath}")
```

```python
# src/pipeline.py
import os
import sys
import logging
from datetime import datetime
from extract import extract_csv
from transform import clean_data, aggregate_data
from load import load_to_postgres, load_to_csv

# Configure logging
logging.basicConfig(
    level=os.getenv('LOG_LEVEL', 'INFO'),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(f'/app/logs/pipeline_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    ]
)
logger = logging.getLogger(__name__)

def main():
    logger.info("=" * 50)
    logger.info("Starting ETL Pipeline")
    logger.info("=" * 50)

    # Validate required environment variables
    required = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME']
    missing = [v for v in required if v not in os.environ]
    if missing:
        logger.error(f"Missing environment variables: {missing}")
        sys.exit(1)

    # Build connection string
    db_url = (
        f"postgresql://{os.environ['DB_USER']}:{os.environ['DB_PASSWORD']}"
        f"@{os.environ['DB_HOST']}:{os.getenv('DB_PORT', '5432')}"
        f"/{os.environ['DB_NAME']}"
    )

    try:
        # Extract
        df = extract_csv('/app/data/raw/input.csv')

        # Transform
        df_clean = clean_data(df)

        # Load
        load_to_postgres(df_clean, 'cleaned_data', db_url)
        load_to_csv(df_clean, '/app/data/processed/cleaned_output.csv')

        logger.info("Pipeline completed successfully!")

    except Exception as e:
        logger.error(f"Pipeline failed: {e}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### Step 2: The Dockerfile

```dockerfile
FROM python:3.11-slim

# System dependencies for psycopg2
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/

# Create directories for data and logs
RUN mkdir -p /app/data/raw /app/data/processed /app/logs

WORKDIR /app/src

CMD ["python", "pipeline.py"]
```

```txt
# requirements.txt
pandas==2.1.4
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
```

### Step 3: Docker Compose

```yaml
# docker-compose.yml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - pg-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5

  etl:
    build: .
    environment:
      DB_HOST: db
      DB_PORT: "5432"
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
      LOG_LEVEL: ${LOG_LEVEL:-INFO}
    volumes:
      - ./data:/app/data          # Input/output data
      - ./logs:/app/logs          # Persist logs
      - ./src:/app/src            # Live code (dev only)
    depends_on:
      db:
        condition: service_healthy

volumes:
  pg-data:
```

```env
# .env
DB_USER=pipeline
DB_PASSWORD=pipeline_secret_123
DB_NAME=warehouse
LOG_LEVEL=DEBUG
```

### Step 4: Run It

```bash
# Place your input CSV
mkdir -p data/raw
echo "name,age,city,salary
Alice,30,New York,85000
Bob,25,San Francisco,92000
Charlie,35,New York,110000
Diana,28,Los Angeles,78000
Bob,25,San Francisco,92000" > data/raw/input.csv

# Start everything
docker compose up --build

# Check the output
cat data/processed/cleaned_output.csv
cat logs/pipeline_*.log
```

One command. Database starts, waits for health check, ETL runs, data gets loaded, logs get saved to your machine. Done.

## Database-to-Database ETL

A more realistic pattern — extracting from one database and loading to another:

```yaml
# docker-compose.yml
services:
  source-db:
    image: postgres:16
    environment:
      POSTGRES_DB: production
      POSTGRES_PASSWORD: source_pass
    volumes:
      - ./init/seed_data.sql:/docker-entrypoint-initdb.d/01-seed.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  target-db:
    image: postgres:16
    environment:
      POSTGRES_DB: warehouse
      POSTGRES_PASSWORD: target_pass
    ports:
      - "5432:5432"
    volumes:
      - wh-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  etl:
    build: .
    environment:
      SOURCE_DB_URL: postgresql://postgres:source_pass@source-db:5432/production
      TARGET_DB_URL: postgresql://postgres:target_pass@target-db:5432/warehouse
    depends_on:
      source-db:
        condition: service_healthy
      target-db:
        condition: service_healthy

volumes:
  wh-data:
```

The ETL script:

```python
# src/db_pipeline.py
import os
import pandas as pd
from sqlalchemy import create_engine

source_engine = create_engine(os.environ['SOURCE_DB_URL'])
target_engine = create_engine(os.environ['TARGET_DB_URL'])

# Extract
df = pd.read_sql("SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '1 day'", source_engine)

# Transform
df['total_with_tax'] = df['total'] * 1.08
df['loaded_at'] = pd.Timestamp.now()

# Load
df.to_sql('orders_fact', target_engine, if_exists='append', index=False)
print(f"Loaded {len(df)} rows to warehouse")
```

## Scheduled Pipelines with Cron

You can run pipelines on a schedule using cron inside Docker:

### Option 1: Container with Cron

```dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y cron && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ./src/

# Create cron job — run pipeline every hour
RUN echo "0 * * * * cd /app/src && python pipeline.py >> /app/logs/cron.log 2>&1" > /etc/cron.d/pipeline
RUN chmod 0644 /etc/cron.d/pipeline
RUN crontab /etc/cron.d/pipeline

# Create log directory
RUN mkdir -p /app/logs

CMD ["cron", "-f"]
```

### Option 2: Use Docker's Restart + Sleep (Simple)

```bash
# One-shot container that runs, sleeps, repeats
docker run -d --restart always my-etl \
    sh -c "while true; do python pipeline.py; sleep 3600; done"
```

### Option 3: Host Crontab (Simplest)

On your host machine:

```bash
crontab -e
# Add:
0 * * * * cd /path/to/project && docker compose run --rm etl
```

This is the simplest approach — let the host handle scheduling, Docker handles the environment.

For anything more complex than basic cron, use Airflow (covered in Lesson 12).

## Pipeline Patterns

### Pattern 1: One-Shot Pipeline

Runs, processes data, exits. Like a batch job.

```yaml
services:
  etl:
    build: .
    command: python pipeline.py
    # Container exits when pipeline finishes
```

```bash
docker compose run --rm etl  # Run once, remove container when done
```

### Pattern 2: Long-Running Worker

Continuously processes data (like a streaming consumer).

```yaml
services:
  worker:
    build: .
    command: python worker.py
    restart: unless-stopped  # Restart on crash
    deploy:
      resources:
        limits:
          memory: 2G
```

### Pattern 3: Multi-Step Pipeline

Different containers for different steps:

```yaml
services:
  extract:
    build: .
    command: python extract.py
    volumes:
      - pipeline-data:/app/data

  transform:
    build: .
    command: python transform.py
    depends_on:
      extract:
        condition: service_completed_successfully
    volumes:
      - pipeline-data:/app/data

  load:
    build: .
    command: python load.py
    depends_on:
      transform:
        condition: service_completed_successfully
    volumes:
      - pipeline-data:/app/data

volumes:
  pipeline-data:
```

`service_completed_successfully` makes each step wait for the previous one to finish successfully before starting.

### Pattern 4: Parallel Processing

```yaml
services:
  etl:
    build: .
    deploy:
      replicas: 3  # Run 3 instances
    environment:
      WORKER_ID: "{{.Task.Slot}}"
```

## Error Handling and Retry

### In Your Pipeline Code

```python
import time
import logging
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError

logger = logging.getLogger(__name__)

def connect_with_retry(db_url, max_retries=5, delay=5):
    """Connect to database with exponential backoff."""
    for attempt in range(1, max_retries + 1):
        try:
            engine = create_engine(db_url)
            # Test the connection
            with engine.connect() as conn:
                conn.execute("SELECT 1")
            logger.info(f"Connected to database on attempt {attempt}")
            return engine
        except OperationalError as e:
            if attempt < max_retries:
                wait = delay * (2 ** (attempt - 1))  # Exponential backoff
                logger.warning(f"Connection failed (attempt {attempt}/{max_retries}). Retrying in {wait}s...")
                time.sleep(wait)
            else:
                logger.error(f"Failed to connect after {max_retries} attempts")
                raise
```

### In Compose

```yaml
services:
  etl:
    build: .
    restart: on-failure     # Restart if exit code is non-zero
    deploy:
      restart_policy:
        condition: on-failure
        max_attempts: 3
        delay: 10s
```

## Monitoring Your Pipeline

### Logs

```bash
# Follow logs from all services
docker compose logs -f

# Last 100 lines from ETL service
docker compose logs --tail 100 etl

# Follow specific service
docker compose logs -f etl
```

### Health Status

```bash
# See service health
docker compose ps

# Detailed info
docker inspect --format='{{.State.Health.Status}}' container_name
```

### Resource Usage

```bash
# CPU and memory for all containers
docker stats

# For compose services specifically
docker compose top
```

## Development Workflow

Here's the workflow I use for developing pipelines:

```bash
# 1. Start infrastructure (database, redis, etc.)
docker compose up -d db redis

# 2. Develop and test locally (with bind mount)
docker compose run --rm -v $(pwd)/src:/app/src etl python pipeline.py

# 3. Fix issues, re-run (no rebuild needed thanks to bind mount)
docker compose run --rm -v $(pwd)/src:/app/src etl python pipeline.py

# 4. Happy with the code? Build and run properly
docker compose up --build etl

# 5. Clean up
docker compose down
```

The bind mount in step 2-3 means you edit code in VS Code and immediately run it in the container — no rebuilding the Docker image every time you change a line. This is huge for productivity.

---

## Practice Problems

### Beginner

1. Create a simple Python script that reads a CSV file and prints a summary (row count, column names, first 5 rows). Containerize it with a Dockerfile and run it with `docker run`, using a bind mount to provide the CSV file.

2. Add PostgreSQL to the setup using Docker Compose. Have your Python container connect to PostgreSQL and create a table. Use health checks so the Python container waits for PostgreSQL.

3. Modify the pipeline to read configuration from environment variables. Pass `INPUT_FILE` and `OUTPUT_TABLE` as environment variables and verify they work.

### Intermediate

4. Build the complete ELT pipeline from this lesson:
   - PostgreSQL source and target databases
   - Python ETL container
   - Seed data in the source database (use `/docker-entrypoint-initdb.d/`)
   - Health checks on both databases
   - Output logs to your host machine via bind mount

5. Add error handling with retry logic to the pipeline. Make the database connection use exponential backoff. Test it by starting the ETL container before the database is ready (remove `depends_on`).

6. Create a development workflow:
   - `docker compose up -d db` (start only the database)
   - Run the ETL with bind-mounted source code so you can edit and re-run without rebuilding
   - Add a `make` or shell script to simplify the commands

### Advanced

7. Build a multi-step pipeline using `service_completed_successfully`:
   - Step 1: Extract data from an API (mock it with a JSON file)
   - Step 2: Transform (runs only after step 1 succeeds)
   - Step 3: Load to PostgreSQL (runs only after step 2 succeeds)
   - Shared data between steps via a named volume
   - If step 1 fails, steps 2 and 3 should not run

8. Create a pipeline that processes multiple files in parallel:
   - A "dispatcher" container lists files in `/app/data/raw/`
   - Multiple "worker" containers process files
   - A "collector" container combines results
   - Use Docker Compose to orchestrate all of this

9. Implement a monitoring setup:
   - Pipeline writes metrics (rows processed, duration, errors) to a log file
   - Add a health check endpoint to a long-running pipeline
   - Create a simple dashboard (even a script that parses logs) to track pipeline runs

---

**Up next:** [Databases in Docker](11_Databases_In_Docker.md) — PostgreSQL, DuckDB, and data persistence patterns that every DE needs.

## Resources

- [Docker Compose Watch](https://docs.docker.com/compose/how-tos/file-watch/) — Automatic code sync for development
- [Compose File Reference](https://docs.docker.com/reference/compose-file/) — All compose options
- [Docker SDK for Python](https://docker-py.readthedocs.io/) — Programmatically control Docker from Python
- [Best Practices for Containerized Pipelines](https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/) — Dockerfile best practices
