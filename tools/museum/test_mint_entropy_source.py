"""Synthetic exact-wire controls, without native execution or RPC acceptance."""
import copy
import unittest
from unittest.mock import patch

from tools.metadata.genesis_dossier_profile import _entropy_hash
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import calldata, encode
from .chain_rpc import ReplayTransport
from .independent_wire import ZERO_ADDRESS
from .mint_entropy_source import (MintEntropySource, PROFILE, PROFILE_HASH, ZERO, TOKEN_ENTROPY,
    SUBJECT, REQUEST, POLICY, RECOVERY, CONFIG, TRANSFER, REGISTERED, REVERTED, ENTROPY_REGISTERED,
    REQUESTED, FINALIZED, TERMINAL, SUPERSEDED, COORDINATOR_INTERFACE, VIEW_INTERFACE, MODULE_TYPE,
    token_key, request_hash, seed_hash)


def H(number): return "0x" + f"{number:064x}"
def A(number): return "0x" + f"{number:040x}"


class MintEntropyFixture:
    def __init__(self, *, status=5, recovery=False, late=False, burned=False, prepared=False, abandoned=False):
        self.code = {A(10): b"\x60\x01", A(20): b"\x60\x02"}
        self.a = {"profile": PROFILE, "chainId": "31337", "core": A(10), "coordinator": A(20),
            "tokenId": "71", "collectionId": "6", "blockHash": H(106), "blockNumber": "6",
            "timestamp": "1006", "stateRoot": H(206), "environment": "local_evm_fixture",
            "deploymentEvidenceHash": H(500), "codePins": [{"address": address, "runtimeHash": keccak256(code)}
                for address, code in self.code.items()]}
        self.blocks = {H(100+n): {"hash": H(100+n), "number": hex(n), "timestamp": hex(1000+n),
            "stateRoot": H(200+n), "parentHash": H(99+n) if n else ZERO,
            "transactions": [H(300+n)]} for n in range(7)}
        self.receipts = {H(300+n): {"transactionHash": H(300+n), "blockHash": H(100+n), "blockNumber": hex(n),
            "transactionIndex": "0x0", "status": "0x1", "logs": []} for n in range(7)}
        self.calls, self.requested, self.commitment, self.data = {}, [], H(600), b"native token data"
        for host, ids in ((A(10), ("0x80ac58cd",)), (A(20), (COORDINATOR_INTERFACE, VIEW_INTERFACE))):
            for interface in ("0x01ffc9a7",) + ids:
                self.set(host, "supportsInterface(bytes4)", ("bool",), (True,), ("bytes4",), (interface,))
            self.set(host, "supportsInterface(bytes4)", ("bool",), (False,), ("bytes4",), ("0xffffffff",))
        for signature, kinds, values in (("core()", ("address",), (A(10),)),
            ("streamModuleType()", ("bytes32",), (MODULE_TYPE,)),
            ("streamModuleVersion()", ("bytes32",), (schema_id("6529stream.entropy-coordinator.v1"),)),
            ("streamModuleInterfaceId()", ("bytes4",), (COORDINATOR_INTERFACE,))):
            self.set(A(20), signature, kinds, values)
        self.core("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), (True, 6, 2, burned))
        self.core("tokenLifecycle(uint256)", ("uint8",), (3 if burned else 2,))
        self.core("coordinatorAtMint(uint256)", ("address",), (A(20),))
        self.core("tokenData(uint256)", ("bytes",), (self.data,))
        self.core("ownerOf(uint256)", ("address",), (A(1),))
        if abandoned:
            self.log(0, A(10), [REGISTERED, H(71), H(9)], ("uint16", "uint256"), (1, 8))
            self.log(0, A(10), [REVERTED, H(71), H(9)], ("uint16",), (1,))
        self.log(0 if prepared else 1, A(10), [REGISTERED, H(71), H(6)], ("uint16", "uint256"), (1, 2))
        self.log(1, A(20), [ENTROPY_REGISTERED, H(6), H(71)], ("bytes32",), (self.commitment,))
        self.log(1, A(10), [TRANSFER, H(0), H(1), H(71)])
        self.policies, self.requests, self.recoveries, self.keys = {}, {}, {}, []
        if status != 3:
            first = self.add_request(2, 1)
            if recovery:
                self.log(3, A(20), [TERMINAL, first], ("uint8",), (7,))
                second = self.add_request(4, 2, previous=first, accept_late=late)
                active, final_height = first if late else second, 5
            else:
                active, final_height = first, 3
            if status == 5:
                if late: self.log(5, A(20), [SUPERSEDED, first, second], ("uint16",), (1,))
                raw = H(700)
                self.requests[active] = self.requests[active][:-1] + (raw,)
                seed = seed_hash(self.a, active, self.requests[active], self.policies[active], raw)
                self.log(final_height, A(20), [FINALIZED, active, H(71), ZERO], ("bytes32", "bytes32"), (seed, raw))
            else:
                seed = ZERO
                if status in (6, 7): self.log(final_height, A(20), [TERMINAL, active], ("uint8",), (status,))
            p, r = self.policies[active], self.requests[active]
            entropy = (status, seed, p[0], p[2], p[3], active, r[5], p[6])
        else:
            entropy = (3, ZERO, A(30), 1, H(501), ZERO, 0, 0)
        self.set(A(20), "collectionEntropyConfig(uint256)", CONFIG,
            (A(30), True, True, 100, H(501), H(503), H(503)), ("uint256",), (6,))
        self.set(A(20), "collectionProviderEpoch(uint256)", ("uint32",), (1,), ("uint256",), (6,))
        if burned: self.log(6, A(10), [TRANSFER, H(1), ZERO, H(71)])
        self.entropy = entropy
        self.update_views()

    def set(self, host, signature, outputs, values, inputs=(), args=()):
        self.calls[(host, calldata(signature, inputs, args))] = encode(outputs, values)

    def core(self, signature, outputs, values):
        self.set(A(10), signature, outputs, values, ("uint256",), (71,))

    def log(self, block, host, topics, kinds=(), values=()):
        receipt = self.receipts[H(300+block)]
        row = {key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
        row.update(address=host, topics=topics, data="0x" + encode(kinds, values).hex(),
            logIndex=hex(len(receipt["logs"])), removed=False)
        receipt["logs"].append(row)
        return row

    def add_request(self, block, attempt, *, previous=ZERO, accept_late=False):
        p = (A(29+attempt), H(502+attempt), attempt, H(500+attempt), H(503), self.commitment, attempt)
        key = request_hash(self.a, p)
        r = (token_key(71), 71, ZERO, p[0], block, 40+attempt, ZERO)
        recovery = (ZERO,) * 7 + (0, False) if previous == ZERO else (
            previous, H(800), H(801), H(802), H(803), H(804), H(805), block, accept_late)
        self.policies[key], self.requests[key], self.recoveries[key] = p, r, recovery
        self.keys.append(key)
        self.log(block, A(20), [REQUESTED, key, H(71), ZERO], ("address", "uint256"), (p[0], r[5]))
        return key

    def update_views(self):
        status, seed, _, _, _, active, _, _ = self.entropy
        self.set(A(20), "tokenEntropy(uint256)", TOKEN_ENTROPY, self.entropy, ("uint256",), (71,))
        self.set(A(20), "tokenEntropyStatus(uint256)", ("uint8",), (status,), ("uint256",), (71,))
        self.set(A(20), "tokenSeed(uint256)", ("bytes32", "bool"), (seed, status == 5), ("uint256",), (71,))
        self.set(A(20), "scopeEntropy(bytes32)", SUBJECT, (6, self.commitment, active, seed, status), ("bytes32",), (token_key(71),))
        self.set(A(20), "registeredAtBlock(uint256)", ("uint64",), (1,), ("uint256",), (71,))
        for key, r in self.requests.items():
            self.set(A(20), "requests(bytes32)", REQUEST, r, ("bytes32",), (key,))
            self.set(A(20), "requestPolicySnapshot(bytes32)", POLICY, self.policies[key], ("bytes32",), (key,))
            self.set(A(20), "providerRequestKeys(address,uint256)", ("bytes32",), (key,), ("address", "uint256"), (r[3], r[5]))
            self.set(A(20), "freshRecoveryReceipt(bytes32)", RECOVERY, self.recoveries[key], ("bytes32",), (key,))

    def move_log(self, old_block, new_block, index, *, position=None):
        row = self.receipts[H(300+old_block)]["logs"].pop(index)
        target = self.receipts[H(300+new_block)]
        row.update({k: target[k] for k in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")})
        target["logs"].insert(len(target["logs"]) if position is None else position, row)
        for height in (old_block, new_block):
            for i, log in enumerate(self.receipts[H(300+height)]["logs"]): log["logIndex"] = hex(i)

    def request(self, method, params):
        self.requested.append((method, params))
        if method == "eth_chainId": return "0x7a69"
        if method == "eth_getBlockByHash": return copy.deepcopy(self.blocks[params[0]])
        if method == "eth_getTransactionReceipt": return copy.deepcopy(self.receipts[params[0]])
        if method in ("eth_call", "eth_getCode"):
            assert params[1] == {"blockHash": self.a["blockHash"], "requireCanonical": True}
            if method == "eth_getCode": return "0x" + self.code[params[0]].hex()
            return "0x" + self.calls[(params[0]["to"], params[0]["data"])].hex()
        raise AssertionError(method)

    def source(self): return MintEntropySource(dumps(self.a), self)
    def result(self): return loads(self.source().snapshot(), maximum=4*1024*1024)


class MintEntropySourceTests(unittest.TestCase):
    def test_finalized_exact_leaf_complete_history_and_offline_replay(self):
        f = MintEntropyFixture(); source = f.source(); raw = source.snapshot(); report = loads(raw)
        self.assertEqual(report["profileHash"], PROFILE_HASH)
        self.assertEqual(report["entropy"]["leafHash"], _entropy_hash(report["entropy"]["leaf"]))
        self.assertEqual(keccak256(hex_bytes(report["entropyLeafBytes"])), report["entropy"]["leafHash"])
        self.assertEqual(len(hex_bytes(report["entropyLeafBytes"])), 288)
        self.assertEqual(report["mint"]["mintCommitment"], f.commitment)
        self.assertEqual(report["identity"]["tokenDataHash"], keccak256(f.data))
        self.assertEqual(report["historyCoverage"], {"startBlock": "0", "endBlock": "6", "blockCount": "7", "transactionCount": "7"})
        self.assertEqual([e["event"] for e in report["entropy"]["events"]], ["EntropyRequested", "EntropyFinalized"])
        self.assertTrue(report["terminalEligible"])
        self.assertFalse(report["claims"]["actualChainAcceptance"])
        self.assertFalse(report["claims"]["oracleRandomnessVerified"])
        transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            replay = MintEntropySource(source.anchor_bytes, ReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)
        self.assertEqual(source.snapshot(), raw)
        self.assertEqual(set(source.pins), {A(10), A(20)})

    def test_supported_unfinalized_states_remain_explicit(self):
        for status in (3, 4, 6, 7):
            with self.subTest(status=status):
                report = MintEntropyFixture(status=status).result()
                self.assertEqual(report["observedStatus"], str(status))
                self.assertFalse(report["terminalEligible"])
                self.assertIn("not FINALIZED", report["remaining"][0])
                self.assertEqual(report["entropy"]["leaf"]["seed"], ZERO)
                self.assertEqual(len(report["entropy"]["events"]), 0 if status == 3 else 1)

    def test_fresh_recovery_and_late_original_keep_every_request(self):
        for late in (False, True):
            with self.subTest(late=late):
                f = MintEntropyFixture(recovery=True, late=late); report = f.result()
                self.assertEqual([r["requestKey"] for r in report["native"]["requests"]], f.keys)
                self.assertEqual(report["entropy"]["leaf"]["requestKey"], f.keys[0 if late else 1])
                self.assertEqual(report["entropy"]["leaf"]["requestAttempt"], "1" if late else "2")
                self.assertEqual(len(report["entropyLogs"]), 3)
                self.assertEqual(len(report["entropyControlLogs"]), 2 if late else 1)

    def test_burned_prepared_and_abandoned_allocation_history(self):
        for options in ({"burned": True}, {"prepared": True}, {"abandoned": True}):
            with self.subTest(options=options):
                f = MintEntropyFixture(**options)
                if options.get("burned"): del f.calls[(A(10), calldata("ownerOf(uint256)", ("uint256",), (71,)))]
                report = f.result()
                self.assertEqual(report["identity"]["burned"], bool(options.get("burned")))
                self.assertEqual(len(report["mint"]["abandonedAllocations"]), int(bool(options.get("abandoned"))))
                self.assertEqual(report["mint"]["logs"]["registered"]["blockNumber"], "0x0" if options.get("prepared") else "0x1")

    def test_nonexistent_disabled_not_required_and_unknown_status_fail_closed(self):
        for status in (0, 1, 2, 8):
            f = MintEntropyFixture(status=3); f.entropy = (status,) + f.entropy[1:]; f.update_views()
            with self.subTest(status=status), self.assertRaisesRegex(MuseumError, "production writer"):
                f.source().snapshot()

    def test_core_identity_coordinator_and_mint_event_mismatch(self):
        changes = [lambda f: f.core("coordinatorAtMint(uint256)", ("address",), (A(99),)),
            lambda f: f.core("tokenLifecycle(uint256)", ("uint8",), (1,)),
            lambda f: f.core("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), (True, 6, 3, False)),
            lambda f: f.receipts[H(301)]["logs"][1]["topics"].__setitem__(1, H(7)),
            lambda f: f.receipts[H(301)]["logs"][1].update(address=A(99)),
            lambda f: f.receipts[H(301)]["logs"][2]["topics"].__setitem__(1, H(9)),
            lambda f: f.receipts[H(301)]["logs"][0].update(data="0x" + encode(("uint16", "uint256"), (2, 2)).hex())]
        for edit in changes:
            f = MintEntropyFixture(); edit(f)
            with self.subTest(edit=edit), self.assertRaises(MuseumError): f.source().snapshot()

    def test_missing_requested_finalized_terminal_and_wrong_scope(self):
        cases = [(5, 2), (5, 3), (7, 3)]
        for status, block in cases:
            f = MintEntropyFixture(status=status); f.receipts[H(300+block)]["logs"] = []
            with self.subTest(status=status, block=block), self.assertRaises(MuseumError): f.source().snapshot()
        f = MintEntropyFixture(); f.receipts[H(302)]["logs"][0]["topics"][3] = H(99)
        with self.assertRaisesRegex(MuseumError, "scope/request"): f.source().snapshot()

    def test_request_storage_policy_hash_and_index_joins(self):
        edits = [("requests(bytes32)", REQUEST, lambda r: (H(99),) + r[1:]),
                 ("requests(bytes32)", REQUEST, lambda r: r[:4] + (3,) + r[5:]),
                 ("requestPolicySnapshot(bytes32)", POLICY, lambda p: p[:3] + (H(99),) + p[4:]),
                 ("requestPolicySnapshot(bytes32)", POLICY, lambda p: p[:5] + (H(99),) + p[6:])]
        for signature, kinds, edit in edits:
            f = MintEntropyFixture(); key = f.keys[0]; row = f.requests[key] if kinds == REQUEST else f.policies[key]
            f.set(A(20), signature, kinds, edit(row), ("bytes32",), (key,))
            with self.subTest(signature=signature, edit=edit), self.assertRaises(MuseumError): f.source().snapshot()
        f = MintEntropyFixture(); r = f.requests[f.keys[0]]
        f.set(A(20), "providerRequestKeys(address,uint256)", ("bytes32",), (H(99),), ("address", "uint256"), (r[3], r[5]))
        with self.assertRaisesRegex(MuseumError, "provider request index"): f.source().snapshot()

    def test_coherently_changed_native_views_cannot_replace_final_seed(self):
        f = MintEntropyFixture(); f.entropy = (5, H(99)) + f.entropy[2:]; f.update_views()
        f.receipts[H(303)]["logs"][0]["data"] = "0x" + encode(("bytes32", "bytes32"), (H(99), H(700))).hex()
        with self.assertRaisesRegex(MuseumError, "seed preimage"): f.source().snapshot()

    def test_late_original_requires_each_retained_permission_and_supersession(self):
        for missing in ("permission", "supersession", "previous"):
            f = MintEntropyFixture(recovery=True, late=True)
            if missing == "permission": f.recoveries[f.keys[1]] = f.recoveries[f.keys[1]][:-1] + (False,)
            if missing == "previous": f.recoveries[f.keys[1]] = (H(99),) + f.recoveries[f.keys[1]][1:]
            if missing == "supersession":
                f.receipts[H(305)]["logs"].pop(0); f.receipts[H(305)]["logs"][0]["logIndex"] = "0x0"
            f.update_views()
            with self.subTest(missing=missing), self.assertRaises(MuseumError): f.source().snapshot()

    def test_abi_runtime_interfaces_provenance_and_failed_capture_guard(self):
        f = MintEntropyFixture(); f.code[A(20)] += b"x"
        with self.assertRaisesRegex(MuseumError, "runtime differs"): f.source().snapshot()
        f = MintEntropyFixture(); key = (A(20), calldata("tokenEntropy(uint256)", ("uint256",), (71,)))
        f.calls[key] += bytes(32)
        source = f.source()
        with self.assertRaisesRegex(MuseumError, "ABI"): source.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"): source.snapshot()
        with self.assertRaisesRegex(MuseumError, "snapshot required"): source.transcript()
        f = MintEntropyFixture(); f.set(A(20), "supportsInterface(bytes4)", ("bool",), (True,), ("bytes4",), ("0xffffffff",))
        with self.assertRaisesRegex(MuseumError, "invalid interface"): f.source().snapshot()
        with self.assertRaisesRegex(MuseumError, "provenance"): MintEntropySource(dumps(f.a), f, provenance="trusted_rpc")

    def test_receipt_range_and_packet_event_bound_are_refusals(self):
        f = MintEntropyFixture(); f.blocks[H(102)]["parentHash"] = H(99)
        # An unavailable header is a transport error, never a successfully truncated capture.
        with self.assertRaises((KeyError, MuseumError)): f.source().snapshot()
        f = MintEntropyFixture(status=4)
        for n in range(64): f.log(3, A(20), [REQUESTED, H(2000+n), H(71), ZERO], ("address", "uint256"), (A(30), n))
        with self.assertRaisesRegex(MuseumError, "packet event bound"): f.source().snapshot()
        self.assertFalse(any(method == "eth_call" and params[0]["data"].startswith(calldata("requests(bytes32)")[:10])
            for method, params in f.requested))

    def test_receiver_hook_request_after_transfer_is_valid_but_before_transfer_is_not(self):
        for position, valid in ((3, True), (2, False)):
            f = MintEntropyFixture(); key = f.keys[0]
            f.move_log(2, 1, 0, position=position)
            f.requests[key] = f.requests[key][:4] + (1,) + f.requests[key][5:]
            f.update_views()
            with self.subTest(position=position):
                if valid: self.assertTrue(f.result()["terminalEligible"])
                else:
                    with self.assertRaisesRegex(MuseumError, "completed mint Transfer"): f.source().snapshot()

    def test_burn_prevents_requests_but_does_not_prevent_finalization(self):
        f = MintEntropyFixture(burned=True)
        f.move_log(6, 2, 0)  # request, then burn, then later callback
        self.assertTrue(f.result()["terminalEligible"])
        f = MintEntropyFixture(burned=True)
        f.move_log(6, 2, 0, position=0)  # burn, then impossible new request
        with self.assertRaisesRegex(MuseumError, "request after burn"): f.source().snapshot()

    def test_final_repeated_header_requires_exact_retained_transaction_denominator(self):
        f = MintEntropyFixture(); original_request = f.request
        def changed(method, params):
            result = original_request(method, params)
            if method == "eth_getBlockByHash" and params[0] == f.a["blockHash"] and any(m == "eth_call" for m, _ in f.requested):
                result["transactions"] = []
            return result
        f.request = changed
        with self.assertRaisesRegex(MuseumError, "final source differs"): f.source().snapshot()

    def test_first_policy_joins_locked_config_even_when_seed_is_coherently_rehashed(self):
        for field in (1, 4):  # Neither provider code hash nor salt is in the request-key preimage.
            f = MintEntropyFixture(); key = f.keys[0]
            policy = list(f.policies[key]); policy[field] = H(999); f.policies[key] = tuple(policy)
            changed_seed = seed_hash(f.a, key, f.requests[key], f.policies[key], f.requests[key][6])
            f.entropy = (5, changed_seed) + f.entropy[2:]
            f.receipts[H(303)]["logs"][0]["data"] = "0x" + encode(("bytes32", "bytes32"), (changed_seed, H(700))).hex()
            f.update_views()
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "locked collection policy"):
                f.source().snapshot()
        # A later recovery uses its own higher-epoch provider, preserving the original lock.
        result = MintEntropyFixture(recovery=True).result()
        self.assertNotEqual(result["native"]["collectionEntropyConfig"][0], result["entropy"]["leaf"]["provider"])
        self.assertEqual(result["native"]["collectionProviderEpoch"], "1")

    def test_recovery_cannot_reuse_provider_request_id_with_inconsistent_index_answers(self):
        f = MintEntropyFixture(recovery=True); first, old = f.keys
        policy = (f.policies[first][0],) + f.policies[old][1:]
        new = request_hash(f.a, policy)
        r = f.requests.pop(old)
        f.requests[new] = r[:3] + (policy[0], r[4], f.requests[first][5], r[6])
        f.policies.pop(old); f.policies[new] = policy
        f.recoveries[new] = f.recoveries.pop(old); f.keys[1] = new
        new_seed = seed_hash(f.a, new, f.requests[new], policy, r[6])
        f.entropy = (5, new_seed, policy[0], policy[2], policy[3], new, f.requests[first][5], policy[6])
        requested = f.receipts[H(304)]["logs"][0]
        requested["topics"][1] = new
        requested["data"] = "0x" + encode(("address", "uint256"), (policy[0], f.requests[first][5])).hex()
        finalized = f.receipts[H(305)]["logs"][0]
        finalized["topics"][1] = new
        finalized["data"] = "0x" + encode(("bytes32", "bytes32"), (new_seed, r[6])).hex()
        f.update_views()
        query = calldata("providerRequestKeys(address,uint256)", ("address", "uint256"), (policy[0], f.requests[first][5]))
        ordinary, answers = f.request, []
        def contradictory(method, params):
            if method == "eth_call" and params[0]["data"] == query:
                answers.append(first if not answers else new)
                f.requested.append((method, params))
                return "0x" + encode(("bytes32",), (answers[-1],)).hex()
            return ordinary(method, params)
        f.request = contradictory
        with self.assertRaisesRegex(MuseumError, "duplicate provider request ID"): f.source().snapshot()
        self.assertEqual(answers, [first])  # Reject before accepting a second answer to the same native index.


if __name__ == "__main__": unittest.main()
