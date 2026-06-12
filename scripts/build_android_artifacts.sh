#!/usr/bin/env bash
set -euo pipefail

# Build Android artifacts for this Flutter project.
# Supports APK / AAB and copies outputs into a timestamped artifacts folder.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
ANDROID_TARGET="${ANDROID_TARGET:-}"
TARGET="${1:-${TARGET:-${ANDROID_TARGET:-apk}}}" # apk | appbundle/aab | both
BUILD_MODE="${2:-${BUILD_MODE:-release}}" # debug | profile | release
SPLIT_PER_ABI="${SPLIT_PER_ABI:-}"       # legacy alias for APK_PROFILE=split
APK_PROFILE="${APK_PROFILE:-}"           # arm64 | split | universal
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/artifacts/android}"
ARTIFACT_NAME="${ARTIFACT_NAME:-Selune}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL:-}"
APPREAD_READER_GATEWAY_BASE_URL="${APPREAD_READER_GATEWAY_BASE_URL:-}"
APPREAD_APP_NAME="${APPREAD_APP_NAME:-}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"
SKIP_PUB_GET="${SKIP_PUB_GET:-0}"

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  echo "${value}"
}

validate_version_overrides() {
  BUILD_NAME="$(trim_whitespace "${BUILD_NAME}")"
  BUILD_NUMBER="$(trim_whitespace "${BUILD_NUMBER}")"

  if [[ -n "${BUILD_NAME}" && ! "${BUILD_NAME}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "Error: BUILD_NAME must look like 1.1 or 1.1.0. Current: ${BUILD_NAME}" >&2
    exit 1
  fi

  if [[ -n "${BUILD_NUMBER}" && ! "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
    echo "Error: BUILD_NUMBER must be an integer build code like 26041801. Current: ${BUILD_NUMBER}" >&2
    exit 1
  fi
}

append_dart_defines() {
  local array_name="$1"
  local define_value

  if [[ -n "${APPREAD_API_BASE_URL}" ]]; then
    printf -v define_value '%q' "--dart-define=APPREAD_API_BASE_URL=${APPREAD_API_BASE_URL}"
    eval "${array_name}+=(${define_value})"
  fi
  if [[ -n "${APPREAD_READER_GATEWAY_BASE_URL}" ]]; then
    printf -v define_value '%q' "--dart-define=APPREAD_READER_GATEWAY_BASE_URL=${APPREAD_READER_GATEWAY_BASE_URL}"
    eval "${array_name}+=(${define_value})"
  fi
  if [[ -n "${APPREAD_APP_NAME}" ]]; then
    printf -v define_value '%q' "--dart-define=APPREAD_APP_NAME=${APPREAD_APP_NAME}"
    eval "${array_name}+=(${define_value})"
  fi
}

usage() {
  cat <<USAGE
Usage:
  ./scripts/build_android_artifacts.sh [target] [build_mode]

Arguments:
  target      apk | appbundle/aab | both (default: apk)
  build_mode  debug | profile | release (default: release)

Environment variables:
  FLUTTER_CMD   Flutter command path (default: flutter)
  ANDROID_TARGET apk | appbundle/aab | both (default: apk, alias for target argument)
  APK_PROFILE   APK output profile: arm64 | split | universal (default: arm64)
                arm64 uses --target-platform android-arm64 to preserve the raw versionCode.
                split uses --split-per-abi, which lets Android append ABI-specific versionCode offsets.
  SPLIT_PER_ABI Legacy alias. Set to 1 for APK_PROFILE=split
  OUTPUT_DIR    Output artifacts folder (default: artifacts/android)
  ARTIFACT_NAME Final artifact display name prefix (default: Selune)
  BUILD_NAME    Override Flutter --build-name
  BUILD_NUMBER  Override Flutter --build-number
  APPREAD_API_BASE_URL Optional backend API base URL override
  APPREAD_READER_GATEWAY_BASE_URL Optional reader gateway base URL override
  APPREAD_APP_NAME Optional app identifier override
  SKIP_CLEAN    1 to skip flutter clean
  SKIP_PUB_GET  1 to skip flutter pub get

Examples:
  ./scripts/build_android_artifacts.sh apk release
  APK_PROFILE=split ./scripts/build_android_artifacts.sh apk release
  APK_PROFILE=universal ./scripts/build_android_artifacts.sh apk release
  ./scripts/build_android_artifacts.sh both release
  BUILD_NAME=1.1.0 BUILD_NUMBER=26041801 ./scripts/build_android_artifacts.sh apk release
USAGE
}

if [[ "${TARGET}" == "-h" || "${TARGET}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${TARGET}" == "aab" ]]; then
  TARGET="appbundle"
fi

if [[ "${TARGET}" != "apk" && "${TARGET}" != "appbundle" && "${TARGET}" != "both" ]]; then
  echo "Error: target must be apk | appbundle/aab | both. Current: ${TARGET}" >&2
  usage
  exit 1
fi

if [[ "${BUILD_MODE}" != "debug" && "${BUILD_MODE}" != "profile" && "${BUILD_MODE}" != "release" ]]; then
  echo "Error: build_mode must be debug | profile | release. Current: ${BUILD_MODE}" >&2
  usage
  exit 1
fi

if [[ -z "${APK_PROFILE}" ]]; then
  if [[ "${SPLIT_PER_ABI}" == "1" ]]; then
    APK_PROFILE="split"
  else
    APK_PROFILE="arm64"
  fi
fi

if [[ "${APK_PROFILE}" != "arm64" && "${APK_PROFILE}" != "split" && "${APK_PROFILE}" != "universal" ]]; then
  echo "Error: APK_PROFILE must be arm64 | split | universal. Current: ${APK_PROFILE}" >&2
  usage
  exit 1
fi

if ! command -v "${FLUTTER_CMD}" >/dev/null 2>&1; then
  echo "Error: Flutter command not found: ${FLUTTER_CMD}" >&2
  exit 1
fi

validate_version_overrides

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SESSION_DIR="${OUTPUT_DIR}/${TIMESTAMP}-${BUILD_MODE}"
mkdir -p "${SESSION_DIR}"

artifact_base_name() {
  echo "${ARTIFACT_NAME}"
}

artifact_version_suffix() {
  local version_label=""
  if [[ -n "${BUILD_NAME}" && -n "${BUILD_NUMBER}" ]]; then
    version_label="${BUILD_NAME}-${BUILD_NUMBER}"
  elif [[ -n "${BUILD_NAME}" ]]; then
    version_label="${BUILD_NAME}"
  elif [[ -n "${BUILD_NUMBER}" ]]; then
    version_label="${BUILD_NUMBER}"
  fi

  if [[ -n "${version_label}" ]]; then
    echo "-${version_label}"
  else
    echo ""
  fi
}

artifact_mode_suffix() {
  if [[ "${BUILD_MODE}" == "release" ]]; then
    echo ""
  else
    echo "-${BUILD_MODE}"
  fi
}

android_apk_name() {
  local abi_label="$1"
  local name
  name="$(artifact_base_name)-Android"
  if [[ -n "${abi_label}" ]]; then
    name="${name}-${abi_label}"
  fi
  name="${name}$(artifact_version_suffix)$(artifact_mode_suffix).apk"
  echo "${name}"
}

android_aab_name() {
  local name
  name="$(artifact_base_name)-Android$(artifact_version_suffix)$(artifact_mode_suffix).aab"
  echo "${name}"
}

echo "==> Project root: ${PROJECT_ROOT}"
echo "==> Flutter cmd : ${FLUTTER_CMD}"
echo "==> Target      : ${TARGET}"
echo "==> Build mode  : ${BUILD_MODE}"
echo "==> APK profile : ${APK_PROFILE}"
echo "==> Build name  : ${BUILD_NAME:-pubspec default}"
echo "==> Build number: ${BUILD_NUMBER:-pubspec default}"
echo "==> API base    : ${APPREAD_API_BASE_URL:-dart default}"
echo "==> Reader API  : ${APPREAD_READER_GATEWAY_BASE_URL:-dart default}"
echo "==> App name    : ${APPREAD_APP_NAME:-dart default}"
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

# flutter clean removes build-rooted artifact folders used by the unified
# packaging flow, so restore this session directory before building.
mkdir -p "${SESSION_DIR}"

build_apk() {
  local cmd=("${FLUTTER_CMD}" build apk "--${BUILD_MODE}")
  if [[ "${APK_PROFILE}" == "split" ]]; then
    echo "==> flutter build apk --${BUILD_MODE} --split-per-abi"
    cmd+=(--split-per-abi)
  elif [[ "${APK_PROFILE}" == "arm64" ]]; then
    echo "==> flutter build apk --${BUILD_MODE} --target-platform android-arm64"
    cmd+=(--target-platform android-arm64)
  else
    echo "==> flutter build apk --${BUILD_MODE}"
  fi
  if [[ -n "${BUILD_NAME}" ]]; then
    cmd+=(--build-name="${BUILD_NAME}")
  fi
  if [[ -n "${BUILD_NUMBER}" ]]; then
    cmd+=(--build-number="${BUILD_NUMBER}")
  fi
  append_dart_defines cmd
  "${cmd[@]}"

  local apk_dir="${PROJECT_ROOT}/build/app/outputs/flutter-apk"
  local copied=0

  if [[ "${APK_PROFILE}" == "split" ]]; then
    while IFS= read -r -d '' file; do
      local base
      base="$(basename "${file}")"
      local abi_label=""
      case "${base}" in
        *arm64-v8a*) abi_label="arm64-v8a" ;;
        *armeabi-v7a*) abi_label="armeabi-v7a" ;;
        *x86_64*) abi_label="x86_64" ;;
      esac
      cp "${file}" "${SESSION_DIR}/$(android_apk_name "${abi_label}")"
      copied=1
    done < <(find "${apk_dir}" -maxdepth 1 -type f -name "app-*-${BUILD_MODE}.apk" -print0)
  elif [[ "${APK_PROFILE}" == "arm64" ]]; then
    local apk_file="${apk_dir}/app-${BUILD_MODE}.apk"
    if [[ -f "${apk_file}" ]]; then
      cp "${apk_file}" "${SESSION_DIR}/$(android_apk_name "arm64-v8a")"
      copied=1
    fi
  else
    local apk_file="${apk_dir}/app-${BUILD_MODE}.apk"
    if [[ -f "${apk_file}" ]]; then
      cp "${apk_file}" "${SESSION_DIR}/$(android_apk_name "")"
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
  append_dart_defines cmd
  "${cmd[@]}"

  local aab_file="${PROJECT_ROOT}/build/app/outputs/bundle/${BUILD_MODE}/app-${BUILD_MODE}.aab"
  if [[ ! -f "${aab_file}" ]]; then
    echo "Error: AAB output not found: ${aab_file}" >&2
    exit 1
  fi

  cp "${aab_file}" "${SESSION_DIR}/$(android_aab_name)"
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
