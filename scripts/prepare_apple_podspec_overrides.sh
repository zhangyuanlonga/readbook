#!/usr/bin/env bash
set -euo pipefail

# Patches a few third-party podspecs in pub-cache so Apple builds don't depend
# on flaky remote CocoaPods specs and legacy OrderedSet/sqlite3 pods.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGE_CONFIG="${PROJECT_ROOT}/.dart_tool/package_config.json"

if [[ ! -f "${PACKAGE_CONFIG}" ]]; then
  echo "==> Apple podspec overrides: skip (.dart_tool/package_config.json not found)"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "==> Apple podspec overrides: skip (python3 not found)"
  exit 0
fi

python3 - "${PACKAGE_CONFIG}" <<'PY'
import json
import pathlib
import sys

package_config = pathlib.Path(sys.argv[1])
data = json.loads(package_config.read_text())
packages = {
    pkg["name"]: pathlib.Path(pkg["rootUri"].replace("file://", ""))
    for pkg in data.get("packages", [])
}

ORDERED_SET = """import Foundation

final class OrderedSet<Element: Equatable>: Sequence {
    private var elements: [Element]

    init<S: Sequence>(sequence: S) where S.Element == Element {
        var uniqueElements: [Element] = []
        for element in sequence {
            if !uniqueElements.contains(element) {
                uniqueElements.append(element)
            }
        }
        elements = uniqueElements
    }

    subscript(index: Int) -> Element {
        elements[index]
    }

    func makeIterator() -> IndexingIterator<[Element]> {
        elements.makeIterator()
    }

    func append(_ element: Element) {
        if !elements.contains(element) {
            elements.append(element)
        }
    }

    func remove(_ element: Element) {
        elements.removeAll { $0 == element }
    }

    func removeObject(at index: Int) {
        elements.remove(at: index)
    }

    func removeAllObjects() {
        elements.removeAll()
    }
}
"""

def write_if_changed(path: pathlib.Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    current = path.read_text() if path.exists() else None
    if current != content:
        path.write_text(content)
        print(f"patched {path}")

def replace_in_file(path: pathlib.Path, old: str, new: str) -> None:
    if not path.exists():
        return
    text = path.read_text()
    updated = text.replace(old, new)
    if updated != text:
        path.write_text(updated)
        print(f"patched {path}")

def ensure_line_after(path: pathlib.Path, anchor: str, line: str) -> None:
    if not path.exists():
        return
    text = path.read_text()
    if line in text:
        return
    if anchor not in text:
        return
    updated = text.replace(anchor, f"{anchor}{line}", 1)
    if updated != text:
        path.write_text(updated)
        print(f"patched {path}")

def patch_inappwebview(name: str, platform_dir: str) -> None:
    root = packages.get(name)
    if root is None:
        return
    base = root / platform_dir
    ordered_set_file = base / "Classes/Types/OrderedSet.swift"
    controller_file = base / "Classes/Types/WKUserContentController.swift"
    podspec_file = base / f"{name}.podspec"
    write_if_changed(ordered_set_file, ORDERED_SET)
    replace_in_file(controller_file, "import OrderedSet\n", "")
    replace_in_file(podspec_file, "  s.dependency 'OrderedSet', '~>6.0.3'\n", "")

def patch_shared_preferences() -> None:
    root = packages.get("shared_preferences_foundation")
    if root is None:
        return
    podspec = root / "darwin/shared_preferences_foundation.podspec"
    ensure_line_after(
        podspec,
        "  s.ios.dependency 'Flutter'\n",
        "  s.osx.dependency 'FlutterMacOS'\n",
    )

def patch_sqlite3_flutter_libs() -> None:
    root = packages.get("sqlite3_flutter_libs")
    if root is None:
        return
    podspec = root / "darwin/sqlite3_flutter_libs.podspec"
    ensure_line_after(
        podspec,
        "    s.ios.dependency 'Flutter'\n",
        "    s.osx.dependency 'FlutterMacOS'\n",
    )
    dependency_block = """    s.dependency 'sqlite3', '~> 3.52.0'
    s.dependency 'sqlite3/fts5'
    s.dependency 'sqlite3/perf-threadsafe'
    s.dependency 'sqlite3/rtree'
    s.dependency 'sqlite3/dbstatvtab'
    s.dependency 'sqlite3/math'
    s.dependency 'sqlite3/session'
"""
    replace_in_file(podspec, dependency_block, "    s.libraries = 'sqlite3'\n")

patch_inappwebview("flutter_inappwebview_ios", "ios")
patch_inappwebview("flutter_inappwebview_macos", "macos")
patch_shared_preferences()
patch_sqlite3_flutter_libs()
PY
