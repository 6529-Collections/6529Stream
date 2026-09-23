"""Inspect Solidity 0.8.19 code-generation selectors without running solc.

This is an informational preflight for retained scoped Standard JSON inputs.
It models selector expansion from the separate analysis AST; it is not a
compiler, verification gate, or evidence of actual compiler scheduling.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


class SelectionError(ValueError):
    """Input is malformed or cannot be resolved against the retained AST."""


def _read_json(path: Path, label: str) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SelectionError(f"cannot read {label} JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SelectionError(f"{label} JSON must be an object")
    return value


def _output_selection(codegen_input: dict) -> dict:
    try:
        selection = codegen_input["settings"]["outputSelection"]
    except (KeyError, TypeError) as exc:
        raise SelectionError("codegen input lacks settings.outputSelection") from exc
    if not isinstance(selection, dict) or not selection:
        raise SelectionError("settings.outputSelection must be a non-empty object")
    return selection


def _source_ast(analysis_output: dict, source: str) -> dict:
    try:
        ast = analysis_output["sources"][source]["ast"]
    except (KeyError, TypeError) as exc:
        raise SelectionError(f"analysis output has no AST for selected source {source!r}") from exc
    if not isinstance(ast, dict) or not isinstance(ast.get("nodes"), list):
        raise SelectionError(f"analysis AST for {source!r} has no nodes array")
    return ast


def _contracts(ast: dict, source: str) -> list[dict]:
    found = {}
    for node in ast["nodes"]:
        if not isinstance(node, dict) or node.get("nodeType") != "ContractDefinition":
            continue
        name = node.get("name")
        if not isinstance(name, str) or not name:
            raise SelectionError(f"AST has unnamed contract definition in {source!r}")
        if name in found:
            raise SelectionError(f"AST has duplicate contract name {source}:{name}")
        found[name] = node
    return [found[name] for name in sorted(found)]


def _library_is_internal_only(node: dict) -> bool:
    """True when a library declares no externally callable functions."""
    body = node.get("nodes", [])
    if not isinstance(body, list):
        raise SelectionError("contract definition nodes must be an array")
    return not any(
        isinstance(child, dict)
        and child.get("nodeType") == "FunctionDefinition"
        and child.get("visibility") in ("public", "external")
        for child in body
    )


def _is_concrete(node: dict) -> bool:
    return node.get("abstract") is not True and node.get("contractKind") != "interface"


def _requests_binary(fields: list[str]) -> bool:
    return any(
        field == "evm"
        or field in ("evm.bytecode", "evm.deployedBytecode")
        or field.startswith(("evm.bytecode.", "evm.deployedBytecode."))
        for field in fields
    )


def inspect_selection(analysis_output: dict, codegen_input: dict) -> dict:
    """Describe exact names and Solidity 0.8.19 source-AST selector expansion."""
    sources = codegen_input.get("sources")
    if not isinstance(sources, dict) or not sources:
        raise SelectionError("codegen input lacks a non-empty sources object")
    ast_sources = analysis_output.get("sources")
    if not isinstance(ast_sources, dict) or set(ast_sources) != set(sources):
        raise SelectionError("analysis output and codegen input source names differ")
    if not isinstance(codegen_input.get("settings"), dict):
        raise SelectionError("codegen input lacks a settings object")
    selection = _output_selection(codegen_input)
    for selector in selection:
        if selector != "*" and selector not in sources:
            raise SelectionError(f"outputSelection names unknown source {selector!r}")

    # Standard JSON source wildcards and concrete source names both select all
    # definitions within their source for the empty contract-key output.
    wildcard = "*" in selection
    source_rows = []
    for source in sorted(sources):
        source_selectors = []
        if wildcard:
            source_selectors.append({"source": "*", "contracts": selection["*"]})
        if source in selection:
            source_selectors.append({"source": source, "contracts": selection[source]})
        if not source_selectors:
            continue

        exact_names: set[str] = set()
        exact_fields: dict[str, set[str]] = {}
        wildcard_fields: set[str] = set()
        source_ast_fields: set[str] = set()
        ast_expand = False
        select_all = False
        for row in source_selectors:
            outputs = row["contracts"]
            if not isinstance(outputs, dict) or not outputs:
                raise SelectionError(f"contract selector for {row['source']!r} must be an object")
            if "" in outputs:
                fields = outputs[""]
                if not isinstance(fields, list) or not fields or any(not isinstance(f, str) for f in fields):
                    raise SelectionError(f"invalid empty-contract-key output for {row['source']!r}")
                ast_expand = True
                source_ast_fields.update(fields)
            if "*" in outputs:
                fields = outputs["*"]
                if not isinstance(fields, list) or not fields or any(not isinstance(f, str) for f in fields):
                    raise SelectionError(f"invalid wildcard-contract output for {row['source']!r}")
                select_all = True
                wildcard_fields.update(fields)
            for name, fields in outputs.items():
                if name in ("", "*"):
                    continue
                if not isinstance(name, str) or not name:
                    raise SelectionError(f"invalid contract selector in {row['source']!r}")
                if not isinstance(fields, list) or not fields or any(not isinstance(f, str) for f in fields):
                    raise SelectionError(f"invalid output fields for {row['source']}:{name}")
                exact_names.add(name)
                exact_fields.setdefault(name, set()).update(fields)

        ast = _source_ast(analysis_output, source) if ast_expand or select_all or exact_names else None
        definitions = _contracts(ast, source) if ast is not None else []
        definitions_by_name = {definition["name"]: definition for definition in definitions}
        unknown = sorted(exact_names - definitions_by_name.keys())
        if unknown:
            raise SelectionError(f"requested contract absent from analysis AST: {source}:{unknown[0]}")
        if select_all:
            exact_names.update(definitions_by_name)

        explicit = sorted(exact_names)
        siblings = sorted(
            definition["name"] for definition in definitions
            if ast_expand and definition["name"] not in exact_names
            and _is_concrete(definition)
        )
        expanded_names = set(explicit)
        if ast_expand:
            expanded_names.update(
                definition["name"] for definition in definitions
                if _is_concrete(definition)
            )
        expanded = [definitions_by_name[name] for name in sorted(expanded_names)]
        source_rows.append({
            "source": source,
            "selectors": [{
                "source": row["source"],
                "namedContracts": [
                    {"name": name, "fields": sorted(row["contracts"][name]),
                     "requestsBinary": _requests_binary(row["contracts"][name])}
                    for name in sorted(row["contracts"]) if name not in ("", "*")
                ],
                "wildcardContractFields": sorted(row["contracts"].get("*", [])),
                "allContracts": "*" in row["contracts"],
                "sourceAstFields": sorted(row["contracts"].get("", [])),
                "sourceAst": "" in row["contracts"],
            } for row in source_selectors],
            "namedBinarySelectors": [
                {"name": name, "fields": sorted(exact_fields[name])}
                for name in sorted(exact_fields) if _requests_binary(sorted(exact_fields[name]))
            ],
            "wildcardBinaryFields": sorted(field for field in wildcard_fields
                                             if _requests_binary([field])),
            "sourceAstFields": sorted(source_ast_fields),
            "explicitContractNames": explicit,
            "astSourceSelectionExpandsAllConcreteDefinitions": ast_expand,
            "implicitSiblingConcreteContractNames": siblings,
            "implicitSiblingCount": len(siblings),
            "expandedDefinitions": [
                {"name": definition["name"],
                 "contractKind": definition.get("contractKind", "unknown"),
                 "abstract": definition.get("abstract") is True,
                 "classification": (
                     "abstract-contract" if not _is_concrete(definition)
                     else ("concrete-host" if definition.get("contractKind") != "library"
                           else ("implicit-internal-only-library"
                                 if definition["name"] in siblings and _library_is_internal_only(definition)
                                 else "library"))
                 )}
                for definition in expanded
            ],
            "expandedConcreteHostCount": sum(
                definition.get("contractKind") not in ("library", "interface")
                and _is_concrete(definition)
                for definition in expanded
            ),
            "expandedLibraryCount": sum(
                definition.get("contractKind") == "library" for definition in expanded
            ),
        })

    return {
        "tool": "inspect_codegen_selection",
        "compilerSemantics": "Solidity 0.8.19 requested-contract selector expansion",
        "informationalOnly": True,
        "warning": "AST selection expansion predicts requested compiler roots; this report is not native compiler evidence.",
        "requestedSourceSelector": "*" if wildcard else "explicit",
        "sourceCount": len(source_rows),
        "sources": source_rows,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analysis-output", type=Path, default=Path("analysis-output.json"))
    parser.add_argument("--codegen-input", type=Path, default=Path("codegen-input.json"))
    args = parser.parse_args(argv)
    try:
        report = inspect_selection(
            _read_json(args.analysis_output, "analysis output"),
            _read_json(args.codegen_input, "codegen input"),
        )
    except SelectionError as exc:
        print(f"inspect_codegen_selection: error: {exc}", file=sys.stderr)
        return 2
    json.dump(report, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
