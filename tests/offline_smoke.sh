#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURE="${REPO_ROOT}/fixtures/jira/VA-1564.raw.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if [[ ! -f "${FIXTURE}" ]]; then
  echo "Fixture not found: ${FIXTURE}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

pushd "${TMP_DIR}" >/dev/null
"${REPO_ROOT}/scripts/jira_bootstrap.sh" \
  --issue "VA-1564" \
  --mode "plan" \
  --workspace "current-folder" \
  --clone "off" \
  --issue-json "${FIXTURE}"
popd >/dev/null

for file in \
  "${TMP_DIR}/docs/VA-1564-spec.md" \
  "${TMP_DIR}/docs/VA-1564-implementation-plan.md" \
  "${TMP_DIR}/docs/VA-1564-checklist.md" \
  "${TMP_DIR}/docs/VA-1564-jira-summary.md"; do
  [[ -f "${file}" ]] || { echo "Missing expected file: ${file}" >&2; exit 1; }
done

if ! grep -q "# VA-1564 - Jira Summary" "${TMP_DIR}/docs/VA-1564-jira-summary.md"; then
  echo "Summary file content check failed" >&2
  exit 1
fi

echo "Offline smoke test passed"
