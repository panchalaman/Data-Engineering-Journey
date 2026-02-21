# Learn Docker — for Data Engineering

My notes and practice from learning Docker, specifically focused on data engineering workflows. This course goes from absolute basics to production-ready setups — containers, images, Compose, databases, Airflow, CI/CD, security — everything you need to use Docker professionally in data engineering.

## Why Docker for Data Engineering?

Every data engineering job posting lists Docker as a required or preferred skill. It's not optional anymore. Here's why:

- Your ETL pipeline runs the same way on your laptop, your colleague's machine, and in production
- Setting up PostgreSQL, Airflow, Redis, and your pipeline takes one command instead of a day
- You can test against real databases locally without installing anything permanently
- CI/CD pipelines build and deploy your containers automatically
- Kubernetes (the next step) is built entirely around containers

## Course Structure

### Part 1 — Docker Fundamentals

| # | Lesson | What You'll Learn |
|---|--------|------------------|
| 01 | [What Is Docker](01_What_Is_Docker.md) | Why Docker exists, containers vs VMs, core concepts |
| 02 | [Installation & Setup](02_Installation_And_Setup.md) | Install on macOS, Linux, Windows. Verify it works |
| 03 | [Your First Container](03_Your_First_Container.md) | docker run, stop, rm, exec, logs — the daily commands |
| 04 | [Docker Images](04_Docker_Images.md) | Layers, tags, registries, slim vs alpine, image management |
| 05 | [Building Images](05_Building_Images.md) | Dockerfile mastery — FROM, COPY, RUN, CMD, multi-stage builds |

### Part 2 — Core Docker Skills

| # | Lesson | What You'll Learn |
|---|--------|------------------|
| 06 | [Volumes & Storage](06_Volumes_And_Storage.md) | Named volumes, bind mounts, data persistence for databases |
| 07 | [Networking](07_Networking.md) | Bridge networks, container DNS, port mapping, service discovery |
| 08 | [Docker Compose](08_Docker_Compose.md) | Multi-container apps, services, depends_on, profiles |
| 09 | [Environment & Secrets](09_Environment_And_Secrets.md) | ENV, ARG, .env files, Docker secrets, config patterns |

### Part 3 — Docker for Data Engineering

| # | Lesson | What You'll Learn |
|---|--------|------------------|
| 10 | [Data Engineering Pipelines](10_Data_Engineering_Pipelines.md) | Containerized ETL, project structure, development workflow |
| 11 | [Databases in Docker](11_Databases_In_Docker.md) | PostgreSQL, DuckDB, Redis, init scripts, backups |
| 12 | [Airflow with Docker](12_Airflow_With_Docker.md) | Airflow setup, DAGs, connections, scheduling |

### Part 4 — Production & DevOps

| # | Lesson | What You'll Learn |
|---|--------|------------------|
| 13 | [CI/CD & Registry](13_CI_CD_And_Registry.md) | Docker Hub, GHCR, GitHub Actions, automated builds |
| 14 | [Production Best Practices](14_Production_Best_Practices.md) | Multi-stage builds, health checks, logging, resource limits |
| 15 | [Security](15_Security.md) | Non-root users, image scanning, secrets, network isolation |

### Practice Projects

| # | Project | Difficulty | What You'll Build |
|---|---------|-----------|------------------|
| 01 | [Python ETL Pipeline](projects/01_python_etl_pipeline/) | Intermediate | CSV → Python → PostgreSQL with Compose |
| 02 | [Multi-Service Pipeline](projects/02_multi_service_pipeline/) | Advanced | Source DB → ETL → Warehouse with star schema |
| 03 | [Airflow Pipeline](projects/03_airflow_pipeline/) | Advanced | Full Airflow setup with DAGs, multiple databases, quality checks |

## How to Use This Course

**If you're completely new to Docker:** Start at Lesson 01 and work through sequentially. Each lesson builds on the previous one.

**If you know Docker basics:** Jump to Part 2 (Lesson 06) or Part 3 (Lesson 10) depending on your experience.

**If you want hands-on practice:** Every lesson ends with practice problems (Beginner → Intermediate → Advanced) and the three projects at the end bring everything together.

## Prerequisites

- Basic command line skills (cd, ls, mkdir, etc.)
- Python fundamentals (you'll see Python examples throughout)
- Basic SQL knowledge (for database examples)
- A computer where you can install Docker

## What's NOT Covered

- Kubernetes (that's a separate course)
- Docker Swarm (most people use Kubernetes instead)
- Windows containers (Linux containers cover 99% of use cases)
- Every possible Docker command (focused on what data engineers actually use)

## Quick Reference

Commands you'll use daily:

```bash
# Containers
docker run -d --name myapp -p 8080:80 nginx
docker ps                         # List running containers
docker logs -f myapp              # Follow logs
docker exec -it myapp bash        # Shell into container
docker stop myapp && docker rm myapp

# Images
docker build -t myapp:v1 .
docker images
docker pull postgres:16

# Compose
docker compose up -d              # Start everything
docker compose down               # Stop everything
docker compose logs -f            # Follow all logs
docker compose exec db psql -U postgres

# Cleanup
docker system prune               # Remove unused stuff
docker volume prune               # Remove unused volumes
```

## Resources

- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/) — Official image registry
- [Play with Docker](https://labs.play-with-docker.com/) — Free Docker playground in the browser
- [Docker Cheat Sheet](https://docs.docker.com/get-started/docker_cheatsheet.pdf)
- [Airflow Docker Guide](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html)
