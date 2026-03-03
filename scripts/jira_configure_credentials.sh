#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ENV="${SKILL_ROOT}/.env.local"

JIRA_BASE_URL_VALUE=""
JIRA_EMAIL_VALUE=""
JIRA_API_TOKEN_VALUE=""

usage() {
  cat <<'EOF'
Usage:
  jira_configure_credentials.sh
  jira_configure_credentials.sh --base-url <url> --email <email> --token <token>

Writes Jira credentials to:
  <skill-root>/.env.local
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      JIRA_BASE_URL_VALUE="${2:-}"
      shift 2
      ;;
    --email)
      JIRA_EMAIL_VALUE="${2:-}"
      shift 2
      ;;
    --token)
      JIRA_API_TOKEN_VALUE="${2:-}"
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

if [[ -z "${JIRA_BASE_URL_VALUE}" ]]; then
  read -r -p "Jira base URL (e.g. https://company.atlassian.net): " JIRA_BASE_URL_VALUE
fi

if [[ -z "${JIRA_EMAIL_VALUE}" ]]; then
  read -r -p "Jira email: " JIRA_EMAIL_VALUE
fi

if [[ -z "${JIRA_API_TOKEN_VALUE}" ]]; then
  read -r -s -p "Jira API token: " JIRA_API_TOKEN_VALUE
  echo
fi

if [[ -z "${JIRA_BASE_URL_VALUE}" || -z "${JIRA_EMAIL_VALUE}" || -z "${JIRA_API_TOKEN_VALUE}" ]]; then
  echo "All credentials are required." >&2
  exit 1
fi

cat > "${TARGET_ENV}" <<EOF
JIRA_BASE_URL="${JIRA_BASE_URL_VALUE}"
JIRA_EMAIL="${JIRA_EMAIL_VALUE}"
JIRA_API_TOKEN="${JIRA_API_TOKEN_VALUE}"
EOF

chmod 600 "${TARGET_ENV}"

echo "Credentials written to ${TARGET_ENV}"
