# Production Best Practices

There's a big difference between "it works on my machine" and "it's ready for production." This lesson covers everything you need to make your Docker images small, fast, secure, and reliable.

## Image Size Matters

Smaller images mean:
- Faster pulls and deployments
- Less storage cost
- Smaller attack surface
- Faster CI/CD pipelines

### Choose the Right Base Image

```
┌─────────────────────────────────────────────┐
│ Image                    │ Size     │ Use?   │
├─────────────────────────────────────────────┤
│ python:3.11              │ ~1 GB    │ Avoid  │
│ python:3.11-slim         │ ~150 MB  │ Good   │
│ python:3.11-alpine       │ ~50 MB   │ Tricky │
│ ubuntu:22.04             │ ~77 MB   │ OK     │
│ debian:bookworm-slim     │ ~80 MB   │ Good   │
│ alpine:3.19              │ ~7 MB    │ Best   │
└─────────────────────────────────────────────┘
```

`python:3.11-slim` is the sweet spot. Alpine is smaller but uses musl instead of glibc, which breaks some Python packages (like pandas, numpy) unless you install extra build tools.

### Clean Up After apt-get

```dockerfile
# BAD — leaves apt cache in the layer
RUN apt-get update
RUN apt-get install -y gcc libpq-dev
RUN apt-get clean

# GOOD — one layer, cache cleaned
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*
```

`--no-install-recommends` skips optional packages. `rm -rf /var/lib/apt/lists/*` removes the package index cache.

### Use --no-cache-dir with pip

```dockerfile
# BAD — pip cache stays in the image
RUN pip install pandas sqlalchemy

# GOOD — no cache
RUN pip install --no-cache-dir pandas sqlalchemy
```

### Combine RUN Commands

Every `RUN` creates a new layer. Combine related commands:

```dockerfile
# BAD — 4 layers
RUN apt-get update
RUN apt-get install -y gcc
RUN pip install pandas
RUN rm -rf /var/lib/apt/lists/*

# GOOD — 1 layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    pip install --no-cache-dir pandas && \
    rm -rf /var/lib/apt/lists/*
```

## Multi-Stage Builds

This is the most powerful technique for small production images. You use one stage to build (with all the compilers and development tools) and a second stage that only contains the runtime.

### Basic Multi-Stage

```dockerfile
# Stage 1: Build
FROM python:3.11-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

# Copy only the installed packages from builder
COPY --from=builder /install /usr/local

WORKDIR /app
COPY src/ ./src/

# No gcc, no build tools, no pip cache — just the runtime
CMD ["python", "src/pipeline.py"]
```

Result:
- Builder stage: ~500 MB (with gcc, dev headers, pip cache)
- Final image: ~200 MB (just Python + your packages + your code)

### Multi-Stage for Data Engineering

```dockerfile
# Stage 1: Build dependencies
FROM python:3.11-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        libpq-dev \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir=/wheels -r requirements.txt

# Stage 2: Production image
FROM python:3.11-slim

# Only install runtime libraries (no compilers)
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install from pre-built wheels (no compilation needed)
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

COPY src/ ./src/

# Non-root user
RUN useradd --create-home appuser
USER appuser

CMD ["python", "src/pipeline.py"]
```

Using `pip wheel` in the builder creates pre-compiled wheel files. The runtime stage installs from wheels — no compiler needed.

## Health Checks

Health checks let Docker (and orchestrators like Kubernetes) know if your application is actually working, not just running.

### In Dockerfile

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
```

### In Docker Compose

```yaml
services:
  etl-api:
    build: .
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Health Check Options

| Option | What It Does | Typical Value |
|--------|-------------|---------------|
| `interval` | Time between checks | 30s |
| `timeout` | Max time for a check to respond | 5s |
| `retries` | How many failures before "unhealthy" | 3 |
| `start_period` | Grace period on startup | 10-30s |

## Logging

### Log to stdout/stderr

Docker captures stdout and stderr from your container. Always log there, not to files inside the container.

```python
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(name)s %(levelname)s %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
```

```bash
# View logs
docker logs my-container
docker logs -f my-container    # Follow
docker logs --tail 100 my-container
```

### Structured Logging (JSON)

