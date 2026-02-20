#!/usr/bin/env bash
set -euo pipefail

# Build a Windows desktop artifact (Release folder zipped).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
BUILD_MODE="${1:-${BUILD_MODE:-release}}" # debug | profile | release
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/build/windows/artifacts}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"
SKIP_PUB_GET="${SKIP_PUB_GET:-0}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/build_windows_artifact.sh [build_mode]

Arguments:
  build_mode  debug | profile | release (default: release)

Environment variables:
  FLUTTER_CMD  Flutter command path (default: flutter)
  OUTPUT_DIR   Output artifacts folder (default: build/windows/artifacts)
  SKIP_CLEAN   1 to skip flutter clean
  SKIP_PUB_GET 1 to skip flutter pub get

Examples:
  ./scripts/build_windows_artifact.sh release
  OUTPUT_DIR=/d/out ./scripts/build_windows_artifact.sh profile
USAGE
}

is_windows_host() {
  case "${OS:-}" in
    Windows_NT) return 0 ;;
  esac

  case "$(uname -s 2>/dev/null || true)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_python_cmd() {
  if command -v python3 >/dev/null 2>&1; then
    echo "python3"
    return
  fi

  if command -v py >/dev/null 2>&1; then
    echo "py -3"
    return
  fi

  echo ""
}

if [[ "${BUILD_MODE}" == "-h" || "${BUILD_MODE}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${BUILD_MODE}" != "debug" && "${BUILD_MODE}" != "profile" && "${BUILD_MODE}" != "release" ]]; then
  echo "Error: build_mode must be debug | profile | release. Current: ${BUILD_MODE}" >&2
  usage
  exit 1
fi

if ! is_windows_host; then
  echo "Error: Windows artifact can only be built on Windows hosts." >&2
  echo "Tip: run this script in PowerShell/Git Bash on a Windows machine." >&2
  exit 1
fi

if ! command -v "${FLUTTER_CMD}" >/dev/null 2>&1; then
  echo "Error: Flutter command not found: ${FLUTTER_CMD}" >&2
  exit 1
fi

PYTHON_CMD="$(resolve_python_cmd)"
if [[ -z "${PYTHON_CMD}" ]]; then
  echo "Error: python3 (or py -3) is required to create the zip artifact." >&2
  exit 1
fi

MODE_DIR="Release"
if [[ "${BUILD_MODE}" == "debug" ]]; then
  MODE_DIR="Debug"
elif [[ "${BUILD_MODE}" == "profile" ]]; then
  MODE_DIR="Profile"
fi

echo "==> Project root: ${PROJECT_ROOT}"
echo "==> Flutter cmd : ${FLUTTER_CMD}"
echo "==> Build mode  : ${BUILD_MODE}"
echo "==> Output dir  : ${OUTPUT_DIR}"

cd "${PROJECT_ROOT}"

if [[ "${SKIP_CLEAN}" != "1" ]]; then
  echo "==> flutter clean"
  "${FLUTTER_CMD}" clean
fi

if [[ "${SKIP_PUB_GET}" != "1" ]]; then
  echo "==> flutter pub get"
  "${FLUTTER_CMD}" pub get
fi

echo "==> flutter build windows --${BUILD_MODE}"
"${FLUTTER_CMD}" build windows --"${BUILD_MODE}"

RUNNER_DIR="${PROJECT_ROOT}/build/windows/x64/runner/${MODE_DIR}"
if [[ ! -d "${RUNNER_DIR}" ]]; then
  echo "Error: Windows runner folder not found: ${RUNNER_DIR}" >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
APP_SLUG="$(basename "${PROJECT_ROOT}")"
ARTIFACT_DIR="${OUTPUT_DIR}/${TIMESTAMP}-${BUILD_MODE}"
ARCHIVE_PATH="${ARTIFACT_DIR}/${APP_SLUG}-windows-${BUILD_MODE}.zip"

mkdir -p "${ARTIFACT_DIR}"

# shellcheck disable=SC2086
${PYTHON_CMD} - "${RUNNER_DIR}" "${ARCHIVE_PATH}" <<'PY'
import pathlib
import sys
import zipfile

source = pathlib.Path(sys.argv[1]).resolve()
archive = pathlib.Path(sys.argv[2]).resolve()

with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in source.rglob("*"):
        if path.is_file():
            zf.write(path, path.relative_to(source.parent))
PY

echo ""
echo "Done. Windows artifact is ready:"
echo "${ARCHIVE_PATH}"
