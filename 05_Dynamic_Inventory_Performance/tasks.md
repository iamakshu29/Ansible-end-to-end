# Phase 05 — Dynamic Inventory & Performance Tuning

## Before you start — be comfortable with:

- Everything from Phases 01 through 04
- How `group_vars` and `host_vars` work with static inventory (Phase 01)
- What `ansible.cfg` is and its basic settings
- What facts are and why fact gathering takes time (Phase 01)

Static inventory breaks down at scale. This phase is what makes Ansible practical in a real company running hundreds of hosts on cloud infrastructure.

---

## What this phase covers

Dynamic inventory: querying live infrastructure instead of maintaining static host files. Performance tuning: making Ansible run faster when you have many hosts. This is the gap between hobbyist Ansible and company-level Ansible.

---

## Folder structure to build as you go

```
05_Dynamic_Inventory_Performance/
  inventory/
    static/
      inventory.yml
    dynamic/
      constructed.yml       <- constructed plugin config
      aws_ec2.yml           <- AWS plugin config (if you have AWS access)
    combined/
      inventory.yml             <- static bastion hosts
      constructed.yml       <- dynamic cloud hosts
  ansible.cfg
  01_static_problem.md      <- notes on why static inventory fails at scale
  02_constructed_plugin.yml
  03_performance_tuning.yml
  04_async_tasks.yml
  project_inventory_report.yml
```

---

## Concepts to Master

---

### 1. Why static inventory breaks down — understand the problem first

- In cloud environments, hosts come and go constantly
- Maintaining a `inventory.yml` by hand means it is always partially stale
- Every new VM requires a manual file edit and a git commit
- Dynamic inventory solves this: Ansible queries the cloud API at runtime and builds the current live host list every time it runs

**Exercise — 01_static_problem.md:**

- Open your existing static inventory from earlier phases
- Imagine you have 200 EC2 instances and 10 new ones spin up today
- Write out (in `01_static_problem.md`) the manual steps you would need to update static inventory correctly with the right groups
- Write what could go wrong if the file is not updated
- This is the problem dynamic inventory eliminates

---

### 2. Inventory plugins vs scripts

| | Inventory Plugin | Inventory Script |
|---|---|---|
| Format | YAML config file | Python script |
| Status | Modern, recommended | Old, still works |
| Configured via | `.yml` file with `plugin:` key | Python file, executable |
| Maintained | Actively by Ansible | Community/manual |

Enable plugins in `ansible.cfg`:

```ini
[inventory]
enable_plugins = constructed, yaml, ini, aws_ec2
```

**Exercise — ansible.cfg:**

- Create `ansible.cfg` in this phase folder with the above settings
- Add `inventory = ./inventory/dynamic/` so Ansible looks there by default

---

### 3. Constructed inventory plugin — create groups from any data source

The constructed plugin is the easiest to practice without cloud access. It works ON TOP of your existing static inventory and creates new groups dynamically from variable values.

**Exercise — inventory/dynamic/constructed.yml:**

- Create `inventory/static/inventory.yml` with 4 hosts and inline variables:

```ini
web01 env=prod role=web
web02 env=staging role=web
db01  env=prod role=db
db02  env=staging role=db
```

- Create `inventory/dynamic/constructed.yml` with `plugin: constructed`
- Use `groups:` to create:
  - `production_hosts` — any host where `env == "prod"`
  - `staging_hosts` — any host where `env == "staging"`
  - `web_tier` — any host where `role == "web"`
- Use `keyed_groups:` to automatically create groups from the `env` variable values (e.g., `env=prod` creates a group called `env_prod` automatically)
- Write `02_constructed_plugin.yml` that prints `group_names` for each host
- Run it. Verify each host shows the correct dynamically-created groups
- This is the SAME mechanism used with AWS EC2 tags in production — just without the cloud

---

### 4. AWS EC2 inventory plugin — the most common in companies

> If you have AWS access, do the full exercise. If not, read and understand the structure — the concepts are identical to the constructed plugin you just built.

- Plugin name: `amazon.aws.aws_ec2`
- Config file must end in `aws_ec2.yml` or `aws_ec2.yaml`
- Key config options:
  - `regions:` — which AWS regions to query
  - `filters:` — e.g., `{instance-state-name: running}` — only running instances
  - `hostnames:` — what to use as the Ansible hostname (private IP, public DNS, etc.)
  - `keyed_groups:` — create groups from EC2 tag values
  - `compose:` — add variables computed from instance attributes

**Exercise (with AWS access):**

- Install the collection: `ansible-galaxy collection install amazon.aws`
- Create `inventory/dynamic/aws_ec2.yml` that queries your region, filters to running instances, and creates groups from `Environment` and `Role` tags
- Run: `ansible-inventory -i inventory/dynamic/aws_ec2.yml --graph`
- Read the group tree. See how your EC2 tags became Ansible groups.

**Exercise (without AWS access):**

- Run `ansible-inventory --list` on your static inventory
- Read the JSON structure carefully — `_meta`, `hostvars`, group membership
- This is the exact format a dynamic inventory plugin must output. Understanding it matters.

---

### 5. Combined inventory — mixing static and dynamic sources

- Put multiple inventory files or configs in one directory
- Ansible merges ALL sources found in the directory
- Groups and hosts from all sources are combined into one unified inventory

**Exercise — inventory/combined/:**

