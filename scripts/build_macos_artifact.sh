#!/usr/bin/env bash
set -euo pipefail

# Build a macOS desktop artifact (.app zipped).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
BUILD_MODE="${1:-${BUILD_MODE:-release}}" # debug | profile | release
APP_NAME="${APP_NAME:-}"                  # optional, e.g. YuanRead
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/build/macos/artifacts}"
ARTIFACT_NAME="${ARTIFACT_NAME:-Selune}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL:-}"
APPREAD_READER_GATEWAY_BASE_URL="${APPREAD_READER_GATEWAY_BASE_URL:-}"
APPREAD_APP_NAME="${APPREAD_APP_NAME:-selune}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"
SKIP_PUB_GET="${SKIP_PUB_GET:-0}"
SKIP_POD_INSTALL="${SKIP_POD_INSTALL:-0}"
PREPARE_APPLE_PODS="${PREPARE_APPLE_PODS:-1}"

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

usage() {
  cat <<USAGE
Usage:
  ./scripts/build_macos_artifact.sh [build_mode]

Arguments:
  build_mode  debug | profile | release (default: release)

Environment variables:
  FLUTTER_CMD  Flutter command path (default: flutter)
  APP_NAME     Optional .app name (without .app), e.g. YuanRead
  OUTPUT_DIR   Output artifacts folder (default: build/macos/artifacts)
  ARTIFACT_NAME Final artifact display name prefix (default: Selune)
  BUILD_NAME   Override Flutter --build-name
  BUILD_NUMBER Override Flutter --build-number
  SKIP_CLEAN   1 to skip flutter clean
  SKIP_PUB_GET 1 to skip flutter pub get
  SKIP_POD_INSTALL 1 to skip pod install in macos/

Examples:
  ./scripts/build_macos_artifact.sh release
  APP_NAME=YuanRead ./scripts/build_macos_artifact.sh release
  BUILD_NAME=1.1.0 BUILD_NUMBER=26041801 ./scripts/build_macos_artifact.sh release
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

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: macOS artifact can only be built on macOS hosts." >&2
  exit 1
fi

if ! command -v "${FLUTTER_CMD}" >/dev/null 2>&1; then
  echo "Error: Flutter command not found: ${FLUTTER_CMD}" >&2
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "Error: zip command is required but not found." >&2
  exit 1
fi

validate_version_overrides

MODE_DIR="Release"
if [[ "${BUILD_MODE}" == "debug" ]]; then
  MODE_DIR="Debug"
elif [[ "${BUILD_MODE}" == "profile" ]]; then
  MODE_DIR="Profile"
fi

echo "==> Project root: ${PROJECT_ROOT}"
echo "==> Flutter cmd : ${FLUTTER_CMD}"
echo "==> Build mode  : ${BUILD_MODE}"
echo "==> Build name  : ${BUILD_NAME:-pubspec default}"
echo "==> Build number: ${BUILD_NUMBER:-pubspec default}"
echo "==> API base    : ${APPREAD_API_BASE_URL:-dart default}"
echo "==> Reader API  : ${APPREAD_READER_GATEWAY_BASE_URL:-dart default}"
echo "==> App name    : ${APPREAD_APP_NAME:-dart default}"
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

if [[ "${PREPARE_APPLE_PODS}" == "1" ]]; then
  echo "==> prepare Apple podspec overrides"
  "${SCRIPT_DIR}/prepare_apple_podspec_overrides.sh"
fi

if [[ "${SKIP_POD_INSTALL}" != "1" ]]; then
  if command -v pod >/dev/null 2>&1; then
    echo "==> pod install --no-repo-update (macos/)"
    (cd macos && pod install --no-repo-update)
  else
    echo "==> Warning: CocoaPods (pod) not found, skip pod install"
  fi
fi

echo "==> flutter build macos --${BUILD_MODE}"
CMD=("${FLUTTER_CMD}" build macos --"${BUILD_MODE}")
if [[ -n "${BUILD_NAME}" ]]; then
  CMD+=(--build-name="${BUILD_NAME}")
fi
if [[ -n "${BUILD_NUMBER}" ]]; then
  CMD+=(--build-number="${BUILD_NUMBER}")
fi
append_dart_defines CMD
"${CMD[@]}"

PRODUCTS_DIR="${PROJECT_ROOT}/build/macos/Build/Products/${MODE_DIR}"
APP_PATH=""

if [[ -n "${APP_NAME}" ]]; then
  APP_PATH="${PRODUCTS_DIR}/${APP_NAME}.app"
  if [[ ! -d "${APP_PATH}" ]]; then
    echo "Error: App not found: ${APP_PATH}" >&2
    exit 1
  fi
else
  APP_CANDIDATES=()
  while IFS= read -r app_candidate; do
    [[ -n "${app_candidate}" ]] && APP_CANDIDATES+=("${app_candidate}")
  done < <(find "${PRODUCTS_DIR}" -maxdepth 1 -type d -name '*.app' | sort)

  if [[ "${#APP_CANDIDATES[@]}" -eq 0 ]]; then
    echo "Error: No .app bundle found under ${PRODUCTS_DIR}" >&2
    exit 1
  fi

  APP_PATH="${APP_CANDIDATES[0]}"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
APP_BASENAME="$(basename "${APP_PATH}" .app)"
ARTIFACT_DIR="${OUTPUT_DIR}/${TIMESTAMP}-${BUILD_MODE}"
ARCHIVE_PATH="${ARTIFACT_DIR}/$(artifact_base_name)-macOS$(artifact_version_suffix)$(artifact_mode_suffix).zip"
TMP_DIR="${ARTIFACT_DIR}/.tmp"

mkdir -p "${ARTIFACT_DIR}"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
cp -R "${APP_PATH}" "${TMP_DIR}/"

(
  cd "${TMP_DIR}"
  zip -qry "${ARCHIVE_PATH}" "${APP_BASENAME}.app"
)

rm -rf "${TMP_DIR}"

echo ""
echo "Done. macOS artifact is ready:"
echo "${ARCHIVE_PATH}"
