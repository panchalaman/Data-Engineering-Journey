# Docker Practice — Data Engineering Interview Prep

A collection of hands-on exercises and interview-style questions that cover what companies actually ask data engineers about Docker. I've organized these from foundational to advanced, and each section mixes conceptual questions (the "why") with practical tasks (the "how").

Don't just read the answers. Open a terminal, type the commands, break things, fix them. That's how this stuff sticks.

---

## Section 1: Containers & Images — The Basics

### Conceptual Questions

**Q1: What's the difference between a container and a virtual machine?**

A container shares the host OS kernel and isolates processes using namespaces and cgroups. A VM runs its own complete OS on top of a hypervisor. Containers are lighter (MBs vs GBs), start in seconds (not minutes), and use fewer resources. For data engineering, this means you can run PostgreSQL, Redis, Airflow, and your pipeline all on a laptop without it melting.

**Q2: What happens when you run `docker run postgres:16`?**

1. Docker checks if `postgres:16` exists locally
2. If not, pulls it from Docker Hub (default registry)
3. Creates a new container from the image
4. Assigns it a network interface on the default bridge network
5. Starts the container's entrypoint process (PostgreSQL server)

If you didn't pass `-d`, you're now attached to the container's stdout. If you didn't pass `--name`, Docker generates a random name. If you didn't pass `-v`, your data dies when the container is removed.

**Q3: What's the difference between `docker stop` and `docker kill`?**

`docker stop` sends SIGTERM (polite shutdown — lets PostgreSQL flush to disk), waits 10 seconds, then sends SIGKILL. `docker kill` sends SIGKILL immediately (hard stop). Always use `stop` for databases. Use `kill` only when a container is unresponsive.

**Q4: Explain Docker image layers.**

Each instruction in a Dockerfile creates a layer. Layers are read-only and stacked. When you change one layer, only that layer and everything above it gets rebuilt. This is why you put `COPY requirements.txt` and `RUN pip install` before `COPY src/` — your dependencies don't change often, so that layer stays cached.

```
Layer 4: COPY src/ ./src/          ← Changes often (rebuilt every time)
Layer 3: RUN pip install -r req..  ← Cached (unless requirements.txt changed)
Layer 2: COPY requirements.txt .   ← Cached (unless file changed)
Layer 1: FROM python:3.11-slim     ← Base image (always cached)
```

### Hands-On Tasks

**Task 1: Container Lifecycle**

```bash
# Do all of these in order. Predict the output before running each command.

# 1. Run a postgres container
docker run -d --name practice-db -e POSTGRES_PASSWORD=secret postgres:16

# 2. Check it's running
docker ps

# 3. Create a table
docker exec -it practice-db psql -U postgres -c "CREATE TABLE test (id INT, name TEXT);"
docker exec -it practice-db psql -U postgres -c "INSERT INTO test VALUES (1, 'docker');"

# 4. Stop the container
docker stop practice-db

# 5. Is the data still there? Start it again and check
docker start practice-db
docker exec -it practice-db psql -U postgres -c "SELECT * FROM test;"
# Answer: Yes — stopping doesn't remove the container or its filesystem

# 6. Remove the container
docker rm -f practice-db

# 7. Run a new container with the same name. Is the data there?
docker run -d --name practice-db -e POSTGRES_PASSWORD=secret postgres:16
sleep 3
docker exec -it practice-db psql -U postgres -c "SELECT * FROM test;"
# Answer: No — the container filesystem is gone. You needed a volume.

# 8. Clean up
docker rm -f practice-db
```

**Task 2: Image Investigation**

```bash
# Pull these images and compare sizes
docker pull python:3.11
docker pull python:3.11-slim
docker pull python:3.11-alpine

# Check sizes
docker images python

# Questions to answer:
# - What's the size difference between full and slim?
# - Why would you NOT use alpine for a data engineering project?
#   (Hint: try `docker run --rm python:3.11-alpine pip install pandas`)

# Look at what's inside an image
docker history python:3.11-slim
docker history --no-trunc python:3.11-slim
```

**Task 3: Debugging a Container**

