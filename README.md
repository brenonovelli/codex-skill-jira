# Jira Codex Workspace

Turn a Jira issue (`KEY` or URL) into technical planning docs with a conversational or CLI flow.

## Global Skill Install (`$jira`)

After publishing this repo on GitHub, install it globally in Codex:

```bash
python3 "$HOME/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py" \
  --repo <owner>/<repo> \
  --path . \
  --name jira
```

Restart Codex after installation.

Then, inside any project, you can invoke:

```text
$jira VA-1234
```

## Quick Setup

```bash
cp .env.example .env
```

Fill `.env`:

```bash
JIRA_BASE_URL="https://yourcompany.atlassian.net"
JIRA_EMAIL="you@company.com"
JIRA_API_TOKEN="your_api_token_here"
```

## Quick Usage

### Conversational

Open Codex in this repository and say something that mentions the issue:
- `Let's work on VA-123`
- `Please plan https://company.atlassian.net/browse/VA-123`

### CLI

```bash
scripts/codex-jira VA-123
scripts/codex-jira VA-123 --mode run --workspace current-folder --clone off
```

Offline fixture mode:

```bash
scripts/codex-jira VA-123 --issue-json /tmp/VA-123.raw.json
```

## Generated Files

- `docs/<ISSUE>-spec.md`
- `docs/<ISSUE>-implementation-plan.md`
- `docs/<ISSUE>-checklist.md`
- `docs/<ISSUE>-jira-summary.md`

## Full Documentation

For complete CLI reference and behavior details, see `docs/WORKSPACE_GUIDE.md`.