For production, JSON logs are easier to parse by log aggregation tools (ELK, Datadog, etc.):

```python
import json
import logging
import sys

class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            'timestamp': self.formatTime(record),
            'level': record.levelname,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
        }
        if record.exc_info:
            log_record['exception'] = self.formatException(record.exc_info)
        return json.dumps(log_record)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logging.root.addHandler(handler)
logging.root.setLevel(logging.INFO)
```

Output:
```json
{"timestamp": "2024-01-15 10:30:00", "level": "INFO", "message": "Loaded 1500 rows to warehouse", "module": "load", "function": "load_to_postgres"}
```

### Docker Logging Drivers

```yaml
services:
  etl:
    build: .
    logging:
      driver: json-file
      options:
        max-size: "10m"     # Max 10MB per log file
        max-file: "3"       # Keep 3 rotated files
```

Without size limits, logs can fill up your disk. Always set these.

## Resource Limits

Prevent a single container from consuming all system resources:

```yaml
services:
  etl:
    build: .
    deploy:
      resources:
        limits:
          cpus: '2.0'       # Max 2 CPU cores
          memory: 2G        # Max 2GB RAM
        reservations:
          cpus: '0.5'       # Guaranteed 0.5 cores
          memory: 512M      # Guaranteed 512MB
```

### Why This Matters for Data Engineering

A pandas script processing a large file can easily consume 8GB+ of memory and crash everything else on the machine. Set limits to fail gracefully instead of killing your database.

```yaml
services:
  heavy-etl:
    build: .
    deploy:
      resources:
        limits:
          memory: 4G
    # If the ETL needs more than 4G, it gets OOM-killed
    # instead of taking down the database
```

## Restart Policies

```yaml
services:
  # Always restart (unless manually stopped)
  worker:
    restart: unless-stopped

  # Restart only on failure
  etl:
    restart: on-failure

  # Never restart (one-shot tasks)
  migration:
    restart: "no"
```

| Policy | Behavior |
|--------|----------|
| `no` | Never restart (default) |
| `on-failure` | Restart only if exit code is non-zero |
| `always` | Always restart, even if stopped manually |
| `unless-stopped` | Like `always`, but not after manual stop |

## Graceful Shutdown

When Docker stops a container, it sends SIGTERM. Your app should handle it:

```python
import signal
import sys

def shutdown_handler(signum, frame):
    print("Received shutdown signal. Cleaning up...")
    # Close database connections
    # Flush buffered writes
    # Save checkpoint
    sys.exit(0)

signal.signal(signal.SIGTERM, shutdown_handler)
signal.signal(signal.SIGINT, shutdown_handler)
```

Docker waits 10 seconds for the app to stop gracefully, then sends SIGKILL. You can increase this:

```yaml
services:
  etl:
    stop_grace_period: 30s    # Give 30 seconds to clean up
```

## .dockerignore

This file prevents unnecessary files from being sent to the build context:

```gitignore
# .dockerignore
.git
.gitignore
.env
*.md
__pycache__
*.pyc
.pytest_cache
.venv
venv
node_modules
*.egg-info
.mypy_cache
docker-compose*.yml
Dockerfile*
.dockerignore
data/
logs/
*.csv
*.parquet
.DS_Store
```

A large build context slows down every build. If your data directory has 2GB of CSV files, Docker copies ALL of it to the daemon on every `docker build` — even if the Dockerfile doesn't use any of it.

## Labels and Metadata

Add metadata to your images:

```dockerfile
LABEL maintainer="panchalaman@hotmail.com"
LABEL version="1.2.0"
LABEL description="ETL pipeline for data warehouse"
LABEL org.opencontainers.image.source="https://github.com/panchalaman/data-pipeline"
```

```bash
# View labels
docker inspect --format='{{json .Config.Labels}}' my-image
```

## Production Dockerfile Template

Here's a battle-tested template for data engineering:

