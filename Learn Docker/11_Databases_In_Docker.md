# Databases in Docker

Running databases in Docker is probably the single most useful thing Docker does for data engineers. Before Docker, setting up a local PostgreSQL instance, configuring it, loading test data — that was a chore. With Docker, it's one command.

## PostgreSQL — The Workhorse

PostgreSQL is the most common database you'll encounter in data engineering. Here's how to run it properly in Docker.

### Basic Setup

```bash
docker run -d \
    --name postgres \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_USER=dataengineer \
    -e POSTGRES_DB=warehouse \
    -p 5432:5432 \
    -v pg-data:/var/lib/postgresql/data \
    postgres:16
```

That's a fully running PostgreSQL 16 instance. Connect from your machine:

```bash
psql -h localhost -U dataengineer -d warehouse
# or from DBeaver, pgAdmin, any SQL client
```

### Environment Variables for PostgreSQL Image

| Variable | What It Does | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | Superuser password (required) | — |
| `POSTGRES_USER` | Superuser name | `postgres` |
| `POSTGRES_DB` | Default database | Same as `POSTGRES_USER` |
| `PGDATA` | Data directory inside container | `/var/lib/postgresql/data` |

### Initializing with SQL Scripts

The PostgreSQL image has a special feature: any `.sql` or `.sh` files in `/docker-entrypoint-initdb.d/` run automatically when the container starts for the first time (when the data directory is empty).

```bash
# init/01-schema.sql
CREATE TABLE IF NOT EXISTS dim_skills (
    skill_id SERIAL PRIMARY KEY,
    skill_name VARCHAR(100) NOT NULL,
    category VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS fact_job_postings (
    posting_id SERIAL PRIMARY KEY,
    title VARCHAR(200),
    company VARCHAR(200),
    salary_min INTEGER,
    salary_max INTEGER,
    posted_date DATE
);
```

```bash
# init/02-seed-data.sql
INSERT INTO dim_skills (skill_name, category) VALUES
    ('Python', 'Programming'),
    ('SQL', 'Query Language'),
    ('Docker', 'DevOps'),
    ('Airflow', 'Orchestration'),
    ('Spark', 'Processing');
```

Mount the directory:

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: warehouse
    volumes:
      - pg-data:/var/lib/postgresql/data
      - ./init:/docker-entrypoint-initdb.d    # Auto-run SQL files
    ports:
      - "5432:5432"

volumes:
  pg-data:
```

Files run in alphabetical order — that's why I prefix with numbers (`01-`, `02-`). Schema first, then seed data.

**Important:** Init scripts only run on FIRST startup (when the volume is empty). If you change the scripts, you need to remove the volume first:

```bash
docker compose down -v    # Remove volumes
docker compose up -d      # Fresh start, runs init scripts again
```

### PostgreSQL Configuration Tuning

For development, the defaults are fine. But if you're testing with larger datasets:

```yaml
services:
  db:
    image: postgres:16
    command: >
      postgres
      -c shared_buffers=512MB
      -c work_mem=64MB
      -c maintenance_work_mem=256MB
      -c effective_cache_size=1GB
      -c max_connections=200
    environment:
      POSTGRES_PASSWORD: secret
    deploy:
      resources:
        limits:
          memory: 2G
```

Or mount a custom config file:

```yaml
volumes:
  - ./postgresql.conf:/etc/postgresql/postgresql.conf
command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

### Backups

```bash
# Backup to SQL dump
docker exec postgres pg_dump -U dataengineer warehouse > backup.sql

# Backup to compressed format
docker exec postgres pg_dump -U dataengineer -Fc warehouse > backup.dump

# Restore from SQL dump
cat backup.sql | docker exec -i postgres psql -U dataengineer -d warehouse

# Restore from compressed format
docker exec -i postgres pg_restore -U dataengineer -d warehouse < backup.dump
```

Automate backups with a cron job or a sidecar container:

```yaml
services:
  db:
    image: postgres:16
    # ...

  backup:
    image: postgres:16
    volumes:
      - ./backups:/backups
    entrypoint: /bin/sh -c
    command: |
      "while true; do
        PGPASSWORD=secret pg_dump -h db -U postgres warehouse > /backups/warehouse_$$(date +%Y%m%d_%H%M%S).sql
        echo 'Backup completed'
        sleep 86400
      done"
    depends_on:
      - db
```