```bash
# This container will fail. Figure out why.
docker run -d --name broken-db \
    -e POSTGRES_USER=admin \
    postgres:16

# Check what happened
docker ps -a    # What's the status?
docker logs broken-db    # What does it say?

# Fix: POSTGRES_PASSWORD is required
docker rm broken-db
docker run -d --name broken-db \
    -e POSTGRES_USER=admin \
    -e POSTGRES_PASSWORD=secret \
    postgres:16

docker rm -f broken-db
```

---

## Section 2: Dockerfile — Building Production Images

### Conceptual Questions

**Q5: What's the difference between CMD and ENTRYPOINT?**

`ENTRYPOINT` defines the executable. `CMD` provides default arguments to it. In practice:

```dockerfile
ENTRYPOINT ["python"]
CMD ["pipeline.py"]
# Runs: python pipeline.py
# Override: docker run my-image other_script.py → python other_script.py

# vs

CMD ["python", "pipeline.py"]
# Runs: python pipeline.py
# Override: docker run my-image bash → bash (completely replaces the command)
```

For data engineering, use `ENTRYPOINT ["python"]` + `CMD ["pipeline.py"]` when you want a flexible Python runner. Use `CMD` alone when the image might be used for different purposes.

**Q6: Why does the order of Dockerfile instructions matter?**

Layer caching. Docker caches each layer and reuses it if nothing changed. If you put `COPY . .` before `RUN pip install`, every code change invalidates the pip install cache and reinstalls all packages. That turns a 10-second build into a 2-minute build.

```dockerfile
# BAD — pip install runs on every code change
COPY . .
RUN pip install -r requirements.txt

# GOOD — pip install is cached unless requirements.txt changes
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

**Q7: What's a multi-stage build and why use it?**

You use one stage to build (install compilers, build wheels) and another to run (just the runtime). The final image doesn't contain build tools, reducing size and attack surface.

```dockerfile
# Build stage — has gcc, build tools (~800MB)
FROM python:3.11-slim AS builder
RUN apt-get update && apt-get install -y gcc libpq-dev
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir=/wheels -r requirements.txt

# Runtime stage — no build tools (~150MB)
FROM python:3.11-slim
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels
COPY src/ ./src/
CMD ["python", "src/pipeline.py"]
```

**Q8: What belongs in .dockerignore and why?**

Everything that doesn't need to be in the image. The build context (everything Docker sends to the daemon) should be minimal.

```
.git
.env
__pycache__
*.pyc
.venv
node_modules
data/
logs/
*.md
.DS_Store
```

Without `.dockerignore`, Docker sends your entire directory to the builder — including that 2GB `data/` folder and your `.git` history.

### Hands-On Tasks

**Task 4: Fix This Dockerfile**

This Dockerfile has 6 problems. Find and fix all of them.

```dockerfile
FROM python:latest

COPY . /app
WORKDIR /app

ENV DB_PASSWORD=super_secret_123

RUN pip install -r requirements.txt
RUN apt-get update && apt-get install -y gcc libpq-dev

CMD python pipeline.py
```

<details>
<summary>Problems and fixes (try before looking)</summary>

1. `python:latest` — Never use `latest`. Pin a version: `python:3.11-slim`
2. `COPY . /app` before `pip install` — Breaks layer caching. Copy requirements.txt first
3. `ENV DB_PASSWORD=super_secret_123` — Never put secrets in the image. Use runtime env vars
4. `pip install` before `apt-get install` — System deps (gcc, libpq-dev) are needed BEFORE pip install
5. `CMD python pipeline.py` — Use exec form: `CMD ["python", "pipeline.py"]` (proper signal handling)
6. No non-root user — Add `USER appuser` for security

Fixed version:

```dockerfile
FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

RUN useradd --create-home appuser

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appuser src/ ./src/

USER appuser

CMD ["python", "src/pipeline.py"]
```

</details>

**Task 5: Build and Optimize**

Create a `Dockerfile` and `requirements.txt` for a Python data pipeline:

```txt
# requirements.txt
pandas==2.1.4
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
requests==2.31.0
```

```python
# src/pipeline.py
import pandas as pd
import os
print(f"Pipeline running with pandas {pd.__version__}")
print(f"DB_HOST: {os.getenv('DB_HOST', 'not set')}")
```

Build it three ways and compare sizes:

```bash
# 1. Naive build (no optimization)
# 2. Optimized single-stage (slim base, proper layer order)
# 3. Multi-stage build

