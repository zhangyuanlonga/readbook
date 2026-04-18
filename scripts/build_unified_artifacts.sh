#!/usr/bin/env bash
set -euo pipefail

# Build and collect Flutter artifacts for multiple platforms into one folder.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
PLATFORMS_INPUT="${1:-${PLATFORMS:-auto}}"
BUILD_MODE="${2:-${BUILD_MODE:-release}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${PROJECT_ROOT}/build/unified_artifacts}"
ANDROID_TARGET="${ANDROID_TARGET:-apk}"  # apk | appbundle | both
ANDROID_APK_PROFILE="${ANDROID_APK_PROFILE:-arm64}" # arm64 | split | universal
SPLIT_PER_ABI="${SPLIT_PER_ABI:-}"       # legacy alias for ANDROID_APK_PROFILE=split
APP_NAME="${APP_NAME:-Runner}"           # iOS APP_NAME
MACOS_APP_NAME="${MACOS_APP_NAME:-}"     # macOS APP_NAME
ARTIFACT_NAME="${ARTIFACT_NAME:-书享阅读 Next}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL:-}"
APPREAD_APP_NAME="${APPREAD_APP_NAME:-}"
VERSION_PROMPT="${VERSION_PROMPT:-1}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"
SKIP_PUB_GET="${SKIP_PUB_GET:-0}"
SKIP_POD_INSTALL="${SKIP_POD_INSTALL:-0}"
ALLOW_PARTIAL="${ALLOW_PARTIAL:-1}"      # 1: continue when a platform fails
KEEP_STAGING="${KEEP_STAGING:-0}"

PLATFORMS=()
SUCCESS_PLATFORMS=()
FAILED_PLATFORMS=()
SKIPPED_PLATFORMS=()

usage() {
  cat <<USAGE
Usage:
  ./scripts/build_unified_artifacts.sh [platforms] [build_mode]

Arguments:
  platforms   auto | android,ios,macos,linux,windows (default: auto)
  build_mode  debug | profile | release (default: release)

Environment variables:
  FLUTTER_CMD      Flutter command path (default: flutter)
  OUTPUT_ROOT      Unified output root (default: build/unified_artifacts)
  ANDROID_TARGET   apk | appbundle | both (default: apk)
  ANDROID_APK_PROFILE Android APK profile: arm64 | split | universal (default: arm64)
  SPLIT_PER_ABI    Legacy alias. Set to 1 for ANDROID_APK_PROFILE=split
  APP_NAME         iOS app bundle name (default: Runner)
  MACOS_APP_NAME   Optional macOS .app name without .app
  BUILD_NAME       Override Flutter --build-name
  BUILD_NUMBER     Override Flutter --build-number
  VERSION_PROMPT   1 to ask interactively before build when TTY is available
  SKIP_CLEAN       1 to skip flutter clean
  SKIP_PUB_GET     1 to skip flutter pub get
  SKIP_POD_INSTALL 1 to skip pod install for iOS/macOS
  ALLOW_PARTIAL    1 to continue when one platform fails (default: 1)
  KEEP_STAGING     1 to keep temporary staging files

Examples:
  ./scripts/build_unified_artifacts.sh
  ./scripts/build_unified_artifacts.sh android,ios,macos release
  ANDROID_APK_PROFILE=split ./scripts/build_unified_artifacts.sh android release
  ANDROID_TARGET=both ANDROID_APK_PROFILE=universal ./scripts/build_unified_artifacts.sh android release
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

host_os() {
  if is_windows_host; then
    echo "windows"
    return
  fi

  case "$(uname -s 2>/dev/null || true)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

default_platforms_for_host() {
  case "$(host_os)" in
    darwin) echo "android ios macos" ;;
    linux) echo "android linux" ;;
    windows) echo "android windows" ;;
    *) echo "android" ;;
  esac
}

is_platform_supported_on_host() {
  local platform="$1"

  case "${platform}" in
    android) return 0 ;;
    ios|macos) [[ "$(host_os)" == "darwin" ]] ;;
    linux) [[ "$(host_os)" == "linux" ]] ;;
    windows) [[ "$(host_os)" == "windows" ]] ;;
    *) return 1 ;;
  esac
}

array_contains() {
  local needle="$1"
  shift

  local item
  for item in "$@"; do
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done

  return 1
}

read_pubspec_version() {
  local version_line
  version_line="$(grep -E '^version:' "${PROJECT_ROOT}/pubspec.yaml" | head -n 1 | sed 's/^version:[[:space:]]*//')"
  echo "${version_line}"
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  echo "${value}"
}

