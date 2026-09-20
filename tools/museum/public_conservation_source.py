"""Native selected conservation histories and original op24 correspondence.

Historical receipts are distinct from current consuming eligibility. No tier,
sale floor, archive delivery, signature revalidation or complete packet follows.
"""
import hashlib

from jsonschema.exceptions import ValidationError

from tools.metadata import conservation_profile as interpretation
from . import artist_attestation_source as artist
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import Array, decode, encode
from .chain_rpc import quantity
from .current_rights_source import CurrentRightsSource, PROVIDER_CONFIG, DOCUMENT_FACTS, PRESENTATION
from .independent_wire import RECORD, RAW_BYTES, ZERO, ZERO_ADDRESS, generic_hash, json_values, require
from .metadata_catalog_source import RECEIPT, POLICY, ARTIST
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport

PROFILE = "STREAM_MUSEUM_PUBLIC_CONSERVATION_SOURCE_V1"
SOURCE_REVISION = "dffb8daa315114a7b26b4cff67df5747834f7ff9"
MAX_REVISIONS, MAX_CATALOGS, MAX_OUTPUT = 64, 128, 32 * 1024 * 1024
CONSERVATION_INTERFACE = "0xd5f6626e"
EVIDENCE = artist.EVIDENCE
RECORD_EVIDENCE = ("bytes32", "uint8", "bytes32", "address", "uint64", "uint64", "bytes32", "bytes32", EVIDENCE, "bytes32")
ASSOCIATION = ("bytes32", "bytes32", "uint64", "bytes32")
SELECTION = (RECORD_EVIDENCE, ASSOCIATION, "uint8", "uint8", RECORD_EVIDENCE, "bytes32", "uint8",
    "bytes32", "address", "uint64", "uint64", "bytes32", "bytes32")
CATALOG_PIN = ("bytes32", "bytes32", "uint256")
PREPARED = ("uint256", "bytes32", ASSOCIATION, RECORD_EVIDENCE, Array(CATALOG_PIN, MAX_CATALOGS), "bytes32")
LOCK = ("bool", "address", "bytes32", "bytes32", "bytes32", "uint64", "bytes32", "uint64", "uint64")
REFERENCE = ("uint16", "bytes32", "bytes", "string")
FAMILIES = (interpretation.INTENT, interpretation.WAIVER, interpretation.INTERVIEW)
RECORD_TYPES = tuple(schema_id(n) for n in ("ARTIST_INTENT", "ARTIST_INTENT_WAIVER", "ARTIST_STATEMENT"))
DEFINITIONS = interpretation.documents() | {"RFC8785_JCS": JCS_BYTES}
JCS_ID = schema_id("RFC8785_JCS")


def _zero(kind):
    if isinstance(kind, Array): return ()
    if isinstance(kind, tuple): return tuple(_zero(k) for k in kind)
    return False if kind == "bool" else ZERO_ADDRESS if kind == "address" else ZERO if kind == "bytes32" else 0


def _signature(kind):
    if isinstance(kind, Array): return _signature(kind.item) + "[]"
    return "(" + ",".join(_signature(k) for k in kind) + ")" if isinstance(kind, tuple) else kind


EMPTY_RECORD, EMPTY_SELECTION, EMPTY_LOCK, EMPTY_PREPARED = map(_zero, (RECORD_EVIDENCE, SELECTION, LOCK, PREPARED))
SELECTED_EVENT = schema_id("ConservationRecordSelected(uint256,bytes32,bytes32," + _signature(SELECTION) + ")")
LOCKED_EVENT = schema_id("ConservationIntentLocked(uint256,bytes32," + _signature(LOCK) + ")")
PREPARED_EVENT = schema_id("ConservationInterviewPrepared(bytes32,address,bytes32)")
CLAIMS = {"completeBoundSelectedHistories": True, "artistEstateLineagesSeparate": True,
    "originalNativeOp24CorrespondenceChecked": True, "originalSignatureBytesRetained": True,
    "parentInterviewAndCatalogsChecked": True, "historicalLockChecked": True,
    "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
    "fullGenericMetadataHistory": False, "allUnusedPreparationsCaptured": False,
    "archivedOperationReplay": False, "originalSignatureDomainProven": False,
    "currentSignerReauthorization": False, "signatureRevalidation": False,
    "tierDeclarationProven": False, "tierDefaultProven": False, "saleFloorEnforced": False,
    "archiveDeliveryProven": False, "actualChainAcceptance": False,
    "sourceConsensusVerified": False, "completeAcquisitionPacket": False}
