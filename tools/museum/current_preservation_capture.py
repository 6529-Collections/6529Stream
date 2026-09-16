"""Real local file operations, actual current Safe publications and offline preservation exports.

The local harness observes its own work. The exported records remain account
reports, not independent proof of historical execution or institutional review.
"""
from datetime import datetime, timezone
import hashlib
from pathlib import Path
import platform
import shutil
import time

from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .current_museum_capture import CurrentMuseumFixture, ROOT, capture as capture_media, main as run_main
from .current_media_inputs import PREFIX, PF, image_bytes
from .independent_wire import ZERO, require
from .recorded_semantic import JCS_ID
from .schemas import NAMES, HEX32, TEXT, UINT, definitions, enum, obj, arr
from .recorded_fixity import SCHEMAS as FIXITY_SCHEMAS, FAMILIES as FIXITY_FAMILIES, AGENT_NAME, REPORT_NAME as FIXITY_REPORT, EVENT_NAME as FIXITY_EVENT
from .preservation_events import SCHEMAS as EVENT_SCHEMAS, FAMILIES as EVENT_FAMILIES, EVENT_NAME, REPORT_NAME, MODE, PROFILE_HASH
from .preservation_resources import SCHEMAS as OBJECT_SCHEMAS, OBJECT_NAME
from .review import _validate, _selector

WORKFLOW = "actual_current_foundation_recorded_preservation_v1"
OBJECT_ID = schema_id("current museum preservation declared image v1")
AGENT_ID = schema_id("current museum preservation capture software v1")
OPERATION_NAME = "CURRENT_MUSEUM_LOCAL_FILE_OPERATION_V1"
OPERATION_SCHEMA = dumps(obj({"version": enum("1"), "operation": enum("copy_and_compare"),
    "sourceFile": TEXT, "destinationFile": TEXT, "sourceSha256": HEX32, "destinationSha256": HEX32,
    "sourceBytes": UINT, "destinationBytes": UINT, "performedAt": UINT, "clock": enum("host_utc"),
    "equal": enum(True), "expectedDeclarations": arr(definitions()["selector"], 1, 3), "detail": TEXT}) |
    {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + OPERATION_NAME})
SCHEMAS = {**FIXITY_SCHEMAS, **EVENT_SCHEMAS, OBJECT_NAME: OBJECT_SCHEMAS[OBJECT_NAME], OPERATION_NAME: OPERATION_SCHEMA}
FAMILY = schema_id("INDEPENDENT_SEMANTIC_ASSERTION")
EVENT_FAMILY = schema_id("INDEPENDENT_PRESERVATION_EVENT")


def measure_file(path, expected, event_id, *, clock=time.time):
    """Read real file bytes and compare with supplied recorded expectations; never force success."""
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), "local observation must be an ordinary file")
    raw = path.read_bytes()
    require(len(raw) <= 32 * 1024 * 1024, "local observation exceeds profile bound")
    digest = "0x" + hashlib.sha256(raw).hexdigest()
    equal = digest == expected["digest"] and str(len(raw)) == expected["size"]
    report = {"version": "1", "eventId": event_id, "objectId": OBJECT_ID, "agentId": AGENT_ID,
        "checkedAt": str(int(clock())), "algorithm": schema_id("SHA256"), "expectedDigest": expected["digest"],
        "observedDigest": digest, "expectedByteSize": expected["size"], "observedByteSize": str(len(raw)),
        "outcome": schema_id("SUCCESS" if equal else "FAILED"), "performed": True,
        "detail": dumps({"method": "Python hashlib.sha256 over read_bytes, then exact size/digest comparison",
            "file": path.name, "clock": "host_utc", "expectedDeclaration": expected["source"],
            "expectedPointers": expected["pointers"], "qualification": "Local harness observation, published as an account report; no independent historical or agent-identity proof."}).decode()}
    _validate(FIXITY_SCHEMAS[FIXITY_REPORT], dumps(report))
    return raw, report


