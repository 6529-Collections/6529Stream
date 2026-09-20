"""ART38 V2 supplied standing-conflict history and historical acknowledgement joins."""
from dataclasses import dataclass
from pathlib import Path

from . import artist_c2pa as v1
from .canonical import dumps, hex_bytes, keccak256, schema_id, subject_id
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, require

SOURCE_REVISION = "e21d58e402f171a94009696b7f9373c12ed3a64f"
SOURCE_PINS = {
    "smart-contracts/interfaces/stream/metadata/IStreamC2PAConflicts.sol": "13c8bca985289e50421dd8024b48bfe87488601a2c1cdac1777ce27f66f02e17",
    "smart-contracts/domains/metadata/StreamC2PAConflicts.sol": "94804545d624f3b2317113a49dda13418671628dc223f299b846fd321862d03f",
    "smart-contracts/domains/metadata/StreamC2PAReconciliation.sol": "0f9fa731f72e1d2c7b2909a8be35a2473ea2642919fea624d94e4e3552484446",
    "smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol": "0668a4076a94f107c8fa98b02b425a6d5b6cbe2935c8985beea4000da2aa267d",
    "smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol": "bc5b04c6c407bcf8355158477f4f0782057569e0f6639c5ca18727f638972a02",
    "smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol": "a908d04e1d1b77f9f077301d6ebb22e0a448b2883da04ef9dedd8989318f3539",
    "smart-contracts/domains/metadata/StreamStaticC2PAAttributionCompanion.sol": "f12917fec7ea7de37555e868c8133510b6b5f23c3e2b2b7524f1d0652df2d564",
}
NAME = "STREAM_MUSEUM_ARTIST_C2PA_CONSUMPTION_V2"
DOMAIN = schema_id("6529STREAM_C2PA_STANDING_CONFLICT_V1")
CHAIN = schema_id("6529STREAM_C2PA_CONFLICT_CHAIN_V1")
DISPOSITION = schema_id("6529STREAM_C2PA_DISPUTE_DISPOSITION_V1")
STANDING_FIELDS = ("conflictId", "chainHash", "recordHash", "selectionHash", "revision", "unresolvedCount")
STANDING = ("bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint64")
CONFLICT_FIELDS = ("conflictId", "collectionId", "subjectId", "artistId", "bindingHash", "generation",
    "recordHash", "selectionHash", "previousConflict", "chainHash", "revision", "recordedAt")
CONFLICT = ("bytes32", "uint256", "bytes32", "bytes32", "bytes32", "uint64",
    "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint64")
RESOLUTION_FIELDS = ("actionId", "disputeRecordHash", "evidenceHash", "narrativeHash", "acknowledgedAt")
RESOLUTION = ("bytes32", "bytes32", "bytes32", "bytes32", "uint64")
FILING = ("uint256", "uint64", "uint8", "bytes32", "bytes32")
ARTIST_STANDING = ("bytes32", "uint64", "uint32", "bytes32")
ARTIST_HEAD = ("bytes32", "bytes32", "bytes32", "uint8", "uint8", "bool", "bool")
ARTIST_RECORD = ("bytes32", FILING, "address", "uint8", "uint256", "uint64",
    "bytes32", "bytes32", "bytes32", "bytes32", ARTIST_STANDING, "bytes32")
REQUEST = ("uint256", "uint64", "bytes32", "uint8", "bytes32", "bytes32", "bytes32")
ARTIST_RESOLUTION = (REQUEST, "bytes32", "address", "address", "uint8", "uint8", "uint64", "bytes32", "bytes32")
EVIDENCE = ("uint16", "uint256", "uint64", "bytes32", "bytes32", "bytes32")
COVERAGE = ("bytes32",) * 12
EMPTY_STANDING = (ZERO, ZERO, ZERO, ZERO, 0, 0)
EMPTY_RESOLUTION = (ZERO, ZERO, ZERO, ZERO, 0)
MAX_HISTORY = v1.MAX_HISTORY
CLAIMS = {**v1.CLAIMS, "suppliedConflictPrefixChecked": True,
    "historicalAcknowledgementGuardsRequiredForClearedRows": True, "laterDisputesAutomaticallyRevive": False,
    "op46GovernanceAuthenticated": False, "op46ArchiveAuthenticated": False,
    "underlyingCoverageReceiptsVerified": False, "originalArtistNativeReceiptInvented": False}
