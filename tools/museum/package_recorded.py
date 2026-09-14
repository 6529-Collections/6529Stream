"""Recorded-account v2 packages: original capture bytes and honest format support."""
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256
from .chain_rpc import MAX_TRANSCRIPT
from .package import MAX_BYTES, _package_path
from .package_v2 import CLAIMS, FORMATS, _assemble, _dependencies, _read_package
from .recorded_projection import REPLAY_INPUTS, output_files, replay_source_bytes
from .recorded_selection import project_recorded

PIN_NAMES = ("source", "publication", "interpretation", "profile", "selection", "plan")
CAPTURES = {"source-capture.json": "capture_bytes", "publications.json": "publication_bytes",
            "interpretation.json": "interpretation_bytes"}
INPUT_FILES = (*REPLAY_INPUTS, "deployment-evidence.json", "selection.json", "plan.json", *CAPTURES)
UNSUPPORTED_REASON = ("The recorded account profile admits finite Linked Art v2 projection only. "
    "This format currently requires a synthetic-only source/plan adapter; no recorded adapter is admitted. "
    "Source metadata is not inferred or relabelled to produce this format.")


def _public(disclosure):
    if disclosure != "public":
        raise MuseumError("recorded package requires explicit public classification; restricted export is unsupported")


def build_recorded_directory(directory, *, root, disclosure, **pins):
    """Read only the named capture inputs, with bounds and no output-directory side effects."""
    _public(disclosure)
    directory = Path(directory).resolve()
    inputs, total = {}, 0
    for name in INPUT_FILES:
        path = _package_path(directory, name)
        size = path.stat().st_size
        total += size
        limit = 524288 if name in ("selection.json", "plan.json") else MAX_TRANSCRIPT
        if size > limit or total > MAX_BYTES:
            raise MuseumError("recorded package input byte bound")
        inputs[name] = path.read_bytes()
    return build_recorded_package(inputs, root=root, disclosure=disclosure, **pins)


