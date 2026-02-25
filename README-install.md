# Jenkins Installation Guide — Ubuntu Server

Step-by-step instructions for installing Jenkins LTS and all required tooling on
an Ubuntu Server (22.04 or 24.04 LTS) to support the examplary CI/CD pipelines.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install Java (OpenJDK 21)](#2-install-java-openjdk-21)
3. [Install Jenkins LTS](#3-install-jenkins-lts)
4. [Configure Firewall](#4-configure-firewall)
5. [Initial Jenkins Setup](#5-initial-jenkins-setup)
6. [Install Jenkins Plugins](#6-install-jenkins-plugins)
7. [Install Docker Engine](#7-install-docker-engine)
8. [Install .NET SDK 8.0](#8-install-net-sdk-80)
9. [Install Cloud Foundry CLI v8](#9-install-cloud-foundry-cli-v8)
10. [Install Terraform](#10-install-terraform)
11. [Configure Jenkins Credentials](#11-configure-jenkins-credentials)
12. [Apply Configuration as Code (JCasC)](#12-apply-configuration-as-code-jcasc)
13. [Post-Installation Verification](#13-post-installation-verification)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Prerequisites

Before you begin, ensure your Ubuntu server meets the following requirements:

- Ubuntu Server 22.04 LTS or 24.04 LTS (64-bit)
- Minimum 4 GB RAM (8 GB recommended for building Docker images)
- Minimum 50 GB disk space
- `sudo` access
- Outbound internet access (for package downloads and plugin installation)
- A DNS name or static IP for the Jenkins server

Update the system packages first:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget gnupg ca-certificates lsb-release software-properties-common unzip git
```

---

## 2. Install Java (OpenJDK 21)

Jenkins requires Java 21 (as of Jenkins LTS 2.479.1+). Install OpenJDK 21:

```bash
sudo apt update
sudo apt install -y fontconfig openjdk-21-jre
```

Verify the installation:

```bash
java -version
```

You should see output indicating OpenJDK version 21.x.

---

## 3. Install Jenkins LTS

Add the official Jenkins repository signing key and apt source, then install:

```bash
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key  
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins
```

Enable and start the Jenkins service:

```bash
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
```

Jenkins should now be running on port 8080. Confirm with:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
# Should return 403 (login page redirect) if Jenkins is running
```

> **Note:** If the GPG key URL above returns an error, check the current key URL at
> https://www.jenkins.io/doc/book/installing/linux/ — the key filename may change
> with new releases.

---

## 4. Configure Firewall

If UFW is active on your server, allow Jenkins and SSH traffic:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 8080/tcp
sudo ufw --force enable
sudo ufw status
```

If you plan to put Jenkins behind a reverse proxy (Nginx or Apache), allow port 443
instead and proxy traffic to localhost:8080.

---

## 5. Initial Jenkins Setup

### 5.1 Unlock Jenkins

Open your browser and navigate to `http://<your-server-ip>:8080`. Jenkins will
display the "Unlock Jenkins" page. Retrieve the initial admin password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Paste the password into the browser prompt.

### 5.2 Create Admin User

After unlocking, Jenkins will prompt you to either install suggested plugins or
select plugins manually. For now, choose **"Install suggested plugins"** — we will
install the project-specific plugins in the next step.

Create your admin user account when prompted. Save the Jenkins URL configuration
(set it to your server's public hostname or IP).

---

## 6. Install Jenkins Plugins

This repository includes a curated list of required plugins at `jenkins/plugins/plugins.txt`.

### Option A: Using the Jenkins Plugin CLI (recommended for automation)

The `jenkins-plugin-cli` tool ships with Jenkins. Run it from the server:

```bash
# Stop Jenkins before bulk plugin install
sudo systemctl stop jenkins

# Install all plugins from the list
sudo java -jar /usr/share/jenkins/jenkins-plugin-manager.jar \
  --war /usr/share/java/jenkins.war \
  --plugin-download-directory /var/lib/jenkins/plugins/ \
  --plugin-file /path/to/jenkins-ci-cd-example/jenkins/plugins/plugins.txt

# Fix ownership (plugins must be owned by the jenkins user)
sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins/

# Restart Jenkins
sudo systemctl start jenkins
```

> **Note:** If `jenkins-plugin-manager.jar` is not present at the path above,
> download it from the [Plugin Installation Manager releases](https://github.com/jenkinsci/plugin-installation-manager-tool/releases):
>
> ```bash
> wget -O jenkins-plugin-manager.jar \
>   https://github.com/jenkinsci/plugin-installation-manager-tool/releases/latest/download/jenkins-plugin-manager-2.14.0.jar
> ```

### Option B: Using the Jenkins Web UI

1. Navigate to **Manage Jenkins → Plugins → Available plugins**
2. Search for and install each plugin listed below
3. Restart Jenkins after all plugins are installed

### Required Plugins

| Plugin | Purpose |
|--------|---------|
| **TFS Plugin** | Source code management integration with Team Foundation Server |
| **Git Plugin** | Git SCM support |
| **Pipeline (workflow-aggregator)** | Core pipeline engine |
| **Pipeline Utility Steps** | readYaml, readJSON, and other file utilities |
| **Docker Pipeline** | `docker.build()`, `docker.withRegistry()` pipeline steps |
| **Docker Plugin** | Docker agent provisioning |
| **CloudBees Docker Build and Publish** | Docker build and push from freestyle jobs |
| **Cloud Foundry Plugin** | `pushToCloudFoundry` pipeline step for CF deployments |
| **.NET SDK Support** | `dotnetBuild`, `dotnetPublish` pipeline steps |
| **Terraform Plugin** | Terraform `init`, `plan`, `apply` build wrappers |
| **Generic Webhook Trigger** | Receives webhook payloads from TFS service hooks |
| **Credentials Binding** | Injects credentials as environment variables |
| **Configuration as Code (JCasC)** | Declarative Jenkins configuration via YAML |
| **Timestamper** | Adds timestamps to console output |
| **Workspace Cleanup** | `cleanWs()` pipeline step |
| **MSTest Publisher** | Publishes .NET test results (.trx files) |
| **AnsiColor** | ANSI color support in console output |

After installing, restart Jenkins:

```bash
sudo systemctl restart jenkins
```

---

## 7. Install Docker Engine

Docker is required on the Jenkins server (or agents) for building and pushing
container images. Install Docker CE from the official repository:

```bash
# Remove any conflicting packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y $pkg 2>/dev/null
done

# Add Docker's GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

Grant the `jenkins` user permission to run Docker commands:

```bash
sudo usermod -aG docker jenkins
```

Restart Jenkins so it picks up the new group membership:

```bash
sudo systemctl restart jenkins
```

Verify Docker is accessible to Jenkins:

```bash
sudo -u jenkins docker info
```

---

## 8. Install .NET SDK 8.0

The .NET SDK is required for building the .NET Core API applications.

### On Ubuntu 22.04 or 24.04 (from Ubuntu feeds):

```bash
sudo apt update
sudo apt install -y dotnet-sdk-8.0
```

### Alternative: From Microsoft's repository

Use this if the Ubuntu feed does not have the version you need:

```bash
wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb \
  -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

sudo apt update
sudo apt install -y dotnet-sdk-8.0
```

> **Important:** Do not mix packages from the Ubuntu feed and the Microsoft
> repository. Choose one source and stick with it.

Verify:

```bash
dotnet --version
dotnet --list-sdks
```

---

## 9. Install Cloud Foundry CLI v8

The CF CLI is required for deploying applications to Tanzu Cloud Foundry.

```bash
# Add the Cloud Foundry GPG key and repository
curl -fsSL https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | \
  sudo gpg --dearmor -o /usr/share/keyrings/cloudfoundry-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/cloudfoundry-keyring.gpg] \
  https://packages.cloudfoundry.org/debian stable main" | \
  sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list > /dev/null

sudo apt update
sudo apt install -y cf8-cli
```

Verify:

```bash
cf version
```

> **Known issue on Ubuntu 24.04:** If you encounter a GPG key error
> (`NO_PUBKEY 172B5989FCD21EF8`), use the binary install method instead:
>
> ```bash
> curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&version=v8&source=github" | sudo tar -zx -C /usr/local/bin
> cf version
> ```

Test connectivity to your Cloud Foundry API:

```bash
cf api https://api.sys.<fqdn>. --skip-ssl-validation
cf login
```

---

## 10. Install Terraform

Terraform is used for provisioning Cloud Foundry orgs, spaces, and ASGs.

```bash
# Add HashiCorp GPG key and repository
curl -fsSL https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

sudo apt update
sudo apt install -y terraform
```

Verify:

```bash
terraform version
```

---

## 11. Configure Jenkins Credentials

Before running any pipelines, store the following credentials in Jenkins:

1. Navigate to **Manage Jenkins → Credentials → System → Global credentials**
2. Add each credential using the ID shown below

| Credential ID | Type | Description |
|---------------|------|-------------|
| `cf-api-credentials` | Username with password | Cloud Foundry API user and password |
| `gitea-docker-registry` | Username with password | GitEA registry username and token |
| `tfs-pat` | Secret text | TFS Personal Access Token (scopes: Code read, Code status) |
| `cf-api-endpoint` | Secret text | CF API URL (e.g., `https://api.sys.<fqdn>.`) |

These IDs match what the Jenkinsfiles and JCasC configuration reference.

---

## 12. Apply Configuration as Code (JCasC)

The JCasC plugin allows you to define Jenkins configuration declaratively. The
configuration file is at `jenkins/casc/jenkins.yaml` in this repository.

### 12.1 Set environment variables

JCasC uses environment variable interpolation. Set these before starting Jenkins:

```bash
sudo mkdir -p /etc/systemd/system/jenkins.service.d

sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="CASC_JENKINS_CONFIG=/var/lib/jenkins/casc_configs"
Environment="JENKINS_ADMIN_USER=admin"
Environment="JENKINS_ADMIN_PASS=CHANGE_ME_TO_A_STRONG_PASSWORD"
Environment="CF_API_ENDPOINT=https://api.sys.<system-domain>"
Environment="CF_USERNAME=cf-deploy-user"
Environment="CF_PASSWORD=CHANGE_ME"
Environment="GITEA_REGISTRY=gitea.<fqdn>."
Environment="GITEA_USER=jenkins-svc"
Environment="GITEA_TOKEN=CHANGE_ME"
Environment="TFS_PAT=CHANGE_ME"
Environment="SHARED_LIBRARY_REPO=https://tfs.<fqdn>./collection/project/_git/cicd-shared-library"
Environment="CICD_CONFIG_REPO=https://tfs.<fqdn>./collection/project/_git/jenkins-ci-cd-example
Environment="JENKINS_URL=http://jenkins.<fqdn>.:8080/"
EOF
```

### 12.2 Copy the JCasC file

```bash
sudo mkdir -p /var/lib/jenkins/casc_configs
sudo cp jenkins/casc/jenkins.yaml /var/lib/jenkins/casc_configs/
sudo chown -R jenkins:jenkins /var/lib/jenkins/casc_configs
```

### 12.3 Reload

```bash
sudo systemctl daemon-reload
sudo systemctl restart jenkins
```

Jenkins will automatically apply the YAML configuration on startup. You can verify
by navigating to **Manage Jenkins → Configuration as Code → View Configuration**.

---

## 13. Post-Installation Verification

Run through this checklist to confirm everything is working:

```bash
# 1. Jenkins is running
sudo systemctl is-active jenkins

# 2. Java version
java -version

# 3. Docker is available to Jenkins
sudo -u jenkins docker info | head -5

# 4. .NET SDK
dotnet --list-sdks

# 5. CF CLI
cf version

# 6. Terraform
terraform version

# 7. Jenkins plugins (via API)
curl -s -u admin:YOUR_PASSWORD \
  http://localhost:8080/pluginManager/api/json?depth=1 | \
  python3 -m json.tool | grep -E '"shortName"|"version"' | head -40
```

### Smoke test: Create a test pipeline job

1. In Jenkins, create a new Pipeline job called `test-docker-build`
2. Use the following inline pipeline script:

```groovy
pipeline {
    agent any
    stages {
        stage('Verify Tools') {
            steps {
                sh 'java -version'
                sh 'docker --version'
                sh 'dotnet --version'
                sh 'cf version'
                sh 'terraform version'
            }
        }
    }
}
```

3. Run the job — all five commands should succeed

---

## 14. Troubleshooting

### Jenkins won't start after plugin install

Check the Jenkins log for plugin dependency errors:

```bash
sudo journalctl -u jenkins.service --since "10 minutes ago" --no-pager
```

If a plugin has unmet dependencies, install the missing dependency or upgrade
the conflicting plugin via the UI or CLI.

### Docker permission denied

If Jenkins jobs fail with `permission denied` when calling Docker:

```bash
# Verify jenkins is in the docker group
groups jenkins

# If not, add and restart
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### JCasC not applying

Verify the `CASC_JENKINS_CONFIG` environment variable is set:

```bash
sudo systemctl show jenkins | grep -i casc
```

Check the JCasC log output:

```bash
sudo journalctl -u jenkins.service | grep -i "casc\|configuration.as.code"
```

### CF CLI GPG key issue on Ubuntu 24.04

If `apt update` fails with a GPG error for the Cloud Foundry repository, fall
back to the binary installation described in [Section 9](#9-install-cloud-foundry-cli-v8).

### .NET SDK version conflicts

If `dotnet --info` shows mismatched SDK and runtime versions, you may have
packages from both the Ubuntu and Microsoft feeds. Remove one source:

```bash
# Check installed .NET packages
dpkg --list | grep dotnet

# Remove Microsoft feed if using Ubuntu packages
sudo dpkg -r packages-microsoft-prod
sudo apt update
```

---

## Reference Links

- [Jenkins Official Install Guide (Linux)](https://www.jenkins.io/doc/book/installing/linux/)
- [Docker Engine Install (Ubuntu)](https://docs.docker.com/engine/install/ubuntu/)
- [.NET on Ubuntu](https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu-install)
- [CF CLI v8 Installation](https://github.com/cloudfoundry/cli/wiki/V8-CLI-Installation-Guide)
- [Terraform Install (apt)](https://developer.hashicorp.com/terraform/install)
- [Jenkins Plugin Installation Manager](https://github.com/jenkinsci/plugin-installation-manager-tool)
- [Jenkins Configuration as Code](https://plugins.jenkins.io/configuration-as-code/)
- [Cloud Foundry Jenkins Plugin](https://plugins.jenkins.io/cloudfoundry/)
