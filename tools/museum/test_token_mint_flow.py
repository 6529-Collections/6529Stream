"""Offline controls for the staged token flow; no RPC or native execution."""
import hashlib
import copy
import unittest

from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO
from .current_media_inputs import image_bytes, media_description
from .token_mint_flow import (ARTIST_ADMIN, COLLECTION_ID, PHASE_ID, TOKEN_DATA,
    TOKEN_GRAPH_DECLARATIONS, TOKEN_GRAPH_PRODUCTS,
    TOKEN_INTERFACE_PRODUCTS, TOKEN_MODULE_ROWS, TOKEN_PRODUCT_ROOTS, TOKEN_SALE_PRODUCTS,
    PRICE, SALE_EVENT, ENTROPY_ADMIN, ENTROPY_REVEAL_OWNER, TokenMintFlowMixin, interface_enum_value)


class FakeFlow(TokenMintFlowMixin):
    def __init__(self):
        self.account = "0x" + "01" * 20
        self.addresses = {"StreamRoleRegistry": "0x" + "02" * 20,
            "StreamMintManager": "0x" + "03" * 20}
        self.token_suite = tuple(range(11))
        self.calls = []

    def rpc(self, method, params):
        if method == "eth_chainId": return "0x7a69"
        if method == "eth_getBlockByNumber": return {"timestamp": "0x64"}
        raise AssertionError(method)

    def call(self, name, function, values=()):
        self.calls.append((name, function, values))
        if function == "roleMutationState": return "0x" + "11" * 32, 4
        if function == "globalRoleMutationState": return "0x" + "12" * 32, 8
        if function == "gasParameterInfo": return 150000, 150000, 2, 1
        raise AssertionError(function)


class FakeMintFlow(TokenMintFlowMixin):
    def __init__(self):
        self.token_suite = tuple(range(11))
        self.addresses = {"StreamFixedPriceSaleAdapter": "0x" + "10" * 20,
            "StreamCore": "0x" + "20" * 20,
            "StreamEntropyCoordinator": "0x" + "21" * 20}
        self.token_buyer = "0x" + "30" * 20
        self.token_artist_safe = "0x" + "40" * 20
        self.token_platform_safe = "0x" + "50" * 20
        self.profile = "0x" + "61" * 32
        self.policy = "0x" + "62" * 32
        self.mint_policy = "0x" + "63" * 32
        self.digest = "0x" + "64" * 32
        self.wallet = "0x" + "70" * 20

    def _now(self): return 100
    def _safe_proof(self, safe, digest): return (safe + digest).encode()
    def data(self, name, function, values): return "0x1234"
    def _send_value(self, target, data, sender, value):
        event_data = "0x" + encode(("bytes32", "bytes32", "address", "uint256"),
            (self.digest, self.profile, self.wallet, PRICE)).hex()
        return "0x" + "81" * 32, {"status": "0x1", "logs": [{
            "address": self.addresses["StreamFixedPriceSaleAdapter"],
            "topics": [SALE_EVENT, "0x" + "82" * 32, "0x" + "83" * 32, hex(7)],
            "data": event_data}]}
    def rpc(self, method, params):
        if method == "eth_getTransactionByHash": return {"hash": params[0], "input": "0x1234"}
        raise AssertionError(method)
    def call(self, name, function, values=()):
        results = {
            "primaryPolicy": (self.policy, self.profile, self.wallet),
            "phasePolicyHash": (self.mint_policy,), "signerEpoch": (3,),
            "authorizationDigest": (self.digest,), "ownerOf": (self.token_buyer,),
            "tokenCollectionIdentity": (True, COLLECTION_ID, 1, False),
            "tokenLifecycle": (2,),
            "coordinatorAtMint": (self.addresses["StreamEntropyCoordinator"],),
            "tokenData": (TOKEN_DATA,), "collectionMintedEver": (1,), "totalSupply": (1,),
            "isOperationRootUsed": (True,), "authorizationUsed": (True,),
        }
        return results[function]


