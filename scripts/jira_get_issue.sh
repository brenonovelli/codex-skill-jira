#!/usr/bin/env bash

set -euo pipefail

ISSUE=""
OUTPUT_FILE=""
INPUT_FILE=""
ENV_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  jira_get_issue.sh --issue <KEY|URL> [--output <file>] [--input-file <jira-issue.json>] [--env-file <path>]

Environment (required when --input-file is not used):
  JIRA_BASE_URL   Ex: https://company.atlassian.net
  JIRA_EMAIL      Atlassian account email
  JIRA_API_TOKEN  Atlassian API token

Credential loading order:
  1) --env-file
  2) <skill-root>/.env
  3) <skill-root>/.env.local
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      ISSUE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --input-file)
      INPUT_FILE="${2:-}"
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
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

load_env_defaults

if [[ -z "${ISSUE}" ]]; then
  echo "Missing --issue" >&2
  usage >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not found in PATH." >&2
  exit 1
fi

if [[ "${ISSUE}" =~ /browse/([A-Za-z0-9]+-[0-9]+) ]]; then
  ISSUE_KEY="${BASH_REMATCH[1]}"
else
  ISSUE_KEY="${ISSUE}"
fi

RAW_JSON=""
if [[ -n "${INPUT_FILE}" ]]; then
  if [[ ! -f "${INPUT_FILE}" ]]; then
    echo "Input file not found: ${INPUT_FILE}" >&2
    exit 1
  fi
  RAW_JSON="$(cat "${INPUT_FILE}")"
else
  : "${JIRA_BASE_URL:?JIRA_BASE_URL is required when --input-file is not used}"
  : "${JIRA_EMAIL:?JIRA_EMAIL is required when --input-file is not used}"
  : "${JIRA_API_TOKEN:?JIRA_API_TOKEN is required when --input-file is not used}"

  API_URL="${JIRA_BASE_URL%/}/rest/api/3/issue/${ISSUE_KEY}?expand=renderedFields,comment"

  RAW_JSON="$(curl -fsS \
    -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    -H "Accept: application/json" \
    "${API_URL}")"
fi

NORMALIZED_JSON="$(printf '%s' "${RAW_JSON}" | jq -c '
  def flat:
    if . == null then ""
    elif type == "string" then .
    elif type == "array" then map(flat) | join("\n")
    elif type == "object" then ((.text // "") + ((.content // []) | flat))
    else ""
    end;
  def clean:
    gsub("\r"; "")
    | gsub("[ \t]+\n"; "\n")
    | gsub("\n{3,}"; "\n\n")
    | sub("^\n+"; "")
    | sub("\n+$"; "");
  def find_urls:
    [scan("https?://[^\\s<>\")\\]]+")];
  def repo_only:
    map(select(test("(github\\.com|gitlab\\.com|bitbucket\\.org)")));

  {
    key: (.key // "'"${ISSUE_KEY}"'"),
    issue_url: (.self // ""),
    summary: (.fields.summary // ""),
    status: (.fields.status.name // ""),
    assignee: (.fields.assignee.displayName // "Unassigned"),
    reporter: (.fields.reporter.displayName // ""),
    description: ((.fields.description | flat) | clean),
    comments: [(.fields.comment.comments[]?.body | flat | clean) | select(length > 0)],
    links: (
      (
        [(.fields.issuelinks[]?.outwardIssue?.self // empty),
         (.fields.issuelinks[]?.inwardIssue?.self // empty)]
        +
        ((.fields.description | flat | find_urls))
        +
        [(.fields.comment.comments[]?.body | flat | find_urls[]) ]
      )
      | map(select(length > 0))
      | unique
    )
  }
  | .repo_urls = (.links | repo_only | unique)
')"

if [[ -n "${OUTPUT_FILE}" ]]; then
  mkdir -p "$(dirname "${OUTPUT_FILE}")"
  printf '%s\n' "${NORMALIZED_JSON}" > "${OUTPUT_FILE}"
else
  printf '%s\n' "${NORMALIZED_JSON}"
fi
