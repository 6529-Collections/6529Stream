"""Small semantic contracts for current developer documentation, not prose templates."""
from __future__ import annotations
import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote

LINK = re.compile(r"\[[^\]]+\]\(([^)\s]+)\)")
FENCE = re.compile(r"^```[^\n]*\n(.*?)^```", re.MULTILINE | re.DOTALL)


def validate_document(root, path, *, terms, links=(), commands=(), source_terms=(), sale_schema=False):
    root, path = Path(root).resolve(), Path(path).resolve()
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise ValueError("document escapes repository") from exc
    if not path.is_file():
        raise ValueError("missing document: " + str(path))
    text = path.read_text(encoding="utf-8")
    normalized = " ".join(text.lower().split())
    for term in ("pre-audit", "not production-ready", *terms):
        if " ".join(term.lower().split()) not in normalized:
            raise ValueError("missing current documentation boundary: " + term)
    fences = "\n".join(FENCE.findall(text))
    for obsolete in ("mintDrop(", "DropAuthorization:", "withdrawFixedPriceCreditTo("):
        if obsolete in fences:
            raise ValueError("legacy API in current executable example: " + obsolete)
    for command in commands:
        if command not in text:
            raise ValueError("missing developer command: " + command)
    found = set()
    for match in LINK.finditer(text):
        target = match.group(1)
        if target.startswith(("#", "mailto:")) or "://" in target:
            continue
        target = unquote(target.split("#", 1)[0].split("?", 1)[0])
        resolved = (path.parent / target).resolve()
        try:
            relative = resolved.relative_to(root).as_posix()
        except ValueError as exc:
            raise ValueError("linked path escapes repository: " + target) from exc
        if not resolved.exists():
            raise ValueError("missing linked target: " + relative)
        found.add(relative)
    for target in links:
        if target not in found:
            raise ValueError("missing navigation boundary: " + target)
    for source, tokens in source_terms:
        source_text = (root / source).read_text(encoding="utf-8")
        for token in tokens:
            if token not in source_text:
                raise ValueError("documented API missing from source: " + token)
    if sale_schema:
        source = (root / "smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol").read_text(encoding="utf-8")
        match = re.search(r'"SaleAuthorization\(([^)]*)\)"', source)
        if not match:
            raise ValueError("missing source SaleAuthorization type hash")
        expected = [tuple(item.split()) for item in match.group(1).split(",")]
        block = text.split("SaleAuthorization: [", 1)[-1].split("]", 1)[0]
        fields = re.findall(r'name: "([^"]+)", type: "([^"]+)"', block)
        if [(kind, name) for name, kind in fields] != expected:
            raise ValueError("SaleAuthorization example fields differ from source")


def run(argv, *, default, option, validate):
    parser = argparse.ArgumentParser(description="Check current documentation boundaries")
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(option, dest="document", type=Path, default=Path(default))
    args = parser.parse_args(argv)
    root = args.repo_root.resolve()
    path = args.document if args.document.is_absolute() else root / args.document
    try:
        validate(root, path)
    except (ValueError, OSError) as exc:
        print("documentation check failed: " + str(exc), file=sys.stderr)
        return 1
    print(str(default) + " current documentation boundaries pass")
    return 0
