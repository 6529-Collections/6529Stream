"""Typed native source joins for an independently verified object-dossier state.

Successful replay verifies each concrete reader's bounded facts. It does not
turn a caller-selected host roster into every applicable protocol host, or turn
synthetic transport evidence into an actual-chain acceptance result.
"""
from pathlib import Path

from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, _paths
from .canonical import dumps, hex_bytes, keccak256, loads, subject_id, uint
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .independent_wire import require
from .object_dossier_components import validate_source_state

PROFILE = "STREAM_MUSEUM_OBJECT_DOSSIER_NATIVE_INPUTS_V1"
REPORT_PROFILE = "STREAM_MUSEUM_OBJECT_DOSSIER_NATIVE_JOINS_V1"
KINDS = ("owner", "independent", "ownership", "metadata", "hosts")
MAX_SOURCES = 128
ROW_FIELDS = {"id", "kind", "provenance", "anchorPath", "anchorHash", "transcriptPath",
              "transcriptHash", "snapshotPath", "snapshotHash"}
REQUIREMENTS = ("OD-OWNER-LANE-COMPLETE", "OD-OWNER-LANE-HEADS", "OD-INDEPENDENT-LANE-COMPLETE",
                "OD-INDEPENDENT-LANE-HEADS", "OD-TOKEN-LANE-COMPLETE", "OD-TOKEN-LANE-HEADS",
                "OD-TRANSFER-PROVENANCE")
CLAIMS = {"typedNativeSourcesReplayed": True, "allOriginalOccurrencesRetained": True,
          "globalApplicableHostsComplete": False, "completeCanonicalData": False,
          "fullObjectDossierConformance": False, "actualChainAcceptance": False,
          "legalTitleProven": False, "consensusProof": False, "networkFetch": False}
QUALIFICATION = ("Concrete source readers are replayed against one independently verified source state. "
    "Synthetic sources remain synthetic. Complete per-host lanes and current registered-host coverage "
    "do not establish all applicable historical or unregistered hosts, semantic interpretation, "
    "covering event archives, title correspondence, legal title or complete OBJECT_DOSSIER_V1 conformance.")
