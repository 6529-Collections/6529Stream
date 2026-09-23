"""Extract original mint bytes from an ALREADY verified retained token fixture.

This pure boundary checks byte/ABI/event correspondence. It neither replays the
containing fixture nor authenticates RPC, signatures, receipt inclusion or the
chain. Entropy registration is historical; terminal entropy requires a separate
same-block reader and complete history. No supplied executable code is loaded.
"""
import hashlib

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import calldata, decode
from .chain_history import LOG_FIELDS, MAX_LOGS_PER_RECEIPT
from .independent_wire import ZERO, require
from .object_dossier_native import validate_reference
from .token_fixture import (BUY_SIGNATURE, MAX_BYTES, SALE_AUTHORIZATION, SALE_EVENT,
    TRANSFER_EVENT, _VIEWS, _authorization_id, _decode_view, _receipt_log,
    _rpc_quantity, _safe_approved_signatures, _sale_digest)

PROFILE = "STREAM_MUSEUM_RETAINED_TOKEN_MINT_EVIDENCE_V1"
REGISTERED_EVENT = keccak256(b"TokenCollectionRegistered(uint16,uint256,uint256,uint256)")
ENTROPY_REGISTERED_EVENT = keccak256(b"EntropyRegistered(uint256,uint256,bytes32)")
MAX_RECEIPT_BYTES = 2 * 1024 * 1024
MAX_CALLDATA_BYTES = 65536
MAX_TOKEN_DATA_BYTES = 16384
PREFIX = "mint/originals/"
AUTHORIZATION_FIELDS = ("collectionId", "phaseId", "payer", "recipient", "artist",
    "profileId", "expectedPrimaryPolicyHash", "tokenDataHash", "mintCommitment",
    "mintPolicyHash", "price", "nonce", "deadline", "signerEpoch")
CLAIMS = {"containingFixtureReplayPerformed": False, "sourcePublisherAuthenticated": False,
    "signaturesReverified": False, "receiptInclusionProven": False, "consensusProof": False,
    "sourceBlockCoordinatorRuntimeChecked": False, "sourceBlockSaleRuntimeChecked": False,
    "completeEntropyHistory": False, "sourceBlockEntropyStatusCaptured": False,
    "entropySeedCaptured": False, "entropyFinalized": False, "packetItem4Complete": False,
    "fullAcquisitionPacketConformance": False, "fullObjectDossierConformance": False,
    "actualChainAcceptance": False, "legalTitleProven": False, "networkFetch": False}
