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

The goal is to provision infrastructure, configure servers using Ansible, and destroy the infrastructure when finished to minimize AWS costs.

---

# Architecture

```text
          ansible_nodes_setup.sh
                    │
       ┌────────────┴────────────┐
       │                         │
       ▼                         ▼
  Packer Build              Terraform Apply
  (One Time)                     │
       │               ┌─────────┴─────────┐
       ▼               │                   │
  Controller AMI  1 Controller EC2     2 Managed Node EC2s
                        │
                        ▼
              Jenkins (on Controller) + credentials through AWS Secrets Manager
                        │
                        ▼
               Checkout GitHub Repo
               (no manual clone needed)
                        │
                        ▼
              Run Ansible Playbooks
                        │
                        ▼
         AWS EC2 Dynamic Inventory
         (discovers managed nodes by tag)
                        │
                        ▼
             Configure Managed Nodes
```

---

# Project Structure

```text
Ansible/
│
├── Infra/
│   ├── ansible_nodes_setup.sh     ← single entry point (apply / destroy)
│   ├── manifest.json              ← packer AMI output
│   ├── packer/
│   │   ├── ansible_controller_node.pkr.hcl
│   │   ├── install_tools.sh
│   │   └── jenkins.yaml
│   └── terraform/
│       ├── ec2.tf                 ← provisions controller + managed nodes
│       ├── sg.tf
│       ├── role_and_policy.tf
│       └── variables.tf
│
├── Jenkins_Pipeline/
│   └── Jenkinsfile                ← checkout repo + run ansible playbook
│
└── <module folders>/
    ├── playbooks
    ├── inventory/
    └── roles/
```

---

# Roadmap

## Phase 1 – Infrastructure Provisioning ✅ (Automated)

Handled entirely by `ansible_nodes_setup.sh`.

**apply:**
1. Checks AWS CLI, Packer, Terraform are available
2. Builds controller AMI with Packer (skipped if AMI already exists in `manifest.json`)
3. Provisions controller EC2 + managed node EC2s with Terraform in a single apply

**destroy:**
```bash
./ansible_nodes_setup.sh destroy            # keeps AMI
./ansible_nodes_setup.sh destroy --delete-ami  # also deregisters AMI + snapshots
```

AMI includes: Java, Jenkins, Ansible, Terraform, AWS CLI, Git, Python, required collections.

---

## Phase 2 – Jenkins Pipeline Setup

Jenkins runs on the controller node (provisioned above).

**Purpose:** Auto-checkout the GitHub repo and run Ansible playbooks — no need to manually SSH and clone.

**Pipeline does:**
* Checkout repo from GitHub using stored credentials
* Validate Ansible is available on the agent
* Run the specified playbook against dynamic inventory

**Parameters (passed at runtime):**

| Parameter | Default | Description |
|---|---|---|
| `PLAYBOOK_PATH` | `01_.../01_variable_sources.yml` | Path to playbook |
| `INVENTORY_PATH` | `01_.../inventory/inventory.yml` | Path to inventory |
| `TAG_NAME` | `project` | AWS tag key for dynamic inventory |
| `TAG_VALUE` | `strata` | AWS tag value for dynamic inventory |

Jenkins does **not** manage infrastructure. Terraform is only run via the shell script.

---

## Phase 3 – Secrets Management

Do **not** store secrets in Jenkins credentials where avoidable.

Use AWS Secrets Manager for:

* SSH Private Key (for Ansible to connect to managed nodes)
* GitHub Personal Access Token (if repo is private)
* Any additional credentials

The Jenkins pipeline retrieves secrets during execution via IAM Role attached to the controller EC2.

---

## Phase 4 – Dynamic Inventory

Configure the AWS EC2 Inventory Plugin on the controller.

Inventory automatically discovers EC2 instances using tags set during Terraform provisioning.

Example tags:

```
Environment = Lab
Role = Worker
```

No static inventory file should be maintained for managed nodes.

---

# Future Enhancements

* Parameterized Jenkins builds
* Trigger Jenkins pipeline via REST API (platform engineer style — no UI)
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

* [x] Write Packer template (controller AMI)
* [x] Write Terraform (controller + managed nodes)
* [x] Write `ansible_nodes_setup.sh` (single entry point)
* [x] Configure IAM Role + Security Groups
* [ ] Configure Jenkins Multibranch Pipeline
* [ ] Configure AWS Secrets Manager (SSH key, GitHub PAT)
* [ ] Configure AWS EC2 Dynamic Inventory
* [ ] Write and execute Ansible Playbooks
* [ ] Trigger Jenkins pipeline via REST API (no UI required)
* [ ] Destroy infrastructure when done

---

# End-to-End Workflow

```
./ansible_nodes_setup.sh apply
        │
        ▼
Packer builds Controller AMI (once)
        │
        ▼
Terraform provisions Controller + Managed Nodes
        │
        ▼
Jenkins on Controller checks out GitHub Repo
        │
        ▼
Jenkins runs Ansible Playbook
        │
        ▼
Dynamic Inventory discovers Managed Nodes by tag
        │
        ▼
Managed Nodes configured
        │
        ▼
./ansible_nodes_setup.sh destroy (--delete-ami)
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
