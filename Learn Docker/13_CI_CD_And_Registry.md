# CI/CD and Container Registry

You've been building Docker images locally. That works for development, but at some point you need to:
- Share images with your team
- Deploy to staging/production servers
- Automate builds when code changes

That's what container registries and CI/CD pipelines are for.

## Container Registries

A registry is like GitHub but for Docker images. You push images to it, and anyone with access can pull them.

```
┌────────────────┐      docker push      ┌──────────────────┐
│  Your Machine  │  ──────────────────>  │    Registry      │
│                │                       │                  │
│  my-etl:v1.2   │  <──────────────────  │  my-etl:v1.2     │
│                │      docker pull      │  my-etl:v1.1     │
└────────────────┘                       │  my-etl:latest   │
                                         └──────────────────┘
                                              ↑        ↑
                                         CI/CD      Servers
                                         pushes     pull
```

### Popular Registries

| Registry | Best For | Free Tier |
|----------|---------|-----------|
| **Docker Hub** | Public images, personal projects | Unlimited public, 1 private repo |
| **GitHub Container Registry (ghcr.io)** | GitHub-hosted projects | 500MB free storage |
| **AWS ECR** | AWS deployments | 500MB free (12 months) |
| **Google Artifact Registry** | GCP deployments | 500MB free |
| **Azure Container Registry** | Azure deployments | Basic tier |

## Docker Hub

Docker Hub is the default registry. When you `docker pull python:3.11`, it pulls from Docker Hub.

### Push Your First Image

```bash
# 1. Create a Docker Hub account at hub.docker.com

# 2. Log in from your terminal
docker login
# Enter your Docker Hub username and password

# 3. Tag your image with your Docker Hub username
docker tag my-etl:v1 yourusername/my-etl:v1

# 4. Push
docker push yourusername/my-etl:v1

# 5. Anyone can now pull it
docker pull yourusername/my-etl:v1
```

### Image Naming Convention

```
registry/username/image-name:tag

Examples:
  docker.io/panchalaman/data-pipeline:v1.2     (Docker Hub)
  ghcr.io/panchalaman/data-pipeline:v1.2       (GitHub)
  123456789.dkr.ecr.us-east-1.amazonaws.com/data-pipeline:v1.2  (AWS ECR)
```

When you omit the registry, Docker assumes Docker Hub. When you omit the tag, it assumes `latest`.

### Tagging Strategy

```bash
# Tag with version
docker tag my-etl:latest yourusername/my-etl:v1.2.0

# Tag with git commit SHA (for traceability)
docker tag my-etl:latest yourusername/my-etl:$(git rev-parse --short HEAD)

# Tag with date
docker tag my-etl:latest yourusername/my-etl:2024-01-15

# Multiple tags for the same image
docker tag my-etl:latest yourusername/my-etl:v1.2.0
docker tag my-etl:latest yourusername/my-etl:latest
docker push yourusername/my-etl:v1.2.0
docker push yourusername/my-etl:latest
```

Best practice: always push a specific version tag AND `latest`. Use the version tag in production. Use `latest` for development convenience.

## GitHub Container Registry (ghcr.io)

If your code is on GitHub, this is the natural choice. Images live alongside your code.

```bash
# Log in with a GitHub Personal Access Token
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Tag and push
docker tag my-etl:v1 ghcr.io/panchalaman/my-etl:v1
docker push ghcr.io/panchalaman/my-etl:v1
```

## AWS ECR (Elastic Container Registry)

For AWS deployments:

```bash
# Get login token (requires AWS CLI configured)
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com

# Create repository (first time only)
aws ecr create-repository --repository-name data-pipeline

# Tag and push
docker tag my-etl:v1 123456789.dkr.ecr.us-east-1.amazonaws.com/data-pipeline:v1
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/data-pipeline:v1
```

## CI/CD — Automating Everything

CI/CD means:
- **CI (Continuous Integration)**: Automatically build and test your code on every push
- **CD (Continuous Delivery/Deployment)**: Automatically build images and deploy them

For data engineering, a typical CI/CD pipeline:

```
Code Push → Build Docker Image → Run Tests → Push to Registry → Deploy
```

## GitHub Actions

The most common CI/CD tool for GitHub-hosted repos. You define workflows in `.github/workflows/` as YAML files.

### Basic: Build and Push on Every Push

```yaml
# .github/workflows/docker-build.yml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name == 'push' }}  # Only push on main, not PRs
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/data-pipeline:latest
            ${{ secrets.DOCKER_USERNAME }}/data-pipeline:${{ github.sha }}
```

### Set Up Secrets

In your GitHub repo: Settings → Secrets and variables → Actions → New repository secret:
- `DOCKER_USERNAME` — your Docker Hub username
- `DOCKER_PASSWORD` — your Docker Hub access token (not your password)

### Build and Push to GitHub Container Registry

```yaml
# .github/workflows/ghcr-build.yml
name: Build and Push to GHCR

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

This automatically tags images with branch name, semantic version (from git tags), and commit SHA.

### Full Pipeline: Build, Test, Push

```yaml
# .github/workflows/pipeline.yml
name: Data Pipeline CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_warehouse
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: pytest tests/ -v
        env:
          DB_HOST: localhost
          DB_PASSWORD: test
          DB_NAME: test_warehouse

  build-and-push:
    needs: test    # Only runs if tests pass
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'   # Only on main branch

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/data-pipeline:latest
            ${{ secrets.DOCKER_USERNAME }}/data-pipeline:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