- Create `inventory/combined/inventory.yml` with one static `bastion` host
- Create `inventory/combined/constructed.yml` pointing to your 4 static test hosts
- In `ansible.cfg` set `inventory = ./inventory/combined/`
- Run `ansible-inventory --graph`
- Verify both the static bastion host AND the constructed dynamic groups appear together in the same graph

---

### 6. Performance tuning

**Exercise — 03_performance_tuning.yml:**

Add each setting ONE AT A TIME to `ansible.cfg` and test the impact.

**Step 1 — Increase forks:**

```ini
[defaults]
forks = 10
```

- Write a playbook that runs a simple task against all 4 test hosts
- Run with `forks = 1`, then `forks = 4`. Time both runs. Observe the difference.

**Step 2 — Enable pipelining:**

```ini
[ssh_connection]
pipelining = True
```

- Run the same playbook. Note the time. (On localhost the difference is minimal — understand WHY it helps on real SSH hosts: it batches SSH operations into one connection instead of reconnecting per module.)

**Step 3 — Disable fact gathering where not needed:**

- Add `gather_facts: false` to a playbook that does not use any `ansible_facts`
- Run with and without `gather_facts`. Time the difference.
- On 100 hosts, skipping fact gathering saves several minutes.

**Step 4 — gather_subset:**

- Instead of `gather_facts: false`, use: `gather_subset: ['!all', '!min', 'network']`
- This collects ONLY network facts instead of everything
- Run it. Print `ansible_facts`. Notice how much less data there is.

---

### 7. Async tasks — run long tasks without blocking

- `async: 300` — the task is allowed up to 300 seconds to complete
- `poll: 10` — check task status every 10 seconds
- `poll: 0` — fire and forget: start the task and immediately move on
- `async_status` module — check the result of a `poll: 0` task later

**Exercise — 04_async_tasks.yml:**

- Write a task: `command: sleep 10`. Run it normally. The play blocks 10 seconds.
- Add `async: 30, poll: 5`. Run. Ansible polls every 5 seconds and reports when done.
- Change to `poll: 0`. Register the result with `register: async_result`. The task starts and the play immediately moves on.
- Add a second task using `async_status` module to check the result:
  - `jid: "{{ async_result.ansible_job_id }}"`
  - `until` the status is `finished`, `retries: 10`, `delay: 3`
- Run it. Understand the fire-and-forget pattern.

---

## Break stuff on purpose

- In `constructed.yml` — write a `groups:` condition with a Jinja2 syntax error. Run `ansible-inventory --list`. Read the error.
- Set `forks = 200`. Run a play against 10 hosts. Watch system resources (open Task Manager or `top` while it runs). Understand the risk.
- Set `gather_facts: false` and then try to use `ansible_facts['distribution']` in a task. Run it. Read the error. This is why you cannot disable facts blindly.
- Use `poll: 0` to fire an async task. Do NOT add an `async_status` check. The play exits `succeeded`. Is the background task done? How would you know? This is the trap.

---

## Mini Project — Inventory-Driven Environment Report

Build a combined static + constructed inventory setup and a playbook that uses it.

**Requirements:**

- `inventory/inventory.yml` with 6 hosts across two groups: `webservers`, `databases`
- Each host has inline variables: `env` (prod or staging) and `tier` (web or db)
- `inventory/constructed.yml` that creates:
  - `production` group — all hosts where `env == "prod"`
  - `staging` group — all hosts where `env == "staging"`
  - Keyed groups from the `tier` variable automatically
- Playbook that:
  - Runs against all hosts
  - Prints for each host: `inventory_hostname`, which groups it belongs to, and whether it is in the `production` group
  - Uses `gather_subset` to collect only network and virtual facts (not everything)
  - Has one task with `async: 20, poll: 5` to simulate a slow operation
  - Prints total memory from facts for hosts where it is available
- `ansible.cfg` with: `forks = 4`, `pipelining = True`, smart fact caching enabled

**Stretch goals:**

- Add a bastion host to the inventory that is only in the static `inventory.yml` (not in any dynamic group)
- Use `compose:` in `constructed.yml` to add a new variable `environment_label` combining `env` and `tier` (e.g., `"prod-web"`, `"staging-db"`)
- Add a second play that only runs against the `production` group and prints a warning

**Files to create:**

- `05_Dynamic_Inventory_Performance/inventory/inventory.yml`
- `05_Dynamic_Inventory_Performance/inventory/constructed.yml`
- `05_Dynamic_Inventory_Performance/ansible.cfg`
- `05_Dynamic_Inventory_Performance/project_inventory_report.yml`

---

## Vocabulary to know cold

| Term | Definition |
|------|-----------|
| dynamic inventory | inventory built by querying a live system at runtime |
| inventory plugin | a YAML-configured component that queries an external source |
| `forks` | number of parallel SSH connections Ansible opens simultaneously |
| pipelining | SSH optimization that batches module operations into fewer connections |
| fact caching | storing gathered facts to disk or Redis to skip re-gathering |
| `async` | run a task in the background without blocking the play |
| `poll` | how often in seconds to check the status of an async task |
| `keyed_groups` | auto-create Ansible groups from attribute or tag values |
| `constructed` | an inventory plugin that layers groups/vars on top of another source |

---

## Resources

- [Inventory Plugins](https://docs.ansible.com/ansible/latest/plugins/inventory.html)
- [Constructed Inventory Plugin](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/constructed_inventory.html)
- [AWS EC2 Inventory Plugin](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Working with Dynamic Inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_dynamic_inventory.html)
- [Async Actions and Polling](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_async.html)
- [Performance Tips](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