class FakeConfigurationFlow(TokenMintFlowMixin):
    def __init__(self):
        names = ("DevelopmentEntropyProvider", "StreamFixedPriceSaleAdapter",
            "StreamEntropyCoordinator", "StreamMetadataRouter", "StreamRoyaltyResolver",
            "StreamRevenueResolver", "StreamRevenueEscrow")
        self.addresses = {name: "0x" + bytes([index + 1]).hex() * 20
            for index, name in enumerate(names)}
        self.token_suite = tuple(range(11)); self.account = "0x" + "aa" * 20
        self.token_split_profile = "0x" + "bb" * 32; self.governed = []
        self.runtime = b"\x60\x00"
        self.provider_config = "0x" + "cc" * 32

    def rpc(self, method, params):
        if method == "eth_getCode": return "0x" + self.runtime.hex()
        raise AssertionError(method)

    def govern_configuration(self, name, function, values, transition=None, **kwargs):
        self.governed.append((name, function, values, transition, kwargs))

    def call(self, name, function, values=()):
        if function == "coordinator": return self.addresses["StreamEntropyCoordinator"],
        if function == "controller": return self.account,
        if function == "isStreamEntropyProvider": return True,
        if function == "collectionEntropyConfig":
            return (self.addresses["DevelopmentEntropyProvider"], True, False, 100,
                self.provider_config, keccak256(self.runtime), schema_id("collection salt"))
        if function == "streamEntropyProviderFamily": return "0x" + "dd" * 32,
        if function == "streamEntropyProviderVersion": return "0x" + "ee" * 32,
        if function == "streamEntropyProviderConfigHash": return self.provider_config,
        if function == "creditProducerTransitionHashes":
            return ("0x" + "11" * 32, "0x" + "12" * 32, "0x" + "13" * 32)
        raise AssertionError((name, function))


class FakePreviewFlow(TokenMintFlowMixin):
    def __init__(self):
        self.account = "0x" + "91" * 20
        self.addresses = {"StreamArtistOnboardingRegistry": "0x" + "92" * 20}
        self.token_suite = tuple(range(11)); self.params = None

    def data(self, name, function, values):
        self.encoded = (name, function, values)
        return "0x1234"

    def rpc(self, method, params):
        self.params = (method, params)
        return "0x" + encode(("bytes32", "bytes32"),
            ("0x" + "93" * 32, "0x" + "94" * 32)).hex()


class FakeSafeProofFlow(TokenMintFlowMixin):
    def __init__(self):
        self.account = "0x" + "a0" * 20
        self.safe = "0x" + "a1" * 20
        self.owners = ["0x" + "a3" * 20, "0x" + "a2" * 20]
        self.safe_accounts = {self.safe: self.owners}
        self.domain = "0x" + "a4" * 32
        self.message_hash = "0xce74efc78cd170fb16846f0be81d196be04330da50c2f081d090f9b9294090b9"
        self.magic = "0x1626ba7e"
        self.reads = []; self.invocations = []; self.preflights = []

    def read(self, target, signature, kinds, values, outputs):
        self.reads.append((target, signature, kinds, values, outputs))
        if signature == "domainSeparator()": return self.domain,
        if signature == "getMessageHash(bytes)": return self.message_hash,
        return 1,

    def invoke(self, target, signature, kinds, values, *, sender):
        self.invocations.append((target, signature, kinds, values, sender))

    def rpc(self, method, params):
        self.preflights.append((method, params))
        return "0x" + encode(("bytes4",), (self.magic,)).hex()


def interface_enums(interface, enums):
    return {"ast": {"nodes": [{"nodeType": "ContractDefinition", "contractKind": "interface", "name": interface,
        "nodes": [{"nodeType": "EnumDefinition", "name": enum_name,
            "members": [{"nodeType": "EnumValue", "name": member} for member in members]}
            for enum_name, members in enums.items()]}]}}


