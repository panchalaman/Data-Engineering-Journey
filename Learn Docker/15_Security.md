# Docker Security

Security isn't the most exciting topic, but it's the difference between a safe production deployment and a headline about leaked data. In data engineering, you're handling databases, credentials, and potentially sensitive datasets. Getting security right matters.

## The Attack Surface

When you run Docker, there are several layers that can be compromised:

```
┌────────────────────────────────────────┐
│ 1. The Image    — What's baked in?     │
│ 2. The Runtime  — How is it running?   │
│ 3. The Host     — What can it access?  │
│ 4. The Network  — What can it reach?   │
│ 5. The Data     — How are secrets handled? │
└────────────────────────────────────────┘
```

## 1. Run as Non-Root

By default, containers run as root. If someone exploits a vulnerability in your application, they get root access inside the container — and potentially to the host.

```dockerfile
# BAD — running as root (default)
FROM python:3.11-slim
COPY app.py .
CMD ["python", "app.py"]
# Process runs as root inside the container

# GOOD — create and use a non-root user
FROM python:3.11-slim

RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app
COPY --chown=appuser:appuser . .

USER appuser

CMD ["python", "app.py"]
# Process runs as appuser — much safer
```

### Gotcha: File Permissions

When you switch to a non-root user, make sure the user can access the files it needs:

```dockerfile
# Install as root (needs write access to system dirs)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create directories the app needs
RUN mkdir -p /app/logs /app/data && \
    chown -R appuser:appuser /app

# THEN switch to non-root
USER appuser

COPY --chown=appuser:appuser src/ ./src/
```

### Verify It Works

```bash
docker run --rm my-image whoami
# Output: appuser (not root)

docker run --rm my-image id
# Output: uid=1000(appuser) gid=1000(appuser)
```

## 2. Use Minimal Base Images

More software in the image = more potential vulnerabilities.

```
python:3.11      — 1 GB, 500+ packages, 100+ known CVEs
python:3.11-slim — 150 MB, minimal packages, ~20 CVEs
python:3.11-alpine — 50 MB, musl libc, ~5 CVEs
distroless/python3 — 50 MB, no shell at all, ~2 CVEs
```

For data engineering, `python:3.11-slim` is the practical choice. Alpine has compatibility issues with many Python data packages. Distroless is the most secure but harder to debug (no shell access).

### Google Distroless (Maximum Security)

```dockerfile
# Build stage
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/app/deps -r requirements.txt
COPY src/ ./src/

# Production stage — no shell, no package manager, nothing
FROM gcr.io/distroless/python3-debian12
COPY --from=builder /app /app
WORKDIR /app
ENV PYTHONPATH=/app/deps
CMD ["src/pipeline.py"]
```

You can't `docker exec` into a distroless container because there's no shell. That's the point — if an attacker gets in, there's nothing to exploit.

## 3. Scan Images for Vulnerabilities

### Docker Scout

```bash
# Quick overview
docker scout quickview my-image:latest

# Detailed CVE report
docker scout cves my-image:latest

# Compare two versions
docker scout compare my-image:v1 --to my-image:v2
```

### Trivy

```bash
# Scan an image
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image my-image:latest

# Only show HIGH and CRITICAL
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image --severity HIGH,CRITICAL my-image:latest

# Scan and fail if vulnerabilities found (for CI)
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image --exit-code 1 --severity CRITICAL my-image:latest
```

### During CI/CD

```yaml
# GitHub Actions
- name: Scan for vulnerabilities
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: my-image:${{ github.sha }}
    severity: CRITICAL,HIGH
    exit-code: 1    # Fail the build if vulnerabilities found
```

## 4. Keep Images Updated

Base images get security patches regularly. Pin to a specific minor version but update regularly:

```dockerfile
# Pin to minor version (gets patch updates)
FROM python:3.11-slim

# Don't do this — gets ALL updates, including breaking ones
FROM python:latest

# Too specific — misses security patches
FROM python:3.11.7-slim-bookworm
```

Set up Dependabot or Renovate to automatically create PRs when base images are updated.

## 5. Don't Store Secrets in Images

This cannot be stressed enough. Every layer in a Docker image can be inspected.

```bash
# Anyone can see what's in your image
docker history my-image
docker inspect my-image
```

### What NOT to Do

```dockerfile
# NEVER — secret in ENV
ENV API_KEY=sk-abc123def456

# NEVER — secret in COPY
COPY credentials.json /app/

# NEVER — secret in ARG (visible in history)
ARG DB_PASSWORD=mysecret
RUN configure-db --password=$DB_PASSWORD

# NEVER — secret downloaded and "deleted"
RUN curl -H "Authorization: Bearer sk-abc123" https://api.example.com/config > /app/config
RUN rm /app/config    # Still in the previous layer!
```

