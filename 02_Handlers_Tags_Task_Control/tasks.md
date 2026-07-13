# Phase 02 — Handlers, Tags & Task Control

## Before you start — be comfortable with:

- Everything from Phase 01 (variables, facts, Jinja2 filters)
- What a task is and how modules map to tasks
- What `changed` vs `ok` vs `failed` status means in Ansible output
- Basic `when:` usage — you have seen it, even if it is not fully clear yet

If variable precedence is still fuzzy, go back. The `when:` conditional depends on it.

---

## What this phase covers

Controlling what runs, when it runs, how failures are handled, and how to avoid running unnecessary work. These are the details that separate beginner playbooks from playbooks that can safely run in production without side effects.

---

## Folder structure to build as you go

```
02_Handlers_Tags_Task_Control/
  inventory/
    inventory.yml
  tasks/
    install.yml
    configure.yml
    deploy.yml
  01_handlers.yml
  02_tags.yml
  03_conditionals.yml
  04_loops.yml
  05_blocks.yml
  06_import_vs_include.yml
  project_app_setup.yml
```

---

## Concepts to Master

---

### 1. Handlers — the right way to trigger service restarts

- A handler is a task that only runs when notified — and only **once** per play, at the end
- `notify: handler_name` — triggers a handler if and only if the notifying task reports `changed`
- If the same handler is notified by 5 tasks, it still only runs once
- `listen: topic_name` — a handler can listen on a topic name; multiple tasks can notify the same topic
- `force_handlers: true` — run handlers even if the play fails partway through
- `flush_handlers` — a special task that forces pending handlers to run mid-play, before the play naturally ends

Why handlers exist: restarting nginx every time a config task runs is wrong. Handlers ensure a restart only happens when something actually changed.

**Exercise — 01_handlers.yml:**

- Write a playbook that creates `/tmp/app.conf` using the `copy` module with some content
- Add a handler that prints `"Config changed — service would restart"`
- The `copy` task should `notify:` this handler
- Run it the first time — handler should fire (file was created = changed)
- Run it a **second time** without changing anything — handler should **NOT** fire
- Change the file content in the playbook and run again — handler fires again. Understand why.
- Add a second task that also notifies the same handler. Run. Confirm it still only runs once.
- Add `flush_handlers` between the two tasks. Run again. What changes?

---

### 2. Tags — running only a slice of a playbook

- `--tags webserver` — only run tasks tagged `webserver`
- `--skip-tags debug` — run everything EXCEPT tasks tagged `debug`
- `--tags all` — run everything (the default)
- `always` — a built-in tag; tasks tagged `always` run even when other tags filter
- `never` — a built-in tag; tasks tagged `never` are skipped unless explicitly requested
- Tags are inherited by tasks inside a block or role that has a tag

**Exercise — 02_tags.yml:**

- Write a playbook with 6 tasks:
  - Two tagged `install`
  - Two tagged `configure`
  - One tagged `debug` and also tagged `never` (skipped by default)
  - One tagged `always` (runs no matter what)
- Run with `--tags install` → only install + always tasks should run
- Run with `--skip-tags configure` → everything except configure tasks
- Run with `--tags debug` → the debug task + always task should run
- Run with `--tags never` → what happens? Think before running.
- Run with `--list-tasks` to see all tasks and their tags without executing

---

### 3. Conditionals — `when:` and its rules

- `when: condition` — this task only runs if the condition is true
- Conditions are Jinja2 expressions — **do NOT wrap them in `{{ }}`**
  - Correct: `when: ansible_facts['os_family'] == "RedHat"`
  - Wrong: `when: "{{ ansible_facts['os_family'] == 'RedHat' }}"` (deprecated)
- AND: `when: condition1 and condition2`
- AND via list: `when: [condition1, condition2]` (list items = AND)
- OR: `when: condition1 or condition2`
- Is defined: `when: my_var is defined`
- In a list: `when: "'web' in group_names"`

**Exercise — 03_conditionals.yml:**

- Write a playbook targeting localhost with tasks that:
  - Print `"This is Linux"` only when `ansible_facts['system'] == "Linux"`
  - Print `"This is Windows"` only when `ansible_facts['system'] == "Win32NT"`
  - Print a variable only when it is defined — run once with it defined, once without. Verify the task is skipped in the second run.
  - Print something only when two conditions are BOTH true (AND)
  - Print something when EITHER of two conditions is true (OR)
- After each run check which tasks show `ok`, `skipped`, or `changed` in the output

---

### 4. Loops — repeating a task over a list

- `loop:` — current standard way to iterate
- `with_items:` — older syntax, still widely used, functionally the same as `loop:`
- `item` — the magic variable holding the current loop value inside the task
- Loop over a list of dicts: reference fields with `item.key`
- `loop_control`:
  - `label: "{{ item.name }}"` — what to print in output instead of the full item
  - `index_var: idx` — creates a variable with the current loop index
  - `pause: 2` — pause N seconds between iterations
- `until:` — retry a task until a condition is true
  - `retries: 5` — how many times to try
  - `delay: 10` — seconds to wait between retries

**Exercise — 04_loops.yml:**

- Use `loop:` to create 4 files in `/tmp/` — one per item in a list of filenames
- Use `loop:` over a list of dicts (each dict has `name` and `content` fields) and create each file with its corresponding content
- Add `loop_control` with `label:` so the output shows just the filename, not the full dict — run without label first, then add it and compare
- Write a task with `until:` that checks if `/tmp/ready.txt` exists, retries 5 times, waits 3 seconds between tries. While it retries, create `/tmp/ready.txt` manually in another terminal. Watch it succeed.

