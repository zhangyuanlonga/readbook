#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

args=("$@")

if [[ -n "${FLUTTER_CMD:-}" ]]; then
  args+=("--flutter=${FLUTTER_CMD}")
fi

dart run tool/run_architecture_green_suite.dart "${args[@]}"
