# Jira Skill Guide

## Overview

This repository provides a global Codex skill named `$jira`.
Use it to convert a Jira issue key or URL into technical planning documents.

## Install Globally

### Interactive Codex (recommended)

```text
Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira
```

### Terminal with Codex

```bash
codex exec 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Note: use single quotes so the shell does not expand `$skill-installer`.

After installation, restart Codex.

## Project Configuration

Ask Codex to configure credentials globally:

```text
Configure Jira credentials for $jira
```

Codex should collect:
- `JIRA_BASE_URL`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

And store them in:

```text
~/.codex/skills/jira/.env.local
```

Credentials behavior:
- If Jira credentials are missing, the flow stops with an explicit error.
- Offline fixture mode is supported when the skill receives a local Jira JSON input.

## Usage

Call the skill directly:

```text
$jira VA-1234
```

You can also mention issues naturally in conversation:
- `Let's work on VA-1234`
- `Help me with VA-1234`
- `Please plan https://company.atlassian.net/browse/VA-1234`

## Generated Files

For each issue:
- `docs/<ISSUE>-spec.md`
- `docs/<ISSUE>-implementation-plan.md`
- `docs/<ISSUE>-checklist.md`
- `docs/<ISSUE>-jira-summary.md`
