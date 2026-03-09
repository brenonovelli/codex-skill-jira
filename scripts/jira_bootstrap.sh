#!/usr/bin/env bash

set -euo pipefail

ISSUE=""
MODE="plan"
WORKSPACE_STRATEGY="feature-folder"
CLONE_POLICY="auto"
CONFIRM_POLICY="off"
ISSUE_JSON_FILE=""
ENV_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
JIRA_GET_SCRIPT="${SCRIPT_DIR}/jira_get_issue.sh"
STEP_COUNTER=0

ISSUE_KEY=""
SUMMARY=""
STATUS=""
ASSIGNEE=""
REPORTER=""
DESCRIPTION=""
ISSUE_URL=""
COMMENTS_COUNT="0"
REPO_LINK_COUNT="0"
TARGET_DIR=""
PLAN_FILE=""

CLONE_STATUS="not-run"
CLONE_REPORT_LINES=""
LOCAL_REPO_COUNT="0"
LOCAL_REPO_CONTEXT_LINES=""
CODE_ANALYSIS_LINES=""
VALIDATION_COMMANDS_LINES=""
IMPLEMENTATION_STEPS_LINES=""
RISK_LINES=""

log_info() {
  echo "[jira_bootstrap] $*"
}

log_step() {
  ((STEP_COUNTER+=1))
  log_info "Step ${STEP_COUNTER}: $*"
}

usage() {
  cat <<'EOF_USAGE'
Usage:
  jira_bootstrap.sh --issue <KEY|URL> [--mode plan|run] [--workspace feature-folder|current-folder] [--clone ask|auto|off] [--confirm ask|off] [--issue-json <jira-issue.json>] [--env-file <path>]

Behavior:
  - Defaults: --mode plan --workspace feature-folder --clone auto --confirm off
  - Primary output: docs/<ISSUE>-implementation-plan.md
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
  jira_bootstrap.sh --issue https://company.atlassian.net/browse/VA-1462 --mode plan --clone auto
  jira_bootstrap.sh --issue VA-1462 --confirm ask
  jira_bootstrap.sh --issue VA-1462 --issue-json /tmp/VA-1462.raw.json
EOF_USAGE
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

append_line() {
  local var_name="$1"
  local value="$2"
  printf -v "${var_name}" '%s%s\n' "${!var_name}" "${value}"
}

display_path() {
  local path="$1"
  printf '%s' "${path#./}"
}

extract_keywords() {
  local raw_text="$1"
  printf '%s\n' "${raw_text}" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z0-9' '\n' \
    | awk 'length($0) >= 4' \
    | awk '!seen[$0]++' \
    | awk 'NR<=8'
}

build_search_regex_from_issue() {
  local raw_text="$1"
  local keyword=""
  local regex=""

  while IFS= read -r keyword; do
    [[ -n "${keyword}" ]] || continue
    if [[ -z "${regex}" ]]; then
      regex="${keyword}"
    else
      regex="${regex}|${keyword}"
    fi
  done < <(extract_keywords "${raw_text}")

  printf '%s' "${regex}"
}

summarize_issue_context() {
  local desc_clean=""

  desc_clean="${DESCRIPTION:-No Jira description available.}"
  desc_clean="$(printf '%s' "${desc_clean}" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-1200)"

  {
    echo "## Issue Essentials"
    echo "- Issue key: ${ISSUE_KEY}"
    echo "- Jira URL: ${ISSUE_URL}"
    echo "- Summary: ${SUMMARY}"
    echo "- Status: ${STATUS}"
    echo "- Assignee: ${ASSIGNEE}"
    echo "- Reporter: ${REPORTER}"
    echo "- Comments captured: ${COMMENTS_COUNT}"
    echo
    echo "## Important Context"
    echo "${desc_clean}"
  }
}

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
    append_line CLONE_REPORT_LINES "- Clone disabled by policy (--clone off)."
    log_info "Clone stage skipped by policy (clone=off)."
    return
  fi

  if [[ "${REPO_LINK_COUNT}" == "0" ]]; then
    CLONE_STATUS="no-repositories"
    append_line CLONE_REPORT_LINES "- No repository links detected in issue."
    log_info "Clone stage skipped because no repository links were detected."
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
    append_line CLONE_REPORT_LINES "- Clone skipped (policy ask without positive confirmation)."
    log_info "Clone stage skipped (clone=ask without positive confirmation)."
    return
  fi

  CLONE_STATUS="completed"
  log_step "Cloning detected repositories."
  mkdir -p "${TARGET_DIR}/repos"

  while IFS= read -r url; do
    repo_name="$(basename "${url}" .git)"
    repo_name="${repo_name%%\?*}"
    dest="${TARGET_DIR}/repos/${repo_name}"
    dest_display="$(display_path "${dest}")"

    if [[ -d "${dest}" ]]; then
      append_line CLONE_REPORT_LINES "- Already present: ${dest_display} (source: ${url})."
      log_info "Repository already exists, skipping clone: ${dest_display}"
      continue
    fi

    log_info "Cloning ${url} -> ${dest_display}"
    if clone_repo_url "${url}" "${dest}"; then
      append_line CLONE_REPORT_LINES "- Cloned: ${dest_display} (source: ${url})."
    else
      append_line CLONE_REPORT_LINES "- Failed: ${url}."
      log_info "Failed to clone ${url}"
    fi
  done < <(printf '%s' "${ISSUE_JSON}" | jq -r '.repo_urls[]')
}

