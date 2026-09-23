"""Coherent synthetic governance-transaction evidence over Finality V6.

This fixture deliberately rebuilds the governance action, action ID, stored
reads, event receipts and outer Executor calldata before any capture is made.
It is synthetic test evidence: transaction hashes and sender fields are not
signed-envelope or consensus proofs.
"""
import copy

from . import governance_transaction_wire as governance
from . import native_finality_wire as finality
from . import public_finality_source as finality_source
from .canonical import hex_bytes, keccak256, loads
from .chain_abi import Array, calldata, encode
from .finality_v6_fixture import FinalityV6Fixture
from .independent_wire import ZERO_ADDRESS
from .test_current_rights_source import A, H
from .title_v5_fixture import TOKEN


class FinalityGovernanceTransactionFixture(FinalityV6Fixture):
    """One fully rebuilt single or batch Executor transaction fixture."""

    def __init__(self, *, mode="single", burned=False):
        if mode not in ("single", "batch", "missing_schedule", "missing_execution"):
            raise ValueError("invalid synthetic governance transaction mode")
        self.transaction_mode = mode
        self.governance_transactions = {}
        super().__init__(burned=burned)

    @staticmethod
    def _position(receipt):
        return receipt["blockHash"], receipt["blockNumber"], receipt["transactionIndex"]

    def _reindex_blocks(self):
        for block_hash in {row["blockHash"] for row in self.receipts.values()}:
            index = 0
            receipts = sorted((row for row in self.receipts.values() if row["blockHash"] == block_hash),
                key=lambda row: int(row["transactionIndex"], 16))
            for receipt in receipts:
                for log in receipt["logs"]:
                    log["logIndex"] = hex(index); index += 1

    def _receipt(self, block, transaction_hash, transaction_index):
        header = self.blocks[H(200 + block)]
        receipt = {"transactionHash": transaction_hash, "blockHash": header["hash"],
            "blockNumber": header["number"], "transactionIndex": hex(transaction_index),
            "status": "0x1", "logs": []}
        header["transactions"].append(transaction_hash)
        self.receipts[transaction_hash] = receipt
        return receipt

    def _append(self, receipt, address, topics, data):
        preceding = sum(len(row["logs"]) for row in self.receipts.values()
            if row["blockHash"] == receipt["blockHash"]
            and int(row["transactionIndex"], 16) < int(receipt["transactionIndex"], 16))
        log = {"address": address, "blockHash": receipt["blockHash"],
            "blockNumber": receipt["blockNumber"], "transactionHash": receipt["transactionHash"],
            "transactionIndex": receipt["transactionIndex"], "logIndex": hex(preceding + len(receipt["logs"])),
            "topics": list(topics), "data": data, "removed": False}
        receipt["logs"].append(log)
        return log

    def _install_finality(self):
        # Build the unchanged synthetic V6 material first, then replace every
        # governance-dependent byte before a source or package is captured.
        super()._install_finality()
        a = self.finality_addresses
        bundle = copy.deepcopy(self.finality_bundle)
        graph = {key: {"address": a[finality_source.GRAPH_MAP[key]],
            "runtimeHash": self.pins[a[finality_source.GRAPH_MAP[key]]]}
            for key in finality.GRAPH_KEYS}
        context = {
            **{key: self.a[key] for key in ("chainId", "core", "collectionId", "blockHash",
                "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash")},
            "tokenId": str(TOKEN)}
        derived = finality.validate_bundle(bundle, context, graph)
        execution, stored = bundle["execution"], finality.from_json(finality.GOVERNANCE_ACTION,
            bundle["execution"]["action"])
        original_action_id = finality.from_json(finality.EXECUTION_WITNESS,
            bundle["finality"]["executionWitness"])[0]
        original_call_datas = tuple(hex_bytes(value) for value in execution["callDatas"])
        original_call_key = keccak256(b"".join(hex_bytes(keccak256(raw)) for raw in original_call_datas))
        final_data = hex_bytes(execution["callDatas"][int(derived["execution"]["matchedCallIndex"])])
        expected = derived["executionContext"]
        final_call = (a["originalFinality"], 0, "0x" + final_data[:4].hex(), keccak256(final_data),
            expected["scopeHash"], expected["oldValueHash"], expected["newValueHash"])
        if self.transaction_mode == "batch":
            marker = hex_bytes(calldata("syntheticGovernanceMarker(bytes32)", ("bytes32",), (H(36010),)))
            calls = ((A(36010), 0, "0x" + marker[:4].hex(), keccak256(marker), H(36011), H(36012), H(36013)),
                final_call)
            call_datas = (marker, final_data)
        else:
            calls, call_datas = (final_call,), (final_data,)

        digest = governance.calls_hash(calls)
        aggregates = governance.transition_hashes(calls)
        action = (3, stored[1], calls[0][0], sum(row[1] for row in calls), calls[0][2], digest,
            *aggregates, stored[9], stored[10], stored[11], stored[12], ZERO_ADDRESS,
            ZERO_ADDRESS, stored[15], stored[16], stored[17])
        nonce = 1
        identity = (action[1], digest, *aggregates, nonce, action[9], action[10], action[15], action[17])
        action_id = governance.action_id(self.a["chainId"], a["executor"], identity)
        witness = list(finality.from_json(finality.EXECUTION_WITNESS, bundle["finality"]["executionWitness"]))
        witness[0] = action_id
        bundle["finality"]["executionWitness"] = list(witness)
        bundle["execution"]["action"] = list(action)
        bundle["execution"]["callDatas"] = ["0x" + raw.hex() for raw in call_datas]
        bundle["execution"]["runtime"] = "0x" + (b"\0" + encode((Array("bytes", 64),), (call_datas,))).hex()
        self.finality_bundle = bundle

        pointer = execution["callDataPointer"]
        runtime = hex_bytes(bundle["execution"]["runtime"])
        self.codes[pointer] = runtime
        self.add(a["originalFinality"], "finalityExecutionWitness(bytes32)", ("bytes32",),
            (bundle["finality"]["record"][1],), (finality.EXECUTION_WITNESS,), (tuple(witness),))
        self.add(a["executor"], "governanceAction(bytes32)", ("bytes32",), (action_id,),
            (finality.GOVERNANCE_ACTION,), (action,))
        self.add(a["executor"], "scheduledCallDataPointer(bytes32)", ("bytes32",), (action_id,),
            ("address",), (pointer,))
        self.add(a["executor"], "scheduledCallData(bytes32)", ("bytes32",), (action_id,),
            (Array("bytes", 64),), (call_datas,))
        call_key = keccak256(b"".join(hex_bytes(keccak256(raw)) for raw in call_datas))
        self.add(a["executor"], "publishedCallData(bytes32)", ("bytes32",), (call_key,),
            ("address",), (pointer,))

        # Remove the compact fixture's synthetic governance/terminal logs.
        terminal_addresses = {(row["address"], row["topics"][0])
            for row in finality.expected_events(copy.deepcopy(self.finality_bundle), context, graph)
            if row["kind"] in ("finality_finalized", "pointer_recorded", "freeze_executed",
                "execution_witness", "archive_witness")}
        governance_topics = {finality.EVENTS[key] for key in ("governanceScheduled", "governanceExecuted")}
        def replaced(log):
            if (log["address"], log["topics"][0]) in terminal_addresses:
                return True
            if log["address"] != a["executor"]:
                return False
            if log["topics"][0] in governance_topics:
                return len(log["topics"]) > 1 and log["topics"][1] == original_action_id
            return (log["topics"][0] == finality.EVENTS["governanceCalldataPublished"]
                and len(log["topics"]) > 1 and log["topics"][1] == original_call_key)
        for receipt in self.receipts.values():
            receipt["logs"][:] = [log for log in receipt["logs"]
                if not replaced(log)]
        self._reindex_blocks()

        # Keep publication, scheduling and execution in distinct original
        # transactions. This is valid for both the single wrapper (the bytes
        # were already published) and explicit batch scheduling.
        publish_hash, schedule_hash, execute_hash = H(36020), H(36021), H(36022)
        publish_receipt = self._receipt(3, publish_hash, 1)
        schedule_receipt = self._receipt(3, schedule_hash, 2)
        execute_receipt = self._receipt(4, execute_hash, 1)
        publisher = A(35006)
        self._append(publish_receipt, a["executor"],
            (finality.EVENTS["governanceCalldataPublished"], call_key),
            "0x" + encode(finality.GOVERNANCE_CALLDATA_DATA, (1, pointer, publisher)).hex())
        action_topics = (action_id, finality._topic("uint8", action[1]), finality._topic("address", action[2]))
        scheduled = (1, *action[3:11], nonce, action[11], action[15], action[16], action[17])
        self._append(schedule_receipt, a["executor"],
            (finality.EVENTS["governanceScheduled"], *action_topics),
            "0x" + encode(finality.GOVERNANCE_SCHEDULED_DATA, scheduled).hex())

        expected_events = finality.expected_events(bundle, context, graph)
        for kind in ("finality_finalized", "pointer_recorded", "freeze_executed", "execution_witness", "archive_witness"):
            row = next(item for item in expected_events if item["kind"] == kind)
            self._append(execute_receipt, row["address"], row["topics"], row["data"])
        executed = (1, *action[3:9], action[12], action[17])
        self._append(execute_receipt, a["executor"],
            (finality.EVENTS["governanceExecuted"], *action_topics),
            "0x" + encode(finality.GOVERNANCE_EXECUTED_DATA, executed).hex())

        if self.transaction_mode == "batch":
            schedule_input = calldata(governance.SIGNATURES["schedule_batch"], governance.SCHEDULE_BATCH,
                (action[1], calls, *aggregates, action[9], action[10], action[15], action[16], action[17]))
            execute_input = calldata(governance.SIGNATURES["execute_batch"], governance.EXECUTE_BATCH,
                (action_id, calls, call_datas))
        else:
            request = (action[1], *calls[0][:3], call_datas[0], *calls[0][4:], action[9], action[10],
                action[15], action[16], action[17])
            schedule_input = calldata(governance.SIGNATURES["schedule_action"], governance.SCHEDULE_ACTION,
                (request,))
            execute_input = calldata(governance.SIGNATURES["execute_action"], governance.EXECUTE_ACTION,
                (action_id, call_datas[0]))
        chain = hex(int(self.a["chainId"]))
        self.governance_transactions = {
            schedule_hash: {"hash": schedule_hash, "blockHash": schedule_receipt["blockHash"],
                "blockNumber": schedule_receipt["blockNumber"], "transactionIndex": schedule_receipt["transactionIndex"],
                "from": action[11], "to": a["executor"], "value": "0x0", "input": schedule_input,
                "chainId": chain},
            execute_hash: {"hash": execute_hash, "blockHash": execute_receipt["blockHash"],
                "blockNumber": execute_receipt["blockNumber"], "transactionIndex": execute_receipt["transactionIndex"],
                "from": action[12], "to": a["executor"], "value": hex(action[3]), "input": execute_input,
                "chainId": chain}}
        self.schedule_transaction_hash, self.execution_transaction_hash = schedule_hash, execute_hash

    def request(self, method, params):
        if method == "eth_getTransactionByHash":
            self.requested.append((method, copy.deepcopy(params)))
            value = self.governance_transactions.get(params[0])
            if ((self.transaction_mode == "missing_schedule" and params[0] == self.schedule_transaction_hash)
                    or (self.transaction_mode == "missing_execution" and params[0] == self.execution_transaction_hash)):
                return None
            return copy.deepcopy(value)
        return super().request(method, params)

    def transaction_source(self):
        from .public_governance_transaction_source import PublicGovernanceTransactionSource
        native = self.finality_capture()
        return PublicGovernanceTransactionSource(dict(native.files), native.manifest_hash, self,
            provenance="synthetic_fixture")

    def transaction_result(self):
        from . import public_governance_transaction_source as source
        return loads(self.transaction_source().snapshot(), maximum=source.MAX_BYTES)

    def transaction_capture(self):
        from . import public_governance_transaction_capture as capture
        source = self.transaction_source()
        return capture._assemble(source, capture.source.PROFILE_HASH)

    def transaction_inputs(self):
        from . import acquisition_finality_v6 as assembly
        title, finality_capture = self.finality_inputs()
        original = assembly.compose(title.files, title.manifest_hash, finality_capture.files,
            finality_capture.manifest_hash, disclosure="public")
        return original, self.transaction_capture()
