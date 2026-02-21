# Environment Variables and Secrets

Hardcoding passwords, API keys, and connection strings directly in your Dockerfiles and compose files is one of those things everyone does when learning. Then they accidentally push database credentials to a public GitHub repo and learn the hard way why you shouldn't.

This lesson covers the right ways to handle configuration and sensitive data in Docker.

## Configuration Hierarchy

There's a clear hierarchy of how configuration should work in Docker:

```
Most Flexible (Runtime)
  │
  ├── Environment variables (-e / --env)
  ├── .env files (env_file)
  ├── Docker secrets (swarm / compose secrets)
  ├── Config files (bind mounted)
  │
  └── Baked into image (ENV in Dockerfile)
         ↑
Most Rigid (Build Time)
```

The rule: **configuration that changes between environments should NOT be baked into the image**. DB credentials for dev and prod are different, so they should be injected at runtime.

## ENV in Dockerfile — Build-Time Defaults

`ENV` in a Dockerfile sets default values that exist in every container created from that image:

```dockerfile
FROM python:3.11-slim

# These are defaults — can be overridden at runtime
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=INFO
ENV APP_PORT=8000
```

Use `ENV` for:
- Python settings (`PYTHONDONTWRITEBYTECODE`, `PYTHONUNBUFFERED`)
- Application defaults (log level, port numbers)
- Non-sensitive configuration

Do NOT use `ENV` for:
- Passwords
- API keys
- Database connection strings
- Anything that differs between dev/staging/prod

## ARG — Build-Time Only Variables

`ARG` exists only during the build. It doesn't persist into the running container.

```dockerfile
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim

ARG APP_VERSION=1.0.0
LABEL version=${APP_VERSION}

# This will NOT be available when the container runs
# ARG values disappear after build
```

```bash
# Override at build time
docker build --build-arg PYTHON_VERSION=3.12 --build-arg APP_VERSION=2.0.0 -t my-app .
```

**Common trap:** people try to use `ARG` for passwords during pip install (like private repos). The arg value ends up in the image layer history. Anyone who can pull the image can see it with `docker history`. Use multi-stage builds instead — more on that in Lesson 14.

## Environment Variables at Runtime

### With docker run

```bash
# Single variable
docker run -e DATABASE_URL=postgresql://user:pass@db:5432/mydb my-app

# Multiple variables
docker run \
    -e DATABASE_URL=postgresql://user:pass@db:5432/mydb \
    -e REDIS_URL=redis://redis:6379 \
    -e LOG_LEVEL=DEBUG \
    my-app

# Pass from your shell (no value = use host's value)
export DATABASE_URL=postgresql://localhost:5432/mydb
docker run -e DATABASE_URL my-app
```

### With Docker Compose

```yaml
services:
  etl:
    image: my-etl
    environment:
      DATABASE_URL: postgresql://user:pass@db:5432/warehouse
      REDIS_URL: redis://redis:6379
      LOG_LEVEL: INFO
      BATCH_SIZE: "1000"    # Numbers should be strings in YAML
```

## .env Files — Keep Secrets Out of Compose

The real-world pattern: don't put credentials in `docker-compose.yml`. Use a `.env` file.

### How It Works

```bash
# .env (in the same directory as docker-compose.yml)
POSTGRES_PASSWORD=super_secret_p@ssword
POSTGRES_USER=pipeline
POSTGRES_DB=warehouse
REDIS_PASSWORD=redis_secret_123
API_KEY=sk-abc123def456
```

```yaml
# docker-compose.yml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_DB: ${POSTGRES_DB}

  etl:
    build: .
    environment:
      DB_HOST: db
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_USER: ${POSTGRES_USER}
      DB_NAME: ${POSTGRES_DB}
      API_KEY: ${API_KEY}
```

Now add `.env` to `.gitignore`:

```bash
echo ".env" >> .gitignore
```

Create a template for other developers:

```bash
# .env.example (committed to git)
POSTGRES_PASSWORD=change_me
POSTGRES_USER=pipeline
POSTGRES_DB=warehouse
REDIS_PASSWORD=change_me
API_KEY=change_me
```

### env_file Directive

Alternatively, load the entire `.env` file into a service:

```yaml
services:
  etl:
    build: .
    env_file:
      - .env              # Load all variables from .env
      - .env.overrides    # Additional/override variables
```