QUALIFICATION = ("Supplied native ABI, hashes and original acknowledgement-guard correspondence only. "
    "A closed original-generation Artist Head is a separate historical observation at acknowledgement time; "
    "current Artist Head and live Display remain separate. No latest-binding promotion, automatic conflict revival, "
    "source authentication, op46 governance/signature/event/archive proof, native Artist receipt, external C2PA validation "
    "or frozen-output conformance is inferred. No RPC, URI fetching or state mutation.")


@dataclass(frozen=True)
class ConflictEvidence:
    at: bytes
    record: bytes
    resolution: bytes
    narrative: bytes


@dataclass(frozen=True)
class Acknowledgement:
    conflict_id: str
    block_number: int
    block_hash: str
    block_timestamp: int
    original_resolution: bytes
    closed_head: bytes
    opening: bytes
    evidence_chunk: bytes
    narrative_chunk: bytes
    coverage_address: bytes
    coverage_code_hash: bytes
    coverage_code: bytes
    coverage_facts: bytes
    current_head: bytes | None = None


@dataclass(frozen=True)
class ScopeEvidence:
    context: v1.Context
    definition: bytes
    current: bytes
    selections: tuple
    display: bytes
    reports: tuple
    standing: bytes
    history: tuple
    acknowledgements: tuple
    attribution: str
    chunks: str


def _standing(raw):
    value, = decode((STANDING,), raw, maximum=192)
    if value[4] == 0:
        require(value == EMPTY_STANDING, "C2PA conflict partial empty Standing")
    else:
        require(value[1] != ZERO and value[5] <= value[4], "C2PA conflict Standing chain/count")
        require((value[0] == value[2] == value[3] == ZERO) if value[5] == 0
            else all(value[i] != ZERO for i in (0, 2, 3)), "C2PA conflict Standing tail")
    return value


def decode_standing(raw):
    return {**v1._named(STANDING_FIELDS, _standing(raw)), "original": v1._bytes(raw)}


def conflict_hash(context, conflict):
    require(type(context) is v1.Context, "C2PA conflict context type")
    blank = (ZERO, *conflict[1:9], ZERO, *conflict[10:])
    return keccak256(encode(("bytes32", "uint256", "address", "address", "address", CONFLICT),
        (DOMAIN, context.chain_id, context.companion, context.core, context.artist, blank)))


def chain_hash(previous, identifier, revision):
    return keccak256(encode(("bytes32", "bytes32", "bytes32", "uint64"), (CHAIN, previous, identifier, revision)))