PROFILE_BYTES = dumps({"name": REPORT_PROFILE, "version": "1", "inputProfile": PROFILE,
    "status": "prospective_unregistered_assembly_profile", "sourceKinds": list(KINDS),
    "bounds": {"sources": str(MAX_SOURCES), "inputBytes": str(MAX_BYTES)},
    "scopeRules": {"owner": "exact token", "independent": "exact collection or separate deployment scope zero",
        "metadata": "exact nonzero collection", "ownership": "exact Core/token/collection/serial",
        "hosts": "current registered roster and selected metadata; global exhaustiveness unresolved"},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _classes():
    from .owner_catalog_source import OwnerCatalogSource
    from .independent_catalog_source import IndependentCatalogSource
    from .ownership_source import OwnershipSource
    from .metadata_catalog_source import MetadataCatalogSource
    from .dossier_hosts_source import DossierHostsSource
    return dict(zip(KINDS, (OwnerCatalogSource, IndependentCatalogSource, OwnershipSource,
                            MetadataCatalogSource, DossierHostsSource)))


def validate_reference(reference):
    require(type(reference) is dict and set(reference) == {"sourceState", "sourceAnchor", "coreFacts", "rpcReadPins"},
            "native join reference shape")
    validate_source_state(reference["sourceState"])
    a = reference["sourceAnchor"]
    require(type(a) is dict and set(a) == {"timestamp", "stateRoot", "environment",
            "deploymentEvidenceHash", "coreRuntimeHash", "runtimePins"}, "native join reference anchor shape")
    uint(a["timestamp"], 64)
    require(a["environment"] in ("local_evm_fixture", "public_chain"), "native join reference environment")
    for key in ("stateRoot", "deploymentEvidenceHash", "coreRuntimeHash"):
        require(any(hex_bytes(a[key], 32)), "native join reference commitment")
    require(type(a["runtimePins"]) is list and 0 < len(a["runtimePins"]) <= 4096,
            "native reference runtime pin count")
    pins = {}
    for pin in a["runtimePins"]:
        require(type(pin) is dict and set(pin) == {"address", "runtimeHash"}
                and any(hex_bytes(pin["address"], 20)) and any(hex_bytes(pin["runtimeHash"], 32))
                and pin["address"] not in pins, "native reference runtime pin shape/duplicate")
        pins[pin["address"]] = pin["runtimeHash"]
    require(pins.get(reference["sourceState"]["core"]) == a["coreRuntimeHash"], "native reference Core pin differs")
    facts = reference["coreFacts"]
    require(type(facts) is dict and set(facts) == {"lifecycle", "burned", "owner"}
            and facts["lifecycle"] in ("2", "3") and type(facts["burned"]) is bool
            and facts["burned"] == (facts["lifecycle"] == "3"), "native reference lifecycle differs")
    owner = hex_bytes(facts["owner"], 20)
    require(bool(any(owner)) == (facts["lifecycle"] == "2"), "native reference owner/lifecycle differs")
    require(type(reference["rpcReadPins"]) is list and len(reference["rpcReadPins"]) <= 100000,
            "native reference RPC pin bound")
    keys = set()
    for pin in reference["rpcReadPins"]:
        require(type(pin) is dict and set(pin) == {"requestHash", "resultHash"}
                and any(hex_bytes(pin["requestHash"], 32)) and any(hex_bytes(pin["resultHash"], 32))
                and pin["requestHash"] not in keys, "native reference RPC pin shape/duplicate")
        keys.add(pin["requestHash"])
    return reference


def reference_from_originals(state, originals):
    """Use only after the containing actual-token fixture has been verified."""
    a = loads(originals["anchor.json"], maximum=524288, canonical=True)
    pins = {p["address"]: p["runtimeHash"] for p in a["codePins"]}
    require(all(a[k] == state[k] for k in ("chainId", "core", "blockNumber", "blockHash")),
            "native reference original source mismatch")
    require(a["deploymentEvidenceHash"] == keccak256(originals["deployment-evidence.json"]),
            "native reference original deployment differs")
    from .token_fixture import _decode_view
    evidence = loads(originals["deployment-evidence.json"], maximum=MAX_BYTES, canonical=True)
    views = evidence["tokenSourceBlockViews"]
    def view(name):
        return _decode_view(views[name], name, uint(state["tokenId"]), state["core"], state["blockHash"])
    identity = view("tokenCollectionIdentity")
    lifecycle, = view("tokenLifecycle")
    owner, = view("ownerOf")
    require(identity[:3] == (True, uint(state["collectionId"]), uint(state["collectionSerial"])),
            "native reference original Core identity differs")
    transcript = loads(originals["transcript.json"], maximum=MAX_TRANSCRIPT, canonical=True)
    read_pins = {}
    _merge_rpc_results(transcript["calls"], read_pins)
    return validate_reference({"sourceState": state, "sourceAnchor": {
        **{k: a[k] for k in ("timestamp", "stateRoot", "environment", "deploymentEvidenceHash")},
        "coreRuntimeHash": pins[state["core"]], "runtimePins": a["codePins"]},
        "coreFacts": {"lifecycle": str(lifecycle), "burned": identity[3], "owner": owner},
        "rpcReadPins": [{"requestHash": key, "resultHash": value} for key, value in sorted(read_pins.items())]})


def _envelope(raw, expected_hash, files, reference):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST
            and any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            "native envelope external commitment/bound differs")
    envelope = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(envelope) is dict and set(envelope) == {"profile", "version", "disclosure", "sourceState", "sources"}
            and envelope["profile"] == PROFILE and envelope["version"] == "1"
            and envelope["disclosure"] == "public", "native envelope shape/disclosure")
    require(envelope["sourceState"] == reference["sourceState"], "native envelope reference state differs")
    require(type(files) is dict and all(type(k) is str and type(v) is bytes for k, v in files.items())
            and len(files) <= MAX_FILES and len(raw) + sum(map(len, files.values())) <= MAX_BYTES,
            "native source files/aggregate bound")
    _paths(files)
    rows = envelope["sources"]
    require(type(rows) is list and len(rows) <= MAX_SOURCES, "native source count bound")
    ids, paths = [], []
    for row in rows:
        require(type(row) is dict and set(row) == ROW_FIELDS and type(row["id"]) is str
                and row["id"] and len(row["id"]) <= 128 and row["id"].isascii()
                and all(c.isalnum() or c in "_-" for c in row["id"])
                and row["kind"] in KINDS and row["provenance"] in ("synthetic_fixture", "trusted_rpc"),
                "native source row shape/kind/provenance")
        ids.append(row["id"])
        for label, bound in (("anchor", 524288), ("transcript", MAX_TRANSCRIPT), ("snapshot", MAX_BYTES)):
            path, digest = row[label + "Path"], row[label + "Hash"]
            require(type(path) is str and path in files and 0 < len(files[path]) <= bound
                    and any(hex_bytes(digest, 32)) and keccak256(files[path]) == digest,
                    "native original " + label + " bytes/pin differs")
            paths.append(path)
    require(ids == sorted(set(ids)), "native source ids must be sorted/unique")
    _paths(paths)
    require(set(paths) == set(files), "native original file inventory differs")
    return envelope