def build_recorded_package(inputs, *, root, disclosure, source_hash, publication_hash,
                           interpretation_hash, profile_hash, selection_hash, plan_hash,
                           premis_plan_bytes=None, premis_plan_hash=None, premis_profile_hash=None):
    """Replay actual capture evidence; no fixture state or Boolean authority promotion."""
    _public(disclosure)
    inputs = dict(inputs)
    if (set(inputs) != set(INPUT_FILES) or any(type(raw) is not bytes or len(raw) > MAX_TRANSCRIPT
                                             for raw in inputs.values())
            or sum(map(len, inputs.values())) > MAX_BYTES):
        raise MuseumError("recorded package exact input set or byte bound")
    if any(len(inputs[name]) > 524288 for name in ("selection.json", "plan.json")):
        raise MuseumError("recorded package plan byte bound")
    pins = dict(zip(PIN_NAMES, (source_hash, publication_hash, interpretation_hash,
                               profile_hash, selection_hash, plan_hash)))
    for value in pins.values():
        hex_bytes(value, 32)
    root = Path(root).resolve()
    source = replay_source_bytes(root, inputs, source_hash=source_hash, publication_hash=publication_hash,
        interpretation_hash=interpretation_hash, profile_hash=profile_hash)
    # These files are captured originals, not outputs silently regenerated over them.
    for name, attr in CAPTURES.items():
        if inputs[name] != getattr(source, attr):
            raise MuseumError("recorded captured bytes differ from replay: " + name)
    if keccak256(inputs["deployment-evidence.json"]) != source.anchor["deploymentEvidenceHash"]:
        raise MuseumError("recorded deployment evidence differs from anchor")
    if source.state.mode != "recorded_state" or any(r.disclosure != "public" for r in source.state.records):
        raise MuseumError("recorded package cannot disclose restricted source records")
    result = project_recorded(source, inputs["selection.json"], inputs["plan.json"],
        selection_hash=selection_hash, plan_hash=plan_hash)
    requested = (premis_plan_bytes, premis_plan_hash, premis_profile_hash)
    extended = any(v is not None for v in requested)
    if extended and not all(v is not None for v in requested):
        raise MuseumError("recorded PREMIS requires plan and both pins")
    premis_result = None
    if extended:
        from .recorded_premis import project_recorded_premis, PROFILE_BYTES as RECORDED_PREMIS_BYTES
        from .premis import PinnedPremis, PROFILE_BYTES as XSD_BYTES, PROFILE_HASH as XSD_HASH
        premis_result = project_recorded_premis(source, inputs["selection.json"], inputs["plan.json"], premis_plan_bytes,
            selection_hash=selection_hash, plan_hash=plan_hash, premis_plan_hash=premis_plan_hash,
            premis_profile_hash=premis_profile_hash, premis_schema=PinnedPremis(root, XSD_BYTES, profile_hash=XSD_HASH))
        pins.update(premis_plan=premis_plan_hash, premis_profile=premis_profile_hash)
    files = _dependencies(root, recorded=True, premis=extended)
    files.update({"inputs/" + name: raw for name, raw in inputs.items()})
    # These bytes were verified against the registered interpretation by replay_source_bytes.
    for name, (_, raw) in source.profile.documents.items():
        files["definitions/" + name + ".json"] = raw
    files.update({"linked-art/" + name: raw for name, raw in output_files(result).items()})
    files["linked-art/entity-index.json"] = dumps([
        {"id": resource.identifier, "kind": "linked_art", "path": "linked-art/resource-" + str(index) + ".json",
         "expandedPath": "linked-art/expanded-" + str(index) + ".json"}
        for index, resource in enumerate(result.resources)])
    source_evidence = {"mode": "recorded_account_package_evidence", "sourceMode": source.state.mode,
        "environment": source.anchor["environment"], "anchorHash": keccak256(inputs["anchor.json"]),
        "sourceStateHash": source.state.commitment, "sourceCaptureHash": keccak256(source.capture_bytes),
        "publicationHash": keccak256(source.publication_bytes),
        "registeredInterpretationHash": keccak256(source.interpretation_bytes),
        "deploymentEvidenceHash": keccak256(inputs["deployment-evidence.json"]),
        "registeredProfileHash": source.profile_hash,
        "trustModel": "Externally admitted anchor and runtime pins; exact trusted-RPC transcript replay.",
        "deploymentEvidencePolicy": "Original bytes retained and anchor hash checked; independent runtime/deployment admission remains external.",
        "declaredLanesOnly": True, "cryptographicStateProof": False, "consensusFinality": False,
        "humanIdentityEstablished": False, "independentReviewEstablished": False,
        "publicDeploymentAcceptance": False}
    files["reports/source-evidence.json"] = dumps(source_evidence)
    files["reports/disclosure.json"] = dumps({"classification": disclosure,
        "inputClassification": "Explicit operator declaration covering every retained capture input.",
        "restrictedInputPolicy": "Reject before export; no redaction or commitment-only disclosure proof.",
        "records": [{"selector": record.selector.__dict__, "payloadHash": record.payload_hash,
                     "disclosure": record.disclosure} for record in source.state.records]})
    support = [{"format": FORMATS[0], "status": "supported", "profile": "recorded_account",
                "entityIndex": "linked-art/entity-index.json", "report": "linked-art/report.json"}]
    support += [{"format": name, "status": "unsupported", "reasonCode": "recorded_adapter_unavailable",
                 "reason": UNSUPPORTED_REASON} for name in FORMATS[1:]]
    if extended:
        from .canonical import loads
        files["inputs/premis-plan.json"] = premis_plan_bytes
        files["definitions/recorded-premis-profile.json"] = RECORDED_PREMIS_BYTES
        files["premis/report.json"] = premis_result.report
        report = loads(premis_result.report, maximum=67108864)
        support[1] = {"format": FORMATS[1], "status": report["status"], "profile": "recorded_account_premis_v1",
                      "report": "premis/report.json"}
        if premis_result.projection is None:
            support[1]["reasonCode"] = report["reasonCode"]
        else:
            files["premis/premis.xml"] = premis_result.projection.xml
            for name in ("coverage", "provenance", "correspondence"):
                files["premis/" + name + ".json"] = getattr(premis_result.projection, name)
    files["reports/format-support.json"] = dumps({"sourceStateHash": source.state.commitment,
                                                "formats": support})
    return _assemble(root, files, {"mode": "recorded_account_premis_resource_package" if extended else "recorded_account_resource_package", "version": "2",
        "formats": support, "environment": source.anchor["environment"], "disclosure": disclosure,
        "sourceStateHash": source.state.commitment, "pins": pins, "claims": CLAIMS})


def verify_recorded_package(directory, expected_manifest_hash):
    """Reconstruct from the package alone after authenticating its external manifest pin."""
    directory = Path(directory).resolve()
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    extended = manifest.get("mode") == "recorded_account_premis_resource_package"
    pin_names = set(PIN_NAMES) | ({"premis_plan", "premis_profile"} if extended else set())
    if (set(manifest) != {"mode", "version", "formats", "environment", "disclosure",
                         "sourceStateHash", "pins", "claims", "files"}
            or manifest["mode"] not in ("recorded_account_resource_package", "recorded_account_premis_resource_package")
            or manifest["version"] != "2"
            or manifest["claims"] != CLAIMS or not isinstance(manifest["pins"], dict)
            or set(manifest["pins"]) != pin_names):
        raise MuseumError("unsupported recorded package manifest")
    _public(manifest["disclosure"])
    try:
        extra = {} if not extended else {"premis_plan_bytes": files["inputs/premis-plan.json"],
            "premis_plan_hash": manifest["pins"]["premis_plan"], "premis_profile_hash": manifest["pins"]["premis_profile"]}
        rebuilt = build_recorded_package({name: files["inputs/" + name] for name in INPUT_FILES},
            root=directory / "dependencies", disclosure=manifest["disclosure"], **extra,
            **{name + "_hash": manifest["pins"][name] for name in PIN_NAMES})
    except (KeyError, FileNotFoundError) as exc:
        raise MuseumError("recorded package reconstruction input missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files:
        raise MuseumError("recorded package semantic reconstruction differs")
    return rebuilt
