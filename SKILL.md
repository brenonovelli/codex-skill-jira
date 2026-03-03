---
name: jira
description: Generate technical planning artifacts from a Jira issue key or URL. Use when the user asks to plan work or run the implementation flow from Jira context, summarize Jira data, extract repository links, prepare a delivery checklist, or explicitly invokes $jira.
---

# Jira Integration Skill

Use `scripts/jira_bootstrap.sh` as the main entrypoint.
For workspace-first usage, see `AGENTS.md` in this repository root.
For user-facing onboarding, see `README.md`.
For full CLI reference and details, see `docs/WORKSPACE_GUIDE.md`.

Use two supported flows:
- CLI flow: user provides flags directly.
- Conversational flow: ask for missing inputs in a fixed sequence, confirm, then run the same CLI command.

## Execute

```bash
scripts/jira_bootstrap.sh --issue <KEY|URL> [--mode plan|run] [--workspace feature-folder|current-folder] [--clone ask|auto|off] [--issue-json <jira-issue.json>] [--env-file <path>]
```

If run in an interactive terminal with missing flags, the script asks questions for the missing values and requests confirmation before execution.

Shortcut command:

```bash
scripts/codex-jira [ISSUE] [jira_bootstrap flags...]
```

Examples:
- `scripts/codex-jira VA-1462`
- `scripts/codex-jira VA-1462 --mode run --clone off`
- `scripts/codex-jira` (interactive prompts)

## Conversational Protocol

When the user invokes the skill without all inputs, ask one question at a time in this exact order:
1. `issue` (required)
2. `mode` (`plan` default, `run` optional)
3. `workspace` (`feature-folder` default, `current-folder` optional)
4. `clone` (`ask` default, `auto` or `off` optional)

Validation rules:
- Reject invalid values and reprompt with allowed options.
- Do not continue until `issue` is present.
- Before execution, show a short summary and request explicit confirmation.

Execution rule:
- Always execute through `scripts/jira_bootstrap.sh` with resolved values (single source of truth).

## Inputs

- `--issue` (required): Jira key (example: `VA-1462`) or full Jira URL.
- `--mode`:
  - `plan` (default): generate docs only.
  - `run`: generate docs and optionally clone repositories detected in Jira data.
- `--workspace`:
  - `feature-folder` (default): create `./<ISSUE_KEY>/docs`.
  - `current-folder`: write docs to `./docs`.
- `--clone`:
  - `ask` (default): ask before cloning when in interactive shell.
  - `auto`: clone directly.
  - `off`: never clone.
- `--issue-json`: optional local Jira JSON file for offline testing.
- `--env-file`: optional explicit credentials file.

## Jira API Access

When `--issue-json` is not provided, Jira credentials are required.
Preferred: load from `.env`/`.env.local` (or pass `--env-file`).
Alternative: export in shell:

```bash
export JIRA_BASE_URL="https://company.atlassian.net"
export JIRA_EMAIL="you@company.com"
export JIRA_API_TOKEN="..."
```

`scripts/jira_get_issue.sh` retrieves Jira issue data and normalizes output (summary, description, comments, and repository links).

## Generated Files

- `<workspace>/docs/<ISSUE>-spec.md`
- `<workspace>/docs/<ISSUE>-implementation-plan.md`
- `<workspace>/docs/<ISSUE>-checklist.md`
- `<workspace>/docs/<ISSUE>-jira-summary.md`
