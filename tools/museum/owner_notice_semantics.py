"""Original owner notice statements with exact registered semantic authorities.

This new profile leaves the original catalogue, schema and export formats intact.
Publication authority is the admitted native receipt, never a payload speaker flag.
"""
from pathlib import Path

from tools.metadata import owner_notice_profile as meaning

from .account_profile import JCS_BYTES, JCS_ID
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import decode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport
from .independent_catalog_source import IndependentCatalogSource
from .independent_source import IndependentSourceAdapter
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, require
from .owner_catalog_source import OwnerCatalogSource
from .ownership_source import OwnershipSource

PROFILE = "STREAM_MUSEUM_OWNER_NOTICE_SEMANTICS_V1"
STEWARD, RESPONSE = schema_id("STEWARD_DESIGNATION"), schema_id("RECOVERY_RESPONSE")
INDEPENDENT_RESPONSE = schema_id("INDEPENDENT_PRESERVATION_EVENT")
DESIGNATED = schema_id("OwnerStewardDesignated(uint256,address,bytes32,bytes32,uint16)")
FAMILIES = {STEWARD: (meaning.STEWARD, meaning.SP), RESPONSE: (meaning.RESPONSE, meaning.RP)}
DOCUMENTS = {name: (kind, meaning.canonical(function(family)))
    for family, profile_name in FAMILIES.values()
    for name, kind, function in ((family, 0, meaning.schema), (profile_name, 2, meaning.profile))}
DOCUMENTS["RFC8785_JCS"] = (1, JCS_BYTES)
QUALIFICATION = ("Original owner-authorized notice statements and independent attestor statements are kept separate. "
    "Designation grants notice standing only; response is an authored acknowledgement or objection, never a veto. "
    "Endpoint and identity references prove neither institutional identity, external delivery, receipt nor assent. "
    "Historical receipt authority and same-block read consistency are not Ethereum consensus or actual-chain acceptance.")
