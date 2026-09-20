"""Gather actual-token evidence and replayed native sources into one offline examination package.

This is an exporter of original evidence and derived fields. It never fills an
unknown canonical packet field with a claimed absence or a caller assertion.
"""
from pathlib import Path

from . import object_dossier as base
from . import object_dossier_native as native
from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, _paths, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads, subject_id
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .citations_v2 import (PROFILE_BYTES as CITATION_PROFILE_BYTES, PROFILE_HASH as CITATION_PROFILE_HASH,
    SCHEMA_BYTES as CITATION_SCHEMA_BYTES, canonical_citation, parse_citation)
from .independent_wire import ZERO, require

MODE = "source_gathered_token_examination"
PROFILE = "STREAM_MUSEUM_DOSSIER_GATHER_V1"
INPUT_PROFILE = "STREAM_MUSEUM_DOSSIER_GATHER_INPUTS_V1"
KINDS = (*native.KINDS, "general", "inventory", "citation")
QUALIFICATION = ("Original actual-token fixture and scoped semantic bag are replayed unchanged. "
    "Additional native sources retain caller-admitted provenance and exact native scopes. "
    "The package gathers evidence and derives fields; it is not a complete canonical acquisition packet, "
    "full object dossier, consensus proof, legal title determination or institutional acceptance.")
CLAIMS = {"actualTokenFixtureReplayed": True, "originalSourceBytesRetained": True,
    "typedNativeSourcesReplayed": True, "syntheticEvidencePromoted": False,
    "globalApplicableHostsComplete": False, "canonicalAcquisitionPacketEmitted": False,
    "fullObjectDossierConformance": False, "sourceConsensusVerified": False,
    "institutionalAcceptance": False, "networkFetch": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "inputProfile": INPUT_PROFILE, "sourceKinds": list(KINDS), "citationProfileHash": CITATION_PROFILE_HASH,
    "limits": {"sources": str(native.MAX_SOURCES), "files": str(MAX_FILES), "bytes": str(MAX_BYTES)},
    "scope": "One actual retained token fixture, complete finite histories of explicitly admitted native sources and exact extracted occurrence bytes.",
    "joins": "Exact original identity/block, shared runtime pins and repeated RPC results; legacy inventory does not declare environment or deploymentEvidenceHash.",
    "completeness": "All 19 canonical packet items remain visible. Unknown source fields never become absent, waived, none or complete. Unsupported full-packet export rejects.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)
TOOL_NAMES = ("dossier_gather.py", "dossier_gather_records.py", "citations_v2.py", "canonical_citation_source.py")


def _public(disclosure):
    require(disclosure == "public", "gather requires explicit public disclosure before source reads")


def prepare_inputs(state, captures, *, disclosure, provenance):
    """Create a pinned read plan from exact capture triplets; build performs source replay.

    state is the original fixture's derived sourceState. This operation records
    explicit caller provenance; it does not authenticate the origin of files.
    """
    _public(disclosure)
    require(provenance in ("synthetic_fixture", "trusted_rpc"), "gather plan explicit source provenance required")
    base._bounded(captures)
    from . import owner_catalog_source, independent_catalog_source, metadata_catalog_source
    from . import ownership_source, dossier_hosts_source, general_attestation_source, general_attestation_source_v2
    from . import object_inventory_source, canonical_citation_source
    profiles = {module.PROFILE: kind for kind, module in (
        ("owner", owner_catalog_source), ("independent", independent_catalog_source), ("metadata", metadata_catalog_source),
        ("ownership", ownership_source), ("hosts", dossier_hosts_source), ("general", general_attestation_source),
        ("general", general_attestation_source_v2), ("inventory", object_inventory_source), ("citation", canonical_citation_source))}
    ids = set()
    for path in captures:
        parts = path.split("/")
        require(len(parts) == 2 and parts[1] in ("anchor.json", "transcript.json", "snapshot.json"),
            "gather captures require id/anchor.json, transcript.json and snapshot.json only")
        ids.add(parts[0])
    rows = []
    for identifier in sorted(ids):
        paths = {name: identifier + "/" + name + ".json" for name in ("anchor", "transcript", "snapshot")}
        require(set(paths.values()) <= captures.keys(), "gather capture triplet incomplete")
        profile = loads(captures[paths["anchor"]], maximum=524288, canonical=True).get("profile")
        require(profile in profiles, "gather capture profile unsupported")
        row = {"id": identifier, "kind": profiles[profile], "provenance": provenance}
        for name, path in paths.items():
            row[name + "Path"], row[name + "Hash"] = path, keccak256(captures[path])
        rows.append(row)
    raw = dumps({"profile": INPUT_PROFILE, "version": "1", "disclosure": "public", "sourceState": state, "sources": rows})
    # Reuse the complete shape, aggregate and path checks without claiming replay.
    _inputs(raw, keccak256(raw), captures, {"sourceState": state})
    return {"inputs.json": raw, **{"data/" + p: b for p, b in captures.items()}}


def _inputs(raw, expected_hash, files, reference):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST
        and any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "gather input external pin/bound differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"profile", "version", "disclosure", "sourceState", "sources"}
        and value["profile"] == INPUT_PROFILE and value["version"] == "1"
        and value["sourceState"] == reference["sourceState"], "gather input shape/source state differs")
    _public(value["disclosure"])
    base._bounded(files)
    require(len(raw) + sum(map(len, files.values())) <= MAX_BYTES, "gather input aggregate bound")
    rows = value["sources"]
    require(type(rows) is list and len(rows) <= native.MAX_SOURCES, "gather source count bound")
    ids, paths = [], []
    for row in rows:
        require(type(row) is dict and set(row) == native.ROW_FIELDS and type(row["id"]) is str
            and 0 < len(row["id"]) <= 128 and row["id"].isascii()
            and row["id"] != "retained-token-fixture"
            and all(c.isalnum() or c in "_-" for c in row["id"])
            and row["kind"] in KINDS and row["provenance"] in ("synthetic_fixture", "trusted_rpc"),
            "gather source row shape/kind/provenance")
        ids.append(row["id"])
        for name, limit in (("anchor", 524288), ("transcript", MAX_TRANSCRIPT), ("snapshot", MAX_BYTES)):
            path, digest = row[name + "Path"], row[name + "Hash"]
            require(type(path) is str and path in files and 0 < len(files[path]) <= limit
                and any(hex_bytes(digest, 32)) and keccak256(files[path]) == digest,
                "gather original " + name + " bytes/pin differs")
            paths.append(path)
    require(ids == sorted(set(ids)), "gather source ids must be sorted/unique")
    _paths(paths)
    require(set(paths) == set(files), "gather exact original source file set differs")
    return value


