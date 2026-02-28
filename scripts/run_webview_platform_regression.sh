#!/usr/bin/env bash
set -euo pipefail

# One-command entry to run real platform regression for webView:true.
# Delegates device discovery + execution to tool/run_webview_platform_regression.dart.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

args=("$@")

if [[ -n "${FLUTTER_CMD:-}" ]]; then
  args+=("--flutter=${FLUTTER_CMD}")
fi
if [[ -n "${WEBVIEW_REGRESSION_PLATFORMS:-}" ]]; then
  args+=("--platforms=${WEBVIEW_REGRESSION_PLATFORMS}")
fi
if [[ -n "${WEBVIEW_REGRESSION_LOG_DIR:-}" ]]; then
  args+=("--log-dir=${WEBVIEW_REGRESSION_LOG_DIR}")
fi
if [[ -n "${WEBVIEW_REGRESSION_TEST_TARGET:-}" ]]; then
  args+=("--test-target=${WEBVIEW_REGRESSION_TEST_TARGET}")
fi

dart run tool/run_webview_platform_regression.dart "${args[@]}"
