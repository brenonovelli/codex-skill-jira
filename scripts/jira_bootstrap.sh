#!/usr/bin/env bash

set -euo pipefail

ISSUE=""
MODE="plan"
WORKSPACE_STRATEGY="feature-folder"
CLONE_POLICY="ask"
ISSUE_JSON_FILE=""
ENV_FILE=""
ISSUE_SET=0
MODE_SET=0
WORKSPACE_SET=0
CLONE_SET=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
JIRA_GET_SCRIPT="${SCRIPT_DIR}/jira_get_issue.sh"

usage() {
  cat <<'EOF'
Usage:
  jira_bootstrap.sh --issue <KEY|URL> [--mode plan|run] [--workspace feature-folder|current-folder] [--clone ask|auto|off] [--issue-json <jira-issue.json>] [--env-file <path>]

Interactive mode:
  If run in a terminal and some flags are omitted, the script asks for missing values.

Credentials:
  If --issue-json is not provided, Jira credentials are required.
  The script loads credentials from:
  1) --env-file
  2) <skill-root>/.env
  3) <skill-root>/.env.local

Examples:
  jira_bootstrap.sh --issue VA-1462
  jira_bootstrap.sh --issue https://company.atlassian.net/browse/VA-1462 --mode run --clone ask
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

prompt_with_default() {
  local prompt="$1"
  local default_value="$2"
  local user_value=""
  if ! read -r -p "${prompt} [${default_value}]: " user_value; then
    printf '%s\n' "${default_value}"
    return
  fi
  if [[ -z "${user_value}" ]]; then
    printf '%s\n' "${default_value}"
  else
    printf '%s\n' "${user_value}"
  fi
}

interactive_setup_if_needed() {
  local missing_any=0
  local answer=""

  [[ -z "${ISSUE}" ]] && missing_any=1
  [[ "${MODE_SET}" -eq 0 ]] && missing_any=1
  [[ "${WORKSPACE_SET}" -eq 0 ]] && missing_any=1
  [[ "${CLONE_SET}" -eq 0 ]] && missing_any=1

  if [[ "${missing_any}" -eq 0 || ! -t 0 || ! -t 1 ]]; then
    return
  fi

  echo "Interactive setup:"
  if [[ -z "${ISSUE}" ]]; then
    while [[ -z "${ISSUE}" ]]; do
      if ! read -r -p "Issue key or URL (required): " ISSUE; then
        echo "Aborted."
        exit 1
      fi
      if [[ -z "${ISSUE}" ]]; then
        echo "Issue is required."
      fi
    done
  fi

  if [[ "${MODE_SET}" -eq 0 ]]; then
    while true; do
      MODE="$(prompt_with_default "Mode (plan/run)" "${MODE}")"
      if is_valid_mode "${MODE}"; then
        break
      fi
      echo "Invalid mode: ${MODE}. Use plan or run."
    done
  fi

  if [[ "${WORKSPACE_SET}" -eq 0 ]]; then
    while true; do
      WORKSPACE_STRATEGY="$(prompt_with_default "Workspace (feature-folder/current-folder)" "${WORKSPACE_STRATEGY}")"
      if is_valid_workspace "${WORKSPACE_STRATEGY}"; then
        break
      fi
      echo "Invalid workspace: ${WORKSPACE_STRATEGY}. Use feature-folder or current-folder."
    done
  fi

  if [[ "${CLONE_SET}" -eq 0 ]]; then
    while true; do
      CLONE_POLICY="$(prompt_with_default "Clone policy (ask/auto/off)" "${CLONE_POLICY}")"
      if is_valid_clone_policy "${CLONE_POLICY}"; then
        break
      fi
      echo "Invalid clone policy: ${CLONE_POLICY}. Use ask, auto or off."
    done
  fi

  echo "Confirm values:"
  echo "- Issue: ${ISSUE}"
  echo "- Mode: ${MODE}"
  echo "- Workspace: ${WORKSPACE_STRATEGY}"
  echo "- Clone policy: ${CLONE_POLICY}"
  if ! read -r -p "Continue? [Y/n] " answer; then
    echo "Aborted."
    exit 1
  fi
  case "${answer}" in
    n|N|no|NO)
      echo "Aborted."
      exit 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      ISSUE="${2:-}"
      ISSUE_SET=1
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      MODE_SET=1
      shift 2
      ;;
    --workspace)
      WORKSPACE_STRATEGY="${2:-}"
      WORKSPACE_SET=1
      shift 2
      ;;
    --clone)
      CLONE_POLICY="${2:-}"
      CLONE_SET=1
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
interactive_setup_if_needed

if [[ -z "${ISSUE}" ]]; then
  echo "Missing --issue (or run interactively to provide it)."
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
  ISSUE_JSON="$("${JIRA_GET_SCRIPT}" --issue "${ISSUE}" --input-file "${ISSUE_JSON_FILE}")"
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
  ISSUE_JSON="$("${JIRA_GET_SCRIPT}" "${JIRA_GET_ARGS[@]}")"
fi

ISSUE_KEY="$(printf '%s' "${ISSUE_JSON}" | jq -r '.key')"
SUMMARY="$(printf '%s' "${ISSUE_JSON}" | jq -r '.summary')"
STATUS="$(printf '%s' "${ISSUE_JSON}" | jq -r '.status')"
ASSIGNEE="$(printf '%s' "${ISSUE_JSON}" | jq -r '.assignee')"
REPORTER="$(printf '%s' "${ISSUE_JSON}" | jq -r '.reporter')"
DESCRIPTION="$(printf '%s' "${ISSUE_JSON}" | jq -r '.description')"
ISSUE_URL="$(printf '%s' "${ISSUE_JSON}" | jq -r '.issue_url')"

SPEC_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-spec.md"
PLAN_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-implementation-plan.md"
CHECKLIST_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-checklist.md"
SUMMARY_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-jira-summary.md"

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
  local repos_count=0
  repos_count="$(printf '%s' "${ISSUE_JSON}" | jq -r '.repo_urls | length')"
  if [[ "${MODE}" != "run" || "${CLONE_POLICY}" == "off" || "${repos_count}" == "0" ]]; then
    return
  fi

  local should_clone="yes"
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
    echo "Skipping clone step."
    return
  fi

  mkdir -p "${TARGET_DIR}/repos"
  while IFS= read -r url; do
    repo_name="$(basename "${url}" .git)"
    dest="${TARGET_DIR}/repos/${repo_name}"
    if [[ -d "${dest}" ]]; then
      echo "Repository already exists, skipping: ${dest}"
      continue
    fi
    echo "Cloning ${url} -> ${dest}"
    clone_repo_url "${url}" "${dest}" || echo "Failed to clone ${url}"
  done < <(printf '%s' "${ISSUE_JSON}" | jq -r '.repo_urls[]')
}

clone_repositories_if_needed

echo "Generated files:"
echo "- ${SPEC_FILE}"
echo "- ${PLAN_FILE}"
echo "- ${CHECKLIST_FILE}"
echo "- ${SUMMARY_FILE}"
