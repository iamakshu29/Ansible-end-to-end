# Phase 03 — Roles & Reusability

## Before you start — be comfortable with:

- Everything from Phase 01 and Phase 02
- The static vs dynamic concept from Phase 02 (`import_tasks` vs `include_tasks`) — the same idea applies to `import_role` vs `include_role` which you'll use in this phase
- What `group_vars` and `host_vars` are and how they relate to variable precedence
- What a handler is (from Phase 02) — roles have their own handlers directory

Do not start this phase if Phase 02 concepts still feel unclear. Roles are where everything from the first two phases comes together.

---

## What this phase covers

How production Ansible projects are actually structured. Every company that uses Ansible beyond basic scripts uses roles. If you cannot describe role structure and the `defaults` vs `vars` distinction clearly, your resume claim will not hold up in an interview.

---

## Folder structure to build as you go

```
03_Roles_Reusability/
  inventory/
    inventory.yml
    group_vars/
      all.yml
  roles/
    common/
      tasks/main.yml
      defaults/main.yml
      meta/main.yml
    webserver/
      tasks/
        main.yml
        install.yml
        configure.yml
      handlers/main.yml
      templates/
        nginx.conf.j2
      files/
        index.html
      defaults/main.yml
      vars/main.yml
      meta/main.yml
    app_deploy/
      tasks/main.yml
      defaults/main.yml
  ansible.cfg
  site.yml
  webservers.yml
  requirements.yml
```

Build this by hand as you work through exercises. Do not create the whole structure upfront.

---

## Concepts to Master

---

### 1. Role directory structure — every directory has a purpose

| Directory             | Purpose                                                                |
| --------------------- | ---------------------------------------------------------------------- |
| `tasks/main.yml`    | entry point — Ansible runs this when the role is called               |
| `tasks/install.yml` | convention: split big task files by concern,`import_tasks` from main |
| `handlers/main.yml` | handlers scoped to this role only                                      |
| `templates/`        | Jinja2`.j2` template files                                           |
| `files/`            | static files copied as-is (no templating)                              |
| `defaults/main.yml` | lowest-precedence variables — overridable public interface            |
| `vars/main.yml`     | high-precedence internal constants — not meant to be overridden       |
| `meta/main.yml`     | role metadata: author, Galaxy info, dependency list                    |
| `library/`          | custom modules scoped to this role only                                |

Only `tasks/` is required. All other directories are optional. Ansible automatically reads `main.yml` from each directory — you do not import it manually.

**Exercise — Create the webserver role:**

> **Important — scope of role variables**: Variables defined in `defaults/main.yml` and `vars/main.yml` are only available **inside that role's own tasks**. They do not exist in playbook-level `tasks:` blocks unless the role has been called. `site.yml` should only call the role — the tasks that USE the variables live inside the role files.

- Create the full directory structure for the `webserver` role manually (no shortcuts)
- `tasks/main.yml`: use `import_tasks` to call `install.yml` and `configure.yml`
  - `tasks/install.yml`: a debug task that prints `"Installing nginx on port {{ http_port }}"`
  - `tasks/configure.yml`: a debug task that prints `"Configuring nginx — worker user: {{ nginx_user }}"`
- `handlers/main.yml`: a handler that prints `"Nginx restarted"`
- `defaults/main.yml`: set `http_port: 80` and `server_name: "localhost"`
- `vars/main.yml`: set `nginx_user: "www-data"`
- Write `site.yml` that calls the webserver roles using localhost
  - `site.yml`: a single play targeting `localhost` with only a `roles:` key calling `webserver` — no inline `tasks:` here
  - Run it. Verify both debug messages print with the correct values from `defaults/` and `vars/`

---

### 2. `defaults` vs `vars` — the most misunderstood concept in roles

This is a critical interview topic.

**`defaults/main.yml`:**

- Lowest variable precedence of everything in Ansible
- The role's overridable public interface
- Think of it as: *"I set a sane default, but you are expected to override this"*
- Any inventory variable, `group_var`, `host_var`, or playbook `vars:` overrides defaults

