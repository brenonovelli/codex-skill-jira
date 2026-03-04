#!/usr/bin/env bash

set -euo pipefail

ISSUE=""
MODE="plan"
WORKSPACE_STRATEGY="feature-folder"
CLONE_POLICY="auto"
CONFIRM_POLICY="off"
ISSUE_JSON_FILE=""
ENV_FILE=""
REPO_LINK_COUNT="0"
COMMENTS_COUNT="0"
CLONE_STATUS="not-run"
CLONE_REPORT_LINES=""
LOCAL_REPO_COUNT="0"
LOCAL_REPO_CONTEXT_LINES=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
JIRA_GET_SCRIPT="${SCRIPT_DIR}/jira_get_issue.sh"

usage() {
  cat <<'EOF'
Usage:
  jira_bootstrap.sh --issue <KEY|URL> [--mode plan|run] [--workspace feature-folder|current-folder] [--clone ask|auto|off] [--confirm ask|off] [--issue-json <jira-issue.json>] [--env-file <path>]

Behavior:
  - Defaults: --mode plan --workspace feature-folder --clone auto --confirm off
  - No interactive prompts are shown by default.
  - Use --confirm ask to request interactive confirmation before execution.

Credentials:
  If --issue-json is not provided, Jira credentials are required.
  The script loads credentials from:
  1) --env-file
  2) <skill-root>/.env
  3) <skill-root>/.env.local

Examples:
  jira_bootstrap.sh --issue VA-1462
  jira_bootstrap.sh --issue https://company.atlassian.net/browse/VA-1462 --mode run --clone auto
  jira_bootstrap.sh --issue VA-1462 --confirm ask
  jira_bootstrap.sh --issue VA-1462 --issue-json /tmp/VA-1462.raw.json
EOF
}

load_env_file() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "${file}"
  set +a
}

load_env_defaults() {
  if [[ -n "${ENV_FILE}" ]]; then
    if [[ ! -f "${ENV_FILE}" ]]; then
      echo "Env file not found: ${ENV_FILE}" >&2
      exit 1
    fi
    load_env_file "${ENV_FILE}"
    return
  fi

  load_env_file "${SKILL_ROOT}/.env"
  load_env_file "${SKILL_ROOT}/.env.local"
}

is_valid_mode() {
  local value="${1:-}"
  [[ "${value}" == "plan" || "${value}" == "run" ]]
}

is_valid_workspace() {
  local value="${1:-}"
  [[ "${value}" == "feature-folder" || "${value}" == "current-folder" ]]
}

is_valid_clone_policy() {
  local value="${1:-}"
  [[ "${value}" == "ask" || "${value}" == "auto" || "${value}" == "off" ]]
}

is_valid_confirm_policy() {
  local value="${1:-}"
  [[ "${value}" == "ask" || "${value}" == "off" ]]
}

confirm_if_requested() {
  local answer=""

  if [[ "${CONFIRM_POLICY}" != "ask" ]]; then
    return
  fi

  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "--confirm ask requires an interactive terminal." >&2
    exit 1
  fi

  echo "Execution summary:"
  echo "- Issue: ${ISSUE}"
  echo "- Mode: ${MODE}"
  echo "- Workspace: ${WORKSPACE_STRATEGY}"
  echo "- Clone policy: ${CLONE_POLICY}"
  if ! read -r -p "Continue? [y/N] " answer; then
    echo "Aborted."
    exit 1
  fi
  case "${answer}" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      ISSUE="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --workspace)
      WORKSPACE_STRATEGY="${2:-}"
      shift 2
      ;;
    --clone)
      CLONE_POLICY="${2:-}"
      shift 2
      ;;
    --confirm)
      CONFIRM_POLICY="${2:-}"
      shift 2
      ;;
    --issue-json)
      ISSUE_JSON_FILE="${2:-}"
      shift 2
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

load_env_defaults

if [[ -z "${ISSUE}" ]]; then
  echo "Missing --issue."
  usage
  exit 1
fi

if ! is_valid_mode "${MODE}"; then
  echo "Invalid --mode: ${MODE}"
  exit 1
fi

if ! is_valid_workspace "${WORKSPACE_STRATEGY}"; then
  echo "Invalid --workspace: ${WORKSPACE_STRATEGY}"
  exit 1
fi

if ! is_valid_clone_policy "${CLONE_POLICY}"; then
  echo "Invalid --clone: ${CLONE_POLICY}"
  exit 1
fi

if ! is_valid_confirm_policy "${CONFIRM_POLICY}"; then
  echo "Invalid --confirm: ${CONFIRM_POLICY}"
  exit 1
fi

confirm_if_requested