## DuckDB — Analytics in a Container

DuckDB is an in-process analytical database. It doesn't run as a server — it runs embedded in your application. But Docker is still useful for creating consistent environments.

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN pip install duckdb pandas

COPY scripts/ ./scripts/
COPY data/ ./data/

CMD ["python", "scripts/analyze.py"]
```

```python
# scripts/analyze.py
import duckdb

# DuckDB works with local files — no server needed
conn = duckdb.connect('/app/data/analytics.duckdb')

# Create and query
conn.execute("""
    CREATE TABLE IF NOT EXISTS sales AS
    SELECT * FROM read_csv_auto('/app/data/sales.csv')
""")

result = conn.execute("""
    SELECT product, SUM(amount) as total
    FROM sales
    GROUP BY product
    ORDER BY total DESC
    LIMIT 10
""").fetchdf()

print(result)
```

### DuckDB with MotherDuck

```python
import duckdb

# Connect to MotherDuck (cloud DuckDB)
conn = duckdb.connect('md:my_database')

# Or attach a shared database
conn.execute("ATTACH 'md:_share/data_jobs/87603155-cdc7-4c80-85ad-3a6b0d760d93' AS data_jobs")
```

For MotherDuck in Docker, you need to pass the token:

```yaml
services:
  analytics:
    build: .
    environment:
      MOTHERDUCK_TOKEN: ${MOTHERDUCK_TOKEN}
    volumes:
      - ./data:/app/data
```

## MySQL

```yaml
services:
  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: app_db
      MYSQL_USER: dataengineer
      MYSQL_PASSWORD: de_password
    volumes:
      - mysql-data:/var/lib/mysql
      - ./init:/docker-entrypoint-initdb.d   # Same init script pattern as PostgreSQL
    ports:
      - "3306:3306"

volumes:
  mysql-data:
```

## Redis — Caching and Queues

Redis is commonly used alongside data pipelines for caching, job queues, and rate limiting.

```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes  # Persist data to disk

volumes:
  redis-data:
```

```python
import redis

r = redis.Redis(host='redis', port=6379)

# Cache expensive query results
cache_key = "top_skills_2024"
cached = r.get(cache_key)

if cached:
    result = json.loads(cached)
else:
    result = run_expensive_query()
    r.setex(cache_key, 3600, json.dumps(result))  # Cache for 1 hour
```

## MongoDB — Document Store

For semi-structured or nested data:

```yaml
services:
  mongo:
    image: mongo:7
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: secret
    volumes:
      - mongo-data:/data/db
    ports:
      - "27017:27017"

volumes:
  mongo-data:
```

## Complete Data Stack

Here's a realistic multi-database development environment:

```yaml
# docker-compose.yml — Full data engineering dev stack
services:
  # OLTP source (simulates production app database)
  source-postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: production
      POSTGRES_PASSWORD: ${SOURCE_DB_PASS}
    volumes:
      - source-pg:/var/lib/postgresql/data
      - ./init/source:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Data warehouse
  warehouse:
    image: postgres:16
    environment:
      POSTGRES_DB: warehouse
      POSTGRES_PASSWORD: ${WH_DB_PASS}
    volumes:
      - warehouse-pg:/var/lib/postgresql/data
      - ./init/warehouse:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"    # Expose for DBeaver/pgAdmin
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Redis for caching
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data

  # pgAdmin for visual DB management
  pgadmin:
    image: dpage/pgadmin4
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@admin.com
      PGADMIN_DEFAULT_PASSWORD: admin
    ports:
      - "8080:80"
    profiles: ["ui"]    # Only start when explicitly requested

volumes:
  source-pg:
  warehouse-pg:
  redis-data:
```

```bash
# Start core services
docker compose up -d

# Need pgAdmin? Include the UI profile
docker compose --profile ui up -d

# Connect DBeaver to warehouse at localhost:5432
```

## Data Persistence Patterns

### Pattern 1: Named Volume (Standard)

```yaml
volumes:
  - pg-data:/var/lib/postgresql/data
```

Best for: Production databases, warehouses, any data that must survive container restarts.

### Pattern 2: Bind Mount for Init Scripts

```yaml
volumes:
  - ./init:/docker-entrypoint-initdb.d:ro