### What TO Do

```dockerfile
# Pass secrets at runtime
# docker run -e API_KEY=$API_KEY my-image

# Or use Docker secrets (compose/swarm)
# Mounted at /run/secrets/ — never in the image
```

### BuildKit Secrets (For Build-Time Secrets)

If you need a secret during build (like accessing a private Python package):

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.11-slim

# Mount the secret — it never gets stored in a layer
RUN --mount=type=secret,id=pip_token \
    pip install --no-cache-dir \
    --extra-index-url https://$(cat /run/secrets/pip_token)@pypi.private.com/simple \
    my-private-package
```

```bash
docker build --secret id=pip_token,src=./pip_token.txt -t my-image .
```

The secret is available during build but NOT stored in any layer.

## 6. Read-Only Filesystem

If your container doesn't need to write to the filesystem, make it read-only:

```bash
docker run --read-only my-image
```

```yaml
services:
  etl:
    image: my-etl
    read_only: true
    tmpfs:
      - /tmp         # Allow writing to /tmp only
    volumes:
      - ./output:/app/output   # Allow writing to specific directory
```

If an attacker gets in, they can't write malware to the filesystem.

## 7. Drop Capabilities

Linux capabilities are fine-grained permissions. Containers get many by default. Drop the ones you don't need.

```bash
# Drop all capabilities, add only what's needed
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE my-image
```

```yaml
services:
  etl:
    image: my-etl
    cap_drop:
      - ALL
    cap_add:
      - NET_RAW      # Only if needed (e.g., for pinging)
```

For most data engineering containers, you don't need ANY extra capabilities.

## 8. Network Security

### Principle of Least Privilege

Only expose what needs to be exposed:

```yaml
services:
  # Database — accessible only within Docker network
  db:
    image: postgres:16
    # NO ports mapping — not accessible from host
    networks:
      - backend

  # ETL — internal only
  etl:
    build: .
    networks:
      - backend

  # API — exposed to host
  api:
    build: ./api
    ports:
      - "8080:8080"
    networks:
      - backend
      - frontend

networks:
  backend:     # Internal — db and etl
    internal: true    # Can't reach the internet
  frontend:    # External — can reach internet
```

The `internal: true` flag means containers on that network cannot access the internet. Your database doesn't need internet access.

### Bind to Localhost

When exposing ports, bind to localhost to prevent access from other machines:

```yaml
ports:
  - "127.0.0.1:5432:5432"    # Only accessible from this machine
  # NOT "5432:5432"           # Accessible from anywhere on the network
```

## 9. Docker Socket Security

The Docker socket (`/var/run/docker.sock`) gives full control over Docker. Mounting it into a container is extremely dangerous.

```yaml
# DANGEROUS — avoid unless absolutely necessary
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

Any container with access to the Docker socket can:
- Start new containers
- Access all volumes
- Essentially has root access to the host

If you must mount it (e.g., for Watchtower), make it read-only and use a proxy like docker-socket-proxy:

```yaml
services:
  docker-proxy:
    image: tecnativa/docker-socket-proxy
    environment:
      CONTAINERS: 1
      IMAGES: 1
      # Only allow listing containers and images
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - docker-internal

  watchtower:
    image: containrrr/watchtower
    environment:
      DOCKER_HOST: tcp://docker-proxy:2375
    networks:
      - docker-internal

networks:
  docker-internal:
    internal: true
```

## 10. Content Trust (Image Signing)

Docker Content Trust ensures you're pulling images that haven't been tampered with:

```bash
# Enable content trust
export DOCKER_CONTENT_TRUST=1

# Now docker pull only accepts signed images
docker pull postgres:16    # Works — official images are signed
docker pull suspicious/image:latest  # Fails if not signed
```

## Security Checklist

For every production deployment, verify:

```
Image Security:
  [ ] Using slim/alpine base image
  [ ] Image scanned for CVEs (docker scout / trivy)
  [ ] Base image is up to date
  [ ] No secrets baked in
  [ ] Multi-stage build (no build tools in final image)

Runtime Security:
  [ ] Running as non-root user
  [ ] Read-only filesystem where possible
  [ ] Capabilities dropped
  [ ] Resource limits set (CPU/memory)

Network Security:
  [ ] Only necessary ports exposed
  [ ] Ports bound to 127.0.0.1 (not 0.0.0.0)
  [ ] Internal networks for backend services
  [ ] Database not exposed to host (unless needed for dev tools)

Secret Management:
  [ ] Using .env files (gitignored) or Docker secrets
  [ ] No hardcoded credentials
  [ ] Build-time secrets use BuildKit --mount=type=secret
  [ ] Connection strings not logged

Infrastructure:
  [ ] Docker socket not mounted (or proxied)
  [ ] Docker Content Trust enabled
  [ ] Log rotation configured
  [ ] Regular image updates scheduled
```

