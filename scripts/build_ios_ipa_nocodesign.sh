#!/usr/bin/env bash
set -euo pipefail

# Build an unsigned iOS IPA from a Flutter project.
# The resulting IPA can be re-signed and installed via tools like all-sign.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
APP_NAME="${APP_NAME:-Runner}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/build/ios/ipa}"
ARTIFACT_NAME="${ARTIFACT_NAME:-Selune}"
BUILD_MODE="${BUILD_MODE:-release}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
APPREAD_API_BASE_URL="${APPREAD_API_BASE_URL:-}"
APPREAD_READER_GATEWAY_BASE_URL="${APPREAD_READER_GATEWAY_BASE_URL:-}"
APPREAD_APP_NAME="${APPREAD_APP_NAME:-}"
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

if [[ "${BUILD_MODE}" != "release" && "${BUILD_MODE}" != "profile" ]]; then
  echo "Error: BUILD_MODE must be 'release' or 'profile'. Current: ${BUILD_MODE}" >&2
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

if [[ "${OUTPUT_DIR}" != /* ]]; then
  OUTPUT_DIR="${PROJECT_ROOT}/${OUTPUT_DIR}"
fi

echo "==> Project root: ${PROJECT_ROOT}"
echo "==> Flutter cmd: ${FLUTTER_CMD}"
echo "==> Build mode : ${BUILD_MODE}"
echo "==> Build name : ${BUILD_NAME:-pubspec default}"
echo "==> Build number: ${BUILD_NUMBER:-pubspec default}"
echo "==> API base   : ${APPREAD_API_BASE_URL:-dart default}"
echo "==> Reader API : ${APPREAD_READER_GATEWAY_BASE_URL:-dart default}"
echo "==> App name   : ${APPREAD_APP_NAME:-dart default}"
echo "==> App name   : ${APP_NAME}"
echo "==> Output dir : ${OUTPUT_DIR}"

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
    echo "==> pod install --no-repo-update (ios/)"
    (cd ios && pod install --no-repo-update)
  else
    echo "==> Warning: CocoaPods (pod) not found, skip pod install"
  fi
fi

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

echo "==> flutter build ios --${BUILD_MODE} --no-codesign"
CMD=("${FLUTTER_CMD}" build ios --"${BUILD_MODE}" --no-codesign)
if [[ -n "${BUILD_NAME}" ]]; then
  CMD+=(--build-name="${BUILD_NAME}")
fi
if [[ -n "${BUILD_NUMBER}" ]]; then
  CMD+=(--build-number="${BUILD_NUMBER}")
fi
append_dart_defines CMD
"${CMD[@]}"

APP_PATH="${PROJECT_ROOT}/build/ios/iphoneos/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Error: Built app not found: ${APP_PATH}" >&2
  echo "Try setting APP_NAME if your app target is not Runner." >&2
  exit 1
fi

echo "==> iOS intermediate output (.app): ${APP_PATH}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
IPA_PATH="${OUTPUT_DIR}/$(artifact_base_name)-iOS$(artifact_version_suffix)$(artifact_mode_suffix).ipa"
TMP_DIR="${PROJECT_ROOT}/build/ios/ipa/.tmp-${TIMESTAMP}"

mkdir -p "${OUTPUT_DIR}"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}/Payload"
cp -R "${APP_PATH}" "${TMP_DIR}/Payload/"

echo "==> Packaging unsigned IPA from Payload/${APP_NAME}.app"
(
  cd "${TMP_DIR}"
  zip -qry "${IPA_PATH}" Payload
)

rm -rf "${TMP_DIR}"

echo ""
echo "Done. Unsigned IPA generated (final artifact):"
echo "${IPA_PATH}"
echo ""
echo "Note: Flutter always produces a .app first, then this script packages it into .ipa."
echo "Next step: import this IPA into your signing tool and re-sign/install on device."
