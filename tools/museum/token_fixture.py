"""Retain and replay one bounded actual local token dossier capture offline.

The retained RPC material is consistency evidence from a pinned local chain,
not a consensus proof.  The authority exercise remains the explicitly
synthetic snapshot selected by the source capture, and the resulting scoped
dossier does not claim full ``OBJECT_DOSSIER_V1`` conformance.
"""
import base64
import binascii
import gzip
import hashlib
import io
from pathlib import Path
import tempfile
import re

from .bagit import write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .citations import canonical_citation
from .current_media_inputs import image_bytes, media_description
from .dossier import _assemble as build_scoped_dossier
from .dossier import verify_dossier, verify_ocfl
from .independent_wire import ZERO, require
from .ocfl import build_version
from .package import write_package
from .semantic_export import MANIFEST_PATH, build_export, verify_export
from .token_media_inputs import token_scope
from .typed_authority_fixture import (OPTIONAL, REQUIRED as BASE_REQUIRED,
    rebuild as rebuild_authority)

TOOL_SNAPSHOT_FILES = tuple("dossier-bag/data/tool/" + name for name in
    ("dossier.py.txt", "dossier_media.py.txt", "dossier_bagit.py.txt", "source-index.json"))
REQUIRED = (*BASE_REQUIRED, "token-result.json", "test-image.png", *TOOL_SNAPSHOT_FILES)
MAX_BYTES = 64 * 1024 * 1024
EXPANDED_MAX = MAX_BYTES * 2 + 1048576
BAGGING_DATE = "2026-09-16"
OCFL_CREATED = "2026-09-16T00:00:00Z"
OCFL_MESSAGE = "New actual token and fresh token-subject media capture"
MODE = "retained_actual_local_token_semantic_dossier_capture"
RESULT_MODE = "actual_joined_token_scoped_dossier_capture"

SALE_EVENT = keccak256(b"NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)")
TRANSFER_EVENT = keccak256(b"Transfer(address,address,uint256)")
BUY_SIGNATURE = ("buy((uint256,bytes32,address,address,address,bytes32,bytes32,bytes32,bytes32,"
    "bytes32,uint256,bytes32,uint64,uint64),bytes,bytes,bytes)")
SALE_AUTHORIZATION = ("uint256", "bytes32", "address", "address", "address", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "bytes32", "uint64", "uint64")
SALE_AUTHORIZATION_TYPEHASH = keccak256(
    b"SaleAuthorization(uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 expectedPrimaryPolicyHash,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch)")
