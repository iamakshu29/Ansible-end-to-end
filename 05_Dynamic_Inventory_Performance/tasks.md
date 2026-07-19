# Phase 05 — Dynamic Inventory & Performance Tuning

## Before you start — be comfortable with:

- Everything from Phases 01 through 04
- How `group_vars` and `host_vars` work with static inventory (Phase 01)
- What `ansible.cfg` is and its basic settings
- What facts are and why fact gathering takes time (Phase 01)

Static inventory breaks down at scale. This phase is what makes Ansible practical in a real company running hundreds of hosts on cloud infrastructure.

---

## What "dynamic inventory" actually means

**Static inventory**: you write a YAML file listing every host. When a server is added or removed, you edit the file manually. At 200 servers this is painful. At 500 it is unmanageable.

**Dynamic inventory**: Ansible runs a query at playbook-start and builds the host list from a live system — AWS, Azure, GCP, a CMDB, etc. You never touch a hosts file. The list is always current.

This phase teaches you how dynamic inventory works, how to practice it without cloud access, and how to make Ansible faster once you have many hosts.

---

## Inventory Plugins vs Inventory Scripts — one clear explanation

Both do the same job: give Ansible a list of hosts and their variables.

**Inventory Script (old, avoid)**

- A Python or bash script you write or download from somewhere
- Ansible runs it as an executable and reads the JSON from stdout
- You manage the script, its dependencies, and a separate config file
- Still works but actively being replaced

**Inventory Plugin (modern, use this always)**

- A YAML config file with a `plugin:` key at the top
- Ansible's built-in plugin code handles all the API calls for you
- You only write the YAML config describing what to query and how to group results
- Maintained by the Ansible team or collection authors
- Version-controllable, readable, no code to manage

**Rule: use plugins. Forget scripts exist unless you're maintaining old code.**

The most important plugins:

| Plugin                          | What it queries                                   |
| ------------------------------- | ------------------------------------------------- |
| `ansible.builtin.constructed` | sits on top of any other source, adds groups/vars |
| `ansible.builtin.yaml`        | reads YAML inventory files                        |
| `amazon.aws.aws_ec2`          | queries AWS EC2 API                               |
| `azure.azcollection.azure_rm` | queries Azure Resource Manager                    |
| `google.cloud.gcp_compute`    | queries GCP Compute Engine                        |

---

## The constructed plugin — very important

The `ansible.builtin.constructed` plugin is one of the most used plugins in real deployments. Here is what it does:

1. Reads hosts from another inventory source you point it at (static YAML, AWS EC2, anything)
2. Lets you create groups dynamically based on variable values on those hosts
3. Lets you auto-create groups from any variable's values automatically
4. Lets you add computed variables to hosts

**Why it matters in production**: AWS gives you EC2 instances with tags like `Environment=prod` and `Role=web`. The constructed plugin turns those tags into Ansible groups automatically. Your playbook then just targets `production` or `web_tier` without caring which specific IPs are in those groups right now.

**Why you CAN practice it without cloud access**: The constructed plugin works on top of static inventory too. You define hosts with variables in static YAML, point constructed at that file, and it builds groups from the variables. The logic is identical. That is exactly what this phase does.

---

## Note on ansible.cfg format

`ansible.cfg` always uses INI format — that is how Ansible reads it and it never changes. This is not the "old way", it is the only format for `ansible.cfg`.

Your **inventory files** use YAML. Do not mix this up.

```
ansible.cfg      ← always INI format (that's correct)
inventory/*.yml  ← YAML format for all inventory files
```

---

## Folder structure for this phase

```
05_Dynamic_Inventory_Performance/
  inventory/
    static/
      inventory.yml         ← YAML static inventory with host variables
    dynamic/
      constructed.yml       ← constructed plugin — reads static, adds groups
      aws_ec2.yml           ← AWS plugin config (only if you have AWS access)
    combined/
      inventory.yml         ← a bastion host (static)
      constructed.yml       ← constructed reading static hosts
  ansible.cfg
  01_static_problem.md
  02_constructed_plugin.yml
  03_performance_tuning.yml
  04_async_tasks.yml
  project_inventory_report.yml
```

