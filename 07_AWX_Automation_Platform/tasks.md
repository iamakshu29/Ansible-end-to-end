# Phase 07 — AWX / Ansible Automation Platform

## Before you start — be comfortable with:

- Everything from Phases 01 through 06
- Roles, collections, vault, and dynamic inventory — all of it
- What a Git repository is and how playbooks are stored in one
- Basic RBAC concepts (roles, permissions, users, groups)

This is the final phase. AWX is what companies actually run in production. Individual `ansible-playbook` commands from a terminal are for development and testing. Production automation at a company goes through AWX or AAP. You can run AWX locally with Docker Compose — do that for this phase.

---

## What this phase covers

AWX is the open-source upstream of Red Hat Ansible Automation Platform (AAP). It provides a web UI, REST API, RBAC, scheduling, job history, and centralized credential management — everything needed for team-scale Ansible.

---

## Setup — Run AWX Locally First

Before any exercise, get AWX running. Without a running instance, this phase is just reading.

**Option 1 — Docker Compose (easier, recommended for learning):**

Follow the AWX GitHub README: [https://github.com/ansible/awx/blob/devel/tools/docker-compose/README.md](https://github.com/ansible/awx/blob/devel/tools/docker-compose/README.md)

**Option 2 — AWX Operator on Kubernetes:**

Requires minikube or kind: [https://github.com/ansible/awx-operator](https://github.com/ansible/awx-operator)

Once AWX is running: open the web UI in your browser (usually `http://localhost`), log in with the default admin credentials, and spend 10 minutes clicking through every menu item before starting exercises. Do not follow instructions yet — just look at what exists in each section.

---

## Folder structure to build as you go

```
07_AWX_Automation_Platform/
  awx-demo-project/           <- push this to GitHub for AWX to pull
    inventory/
      hosts.yml
    roles/
      demo_app/
        tasks/main.yml
        defaults/main.yml
    group_vars/
      all/
        vars.yml
        vault.yml
    site.yml
  notes/
    01_awx_setup.md
    02_objects_walkthrough.md
    03_api_calls.md
```

Write notes as you work through each exercise. These become your interview material.

---

## Concepts to Master

---

### 1. AWX architecture — what is actually running

| Component | Role |
|---|---|
| Web UI | browser interface for everything |
| REST API | every UI action is backed by an API — fully automatable |
| PostgreSQL | stores all config, job results, credentials, users |
| Redis | job queue, coordinates work between components |
| Task runners | processes that actually execute `ansible-playbook` under the hood |

**Key point:** AWX does NOT replace Ansible. It is a control plane ON TOP of Ansible. Under the hood it still runs `ansible-playbook` — just managed, orchestrated, and audited.

**Exercise — notes/01_awx_setup.md:**

After setting up AWX, write down:
- Which deployment method did you use?
- What port is the UI on?
- What containers or pods are running? (`docker ps` or `kubectl get pods`)
- What is each container responsible for?

This forces you to understand what you installed, not just that it works.

---

### 2. Core objects — the building blocks you work with every day

**Organizations:**
Top-level containers. Everything belongs to an org. Used for multi-tenancy and RBAC isolation.

**Inventories:**
Same concept as Ansible inventory, managed in AWX. Types: manual (you define hosts) or sourced (synced from cloud plugin or script).

**Credentials:**
Centralized, encrypted secret storage. Never exposed in plaintext in the UI.

| Credential Type | Used for |
|---|---|
| Machine | SSH key/password for connecting to hosts |
| Vault | Ansible Vault password |
| Source Control | Git username/token for pulling playbooks |
| Amazon Web Services | AWS API access |
| Custom | define your own schema |

**Projects:**
A link to a Git repository containing your playbooks. AWX pulls the repo (git clone/pull) before running a job. This enforces: playbook code lives in Git, not in AWX.

**Job Templates:**
The main runnable unit. Defines: Project + Inventory + Playbook file + Credentials + Extra Variables + Tags + Limit.

**Workflow Job Templates:**
A DAG of Job Templates connected by conditions (On Success, On Failure, Always).

**Exercise — notes/02_objects_walkthrough.md:**

In the AWX UI, create each of these in order:
- Organization: `"Demo Org"`
- Two Users: `developer1` and `ops_lead`
- Team: `"App Developers"` with `developer1` as a member
- Make `ops_lead` an admin of Demo Org

---

### 3. Projects — connecting AWX to Git

**Exercise:**

- Create a Git repo on GitHub called `awx-demo-project`
- Push the `awx-demo-project/` folder from this phase's folder structure to that repo
- Make sure `site.yml` calls the `demo_app` role against `localhost`
- In AWX UI, go to **Projects → Add**:
  - SCM Type: Git
  - Paste your repo URL
  - Set the branch (main or master)
  - Save, then click the sync icon to pull the repo
- Watch the sync job run. Verify it succeeded.
- Make a change to `site.yml` in GitHub. Sync the project again. Verify AWX pulled the new version.

---

### 4. Inventories and Credentials

**Inventory Exercise:**

- In AWX create a new Inventory: `"Demo Inventory"`
- Add a Host manually: `localhost` with variable `ansible_connection=local`
- Add a Group `webservers` and put `localhost` in it
- Add an Inventory Source: point it to your `awx-demo-project` repo and a `hosts.yml` file
- Sync it. Verify hosts from your file appear in the inventory.

**Credentials Exercise:**

- Go to **Credentials → Add**:
  - Machine credential: name `"localhost-cred"`, type Machine, set `become` method to `sudo`
  - Vault credential: name `"vault-cred"`, type Vault, enter the vault password you used
- Note: after saving, you never see the secret value again in the UI. That is the point.

---

### 5. Job Templates in depth

**Exercise:**

- In AWX create a Job Template:
  - Name: `"Deploy Demo App"`
  - Job Type: Run
  - Inventory: Demo Inventory
  - Project: your `awx-demo-project`
  - Playbook: `site.yml`
  - Credentials: attach both `localhost-cred` and `vault-cred`
  - Extra Variables: `app_version: "1.0.0"`
- Save it. Click **Launch**.
- Watch the job run in real time. Read the output. Verify it matches running `ansible-playbook` from terminal.
- Run the same Job Template a second time. Idempotent tasks show `ok`.

**Add a Survey:**

- Edit the Job Template. Click **Survey → Add a question**:
  - Question: `"Application Version"`, Variable name: `app_version`, Type: Text, Default: `"1.0.0"`
- Launch again. The survey form appears. Enter `"2.0.0"`. Submit.
- Verify the playbook ran with `app_version=2.0.0`.

---

### 6. Workflow Templates — chaining jobs

**Exercise:**

- Create four simple Job Templates:
  - `"Deploy"` — runs `site.yml`
  - `"Smoke Test"` — playbook that prints `"Running health checks..."`
  - `"Notify"` — playbook that prints `"Sending notification..."`
  - `"Rollback"` — playbook that prints `"Rolling back..."`

- Create a Workflow Template called `"Full Deployment Workflow"`:
  - Node 1: Deploy
  - On Success → Node 2: Smoke Test
  - On Success → Node 3: Notify
  - On Failure of Deploy → Node 4: Rollback
  - Always (after either path) → Node 5: Notify

- Launch the Workflow. Watch it execute.
- Break `site.yml` with a YAML syntax error. Push to GitHub. Sync the project. Launch the Workflow again.
- Watch: Deploy fails → Rollback runs → Notify still runs.
- Fix the syntax error. Push, sync, launch. Success path runs.

---

### 7. RBAC — who can do what

**Exercise:**

In AWX apply these permissions:
- Give **App Developers** team: `Execute` permission on the Deploy Job Template (they can run it, not edit it)
- Give `developer1`: `Use` permission on Demo Inventory (they can use it in a job, not modify hosts)
- Give `developer1`: NO permission on the Vault credential (they should not access it directly)
- Give `ops_lead`: `Admin` permission on everything in Demo Org

Log out of admin. Log in as `developer1`:
- Try to run the Deploy Job Template → should work
- Try to edit the Job Template → should be blocked
- Try to see the Vault credential value → should be blocked

Log back in as admin. This is RBAC in practice.

---

### 8. REST API — automating AWX itself

Every UI action maps to an API call. The base URL is `http://localhost/api/v2/`.

**Exercise — notes/03_api_calls.md:**

Open `http://localhost/api/v2/` in your browser. Click through every endpoint. Read what each returns.

Then use PowerShell to make API calls:

**Step 1 — Get an auth token:**
- `POST /api/v2/tokens/` with your admin credentials
- Save the token value

**Step 2 — List all Job Templates:**
- `GET /api/v2/job_templates/` with `Authorization: Bearer <token>` in the header
- Find the ID of your `"Deploy Demo App"` template

**Step 3 — Launch a job via API:**
- `POST /api/v2/job_templates/{id}/launch/` with extra_vars as JSON in the body: `{"app_version": "3.0.0"}`
- Find the job ID in the response

**Step 4 — Check the job status:**
- `GET /api/v2/jobs/{job_id}/` with the token
- Read the `status` field. Poll until `status == "successful"` or `"failed"`

Write the exact commands, responses, and what you learned in `notes/03_api_calls.md`. This is what CI/CD pipelines do — Jenkins or GitHub Actions calls these exact endpoints to trigger deployments.

---

## Break stuff on purpose

- Push a playbook with a YAML syntax error to GitHub. Sync the project. Launch a job using that playbook. Read the error in AWX output. Fix, push, sync, relaunch.
- Create a Job Template with the wrong vault credential (wrong password). Launch it. Read the error. This is what expired vault passwords look like in production.
- Log in as `developer1`. Try to access the Vault credential via the API using its ID. Can you see the secret? What does AWX return for the password field?
- Set a Job Template to disallow concurrent runs (the default). Try to launch it twice simultaneously from two browser tabs. What happens to the second launch?

---

## Mini Project — End-to-End AWX Automation Pipeline

Build a complete project demonstrating AWX at a company-level standard.

**Git repo (`awx-demo-project`) must have:**

- `site.yml` calling the `demo_app` role
- `demo_app` role with `defaults/main.yml`, `tasks/main.yml`, one template file
- `group_vars/all/vault.yml` (encrypted) with at least one secret
- `group_vars/all/vars.yml` referencing the vault secret

**In AWX configure:**

- Organization: Demo Org
- Two users: `developer1` and `ops_lead`
- Team: App Developers (`developer1` is a member)
- Project synced from your GitHub repo
- Inventory with localhost and a `webservers` group
- Machine credential and Vault credential (two separate objects)
- Job Template `"Deploy Demo App"` with a Survey asking for `app_version`
- Workflow Template with at least 3 nodes: Deploy → Smoke Test → Notify

**RBAC:**

- App Developers team has `Execute` on the Job Template, not `Admin`
- `ops_lead` has `Admin` on the Organization
- Verify `developer1` can run but not edit the Job Template

**API:**

- Trigger the Job Template via REST API (PowerShell or curl)
- Pass `app_version` as an extra variable via the API call
- Poll the job status via the API until it completes
- Write the exact commands and responses in `notes/03_api_calls.md`

**Stretch goals:**

- Add a second branch in GitHub (`staging`). Create a second Project pointing to `staging`. Create a second Job Template for staging. Show how the same role deploys to different environments.
- Add a Notification Template that posts to a Slack webhook on job failure
- Schedule the Deploy Job Template to run at a fixed time daily using the **Schedules** feature

---

## Interview Prep — Questions Across All Phases

By this point you should be able to answer every one of these without looking at notes. If you cannot, go back to that phase.

---

**Q: What is idempotency and why does it matter?**

Same end state on every run. Matters because playbooks run repeatedly in production. A non-idempotent task corrupts state on re-run.

---

**Q: What is the difference between `import_tasks` and `include_tasks`?**

Static vs dynamic. `import` at parse time: tags work on inner tasks, no loops, `when` applies to every task inside. `include` at runtime: loops work, variable filenames work, tags do not penetrate inside.

---

**Q: Explain Ansible variable precedence.**

22 levels. Extra vars (`-e`) at the very top. Role `defaults` at the very bottom. `host_vars` beats `group_vars`. Task vars beat play vars beat inventory vars.

---

**Q: How do you handle secrets in Ansible?**

Ansible Vault (AES-256). Encrypt vars files. Use vault IDs per environment. Store vault password in CI secret store. Never commit plaintext. Pattern: `vault.yml` encrypted, `vars.yml` references `vault_` prefixed variables.

---

**Q: What is the difference between role `defaults` and role `vars`?**

`defaults`: lowest precedence — overridable public interface. `vars`: high precedence — internal constants not meant to be overridden from outside.

---

**Q: What is the difference between roles and collections?**

Roles: reusable automation unit. Collections: packaging format containing multiple roles + modules + plugins, versioned and installable from Galaxy/Hub.

---

**Q: How do you make a `shell` or `command` task idempotent?**

Use `creates:`/`removes:` parameters, or a `when:` check with `stat` module beforehand, or `changed_when: false` for tasks that never change state.

---

**Q: How does Ansible scale to hundreds of hosts?**

Increase `forks`. Enable SSH pipelining. Use fact caching. Disable `gather_facts` where not needed. Use `async` for long-running tasks. Use `serial` for rolling deploys. Use AWX for orchestration and parallel team access.

---

**Q: What is Molecule and why use it?**

Testing framework for roles. Creates a test instance, runs the role, verifies the result, destroys the instance. Catches idempotency bugs and regressions before they reach production.

---

**Q: What is AWX? When would a company use it?**

Web UI + REST API + RBAC + scheduling + audit trail for Ansible at team scale. Use when multiple teams run playbooks, when you need access control and audit logs, or when CI/CD needs to trigger deployments via API.

---

**Q: What is the difference between Ansible and Terraform?**

Ansible: configuration management, app deployment, OS-level tasks, push-based. Terraform: infrastructure provisioning — creating and destroying cloud resources. They complement each other: Terraform creates the VMs, Ansible configures them.

---

## Vocabulary to know cold

| Term | Definition |
|------|-----------|
| AWX | open-source web UI and API for Ansible; upstream of AAP |
| AAP | Ansible Automation Platform — Red Hat's enterprise paid product |
| Job Template | a saved runnable configuration: playbook + inventory + credentials |
| Job | a single execution of a Job Template |
| Workflow Template | a DAG of Job Templates with conditional branching |
| Survey | a UI form for collecting runtime variables before a job runs |
| Credential | a securely stored secret in AWX (SSH key, password, API token) |
| Project | a link to a Git repo; AWX syncs and runs playbooks from here |
| Inventory Source | a dynamic source that AWX syncs to populate an inventory |
| RBAC | role-based access control — who can do what to which AWX objects |
| Organization | top-level tenant boundary in AWX for multi-team isolation |
| `set_stats` | Ansible module that passes data from one Workflow node to the next |

---

## Resources

- [AWX Project on GitHub](https://github.com/ansible/awx)
- [AWX Operator on Kubernetes](https://github.com/ansible/awx-operator)
- [AWX Documentation](https://ansible.readthedocs.io/projects/awx/)
- [Ansible Automation Platform Docs (Red Hat)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform)
- [AWX REST API Guide](https://docs.ansible.com/automation-controller/latest/html/controllerapi/index.html)
- [awx CLI Docs](https://docs.ansible.com/automation-controller/latest/html/controllercli/index.html)
- [Jeff Geerling — Infrastructure Automation with AWX](https://www.jeffgeerling.com/blog/2022/automating-my-entire-infrastructure-ansible)