---

### 5. Blocks — grouping tasks and handling errors

- `block:` — group tasks so they share one `when:`, `tags`, `become:`, or error handler
- `rescue:` — runs if ANY task in the block fails
  - `ansible_failed_task` — the task object that failed, available in rescue
  - `ansible_failed_result` — the result dict from the failed task, available in rescue
- `always:` — runs regardless of whether block succeeded or failed (like `finally`)

**Exercise — 05_blocks.yml:**

- Write a playbook with a block that:
  - Task 1: creates `/tmp/block_test.txt`
  - Task 2: runs a command that intentionally fails (`command: /bin/false`)
  - Task 3: prints `"This should not run"` — verify it is SKIPPED
  - `rescue:` prints the failed task name using `ansible_failed_task.name`
  - `always:` deletes `/tmp/block_test.txt` (cleanup)
- Run it. Verify: task 3 was skipped, rescue ran, always ran, file was cleaned up.
- Now fix task 2 so it succeeds. Run again. Verify: task 3 now runs, rescue does NOT run, always still runs.

---

### 6. import vs include — static vs dynamic (critical interview topic)

| | `import_*` (static) | `include_*` (dynamic) |
|---|---|---|
| Processed | at parse time | at runtime |
| Tags work on inner tasks | ✅ yes | ❌ no |
| Can loop over it | ❌ no | ✅ yes |
| Variable as filename | ❌ no | ✅ yes |
| `when:` behaviour | applies to every task inside | decides whether to load the file |

> **Note:** A task file used with `import_tasks` or `include_tasks` must contain **only a flat list of tasks** — no `hosts:`, `become:`, `gather_facts:`, or `tasks:` key. Those keys belong to a playbook, not a task file. If you add them, Ansible will fail to parse the file correctly when importing it. A task file is not a playbook — it is just a list of task objects that gets pulled into a playbook that already has those top-level settings.

**Exercise — 06_import_vs_include.yml:**

- Create `tasks/install.yml`, `tasks/configure.yml`, `tasks/deploy.yml` — each with 1–2 debug tasks tagged with meaningful tag names
- In your main playbook:
  - Use `import_tasks` for `install.yml` with a tag `"install"` on the import
  - Use `include_tasks` for `configure.yml`
  - Use `include_tasks` with a VARIABLE as the filename: `include_tasks: "tasks/{{ task_file }}"` with `vars: {task_file: "deploy.yml"}`
- Run with `--tags install` — import lets tags through. Observe.
- Run with `--tags configure` — include does NOT let tags through to inside tasks. Observe.
- Try using `import_tasks` with the variable filename. Run. Read the error. Understand it.
- Switch back to `include_tasks`. Run. It works.

---

## Break stuff on purpose

- Remove `notify:` from a task. Run it. Handler does not fire. Now add `force_handlers: true` at play level. Does the handler fire now?
- Run `--tags nonexistent` on a playbook. What happens?
- Wrap a `when:` value in `{{ }}`. Run it. Read the deprecation warning.
- Put the failing task AFTER the `rescue:` block (not inside `block:`). Does rescue catch the error? Why not?

---

## Mini Project — Controlled App Setup Playbook

Build a playbook that simulates setting up an application with full flow control.

**Requirements:**

- At least 6 tasks divided into three groups: install, configure, deploy
- Each group tagged so you can run any group in isolation
- A handler called `"restart app service"` triggered by any configure task that changes
- A loop that creates multiple config files from a list of dicts (filename + content pairs)
- A `when:` condition that skips the deploy group entirely when `deploy_enabled` is `false`
- A `block/rescue/always` around the deploy section:
  - `block:` run deploy tasks
  - `rescue:` print the failed task name
  - `always:` print `"Deploy attempt finished"` regardless of outcome
- Use `include_tasks` to pull the configure tasks from a separate file

**Stretch goals:**

- Add a task tagged `never` that prints all variables — only runs with `--tags debug`
- Add `until:` on a deploy health-check task that retries 3 times with 5 second delay
- Use `flush_handlers` after the configure section so the service restarts before deploy begins

**Files to create:**

- `02_Handlers_Tags_Task_Control/project_app_setup.yml`
- `02_Handlers_Tags_Task_Control/tasks/configure_tasks.yml`

---

## Vocabulary to know cold

| Term | Definition |
|------|-----------|
| handler | a task triggered by `notify`; runs once at the end of a play |
| `notify` | signal a handler from a task; only fires when status is `changed` |
| `flush_handlers` | force pending handlers to run now, before the play ends |
| tag | a label on a task, block, or role that controls what gets executed |
| `when` | a Jinja2 condition that gates whether a task runs |
| `loop` | iterate over a list, running the task once per item |
| `until` | retry a task repeatedly until a condition becomes true |
| block | a logical grouping of tasks with shared attributes and error handling |
| `rescue` | tasks that run when a block fails |
| `always` | tasks that run regardless of block success or failure |
| static | resolved at parse time before execution starts (`import_*`) |
| dynamic | resolved at runtime when Ansible reaches that point (`include_*`) |

---

## Resources

- [Handlers](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html)
- [Tags](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_tags.html)
- [Conditionals](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_conditionals.html)
- [Loops](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_loops.html)
- [Blocks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html)
- [import vs include](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse.html#comparing-includes-and-imports-dynamic-and-static-reuse)