QUALIFICATION = (
    "Complete native selected revisions for collection/token Artist and estate lineages on the canonical "
    "provider-bound conservation selector. Native original op24 publication, consumed authorization, "
    "stored statement, signature bytes, receipt and exact payload correspondence are retained. This "
    "does not replay archived operations, infer an original signing domain from today's facade, or "
    "revalidate historical signatures or today's signer permissions. Definitions and association changes "
    "leave historical evidence intact while blocking current-use claims. Filter completeness and canonical "
    "mapping remain provider trust. Missing tier declarations, defaults and sale floors remain required "
    "producer work; no full packet, legal truth, interview delivery or actual-chain acceptance is inferred.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "status": "prospective_unregistered_read_profile", "historyProfileHash": HISTORY_PROFILE_HASH,
    "bounds": {"revisionsPerLineage": str(MAX_REVISIONS), "lineages": "4", "catalogPinsPerSelection": str(MAX_CATALOGS),
        "nativeSelectablePayloadBytes": "8192", "snapshotBytes": str(MAX_OUTPUT), "transcriptBytes": "67108864"},
    "rules": ["Core ACTIVE router -> original finality -> immutable native provider configuration targets[17]; current Metadata and Artist facade bindings and admitted runtime hashes must agree.",
        "Every original selected revision, per-kind native index progression, signed predecessor, selection hash, publication event and selection event must agree; no latest supported fallback.",
        "Original classes1/3 remain Artist/estate separately. Saved native publication and full statement establish historical correspondence; no imported signature is rehashed under the current facade.",
        "PRESENT follows the parent's exact interview locator and full Reference, original payload and complete ordered catalog pins. WAIVED has a zero interview record and retains its own explicit statement.",
        "A separately observed preparation is not proof that a particular adoption used it. A zero prepared getter is permitted for ordinary full-witness adoption.",
        "All fixed interpretation bytes and referenced catalog bytes remain exact even when inactive. Known current definition/association failures retain history with current-use eligibility false; otherwise requireCurrent must return the exact head.",
        "One native Artist intent lock joins its original selected row and exact event, without reauthorizing a past locker. Empty selected head is only absence on this bound selector, never absence of generic records or a tier waiver."],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def selection_hash(a, subject, row):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "address", "address", "address", "uint256", "bytes32", SELECTION),
        (schema_id("6529STREAM_CONSERVATION_SELECTION_V1"), uint(a["chainId"]), a["conservationSelector"], a["core"],
         a["host"], a["schemas"], a["store"], uint(a["collectionId"]), subject, row[:-1] + (ZERO,))))


def preparation_hash(a, row):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "address", "address", "address", PREPARED),
        (schema_id("6529STREAM_CONSERVATION_INTERVIEW_PREPARATION_V1"), uint(a["chainId"]), a["conservationSelector"],
         a["core"], a["host"], a["schemas"], a["store"], row[:-1] + (ZERO,))))