CLAIMS = {"originalReceiptsRetained": True, "registeredDefinitionBytesChecked": True,
    "institutionalIdentityProven": False, "externalDeliveryProven": False, "recipientReceiptProven": False,
    "institutionalAssentProven": False, "writeAuthorityGranted": False, "vetoAuthorityGranted": False,
    "recoveryExecutionInferredFromResponse": False, "globalHostCompleteness": False,
    "actualChainAcceptance": False, "fullObjectDossierConformance": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_projection",
    "definitions": [{"name": name, "kind": str(kind), "hash": keccak256(raw), "bytes": str(len(raw)),
        "registeredCanonicalizationId": RAW_BYTES} for name, (kind, raw) in sorted(DOCUMENTS.items())],
    "rules": {"authority": "Owner receipts establish owner at publication; independent class5 is its own voice.",
        "designation": "Only original OwnerStewardDesignated events advance the per-author designation head; generic same-family records do not.",
        "current": "Current designation needs same-block concrete ownership history; burn retains history and has no current notice target.",
        "response": "Retain scheduled action ID, manifest, class, grounds and ordered references without interpreting them as execution or veto.",
        "definitions": "Exact immutable schema/profile/JCS bytes and original receipt definition hashes; retired definitions remain readable.",
        "graph": "Statements become attributed LinguisticObjects; lexical institutions/accounts are not promoted to verified agents."},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def same_state(left, right):
    for key in ("chainId", "core", "blockNumber", "blockHash", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash"):
        require(left[key] == right[key], "owner notice source state differs: " + key)


def consistent_reads(transcripts):
    """Reject contradictory same-request answers across independently replayed inputs."""
    seen = {}
    for raw in transcripts:
        for row in loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)["calls"]:
            key, value = dumps([row["method"], row["params"]]), dumps(row["result"])
            require(key not in seen or seen[key] == value, "owner notice cross-source RPC result differs")
            seen[key] = value


def designation_events(catalogue, snapshot):
    """The concrete complete-history reader already authenticated every receipt/log."""
    records = {row["recordHash"]: row for row in snapshot["records"]}
    events = {}
    for call in loads(catalogue.transcript(), maximum=MAX_TRANSCRIPT, canonical=True)["calls"]:
        if call["method"] != "eth_getTransactionReceipt":
            continue
        for log in call["result"]["logs"]:
            topics = log["topics"]
            if log["address"] != catalogue.a["host"] or not topics or topics[0] != DESIGNATED:
                continue
            require(len(topics) == 4, "steward event topics differ")
            token, = decode(("uint256",), hex_bytes(topics[1], 32))
            if token != uint(catalogue.a["tokenId"]):
                continue
            owner, = decode(("address",), hex_bytes(topics[2], 32))
            predecessor, version = decode(("bytes32", "uint16"), hex_bytes(log["data"]))
            digest = topics[3]
            require(version == 1 and digest in records and digest not in events, "steward event original missing/duplicate")
            saved = records[digest]
            require(saved["record"][0] == STEWARD and saved["receipt"][1] == owner,
                "steward event family/author differs")
            position = saved["publication"]
            require(all(log[key] == position[key] for key in ("blockHash", "transactionHash"))
                and int(log["transactionIndex"], 16) == uint(position["transactionIndex"])
                and int(log["blockNumber"], 16) == uint(position["blockNumber"])
                and int(log["logIndex"], 16) > uint(position["logIndex"]),
                "steward event does not follow original publication")
            events[digest] = {"owner": owner, "predecessor": predecessor, "event": log}
    return events


class OwnerNoticeSemanticSource:
    """Whole selected token's two owner families plus explicitly supplied independent scopes."""
    _read = IndependentSourceAdapter._read
    _block = IndependentSourceAdapter._block
    _chunk = IndependentSourceAdapter._chunk
    _document = IndependentSourceAdapter._document

    def __init__(self, catalogue, transport, *, ownership=None, independents=()):
        require(type(catalogue) is OwnerCatalogSource, "concrete owner catalogue required")
        require(ownership is None or type(ownership) is OwnershipSource, "concrete ownership history required")
        require(type(independents) in (tuple, list) and len(independents) <= 8
            and all(type(item) is IndependentCatalogSource for item in independents), "independent notice source bound/type")
        require(catalogue.provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport),
            "owner notice synthetic transport cannot become trusted")
        self.catalogue, self.ownership, self.independents = catalogue, ownership, tuple(independents)
        self.a, self.pins, self.provenance = catalogue.a, catalogue.pins, catalogue.provenance
        self.anchor_bytes = catalogue.anchor_bytes
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self.documents, self.document_stack, self.chunks = {}, set(), {}
        self.document_bytes, self._started, self._snapshot = 0, False, None

    def transcript(self):
        require(self._snapshot is not None, "owner notice semantic snapshot required")
        return self.reader.transcript()

    def _definition(self, name):
        kind, raw = DOCUMENTS[name]
        identifier = schema_id(name)
        self._document(identifier, kind)
        _, actual, view = self.documents[identifier]
        return (actual == raw and view[3][2] == keccak256(raw)
            and view[3][3] == RAW_BYTES and view[3][4] == ZERO)

    def _interpret(self, saved, host, *, independent=False):
        record, receipt = saved["record"], saved["receipt"]
        family = RESPONSE if independent else record[0]
        name, profile_name = FAMILIES[family]
        content = record[2] if independent else record[3]
        schema = record[4] if independent else record[2]
        payload = hex_bytes(saved["payloadHex"] if independent else record[5])
        selector = {"chainId": self.a["chainId"], "core": self.a["core"], "host": host,
            "tokenId": self.a["tokenId"], "recordHash": saved["recordHash"], "recordType": record[0],
            "subjectId": record[1], "schemaId": schema, "scopeKey": receipt[0],
            "recordIndex": receipt[4] if independent else receipt[3], "author": receipt[1],
            "blockHash": self.a["blockHash"], "blockNumber": self.a["blockNumber"]}
        authority = {"carrier": "independent_attestor" if independent else "historical_token_owner",
            "author": receipt[1], "recordedAt": receipt[3] if independent else receipt[2],
            "relayedOwnerAuthorization": False if independent else receipt[5],
            "stewardAssumedSigner": False, "ownerStandingAtPublication": not independent,
            "institutionalIdentityProven": False, "institutionalAssentProven": False}
        row = {"source": selector, "original": saved, "family": name, "authority": authority,
            "payloadHex": "0x" + payload.hex(), "status": "unsupported", "reasonCode": None,
            "value": None, "nativeEffectiveAt": record[7] if independent else record[6]}
        if schema != schema_id(name) or content[2] != JCS_ID:
            row["reasonCode"] = "original_schema_or_canonicalization_unsupported"
            return row
        self._document(schema, 0, receipt[9])
        self._document(content[2], 1, receipt[10])
        if not all([self._definition(name), self._definition(profile_name), self._definition("RFC8785_JCS")]):
            row["reasonCode"] = "registered_definition_bytes_unsupported"
            return row
        if content[0] != "1" or not payload or keccak256(payload) != content[1]:
            row["reasonCode"] = "embedded_keccak_payload_required"
            return row
        require(self._chunk(keccak256(payload)) == payload, "owner notice retained payload differs")
        try:
            value = meaning.validate(payload, name)
        except meaning.NoticeError as exc:
            raise MuseumError("owner notice original semantic payload invalid: " + str(exc)) from exc
        require(value["subjectId"] == record[1]
            and value["profileHash"] == keccak256(DOCUMENTS[profile_name][1]), "owner notice subject/profile differs")
        row.update(value=value, status="supported", reasonCode=None,
            registeredAuthorities={"schemaDefinitionHash": receipt[9], "canonicalizationDefinitionHash": receipt[10],
                "profileId": schema_id(profile_name), "profileDefinitionHash": value["profileHash"]})
        return row

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed owner notice semantics cannot resume")
        self._started = True
        try:
            return self._capture()
        except MuseumError:
            raise
        except (KeyError, IndexError, TypeError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed owner notice semantic evidence") from exc

    def _capture(self):
        raw_catalogue = self.catalogue.snapshot()
        catalogue = loads(raw_catalogue, maximum=MAX_TRANSCRIPT, canonical=True)
        self._block()
        for key in ("host", "core", "schemas", "store"):
            require(keccak256(hex_bytes(self.reader.code(self.a[key]))) == self.pins[self.a[key]],
                "owner notice semantic runtime differs")
        owner_rows = [self._interpret(saved, self.a["host"]) for saved in catalogue["records"]
            if saved["record"][0] in FAMILIES]
        by_hash = {row["source"]["recordHash"]: row for row in owner_rows}
        typed = designation_events(self.catalogue, catalogue)
        heads = {}
        designation_order = sorted((by_hash[digest] for digest in typed), key=lambda row: uint(row["source"]["recordIndex"]))
        for row in designation_order:
            digest, author = row["source"]["recordHash"], row["source"]["author"]
            predecessor = heads.get(author, ZERO)
            require(typed[digest]["predecessor"] == predecessor, "steward per-author predecessor differs")
            if row["status"] == "supported":
                require((row["value"]["predecessor"] or ZERO) == predecessor, "steward payload predecessor differs")
            row["designation"] = {"predecessor": predecessor, "event": typed[digest]["event"],
                "noticeStandingOnly": True, "current": False}
            heads[author] = digest
        for row in owner_rows:
            if row["source"]["recordType"] == STEWARD and row["status"] == "supported":
                require(row["source"]["recordHash"] in typed, "typed steward designation event missing")
        for author, digest in sorted(heads.items()):
            _, (actual,) = self._read(self.a["host"], "stewardDesignationFor(uint256,address)",
                ("uint256", "address"), (uint(self.a["tokenId"]), author), ("bytes32",))
            require(actual == digest, "native steward per-author head differs")
        current = {"status": "not_captured", "owner": None, "recordHash": None,
            "reasonCode": "same_block_ownership_source_not_supplied"}
        transcripts = [self.catalogue.transcript()]
        ownership_hash = None
        if self.ownership is not None:
            same_state(self.a, self.ownership.a)
            require(self.ownership.a["tokenId"] == self.a["tokenId"]
                and self.ownership.a["coreRuntimeHash"] == self.pins[self.a["core"]]
                and self.ownership.provenance == self.provenance, "owner notice ownership identity/pin/provenance differs")
            raw = self.ownership.snapshot(); ownership_hash = keccak256(raw)
            identity = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)["identity"]
            transcripts.append(self.ownership.transcript())
            if identity["lifecycle"] == "3":
                current = {"status": "burned_no_current_owner", "owner": ZERO_ADDRESS,
                    "recordHash": ZERO, "reasonCode": None}
            else:
                owner = identity["owner"]
                _, observed = self._read(self.a["host"], "currentStewardDesignation(uint256)",
                    ("uint256",), (uint(self.a["tokenId"]),), ("address", "bytes32"))
                require(observed == (owner, heads.get(owner, ZERO)), "current steward/ownership history differs")
                current = {"status": "no_designation" if observed[1] == ZERO else "recorded_notice_target",
                    "owner": owner, "recordHash": observed[1], "reasonCode": None}
                if observed[1] != ZERO:
                    by_hash[observed[1]]["designation"]["current"] = True
        independent_rows, independent_sources, seen = [], [], set()
        for source in self.independents:
            same_state(self.a, source.a)
            require(all(self.a[key] == source.a[key] and self.pins[self.a[key]] == source.pins[source.a[key]]
                for key in ("schemas", "store")) and source.provenance == self.provenance,
                "independent notice dependency/provenance differs")
            key = (source.a["host"], source.a["scopeKey"])
            require(key not in seen, "duplicate independent notice source")
            seen.add(key)
            raw = source.snapshot(); snapshot = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
            independent_sources.append({"host": source.a["host"], "scopeKey": source.a["scopeKey"], "snapshotHash": keccak256(raw)})
            transcripts.append(source.reader.transcript())
            for saved in snapshot["records"]:
                if saved["record"][0] != INDEPENDENT_RESPONSE or saved["record"][4] != schema_id(meaning.RESPONSE):
                    continue
                if saved["record"][1] != catalogue["subjectId"]:
                    continue
                require(saved["subject"][0] == "1" and saved["subject"][2] == self.a["tokenId"],
                    "independent recovery response token subject differs")
                independent_rows.append(self._interpret(saved, source.a["host"], independent=True))
        self._block()
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        transcripts.append(self.reader.transcript()); consistent_reads(transcripts)
        self._snapshot = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "caller_admitted_rpc_semantics" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "sourceState": catalogue["sourceState"], "subjectId": catalogue["subjectId"],
            "ownerCatalogueHash": keccak256(raw_catalogue), "ownershipHash": ownership_hash,
            "independentSources": independent_sources, "transcriptHash": keccak256(self.reader.transcript()),
            "ownerStatements": owner_rows, "independentStatements": independent_rows,
            "designationHeads": [{"author": author, "recordHash": digest} for author, digest in sorted(heads.items())],
            "currentDesignation": current,
            "documents": [{"documentId": key, "rawViewHex": "0x" + raw.hex(), "payloadHex": "0x" + payload.hex()}
                for key, (raw, payload, _) in sorted(self.documents.items())],
            "claims": CLAIMS, "qualification": QUALIFICATION})
        return self._snapshot