def _reader(row, files):
    raw = files[row["anchorPath"]]
    transport = ReplayTransport(files[row["transcriptPath"]], row["transcriptHash"])
    if row["kind"] in native.KINDS:
        constructor = native._classes()[row["kind"]]
    elif row["kind"] == "general":
        from .general_attestation_source import GeneralAttestationSource, PROFILE as V1
        from .general_attestation_source_v2 import GeneralAttestationSourceV2, PROFILE as V2
        profile = loads(raw, maximum=524288, canonical=True).get("profile")
        require(profile in (V1, V2), "gather exact General source profile required")
        constructor = GeneralAttestationSource if profile == V1 else GeneralAttestationSourceV2
    elif row["kind"] == "inventory":
        from .object_inventory_source import NativeInventorySource
        constructor = NativeInventorySource
    else:
        from .canonical_citation_source import CanonicalCitationSource
        constructor = CanonicalCitationSource
    return constructor(raw, transport, provenance=row["provenance"])


def _join(source, kind, reference, shared_pins):
    a, state, anchor = source.a, reference["sourceState"], reference["sourceAnchor"]
    if kind != "inventory":
        native._join_anchor(kind, a, reference, shared_pins)
        if kind in ("general", "citation"):
            require(a["collectionId"] == state["collectionId"], "gather source collection differs")
        if kind == "citation":
            require(a["tokenId"] == state["tokenId"], "gather citation token differs")
        return []
    # This immutable older profile has no environment/deployment-evidence field.
    # Do not add those fields to its source or imply that it authenticated them.
    for key in ("chainId", "blockHash", "blockNumber", "collectionId"):
        require(a[key] == state[key], "gather inventory source differs: " + key)
    for key in ("timestamp", "stateRoot"):
        require(a[key] == anchor[key], "gather inventory anchor differs: " + key)
    require(source.pins.get(state["core"]) == anchor["coreRuntimeHash"], "gather inventory Core pin differs")
    for address, digest in source.pins.items():
        require(address not in shared_pins or shared_pins[address] == digest,
            "gather inventory shared runtime conflict")
        shared_pins[address] = digest
    return ["environment", "deploymentEvidenceHash"]


