# Ansible Syntax Quick Reference

> Syntax-only cheat sheet for first-time learners.
> Theory, exercises, and projects live in each phase's `tasks.md`.
> Use this file when you know the concept but need to remember how to write it.

---

## Playbook skeleton

```yaml
---
- name: Short description of this play
  hosts: webservers          # target group or host from inventory
  become: true               # run tasks as root (sudo)
  gather_facts: true         # run setup module before tasks (default: true)

  vars:
    app_name: myapp
    app_port: 8080

  vars_files:
    - vars/app_vars.yml

  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted

  tasks:
    - name: Task description
      module_name:
        param1: value1
        param2: value2
      notify: restart nginx   # trigger handler if this task reports changed
      when: ansible_facts['os_family'] == "Debian"
      tags: [install]
```

---

## Inventory (YAML format)

```yaml
all:
  children:
    webservers:
      hosts:
        web01:
          ansible_host: 192.168.1.10
        web02:
          ansible_host: 192.168.1.11
    databases:
      hosts:
        db01:
          ansible_host: 192.168.1.20
```

---

## group_vars and host_vars — naming rule

```
inventory/
  inventory.yml
  group_vars/
    all.yml          ← applies to ALL hosts in the entire inventory
    webservers.yml   ← file name MUST exactly match the group name in inventory
    databases.yml    ← file name MUST exactly match the group name in inventory
  host_vars/
    web01.yml        ← file name MUST exactly match the host's inventory_hostname
    db01.yml         ← file name MUST exactly match the host's inventory_hostname
```

> **Rule:** `group_vars/<filename>.yml` — `<filename>` must equal the group name exactly (case-sensitive).
> `host_vars/<filename>.yml` — `<filename>` must equal the `inventory_hostname` exactly.
> A spelling or case mismatch means the variable is silently not loaded — no error, no warning.

---

## Variables

```yaml
# In a playbook play
vars:
  app_name: myapp           # string
  app_port: 8080            # integer
  debug_mode: false         # boolean
  allowed_ips:              # list
    - 10.0.0.1
    - 10.0.0.2
  db_config:                # dict / map
    host: localhost
    port: 5432

vars_files:
  - vars/app_vars.yml       # load an external YAML file into the play

vars_prompt:                # ask for input before play starts
  - name: operator_name
    prompt: "Enter your name"
    private: false          # false = visible input, true = hidden (like a password)
```

### set_fact — create or update a variable at runtime

```yaml
- name: Build URL from parts
  set_fact:
    derived_url: "http://{{ app_host }}:{{ app_port }}/api"
```

### register — capture a task's return value into a variable

```yaml
- name: Check if file exists
  stat:
    path: /tmp/myfile.txt
  register: file_check                        # result stored in file_check

- name: Print result
  debug:
    msg: "File exists: {{ file_check.stat.exists }}"
```

### Extra vars — command line (highest precedence, overrides everything)

```bash
ansible-playbook site.yml -e "app_env=production app_port=9090"
ansible-playbook site.yml -e "@vars/overrides.yml"   # load overrides from a file
```

---

## Handlers

```yaml
# Define at play level, under handlers:
handlers:
  - name: restart nginx          # this name must match notify: exactly
    service:
      name: nginx
      state: restarted

  - name: reload app config
    service:
      name: myapp
      state: reloaded

  # listen: lets multiple notify names trigger one handler
  - name: any config change handler
    service:
      name: myapp
      state: restarted
    listen: "config changed"     # notify: "config changed" from any task hits this

# In tasks — trigger a handler
tasks:
  - name: Update nginx config
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: restart nginx        # only fires if this task reports changed

  - name: Force handlers to run now (not at end of play)
    meta: flush_handlers
```

> **Rules to remember:**
>
> - A handler runs **once per play, at the end** — even if notified by 10 tasks
> - It only fires when the notifying task reports `changed` — not on `ok`
> - `meta: flush_handlers` — forces pending handlers to run immediately at that point
> - `force_handlers: true` at play level — run handlers even when the play fails