if [[ "${ISSUE}" =~ /browse/([A-Za-z0-9]+-[0-9]+) ]]; then
  ISSUE_KEY_INPUT="${BASH_REMATCH[1]}"
else
  ISSUE_KEY_INPUT="${ISSUE}"
fi

if [[ "${WORKSPACE_STRATEGY}" == "feature-folder" ]]; then
  TARGET_DIR="./${ISSUE_KEY_INPUT}"
  mkdir -p "${TARGET_DIR}/docs"
else
  TARGET_DIR="."
  mkdir -p "${TARGET_DIR}/docs"
fi

ISSUE_JSON=""
if [[ -n "${ISSUE_JSON_FILE}" ]]; then
  ISSUE_JSON="$(bash "${JIRA_GET_SCRIPT}" --issue "${ISSUE}" --input-file "${ISSUE_JSON_FILE}")"
else
  if [[ -z "${JIRA_BASE_URL:-}" || -z "${JIRA_EMAIL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
    echo "Missing Jira credentials. Configure ${SKILL_ROOT}/.env.local (or .env), or pass --env-file." >&2
    echo "Alternative for offline mode: pass --issue-json <file>." >&2
    exit 1
  fi
  JIRA_GET_ARGS=(--issue "${ISSUE}")
  if [[ -n "${ENV_FILE}" ]]; then
    JIRA_GET_ARGS+=(--env-file "${ENV_FILE}")
  fi
  ISSUE_JSON="$(bash "${JIRA_GET_SCRIPT}" "${JIRA_GET_ARGS[@]}")"
fi

ISSUE_KEY="$(printf '%s' "${ISSUE_JSON}" | jq -r '.key')"
SUMMARY="$(printf '%s' "${ISSUE_JSON}" | jq -r '.summary')"
STATUS="$(printf '%s' "${ISSUE_JSON}" | jq -r '.status')"
ASSIGNEE="$(printf '%s' "${ISSUE_JSON}" | jq -r '.assignee')"
REPORTER="$(printf '%s' "${ISSUE_JSON}" | jq -r '.reporter')"
DESCRIPTION="$(printf '%s' "${ISSUE_JSON}" | jq -r '.description')"
ISSUE_URL="$(printf '%s' "${ISSUE_JSON}" | jq -r '.issue_url')"
REPO_LINK_COUNT="$(printf '%s' "${ISSUE_JSON}" | jq -r '.repo_urls | length')"
COMMENTS_COUNT="$(printf '%s' "${ISSUE_JSON}" | jq -r '.comments | length')"

SPEC_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-spec.md"
PLAN_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-implementation-plan.md"
CHECKLIST_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-checklist.md"
SUMMARY_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-jira-summary.md"

append_clone_report_line() {
  CLONE_REPORT_LINES+="- $1"$'\n'
}

append_local_repo_context_line() {
  LOCAL_REPO_CONTEXT_LINES+="- $1"$'\n'
}

display_path() {
  local path="$1"
  printf '%s' "${path#./}"
}

build_repository_workspace_section() {
  local clone_execution="not-run"
  case "${CLONE_STATUS}" in
    disabled) clone_execution="disabled by policy" ;;
    no-repositories) clone_execution="no repository links found" ;;
    skipped) clone_execution="skipped by confirmation policy" ;;
    completed) clone_execution="executed" ;;
  esac

  {
    echo "## Repository Workspace"
    echo "- Repository links detected: ${REPO_LINK_COUNT}"
    echo "- Clone policy: ${CLONE_POLICY}"
    echo "- Clone execution: ${clone_execution}"
    echo "- Local repositories available: ${LOCAL_REPO_COUNT}"
    if [[ -z "${CLONE_REPORT_LINES}" ]]; then
      echo "- No clone actions recorded."
    else
      printf '%s' "${CLONE_REPORT_LINES}"
    fi
    if [[ -n "${LOCAL_REPO_CONTEXT_LINES}" ]]; then
      echo
      echo "### Local Repository Snapshot"
      printf '%s' "${LOCAL_REPO_CONTEXT_LINES}"
    fi
  }
}

build_consolidated_context_section() {
  {
    echo "## Consolidated Context"
    echo "- Issue key: ${ISSUE_KEY}"
    echo "- Summary: ${SUMMARY}"
    echo "- Status: ${STATUS}"
    echo "- Assignee: ${ASSIGNEE}"
    echo "- Reporter: ${REPORTER}"
    echo "- Comments captured: ${COMMENTS_COUNT}"
    echo "- Repository links detected: ${REPO_LINK_COUNT}"
    echo "- Local repositories available: ${LOCAL_REPO_COUNT}"
    if [[ "${LOCAL_REPO_COUNT}" != "0" ]]; then
      echo "- Repository root: \`$(display_path "${TARGET_DIR}/repos")\`"
    fi
  }
}