def _logical_key(kind, a):
    if kind in native.KINDS:
        return native._source_key(kind, a)
    if kind == "general":
        return kind, a["host"], a["collectionId"]
    if kind == "inventory":
        return kind, a["producer"], a["collectionId"]
    return kind, a["core"], a["tokenId"]


def _replay_sources(raw, expected_hash, files, reference):
    """Internal join: the public gatherer derives reference from its verified fixture."""
    native.validate_reference(reference)
    value = _inputs(raw, expected_hash, files, reference)
    shared_pins = {p["address"]: p["runtimeHash"] for p in reference["sourceAnchor"]["runtimePins"]}
    shared_reads = {p["requestHash"]: p["resultHash"] for p in reference["rpcReadPins"]}
    sources, seen = [], set()
    for row in value["sources"]:
        source = _reader(row, files)
        missing = _join(source, row["kind"], reference, shared_pins)
        key = _logical_key(row["kind"], source.a)
        require(key not in seen, "gather duplicate logical source")
        seen.add(key)
        snapshot = source.snapshot()
        require(snapshot == files[row["snapshotPath"]] and source.transcript() == files[row["transcriptPath"]],
            "gather original source replay differs")
        native._merge_observed_code(source, shared_pins)
        native._merge_rpc_results(source.reader.rows, shared_reads)
        decoded = loads(snapshot, maximum=MAX_BYTES, canonical=True)
        if row["kind"] in ("ownership", "hosts", "citation"):
            identity = decoded["sourceState"] if row["kind"] == "hosts" else decoded["identity"]
            require(identity["collectionSerial"] == reference["sourceState"]["collectionSerial"],
                "gather original collection serial differs")
            if row["kind"] == "ownership":
                require(identity["lifecycle"] == reference["coreFacts"]["lifecycle"]
                    and identity["owner"] == reference["coreFacts"]["owner"], "gather original lifecycle/owner differs")
            elif row["kind"] == "citation":
                require(identity["lifecycle"] == reference["coreFacts"]["lifecycle"]
                    and identity["burned"] == reference["coreFacts"]["burned"]
                    and identity["collectionId"] == reference["sourceState"]["collectionId"]
                    and identity["tokenId"] == reference["sourceState"]["tokenId"], "gather citation Core facts differ")
            else:
                require(identity["burned"] == reference["coreFacts"]["burned"], "gather original burn state differs")
        if row["kind"] == "inventory":
            require(decoded["core"] == reference["sourceState"]["core"]
                and any(t["tokenId"] == reference["sourceState"]["tokenId"] for t in decoded["tokens"]),
                "gather inventory original Core/token membership differs")
        sources.append({"id": row["id"], "kind": row["kind"], "anchor": source.a,
            "snapshot": decoded, "provenance": row["provenance"], "input": row,
            "undeclaredAnchorFields": missing,
            "readerProfileBytes": _reader_profile(source)})
    coverage, _ = native._coverage(sources, reference["sourceState"])
    return sources, coverage


def _reader_profile(source):
    # The constructor comes exclusively from _reader's closed dispatch above.
    # Never import code named by an input, a payload or an archived tool file.
    import sys
    return sys.modules[type(source).__module__].PROFILE_BYTES