def copy_and_measure(source, destination, expected, *, clock=time.time):
    source, destination = Path(source), Path(destination)
    require(source.is_file() and not source.is_symlink(), "copy source must be an ordinary file")
    require(not destination.exists() and not destination.is_symlink(), "copy destination already exists")
    # The task-owned destination is new. No replacement or deletion of user files.
    with destination.open("xb") as target, source.open("rb") as origin:
        shutil.copyfileobj(origin, target)
    before, after = source.read_bytes(), destination.read_bytes()
    require(before == after, "actual copied bytes differ")
    report = {"version": "1", "operation": "copy_and_compare", "sourceFile": source.name,
        "destinationFile": destination.name, "sourceSha256": "0x" + hashlib.sha256(before).hexdigest(),
        "destinationSha256": "0x" + hashlib.sha256(after).hexdigest(), "sourceBytes": str(len(before)),
        "destinationBytes": str(len(after)), "performedAt": str(int(clock())), "clock": "host_utc", "equal": True,
        "expectedDeclarations": expected["source"], "detail": "Actual local copy followed by complete byte comparison; no remote replica availability or preservation-institution claim."}
    _validate(OPERATION_SCHEMA, dumps(report))
    return report


class CurrentPreservationFixture(CurrentMuseumFixture):
    def publish(self, *args, **kwargs):
        selector, sid = super().publish(*args, **kwargs)
        if not hasattr(self, "published"): self.published = []
        self.published.append(selector)
        return selector, sid

    def capture_lanes(self):
        return [{"scopeKey": "1", "recordType": family} for family in
            (FAMILY, schema_id("INDEPENDENT_FIXITY"), EVENT_FAMILY)]

    def _expectations(self):
        """Read the actual prior stored semantic payload, not a computed media-description digest."""
        facts, chosen, pointers = {}, [], {}
        for selector in self.published:
            if selector["schemaId"] != schema_id(NAMES[1]): continue
            record, receipt = self.call("StreamCollectionAttestations", "collectionRecord", (selector["recordHash"],))
            _, raw = self.call("StreamCollectionAttestations", "recordPayload", (selector["recordHash"],))
            require(record[2] == (1, hex_bytes(keccak256(raw)), JCS_ID) and receipt[1] == self.attestor,
                "recorded expected file facts changed")
            value = loads(raw, maximum=8192, canonical=True)
            local, where = {}, {}
            for i, assertion in enumerate(value["assertions"]):
                if assertion["subject"] != PREFIX + "image": continue
                for field in ("digest", "size", "puid"):
                    if assertion["relation"] == PF[field]:
                        local[field] = assertion["object"]["literal"]["lexicalValue"]
                        where[field] = "/assertions/" + str(i) + "/object/literal/lexicalValue"
            if local:
                require(not (facts.keys() & local.keys()), "ambiguous duplicate recorded file fact")
                facts.update(local)
                chosen.append(selector)
                pointers.update({field: {**selector, "pointer": pointer} for field, pointer in where.items()})
        require(set(facts) == {"digest", "size", "puid"}, "complete recorded expected digest/size/format required")
        hex_bytes("0x" + facts["digest"], 32)
        return {**facts, "digest": "0x" + facts["digest"], "source": chosen, "pointers": pointers}

    def _publish_typed(self, name, value, *, family=None, subject=None):
        raw = dumps(value); _validate(SCHEMAS[name], raw)
        require(len(raw) <= 8192, "typed preservation payload exceeds original host bound")
        selector, _ = self.publish(raw, schema_id(name), JCS_ID, self.next_preservation_nonce,
            record_type=family or FAMILY, subject=subject)
        self.next_preservation_nonce += 1
        # The write receipt alone is insufficient: retain original actual bytes readback.
        _, saved = self.call("StreamCollectionAttestations", "recordPayload", (selector["recordHash"],))
        require(saved == raw, "actual stored preservation payload differs")
        return selector, keccak256(raw)

    def after_media_publications(self):
        require(hasattr(self, "observation_directory"), "preservation capture needs task-owned file directory")
        expected = self._expectations()
        self.expectations = expected
        self.next_preservation_nonce = 1000
        for name, raw in SCHEMAS.items(): self.register_document(name, 0, raw, JCS_ID)
        version = "Python " + platform.python_version() + "; capture source SHA-256 " + hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        description = {"version": "1", "agentId": AGENT_ID, "name": "Stream local preservation capture harness",
            "type": "software", "agentVersion": version}
        agent_selector, agent_hash = self._publish_typed(AGENT_NAME, description)
        agent = {"agentId": AGENT_ID, "agentRole": schema_id("PRESERVATION_CHECK_EXECUTOR"),
            "account": "0x" + "00" * 20, "did": "", "uri": "urn:6529stream:local-preservation-capture:v1", "agentHash": agent_hash}
        self.observations, self.checks, self.selected_events = {}, [], []
        for filename, label in (("declared.png", "matching"), ("mutated.bin", "changed")):
            event_id = schema_id("current preservation measured " + label + " v1")
            raw, report = measure_file(self.observation_directory / filename, expected, event_id)
            report_selector, report_hash = self._publish_typed(FIXITY_REPORT, report, family=FIXITY_FAMILIES[FIXITY_REPORT])
            uri = "urn:6529stream:local-check:" + event_id[2:]
            value = {"version": "1", "event": {"eventId": event_id, "eventType": schema_id("FIXITY_CHECK"),
                "outcome": report["outcome"], "eventURI": uri, "eventHash": report_hash, "eventTime": report["checkedAt"], "schemaId": schema_id(FIXITY_REPORT)},
                "agent": agent, "check": {"objectId": OBJECT_ID, "algorithm": schema_id("SHA256"), "digest": report["observedDigest"],
                    "byteSize": report["observedByteSize"], "checkedAt": report["checkedAt"], "outcome": report["outcome"], "agentId": AGENT_ID,
                    "reportURI": uri, "reportHash": report_hash}, "object": PREFIX + "image", "report": report_selector, "agentDocument": agent_selector}
            selector, _ = self._publish_typed(FIXITY_EVENT, value, family=FIXITY_FAMILIES[FIXITY_EVENT])
            self.observations[event_id] = raw; self.checks.append(report); self.selected_events.append(selector)
        require([r["outcome"] for r in self.checks] == [schema_id("SUCCESS"), schema_id("FAILED")],
            "actual comparison must retain matching success and changed-file failure")
        self.replication = copy_and_measure(self.observation_directory / "declared.png", self.observation_directory / "replica.png", expected)
        result_selector, result_hash = self._publish_typed(OPERATION_NAME, self.replication, family=EVENT_FAMILY)
        event_id = schema_id("current preservation actual replication v1")
        report = {"version": "1", "eventId": event_id, "eventType": schema_id("REPLICATION"), "outcome": schema_id("SUCCESS"),
            "eventTime": self.replication["performedAt"], "status": "completed", "objectIds": [OBJECT_ID], "agentIds": [AGENT_ID],
            "detail": "Copy into a new local file and compare complete bytes; linked measured operation is retained.",
            "outcomeDetail": "The actual two local files matched. No remote replica claim.",
            "results": [{"purpose": "local copy and byte comparison", "uri": "urn:6529stream:local-replica:v1", "contentHash": result_hash, "record": result_selector}]}
        report_selector, report_hash = self._publish_typed(REPORT_NAME, report, family=EVENT_FAMILIES[REPORT_NAME])
        body = {"version": "1", "event": {"eventId": event_id, "eventType": report["eventType"], "outcome": report["outcome"],
            "eventURI": "urn:6529stream:local-replication-report:v1", "eventHash": report_hash, "eventTime": report["eventTime"], "schemaId": schema_id(REPORT_NAME)},
            "objects": [{"objectId": OBJECT_ID, "identifier": PREFIX + "image", "role": schema_id("PRESERVATION_OBJECT")}],
            "agents": [{"agent": agent, "document": agent_selector}], "report": report_selector}
        selector, _ = self._publish_typed(EVENT_NAME, body, family=EVENT_FAMILY); self.selected_events.append(selector)
        from .current_media_inputs import media_description
        media = media_description((self.observation_directory / "declared.png").read_bytes())
        object_ = {"version": "1", "collectionId": "1", "object": {"objectId": OBJECT_ID, "objectRole": schema_id("SOURCE_MASTER"),
            "uri": media["uri"], "contentHash": expected["digest"], "mimeType": media["mime"], "byteSize": expected["size"],
            "formatId": schema_id("PRONOM:" + expected["puid"]), "schemaId": ZERO}, "hashAlgorithm": "SHA256",
            "format": {"kind": "pronom", "puid": expected["puid"]}, "significantProperties": [], "relationships": []}
        self.selected_object, _ = self._publish_typed(OBJECT_NAME, object_, subject=(2, 1, 0, OBJECT_ID))

    def extra_capture_evidence(self):
        return {"preservationWorkflow": WORKFLOW, "performedChecks": self.checks, "copyOperation": self.replication,
            "expectedFileDeclaration": self.expectations, "softwareSourceSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "measurementClock": "host UTC at file operation; independent from simulated-chain publication timestamps",
            "preservationQualification": "This local run executes its reported file operations and actual Safe publications. Offline recipients verify recorded assertions and byte commitments, not historical performance, software identity, rights or institutional approval."}