This pipeline:
1. Runs tests against a real PostgreSQL instance (spun up as a GitHub Actions service)
2. Only if tests pass AND it's a push to `main`, builds and pushes the Docker image
3. Uses GitHub Actions build cache for faster builds

## Docker Build Caching in CI

Docker layer caching is critical for CI speed. Without it, every build downloads and installs all dependencies from scratch. With it, unchanged layers are reused.

### GitHub Actions Cache

```yaml
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myapp:latest
    cache-from: type=gha          # Load cache from GitHub
    cache-to: type=gha,mode=max   # Save cache to GitHub
```

### Registry Cache

Use the registry itself as a cache:

```yaml
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myrepo/myapp:latest
    cache-from: type=registry,ref=myrepo/myapp:buildcache
    cache-to: type=registry,ref=myrepo/myapp:buildcache,mode=max
```

## Versioning Strategy

### Semantic Versioning

```
v1.2.3
│ │ │
│ │ └── Patch: bug fixes
│ └──── Minor: new features (backward compatible)
└────── Major: breaking changes
```

```bash
# Create a version tag
git tag v1.2.0
git push origin v1.2.0

# GitHub Actions can trigger on tags
on:
  push:
    tags: ['v*']
```

### Branch-Based Tags

```
main branch    → myapp:latest, myapp:main
develop branch → myapp:develop
feature/xyz    → myapp:feature-xyz
v1.2.0 tag     → myapp:v1.2.0, myapp:1.2, myapp:1
```

## Multi-Architecture Builds

If your team uses both Intel Macs and Apple Silicon (M1/M2/M3), or deploys to ARM-based servers:

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push (multi-arch)
  uses: docker/build-push-action@v5
  with:
    context: .
    platforms: linux/amd64,linux/arm64
    push: true
    tags: myrepo/myapp:latest
```

This builds images for both Intel and ARM architectures. Docker automatically pulls the right one based on the user's platform.

## Local Development Workflow

Here's how CI/CD fits into your daily workflow:

```bash
# 1. Develop locally
docker compose up --build
# Edit code, test, iterate

# 2. Push to feature branch
git checkout -b feature/new-transform
git add . && git commit -m "add salary normalization"
git push origin feature/new-transform

# 3. CI runs tests automatically (GitHub Actions)
# If tests pass, create a pull request

# 4. Merge to main
# CI builds the Docker image and pushes to registry

# 5. Deploy
# Pull the new image on your server/cloud
docker pull myrepo/data-pipeline:latest
docker compose up -d
```

## Automating Deployment

### Simple: SSH and Pull

```yaml
deploy:
  needs: build-and-push
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to server
      uses: appleboy/ssh-action@v1
      with:
        host: ${{ secrets.SERVER_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SSH_KEY }}
        script: |
          cd /opt/data-pipeline
          docker compose pull
          docker compose up -d
```

### Better: Use Watchtower (Auto-Update)

Run Watchtower on your server. It monitors running containers and automatically pulls new images:

```yaml
# On your server's docker-compose.yml
services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 300  # Check every 5 minutes
```

When you push a new `latest` image to the registry, Watchtower detects it and restarts the container with the new image. Zero-touch deployment.

---

## Practice Problems

### Beginner

1. Create a Docker Hub account. Build a simple Python image locally, tag it with your username, and push it. Pull it on a different machine (or after `docker rmi`).

2. Set up a basic GitHub Actions workflow that just builds a Docker image (no push) on every push issue. Verify it runs on GitHub.

3. Tag an image with three different tags (latest, version, git SHA). Push all three. Verify they exist on Docker Hub.

### Intermediate

4. Create a GitHub Actions workflow that:
   - Builds your data pipeline Docker image
   - Runs tests (even just `python -c "import pandas; print('ok')"`)
   - Pushes to Docker Hub only on the `main` branch
   - Uses build caching for faster builds

5. Set up GitHub Container Registry (ghcr.io):
   - Configure the workflow to push to ghcr.io instead of Docker Hub
   - Make the package public
   - Pull the image from ghcr.io on your local machine

6. Implement semantic versioning:
   - Create a workflow that triggers on git tags (v*)
   - Automatically tags the Docker image with the version from the git tag
   - Also tag with `latest`

### Advanced

7. Build a complete CI/CD pipeline for a data engineering project:
   - Lint Python code (flake8 or ruff)
   - Run unit tests against a PostgreSQL service container
   - Build multi-architecture Docker image (amd64 + arm64)
   - Push to registry with proper tags
   - Only deploy on tagged releases

8. Set up automated deployment:
   - Push image to registry from GitHub Actions
   - Configure Watchtower on a server (or local Docker) to auto-pull updates
   - Make a code change, push, and verify the container updates automatically

9. Create a matrix build:
   - Build the same pipeline image with Python 3.10, 3.11, and 3.12
   - Run tests against all three versions
   - Push all three with appropriate tags (e.g., `myapp:v1.0-py3.11`)

---

**Up next:** [Production Best Practices](14_Production_Best_Practices.md) — making your Docker images production-ready.

## Resources

- [GitHub Actions Docker Guide](https://docs.github.com/en/actions/use-cases-and-examples/publishing-packages/publishing-docker-images) — Official guide
- [Docker Build Push Action](https://github.com/docker/build-push-action) — GitHub Action for building and pushing
- [Docker Hub](https://hub.docker.com/) — Public registry
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) — GHCR docs
- [Watchtower](https://containrrr.dev/watchtower/) — Automated container updates