def _citation_files(sources):
    files, index = {}, []
    for source in sources:
        if source["kind"] != "citation":
            continue
        snap = source["snapshot"]
        groups = [("fin", snap["finality"]),
            ("snap", [] if snap["snapshots"] is None else snap["snapshots"]["selected"]),
            ("rec", [] if snap["recovery"] is None else snap["recovery"]["records"])]
        for kind, rows in groups:
            for i, row in enumerate(rows):
                raw = hex_bytes(row["manifestBytes"])
                if not raw:
                    continue
                path = f"citation/sources/{source['id']}/{kind}/{i:04d}/manifest.bin"
                files[path] = raw
                original = path.rsplit("/", 1)[0] + "/record.json"
                files[original] = dumps(row)
                chunks = []
                offset = 0
                for n, descriptor in enumerate(row.get("chunks", [])):
                    size = int(descriptor["length"])
                    part = raw[offset:offset + size]
                    require(len(part) == size and keccak256(part) == descriptor["chunkHash"], "gather citation chunk differs")
                    chunk_path = path.rsplit("/", 1)[0] + f"/chunks/{n:04d}.bin"
                    files[chunk_path] = part
                    chunks.append({"path": chunk_path, "original": descriptor})
                    offset += size
                if "chunks" in row:
                    require(offset == len(raw), "gather citation chunk closure differs")
                index.append({"sourceId": source["id"], "kind": kind, "manifestHash": keccak256(raw),
                    "path": path, "originalRecordPath": original, "chunks": chunks})
    base._bounded(files)
    return files, index


def _citation_choices(reference, sources):
    state = reference["sourceState"]
    work = canonical_citation(state["chainId"], state["core"], state["tokenId"])
    original = parse_citation(state["canonicalCitation"], require_state=True)
    choices = [{"sourceId": "retained-token-fixture", **original["qualifier"],
        "citation": state["canonicalCitation"], "basis": "original_replayed_scoped_semantic_lane"}]
    for source in sources:
        kind, a, result = source["kind"], source["anchor"], source["snapshot"]
        if kind in ("owner", "metadata", "independent", "general"):
            scope = a["tokenId"] if kind == "owner" else a["scopeKey"] if kind == "independent" else a["collectionId"]
            for i, lane in enumerate(result["lanes"]):
                digest = lane.get("head", lane.get("chainHash"))
                if digest == ZERO:
                    continue
                qualifier = {"kind": "chain", "hash": digest}
                choices.append({"sourceId": source["id"], **qualifier,
                    "citation": canonical_citation(state["chainId"], state["core"], state["tokenId"], qualifier),
                    "host": a["host"], "scopeKey": scope, "recordType": lane["recordType"],
                    "originalSelector": "/lanes/" + str(i), "provenance": source["provenance"],
                    "basis": "complete_admitted_native_lane"})
        elif kind == "citation":
            require(result["originalWorkCitation"] == work, "gather citation original identity differs")
            for qualifier_kind in ("fin", "snap", "rec"):
                for choice in result["choices"][qualifier_kind]:
                    parsed = parse_citation(choice["citation"], require_state=True)
                    require(choice["citation"] == canonical_citation(state["chainId"], state["core"], state["tokenId"],
                        {"kind": qualifier_kind, "hash": choice["hash"]}) and parsed["qualifier"]["kind"] == qualifier_kind,
                        "gather source-derived citation differs")
                    choices.append({"sourceId": source["id"], "kind": qualifier_kind,
                        "hash": choice["hash"], "citation": choice["citation"], "nativeEvidence": choice,
                        "provenance": source["provenance"], "basis": "native_original_record"})
    return {"profileHash": CITATION_PROFILE_HASH, "originalWorkCitation": work,
        "originalFixtureCitation": state["canonicalCitation"], "choices": choices,
        "selection": "Explicitly choose the required original state; no latest, fin-over-rec, or cross-family winner is inferred."}


ITEMS = (
    ("Canonical qualified citation", "Native qualifier choices are provided; renderer output and successor declarations are separately owned."),
    ("Token subject ID", ""),
    ("Finality and token content-root proof", "Complete applicable finality scope and native token content-root inclusion proof reader required."),
    ("Entropy provenance and events", "Coordinator-at-mint leaf plus complete Requested/Finalized event reader required."),
    ("Record-chain heads", "Admitted host lanes are gathered; all historical/unregistered applicable hosts remain unresolved."),
    ("Attribution and personhood", "Canonical current binding/sanction/native status and typed personhood selection reader required."),
    ("Effective collection/token rights", "Historical typed RIGHTS may be gathered; native current selection and token precedence reader required."),
    ("Fixity, preservation coverage and masters", "Mode-total current coverage, deadlines, script environments and master selection reader required."),
    ("Accession legal instrument", "Exact adopted ACCESSION instrument selection required; no legal title inferred."),
    ("Ownership and title provenance", "Core transfers are gathered when supplied; covering protocol event archive and TITLE_BINDING interpretation required."),
    ("Latest script preservation drill", "Applicable drill, acceptance policy and render outcome reader required."),
    ("Work-description tombstone", "Native selected tombstone and authenticated absence reader required."),
    ("Conservation tier, intent and interview", "Selected original conservation/waiver/interview/tier payload and authority joins required."),
    ("C2PA provenance", "Selected native C2PA and validation-report correspondence reader required."),
    ("Condition examinations", "Original reports may be gathered; complete current selection and capture-byte closure required."),
    ("Accompanying dossier bag", "Retained scoped semantic bag is available; complete accompanying object-dossier bag is not emitted."),
    ("Post-finality recovery lineage", "Executed citation lineage may be gathered; all scheduled/executed applicable recoveries and owner response joins required."),
    ("Platform sustainability", "Funding/floor, latest state-export age and zero-signer museum-drill reader required."),
    ("Sole ERC-721 identity", ""))