resolve_version_overrides() {
  local pubspec_version current_name current_number input

  pubspec_version="$(read_pubspec_version)"
  current_name="${pubspec_version%%+*}"
  current_number=""
  if [[ "${pubspec_version}" == *"+"* ]]; then
    current_number="${pubspec_version##*+}"
  fi

  if [[ -z "${BUILD_NAME}" ]]; then
    BUILD_NAME="${current_name}"
  fi
  if [[ -z "${BUILD_NUMBER}" ]]; then
    BUILD_NUMBER="${current_number}"
  fi

  if [[ "${VERSION_PROMPT}" == "1" && -t 0 ]]; then
    echo "==> Current pubspec version: ${pubspec_version:-unknown}"
    read -r -p "==> Confirm build name [${BUILD_NAME:-none}]: " input
    input="$(trim_whitespace "${input}")"
    if [[ -n "${input}" ]]; then
      BUILD_NAME="${input}"
    fi
    read -r -p "==> Confirm build number [${BUILD_NUMBER:-none}]: " input
    input="$(trim_whitespace "${input}")"
    if [[ -n "${input}" ]]; then
      BUILD_NUMBER="${input}"
    fi
  fi

  BUILD_NAME="$(trim_whitespace "${BUILD_NAME}")"
  BUILD_NUMBER="$(trim_whitespace "${BUILD_NUMBER}")"

  if [[ -n "${BUILD_NAME}" && ! "${BUILD_NAME}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "Error: BUILD_NAME must look like 1.1 or 1.1.0." >&2
    exit 1
  fi
  if [[ -n "${BUILD_NUMBER}" && ! "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
    echo "Error: BUILD_NUMBER must be an integer." >&2
    exit 1
  fi
}

normalize_platforms() {
  local input="$1"
  local raw
  local token
  local -a tokens=()

  PLATFORMS=()

  if [[ "${input}" == "auto" ]]; then
    raw="$(default_platforms_for_host)"
  else
    raw="${input//,/ }"
  fi

  for token in ${raw}; do
    tokens+=("${token}")
  done

  if [[ "${#tokens[@]}" -eq 0 ]]; then
    echo "Error: no platforms resolved from input '${input}'." >&2
    return 1
  fi

  for token in "${tokens[@]}"; do
    case "${token}" in
      android|ios|macos|linux|windows) ;;
      *)
        echo "Error: unsupported platform '${token}'." >&2
        usage >&2
        return 1
        ;;
    esac

    if ! array_contains "${token}" "${PLATFORMS[@]-}"; then
      PLATFORMS+=("${token}")
    fi
  done

  return 0
}

record_failure() {
  local platform="$1"
  FAILED_PLATFORMS+=("${platform}")
  if [[ "${ALLOW_PARTIAL}" != "1" ]]; then
    echo "Error: ${platform} build failed and ALLOW_PARTIAL=0." >&2
    exit 1
  fi
}

copy_artifacts_from_staging() {
  local platform="$1"
  local source_dir="$2"
  local has_file=0

  while IFS= read -r -d '' file; do
    has_file=1
    local base dest unique_dest idx
    base="$(basename "${file}")"
    dest="${SESSION_DIR}/${base}"
    unique_dest="${dest}"
    idx=1

    while [[ -e "${unique_dest}" ]]; do
      unique_dest="${dest}.${idx}"
      idx=$((idx + 1))
    done

    cp "${file}" "${unique_dest}"
    printf '%s\n' "${platform}: $(basename "${unique_dest}")" >> "${MANIFEST_FILE}"
  done < <(find "${source_dir}" -type f ! -name '.DS_Store' -print0)

  if [[ "${has_file}" -eq 0 ]]; then
    echo "Warning: ${platform} has no artifact files in ${source_dir}" >&2
    return 1
  fi

  return 0
}

run_platform_build() {
  local platform="$1"
  shift

  local stage_dir="${STAGING_ROOT}/${platform}"
  mkdir -p "${stage_dir}"

  if ! is_platform_supported_on_host "${platform}"; then
    echo "==> [${platform}] skip (unsupported host: $(host_os))"
    SKIPPED_PLATFORMS+=("${platform}")
    if [[ "${ALLOW_PARTIAL}" != "1" ]]; then
      echo "Error: ${platform} is unsupported on this host and ALLOW_PARTIAL=0." >&2
      exit 1
    fi
    return 0
  fi

  echo "==> [${platform}] build start"
  if "$@"; then
    if copy_artifacts_from_staging "${platform}" "${stage_dir}"; then
      SUCCESS_PLATFORMS+=("${platform}")
      echo "==> [${platform}] done"
    else
      echo "==> [${platform}] build finished but no artifacts copied"
      record_failure "${platform}"
    fi
  else
    echo "==> [${platform}] build failed"
    record_failure "${platform}"
  fi
}

if [[ "${PLATFORMS_INPUT}" == "-h" || "${PLATFORMS_INPUT}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${BUILD_MODE}" != "debug" && "${BUILD_MODE}" != "profile" && "${BUILD_MODE}" != "release" ]]; then
  echo "Error: build_mode must be debug | profile | release. Current: ${BUILD_MODE}" >&2
  usage
  exit 1
fi

if [[ "${ANDROID_TARGET}" != "apk" && "${ANDROID_TARGET}" != "appbundle" && "${ANDROID_TARGET}" != "both" ]]; then
  echo "Error: ANDROID_TARGET must be apk | appbundle | both. Current: ${ANDROID_TARGET}" >&2
  exit 1
fi

if ! command -v "${FLUTTER_CMD}" >/dev/null 2>&1; then
  echo "Error: Flutter command not found: ${FLUTTER_CMD}" >&2
  exit 1
fi

if ! normalize_platforms "${PLATFORMS_INPUT}"; then
  exit 1
fi

resolve_version_overrides

BUILDABLE_COUNT=0
for platform in "${PLATFORMS[@]-}"; do
  if is_platform_supported_on_host "${platform}"; then
    if [[ "${platform}" == "ios" && "${BUILD_MODE}" == "debug" ]]; then
      continue
    fi
    BUILDABLE_COUNT=$((BUILDABLE_COUNT + 1))
  fi
done

if [[ "${BUILDABLE_COUNT}" -eq 0 ]]; then
  echo "Error: no buildable platforms for host $(host_os) with build mode ${BUILD_MODE}." >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SESSION_DIR="${OUTPUT_ROOT}/${TIMESTAMP}-${BUILD_MODE}"
STAGING_ROOT="${SESSION_DIR}/.staging"
MANIFEST_FILE="${SESSION_DIR}/manifest.txt"

mkdir -p "${SESSION_DIR}" "${STAGING_ROOT}"
{
  echo "Flutter unified artifact manifest"
  echo "project: ${PROJECT_ROOT}"
  echo "timestamp: ${TIMESTAMP}"
  echo "build_mode: ${BUILD_MODE}"
  echo "build_name: ${BUILD_NAME:-pubspec default}"
  echo "build_number: ${BUILD_NUMBER:-pubspec default}"
  echo "api_base_url: ${APPREAD_API_BASE_URL:-dart default}"
  echo "app_name: ${APPREAD_APP_NAME:-dart default}"
  echo "platforms: ${PLATFORMS[*]}"
  echo ""
} > "${MANIFEST_FILE}"

echo "==> Project root : ${PROJECT_ROOT}"
echo "==> Flutter cmd  : ${FLUTTER_CMD}"
echo "==> Host OS      : $(host_os)"
echo "==> Platforms    : ${PLATFORMS[*]}"
echo "==> Build mode   : ${BUILD_MODE}"
echo "==> Android target: ${ANDROID_TARGET}"
echo "==> Android APK  : ${ANDROID_APK_PROFILE}"
echo "==> Build name   : ${BUILD_NAME:-pubspec default}"
echo "==> Build number : ${BUILD_NUMBER:-pubspec default}"
echo "==> API base URL : ${APPREAD_API_BASE_URL:-dart default}"
echo "==> App name     : ${APPREAD_APP_NAME:-dart default}"
echo "==> Output folder: ${SESSION_DIR}"

cd "${PROJECT_ROOT}"

if [[ "${SKIP_CLEAN}" != "1" ]]; then
  echo "==> flutter clean"
  "${FLUTTER_CMD}" clean
fi

if [[ "${SKIP_PUB_GET}" != "1" ]]; then
  echo "==> flutter pub get"
  "${FLUTTER_CMD}" pub get
fi

for platform in "${PLATFORMS[@]-}"; do
  case "${platform}" in
    android)
      run_platform_build "android" env \
        FLUTTER_CMD="${FLUTTER_CMD}" \
        OUTPUT_DIR="${STAGING_ROOT}/android" \
        SKIP_CLEAN=1 \
        SKIP_PUB_GET=1 \
        APK_PROFILE="${ANDROID_APK_PROFILE}" \
        SPLIT_PER_ABI="${SPLIT_PER_ABI}" \
        BUILD_NAME="${BUILD_NAME}" \
        BUILD_NUMBER="${BUILD_NUMBER}" \
        APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL}" \
        APPREAD_APP_NAME="${APPREAD_APP_NAME}" \
        "${SCRIPT_DIR}/build_android_artifacts.sh" "${ANDROID_TARGET}" "${BUILD_MODE}"
      ;;
    ios)
      echo "==> [ios] tip: Flutter first outputs .app, then the script packages final .ipa"
      if [[ "${BUILD_MODE}" == "debug" ]]; then
        echo "==> [ios] skip (unsupported build mode: debug)"
        SKIPPED_PLATFORMS+=("ios")
        if [[ "${ALLOW_PARTIAL}" != "1" ]]; then
          echo "Error: iOS does not support debug mode in this script and ALLOW_PARTIAL=0." >&2
          exit 1
        fi
      else
        run_platform_build "ios" env \
          FLUTTER_CMD="${FLUTTER_CMD}" \
          OUTPUT_DIR="${STAGING_ROOT}/ios" \
          APP_NAME="${APP_NAME}" \
          BUILD_MODE="${BUILD_MODE}" \
          SKIP_CLEAN=1 \
          SKIP_PUB_GET=1 \
          SKIP_POD_INSTALL="${SKIP_POD_INSTALL}" \
          BUILD_NAME="${BUILD_NAME}" \
          BUILD_NUMBER="${BUILD_NUMBER}" \
          APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL}" \
          APPREAD_APP_NAME="${APPREAD_APP_NAME}" \
          "${SCRIPT_DIR}/build_ios_ipa_nocodesign.sh"
      fi
      ;;
    macos)
      run_platform_build "macos" env \
        FLUTTER_CMD="${FLUTTER_CMD}" \
        OUTPUT_DIR="${STAGING_ROOT}/macos" \
        APP_NAME="${MACOS_APP_NAME}" \
        SKIP_CLEAN=1 \
        SKIP_PUB_GET=1 \
        SKIP_POD_INSTALL="${SKIP_POD_INSTALL}" \
        BUILD_NAME="${BUILD_NAME}" \
        BUILD_NUMBER="${BUILD_NUMBER}" \
        APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL}" \
        APPREAD_APP_NAME="${APPREAD_APP_NAME}" \
        "${SCRIPT_DIR}/build_macos_artifact.sh" "${BUILD_MODE}"
      ;;
    linux)
      run_platform_build "linux" env \
        FLUTTER_CMD="${FLUTTER_CMD}" \
        OUTPUT_DIR="${STAGING_ROOT}/linux" \
        SKIP_CLEAN=1 \
        SKIP_PUB_GET=1 \
        BUILD_NAME="${BUILD_NAME}" \
        BUILD_NUMBER="${BUILD_NUMBER}" \
        APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL}" \
        APPREAD_APP_NAME="${APPREAD_APP_NAME}" \
        "${SCRIPT_DIR}/build_linux_artifact.sh" "${BUILD_MODE}"
      ;;
    windows)
      run_platform_build "windows" env \
        FLUTTER_CMD="${FLUTTER_CMD}" \
        OUTPUT_DIR="${STAGING_ROOT}/windows" \
        SKIP_CLEAN=1 \
        SKIP_PUB_GET=1 \
        BUILD_NAME="${BUILD_NAME}" \
        BUILD_NUMBER="${BUILD_NUMBER}" \
        APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL}" \
        APPREAD_APP_NAME="${APPREAD_APP_NAME}" \
        "${SCRIPT_DIR}/build_windows_artifact.sh" "${BUILD_MODE}"
      ;;
  esac