---

## Tags

```yaml
tasks:
  - name: Install nginx
    apt:
      name: nginx
    tags: [install, packages]     # list of tags on one task

  - name: Configure nginx
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    tags: configure               # single tag

  - name: Debug variable dump (skipped by default)
    debug:
      var: hostvars
    tags: never                   # built-in: skipped unless --tags never

  - name: Always print app version
    debug:
      msg: "Version {{ app_version }}"
    tags: always                  # built-in: runs regardless of which tags are specified
```

```bash
ansible-playbook site.yml --tags install              # only tasks tagged install (+ always)
ansible-playbook site.yml --skip-tags configure       # everything except configure tasks
ansible-playbook site.yml --tags install,configure    # multiple tags
ansible-playbook site.yml --tags never                # explicitly run never-tagged tasks
ansible-playbook site.yml --list-tasks                # preview task list without running
```

---

## Conditionals (`when:`)

```yaml
# Single condition
- name: Only on RedHat
  debug:
    msg: "RedHat system"
  when: ansible_facts['os_family'] == "RedHat"

# AND — using 'and' keyword
- name: AND inline
  debug:
    msg: "RedHat and port 80"
  when: ansible_facts['os_family'] == "RedHat" and app_port == 80

# AND — using list (every item in the list must be true)
- name: AND via list
  debug:
    msg: "Both conditions true"
  when:
    - ansible_facts['os_family'] == "RedHat"
    - app_port == 80

# OR
- name: OR condition
  debug:
    msg: "Debian or Ubuntu"
  when: ansible_facts['distribution'] == "Debian" or ansible_facts['distribution'] == "Ubuntu"

# Check if a variable is defined before using it
- name: Only when var is set
  debug:
    msg: "{{ my_var }}"
  when: my_var is defined

# Check group membership
- name: Only for web hosts
  debug:
    msg: "This is a web server"
  when: "'webservers' in group_names"
```

> **Do NOT wrap `when:` values in `{{ }}`** — the value is already a Jinja2 expression.
> Correct: `when: my_var == "hello"`
> Wrong: `when: "{{ my_var == 'hello' }}"` (deprecated and causes warnings)

---

## Loops

```yaml
# loop: over a simple list
- name: Create multiple files
  file:
    path: "/tmp/{{ item }}"
    state: touch
  loop:
    - file1.txt
    - file2.txt
    - file3.txt

# loop: over a list of dicts — access fields with item.key
- name: Create files with content
  copy:
    dest: "/tmp/{{ item.name }}"
    content: "{{ item.content }}"
  loop:
    - { name: "app.conf",  content: "port=8080" }
    - { name: "db.conf",   content: "host=localhost" }
    - { name: "log.conf",  content: "level=info" }

# loop_control — control output label, index, pause
- name: Loop with label and index
  debug:
    msg: "[{{ idx }}] Processing {{ item.name }}"
  loop:
    - { name: web01 }
    - { name: db01 }
  loop_control:
    label: "{{ item.name }}"   # shown in Ansible output instead of the full item dict
    index_var: idx             # 0-based loop counter available as idx inside the task
    pause: 1                   # seconds to wait between iterations

# until: — retry a task until a condition becomes true
- name: Wait for service to be ready
  stat:
    path: /tmp/ready.txt
  register: result
  until: result.stat.exists     # keep retrying until this is true
  retries: 5                    # try at most 5 times
  delay: 3                      # wait 3 seconds between each retry
```

---

## Blocks (block / rescue / always)

```yaml
tasks:
  - name: Deploy with error handling
    block:
      - name: Step 1 — create workdir
        file:
          path: /tmp/deploy
          state: directory

      - name: Step 2 — run deploy (might fail)
        command: /opt/scripts/deploy.sh

      - name: Step 3 — verify deploy
        command: curl -sf http://localhost/health

    rescue:
      - name: Runs only when something in block fails
        debug:
          msg: "Failed at: {{ ansible_failed_task.name }}"
          # ansible_failed_task   — the task object that failed
          # ansible_failed_result — the full result dict from the failed task

    always:
      - name: Cleanup — runs regardless of success or failure
        file:
          path: /tmp/deploy
          state: absent

  # block shares when: / tags / become: across all tasks inside it
  - name: Conditional block
    block:
      - name: Task A
        debug:
          msg: "Task A"
      - name: Task B
        debug:
          msg: "Task B"
    when: ansible_facts['os_family'] == "Debian"
    tags: configure
    become: true
```

