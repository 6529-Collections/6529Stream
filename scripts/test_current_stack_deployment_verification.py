#!/usr/bin/env python3
"""Offline bytecode regressions; no signer, compiler or network required."""

import copy
import unittest

import verify_current_stack_deployment as verifier


ADDRESS = "0x" + "11" * 20
SENDER = "0x" + "22" * 20
LIBRARY = "x.sol:L"
HASH = "0x" + "33" * 32


def contract(runtime="600100", creation="60026000", immutables=None, links=None, kind="contract"):
    return {"identity": "x.sol:C", "kind": kind, "build_info_sha256": "compiler",
            "immutable_names": {"7": {"name": "authority"}},
            "evm": {"bytecode": {"object": creation, "linkReferences": {}},
                    "deployedBytecode": {"object": runtime, "linkReferences": links or {},
                                         "immutableReferences": immutables or {}}}}


class BytecodeTests(unittest.TestCase):
    def test_exact_runtime_and_changed_opcode(self):
        record = verifier.compare_runtime(contract(), bytes.fromhex("600100"), ADDRESS, {})
        self.assertEqual(record["non_immutable_bytes_verified"], 3)
        with self.assertRaisesRegex(verifier.VerificationError, "outside immutable"):
            verifier.compare_runtime(contract(), bytes.fromhex("610100"), ADDRESS, {})

    def test_immutables_are_observed_not_semantically_verified(self):
        item = contract("600000", immutables={"7": [{"start": 1, "length": 1}]})
        record = verifier.compare_runtime(item, bytes.fromhex("60ff00"), ADDRESS, {})
        observation = record["immutable_observations"][0]
        self.assertEqual(observation["observed_words"][0]["value"], "0xff")
        self.assertFalse(observation["semantic_value_verified"])
        with self.assertRaisesRegex(verifier.VerificationError, "Runtime length"):
            verifier.compare_runtime(item, bytes.fromhex("60ff0000"), ADDRESS, {})

    def test_repeated_immutable_words_must_agree(self):
        item = contract("600000", immutables={"7": [{"start": 1, "length": 1}, {"start": 2, "length": 1}]})
        with self.assertRaisesRegex(verifier.VerificationError, "different values"):
            verifier.compare_runtime(item, bytes.fromhex("60aabb"), ADDRESS, {})

    def test_reference_bounds_overlap_and_library_overlap_rejected(self):
        for refs in ({"7": [{"start": 2, "length": 2}]},
                     {"7": [{"start": 1, "length": 2}], "8": [{"start": 1, "length": 1}]}):
            with self.assertRaises(verifier.VerificationError):
                verifier.compare_runtime(contract(immutables=refs), bytes.fromhex("600100"), ADDRESS, {})
        links = {"x.sol": {"L": [{"start": 1, "length": 20}]}}
        item = contract("73" + "00" * 20, links=links,
                        immutables={"7": [{"start": 1, "length": 1}]})
        with self.assertRaisesRegex(verifier.VerificationError, "overlaps a checked"):
            verifier.compare_runtime(item, b"\x73" + verifier.hex_bytes(SENDER), ADDRESS, {LIBRARY: SENDER})

    def test_linked_address_is_verified_not_masked(self):
        links = {"x.sol": {"L": [{"start": 1, "length": 20}]}}
        item = contract("73" + "__" * 20 + "00", links=links)
        actual = b"\x73" + verifier.hex_bytes(SENDER) + b"\x00"
        self.assertEqual(verifier.compare_runtime(item, actual, ADDRESS, {LIBRARY: SENDER})["linked_libraries"][0]["address"], SENDER)
        with self.assertRaisesRegex(verifier.VerificationError, "outside immutable"):
            verifier.compare_runtime(item, actual, ADDRESS, {LIBRARY: ADDRESS})
        with self.assertRaisesRegex(verifier.VerificationError, "Missing linked"):
            verifier.compare_runtime(item, actual, ADDRESS, {})

    def test_library_self_address_is_checked(self):
        item = contract("73" + "00" * 20 + "30", kind="library")
        actual = b"\x73" + verifier.hex_bytes(ADDRESS) + b"\x30"
        self.assertTrue(verifier.compare_runtime(item, actual, ADDRESS, {})["library_self_address"]["verified"])
        with self.assertRaisesRegex(verifier.VerificationError, "self-address differs"):
            verifier.compare_runtime(item, actual, SENDER, {})

    def test_via_ir_library_deploy_address_is_checked_not_masked(self):
        item = contract("307f" + "00" * 32 + "14", kind="library",
                        immutables={"library_deploy_address": [{"start": 2, "length": 32}]})
        actual = b"\x30\x7f" + bytes(12) + verifier.hex_bytes(ADDRESS) + b"\x14"
        record = verifier.compare_runtime(item, actual, ADDRESS, {})
        self.assertTrue(record["library_self_address"]["verified"])
        self.assertEqual(record["immutable_observations"], [])
        self.assertEqual(record["non_immutable_bytes_verified"], len(actual))
        with self.assertRaisesRegex(verifier.VerificationError, "self-address differs"):
            verifier.compare_runtime(item, actual, SENDER, {})

    def test_pure_library_without_self_guard_is_compared_exactly(self):
        item = contract(kind="library")
        record = verifier.compare_runtime(item, bytes.fromhex("600100"), ADDRESS, {})
        self.assertIsNone(record["library_self_address"])
        with self.assertRaisesRegex(verifier.VerificationError, "outside immutable"):
            verifier.compare_runtime(item, bytes.fromhex("600200"), ADDRESS, {})


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.item = contract()
        self.tx = {"from": SENDER, "to": None, "nonce": "0x3", "input": "0x60026000aabb", "value": "0x0"}
        self.receipt = {"transactionHash": HASH, "status": "0x1", "blockNumber": "0x5",
                        "blockHash": HASH, "contractAddress": ADDRESS}
        self.broadcast = {"chain": 11155111, "libraries": [], "transactions": [
            {"hash": HASH, "transactionType": "CREATE", "contractName": "C",
             "contractAddress": ADDRESS, "transaction": copy.deepcopy(self.tx)}]}

    def rpc(self, method, params):
        return {"eth_chainId": hex(11155111), "eth_getBlockByNumber": {"number": "0x6", "hash": HASH},
                "eth_getTransactionByHash": self.tx, "eth_getTransactionReceipt": self.receipt,
                "eth_getCode": "0x600100"}[method]

    def verify(self):
        return verifier.verify({"x.sol:C": self.item}, self.broadcast, self.rpc)

    def test_public_create_and_constructor_suffix(self):
        record = self.verify()["contracts"][0]
        self.assertTrue(record["creation_prefix_verified"])
        self.assertEqual(record["constructor_arguments_hex"], "0xaabb")
        self.assertFalse(record["constructor_arguments_semantically_verified"])

    def test_public_input_diff_and_reverted_receipt_rejected(self):
        self.tx["input"] = "0x60026000bbbb"
        with self.assertRaisesRegex(verifier.VerificationError, "input differs"):
            self.verify()
        self.tx["input"] = self.broadcast["transactions"][0]["transaction"]["input"]
        self.receipt["status"] = "0x0"
        with self.assertRaisesRegex(verifier.VerificationError, "unsuccessful"):
            self.verify()

    def test_dry_run_and_wrong_chain_rejected(self):
        self.broadcast["transactions"][0]["hash"] = None
        with self.assertRaisesRegex(verifier.VerificationError, "dry run"):
            self.verify()
        self.broadcast["chain"] = 1
        with self.assertRaisesRegex(verifier.VerificationError, "chain differs"):
            self.verify()

    def test_create2_commitment_and_wrong_address(self):
        entry = self.broadcast["transactions"][0]
        entry["transactionType"] = "CREATE2"
        self.tx["to"] = SENDER
        self.tx["input"] = "0x" + "00" * 32 + self.tx["input"][2:]
        entry["transaction"] = copy.deepcopy(self.tx)
        entry["contractAddress"] = "0x" + verifier.keccak(
            b"\xff" + verifier.hex_bytes(SENDER) + bytes(32) + verifier.keccak(bytes.fromhex("60026000aabb")))[-20:].hex()
        self.assertIn("no internal trace", self.verify()["contracts"][0]["creation"]["proof"])
        entry["contractAddress"] = ADDRESS
        with self.assertRaisesRegex(verifier.VerificationError, "CREATE2 address"):
            self.verify()

    def test_runtime_only_is_explicit(self):
        result = verifier.verify({"x.sol:C": self.item}, self.broadcast, self.rpc, {SENDER: "x.sol:C"})
        self.assertFalse(result["contracts"][1]["creation_prefix_verified"])

    def test_internal_creation_has_explicit_trace_limitation(self):
        call_hash = "0x" + "44" * 32
        call = {"from": SENDER, "to": ADDRESS, "input": "0x1234"}
        self.broadcast["transactions"].append({"hash": call_hash, "transactionType": "CALL",
            "transaction": call, "additionalContracts": [{"contractName": "C", "address": SENDER,
                "transactionType": "CREATE2", "initCode": "0x60026000"}]})
        def rpc(method, params):
            if method == "eth_getTransactionByHash" and params == [call_hash]:
                return call
            if method == "eth_getTransactionReceipt" and params == [call_hash]:
                return {**self.receipt, "transactionHash": call_hash}
            return self.rpc(method, params)
        record = verifier.verify({"x.sol:C": self.item}, self.broadcast, rpc)["contracts"][1]
        self.assertFalse(record["creation_prefix_verified"])
        self.assertTrue(record["supplied_creation_prefix_matches_compiler"])
        self.assertIn("no independent", record["creation_limitation"])
        self.broadcast["transactions"][1]["additionalContracts"][0]["initCode"] = "0x60036000"
        with self.assertRaisesRegex(verifier.VerificationError, "no unique compiler"):
            verifier.verify({"x.sol:C": self.item}, self.broadcast, rpc)

    def test_sstore2_data_runtime_requires_exact_bytes(self):
        preamble = "600b5981380380925939f3"
        self.tx["input"] = "0x" + preamble + "00aabb"
        entry = self.broadcast["transactions"][0]
        entry["contractName"] = None
        entry["transaction"] = copy.deepcopy(self.tx)
        def rpc(method, params):
            return "0x00aabb" if method == "eth_getCode" else self.rpc(method, params)
        record = verifier.verify({}, self.broadcast, rpc)["contracts"][0]
        self.assertTrue(record["exact_data_runtime_verified"])
        with self.assertRaisesRegex(verifier.VerificationError, "exact SSTORE2"):
            verifier.verify({}, self.broadcast, self.rpc)

    def test_no_writing_rpc_method_is_available(self):
        with self.assertRaisesRegex(verifier.VerificationError, "read-only"):
            verifier.PublicRpc("unused")("eth_sendRawTransaction", ["unused"])


if __name__ == "__main__":
    unittest.main()
