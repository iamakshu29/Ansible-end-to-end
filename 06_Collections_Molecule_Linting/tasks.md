# Phase 06 — Collections, Molecule & Linting

## Before you start — be comfortable with:

- Everything from Phases 01 through 05
- Role directory structure, especially `meta/` and `tasks/` (Phase 03)
- What `ansible-galaxy` does at a basic level (Phase 03)
- What idempotency means and why `changed_when` matters (Phase 04)

This phase is about the quality layer. Companies with mature Ansible practices use Collections for all content, Molecule for role testing, and `ansible-lint` in CI. These are signals in a resume and interview that you have worked on a team, not solo.

---

## What this phase covers

Collections: the modern packaging format that replaced standalone Galaxy roles. Molecule: the industry-standard framework for testing Ansible roles. `ansible-lint` and `yamllint`: the quality tools that run in every CI/CD pipeline.

---

## Folder structure to build as you go

```
06_Collections_Molecule_Linting/
  collections/                  <- local collection install path
  requirements.yml              <- pin collections with versions
  ansible.cfg
  roles/
    webserver/
      tasks/main.yml
      handlers/main.yml
      defaults/main.yml
      molecule/
        default/
          molecule.yml
          converge.yml
          verify.yml
  .ansible-lint
  .yamllint
  site.yml
```

---

## Concepts to Master

---

### 1. Collections — the modern packaging format

A collection bundles roles + modules + plugins + docs into one installable, versioned package. It replaced standalone Galaxy roles.

**Collection namespace format:** `vendor.collection_name`

| Collection | Contents |
|---|---|
| `community.general` | huge library of community modules |
| `ansible.builtin` | core modules built into Ansible itself |
| `ansible.posix` | POSIX-compliant system modules |
| `amazon.aws` | all AWS modules |
| `kubernetes.core` | Kubernetes management |

**Exercise — requirements.yml:**

- Create `requirements.yml`:

```yaml
collections:
  - name: community.general
    version: ">=9.0.0"
  - name: ansible.posix
    version: ">=1.5.0"
```

- Run: `ansible-galaxy collection install -r requirements.yml -p ./collections`
- Open the `collections/` directory. Browse the installed structure.
- Open one collection's `plugins/modules/` folder. Read what modules are available.
- Open one module's `DOCUMENTATION` section. Get comfortable reading it.
- In `ansible.cfg` add:

```ini
[defaults]
collections_path = ./collections
```

---

### 2. Fully Qualified Collection Names (FQCN) — the modern standard

| Old short name | New FQCN |
|---|---|
| `copy` | `ansible.builtin.copy` |
| `file` | `ansible.builtin.file` |
| `service` | `ansible.builtin.service` |
| `template` | `ansible.builtin.template` |
| `debug` | `ansible.builtin.debug` |

Why FQCN matters: with many collections installed, module names can collide. FQCN removes all ambiguity. `ansible-lint` will warn about short names in modern code.

**Exercise — rewrite with FQCN:**

- Take any playbook from a previous phase
- Rewrite every module call using its full FQCN
- For each `ansible.builtin.X` module: run `ansible-doc ansible.builtin.X` in the terminal
- Read the documentation output. Get comfortable reading `ansible-doc`.
- Run the rewritten playbook — it should work identically.

---

### 3. Molecule — role testing framework

**Installation:**

```bash
pip install molecule molecule-plugins[docker]
```

Requires Docker Desktop running on your machine.

**The full test lifecycle:**

| Step | What it does |
|---|---|
| `lint` | check syntax and style |
| `create` | spin up a Docker container as the test host |
| `prepare` | optional: run `prepare.yml` before the role |
| `converge` | run your role against the container |
| `idempotence` | run converge AGAIN and verify nothing changed second time |
| `verify` | run assertions to confirm correct results |
| `destroy` | tear down the container |

**Commands:**

- `molecule test` — full cycle end to end
- `molecule converge` — just run the role (skips create/destroy if instance exists)
- `molecule verify` — run only `verify.yml`
- `molecule login` — SSH into the test container to look around manually
- `molecule destroy` — tear down the container

**Exercise — Initialize Molecule in the webserver role:**

```bash
cd roles/webserver
molecule init scenario default
```

This creates `molecule/default/` with `molecule.yml`, `converge.yml`, `verify.yml`.

**Open `molecule/molecule.yml`:**
- Set driver to `docker`
- Set platform to `ubuntu:22.04`

**Open `molecule/converge.yml`:**
- It calls your role. Add required variables in `vars:` section.

