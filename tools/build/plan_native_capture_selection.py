"""Plan same-context native compiler roots from a retained Solidity analysis AST.

This is an informational preflight. It does not invoke a compiler or produce
compiler output. Empty contract-key AST selectors follow the same source and
immutable-owner rules as ``partition_native_capture._selection``.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import sys

from tools.build.inspect_codegen_selection import SelectionError, _read_json
from tools.build.partition_native_capture import _selection


def _fail(message: str) -> None:
    raise SelectionError(message)


def _field_list(value, coordinate: str) -> list[str]:
    if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item for item in value):
        _fail(f"invalid original output fields for {coordinate}")
    return value


def _definitions(analysis_output: dict) -> tuple[dict[str, dict], dict[str, dict]]:
    sources = analysis_output.get("sources")
    if not isinstance(sources, dict) or not sources:
        _fail("analysis output lacks a non-empty sources object")
    by_id: dict[str, dict] = {}
    by_coordinate: dict[str, dict] = {}
    for source in sorted(sources):
        if not isinstance(source, str) or not source:
            _fail("analysis output has an invalid source name")
        row = sources[source]
        ast = row.get("ast") if isinstance(row, dict) else None
        nodes = ast.get("nodes") if isinstance(ast, dict) else None
        if not isinstance(nodes, list):
            _fail(f"analysis output has no full AST nodes for {source!r}")
        for node in nodes:
            if not isinstance(node, dict) or node.get("nodeType") != "ContractDefinition":
                continue
            ident, name = node.get("id"), node.get("name")
            if type(ident) is not int or ident < 0:
                _fail(f"invalid contract declaration ID in {source!r}")
            if ident in by_id:
                _fail(f"duplicate contract declaration ID: {ident}")
            if not isinstance(name, str) or not name:
                _fail(f"unnamed contract definition in {source!r}")
            coordinate = source + ":" + name
            if coordinate in by_coordinate:
                _fail(f"duplicate contract coordinate: {coordinate}")
            entry = {"source": source, "coordinate": coordinate, "node": node}
            by_id[ident] = entry
            by_coordinate[coordinate] = entry

    for ident, entry in by_id.items():
        node, coordinate = entry["node"], entry["coordinate"]
        dependencies = node.get("contractDependencies", [])
        if not isinstance(dependencies, list):
            _fail(f"invalid contractDependencies for {coordinate}")
        if any(type(dep) is not int or dep < 0 for dep in dependencies):
            _fail(f"invalid dependency declaration ID for {coordinate}")
        if len(dependencies) != len(set(dependencies)):
            _fail(f"duplicate dependency declaration ID for {coordinate}")
        for dep in dependencies:
            if dep not in by_id:
                _fail(f"unknown dependency declaration ID {dep} for {coordinate}")
        linearized = node.get("linearizedBaseContracts", [ident])
        if (not isinstance(linearized, list) or not linearized
                or any(type(base) is not int or base < 0 for base in linearized)
                or len(linearized) != len(set(linearized))):
            _fail(f"invalid C3 linearization for {coordinate}")
        for base in linearized:
            if base not in by_id:
                _fail(f"unknown C3 base declaration ID {base} for {coordinate}")
    return by_id, by_coordinate


def plan_selection(analysis_output: dict, codegen_input: dict,
                   selected_products: list[str]) -> dict:
    """Return deterministic outputSelection roots and AST-expansion warnings.

    Explicit roots retain their exact original output field lists. A recursive
    ``contractDependencies`` child uses its own original named fields when
    present; otherwise it inherits the union of its direct parents' fields.
    """
    if not isinstance(codegen_input, dict) or not isinstance(codegen_input.get("sources"), dict):
        _fail("codegen input lacks a sources object")
    ast_sources = analysis_output.get("sources") if isinstance(analysis_output, dict) else None
    if not isinstance(ast_sources, dict) or set(ast_sources) != set(codegen_input["sources"]):
        _fail("analysis output and codegen input source names differ")
    settings = codegen_input.get("settings")
    if not isinstance(settings, dict) or not isinstance(settings.get("outputSelection"), dict):
        _fail("codegen input lacks settings.outputSelection")
    original_selection = settings["outputSelection"]
    by_id, by_coordinate = _definitions(analysis_output)

    if (not isinstance(selected_products, list) or not selected_products
            or any(not isinstance(item, str) or not item for item in selected_products)):
        _fail("selected products must be a non-empty list of fully qualified names")
    if len(selected_products) != len(set(selected_products)):
        _fail("duplicate selected product coordinate")
    roots = sorted(selected_products)
    for coordinate in roots:
        if coordinate.count(":") != 1:
            _fail(f"invalid fully qualified product coordinate: {coordinate!r}")
        if coordinate not in by_coordinate:
            _fail(f"unknown selected product coordinate: {coordinate}")

    def requested_fields(coordinate: str):
        source, name = coordinate.rsplit(":", 1)
        row = original_selection.get(source)
        if not isinstance(row, dict) or name not in row:
            return None
        return _field_list(row[name], coordinate)

    root_fields = {}
    for coordinate in roots:
        fields = requested_fields(coordinate)
        if fields is None:
            _fail(f"selected root is absent from original outputSelection: {coordinate}")
        root_fields[coordinate] = list(fields)

    # Walk dependencies in deterministic order and retain the parent edge so
    # an unrequested child inherits the exact output fields that require it.
    parent_fields: dict[str, set[str]] = {}
    closure = set(roots)
    pending = list(roots)
    propagated: dict[str, set[str]] = {}
    while pending:
        parent = pending.pop(0)
        fields = set(root_fields[parent]) if parent in root_fields else (
            set(requested_fields(parent) or ()) | parent_fields.get(parent, set()))
        if propagated.get(parent) == fields:
            continue
        propagated[parent] = fields
        parent_node = by_coordinate[parent]["node"]
        for dep_id in sorted(parent_node.get("contractDependencies", [])):
            dep = by_id[dep_id]
            node = dep["node"]
            if node.get("abstract") is True or node.get("contractKind") == "interface":
                _fail(f"contractDependency is not concrete: {dep['coordinate']}")
            coordinate = dep["coordinate"]
            before = len(parent_fields.setdefault(coordinate, set()))
            parent_fields[coordinate].update(fields)
            if coordinate not in closure:
                closure.add(coordinate)
            if len(parent_fields[coordinate]) != before:
                pending.append(coordinate)

    # Build a request for the existing selector helper. This keeps its source
    # AST and full-C3 immutable-owner behavior authoritative.
    augmented = copy.deepcopy(codegen_input)
    augmented_selection = augmented["settings"]["outputSelection"]
    selected_fields = dict(root_fields)
    for coordinate in sorted(closure - set(roots)):
        original = requested_fields(coordinate)
        inherited = sorted(parent_fields.get(coordinate, set()))
        selected_fields[coordinate] = sorted(set(original or ()) | set(inherited))
        if not selected_fields[coordinate]:
            _fail(f"dependency has no inherited output fields: {coordinate}")
    for coordinate in sorted(closure):
        source, name = coordinate.rsplit(":", 1)
        augmented_selection.setdefault(source, {})[name] = selected_fields[coordinate]
    native_selection = _selection(augmented, analysis_output, sorted(closure))

    ast_source_names = sorted(source for source, outputs in native_selection.items() if "" in outputs)
    ast_selected_sources = set(ast_source_names)
    siblings = []
    for source in ast_source_names:
        nodes = analysis_output["sources"][source]["ast"]["nodes"]
        for node in nodes:
            if (not isinstance(node, dict) or node.get("nodeType") != "ContractDefinition"
                    or node.get("abstract") is True or node.get("contractKind") == "interface"):
                continue
            coordinate = source + ":" + node["name"]
            if coordinate not in closure:
                siblings.append({"coordinate": coordinate,
                                 "contractKind": node.get("contractKind", "unknown")})
    siblings.sort(key=lambda row: row["coordinate"])
    return {
        "tool": "plan_native_capture_selection",
        "informationalOnly": True,
        "warning": "This AST-based plan is not native compiler evidence and does not predict compiler time or completion.",
        "selectedRootProducts": roots,
        "selectedProducts": sorted(closure),
        "productCount": len(closure),
        "dependencyProducts": sorted(closure - set(roots)),
        "nativeAstSources": ast_source_names,
        "unselectedConcreteDefinitionsInAstSources": siblings,
        "unselectedConcreteDefinitionCount": len(siblings),
        "sourceAstExpansionWarning": (
            "Source AST selectors include unselected concrete definitions; consider extracting tiny boundaries before a long native capture."
            if siblings else None
        ),
        "outputSelection": native_selection,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analysis-output", type=Path, required=True)
    parser.add_argument("--codegen-input", type=Path, required=True,
                        help="Original Standard JSON input containing requested outputSelection fields")
    parser.add_argument("--product", action="append", required=True,
                        help="Explicit source.sol:Contract product; may be repeated")
    args = parser.parse_args(argv)
    try:
        report = plan_selection(_read_json(args.analysis_output, "analysis output"),
                                _read_json(args.codegen_input, "codegen input"), args.product)
    except SelectionError as exc:
        print(f"plan_native_capture_selection: error: {exc}", file=sys.stderr)
        return 2
    json.dump(report, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
