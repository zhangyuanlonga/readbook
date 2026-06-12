#!/usr/bin/env bash
set -euo pipefail

# Build a Windows desktop artifact (Release folder zipped).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
BUILD_MODE="${1:-${BUILD_MODE:-release}}" # debug | profile | release
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/build/windows/artifacts}"
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
  ./scripts/build_windows_artifact.sh [build_mode]

Arguments:
  build_mode  debug | profile | release (default: release)

Environment variables:
  FLUTTER_CMD  Flutter command path (default: flutter)
  OUTPUT_DIR   Output artifacts folder (default: build/windows/artifacts)
  ARTIFACT_NAME Final artifact display name prefix (default: Selune)
  BUILD_NAME   Override Flutter --build-name
  BUILD_NUMBER Override Flutter --build-number
  APPREAD_API_BASE_URL Optional backend API base URL override
  APPREAD_READER_GATEWAY_BASE_URL Optional reader gateway base URL override
  APPREAD_APP_NAME Optional app identifier override
  SKIP_CLEAN   1 to skip flutter clean
  SKIP_PUB_GET 1 to skip flutter pub get

Examples:
  ./scripts/build_windows_artifact.sh release
  OUTPUT_DIR=/d/out ./scripts/build_windows_artifact.sh profile
  BUILD_NAME=1.1.0 BUILD_NUMBER=26041801 ./scripts/build_windows_artifact.sh release
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

echo "==> flutter build windows --${BUILD_MODE}"
CMD=("${FLUTTER_CMD}" build windows --"${BUILD_MODE}")
if [[ -n "${BUILD_NAME}" ]]; then
  CMD+=(--build-name="${BUILD_NAME}")
fi
if [[ -n "${BUILD_NUMBER}" ]]; then
  CMD+=(--build-number="${BUILD_NUMBER}")
fi
append_dart_defines CMD
"${CMD[@]}"

RUNNER_DIR="${PROJECT_ROOT}/build/windows/x64/runner/${MODE_DIR}"
if [[ ! -d "${RUNNER_DIR}" ]]; then
  echo "Error: Windows runner folder not found: ${RUNNER_DIR}" >&2
  exit 1
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

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${OUTPUT_DIR}/${TIMESTAMP}-${BUILD_MODE}"
ARCHIVE_PATH="${ARTIFACT_DIR}/$(artifact_base_name)-Windows$(artifact_version_suffix)$(artifact_mode_suffix).zip"

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
