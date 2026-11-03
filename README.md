# CareOps Platform

A hands-on DevOps project for a fictional healthcare appointment service.

## Project goal

Learn to build, containerize, deploy, monitor, and troubleshoot an application.

## Planned tools

- Python and Flask for the application
- Git and GitHub for version control
- Docker for containers
- GitHub Actions for continuous integration
- Kubernetes for container orchestration
- Terraform for infrastructure as code
- AWS for cloud hosting

## Data

This project uses fictional data only.

## Build the Docker image

Run this command from the project folder:

```bash
docker build -t careops-platform:v2 .
```

This builds an image containing Python, the application dependencies,
and the application code. The container starts Gunicorn as a non-root user.

## Run the container

Docker must be installed and running.

Start the container:

```bash
docker run -d --name careops-app -p 127.0.0.1:8081:5000 careops-platform:v2
```

If a container named careops-app already exists, use a different name
or stop and remove the existing project container before recreating it.

## Check application health

Run on the machine hosting Docker:

```bash
curl -i http://127.0.0.1:8081/health
```

Expected HTTP status: 200 OK

Expected response body:

```json
{"status":"healthy"}
```

## View container logs

```bash
docker logs careops-app
```