def export_preservation(output):
    """Replay the closed captured source; no RPC needed after the original full-media package exists."""
    from .recorded_projection import replay_source_bytes
    from .package_recorded import INPUT_FILES
    from .package import write_package
    from .package_v2 import verify_package
    from .preservation_package import build_preservation_package
    from .resource_package import build_resource_package
    from .preservation_resources import MODE as RESOURCE_MODE, PROFILE_HASH as RESOURCE_HASH
    output = Path(output)
    pins = loads((output / "pins.json").read_bytes(), maximum=524288)
    source = replay_source_bytes(ROOT, {name: (output / name).read_bytes() for name in INPUT_FILES},
        **{key + "_hash": pins[key + "_hash"] for key in ("source", "publication", "interpretation", "profile")})
    events = [_selector(record, "") for record in source.state.records if record.selector.schema_id in (schema_id(FIXITY_EVENT), schema_id(EVENT_NAME))]
    objects = [_selector(record, "") for record in source.state.records if record.selector.schema_id == schema_id(OBJECT_NAME)]
    require(len(events) == 3 and len(objects) == 1, "exact actual recorded event/object selection missing")
    observations = {}
    for selector in events:
        record = source.record(selector)
        if selector["schemaId"] != schema_id(FIXITY_EVENT): continue
        value = loads(record.payload, canonical=True)
        event_id = value["event"]["eventId"]
        filename = "declared.png" if value["event"]["outcome"] == schema_id("SUCCESS") else "mutated.bin"
        observations[event_id] = (output / "observed-files" / filename).read_bytes()
    plan = dumps({"mode": MODE, "version": "1", "sourceStateHash": source.state.commitment, "profileHash": source.profile_hash,
        "premisPlanHash": pins["premis_plan_hash"], "preservationProfileHash": PROFILE_HASH, "events": events})
    result = build_preservation_package(output / "package", pins["package_manifest"], plan, plan_hash=keccak256(plan),
        profile_hash=PROFILE_HASH, observations=observations, disclosure="public")
    require("premis-preservation/premis.xml" in dict(result.files), "recorded performed-event XML unavailable")
    write_package(result, output / "preservation-package"); verify_package(output / "preservation-package", result.manifest_hash)
    resource_plan = dumps({"mode": RESOURCE_MODE, "version": "1", "sourceStateHash": source.state.commitment,
        "accountProfileHash": source.profile_hash, "resourceProfileHash": RESOURCE_HASH,
        "rightsSourceHash": None, "objects": objects, "rights": []})
    resource = build_resource_package(output / "package", pins["package_manifest"], resource_plan,
        plan_hash=keccak256(resource_plan), profile_hash=RESOURCE_HASH, disclosure="public")
    require("premis-resources/premis.xml" in dict(resource.files), "recorded canonical object XML unavailable")
    write_package(resource, output / "object-package"); verify_package(output / "object-package", resource.manifest_hash)
    # Current bytes cannot be silently changed to match an old successful report.
    wrong = dict(observations)
    success = next(key for key in wrong if key == schema_id("current preservation measured matching v1"))
    wrong[success] = wrong[success] + b"changed after report"
    from .canonical import MuseumError
    try:
        build_preservation_package(output / "package", pins["package_manifest"], plan, plan_hash=keccak256(plan),
            profile_hash=PROFILE_HASH, observations=wrong, disclosure="public")
    except MuseumError as exc:
        require("supplied observation differs" in str(exc), "unexpected changed-observation failure")
    else: raise MuseumError("changed observation was accepted")
    report = {"mode": WORKFLOW, "sourceStateHash": source.state.commitment, "baseManifestHash": pins["package_manifest"],
        "preservationManifestHash": result.manifest_hash, "objectManifestHash": resource.manifest_hash,
        "recordedEvents": len(events), "recordedObjects": len(objects), "matchingAndFailedChecksPreserved": True,
        "changedObservationRejected": True, "offlinePackagesVerified": True,
        "metadataRightsCaptured": False, "institutionalConformance": False, "consensusFinality": False,
        "historicalPerformanceProvenByOfflinePackage": False}
    (output / "preservation-result.json").write_bytes(dumps(report))
    return result.manifest_hash


def capture(fixture, output):
    output = Path(output)
    folder = output / "observed-files"; folder.mkdir(exist_ok=False)
    original = image_bytes()
    (folder / "declared.png").write_bytes(original)
    (folder / "mutated.bin").write_bytes(original + b"explicit local mismatch")
    fixture.observation_directory = folder
    capture_media(fixture, output)
    return export_preservation(output)


def main():
    run_main(fixture_type=CurrentPreservationFixture, capture_function=capture)


if __name__ == "__main__": main()