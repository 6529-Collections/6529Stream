"""Offline transport doubles: these do not constitute a deployed-stack rehearsal."""

import copy
import http.client
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.museum.canonical import MuseumError, dumps, keccak256, loads
from tools.museum.chain_abi import encode
from .current_health import Inputs, Monitor, VIEWS, main, read_plan, sha
from .transport import HttpTransport, Recorder, Replay, RpcFailure

ROOT = Path(__file__).resolve().parents[2]
CORE = "0x" + "11" * 20
GOVERNANCE = "0x" + "22" * 20
SALE = "0x" + "33" * 20
SUPPORT = "0x" + "44" * 20
BLOCK = "0x" + "aa" * 32
STATE = "0x" + "bb" * 32
CODE = "0x6000600055"
EVENT = "GenesisInitialized(bytes32,uint256)"


def view(signature):
    return {"type": "function", "name": signature[:-2], "stateMutability": "view", "inputs": [],
            "outputs": [{"name": "", "type": kind} for kind in VIEWS[signature]]}


class Fixture:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.profile_path = ROOT / "release-artifacts/genesis-deployment-profile.json"
        self.profile_sha = sha(self.profile_path.read_bytes())
        self.native = {"mode": "current_museum_native_products_v1", "products": {}}
        self.evidence = {"kind": "local_evm_fixture", "artifacts": {}}
        self.artifacts = {}
        items = [("StreamCore", CORE, []), ("StreamGovernanceExecutor", GOVERNANCE, [
            "genesisInitialized()", "governanceActionPolicyState()"]), ("StreamNativeFixedPrice", SALE, [
            "paused()", "entropyPolicyInventory()", "incompleteFinalityRecoveryRefreshPlanCount()", "recoveryExecutorBinding()"])]
        for name, target, views in items:
            source = "test/offline-monitor/" + name + ".sol"
            abi = [view(signature) for signature in views]
            if target == GOVERNANCE:
                abi.append({"type": "event", "name": "GenesisInitialized", "anonymous": False, "inputs": [
                    {"name": "planHash", "type": "bytes32", "indexed": True},
                    {"name": "batchCount", "type": "uint256", "indexed": False}]})
            artifact = {"metadata": {"settings": {"compilationTarget": {source: name}}}, "abi": abi,
                        "methodIdentifiers": {s: keccak256(s.encode())[2:10] for s in views}}
            self.artifacts[name] = artifact
            path = self.directory / (name + ".json")
            path.write_bytes(dumps(artifact))
            row = {"source": source, "artifact": str(path), "sha256": sha(path.read_bytes())}
            self.native["products"][name] = row
            self.evidence["artifacts"][name] = row | {"address": target,
                "runtimeHash": keccak256(bytes.fromhex(CODE[2:])), "runtimeBytes": "5"}
        self.anchor = {"chainId": "31337", "core": CORE, "blockHash": BLOCK, "blockNumber": "42",
                       "timestamp": "12345", "stateRoot": STATE, "environment": "offline_transport_double",
                       "codePins": [{"address": target, "runtimeHash": keccak256(bytes.fromhex(CODE[2:]))}
                                    for target in (CORE, GOVERNANCE, SALE, SUPPORT)]}
        self.candidate = {"schema_version": "6529stream.canonical-deployment-candidate.v2",
            "network": {"chain_id": 31337}, "genesis_profile": {"sha256": "sha256:" + self.profile_sha,
                "schema_version": "6529stream.genesis-deployment-profile.v2", "entry_count": 37}, "instances": []}
        for number, key, name in [(1, "STREAM_CORE", "StreamCore"), (2, "GOVERNANCE_LAYER", "StreamGovernanceExecutor")]:
            row = self.evidence["artifacts"][name]
            self.candidate["instances"].append({"profile_entry_id": number, "profile_entry_key": key,
                "address": row["address"], "runtime": {"expected_keccak256": row["runtimeHash"]},
                "target": {"name": name, "source": row["source"], "artifact_sha256": "sha256:" + row["sha256"]}})

    def write(self, candidate=True):
        native_raw = dumps(self.native)
        self.evidence["nativeInputManifestSha256"] = sha(native_raw)
        evidence_raw = dumps(self.evidence)
        self.anchor["deploymentEvidenceHash"] = keccak256(evidence_raw)
        for name, raw in (("native", native_raw), ("evidence", evidence_raw), ("anchor", dumps(self.anchor)),
                          ("candidate", dumps(self.candidate))):
            (self.directory / (name + ".json")).write_bytes(raw)
        args = {"anchor_path": self.directory / "anchor.json", "anchor_sha256": sha(dumps(self.anchor)),
                "evidence_path": self.directory / "evidence.json", "native_path": self.directory / "native.json",
                "profile_path": self.profile_path, "profile_sha256": self.profile_sha}
        if candidate:
            args.update(candidate_path=self.directory / "candidate.json", candidate_sha256=sha(dumps(self.candidate)))
        return args

    def cli_args(self, args):
        mapping = {"anchor_path": "anchor", "anchor_sha256": "anchor-sha256", "evidence_path": "deployment-evidence",
                   "native_path": "native-manifest", "profile_path": "genesis-profile", "profile_sha256": "genesis-profile-sha256",
                   "candidate_path": "candidate", "candidate_sha256": "candidate-sha256"}
        return [part for key, value in args.items() for part in ("--" + mapping[key], str(value))]


