# Phase 01 — Variables, Facts & Jinja2 Templating

## Before you start — be comfortable with:

- What a playbook is and how plays and tasks relate to each other
- What an inventory file contains and how hosts and groups work
- What YAML syntax looks like — indentation, lists, dicts, strings
- What `{{ }}` means at a high level — it is Jinja2 template syntax, not Ansible-specific

If any of the above feel unclear, review your basic playbook notes first.
Variables and facts are the foundation of everything in this path.
If variable precedence is not clear, roles and dynamic inventory will not make sense.

---

## What this phase covers

How Ansible resolves values at runtime — where variables come from, which one wins when the same variable is defined in multiple places, how facts differ from variables, and how Jinja2 lets you use logic inside playbooks and template files.
This is the language Ansible speaks internally. Everything else depends on it.

---

## Folder structure to build as you go

```
01_Variables_Facts_Jinja2/
  inventory/
    inventory.yml
    group_vars/
      all.yml
      databases.yml
    host_vars/
      web01.yml
  vars/
    app_vars.yml
  templates/
    app_config.j2
  01_variable_sources.yml
  02_variable_precedence.yml
  03_magic_variables.yml
  04_facts.yml
  05_jinja2_filters.yml
  06_templates.yml
```

Create files as you reach each concept. Do not create everything upfront — build it as you learn each section.

---

## Concepts to Master

Work through these in order. Read the concept, then do the exercise. Do not move on until you have run it and understand the output.

---

### 1. Variable sources — where can variables be defined?

- Inventory variables — inline next to a host or group in the inventory file
- `group_vars/` directory — one file per group name, applies to every host in that group
- `host_vars/` directory — one file per hostname, applies only to that specific host
- `vars:` section in the playbook — defined at the top of a play
- `vars_files:` — a list of external YAML files to load into a play
- `set_fact` module — create or update a variable at runtime, mid-play
- `register` — capture the output of a module into a variable for later use
- Extra vars (`-e` flag on command line) — highest precedence of all sources
- `vars_prompt` — prompt the operator for a value at runtime before the play starts

**Exercise — 01_variable_sources.yml:**

- Create an inventory with two hosts: `web01` and `db01`, in groups `webservers` and `databases`
- Define `app_name` in `group_vars/all.yml`
- Define `db_port` in `group_vars/databases.yml`
- Define `web_port` in `host_vars/web01.yml`
- Write a playbook that uses `debug: msg` to print all three variables on each host
- Run it. Observe which host sees which variable
- Add a `vars:` section in the play with `app_name` set to something different. Run again. Which value won?

---

### 2. Variable precedence — the 22-level order

This is a critical interview topic. Know these three levels cold:

- **TOP** — extra vars (`-e`) beats everything, always
- **BOTTOM** — role `defaults/main.yml` — lowest of all, always overridable
- **MIDDLE pattern** — task vars > block vars > play vars > host_vars > group_vars

Key rules:
- `host_vars` always overrides `group_vars` for the same variable name
- `group_vars/all` is the lowest group level — all other groups override it
- Child groups override parent groups in the group hierarchy

**Exercise — 02_variable_precedence.yml:**

- Define the SAME variable `app_env` in three places simultaneously:
  - `group_vars/all.yml` → set to `"global"`
  - `group_vars/webservers.yml` → set to `"web-group"`
  - `host_vars/web01.yml` → set to `"web01-host"`
- Write a playbook that prints `app_env` for `web01`
- **Predict the output BEFORE running.** Then run it. Were you right?
- Now run with `-e app_env=commandline`. What happens?
- Remove the `host_vars/web01.yml` entry. What does `web01` get now?

---

### 3. Magic variables — built-in variables Ansible always provides

These are never defined by you — Ansible injects them automatically:

- `hostvars` — a dict of ALL hosts and their variables; lets you access another host's vars
  - hostvars stores the variables of every host in the inventory.
  - Normally, a host can access only its own variables using {{ variable_name }}.
  - To access a variable from another host, use `{{ hostvars['inventory_hostname']['variable_name'] }}`
  - You can also use groups instead hardcode the hostname, use `{{ hostvars[groups['db'][0]]['db_port'] }}`