Difference between `env_file` and `${VARIABLE}` substitution:
- `env_file` passes variables directly to the container
- `${VARIABLE}` substitution happens in the compose file itself (variable must be in your shell or `.env`)

### Multiple Environment Files

```yaml
services:
  etl:
    build: .
    env_file:
      - .env.common       # Shared config
      - .env.${ENV:-dev}   # Environment-specific (defaults to dev)
```

```bash
# Development
docker compose up -d  # Uses .env.dev

# Production
ENV=prod docker compose up -d  # Uses .env.prod
```

## Accessing Environment Variables in Code

### Python

```python
import os

# Get with a default
db_host = os.environ.get("DB_HOST", "localhost")
db_password = os.environ["DB_PASSWORD"]  # Raises KeyError if missing
log_level = os.getenv("LOG_LEVEL", "INFO")
batch_size = int(os.getenv("BATCH_SIZE", "500"))

# Construct connection string from individual vars
db_url = f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@{os.getenv('DB_HOST')}/{os.getenv('DB_NAME')}"
```

### Best Practice: Validate at Startup

```python
import os
import sys

REQUIRED_VARS = ["DB_HOST", "DB_PASSWORD", "DB_USER", "DB_NAME"]

missing = [var for var in REQUIRED_VARS if var not in os.environ]
if missing:
    print(f"ERROR: Missing environment variables: {', '.join(missing)}")
    sys.exit(1)

# If we get here, all required vars are set
```

This saves you from debugging mysterious "connection refused" errors 10 minutes into a pipeline run. Fail fast.

## Docker Secrets — The Proper Way for Production

For production workloads, Docker provides a secrets mechanism. Secrets are stored securely and mounted as files inside the container, not as environment variables (which can leak via `docker inspect`, logs, or `/proc`).

### Compose Secrets (Docker Compose v2)

```bash
# Create secret files
echo "super_secret_password" > db_password.txt
echo "sk-abc123def456" > api_key.txt
```

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

  etl:
    build: .
    secrets:
      - db_password
      - api_key

secrets:
  db_password:
    file: ./db_password.txt
  api_key:
    file: ./api_key.txt
```

Inside the container, secrets are available as files at `/run/secrets/<secret_name>`:

```python
# Reading a Docker secret in Python
def read_secret(name):
    try:
        with open(f"/run/secrets/{name}") as f:
            return f.read().strip()
    except FileNotFoundError:
        # Fall back to environment variable
        return os.environ.get(name.upper())

db_password = read_secret("db_password")
api_key = read_secret("api_key")
```

Many official Docker images support the `_FILE` suffix convention. PostgreSQL, for example:

```yaml
environment:
  POSTGRES_PASSWORD_FILE: /run/secrets/db_password
  # Instead of: POSTGRES_PASSWORD: actual_password
```

### Why Secrets Over Environment Variables?

| | Environment Variables | Docker Secrets |
|---|---|---|
| **Visible in** | `docker inspect`, logs, `/proc` | Only inside container at `/run/secrets/` |
| **Stored** | In container metadata | Encrypted at rest (Swarm), file-based (Compose) |
| **Rotation** | Requires container restart | Can update without restart (Swarm) |
| **Best for** | Non-sensitive config | Passwords, API keys, certificates |

## Configuration Patterns for Data Engineering

### Pattern 1: Development Setup

```yaml
# docker-compose.dev.yml
services:
  etl:
    build: .
    env_file:
      - .env.dev
    environment:
      LOG_LEVEL: DEBUG          # Override for verbose logging
      DRY_RUN: "true"          # Don't actually write to production
    volumes:
      - ./src:/app/src          # Live code changes
```

### Pattern 2: Config File Mounting

For complex configurations (like Airflow, Spark, etc.), mount config files:

```yaml
services:
  airflow:
    image: apache/airflow:2.8.0
    volumes:
      - ./config/airflow.cfg:/opt/airflow/airflow.cfg:ro
      - ./dags:/opt/airflow/dags
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: ${AIRFLOW_DB_URL}
```

### Pattern 3: Connection String Builder

```python
# config.py — centralized config from environment
import os

class Config:
    # Database
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = int(os.getenv("DB_PORT", "5432"))
    DB_USER = os.getenv("DB_USER", "postgres")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "")
    DB_NAME = os.getenv("DB_NAME", "warehouse")

    @property
    def database_url(self):
        return f"postgresql://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    # Pipeline config
    BATCH_SIZE = int(os.getenv("BATCH_SIZE", "1000"))
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
    OUTPUT_DIR = os.getenv("OUTPUT_DIR", "/app/output")

