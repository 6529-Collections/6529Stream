"""Native RIGHTS selections with explicitly provider-admitted filtered history.

The selected revision denominator comes from native state. Publication/event
coverage depends on the RPC provider; this profile does not walk genesis or
claim that filtered logs independently prove their own completeness.
"""
from tools.metadata.rights_profile import USES
from .canonical import dumps, keccak256, loads, subject_id, uint
from .current_rights_source import (CurrentRightsSource, PROFILE as ORIGINAL_PROFILE,
    PROFILE_BYTES as ORIGINAL_PROFILE_BYTES, CLAIMS as ORIGINAL_CLAIMS,
    MAX_REVISIONS, MAX_OUTPUT, METADATA_RECORDED, SELECTED_EVENT, SELECTION)
from .independent_wire import json_values, require
from .metadata_rights_source import RECORD_TYPE
from .public_chain_history import (scan_public_history, PROFILE as HISTORY_PROFILE,
    PROFILE_HASH as HISTORY_PROFILE_HASH)
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport


PROFILE = "STREAM_MUSEUM_PUBLIC_RIGHTS_SOURCE_V1"
CLAIMS = dict(ORIGINAL_CLAIMS, nativeSelectedRevisionDenominatorChecked=True,
    filteredEventReceiptCorrespondenceChecked=True, providerLogCompletenessTrusted=True,
    canonicalMappingTrusted=True, genesisWalk=False, allBlockReceipts=False,
    independentlyVerifiedLogCompleteness=False)
QUALIFICATION = (
    "Complete native selected RIGHTS revisions for the bound collection and token, joined to "
    "provider-admitted filtered publication and selection logs over block zero through the source anchor. "
    "Native heads and revision indexes supply the selected-state denominator; filtered RPC log "
    "completeness and canonical block mappings remain provider trust. Returned logs are checked against "
    "their complete receipts and canonical block headers. This is not a genesis header walk or an "
    "all-block receipt capture. Installed ACTIVE Core pointers and the original finality provider bind "
    "the selector. Original notices and known Artist registrations do not establish legal permission, "
    "current publisher authority, date applicability, or full finality eligibility. Token grants, "
    "including unspecified, take precedence per use. Selection absence is not historical RIGHTS absence.")
_rules = dict(loads(ORIGINAL_PROFILE_BYTES)["rules"])
_rules["publication"] = (
    "Only native-derived Metadata collection/RIGHTS/collection-or-token subjects and selector "
    "collection/subjects filters; fixed numeric block zero through anchor under the pinned shared "
    "history profile. Every selected revision and original publication must bijectively join native "
    "events, including publication-before-selection order. Provider completeness remains trusted.")
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "sourceReviewCommit": "75ad082dc4d5f317e0ad89d046f01b571a033ce3",
    "historyProfile": {"id": HISTORY_PROFILE, "hash": HISTORY_PROFILE_HASH},
    "bounds": {"revisionsPerScope": str(MAX_REVISIONS), "scopes": "2", "payloadBytes": "8192",
        "snapshotBytes": str(MAX_OUTPUT), "transcriptBytes": "67108864"},
    "rules": _rules, "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class PublicRightsSource(CurrentRightsSource):
    """Additive capture profile; original native ABI/meaning checks are unchanged."""

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "public RIGHTS provenance")
        a = loads(anchor_bytes, maximum=65536, canonical=True)
        require(type(a) is dict and a.get("profile") == PROFILE, "public RIGHTS anchor shape/profile")
        # Reuse the closed native anchor validator without changing its profile or
        # transport globals. Its constructor performs no RPC reads.
        projected = dict(a, profile=ORIGINAL_PROFILE)
        super().__init__(dumps(projected), transport, provenance="synthetic_fixture")
        self.anchor_bytes, self.a, self.provenance = anchor_bytes, a, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])

    def _filters(self):
        a = self.a
        subjects = [subject_id(kind, a["chainId"], a["core"], a["collectionId"],
            token_id=a["tokenId"] if kind == "token" else "0") for kind in ("collection", "token")]
        cid = "0x" + uint(a["collectionId"]).to_bytes(32, "big").hex()
        return [{"address": a["host"], "topics": [METADATA_RECORDED, cid, RECORD_TYPE, subjects]},
            {"address": a["rightsSelector"], "topics": [SELECTED_EVENT, cid, subjects]}]

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "public RIGHTS failed capture cannot resume"); self._started = True
        a = self.a
        history = scan_public_history(self.reader, a, filters=self._filters())
        source_header = dumps(next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash"
            and row["params"] == [a["blockHash"], False]))
        binding = self._bindings()
        _, identity = self._read(a["core"], "tokenCollectionIdentity(uint256)", ("uint256",), (uint(a["tokenId"]),),
            ("bool", "uint256", "uint256", "bool"))
        lifecycle = self._one(a["core"], "tokenLifecycle(uint256)", "uint8", ("uint256",), (uint(a["tokenId"]),))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0 and lifecycle in (2, 3)
            and identity[3] == (lifecycle == 3), "public RIGHTS token identity/lifecycle differs")
        self._definitions()
        scopes = {kind: self._scope(kind) for kind in ("collection", "token")}
        self._publications(history)
        self._selection_events(history, scopes)
        chosen = scopes["token"] if scopes["token"]["status"] == "present" else scopes["collection"]
        grants = ({use: "unspecified" for use in USES} if chosen["status"] == "absent" else
            {use: self.records[chosen["current"][0]]["value"]["grants"][use]["status"] for use in USES})
        count = sum(value != "unspecified" for value in grants.values())
        completeness = ("absent" if chosen["status"] == "absent" else "specified" if count == 6 else
            "unspecified" if count == 0 else "partially_specified")
        for scope in scopes.values():
            require(json_values(self._one(a["rightsSelector"], "currentRights(uint256,bytes32)", SELECTION,
                ("uint256", "bytes32"), (uint(a["collectionId"]), scope["subjectId"]))) == scope["current"],
                "public RIGHTS final selected head differs")
        require(dumps(self.reader.request("eth_getBlockByHash", [a["blockHash"], False])) == source_header
            and dumps(self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False])) == source_header,
            "public RIGHTS final source header differs")
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "source": a,
            "mode": "caller_admitted_rpc" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "binding": binding, "identity": {"tokenId": a["tokenId"], "collectionId": a["collectionId"],
                "collectionSerial": str(identity[2]), "lifecycle": str(lifecycle), "burned": identity[3]},
            "scopes": scopes, "records": list(self.records.values()), "documents": list(self.documents.values()),
            "artistLicensorIdentities": list(self.artist_identities.values()), "effectiveGrants": grants,
            "completeness": completeness, "historyCoverage": history["coverage"],
            "dateAssessment": "not_assessed_no_inferred_timezone", "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "public RIGHTS snapshot bound")
        self._snapshot = result
        return result
