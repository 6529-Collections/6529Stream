"""Hand-assembled Paris controls and literal original Registry ABI envelopes.

These are tool tests, not genuine deployed-renderer goldens or an admission.
No compiler, RPC or EVM is invoked.
"""
import copy
from contextlib import redirect_stderr, redirect_stdout
import io
import json
from pathlib import Path
import tempfile
import unittest

from Crypto.Hash import keccak

from tools.metadata import static_renderer_evidence as E

A = "0x" + "11" * 20
B = "0x" + "22" * 20
C = "0x" + "33" * 20
SELECTOR = bytes.fromhex("aabbccdd")


def w(n):
    return n.to_bytes(32, "big")


def h(raw):
    return keccak.new(digest_bits=256, data=raw).digest()


def push(n, width=None):
    width = width or max(1, (n.bit_length() + 7) // 8)
    return bytes([0x5F + width]) + n.to_bytes(width, "big")


def call(target=B, selector=SELECTOR, out_size=32, tail=b"\x50\x00"):
    # mstore(0, shl(224, selector)); staticcall(100000,target,0,4,64,out_size).
    return (push(int.from_bytes(selector, "big"), 4) + push(224) + b"\x1b" + push(0) + b"\x52"
            + push(out_size) + push(64) + push(4) + push(0) + push(int(target, 16), 20)
            + push(100000) + b"\xfa" + tail)


def read(target=B, selector=SELECTOR, maximum=32, exact=True):
    return {"target": target, "selector": "0x" + selector.hex(), "maxReturnBytes": maximum, "exact": exact}


def analyze(code, more=None, reads=None, **limits):
    return E.analyze({A: code, **(more or {})}, [{"address": A, "selector": "0x" + SELECTOR.hex(), "calldataBytes": 36}], reads or [], **limits)


class BytecodeAnalysisTests(unittest.TestCase):
    def test_stop_skips_dead_metadata_and_push_data(self):
        # TIMESTAMP/DELEGATECALL in a PUSH immediate and trailing bytes are not executable.
        result = analyze(bytes.fromhex("6142f4500042f4"))
        self.assertEqual(result["status"], "CLOSED")
        self.assertEqual(result["reachableInstructions"], 3)
        self.assertFalse(result["registrationApproved"])

    def test_reachable_environment_and_write_opcodes_refuse(self):
        for op in (0x31, 0x32, 0x3A, *range(0x40, 0x46), *range(0x47, 0x4B), 0x55,
                   0xA0, 0xA4, 0xF0, 0xF1, 0xF2, 0xF4, 0xF5, 0xFF):
            with self.subTest(op=op):
                self.assertEqual(analyze(bytes([op]))["status"], "REFUSED")

    def test_unknown_conditional_explores_both_branches(self):
        # calldataload(4) is an arbitrary argument; timestamp is on the taken side.
        code = bytes.fromhex("6004356009570000005b4200")
        result = analyze(code)
        self.assertEqual(result["status"], "REFUSED")
        self.assertEqual(result["issues"][0]["pc"], 10)

    def test_known_false_condition_does_not_take_jump(self):
        self.assertEqual(analyze(bytes.fromhex("60006008570000005b4200"))["status"], "CLOSED")

    def test_selector_dispatch_is_not_whole_runtime_scan(self):
        # Exact selector -> safe STOP; another selector -> TIMESTAMP.
        code = push(0) + b"\x35" + push(224) + b"\x1c" + push(int.from_bytes(SELECTOR, "big"), 4) + b"\x14"
        destination = len(code) + 5
        code += push(destination) + b"\x57\x42\x00\x5b\x00"
        self.assertEqual(analyze(code)["status"], "CLOSED")
        changed = bytearray(code); changed[9] ^= 1
        self.assertEqual(analyze(bytes(changed))["status"], "REFUSED")

    def test_unknown_jump_and_jump_into_push_data(self):
        self.assertEqual(analyze(bytes.fromhex("60043556"))["status"], "INCOMPLETE")
        # Destination1 is PUSH data, not JUMPDEST: exceptional halt cannot reach timestamp.
        self.assertEqual(analyze(bytes.fromhex("60015642"))["status"], "CLOSED")

    def test_transitive_three_runtime_closure_and_exact_pins(self):
        runtimes = {B: call(C), C: b"\x00"}
        result = analyze(call(), runtimes, [read(), read(C)])
        self.assertEqual(result["status"], "CLOSED")
        self.assertEqual({e["target"] for e in result["reads"]}, {B, C})
        self.assertEqual(result["contexts"], 3)
        self.assertEqual(result["runtimeHashes"][C], "0x" + h(b"\x00").hex())
        runtimes[C] = b"\x42\x00"
        self.assertEqual(analyze(call(), runtimes, [read(), read(C)])["status"], "REFUSED")

    def test_declared_selector_and_target_required_at_each_depth(self):
        for rows in ([read()], [read(), read(C, bytes.fromhex("01020304"))]):
            result = analyze(call(), {B: call(C), C: b"\0"}, rows)
            self.assertEqual(result["status"], "REFUSED")
            self.assertTrue(any("undeclared read" in x["reason"] for x in result["issues"]))

    def test_dynamic_target_and_selector_refuse_closure(self):
        fixed = call()
        prefix = push(int(B, 16), 20)
        dynamic = fixed.replace(prefix, push(4) + b"\x35")
        self.assertEqual(analyze(dynamic, {B: b"\0"}, [read()])["status"], "INCOMPLETE")
        # Unknown calldata argument becomes the input selector via MSTORE.
        dynamic = push(4) + b"\x35" + push(0) + b"\x52" + fixed[11:]
        self.assertEqual(analyze(dynamic, {B: b"\0"}, [read()])["status"], "INCOMPLETE")

    def test_call_output_copy_and_later_copy_share_bound(self):
        result = analyze(call(out_size=33), {B: b"\0"}, [read()])
        self.assertEqual(result["status"], "INCOMPLETE")
        extra = b"\x50" + push(1) + push(0) + push(0) + b"\x3e\x00"
        self.assertEqual(analyze(call(tail=extra), {B: b"\0"}, [read()])["status"], "INCOMPLETE")
        exact = b"\x50" + push(32) + push(0) + push(0) + b"\x3e\x00"
        self.assertEqual(analyze(call(out_size=0, tail=exact), {B: b"\0"}, [read()])["status"], "CLOSED")

    def test_unknown_returndata_size_is_not_assumed_to_obey_declaration(self):
        tail = b"\x50\x3d" + push(0) + push(0) + b"\x3e\x00"
        result = analyze(call(out_size=0, tail=tail), {B: b"\0"}, [read()])
        self.assertEqual(result["status"], "INCOMPLETE")
        self.assertTrue(any("unresolved returndata" in x["reason"] for x in result["issues"]))

    def test_callee_return_and_success_are_unknown_not_executed(self):
        # The child always STOPs, but the checker must also consider either call status.
        prefix = call(out_size=0, tail=b"")
        destination = len(prefix) + 4
        code = prefix + push(destination) + b"\x57\x00\x5b\x42\x00"
        self.assertEqual(analyze(code, {B: b"\0"}, [read()])["status"], "REFUSED")

    def test_storage_is_unknown_even_when_slot_constant(self):
        self.assertEqual(analyze(bytes.fromhex("60005456"))["status"], "INCOMPLETE")

    def test_gas_requires_precheck_proof_not_an_exception_flag(self):
        result = analyze(b"\x5a\x50\x00")
        self.assertEqual(result["status"], "INCOMPLETE")
        self.assertIn("precheck", result["issues"][0]["reason"])

    def test_unknown_or_future_opcode_and_resource_limits_refuse(self):
        self.assertEqual(analyze(b"\x5f\x00")["status"], "INCOMPLETE")
        self.assertEqual(analyze(b"\x60\x01\x50\x00", max_states=1)["status"], "INCOMPLETE")
        self.assertEqual(analyze(call(), {B: b"\0"}, [read()], max_contexts=1)["status"], "INCOMPLETE")
        self.assertEqual(analyze(call(), {B: b"\0"}, [read()], memory_limit=36)["status"], "INCOMPLETE")
        self.assertEqual(analyze(push(E.MASK) + push(0) + b"\x52\x00", max_memory_cells=1)["status"], "INCOMPLETE")

    def test_partial_known_bits_never_choose_one_unknown_branch(self):
        value = E._number((0xAA,) + (None,) * 31)
        self.assertEqual(E._arithmetic(0x1C, [248, value]), 0xAA)
        self.assertIsNone(E._constant(E._arithmetic(0x16, [255, value])))
        self.assertEqual(E._arithmetic(0x17, [E.MASK, value]), E.MASK)
        self.assertEqual(E._arithmetic(0x16, [0, value]), 0)
        # A partial value with only known zero bits could be either zero or nonzero.
        code = push(4) + b"\x35" + push(255) + b"\x16"
        code += push(len(code) + 4) + b"\x57\x00\x5b\x42\x00"
        self.assertEqual(analyze(code)["status"], "REFUSED")

    def test_partial_bit_results_cover_concrete_completions(self):
        # Independent concrete bit operations: abstract known bits must agree
        # with every sampled completion, including unknown sign/low bits.
        for known in (0, 255, E.MASK ^ 255, 1 << 255, E.MASK):
            for base in (0, 0xAA, E.MASK):
                abstract = E._partial(base, known)
                for completion in (0, 1, 0x5555, E.MASK):
                    concrete = (base & known) | (completion & (E.MASK ^ known))
                    for op, other, expected in ((0x16, 255, concrete & 255),
                                               (0x17, 255, concrete | 255),
                                               (0x18, E.MASK, concrete ^ E.MASK)):
                        value, mask = E._bits(E._arithmetic(op, [abstract, other]))
                        self.assertEqual(value & mask, expected & mask)
                    for shift in (0, 1, 224, 255, 256):
                        for op, expected in ((0x1B, (concrete << shift) & E.MASK),
                                             (0x1C, concrete >> shift)):
                            value, mask = E._bits(E._arithmetic(op, [shift, abstract]))
                            self.assertEqual(value & mask, expected & mask)

    def test_large_memory_and_copy_sizes_refuse_before_allocating(self):
        self.assertEqual(analyze(push(E.MASK) + b"\x51")["status"], "INCOMPLETE")
        tail = b"\x50" + push(E.MASK) + push(0) + push(0) + b"\x3e\x00"
        self.assertEqual(analyze(call(out_size=0, tail=tail), {B: b"\0"}, [read()])["status"], "INCOMPLETE")

    def test_recursive_call_context_reaches_fixed_point(self):
        result = analyze(call(A), reads=[read(A)])
        self.assertEqual(result["status"], "CLOSED")
        self.assertEqual(result["contexts"], 2)  # unknown root caller, then self caller.

    def test_known_arithmetic_and_memory_byte_order(self):
        table = [(0x03, [3, 5], -2), (0x04, [9, 2], 4), (0x05, [E.MASK - 8, 2], -4),
                 (0x07, [E.MASK - 8, 2], -1), (0x08, [E.MASK, 1, 3], 1),
                 (0x0A, [2, 256], 0), (0x0B, [0, 128], E.MASK - 127),
                 (0x10, [3, 5], 1), (0x12, [E.MASK, 0], 1),
                 (0x1A, [31, 0x1234], 0x34), (0x1B, [256, 1], 0),
                 (0x1C, [8, 0x1234], 0x12), (0x1D, [256, E.MASK], -1)]
        for op, values, expected in table:
            self.assertEqual(E._arithmetic(op, values) & E.MASK, expected & E.MASK)
        # MSTORE8 affects the high byte consumed by MLOAD/SHR; compare to a literal selector.
        code = push(0xAA) + push(0) + b"\x53" + push(0) + b"\x51" + push(248) + b"\x1c"
        code += push(0xAA) + b"\x14" + push(len(code) + 9) + b"\x57\x42\x00\x5b\x00"
        self.assertEqual(analyze(code)["status"], "CLOSED")


def packet():
    # Original ABI: target[] offset, length, (address, runtimeHash, role).
    role = h(b"CORE")
    targets_raw = w(32) + w(1) + w(int(B, 16)) + h(b"\0") + role
    target_hash = h(targets_raw)
    # abi.encode(domain, targetSetHash, Read[]) with one four-word element.
    set_hash = h(h(b"6529STREAM_RENDERER_READ_SET_V1") + target_hash + w(96)
                 + w(1) + w(0) + SELECTOR + bytes(28) + w(32) + w(1))
    versions = [h(b"renderer-version"), h(b"context-version"), h(b"schema")]
    code = call()
    analysis = (h(b"6529STREAM_STATIC_RENDERER_ANALYSIS_ABI_V1") + w(int(A, 16)) + h(code)
                + set_hash + b"".join(versions) + h(b"external-tool") + h(b"external-findings") + w(1))
    # Independent 12-word request. TokenId deliberately retains the full 256-bit width.
    request = w(int(B, 16)) + w(2**255 + 3) + w(1) + w(2) + h(b"seed") + w(1) + w(1) + w(2) + w(3) + h(b"view") + h(b"manifest") + h(b"snapshot")
    output = b"data:application/json;base64,e30="
    golden = w(32) + w(1) + request + h(output)
    calldata = h(b"tokenURI((address,uint256,uint256,uint256,bytes32,uint8,uint8,uint8,uint8,bytes32,bytes32,bytes32))")[:4] + request
    returned = w(32) + w(len(output)) + output + bytes((-len(output)) % 32)
    return {"version": 1, "renderer": A, "rendererRuntime": "0x" + code.hex(),
            "rendererVersion": "0x" + versions[0].hex(), "contextVersion": "0x" + versions[1].hex(),
            "schemaHash": "0x" + versions[2].hex(), "maxJSONBytes": 64,
            "targets": [{"address": B, "runtime": "0x00", "role": "0x" + role.hex()}],
            "reads": [{"targetIndex": 0, "selector": "0x" + SELECTOR.hex(), "maxReturnBytes": 32, "exact": True}],
            "analysisPayload": "0x" + analysis.hex(), "goldenPayload": "0x" + golden.hex(),
            "recomputations": [{"label": "supplied-run-1", "stateHash": "0x" + h(b"declared-state").hex(),
                                "results": [{"calldata": "0x" + calldata.hex(), "returnData": "0x" + returned.hex()}]}]}


class GoldenEvidenceTests(unittest.TestCase):
    def test_original_static_abi_and_recomputation_join_without_admission_claim(self):
        result = E.check_packet(packet())
        self.assertEqual(result["analysis"]["status"], "CLOSED")
        self.assertTrue(result["golden"]["allBytesMatch"])
        for key in ("admissionReady", "registeredAnalysisClaimVerified", "routerPathsAnalyzed"):
            self.assertFalse(result[key])
        self.assertFalse(result["golden"]["executionVerified"])

    def test_keccak_is_ethereum_not_sha3(self):
        self.assertEqual(E.digest(b"").hex(), "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")

    def test_analysis_exact_runtime_roster_cap_and_all_binding_words(self):
        for field in ("rendererVersion", "contextVersion", "schemaHash"):
            p = packet(); p[field] = "0x" + h(field.encode()).hex()
            with self.assertRaises(E.EvidenceError): E.check_packet(p)
        for offset in range(0, 320, 32):
            p = packet(); data = bytearray.fromhex(p["analysisPayload"][2:])
            if offset in (224, 256): data[offset:offset + 32] = bytes(32)
            else: data[offset] ^= 1
            p["analysisPayload"] = "0x" + data.hex()
            with self.assertRaises(E.EvidenceError): E.check_packet(p)
        for change in (lambda p: p.update(rendererRuntime="0x0000"),
                       lambda p: p["targets"][0].update(runtime="0x0000"),
                       lambda p: p["reads"][0].update(maxReturnBytes=64)):
            p = packet(); change(p)
            with self.assertRaises(E.EvidenceError): E.check_packet(p)

    def test_canonical_golden_offsets_lengths_padding_enums_and_no_tail(self):
        p = packet(); raw = bytes.fromhex(p["goldenPayload"][2:])
        invalid = [w(64) + raw[32:], raw + bytes(32), raw[:-1], w(32) + w(0), w(32) + w(17)]
        for field, bad in ((0, 1 << 160), (5, 4), (6, 3), (7, 256), (8, 256)):
            item = bytearray(raw); item[64 + field * 32:96 + field * 32] = w(bad); invalid.append(bytes(item))
        invalid.append(raw[:-32] + bytes(32))
        for item in invalid:
            with self.assertRaises(E.EvidenceError): E.golden_vectors(item)
        self.assertEqual(len(E.golden_vectors(raw)[0][0]), 388)

    def test_vector_count_sixteen_and_all_outputs_recomputed(self):
        p = packet(); raw = bytes.fromhex(p["goldenPayload"][2:]); row = raw[64:]
        p["goldenPayload"] = "0x" + (w(32) + w(16) + row * 16).hex()
        p["recomputations"][0]["results"] *= 16
        self.assertEqual(E.check_packet(p)["golden"]["vectors"], 16)
        p["recomputations"][0]["results"].pop()
        with self.assertRaises(E.EvidenceError): E.check_packet(p)

    def test_repeated_runs_do_not_change_expected_golden_or_omit_vectors(self):
        p = packet(); second = copy.deepcopy(p["recomputations"][0]); second["label"] = "supplied-run-2"
        p["recomputations"].append(second)
        self.assertEqual(E.check_packet(p)["golden"]["suppliedRecomputations"], 2)
        raw = bytearray.fromhex(second["results"][0]["returnData"][2:]); raw[64] ^= 1
        second["results"][0]["returnData"] = "0x" + raw.hex()
        with self.assertRaisesRegex(E.EvidenceError, "drift"): E.check_packet(p)

    def test_missing_run_reordered_request_and_noncanonical_string(self):
        p = packet(); p["recomputations"] = []
        with self.assertRaises(E.EvidenceError): E.check_packet(p)
        p = packet(); result = p["recomputations"][0]["results"][0]
        result["calldata"] = result["calldata"][:-2] + "ff"
        with self.assertRaises(E.EvidenceError): E.check_packet(p)
        for raw in (w(64) + w(1) + b"x" + bytes(31), w(32) + w(1) + b"x" + bytes(30) + b"x",
                    w(32) + w(33) + bytes(32), w(32) + w(0) + bytes(32)):
            with self.assertRaises(E.EvidenceError): E.string_result(raw, 64)
        with self.assertRaises(E.EvidenceError): E.string_result(w(32) + w(2) + b"xx" + bytes(30), 1)

    def test_hostile_json_types_duplicates_and_unlinked_runtime_refuse(self):
        for mutate in (lambda p: p.update(version=True), lambda p: p.update(maxJSONBytes=True),
                       lambda p: p.update(passed=True), lambda p: p["reads"][0].update(exact=1),
                       lambda p: p.update(rendererRuntime="0x__$unlinked$__")):
            p = packet(); mutate(p)
            with self.assertRaises(E.EvidenceError): E.check_packet(p)
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "p.json"
            for raw in ('{"version":1,"version":1}', '{"version":NaN}'):
                f.write_text(raw, encoding="utf-8")
                with self.assertRaises(E.EvidenceError): E.load_packet(f)

    def test_claimed_passed_analysis_does_not_hide_unresolved_program(self):
        p = packet(); p["rendererRuntime"] = "0x5a00"
        raw = bytearray.fromhex(p["analysisPayload"][2:]); raw[64:96] = h(bytes.fromhex("5a00"))
        p["analysisPayload"] = "0x" + raw.hex()
        result = E.check_packet(p)
        self.assertEqual(result["analysis"]["status"], "INCOMPLETE")
        self.assertFalse(result["registeredAnalysisClaimVerified"])

    def test_cli_status_and_claim_boundaries(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "packet.json"
            p = packet()
            for expected in (0, 2, 1):
                if expected == 2:
                    p["rendererRuntime"] = "0x5a00"
                    raw = bytearray.fromhex(p["analysisPayload"][2:]); raw[64:96] = h(bytes.fromhex("5a00"))
                    p["analysisPayload"] = "0x" + raw.hex()
                if expected == 1: p["version"] = True
                path.write_text(json.dumps(p), encoding="utf-8")
                out, err = io.StringIO(), io.StringIO()
                with redirect_stdout(out), redirect_stderr(err):
                    self.assertEqual(E.main([str(path)]), expected)
                if expected != 1:
                    self.assertFalse(json.loads(out.getvalue())["admissionReady"])
                else:
                    self.assertIn("refused", err.getvalue())

    def test_standalone_cli_does_not_require_an_external_passed_claim(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "analysis.json"
            p = {"runtimes": {A: "0x" + call().hex(), B: "0x00"},
                 "entries": [{"address": A, "selector": "0x" + SELECTOR.hex(), "calldataBytes": 36}],
                 "reads": [read()]}
            path.write_text(json.dumps(p), encoding="utf-8")
            out = io.StringIO()
            with redirect_stdout(out):
                self.assertEqual(E.main(["--analyze-only", str(path)]), 0)
            result = json.loads(out.getvalue())
            self.assertEqual(result["status"], "CLOSED")
            self.assertFalse(result["admissionReady"])


if __name__ == "__main__":
    unittest.main()
