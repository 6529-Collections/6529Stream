"""Verify the retained historical companion frontier without fetching Git history.

Only type identifiers and import statements may differ from the pinned RC1
sources. Reversing those declared changes must recover each original byte hash.
Shared dependencies remain explicitly pinned; drift requires a reviewed fixture
update or expansion of the historical frontier, not a silently mixed stack.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "test/fixtures/legacy-rc1/provenance.json"
TOKEN = re.compile(
    r'//[^\r\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_]\w*'
)
IMPORT = re.compile(r'import\s+(?:[^;]*?\sfrom\s+)?["\']([^"\']+)["\']\s*;')


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def check(root: Path = ROOT) -> list[str]:
    manifest = json.loads((root / MANIFEST.relative_to(ROOT)).read_text(encoding="utf-8"))
    failures: list[str] = []
    reverse = {value: key for key, value in manifest["typeRenames"].items()}
    companions = {row["path"] for row in manifest["companions"]}
    shared = manifest["sharedDependencies"]
    forbidden = {row["source"] for row in manifest["companions"]}
    for kind in ("companions", "entrypoints"):
        for row in manifest[kind]:
            path = root / row["path"]
            raw = path.read_bytes()
            if digest(raw) != row["transformedSHA256"]:
                failures.append(f'{row["path"]}: transformed source changed')
            restored = raw.decode("utf-8")
            for change in row["imports"]:
                if restored.count(change["transformed"]) != 1:
                    failures.append(f'{row["path"]}: expected import rewrite missing/duplicated')
                restored = restored.replace(change["transformed"], change["original"])
            if kind == "companions":
                restored = TOKEN.sub(lambda match: reverse.get(match.group(), match.group()), restored)
            if digest(restored.encode("utf-8")) != row["sourceSHA256"]:
                failures.append(f'{row["path"]}: inverse transform does not recover RC1 source')
            if kind == "companions":
                for match in IMPORT.finditer(raw.decode("utf-8")):
                    if not match.group(1).startswith(("./", "../")):
                        failures.append(f'{row["path"]}: companion imports must be relative')
                    resolved = (path.parent / match.group(1)).resolve()
                    try:
                        relative = resolved.relative_to(root.resolve()).as_posix()
                    except ValueError:
                        failures.append(f'{row["path"]}: import escapes repository')
                        continue
                    if relative in forbidden or relative not in companions | shared.keys():
                        failures.append(f'{row["path"]}: unpinned dependency {relative}')
    for relative, expected in shared.items():
        if digest((root / relative).read_bytes()) != expected:
            failures.append(f"{relative}: shared historical dependency changed")
    return failures


def main() -> int:
    failures = check()
    if failures:
        print("\n".join(failures))
        return 1
    print("Legacy RC1 frontier verified: 13 companions, 4 import-only entrypoints, 133 shared dependencies")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