docker images | grep pipeline
# Which is smallest? By how much?
```

**Task 6: Build Arguments**

Create a Dockerfile that accepts `PYTHON_VERSION` as a build argument:

```bash
docker build --build-arg PYTHON_VERSION=3.11 -t pipeline:py311 .
docker build --build-arg PYTHON_VERSION=3.12 -t pipeline:py312 .

# Verify each uses the correct Python version
docker run --rm pipeline:py311 python --version
docker run --rm pipeline:py312 python --version
```

---

## Section 3: Volumes & Storage

### Conceptual Questions

**Q9: Named volume vs bind mount — when do you use each?**

| | Named Volume | Bind Mount |
|---|---|---|
| **Managed by** | Docker | You |
| **Location** | Docker's internal storage | Specific path on host |
| **Use case** | Database data, persistent state | Development (live code), config files |
| **Performance (macOS)** | Good | Slower (Docker VM overhead) |
| **In production** | Yes | Rarely |

Rule of thumb: named volumes for data that the container owns (database files), bind mounts for data that YOU own (source code, config).

**Q10: A developer says "I lost all my PostgreSQL data after restarting." What happened?**

They ran PostgreSQL without a volume. Container filesystem is ephemeral — when the container is removed (`docker rm`), the data is gone. The fix:

```bash
# This loses data on container removal:
docker run -d postgres:16

# This persists data:
docker run -d -v pg-data:/var/lib/postgresql/data postgres:16
```

Note: `docker stop` + `docker start` preserves data (container still exists). Only `docker rm` destroys it. But the real insurance is a named volume.

### Hands-On Tasks

**Task 7: Prove Data Persistence**

```bash
# Step 1: Create postgres WITH a volume, add data
docker run -d --name db1 \
    -e POSTGRES_PASSWORD=secret \
    -v test-vol:/var/lib/postgresql/data \
    postgres:16
sleep 5
docker exec db1 psql -U postgres -c "CREATE TABLE proof (msg TEXT);"
docker exec db1 psql -U postgres -c "INSERT INTO proof VALUES ('volumes work');"

# Step 2: Destroy the container
docker rm -f db1

# Step 3: New container, same volume
docker run -d --name db2 \
    -e POSTGRES_PASSWORD=secret \
    -v test-vol:/var/lib/postgresql/data \
    postgres:16
sleep 5
docker exec db2 psql -U postgres -c "SELECT * FROM proof;"
# Expected: "volumes work"

# Clean up
docker rm -f db2
docker volume rm test-vol
```

**Task 8: Backup and Restore a Volume**

```bash
# Create a database with data
docker run -d --name backup-db \
    -e POSTGRES_PASSWORD=secret \
    -v backup-vol:/var/lib/postgresql/data \
    postgres:16
sleep 5
docker exec backup-db psql -U postgres -c "CREATE TABLE important (id INT, data TEXT);"
docker exec backup-db psql -U postgres -c "INSERT INTO important VALUES (1, 'critical data');"

# Backup the volume to a tar file
docker run --rm \
    -v backup-vol:/source:ro \
    -v $(pwd):/backup \
    alpine tar czf /backup/db-backup.tar.gz -C /source .

# Destroy everything
docker rm -f backup-db
docker volume rm backup-vol

# Restore to a new volume
docker volume create restored-vol
docker run --rm \
    -v restored-vol:/target \
    -v $(pwd):/backup:ro \
    alpine tar xzf /backup/db-backup.tar.gz -C /target

# Verify
docker run -d --name restored-db \
    -e POSTGRES_PASSWORD=secret \
    -v restored-vol:/var/lib/postgresql/data \
    postgres:16
sleep 5
docker exec restored-db psql -U postgres -c "SELECT * FROM important;"
# Expected: 1 | critical data