def _join_anchor(kind, a, reference, shared_pins):
    state, ref = reference["sourceState"], reference["sourceAnchor"]
    for key in ("chainId", "core", "blockNumber", "blockHash"):
        require(a.get(key) == state[key], "native common source identity differs: " + key)
    for key in ("timestamp", "stateRoot", "environment", "deploymentEvidenceHash"):
        require(a.get(key) == ref[key], "native common source anchor differs: " + key)
    if kind in ("owner", "ownership", "hosts"):
        require(a.get("tokenId") == state["tokenId"], "native exact token differs")
    if kind in ("ownership", "metadata", "hosts"):
        require(a.get("collectionId") == state["collectionId"], "native exact collection differs")
    if kind == "independent":
        require(a.get("scopeKey") in ("0", state["collectionId"]), "native unrelated independent scope")
    pins = {a["core"]: a["coreRuntimeHash"]} if kind in ("ownership", "hosts") else {
        p["address"]: p["runtimeHash"] for p in a["codePins"]}
    require(pins.get(state["core"]) == ref["coreRuntimeHash"], "native common Core runtime differs")
    for address, digest in pins.items():
        require(address not in shared_pins or shared_pins[address] == digest,
                "native shared address runtime conflict")
        shared_pins[address] = digest


def _source_key(kind, a):
    if kind in ("ownership", "hosts"):
        return kind, a["core"], a["tokenId"]
    return kind, a["host"], a["tokenId"] if kind == "owner" else a[
        "scopeKey" if kind == "independent" else "collectionId"]


def _merge_observed_code(source, shared_pins):
    """Join actual read results, not historical registry expected code hashes."""
    for row in source.reader.rows:
        if row["method"] != "eth_getCode":
            continue
        address, block = row["params"]
        require(block == {"blockHash": source.a["blockHash"], "requireCanonical": True},
                "native observed code source block differs")
        digest = keccak256(hex_bytes(row["result"]))
        require(address not in shared_pins or shared_pins[address] == digest,
                "native observed shared runtime conflict")
        shared_pins[address] = digest


def _merge_rpc_results(rows, shared_reads):
    """Identical read-only RPC requests at one source cannot have two results."""
    for row in rows:
        key = keccak256(dumps([row["method"], row["params"]]))
        digest = keccak256(dumps(row["result"]))
        require(key not in shared_reads or shared_reads[key] == digest,
                "native identical RPC request has conflicting results")
        shared_reads[key] = digest