---

## import_tasks vs include_tasks

```yaml
tasks:
  # import_tasks — static: resolved at PARSE time
  - import_tasks: tasks/install.yml
    tags: install              # tags pass through to every task inside the file

  # include_tasks — dynamic: resolved at RUNTIME
  - include_tasks: tasks/configure.yml
    # tags do NOT pass through to tasks inside the file

  # include_tasks with a variable filename (only possible with include, not import)
  - include_tasks: "tasks/{{ task_file }}"
    vars:
      task_file: deploy.yml
```

**Task file format** — `tasks/install.yml` must be a flat list of tasks, nothing else:

```yaml
---
- name: Install nginx
  apt:
    name: nginx
    state: present

- name: Install curl
  apt:
    name: curl
    state: present
```

> No `hosts:`, `tasks:`, `become:`, or `gather_facts:` keys in a task file — those belong in a playbook, not a task file.

|                                  | `import_tasks`     | `include_tasks`  |
| -------------------------------- | -------------------- | ------------------ |
| Resolved                         | parse time           | runtime            |
| Tags pass through to inner tasks | yes                  | no                 |
| Loop over the include            | no                   | yes                |
| Variable as filename             | only play-level vars | yes (any variable) |

---

## Jinja2 quick reference

```yaml
# In playbook tasks (inside double curly braces)
{{ variable }}                                              # substitute value
{{ variable | default('fallback') }}                        # fallback if undefined
{{ variable | upper }}                                      # UPPERCASE
{{ variable | lower }}                                      # lowercase
{{ list | join(', ') }}                                     # join list → "a, b, c"
{{ list | length }}                                         # count of items
{{ value | int }}                                           # convert to integer
{{ value | string }}                                        # convert to string
{{ dict | to_json }}                                        # serialize dict to JSON string
{{ dict | to_yaml }}                                        # serialize dict to YAML string
{{ list | selectattr('role', 'equalto', 'web') | list }}    # filter list of dicts by field
{{ list | map(attribute='name') | list }}                   # extract one field from each dict
{{ dict1 | combine(dict2) }}                                # merge two dicts (dict2 wins on conflict)
```

**In `.j2` template files:**

```jinja2
# Conditional block
{% if debug_mode %}
debug = true
log_level = verbose
{% else %}
debug = false
{% endif %}

# Loop
{% for ip in allowed_ips %}
allow {{ ip }};
{% endfor %}

# Access a variable
server_name = {{ inventory_hostname }};
```

---

## Common run flags

```bash
# Run a playbook
ansible-playbook site.yml -i inventory/inventory.yml     # specify inventory file
ansible-playbook site.yml --tags install                 # only run tagged tasks
ansible-playbook site.yml --skip-tags debug              # skip tagged tasks
ansible-playbook site.yml --check                        # dry run — no real changes
ansible-playbook site.yml -e "var=value"                 # extra vars (highest precedence)
ansible-playbook site.yml -v                             # verbose output (one level)
ansible-playbook site.yml -vvv                           # very verbose (use for debugging)
ansible-playbook site.yml --list-tasks                   # list tasks without running
ansible-playbook site.yml --limit web01                  # run only on a specific host

# Ad-hoc commands
ansible all -m ping -i inventory.yml                     # ping all hosts
ansible all -m setup -i inventory.yml                    # gather facts for all hosts
ansible web01 -m shell -a "uptime" -i inventory.yml      # run a shell command on one host
```

---

## Roles

### Role directory structure