DOMAIN_TYPEHASH = keccak256(b"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
NONCE_DOMAIN = keccak256(b"6529STREAM_NATIVE_SALE_NONCE_V1")
NAME_HASH = keccak256(b"6529StreamFixedPriceSale")
VERSION_HASH = keccak256(b"2")

_VIEWS = {
    "ownerOf": ("ownerOf(uint256)", ("address",)),
    "tokenCollectionIdentity": ("tokenCollectionIdentity(uint256)",
        ("bool", "uint256", "uint256", "bool")),
    "tokenLifecycle": ("tokenLifecycle(uint256)", ("uint8",)),
    "tokenData": ("tokenData(uint256)", ("bytes",)),
    "coordinatorAtMint": ("coordinatorAtMint(uint256)", ("address",)),
    "tokenURI": ("tokenURI(uint256)", ("string",)),
}


def _result(files):
    value = loads(files["token-result.json"], maximum=65536, canonical=True)
    require(set(value) == {"mode", "nativeInputManifestSha256", "subjectId", "tokenId",
        "exportManifestHash", "bagManifestHash", "ocflInventoryHash", "qualification"}
        and value["mode"] == RESULT_MODE and isinstance(value["qualification"], str)
        and value["qualification"],
        "retained token result shape differs")
    uint(value["tokenId"])
    require(uint(value["tokenId"]) > 0, "retained token result token must be nonzero")
    for name in ("exportManifestHash", "bagManifestHash", "ocflInventoryHash"):
        hex_bytes(value[name], 32)
    require(isinstance(value["nativeInputManifestSha256"], str)
        and re.fullmatch(r"[0-9a-f]{64}", value["nativeInputManifestSha256"]) is not None,
        "retained token native manifest SHA-256 differs")
    return value


def _source_scope(files, result):
    anchor = loads(files["anchor.json"], maximum=524288, canonical=True)
    require(anchor.get("environment") == "local_evm_fixture"
        and anchor.get("chainId") == "31337", "retained token requires actual local capture scope")
    scope = token_scope(anchor["chainId"], anchor["core"], "1", result["tokenId"])
    require(result["subjectId"] == scope.subject_id, "retained token result subject differs")
    capture = loads(files["source-capture.json"], maximum=MAX_BYTES, canonical=True)
    records = capture.get("records")
    expected_subject = _wire_subject(scope)
    require(isinstance(records, list) and records
        and all(row.get("subject") == expected_subject for row in records),
        "retained source records do not share the exact token subject")
    lanes = capture.get("lanes")
    require(isinstance(lanes, list) and len(lanes) == 1
        and lanes[0].get("scopeKey") == "1" and uint(lanes[0].get("count", "0")) == len(records),
        "retained token requires one exact nonempty source lane")
    require(anchor.get("lanes") == [{"scopeKey": lanes[0]["scopeKey"],
        "recordType": lanes[0]["recordType"]}], "retained token anchor lane differs")
    return anchor, scope, capture


def _wire_subject(scope):
    """Return the canonical JSON form of the independently derived wire tuple."""
    return [str(scope.wire_subject[0]), str(scope.wire_subject[1]),
        str(scope.wire_subject[2]), scope.wire_subject[3]]


def _decode_view(row, name, token_id, core, block_hash):
    require(isinstance(row, dict) and set(row) == {"to", "data", "result", "blockHash"},
        "retained token source view shape differs: " + name)
    signature, outputs = _VIEWS[name]
    expected_data = calldata(signature, ("uint256",), (token_id,))
    require(row["to"] == core and row["blockHash"] == block_hash
        and row["data"] == expected_data, "retained token source view query differs: " + name)
    return decode(outputs, hex_bytes(row["result"]), maximum=1048576)


def _token_metadata(uri, token_id, png):
    prefix = "data:application/json;base64,"
    require(isinstance(uri, str) and uri.startswith(prefix) and len(uri) <= 1048576,
        "retained token metadata must be bounded native JSON")
    try:
        raw = base64.b64decode(uri[len(prefix):], validate=True)
    except (binascii.Error, ValueError) as exc:
        raise MuseumError("retained token metadata base64 differs") from exc
    metadata = loads(raw, maximum=524288)
    require(metadata.get("image") == media_description(png)["uri"]
        and metadata.get("token_id") == token_id and metadata.get("collection_id") == 1
        and metadata.get("collection_serial") == 1,
        "retained token metadata identity/media differs")
    try:
        token_data = base64.b64decode(metadata.get("token_data_base64", ""), validate=True)
    except (binascii.Error, TypeError, ValueError) as exc:
        raise MuseumError("retained token metadata data encoding differs") from exc
    require(token_data == png, "retained token metadata data bytes differ")
    return raw


def _sale_digest(sale_address, authorization):
    domain = keccak256(encode(("bytes32", "bytes32", "bytes32", "uint256", "address"),
        (DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, 31337, sale_address)))
    struct_hash = keccak256(encode(("bytes32", SALE_AUTHORIZATION),
        (SALE_AUTHORIZATION_TYPEHASH, authorization)))
    return keccak256(b"\x19\x01" + hex_bytes(domain, 32) + hex_bytes(struct_hash, 32))


def _authorization_id(sale_address, artist, nonce):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32"),
        (NONCE_DOMAIN, 31337, sale_address, artist, nonce)))


def _safe_approved_signatures(evidence, safe):
    accounts = evidence.get("safeAccounts")
    owners = accounts.get(safe) if isinstance(accounts, dict) else None
    require(isinstance(owners, list) and len(owners) >= 2 and len(set(owners)) == len(owners),
        "retained sale Safe owner set differs")
    result = b""
    for owner in sorted(owners):
        result += bytes(12) + hex_bytes(owner, 20) + bytes(32) + b"\x01"
    return result


