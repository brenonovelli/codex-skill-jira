---
name: jira
description: Generate technical planning artifacts from a Jira issue key or URL. Use when the user asks to plan work or run the implementation flow from Jira context, summarize Jira data, extract repository links, prepare a delivery checklist, or explicitly invokes $jira.
---

# Jira Integration Skill

Use `scripts/jira_bootstrap.sh` as the main entrypoint.
For workspace-first usage, see `AGENTS.md` in this repository root.
For user-facing onboarding, see `README.md`.
For evolving operational learnings, see `docs/WORKSPACE_GUIDE.md`.

## Conversational Protocol

Default behavior (low friction):
1. Resolve `issue` (required)
2. Use defaults unless user explicitly overrides:
   - `mode=plan`
   - `workspace=feature-folder`
   - `clone=ask`
   - `confirm=off`
3. Execute directly without confirmation prompts.

On-demand confirmation:
- If the user explicitly asks for confirmation, set `confirm=ask` and show a short summary before execution.

Validation rules:
- Reject invalid values and reprompt with allowed options.
- Do not continue until `issue` is present.

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
