"""Offline V3 projection with exact selected declaration lineage and original bytes."""
from dataclasses import replace
from pathlib import Path

from .canonical import dumps, keccak256, loads
from .declaration_lineage import declaration_graph
from .declaration_lineage_profile import DeclarationLineageProfile
from .independent_wire import require
from .recorded_selection import _project_recorded_base
from .coverage import verify_coverage
from .schema_inventory import EVALUATION_PROFILE_HASH, inventory_exact


def project_declaration_lineage(source, selection_bytes, plan_bytes, *, selection_hash, plan_hash):
    require(type(source.profile) is DeclarationLineageProfile, "concrete declaration lineage profile required")
    # Unchanged projection enforces the exact original policy/plan pins, account
    # authority, unresolved-reference and competing selected identity refusals.
    result = _project_recorded_base(source, selection_bytes, plan_bytes, selection_hash=selection_hash, plan_hash=plan_hash)
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    graphs, node_count = [], 0
    for row in plan["entityAuthoritySet"]:
        graph = declaration_graph(source, row)
        node_count += len(graph["nodes"])
        require(node_count <= 512, "projection lineage node bound")
        graphs.append(graph)
    selected = {graph["nodes"][0]["value"]["id"]: graph for graph in graphs}
    external = {row["id"]: row["kind"] for row in plan["externalEntities"]}
    for graph in graphs:
        graph_keys = {dumps(node["source"]) for node in graph["nodes"]}
        for node in graph["nodes"]:
            identifier = node["value"]["id"]
            if identifier in external:
                require(external[identifier] == node["value"]["kind"], "external lineage predecessor kind differs")
            if identifier in selected:
                chosen = selected[identifier]
                chosen_keys = {dumps(value["source"]) for value in chosen["nodes"]}
                require(dumps(node["source"]) in chosen_keys or dumps(chosen["selected"]) in graph_keys,
                    "selected predecessor identity is an unrelated declaration")
    sidecar = loads(result.sidecar, maximum=67108864, canonical=True)
    sidecar["declarationLineage"] = graphs
    # Ancestor evidence is selected for lineage even when its resource is not
    # selected. Inventory its complete original payload without reprojecting it.
    coverage = loads(result.coverage, maximum=67108864, canonical=True)
    covered = {row["recordHash"] for row in coverage}
    lineage_records = {node["source"]["recordHash"] for graph in graphs for node in graph["nodes"]}
    for record_hash in sorted(lineage_records - covered):
        record = source.records[record_hash]
        inv = inventory_exact(record.schema, record.payload, schema_hash=record.selector.schema_hash,
            payload_hash=record.payload_hash, evaluation_hash=EVALUATION_PROFILE_HASH)
        rows = [{"pointer": field.pointer, "presence": field.presence, "exactHex": "0x" + field.exact.hex(),
            "disposition": "retained_stream_only", "rule": "urn:6529stream:museum:declaration-lineage:v3",
            "reason": "complete original declaration lineage evidence; no claim redirection"} for field in inv.fields]
        verify_coverage(inv.fields, rows)
        coverage.append({"recordHash": record_hash, "schemaHash": inv.schema_hash, "payloadHash": inv.payload_hash,
            "evaluationHash": inv.evaluation_hash, "fields": rows})
    coverage_raw = dumps(sorted(coverage, key=lambda row: row["recordHash"]))
    for row in sidecar["publicSources"]:
        if row["selector"]["recordHash"] in lineage_records:
            row["inventoryScope"] = True
    sidecar_raw = dumps(sidecar)
    report = loads(result.report, maximum=67108864, canonical=True)
    report.update(sidecarHash=keccak256(sidecar_raw), coverageHash=keccak256(coverage_raw), declarationLineageHash=keccak256(dumps(graphs)),
        identityPolicy="Exact selected declarations; original identities, claims, reviews and authority retained. No automatic equivalence, deletion, subject redirection or latest-wins rule.")
    for row in report["entities"]:
        if row["kind"] == "stream_extension":
            row["sidecarHash"] = report["sidecarHash"]
    report_raw = dumps(report)
    require(sum(len(r.content) + len(r.expanded) for r in result.resources)
        + len(sidecar_raw) + len(coverage_raw) + len(result.provenance) + len(report_raw) <= 67108864,
        "encoded lineage projection byte limit")
    return replace(result, sidecar=sidecar_raw, coverage=coverage_raw, report=report_raw)


def main():
    import argparse
    from .recorded_projection import output_files, replay_source
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    for name in ("source", "publication", "interpretation", "profile", "selection", "plan"):
        parser.add_argument("--" + name + "-hash", required=True)
    args = parser.parse_args()
    source = replay_source(Path(__file__).resolve().parents[2] / "schemas/museum", args.input,
        source_hash=args.source_hash, publication_hash=args.publication_hash,
        interpretation_hash=args.interpretation_hash, profile_hash=args.profile_hash)
    result = project_declaration_lineage(source, (args.input / "selection.json").read_bytes(),
        (args.input / "plan.json").read_bytes(), selection_hash=args.selection_hash, plan_hash=args.plan_hash)
    args.output.mkdir(parents=True, exist_ok=False)
    files = output_files(result)
    for name, raw in files.items():
        (args.output / name).write_bytes(raw)
    print(dumps({"mode": "recorded_declaration_lineage_projection", "profileHash": source.profile_hash,
        "files": {name: keccak256(raw) for name, raw in files.items()}, "cryptographicStateProof": False,
        "humanIndependenceEstablished": False}).decode())


if __name__ == "__main__":
    main()