# Clean up
docker rm -f restored-db
docker volume rm restored-vol
rm db-backup.tar.gz
```

---

## Section 4: Networking

### Conceptual Questions

**Q11: Why can't two containers communicate on the default bridge network by name?**

The default bridge network doesn't have an embedded DNS server. Containers on it can only reach each other by IP address, which changes on restart. User-defined bridge networks have DNS built in — containers resolve each other by name automatically.

```bash
# This doesn't work (default bridge):
docker run -d --name db postgres:16
docker run --rm python:3.11-slim python -c "import socket; socket.gethostbyname('db')"
# Error: Name resolution failed

# This works (user-defined network):
docker network create my-net
docker run -d --name db --network my-net -e POSTGRES_PASSWORD=s postgres:16
docker run --rm --network my-net python:3.11-slim python -c "import socket; print(socket.gethostbyname('db'))"
# Output: 172.18.0.2
```

**Q12: Inside a Docker container, what does `localhost` refer to?**

The container itself. NOT the host machine. This is the #1 networking mistake. If your Python container tries to connect to PostgreSQL on `localhost:5432`, it's looking for PostgreSQL inside the Python container — which doesn't exist.

```python
# WRONG — localhost means "this container"
conn = psycopg2.connect(host="localhost", port=5432, ...)

# RIGHT — use the container name (on a user-defined network)
conn = psycopg2.connect(host="db", port=5432, ...)
```

**Q13: When do you need port mapping (`-p`) and when don't you?**

Port mapping is for host-to-container communication only. Container-to-container communication on the same Docker network doesn't need it.

```bash
# Port mapping needed: you want to use psql from your laptop
docker run -d -p 5432:5432 --name db postgres:16
# Now: psql -h localhost -p 5432 works from your machine

# Port mapping NOT needed: another container connects to it
docker run --rm --network same-net python:3.11-slim python -c "
import psycopg2
conn = psycopg2.connect(host='db', port=5432, ...)  # Direct, no port mapping needed
"
```

### Hands-On Tasks

**Task 9: Container Communication**

```bash
# Build a mini data pipeline with networking

# Create a network
docker network create pipeline

# Start PostgreSQL
docker run -d --name warehouse --network pipeline \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_DB=analytics \
    postgres:16

sleep 5