config = Config()
```

## Common Anti-Patterns

### 1. Secrets in Dockerfile

```dockerfile
# NEVER DO THIS
ENV API_KEY=sk-abc123def456
RUN echo "password: secret123" > /app/config.yml

# Anyone with access to the image can see these:
# docker history my-image
# docker inspect my-container
```

### 2. Secrets in docker-compose.yml (committed to git)

```yaml
# NEVER COMMIT THIS
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: my_actual_production_password  # NO!
```

### 3. Printing Secrets in Logs

```python
# NEVER DO THIS
print(f"Connecting to {db_url}")  # This logs the password!

# DO THIS
print(f"Connecting to {db_host}:{db_port}/{db_name}")  # No password
```

### 4. Using ARG for Secrets

```dockerfile
# NEVER DO THIS
ARG DB_PASSWORD
RUN pip install --extra-index-url https://user:${DB_PASSWORD}@private.repo/simple my-package

# The ARG value is stored in layer history!
# Use multi-stage builds instead (see Lesson 14)
```

## Quick Reference: What Goes Where

| What | Where | Example |
|------|-------|---------|
| Python settings | `ENV` in Dockerfile | `PYTHONUNBUFFERED=1` |
| App defaults | `ENV` in Dockerfile | `LOG_LEVEL=INFO` |
| Build-time config | `ARG` in Dockerfile | `PYTHON_VERSION=3.11` |
| DB credentials | `.env` file (gitignored) | `DB_PASSWORD=secret` |
| API keys | Docker secrets or `.env` | `API_KEY=sk-abc...` |
| Connection strings | Runtime env vars | `DATABASE_URL=...` |
| Complex config | Mounted config files | `airflow.cfg`, `spark-defaults.conf` |

---

## Practice Problems

### Beginner

1. Create a Dockerfile with `ENV LOG_LEVEL=INFO`. Build and run it. Override the log level at runtime with `-e LOG_LEVEL=DEBUG`. Verify inside the container with `env | grep LOG`.

2. Create a `.env` file with `POSTGRES_PASSWORD`, `POSTGRES_USER`, and `POSTGRES_DB`. Create a compose file that uses `${VARIABLE}` substitution from the `.env` file. Start PostgreSQL and verify the variables are set correctly.

3. Use `ARG` to make the Python version configurable in a Dockerfile. Build the image with `--build-arg PYTHON_VERSION=3.12`. Verify the Python version inside the container.

### Intermediate

4. Create a Python ETL script (`config.py`) that reads all its configuration from environment variables with sensible defaults. Include validation that exits with an error if required variables are missing. Test it in a container.

5. Set up a compose environment with:
   - `.env.dev` (local database, debug logging)
   - `.env.prod` (remote database, info logging)
   - A compose file that loads the right `.env` based on an `ENV` variable
   - Verify each environment has the correct settings

6. Implement Docker Compose secrets for a PostgreSQL + Python setup. The database password should be stored in a file and mounted as a secret. The Python code should read from `/run/secrets/` with a fallback to environment variables.

### Advanced

7. Create a multi-environment deployment:
   - `docker-compose.yml` (base services)
   - `docker-compose.dev.yml` (dev overrides: debug mode, exposed ports, bind mounts)
   - `docker-compose.prod.yml` (prod overrides: secrets, resource limits, no exposed ports)
   - `.env.dev` and `.env.prod` with appropriate credentials
   - Test both configurations work correctly

8. Build a secrets rotation system:
   - Store database credentials as Docker secrets
   - Write a Python script that reads the secret, connects to the database, and periodically checks if the secret file has changed
   - Simulate rotation by updating the secret file while the container is running

---

**Up next:** [Data Engineering Pipelines in Docker](10_Data_Engineering_Pipelines.md) — where everything we've learned so far comes together.

## Resources

- [Docker Environment Variables](https://docs.docker.com/compose/how-tos/environment-variables/) — Complete guide
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/) — Secrets management
- [12-Factor App Config](https://12factor.net/config) — Industry standard for config management
- [Compose env_file](https://docs.docker.com/reference/compose-file/services/#env_file) — How env_file works in Compose
