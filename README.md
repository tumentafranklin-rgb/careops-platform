# CareOps Platform

A hands-on DevOps learning project inspired by a remote healthcare
engineering role.

The application currently provides a welcome endpoint and a health
endpoint. It uses fictional data only.

## Project goal

Learn to build, test, containerize, deploy, and troubleshoot an application,
then manage infrastructure using Terraform.

## Completed work

- Flask application with welcome and health endpoints
- Automated health endpoint test using pytest
- Docker image running Gunicorn as a non-root user
- GitHub Actions tests, Docker build, and container smoke test
- Local Kubernetes cluster using kind
- Deployment with two replicas and a ClusterIP Service
- Readiness and liveness probes
- CPU and memory requests and limits
- Pod recovery, rolling update, and rollback exercises
- Local Terraform resource lifecycle exercise

## Planned work

- AWS infrastructure as code using Terraform
- AWS application deployment
- Additional application features
- Operational monitoring

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
├── terraform/
│   └── local/
│       ├── .terraform.lock.hcl
│       └── main.tf
├── .dockerignore
├── .gitignore
├── app.py
├── Dockerfile
├── README.md
├── requirements.txt
├── requirements-dev.txt
└── test_app.py
```

Generated environments, caches, Terraform state, and downloaded providers
are omitted from this structure.

## Prerequisites

These instructions use a Linux terminal.

- Python 3.14 with pip and virtual environment support
- Git
- Docker installed and running
- kind and kubectl for the Kubernetes exercises
- Terraform 1.17.x for the local Terraform exercise
- Internet access to download dependencies and images

Run commands from the project root unless stated otherwise.

## Application endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | / | Welcome message and application version |
| GET | /health | Application health response |

The home endpoint returns HTTP 200 with:

```json
{"message":"Welcome to CareOps Platform","version":"v3"}
```

The health endpoint returns HTTP 200 with:

```json
{"status":"healthy"}
```

The health endpoint checks whether the application responds.
It does not check an external database or other dependencies.

## Run locally with Python

Create a virtual environment once:

```bash
python3 -m venv .venv
```

Activate it in the terminal where you will run Python commands:

```bash
source .venv/bin/activate
```

Install application dependencies:

```bash
python -m pip install -r requirements.txt
```

Start the development server:

```bash
python -m flask --app app run
```

Leave that terminal running. In another terminal:

```bash
curl -i http://127.0.0.1:5000/
curl -i http://127.0.0.1:5000/health
```

The Flask development server is for local development.
The Docker image uses Gunicorn.

Press Ctrl+C in the server terminal to stop it.

If python is not found in a new terminal, activate the virtual
environment again.

## Run automated tests

Activate the virtual environment:

```bash
source .venv/bin/activate
```

Install development dependencies:

```bash
python -m pip install -r requirements-dev.txt
```

Run the tests:

```bash
python -m pytest -v
```

The test checks the health endpoint's HTTP status and JSON response.

Flask's test client sends requests directly to the application.
A running server is not required.

## Build the Docker image

```bash
docker build -t careops-platform:v3 .
```

The image contains Python, application dependencies, and application code.

Gunicorn runs with two workers as appuser, UID 10001.

The .dockerignore file excludes the local Python environment,
Git history, generated Python files, test caches, and the local .env file.

## Run with Docker

Start the application container:

```bash
docker run -d --name careops-app -p 127.0.0.1:8081:5000 careops-platform:v3
```

Port 8081 on the Docker host forwards to port 5000 inside the container.
The published port is bound to the host's loopback address.

Check the container:

```bash
docker ps --filter name=careops-app
```

Test from the Docker host:

```bash
curl -i http://127.0.0.1:8081/
curl -i http://127.0.0.1:8081/health
```

View logs:

```bash
docker logs careops-app
```

Check the container user:

```bash
docker exec careops-app id
```

Expected user ID: 10001.

### Replace an existing project container

Inspect the existing container first:

```bash
docker ps -a --filter name=careops-app
```

If it is running, stop it:

```bash
docker stop careops-app
```

Remove the stopped container:

```bash
docker rm careops-app
```

Then rerun the docker run command with the desired image tag.

These commands remove the container, not the image or project files.

## Continuous integration

The workflow is defined in .github/workflows/ci.yml.

It runs on pushes to main and pull requests targeting main.

The workflow:

1. Checks out the repository.
2. Sets up Python 3.14.
3. Installs application and testing dependencies.
4. Runs pytest.
5. Builds careops-platform:ci.
6. Starts a test container.
7. Requests its health endpoint with bounded retries.
8. Displays container logs, even if an earlier step fails.
9. Removes the test container.

The smoke test checks whether the container serves its health endpoint
without an HTTP error. The pytest test checks the exact status and JSON.

The image is built and tested on GitHub's runner.
It is not published or deployed by this workflow.

## Run locally with Kubernetes

The kind configuration creates one control-plane node.
Both application replicas run on that node.

### Build and create the cluster

Build the image:

```bash
docker build -t careops-platform:v3 .
```

Create the cluster once:

```bash
kind create cluster --name careops --config k8s/kind-config.yaml --wait 180s
```

If the cluster already exists, inspect it instead:

```bash
kind get clusters
kubectl --context kind-careops get nodes
```

### Load the image and deploy

Load the image into the kind node:

```bash
kind load docker-image careops-platform:v3 --name careops
```

The Deployment uses imagePullPolicy: Never.
The image must already be present on the node.

Apply the Deployment and Service:

```bash
kubectl --context kind-careops apply -f k8s/deployment.yaml
kubectl --context kind-careops apply -f k8s/service.yaml
```

kind-config.yaml configures kind itself.
Do not apply it as a Kubernetes resource with kubectl.

Wait for the rollout:

```bash
kubectl --context kind-careops rollout status deployment/careops-app --timeout=120s
```

Inspect the application:

```bash
kubectl --context kind-careops get pods -l app=careops -o wide
kubectl --context kind-careops get service careops-service
kubectl --context kind-careops get endpointslices -l kubernetes.io/service-name=careops-service
```

Expect two ready Pods. Their IP addresses should appear as the
Service's endpoints.

### Access the application

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
It does not test traffic distribution through the Service's ClusterIP.

Restart port forwarding if its selected Pod terminates during a rollout
or recovery exercise.

Press Ctrl+C in the port-forward terminal when finished.

## Kubernetes configuration

### Replicas and Service

The Deployment requests two replicas.

The ClusterIP Service listens on port 80 and targets application port 5000.
Its selector matches Pods labeled app=careops.

### Readiness probe

- Path: /health
- Port: 5000
- Initial delay: 3 seconds
- Check interval: 5 seconds
- Default failure threshold: 3 consecutive failures

Readiness determines whether a Pod is eligible for normal Service traffic.
Readiness failures do not restart the container.

### Liveness probe

- Path: /health
- Port: 5000
- Initial delay: 10 seconds
- Check interval: 10 seconds
- Failure threshold: 3 consecutive failures

Repeated liveness failures cause Kubernetes to restart the container.

### Resource requests and limits

| Resource | Request | Limit |
| --- | --- | --- |
| CPU | 100m (0.1 CPU) | 500m (0.5 CPU) |
| Memory | 64Mi | 256Mi |

Requests are used for scheduling.
CPU limits can throttle usage.
Exceeding the memory limit can cause container termination.

These are initial learning-project values.
A real workload requires measurement and tuning.

The Pod's quality-of-service class is Burstable.

## Local Terraform exercise

The configuration in terraform/local/main.tf uses the HashiCorp local
provider to manage careops-config.json in the same folder.

The generated file contains:

```json
{"application":"careops-platform","environment":"development","version":"v3"}
```

This is a learning resource. The Flask application does not read it.

### Initialize, format, and validate

```bash
terraform -chdir=terraform/local init
terraform -chdir=terraform/local fmt -check
terraform -chdir=terraform/local validate
```

Initialization downloads the provider and creates the provider lock file.

To apply standard formatting:

```bash
terraform -chdir=terraform/local fmt
```

### Preview and create the resource

```bash
terraform -chdir=terraform/local plan
terraform -chdir=terraform/local apply
```

Review the apply plan before entering yes.

Inspect the generated file:

```bash
cat terraform/local/careops-config.json
```

Run another plan:

```bash
terraform -chdir=terraform/local plan
```

If the file matches the configuration, expect no changes.

### Inspect state

```bash
terraform -chdir=terraform/local state list
terraform -chdir=terraform/local state show local_file.app_config
```

State records the resources Terraform manages.

### Remove the resource

```bash
terraform -chdir=terraform/local destroy
```

Review the plan before entering yes.
For this configuration, only the managed JSON file should be destroyed.

Verify cleanup:

```bash
terraform -chdir=terraform/local state list
ls terraform/local/careops-config.json
```

After destruction, the state list should be empty.
The ls command should report that the JSON file does not exist.

The configuration and provider lock file remain available to recreate it.

### Terraform files and Git

Committed:

- main.tf
- .terraform.lock.hcl

Excluded by .gitignore:

- Downloaded providers in .terraform
- Terraform state and state backups
- Saved plans ending in .tfplan
- crash.log

The generated JSON file is not currently ignored.
Avoid staging it when committing the configuration.

State and saved plans can contain sensitive values.
The lock file records the selected provider version and checksums.

## Completed troubleshooting exercises

### Automated test failures

I changed an expected HTTP status from 200 to 201.
Pytest reported an assertion failure.

I also corrected a Python syntax error and confirmed the test passed again.

### Docker port conflict

Port 8080 was already allocated.

I removed the container created by the failed attempt and restarted
the application using host port 8081.

### Container health check in CI

A health request failed with a connection reset.

I added bounded retries that include connection resets.
The next workflow run passed.

### Readiness failure

I temporarily changed the readiness path to /not-ready.

The replacement Pod stayed Running but unready without restarting.
The previous healthy Pod remained available during the blocked rollout.

I restored /health afterward.

### Liveness failure

A liveness probe using /not-ready received HTTP 404 responses.

Kubernetes recorded failed liveness checks and restarted the container.
I restored /health afterward.

### Pod recovery

With two replicas configured, I deleted one application Pod.

Kubernetes created a replacement while the other Pod stayed running.
The Service updated its endpoints to include the new Pod IP
and remove the deleted Pod IP.

Both replicas share one node, so this does not demonstrate node-failure recovery.

### Rolling update and rollback

I deployed v3 and verified the version in the home response.

I inspected Deployment history and confirmed the previous v2 template
had the expected probes and resource settings.

I rolled back to revision 8 in that cluster and verified the v2 response.
Finally, I reapplied the saved Deployment file to restore v3.

A rollout rollback changes the cluster, not the configuration stored in Git.
Revision numbers depend on the Deployment's history in each cluster.

### Terraform lifecycle

I initialized and validated the local configuration, then reviewed its plan.

I applied it to create a JSON file and confirmed a second plan required
no changes.

Changing environment from local to development caused the local-file
resource to be replaced.

I inspected state, destroyed the resource, and verified the file was removed.

## Useful troubleshooting commands

Inspect application Pods and events:

```bash
kubectl --context kind-careops describe pods -l app=careops
```

Read application logs:

```bash
kubectl --context kind-careops logs -l app=careops --prefix=true --tail=50
```

Inspect rollout history:

```bash
kubectl --context kind-careops rollout history deployment/careops-app
```

Check Git changes:

```bash
git status --short
git --no-pager diff
```

Check Terraform configuration:

```bash
terraform -chdir=terraform/local validate
terraform -chdir=terraform/local plan
```

## Limitations

- Appointment-management features are not implemented.
- There is no database or persistent application storage.
- The Kubernetes cluster has one node.
- Images are loaded manually into kind.
- CI does not deploy to Kubernetes.
- Dependency ranges do not fully lock Python package versions.
- The local Terraform exercise does not configure the application.
- AWS infrastructure and deployment are planned.
- This is a learning project, not a production healthcare system.

## AWS container registry exercise

Terraform configuration in terraform/aws manages a private Amazon ECR
repository named careops-platform in us-east-1.

Repository settings:

- Immutable image tags
- AES256 encryption at rest
- Project, Environment, and ManagedBy tags

I authenticated Docker to ECR and uploaded the v3 application image.
I verified its tag, digest, and stored size using aws ecr describe-images.

The image is stored in AWS. The application is not running in AWS yet.

### Terraform commands

```bash
terraform -chdir=terraform/aws init
terraform -chdir=terraform/aws validate
terraform -chdir=terraform/aws plan
terraform -chdir=terraform/aws apply
```

Review the plan before approving apply.

Display the repository address:

```bash
terraform -chdir=terraform/aws output -raw repository_url
```

### Troubleshooting completed

An AWS request initially failed because the VM's system clock was behind.
I corrected the clock using Chrony and verified AWS authentication.

Repository creation initially failed because the CLI user lacked ECR
permissions. I attached a customer-managed policy scoped to the project
repository, with a separate ECR authentication permission.

The repository was created successfully, and a later Terraform plan
reported no changes.

### Cost and cleanup

Stored images can incur ECR storage charges.
A $10 budget alert is configured; it does not automatically stop spending.

Before destroying the repository, remove its images or explicitly review
a change allowing Terraform to delete a nonempty repository.

Keep Terraform state available so Terraform can manage and remove
the resources it created.

- Private Amazon ECR repository managed with Terraform
- Application image uploaded to ECR and verified

## Completed AWS EC2 deployment and cleanup

I deployed the v3 image from private Amazon ECR to an Amazon Linux
t3.micro EC2 instance using Terraform.

The deployment included:

- An encrypted 8 GB gp3 root disk
- A security group allowing application access from my public IP only
- An EC2 IAM role with repository-scoped ECR pull permissions
- Systems Manager access without an inbound SSH rule
- A startup script that installed Docker and launched the application

I checked startup progress through Systems Manager and cloud-init logs.
Both the health endpoint and the v3 home response returned HTTP 200
from my local machine.

After testing, I renamed compute.tf, iam.tf, network.tf, and security.tf
to end in .tf.disabled, then reviewed and applied the cleanup plan.

Terraform destroyed the eight EC2 deployment resources.
I verified that the instance was terminated and its root disk was removed.
A subsequent Terraform plan reported no changes.

The deployment code remains as .tf.disabled files for reference.
Terraform does not load these files. Restoring their .tf extensions
will propose recreating the deployment and incur charges if applied.
The allowed public IP must be checked before redeployment.

The private ECR repository and v3 image remain.
ECR storage can continue to incur charges.

- AWS EC2 deployment from private ECR, verified and cleaned up