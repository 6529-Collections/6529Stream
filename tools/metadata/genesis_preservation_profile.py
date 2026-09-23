"""Canonical prospective museum preservation schemas and worked examples.

These documents define portable genesis meanings.  They do not register a
schema, authenticate an artist, prove archival availability, or replace the
narrow native reference-render profile.
"""

import argparse
import copy
from pathlib import Path

import jsonschema

from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from tools.museum.linked_art import format_checker


ROOT = Path(__file__).resolve().parents[2]
MASTER_WAIVER = "STREAM_MASTER_WAIVER_V1"
REFERENCE_RENDER = "STREAM_REFERENCE_RENDER_V1"
METRIC = "STREAM_METRIC_SSIM_V1"
NAMES = (MASTER_WAIVER, REFERENCE_RENDER, METRIC)
SOURCE_REVISION = "6292287bdabe1d2452f11b1254ced325e259b731"
REFERENCE_TOOL = "6529Stream integer SSIM"
REFERENCE_TOOL_VERSION = "1.0.0"
REFERENCE_IMPLEMENTATION_HASH = "0xc80f065d2bb7dcc71bd3ee98ac798ef19795fe7d4b8f68a0d777e4e6f9cfbc68"
PARAMETERS_HASH = "0x1284b35afa316cb69d790a354cefdeb19d00a37116b1ec25e2ded88a1f59add3"
SCALE = 1_000_000_000
SOURCE_FILES = {
    "tools/museum/canonical.py": "208c31075112ee942818639774bae416855228e8e1cce8fbf033cd1181404069",
    "tools/museum/chain_abi.py": "4dc74a1d21ec5cd443e1ef97fa0a2c3ddd86b99bfaefd3ca76f6ead00109d94d",
    "tools/preservation/reference_manifest.py": "4a39660ef75d0f286cbcaa31fa6c8770ed77a53fbe152a73fd7e6c5325238bee",
    "tools/preservation/reference_metric.py": "88428ca6ca5babaea0bff0448b73b7edc45305db54edf07ef53f66a647d42a07",
}
PARAMETERS = {
    "profile": "STREAM_SSIM_RGB8_INTEGER_GAUSSIAN11_V1",
    "window": [1, 8, 38, 114, 222, 277, 222, 114, 38, 8, 1],
    "windowRule": "separable fixed integer weights; valid windows only",
    "moments": "weighted population moments",
    "channels": "mean of RGB; RGBA requires alpha255",
    "range": 255,
    "c1": [65025, 10000],
    "c2": [585225, 10000],
    "rounding": "floor each window/channel score at1e9; floor their mean",
    "scaling": "no resampling, gamma conversion or color-profile application",
    "input": "PNG8 RGB/RGBA, noninterlaced, sRGB or untagged;11..512 each dimension",
}


def _constant_shape(value):
    if isinstance(value, dict):
        return obj({key: _constant_shape(child) for key, child in value.items()})
    if isinstance(value, list):
        return {"type": "array", "items": {"enum": sorted(set(value))},
                "minItems": len(value), "maxItems": len(value)}
    return {"const": value}


def obj(properties, required=None):
    return {"type": "object", "properties": properties, "required": list(properties) if required is None else required,
            "additionalProperties": False}


def arr(items, minimum=0, maximum=512, *, unique=False):
    result = {"type": "array", "items": items, "minItems": minimum, "maxItems": maximum}
    if unique:
        result["uniqueItems"] = True
    return result


def enum(*values):
    return {"enum": list(values)}


HEX32 = {"type": "string", "pattern": r"^0x[0-9a-f]{64}(?![\s\S])"}
SHA256 = {"type": "string", "pattern": "^[0-9a-f]{64}$"}
UINT = {"type": "string", "pattern": "^(0|[1-9][0-9]*)$", "maxLength": 78,
        "not": {"pattern": "[\\r\\n]"}}