**`vars/main.yml`:**

- Very high variable precedence — higher than `group_vars` and `host_vars`
- Internal constants the role needs to function
- Think of it as: *"This is how this role works — do not change this from outside"*

**Interview answer: `defaults/` is the role's public API. `vars/` is its private internals.**

**Exercise — Prove the precedence difference:**

- In the webserver role: `defaults/main.yml` has `http_port: 80`, `vars/main.yml` has `nginx_user: "www-data"`
- In your playbook `vars:` section, try to override BOTH: `{http_port: 8080, nginx_user: "myuser"}`
- Add debug tasks to print both variables. Run it.
- Which one changed? Which stayed as defined in the role? # Both changes
- Now try overriding `nginx_user` via `group_vars/all.yml` instead. Which wins: group_vars or `vars/main.yml`?
- Write down what you observed. This IS the `defaults` vs `vars` distinction in action.

---

### 3. Role dependencies — `meta/main.yml`

- `dependencies:` — a list of other roles that must run before this role
- Ansible runs all dependencies automatically, in order, before the role itself
- `allow_duplicates: true` — by default a role dependency only runs once per play
- Use case: a `common` role (NTP, firewall, base config) that every app role needs

**Exercise — Create a `common` role and make `webserver` depend on it:**

- Create `roles/common/` with a single task that prints `"Running common setup"`
- In `roles/webserver/meta/main.yml` add `dependencies: [{role: common}]`
- Run `site.yml`. Verify `common` runs BEFORE `webserver`, automatically, without you calling it in the playbook.
- Now also add `common` explicitly in `site.yml` too. Run again.
- Does `common` run twice? (It should NOT — that is `allow_duplicates: false`)
- Add `allow_duplicates: true` to common's `meta/main.yml`. Run again. Does it run twice now?

---

### 4. Calling roles — three ways

- `roles:` list at the play level — static, runs before any `tasks:` in the play
- `import_role:` — static inline within `tasks:`, full tag support, no loops
- `include_role:` — dynamic inline, supports loops and runtime variable-based decisions
- Pass variables to a role using `vars:` when calling `import_role` or `include_role`

**Exercise — Call the same role three ways:**

- Write `webservers.yml` with three separate plays:
  - Play 1: call `webserver` role using `roles:` list syntax
  - Play 2: call `webserver` role using `import_role` with `vars: {http_port: 9090}`
  - Play 3: call `webserver` role using `include_role`
- Add tags to the `import_role` call. Run with `--tags` — verify tags work on inner tasks.
- Add tags to the `include_role` call. Run with `--tags` — verify tags do NOT reach inside the role. (This is the static vs dynamic difference from Phase 02.)
- Loop over `include_role` with a list of role names. Verify the loop works.
- Try the same loop with `import_role`. Run. Read the error. Understand it.

---

### 5. Role search path — where Ansible looks for roles

Ansible checks these paths in order (first match wins):

1. `./roles/` directory next to the playbook file (most common)
2. `~/.ansible/roles/` — user-level install location
3. `/etc/ansible/roles/` — system-wide location
4. `roles_path` in `ansible.cfg` — custom paths, can be a list

**Exercise — `ansible.cfg` roles_path:**

- Create `ansible.cfg` at the root of `03_Roles_Reusability/`:

```ini
[defaults]
roles_path = ./roles
```

- Move your `roles/` directory one level deeper (e.g., into `custom_roles/`)
- Update `ansible.cfg` to point to it. Run `site.yml`. Verify it still works.

---

### 6. Ansible Galaxy — requirements.yml

- `ansible-galaxy install geerlingguy.nginx` — install a role from Galaxy
- `requirements.yml` — pin exact versions so installs are reproducible across environments
- `ansible-galaxy install -r requirements.yml` — install everything at once

**Exercise — requirements.yml:**

- Create `requirements.yml` that installs `geerlingguy.git` from Galaxy
- Run `ansible-galaxy install -r requirements.yml`
- Open the installed role. Read its `defaults/main.yml`
- Count how many configurable variables it exposes — that IS the `defaults` pattern in action
- Read its `tasks/main.yml` — understand how it splits tasks across multiple files

