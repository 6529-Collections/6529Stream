"""Source-replayed account authority reconciliation; complete offline evidence retention."""
from pathlib import Path

from .authority import (BODY_SCHEMA_BYTES, CLAIMS, NAME, NATIVE_KINDS, PROFILE_BYTES, PROFILE_HASH, RELATION,
    _body, _reconcile, need)
from .canonical import MuseumError, dumps, keccak256, loads
from .package import _package_path, write_package
from .package_recorded import INPUT_FILES, verify_recorded_package
from .package_v2 import _assemble, _read_package
from .preservation_graph import validator
from .recorded_projection import replay_source_bytes
from .recorded_selection import select_recorded

MODE = "recorded_account_authority_package"


def _candidates(source, selection_bytes, selection_hash):
    """Only call with the concrete source freshly reconstructed from package inputs."""
    selection = select_recorded(source, selection_bytes, policy_hash=selection_hash)
    policy = loads(selection_bytes, maximum=524288, canonical=True)
    admitted = {claim.selector: claim for claim in selection.selected}
    candidates = []
    for selector in policy["sourceAuthoritySet"]:
        assertion, issuer, position = source.assertion(selector)
        if assertion["relation"] != RELATION: continue
        body = _body(assertion); payload = source.payload(source.record(selector))
        alignments = [value for value in payload["authorityAlignments"] if value["assertionId"] == assertion["id"]]
        need(alignments == [body["alignment"]], "original authority alignment is not bound by exact assertion literal")
        declarations = [value for value in payload["entities"] if value["id"] == assertion["subject"]]
        declaration_ok = (len(declarations) == 1 and declarations[0]["kind"] == NATIVE_KINDS[body["entityKind"]]
            and declarations[0]["declaringAgent"] == issuer)
        declaration = None if not declaration_ok else {"value": declarations[0],
            "source": dict(selector, pointer="/entities/" + str(payload["entities"].index(declarations[0]))),
            "declarationHash": keccak256(dumps(declarations[0]))}
        selected = admitted.get(dumps(selector))
        reviewed = selected is not None and bool(selected.review_evidence)
        reason = "mapping_lacks_selected_authenticated_review" if declaration_ok else "original_local_entity_declaration_missing_or_incompatible"
        if body["entityKind"] == "Type": reason = "recorded_type_declaration_unsupported"
        candidates.append({"assertion": assertion, "eligible": reviewed and declaration_ok and body["entityKind"] != "Type", "eligibilityReason": reason,
            "source": selector, "reviews": [] if selected is None else [loads(raw, canonical=True) for raw in selected.review_evidence],
            "basis": "not_selected" if selected is None else selected.basis, "position": [str(v) for v in position],
            "entityDeclaration": declaration})
    return candidates, selection


def _bind_declarations(source, original_plan_bytes, candidates):
    """An IRI alone cannot authorize reuse of a selected dossier declaration."""
    plan = loads(original_plan_bytes, maximum=524288, canonical=True)
    original = {}
    for selector in plan["entityAuthoritySet"]:
        declaration, _ = source.entity(source.state, selector, source.profile_hash)
        original[declaration["id"]] = {"value": declaration, "source": selector,
            "declarationHash": keccak256(dumps(declaration))}
    external = {value["id"] for value in plan["externalEntities"]}
    eligible = {}
    for row in candidates:
        if row["eligible"]:
            eligible.setdefault(row["assertion"]["subject"], set()).add(dumps(row["entityDeclaration"]))
    for row in candidates:
        identifier = row["assertion"]["subject"]; reason = None
        if identifier in external:
            reason = "original_external_identity_cannot_be_redeclared"
        elif identifier in original and row["entityDeclaration"] != original[identifier]:
            reason = "original_selected_declaration_reuse_not_established"
        elif identifier not in original and len(eligible.get(identifier, ())) > 1:
            reason = "ambiguous_selected_local_declarations"
        if row["eligible"] and reason is not None:
            row["eligible"] = False; row["eligibilityReason"] = reason