TEXT = {"type": "string", "maxLength": 16384}
IRI = {"type": "string", "format": "uri", "maxLength": 2048}
NULL_HASH = {"oneOf": [HEX32, {"type": "null"}]}
HASH_REF = obj({"algorithm": {"type": "integer", "minimum": 1, "maximum": 6},
                "canonicalizationId": HEX32,
                "digest": {"type": "string", "pattern": "^0x(?:[0-9a-f]{2}){1,128}$"}})
REFERENCE = obj({"hash": HASH_REF, "uri": IRI})
ARTIST = obj({"artistId": HEX32, "bindingGeneration": UINT, "bindingHash": HEX32})
RATIONAL = obj({"numerator": UINT, "denominator": {"type": "string", "pattern": "^[1-9][0-9]*$", "maxLength": 78}})
MIRROR = obj({"storageFamily": {"type": "string", "minLength": 1, "maxLength": 128},
              "receipt": REFERENCE})
ARTIFACT = obj({"content": REFERENCE, "formatId": HEX32, "byteLength": UINT,
                "archiveMirrors": arr(MIRROR, 2, 2)})


def _capture(capture_class, parameters):
    return obj({"tokenId": UINT, "captureClass": {"const": capture_class},
                "artifact": ARTIFACT, "parameters": parameters})