## Real-World Secure Data Pipeline

Putting it all together:

```dockerfile
# Dockerfile.prod
FROM python:3.11-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir=/wheels -r requirements.txt

FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 && \
    rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash etluser

WORKDIR /app

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

COPY --chown=etluser:etluser src/ ./src/
RUN mkdir -p /app/logs && chown etluser:etluser /app/logs

USER etluser

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "print('ok')" || exit 1

CMD ["python", "src/pipeline.py"]
```

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
    networks:
      - backend
    deploy:
      resources:
        limits:
          memory: 2G
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETUID
      - SETGID
    logging:
      options:
        max-size: "10m"
        max-file: "3"

  etl:
    build:
      context: .
      dockerfile: Dockerfile.prod
    env_file:
      - .env.prod
    secrets:
      - db_password
    networks:
      - backend
    depends_on:
      db:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
    read_only: true
    tmpfs:
      - /tmp
    volumes:
      - ./logs:/app/logs
    restart: on-failure
    stop_grace_period: 30s
    cap_drop:
      - ALL
    logging:
      options:
        max-size: "10m"
        max-file: "3"

secrets:
  db_password:
    file: ./secrets/db_password.txt

networks:
  backend:
    internal: true

volumes:
  pg-data:
```

---

## Practice Problems

### Beginner

1. Take any Dockerfile from previous lessons. Add a non-root user and switch to it. Verify with `docker run --rm my-image whoami`.

2. Scan one of your images with Docker Scout (`docker scout cves my-image`). How many vulnerabilities are found? What severity levels?

3. Run a container with `--read-only`. Try to write a file inside it. What happens? Now add a `tmpfs` mount and try writing to that path.

### Intermediate

4. Create a secure PostgreSQL setup:
   - Database password via Docker secrets (not environment variable)
   - Database on an internal network (no port mapping)
   - ETL container on the same internal network
   - Verify the database is NOT accessible from the host machine
   - Verify the ETL container CAN reach the database

5. Run `docker history your-image` on an image that has secrets baked in (for testing). See how the secret is visible. Now rebuild using BuildKit `--mount=type=secret` and verify the secret is NOT in the history.

6. Set up a compose stack with proper capabilities:
   - Drop ALL capabilities from every container
   - Add back only the minimum required
   - Verify everything still works

### Advanced

7. Build the most secure data pipeline possible:
   - Distroless final image (no shell)
   - Non-root user
   - Read-only filesystem
   - All capabilities dropped
   - Internal network for database
   - Secrets via Docker secrets
   - Resource limits
   - Health checks
   - Image scanning in CI (fail on CRITICAL)

8. Implement a complete security audit:
   - Scan all your project's images with Trivy
   - Check for leaked secrets with `docker history`
   - Verify non-root users across all containers
   - Test network isolation (container on internal network can't reach the internet)
   - Document findings and fixes

9. Set up Docker Content Trust:
   - Enable `DOCKER_CONTENT_TRUST=1`
   - Sign and push an image
   - Verify that unsigned images are rejected
   - Set up a CI pipeline that only deploys signed images

---

## You Made It

This is the last lesson. If you've worked through all 15 lessons, you now know Docker at a level that most data engineers in the industry operate at — and then some.

Here's what you can now do:
- Containerize any Python data pipeline
- Set up multi-service environments with Compose
- Run databases, Airflow, and complete data stacks in Docker
- Build production-ready images (small, secure, fast)
- Automate builds with CI/CD
- Handle secrets, networking, and security properly

The only thing left is to practice. Go build something. Containerize a real project. Break things. Fix them. That's how you actually learn.

Keep building.

## Resources

- [Docker Security Best Practices](https://docs.docker.com/build/building/best-practices/) — Official guide
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) — Industry security standard
- [Docker Content Trust](https://docs.docker.com/engine/security/trust/) — Image signing
- [Trivy](https://aquasecurity.github.io/trivy/) — Vulnerability scanning
- [Docker Scout](https://docs.docker.com/scout/) — Built-in scanning
- [Snyk Container](https://snyk.io/product/container-vulnerability-management/) — Another scanning option
- [OWASP Docker Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) — Security cheat sheet