---

## Exercise 1 — Static inventory with inline variables

**Exercise — inventory/static/inventory.yml:**

- Create 4 hosts in the `all` group: `web01`, `web02`, `db01`, `db02`
- Each host needs `ansible_connection: local` — this tells Ansible to connect to your own machine instead of opening SSH. Ansible still treats each entry as a separate logical host, so all grouping, variables, and facts work exactly as with real remote hosts.
- Give each host two inline variables: `env` (either `prod` or `staging`) and `role` (either `web` or `db`)
  - `web01`: prod, web | `web02`: staging, web | `db01`: prod, db | `db02`: staging, db
- Run: `ansible-inventory -i inventory/static/inventory.yml --graph`
- Run: `ansible-inventory -i inventory/static/inventory.yml --list`
- `--graph` shows the group tree. `--list` shows the full JSON — this JSON is the exact format any inventory plugin produces. All 4 hosts will be under `all` only, with no meaningful groups. This is what the constructed plugin fixes next.

---

## Exercise 2 — Constructed plugin

Key facts about `constructed` before writing the config:

- The config file starts with `plugin: ansible.builtin.constructed`
- `sources:` — a list of inventory files or directories for the plugin to read hosts from
- `groups:` — a dictionary of `group_name: "jinja2 condition"`.
  - Any host where the condition is true joins that group.
- `keyed_groups:` — auto-create groups from a variable's unique values. 
  - If `env` has values `prod` and `staging`, you get two groups automatically.
  - Each entry needs `key:` (the variable), `prefix:`, and `separator:`.
- `compose:` — add new computed variables to hosts using Jinja2 expressions

**Exercise — inventory/dynamic/constructed.yml:**

- Create the config file with `plugin: ansible.builtin.constructed`
- Set `sources:` to point at `inventory/static/inventory.yml`
- Use `groups:` to create: `production` (where `env == 'prod'`), `staging` (where `env == 'staging'`), `web_tier` (where `role == 'web'`), `db_tier` (where `role == 'db'`)
- Use `keyed_groups:` to auto-create groups from the `env` variable (prefix `env`) and from the `role` variable (prefix `role`)
- Use `compose:` to add a new variable `environment_label` that concatenates `env + '-' + role` on each host
- Run: `ansible-inventory -i inventory/dynamic/constructed.yml --graph`
- Compare the output to Exercise 1. Notice the new groups that didn't exist before.
- Run: `ansible-inventory -i inventory/dynamic/constructed.yml --list`
- Find `environment_label` in the output for each host under `hostvars`. Confirm its value.
- This is the SAME mechanism used with AWS EC2 tags. Replace the static source with `amazon.aws.aws_ec2` and `keyed_groups` with tag keys — the rest is identical.

**Exercise — 02_constructed_plugin.yml:**

- Write a playbook that runs against `all` with `gather_facts: false`
- Print `inventory_hostname`, `group_names`, and `environment_label` for every host
- Run it: `ansible-playbook -i inventory/dynamic/constructed.yml 02_constructed_plugin.yml`
- Verify each host shows the correct groups and the computed label

---

## Exercise 3 — Combined inventory directory

Ansible merges ALL inventory sources found in a directory into one unified inventory.

**Exercise — inventory/combined/:**

- Create `inventory/combined/bastion.yml` with one static host `bastion`, using `ansible_connection: local`, and give it `role: bastion`, `env: prod`
  - **Important**: name the file `bastion.yml`, not `inventory.yml`. Ansible processes files in a directory alphabetically — `b` comes before `c`, so `bastion.yml` is loaded before `constructed.yml`. If the static file is loaded after the constructed plugin runs, hosts from it get no groups applied and land in `@ungrouped:`.