def _packet(reference, sources, gathered, citations):
    state = reference["sourceState"]
    identity = {"core": state["core"], "collectionId": state["collectionId"], "globalTokenId": state["tokenId"],
        "catalogNumber": state["tokenId"], "collectionSerial": state["collectionSerial"]}
    native_sources = [{"sourceId": s["id"], "kind": s["kind"], "provenance": s["provenance"],
        "snapshotPath": "sources/" + s["input"]["snapshotPath"],
        "snapshotHash": s["input"]["snapshotHash"], "undeclaredAnchorFields": s["undeclaredAnchorFields"]} for s in sources]
    present = {s["kind"] for s in sources}
    evidence = {1: "citation/choices.json", 2: "/derived/subjectId",
        16: "source/scoped-bag/stream-manifest.json", 19: "/derived/erc721Identity"}
    for item, kinds, path in ((3, {"citation"}, "citation/choices.json"),
            (5, {"metadata", "owner", "independent", "general"}, "gathered/index.json#/heads"),
            (6, {"general"}, "gathered/index.json#/records"),
            (7, {"metadata"}, "gathered/index.json#/typedHistoricalFacts"),
            (9, {"owner"}, "gathered/index.json#/records"),
            (10, {"ownership"}, "gathered/index.json#/ownership"),
            (12, {"metadata"}, "gathered/index.json#/records"),
            (13, {"inventory"}, "gathered/index.json#/renderInventories"),
            (14, {"metadata", "independent"}, "gathered/index.json#/records"),
            (15, {"owner", "independent"}, "gathered/index.json#/typedHistoricalFacts"),
            (17, {"citation"}, "citation/choices.json")):
        if present & kinds:
            evidence[item] = path
    rows = [{"item": str(i), "name": title, "status": "derived" if i in (1, 2, 19) else "unresolved",
        "evidence": [] if i not in evidence else [evidence[i]], "remaining": reason}
        for i, (title, reason) in enumerate(ITEMS, 1)]
    return {"profile": PROFILE, "sourceState": state, "sourceAnchor": reference["sourceAnchor"],
        "derived": {"subjectId": state["subjectId"], "collectionSubjectId": subject_id("collection",
            state["chainId"], state["core"], state["collectionId"]), "erc721Identity": identity,
            "burned": reference["coreFacts"]["burned"], "observedOwner": reference["coreFacts"]["owner"],
            "examinedAt": reference["sourceAnchor"]["timestamp"], "citationChoices": citations},
        "sources": native_sources, "items": rows, "unresolvedItems": [r["item"] for r in rows if r["status"] == "unresolved"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}


def _examination(report):
    d = report["derived"]
    lines = ["# Token acquisition examination", "", report["qualification"], "",
        "Work: `" + d["citationChoices"]["originalWorkCitation"] + "`", "",
        "Source block: `" + report["sourceState"]["blockNumber"] + "` / `" + report["sourceState"]["blockHash"] + "`", "",
        "| Item | Requirement | Status | Remaining evidence |", "| --- | --- | --- | --- |"]
    lines += ["| " + " | ".join((r["item"], r["name"], r["status"], r["remaining"])) + " |" for r in report["items"]]
    lines += ["", "The complete original native records, byte files and per-host heads are in `gathered/index.json`.",
        "Citation choices retain their source and scope in `citation/choices.json`.", ""]
    return "\n".join(lines).encode("utf-8")


def _tools(snapshot=None):
    expected = {"tool/" + name + ".txt" for name in TOOL_NAMES}
    if snapshot is None:
        snapshot = {"tool/" + name + ".txt": Path(__file__).with_name(name).read_bytes().replace(b"\r\n", b"\n") for name in TOOL_NAMES}
    require(type(snapshot) is dict and set(snapshot) == expected, "gather inert tool snapshot set differs")
    for raw in snapshot.values():
        require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST and b"\r" not in raw, "gather inert tool bounds/encoding")
        raw.decode("utf-8")
    return snapshot | {"tool/source-index.json": dumps({"mode": "inert_implementation_provenance",
        "completeRuntimeArchive": False, "files": [base._ref(p, b) for p, b in sorted(snapshot.items())]})}