# From a Python container on the same network, connect and create a table
docker run --rm --network pipeline python:3.11-slim bash -c "
pip install psycopg2-binary -q
python -c \"
import psycopg2
conn = psycopg2.connect(host='warehouse', dbname='analytics', user='postgres', password='secret')
cur = conn.cursor()
cur.execute('CREATE TABLE IF NOT EXISTS events (id SERIAL, event TEXT, ts TIMESTAMP DEFAULT NOW())')
cur.execute(\\\"INSERT INTO events (event) VALUES ('pipeline_start')\\\")
conn.commit()
cur.execute('SELECT * FROM events')
print(cur.fetchall())
conn.close()
\"
"

# Verify from another container
docker run --rm --network pipeline postgres:16 \
    psql -h warehouse -U postgres -d analytics -c "SELECT * FROM events;"

# Clean up
docker rm -f warehouse
docker network rm pipeline
```

**Task 10: Network Isolation**

```bash
# Prove that containers on different networks CAN'T communicate

docker network create frontend
docker network create backend

docker run -d --name api --network frontend alpine sleep 3600
docker run -d --name db --network backend -e POSTGRES_PASSWORD=s postgres:16

# Try to ping db from api (should FAIL)
docker exec api ping -c 2 db
# Error: bad address 'db'

# Connect api to both networks
docker network connect backend api

# Now try again (should SUCCEED)
docker exec api ping -c 2 db

# Clean up
docker rm -f api db
docker network rm frontend backend
```

---

## Section 5: Docker Compose

### Conceptual Questions

**Q14: What does `depends_on` actually guarantee?**

Only that the dependency container has STARTED. Not that the service inside is ready. PostgreSQL might take 5 seconds after the container starts to accept connections. Use `depends_on` with `condition: service_healthy` and a health check to wait for actual readiness.

```yaml
# BAD — app starts before Postgres is ready
depends_on:
  - db

# GOOD — app starts after Postgres accepts connections
depends_on:
  db:
    condition: service_healthy
```

**Q15: What's the difference between `docker compose down` and `docker compose down -v`?**

`down` removes containers and networks but keeps volumes (your database data survives). `down -v` removes volumes too (all data is destroyed). In development, use `down -v` when you want a fresh start. Never use `down -v` in production unless you mean to delete all data.

**Q16: How do you handle secrets in Docker Compose?**

Three approaches, from simplest to most secure:

1. **`.env` file** (gitignored) — good for development
2. **`env_file` directive** — loads vars from file into container
3. **Docker secrets** — mounted as files at `/run/secrets/`, encrypted at rest

```yaml
# Method 1: .env substitution
environment:
  DB_PASSWORD: ${DB_PASSWORD}  # From .env file

# Method 2: env_file
env_file:
  - .env

# Method 3: Docker secrets
secrets:
  - db_password
# Read in Python: open('/run/secrets/db_password').read().strip()
```

### Hands-On Tasks

**Task 11: Build a Complete Stack**

Create this `docker-compose.yml` from scratch (don't copy-paste, type it out):

Requirements:
- PostgreSQL 16 with named volume, health check, port 5432
- Redis 7 alpine with named volume, port 6379
- pgAdmin with port 8080 (profile: "ui")
- All credentials from `.env` file
- A custom network

Then:

```bash
# Start core services
docker compose up -d

# Verify PostgreSQL is healthy
docker compose ps

# Connect to PostgreSQL
docker compose exec db psql -U ${your_user} -d ${your_db}

# Start pgAdmin too
docker compose --profile ui up -d

# Open http://localhost:8080

# Stop everything
docker compose down

# Verify data persists
docker compose up -d
docker compose exec db psql -U ${your_user} -c "SELECT 1;"

# Nuclear clean
docker compose down -v
```

**Task 12: Compose with Build**

Create a project that:
1. Has a `Dockerfile` for a Python ETL script
2. Has `docker-compose.yml` with PostgreSQL + your ETL service
3. ETL waits for PostgreSQL to be healthy (`condition: service_healthy`)
4. ETL reads config from environment variables
5. ETL creates a table and inserts a row

Test it:

```bash
docker compose up --build
# Should see: PostgreSQL ready... ETL running... Data inserted
docker compose exec db psql -U postgres -c "SELECT * FROM your_table;"
```

**Task 13: Multi-Environment Setup**

Create:
- `docker-compose.yml` — base config
- `docker-compose.dev.yml` — exposes all ports, bind mounts code
- `docker-compose.prod.yml` — no exposed ports (except app), no bind mounts, resource limits

```bash
# Development
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Production
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Verify different ports are exposed in each
docker compose ps
```

---

## Section 6: Data Engineering Scenarios

These are the kind of problems you get in take-home assignments and on-site interviews.

### Scenario 1: Containerize an Existing Pipeline

You receive a Python script that:
- Reads from a CSV file
- Cleans and transforms data with pandas
- Loads to PostgreSQL
- Currently runs with `python pipeline.py` on someone's laptop

**Task:** Containerize it so any team member can run it with one command.

Deliverables:
- [ ] `Dockerfile` (production quality)
- [ ] `docker-compose.yml` (PostgreSQL + ETL)
- [ ] `.env.example` (template for credentials)
- [ ] `.dockerignore`
- [ ] Health checks on PostgreSQL
- [ ] Data survives `docker compose down`
- [ ] ETL logs visible on host machine
- [ ] Works on both Intel and Apple Silicon Macs

### Scenario 2: Debug a Failing Pipeline

Your pipeline was running fine yesterday. Today `docker compose up` fails. Debug it.

Common issues to practice diagnosing:

```bash
# Issue 1: Container exits immediately
docker compose up -d
docker compose ps    # Status: "Exited (1)"
docker compose logs etl    # What's the error?

# Issue 2: "Connection refused" to database
# Check: Is the DB healthy? Is the ETL on the same network?
# Is it using 'localhost' instead of the service name?

# Issue 3: "Permission denied" writing to mount
# Check: Is the container running as non-root?
# Does the user have write access?

# Issue 4: Volume data from wrong Postgres version
# Symptom: "The data directory was initialized by PostgreSQL version 15"
# Fix: docker compose down -v (WARNING: data loss) or use pg_upgrade

# Issue 5: Port already in use
# "bind: address already in use"
lsof -i :5432    # What's using the port?
# Fix: stop the other process, or use a different host port (-p 5433:5432)
```

### Scenario 3: Design a Data Platform

Design a Docker Compose setup for this architecture:

```
Source API  →  Python Extractor  →  Raw DB (PostgreSQL)
                                        ↓
                                  Python Transformer  →  Warehouse (PostgreSQL)
                                        ↓
                                    pgAdmin (UI)
```

Requirements:
- Two separate PostgreSQL instances (raw and warehouse)
- Python containers for extract and transform
- Extract runs first, transform runs after
- No passwords in compose file
- Raw DB not accessible from host (internal only)
- Warehouse accessible on port 5432 (for DBeaver)
- pgAdmin on port 8080 (optional, via profile)

Write the `docker-compose.yml` from scratch.

### Scenario 4: Airflow Setup

Set up Airflow with Docker Compose and create a DAG that:

1. Waits for a file to appear in `/opt/airflow/data/`
2. Reads the file and loads it to PostgreSQL
3. Runs a data quality check (row count > 0, no nulls in key columns)
4. Sends a summary log

Test by:
1. Starting Airflow
2. Placing a CSV file in the mounted `data/` directory
3. Watching the DAG trigger and complete

---

## Section 7: Interview Questions — Rapid Fire

These are questions I've seen come up in data engineering interviews. Short answers are fine — interviewers want to know you understand the concept, not that you can recite documentation.

### Beginner

**Q: How do you check logs for a crashed container?**
`docker logs <container_name>` — works even after the container has stopped.

**Q: How do you get a shell inside a running container?**
`docker exec -it <container_name> bash` (or `sh` if bash isn't installed).

**Q: What's the purpose of `-d` in `docker run -d`?**
Detached mode — runs the container in the background. Without it, your terminal is attached to the container's stdout.

**Q: How do you list all containers, including stopped ones?**
`docker ps -a`

**Q: What does `docker system prune` do?**
Removes stopped containers, unused networks, dangling images, and build cache. Add `--volumes` to also remove unused volumes. Add `-a` to remove ALL unused images.

### Intermediate

**Q: How do you pass environment variables to a container?**
`docker run -e VAR=value`, `--env-file .env`, or `environment:` in compose. For secrets, use Docker secrets mounted at `/run/secrets/`.

**Q: Why should you run containers as non-root?**
If the container is compromised, the attacker gets root access. With a non-root user, the blast radius is limited. Add `USER appuser` in Dockerfile after installing dependencies.

**Q: What's the difference between COPY and ADD in a Dockerfile?**
`COPY` copies files. `ADD` also supports URLs and auto-extracts tar archives. Use `COPY` unless you specifically need `ADD`'s features — it's more explicit.

**Q: How do you make a Docker Compose service wait for a database to be ready?**
Use `depends_on` with `condition: service_healthy` and add a `healthcheck` to the database service (e.g., `pg_isready` for PostgreSQL).

**Q: How do you persist data from a PostgreSQL container?**
Mount a named volume to `/var/lib/postgresql/data`. Without it, data is lost when the container is removed.

**Q: What's the Docker build context?**
The directory sent to the Docker daemon when you run `docker build`. A `.dockerignore` file controls what's excluded. Large build contexts slow down builds significantly.

### Advanced

**Q: Explain multi-stage builds and when you'd use them.**
Use one stage to build (compile code, install build deps) and copy only artifacts to a final slim stage. Reduces image size and removes build tools from production. Common for Python packages that need C compilation (psycopg2, numpy).

**Q: How would you handle database migrations in a containerized environment?**
Run migrations as a separate init container or a Compose service that runs before the app. Use `depends_on` with health checks. Tools like Alembic or Flyway run as one-shot containers. Never bake migration logic into the application startup.

**Q: How do you debug a container that crashes on startup?**
1. `docker logs <container>` — check error output
2. `docker run -it <image> bash` — override entrypoint, explore interactively
3. `docker inspect <container>` — check env vars, mounts, network
4. `docker run --entrypoint sh <image>` — skip the normal entrypoint entirely

**Q: How do you scan Docker images for vulnerabilities?**
`docker scout cves <image>` (built-in) or `trivy image <image>` (third-party). Integrate into CI to fail builds on CRITICAL vulnerabilities.

**Q: Explain Docker networking in a multi-container Compose setup.**
Compose creates a default network. All services are on it and can reach each other by service name (Docker DNS). Port mapping (`ports:`) is only for host access. You can create custom networks for isolation — e.g., database on `backend` network only.

**Q: What happens if you put secrets in a Dockerfile's ENV instruction?**
Anyone who pulls the image can see them with `docker inspect` or `docker history`. Secrets should be injected at runtime via `-e`, `.env` files, or Docker secrets. For build-time secrets, use BuildKit's `--mount=type=secret`.

---

## Section 8: Real-World Troubleshooting

These are actual problems you'll hit working with Docker in data engineering. Practice diagnosing them.

### Problem 1: "No space left on device"

```bash
# Diagnose
docker system df

# Fix
docker system prune -a --volumes

# Prevent: add to your crontab
# 0 3 * * 0 docker system prune -f --volumes
```

### Problem 2: Container works locally, fails in CI

Common causes:
- Platform mismatch (M1/M2 Mac builds arm64, CI runs amd64)
- Missing environment variables in CI
- Network restrictions in CI environment

```bash
# Fix platform issues
docker buildx build --platform linux/amd64 -t my-image .

# Or in Compose
services:
  app:
    platform: linux/amd64
```

### Problem 3: "Connection refused" between containers

Checklist:
1. Are both containers on the same network? (`docker network inspect`)
2. Are you using the container/service name, not `localhost`?
3. Is the target service actually running and healthy? (`docker compose ps`)
4. Are you connecting to the container's internal port (not the mapped host port)?

### Problem 4: Changes to code aren't reflected

In development:
- If using bind mounts, changes should be instant. Check the mount path.
- If NOT using bind mounts, you need to rebuild: `docker compose up --build`
- Clear Python bytecode: add `ENV PYTHONDONTWRITEBYTECODE=1` to Dockerfile

### Problem 5: Database init scripts don't run

PostgreSQL init scripts (`/docker-entrypoint-initdb.d/`) only run when the data volume is empty. If you modify scripts:

```bash
docker compose down -v    # Remove the volume
docker compose up -d      # Fresh start
```

### Problem 6: Slow builds

```bash
# Check if .dockerignore exists and excludes:
# .git, data/, logs/, .venv, __pycache__

# Check layer ordering — requirements.txt before source code?

# Use BuildKit (faster, better caching)
DOCKER_BUILDKIT=1 docker build -t my-image .
```

---

## Section 9: Best Practices Checklist

Use this as a review before interviews or code reviews.

### Dockerfile

```
[ ] Uses specific version tag (not :latest)
[ ] Uses -slim base image
[ ] COPY requirements.txt before COPY source code (layer caching)
[ ] RUN apt-get update && install in same layer, with rm -rf /var/lib/apt/lists/*
[ ] Uses --no-cache-dir with pip install
[ ] Has .dockerignore
[ ] Runs as non-root user (USER instruction)
[ ] Uses exec form for CMD/ENTRYPOINT: ["python", "app.py"]
[ ] No secrets in ENV or ARG
[ ] Multi-stage build for compiled dependencies
```

### Docker Compose

```
[ ] Uses .env file for credentials (gitignored)
[ ] Has .env.example committed to git
[ ] Health checks on databases
[ ] depends_on with condition: service_healthy
[ ] Named volumes for persistent data
[ ] Bind mounts only for development
[ ] Resource limits (memory, CPU) in production
[ ] Restart policies (unless-stopped or on-failure)
[ ] No hardcoded passwords
```

### General

```
[ ] Images are scanned for vulnerabilities
[ ] Images are tagged with version AND git SHA
[ ] docker system prune runs regularly
[ ] Logs are accessible (bind mount or logging driver)
[ ] Container processes handle SIGTERM gracefully
[ ] Containers are stateless (state lives in volumes/databases)
```

---

That's the entire practice set. If you can do all of these tasks confidently and explain the concepts clearly, you're well prepared for Docker questions in any data engineering interview. The key is hands-on practice — reading isn't enough, you need to have typed the commands and fixed the errors yourself.

Keep building.