- Create `inventory/combined/constructed.yml` with `plugin: constructed` and your `groups:` and `keyed_groups:` rules — do NOT use `sources:` (not supported on Ansible 2.10)
- Run: `ansible-inventory -i inventory/static/inventory.yml -i inventory/combined/ --graph`
- How it works: Ansible loads sources left to right. `-i inventory/static/inventory.yml` loads web01/web02/db01/db02. `-i inventory/combined/` loads bastion (from inventory.yml) and then the constructed plugin sees ALL 5 hosts already in inventory and applies its groups to them.
- Verify all 5 hosts appear and all groups are present — bastion will appear in `production` and `env_prod` because it has `env: prod`
- This is how real environments work: static file for fixed infra (bastion, jump hosts), dynamic plugin for cloud hosts — combined via a directory or multiple `-i` flags

---

## Exercise 4 — Performance tuning

The `ansible.cfg` controls defaults. Test one setting at a time.

**Exercise — 03_performance_tuning.yml:**

**Step 1 — Forks:**

- `forks` in `[defaults]` controls how many hosts Ansible talks to simultaneously (default: 5)
- Write a playbook that prints `inventory_hostname` for all 4 hosts
- Change `forks` to `1` in `ansible.cfg` and run — tasks run one host at a time (serial)
- Change `forks` to `4` and run — all 4 hosts run in parallel
- On localhost the time difference is tiny. On 100 real remote hosts, `forks=1` is 10+ minutes, `forks=20` is under a minute.

**Step 2 — Pipelining:**

- `pipelining = True` in `[ssh_connection]` — already set in `ansible.cfg`
- Pipelining has no visible effect with `ansible_connection: local` — it only matters over SSH
- What it does: normally Ansible opens a new SSH connection to copy the module script, then another to run it. Pipelining pipes the script directly over one connection.
- Run the playbook. Note it works. Understand the setting even if the difference is invisible here.

**Step 3 — Disable fact gathering:**

- Add a second play to `03_performance_tuning.yml` with `gather_facts: false`
- Run it. Notice the "Gathering Facts" step is skipped entirely
- On 100 hosts, fact gathering alone can take several minutes. Turning it off when facts are not needed is the single biggest speed win.

**Step 4 — gather_subset:**

- Instead of disabling facts entirely, use `gather_subset` to collect only what you need
- Available subsets include: `network`, `hardware`, `virtual`, `facter`, `ohai`
- Use `!all` and `!min` to turn off all defaults, then add only `network`
- Add a play that does this and prints `ansible_facts` — compare how little data comes back vs a full gather
- Notice that `ansible_facts['distribution']` is now undefined because you only collected network facts

---

## Exercise 5 — Async tasks

**Exercise — 04_async_tasks.yml — build step by step:**

**Step 1 — blocking task:**

- Write a task that runs `sleep 5` using the `command` module with `delegate_to: localhost`
- Run it. The play blocks for the full 5 seconds before moving on.

**Step 2 — async with polling:**

- Add `async: 30` and `poll: 3` to the same task
- `async: 30` — allow the task up to 30 seconds to complete
- `poll: 3` — check task status every 3 seconds
- Run it. Ansible starts the task, checks in every 3 seconds, and waits for completion. You see the polling output.

**Step 3 — fire and forget (poll: 0):**

- Change `poll:` to `0` and `register:` the result into a variable
- `poll: 0` means: start the task and immediately move on — do not wait
- Add a `debug` task after it with a message like "doing other work while task runs"
- Add another task using the `async_status` module to check back later:
  - use the `jid:` from your registered variable to identify the job
  - use `until:` to keep checking until `finished` is true
  - set `retries:` and `delay:` appropriately
- Run it. Verify the play moves past the slow task immediately and only waits at the `async_status` check

---

## Break stuff on purpose

- In `constructed.yml` — write a `groups:` condition with a Jinja2 syntax error (e.g., `"env =="` with nothing after it). Run `ansible-inventory --list`. Read the error message.
- Set `gather_facts: false` and then use `ansible_facts['distribution']` in a task. Run it. Ansible fails at runtime, not at parse time. This is why you cannot blindly disable facts.
- Use `poll: 0` to start an async task but do NOT add an `async_status` check. The playbook exits "succeeded". The background task is still running. How would you know if it failed? This is the trap of fire-and-forget.
- In `constructed.yml` — write a `groups:` condition referencing a variable that no host has (e.g., `nonexistent_var == 'value'`). Run it. Notice Ansible does not error — it silently skips hosts where the variable is undefined. This is important to know.

