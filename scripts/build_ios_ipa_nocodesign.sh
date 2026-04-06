#!/usr/bin/env bash
set -euo pipefail

# Build an unsigned iOS IPA from a Flutter project.
# The resulting IPA can be re-signed and installed via tools like all-sign.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
APP_NAME="${APP_NAME:-Runner}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/build/ios/ipa}"
ARTIFACT_NAME="${ARTIFACT_NAME:-书享阅读 Next}"
BUILD_MODE="${BUILD_MODE:-release}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"
SKIP_PUB_GET="${SKIP_PUB_GET:-0}"
SKIP_POD_INSTALL="${SKIP_POD_INSTALL:-0}"
PREPARE_APPLE_PODS="${PREPARE_APPLE_PODS:-1}"

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

echo "==> Project root: ${PROJECT_ROOT}"
echo "==> Flutter cmd: ${FLUTTER_CMD}"
echo "==> Build mode : ${BUILD_MODE}"
echo "==> Build name : ${BUILD_NAME:-pubspec default}"
echo "==> Build number: ${BUILD_NUMBER:-pubspec default}"
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

echo "==> flutter build ios --${BUILD_MODE} --no-codesign"
CMD=("${FLUTTER_CMD}" build ios --"${BUILD_MODE}" --no-codesign)
if [[ -n "${BUILD_NAME}" ]]; then
  CMD+=(--build-name="${BUILD_NAME}")
fi
if [[ -n "${BUILD_NUMBER}" ]]; then
  CMD+=(--build-number="${BUILD_NUMBER}")
fi
"${CMD[@]}"

APP_PATH="${PROJECT_ROOT}/build/ios/iphoneos/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Error: Built app not found: ${APP_PATH}" >&2
  echo "Try setting APP_NAME if your app target is not Runner." >&2
  exit 1
fi

echo "==> iOS intermediate output (.app): ${APP_PATH}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
IPA_PATH="${OUTPUT_DIR}/$(artifact_base_name) iOS$(artifact_mode_suffix) ${TIMESTAMP}.ipa"
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