def build_authority_package(directory, expected_manifest_hash, request_bytes, selection_bytes, snapshots, *,
                            request_hash, selection_hash, profile_hash, disclosure):
    need(disclosure == "public", "explicit public classification required")
    need(profile_hash == PROFILE_HASH, "external profile differs")
    directory = Path(directory).resolve(); original = verify_recorded_package(directory, expected_manifest_hash)
    original_files = dict(original.files); pins = loads(original.manifest, maximum=2097152)["pins"]
    source = replay_source_bytes(directory / "dependencies", {name: original_files["inputs/" + name] for name in INPUT_FILES},
        **{key + "_hash": pins[key] for key in ("source", "publication", "interpretation", "profile")})
    candidates, selected = _candidates(source, selection_bytes, selection_hash)
    _bind_declarations(source, original_files["inputs/plan.json"], candidates)
    projected = _reconcile(request_bytes, candidates, snapshots, request_hash=request_hash, profile_hash=profile_hash,
        mode="recorded_account_authority_reconciliation", model=validator(directory / "dependencies"))
    # An extension may add equivalent to an already-selected resource of the same
    # class; it may never use a new declaration to retype the original dossier.
    original_index = {row["id"]: row for row in loads(original_files["linked-art/entity-index.json"], maximum=2097152)}
    for row in loads(projected["authority/index.json"], maximum=2097152)["resources"]:
        old = original_index.get(row["id"])
        if old is not None:
            need(old["kind"] == "linked_art" and loads(original_files[old["path"]], maximum=2097152)["type"] == row["type"],
                "selected original entity cannot change type")
    files = {"source/" + name: raw for name, raw in original.files}; files["source/manifest.json"] = original.manifest
    files.update({"inputs/requests.json": request_bytes, "inputs/selection.json": selection_bytes,
        "definitions/authority-profile.json": PROFILE_BYTES, "definitions/" + NAME + ".json": BODY_SCHEMA_BYTES})
    index = {}
    for logical_path, (descriptor_bytes, raw, descriptor_hash) in sorted(snapshots.items()):
        name = keccak256(logical_path.encode("utf-8"))[2:]
        descriptor_path, raw_path = "snapshots/" + name + ".descriptor.json", "snapshots/" + name + ".rdf.json"
        files[descriptor_path], files[raw_path] = descriptor_bytes, raw
        index[logical_path] = {"descriptorPath": descriptor_path, "rawPath": raw_path, "descriptorHash": descriptor_hash}
    files["inputs/snapshot-index.json"] = dumps(index)
    files["authority/selection.json"] = dumps({"stateCommitment": selected.source_state_hash,
        "sourceProfileHash": selected.profile_hash, "selectionHash": selection_hash,
        "diagnostics": [{"selector": loads(row.selector, canonical=True), "reason": row.reason} for row in selected.diagnostics]})
    files.update(projected)
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "requestHash": request_hash, "selectionHash": selection_hash, "profileHash": profile_hash, "claims": CLAIMS,
        "disclosure": disclosure})


def verify_authority_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve(); raw, manifest, files = _read_package(directory, expected_manifest_hash)
    need(set(manifest) == {"mode", "version", "sourceManifestHash", "requestHash", "selectionHash", "profileHash", "claims", "disclosure", "files"}
        and manifest["mode"] == MODE and manifest["version"] == "1" and manifest["claims"] == CLAIMS, "package manifest differs")
    try:
        index = loads(files["inputs/snapshot-index.json"], maximum=524288, canonical=True)
        need(isinstance(index, dict) and len(index) <= 64, "snapshot index bound")
        snapshots = {}
        for path, row in index.items():
            need(isinstance(row, dict) and set(row) == {"descriptorPath", "rawPath", "descriptorHash"}, "snapshot index shape")
            snapshots[path] = (files[row["descriptorPath"]], files[row["rawPath"]], row["descriptorHash"])
        rebuilt = build_authority_package(directory / "source", manifest["sourceManifestHash"], files["inputs/requests.json"],
            files["inputs/selection.json"], snapshots, request_hash=manifest["requestHash"], selection_hash=manifest["selectionHash"],
            profile_hash=manifest["profileHash"], disclosure=manifest["disclosure"])
    except (KeyError, FileNotFoundError) as exc: raise MuseumError("authority package input missing") from exc
    need(rebuilt.manifest == raw and dict(rebuilt.files) == files, "package semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    p = argparse.ArgumentParser(description=__doc__); sub = p.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    build = sub.add_parser("build")
    for name in ("source", "requests", "selection", "snapshot_index", "directory"): build.add_argument(name, type=Path)
    for name in ("source-manifest-hash", "request-hash", "selection-hash", "profile-hash"): build.add_argument("--" + name, required=True)
    build.add_argument("--disclosure", choices=("public", "restricted"), required=True); args = p.parse_args()
    def read(path, limit):
        need(path.stat().st_size <= limit, "input file bound")
        raw = path.read_bytes(); need(len(raw) <= limit, "input file changed beyond bound"); return raw
    try:
        if args.command == "verify": result = verify_authority_package(args.directory, args.manifest_hash)
        else:
            index = loads(read(args.snapshot_index, 524288), maximum=524288, canonical=True)
            need(isinstance(index, dict) and len(index) <= 64, "snapshot index bound")
            snapshots = {}
            for path, row in index.items():
                need(isinstance(row, dict) and set(row) == {"descriptorPath", "rawPath", "descriptorHash"}, "snapshot index shape")
                snapshots[path] = (read(_package_path(args.snapshot_index.parent.resolve(), row["descriptorPath"]), 65536),
                    read(_package_path(args.snapshot_index.parent.resolve(), row["rawPath"]), 1048576), row["descriptorHash"])
            result = build_authority_package(args.source, args.source_manifest_hash, read(args.requests, 524288),
                read(args.selection, 524288), snapshots, request_hash=args.request_hash, selection_hash=args.selection_hash,
                profile_hash=args.profile_hash, disclosure=args.disclosure)
            write_package(result, args.directory)
        print(result.manifest_hash)
    except (MuseumError, OSError) as exc: p.exit(2, str(exc) + "\n")


if __name__ == "__main__": main()
