# Docker Command Reference — What Data Engineers Actually Use

This isn't a list of every Docker command that exists. It's the commands I actually use regularly, organized by how often they come up. If a command isn't here, you probably don't need it for data engineering work.

## Commands You'll Use Every Day

### docker run — Start a Container

```bash
# Basic — run and attach to terminal
docker run python:3.11-slim python -c "print('hello')"

# Detached (background) — most common for databases
docker run -d --name my-postgres -p 5432:5432 -e POSTGRES_PASSWORD=secret postgres:16

# Interactive shell
docker run -it python:3.11-slim bash

# Auto-remove when it exits (great for one-off tasks)
docker run --rm python:3.11-slim python -c "import sys; print(sys.version)"

# The full combo you'll type a hundred times
docker run -d \
    --name warehouse \
    --network pipeline-net \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_DB=warehouse \
    -v pg-data:/var/lib/postgresql/data \
    -p 5432:5432 \
    --restart unless-stopped \
    postgres:16
```

**Flags you need to know:**

| Flag | What It Does | Example |
|------|-------------|---------|
| `-d` | Run in background (detached) | `-d` |
| `-it` | Interactive terminal (for bash/sh) | `-it` |
| `--rm` | Remove container when it stops | `--rm` |
| `--name` | Give the container a name | `--name my-db` |
| `-p` | Map host port to container port | `-p 5432:5432` |
| `-e` | Set environment variable | `-e POSTGRES_PASSWORD=secret` |
| `-v` | Mount volume or bind mount | `-v pg-data:/var/lib/postgresql/data` |
| `--network` | Connect to a Docker network | `--network my-net` |
| `-w` | Set working directory inside container | `-w /app` |
| `--restart` | Restart policy | `--restart unless-stopped` |
| `--env-file` | Load env vars from file | `--env-file .env` |
| `-u` | Run as specific user | `-u $(id -u):$(id -g)` |
| `--memory` | Limit memory | `--memory 2g` |
| `--cpus` | Limit CPU | `--cpus 2.0` |

### docker ps — What's Running?

```bash
# Running containers
docker ps

# All containers (including stopped)
docker ps -a

# Just IDs (useful for scripting)
docker ps -q

# Custom format (cleaner output)
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

# Filter by name
docker ps --filter "name=postgres"

# Filter by status
docker ps --filter "status=exited"
```

### docker stop / start / restart

```bash
# Stop a container (graceful — sends SIGTERM, then SIGKILL after 10s)
docker stop my-postgres

# Stop with custom timeout
docker stop -t 30 my-postgres    # Wait 30 seconds before killing

# Start a stopped container
docker start my-postgres

# Restart
docker restart my-postgres

# Stop all running containers
docker stop $(docker ps -q)
```

### docker rm — Remove Containers

```bash
# Remove a stopped container
docker rm my-postgres

# Force remove (even if running)
docker rm -f my-postgres

# Remove all stopped containers
docker rm $(docker ps -aq --filter "status=exited")

# Stop and remove in one line
docker rm -f my-postgres
```

### docker logs — See What Happened

```bash
# View logs
docker logs my-postgres

# Follow logs (like tail -f)
docker logs -f my-postgres

# Last 50 lines
docker logs --tail 50 my-postgres

# Logs with timestamps
docker logs -t my-postgres

# Logs since a specific time
docker logs --since 2024-01-15T10:00:00 my-postgres
docker logs --since 30m my-postgres    # Last 30 minutes
```

### docker exec — Run Commands Inside a Container

```bash
# Get a shell inside a running container
docker exec -it my-postgres bash

# Run a specific command
docker exec my-postgres pg_isready

# Run psql inside a postgres container
docker exec -it my-postgres psql -U postgres -d warehouse

# Run as a specific user
docker exec -u postgres my-postgres psql -c "SELECT version();"

# Run with environment variable
docker exec -e PGPASSWORD=secret my-postgres psql -U postgres -c "SELECT 1;"
```

## Image Commands

### docker build — Build Images