class Double:
    def __init__(self):
        self.calls = []
        self.number_reads = 0
        self.chain = "0x7a69"
        self.reorg = False
        self.fail_method = None
        self.runtime = {}
        self.values = {"genesisInitialized()": (True,), "governanceActionPolicyState()": (STATE, BLOCK, 12, 1),
                       "paused()": (False,), "entropyPolicyInventory()": (0, 0, STATE),
                       "incompleteFinalityRecoveryRefreshPlanCount()": (0,), "recoveryExecutorBinding()": (SUPPORT, STATE)}
        self.bad_return = None
        self.logs = [{"address": GOVERNANCE, "blockHash": BLOCK, "blockNumber": "0x2a", "removed": False,
                      "transactionHash": "0x" + "cc" * 32, "transactionIndex": "0x1", "logIndex": "0x2",
                      "topics": [keccak256(EVENT.encode()), STATE], "data": "0x" + encode(("uint256",), (3,)).hex()}]
        self.extra_logs = {}

    def request(self, method, params):
        self.calls.append((method, params))
        if method == self.fail_method:
            raise RpcFailure("rpc_rejected")
        if method == "eth_chainId":
            return self.chain
        if method in ("eth_getBlockByNumber", "eth_getBlockByHash"):
            self.number_reads += method == "eth_getBlockByNumber"
            block = "0x" + "dd" * 32 if self.reorg and self.number_reads == 2 else BLOCK
            return {"hash": block, "number": "0x2a", "timestamp": "0x3039", "stateRoot": STATE}
        if method == "eth_getCode":
            assert params[1] == {"blockHash": BLOCK, "requireCanonical": True}
            return self.runtime.get(params[0], CODE)
        if method == "eth_call":
            assert params[1] == {"blockHash": BLOCK, "requireCanonical": True}
            if self.bad_return is not None:
                return self.bad_return
            signature = next(s for s in VIEWS if params[0]["data"] == keccak256(s.encode())[:10])
            return "0x" + encode(VIEWS[signature], self.values[signature]).hex()
        if method == "eth_getLogs":
            assert params[0]["blockHash"] == BLOCK
            return self.logs if params[0]["address"] == GOVERNANCE else self.extra_logs[params[0]["address"]]
        raise AssertionError("unexpected method " + method)