analyze_single_repository() {
  local repo_dir="$1"
  local issue_search_regex="$2"
  local repo_name=""
  local rel_path=""
  local branch=""
  local head=""
  local origin=""
  local file_count="0"
  local manifests=""
  local top_areas=""
  local matches=""
  local test_cmd=""

  repo_name="$(basename "${repo_dir}")"
  rel_path="$(display_path "${repo_dir}")"

  ((LOCAL_REPO_COUNT+=1))

  branch="$(git -C "${repo_dir}" symbolic-ref --short HEAD 2>/dev/null || true)"
  head="$(git -C "${repo_dir}" rev-parse --short HEAD 2>/dev/null || true)"
  origin="$(git -C "${repo_dir}" config --get remote.origin.url 2>/dev/null || true)"
  [[ -n "${branch}" ]] || branch="detached-or-unknown"
  [[ -n "${head}" ]] || head="unknown"
  [[ -n "${origin}" ]] || origin="unknown"

  append_line LOCAL_REPO_CONTEXT_LINES "- ${rel_path} (branch: ${branch}, head: ${head}, origin: ${origin})."

  file_count="$(find "${repo_dir}" -type f \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    | wc -l | tr -d ' ')"

  manifests="$(find "${repo_dir}" -maxdepth 2 -type f \
    \( -name 'package.json' -o -name 'go.mod' -o -name 'pyproject.toml' -o -name 'requirements*.txt' -o -name 'pom.xml' -o -name 'build.gradle*' -o -name 'Cargo.toml' -o -name 'Gemfile' \) \
    | sed "s#^${repo_dir}/##" \
    | sort \
    | paste -sd ', ' -)"
  [[ -n "${manifests}" ]] || manifests="none detected (maxdepth 2)"

  top_areas="$(find "${repo_dir}" -mindepth 1 -maxdepth 1 -type d \
    -not -name '.git' \
    -not -name 'node_modules' \
    | sed "s#^${repo_dir}/##" \
    | sort \
    | awk 'NR<=8' \
    | paste -sd ', ' -)"
  [[ -n "${top_areas}" ]] || top_areas="root-only"

  test_cmd=""
  if [[ -f "${repo_dir}/package.json" ]]; then
    local npm_test
    npm_test="$(jq -r '.scripts.test // empty' "${repo_dir}/package.json" 2>/dev/null || true)"
    if [[ -n "${npm_test}" ]]; then
      test_cmd="npm test"
    else
      test_cmd="npm run test --if-present"
    fi
  elif [[ -f "${repo_dir}/go.mod" ]]; then
    test_cmd="go test ./..."
  elif [[ -f "${repo_dir}/pyproject.toml" || -n "$(find "${repo_dir}" -maxdepth 1 -type f -name 'requirements*.txt' -print -quit)" ]]; then
    test_cmd="pytest"
  elif [[ -f "${repo_dir}/pom.xml" ]]; then
    test_cmd="mvn test"
  elif [[ -n "$(find "${repo_dir}" -maxdepth 1 -type f -name 'build.gradle*' -print -quit)" ]]; then
    test_cmd="./gradlew test"
  else
    test_cmd="define project-specific command"
  fi

  matches=""
  if [[ -n "${issue_search_regex}" ]]; then
    matches="$(rg -i --files-with-matches -g '!**/.git/**' -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/build/**' "${issue_search_regex}" "${repo_dir}" 2>/dev/null \
      | sed "s#^${repo_dir}/##" \
      | awk 'NR<=10' \
      | paste -sd ', ' -)"
  fi
  [[ -n "${matches}" ]] || matches="no direct keyword match found"

  append_line CODE_ANALYSIS_LINES "### ${repo_name}"
  append_line CODE_ANALYSIS_LINES "- Path: ${rel_path}"
  append_line CODE_ANALYSIS_LINES "- Files (approx): ${file_count}"
  append_line CODE_ANALYSIS_LINES "- Key manifests: ${manifests}"
  append_line CODE_ANALYSIS_LINES "- Top areas: ${top_areas}"
  append_line CODE_ANALYSIS_LINES "- Candidate touched files/modules: ${matches}"
  append_line CODE_ANALYSIS_LINES ""

  append_line IMPLEMENTATION_STEPS_LINES "- [ ] ${repo_name}: implementar mudanças nas áreas candidatas e ajustar contratos/integrações necessárias."
  append_line IMPLEMENTATION_STEPS_LINES "- [ ] ${repo_name}: adicionar/atualizar testes para cobrir o comportamento esperado da ${ISSUE_KEY}."

  append_line VALIDATION_COMMANDS_LINES "- ${repo_name}: ${test_cmd}"
}

