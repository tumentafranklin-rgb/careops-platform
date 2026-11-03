# CareOps Platform

A hands-on DevOps project for a fictional healthcare appointment service.
The application currently provides a welcome endpoint and a health endpoint.
It uses fictional data only.

## Project goal

Learn to build, test, containerize, deploy, monitor, and troubleshoot an application.

## Implemented features

- Python application using Flask
- Automated health endpoint test using pytest
- Docker image running Gunicorn as a non-root user
- GitHub Actions workflow for tests, image builds, and container smoke tests
- Local Kubernetes cluster using kind
- Deployment with two replicas
- ClusterIP Service
- Readiness and liveness probes
- CPU and memory requests and limits
- Pod recovery, rolling update, and rollback exercises

## Planned work

- Infrastructure as code using Terraform
- AWS deployment
- Additional application features and monitoring

## Project structure

```text
careops-platform/
├── .github/
│   └── workflows/
│       └── ci.yml
├── k8s/
│   ├── kind-config.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── .dockerignore
├── .gitignore
├── app.py
├── Dockerfile
├── README.md
├── requirements.txt
├── requirements-dev.txt
└── test_app.py
```

## Prerequisites

The commands below are intended for Linux.

- Python 3.14 with pip and virtual environment support
- Git
- Docker installed and running
- kind and kubectl for Kubernetes exercises
- Internet access for downloading dependencies and images

Run commands from the project folder unless stated otherwise.

## Run locally with Python

Create a virtual environment once:

```bash
python3 -m venv .venv
```

Activate it in your terminal:

```bash
source .venv/bin/activate
```

Install the application dependencies:

```bash
python -m pip install -r requirements.txt
```

Start the development server:

```bash
python -m flask --app app run
```

Leave that terminal running. In another terminal, test the application:

```bash
curl -i http://127.0.0.1:5000/
curl -i http://127.0.0.1:5000/health
```

The Flask development server is for local development.
The Docker image uses Gunicorn.

Press Ctrl+C in the server terminal to stop it.

## Application endpoints

### GET /

Returns a welcome message and the current application version:

```json
{"message":"Welcome to CareOps Platform","version":"v3"}
```

### GET /health

Returns HTTP 200 with:

```json
{"status":"healthy"}
```

This endpoint checks whether the application can respond.
It does not check an external database or other dependencies.

## Run automated tests

Activate the virtual environment:

```bash
source .venv/bin/activate
```

Install application and testing dependencies:

```bash
python -m pip install -r requirements-dev.txt
```

Run tests:

```bash
python -m pytest -v
```

The health endpoint test checks the HTTP status and JSON response.

Flask's test client runs requests directly against the application.
A running web server is not required for this test.

## Build the Docker image

```bash
docker build -t careops-platform:v3 .
```

The image contains Python, the application dependencies, and application code.
It starts Gunicorn with two workers and runs as appuser with UID 10001.

The .dockerignore file excludes local environments, Git history,
generated Python files, test caches, and the local .env file.

## Run with Docker

Start a container:

```bash
docker run -d --name careops-app -p 127.0.0.1:8081:5000 careops-platform:v3
```

Port 8081 on the Docker host forwards to port 5000 inside the container.
The published port is bound to the host's loopback address.

If careops-app already exists, inspect it first:

```bash
docker ps -a --filter name=careops-app
```

To replace this project's existing container:

```bash
docker stop careops-app
docker rm careops-app
```

Then run the docker run command again.

Check the application from the Docker host:

```bash
curl -i http://127.0.0.1:8081/
curl -i http://127.0.0.1:8081/health
```

View logs:

```bash
docker logs careops-app
```

Verify the container user:

```bash
docker exec careops-app id
```

Expected user ID: 10001.

Stop the container when finished:

```bash
docker stop careops-app
```

## Continuous integration

The workflow is defined in .github/workflows/ci.yml.

It runs on pushes to main and pull requests targeting main.

The workflow:

1. Checks out the repository.
2. Sets up Python 3.14.
3. Installs development dependencies.
4. Runs pytest.
5. Builds careops-platform:ci.
6. Starts a test container.
7. Checks the container's health endpoint with bounded retries.
8. Displays container logs, even when an earlier step fails.
9. Removes the test container.

The workflow builds and tests the image on GitHub's runner.
It does not publish the image or deploy it to Kubernetes.

## Run locally with Kubernetes

The configuration creates a single-node kind cluster.
Both application replicas run on that node.

Build the application image:

```bash
docker build -t careops-platform:v3 .
```

Create the cluster once:

```bash
kind create cluster --name careops --config k8s/kind-config.yaml --wait 180s
```

For an existing cluster, check its node:

