#  CI/CD Configuration — Tanzu Cloud Foundry

Jenkins pipeline configuration and Terraform infrastructure-as-code for deploying
three applications to Tanzu Cloud Foundry.

## Repository Structure

```
.
├── pipelines/                    # Parameterized Jenkinsfile templates
│   ├── Jenkinsfile.docker        # Docker-based apps (Node.js front-ends, App1 SQL)
│   └── Jenkinsfile.buildpack     # Buildpack-based apps (.NET Core APIs)
│
├── apps/                         # Per-application configuration
│   ├── app1-frontend/            # App 1 Node.js front-end (Docker)
│   ├── app1-api/                 # App 1 .NET Core API (buildpack)
│   ├── app1-db/                  # App 1 MS SQL on-platform (Docker)
│   ├── app2-frontend/            # App 2 Node.js front-end (Docker)
│   ├── app2-api/                 # App 2 .NET Core API (buildpack)
│   ├── app3-frontend/            # App 3 Node.js front-end (Docker)
│   └── app3-api/                 # App 3 .NET Core API (buildpack)
│
├── shared-library/               # Jenkins shared library
│   └── vars/
│       ├── dockerPipeline.groovy
│       └── buildpackPipeline.groovy
│
├── jenkins/                      # Jenkins server configuration
│   ├── plugins/
│   │   └── plugins.txt           # Required plugin list (for install-plugins.sh)
│   └── casc/
│       └── jenkins.yaml          # Configuration-as-Code (JCasC)
│
└── terraform/                    # Infrastructure-as-Code
    ├── modules/
    │   ├── cf-org/               # CF org provisioning
    │   ├── cf-space/             # CF space provisioning
    │   └── cf-asg/               # Application Security Group definitions
    └── environments/
        ├── dev/                  # Dev org configuration
        └── prod/                 # Production org configuration
```

## Application Workload

| Application | Front-End          | API Layer  | Database              | Quota   |
|-------------|--------------------|------------|-----------------------|---------|
| App 1       | Node.js (Docker)   | .NET Core  | On-Platform SQL (Docker) | > 2 GB  |
| App 2       | Node.js (Docker)   | .NET Core  | Off-Platform SQL      | Standard|
| App 3       | Node.js (Docker)   | .NET Core  | Off-Platform SQL      | Standard|

## Platform Topology

- **Two CF Orgs**: `dev` and `prod`
- **Apps 1 & 2**: Separate spaces, default ASG (egress restricted)
- **App 3**: Separate space with isolation segment, custom ASG allowing port 1433

## Prerequisites

- Jenkins with plugins listed in `jenkins/plugins/plugins.txt`
- Docker installed on Jenkins agents
- .NET SDK installed on Jenkins agents
- CF CLI v7+ installed on Jenkins agents
- Terraform >= 1.5
- TFS/Azure DevOps with service hooks configured
- GitEA registry for Docker image storage

## Quick Start

1. Install Jenkins plugins: `jenkins-plugin-cli --plugin-file jenkins/plugins/plugins.txt`
2. Apply JCasC: copy `jenkins/casc/jenkins.yaml` to `$JENKINS_HOME/casc_configs/`
3. Provision infrastructure: `cd terraform/environments/dev && terraform init && terraform plan`
4. Configure TFS service hooks to point at Jenkins
5. Create Jenkins pipeline jobs referencing `pipelines/Jenkinsfile.docker` or `pipelines/Jenkinsfile.buildpack`