def _receipt_log(log, receipt):
    return (isinstance(log, dict) and log.get("transactionHash") == receipt["transactionHash"]
        and log.get("transactionIndex") == receipt["transactionIndex"]
        and log.get("blockHash") == receipt["blockHash"]
        and log.get("blockNumber") == receipt["blockNumber"] and log.get("removed") is False)


def _rpc_quantity(value, label):
    require(isinstance(value, str) and re.fullmatch(r"0x(?:0|[1-9a-f][0-9a-f]*)", value) is not None,
        "retained paid mint " + label + " differs")
    return int(value, 16)


def _mint_evidence(files, result, anchor, png):
    evidence = loads(files["deployment-evidence.json"], maximum=MAX_BYTES, canonical=True)
    native = loads(files["native-inputs.json"], maximum=MAX_BYTES, canonical=True)
    require(evidence.get("kind") == "local_evm_fixture"
        and evidence.get("nativeInputManifestSha256") == result["nativeInputManifestSha256"]
        and hashlib.sha256(files["native-inputs.json"]).hexdigest()
            == result["nativeInputManifestSha256"]
        and evidence.get("nativeComposition") == native.get("tokenComposition"),
        "retained token deployment/native manifest evidence differs")
    require(evidence.get("media") == media_description(png),
        "retained token media description differs from original PNG")
    mint = evidence.get("tokenMint")
    require(isinstance(mint, dict) and mint.get("tokenId") == result["tokenId"]
        and mint.get("collectionId") == "1" and mint.get("collectionSerial") == "1"
        and mint.get("tokenLifecycle") == "2", "retained token mint identity differs")
    require(mint.get("tokenData") == "0x" + png.hex()
        and mint.get("tokenDataBytes") == str(len(png))
        and mint.get("tokenDataHash") == keccak256(png)
        and mint.get("tokenDataSha256") == hashlib.sha256(png).hexdigest(),
        "retained token mint bytes differ from original PNG")
    require(mint.get("owner") == mint.get("buyer") and mint.get("operationRootUsed") is True
        and mint.get("authorizationUsed") is True and mint.get("developmentEntropyOnly") is True,
        "retained token mint authorization/readback differs")
    transaction, receipt = mint.get("transaction"), mint.get("receipt")
    tx_hash = mint.get("transactionHash")
    value = transaction.get("value") if isinstance(transaction, dict) else None
    amount = _rpc_quantity(value, "transaction value")
    artifacts = evidence.get("artifacts")
    sale_row = artifacts.get("StreamFixedPriceSaleAdapter") if isinstance(artifacts, dict) else None
    sale = sale_row.get("address") if isinstance(sale_row, dict) else None
    products = native.get("products")
    sale_product = products.get("StreamFixedPriceSaleAdapter") if isinstance(products, dict) else None
    require(isinstance(sale_row, dict) and isinstance(sale_product, dict)
        and {name: sale_row.get(name) for name in sale_product} == sale_product
        and all(name in sale_product for name in ("source", "artifact", "sha256", "origin"))
        and any(hex_bytes(sale, 20)), "retained sale artifact provenance/address differs")
    hex_bytes(tx_hash, 32)
    require(isinstance(transaction, dict) and isinstance(receipt, dict)
        and transaction.get("hash") == tx_hash and receipt.get("transactionHash") == tx_hash
        and receipt.get("status") == "0x1" and transaction.get("from") == mint["buyer"]
        and receipt.get("from") == mint["buyer"] and transaction.get("to") == sale
        and receipt.get("to") == sale
        and all(transaction.get(field) == receipt.get(field)
            for field in ("blockHash", "blockNumber", "transactionIndex"))
        and amount == uint(mint["price"]) and amount > 0,
        "retained paid mint transaction/receipt differs")
    hex_bytes(receipt.get("blockHash"), 32)
    mint_block = _rpc_quantity(receipt.get("blockNumber"), "block number")
    _rpc_quantity(receipt.get("transactionIndex"), "transaction index")
    require(mint_block <= uint(anchor["blockNumber"]),
        "retained paid mint occurs after source snapshot")

    raw_input = hex_bytes(transaction.get("input"))
    selector = hex_bytes(calldata(BUY_SIGNATURE)[:10], 4)
    require(raw_input[:4] == selector, "retained paid mint calldata selector differs")
    authorization, token_data, platform_signature, artist_signature = decode(
        (SALE_AUTHORIZATION, "bytes", "bytes", "bytes"), raw_input[4:], maximum=8192)
    require(authorization[0] == 1 and authorization[1] != ZERO
        and authorization[2] == authorization[3] == mint["buyer"]
        and authorization[4] == mint["artist"] and authorization[5] == mint["profileId"]
        and authorization[6] != ZERO and authorization[7] == keccak256(png)
        and authorization[8] == schema_id("local token media capture actual mint")
        and authorization[9] != ZERO and authorization[10] == uint(mint["price"])
        and authorization[11] == schema_id("local token media capture sale")
        and authorization[12] > 0 and authorization[13] > 0 and token_data == png
        and platform_signature == _safe_approved_signatures(evidence, mint["platform"])
        and artist_signature == _safe_approved_signatures(evidence, mint["artist"]),
        "retained paid mint calldata values differ")
    digest = _sale_digest(sale, authorization)
    authorization_id = _authorization_id(sale, authorization[4], authorization[11])
    require(digest == mint["saleAuthorizationDigest"]
        and authorization_id == mint["authorizationId"],
        "retained sale authorization digest/id differs")

    logs = receipt.get("logs")
    require(isinstance(logs, list), "retained paid mint receipt logs missing")
    sales = [log for log in logs if log.get("address") == sale
        and log.get("topics", [None])[0] == SALE_EVENT]
    require(len(sales) == 1 and _receipt_log(sales[0], receipt)
        and len(sales[0]["topics"]) == 4, "retained NativeSaleSettled event differs")
    sale_event = sales[0]
    event_digest, profile, wallet, amount = decode(
        ("bytes32", "bytes32", "address", "uint256"), hex_bytes(sale_event["data"]))
    require(sale_event["topics"][1] == authorization_id
        and sale_event["topics"][2] == mint["operationRoot"]
        and int(sale_event["topics"][3], 16) == uint(result["tokenId"])
        and event_digest == digest and profile == mint["profileId"]
        and wallet == mint["wallet"] and amount == uint(mint["price"]),
        "retained NativeSaleSettled values differ")
    transfers = [log for log in logs if log.get("address") == anchor["core"]
        and log.get("topics", [None])[0] == TRANSFER_EVENT]
    recipient_topic = "0x" + (bytes(12) + hex_bytes(mint["buyer"], 20)).hex()
    token_topic = "0x" + uint(result["tokenId"]).to_bytes(32, "big").hex()
    require(len(transfers) == 1 and _receipt_log(transfers[0], receipt)
        and transfers[0].get("topics") == [TRANSFER_EVENT, ZERO, recipient_topic, token_topic]
        and transfers[0].get("data") == "0x", "retained Core mint Transfer differs")

    views = evidence.get("tokenSourceBlockViews")
    require(isinstance(views, dict) and set(views) == set(_VIEWS),
        "retained token source-block view set differs")
    token_id = uint(result["tokenId"])
    decoded = {name: _decode_view(views[name], name, token_id, anchor["core"], anchor["blockHash"])
        for name in _VIEWS}
    require(decoded["ownerOf"] == (mint["owner"],)
        and decoded["tokenCollectionIdentity"] == (True, 1, 1, False)
        and decoded["tokenLifecycle"] == (2,)
        and decoded["tokenData"] == (png,)
        and decoded["coordinatorAtMint"] == (mint["coordinatorAtMint"],),
        "retained token source-block Core views differ from mint evidence")
    metadata = _token_metadata(decoded["tokenURI"][0], token_id, png)
    return evidence, mint, keccak256(metadata)