**Open `molecule/verify.yml` — this is where you write ASSERTIONS:**
- Add tasks that check ACTUAL outcomes, not just "the play ran without errors":
  - The directory `/tmp/webserver_marker` exists (create it in your role's tasks first)
  - A specific file was created with the correct content
- Use `ansible.builtin.stat` and `ansible.builtin.assert` to check conditions.

**Run the cycle:**

```bash
molecule converge          # run the role
molecule login             # inspect the container manually, then exit
molecule verify            # run your assertions
molecule test              # full cycle — watch all steps
```

**Exercise — Test idempotency:**

- `molecule test` runs `converge` twice automatically (the idempotence step)
- If any task reports `changed` on the second run, Molecule fails the idempotence check
- Find which task is not idempotent. Fix it. Run `molecule test` again.

**Exercise — Test across multiple distros:**

- In `molecule.yml` add a second platform: `centos:stream9` (or `ubuntu:20.04`)
- Run `molecule test`. Your role runs against BOTH containers simultaneously.
- If something works on Ubuntu but fails on CentOS, you will find it here.

---

### 4. ansible-lint — enforcing code quality

**Installation:** `pip install ansible-lint`

**Exercise — Run ansible-lint and fix everything:**

- From the project root: `ansible-lint site.yml`
- Read every violation. Do not dismiss any.

**Key violations to understand and fix:**

| Rule | What it means |
|---|---|
| `fqcn` | you used a short module name — change to FQCN |
| `no-changed-when` | your `shell`/`command` task has no `changed_when` |
| `yaml[truthy]` | you used `yes`/`no` instead of `true`/`false` |
| `no-jinja-when` | you wrapped a `when:` value in `{{ }}` |
| `name[casing]` | your task name does not start with uppercase |

- Fix each violation one at a time. Re-run `ansible-lint` after each fix.
- Goal: `ansible-lint` returns zero violations.

**Exercise — .ansible-lint config:**

- Create `.ansible-lint` at project root:

```yaml
profile: moderate
exclude_paths:
  - collections/
```

- Re-run `ansible-lint`. The `moderate` profile enforces more rules. Fix new violations.

---

### 5. yamllint — YAML formatting enforcement

**Exercise — .yamllint config:**

- Create `.yamllint` at project root:

```yaml
extends: default
rules:
  line-length:
    max: 160
  truthy:
    allowed-values: ['true', 'false']
```

- Run: `yamllint .`
- Read violations. Fix them. Common issues: trailing spaces, `yes`/`no` instead of `true`/`false`, inconsistent indentation.

---

### 6. The full quality pipeline — simulate CI locally

Every PR to a company Ansible repo runs these checks in order. If any step fails, the PR cannot merge.

**Exercise — Run the full pipeline manually:**

```bash
yamllint .
ansible-lint site.yml
cd roles/webserver && molecule test
```

All three must pass with zero errors. Fix anything that fails. This is your quality bar.

---

## Break stuff on purpose

- Add `shell: echo "hello"` to a role without `changed_when: false`. Run `ansible-lint`. See the `no-changed-when` violation. Understand why it exists.
- In `molecule/verify.yml` write an assertion you know is FALSE (check for a file your role does NOT create). Run `molecule verify`. See how assertion failures look.
- Make a task non-idempotent intentionally (append to a file with `shell`). Run `molecule test`. Find exactly where the idempotence check fails in the output.
- Install two collections that have a module with the same short name. Try to call it without FQCN. See what Ansible does. Add FQCN. See it resolve correctly.

---

## Mini Project — Tested and Linted webserver Role

Bring the webserver role from Phase 03 up to production quality standards.

**Requirements:**

- All module calls use FQCN throughout the role
- `defaults/main.yml` has at least 4 configurable variables
- `tasks/main.yml` imports `install.yml` and `configure.yml`
- `templates/` has one `.j2` file rendered by `configure.yml`
- `handlers/main.yml` has one handler triggered by `configure.yml`
- `molecule/default/` is set up with Docker driver and Ubuntu 22.04
- `converge.yml` calls the role with at least one variable override
- `verify.yml` has at least 3 assertions checking ACTUAL outcomes:
  - The config file exists at the correct path
  - The config file contains the correct rendered value from a variable
  - A specific directory was created with the correct permissions
- `molecule test` runs clean — all phases pass, idempotence check passes
- `ansible-lint` runs with zero violations at `moderate` profile
- `yamllint .` runs with zero violations

**Stretch goals:**

- Add a second Molecule scenario for CentOS Stream 9
- Add a `prepare.yml` that installs Python on the test container before converge
- Create a `requirements.yml` that pins all collections used in the role

**Files to create/update:**

- `06_Collections_Molecule_Linting/roles/webserver/` (full role with all directories)
- `06_Collections_Molecule_Linting/roles/webserver/molecule/default/`
- `06_Collections_Molecule_Linting/.ansible-lint`
- `06_Collections_Molecule_Linting/.yamllint`
- `06_Collections_Molecule_Linting/requirements.yml`

---

## Vocabulary to know cold

| Term | Definition |
|------|-----------|
| collection | a versioned, installable package: roles + modules + plugins in one unit |
| namespace | the vendor prefix in a collection name (e.g., `amazon` in `amazon.aws`) |
| FQCN | fully qualified collection name (e.g., `ansible.builtin.copy`) |
| Molecule | testing framework for Ansible roles: create → converge → verify → destroy |
| scenario | a named Molecule test configuration inside a role (`molecule/default/`) |
| converge | the Molecule step that applies your role to the test container |
| idempotence | Molecule's built-in check: run the role twice, verify nothing changed second time |
| verify | the Molecule step that asserts your role produced the correct end state |
| driver | how Molecule creates test instances (Docker, Podman, Vagrant) |
| `ansible-lint` | static analysis tool that enforces Ansible best practices and style |
| `yamllint` | YAML syntax and formatting linter |
| profile | `ansible-lint` strictness level: min, basic, moderate, safety, production |

---

## Resources

- [Using Collections](https://docs.ansible.com/ansible/latest/collections_guide/index.html)
- [Molecule Docs](https://ansible.readthedocs.io/projects/molecule/)
- [Molecule Getting Started Guide](https://ansible.readthedocs.io/projects/molecule/getting-started/)
- [ansible-lint Docs](https://ansible.readthedocs.io/projects/lint/)
- [ansible-lint Rules Reference](https://ansible.readthedocs.io/projects/lint/rules/)
- [yamllint Docs](https://yamllint.readthedocs.io/en/stable/)
- [Jeff Geerling — Testing Roles with Molecule](https://www.jeffgeerling.com/blog/2018/testing-your-ansible-roles-molecule)
