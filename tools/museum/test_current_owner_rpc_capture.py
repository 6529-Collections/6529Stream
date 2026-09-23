"""Pure/transport-double bridge tests. No compiler, chain, mint or RPC acceptance."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .chain_abi import Array, encode
from .current_museum_capture import CurrentMuseumFixture
from .current_owner_rpc_capture import (CurrentOwnerRpcFixture, HOST, OWNER_MANIFEST,
    OWNER_PRODUCT_ROOTS, TRANSFER_EVENT, capture, document_input)
from .independent_wire import DOCUMENT_SPEC, RAW_BYTES, ZERO


def address(n):
    return "0x" + n.to_bytes(20, "big").hex()


class DocumentDouble(CurrentOwnerRpcFixture):
    def __init__(self, raw=b"a" * 8192 + b"b" * 8192 + b"c"):
        self.schemas, self.store = address(1), address(2)
        self.addresses = {"StreamGovernanceExecutor": address(3)}
        self.spec, self.chunks, self.parts = document_input("EXACT_DOCUMENT", 0, raw, RAW_BYTES)
        self.row = [True, 0, keccak256(encode((DOCUMENT_SPEC, Array("bytes32")),
            (self.spec, self.chunks))), self.spec, self.chunks]
        self.raw = raw
        self.chunk_bytes = dict(zip(self.chunks, self.parts))
        self.reads = []

    def call(self, name, method, values=()):
        assert name == "StreamSchemaRegistry"
        if method == "document":
            assert values == (schema_id(self.spec[0]),)
            return (self.row,)
        if method == "documentBytes":
            return (self.raw,)
        if method == "chunkStore":
            return (self.store,)
        if method == "governanceAuthority":
            return (self.addresses["StreamGovernanceExecutor"],)
        raise AssertionError(method)

    def read(self, target, signature, kinds, values, outputs):
        assert (target, signature, kinds, outputs) == (self.store, "readChunk(bytes32)", ("bytes32",), ("bytes",))
        self.reads.append(values[0])
        return (self.chunk_bytes[values[0]],)

    def register(self):
        return self.register_document(self.spec[0], self.spec[1], b"".join(self.parts), self.spec[3], self.spec[4])


class DocumentReuseTests(unittest.TestCase):
    def test_exact_active_reuse_does_not_publish_or_register_and_preserves_repeated_chunks(self):
        f = DocumentDouble(b"x" * 16384 + b"y")
        with patch.object(CurrentMuseumFixture, "register_document", side_effect=AssertionError("no mutation")):
            self.assertEqual(f.register(), schema_id("EXACT_DOCUMENT"))
        self.assertEqual(f.reads, list(f.chunks))
        self.assertEqual(f.chunks[0], f.chunks[1])

    def test_any_specification_change_is_refused_even_when_payload_bytes_match(self):
        for index, value in enumerate(("OTHER", 1, schema_id("other"), schema_id("canonical"),
                schema_id("prior"), "https://example.invalid/doc", 7)):
            with self.subTest(field=index):
                f = DocumentDouble()
                spec = list(f.spec); spec[index] = value
                f.row[3] = tuple(spec)
                # A self-consistent foreign declaration still cannot reuse this requested ID.
                f.row[2] = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (f.row[3], f.chunks)))
                with self.assertRaisesRegex(MuseumError, "conflicting or retired"):
                    f.register()

    def test_retirement_declaration_or_chunk_order_cannot_be_hidden_by_equal_document_bytes(self):
        for change in (lambda f: f.row.__setitem__(1, 1), lambda f: f.row.__setitem__(1, 2),
                lambda f: f.row.__setitem__(2, ZERO),
                lambda f: f.row.__setitem__(4, tuple(reversed(f.chunks)))):
            f = DocumentDouble(); change(f)
            with self.assertRaisesRegex(MuseumError, "conflicting or retired"):
                f.register()

    def test_corrupt_store_and_reconstructed_bytes_are_independently_refused(self):
        f = DocumentDouble(); f.chunk_bytes[f.chunks[0]] = b"corrupt"
        with self.assertRaisesRegex(MuseumError, "ordered chunk"):
            f.register()
        f = DocumentDouble(); f.raw = b"corrupt"
        with self.assertRaisesRegex(MuseumError, "document bytes"):
            f.register()

    def test_changed_graph_is_refused(self):
        for method in ("chunkStore", "governanceAuthority"):
            f = DocumentDouble(); original = f.call
            f.call = lambda name, fun, values=(): (address(99),) if fun == method else original(name, fun, values)
            with self.assertRaisesRegex(MuseumError, "graph differs"):
                f.register()

    def test_missing_definition_uses_original_registration_then_full_readback(self):
        f = DocumentDouble(); f.row[0] = False
        def admitted(instance, *args):
            self.assertIs(instance, f)
            self.assertEqual(args, (f.spec[0], 0, f.raw, RAW_BYTES, ZERO))
            f.row[0] = True
        with patch.object(CurrentMuseumFixture, "register_document", autospec=True, side_effect=admitted) as original:
            f.register()
        self.assertEqual(original.call_count, 1)
        self.assertEqual(f.reads, list(f.chunks))
        f.row[0] = False
        with patch.object(CurrentMuseumFixture, "register_document", autospec=True):
            with self.assertRaisesRegex(MuseumError, "admission absent"):
                f.register()

    def test_document_bounds_fail_without_rpc(self):
        for name, kind, raw in (("", 0, b"x"), ("a b", 0, b"x"), ("N", True, b"x"),
                ("N", 4, b"x"), ("N", 0, b""), ("N", 0, b"x" * 524289)):
            with self.assertRaises(MuseumError):
                document_input(name, kind, raw, RAW_BYTES)


class TransferDouble(CurrentOwnerRpcFixture):
    def __init__(self):
        self.addresses = {"StreamCore": address(1)}
        self.token_buyer, self.owner_safe = address(2), address(3)
        self.safe_accounts = {self.owner_safe: [address(4), address(5)]}
        self.token_id, self.current_owner = 1, self.token_buyer
        self.token_mint_evidence = {"owner": self.token_buyer}
        self.sent = []
        self.receipt = {"status": "0x1", "transactionHash": schema_id("real-receipt-double"), "logs": [{
            "address": address(1), "topics": [TRANSFER_EVENT,
                "0x" + encode(("address",), (self.token_buyer,)).hex(),
                "0x" + encode(("address",), (self.owner_safe,)).hex(),
                "0x" + encode(("uint256",), (1,)).hex()], "data": "0x"}]}

    def call(self, name, method, values):
        assert (name, values) == ("StreamCore", (1,))
        return (self.current_owner,) if method == "ownerOf" else (True, 1, 1, False)

    def data(self, name, method, values):
        assert (name, method, values) == ("StreamCore", "transferFrom(address,address,uint256)",
            (self.token_buyer, self.owner_safe, 1))
        return "0x12345678"

    def send(self, data, target=None, sender=None):
        self.sent.append((data, target, sender)); self.current_owner = self.owner_safe
        return self.receipt

    def rpc(self, method, values):
        assert (method, values) == ("eth_getTransactionByHash", [self.receipt["transactionHash"]])
        return {"hash": values[0], "from": self.token_buyer, "to": address(1), "input": "0x12345678"}


class OwnerCompositionTests(unittest.TestCase):
    def test_transfer_preserves_original_eoa_mint_evidence_and_records_actual_sender(self):
        f = TransferDouble(); f.transfer_token_to_owner_safe()
        self.assertEqual(f.sent, [("0x12345678", address(1), address(2))])
        self.assertEqual(f.owner_transfer["to"], address(3))
        self.assertEqual(f.owner_transfer["receipt"], f.receipt)
        self.assertEqual(f.token_mint_evidence, {"owner": address(2)})

    def test_transfer_requires_original_owner_and_exact_event_and_transaction(self):
        f = TransferDouble(); f.current_owner = address(99)
        with self.assertRaisesRegex(MuseumError, "no longer owns"):
            f.transfer_token_to_owner_safe()
        self.assertEqual(f.sent, [])
        for change in (lambda f: f.receipt.__setitem__("status", "0x0"),
                lambda f: f.receipt["logs"][0].__setitem__("address", address(99)),
                lambda f: f.receipt["logs"][0]["topics"].__setitem__(2, ZERO)):
            f = TransferDouble(); change(f)
            with self.assertRaisesRegex(MuseumError, "event differs"):
                f.transfer_token_to_owner_safe()
        f = TransferDouble(); original = f.rpc
        f.rpc = lambda method, values: original(method, values) | {"from": address(99)}
        with self.assertRaisesRegex(MuseumError, "transaction differs"):
            f.transfer_token_to_owner_safe()

    def test_graph_and_safe_ownership_finish_before_owner_construction(self):
        f = object.__new__(CurrentOwnerRpcFixture); steps = []
        f.rpc = Mock(return_value="0x7a69")
        for name in ("build_token_artist_graph", "select_token_modules", "complete_token_artist_graph",
                "deploy_token_sale_products", "configure_token_sale_products", "prepare_owner_commerce", "mint_token",
                "verify_owner_commerce",
                "transfer_token_to_owner_safe", "deploy_owner_records"):
            setattr(f, name, Mock(side_effect=lambda *args, name=name: steps.append(name)))
        f.safe = Mock(side_effect=lambda salt: steps.append("safe") or address(3))
        with patch.object(CurrentMuseumFixture, "foundation", side_effect=lambda: steps.append("foundation")):
            f.foundation()
        self.assertEqual(steps, ["foundation", "build_token_artist_graph", "select_token_modules",
            "complete_token_artist_graph", "deploy_token_sale_products", "select_token_modules",
            "configure_token_sale_products", "prepare_owner_commerce", "safe", "mint_token",
            "verify_owner_commerce", "transfer_token_to_owner_safe",
            "deploy_owner_records"])
        with self.assertRaisesRegex(MuseumError, "already attempted"):
            f.foundation()

    def test_owner_constructor_uses_current_dependencies_and_original_manifest_commitment(self):
        f = object.__new__(CurrentOwnerRpcFixture)
        f.addresses = {"StreamCore": address(1), "StreamGovernanceExecutor": address(2)}
        f.schemas, f.deployment = address(3), schema_id("deployment")
        f.deploy_library_closure, f.deploy, f.require_owner_bindings = Mock(), Mock(), Mock()
        f.deploy_owner_records()
        args = f.deploy.call_args.args
        self.assertEqual(args[0], HOST)
        config, = args[1]
        self.assertEqual(config[:4], (address(1), address(3), address(2), f.deployment))
        self.assertEqual(config[4], "ipfs://bafkreihrgxci5bintrod4j2fsvklcrs2pibs6h6detr2jgseg3f4emrdpq")
        self.assertEqual(config[5], keccak256(OWNER_MANIFEST))
        f.require_owner_bindings.assert_called_once_with()

    def test_failed_owner_publication_is_not_silently_retried(self):
        f = object.__new__(CurrentOwnerRpcFixture)
        f.require_owner_bindings = Mock(); f.token_id, f.owner_safe = 1, address(3)
        with patch("tools.museum.current_owner_rpc_capture.publish_owner_records", side_effect=MuseumError("refusal")):
            with self.assertRaisesRegex(MuseumError, "refusal"):
                f.after_media_publications()
        with self.assertRaisesRegex(MuseumError, "already attempted"):
            f.after_media_publications()

    def test_complete_owner_capture_follows_account_anchor_and_uses_same_process(self):
        f = object.__new__(CurrentOwnerRpcFixture); f.endpoint = "http://127.0.0.1:1"
        f.owner_publications = {"records": [{"recordHash": schema_id("r"), "tokenId": "1"}],
            "loans": [schema_id("loan")], "valuations": [schema_id("value")], "transactions": [schema_id("tx")]}
        order = []; account_hash = schema_id("account"); owner_anchor = b"owner-anchor-double"
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            def media(fixture, path):
                self.assertIs(fixture, f); order.append("media-anchor")
                path.joinpath("anchor.json").write_bytes(b"account-anchor-double")
                path.joinpath("deployment-evidence.json").write_bytes(b"deployment-double")
                return account_hash
            def anchor(fixture, account, evidence, records):
                self.assertIs(fixture, f); self.assertEqual(account, b"account-anchor-double")
                self.assertEqual(evidence, b"deployment-double"); self.assertEqual(records, f.owner_publications["records"])
                order.append("owner-anchor"); return owner_anchor
            def rpc_capture(package, digest, anchor_bytes, evidence, plan, **kwargs):
                self.assertEqual((package, digest), (output / "package", account_hash))
                self.assertEqual(anchor_bytes, owner_anchor)
                self.assertEqual(loads(plan), {"version": "1", **{k: f.owner_publications[k]
                    for k in ("loans", "valuations", "transactions")}})
                self.assertEqual(kwargs["transport"]._endpoint, f.endpoint)
                self.assertEqual(kwargs["plan_hash"], keccak256(plan))
                order.append("owner-rpc"); return "captured-double"
            def export(package, digest, captured, destination, **kwargs):
                self.assertEqual(captured, "captured-double"); self.assertEqual(destination, output / "owner-dossier")
                order.append("offline-export"); return {"valuationManifestHash": schema_id("valuation-package")}
            with patch("socket.socket", side_effect=AssertionError("no network")), \
                    patch("tools.museum.current_owner_rpc_capture.capture_media", side_effect=media), \
                    patch("tools.museum.current_owner_rpc_capture.make_owner_anchor", side_effect=anchor), \
                    patch("tools.museum.current_owner_rpc_capture.capture_owner_evidence", side_effect=rpc_capture), \
                    patch("tools.museum.current_owner_rpc_capture.export_owner_dossier", side_effect=export):
                self.assertEqual(capture(f, output), schema_id("valuation-package"))
            self.assertEqual(order, ["media-anchor", "owner-anchor", "owner-rpc", "offline-export"])
            pins = loads((output / "owner-input-pins.json").read_bytes())
            self.assertEqual(pins["anchorHash"], keccak256(owner_anchor))
            self.assertEqual(pins["deploymentEvidenceHash"], keccak256(b"deployment-double"))

    def test_opt_in_registry_runs_after_owner_export_and_preserves_return(self):
        f = object.__new__(CurrentOwnerRpcFixture); f.endpoint = "http://127.0.0.1:1"
        f.registry_bridge = (b"external-admission", schema_id("external"))
        f.owner_publications = {"records": [], "loans": [], "valuations": [], "transactions": []}
        order = []; account_hash = schema_id("account"); captured = object()
        def media(fixture, output):
            output.joinpath("anchor.json").write_bytes(b"account")
            output.joinpath("deployment-evidence.json").write_bytes(b"evidence")
            return account_hash
        def export(*args, **kwargs):
            order.append("owner-export")
            return {"valuationManifestHash": schema_id("valuation-package")}
        def registry(fixture, destination, digest, owner_capture):
            self.assertIs(fixture, f); self.assertEqual(destination, output)
            self.assertEqual(digest, account_hash); self.assertIs(owner_capture, captured)
            order.append("registry-capture")
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            with patch("socket.socket", side_effect=AssertionError("no network")), \
                    patch("tools.museum.current_owner_rpc_capture.capture_media", side_effect=media), \
                    patch("tools.museum.current_owner_rpc_capture.make_owner_anchor", return_value=b"owner"), \
                    patch("tools.museum.current_owner_rpc_capture.capture_owner_evidence", return_value=captured), \
                    patch("tools.museum.current_owner_rpc_capture.export_owner_dossier", side_effect=export), \
                    patch("tools.museum.current_owner_rpc_capture.registry_capture.capture_registry", side_effect=registry):
                self.assertEqual(capture(f, output), schema_id("valuation-package"))
            self.assertEqual(order, ["owner-export", "registry-capture"])

    def test_new_cli_reuses_one_existing_process_owner(self):
        from . import current_owner_rpc_capture as module
        with patch.object(module, "run_main") as run:
            module.main()
        run.assert_called_once_with(fixture_type=CurrentOwnerRpcFixture, capture_function=capture,
            configure_parser=module.configure_parser,
            prepare_arguments=module.registry_capture.prepare_arguments,
            configure_fixture=module.registry_capture.configure_fixture)


class NativeInputTests(unittest.TestCase):
    def fixture(self):
        f = object.__new__(CurrentOwnerRpcFixture)
        template = {"ast": {}, "bytecode": {"object": "00", "linkReferences": {}},
            "deployedBytecode": {"object": "00", "linkReferences": {}}}
        f.products = {name: copy.deepcopy(template) for name in OWNER_PRODUCT_ROOTS}
        f.manifest = {"graphImmutableProjection": {}, "products": {
            name: {"source": name + ".sol"} for name in OWNER_PRODUCT_ROOTS}}
        return f

    def test_missing_owner_or_link_target_fails_before_deployment(self):
        f = self.fixture(); del f.products[HOST]
        with self.assertRaisesRegex(MuseumError, "root products missing"):
            f.require_owner_products()
        f = self.fixture()
        f.products[HOST]["bytecode"]["linkReferences"] = {"missing.sol": {"Missing": [{"start": 0, "length": 20}]}}
        with self.assertRaisesRegex(MuseumError, "link source differs"):
            f.require_owner_products()

    def test_missing_ast_and_oversized_products_are_refused(self):
        f = self.fixture(); del f.products[HOST]["ast"]
        with self.assertRaisesRegex(MuseumError, "AST missing"):
            f.require_owner_products()
        for field, size in (("bytecode", 49153), ("deployedBytecode", 24577)):
            f = self.fixture(); f.products[HOST][field]["object"] = "00" * size
            with self.assertRaisesRegex(MuseumError, "original bound"):
                f.require_owner_products()

    def test_full_constructor_arguments_are_counted_at_send_boundary(self):
        f = object.__new__(CurrentOwnerRpcFixture)
        with patch.object(CurrentMuseumFixture, "send", side_effect=AssertionError("must not send")):
            with self.assertRaisesRegex(MuseumError, "full initcode"):
                f.send("0x" + "00" * 49153)


if __name__ == "__main__":
    unittest.main()