def _export_scope(export, scope):
    manifest = loads(dict(export.files)[MANIFEST_PATH], maximum=8192, canonical=True)
    source = manifest["sourceState"]
    heads = source.get("recordHeads")
    citation = None if not isinstance(heads, list) or len(heads) != 1 else canonical_citation(
        scope.chain_id, scope.core, scope.token_id,
        {"kind": "chain", "hash": heads[0]["recordChainHash"]})
    require(source["chainId"] == scope.chain_id and source["core"] == scope.core
        and source["collectionId"] == scope.collection_id and source["tokenId"] == scope.token_id
        and source["anchorSubject"] == scope.anchor_subject
        and source["canonicalCitation"] == citation
        and all(row["subjectId"] == scope.subject_id for row in heads),
        "rebuilt export does not retain the exact token scope")
    return source


def rebuild(files):
    """Replay retained authority, V3 export, dossier and OCFL from original inputs."""
    files = dict(files)
    require(set(REQUIRED) <= set(files) <= set(REQUIRED + OPTIONAL),
        "retained token fixture exact input set")
    require(all(name in files for name in OPTIONAL) or all(name not in files for name in OPTIONAL),
        "retained token publisher retention pair")
    result = _result(files)
    anchor, scope, _ = _source_scope(files, result)
    png = files["test-image.png"]
    require(type(png) is bytes and png == image_bytes(),
        "retained token original test image differs")
    _, mint, metadata_hash = _mint_evidence(files, result, anchor, png)
    authority = rebuild_authority(files)
    with tempfile.TemporaryDirectory(prefix="stream-token-fixture-") as temporary:
        root = Path(temporary)
        authority_dir = root / "authority"; write_package(authority, authority_dir)
        export = build_export(authority_dir, authority.manifest_hash, disclosure="public")
        require(export.manifest_hash == result["exportManifestHash"],
            "retained token export pin differs")
        _export_scope(export, scope)
        export_dir = root / "export"; write_package(export, export_dir)
        verify_export(export_dir, export.manifest_hash)
        name = hashlib.sha256(png).hexdigest() + ".bin"
        tool_snapshot = {path[len("dossier-bag/data/"):]: files[path]
            for path in TOOL_SNAPSHOT_FILES}
        bag = build_scoped_dossier(export, {name: png}, bagging_date=BAGGING_DATE,
            tool_snapshot=tool_snapshot)
        require(bag.manifest_hash == result["bagManifestHash"],
            "retained token dossier pin differs")
        bag_dir = root / "bag"; write_tree(bag.files, bag_dir)
        verify_dossier(bag_dir, bag.manifest_hash)
        ocfl = build_version(bag, created=OCFL_CREATED, message=OCFL_MESSAGE)
        require(ocfl.inventory_hash == result["ocflInventoryHash"],
            "retained token OCFL pin differs")
        ocfl_dir = root / "ocfl"; write_tree(ocfl.files, ocfl_dir)
        verify_ocfl(ocfl_dir, ocfl.inventory_hash)
    authority_result = loads(files["authority-result.json"], maximum=65536, canonical=True)
    require(authority_result.get("snapshotMode") == "synthetic_fixture"
        and authority_result.get("authorityPublisherAuthenticated") is False
        and authority_result.get("selfReviewOnly") is True,
        "retained token authority qualification differs")
    report = {"mode": "offline_actual_local_token_dossier_replay",
        "subjectId": scope.subject_id, "tokenId": scope.token_id,
        "exportManifestHash": export.manifest_hash, "bagManifestHash": bag.manifest_hash,
        "ocflInventoryHash": ocfl.inventory_hash,
        "mediaSha256": hashlib.sha256(png).hexdigest(), "tokenMetadataHash": metadata_hash,
        "mintTransactionHash": mint["transactionHash"], "trustedRpcReplay": True,
        "consensusProof": False,
        "syntheticAuthoritySnapshot": True,
        "authorityPublisherAuthenticated": False, "qualifiedHumanReview": False,
        "fullObjectDossierConformance": False, "networkFetch": False}
    return export, bag, ocfl, report


