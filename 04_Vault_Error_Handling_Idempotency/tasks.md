# Phase 04 — Vault, Error Handling & Idempotency

## Before you start — be comfortable with:

- Everything from Phases 01, 02, and 03
- What `register` and `set_fact` do (Phase 01)
- What `block/rescue/always` is at a basic level (Phase 02)
- Role `defaults` vs `vars` distinction (Phase 03)

This phase covers three topics that come up in every senior-level Ansible interview. They are also the three things that go wrong most often in real production environments.

---

## What this phase covers

Making Ansible secure, resilient, and safe to run repeatedly in production. Vault for secrets. Error handling so a failure does not leave things in a broken state. Idempotency so running a playbook 10 times is as safe as running it once.

---

## Folder structure to build as you go

```
04_Vault_Error_Handling_Idempotency/
  inventory/
    inventory.yml
    group_vars/
      all/
        vars.yml
        vault.yml     <- encrypted
  01_vault_basics.yml
  02_vault_ids.yml
  03_error_handling.yml
  04_idempotency.yml
  05_strategies.yml
  project_deployment.yml
```

---

## Concepts to Master

---

### 1. Ansible Vault basics

- Vault encrypts data at rest using AES-256
- `ansible-vault encrypt group_vars/all/vault.yml` — encrypt an entire file
- `ansible-vault view group_vars/all/vault.yml` — view without decrypting to disk
- `ansible-vault edit group_vars/all/vault.yml` — open encrypted file for editing
- `ansible-vault rekey group_vars/all/vault.yml` — re-encrypt with a new password
- `ansible-vault encrypt_string 'mysecretpassword' --name 'db_password'` — encrypt a single string; outputs a `!vault |` block you paste directly into any YAML vars file
- `--ask-vault-pass` — prompt for password interactively when running a playbook
- `--vault-password-file` — read password from a file (used in CI/CD)

**Company best-practice pattern:**

```
group_vars/all/vars.yml    <- non-sensitive variables, plain text
group_vars/all/vault.yml   <- sensitive variables, encrypted
```

In `vault.yml`: `vault_db_password: "supersecret"`
In `vars.yml`: `db_password: "{{ vault_db_password }}"`

This lets you see variable names in plain text without ever exposing values.

**NEVER commit plaintext secrets to Git.**

**Exercise — 01_vault_basics.yml:**

- Create `group_vars/all/vars.yml` with `app_name: "myapp"`
- Create `group_vars/all/vault.yml` with `vault_db_password: "supersecret123"`
- Run: `ansible-vault encrypt group_vars/all/vault.yml`
- Open the file — verify it is now encrypted gibberish
- In `vars.yml` add: `db_password: "{{ vault_db_password }}"`
- Write `01_vault_basics.yml` that prints both `app_name` and `db_password`
- Run with `--ask-vault-pass`. Enter your password. Verify the decrypted value prints.
- Run WITHOUT `--ask-vault-pass`. Read the error. Understand it.
- Run `ansible-vault encrypt_string 'anotherpassword' --name 'api_key'`
- Paste the output block into `vars.yml` directly. Print it in the playbook. Run it.

---

### 2. Vault IDs — multiple passwords per environment

- `ansible-vault encrypt --vault-id dev@prompt secrets_dev.yml`
- `ansible-vault encrypt --vault-id prod@prompt secrets_prod.yml`
- In `ansible.cfg`: `vault_identity_list = dev@~/.vault_dev, prod@~/.vault_prod`
- Run: `ansible-playbook site.yml --vault-id dev@~/.vault_dev`

This lets developers have the dev password but NOT the prod password.

**Exercise — 02_vault_ids.yml:**

- Create two separate vault-encrypted files:
  - `vars/dev_secrets.yml` — encrypted with vault ID `dev`, password `devpass`
  - `vars/prod_secrets.yml` — encrypted with vault ID `prod`, password `prodpass`
  - Each has `environment_db_url` set to a different value
- Write `02_vault_ids.yml` that loads both and prints both variables
- Run with `--vault-id dev@prompt` (enter `devpass`) — `dev_secrets.yml` decrypts, `prod_secrets.yml` fails
- Run with both: `--vault-id dev@prompt --vault-id prod@prompt` — both files decrypt
- Understand what this means for environment separation in a real team

---

### 3. Error handling

- Default: Ansible stops on the first failed task
- `ignore_errors: true` — continue even if this task fails (use sparingly — it masks real problems)
- `failed_when: condition` — override what counts as failure
- `changed_when: false` — always report `ok`, never `changed` (for read-only tasks)
- `changed_when: condition` — custom logic for when a task counts as making a change
- `any_errors_fatal: true` — if any host fails, abort the play for ALL hosts immediately
- `max_fail_percentage: 20` — allow up to 20% of hosts to fail before aborting

**Exercise — 03_error_handling.yml:**

- Write a task that runs `command: /bin/false`. Run it — it fails and stops.
- Add `ignore_errors: true`. Run again. Play continues.
- Write a command task that runs `command: echo "checking..."`. It always reports `changed` on re-run. Add `changed_when: false`. Run twice. Second run shows `ok`, not `changed`.
- Write a task using `bash -c "exit 2"`. Register the result. Add `failed_when: result.rc not in [0, 2]`. Run it — should succeed despite exit code 2.
- Add `any_errors_fatal: true` at play level. Run against two hosts where one fails. What happens to the other host?

---

### 4. Idempotency — the most important concept in Ansible

Idempotent = running the same playbook 10 times produces the exact same end state as running it once.

**Ansible modules are idempotent by default** — they check state before acting. `command` and `shell` are NOT — they run unconditionally every time.