class FakePhaseFlow(TokenMintFlowMixin):
    def __init__(self):
        self.products = {
            "IStreamMintManager": interface_enums("IStreamMintManager", {
                "CounterKeyMode": ["UNKNOWN", "CONSTANT", "PAYER", "RECIPIENT", "EXECUTOR", "AUTHORIZER", "CONTEXT"]}),
            "IStreamMintLedger": interface_enums("IStreamMintLedger", {
                "CounterCapMode": ["NONE", "STATIC", "RESOLVER"], "CounterDeltaMode": ["STATIC", "RESOLVER"]}),
        }
        self.token_suite = tuple(range(11))
        self.addresses = {"StreamFixedPriceSaleAdapter": "0x" + "71" * 20}
        self.initial, self.final = "0x" + "72" * 32, "0x" + "73" * 32
        self.actions = []

    def call(self, name, function, values=()):
        self.actions.append((function, values))
        if function == "phasePolicyHash": return self.final,
        if function == "previewPhasePolicyHash": return (self.final if values[-1] else self.initial),
        raise AssertionError(function)

    def transact(self, name, function, values=()):
        self.actions.append((function, values))

    def _record_policy_consent(self, policy):
        self.actions.append(("consent", policy))


class FakeRevealPolicyFlow(FakeFlow):
    def __init__(self):
        super().__init__()
        self.addresses["StreamEntropyCoordinator"] = "0x" + "c1" * 20
        self.governor = "0x" + "c2" * 20
        self.safe_accounts = {self.governor: ["0x" + "c3" * 20, "0x" + "c4" * 20]}
        self.granted = set(); self.governed = []; self.safe_calls = []
        self.runtime = "0x6000"; self.policy = None; self.policy_override = None
        self.token_entropy_evidence = {"secureRandomnessClaimed": False}
        self.transaction_hash = "0x" + "c5" * 32

    def rpc(self, method, params):
        if method == "eth_getCode": return self.runtime
        return super().rpc(method, params)

    def call(self, name, function, values=()):
        if function == "hasRole": return ((values[0], values[1]) in self.granted),
        if function == "roleHolderCount": return sum(role == values[0] for role, _ in self.granted),
        if function == "resolveRole": return self.governor,
        if function == "collectionRevealPolicy": return (self.policy_override or self.policy),
        return super().call(name, function, values)

    def govern_configuration(self, name, function, values, transition):
        self.governed.append((name, function, values, transition))
        self.granted.add(values)

    def transact(self, name, function, values, *, safe):
        self.safe_calls.append((name, function, values, safe))
        self.policy = (True, *values[1:])
        return {"transactionHash": self.transaction_hash}