def gather(retained, retained_hash, source_bundle, source_bundle_hash, source_files, *, disclosure, tool_snapshot=None):
    """Replay actual token source, gather native original bytes and export derived facts."""
    _public(disclosure)
    state, originals, export, bag, ocfl = base._replay(retained, retained_hash)
    reference = native.reference_from_originals(state, originals)
    reads = {p["requestHash"]: p["resultHash"] for p in reference["rpcReadPins"]}
    # The fixture's authenticated Core views are also source-state observations;
    # they live in the deployment evidence rather than the semantic transcript.
    evidence = loads(originals["deployment-evidence.json"], maximum=MAX_BYTES, canonical=True)
    for view in evidence["tokenSourceBlockViews"].values():
        native._merge_rpc_results([{"method": "eth_call", "params": [{"to": view["to"], "data": view["data"]},
            {"blockHash": view["blockHash"], "requireCanonical": True}], "result": view["result"]}], reads)
    for name in ("publication-transcript.json", "interpretation-transcript.json"):
        if name in originals:
            native._merge_rpc_results(loads(originals[name], maximum=MAX_TRANSCRIPT, canonical=True)["calls"], reads)
    reference["rpcReadPins"] = [{"requestHash": k, "resultHash": v} for k, v in sorted(reads.items())]
    sources, coverage = _replay_sources(source_bundle, source_bundle_hash, source_files, reference)
    from .dossier_gather_records import extract
    extracted, gathered = extract(reference, [{k: s[k] for k in ("id", "kind", "anchor", "snapshot", "provenance")} for s in sources])
    citations = _citation_choices(reference, sources)
    citation_files, citations["retainedManifests"] = _citation_files(sources)
    report = _packet(reference, sources, gathered, citations)
    payloads = {"source/retained/" + p: b for p, b in retained.items()}
    payloads.update({"source/scoped-bag/" + p: b for p, b in bag.files})
    payloads.update({"sources/" + p: b for p, b in source_files.items()})
    payloads.update(_tools(tool_snapshot))
    require(not (set(payloads) & set(extracted)), "gather extraction path collision")
    payloads.update(extracted)
    require(not (set(payloads) & set(citation_files)), "gather citation extraction path collision")
    payloads.update(citation_files)
    for source in sources:
        raw = source["readerProfileBytes"]
        payloads["definitions/source-readers/" + keccak256(raw)[2:] + ".json"] = raw
    payloads.update({"inputs/sources.json": source_bundle, "gathered/index.json": dumps(gathered),
        "gathered/registered-host-coverage.json": dumps(coverage), "citation/choices.json": dumps(citations),
        "packet/fields.json": dumps(report), "packet/examination.md": _examination(report),
        "definitions/gather-profile.json": PROFILE_BYTES, "definitions/citation-profile-v2.json": CITATION_PROFILE_BYTES,
        "definitions/citation-schema-v2.json": CITATION_SCHEMA_BYTES})
    base._bounded(payloads)
    manifest = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "sourceState": state, "retainedManifestHash": retained_hash, "sourceBundleHash": source_bundle_hash,
        "scopedBagManifestHash": bag.manifest_hash, "semanticExportManifestHash": export.manifest_hash,
        "originalOcflInventoryHash": ocfl.inventory_hash, "files": [base._ref(p, b) for p, b in sorted(payloads.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "gather manifest bound")
    payloads["manifest.json"] = manifest
    base._bounded(payloads)
    return base.Assembly(tuple(sorted(payloads.items())), manifest, report)


def verify(files, expected_hash):
    """Verify external pin and every file, then rebuild with the original inert sources."""
    files = dict(files); base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "gather external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "sourceState",
        "retainedManifestHash", "sourceBundleHash", "scopedBagManifestHash", "semanticExportManifestHash",
        "originalOcflInventoryHash", "files", "claims", "qualification"} and value["mode"] == MODE
        and value["profile"] == PROFILE and value["version"] == "1" and value["profileHash"] == PROFILE_HASH
        and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION, "gather closed manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "gather original file commitments differ")
    required = {"inputs/sources.json", "gathered/index.json", "packet/fields.json", "citation/choices.json"}
    required.update("source/retained/" + p for p in base.RETENTION_NAMES)
    required.update("tool/" + p + ".txt" for p in TOOL_NAMES)
    require(required <= files.keys(), "gather original reconstruction input missing")
    retained = {p: files["source/retained/" + p] for p in base.RETENTION_NAMES}
    sources = {p[8:]: b for p, b in files.items() if p.startswith("sources/")}
    snapshot = {"tool/" + p + ".txt": files["tool/" + p + ".txt"] for p in TOOL_NAMES}
    rebuilt = gather(retained, value["retainedManifestHash"], files["inputs/sources.json"],
        value["sourceBundleHash"], sources, disclosure="public", tool_snapshot=snapshot)
    require(dict(rebuilt.files) == files, "gather source reconstruction differs")
    return rebuilt


