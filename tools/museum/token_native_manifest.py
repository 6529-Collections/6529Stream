"""Pin one mint graph and an explicit Museum extension; never imply prior joined acceptance."""
import hashlib
import json
from pathlib import Path

from .canonical import dumps, keccak256
from .independent_wire import require

EXTENSIONS = frozenset(("StreamCollectionAttestations", "StreamIndependentReads"))


def pinned_json(path, expected):
    raw = Path(path).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == expected, "token composition input pin differs: " + str(path))
    return json.loads(raw)


def extension_sources(products):
    """Retain the original compilation inputs, including old linked-library source."""
    sources = {}
    for name in sorted(EXTENSIONS):
        row = products[name]
        artifact = pinned_json(row["artifact"], row["sha256"])
        project = Path(row["artifact"]).resolve().parents[2]
        for source, metadata in artifact["metadata"]["sources"].items():
            path = (project / source).resolve()
            require(path.is_relative_to(project), "extension source outside original project")
            raw = path.read_bytes()
            require(keccak256(raw) == metadata["keccak256"], "extension compilation source changed: " + source)
            item = {"source": source, "sha256": hashlib.sha256(raw).hexdigest(),
                "keccak256": metadata["keccak256"], "byteLength": str(len(raw)), "contentUtf8": raw.decode("utf-8")}
            require(source not in sources or sources[source] == item, "extension compilation sources disagree")
            sources[source] = item
    return [sources[source] for source in sorted(sources)]


def build_manifest(handoff_path, handoff_hash, museum_path, museum_hash, roots):
    """Select exact recursive link closure; no discovery, compilation, deployment or overlay."""
    handoff = pinned_json(handoff_path, handoff_hash)
    museum = pinned_json(museum_path, museum_hash)
    require(museum["mode"] == "current_museum_native_products_v1", "original museum native manifest mode")
    require(handoff["tests"]["accepted"] is True, "base graph lacks retained accepted tests")
    retained = {}
    for key in ("captureManifest", "acceptedResult", "currentGraphProjection"):
        row = handoff[key]; retained[key] = pinned_json(row["path"], row["sha256"])
    require(retained["acceptedResult"]["accepted"] is True, "pinned base result was not accepted")
    for row in handoff["sourceRecipes"]:
        raw = Path(row["path"]).read_bytes()
        require(hashlib.sha256(raw).hexdigest() == row["sha256"], "accepted mint recipe changed")
    available = {}
    for key, row in handoff["products"].items():
        if not row["source"].startswith(("smart-contracts/", "script/current/")): continue
        name = row["contract"]
        require(key == row["source"] + ":" + name and name not in available, "ambiguous accepted product identity")
        available[name] = {"source": row["source"], "artifact": row["artifact"], "sha256": row["sha256"],
            "origin": "accepted_mint_graph", "acceptedGraphHead": handoff["acceptedGraphHead"]}
    require(not EXTENSIONS.intersection(available), "extension unexpectedly overlaps accepted mint graph")
    for name in EXTENSIONS:
        row = museum["products"][name]
        available[name] = {"source": row["source"], "artifact": row["artifact"], "sha256": row["sha256"],
            "origin": "separately_pinned_museum_extension", "priorMuseumManifestSha256": museum_hash}
    roots = sorted(set(roots) | EXTENSIONS)
    require(roots and all(type(name) is str for name in roots), "explicit native root products required")
    selected, pending = {}, list(roots)
    while pending:
        name = pending.pop()
        if name in selected: continue
        require(name in available, "required product outside pinned composition: " + name)
        row = available[name]
        artifact = pinned_json(row["artifact"], row["sha256"])
        require(artifact["metadata"]["settings"]["compilationTarget"] == {row["source"]: name}, "native product source identity differs")
        require(isinstance(artifact["abi"], list), "selected native ABI missing")
        selected[name] = row
        for field in ("bytecode", "deployedBytecode"):
            for source, libraries in artifact[field]["linkReferences"].items():
                for library in libraries:
                    require(available.get(library, {}).get("source") == source, "native link origin outside exact closure")
                    pending.append(library)
    safe = museum["safeFixture"]
    pinned_json(safe["path"], safe["sha256"])
    projection = {"directory": str(Path(handoff["currentGraphProjection"]["path"]).resolve().parent),
        "manifestSha256": handoff["currentGraphProjection"]["sha256"]}
    return dumps({"mode": "current_museum_native_products_v1", "products": dict(sorted(selected.items())),
        "graphImmutableProjection": projection,
        "safeFixture": safe, "tokenComposition": {"version": "1", "rootProducts": roots,
            "baseGraphHead": handoff["acceptedGraphHead"], "handoff": {"path": str(Path(handoff_path).resolve()), "sha256": handoff_hash},
            "baseManifest": handoff["captureManifest"], "baseAcceptedResult": handoff["acceptedResult"],
            "sourceRecipes": handoff["sourceRecipes"],
            "graphImmutableProjection": projection,
            "extensionCompilationSources": extension_sources(selected),
            "extensionSourceQualification": "Original compilation source bytes are preserved as provenance. External links use only the explicitly selected products; StreamMetadataRenderer comes from the pinned mint graph, not these older source bytes.",
            "museumManifest": {"path": str(Path(museum_path).resolve()), "sha256": museum_hash},
            "extensions": sorted(EXTENSIONS), "joinedCompositionPreviouslyAccepted": False,
            "joinedCaptureStatus": "not_run", "entropyQualification": "Local controlled entropy is an explicit test substitution.",
            "qualification": "Previously accepted mint behavior authenticates the base recipe/artifact evidence only. The two separately pinned Museum products form a new composition requiring actual joined deployment and calls; no silent replacement of the base Core, governance, schema or renderer products."}})


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path); parser.add_argument("museum", type=Path); parser.add_argument("output", type=Path)
    parser.add_argument("--handoff-sha256", required=True); parser.add_argument("--museum-sha256", required=True)
    parser.add_argument("--root", action="append", default=[])
    parser.add_argument("--token-graph", action="store_true", help="select the exact current token capture recipe roots")
    args = parser.parse_args()
    roots = args.root
    if args.token_graph:
        from .token_mint_flow import TOKEN_PRODUCT_ROOTS
        roots = list(set(roots) | set(TOKEN_PRODUCT_ROOTS))
    require(roots, "select --token-graph or explicit --root products")
    raw = build_manifest(args.handoff, args.handoff_sha256, args.museum, args.museum_sha256, roots)
    with args.output.open("xb") as output: output.write(raw)
    print(hashlib.sha256(raw).hexdigest())


if __name__ == "__main__": main()
