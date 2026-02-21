# Docker Compose

Remember the last lesson where we were running three containers with individual `docker run` commands, each with flags for networks, volumes, ports, and environment variables? Now imagine doing that for 5 services. Every single day. And making sure the network name, volume names, and environment variables are consistent across all of them.

That's unsustainable. Docker Compose solves this.

## What Docker Compose Does

Docker Compose lets you define your entire multi-container setup in a single YAML file (`docker-compose.yml`). One command starts everything. One command stops everything. All the networking, volumes, and configuration are declared in one place.

```
Without Compose:
  docker network create ...
  docker volume create ...
  docker run --name db --network ... -e ... -v ... postgres:16
  docker run --name redis --network ... redis:7
  docker run --name app --network ... -v ... -e ... my-app
  (repeat for every service, remember all the flags, pray you don't typo)

With Compose:
  docker compose up
  (done)
```

## Your First docker-compose.yml

Create a file called `docker-compose.yml`:

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: warehouse
    ports:
      - "5432:5432"
    volumes:
      - pg-data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  pg-data:
```

Now run it:

```bash
docker compose up -d
```

That's it. Two containers running, connected on a shared network, with a persistent volume for Postgres. Let me break this down.

## Anatomy of docker-compose.yml

```yaml
services:          # Define your containers here (called "services")
  db:              # Service name — also becomes the DNS hostname
    image: ...     # Which image to use
    environment:   # Environment variables
    ports:         # Port mapping (host:container)
    volumes:       # Volume mounts
    depends_on:    # Start order dependencies
    build:         # Build from Dockerfile instead of pulling image
    command:       # Override the default command
    restart:       # Restart policy

volumes:           # Named volumes used by services
networks:          # Custom networks (optional — Compose creates one by default)
```

### Services

Each service is a container. The service name becomes the DNS hostname on the Compose network. So in the example above, the Python container can connect to Postgres using host `db` and Redis using host `redis`.

### Automatic Networking

Compose creates a network automatically. All services in the same `docker-compose.yml` are on it. You don't need to create or manage networks — it's handled for you.

```yaml
services:
  app:
    image: my-app
    # Can reach "db" and "redis" by name — no extra config needed

  db:
    image: postgres:16

  redis:
    image: redis:7
```

Inside the `app` container:
- `db:5432` reaches PostgreSQL
- `redis:6379` reaches Redis

## Essential Commands

```bash
# Start all services (detached mode)
docker compose up -d

# Start and rebuild images
docker compose up -d --build

# Stop all services
docker compose down

# Stop and remove volumes too (WARNING: deletes database data!)
docker compose down -v

# View running services
docker compose ps

# View logs
docker compose logs

# Follow logs from a specific service
docker compose logs -f db

# Run a one-off command in a service
docker compose exec db psql -U postgres

# Restart a specific service
docker compose restart app

# Scale a service (run multiple instances)
docker compose up -d --scale worker=3

# Pull latest images
docker compose pull
```

### up vs down vs stop

| Command | What It Does |
|---------|------------|
| `docker compose up -d` | Creates and starts containers, networks, volumes |
| `docker compose stop` | Stops containers (keeps them and their data) |
| `docker compose start` | Starts previously stopped containers |
| `docker compose down` | Stops AND removes containers and networks (volumes preserved) |
| `docker compose down -v` | Stops, removes containers, networks, AND volumes |

## Building Custom Images in Compose

Instead of pulling a pre-built image, you can build from a Dockerfile:

```yaml
services:
  etl:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ./data:/app/data
    depends_on:
      - db

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
```

Now `docker compose up --build` builds your ETL image and starts everything.

### Build Context Options

```yaml
services:
  app:
    build:
      context: ./app          # Build context directory
      dockerfile: Dockerfile  # Dockerfile path (relative to context)
      args:                   # Build arguments
        PYTHON_VERSION: "3.11"
      target: production      # Multi-stage build target
```

## depends_on — Service Startup Order

`depends_on` controls the order services start in. But there's a catch.

```yaml
services:
  app:
    build: .
    depends_on:
      - db
      - redis
    # app starts AFTER db and redis containers are created

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret

  redis:
    image: redis:7
