# Infra — Remaining Tasks

Current state: Packer + Terraform + shell script are working.
This document tracks what still needs to be implemented.

---

## 1. Terraform — EC2 Tags + Public IP Outputs

### Tags on EC2 instances
Dynamic inventory discovers managed nodes by tag. Currently `ec2.tf` has no `tags` block.

**Add to each instance in `ec2.tf`:**
```hcl
tags = each.key == "ansible_controller" ? {
  Name        = "ansible-controller"
  Role        = "controller"
  Environment = "lab"
} : {
  Name        = each.key
  Role        = "worker"
  Environment = "lab"
}
```

### outputs.tf (missing file)
Need public IPs so you know where Jenkins is and can verify managed nodes are up.

**Create `terraform/outputs.tf`:**
```hcl
output "controller_public_ip" {
  description = "Jenkins URL"
  value       = "http://${aws_instance.ansible["ansible_controller"].public_ip}:8080"
}

output "managed_node_ips" {
  description = "Public IPs of managed nodes"
  value = {
    for k, v in aws_instance.ansible :
    k => v.public_ip
    if k != "ansible_controller"
  }
}
```

> **Note:** Also confirm `associate_public_ip_address = true` on managed nodes if you
> need to SSH to them directly for debugging. Within the VPC, Ansible uses private IPs.

---

## 2. Terraform — Secrets Manager + SSM Parameter Store

### GitHub PAT (Secrets Manager)
Used by Jenkins to checkout the private repo.

```hcl
resource "aws_secretsmanager_secret" "github_pat" {
  name        = "ansible-lab/github-pat"
  description = "GitHub Personal Access Token for Jenkins"
}

resource "aws_secretsmanager_secret_version" "github_pat" {
  secret_id     = aws_secretsmanager_secret.github_pat.id
  secret_string = var.github_pat   # pass via tfvars or env var, never hardcode
}
```

### SSH Private Key (Secrets Manager)
Ansible needs the private key to SSH into managed nodes. Store it here so the
controller can fetch it at boot.

```hcl
resource "aws_secretsmanager_secret" "ansible_ssh_key" {
  name        = "ansible-lab/ssh-private-key"
  description = "Private key for Ansible to connect to managed nodes"
}

resource "aws_secretsmanager_secret_version" "ansible_ssh_key" {
  secret_id     = aws_secretsmanager_secret.ansible_ssh_key.id
  secret_string = file("${path.module}/ansible_managed_node_private_key")
}
```

### GitHub Repo URL (SSM Parameter Store)
Non-secret config — SSM is fine for this.

```hcl
resource "aws_ssm_parameter" "github_repo" {
  name  = "/ansible-lab/github-repo-url"
  type  = "String"
  value = "https://github.com/iamakshu29/Ansible-end-to-end.git"
}
```

> **IAM:** The controller's IAM role already needs `secretsmanager:GetSecretValue`
> and `ssm:GetParameter` permissions. Add these to `role_and_policy.tf`.

---

## 3. Jenkins — Auto-configure via JCasC (No manual UI)

`jenkins.yaml` is already deployed by Packer and JCasC plugin is installed.
It currently only sets up the local user. Extend it to auto-create credentials
and the Multibranch Pipeline job.

### 3a. Fix hardcoded password
The current `jenkins.yaml` has a plaintext password. Replace with an env var
injected from Secrets Manager at EC2 boot (via `user_data` or a startup script).

```yaml
securityRealm:
  local:
    allowsSignup: false
    users:
      - id: "${JENKINS_ADMIN_USER}"
        password: "${JENKINS_ADMIN_PASSWORD}"
```

### 3b. Add GitHub credentials to `jenkins.yaml`
`GITHUB_PAT` is injected as an env var fetched from Secrets Manager at boot.

```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - string:
              scope: GLOBAL
              id: "github-pat"
              secret: "${GITHUB_PAT}"
              description: "GitHub PAT for repo checkout"
          - basicSSHUserPrivateKey:
              scope: GLOBAL
              id: "ansible-ssh-key"
              username: "ubuntu"
              privateKeySource:
                directEntry:
                  privateKey: "${ANSIBLE_SSH_PRIVATE_KEY}"
              description: "SSH key for Ansible managed nodes"
```

### 3c. Auto-create Multibranch Pipeline job in `jenkins.yaml`
`job-dsl` plugin is already installed. Add a `jobs` block so the pipeline is
created on first boot — no manual UI setup needed.

