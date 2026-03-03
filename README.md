# Jira Codex Skill (`$jira`)

Generate technical planning docs from a Jira issue key or URL.

## Install Globally (Codex-first)

In interactive Codex:

```text
Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira
```

Or from terminal with Codex:

```bash
codex exec --skip-git-repo-check -s workspace-write --add-dir "$HOME/.codex" --add-dir /tmp 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Note: use single quotes in `codex exec` so the shell does not expand `$skill-installer`.

Why these flags:
- `--skip-git-repo-check`: allows global installation outside a trusted Git directory.
- `-s workspace-write`: avoids `read-only` sandbox failures during installation.
- `--add-dir "$HOME/.codex"` and `--add-dir /tmp`: grants write access for target and temp directories.

If your environment still blocks writes, use:

```bash
codex exec --skip-git-repo-check -s danger-full-access 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

If your environment blocks access to `github.com`, install from a local clone:

```bash
mkdir -p ~/.codex/skills/jira
rsync -a --delete --exclude '.git' '/path/to/codex-skill-jira/' ~/.codex/skills/jira/
```

If you get:

```text
Not inside a trusted directory and --skip-git-repo-check was not specified.
```

use:

```bash
codex exec --skip-git-repo-check -s workspace-write --add-dir "$HOME/.codex" --add-dir /tmp 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Why this happens: `codex exec` enforces a trusted-directory check (usually a Git repo) before running commands. Skill installation is global, so bypassing that check is expected for this step.

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
