#!/usr/bin/env bash
set -euo pipefail

# Build Android artifacts for this Flutter project.
# Supports APK / AAB and copies outputs into a timestamped artifacts folder.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
TARGET="${1:-${TARGET:-apk}}"            # apk | appbundle | both
BUILD_MODE="${2:-${BUILD_MODE:-release}}" # debug | profile | release
SPLIT_PER_ABI="${SPLIT_PER_ABI:-0}"      # 1 to pass --split-per-abi for APK
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/build/android/artifacts}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"
SKIP_PUB_GET="${SKIP_PUB_GET:-0}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/build_android_artifacts.sh [target] [build_mode]

Arguments:
  target      apk | appbundle | both (default: apk)
  build_mode  debug | profile | release (default: release)

Environment variables:
  FLUTTER_CMD   Flutter command path (default: flutter)
  SPLIT_PER_ABI 1 to add --split-per-abi for APK (default: 0)
  OUTPUT_DIR    Output artifacts folder (default: build/android/artifacts)
  BUILD_NAME    Override Flutter --build-name
  BUILD_NUMBER  Override Flutter --build-number
  SKIP_CLEAN    1 to skip flutter clean
  SKIP_PUB_GET  1 to skip flutter pub get

Examples:
  ./scripts/build_android_artifacts.sh apk release
  SPLIT_PER_ABI=1 ./scripts/build_android_artifacts.sh apk release
  ./scripts/build_android_artifacts.sh both release
USAGE
}

if [[ "${TARGET}" == "-h" || "${TARGET}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${TARGET}" != "apk" && "${TARGET}" != "appbundle" && "${TARGET}" != "both" ]]; then
  echo "Error: target must be apk | appbundle | both. Current: ${TARGET}" >&2
  usage
  exit 1
fi

if [[ "${BUILD_MODE}" != "debug" && "${BUILD_MODE}" != "profile" && "${BUILD_MODE}" != "release" ]]; then
  echo "Error: build_mode must be debug | profile | release. Current: ${BUILD_MODE}" >&2
  usage
  exit 1
fi

if ! command -v "${FLUTTER_CMD}" >/dev/null 2>&1; then
  echo "Error: Flutter command not found: ${FLUTTER_CMD}" >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
APP_SLUG="$(basename "${PROJECT_ROOT}")"
SESSION_DIR="${OUTPUT_DIR}/${TIMESTAMP}-${BUILD_MODE}"
mkdir -p "${SESSION_DIR}"

echo "==> Project root: ${PROJECT_ROOT}"
echo "==> Flutter cmd : ${FLUTTER_CMD}"
echo "==> Target      : ${TARGET}"
echo "==> Build mode  : ${BUILD_MODE}"
echo "==> Build name  : ${BUILD_NAME:-pubspec default}"
echo "==> Build number: ${BUILD_NUMBER:-pubspec default}"
echo "==> Output dir  : ${SESSION_DIR}"

cd "${PROJECT_ROOT}"

if [[ "${SKIP_CLEAN}" != "1" ]]; then
  echo "==> flutter clean"
  "${FLUTTER_CMD}" clean
fi

if [[ "${SKIP_PUB_GET}" != "1" ]]; then
  echo "==> flutter pub get"
  "${FLUTTER_CMD}" pub get
fi

build_apk() {
  echo "==> flutter build apk --${BUILD_MODE}${SPLIT_PER_ABI:+}"
  local cmd=("${FLUTTER_CMD}" build apk "--${BUILD_MODE}")
  if [[ "${SPLIT_PER_ABI}" == "1" ]]; then
    cmd+=(--split-per-abi)
  fi
  if [[ -n "${BUILD_NAME}" ]]; then
    cmd+=(--build-name="${BUILD_NAME}")
  fi
  if [[ -n "${BUILD_NUMBER}" ]]; then
    cmd+=(--build-number="${BUILD_NUMBER}")
  fi
  "${cmd[@]}"

  local apk_dir="${PROJECT_ROOT}/build/app/outputs/flutter-apk"
  local copied=0

  if [[ "${SPLIT_PER_ABI}" == "1" ]]; then
    while IFS= read -r -d '' file; do
      local base
      base="$(basename "${file}")"
      cp "${file}" "${SESSION_DIR}/${APP_SLUG}-${base}"
      copied=1
    done < <(find "${apk_dir}" -maxdepth 1 -type f -name "app-*-${BUILD_MODE}.apk" -print0)
  else
    local apk_file="${apk_dir}/app-${BUILD_MODE}.apk"
    if [[ -f "${apk_file}" ]]; then
      cp "${apk_file}" "${SESSION_DIR}/${APP_SLUG}-app-${BUILD_MODE}.apk"
      copied=1
    fi
  fi

  if [[ "${copied}" -ne 1 ]]; then
    echo "Error: APK output not found under ${apk_dir}" >&2
    exit 1
  fi
}

build_appbundle() {
  echo "==> flutter build appbundle --${BUILD_MODE}"
  local cmd=("${FLUTTER_CMD}" build appbundle "--${BUILD_MODE}")
  if [[ -n "${BUILD_NAME}" ]]; then
    cmd+=(--build-name="${BUILD_NAME}")
  fi
  if [[ -n "${BUILD_NUMBER}" ]]; then
    cmd+=(--build-number="${BUILD_NUMBER}")
  fi
  "${cmd[@]}"

  local aab_file="${PROJECT_ROOT}/build/app/outputs/bundle/${BUILD_MODE}/app-${BUILD_MODE}.aab"
  if [[ ! -f "${aab_file}" ]]; then
    echo "Error: AAB output not found: ${aab_file}" >&2
    exit 1
  fi

  cp "${aab_file}" "${SESSION_DIR}/${APP_SLUG}-app-${BUILD_MODE}.aab"
}

if [[ "${TARGET}" == "apk" || "${TARGET}" == "both" ]]; then
  build_apk
fi

if [[ "${TARGET}" == "appbundle" || "${TARGET}" == "both" ]]; then
  build_appbundle
fi

echo ""
echo "Done. Android artifacts are ready:"
echo "${SESSION_DIR}"
ls -1 "${SESSION_DIR}" | sed 's/^/  - /'