def documents():
    master = obj({
        "version": {"const": 1}, "subjectId": HEX32, "artist": ARTIST,
        "scope": obj({"subjectId": HEX32,
            "mediaObjects": arr(obj({"objectId": HEX32,
                "mediaClass": enum("still_image", "print_destined", "audio", "video", "interactive_capture"),
                "masterRoles": arr(enum("SOURCE_MASTER", "PRINT_MASTER"), 1, 2, unique=True)}), 1, 512)}),
        "waiverStatement": REFERENCE, "reason": {"type": "string", "minLength": 1, "maxLength": 16384},
        "predecessor": NULL_HASH})

    still = _capture("still", obj({"kind": {"const": "still"}}))
    frame = _capture("frame_sequence", obj({"kind": {"const": "frame_sequence"},
        "durationMs": UINT, "frameRate": RATIONAL, "timing": enum("constant", "variable")}))
    av = _capture("av_container", obj({"kind": {"const": "av_container"},
        "durationMs": UINT, "frameRate": RATIONAL, "timing": enum("constant", "variable"),
        "audio": {"oneOf": [obj({"codec": {"type": "string", "minLength": 1, "maxLength": 128},
            "channels": UINT, "sampleRateHz": UINT}), {"type": "null"}]}}))
    scripted = _capture("scripted_session", obj({"kind": {"const": "scripted_session"},
        "durationMs": UINT, "inputScript": REFERENCE, "inputLog": REFERENCE}))
    sample = obj({"kind": enum("all_tokens", "explicit_tokens", "sampling_rule"),
        "tokens": arr(UINT, 1, 4096, unique=True), "firstSerialTokenId": UINT, "lastSerialTokenId": UINT,
        "samplingRule": {"oneOf": [REFERENCE, {"type": "null"}]}})
    environment_artifact = obj({"preservationObjectId": HEX32, "content": REFERENCE,
        "archiveMirrors": arr(MIRROR, 2, 2),
        "licenseBasis": enum("open_source", "preservation_exception", "licensed_with_instrument", "undetermined"),
        "instrument": {"oneOf": [REFERENCE, {"type": "null"}]},
        "licenseNote": {"type": "string", "maxLength": 16384},
        "openSubstitution": {"oneOf": [REFERENCE, {"type": "null"}]}})
    environment = obj({"rendererVersion": {"type": "string", "minLength": 1, "maxLength": 256},
        "renderContextVersion": {"type": "string", "minLength": 1, "maxLength": 256},
        "engine": {"type": "string", "minLength": 1, "maxLength": 256},
        "engineVersion": {"type": "string", "minLength": 1, "maxLength": 256},
        "viewport": obj({"width": UINT, "height": UINT, "devicePixelRatio": RATIONAL}),
        "colorSpace": {"type": "string", "minLength": 1, "maxLength": 256},
        "captureToolchain": obj({"name": {"type": "string", "minLength": 1, "maxLength": 256},
            "version": {"type": "string", "minLength": 1, "maxLength": 256}, "source": REFERENCE}),
        "artifact": environment_artifact})
    byte_exact = obj({"mode": {"const": "BYTE_EXACT"}, "softwareRasterization": {"const": True}})
    perceptual = obj({"mode": {"const": "PERCEPTUAL_TOLERANCE"}, "metricSchemaId": HEX32,
        "metricDocument": REFERENCE, "threshold": UINT})
    curated = obj({"mode": {"const": "CURATED_EQUIVALENCE"},
        "evidenceClass": enum("INSTITUTION_SIGNER", "INDEPENDENT_CONDITION"),
        "attestation": REFERENCE, "examinerInstitution": REFERENCE,
        "examinerName": {"type": "string", "minLength": 1, "maxLength": 512},
        "examinerCredential": REFERENCE, "significantPropertiesEvaluation": REFERENCE})
    reference = obj({"version": {"const": 1}, "subjectId": HEX32,
        "workClass": enum("static", "time_based", "interactive"),
        "rendererClass": enum("STATIC", "DYNAMIC"), "tokenSample": sample,
        "requiredCaptureClasses": arr(enum("still", "frame_sequence", "av_container", "scripted_session"),
            1, 4, unique=True),
        "captures": arr({"oneOf": [still, frame, av, scripted]}, 1, 16384),
        "executionEnvironment": environment,
        "acceptance": {"oneOf": [byte_exact, perceptual, curated]}, "predecessor": NULL_HASH})

    exact_source_files = [{"path": path, "sha256": digest} for path, digest in sorted(SOURCE_FILES.items())]
    metric = obj({"version": {"const": 1}, "algorithm": {"const": "SSIM"},
        "profile": {"const": PARAMETERS["profile"]},
        "referenceTool": obj({"name": {"const": REFERENCE_TOOL},
            "version": {"const": REFERENCE_TOOL_VERSION}, "sourceRevision": {"const": SOURCE_REVISION},
            "implementationHash": {"const": REFERENCE_IMPLEMENTATION_HASH},
            "sourceFiles": {"const": exact_source_files}}),
        "parameters": {"const": PARAMETERS}, "parametersHash": {"const": PARAMETERS_HASH},
        "scoreScale": {"const": str(SCALE)},
        "inputLimits": obj({"format": {"const": "PNG8 RGB/RGBA"}, "alpha": {"const": "opaque_if_RGBA"},
            "minimumWidth": {"const": "11"}, "maximumWidth": {"const": "512"},
            "minimumHeight": {"const": "11"}, "maximumHeight": {"const": "512"},
            "maximumBytes": {"const": "4194304"}})})

    result = {}
    for name, body in ((MASTER_WAIVER, master), (REFERENCE_RENDER, reference), (METRIC, metric)):
        result[name] = {"$schema": "https://json-schema.org/draft/2020-12/schema",
            "$id": "urn:6529stream:schema:" + name, "title": name,
            "x-stream-document-status": "prospective_unregistered", **body}
    return result


SCHEMA_BYTES = {name: dumps(value) for name, value in documents().items()}
SCHEMA_HASHES = {name: keccak256(raw) for name, raw in SCHEMA_BYTES.items()}


def _ref(seed, uri):
    return {"hash": {"algorithm": 1,
        "canonicalizationId": "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f",
        "digest": "0x" + format(seed, "064x")}, "uri": uri}