def _occurrences(source, report, state):
    kind, a, row = source["kind"], source["anchor"], source["input"]
    if kind not in ("owner", "independent", "metadata"):
        return [], []
    scope = a["tokenId"] if kind == "owner" else a["scopeKey" if kind == "independent" else "collectionId"]
    collection_subject = subject_id("collection", state["chainId"], state["core"], state["collectionId"])
    occurrences, positions = [], set()
    for ordinal, record in enumerate(report["records"]):
        wire, receipt = record["record"], record["receipt"]
        index = receipt[3 if kind == "owner" else 4]
        position = (wire[0], index)
        require(position not in positions, "native repeated lane index")
        positions.add(position)
        relation = ("exact_token" if wire[1] == state["subjectId"] else
                    "collection_context" if wire[1] == collection_subject else "other_subject_context")
        occurrences.append({"sourceId": row["id"], "kind": kind, "host": a["host"],
            "scopeKey": scope, "recordType": wire[0], "index": index, "recordHash": record["recordHash"],
            "subjectId": wire[1], "subjectRelation": relation, "originalSnapshotPath": row["snapshotPath"],
            "originalSelector": "/records/" + str(ordinal)})
    lanes = [{"sourceId": row["id"], "kind": kind, "host": a["host"], "scopeKey": scope,
              "originalSnapshotPath": row["snapshotPath"], "originalSelector": "/lanes/" + str(i),
              "originalLane": lane} for i, lane in enumerate(report["lanes"])]
    return occurrences, lanes


def _coverage(sources, state):
    catalogs = {_source_key(s["kind"], s["anchor"]): s for s in sources if s["kind"] in ("owner", "independent", "metadata")}
    roster = next((s for s in sources if s["kind"] == "hosts"), None)
    rows, included = [], set()
    if roster is not None:
        for host in roster["snapshot"]["hosts"]:
            if host["resolution"] == "foreign_core":
                continue
            for scope in host["scopes"]:
                key = (host["kind"], host["host"], scope)
                require(key not in included, "native duplicate roster host/scope")
                included.add(key)
                source = catalogs.get(key)
                supported = host["supported"] and host["runtimeMatches"]
                status = "unsupported_host" if not supported else "missing_source" if source is None else (
                    "synthetic_only" if source["provenance"] == "synthetic_fixture" or roster["provenance"] == "synthetic_fixture"
                    else "verified_within_registered_roster")
                if source is not None:
                    require(supported, "native supplied catalogue claims unsupported roster host")
                    pins = {p["address"]: p["runtimeHash"] for p in source["anchor"]["codePins"]}
                    require(pins[host["host"]] == host["runtimeHash"], "native roster/source runtime differs")
                    if host["kind"] in ("metadata", "independent"):
                        observed = {lane["recordType"]: (lane["chainHash"], lane["count"])
                                    for lane in source["snapshot"]["lanes"]}
                        expected = {lane["recordType"]: (lane["chainHash"], lane["count"])
                                    for lane in host["catalog"]["scopeHeads"] if lane["scopeKey"] == scope}
                        require(expected == observed, "native roster/source full lane inventory differs")
                        if host["kind"] == "metadata":
                            policies = {p["recordType"]: (p["family"], p["authorizationMask"])
                                        for p in source["snapshot"]["catalog"]}
                            expected_policies = {p["recordType"]: (p["family"], p["authorizationMask"])
                                for p in host["catalog"]["scopeHeads"] if p["scopeKey"] == scope}
                            require(policies == expected_policies, "native roster/source policy differs")
                rows.append({"host": host["host"], "kind": host["kind"], "scopeKey": scope,
                    "status": status, "sourceId": None if source is None else source["input"]["id"],
                    "rosterSourceId": roster["input"]["id"], "registryStatus": host["status"]})
    for key, source in sorted(catalogs.items()):
        if key not in included:
            rows.append({"host": key[1], "kind": key[0], "scopeKey": key[2],
                "status": "synthetic_only" if source["provenance"] == "synthetic_fixture" else "verified_host_outside_observed_roster",
                "sourceId": source["input"]["id"], "rosterSourceId": None, "registryStatus": None})
    return rows, roster


