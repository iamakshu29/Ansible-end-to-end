# Ansible Automation Lab on AWS

## Objective

Build a fully automated Ansible lab that can be recreated from scratch using Infrastructure as Code.

The project demonstrates:

* Packer
* Terraform
* Jenkins
* AWS EC2
* AWS Secrets Manager
* Ansible
* Dynamic Inventory
* CI/CD

The goal is to provision infrastructure, configure servers using Ansible, and destroy the infrastructure when finished to minimize AWS costs.

---

# Architecture

```text
                        GitHub Repository
                               │
                               ▼
                    Packer Build (One Time)
                               │
                               ▼
                   Jenkins Control Node AMI
                               │
                               ▼
                     Terraform (Control Node)
                               │
                               ▼
                    Jenkins Control Node EC2
                               │
                               ▼
                 Jenkins Multibranch Pipeline
                               │
          ┌────────────────────┴────────────────────┐
          │                                         │
          ▼                                         ▼
 Terraform Apply                           Terraform Destroy
   (Worker Nodes)                             (Worker Nodes)
          │
          ▼
 AWS EC2 Dynamic Inventory
          │
          ▼
    Ansible Playbooks
          │
          ▼
     Configure Servers
```

---

# Project Structure

```text
ansible-lab/
│
├── packer/
│   ├── control-node.pkr.hcl
│   └── scripts/
│       ├── install_java.sh
│       ├── install_jenkins.sh
│       ├── install_ansible.sh
│       ├── install_terraform.sh
│       ├── install_git.sh
│       └── install_awscli.sh
│
├── terraform/
│   ├── control-node/
│   └── workers/
│
├── ansible/
│   ├── inventory/
│   ├── playbooks/
│   ├── group_vars/
│   └── roles/
│
├── Jenkinsfile
│
├── README.md
│
└── docs/
```

---

# Build Roadmap

## Phase 1 – Build the Control Node Image

### Goal

Create a reusable AMI containing all required DevOps tools.

### Install

* Java
* Jenkins
* Git
* Terraform
* AWS CLI
* Ansible
* Python
* Required Ansible Collections

### Configure

* Jenkins plugins
* Multibranch Pipeline
* GitHub connection
* IAM Role
* AWS CLI
* Ansible

### Output

```
Golden AMI
```

---

## Phase 2 – Launch the Control Node

Terraform should:

* Create Security Group
* Create and Attach IAM Role
* Launch EC2 from the Packer AMI
* Output Jenkins URL

Result:

```
Control Node Ready
```

---

## Phase 3 – Repository Setup

Repository should contain:

* Jenkinsfile
* Terraform
* Ansible
* Packer

The Jenkins Multibranch Pipeline should automatically detect the branch.

No manual Git checkout should be required.

---

## Phase 4 – Secrets Management

Do **not** store secrets in Jenkins.

Use AWS Secrets Manager for:

* GitHub Personal Access Token (if required)
* SSH Private Key
* Any additional credentials

The Jenkins pipeline retrieves secrets during execution.

---

## Phase 5 – Worker Infrastructure

Terraform provisions:

* Worker Node 1
* Worker Node 2

The instances should include tags for Ansible Dynamic Inventory.

---

## Phase 6 – Dynamic Inventory

Configure the AWS EC2 Inventory Plugin.

Inventory should automatically discover EC2 instances using tags.

Example:

```
Environment = Lab
Role = Worker
```

No static inventory file should be maintained.

---

## Phase 7 – Jenkins Pipeline

Pipeline flow:

```
Start

↓

Checkout Repository

↓

Terraform Init

↓

Terraform Apply

↓

Wait for EC2 Boot

↓

Verify SSH Connectivity

↓

Generate Dynamic Inventory

↓

Run Ansible Playbook

↓

Validate Configuration

↓

(Optional) Terraform Destroy

↓

Finish
```

---

# Future Enhancements

* Parameterized Jenkins builds
* Optional Infrastructure Cleanup
* Slack Notifications
* Email Notifications
* Terraform Remote State (S3 + DynamoDB)
* Molecule Testing
* Docker-based Ansible Testing
* Multiple Environments (Dev/Test/Prod)
* Versioned Packer Images
* Automatic AMI Discovery in Terraform

---

# Learning Order

Build the project in this sequence:

* [ ] Create GitHub Repository
* [ ] Learn basic Terraform
* [ ] Build Control Node with Packer
* [ ] Create Control Node using Terraform
* [ ] Configure Jenkins Multibranch Pipeline
* [ ] Configure AWS IAM Roles
* [ ] Configure AWS Secrets Manager
* [ ] Create Worker Nodes using Terraform
* [ ] Configure AWS Dynamic Inventory
* [ ] Learn Ansible Basics
* [ ] Execute First Playbook
* [ ] Build Ansible Roles
* [ ] Destroy Infrastructure
* [ ] Automate Complete Workflow

---

# End-to-End Workflow

```
Developer pushes code
        │
        ▼
GitHub
        │
        ▼
Jenkins Multibranch Pipeline
        │
        ▼
Terraform Apply
        │
        ▼
Worker EC2 Instances Created
        │
        ▼
Dynamic Inventory Discovers Hosts
        │
        ▼
Ansible Executes Playbooks
        │
        ▼
Infrastructure Configured
        │
        ▼
(Optional)
Terraform Destroy
```

---

# Skills Demonstrated

* Infrastructure as Code (Terraform)
* Image Baking (Packer)
* Configuration Management (Ansible)
* Continuous Integration (Jenkins)
* AWS EC2
* IAM Roles
* AWS Secrets Manager
* Dynamic Inventory
* GitHub Integration
* CI/CD Automation
* Infrastructure Lifecycle Management