---

## AWS EC2 plugin — understand the structure (reference, no AWS needed)

The `amazon.aws.aws_ec2` plugin is the most common in real companies. Its config file (`aws_ec2.yml`) follows the exact same structure as `constructed.yml`:

- `plugin: amazon.aws.aws_ec2`
- `regions:` — which AWS regions to query
- `filters:` — e.g., only running instances
- `hostnames:` — which attribute to use as the Ansible hostname (private IP, public DNS, etc.)
- `keyed_groups:` — create groups from EC2 tag keys (same as you used in the constructed exercise)
- `compose:` — add computed variables (same as you used in the constructed exercise)

The only difference from what you built is the source of hosts: AWS API instead of a static file. The `keyed_groups` and `compose` keys behave identically.

**If you have AWS access:** install with `ansible-galaxy collection install amazon.aws`, write `inventory/dynamic/aws_ec2.yml`, and run `ansible-inventory -i inventory/dynamic/aws_ec2.yml --graph`

**If you don't:** you already understand the mechanism. The constructed exercise gave you the same mental model. You are not missing anything conceptual.

---

## Mini Project — Inventory-Driven Environment Report

Build a combined static + constructed setup and a playbook that reports on it.

**Requirements:**

- `inventory/combined/inventory.yml` with 6 hosts — `web01` through `web03` and `db01` through `db03`
  - All with `ansible_connection: local`
  - `web*` hosts: `env` alternates prod/staging, `role: web`
  - `db*` hosts: `env` alternates prod/staging, `role: db`
  - One extra `bastion` host with `role: bastion`, `env: prod`
- `inventory/combined/constructed.yml` that creates:
  - `production` group — `env == 'prod'`
  - `staging` group — `env == 'staging'`
  - Keyed groups from `role` automatically
  - `compose` that adds `environment_label` = `env + '-' + role`
- `project_inventory_report.yml` playbook that:
  - Runs against `all`
  - Prints `inventory_hostname`, `group_names`, `environment_label` for every host
  - Uses `gather_subset: ['!all', '!min', 'network']` (not full facts)
  - Has one async task (`sleep 5`, `poll: 0`) with a later `async_status` check
  - Has a second play that runs ONLY against `production` group and prints a message
- `ansible.cfg` with `forks = 4`, pipelining enabled, inventory pointing to `./inventory/combined/`

**Stretch goals:**

- Add `compose` to set `ansible_user` differently per `env` value
- Run `ansible-inventory --graph` and capture the group tree — verify every host is in the right groups before running the playbook

---

## Vocabulary to know

| Term                   | Definition                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------- |
| dynamic inventory      | host list built by querying a live system at runtime, not from a static file          |
| inventory plugin       | a YAML config file that tells Ansible's built-in code how to query a source           |
| inventory script       | old Python executable approach — outputs JSON, not recommended                       |
| `constructed` plugin | built-in plugin that layers groups and variables on top of any other inventory source |
| `groups:`            | key in constructed plugin — create a named group based on a Jinja2 condition         |
| `keyed_groups:`      | auto-create groups from all unique values of a variable or tag                        |
| `compose:`           | add computed variables to hosts using Jinja2 expressions                              |
| `forks`              | number of hosts Ansible works on in parallel                                          |
| `pipelining`         | SSH optimization — batches module operations into fewer connections                  |
| `gather_subset`      | collect only specific categories of facts instead of everything                       |
| `async`              | run a task in the background, do not block the play                                   |
| `poll`               | how often in seconds to check async task status;`0` = fire and forget               |
| `async_status`       | module to check the result of a`poll: 0` task                                       |

---

## Resources

- [Ansible Inventory Plugins](https://docs.ansible.com/ansible/latest/plugins/inventory.html)
- [constructed plugin docs](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/constructed_inventory.html)
- [Working with Dynamic Inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_dynamic_inventory.html)
- [AWS EC2 Inventory Plugin](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Async Actions and Polling](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_async.html)
- [Performance Tips](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