analyze_cloned_repositories() {
  local search_regex=""
  local raw_issue_text=""
  local repo_dir=""

  LOCAL_REPO_COUNT="0"
  LOCAL_REPO_CONTEXT_LINES=""
  CODE_ANALYSIS_LINES=""
  VALIDATION_COMMANDS_LINES=""
  IMPLEMENTATION_STEPS_LINES=""
  RISK_LINES=""

  if [[ ! -d "${TARGET_DIR}/repos" ]]; then
    return
  fi

  raw_issue_text="${SUMMARY}
${DESCRIPTION}
$(printf '%s' "${ISSUE_JSON}" | jq -r '.comments[]?' 2>/dev/null || true)"
  search_regex="$(build_search_regex_from_issue "${raw_issue_text}")"

  while IFS= read -r repo_dir; do
    analyze_single_repository "${repo_dir}" "${search_regex}"
  done < <(find "${TARGET_DIR}/repos" -mindepth 1 -maxdepth 1 -type d | sort)

  if [[ "${LOCAL_REPO_COUNT}" == "0" ]]; then
    append_line CODE_ANALYSIS_LINES "- No local repositories available for code analysis."
    append_line IMPLEMENTATION_STEPS_LINES "- [ ] Implementar mudanças apenas com base no contexto do Jira (nenhum repositório disponível localmente)."
    append_line VALIDATION_COMMANDS_LINES "- Define validation commands after identifying target repository."
    append_line RISK_LINES "- Risco: sem análise de código local, o plano depende apenas do contexto textual da issue."
  else
    append_line RISK_LINES "- Validar dependências cruzadas entre os repositórios antes de merge."
    append_line RISK_LINES "- Confirmar estratégia de rollout para evitar regressões entre serviços relacionados."
  fi
}

