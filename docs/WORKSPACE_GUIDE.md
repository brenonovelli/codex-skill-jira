# Jira Workspace Guide

## What this repository is

This repository is a Jira-focused Codex workspace.
Its main goal is to turn a Jira issue (`KEY` or URL) into technical planning artifacts.

The conversational behavior is defined in `AGENTS.md`.
The deterministic backend is implemented by scripts in `scripts/`.

## Setup

1. Open Codex in this repository.
2. Configure Jira credentials by copying `.env.example` to `.env` (or `.env.local`):

```bash
cp .env.example .env
```

3. Fill:

```bash
JIRA_BASE_URL="https://yourcompany.atlassian.net"
JIRA_EMAIL="you@company.com"
JIRA_API_TOKEN="your_api_token_here"
```

Notes:
- `.env` and `.env.local` are ignored by git.
- You can also provide an explicit credentials file with `--env-file`.

## Conversational flow

You can start with any sentence that mentions the issue key or Jira URL, for example:
- `Let's work on VA-123`
- `Help me with VA-123`
- `Please plan https://company.atlassian.net/browse/VA-123`
- `Work on ticket VA-123 in run mode`

If values are missing, the flow asks for:
1. `issue`
2. `mode` (`plan` or `run`)
3. `workspace` (`feature-folder` or `current-folder`)
4. `clone` (`ask`, `auto`, or `off`)

Then it asks for confirmation and executes.

## CLI usage

### Recommended entrypoint

```bash
scripts/codex-jira [ISSUE] [flags...]
```

Examples:

```bash
scripts/codex-jira VA-123
scripts/codex-jira VA-123 --mode run --workspace current-folder --clone off
scripts/codex-jira --issue-json /tmp/VA-123.raw.json
```

### Full backend command

```bash
scripts/jira_bootstrap.sh --issue <KEY|URL> [--mode plan|run] [--workspace feature-folder|current-folder] [--clone ask|auto|off] [--issue-json <jira-issue.json>] [--env-file <path>]
```

CLI options:
- `--issue` (required): Jira key (`VA-123`) or Jira issue URL.
- `--mode`: `plan` (docs only, default) or `run` (docs + optional clone).
- `--workspace`: `feature-folder` (default) or `current-folder`.
- `--clone`: `ask` (default), `auto`, or `off`.
- `--issue-json`: offline fixture mode (skips Jira API call).
- `--env-file`: explicit env file with Jira credentials.

## Credentials behavior

- If `--issue-json` is provided, Jira credentials are not required.
- If `--issue-json` is not provided, credentials are required.
- Without credentials and without `--issue-json`, the command exits with an error.

Credential loading order:
1. `--env-file <path>`
2. `<workspace>/.env`
3. `<workspace>/.env.local`
4. `./.env`
5. `./.env.local`

## Output files

The flow generates:
- `docs/<ISSUE>-spec.md`
- `docs/<ISSUE>-implementation-plan.md`
- `docs/<ISSUE>-checklist.md`
- `docs/<ISSUE>-jira-summary.md`