```bash
# Build from Dockerfile in current directory
docker build -t my-etl:v1 .

# Build with a specific Dockerfile
docker build -f Dockerfile.prod -t my-etl:prod .

# Build with build arguments
docker build --build-arg PYTHON_VERSION=3.12 -t my-etl:v1 .

# Build with no cache (fresh build)
docker build --no-cache -t my-etl:v1 .

# Build a specific target in multi-stage Dockerfile
docker build --target production -t my-etl:prod .

# Build and show full output (not collapsed)
docker build --progress=plain -t my-etl:v1 .

# Build for a specific platform
docker build --platform linux/amd64 -t my-etl:v1 .
```

### docker images — List Images

```bash
# List all images
docker images

# Filter by name
docker images postgres

# Show image IDs only
docker images -q

# Show image sizes (sorted)
docker images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}" | sort -k2 -h

# Show dangling images (untagged)
docker images --filter "dangling=true"
```

### docker pull / push / tag

```bash
# Pull an image
docker pull postgres:16
docker pull python:3.11-slim

# Tag an image (for pushing to a registry)
docker tag my-etl:v1 yourusername/my-etl:v1
docker tag my-etl:v1 ghcr.io/yourusername/my-etl:v1

# Push to registry
docker push yourusername/my-etl:v1

# Login to a registry
docker login                      # Docker Hub
docker login ghcr.io              # GitHub Container Registry
```

### docker rmi — Remove Images

```bash
# Remove a specific image
docker rmi my-etl:v1

# Force remove
docker rmi -f my-etl:v1

# Remove all dangling images
docker rmi $(docker images -q --filter "dangling=true")

# Remove all images (nuclear)
docker rmi $(docker images -q)
```

## Volume Commands

```bash
# Create a named volume
docker volume create pg-data

# List volumes
docker volume ls

# Inspect a volume (see where it lives on disk)
docker volume inspect pg-data

# Remove a volume
docker volume rm pg-data

# Remove all unused volumes (WARNING: permanent!)
docker volume prune

# Remove with no confirmation prompt
docker volume prune -f
```

## Network Commands

```bash
# Create a network
docker network create pipeline-net

# List networks
docker network ls

# Inspect a network (see connected containers)
docker network inspect pipeline-net

# Connect a running container to a network
docker network connect pipeline-net my-postgres

# Disconnect a container from a network
docker network disconnect pipeline-net my-postgres

# Remove a network
docker network rm pipeline-net

# Remove all unused networks
docker network prune
```

## Docker Compose Commands

These are the commands you'll use most. Compose manages multi-container setups from a `docker-compose.yml` file.

```bash
# Start all services
docker compose up -d

# Start and force rebuild images
docker compose up -d --build

# Start specific services only
docker compose up -d db redis

# Stop all services (containers removed, volumes kept)
docker compose down

# Stop and remove volumes too (WARNING: deletes data!)
docker compose down -v

# Stop without removing containers
docker compose stop

# Start previously stopped services
docker compose start

# Restart a specific service
docker compose restart etl

# View running services
docker compose ps

# View logs from all services
docker compose logs

# Follow logs from a specific service
docker compose logs -f db

# Last 100 lines from a service
docker compose logs --tail 100 etl

# Run a one-off command in a service container
docker compose exec db psql -U postgres

# Run a new container from a service definition
docker compose run --rm etl python scripts/migrate.py

# Pull latest images for all services
docker compose pull

# See the fully resolved compose config (after variable substitution)
docker compose config

# Scale a service
docker compose up -d --scale worker=3

# Start with a specific profile
docker compose --profile debug up -d

# Use a different compose file
docker compose -f docker-compose.prod.yml up -d

# Merge multiple compose files
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# See resource usage
docker compose top
```

## Inspection and Debugging

### docker inspect — Get All the Details

```bash
# Full container info (JSON)
docker inspect my-postgres

# Get just the IP address
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' my-postgres

# Get the mounted volumes
docker inspect -f '{{json .Mounts}}' my-postgres | python -m json.tool

# Get environment variables
docker inspect -f '{{json .Config.Env}}' my-postgres | python -m json.tool

# Get health check status
docker inspect -f '{{.State.Health.Status}}' my-postgres

# Get restart count
docker inspect -f '{{.RestartCount}}' my-postgres
```

