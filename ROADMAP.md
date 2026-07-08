# Ansible — Professional Learning Roadmap

## What you already know

  - What an inventory file is (static, INI/YAML format)
  - What ansible.cfg does and its basic settings
  - What a playbook is — plays, tasks, modules
  - Running ad-hoc commands with ansible
  - Basic modules: ping, copy, file, service, apt/yum

  This path builds directly on top of those. Work through each phase IN ORDER.
  Each phase has a tasks.md file with concepts to read, exercises to do, things to break,
  and a mini project at the end. Do not move to the next phase until the mini project works.

---

## Phase Order

  01_Variables_Facts_Jinja2/          → the language of Ansible — do NOT skip or rush this
  02_Handlers_Tags_Task_Control/      → flow control, conditionals, loops, blocks
  03_Roles_Reusability/               → how real company projects are structured
  04_Vault_Error_Handling_Idempotency/ → enterprise reliability and secrets
  05_Dynamic_Inventory_Performance/   → scale and automation
  06_Collections_Molecule_Linting/    → quality, testing, modern Ansible standards
  07_AWX_Automation_Platform/         → what companies actually run

---

## What you are building toward

  By the end of this path you should be able to:

  - Explain Ansible variable precedence without hesitating
  - Structure a multi-role project the way companies do it
  - Handle secrets securely with Ansible Vault and vault IDs
  - Write truly idempotent playbooks and explain why it matters
  - Use dynamic inventory against AWS EC2 or Azure
  - Test roles with Molecule and enforce quality with ansible-lint
  - Describe how AWX/AAP works and how companies use it for RBAC and scheduling
  - Answer every question in the interview prep sections confidently

---

## Rules for yourself

  - Work through each concept in order. Do not skip exercises.
  - Do every exercise yourself. Do not copy-paste playbooks from anywhere.
  - Run every exercise and read the output — not just "it worked", understand WHY.
  - Do the "Break stuff on purpose" section. Intentional failures teach more than success.
  - Finish the mini project before moving to the next phase. It is not optional.
  - For vocabulary — you must be able to define every word without looking at the file.
  - For resources — read the linked docs. The tasks.md is a guide, not a replacement for docs.

---

## Overall Resources — Always Available

  Ansible Official Documentation:              https://docs.ansible.com/
  Jeff Geerling — Ansible for DevOps (book):  https://www.ansiblefordevops.com/
  Jeff Geerling GitHub (reference roles):      https://github.com/geerlingguy
  Ansible Galaxy (community content):          https://galaxy.ansible.com/
  Red Hat Learning — Ansible (free tier):      https://www.redhat.com/en/technologies/management/ansible/training
  KillerCoda Ansible Scenarios (hands-on):     https://killercoda.com/ansible
  DO407 Course Outline (Red Hat official):     https://www.redhat.com/en/services/training/do407-automation-ansible-i