build_plan_handoff_section() {
  local plan_display=""
  local summary_display=""
  local spec_display=""
  local repos_display=""
  plan_display="$(display_path "${PLAN_FILE}")"
  summary_display="$(display_path "${SUMMARY_FILE}")"
  spec_display="$(display_path "${SPEC_FILE}")"
  repos_display="$(display_path "${TARGET_DIR}/repos")"

  {
    echo "## Planning Handoff"
    echo "- Consolidation order: clone repositories (when available) -> consolidate issue + repository context -> run \`/plan\`."
    echo "- Suggested \`/plan\` context:"
    echo "  - \`${spec_display}\`"
    echo "  - \`${summary_display}\`"
    echo "  - \`${plan_display}\`"
    if [[ "${LOCAL_REPO_COUNT}" != "0" ]]; then
      echo "  - local repositories under \`${repos_display}\`"
    else
      echo "  - no local repositories available (plan only from Jira context)"
    fi
  }
}

cat > "${SPEC_FILE}" <<EOF
# ${ISSUE_KEY} - Technical Spec

## Jira Context
- Source issue: ${ISSUE}
- Jira URL: ${ISSUE_URL}
- Summary: ${SUMMARY}
- Status: ${STATUS}
- Assignee: ${ASSIGNEE}
- Reporter: ${REPORTER}

## Problem Statement
${DESCRIPTION:-No Jira description available.}

## Scope
- Define solution approach.
- Identify impacted systems and repositories.
- Break down delivery in implementation phases.

## Open Questions
- [ ] Confirm business constraints and acceptance criteria.
- [ ] Confirm dependencies with other teams.
- [ ] Confirm rollout strategy and observability requirements.
EOF

cat > "${PLAN_FILE}" <<EOF
# ${ISSUE_KEY} - Implementation Plan

- Source issue: ${ISSUE}
- Jira URL: ${ISSUE_URL}
- Mode: ${MODE}
- Workspace strategy: ${WORKSPACE_STRATEGY}
- Clone policy: ${CLONE_POLICY}

## Phase 1 - Discovery
- Analyze requirements from Jira description and comments.
- Validate technical constraints and impacted services.

## Phase 2 - Implementation
- Define concrete code changes by repository/module.
- Plan migrations/config changes if required.

## Phase 3 - Validation
- Define test strategy (unit/integration/manual).
- Define rollout checks and rollback path.
EOF

cat > "${CHECKLIST_FILE}" <<EOF
# ${ISSUE_KEY} - Delivery Checklist

## Analysis
- [ ] Read Jira description, comments, and linked issues.
- [ ] Confirm acceptance criteria.
- [ ] Confirm impacted repositories and services.

## Build
- [ ] Implement planned changes.
- [ ] Add/update tests.
- [ ] Update docs and runbooks if needed.

## Verification
- [ ] Run test suite.
- [ ] Validate observability and alerts.
- [ ] Prepare rollout and rollback notes.
EOF

{
  echo "# ${ISSUE_KEY} - Jira Summary"
  echo
  echo "- Source issue: ${ISSUE}"
  echo "- Jira URL: ${ISSUE_URL}"
  echo "- Summary: ${SUMMARY}"
  echo "- Status: ${STATUS}"
  echo "- Assignee: ${ASSIGNEE}"
  echo "- Reporter: ${REPORTER}"
  echo
  echo "## Description"
  echo "${DESCRIPTION:-No Jira description available.}"
  echo
  echo "## Recent Comments"
  if ! printf '%s' "${ISSUE_JSON}" | jq -e '.comments | length > 0' >/dev/null; then
    echo "- No comments found."
  else
    printf '%s' "${ISSUE_JSON}" | jq -r '.comments[] | "- " + .'
  fi
  echo
  echo "## Repository Links"
  if ! printf '%s' "${ISSUE_JSON}" | jq -e '.repo_urls | length > 0' >/dev/null; then
    echo "- No repository links detected."
  else
    printf '%s' "${ISSUE_JSON}" | jq -r '.repo_urls[] | "- " + .'
  fi
} > "${SUMMARY_FILE}"

clone_repo_url() {
  local url="$1"
  local destination="$2"
  if [[ "${url}" =~ github\.com/([^/]+/[^/.]+)(\.git)?$ ]] && command -v gh >/dev/null 2>&1; then
    local repo="${BASH_REMATCH[1]}"
    gh repo clone "${repo}" "${destination}"
    return
  fi
  git clone "${url}" "${destination}"
}