def retain(capture, destination):
    """Retain exact original capture inputs behind one external canonical pin."""
    capture, destination = Path(capture).resolve(), Path(destination).resolve()
    files, total = {}, 0
    for name in REQUIRED + OPTIONAL:
        path = capture / name
        if name in OPTIONAL and not path.exists():
            continue
        size = path.stat().st_size; total += size
        require(size <= MAX_BYTES and total <= MAX_BYTES, "token retained input bound")
        files[name] = path.read_bytes()
        require(len(files[name]) == size, "token retained input changed while reading")
    export, bag, ocfl, report = rebuild(files)
    expanded = dumps({"files": {name: raw.hex() for name, raw in sorted(files.items())}})
    packed = gzip.compress(expanded, compresslevel=9, mtime=0)
    authority_result = loads(files["authority-result.json"], maximum=65536, canonical=True)
    manifest = dumps({"version": "1", "mode": MODE,
        "archiveSha256": hashlib.sha256(packed).hexdigest(), "expandedBytes": str(len(expanded)),
        "subjectId": report["subjectId"], "tokenId": report["tokenId"],
        "exportManifestHash": export.manifest_hash, "bagManifestHash": bag.manifest_hash,
        "ocflInventoryHash": ocfl.inventory_hash, "snapshotMode": authority_result["snapshotMode"],
        "classification": ("Actual local paid mint, exact token-subject Safe records and source-block "
            "Core views on pinned native products; externally pinned trusted-RPC replay, not consensus proof."),
        "authorityPublisherAuthenticated": False, "qualifiedHumanReview": False,
        "fullObjectDossierConformance": False, "networkFetch": False,
        "files": [{"path": name, "byteLength": str(len(raw)), "keccak256": keccak256(raw)}
            for name, raw in sorted(files.items())]})
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "inputs.json.gz").write_bytes(packed)
    (destination / "manifest.json").write_bytes(manifest)
    return keccak256(manifest)