- `groups` — a dict of all groups mapped to their list of member hosts
- `group_names` — a list of groups the current host belongs to
- `inventory_hostname` — the name of the current host exactly as written in inventory
- `ansible_facts` — a dict of all facts gathered about the current host
- `ansible_host` — the actual IP or hostname used to connect to the host
- `ansible_play_hosts` — list of hosts still active in the current play

**Exercise — 03_magic_variables.yml:**

- Write a playbook targeting all hosts
- Print `inventory_hostname` and `group_names` for every host
- Print the `groups` variable to see all groups and their members
- Print `hostvars` to see every host's variables in one dump
- Notice how `hostvars` gives you access to `db01`'s variables while running on `web01`
- Access one specific variable from `db01` while running on `web01`: `"{{ hostvars['db01']['db_port'] }}"`
- Run it. Understand the output.

---

### 4. Facts — what they are and how they work

- Facts are auto-discovered information about the target host
- Gathered by the `setup` module, which runs automatically at the start of every play
- `gather_facts: true` (default) vs `gather_facts: false` (skip gathering, speeds up plays)
- Key facts to know: `ansible_facts['os_family']`, `ansible_facts['distribution']`, `ansible_facts['default_ipv4']['address']`, `ansible_facts['memtotal_mb']`
- Custom facts — place a `.fact` file (INI or JSON) in `/etc/ansible/facts.d/` on the target; Ansible reads these under `ansible_local`
- Fact caching — store gathered facts to disk or Redis between runs to skip re-gathering

**Exercise — 04_facts.yml:**

- Write a playbook that prints: OS family and distribution, default IPv4 address, total memory in MB
- Run it. Then add `gather_facts: false` to the play. Run again — what error do you get? Why?
- Re-enable `gather_facts` and add a task using the `setup` module with `filter: ansible_memory_mb` to gather only memory facts
- Finally, run `ansible localhost -m setup` in the terminal. Spend time reading all the facts — this is everything Ansible knows about the host

---

### 5. Jinja2 templating — filters and dynamic values

- `{{ variable }}` — substitute a variable's value
- `{{ variable | default('x') }}` — use `x` if variable is undefined
- `{% if condition %}...{% endif %}` — conditional block inside a `.j2` template file
- `{% for item in list %}...{% endfor %}` — loop inside a `.j2` template file

**Key filters** (the `|` operator transforms a value):

| Filter | What it does |
|--------|-------------|
| `default('fallback')` | use fallback if undefined |
| `upper` / `lower` | change case |
| `to_json` / `to_yaml` | serialize |
| `selectattr('key','equalto','v')` | filter a list of dicts by a field value |
| `map(attribute='name')` | extract one field from each dict in a list |
| `combine(other_dict)` | merge two dicts together |
| `join(', ')` | join a list into a single string |
| `int` / `float` / `string` | type conversion |

**Exercise — 05_jinja2_filters.yml:**

- Define `servers` as a list of dicts, each with `name` and `role` fields. Example: `[{name: web01, role: web}, {name: db01, role: db}, {name: web02, role: web}]`
- Write a playbook that:
  - Prints all server names joined as a comma-separated string (use `join`)
  - Prints only the servers where `role == "web"` (use `selectattr`)
  - Prints just the `name` field from each server (use `map` with `attribute`)
  - Prints a variable that may be undefined, using `default('not set')` as fallback
- Run it. Modify the filters and observe how output changes.

---

### 6. Jinja2 templates — `.j2` files rendered onto the target

- `template` module — renders a `.j2` file and copies the result to the target
- The `.j2` file can use `{{ }}`, `{% if %}`, `{% for %}` freely
- Variables from your playbook are available inside the template
- The rendered file is only updated on the target if the content actually changed

**Exercise — 06_templates.yml + templates/app_config.j2:**

- Create `templates/app_config.j2` that produces a config file with:
  - App name from a variable
  - Port from a variable
  - A `{% if %}` block that adds a debug section only when `debug_mode` is `true`
  - A `{% for %}` loop that lists allowed IPs from a list variable
- Write a playbook that renders this template to `/tmp/app_config.conf` on localhost
- Run it. Check the output file with `cat`
- Change `debug_mode` from `true` to `false`. Run again. Verify the debug section disappeared.

---