class PublicConservationSource:
    _read = CurrentRightsSource._read
    _one = CurrentRightsSource._one
    _pointer = CurrentRightsSource._pointer
    _chunk = CurrentRightsSource._chunk

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc"
            or type(transport) in (PublicRpcTransport, PublicReplayTransport)), "conservation provenance")
        a = loads(anchor_bytes, maximum=65536, canonical=True)
        require(type(a) is dict and a.get("profile") == PROFILE and "artistRegistry" in a and "conservationSelector" in a
            and "rightsSelector" not in a,
            "conservation anchor shape/profile")
        projected = {k: v for k, v in a.items() if k not in ("artistRegistry", "conservationSelector")}
        from .current_rights_source import PROFILE as old_profile
        projected.update(profile=old_profile, rightsSelector=a["conservationSelector"])
        checked = CurrentRightsSource(dumps(projected), transport)
        require(any(hex_bytes(a["artistRegistry"], 20)) and a["artistRegistry"] in checked.pins
            and a["artistRegistry"] not in [a[k] for k in ("core", "host", "router", "originalFinality", "provider", "conservationSelector", "schemas", "store")],
            "conservation Artist facade pin/address")
        self.a, self.pins, self.anchor_bytes, self.provenance = a, checked.pins, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot, self._reads = False, None, {}
        self.chunks, self.documents, self.records, self.identities, self.preparations = {}, {}, {}, {}, {}

    def transcript(self):
        require(self._snapshot is not None, "conservation snapshot required before transcript")
        return self.reader.transcript()

    def _bindings(self):
        a = self.a
        for address, expected in self.pins.items():
            code = self.reader.code(address)
            require(type(code) is str and 2 < len(code) <= 2 + 24576 * 2
                and keccak256(hex_bytes(code)) == expected, "conservation runtime differs")
        pointers = {"metadata": self._pointer("COLLECTION_METADATA", a["host"]),
            "router": self._pointer("METADATA_ROUTER", a["router"])}
        for target, interfaces in ((a["core"], ("0x80ac58cd",)), (a["conservationSelector"], (CONSERVATION_INTERFACE,))):
            for interface in ("0x01ffc9a7",) + interfaces:
                require(self._one(target, "supportsInterface(bytes4)", "bool", ("bytes4",), (interface,)), "conservation native interface")
            require(not self._one(target, "supportsInterface(bytes4)", "bool", ("bytes4",), ("0xffffffff",)), "conservation invalid interface")
        require(self._one(a["router"], "core()", "address") == a["core"], "conservation router Core differs")
        require(self._read(a["router"], "servingOriginalFinalityAnchor()", outputs=("address", "bytes32"))[1]
            == (a["originalFinality"], self.pins[a["originalFinality"]]), "conservation original finality anchor differs")
        presentation = self._one(a["router"], "artistPresentation(uint256)", PRESENTATION, ("uint256",), (uint(a["collectionId"]),))
        saved = self._read(a["router"], "originalFinalityAnchor(uint256)", ("uint256",), (uint(a["collectionId"]),), ("address", "bytes32"))[1]
        require(saved == ((a["originalFinality"], self.pins[a["originalFinality"]]) if presentation[0] else (ZERO_ADDRESS, ZERO)),
            "conservation saved original/presentation lock differs")
        for signature, expected in (("coreReads()", a["core"]), ("metadataReads()", a["host"]),
            ("scopeEvidenceProvider()", a["provider"])):
            require(self._one(a["originalFinality"], signature, "address") == expected, "conservation original provider binding differs")
        require(self._one(a["originalFinality"], "scopeEvidenceProviderCodeHash()", "bytes32") == self.pins[a["provider"]],
            "conservation immutable provider code hash differs")
        configuration = self._one(a["provider"], "nativeConfiguration()", PROVIDER_CONFIG)
        targets, hashes, chain, read_gas, source_gas, component_gas, inventory_hash = configuration
        require(chain == uint(a["chainId"]) and 0 < read_gas <= component_gas <= (1 << 32) - 1
            and source_gas > component_gas + component_gas // 63 + 100000 and source_gas < 1 << 32
            and inventory_hash != ZERO and all(t != ZERO_ADDRESS for t in targets) and all(h != ZERO for h in hashes),
            "conservation native provider configuration")
        for index, key in ((0, "core"), (1, "host"), (2, "router"), (4, "schemas"), (5, "store"),
            (11, "artistRegistry"), (12, "originalFinality"), (17, "conservationSelector")):
            require(targets[index] == a[key] and hashes[index] == self.pins[a[key]], "conservation canonical selector configuration differs")
        for signature, expected in (("core()", a["core"]), ("metadataHost()", a["host"]), ("metadataRouter()", a["router"])):
            require(self._one(a["provider"], signature, "address") == expected, "conservation provider reciprocal binding")
        for signature, expected in (("coreCodeHash()", self.pins[a["core"]]), ("metadataHostCodeHash()", self.pins[a["host"]]),
            ("metadataRouterCodeHash()", self.pins[a["router"]])):
            require(self._one(a["provider"], signature, "bytes32") == expected, "conservation provider reciprocal code pin")
        require(self._one(a["provider"], "deploymentChainId()", "uint256") == chain, "conservation provider chain")
        for key, getter in (("core", "core"), ("host", "metadata"), ("schemas", "schemaRegistry"), ("store", "chunkStore")):
            require(self._one(a["conservationSelector"], getter + "()", "address") == a[key]
                and self._one(a["conservationSelector"], getter + "CodeHash()", "bytes32") == self.pins[a[key]],
                "conservation selector immutable dependency")
        require(self._one(a["conservationSelector"], "deploymentChainId()", "uint256") == chain, "conservation selector chain")
        for key, getter in (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore")):
            require(self._one(a["host"], getter + "()", "address") == a[key]
                and self._one(a["host"], getter + "CodeHash()", "bytes32") == self.pins[a[key]], "conservation Metadata binding")
        require(self._one(a["schemas"], "chunkStore()", "address") == a["store"], "conservation definition Store binding")
        pointers["artist"] = self._pointer("ARTIST_REGISTRY", a["artistRegistry"])
        require(self._one(a["host"], "artistRegistry()", "address") == a["artistRegistry"]
            and self._one(a["host"], "artistRegistryCodeHash()", "bytes32") == self.pins[a["artistRegistry"]],
            "conservation Metadata Artist facade differs")
        self._configuration = configuration
        return {"corePointers": {k: json_values(v) for k, v in pointers.items()}, "nativeConfiguration": json_values(configuration),
            "artistPresentation": json_values(presentation), "savedOriginalFinalityAnchor": json_values(saved),
            "originalProvider": a["provider"], "conservationSelector": a["conservationSelector"]}

    def _suite(self):
        a = self.a
        coordinator = self._one(a["artistRegistry"], "operationCoordinator()", "address")
        require(coordinator in self.pins, "conservation Coordinator runtime pin missing")
        suite = self._one(coordinator, "suiteConfiguration()", artist.SUITE)
        require(suite[0] == a["artistRegistry"] and suite[3] == a["core"] and suite[9] != ZERO
            and self._one(coordinator, "deploymentChainId()", "uint256") == uint(a["chainId"]),
            "conservation Artist suite identity differs")
        owners = (suite[2][2], suite[2][0], suite[2][4])
        require(len(set((a["artistRegistry"], coordinator, *owners))) == 5, "conservation Artist source aliases")
        for target in (a["artistRegistry"], *owners):
            require(target in self.pins and self._one(target, "core()", "address") == a["core"]
                and self._one(target, "operationCoordinator()", "address") == coordinator,
                "conservation Artist reciprocal source differs")
        for target in owners:
            require(self._one(target, "artistRegistry()", "address") == a["artistRegistry"]
                and self._one(target, "deploymentChainId()", "uint256") == uint(a["chainId"]),
                "conservation Artist owner deployment differs")
        self.artist_owners = owners
        return {"coordinator": coordinator, "configuration": json_values(suite),
            "identity": owners[0], "binding": owners[1], "attribution": owners[2]}

    def _known_identity(self, artist_id):
        if artist_id not in self.identities:
            state = self._read(self.artist_owners[0], "authorityState(bytes32)", ("bytes32",), (artist_id,),
                ("address", "uint8", "uint8", "bytes32"))[1]
            require(artist_id != ZERO and state[0] != ZERO_ADDRESS and state[3] != ZERO,
                "conservation original known identity missing")
            self.identities[artist_id] = state
        return self.identities[artist_id][3]

    def _current_association(self):
        cid = uint(self.a["collectionId"])
        binding = self._one(self.artist_owners[1], "binding(uint256)", artist.BINDING, ("uint256",), (cid,))
        attribution = self._read(self.artist_owners[2], "attributionState(uint256)", ("uint256",), (cid,), ("uint8", "uint64"))[1]
        require(attribution[0] <= 5, "conservation current attribution enum")
        eligible = (binding[0] != ZERO and binding[1] != ZERO_ADDRESS and binding[2] != ZERO and binding[3] != ZERO
            and binding[4] > 0 and binding[9] and attribution[0] in (2, 3) and attribution[1] == binding[4])
        association = _zero(ASSOCIATION)
        if binding[0] != ZERO:
            identity = self._known_identity(binding[0])
            association = (binding[0], binding[3], binding[4], identity)
            eligible = eligible and identity == binding[2]
        else:
            require(binding == _zero(artist.BINDING), "conservation partial empty binding")
        self.current_association = association
        self.association_eligible = eligible
        return {"binding": json_values(binding), "attribution": json_values(attribution),
            "association": json_values(association), "acceptedOrSanctioned": eligible}

    def _document(self, document_id, kind, canon, *, expected=None, expected_hash=None, first=False):
        facts = self._one(self.a["schemas"], "documentFacts(bytes32)", DOCUMENT_FACTS, ("bytes32",), (document_id,))
        require(facts[0] and facts[1] == kind and facts[2] in (0, 1, 2) and facts[4] == canon
            and (not first or facts[5] == ZERO) and 0 < facts[6] <= 524288 and 0 < facts[7] <= 64 and facts[8] != ZERO,
            "conservation definition facts differ")
        parts, hashes = [], []
        for index in range(facts[7]):
            digest = self._one(self.a["schemas"], "documentChunkHashAt(bytes32,uint256)", "bytes32",
                ("bytes32", "uint256"), (document_id, index))
            part = self._chunk(digest)
            require(index + 1 == facts[7] or len(part) == 8192, "conservation definition segment length")
            parts.append(part); hashes.append(digest)
        raw = b"".join(parts)
        require(len(raw) == facts[6] and keccak256(raw) == facts[3]
            and (expected is None or raw == expected) and (expected_hash is None or facts[3] == expected_hash),
            "conservation complete definition bytes differ")
        row = {"documentId": document_id, "payloadHex": "0x" + raw.hex(), "facts": json_values(facts), "chunkHashes": hashes}
        require(document_id not in self.documents or self.documents[document_id] == row, "conservation repeated definition differs")
        self.documents[document_id] = row
        return raw, facts

    def _definitions(self):
        for name, raw in DEFINITIONS.items():
            kind = 1 if name == "RFC8785_JCS" else 0 if name in interpretation.FAMILIES else 2
            self._document(schema_id(name), kind, RAW_BYTES, expected=raw, first=True)
        self.fixed_definitions_active = all(row["facts"][2] == "0" for row in self.documents.values())

    def _original(self, digest, kind, subject):
        if digest in self.records:
            row = self.records[digest]
            require(row["record"][1] == subject and row["record"][0] == RECORD_TYPES[kind], "conservation repeated original scope/kind")
            return row
        a, cid = self.a, uint(self.a["collectionId"])
        record, receipt = self._read(a["host"], "collectionRecord(bytes32)", ("bytes32",), (digest,), (RECORD, RECEIPT))[1]
        rt, sid, content, uri, schema, scheme, signature, effective = record
        policy = self._one(a["host"], "recordPolicy(bytes32)", POLICY, ("bytes32",), (rt,))
        require(policy[0] == ARTIST and policy[1] & 2 and policy[2] and rt == RECORD_TYPES[kind] and sid == subject
            and schema == schema_id(FAMILIES[kind]) and content[0] == 1 and len(content[1]) == 32 and content[2] == JCS_ID
            and scheme == ZERO and signature == (0, b"", ZERO) and effective > 0 and receipt[0] == cid
            and receipt[1] != ZERO_ADDRESS and receipt[2] == 1 and 0 < receipt[3] <= uint(a["timestamp"])
            and receipt[6] == keccak256(DEFINITIONS[FAMILIES[kind]]) and receipt[7] == keccak256(JCS_BYTES) and receipt[8] != ZERO,
            "conservation original receipt/family/definitions differ")
        require(generic_hash(uint(a["chainId"]), a["host"], a["core"], cid, receipt[1], record) == digest,
            "conservation original record hash differs")
        require(self._one(a["host"], "recordHashAt(uint256,bytes32,uint256)", "bytes32",
            ("uint256", "bytes32", "uint256"), (cid, rt, receipt[4])) == digest, "conservation original lane index differs")
        previous = ZERO
        if receipt[4]:
            prior = self._one(a["host"], "recordHashAt(uint256,bytes32,uint256)", "bytes32",
                ("uint256", "bytes32", "uint256"), (cid, rt, receipt[4] - 1))
            pr, rr = self._read(a["host"], "collectionRecord(bytes32)", ("bytes32",), (prior,), (RECORD, RECEIPT))[1]
            require(pr[0] == rt and rr[0] == cid and rr[4] + 1 == receipt[4]
                and generic_hash(uint(a["chainId"]), a["host"], a["core"], cid, rr[1], pr) == prior,
                "conservation original lane predecessor differs")
            previous = rr[5]
        require(record_chain(a["chainId"], a["host"], a["collectionId"], rt, previous, digest, str(receipt[4])) == receipt[5],
            "conservation original chain differs")
        raw = self._chunk("0x" + content[1].hex())
        value = interpretation._shape(raw, FAMILIES[kind])
        require(value["subjectId"] == subject, "conservation exact payload subject differs")
        catalogs, witnesses = [], {}
        if kind == 2:
            for payload in [value["transcript"], *(c["payload"] for c in value["captures"])]:
                form = payload["format"]
                if form["kind"] != "catalog": continue
                info = form["catalog"]
                data, facts = self._document(info["documentId"], 2, JCS_ID, expected_hash=info["documentHash"])
                witnesses[info["name"]] = data
                catalogs.append((info["documentId"], info["documentHash"], facts[6]))
        interpretation.validate(raw, FAMILIES[kind], witnesses)
        require(len(catalogs) <= MAX_CATALOGS, "conservation catalog occurrence bound")
        require(self._one(a["host"], "consumedArtistAuthorization(bytes32)", "bool", ("bytes32",), (receipt[8],)),
            "conservation original op24 authorization not consumed")
        saved = self._one(self.artist_owners[2], "publicationAttestation(bytes32)", artist.PUBLICATION_RECORD, ("bytes32",), (receipt[8],))
        publication, evidence, host_code = saved
        require(publication == (a["host"], receipt[1], cid, sid, rt, schema, JCS_ID, 1, keccak256(raw), keccak256(uri.encode()), effective, digest)
            and host_code == self.pins[a["host"]] and evidence[0] == receipt[8] and evidence[1] != ZERO
            and evidence[2] != ZERO and evidence[3] > 0 and evidence[4] == receipt[1] and evidence[5] in (1, 3)
            and evidence[6] == (1 if kind == 2 else 64) and 0 < evidence[7] <= receipt[3]
            and evidence[8] == keccak256(encode((artist.PUBLICATION,), (publication,))),
            "conservation saved native op24 publication differs")
        statement = encode(("uint16", artist.PUBLICATION), (1, publication))
        attestation = self._one(self.artist_owners[2], "attestationRecord(bytes32)", artist.ATTESTATION_RECORD, ("bytes32",), (receipt[8],))
        require(attestation == (receipt[8], ZERO if kind == 2 else digest, artist.PUBLICATION_SCHEMA,
            keccak256(statement), evidence[3], evidence[7], receipt[1]) and len(statement) == 416
            and self._one(self.artist_owners[2], "statementBytes(bytes32)", "bytes", ("bytes32",), (attestation[3],)) == statement,
            "conservation original full publication statement differs")
        bundle = self._one(self.artist_owners[0], "signatureBundle(bytes32)", "bytes", ("bytes32",), (receipt[8],))
        require(len(bundle) <= 4096, "conservation original signature bundle bound")
        binding = self._one(self.artist_owners[1], "bindingAt(uint256,uint64)", artist.BINDING,
            ("uint256", "uint64"), (cid, evidence[3]))
        require(binding[0] == evidence[1] and binding[3:5] == evidence[2:4] and binding[9]
            and binding[2] == self._known_identity(evidence[1]), "conservation original publication association differs")
        native = (digest, kind, keccak256(raw), receipt[1], receipt[3], receipt[4], receipt[5],
            keccak256(encode((RECEIPT,), (receipt,))), evidence, keccak256(encode((artist.PUBLICATION_RECORD,), (saved,))))
        row = {"recordHash": digest, "record": json_values(record), "receipt": json_values(receipt), "payloadHex": "0x" + raw.hex(),
            "value": value, "catalogs": json_values(catalogs), "publication": None, "savedPublication": json_values(saved),
            "nativeEvidence": json_values(native), "association": json_values((evidence[1], evidence[2], evidence[3], binding[2])),
            "attestation": json_values(attestation), "statementHex": "0x" + statement.hex(), "signatureHex": "0x" + bundle.hex(),
            "signatureVerification": "retained_native_original_bytes_without_revalidation"}
        self.records[digest] = row
        return row

    def _selected_originals(self, row, subject):
        record, association, origin, interview_status, interview = row[:5]
        require(record[1] in (0, 1) and origin in (0, 1) and interview_status in (0, 1), "conservation selected enum")
        original = self._original(record[0], record[1], subject)
        require(json_values(record) == original["nativeEvidence"] and json_values(association) == original["association"],
            "conservation selected original/association differs")
        value = original["value"]; claim = value["artist"]
        require(claim == {"artistId": association[0], "bindingGeneration": str(association[2]), "bindingHash": association[1],
            "statementOrigin": "artist_intent" if origin == 0 else "estate_statement"}
            and record[8][5] == (1 if origin == 0 else 3) and value["predecessor"] == (None if row[7] == ZERO else row[7]),
            "conservation original intent/estate/predecessor differs")
        entry = value["interview"]
        if interview_status == 1:
            require(entry["kind"] == "interview_waived" and interview == EMPTY_RECORD and row[5] == ZERO and row[6] == 0,
                "conservation explicit interview waiver differs")
            return []
        require(entry["kind"] == "present" and interview[1] == 2, "conservation parent interview status differs")
        locator = entry["record"]
        require(locator == {"chainId": self.a["chainId"], "core": self.a["core"], "host": self.a["host"],
            "recordHash": interview[0], "schemaId": schema_id(interpretation.INTERVIEW),
            "profileHash": keccak256(DEFINITIONS[interpretation.PROFILES[interpretation.INTERVIEW]])},
            "conservation exact parent interview locator differs")
        other = self._original(interview[0], 2, subject)
        require(other["nativeEvidence"] == json_values(interview) and other["association"] == json_values(association),
            "conservation interview original/association differs")
        reference = entry["payload"]; h = reference["hash"]
        ref = (h["algorithm"], h["canonicalizationId"], hex_bytes(h["digest"]), reference["uri"])
        require(row[5] == keccak256(encode((REFERENCE,), (ref,))), "conservation full interview Reference differs")
        expected = 0
        if h["canonicalizationId"] == JCS_ID and h["algorithm"] in (1, 2):
            payload = hex_bytes(other["payloadHex"])
            digest = keccak256(payload) if h["algorithm"] == 1 else "0x" + hashlib.sha256(payload).hexdigest()
            require(h["digest"] == digest, "conservation exact interview payload digest differs")
            expected = h["algorithm"]
        require(row[6] == expected, "conservation interview payload correspondence differs")
        return [(r[0], r[1], uint(r[2])) for r in other["catalogs"]]

    def _scope(self, subject, origin):
        a, cid = self.a, uint(self.a["collectionId"])
        head = self._one(a["conservationSelector"], "currentConservation(uint256,bytes32,uint8)", SELECTION,
            ("uint256", "bytes32", "uint8"), (cid, subject, origin))
        if head[0][0] == ZERO:
            require(head == EMPTY_SELECTION, "conservation partial empty selected head")
            return {"status": "absent_on_bound_selector", "current": json_values(head), "history": [], "catalogs": [], "events": [],
                "currentEligibility": {"checked": False, "eligible": False, "reasons": ["no_selected_head"]}}
        require(0 < head[9] <= MAX_REVISIONS, "conservation selected revision bound")
        history, catalogs, previous, progress = [], [], EMPTY_SELECTION, {}
        for revision in range(1, head[9] + 1):
            row = self._one(a["conservationSelector"], "conservationSelectionAt(uint256,bytes32,uint8,uint64)", SELECTION,
                ("uint256", "bytes32", "uint8", "uint64"), (cid, subject, origin, revision))
            require(row[0][0] != ZERO and row[2] == origin and row[7] == previous[0][0] and row[8] != ZERO_ADDRESS
                and row[9] == revision and previous[10] <= row[10] <= uint(a["timestamp"])
                and previous[0][4] <= row[0][4] <= row[10] and selection_hash(a, subject, row) == row[12],
                "conservation selected hash/predecessor/time differs")
            lane, index = row[0][1], row[0][5]
            require(lane not in progress or index > progress[lane], "conservation per-kind selected index regresses")
            progress[lane] = index
            expected = self._selected_originals(row, subject)
            count = self._one(a["conservationSelector"], "selectionCatalogCount(uint256,bytes32,uint8,uint64)", "uint256",
                ("uint256", "bytes32", "uint8", "uint64"), (cid, subject, origin, revision))
            require(count == len(expected) <= MAX_CATALOGS, "conservation catalog occurrence count differs")
            pins = [self._one(a["conservationSelector"], "selectionCatalogAt(uint256,bytes32,uint8,uint64,uint256)", CATALOG_PIN,
                ("uint256", "bytes32", "uint8", "uint64", "uint256"), (cid, subject, origin, revision, i)) for i in range(count)]
            require(pins == expected and row[11] == keccak256(encode((Array(CATALOG_PIN, MAX_CATALOGS),), (pins,))),
                "conservation complete ordered catalog pins differ")
            history.append(json_values(row)); catalogs.append(json_values(pins)); previous = row
        require(previous == head, "conservation final selected history/head differs")
        reasons = []
        if not self.fixed_definitions_active: reasons.append("fixed_definition_inactive")
        if any(self.documents[p[0]]["facts"][2] != "0" for p in catalogs[-1]): reasons.append("selected_catalog_inactive")
        if not self.association_eligible or self.current_association != head[1]: reasons.append("current_association_differs")
        if not reasons:
            current = self._one(a["conservationSelector"], "requireCurrent(uint256,bytes32,uint8,bytes32,uint64)", SELECTION,
                ("uint256", "bytes32", "uint8", "bytes32", "uint64"), (cid, subject, origin, head[0][0], head[9]))
            require(current == head, "conservation native consuming eligibility differs")
        return {"status": "selected", "current": json_values(head), "history": history, "catalogs": catalogs, "events": [],
            "currentEligibility": {"checked": not reasons, "eligible": not reasons, "reasons": reasons}}

    def _preparations(self):
        for digest, original in list(self.records.items()):
            if original["record"][0] != RECORD_TYPES[2]: continue
            row = self._one(self.a["conservationSelector"], "preparedInterview(bytes32)", PREPARED, ("bytes32",), (digest,))
            if row[-1] == ZERO:
                require(row == EMPTY_PREPARED, "conservation partial empty interview preparation")
                self.preparations[digest] = {"recordHash": digest, "status": "not_prepared", "wire": json_values(row), "event": None}
                continue
            require(row[0] == uint(self.a["collectionId"]) and row[1] == original["record"][1]
                and json_values(row[2]) == original["association"] and json_values(row[3]) == original["nativeEvidence"]
                and json_values(row[4]) == original["catalogs"] and preparation_hash(self.a, row) == row[-1],
                "conservation original interview preparation differs")
            self.preparations[digest] = {"recordHash": digest, "status": "prepared", "wire": json_values(row), "event": None,
                "adoptionUsedPreparationProven": False}

    def _filters(self, scopes):
        a = self.a
        cid = "0x" + uint(a["collectionId"]).to_bytes(32, "big").hex()
        subjects = [scope["subjectId"] for scope in scopes.values()]
        filters = [{"address": a["host"], "topics": [artist.METADATA_RECORDED, cid, list(RECORD_TYPES), subjects]},
            {"address": a["conservationSelector"], "topics": [[SELECTED_EVENT, LOCKED_EVENT], cid, subjects]}]
        originals, interviews = sorted(self.records), sorted(self.preparations)
        for start in range(0, len(originals), 64):
            filters.append({"address": a["host"], "topics": [artist.CONSUMED, None, originals[start:start + 64]]})
        for start in range(0, len(interviews), 64):
            filters.append({"address": a["conservationSelector"], "topics": [PREPARED_EVENT, interviews[start:start + 64]]})
        return filters

    @staticmethod
    def _position(log):
        return tuple(quantity(log[k]) for k in ("blockNumber", "logIndex"))

    def _events(self, history, scopes):
        a = self.a
        subjects = {scope["subjectId"]: scope for scope in scopes.values()}
        consumed = {}
        for log in history["logs"]:
            topics = log["topics"]
            if log["address"] == a["host"] and topics[0] == artist.METADATA_RECORDED:
                require(len(topics) == 4, "conservation publication topic shape")
                values = decode((RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"), hex_bytes(log["data"]), maximum=32768)
                original = self.records.get(values[1])
                if original is None: continue
                receipt = original["receipt"]
                require(original["publication"] is None and json_values(values[0]) == original["record"]
                    and values[2:] == (receipt[5], receipt[1], "0x" + (1).to_bytes(32, "big").hex(), 1)
                    and topics[1:] == ["0x" + uint(a["collectionId"]).to_bytes(32, "big").hex(), original["record"][0], original["record"][1]]
                    and receipt[3] == history["blockTimestamps"][str(quantity(log["blockNumber"]))],
                    "conservation original publication event differs")
                original["publication"] = log
            elif log["address"] == a["host"] and topics[0] == artist.CONSUMED:
                require(len(topics) == 4 and topics[2] in self.records and topics[2] not in consumed,
                    "conservation consumption event duplicate/shape")
                original = self.records[topics[2]]
                require(topics[1] == original["receipt"][8] and topics[3] == "0x" + encode(("address",), (original["receipt"][1],)).hex(),
                    "conservation native consumed authorization event differs")
                caller, = decode(("address",), hex_bytes(log["data"]))
                require(caller != ZERO_ADDRESS, "conservation zero consumption caller")
                consumed[topics[2]] = log
            elif log["address"] == a["conservationSelector"] and topics[0] == SELECTED_EVENT:
                require(len(topics) == 4 and topics[2] in subjects, "conservation selection event topics")
                row, = decode((SELECTION,), hex_bytes(log["data"]), maximum=1600)
                require(row[2] in (0, 1), "conservation event origin")
                lane = subjects[topics[2]]["origins"]["artist" if row[2] == 0 else "estate"]
                index = len(lane["events"])
                require(index < len(lane["history"]) and json_values(row) == lane["history"][index]
                    and row[0][0] == topics[3] and str(row[10]) == history["blockTimestamps"][str(quantity(log["blockNumber"]))],
                    "conservation selected event/history differs")
                lane["events"].append(log)
            elif log["address"] == a["conservationSelector"] and topics[0] == LOCKED_EVENT:
                require(len(topics) == 3 and topics[2] in subjects, "conservation lock event topics")
                scope = subjects[topics[2]]
                locked, = decode((LOCK,), hex_bytes(log["data"]), maximum=288)
                require(scope["lockEvent"] is None and locked[0] and json_values(locked) == scope["lock"]
                    and str(locked[-1]) == history["blockTimestamps"][str(quantity(log["blockNumber"]))],
                    "conservation lock event/state differs")
                scope["lockEvent"] = log
            elif log["address"] == a["conservationSelector"] and topics[0] == PREPARED_EVENT:
                require(len(topics) == 4 and topics[1] in self.preparations and log["data"] == "0x",
                    "conservation preparation event shape")
                row = self.preparations[topics[1]]
                preparer, = decode(("address",), hex_bytes(topics[2]))
                require(row["status"] == "prepared" and row["event"] is None and topics[3] == row["wire"][-1]
                    and preparer != ZERO_ADDRESS, "conservation preparation event/state differs")
                row["event"] = log
        require(len({r["receipt"][8] for r in self.records.values()}) == len(self.records), "conservation reused original authorization")
        require(set(consumed) == set(self.records), "conservation original consumption event missing")
        for digest, row in self.records.items():
            pub, use = row["publication"], consumed[digest]
            require(pub is not None and pub["transactionHash"] == use["transactionHash"]
                and self._position(pub) < self._position(use), "conservation publication/consumption order differs")
            row["consumption"] = use
        for scope in scopes.values():
            for lane in scope["origins"].values():
                require(len(lane["events"]) == len(lane["history"]), "conservation selected event missing")
                for row, log in zip(lane["history"], lane["events"]):
                    for evidence in (row[0], row[4]):
                        if evidence[0] == ZERO: continue
                        require(self._position(self.records[evidence[0]]["consumption"]) < self._position(log),
                            "conservation selection precedes original publication")
            locked, event = scope["lock"], scope["lockEvent"]
            if not locked[0]:
                require(locked == json_values(EMPTY_LOCK) and event is None, "conservation partial empty intent lock")
            else:
                lane = scope["origins"]["artist"]
                require(lane["status"] == "selected", "conservation lock without Artist head")
                head, selection_event = lane["history"][-1], lane["events"][-1]
                require(locked[1] != ZERO_ADDRESS and locked[2:6] == [head[1][0], head[1][3], head[1][1], head[1][2]]
                    and locked[6:8] == [head[0][0], head[9]] and uint(head[10]) <= uint(locked[8]) <= uint(a["timestamp"])
                    and event is not None and self._position(selection_event) < self._position(event),
                    "conservation original Artist lock join differs")
        for digest, row in self.preparations.items():
            require((row["event"] is not None) == (row["status"] == "prepared"), "conservation preparation event missing")
            if row["event"] is not None:
                require(self._position(self.records[digest]["consumption"]) < self._position(row["event"]),
                    "conservation preparation precedes original interview")

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed conservation capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
            return self._snapshot
        except (KeyError, TypeError, ValueError, IndexError, OverflowError, ValidationError) as exc:
            if isinstance(exc, MuseumError): raise
            raise MuseumError("malformed conservation source evidence") from exc

    def _capture(self):
        a = self.a
        binding = self._bindings()
        binding["artistSuite"] = self._suite()
        association = self._current_association()
        self._definitions()
        identity = self._read(a["core"], "tokenCollectionIdentity(uint256)", ("uint256",), (uint(a["tokenId"]),),
            ("bool", "uint256", "uint256", "bool"))[1]
        lifecycle = self._one(a["core"], "tokenLifecycle(uint256)", "uint8", ("uint256",), (uint(a["tokenId"]),))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0
            and lifecycle in (2, 3) and identity[3] == (lifecycle == 3), "conservation token identity/lifecycle differs")
        scopes = {}
        for kind in ("collection", "token"):
            subject = subject_id(kind, a["chainId"], a["core"], a["collectionId"], token_id=a["tokenId"] if kind == "token" else "0")
            scopes[kind] = {"subjectId": subject, "origins": {name: self._scope(subject, origin)
                for name, origin in (("artist", 0), ("estate", 1))},
                "lock": json_values(self._one(a["conservationSelector"], "intentLock(uint256,bytes32)", LOCK,
                    ("uint256", "bytes32"), (uint(a["collectionId"]), subject))), "lockEvent": None}
        self._preparations()
        history = scan_public_history(self.reader, a, filters=self._filters(scopes))
        self._events(history, scopes)
        for scope in scopes.values():
            for name, origin in (("artist", 0), ("estate", 1)):
                current = self._one(a["conservationSelector"], "currentConservation(uint256,bytes32,uint8)", SELECTION,
                    ("uint256", "bytes32", "uint8"), (uint(a["collectionId"]), scope["subjectId"], origin))
                require(json_values(current) == scope["origins"][name]["current"], "conservation final head changed")
        source_header = next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash"
            and row["params"] == [a["blockHash"], False])
        require(self.reader.request("eth_getBlockByHash", [a["blockHash"], False]) == source_header
            and self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False]) == source_header,
            "conservation final source anchor changed")
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
            "source": a, "mode": "caller_admitted_rpc" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "binding": binding, "identity": {"tokenId": a["tokenId"], "collectionId": a["collectionId"],
                "collectionSerial": str(identity[2]), "lifecycle": str(lifecycle), "burned": identity[3]},
            "scopes": scopes, "records": list(self.records.values()), "preparations": list(self.preparations.values()),
            "documents": list(self.documents.values()), "currentAssociation": association,
            "historyCoverage": history["coverage"], "claims": CLAIMS, "qualification": QUALIFICATION,
            "remaining": ["Required native tier declaration and authoritative producer binding.",
                "Required complete declaration/first-mint history for a default tier.", "Required native tier-dependent sale-floor enforcement.",
                "Other acquisition-packet requirements; selected conservation does not complete item13 or a full packet."]})
        require(len(result) <= MAX_OUTPUT, "conservation snapshot bound")
        return result