def narrative(context, conflict):
    return encode(("bytes32", "uint256", "address", "address", "address", "uint256",
        "bytes32", "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "uint8"),
        (DISPOSITION, context.chain_id, context.companion, context.core, context.artist,
         *conflict[1:6], conflict[0], conflict[9], conflict[6], conflict[7], 1))


def _inputs(scope):
    require(type(scope) is ScopeEvidence and type(scope.context) is v1.Context, "C2PA conflict scope type")
    require(all(type(items) is tuple and len(items) <= MAX_HISTORY for items in
        (scope.selections, scope.reports, scope.history, scope.acknowledgements)), "C2PA conflict history bound")
    values = [scope.definition, scope.current, scope.display, scope.standing, *scope.selections]
    for report in scope.reports:
        require(type(report) is v1.ReportEvidence, "C2PA conflict report type")
        values += [report.record, report.payload, report.observation, report.trust_anchors]
    for item in scope.history:
        require(type(item) is ConflictEvidence, "C2PA conflict evidence type")
        values += [item.at, item.record, item.resolution, item.narrative]
    for item in scope.acknowledgements:
        require(type(item) is Acknowledgement, "C2PA acknowledgement type")
        values += [item.original_resolution, item.closed_head, item.opening, item.evidence_chunk,
            item.narrative_chunk, item.coverage_address, item.coverage_code_hash, item.coverage_code, item.coverage_facts]
        if item.current_head is not None: values.append(item.current_head)
    return values


def _acknowledgement(scope, conflict, stored, item):
    context = scope.context
    encode(("uint256", "uint64"), (item.block_number, item.block_timestamp))
    require(any(hex_bytes(item.block_hash, 32)) and item.conflict_id == conflict[0]
        and item.block_number <= context.block_number and item.block_timestamp == stored[4],
        "C2PA historical acknowledgement observation differs")
    if item.block_number == context.block_number:
        require(item.block_hash == context.block_hash, "C2PA same-block acknowledgement hash differs")
    original, = decode((ARTIST_RESOLUTION,), item.original_resolution, maximum=480)
    head, = decode((ARTIST_HEAD,), item.closed_head, maximum=224)
    opening, = decode((ARTIST_RECORD,), item.opening, maximum=608)
    terms = original[0]
    require(original[1] == stored[0] != ZERO and terms[:3] == (conflict[1], conflict[5], stored[1])
        and stored[1] != ZERO and terms[3] in (1, 2) and terms[4] == stored[2]
        and (2 if terms[3] == 2 else 1) <= original[4] <= 2
        and original[2] != ZERO_ADDRESS and original[3] != ZERO_ADDRESS and original[8] != ZERO
        and 0 < original[6] <= stored[4] and original[6] >= conflict[11]
        and not head[5] and head[0] == terms[2] and head[2] == stored[0],
        "C2PA original dispute resolution/closed Head differs")
    require(opening[0] == terms[2] and opening[1][:3] == (conflict[1], conflict[5], 1)
        and opening[6:8] == (conflict[3], conflict[4]), "C2PA original dispute opening differs")
    raw, = decode(("bytes",), item.evidence_chunk, maximum=8256)
    require(len(raw) == 192 and keccak256(raw) == stored[2] != ZERO, "C2PA covered evidence chunk differs")
    evidence, = decode((EVIDENCE,), raw, maximum=192)
    intended = narrative(context, conflict)
    require(evidence == (1, conflict[1], conflict[5], conflict[4], stored[1], keccak256(intended))
        and stored[3] == evidence[5], "C2PA original typed evidence differs")
    retained, = decode(("bytes",), item.narrative_chunk, maximum=8256)
    require(retained == intended and keccak256(retained) == stored[3], "C2PA original disposition narrative differs")
    coverage_address, = decode(("address",), item.coverage_address, maximum=32)
    coverage_pin, = decode(("bytes32",), item.coverage_code_hash, maximum=32)
    require(coverage_address != ZERO_ADDRESS and type(item.coverage_code) is bytes
        and 0 < len(item.coverage_code) <= 24576 and keccak256(item.coverage_code) == coverage_pin,
        "C2PA supplied archival coverage runtime differs")
    coverage, = decode((COVERAGE,), item.coverage_facts, maximum=384)
    require(coverage[0] != ZERO and coverage[1] != ZERO and coverage[2] == ZERO
        and coverage[3] == stored[2], "C2PA original collection coverage differs")
    if item.current_head is not None:
        decode((ARTIST_HEAD,), item.current_head, maximum=224)
    originals = {name: v1._bytes(getattr(item, name), maximum=24576) for name in
        ("original_resolution", "closed_head", "opening", "evidence_chunk", "narrative_chunk",
         "coverage_address", "coverage_code_hash", "coverage_code", "coverage_facts")}
    return {"conflictId": conflict[0], "basis": "supplied_historical_original_guard_correspondence",
        "observation": {"blockNumber": str(item.block_number), "blockHash": item.block_hash,
            "blockTimestamp": str(item.block_timestamp), "attribution": scope.attribution, "chunks": scope.chunks},
        "originalQuery": {"collectionId": str(conflict[1]), "generation": str(conflict[5])},
        "originalBytes": originals,
        "currentArtistHead": None if item.current_head is None else {
            "original": v1._bytes(item.current_head), "blockNumber": str(context.block_number),
            "blockHash": context.block_hash, "affectsHistoricalAcknowledgement": False},
        "governanceActionOrArchiveVerified": False, "laterDisputesAutomaticallyRevive": False}


def _acknowledgement_observations(scopes):
    observations = {}
    for scope in scopes:
        for item in scope.acknowledgements:
            encode(("uint256", "uint64"), (item.block_number, item.block_timestamp))
            require(any(hex_bytes(item.block_hash, 32)) and any(hex_bytes(item.conflict_id, 32)),
                "C2PA acknowledgement observation identity")
            key = (scope.context.chain_id, item.block_number)
            observed = (item.block_hash, item.block_timestamp)
            require(key not in observations or observations[key] == observed,
                "C2PA conflicting acknowledgement block observations")
            observations[key] = observed


def consume(scope):
    v1._input_budget(_inputs(scope))
    _acknowledgement_observations((scope,))
    for address in (scope.attribution, scope.chunks):
        require(any(hex_bytes(address, 20)), "C2PA conflict supplied dependency address")
    base = v1.consume_reconciliation(scope.context, scope.definition, scope.current,
        scope.selections, scope.display, scope.reports)
    selected = [decode((v1.SELECTION,), raw, maximum=8192)[0] for raw in scope.selections]
    adverse = [s for s in selected if s[6][26] and s[6][25] == 2]
    standing = _standing(scope.standing)
    require(standing[4] == len(scope.history) == len(adverse), "C2PA conflict revision/selection coverage")
    acknowledgements = {}
    for item in scope.acknowledgements:
        require(item.conflict_id not in acknowledgements, "C2PA duplicate acknowledgement")
        acknowledgements[item.conflict_id] = item
    previous, previous_chain, rows, unresolved, used = ZERO, ZERO, [], [], set()
    for revision, (item, selection) in enumerate(zip(scope.history, adverse), 1):
        conflict, = decode((CONFLICT,), item.record, maximum=384)
        at, = decode(("bytes32",), item.at, maximum=32)
        resolution, = decode((RESOLUTION,), item.resolution, maximum=160)
        report = selection[6]
        require(conflict[0] == at != ZERO and conflict[1:6] == report[2:7]
            and conflict[6:8] == (selection[0], selection[2]) and conflict[8] == previous
            and conflict[10] == revision and conflict[0] == conflict_hash(scope.context, conflict)
            and conflict[9] == chain_hash(previous_chain, conflict[0], revision),
            "C2PA original conflict/hash-chain/selection differs")
        intended = narrative(scope.context, conflict)
        observed, = decode(("bytes",), item.narrative, maximum=544)
        require(observed == intended, "C2PA resolutionNarrative getter differs")
        disposition = None
        if resolution[0] == ZERO:
            require(resolution == EMPTY_RESOLUTION, "C2PA partial empty conflict resolution")
            unresolved.append(conflict)
        else:
            require(conflict[0] in acknowledgements and all(resolution[i] != ZERO for i in range(4)),
                "C2PA historical acknowledgement evidence absent")
            disposition = _acknowledgement(scope, conflict, resolution, acknowledgements[conflict[0]])
            used.add(conflict[0])
        rows.append({**v1._named(CONFLICT_FIELDS, conflict), "resolution": v1._named(RESOLUTION_FIELDS, resolution),
            "acknowledgement": disposition, "original": {"at": v1._bytes(item.at), "record": v1._bytes(item.record),
                "resolution": v1._bytes(item.resolution), "narrative": v1._bytes(item.narrative)}})
        previous, previous_chain = conflict[0], conflict[9]
    require(used == set(acknowledgements), "C2PA unrelated acknowledgement")
    tail = unresolved[-1] if unresolved else None
    expected = (ZERO if tail is None else tail[0], previous_chain, ZERO if tail is None else tail[6],
        ZERO if tail is None else tail[7], len(rows), len(unresolved))
    require(standing == expected, "C2PA Standing unresolved tail/count differs")
    return {"profile": NAME, "sourceRevision": SOURCE_REVISION,
        "parentProfileHash": keccak256(v1.profile_bytes()), "reconciliation": base,
        "standing": decode_standing(scope.standing), "conflictHistory": rows,
        "checkedAcknowledgements": str(len(used)),
        "sourceContext": {"chainId": str(scope.context.chain_id), "companion": scope.context.companion,
            "core": scope.context.core, "artist": scope.context.artist, "collectionId": str(scope.context.collection_id),
            "subjectId": scope.context.subject_id, "blockNumber": str(scope.context.block_number),
            "blockHash": scope.context.block_hash, "attribution": scope.attribution, "chunks": scope.chunks},
        "claims": dict(CLAIMS), "qualification": QUALIFICATION}


def consume_static(token_id, raw, collection_scope, token_scope=None):
    encode(("uint256",), (token_id,))
    inputs = [raw, *_inputs(collection_scope)]
    context = collection_scope.context
    require(context.subject_id == subject_id("collection", str(context.chain_id), context.core, str(context.collection_id)),
        "C2PA static collection subject differs")
    token, collection = decode((STANDING, STANDING), raw, maximum=384)
    require(encode((STANDING,), (collection,)) == collection_scope.standing, "C2PA static collection Standing differs")
    if token_id == 0:
        require(token == EMPTY_STANDING and token_scope is None, "C2PA static collection-only token response")
    else:
        require(type(token_scope) is ScopeEvidence, "C2PA static token scope required")
        inputs += _inputs(token_scope)
        other = token_scope.context
        require(other.subject_id == subject_id("token", str(context.chain_id), context.core,
            str(context.collection_id), token_id=str(token_id)), "C2PA static token subject differs")
        require(all(getattr(context, field) == getattr(other, field) for field in v1.Context.__dataclass_fields__
            if field != "subject_id") and collection_scope.attribution == token_scope.attribution
            and collection_scope.chunks == token_scope.chunks, "C2PA static scope contexts differ")
        require(encode((STANDING,), (token,)) == token_scope.standing, "C2PA static token Standing differs")
    v1._input_budget(inputs)
    _acknowledgement_observations((collection_scope,) if token_scope is None else (collection_scope, token_scope))
    return {"profile": NAME, "tokenId": str(token_id), "original": v1._bytes(raw),
        "token": None if token_scope is None else consume(token_scope), "collection": consume(collection_scope),
        "bothScopesRetainedIndependently": True, "claims": dict(CLAIMS), "qualification": QUALIFICATION}


def profile_bytes():
    return dumps({"name": NAME, "version": "2", "status": "prospective_unregistered_supplied_evidence_profile",
        "parentProfileHash": keccak256(v1.profile_bytes()), "sourceRevision": SOURCE_REVISION, "sourceSHA256": SOURCE_PINS,
        "scope": "Historical standing-conflict prefix and original acknowledgement guards; unchanged parent selection/Display decode.",
        "standingBytes": "192", "staticPairBytes": "384", "conflictBytes": "384", "resolutionBytes": "160",
        "originalDispute": {"headBytes": "224", "resolutionBytes": "480", "openingBytes": "608",
            "evidenceBytes": "192", "narrativeBytes": "480", "coverageBytes": "384",
            "headTime": "Explicit historical observation at the stored acknowledgement timestamp; current Head retained separately.",
            "sharedBlockObservations": "Acknowledgements for one chain and block number must agree on block hash and timestamp across both scopes.",
            "nativeReceipt": "Original op46 does not emit an artistNativeReceipt; none is inferred."},
        "limits": {"historyPerScope": str(MAX_HISTORY), "inputOccurrenceBytes": str(v1.MAX_INPUT_BYTES),
            "coverageRuntimeBytes": "24576"}, "claims": CLAIMS, "qualification": QUALIFICATION})


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[2] / "schemas/museum/artist-c2pa-v2/profile.json"
    raw = profile_bytes()
    if args.check:
        require(path.is_file() and path.read_bytes() == raw, "C2PA conflict consumer profile differs")
    else:
        path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print(keccak256(raw))


if __name__ == "__main__":
    main()