def examples():
    h = lambda n: "0x" + format(n, "064x")
    mirror = lambda family, n: {"storageFamily": family, "receipt": _ref(n, "ipfs://archive-receipt-" + family)}
    master = {"version": 1, "subjectId": h(1),
        "artist": {"artistId": h(2), "bindingGeneration": "7", "bindingHash": h(3)},
        "scope": {"subjectId": h(1), "mediaObjects": [
            {"objectId": h(4), "mediaClass": "video", "masterRoles": ["SOURCE_MASTER"]},
            {"objectId": h(5), "mediaClass": "still_image", "masterRoles": ["SOURCE_MASTER", "PRINT_MASTER"]}]},
        "waiverStatement": _ref(6, "ipfs://artist-master-waiver"),
        "reason": "Artist-authored fixture waiver; carrier signature authority is checked separately.",
        "predecessor": None}
    metric = {"version": 1, "algorithm": "SSIM", "profile": PARAMETERS["profile"],
        "referenceTool": {"name": REFERENCE_TOOL, "version": REFERENCE_TOOL_VERSION,
            "sourceRevision": SOURCE_REVISION, "implementationHash": REFERENCE_IMPLEMENTATION_HASH,
            "sourceFiles": [{"path": path, "sha256": digest} for path, digest in sorted(SOURCE_FILES.items())]},
        "parameters": copy.deepcopy(PARAMETERS), "parametersHash": PARAMETERS_HASH,
        "scoreScale": str(SCALE), "inputLimits": {"format": "PNG8 RGB/RGBA", "alpha": "opaque_if_RGBA",
            "minimumWidth": "11", "maximumWidth": "512", "minimumHeight": "11", "maximumHeight": "512",
            "maximumBytes": "4194304"}}
    artifact = lambda n, fmt: {"content": _ref(n, "ipfs://reference-capture-" + str(n)),
        "formatId": h(fmt), "byteLength": "4096",
        "archiveMirrors": [mirror("ENDOWED", n + 100), mirror("INSTITUTIONAL", n + 200)]}
    reference = {"version": 1, "subjectId": h(10), "workClass": "time_based", "rendererClass": "DYNAMIC",
        "tokenSample": {"kind": "explicit_tokens", "tokens": ["1", "50", "100"],
            "firstSerialTokenId": "1", "lastSerialTokenId": "100", "samplingRule": None},
        "requiredCaptureClasses": ["frame_sequence", "av_container"],
        "captures": [
            {"tokenId": token, "captureClass": kind, "artifact": artifact(n, 20 + n),
             "parameters": ({"kind": "frame_sequence", "durationMs": "10000",
                 "frameRate": {"numerator": "30", "denominator": "1"}, "timing": "constant"}
                if kind == "frame_sequence" else {"kind": "av_container", "durationMs": "10000",
                 "frameRate": {"numerator": "30000", "denominator": "1001"}, "timing": "variable",
                 "audio": {"codec": "FLAC", "channels": "2", "sampleRateHz": "48000"}})}
            for token, kind, n in (("1", "frame_sequence", 1), ("1", "av_container", 2),
                                   ("50", "frame_sequence", 3), ("50", "av_container", 4),
                                   ("100", "frame_sequence", 5), ("100", "av_container", 6))],
        "executionEnvironment": {"rendererVersion": "renderer-v4", "renderContextVersion": "context-v2",
            "engine": "Chromium", "engineVersion": "fixture-build",
            "viewport": {"width": "1920", "height": "1080",
                "devicePixelRatio": {"numerator": "1", "denominator": "1"}},
            "colorSpace": "sRGB", "captureToolchain": {"name": "fixture capture",
                "version": "1.0.0", "source": _ref(30, "https://example.org/capture-source")},
            "artifact": {"preservationObjectId": h(31), "content": _ref(32, "ipfs://runnable-environment"),
                "archiveMirrors": [mirror("ENDOWED", 33), mirror("INSTITUTIONAL", 34)],
                "licenseBasis": "preservation_exception", "instrument": _ref(35, "ipfs://preservation-instrument"),
                "licenseNote": "Fixture preservation basis only; no legal conclusion.", "openSubstitution": None}},
        "acceptance": {"mode": "PERCEPTUAL_TOLERANCE", "metricSchemaId": schema_id(METRIC),
            "metricDocument": _ref(36, "ipfs://registered-metric-document"), "threshold": "990000000"},
        "predecessor": None}
    return {"master-waiver.json": master, "reference-render.json": reference, "metric-ssim.json": metric}