```

The catch: `depends_on` only waits for the container to START. It doesn't wait for the service inside to be READY. PostgreSQL might take a few seconds after the container starts to actually accept connections.

### Waiting for Services to Be Ready

Use `depends_on` with `condition`:

```yaml
services:
  app:
    build: .
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
```

Now `app` waits until Postgres actually responds to `pg_isready` before starting. This is the right way to handle dependencies.

## Environment Variables

### Inline

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: warehouse
      POSTGRES_USER: pipeline
```

### From a .env File

Create a `.env` file in the same directory:

```env
POSTGRES_PASSWORD=super_secret_password
POSTGRES_DB=warehouse
POSTGRES_USER=pipeline
```

Reference in compose:

```yaml
services:
  db:
    image: postgres:16
    env_file:
      - .env
```

This is better for secrets — you add `.env` to `.gitignore` so passwords don't end up in your repo.

### Variable Substitution

You can use environment variables from your shell in the compose file:

```yaml
services:
  db:
    image: postgres:${POSTGRES_VERSION:-16}  # Default to 16 if not set
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
```

```bash
DB_PASSWORD=mysecret docker compose up -d
```

## Volumes in Compose

### Named Volumes

```yaml
services:
  db:
    image: postgres:16
    volumes:
      - pg-data:/var/lib/postgresql/data

volumes:
  pg-data:    # Declare named volumes at the top level
```

### Bind Mounts

```yaml
services:
  app:
    build: .
    volumes:
      - ./src:/app/src          # Bind mount for development
      - ./data:/app/data:ro     # Read-only bind mount
```

### Mixed (Common Pattern)

```yaml
services:
  app:
    build: .
    volumes:
      - ./src:/app/src                # Code: bind mount (for live editing)
      - app-deps:/app/.venv           # Dependencies: named volume (for speed)
      - ./data/raw:/app/input:ro      # Input data: read-only bind mount

volumes:
  app-deps:
```

## Networks in Compose

Compose creates a default network, but you can define custom networks:

```yaml
services:
  api:
    image: my-api
    networks:
      - frontend
      - backend

  db:
    image: postgres:16
    networks:
      - backend

  nginx:
    image: nginx
    networks:
      - frontend
    ports:
      - "80:80"

networks:
  frontend:
  backend:
```

Here `db` is only accessible from `backend`. `nginx` can't reach `db` directly. `api` bridges both networks.

## Real-World DE Compose File

Here's a realistic data engineering development setup:

```yaml
# docker-compose.yml
services:
  # Source database (simulating production)
  source-db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: source_pass
      POSTGRES_DB: production
    volumes:
      - source-data:/var/lib/postgresql/data
      - ./init/source_schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Target data warehouse
  warehouse:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: wh_pass
      POSTGRES_DB: warehouse
    ports:
      - "5432:5432"    # Expose so you can connect from DBeaver/pgAdmin
    volumes:
      - wh-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  # ETL pipeline
  etl:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      SOURCE_HOST: source-db
      SOURCE_DB: production
      SOURCE_PASSWORD: source_pass
      TARGET_HOST: warehouse
      TARGET_DB: warehouse
      TARGET_PASSWORD: wh_pass
    volumes:
      - ./src:/app/src          # Live code changes
      - ./data:/app/data        # Data files
      - ./logs:/app/logs        # Log output
    depends_on:
      source-db:
        condition: service_healthy
      warehouse:
        condition: service_healthy

  # pgAdmin for database management (optional)
  pgadmin:
    image: dpage/pgadmin4
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@admin.com
      PGADMIN_DEFAULT_PASSWORD: admin
    ports:
      - "8080:80"
    depends_on:
      - warehouse

volumes:
  source-data:
  wh-data:
```

Start the entire pipeline:

```bash
docker compose up -d
```

What you get:
- Source database with schema loaded from SQL file
- Target warehouse accessible on port 5432
- ETL container that runs only after both databases are healthy
- pgAdmin UI on port 8080 for visual database management
- Persistent data via named volumes
- Live code editing via bind mount on `./src`

## Multiple Compose Files

You can have different configurations for development and production:

```bash
docker-compose.yml          # Base configuration
docker-compose.dev.yml      # Development overrides
docker-compose.prod.yml     # Production overrides
```

```yaml
# docker-compose.yml (base)
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
```

