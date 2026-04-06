#!/usr/bin/env bash
set -euo pipefail

# Build a Linux desktop artifact (bundle tar.gz).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
BUILD_MODE="${1:-${BUILD_MODE:-release}}" # debug | profile | release
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/build/linux/artifacts}"
ARTIFACT_NAME="${ARTIFACT_NAME:-书享阅读 Next}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"
SKIP_PUB_GET="${SKIP_PUB_GET:-0}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/build_linux_artifact.sh [build_mode]

Arguments:
  build_mode  debug | profile | release (default: release)

Environment variables:
  FLUTTER_CMD  Flutter command path (default: flutter)
  OUTPUT_DIR   Output artifacts folder (default: build/linux/artifacts)
  ARTIFACT_NAME Final artifact display name prefix (default: 书享阅读 Next)
  BUILD_NAME   Override Flutter --build-name
  BUILD_NUMBER Override Flutter --build-number
  SKIP_CLEAN   1 to skip flutter clean
  SKIP_PUB_GET 1 to skip flutter pub get

Examples:
  ./scripts/build_linux_artifact.sh release
  OUTPUT_DIR=/tmp/out ./scripts/build_linux_artifact.sh profile
USAGE
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

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Error: Linux artifact can only be built on Linux hosts." >&2
  exit 1
fi

if ! command -v "${FLUTTER_CMD}" >/dev/null 2>&1; then
  echo "Error: Flutter command not found: ${FLUTTER_CMD}" >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "Error: tar command is required but not found." >&2
  exit 1
fi

echo "==> Project root: ${PROJECT_ROOT}"
echo "==> Flutter cmd : ${FLUTTER_CMD}"
echo "==> Build mode  : ${BUILD_MODE}"
echo "==> Build name  : ${BUILD_NAME:-pubspec default}"
echo "==> Build number: ${BUILD_NUMBER:-pubspec default}"
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

echo "==> flutter build linux --${BUILD_MODE}"
CMD=("${FLUTTER_CMD}" build linux --"${BUILD_MODE}")
if [[ -n "${BUILD_NAME}" ]]; then
  CMD+=(--build-name="${BUILD_NAME}")
fi
if [[ -n "${BUILD_NUMBER}" ]]; then
  CMD+=(--build-number="${BUILD_NUMBER}")
fi
"${CMD[@]}"

BUNDLE_DIR="${PROJECT_ROOT}/build/linux/x64/${BUILD_MODE}/bundle"
if [[ ! -d "${BUNDLE_DIR}" ]]; then
  echo "Error: Linux bundle not found: ${BUNDLE_DIR}" >&2
  exit 1
fi

artifact_base_name() {
  local base="${ARTIFACT_NAME}"
  if [[ -n "${BUILD_NAME}" ]]; then
    base="${base} v${BUILD_NAME}"
  fi
  echo "${base}"
}

artifact_mode_suffix() {
  if [[ "${BUILD_MODE}" == "release" ]]; then
    echo ""
  else
    echo " ${BUILD_MODE}"
  fi
}

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${OUTPUT_DIR}/${TIMESTAMP}-${BUILD_MODE}"
ARCHIVE_PATH="${ARTIFACT_DIR}/$(artifact_base_name) Linux$(artifact_mode_suffix).tar.gz"

mkdir -p "${ARTIFACT_DIR}"

tar -czf "${ARCHIVE_PATH}" -C "$(dirname "${BUNDLE_DIR}")" "$(basename "${BUNDLE_DIR}")"

echo ""
echo "Done. Linux artifact is ready:"
echo "${ARCHIVE_PATH}"
