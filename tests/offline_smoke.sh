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
TMP_DIR_ASK=""
cleanup() {
  rm -rf "${TMP_DIR}"
  if [[ -n "${TMP_DIR_ASK}" ]]; then
    rm -rf "${TMP_DIR_ASK}"
  fi
}
trap cleanup EXIT

pushd "${TMP_DIR}" >/dev/null
"${REPO_ROOT}/scripts/jira_bootstrap.sh" \
  --issue "VA-1564" \
  --mode "plan" \
  --workspace "current-folder" \
  --clone "off" \
  --issue-json "${FIXTURE}"
popd >/dev/null

PLAN_FILE="${TMP_DIR}/docs/VA-1564-implementation-plan.md"
[[ -f "${PLAN_FILE}" ]] || { echo "Missing expected file: ${PLAN_FILE}" >&2; exit 1; }

if ! grep -q "# VA-1564 - Implementation Plan" "${PLAN_FILE}"; then
  echo "Plan title check failed" >&2
  exit 1
fi

if ! grep -q "## Issue Essentials" "${PLAN_FILE}"; then
  echo "Issue essentials section missing" >&2
  exit 1
fi

if ! grep -q "## Repository Materialization" "${PLAN_FILE}"; then
  echo "Repository materialization section missing" >&2
  exit 1
fi

if ! grep -q "Clone execution: disabled by policy" "${PLAN_FILE}"; then
  echo "Expected disabled clone execution state was not recorded" >&2
  exit 1
fi

if ! grep -q "## Code Analysis" "${PLAN_FILE}"; then
  echo "Code analysis section missing" >&2
  exit 1
fi

if ! grep -q "## Ready-to-Implement Plan" "${PLAN_FILE}"; then
  echo "Ready-to-implement section missing" >&2
  exit 1
fi

TMP_DIR_ASK="$(mktemp -d)"

pushd "${TMP_DIR_ASK}" >/dev/null
"${REPO_ROOT}/scripts/jira_bootstrap.sh" \
  --issue "VA-1564" \
  --mode "plan" \
  --workspace "current-folder" \
  --clone "ask" \
  --issue-json "${FIXTURE}"
popd >/dev/null

if ! grep -q "Clone execution: skipped by confirmation policy" "${TMP_DIR_ASK}/docs/VA-1564-implementation-plan.md"; then
  echo "Expected plan-mode clone skip state was not recorded" >&2
  exit 1
fi

echo "Offline smoke test passed"