def admit(raw, expected_hash, files, reference):
    """Replay typed bundles; reference must come from verified actual source evidence."""
    validate_reference(reference)
    envelope = _envelope(raw, expected_hash, files, reference)
    classes = _classes()
    shared_pins = {p["address"]: p["runtimeHash"] for p in reference["sourceAnchor"]["runtimePins"]}
    shared_reads = {p["requestHash"]: p["resultHash"] for p in reference["rpcReadPins"]}
    sources, seen, occurrences, lanes = [], set(), [], []
    for row in envelope["sources"]:
        source = classes[row["kind"]](files[row["anchorPath"]],
            ReplayTransport(files[row["transcriptPath"]], row["transcriptHash"]), provenance=row["provenance"])
        a = source.a
        _join_anchor(row["kind"], a, reference, shared_pins)
        snapshot = source.snapshot()
        require(snapshot == files[row["snapshotPath"]] and source.transcript() == files[row["transcriptPath"]],
                "native typed source replay differs")
        _merge_observed_code(source, shared_pins)
        _merge_rpc_results(source.reader.rows, shared_reads)
        key = _source_key(row["kind"], a)
        require(key not in seen, "native duplicate logical source")
        seen.add(key)
        result = loads(snapshot, maximum=MAX_BYTES, canonical=True)
        if row["kind"] in ("ownership", "hosts"):
            identity = result["identity"] if row["kind"] == "ownership" else result["sourceState"]
            require(identity["collectionSerial"] == reference["sourceState"]["collectionSerial"],
                    "native observed collection serial differs")
            if row["kind"] == "ownership":
                require(identity["lifecycle"] == reference["coreFacts"]["lifecycle"]
                        and identity["owner"] == reference["coreFacts"]["owner"], "native observed Core lifecycle/owner differs")
            else:
                require(identity["burned"] == reference["coreFacts"]["burned"], "native observed Core burn identity differs")
        item = {"kind": row["kind"], "anchor": a, "input": row, "snapshot": result, "provenance": row["provenance"]}
        found, heads = _occurrences(item, result, reference["sourceState"])
        occurrences.extend(found); lanes.extend(heads); sources.append(item)
    coverage, roster = _coverage(sources, reference["sourceState"])
    checks = [{"sourceId": s["input"]["id"], "kind": s["kind"],
               "status": "synthetic_only" if s["provenance"] == "synthetic_fixture" else "verified_within_source_profile",
               "anchorHash": s["input"]["anchorHash"], "snapshotHash": s["input"]["snapshotHash"],
               "selector": "/", "originalClaims": s["snapshot"]["claims"]} for s in sources]
    unresolved = ["host_inventory_not_exhaustive", "historical_registry_inventory_unresolved",
        "additional_token_attestation_hosts_unresolved", "covering_protocol_event_archive_missing",
        "title_binding_inventory_unresolved"]
    if roster is None:
        unresolved.append("registered_host_roster_missing")
    for kind in KINDS:
        if not any(s["kind"] == kind for s in sources):
            unresolved.append(kind + "_source_missing")
    return dumps({"profile": REPORT_PROFILE, "profileHash": PROFILE_HASH, "version": "1",
        "inputHash": expected_hash, "reference": reference, "checks": checks,
        "scopeCoverage": coverage, "occurrences": occurrences, "laneWitnesses": lanes,
        "requirements": [{"code": code, "status": "unresolved",
            "reasons": ["covering_protocol_event_archive_missing", "title_binding_inventory_unresolved"]
                if code == "OD-TRANSFER-PROVENANCE" else ["host_inventory_not_exhaustive"]} for code in REQUIREMENTS],
        "unresolved": sorted(set(unresolved)), "claims": CLAIMS, "qualification": QUALIFICATION})


def definitions(directory, *, check=False):
    target = Path(directory) / "native-joins-profile.json"
    if check:
        require(target.is_file() and target.read_bytes() == PROFILE_BYTES, "native joins profile differs")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH
