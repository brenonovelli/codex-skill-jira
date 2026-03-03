# Jira Codex Skill (`$jira`)

Generate technical planning docs from a Jira issue key or URL.

## Install Globally (Codex-first)

In interactive Codex:

```text
Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira
```

Or from terminal with Codex:

```bash
codex exec 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Note: use single quotes in `codex exec` so the shell does not expand `$skill-installer`.

After installation, restart Codex.

## Project Setup

Ask Codex to configure global credentials for `$jira`:

```text
Configure Jira credentials for $jira
```

Codex will ask for:
- `JIRA_BASE_URL`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

Credentials are stored in the global skill file:

```text
~/.codex/skills/jira/.env.local
```

## Use

Inside any project:

```text
$jira VA-1234
```

Or mention the issue naturally:
- `Let's work on VA-1234`
- `Please plan https://company.atlassian.net/browse/VA-1234`

## Output Files

- `docs/<ISSUE>-spec.md`
- `docs/<ISSUE>-implementation-plan.md`
- `docs/<ISSUE>-checklist.md`
- `docs/<ISSUE>-jira-summary.md`

## More Details

See `docs/WORKSPACE_GUIDE.md`.