def export_complete_packet(files, expected_hash):
    """An unsupported required field is an error, never a schema-valid absence."""
    result = verify(files, expected_hash)
    unresolved = result.report["unresolvedItems"]
    require(not unresolved, "canonical acquisition packet unavailable; unresolved items: " + ", ".join(unresolved))
    # No current source path can reach this branch. Future producers must add
    # complete original evidence and the canonical emitter together.
    raise ValueError("canonical packet emitter is not available in this profile")


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser("prepare-inputs")
    prepare.add_argument("--fixture", type=Path, required=True)
    prepare.add_argument("--fixture-hash", required=True)
    prepare.add_argument("--captures", type=Path, required=True)
    prepare.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"), required=True)
    prepare.add_argument("--disclosure", required=True)
    prepare.add_argument("--output", type=Path, required=True)
    build = sub.add_parser("build")
    build.add_argument("--fixture", type=Path, required=True)
    build.add_argument("--fixture-hash", required=True)
    build.add_argument("--sources", type=Path, required=True, help="inputs.json plus data/ containing pinned source files")
    build.add_argument("--sources-hash", required=True)
    build.add_argument("--disclosure", required=True)
    build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "complete-packet"):
        command = sub.add_parser(name)
        command.add_argument("directory", type=Path)
        command.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "prepare-inputs":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        _destination(args.output, [args.fixture, args.captures])
        state, *_ = base._replay(read_tree(args.fixture), args.fixture_hash)
        files = prepare_inputs(state, read_tree(args.captures), disclosure=args.disclosure, provenance=args.provenance)
        _publish(files, args.output, [args.fixture, args.captures])
        print(dumps({"sourcesHash": keccak256(files["inputs.json"]),
            "sources": str(len(loads(files["inputs.json"], maximum=MAX_MANIFEST)["sources"])),
            "sourceReplayPerformed": False}).decode("utf-8"))
        return
    if args.command == "build":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        _destination(args.output, [args.fixture, args.sources])
        tree = read_tree(args.sources)
        require("inputs.json" in tree and all(p == "inputs.json" or p.startswith("data/") for p in tree),
            "gather source directory shape")
        result = gather(read_tree(args.fixture), args.fixture_hash, tree["inputs.json"], args.sources_hash,
            {p[5:]: b for p, b in tree.items() if p.startswith("data/")}, disclosure=args.disclosure)
        _publish(dict(result.files), args.output, [args.fixture, args.sources])
    elif args.command == "complete-packet":
        export_complete_packet(read_tree(args.directory), args.manifest_hash)
        return
    else:
        result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "canonicalPacketReady": result.report["canonicalPacketReady"],
        "unresolvedItems": result.report["unresolvedItems"]}).decode("utf-8"))


if __name__ == "__main__":
    main()