clone_repositories_if_needed() {
  local should_clone="yes"
  local answer=""
  local repo_name=""
  local dest=""
  local dest_display=""

  if [[ "${CLONE_POLICY}" == "off" ]]; then
    CLONE_STATUS="disabled"
    append_clone_report_line "Repository clone step disabled by --clone off."
    return
  fi

  if [[ "${REPO_LINK_COUNT}" == "0" ]]; then
    CLONE_STATUS="no-repositories"
    append_clone_report_line "No repository links were detected in the Jira issue."
    return
  fi

  if [[ "${CLONE_POLICY}" == "ask" ]]; then
    should_clone="no"
    if [[ -t 0 ]]; then
      if ! read -r -p "Clone detected repositories now? [y/N] " answer; then
        answer=""
      fi
      case "${answer}" in
        y|Y|yes|YES) should_clone="yes" ;;
      esac
    fi
  fi

  if [[ "${should_clone}" != "yes" ]]; then
    CLONE_STATUS="skipped"
    append_clone_report_line "Repository clone step skipped (policy ask without positive confirmation)."
    echo "Skipping clone step."
    return
  fi

  CLONE_STATUS="completed"
  mkdir -p "${TARGET_DIR}/repos"
  while IFS= read -r url; do
    repo_name="$(basename "${url}" .git)"
    repo_name="${repo_name%%\?*}"
    dest="${TARGET_DIR}/repos/${repo_name}"
    dest_display="${dest#./}"
    if [[ -d "${dest}" ]]; then
      echo "Repository already exists, skipping: ${dest}"
      append_clone_report_line "Already present: \`${dest_display}\` (source: ${url})."
      continue
    fi
    echo "Cloning ${url} -> ${dest}"
    if clone_repo_url "${url}" "${dest}"; then
      append_clone_report_line "Cloned: \`${dest_display}\` (source: ${url})."
    else
      echo "Failed to clone ${url}"
      append_clone_report_line "Failed: ${url}."
    fi
  done < <(printf '%s' "${ISSUE_JSON}" | jq -r '.repo_urls[]')
}

collect_local_repositories_context() {
  local repo_dir=""
  local rel_path=""
  local origin=""
  local branch=""
  local head=""

  LOCAL_REPO_COUNT="0"
  LOCAL_REPO_CONTEXT_LINES=""

  if [[ ! -d "${TARGET_DIR}/repos" ]]; then
    return
  fi

  while IFS= read -r repo_dir; do
    ((LOCAL_REPO_COUNT+=1))
    rel_path="$(display_path "${repo_dir}")"
    if git -C "${repo_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      origin="$(git -C "${repo_dir}" config --get remote.origin.url 2>/dev/null || true)"
      branch="$(git -C "${repo_dir}" symbolic-ref --short HEAD 2>/dev/null || true)"
      head="$(git -C "${repo_dir}" rev-parse --short HEAD 2>/dev/null || true)"
      [[ -n "${origin}" ]] || origin="unknown"
      [[ -n "${branch}" ]] || branch="detached-or-unknown"
      [[ -n "${head}" ]] || head="unknown"
      append_local_repo_context_line "\`${rel_path}\` (branch: ${branch}, head: ${head}, origin: ${origin})."
    else
      append_local_repo_context_line "\`${rel_path}\` (not a git repository)."
    fi
  done < <(find "${TARGET_DIR}/repos" -mindepth 1 -maxdepth 1 -type d | sort)
}

clone_repositories_if_needed
collect_local_repositories_context

REPOSITORY_WORKSPACE_SECTION="$(build_repository_workspace_section)"
CONSOLIDATED_CONTEXT_SECTION="$(build_consolidated_context_section)"
PLAN_HANDOFF_SECTION="$(build_plan_handoff_section)"

{
  echo
  printf '%s\n' "${REPOSITORY_WORKSPACE_SECTION}"
  echo
  printf '%s\n' "${CONSOLIDATED_CONTEXT_SECTION}"
  echo
  printf '%s\n' "${PLAN_HANDOFF_SECTION}"
} >> "${PLAN_FILE}"

{
  echo
  printf '%s\n' "${REPOSITORY_WORKSPACE_SECTION}"
  echo
  printf '%s\n' "${CONSOLIDATED_CONTEXT_SECTION}"
  echo
  printf '%s\n' "${PLAN_HANDOFF_SECTION}"
} >> "${SUMMARY_FILE}"

echo "Generated files:"
echo "- ${SPEC_FILE}"
echo "- ${PLAN_FILE}"
echo "- ${CHECKLIST_FILE}"
echo "- ${SUMMARY_FILE}"

if [[ "${MODE}" == "plan" ]]; then
  echo "Next conversational step: run /plan using $(display_path "${PLAN_FILE}") and $(display_path "${SUMMARY_FILE}")."
fi