### 7. Defined vs undefined — a common source of bugs

- `variable is defined` — test in a `when:` condition before using
- `variable is undefined` — opposite check
- Know the difference: a variable set to `""`, `false`, `null`, and not defined at all all behave differently
- `omit` — a special value you pass as a module parameter to skip that parameter entirely when the variable is not defined

**Exercise (add to 05_jinja2_filters.yml or a new file):**

- Write a task that prints a variable you have NOT defined anywhere. Run it. Observe the error.
- Add `| default('fallback value')` to the expression. Run again.
- Add a `when: my_var is defined` condition on the task
- Run without defining `my_var` — task should be skipped
- Define `my_var` in `vars:` — task should now run

---

## Break stuff on purpose

- In `02_variable_precedence.yml` — define the same variable in 4 places at once. Run with `-vvv` verbose flag. Trace exactly which value Ansible is picking.
- In `04_facts.yml` — try to use `ansible_facts['made_up_key']` that does not exist. What happens? Add `| default('unknown')` to handle it safely.
- In `06_templates.yml` — break the Jinja2 syntax in the `.j2` file intentionally (leave a tag unclosed). What error does Ansible give?
  > **Answer:** Ansible throws a `TemplateSyntaxError` before any task runs. The error message names the unclosed tag — e.g., `Unexpected end of template. Jinja2 was looking for the following tags: 'endif' or 'else'`. The playbook fails at the template rendering step, nothing is written to the destination file.
- Run any playbook with `--check` flag. Understand what check mode does and when tasks report `changed` vs `ok` without actually making changes.
  > **Answer:** `--check` is a dry-run mode — Ansible simulates what would happen without making any real changes on the target. Tasks that would modify something (create a file, install a package) show as `changed` (yellow). Tasks where the system is already in the desired state show as `ok` (green). No files are written, no packages installed. Use it to safely preview a playbook before applying it to production.

---

## Mini Project — Dynamic System Report

Build a playbook that generates a system report file for each host.

**Requirements:**

- Target: localhost (or any host you have access to)
- Create `templates/system_report.j2`
- The rendered report must include:
  - Hostname from `inventory_hostname`
  - OS family and distribution version from facts
  - Total RAM and free RAM in MB from facts
  - All IP addresses on the host (loop through facts in the template)
  - A list of environment tags — define these in `group_vars` as a list of strings
  - A footer showing the current Ansible version from `ansible_version` magic variable
- Render the report to `/tmp/system_report_{{ inventory_hostname }}.txt`
- After rendering, use `debug:` to print a one-line summary
- Use at least 3 different Jinja2 filters in the template or playbook

**Stretch goals:**

- Add `vars_prompt` to ask for an operator name — include it in the report footer
- Add a `when:` condition so the report only generates if total RAM > 500 MB
- Register the template task result and print whether the file was changed or already up to date

**Files to create:**

- `01_Variables_Facts_Jinja2/project_system_report.yml`
- `01_Variables_Facts_Jinja2/templates/system_report.j2`

---

## Vocabulary to know cold

| Term | Definition |
|------|-----------|
| `vars` | explicitly defined key-value pairs you provide |
| `facts` | auto-discovered information about a host (OS, IPs, memory, etc.) |
| magic vars | special variables Ansible always injects (hostvars, groups, etc.) |
| filter | a Jinja2 function applied with `\|` to transform a value |
| precedence | the ordered rules that determine which variable definition wins |
| `register` | capture a module's return value into a named variable |
| `set_fact` | create or update a variable at runtime during a play |
| `gather_facts` | the automatic step that runs `setup` module at play start |
| custom facts | `.fact` files placed on target hosts that Ansible reads |

---

## Resources

- [Using Variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html)
- [Variable Precedence — full 22-level table](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
- [Magic Variables](https://docs.ansible.com/ansible/latest/reference_appendices/special_variables.html)
- [Discovering Variables / Facts](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_vars_facts.html)
- [Jinja2 Filters](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html)
- [Jinja2 Tests (is defined, in, etc.)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_tests.html)
- [Jeff Geerling — Ansible Variables Deep Dive](https://www.jeffgeerling.com/blog/2017/automate-your-variables-ansible-group-vars-and-host-vars)
