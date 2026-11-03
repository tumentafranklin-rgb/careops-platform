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
## Kubernetes recovery exercise

The application runs with two replicas behind a ClusterIP Service.

I deleted one application Pod to test recovery. Kubernetes created
a replacement Pod while the other replica stayed running.

The Service automatically updated its endpoints to include the
replacement Pod and remove the deleted Pod.

Readiness checks control whether a Pod receives Service traffic.
Liveness checks restart a container after repeated health-check failures.

Both replicas run on one local kind node. This exercise demonstrates
Pod recovery, but does not provide protection against node failure.

## Run locally with Kubernetes

Prerequisites: Docker, kind, and kubectl installed.

Run these commands from the project folder.

Build the application image:

```bash
docker build -t careops-platform:v2 .
```

Create the cluster once:

```bash
kind create cluster --name careops --config k8s/kind-config.yaml --wait 180s
```

Load the image into the cluster:

```bash
kind load docker-image careops-platform:v2 --name careops
```

Apply the application configuration:

```bash
kubectl --context kind-careops apply -f k8s/deployment.yaml
kubectl --context kind-careops apply -f k8s/service.yaml
```

Wait for the Deployment and inspect its Pods:

```bash
kubectl --context kind-careops rollout status deployment/careops-app --timeout=120s
kubectl --context kind-careops get pods -l app=careops
```

Forward a local port to the application selected by the Service:

```bash
kubectl --context kind-careops port-forward service/careops-service 8082:80
```

Leave that terminal running. In another terminal, check health:

```bash
curl -i http://127.0.0.1:8082/health
```

Expected HTTP status: 200 OK

Expected response body:

```json
{"status":"healthy"}
```

Press Ctrl+C in the port-forward terminal when finished.