class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.fixture = Fixture(self.temp.name)

    def run_monitor(self, double=None, candidate=True):
        inputs = Inputs(**self.fixture.write(candidate))
        double = double or Double()
        report, transcript = Monitor(inputs, double).run()
        replay = Replay(transcript, sha(transcript))
        self.assertEqual((report, transcript), Monitor(inputs, replay).run())
        replay.finish()
        return loads(report, maximum=16777216), transcript, double

    def test_partial_capture_reports_all_roles_and_exact_replay(self):
        report, _, double = self.run_monitor()
        self.assertEqual(report["outcome"], "incomplete")
        self.assertTrue(report["coherentBlock"])
        self.assertEqual(len(report["roles"]), 37)
        self.assertEqual([r["id"] for r in report["roles"] if r["status"] == "observed"], [1, 2])
        self.assertEqual(report["products"][1]["events"]["events"][0]["signature"], EVENT)
        self.assertTrue(all(p["runtime"]["status"] == "matched" for p in report["products"]))
        self.assertFalse(report["limits"]["canonicalCandidateValidated"])
        self.assertEqual(len([c for c in double.calls if c[0] == "eth_call"]), 6)

    def test_no_candidate_never_infers_roles_from_native_names(self):
        report, _, _ = self.run_monitor(candidate=False)
        self.assertTrue(all(r["status"] == "unavailable" and not r["bindings"] for r in report["roles"]))

    def test_reorg_invalidates_common_block(self):
        double = Double()
        double.reorg = True
        report, _, _ = self.run_monitor(double)
        self.assertEqual(report["outcome"], "failure")
        self.assertFalse(report["coherentBlock"])
        self.assertIn("block_identity_mismatch", [i["code"] for i in report["incidents"]])

    def test_wrong_chain_skips_state_reads(self):
        double = Double()
        double.chain = "0x1"
        report, _, double = self.run_monitor(double)
        self.assertEqual(report["outcome"], "failure")
        self.assertFalse(any(m in ("eth_call", "eth_getCode", "eth_getLogs") for m, _ in double.calls))

    def test_runtime_mismatch_withholds_abi_reads_and_events(self):
        double = Double()
        double.runtime[GOVERNANCE] = "0x"
        report, _, double = self.run_monitor(double)
        self.assertEqual(report["products"][1]["runtime"]["status"], "mismatch")
        self.assertEqual(report["products"][1]["events"]["status"], "unavailable")
        self.assertFalse(any(m == "eth_call" and p[0]["to"] == GOVERNANCE for m, p in double.calls))

    def test_rpc_rejection_is_retained_and_replayed(self):
        double = Double()
        double.fail_method = "eth_call"
        report, transcript, _ = self.run_monitor(double)
        self.assertEqual(sum(i["code"] == "rpc_rejected" for i in report["incidents"]), 6)
        self.assertIn(b'"error":"rpc_rejected"', transcript)
        self.assertTrue(all(v["status"] == "unavailable" for p in report["products"] for v in p["views"]))

    def test_unavailable_chain_and_malformed_view_are_not_zero_defaults(self):
        double = Double()
        double.fail_method = "eth_chainId"
        report, _, _ = self.run_monitor(double)
        self.assertFalse(report["coherentBlock"])
        double = Double()
        double.bad_return = "0x"
        report, _, _ = self.run_monitor(double)
        self.assertEqual(sum(i["code"] == "invalid_view_response" for i in report["incidents"]), 6)
        self.assertFalse(any("values" in v for p in report["products"] for v in p["views"]))

    def test_pause_pending_recovery_and_uninitialized_genesis_require_review(self):
        double = Double()
        double.values.update({"paused()": (True,), "genesisInitialized()": (False,),
                              "incompleteFinalityRecoveryRefreshPlanCount()": (7,)})
        report, _, _ = self.run_monitor(double)
        self.assertEqual(report["outcome"], "attention")
        self.assertEqual(sum(i["level"] == "attention" for i in report["incidents"]), 3)
        self.assertTrue(any(i["level"] == "unavailable" for i in report["incidents"]))

    def test_event_wrong_block_removed_duplicate_and_wrong_topic_fail(self):
        for mutation in ("block", "removed", "duplicate", "topic", "address"):
            with self.subTest(mutation=mutation):
                double = Double()
                if mutation == "block":
                    double.logs[0]["blockHash"] = STATE
                elif mutation == "removed":
                    double.logs[0]["removed"] = True
                elif mutation == "duplicate":
                    double.logs.append(copy.deepcopy(double.logs[0]))
                elif mutation == "topic":
                    double.logs[0]["topics"][0] = STATE
                else:
                    double.logs[0]["address"] = CORE
                report, _, _ = self.run_monitor(double)
                self.assertEqual(report["outcome"], "failure")
                self.assertEqual(report["products"][1]["events"], {"status": "invalid", "events": []})

    def test_input_pins_and_actual_capture_binding_fail_closed(self):
        args = self.fixture.write()
        for key in ("anchor_sha256", "profile_sha256", "candidate_sha256"):
            with self.subTest(pin=key), self.assertRaises(MuseumError):
                Inputs(**(args | {key: "00" * 32}))
        self.fixture.evidence["artifacts"]["StreamCore"]["address"] = SUPPORT
        with self.assertRaises(MuseumError):
            Inputs(**self.fixture.write())

    def test_event_transaction_hash_index_and_order_consistency(self):
        for mutation in ("two_hashes_one_index", "one_hash_two_indices", "descending_indices"):
            with self.subTest(mutation=mutation):
                double = Double()
                second = copy.deepcopy(double.logs[0])
                second["logIndex"] = "0x3"
                if mutation == "two_hashes_one_index":
                    second["transactionHash"] = STATE
                elif mutation == "one_hash_two_indices":
                    second["transactionIndex"] = "0x2"
                else:
                    second.update(transactionHash=STATE, transactionIndex="0x0")
                double.logs.append(second)
                report, _, _ = self.run_monitor(double)
                self.assertEqual(report["outcome"], "failure")
                self.assertEqual(report["products"][1]["events"]["status"], "invalid")
                self.assertIn("event_transaction_identity_mismatch", [i["code"] for i in report["incidents"]])

    def test_event_transaction_consistency_across_monitored_products(self):
        artifact = self.fixture.artifacts["StreamNativeFixedPrice"]
        artifact["abi"].append(copy.deepcopy(self.fixture.artifacts["StreamGovernanceExecutor"]["abi"][-1]))
        native_row = self.fixture.native["products"]["StreamNativeFixedPrice"]
        Path(native_row["artifact"]).write_bytes(dumps(artifact))
        native_row["sha256"] = sha(dumps(artifact))
        self.fixture.evidence["artifacts"]["StreamNativeFixedPrice"]["sha256"] = native_row["sha256"]
        double = Double()
        second = copy.deepcopy(double.logs[0])
        second.update(address=SALE, logIndex="0x3", transactionHash=STATE)
        double.extra_logs[SALE] = [second]
        report, _, _ = self.run_monitor(double)
        self.assertEqual(report["outcome"], "failure")
        self.assertTrue(all(p["events"]["status"] == "invalid" for p in report["products"][1:]))

    def test_multiple_events_in_same_transaction_and_later_transaction_are_valid(self):
        double = Double()
        second = copy.deepcopy(double.logs[0])
        third = copy.deepcopy(double.logs[0])
        second["logIndex"] = "0x3"
        third.update(logIndex="0x4", transactionIndex="0x2", transactionHash=STATE)
        double.logs.extend([second, third])
        report, _, _ = self.run_monitor(double)
        self.assertEqual(report["products"][1]["events"]["status"], "observed")
        self.assertEqual(len(report["products"][1]["events"]["events"]), 3)

    def test_native_inventory_cannot_substitute_for_deployment_evidence(self):
        self.fixture.evidence["artifacts"] = {}
        with self.assertRaises(MuseumError):
            Inputs(**self.fixture.write())

    def test_artifact_tamper_is_rejected(self):
        args = self.fixture.write()
        path = Path(self.fixture.native["products"]["StreamCore"]["artifact"])
        path.write_bytes(path.read_bytes() + b" ")
        with self.assertRaises(MuseumError):
            Inputs(**args)

    def test_candidate_key_chain_runtime_and_duplicate_address_are_rejected(self):
        original = copy.deepcopy(self.fixture.candidate)
        for mutation in ("key", "chain", "runtime", "address"):
            with self.subTest(mutation=mutation):
                self.fixture.candidate = copy.deepcopy(original)
                row = self.fixture.candidate["instances"][0]
                if mutation == "key":
                    row["profile_entry_key"] = "GOVERNANCE_LAYER"
                elif mutation == "chain":
                    self.fixture.candidate["network"]["chain_id"] = 1
                elif mutation == "runtime":
                    row["runtime"]["expected_keccak256"] = STATE
                else:
                    self.fixture.candidate["instances"][1]["address"] = CORE
                with self.assertRaises(MuseumError):
                    Inputs(**self.fixture.write())

    def test_view_signature_requires_readonly_abi_output_and_compiler_selector(self):
        original = self.fixture.artifacts["StreamGovernanceExecutor"]
        for mutation in ("mutability", "output", "selector", "duplicate"):
            with self.subTest(mutation=mutation):
                artifact = copy.deepcopy(original)
                if mutation == "mutability":
                    artifact["abi"][0]["stateMutability"] = "nonpayable"
                elif mutation == "output":
                    artifact["abi"][0]["outputs"][0]["type"] = "uint256"
                elif mutation == "selector":
                    artifact["methodIdentifiers"] = {}
                else:
                    artifact["abi"].append(artifact["abi"][0])
                with self.assertRaises(MuseumError):
                    read_plan(artifact)

    def test_uint256_and_report_are_deterministic_without_float_loss(self):
        double = Double()
        double.values["entropyPolicyInventory()"] = (2 ** 255 + 17, 2 ** 64 - 1, STATE)
        report, _, _ = self.run_monitor(double)
        row = next(v for p in report["products"] for v in p["views"] if v["signature"] == "entropyPolicyInventory()")
        self.assertEqual(row["values"][:2], [str(2 ** 255 + 17), str(2 ** 64 - 1)])

    def test_replay_tamper_call_order_missing_and_trailing_calls_fail(self):
        inputs = Inputs(**self.fixture.write())
        _, transcript = Monitor(inputs, Double()).run()
        with self.assertRaises(MuseumError):
            Replay(transcript + b" ", sha(transcript))
        for mutation in ("order", "missing", "trailing"):
            value = loads(transcript, maximum=16777216)
            if mutation == "order":
                value["calls"][0], value["calls"][1] = value["calls"][1], value["calls"][0]
            elif mutation == "missing":
                value["calls"].pop()
            else:
                value["calls"].append(value["calls"][-1])
            raw = dumps(value)
            replay = Replay(raw, sha(raw))
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                Monitor(inputs, replay).run()
                replay.finish()

    def test_cli_replay_writes_report_and_refuses_output_overwrite(self):
        args = self.fixture.write()
        report, transcript = Monitor(Inputs(**args), Double()).run()
        path = self.fixture.directory / "transcript.json"
        path.write_bytes(transcript)
        output = self.fixture.directory / "result"
        argv = self.fixture.cli_args(args) + ["--replay", str(path), "--replay-sha256", sha(transcript), "--output", str(output)]
        with patch("sys.stdout", new=io.StringIO()), patch("sys.stderr", new=io.StringIO()):
            self.assertEqual(main(argv), 2)
            self.assertEqual(main(argv), 1)
        self.assertEqual(output.joinpath("report.json").read_bytes(), report)
        self.assertEqual(json.loads(output.joinpath("pins.json").read_bytes())["reportSha256"], sha(report))