def _uri(value):
    if not format_checker().conforms(value, "uri"):
        raise MuseumError("genesis preservation invalid URI")


def _references(value):
    if isinstance(value, dict):
        if set(value) == {"hash", "uri"}:
            yield value
        else:
            for child in value.values():
                yield from _references(child)
    elif isinstance(value, list):
        for child in value:
            yield from _references(child)


def _base(name, raw, maximum):
    if name not in SCHEMA_BYTES or type(raw) is not bytes or not 0 < len(raw) <= maximum:
        raise MuseumError("genesis preservation document bound")
    value = loads(raw, maximum=maximum, canonical=True)
    try:
        jsonschema.Draft202012Validator(documents()[name]).validate(value)
    except jsonschema.ValidationError as exc:
        raise MuseumError("genesis preservation schema differs") from exc
    if dumps(value) != raw:
        raise MuseumError("genesis preservation document must be exact canonical JSON")
    for reference in _references(value):
        _uri(reference["uri"])
        algorithm, digest = reference["hash"]["algorithm"], hex_bytes(reference["hash"]["digest"])
        if algorithm in (1, 2, 3, 6) and len(digest) != 32:
            raise MuseumError("genesis preservation fixed digest length")
        if not any(digest) or not any(hex_bytes(reference["hash"]["canonicalizationId"], 32)):
            raise MuseumError("genesis preservation empty reference commitment")
    return value


def _u(value, bits=256, *, positive=False):
    number = uint(value, bits)
    if positive and number == 0:
        raise MuseumError("genesis preservation positive integer required")
    return number


def _nonzero(value):
    if not any(hex_bytes(value, 32)):
        raise MuseumError("genesis preservation nonzero identifier required")


def validate_master_waiver(raw):
    value = _base(MASTER_WAIVER, raw, 8192)
    _nonzero(value["subjectId"]); _nonzero(value["artist"]["artistId"]); _nonzero(value["artist"]["bindingHash"])
    if value["scope"]["subjectId"] != value["subjectId"]:
        raise MuseumError("master waiver scope subject differs")
    objects = [row["objectId"] for row in value["scope"]["mediaObjects"]]
    for object_id in objects: _nonzero(object_id)
    if len(objects) != len(set(objects)):
        raise MuseumError("master waiver duplicate media object")
    if not all(any(hex_bytes(value["artist"][key], 32)) for key in ("artistId", "bindingHash")):
        raise MuseumError("master waiver artist binding missing")
    uint(value["artist"]["bindingGeneration"], 64)
    return value


def _mirror_families(artifact):
    families = [row["storageFamily"] for row in artifact["archiveMirrors"]]
    if len(set(families)) != 2:
        raise MuseumError("reference render archive families differ")