```

Best for: Loading schemas and seed data on first startup.

### Pattern 3: Ephemeral (No Volume)

```yaml
services:
  test-db:
    image: postgres:16
    # No volume — data dies with the container
```

Best for: Integration tests. Start fresh every time, seed test data, run tests, destroy.

### Pattern 4: Backup Volume

```yaml
services:
  db:
    volumes:
      - pg-data:/var/lib/postgresql/data
  
  backup:
    volumes:
      - pg-data:/source:ro        # Read-only access to DB data
      - ./backups:/backups        # Output to host
```

Best for: Automated backups without stopping the database.

## Performance Considerations

### Memory Limits

```yaml
services:
  db:
    image: postgres:16
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: "2.0"
        reservations:
          memory: 1G
          cpus: "1.0"
```

Set limits to prevent a runaway query from eating all your machine's memory.

### Connection Pooling

If your pipeline opens many connections:

```yaml
services:
  pgbouncer:
    image: edoburu/pgbouncer
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/warehouse
      POOL_MODE: transaction
      MAX_DB_CONNECTIONS: 50
    ports:
      - "6432:6432"
    depends_on:
      - db
```

Your pipeline connects to PgBouncer on port 6432 instead of directly to PostgreSQL. PgBouncer pools connections efficiently.

## Troubleshooting

### Container exits immediately

```bash
docker logs postgres  # Check what went wrong
```

Common causes:
- Wrong `POSTGRES_PASSWORD` format
- Volume has data from a different PostgreSQL version
- Port already in use

### Can't connect from host

```bash
# Verify port mapping
docker ps  # Check the PORTS column

# Verify PostgreSQL is ready
docker exec postgres pg_isready
```

### Data doesn't survive restart

```bash
# Make sure you have a named volume
docker volume ls  # Is your volume listed?
docker inspect postgres | grep -A 5 "Mounts"
```

### Init scripts don't run

Remember: init scripts only run when the data volume is empty. To re-run:

```bash
docker compose down -v  # Remove the volume
docker compose up -d    # Start fresh
```

---

## Practice Problems

### Beginner

1. Run a PostgreSQL container with a named volume. Create a table and insert data. Remove the container. Start a new container with the same volume. Verify your data is still there.

2. Create an init SQL script that creates a `users` table and inserts 5 rows. Mount it into `/docker-entrypoint-initdb.d/` and verify it runs on first startup.

3. Run both PostgreSQL and Redis with Docker Compose. Connect to each and verify they're working.

### Intermediate

4. Set up a PostgreSQL container and connect to it from a Python container on the same Docker network. Write a Python script that creates a table, inserts data, and queries it.

5. Build a two-database setup:
   - Source database with sample data (auto-loaded via init scripts)
   - Target database (empty warehouse)
   - Python container that reads from source and writes to target
   - Proper health checks and `depends_on`

6. Set up automated backups: a sidecar container that dumps the database to a bind-mounted directory every hour. Include timestamps in the backup filenames.

### Advanced

7. Create a complete data stack:
   - PostgreSQL (warehouse)
   - Redis (caching)
   - pgAdmin (UI)
   - Python ETL container
   - Use compose profiles so pgAdmin only starts when you want it
   - All with proper volumes, health checks, and `.env` for credentials

8. Test data persistence thoroughly:
   - Create a PostgreSQL container with a named volume
   - Load 100K+ rows of data
   - Simulate a crash (`docker kill`)
   - Restart and verify data integrity
   - Upgrade PostgreSQL from 15 to 16 with the same data volume (does it work? what breaks?)

9. Set up connection pooling with PgBouncer between your Python pipeline and PostgreSQL. Write a script that opens 100 concurrent connections and measure the difference with and without PgBouncer.

---

**Up next:** [Airflow with Docker](12_Airflow_With_Docker.md) — the industry-standard orchestration tool, running entirely in Docker.

## Resources

- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres) — Official image docs
- [MySQL Docker Image](https://hub.docker.com/_/mysql) — MySQL-specific setup
- [Redis Docker Image](https://hub.docker.com/_/redis) — Redis configuration options
- [DuckDB Documentation](https://duckdb.org/docs/) — DuckDB usage guide
- [PgBouncer](https://www.pgbouncer.org/) — Connection pooling for PostgreSQL