class HttpTransportTests(unittest.TestCase):
    def response(self, value):
        body = io.BytesIO(dumps(value))
        context = unittest.mock.MagicMock()
        context.__enter__.return_value = body
        return context

    def test_rpc_error_message_is_redacted_from_failure_transcript(self):
        transport = HttpTransport("https://example.invalid/secret-key")
        opener = unittest.mock.Mock()
        opener.open.return_value = self.response({"jsonrpc": "2.0", "id": 1,
                                                 "error": {"message": "secret-key upstream failure", "code": -32000}})
        recorder = Recorder(transport)
        with patch("urllib.request.build_opener", return_value=opener), self.assertRaises(RpcFailure):
            recorder.request("eth_chainId", [])
        self.assertNotIn(b"secret", recorder.transcript())
        self.assertIn(b"rpc_rejected", recorder.transcript())

    def test_remote_plaintext_broadcast_and_expired_budget_are_refused(self):
        with self.assertRaises(MuseumError):
            HttpTransport("http://example.invalid")
        transport = HttpTransport("http://127.0.0.1:8545")
        with self.assertRaises(MuseumError):
            transport.request("eth_sendRawTransaction", ["0x"])
        transport._deadline = 0
        with self.assertRaisesRegex(RpcFailure, "budget_exhausted"):
            transport.request("eth_chainId", [])

    def test_malformed_http_headers_and_truncated_body_are_redacted_and_replayable(self):
        for stage in ("open", "read"):
            with self.subTest(stage=stage):
                transport = HttpTransport("https://example.invalid/secret-key")
                opener = unittest.mock.Mock()
                if stage == "open":
                    opener.open.side_effect = http.client.BadStatusLine("secret-key remote status")
                else:
                    context = unittest.mock.MagicMock()
                    context.__enter__.return_value.read.side_effect = http.client.IncompleteRead(b"secret-key partial body")
                    opener.open.return_value = context
                recorder = Recorder(transport)
                with patch("urllib.request.build_opener", return_value=opener), self.assertRaisesRegex(RpcFailure, "transport_failed"):
                    recorder.request("eth_chainId", [])
                raw = recorder.transcript()
                self.assertNotIn(b"secret", raw)
                replay = Replay(raw, sha(raw))
                with self.assertRaisesRegex(RpcFailure, "transport_failed"):
                    replay.request("eth_chainId", [])
                replay.finish()

    def test_mismatched_rpc_id_and_oversized_response_fail(self):
        for value in ({"jsonrpc": "2.0", "id": 2, "result": "0x1"},
                      {"jsonrpc": "2.0", "id": 1, "result": "x" * 1048576}):
            transport = HttpTransport("http://localhost:8545")
            opener = unittest.mock.Mock()
            opener.open.return_value = self.response(value)
            with patch("urllib.request.build_opener", return_value=opener), self.assertRaisesRegex(RpcFailure, "malformed_response"):
                transport.request("eth_chainId", [])

    def test_unrecognized_replay_failure_and_transcript_byte_bound_are_rejected(self):
        raw = dumps({"schema": "6529stream.monitor-transcript.v1", "calls": [
            {"method": "eth_chainId", "params": [], "error": {"untrusted": "text"}}]})
        with self.assertRaises(MuseumError):
            Replay(raw, sha(raw)).request("eth_chainId", [])
        recorder = Recorder(Double())
        with patch("tools.operations.transport.MAX_TRANSCRIPT", 1024), self.assertRaises(MuseumError):
            recorder.request("eth_chainId", [])


if __name__ == "__main__":
    unittest.main()