class TokenMintFlowPreparation(unittest.TestCase):
    def test_explicit_product_roots_include_sale_graph_and_interface_inputs(self):
        self.assertEqual(len(TOKEN_PRODUCT_ROOTS), len(set(TOKEN_PRODUCT_ROOTS)))
        self.assertTrue(set(TOKEN_SALE_PRODUCTS) <= set(TOKEN_PRODUCT_ROOTS))
        self.assertTrue(set(TOKEN_GRAPH_PRODUCTS) <= set(TOKEN_PRODUCT_ROOTS))
        self.assertTrue(set(TOKEN_GRAPH_DECLARATIONS) <= set(TOKEN_PRODUCT_ROOTS))
        self.assertTrue(set(TOKEN_INTERFACE_PRODUCTS) <= set(TOKEN_PRODUCT_ROOTS))
        self.assertIn("StreamArtistOnboardingCoordinator", TOKEN_PRODUCT_ROOTS)
        self.assertNotIn("MockStreamEntropyProvider", TOKEN_PRODUCT_ROOTS)

    def test_module_rows_are_explicit_and_do_not_claim_sale_is_a_core_pointer(self):
        products = {row[0] for row in TOKEN_MODULE_ROWS}
        self.assertEqual(len(products), len(TOKEN_MODULE_ROWS))
        self.assertIn("StreamMintManager", products)
        self.assertIn("StreamArtworkFinalityRegistry", products)
        self.assertNotIn("StreamArtistOnboardingRegistry", products)
        self.assertNotIn("StreamMetadataRouter", products)
        self.assertNotIn("StreamCollectionMetadataV1", products)
        self.assertNotIn("StreamFixedPriceSaleAdapter", products)
        self.assertTrue(all(row[2].startswith("IStream") for row in TOKEN_MODULE_ROWS))
        royalty = next(row for row in TOKEN_MODULE_ROWS if row[0] == "StreamRoyaltyResolver")
        self.assertEqual(royalty[3], "ROYALTY_RESOLVER")

    def test_exact_recipe_constants_are_version_bound(self):
        self.assertEqual(COLLECTION_ID, 1)
        self.assertEqual(PHASE_ID, schema_id("current-stack fixed price"))
        self.assertEqual(ARTIST_ADMIN, schema_id("ROLE_ARTIST_REGISTRY_ADMIN"))
        self.assertEqual(TOKEN_DATA, image_bytes())

    def test_authorization_nonce_and_time_modes_are_monotonic(self):
        flow = FakeFlow()
        self.assertEqual(flow._authorization(False), (0, 86500, b""))
        self.assertEqual(flow._authorization(True), (1, 100, b""))
        self.assertEqual(flow.token_artist_authorization_nonce, 2)

    def test_role_transition_uses_observed_role_and_global_chains(self):
        flow = FakeFlow()
        transition = flow._role_transition(ARTIST_ADMIN, flow.account)
        self.assertEqual(len(transition), 3)
        self.assertTrue(all(value.startswith("0x") and len(value) == 66 for value in transition))
        self.assertNotEqual(transition[1], transition[2])
        self.assertEqual([call[1] for call in flow.calls],
            ["roleMutationState", "globalRoleMutationState"])

    def test_gas_transition_requires_exact_source_revision(self):
        flow = FakeFlow()
        transition = flow._gas_transition(150000, 300000, 1)
        self.assertEqual(len(transition), 3)
        self.assertNotEqual(transition[1], transition[2])
        with self.assertRaisesRegex(MuseumError, "unexpected Artist read gas state"):
            flow._gas_transition(300000, 600000, 2)

    def test_missing_root_graph_dependency_fails_before_any_call(self):
        flow = FakeFlow()
        with self.assertRaisesRegex(MuseumError, "dependency missing"):
            flow._addresses("StreamArtistOnboardingCoordinator")

    def test_non_tuple_suite_is_rejected_without_treating_it_as_an_address_map(self):
        flow = FakeFlow()
        flow.token_suite = dict(flow.addresses)
        with self.assertRaisesRegex(MuseumError, "ABI token_suite"):
            flow._addresses("StreamRoleRegistry")

    def test_sale_flow_uses_zero_policy_only_as_explicit_resolver_input(self):
        self.assertEqual(ZERO, "0x" + "00" * 32)

    def test_mint_returns_integer_and_retains_exact_image_transaction_and_views(self):
        flow = FakeMintFlow()
        self.assertEqual(flow.mint_token(), 7)
        self.assertEqual(flow.token_id, 7)
        evidence = flow.token_mint_evidence
        self.assertEqual(evidence["tokenData"], "0x" + image_bytes().hex())
        self.assertEqual(evidence["tokenDataHash"], keccak256(image_bytes()))
        self.assertEqual(evidence["tokenDataSha256"], hashlib.sha256(image_bytes()).hexdigest())
        self.assertEqual(evidence["transaction"]["hash"], evidence["transactionHash"])
        self.assertEqual(evidence["receipt"]["status"], "0x1")
        self.assertEqual(evidence["tokenLifecycle"], "2")
        self.assertTrue(evidence["operationRootUsed"] and evidence["authorizationUsed"])
        self.assertTrue(evidence["developmentEntropyOnly"])

    def test_pinned_entropy_uses_direct_configuration_and_exact_media_uri(self):
        flow = FakeConfigurationFlow(); flow._govern_initial_configuration()
        functions = [row[1] for row in flow.governed]
        self.assertEqual(functions, ["configureCollection", "setCollectionMetadata",
            "setCollectionScript", "configureCollectionRoyalty",
            "setPrimaryProfileAssignment", "setCreditProducer"])
        self.assertNotIn("activateEntropyProvider", functions)
        self.assertNotIn("initializeOriginalFinalityAnchor", functions)
        metadata = next(row for row in flow.governed if row[1] == "setCollectionMetadata")
        self.assertEqual(metadata[2][3], media_description(TOKEN_DATA)["uri"])
        self.assertTrue(flow.token_entropy_evidence["controlledLocalProvider"])
        self.assertFalse(flow.token_entropy_evidence["secureRandomnessClaimed"])

    def test_state_changing_preview_preserves_actual_unlocked_sender(self):
        flow = FakePreviewFlow()
        result = flow._preview_transaction("StreamArtistOnboardingRegistry",
            "proposeArtistBinding", (1, "proposal"), ("bytes32", "bytes32"))
        self.assertEqual(result, ("0x" + "93" * 32, "0x" + "94" * 32))
        self.assertEqual(flow.encoded,
            ("StreamArtistOnboardingRegistry", "proposeArtistBinding", (1, "proposal")))
        self.assertEqual(flow.params, ("eth_call", [{"from": flow.account,
            "to": flow.addresses["StreamArtistOnboardingRegistry"], "data": "0x1234"},
            "latest"]))

    def test_safe_proof_approves_handler_wrapped_message_hash(self):
        flow = FakeSafeProofFlow(); digest = "0x" + "a5" * 32
        signatures = flow._safe_proof(flow.safe, digest)
        self.assertEqual(flow.reads[0], (flow.safe, "domainSeparator()", (), (), ("bytes32",)))
        self.assertEqual(flow.reads[1], (flow.safe, "getMessageHash(bytes)", ("bytes",),
            (encode(("bytes32",), (digest,)),), ("bytes32",)))
        self.assertEqual([row[3] for row in flow.invocations],
            [(flow.message_hash,), (flow.message_hash,)])
        self.assertEqual([row[4] for row in flow.invocations], sorted(flow.owners))
        self.assertEqual(len(signatures), 130)
        self.assertEqual(flow.preflights, [("eth_call", [{"from": flow.account, "to": flow.safe,
            "data": calldata("isValidSignature(bytes32,bytes)", ("bytes32", "bytes"),
                (digest, signatures))}, "latest"])])
        # Preflight supplies the original Stream digest, while owners approved
        # the independently known Safe domain-wrapped test vector above.
        data = hex_bytes(flow.preflights[0][1][0]["data"])
        self.assertEqual(decode(("bytes32", "bytes"), data[4:])[0], digest)
        self.assertNotEqual(digest, flow.message_hash)

    def test_safe_proof_rejects_wrong_domain_before_owner_approvals(self):
        flow = FakeSafeProofFlow(); flow.domain = "0x" + "b4" * 32
        with self.assertRaisesRegex(MuseumError, "handler message domain differs"):
            flow._safe_proof(flow.safe, "0x" + "a5" * 32)
        self.assertFalse(flow.invocations)

    def test_safe_proof_requires_actual_erc1271_magic(self):
        flow = FakeSafeProofFlow(); flow.magic = "0xffffffff"
        with self.assertRaisesRegex(MuseumError, "ERC-1271 protocol digest proof failed"):
            flow._safe_proof(flow.safe, "0x" + "a5" * 32)

    def test_safe_proof_disallows_owner_preflight_shortcut(self):
        flow = FakeSafeProofFlow(); flow.account = flow.owners[0]
        with self.assertRaisesRegex(MuseumError, "non-owner caller"):
            flow._safe_proof(flow.safe, "0x" + "a5" * 32)
        self.assertFalse(flow.invocations)

    def test_phase_counter_uses_named_pinned_enum_ordinals_for_both_consents(self):
        flow = FakePhaseFlow(); flow._configure_sale_phase()
        self.assertEqual([action[0] for action in flow.actions], ["previewPhasePolicyHash", "consent",
            "configurePhase", "previewPhasePolicyHash", "consent", "setPhaseExecutor", "phasePolicyHash"])
        expected = [(True, 1, 1, 0, 10, 1, schema_id("counter"))]
        for function, values in flow.actions:
            if function in ("previewPhasePolicyHash", "configurePhase"):
                self.assertEqual(values[5], expected)
        self.assertEqual((flow.token_initial_phase_policy, flow.token_mint_policy), (flow.initial, flow.final))

    def test_enum_lookup_uses_ordered_ast_instead_of_abi_uint8_or_assumed_zero(self):
        products = {"Example": interface_enums("Example", {"Mode": ["UNKNOWN", "RESERVED", "STATIC"]})}
        self.assertEqual(interface_enum_value(products, "Example", "Mode", "STATIC"), 2)

    def test_enum_lookup_rejects_missing_and_ambiguous_owned_declarations(self):
        base = {"Example": interface_enums("Example", {"Mode": ["UNKNOWN", "STATIC"]})}
        for products, interface, enum_name, member in (
            ({}, "Example", "Mode", "STATIC"), (base, "Example", "Missing", "STATIC"),
            (base, "Example", "Mode", "MISSING"),
        ):
            with self.subTest(interface=interface, enum=enum_name, member=member), self.assertRaises(MuseumError):
                interface_enum_value(products, interface, enum_name, member)
        for mutation in ("interface", "enum", "member", "kind"):
            products = copy.deepcopy(base)
            definition = products["Example"]["ast"]["nodes"][0]
            if mutation == "interface": products["Example"]["ast"]["nodes"].append(copy.deepcopy(definition))
            elif mutation == "enum": definition["nodes"].append(copy.deepcopy(definition["nodes"][0]))
            elif mutation == "member": definition["nodes"][0]["members"].append({"nodeType": "EnumValue", "name": "STATIC"})
            else: definition["contractKind"] = "contract"
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                interface_enum_value(products, "Example", "Mode", "STATIC")

    def test_reveal_policy_uses_delayed_roles_then_actual_safe_call_and_exact_readback(self):
        flow = FakeRevealPolicyFlow(); flow._activate_token_reveal_policy()
        self.assertEqual([(row[0], row[1], row[2]) for row in flow.governed], [
            ("StreamRoleRegistry", "grantRole", (ENTROPY_ADMIN, flow.governor)),
            ("StreamRoleRegistry", "grantRole", (ENTROPY_REVEAL_OWNER, flow.governor))])
        self.assertEqual(flow.safe_calls, [("StreamEntropyCoordinator", "configureCollectionRevealPolicy",
            (COLLECTION_ID, 0, ENTROPY_REVEAL_OWNER, 100, 0), flow.governor)])
        evidence = flow.token_entropy_evidence["revealPolicy"]
        self.assertEqual(evidence["configurationTransactionHash"], flow.transaction_hash)
        self.assertEqual(evidence["administrator"], flow.governor)
        self.assertEqual(evidence["revealOwner"], flow.governor)
        self.assertTrue(evidence["declared"] and evidence["actualSafeCall"])
        self.assertEqual(evidence["revealFeePerTokenWei"], "0")
        self.assertFalse(flow.token_entropy_evidence["secureRandomnessClaimed"])

    def test_reveal_policy_rejects_non_contract_principal_before_grants(self):
        flow = FakeRevealPolicyFlow(); flow.runtime = "0x"
        with self.assertRaisesRegex(MuseumError, "actual governor Safe required"):
            flow._activate_token_reveal_policy()
        self.assertFalse(flow.governed or flow.safe_calls)

    def test_reveal_policy_rejects_absent_or_different_policy_readback(self):
        for policy in ((False, 0, ENTROPY_REVEAL_OWNER, 100, 0), (True, 1, ENTROPY_REVEAL_OWNER, 100, 0),
                       (True, 0, ENTROPY_REVEAL_OWNER, 100, 1)):
            flow = FakeRevealPolicyFlow(); flow.policy_override = policy
            with self.subTest(policy=policy), self.assertRaisesRegex(MuseumError, "declared zero-fee reveal policy differs"):
                flow._activate_token_reveal_policy()


if __name__ == "__main__": unittest.main()