build_repository_section() {
  local clone_execution="not-run"

  case "${CLONE_STATUS}" in
    disabled) clone_execution="disabled by policy" ;;
    no-repositories) clone_execution="no repository links found" ;;
    skipped) clone_execution="skipped by confirmation policy" ;;
    completed) clone_execution="executed" ;;
  esac

  {
    echo "## Repository Materialization"
    echo "- Repository links detected: ${REPO_LINK_COUNT}"
    echo "- Clone policy: ${CLONE_POLICY}"
    echo "- Clone execution: ${clone_execution}"
    if [[ -n "${CLONE_REPORT_LINES}" ]]; then
      printf '%s' "${CLONE_REPORT_LINES}"
    fi
    if [[ -n "${LOCAL_REPO_CONTEXT_LINES}" ]]; then
      echo
      echo "### Local Repository Snapshot"
      printf '%s' "${LOCAL_REPO_CONTEXT_LINES}"
    fi
  }
}

build_ready_plan_section() {
  {
    echo "## Ready-to-Implement Plan"
    echo ""
    echo "### Implementation Steps"
    if [[ -n "${IMPLEMENTATION_STEPS_LINES}" ]]; then
      printf '%s' "${IMPLEMENTATION_STEPS_LINES}"
    else
      echo "- [ ] Define implementation steps after repository analysis."
    fi
    echo
    echo "### Validation Commands"
    if [[ -n "${VALIDATION_COMMANDS_LINES}" ]]; then
      printf '%s' "${VALIDATION_COMMANDS_LINES}"
    else
      echo "- Define validation commands per repository."
    fi
    echo
    echo "### Risks and Dependencies"
    if [[ -n "${RISK_LINES}" ]]; then
      printf '%s' "${RISK_LINES}"
    else
      echo "- Confirm dependencies and rollout path with stakeholders."
    fi
  }
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
log_step "Validating input arguments and execution policies."

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

log_info "Resolved issue input: ${ISSUE} (key candidate: ${ISSUE_KEY_INPUT})"
log_info "Execution profile: mode=${MODE}, workspace=${WORKSPACE_STRATEGY}, clone=${CLONE_POLICY}, confirm=${CONFIRM_POLICY}"

if [[ "${WORKSPACE_STRATEGY}" == "feature-folder" ]]; then
  TARGET_DIR="./${ISSUE_KEY_INPUT}"
  mkdir -p "${TARGET_DIR}/docs"
else
  TARGET_DIR="."
  mkdir -p "${TARGET_DIR}/docs"
fi

log_info "Workspace target directory: ${TARGET_DIR#./}"

ISSUE_JSON=""
if [[ -n "${ISSUE_JSON_FILE}" ]]; then
  log_step "Loading Jira issue from local JSON fixture."
  ISSUE_JSON="$(bash "${JIRA_GET_SCRIPT}" --issue "${ISSUE}" --input-file "${ISSUE_JSON_FILE}")"
else
  log_step "Fetching Jira issue from remote API."
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

log_info "Issue normalized: key=${ISSUE_KEY}, status=${STATUS}, comments=${COMMENTS_COUNT}, repo_links=${REPO_LINK_COUNT}"

PLAN_FILE="${TARGET_DIR}/docs/${ISSUE_KEY}-implementation-plan.md"

log_step "Materializing repositories (when available)."
clone_repositories_if_needed

log_step "Analyzing local repositories to enrich implementation plan."
analyze_cloned_repositories

log_step "Generating implementation plan output."
{
  echo "# ${ISSUE_KEY} - Implementation Plan"
  echo
  summarize_issue_context
  echo
  build_repository_section
  echo
  echo "## Code Analysis"
  if [[ -n "${CODE_ANALYSIS_LINES}" ]]; then
    printf '%s' "${CODE_ANALYSIS_LINES}"
  else
    echo "- No repository analysis available."
  fi
  echo
  build_ready_plan_section
} > "${PLAN_FILE}"

echo "Generated file:"
echo "- ${PLAN_FILE}"

if [[ "${MODE}" == "plan" ]]; then
  log_step "Plan ready for execution (/plan)."
  echo "Next conversational step: run /plan using $(display_path "${PLAN_FILE}")."
fi