```dockerfile
# ============================================
# Stage 1: Build
# ============================================
FROM python:3.11-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir=/wheels -r requirements.txt

# ============================================
# Stage 2: Production
# ============================================
FROM python:3.11-slim

LABEL maintainer="panchalaman@hotmail.com"
LABEL version="1.0.0"

# Runtime dependencies only
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 curl && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

# Install Python packages from pre-built wheels
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

# Copy application code
COPY --chown=appuser:appuser src/ ./src/

# Create necessary directories
RUN mkdir -p /app/logs /app/data && chown -R appuser:appuser /app

# Python settings
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "print('healthy')" || exit 1

# Default command
CMD ["python", "src/pipeline.py"]
```

## Production Compose Template

```yaml
# docker-compose.prod.yml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - pg-data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  etl:
    build:
      context: .
      target: production
    env_file:
      - .env.prod
    depends_on:
      db:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
    restart: on-failure
    stop_grace_period: 30s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

secrets:
  db_password:
    file: ./secrets/db_password.txt

volumes:
  pg-data:
```

## Image Scanning

Before pushing to production, scan for vulnerabilities:

```bash
# Docker Scout (built into Docker Desktop)
docker scout quickview my-image:latest
docker scout cves my-image:latest

# Trivy (popular open-source scanner)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image my-image:latest
```

## Quick Checklist

Before deploying to production, verify:

- [ ] Using `slim` or `alpine` base image (not full)
- [ ] Multi-stage build (build tools not in final image)
- [ ] `.dockerignore` excludes unnecessary files
- [ ] No secrets baked into the image
- [ ] Running as non-root user
- [ ] Health checks defined
- [ ] Resource limits set
- [ ] Log size limits configured
- [ ] Graceful shutdown handled
- [ ] Image scanned for vulnerabilities
- [ ] Specific version tags (not just `latest`)
- [ ] `pip install --no-cache-dir` used
- [ ] `apt-get` cache cleaned

---

## Practice Problems

### Beginner

1. Take a Dockerfile you've built in previous lessons. Check its size with `docker images`. Now optimize it:
   - Switch to `python:3.11-slim`
   - Add `--no-cache-dir` to pip install
   - Clean up apt cache
   - Compare the new size

2. Add a health check to a Docker Compose service. Start it and watch the health status change with `docker compose ps`. How long does it take to go from "starting" to "healthy"?

3. Create a `.dockerignore` file for a project. Build the image with and without it. Compare build times (check `docker build` output for "sending build context").

### Intermediate

4. Convert a single-stage Dockerfile to multi-stage:
   - Stage 1: Install gcc and compile Python packages
   - Stage 2: Copy only the installed packages (no gcc)
   - Compare image sizes before and after

5. Set up resource limits for a compose stack:
   - PostgreSQL: max 1GB RAM, 1 CPU
   - ETL: max 2GB RAM, 2 CPUs
   - Run a memory-intensive Python script and verify it gets killed when it exceeds the limit

6. Implement structured JSON logging in a Python pipeline. Run it in Docker and verify the logs are parseable JSON with `docker logs container | python -m json.tool`.

### Advanced

7. Build a production-ready data pipeline using every best practice from this lesson:
   - Multi-stage Dockerfile
   - Non-root user
   - Health checks
   - Graceful shutdown handler
   - Resource limits
   - Log rotation
   - Secret management
   - Image scanning (Docker Scout or Trivy)
   - Measure the final image size

8. Create a CI/CD pipeline that enforces best practices:
   - GitHub Action that builds the image
   - Scans for vulnerabilities (fail if HIGH/CRITICAL found)
   - Checks image size (fail if > 500MB)
   - Runs tests
   - Only then pushes to registry

9. Benchmark your optimizations:
   - Build with full base image vs slim
   - Build with vs without multi-stage
   - Build with vs without `.dockerignore`
   - Build with cold cache vs warm cache
   - Record all times and sizes in a comparison table

---

**Up next:** [Docker Security](15_Security.md) — the final piece: keeping your containers and data safe.

## Resources

- [Dockerfile Best Practices](https://docs.docker.com/build/building/best-practices/) — Official guide
- [Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/) — Complete multi-stage docs
- [Docker Scout](https://docs.docker.com/scout/) — Image vulnerability scanning
- [Trivy Scanner](https://aquasecurity.github.io/trivy/) — Open-source vulnerability scanner
- [12-Factor App](https://12factor.net/) — Industry standard for production apps
