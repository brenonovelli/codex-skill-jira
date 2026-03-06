---
name: jira
description: Build a ready-to-implement technical plan from a Jira issue key or URL, including repository cloning and code-aware analysis when repo links are present. Use when the user asks to plan or execute work from Jira context, or explicitly invokes $jira.
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
   - `clone=auto`
   - `confirm=off`
3. Execute directly without confirmation prompts.
4. In `mode=plan`, finish the whole flow in the same user request:
   - read full Jira context;
   - clone listed repositories (when available and enabled);
   - analyze local code to identify likely change areas;
   - produce a ready-to-implement plan;
   - run `/plan` (or equivalent inline output) using that plan.

On-demand confirmation:
- If the user explicitly asks for confirmation, set `confirm=ask` and show a short summary before execution.

Validation rules:
- Reject invalid values and reprompt with allowed options.
- Do not continue until `issue` is present.

Execution rule:
- Always execute through `scripts/jira_bootstrap.sh` with resolved values (single source of truth).
- For `mode=plan`, use `docs/<ISSUE>-implementation-plan.md` as `/plan` input.
- If `repos/` exists, include repository analysis in the planning step.
- Do not pause waiting for an extra user message between bootstrap and planning unless blocked.

Credential setup rule:
- Fast-path: if user already provided `JIRA_BASE_URL`, `JIRA_EMAIL`, and `JIRA_API_TOKEN` in the same request, run `scripts/jira_configure_credentials.sh` immediately without exploratory checks.
- If execution fails due to missing Jira credentials, ask user for:
  - `JIRA_BASE_URL`
  - `JIRA_EMAIL`
  - `JIRA_API_TOKEN`
- Then run `scripts/jira_configure_credentials.sh` to save them globally in `<skill-root>/.env.local`.
- Re-run the original Jira request after credentials are configured.

Implementation rule:
- When user asks to implement/apply the plan, create a new git branch before any code edits.
- Default branch naming: `feature/<ISSUE_KEY>-<ISSUE_TITLE_SLUG>`.
- Build slug from Jira summary/title in lowercase kebab-case (ASCII).
- If branch name already exists, append a unique suffix.
- Respect explicit branch names provided by user.

## Generated Files

- `<workspace>/docs/<ISSUE>-implementation-plan.md`

When repository links are present and clone is enabled:
- `<workspace>/repos/<repo-name>`