```
roles/
  webserver/
    tasks/
      main.yml        ← entry point — Ansible runs this automatically
      install.yml     ← convention: split by concern, import_tasks from main.yml
      configure.yml
    handlers/
      main.yml        ← handlers scoped to this role only
    templates/
      nginx.conf.j2
    files/
      index.html      ← static files copied as-is (no templating)
    defaults/
      main.yml        ← LOWEST precedence — overridable public interface
    vars/
      main.yml        ← HIGH precedence — internal constants, NOT meant to be overridden
    meta/
      main.yml        ← role metadata: author, Galaxy info, dependency list
```

> Only `tasks/` is required. All other directories are optional.
> Ansible automatically reads `main.yml` from each directory — no manual import needed.

### defaults vs vars — the critical distinction

| Directory          | Precedence | Purpose                                               | Overridable from outside? |
| ------------------ | ---------- | ----------------------------------------------------- | ------------------------- |
| `defaults/main.yml` | lowest     | Public API — sane defaults the caller can override  | Yes — by anything         |
| `vars/main.yml`     | very high  | Private constants the role needs to function          | Only by `-e` (extra vars) |

```
defaults/ ← group_vars beats this → host_vars beats this → play vars beats this
vars/     ← beats group_vars, host_vars, play vars — only -e beats it
```

### Calling roles — three ways

```yaml
# 1. roles: list — static, runs before any tasks: in the same play
- name: Play using roles list
  hosts: webservers
  roles:
    - common
    - webserver               # shorthand
    - role: app_deploy        # explicit form — allows passing vars
      vars:
        app_version: "2.0.0"

# 2. import_role — static inline in tasks:, full tag support, no loops
- name: Play using import_role
  hosts: webservers
  tasks:
    - name: Deploy webserver role
      import_role:
        name: webserver
      vars:
        http_port: 9090       # overrides defaults/main.yml
      tags: [deploy]
      # Tags pass through to ALL inner tasks because import_role is resolved at parse time

# 3. include_role — dynamic inline in tasks:, supports loops and runtime decisions
- name: Play using include_role
  hosts: webservers
  tasks:
    - name: Deploy app for each version
      include_role:
        name: app_deploy
      vars:
        app_version: "{{ item }}"
      loop: ["1.0", "2.0", "3.0"]
      # Tags do NOT pass through to inner tasks (dynamic — resolved at runtime)
      # To filter inner tasks: put tags: directly on tasks inside the role files
```

|                              | `roles:` list | `import_role`   | `include_role`        |
| ---------------------------- | ------------- | --------------- | --------------------- |
| Tags pass to inner tasks     | yes           | yes             | no                    |
| Supports `loop:`             | no            | no              | yes                   |
| Runs before `tasks:`         | always        | no, in order    | no, in order          |
| Variable role name           | no            | no              | yes                   |
| Use when                     | simple call   | inline + tags   | loop or dynamic vars  |

### Role dependencies — meta/main.yml

```yaml
# roles/webserver/meta/main.yml
dependencies:
  - role: common              # common runs BEFORE webserver automatically
  - role: security_baseline
    vars:
      firewall_enabled: true

allow_duplicates: false       # default — a dependency runs only once per play
# allow_duplicates: true      # set this to allow the same role to run multiple times
```

### ansible.cfg — roles_path

```ini
[defaults]
roles_path = ./roles           # single path
# roles_path = ./roles:~/.ansible/roles   # colon-separated list (Linux/macOS)
```

### requirements.yml — Galaxy role install

```yaml
# requirements.yml
- src: geerlingguy.nginx
  version: "3.1.4"

- src: geerlingguy.git
  version: "3.0.0"
```

```bash
ansible-galaxy install -r requirements.yml                  # install to default roles path
ansible-galaxy install -r requirements.yml --roles-path ./roles   # install to local roles/
ansible-galaxy install geerlingguy.nginx                    # install single role
```

---

## Ansible Vault

