#!/usr/bin/env bash

set -euo pipefail

INSTALLER="${HOME}/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py"
SKILL_URL="${1:-https://github.com/brenonovelli/codex-skill-jira}"
SKILL_NAME="${2:-jira}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 1
fi

if [[ ! -f "${INSTALLER}" ]]; then
  echo "Installer not found: ${INSTALLER}" >&2
  echo "Make sure Codex is installed and skill-installer is available." >&2
  exit 1
fi

python3 "${INSTALLER}" --url "${SKILL_URL}" --path . --name "${SKILL_NAME}"

echo "Skill '${SKILL_NAME}' installed from ${SKILL_URL}."
echo "Restart Codex to load the updated skill."