QUALIFICATION = ("Pure extraction from a separately verified retained local-token fixture. "
    "Original paid calldata, deployment product rows, receipt events and source-block Core views "
    "are joined without repeating signature or chain verification. Development entropy remains "
    "development entropy. Registration proves no source-block entropy status, seed, request, "
    "finalization, randomness quality, institutional acceptance or full packet conformance.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1",
    "status": "prospective_unregistered_extraction_profile",
    "input": "already_verified_retained_actual_local_token_fixture",
    "bounds": {"originalBytes": str(MAX_BYTES), "receiptBytes": str(MAX_RECEIPT_BYTES),
        "receiptLogs": str(MAX_LOGS_PER_RECEIPT), "calldataBytes": str(MAX_CALLDATA_BYTES),
        "tokenDataBytes": str(MAX_TOKEN_DATA_BYTES)},
    "eventOrder": ["TokenCollectionRegistered", "EntropyRegistered", "Transfer", "NativeSaleSettled"],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json_wire(value):
    if type(value) is int:
        return str(value)
    if type(value) is bytes:
        return "0x" + value.hex()
    if type(value) in (tuple, list):
        return [_json_wire(v) for v in value]
    return value


def _file(path, raw):
    return {"path": path, "bytes": str(len(raw)), "sha256": "0x" + hashlib.sha256(raw).hexdigest(),
            "keccak256": keccak256(raw)}


def _logs(receipt):
    logs = receipt.get("logs")
    require(type(logs) is list and 0 < len(logs) <= MAX_LOGS_PER_RECEIPT,
            "mint receipt log count bound")
    require(len(dumps(receipt)) <= MAX_RECEIPT_BYTES, "mint receipt byte bound")
    previous, normalized = None, []
    for row in logs:
        require(_receipt_log(row, receipt), "mint receipt log coordinates/removed differs")
        index = _rpc_quantity(row.get("logIndex"), "log index")
        require(previous is None or index == previous + 1,
                "mint receipt log order/gap/duplicate differs")
        previous = index
        require(any(hex_bytes(row.get("address"), 20)), "mint log emitter is zero")
        topics = row.get("topics")
        require(type(topics) is list and len(topics) <= 4, "mint log topics bound")
        for topic in topics:
            hex_bytes(topic, 32)
        require(len(hex_bytes(row.get("data"))) <= MAX_RECEIPT_BYTES, "mint log data bound")
        normalized.append({key: row[key] for key in LOG_FIELDS})
    return normalized


def _event(logs, address, topic, count, label):
    rows = [row for row in logs if row["address"] == address and row["topics"]
            and row["topics"][0] == topic]
    require(len(rows) == 1 and len(rows[0]["topics"]) == count,
            "mint exact " + label + " event count/topics differs")
    return rows[0]


def extract(reference, originals):
    """Return deterministic retained files/report; caller must verify fixture first.

    ``reference`` is the exact object_dossier_native reference. ``originals``
    contains the original unpacked token_fixture files, never caller summaries.
    Source authentication and replay remain the containing assembler's duty.
    """
    try:
        return _extract(reference, originals)
    except (KeyError, TypeError, IndexError, OverflowError) as exc:
        raise MuseumError("malformed retained token mint input") from exc


def _extract(reference, originals):
    validate_reference(reference)
    require(type(originals) is dict and all(type(k) is str and type(v) is bytes
            for k, v in originals.items()) and len(originals) <= 8192
            and sum(map(len, originals.values())) <= MAX_BYTES, "mint original input bound/type")
    state, anchor = reference["sourceState"], reference["sourceAnchor"]
    source = loads(originals["anchor.json"], maximum=524288, canonical=True)
    require(all(source[k] == state[k] for k in ("chainId", "core", "blockHash", "blockNumber"))
            and all(source[k] == anchor[k] for k in
                    ("timestamp", "stateRoot", "environment", "deploymentEvidenceHash"))
            and source["codePins"] == anchor["runtimePins"], "mint original source/reference differs")
    require(state["chainId"] == "31337" and anchor["environment"] == "local_evm_fixture",
            "mint extractor requires the retained local-token profile")
    raw = originals["deployment-evidence.json"]
    require(keccak256(raw) == anchor["deploymentEvidenceHash"], "mint original deployment commitment differs")
    evidence = loads(raw, maximum=MAX_BYTES, canonical=True)
    native_raw = originals["native-inputs.json"]
    native = loads(native_raw, maximum=MAX_BYTES, canonical=True)
    require(evidence["kind"] == "local_evm_fixture"
            and evidence["nativeInputManifestSha256"] == hashlib.sha256(native_raw).hexdigest()
            and evidence["nativeComposition"] == native["tokenComposition"],
            "mint original native manifest/composition differs")
    products = {}
    for name in ("StreamCore", "StreamEntropyCoordinator", "StreamFixedPriceSaleAdapter"):
        row, product = evidence["artifacts"][name], native["products"][name]
        require(type(row) is dict and type(product) is dict
                and all(k in product for k in ("source", "artifact", "sha256", "origin"))
                and {k: row.get(k) for k in product} == product,
                "mint original product provenance differs: " + name)
        require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32)),
                "mint original product address/runtime differs")
        products[name] = row
    core = state["core"]
    coordinator, sale = (products[name]["address"] for name in
                         ("StreamEntropyCoordinator", "StreamFixedPriceSaleAdapter"))
    require(products["StreamCore"]["address"] == core
            and products["StreamCore"]["runtimeHash"] == anchor["coreRuntimeHash"],
            "mint original Core product/reference differs")
    source_pins = {row["address"]: row["runtimeHash"] for row in anchor["runtimePins"]}
    require(all(row["address"] not in source_pins or source_pins[row["address"]] == row["runtimeHash"]
                for row in products.values()), "mint original/source shared runtime pin differs")
    mint = evidence["tokenMint"]
    require(all(mint[k] == state[k] for k in ("tokenId", "collectionId", "collectionSerial"))
            and mint["tokenLifecycle"] == "2" and mint["coordinatorAtMint"] == coordinator,
            "mint original identity/coordinator differs")
    require(mint["operationRootUsed"] is True and mint["authorizationUsed"] is True
            and mint["developmentEntropyOnly"] is True and mint["owner"] == mint["buyer"],
            "mint retained authorization/original owner qualification differs")
    token, collection, serial = (uint(state[k]) for k in ("tokenId", "collectionId", "collectionSerial"))
    transaction, receipt, tx_hash = mint["transaction"], mint["receipt"], mint["transactionHash"]
    require(any(hex_bytes(tx_hash, 32)) and transaction["hash"] == receipt["transactionHash"] == tx_hash
            and receipt["status"] == "0x1" and transaction["to"] == receipt["to"] == sale
            and transaction["from"] == receipt["from"] == mint["buyer"]
            and all(transaction[k] == receipt[k] for k in ("blockHash", "blockNumber", "transactionIndex")),
            "mint transaction/receipt identity differs")
    require(any(hex_bytes(receipt["blockHash"], 32)), "mint receipt block hash is zero")
    block = _rpc_quantity(receipt["blockNumber"], "block number")
    position = _rpc_quantity(receipt["transactionIndex"], "transaction index")
    require(block <= uint(state["blockNumber"])
            and (block != uint(state["blockNumber"]) or receipt["blockHash"] == state["blockHash"]),
            "mint receipt/source block differs")
    input_bytes = hex_bytes(transaction["input"])
    require(len(input_bytes) <= MAX_CALLDATA_BYTES
            and input_bytes[:4] == hex_bytes(calldata(BUY_SIGNATURE)[:10], 4),
            "mint paid calldata selector/bound differs")
    authorization, token_data, platform_signature, artist_signature = decode(
        (SALE_AUTHORIZATION, "bytes", "bytes", "bytes"), input_bytes[4:], maximum=MAX_CALLDATA_BYTES)
    require(len(token_data) <= MAX_TOKEN_DATA_BYTES and mint["tokenData"] == "0x" + token_data.hex()
            and mint["tokenDataBytes"] == str(len(token_data)) and mint["tokenDataHash"] == keccak256(token_data)
            and mint["tokenDataSha256"] == hashlib.sha256(token_data).hexdigest(), "mint token data differs")
    require(authorization[0] == collection and authorization[1] != ZERO
            and authorization[2] == authorization[3] == mint["buyer"]
            and any(hex_bytes(mint["buyer"], 20)) and authorization[4] == mint["artist"]
            and authorization[5] == mint["profileId"] and authorization[6] != ZERO
            and authorization[7] == keccak256(token_data) and authorization[8] != ZERO
            and authorization[9] != ZERO and authorization[10] == uint(mint["price"])
            and authorization[10] == _rpc_quantity(transaction["value"], "transaction value")
            and authorization[10] > 0 and authorization[11] != ZERO
            and authorization[12] > 0 and authorization[13] > 0
            and platform_signature == _safe_approved_signatures(evidence, mint["platform"])
            and artist_signature == _safe_approved_signatures(evidence, mint["artist"]),
            "mint paid authorization/calldata differs")
    digest, authorization_id = _sale_digest(sale, authorization), _authorization_id(sale, authorization[4], authorization[11])
    require(digest == mint["saleAuthorizationDigest"] and authorization_id == mint["authorizationId"],
            "mint paid authorization digest/id differs")
    logs = _logs(receipt)
    events = {"registered": _event(logs, core, REGISTERED_EVENT, 3, "Core registration"),
        "entropyRegistered": _event(logs, coordinator, ENTROPY_REGISTERED_EVENT, 3, "entropy registration"),
        "transfer": _event(logs, core, TRANSFER_EVENT, 4, "Core mint Transfer"),
        "sale": _event(logs, sale, SALE_EVENT, 4, "NativeSaleSettled")}
    registered, entropy, transfer, settled = (events[k] for k in events)
    word = lambda value: "0x" + value.to_bytes(32, "big").hex()
    require(registered["topics"][1:] == [word(token), word(collection)]
            and decode(("uint16", "uint256"), hex_bytes(registered["data"])) == (1, serial),
            "mint Core registration identity/schema differs")
    require(entropy["topics"][1:] == [word(collection), word(token)]
            and decode(("bytes32",), hex_bytes(entropy["data"])) == (authorization[8],),
            "mint entropy registration identity/commitment differs")
    recipient_topic = "0x" + (bytes(12) + hex_bytes(authorization[3], 20)).hex()
    require(transfer["topics"] == [TRANSFER_EVENT, ZERO, recipient_topic, word(token)]
            and transfer["data"] == "0x", "mint Core Transfer differs")
    require(any(hex_bytes(mint["operationRoot"], 32))
            and settled["topics"][1:] == [authorization_id, mint["operationRoot"], word(token)]
            and decode(("bytes32", "bytes32", "address", "uint256"), hex_bytes(settled["data"]))
                == (digest, mint["profileId"], mint["wallet"], authorization[10]), "mint sale settlement differs")
    indices = [_rpc_quantity(row["logIndex"], "selected log index") for row in events.values()]
    require(indices == sorted(set(indices)), "mint native event sequence differs")
    views = evidence["tokenSourceBlockViews"]
    require(type(views) is dict and set(views) == set(_VIEWS), "mint Core six-view set differs")
    decoded = {name: _decode_view(views[name], name, token, core, state["blockHash"]) for name in _VIEWS}
    facts = reference["coreFacts"]
    require(decoded["tokenCollectionIdentity"] == (True, collection, serial, facts["burned"])
            and decoded["tokenLifecycle"] == (uint(facts["lifecycle"]),)
            and decoded["ownerOf"] == (facts["owner"],)
            and decoded["coordinatorAtMint"] == (coordinator,) and decoded["tokenData"] == (token_data,),
            "mint source-block Core/reference/calldata differs")
    files = {PREFIX + "profile.json": PROFILE_BYTES, PREFIX + "transaction.json": dumps(transaction),
        PREFIX + "receipt.json": dumps(receipt), PREFIX + "logs.json": dumps(logs),
        PREFIX + "calldata.bin": input_bytes, PREFIX + "token-data.bin": token_data,
        PREFIX + "platform-signature.bin": platform_signature, PREFIX + "artist-signature.bin": artist_signature,
        PREFIX + "source-block-views.json": dumps(views), PREFIX + "deployment-products.json": dumps(products)}
    for name, row in events.items():
        files[PREFIX + "logs/" + name + ".json"] = dumps(row)
    identity = {k: state[k] for k in ("tokenId", "collectionId", "collectionSerial")}
    identity.update(lifecycle="2", burned=False, coordinatorAtMint=coordinator)
    coordinates = {"hash": tx_hash, "blockHash": receipt["blockHash"],
                   "blockNumber": str(block), "transactionIndex": str(position)}
    report = {"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceState": state,
        "sourceAnchorHash": keccak256(dumps(anchor)),
        "originals": {name: {"originalName": name, **{k: v for k, v in _file(name, originals[name]).items()
                         if k != "path"}} for name in
                      ("anchor.json", "deployment-evidence.json", "native-inputs.json")},
        "retainedInputLocation": "originalName identifies an unpacked containing token fixture input, not an extracted output path",
        "mint": {"identity": identity, "identityObservation": "original_mint_transaction",
            "mintCommitment": authorization[8],
            "initialRecipient": authorization[3], "tokenData": _file(PREFIX + "token-data.bin", token_data),
            "paidAuthorization": {**dict(zip(AUTHORIZATION_FIELDS, _json_wire(authorization))),
                "digest": digest, "authorizationId": authorization_id, "operationRoot": mint["operationRoot"],
                "wallet": mint["wallet"], "platform": mint["platform"],
                "platformSignaturePath": PREFIX + "platform-signature.bin",
                "artistSignaturePath": PREFIX + "artist-signature.bin"},
            "transaction": coordinates | {"path": PREFIX + "transaction.json", "calldataPath": PREFIX + "calldata.bin"},
            "receipt": coordinates | {"path": PREFIX + "receipt.json", "allLogsPath": PREFIX + "logs.json"},
            "logs": events, "originalDeploymentProductsPath": PREFIX + "deployment-products.json",
            "developmentEntropyOnly": True},
        "sourceBlockViews": {"path": PREFIX + "source-block-views.json", "observation": "source_block",
                             "coreFacts": facts,
                             "decoded": {k: _json_wire(v) for k, v in decoded.items()}},
        "fieldGaps": {"entropyStatus": "requires_same_block_original_coordinator_read",
            "seed": "not_in_mint_receipt", "provider": "not_in_registration_event",
            "providerEpoch": "not_in_registration_event", "requestKey": "not_in_registration_event",
            "requestAttempt": "not_in_registration_event",
            "requestedFinalizedEvents": "requires_complete_original_coordinator_history",
            "coordinatorSourceBlockRuntime": "original_deployment_pin_only",
            "saleSourceBlockRuntime": "original_deployment_pin_only"},
        "claims": CLAIMS.copy(), "qualification": QUALIFICATION,
        "fileInventory": [_file(path, data) for path, data in sorted(files.items())]}
    return files, report