```bash
kubectl --context kind-careops get nodes
```

Load the image into the cluster:

```bash
kind load docker-image careops-platform:v3 --name careops
```

The Deployment uses imagePullPolicy: Never, so its image must already
be present on the kind node.

Apply the application files individually:

```bash
kubectl --context kind-careops apply -f k8s/deployment.yaml
kubectl --context kind-careops apply -f k8s/service.yaml
```

kind-config.yaml configures kind itself. It is not a Kubernetes
resource to apply with kubectl.

Wait for the Deployment:

```bash
kubectl --context kind-careops rollout status deployment/careops-app --timeout=120s
```

Inspect the Pods and Service:

```bash
kubectl --context kind-careops get pods -l app=careops -o wide
kubectl --context kind-careops get service careops-service
kubectl --context kind-careops get endpointslices -l kubernetes.io/service-name=careops-service
```

Expect two ready application Pods and corresponding ready Service backends.

## Access the Kubernetes application

Start port forwarding:

```bash
kubectl --context kind-careops port-forward service/careops-service 8082:80
```

Leave that terminal running. In another terminal:

```bash
curl -i http://127.0.0.1:8082/
curl -i http://127.0.0.1:8082/health
```

Expect HTTP 200. The home endpoint should report version v3.

Port forwarding selects a Pod through the Service.
It does not test the Service's ClusterIP traffic distribution.

After a rollout or Pod replacement, restart port forwarding if its
selected Pod has terminated.

Press Ctrl+C in the port-forward terminal when finished.

## Kubernetes health checks

Both probes request /health on port 5000.

### Readiness

- Initial delay: 3 seconds
- Check interval: 5 seconds
- Default failure threshold: 3 consecutive failures

Readiness determines whether the Pod is eligible to receive
normal Service traffic. Readiness failures do not restart the container.

### Liveness

- Initial delay: 10 seconds
- Check interval: 10 seconds
- Failure threshold: 3 consecutive failures

Repeated liveness failures cause Kubernetes to restart the container.

## Resource settings

Each application container has these settings:

| Resource | Request | Limit |
| --- | --- | --- |
| CPU | 100m (0.1 CPU) | 500m (0.5 CPU) |
| Memory | 64Mi | 256Mi |

Kubernetes uses requests for scheduling.
CPU limits can throttle CPU usage.
Exceeding the memory limit can cause the container to be terminated.

These are initial learning-project values and require measurement
and tuning for a real workload.

The Pod's quality-of-service class is Burstable.

## Completed troubleshooting exercises

### Test failures

I deliberately changed a test's expected status from 200 to 201.
Pytest reported an assertion failure.

I also corrected a Python syntax error and reran the test successfully.

### Container startup timing in CI

A container health request failed with a connection reset.
I updated the bounded retry settings to include connection resets.
The next workflow run passed.

### Readiness failure

I temporarily changed the readiness path to /not-ready.

The new Pod remained Running but unready without restarting.
The previous healthy Pod stayed available during the blocked rollout.

I restored the readiness path to /health afterward.

### Liveness failure

A liveness probe using /not-ready received HTTP 404 responses.
Kubernetes recorded failed probes and restarted the container.

I restored the liveness path to /health afterward.

### Pod recovery

With two replicas configured, I deleted one application Pod.

Kubernetes created a replacement while the other Pod stayed running.
The Service's EndpointSlice updated to include the replacement Pod IP
and remove the deleted Pod IP.

Both replicas share one local node. This demonstrates Pod recovery,
but does not protect against node failure.

### Rolling update and rollback

I built and loaded v3, updated the Deployment, and verified that both
Pods used v3. The home endpoint returned "version": "v3".

I inspected the revision history and verified the previous v2 template.
In this exercise, the rollback target was revision 8.

I rolled back to v2 and verified the original response without a version field.
Finally, I reapplied the saved Deployment file to restore v3.

A rollback changes the live cluster, not the configuration stored in Git.
Revision numbers are specific to a cluster's Deployment history.

## Useful troubleshooting commands

Inspect application Pods and events:

```bash
kubectl --context kind-careops describe pods -l app=careops
```

View logs from application Pods:

```bash
kubectl --context kind-careops logs -l app=careops --prefix=true --tail=50
```

Inspect rollout history:

```bash
kubectl --context kind-careops rollout history deployment/careops-app
```

Check local changes:

```bash
git status --short
git --no-pager diff
```

## Limitations

- The application has no appointment-management functionality yet.
- There is no database or persistent application storage.
- The Kubernetes cluster has one node.
- Container images are loaded manually into kind.
- CI does not perform a Kubernetes deployment.
- Terraform and AWS work are planned.
- This is a learning project, not a production healthcare system.