**Signs a task is NOT idempotent:**

- It always reports `changed` on re-runs when nothing actually changed
- `shell: echo "line" >> /etc/file` — appends on every run
- `shell: mkdir /opt/app` — fails if directory already exists

**Idempotent alternatives:**

| Non-idempotent               | Idempotent replacement       |
| ---------------------------- | ---------------------------- |
| `shell: echo "x" >> file`  | `lineinfile`               |
| `shell: mkdir /opt/app`    | `file: state=directory`    |
| `shell: apt install nginx` | `package` / `apt` module |

**Exercise — 04_idempotency.yml:**

- Write a playbook with INTENTIONALLY non-idempotent tasks first:
  - `shell: echo "hello" >> /tmp/idempotency_test.txt`
  - `shell: mkdir /tmp/testdir`
- Run it TWICE. Check the file — it has two lines. The mkdir fails second run. These are broken.
- Fix BOTH to be idempotent: use `lineinfile` for the file, `file: state=directory` for the dir
- Run the fixed version TWICE. Second run: everything reports `ok`, not `changed`
- `cat /tmp/idempotency_test.txt` — still exactly one line
- This is the before/after you need to explain in interviews.

---

### 5. Running strategies — serial, linear, free

- `linear` (default) — all hosts execute task 1, then all run task 2, etc.
- `free` — each host runs as fast as it can, independently
- `serial` — batch hosts, critical for zero-downtime rolling deploys:

```yaml
serial: 1            # one host at a time
serial: "25%"        # 25% of total hosts at a time
serial: [1, 5, "20%"]  # ramp up: 1 first, then 5, then 20%
```

**Exercise — 05_strategies.yml:**

- Create an inventory with 4 localhost aliases (use `ansible_connection=local`)
- Write a playbook with `serial: 1` and a task that prints the hostname
- Run it. Watch the output — each host completes before the next starts
- Change to `serial: 2`. Run. Two hosts at a time.
- Change to `serial: [1, 3]`. Run. First 1 host, then remaining 3.
- Make a task fail on one host. With `serial: 1`, what happens to the others?
- Add `any_errors_fatal: true`. Run. What changes?

---

## Break stuff on purpose

- Write `vault.yml` in plain text. Run `git add` on it. See how easy it is to accidentally commit secrets. Encrypt it. Run `git diff`. This is why you always encrypt BEFORE `git add`.
- Run a playbook with a vault-encrypted file and the WRONG vault password. Read the error — this is what you see in production when passwords rotate.
- Write 5 tasks with `ignore_errors: true` where 3 of them fail silently. The play reports success. Add a task after them that depends on the output of a failed task. See what breaks.
- Write a `shell` task that appends to a file. Run it 5 times. Open the file. Rewrite with `lineinfile`. Run 5 times. Open the file. Compare.

---

## Mini Project — Secrets-Aware Deployment Playbook

Build a playbook that handles secrets properly, fails gracefully, and is fully idempotent.

**Requirements:**

- `group_vars/all/vault.yml` — store at least two secrets (`db_password`, `api_key`) — encrypted
- `group_vars/all/vars.yml` — reference both secrets using the `vault_` prefix convention
- Main playbook with:
  - A `block/rescue/always` around the deploy section:
    - `block:` — 3 tasks that simulate deployment using `file`, `copy`, and `template` modules
    - `rescue:` — print the failed task name + error + `"Triggering rollback"`
    - `always:` — print `"Deployment attempt logged"`
  - One task that would be non-idempotent with `shell` — rewrite it to be idempotent using a proper module
  - One task that uses `changed_when` — only reports `changed` when a specific string appears in command output (use `register` then `changed_when: "'updated' in result.stdout"`)
  - `serial: "50%"` so only half the hosts deploy at a time
- Run the playbook TWICE. Second run should show only `ok` statuses, no `changed`. This proves idempotency.

**Stretch goals:**

- Add a vault ID for a `"deploy token"` separate from the `db_password` vault
- Add a task tagged `rollback` using the `never` tag — only runs when explicitly called
- Add `max_fail_percentage: 25` so the play aborts if more than 25% of hosts fail

**Files to create:**

- `04_Vault_Error_Handling_Idempotency/project_deployment.yml`
- `04_Vault_Error_Handling_Idempotency/inventory/group_vars/all/vault.yml` (encrypted)
- `04_Vault_Error_Handling_Idempotency/inventory/group_vars/all/vars.yml`

---

## Vocabulary to know cold

| Term                 | Definition                                                                |
| -------------------- | ------------------------------------------------------------------------- |
| vault                | Ansible's built-in AES-256 encryption for secrets at rest                 |
| vault ID             | a named password identity; allows different passwords per environment     |
| idempotent           | produces the same end state on every run, no matter how many times        |
| `changed_when`     | overrides Ansible's built-in change detection with a custom condition     |
| `failed_when`      | overrides Ansible's built-in failure detection with a custom condition    |
| `ignore_errors`    | continue the play even if a task fails (use sparingly)                    |
| `serial`           | the number or percentage of hosts to process in a single batch            |
| `rescue`           | tasks that run when a block fails — Ansible's catch/except               |
| `always`           | tasks that always run after a block regardless of outcome — like finally |
| `any_errors_fatal` | abort the entire play if any host fails                                   |

---

## Resources

- [Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [Encrypting Content with Vault](https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html)
- [Error Handling in Playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_error_handling.html)
- [Controlling Playbook Execution (serial, strategy)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_strategies.html)
- [Red Hat Blog — Idempotency in Ansible](https://www.redhat.com/en/blog/ansible-idempotency)
- [Best Practices for Secrets](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html#keep-vaulted-variables-safely-visible)