def validate_reference_render(raw):
    value = _base(REFERENCE_RENDER, raw, 24576)
    _nonzero(value["subjectId"])
    if value["predecessor"] is not None:
        _nonzero(value["predecessor"])
    sample = value["tokenSample"]
    tokens = sample["tokens"]
    for token in tokens: _u(token)
    _u(sample["firstSerialTokenId"]); _u(sample["lastSerialTokenId"])
    if sample["firstSerialTokenId"] not in tokens or sample["lastSerialTokenId"] not in tokens:
        raise MuseumError("reference render endpoint sample missing")
    if (sample["kind"] == "sampling_rule") != (sample["samplingRule"] is not None):
        raise MuseumError("reference render sampling rule differs")
    required = set(value["requiredCaptureClasses"])
    if value["workClass"] == "static" and "still" not in required:
        raise MuseumError("reference render static capture missing")
    if value["workClass"] == "time_based" and not required.intersection(("frame_sequence", "av_container")):
        raise MuseumError("reference render time capture missing")
    if value["workClass"] == "interactive" and "scripted_session" not in required:
        raise MuseumError("reference render interactive capture missing")
    pairs = {(row["tokenId"], row["captureClass"]) for row in value["captures"]}
    if any((token, capture_class) not in pairs for token in tokens for capture_class in required):
        raise MuseumError("reference render sample/class coverage incomplete")
    if any(row["tokenId"] not in tokens or row["captureClass"] not in required for row in value["captures"]):
        raise MuseumError("reference render undeclared capture")
    for row in value["captures"]:
        _u(row["tokenId"])
        _mirror_families(row["artifact"])
        _nonzero(row["artifact"]["formatId"])
        if _u(row["artifact"]["byteLength"], positive=True) == 0:
            raise MuseumError("reference render empty capture")
        p = row["parameters"]
        if row["captureClass"] != p["kind"]:
            raise MuseumError("reference render capture parameter class differs")
        for key in ("durationMs",):
            if key in p and _u(p[key], positive=True) == 0:
                raise MuseumError("reference render empty duration")
        if "frameRate" in p:
            _u(p["frameRate"]["numerator"], positive=True); _u(p["frameRate"]["denominator"], positive=True)
        if p.get("audio") is not None:
            _u(p["audio"]["channels"], positive=True); _u(p["audio"]["sampleRateHz"], positive=True)
    environment = value["executionEnvironment"]
    _u(environment["viewport"]["width"], positive=True); _u(environment["viewport"]["height"], positive=True)
    _u(environment["viewport"]["devicePixelRatio"]["numerator"], positive=True)
    _u(environment["viewport"]["devicePixelRatio"]["denominator"], positive=True)
    _nonzero(environment["artifact"]["preservationObjectId"])
    _mirror_families(environment["artifact"])
    license_basis = environment["artifact"]["licenseBasis"]
    instrument = environment["artifact"]["instrument"]
    if license_basis == "licensed_with_instrument" and instrument is None:
        raise MuseumError("reference render license instrument missing")
    if license_basis == "preservation_exception" and not environment["artifact"]["licenseNote"]:
        raise MuseumError("reference render preservation license note missing")
    acceptance = value["acceptance"]
    if acceptance["mode"] == "BYTE_EXACT" and value["rendererClass"] != "STATIC":
        raise MuseumError("reference render dynamic byte exact forbidden")
    if acceptance["mode"] == "PERCEPTUAL_TOLERANCE":
        _nonzero(acceptance["metricSchemaId"])
        if _u(acceptance["threshold"]) > SCALE:
            raise MuseumError("reference render perceptual metric differs")
    return value


def validate_metric(raw):
    value = _base(METRIC, raw, 8192)
    if value["referenceTool"]["sourceFiles"] != [
            {"path": path, "sha256": digest} for path, digest in sorted(SOURCE_FILES.items())]:
        raise MuseumError("metric source set differs")
    if keccak256(dumps(value["parameters"])) != PARAMETERS_HASH:
        raise MuseumError("metric parameters hash differs")
    return value


def validate(name, raw):
    if name == MASTER_WAIVER:
        return validate_master_waiver(raw)
    if name == REFERENCE_RENDER:
        return validate_reference_render(raw)
    if name == METRIC:
        return validate_metric(raw)
    raise MuseumError("unknown genesis preservation schema")


def outputs():
    result = {"schemas/records/" + name + ".json": raw for name, raw in SCHEMA_BYTES.items()}
    for filename, value in examples().items():
        name = {"master-waiver.json": MASTER_WAIVER, "reference-render.json": REFERENCE_RENDER,
                "metric-ssim.json": METRIC}[filename]
        raw = dumps(value)
        validate(name, raw)
        result["schemas/records/examples/genesis-preservation/" + filename] = raw
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for name, raw in outputs().items():
        path = ROOT / name
        if args.check:
            if not path.is_file() or path.read_bytes() != raw:
                raise SystemExit("genesis preservation definition differs: " + name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print("genesis preservation definitions exact")


if __name__ == "__main__":
    main()