def read(directory, manifest_hash):
    """Authenticate and expand a retained token fixture without replaying it."""
    directory = Path(directory)
    manifest_path, archive_path = directory / "manifest.json", directory / "inputs.json.gz"
    require(manifest_path.stat().st_size <= 65536 and archive_path.stat().st_size <= MAX_BYTES,
        "token fixture bound")
    raw = manifest_path.read_bytes()
    require(keccak256(raw) == manifest_hash, "token fixture external pin differs")
    manifest = loads(raw, maximum=65536, canonical=True)
    require(manifest.get("mode") == MODE, "retained token fixture mode differs")
    packed = archive_path.read_bytes()
    require(hashlib.sha256(packed).hexdigest() == manifest["archiveSha256"],
        "token fixture packed pin differs")
    with gzip.GzipFile(fileobj=io.BytesIO(packed)) as stream:
        expanded = stream.read(EXPANDED_MAX + 1)
    require(len(expanded) == int(manifest["expandedBytes"]) and len(expanded) <= EXPANDED_MAX,
        "token fixture expanded bound")
    encoded = loads(expanded, maximum=EXPANDED_MAX, canonical=True)["files"]
    require(set(REQUIRED) <= set(encoded) <= set(REQUIRED + OPTIONAL),
        "token fixture exact file set")
    require(all(name in encoded for name in OPTIONAL) or all(name not in encoded for name in OPTIONAL),
        "token fixture publisher retention pair")
    files = {name: bytes.fromhex(value) for name, value in encoded.items()}
    require(sum(map(len, files.values())) <= MAX_BYTES, "token fixture decoded bound")
    require(manifest["files"] == [{"path": name, "byteLength": str(len(content)),
        "keccak256": keccak256(content)} for name, content in sorted(files.items())],
        "token fixture original input commitments differ")
    return files, manifest


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    pack = sub.add_parser("retain"); pack.add_argument("capture", type=Path); pack.add_argument("destination", type=Path)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "retain":
        print(retain(args.capture, args.destination))
    else:
        files, manifest = read(args.directory, args.manifest_hash)
        export, bag, ocfl, report = rebuild(files)
        require(export.manifest_hash == manifest["exportManifestHash"]
            and bag.manifest_hash == manifest["bagManifestHash"]
            and ocfl.inventory_hash == manifest["ocflInventoryHash"],
            "token fixture replay result differs")
        print(dumps(report).decode("utf-8"))


if __name__ == "__main__":
    main()
