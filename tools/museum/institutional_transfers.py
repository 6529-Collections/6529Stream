"""Pinned original ERC-721 Transfer joins; instruments retain their legal qualification."""
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import encode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .institutional import _admit_row, need
from .institutional_source import InstitutionalOwnerSource

PROFILE = "STREAM_MUSEUM_INSTITUTIONAL_TRANSFER_RECEIPTS_V1"
EVENT = schema_id("Transfer(address,address,uint256)")
CLAIMS = {"selectedOriginalTokenTransfersChecked": True, "cryptographicReceiptProof": False,
    "cryptographicStateProof": False, "legalTitleProven": False, "physicalCustodyTransferred": False,
    "namedInstitutionIdentityProven": False, "fullTokenTransferHistory": False}
CLAIMS["transferPrecedesSourcePublicationProven"] = False
QUALIFICATION = "Selected ERC-721 Transfer receipt correspondence under externally pinned trusted RPC evidence; legal title, physical custody and named institution identity remain separate."
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "bounds": {"records": "64", "receipts": "64", "ancestorSpan": "256", "transactionsPerBlock": "8192", "logsPerReceipt": "4096"},
    "rules": {"source": "Exact reconstructed institutional owner snapshot and selected ACCESSION/DEACCESSION bytes.",
        "receipt": "Successful receipt; exact original Core address, four indexed Transfer topics, empty data, original token/from/to and specified log index.",
        "chain": "Parent-linked headers from externally pinned anchor through oldest selected receipt; exact receipt block/transaction inclusion and compatibility with recorded publication timestamp. Same-block order against the owner publication is not proved.",
        "scope": "Selected transfer facts only. Old transfers beyond the bounded ancestor span require a separately qualified capture profile; no silent truncation.",
        "retention": "Exact source/hints/transcript and deterministic correspondence, no RPC URL retained or remote instrument fetch.",
        "title": "Matching token-transfer evidence never verifies an instrument's legal validity or physical-object custody."},
    "qualification": QUALIFICATION, "claims": CLAIMS})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class TitleTransferCapture:
    def __init__(self, source, hints_bytes, transport, *, hints_hash, source_hash, provenance="synthetic_fixture"):
        need(type(source) is InstitutionalOwnerSource and source.provenance == "trusted_rpc", "transfer concrete source required")
        need(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)), "transfer provenance")
        committed = loads(source.snapshot(), maximum=MAX_TRANSCRIPT, canonical=True)
        need(keccak256(source.snapshot()) == source_hash and keccak256(source.anchor_bytes) == committed["anchorHash"], "transfer source pin differs")
        frozen = InstitutionalOwnerSource(source.anchor_bytes,
            ReplayTransport(source.reader.transcript(), committed["transcriptHash"]), provenance="trusted_rpc")
        need(keccak256(frozen.snapshot()) == source_hash, "transfer source reconstruction differs")
        need(keccak256(hints_bytes) == hints_hash, "transfer hints pin differs")
        hints = loads(hints_bytes, maximum=524288, canonical=True)
        need(isinstance(hints, dict) and set(hints) == {"profile", "ownerSourceHash", "records"}
            and hints["profile"] == PROFILE and hints["ownerSourceHash"] == source_hash, "transfer hint shape/source differs")
        need(isinstance(hints["records"], list) and 0 < len(hints["records"]) <= 64, "transfer selection bound")
        selected = []
        for digest in hints["records"]:
            need(any(hex_bytes(digest, 32)) and digest not in selected and digest in frozen.records, "transfer selected original missing/duplicate")
            selected.append(digest)
        self._source, self._hints, self._hints_bytes = frozen, hints, hints_bytes
        self.provenance = provenance
        self.reader = RecordingReader(transport, frozen.a["blockHash"])
        self._started, self._result = False, None

    def capture(self):
        from .canonical import MuseumError
        try:
            return self._capture()
        except (KeyError, IndexError, TypeError, OverflowError) as exc:
            raise MuseumError("institutional malformed transfer receipt/header") from exc

    def _capture(self):
        if self._result is not None: return self._result
        need(not self._started, "failed transfer capture cannot resume"); self._started = True
        a = self._source.a; anchor_number = uint(a["blockNumber"])
        need(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]), "transfer chain differs")
        selected, receipts = {}, {}
        for digest in sorted(self._hints["records"]):
            row = self._source.records[digest]
            family = next((k for k in ("ACCESSION", "DEACCESSION") if row["record"][0] == schema_id(k)), None)
            need(family is not None, "transfer title-bearing original family required")
            value = _admit_row(self._source, row, family)
            transfer = value["titleBinding"]["transfer"]; tx = transfer["transactionHash"]
            selected[digest] = (row, transfer)
            if tx not in receipts:
                receipt = self.reader.request("eth_getTransactionReceipt", [tx])
                need(isinstance(receipt, dict) and receipt.get("transactionHash") == tx and receipt.get("status") == "0x1", "transfer successful receipt required")
                need(any(hex_bytes(receipt["blockHash"], 32)), "transfer receipt block missing")
                quantity(receipt["blockNumber"]); quantity(receipt["transactionIndex"])
                need(isinstance(receipt.get("logs"), list) and len(receipt["logs"]) <= 4096, "transfer receipt log bound")
                receipts[tx] = receipt
            need(quantity(receipts[tx]["blockNumber"]) == uint(transfer["blockNumber"]), "transfer declared block differs")
        oldest = min(quantity(r["blockNumber"]) for r in receipts.values())
        need(oldest <= anchor_number and anchor_number - oldest <= 256, "transfer ancestor span unsupported")
        blocks, expected = {}, a["blockHash"]
        for number in range(anchor_number, oldest - 1, -1):
            block = self.reader.request("eth_getBlockByHash", [expected, False])
            need(isinstance(block, dict) and block.get("hash") == expected and quantity(block["number"]) == number, "transfer anchor ancestry differs")
            stamp = quantity(block["timestamp"])
            need(any(hex_bytes(block["parentHash"], 32)), "transfer ancestor parent missing")
            if number == anchor_number:
                need(block.get("stateRoot") == a["stateRoot"] and stamp == uint(a["timestamp"]), "transfer original anchor differs")
            else: need(stamp <= quantity(blocks[number + 1]["timestamp"]), "transfer ancestor time order differs")
            txs = block.get("transactions")
            need(isinstance(txs, list) and len(txs) <= 8192, "transfer block transaction bound")
            for tx in txs: need(any(hex_bytes(tx, 32)), "transfer block transaction identity")
            need(len(set(txs)) == len(txs), "transfer duplicate block transaction")
            blocks[number] = block; expected = block["parentHash"]
        indexed = {}
        block_positions = set()
        for tx, receipt in receipts.items():
            number, position = quantity(receipt["blockNumber"]), quantity(receipt["transactionIndex"])
            block = blocks[number]
            need(receipt["blockHash"] == block["hash"] and position < len(block["transactions"])
                and block["transactions"][position] == tx, "transfer receipt canonical transaction differs")
            by_index, last = {}, -1
            for log in receipt["logs"]:
                need(isinstance(log, dict) and log.get("removed") is False, "transfer removed/malformed log")
                index = quantity(log["logIndex"])
                need(index > last and (number, index) not in block_positions, "transfer duplicate/unordered log")
                need(all(log.get(k) == receipt[k] for k in ("blockNumber", "blockHash", "transactionHash", "transactionIndex")), "transfer log receipt coordinates differ")
                by_index[index] = log; last = index; block_positions.add((number, index))
            indexed[tx] = by_index
        correspondences = []
        for digest, (row, transfer) in selected.items():
            tx = transfer["transactionHash"]; receipt = receipts[tx]
            log = indexed[tx].get(uint(transfer["logIndex"]))
            topics = [EVENT, "0x" + encode(("address",), (transfer["from"],)).hex(),
                "0x" + encode(("address",), (transfer["to"],)).hex(), "0x" + encode(("uint256",), (uint(transfer["tokenId"]),)).hex()]
            need(log is not None and log.get("address") == a["core"] and log.get("topics") == topics
                and log.get("data") == "0x", "transfer exact original ERC721 event differs")
            stamp = quantity(blocks[uint(transfer["blockNumber"])]["timestamp"])
            need(stamp <= uint(row["receipt"][2]), "transfer event postdates source publication")
            correspondences.append({"recordHash": digest, "subjectId": row["record"][1], "ownerAtPublication": row["receipt"][1],
                "titleBindingSourcePath": "/titleBinding/transfer", "transfer": transfer,
                "blockHash": receipt["blockHash"], "transactionIndex": str(quantity(receipt["transactionIndex"])),
                "sourceRecordedAt": row["receipt"][2], "eventTimestamp": str(stamp), "claims": CLAIMS})
        need(self.reader.request("eth_getBlockByHash", [a["blockHash"], False]) == blocks[anchor_number], "transfer anchor changed during capture")
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        self._result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "recorded_transfer_receipts" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "ownerSourceHash": self._hints["ownerSourceHash"], "hintsHash": keccak256(self._hints_bytes),
            "transcriptHash": keccak256(self.reader.transcript()), "correspondences": correspondences,
            "claims": CLAIMS, "qualification": QUALIFICATION})
        return self._result