```yaml
# docker-compose.dev.yml
services:
  db:
    ports:
      - "5432:5432"     # Expose in dev, not in prod

  app:
    volumes:
      - ./src:/app/src  # Live reload in dev
```

```bash
# Dev: merge base + dev overrides
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Prod: merge base + prod overrides
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Compose Profiles

Group services that aren't always needed:

```yaml
services:
  db:
    image: postgres:16
    # Always starts (no profile)

  etl:
    build: .
    depends_on: [db]
    # Always starts

  pgadmin:
    image: dpage/pgadmin4
    profiles: ["debug"]
    # Only starts when you ask for it

  test-runner:
    build: .
    command: pytest
    profiles: ["test"]
```

```bash
# Normal — only db and etl start
docker compose up -d

# Include debugging tools
docker compose --profile debug up -d

# Run tests
docker compose --profile test up -d
```

## Watch Mode (Compose Watch)

Docker Compose v2.22+ has a `watch` feature for development. It automatically syncs code changes and rebuilds when needed:

```yaml
services:
  app:
    build: .
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
        - action: rebuild
          path: requirements.txt
```

```bash
docker compose watch
```

Now when you edit files in `./src`, they sync to the container instantly. When you change `requirements.txt`, the container rebuilds automatically.

## Debugging Compose Issues

```bash
# See full configuration (after variable substitution)
docker compose config

# See logs for a specific service
docker compose logs -f etl

# Get a shell inside a running service
docker compose exec db bash

# Check service health
docker compose ps

# See resource usage
docker compose top
```

---

## Practice Problems

### Beginner

1. Create a `docker-compose.yml` that runs:
   - PostgreSQL with a named volume and port 5432 exposed
   - Redis with port 6379 exposed
   
   Start it with `docker compose up -d`. Verify both are running with `docker compose ps`. Connect to PostgreSQL from your host machine.

2. Add a `healthcheck` to the PostgreSQL service in your compose file. Use `docker compose ps` to see the health status change from "starting" to "healthy".

3. Stop your services with `docker compose down`. Start them again with `docker compose up -d`. Verify your PostgreSQL data survived (it should, because of the named volume). Now try `docker compose down -v`. What happens to the data?

### Intermediate

4. Create a compose file with:
   - PostgreSQL as database
   - A Python service that builds from a local Dockerfile
   - The Python service should use `depends_on` with `condition: service_healthy` to wait for PostgreSQL
   - The Python service should create a table and insert a row

5. Create a `.env` file with database credentials. Use `env_file` in your compose file to load them. Verify the variables are applied with `docker compose exec db env`.

6. Create a compose setup with two networks:
   - `frontend` network with an nginx service
   - `backend` network with PostgreSQL
   - An API service connected to both networks
   - Verify that nginx CANNOT reach PostgreSQL directly

### Advanced

7. Build a complete ETL pipeline in Compose:
   - Source PostgreSQL with sample data (loaded via SQL file in `/docker-entrypoint-initdb.d/`)
   - Target PostgreSQL (empty warehouse)
   - Python ETL container that extracts from source, transforms, and loads to target
   - pgAdmin for monitoring
   - All with proper health checks, named volumes, and `.env` for credentials

8. Create a multi-environment setup:
   - `docker-compose.yml` (base)
   - `docker-compose.dev.yml` (expose all ports, bind mount source code)
   - `docker-compose.prod.yml` (no exposed ports except the app, no bind mounts)
   - Use profiles to optionally include monitoring tools

9. Set up Compose with a `watch` configuration. Make code changes and observe automatic syncing and rebuilding. Compare this workflow to manually rebuilding with `docker compose up --build`.

---

**Up next:** [Environment Variables and Secrets](09_Environment_And_Secrets.md) — because hardcoding passwords in compose files is a terrible idea.

## Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/) — Complete reference
- [Compose File Reference](https://docs.docker.com/reference/compose-file/) — Every option available
- [Compose Watch](https://docs.docker.com/compose/how-tos/file-watch/) — Auto-sync and rebuild
- [Compose Profiles](https://docs.docker.com/compose/how-tos/profiles/) — Selective service startup
- [Networking in Compose](https://docs.docker.com/compose/how-tos/networking/) — How Compose handles networking