```bash
# Encrypt / decrypt files
ansible-vault encrypt  group_vars/all/vault.yml        # encrypt entire file (AES-256)
ansible-vault decrypt  group_vars/all/vault.yml        # decrypt to disk (careful with Git)
ansible-vault view     group_vars/all/vault.yml        # view without decrypting to disk
ansible-vault edit     group_vars/all/vault.yml        # open in $EDITOR
ansible-vault rekey    group_vars/all/vault.yml        # re-encrypt with a new password

# Encrypt a single string — paste the !vault | block directly into a vars file
ansible-vault encrypt_string 'mysecretvalue' --name 'api_key'

# Run a playbook with an encrypted file
ansible-playbook site.yml --ask-vault-pass             # prompt for password
ansible-playbook site.yml --vault-password-file ~/.vault_pass   # read from file (CI/CD)
```

### Best-practice pattern — vars.yml + vault.yml

```
group_vars/all/
  vars.yml    ← non-sensitive: db_password: "{{ vault_db_password }}"
  vault.yml   ← encrypted:    vault_db_password: "supersecret123"
```

> Keep `vars.yml` in plain text so you can `grep` variable names.
> Keep `vault.yml` encrypted so values are never in Git in plain text.
> NEVER `git add` a plain-text vault file.

### Vault IDs — multiple passwords per environment

```bash
# Encrypt each environment's secrets with a different vault ID
ansible-vault encrypt --vault-id dev@prompt  vars/secrets_dev.yml
ansible-vault encrypt --vault-id prod@prompt vars/secrets_prod.yml

# Run with one environment's password only
ansible-playbook site.yml --vault-id dev@prompt
ansible-playbook site.yml --vault-id dev@~/.vault_dev   # file-based (no prompt)

# Run with multiple vault IDs at once
ansible-playbook site.yml --vault-id dev@~/.vault_dev --vault-id prod@~/.vault_prod
```

```ini
# ansible.cfg — set default vault identity list
[defaults]
vault_identity_list = dev@~/.vault_dev, prod@~/.vault_prod
```

---

## Error Handling

```yaml
tasks:
  # ignore_errors — continue even if this task fails
  - name: Task that may fail
    command: /bin/false
    ignore_errors: true        # play continues; use sparingly — masks real problems

  # changed_when — override Ansible's built-in change detection
  - name: Read-only check — never report changed
    command: cat /etc/hostname
    changed_when: false        # always reports ok, never changed

  - name: Custom change detection — changed only when output contains "updated"
    command: /opt/scripts/deploy.sh
    register: result
    changed_when: "'updated' in result.stdout"

  # failed_when — override what counts as failure
  - name: Accept exit code 2 as success
    command: bash -c "exit 2"
    register: result
    failed_when: result.rc not in [0, 2]   # exit 2 is OK; exit 1 or 3+ is a failure

# Play-level error settings
- name: Play with error controls
  hosts: all
  any_errors_fatal: true      # if any host fails, abort play for ALL hosts immediately
  max_fail_percentage: 20     # allow up to 20% of hosts to fail before aborting
  tasks: []
```

---

## Strategies — serial, linear, free

```yaml
# serial — batch hosts for rolling deploys
- name: Rolling deploy — one at a time
  hosts: all
  serial: 1               # one host per batch (safest)
  tasks: []

- name: Rolling deploy — 25% at a time
  hosts: all
  serial: "25%"           # percentage of total host count
  tasks: []

- name: Ramp-up deploy — canary first, then rest
  hosts: all
  serial: [1, "50%"]      # batch 1: 1 host; batch 2: 50% of remainder; etc.
  tasks: []

# strategy: free — each host runs as fast as it can, independently
- name: Parallel play
  hosts: all
  strategy: free
  tasks: []

# strategy: linear (default) — all hosts execute each task in lockstep
- name: Lockstep play (default)
  hosts: all
  strategy: linear
  tasks: []
```

```bash
# Strategies do not change run commands — they change execution ORDER
ansible-playbook site.yml -i inventory/inventory.yml
ansible-playbook site.yml -i inventory/inventory.yml --limit web01   # only one host
```