done

if [[ "${KEEP_STAGING}" != "1" ]]; then
  rm -rf "${STAGING_ROOT}"
fi

echo ""
echo "Done. Unified artifacts folder:"
echo "${SESSION_DIR}"
echo ""

if [[ "${#SUCCESS_PLATFORMS[@]}" -gt 0 ]]; then
  echo "Successful platforms: ${SUCCESS_PLATFORMS[*]}"
fi

if [[ "${#SKIPPED_PLATFORMS[@]}" -gt 0 ]]; then
  echo "Skipped platforms: ${SKIPPED_PLATFORMS[*]}"
fi

if [[ "${#FAILED_PLATFORMS[@]}" -gt 0 ]]; then
  echo "Failed platforms: ${FAILED_PLATFORMS[*]}"
fi

echo ""
echo "Collected artifacts:"
find "${SESSION_DIR}" -maxdepth 1 -type f -print | sort | sed 's/^/  - /'
echo ""
echo "Manifest: ${MANIFEST_FILE}"

if [[ "${#SUCCESS_PLATFORMS[@]}" -eq 0 ]]; then
  echo "Error: no platform artifacts were generated." >&2
  exit 1
fi

if [[ "${#FAILED_PLATFORMS[@]}" -gt 0 && "${ALLOW_PARTIAL}" != "1" ]]; then
  exit 1
fi
