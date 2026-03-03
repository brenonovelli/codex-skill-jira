---
name: jira
description: Generate technical planning artifacts from a Jira issue key or URL. Use when the user asks to plan work or run the implementation flow from Jira context, summarize Jira data, extract repository links, prepare a delivery checklist, or explicitly invokes $jira.
---

# Jira Integration Skill

Use `scripts/jira_bootstrap.sh` as the main entrypoint.
For workspace-first usage, see `AGENTS.md` in this repository root.
For user-facing onboarding, see `README.md`.
For full skill usage details, see `docs/WORKSPACE_GUIDE.md`.

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

Credential setup rule:
- If execution fails due to missing Jira credentials, ask user for:
  - `JIRA_BASE_URL`
  - `JIRA_EMAIL`
  - `JIRA_API_TOKEN`
- Then run `scripts/jira_configure_credentials.sh` to save them globally in `<skill-root>/.env.local`.
- Re-run the original Jira request after credentials are configured.

## Generated Files

- `<workspace>/docs/<ISSUE>-spec.md`
- `<workspace>/docs/<ISSUE>-implementation-plan.md`
- `<workspace>/docs/<ISSUE>-checklist.md`
- `<workspace>/docs/<ISSUE>-jira-summary.md`