```yaml
jobs:
  - script: >
      multibranchPipelineJob('ansible-lab') {
        branchSources {
          github {
            id('github-source')
            repoOwner('iamakshu29')
            repository('Ansible-end-to-end')
            credentialsId('github-pat')
            traits {
              gitHubBranchDiscovery { strategyId(1) }
              gitHubPullRequestDiscovery { strategyId(1) }
            }
          }
        }
        factory {
          workflowBranchProjectFactory {
            scriptPath('Jenkins_Pipeline/jenkinsfile')
          }
        }
        triggers {
          periodic(5)
        }
      }
```

### 3d. Inject env vars at EC2 boot (user_data in Terraform)
The controller needs to fetch secrets from Secrets Manager before Jenkins starts,
then export them so JCasC can read `${GITHUB_PAT}` etc.

**Add `user_data` to the controller instance in `ec2.tf`:**
```bash
#!/bin/bash
export GITHUB_PAT=$(aws secretsmanager get-secret-value \
  --secret-id ansible-lab/github-pat \
  --query SecretString --output text --region us-east-1)

export ANSIBLE_SSH_PRIVATE_KEY=$(aws secretsmanager get-secret-value \
  --secret-id ansible-lab/ssh-private-key \
  --query SecretString --output text --region us-east-1)

# Write key to disk for Ansible
mkdir -p /home/ubuntu/.ssh
echo "$ANSIBLE_SSH_PRIVATE_KEY" > /home/ubuntu/.ssh/ansible_managed_node
chmod 600 /home/ubuntu/.ssh/ansible_managed_node
chown ubuntu:ubuntu /home/ubuntu/.ssh/ansible_managed_node

# Pass to Jenkins environment for JCasC
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/secrets.conf <<EOF
[Service]
Environment="GITHUB_PAT=${GITHUB_PAT}"
Environment="ANSIBLE_SSH_PRIVATE_KEY=${ANSIBLE_SSH_PRIVATE_KEY}"
EOF

systemctl daemon-reload
systemctl restart jenkins
```

---

## 4. Dynamic Inventory Config (missing file on controller)

The `aws_ec2.yml` plugin config needs to exist on the controller.
Either bake it into the AMI or write it via `user_data`.

**File: `/etc/ansible/aws_ec2.yml`**
```yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  tag:Role: worker
  tag:Environment: lab
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
hostnames:
  - private-ip-address
compose:
  ansible_host: private_ip_address
```

**Add to `user_data`:**
```bash
cat > /etc/ansible/aws_ec2.yml <<'EOF'
plugin: amazon.aws.aws_ec2
...
EOF
```

> **IAM:** Controller role needs `ec2:DescribeInstances` — check `role_and_policy.tf`.

---

## 5. Trigger Jenkins Pipeline via API (No UI)

Once Jenkins is up, trigger runs from terminal:

```bash
# Get the controller IP from Terraform output
JENKINS_URL=$(terraform -chdir=Infra/terraform output -raw controller_public_ip)

# Trigger a parameterized build
curl -X POST "${JENKINS_URL}/job/ansible-lab/job/main/buildWithParameters" \
  --user "iamakshu:<api-token>" \
  --data "PLAYBOOK_PATH=01_Variables_Facts_Jinja2/01_variable_sources.yml" \
  --data "INVENTORY_PATH=01_Variables_Facts_Jinja2/inventory/inventory.yml" \
  --data "TAG_NAME=Role" \
  --data "TAG_VALUE=worker"
```

Generate API token: Jenkins UI → User → Configure → API Token (one-time setup).

---

## Summary Checklist

| # | Task | File(s) to change |
|---|------|-------------------|
| 1a | Add tags to EC2 instances | `terraform/ec2.tf` |
| 1b | Add public IP outputs | `terraform/outputs.tf` (new) |
| 2a | Secrets Manager for GitHub PAT | `terraform/secrets.tf` (new) |
| 2b | Secrets Manager for SSH private key | `terraform/secrets.tf` (new) |
| 2c | SSM Parameter for GitHub repo URL | `terraform/secrets.tf` (new) |
| 2d | IAM permissions for Secrets Manager + SSM | `terraform/role_and_policy.tf` |
| 3a | Fix hardcoded Jenkins password | `packer/jenkins.yaml` |
| 3b | Add GitHub credentials to JCasC | `packer/jenkins.yaml` |
| 3c | Auto-create Multibranch Pipeline job | `packer/jenkins.yaml` |
| 3d | user_data to inject secrets at boot | `terraform/ec2.tf` |
| 4  | Dynamic inventory config on controller | `terraform/ec2.tf` (user_data) |
| 5  | Jenkins API trigger script | `Jenkins_Pipeline/trigger.sh` (new) |