---

## Break stuff on purpose

- Delete `tasks/main.yml` from your webserver role. Run the playbook. What error?
- Put a variable in `vars/main.yml` with the same name as one in `group_vars/all.yml`. Run. Observe which wins. Swap it to `defaults/main.yml`. Run again. Which wins now?
- Add a circular dependency: `webserver` depends on `common`, `common` depends on `webserver`. Run it. What does Ansible say?
- Call `include_role` with a variable role name and leave the variable undefined. Run. Read the error. Then define it. Run again.

---

## Mini Project — Multi-Role Web Application Setup

Build a project that simulates deploying a two-tier app using multiple roles.

**Requirements:**

- **Role 1: `common`** — runs on all hosts, sets up base configuration

  - `defaults`: `ntp_server: "pool.ntp.org"`, `timezone: "UTC"`
  - Tasks: print `"Setting timezone to {{ timezone }}"`, print `"Configuring NTP: {{ ntp_server }}"`
- **Role 2: `webserver`** — depends on `common`

  - `defaults`: `http_port: 80`, `document_root: "/var/www/html"`
  - `vars`: `nginx_worker_processes: "auto"` (this should NOT be overridable externally)
  - `tasks/install.yml`: print `"Installing nginx"`
  - `tasks/configure.yml`: print `"Configuring nginx on port {{ http_port }}"`, notify handler, render `nginx.conf.j2` to `/tmp/`
  - `handlers`: `"nginx config changed"` handler
  - `templates/nginx.conf.j2`: a minimal fake nginx.conf using `http_port` and `document_root`
- **Role 3: `app_deploy`** — depends on `common`

  - `defaults`: `app_version: "1.0.0"`, `deploy_path: "/opt/app"`
  - Tasks: print `"Deploying version {{ app_version }} to {{ deploy_path }}"`
- `site.yml` calls all three roles
- Override `http_port` to `8080` via `group_vars` for the webservers group
- Override `app_version` to `"2.1.0"` via a `vars:` block when calling `app_deploy`
- Verify through debug output that both overrides actually took effect

**Stretch goals:**

- Add `requirements.yml` that installs one real role from Galaxy alongside your custom roles
- Add a task in `webserver` that uses `files/` to copy `index.html` to `/tmp/`
- Call `app_deploy` in a loop for versions `["1.0.0", "2.0.0", "3.0.0"]`

**Files to create:**

- `03_Roles_Reusability/roles/common/`
- `03_Roles_Reusability/roles/webserver/`
- `03_Roles_Reusability/roles/app_deploy/`
- `03_Roles_Reusability/site.yml`
- `03_Roles_Reusability/requirements.yml`

---

## Vocabulary to know cold

| Term             | Definition                                                                     |
| ---------------- | ------------------------------------------------------------------------------ |
| role             | a self-contained unit of automation with a standard directory structure        |
| `defaults`     | lowest-precedence variables — the role's overridable public interface         |
| `vars`         | high-precedence variables — the role's internal constants                     |
| `meta`         | role metadata: author, Galaxy info, and dependency list                        |
| dependency       | a role that Ansible runs automatically before the current role                 |
| Galaxy           | Ansible's community hub for sharing and downloading roles and collections      |
| `requirements` | `requirements.yml` — a pinned list of external roles/collections to install |
| `roles_path`   | `ansible.cfg` setting that tells Ansible where to look for roles             |

---

## Resources

- [Roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [Role Directory Structure](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html#role-directory-structure)
- [Using Galaxy — requirements.yml](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html#installing-multiple-roles-from-a-file)
- [Ansible Galaxy](https://galaxy.ansible.com/)
- [geerlingguy roles on GitHub — study these](https://github.com/geerlingguy?tab=repositories&q=ansible-role)
- [Ansible for DevOps (book)](https://www.ansiblefordevops.com/)
- [Playbook Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