### docker stats — Live Resource Usage

```bash
# Live CPU/memory for all containers
docker stats

# Specific container
docker stats my-postgres

# One-shot (no streaming)
docker stats --no-stream

# Custom format
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### docker top — Processes Inside a Container

```bash
docker top my-postgres
```

### docker diff — See What Changed in the Filesystem

```bash
# Show files that were added (A), changed (C), or deleted (D)
docker diff my-postgres
```

### docker history — See How an Image Was Built

```bash
# Show all layers and their commands
docker history my-etl:v1

# Full commands (not truncated)
docker history --no-trunc my-etl:v1
```

## Cleanup Commands

Docker accumulates junk fast — stopped containers, dangling images, unused volumes. Clean up regularly.

```bash
# See disk usage overview
docker system df

# Detailed view
docker system df -v

# Remove all stopped containers, unused networks, dangling images, and build cache
docker system prune

# Also remove unused volumes (WARNING: data loss!)
docker system prune --volumes

# Remove ALL unused images (not just dangling)
docker system prune -a

# Just remove stopped containers
docker container prune

# Just remove dangling images
docker image prune

# Remove images older than 24 hours
docker image prune -a --filter "until=24h"

# Just remove unused volumes
docker volume prune

# Just remove unused networks
docker network prune
```

## Copy Files In/Out of Containers

```bash
# Copy from host to container
docker cp ./data.csv my-postgres:/tmp/data.csv

# Copy from container to host
docker cp my-postgres:/var/log/postgresql/postgresql.log ./pg.log

# Copy a whole directory
docker cp ./scripts my-postgres:/tmp/scripts/
```

Useful for quick debugging when you need to grab a log file or drop a script into a running container without rebuilding.

## Save and Load Images (Offline Transfer)

```bash
# Save an image to a tar file
docker save my-etl:v1 -o my-etl-v1.tar

# Load an image from a tar file
docker load -i my-etl-v1.tar

# Export a container's filesystem (different from save — no layers/metadata)
docker export my-container -o container-fs.tar
```

When you need to move images to a machine without internet access (air-gapped environments, some production setups).

## Image Scanning

```bash
# Docker Scout (built into Docker Desktop)
docker scout quickview my-etl:v1
docker scout cves my-etl:v1
docker scout recommendations my-etl:v1

# Trivy (third-party, widely used)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image my-etl:v1

# Only HIGH and CRITICAL
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL my-etl:v1
```

## Buildx — Advanced Builds

```bash
# List buildx builders
docker buildx ls

# Create a new builder (for multi-platform)
docker buildx create --name mybuilder --use

# Build for multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 -t my-etl:v1 --push .

# Build with cache from/to registry
docker buildx build --cache-from type=registry,ref=myrepo/cache --cache-to type=registry,ref=myrepo/cache -t my-etl:v1 .
```

## Less Common but Good to Know

```bash
# See Docker version and system info
docker version
docker info

# Rename a container
docker rename old-name new-name

# Pause/unpause a container (freeze processes)
docker pause my-postgres
docker unpause my-postgres

# Wait for a container to exit and get exit code
docker wait my-etl

# Show port mappings
docker port my-postgres

# Update a running container's config (restart policy, resources)
docker update --restart unless-stopped my-postgres
docker update --memory 4g --cpus 2.0 my-postgres

# View real-time events
docker events
docker events --filter "container=my-postgres"

# Create a container without starting it
docker create --name my-etl my-etl:v1
docker start my-etl
```

---

## Quick Cheat Sheet

The commands that cover 90% of daily work:

```bash
# Start something
docker run -d --name X -p PORT:PORT -e KEY=VAL -v vol:/path image:tag
docker compose up -d

# Check on it
docker ps
docker logs -f X
docker compose logs -f

# Get inside it
docker exec -it X bash
docker compose exec service bash

# Stop it
docker stop X && docker rm X
docker compose down

# Build it
docker build -t name:tag .
docker compose up -d --build

# Clean up
docker system prune
docker volume prune
```

That's it. Everything else is situational.
