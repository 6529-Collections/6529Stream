"""Actual local paid-mint stages for a root-built current token graph.

This mixin owns no foundation, module registration, pointer selection, manifest
publication, source capture, or process lifecycle.  The root fixture supplies a
complete original Artist graph in ``token_suite`` and the two governance hooks
documented by :class:`TokenMintFlow`.  DevelopmentEntropyProvider is an
explicit Anvil-only substitution and is never described as randomness proof.
"""
import hashlib
import time

from .canonical import hex_bytes, keccak256, schema_id
from .chain_abi import calldata, decode, encode
from .current_museum_capture import h
from .current_media_inputs import image_bytes, media_description
from .independent_wire import ZERO, ZERO_ADDRESS, require
from .token_governance import TOKEN_GOVERNANCE_PRODUCTS
from .token_native_graph import TOKEN_GRAPH_DECLARATIONS, TOKEN_GRAPH_PRODUCTS


TOKEN_SALE_PRODUCTS = (
    "StreamRevenueEscrow", "StreamFixedPriceSaleAdapter", "StreamEntropyCoordinator",
    "DevelopmentEntropyProvider",
)

TOKEN_INTERFACE_PRODUCTS = (
    "IStreamMintLedger", "IStreamMintManager", "IStreamEntropyCoordinator",
    "IStreamRoyaltyResolver", "IStreamArtworkFinalityRegistry",
)

TOKEN_PRODUCT_ROOTS = tuple(sorted(set(
    TOKEN_GOVERNANCE_PRODUCTS + TOKEN_GRAPH_PRODUCTS + TOKEN_GRAPH_DECLARATIONS
    + TOKEN_SALE_PRODUCTS + TOKEN_INTERFACE_PRODUCTS)))

TOKEN_MODULE_ROWS = (
    ("StreamMintManager", "MINT_MANAGER", "IStreamMintManager", None),
    ("StreamMintLedger", "MINT_LEDGER", "IStreamMintLedger", None),
    ("StreamEntropyCoordinator", "ENTROPY_COORDINATOR", "IStreamEntropyCoordinator", None),
    ("StreamRoyaltyResolver", "REVENUE_RESOLVER", "IStreamRoyaltyResolver", "ROYALTY_RESOLVER"),
    ("StreamArtworkFinalityRegistry", "ARTWORK_FINALITY_REGISTRY", "IStreamArtworkFinalityRegistry", None),
)

COLLECTION_ID = 1
PHASE_ID = schema_id("current-stack fixed price")
PRIMARY_REVENUE_CLASS = schema_id("PRIMARY_SALE")
TOKEN_DATA = image_bytes()
PRICE = 10**16
ARTIST_ADMIN = schema_id("ROLE_ARTIST_REGISTRY_ADMIN")
ENTROPY_ADMIN = schema_id("ROLE_ENTROPY_ADMIN")
ENTROPY_REVEAL_OWNER = schema_id("ROLE_ENTROPY_REVEAL_OWNER")
ARTIST_READ_GAS = schema_id("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT")
SALE_EVENT = keccak256(b"NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)")


def interface_enum_value(products, interface, enum_name, member):
    """Resolve a named enum from the already hash-verified native interface AST.

    ABI uint8 fields erase enum names and cannot establish their ordinals.
    Require the exact interface-owned declaration and its unique ordered
    members; missing/ambiguous artifacts fail before any transaction is sent.
    """
    require(interface in products, "pinned enum interface artifact missing: " + interface)
    artifact = products[interface]
    definitions = [row for row in artifact.get("ast", {}).get("nodes", [])
        if row.get("nodeType") == "ContractDefinition" and row.get("name") == interface
        and row.get("contractKind") == "interface"]
    require(len(definitions) == 1, "pinned enum interface declaration ambiguous: " + interface)
    enums = [row for row in definitions[0].get("nodes", [])
        if row.get("nodeType") == "EnumDefinition" and row.get("name") == enum_name]
    require(len(enums) == 1, "pinned enum declaration missing/ambiguous: " + interface + "." + enum_name)
    rows = enums[0].get("members", [])
    names = [row.get("name") for row in rows]
    require(0 < len(names) <= 256 and all(row.get("nodeType") == "EnumValue" for row in rows)
        and all(isinstance(name, str) and name for name in names) and len(set(names)) == len(names),
        "pinned enum member inventory malformed")
    require(member in names, "pinned enum member missing: " + interface + "." + enum_name + "." + member)
    return names.index(member)


class TokenMintFlowMixin:
    """Mixin for a complete root-built current graph.

    Required root hooks are ``govern_configuration`` and
    ``select_token_modules``.  Pointer selection must occur at the graph's
    original pre-Coordinator stage; this mixin exposes ``TOKEN_MODULE_ROWS``
    and does not repeat that operation after the Coordinator exists.
    """

    def _addresses(self, *names):
        require(isinstance(getattr(self, "token_suite", None), tuple),
            "root token graph did not provide ABI token_suite")
        missing = [name for name in names if name not in self.addresses]
        require(not missing, "root token graph dependency missing: " + ",".join(missing))
        for name in names:
            require(len(hex_bytes(self.addresses[name], 20)) == 20 and self.addresses[name] != ZERO_ADDRESS,
                "root token graph dependency address invalid: " + name)
        return tuple(self.addresses[name] for name in names)

    def _now(self):
        return int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)

    def _preview_transaction(self, name, function, values, outputs, *, sender=None):
        """Preview a state-changing call from the account that will send it.

        ``CurrentNativeFixture.call`` intentionally omits ``from`` and is only
        suitable for view calls.  Sender-bound creation and administrator
        previews must preserve the unlocked caller used by the subsequent
        transaction.
        """
        target, = self._addresses(name)
        caller = self.account if sender is None else sender
        require(caller != ZERO_ADDRESS and len(hex_bytes(caller, 20)) == 20,
            "transaction preview sender invalid")
        raw = self.rpc("eth_call", [{"from": caller, "to": target,
            "data": self.data(name, function, values)}, "latest"])
        return decode(outputs, hex_bytes(raw))

    def _safe_proof(self, safe, digest):
        """Use actual SafeMessage approved-hash ERC-1271 signatures; no private keys."""
        require(safe in self.safe_accounts and len(self.safe_accounts[safe]) >= 2,
            "official threshold Safe fixture required")
        message = encode(("bytes32",), (digest,))
        domain, = self.read(safe, "domainSeparator()", (), (), ("bytes32",))
        require(domain != ZERO, "official Safe domain absent")
        struct_hash = keccak256(encode(("bytes32", "bytes32"),
            (schema_id("SafeMessage(bytes message)"), keccak256(message))))
        message_hash = keccak256(b"\x19\x01" + hex_bytes(domain, 32) + hex_bytes(struct_hash, 32))
        handler_hash, = self.read(safe, "getMessageHash(bytes)", ("bytes",),
            (message,), ("bytes32",))
        require(handler_hash == message_hash, "official Safe handler message domain differs")
        owners = sorted(self.safe_accounts[safe])
        require(self.account not in owners, "Safe proof preflight must use a non-owner caller")
        signatures = b""
        for owner in owners:
            self.invoke(safe, "approveHash(bytes32)", ("bytes32",),
                (message_hash,), sender=owner)
            approved, = self.read(safe, "approvedHashes(address,bytes32)",
                ("address", "bytes32"), (owner, message_hash), ("uint256",))
            require(approved == 1, "Safe hash approval was not retained")
            signatures += bytes(12) + hex_bytes(owner, 20) + bytes(32) + b"\x01"
        # Keep the protocol digest unchanged at the ERC-1271 boundary. The
        # actual handler applies the Safe domain; a non-owner caller cannot
        # accidentally satisfy a v=1 proof through Safe's sender shortcut.
        result = self.rpc("eth_call", [{"from": self.account, "to": safe,
            "data": calldata("isValidSignature(bytes32,bytes)", ("bytes32", "bytes"),
                (digest, signatures))}, "latest"])
        require(decode(("bytes4",), hex_bytes(result)) == ("0x1626ba7e",),
            "official Safe ERC-1271 protocol digest proof failed")
        return signatures

    def _authorization(self, signed_at=False):
        nonce = getattr(self, "token_artist_authorization_nonce", 0)
        self.token_artist_authorization_nonce = nonce + 1
        return (nonce, self._now() if signed_at else self._now() + 86400, b"")

    def _signed_authorization(self, function, arguments, authorization, safe):
        digest, = self.call("StreamArtistOnboardingRegistry", function,
            (*arguments, authorization))
        return authorization[:2] + (self._safe_proof(safe, digest),)

    def deploy_token_sale_products(self):
        """Deploy the sale-only products against the complete root-built graph."""
        manager, factory, artist, primary, core, executor, roles = self._addresses(
            "StreamMintManager", "StreamSplitFactory", "StreamArtistOnboardingRegistry",
            "StreamRevenueResolver", "StreamCore", "StreamGovernanceExecutor",
            "StreamRoleRegistry")
        self.token_artist_safe = self.safe(781)
        self.token_platform_safe = self.safe(782)
        self.token_protocol_safe = self.safe(783)
        accounts = self.rpc("eth_accounts", [])
        excluded = {self.account, *self.safe_accounts[self.token_artist_safe],
            *self.safe_accounts[self.token_platform_safe], *self.safe_accounts[self.token_protocol_safe]}
        buyers = [account for account in accounts if account not in excluded]
        require(buyers, "distinct unlocked local token buyer unavailable")
        self.token_buyer = buyers[0]
        require(len({self.token_artist_safe, self.token_platform_safe, self.token_buyer}) == 3,
            "token artist, platform and buyer must be distinct")

        entries = [(self.token_artist_safe, 900000, schema_id("artist")),
                   (self.token_protocol_safe, 100000, schema_id("protocol"))]
        split_salt = schema_id("local token media capture split")
        profile, wallet = self._preview_transaction("StreamSplitFactory", "createProfile",
            (entries, split_salt), ("bytes32", "address"))
        self.transact("StreamSplitFactory", "createProfile", (entries, split_salt))
        require(self.call("StreamSplitFactory", "walletFor", (profile,)) == (wallet,),
            "actual split profile wallet differs")

        escrow = self.deploy("StreamRevenueEscrow",
            (factory, executor, ("FLUSH_GAS_FLOOR", 12000000, 12000000, 3)))
        sale = self.deploy("StreamFixedPriceSaleAdapter",
            (manager, primary, self.token_platform_safe, artist, escrow))
        times = (("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 100, 100, 1200),
                 ("ENTROPY_REVEAL_SLO_BLOCKS", 100, 100, 1200),
                 ("ENTROPY_RECOVERY_STEP_DELAY_BLOCKS", 100, 100, 1200))
        entropy = self.deploy("StreamEntropyCoordinator", ((core, executor, roles, times,
            self.deployment, "urn:6529stream:local-token:development-entropy",
            schema_id("local token development entropy module")),))
        provider = self.deploy("DevelopmentEntropyProvider", (entropy, self.account))
        self.token_split_profile, self.token_split_wallet = profile, wallet
        self.token_entropy_qualification = (
            "Anvil DevelopmentEntropyProvider; not secure randomness evidence.")
        return {name: self.addresses[name] for name in TOKEN_SALE_PRODUCTS}

    def _role_transition(self, role, holder):
        roles, = self._addresses("StreamRoleRegistry")
        role_chain, role_revision = self.call("StreamRoleRegistry", "roleMutationState", (role,))
        global_chain, global_revision = self.call("StreamRoleRegistry", "globalRoleMutationState")
        chain = int(self.rpc("eth_chainId", []), 16)
        scope = h(("bytes32", "uint256", "address", "bytes32", "address"),
            (schema_id("6529STREAM_ROLE_MUTATION_SCOPE_V1"), chain, roles, role, holder))
        state = lambda granted, rc, rr, gc, gr: h(
            ("bytes32", "uint256", "address", "bytes32", "bool", "bytes32", "uint64", "bytes32", "uint64"),
            (schema_id("6529STREAM_ROLE_MUTATION_STATE_V1"), chain, roles, scope, granted, rc, rr, gc, gr))
        next_role = h(("bytes32", "bytes32", "uint256", "address", "bytes32", "address", "bool", "uint64"),
            (schema_id("6529STREAM_ROLE_MUTATION_V1"), role_chain, chain, roles, role, holder, True, role_revision + 1))
        next_global = h(("bytes32", "bytes32", "uint256", "address", "bytes32", "address", "bool", "uint64"),
            (schema_id("6529STREAM_GLOBAL_ROLE_MUTATION_V1"), global_chain, chain, roles, role, holder, True, global_revision + 1))
        return scope, state(False, role_chain, role_revision, global_chain, global_revision), state(
            True, next_role, role_revision + 1, next_global, global_revision + 1)

    def _gas_transition(self, expected, value, revision):
        manager, = self._addresses("StreamMintManager")
        actual, floor, failure, actual_revision = self.call(
            "StreamMintManager", "gasParameterInfo", (ARTIST_READ_GAS,))
        require((actual, floor, failure, actual_revision) == (expected, 150000, 2, revision),
            "unexpected Artist read gas state")
        chain = int(self.rpc("eth_chainId", []), 16)
        scope = h(("bytes32", "uint256", "address", "bytes32"),
            (schema_id("6529STREAM_GAS_PARAMETER_SCOPE_V2"), chain, manager, ARTIST_READ_GAS))
        domain = schema_id("6529STREAM_GAS_PARAMETER_STATE_V2")
        state = lambda amount, rev: h(("bytes32", "bytes32", "uint256", "uint256", "uint8", "uint64"),
            (domain, scope, amount, floor, failure, rev))
        return scope, state(actual, actual_revision), state(value, actual_revision + 1)

    def _govern_initial_configuration(self):
        provider, sale = self._addresses("DevelopmentEntropyProvider", "StreamFixedPriceSaleAdapter")
        entropy, = self._addresses("StreamEntropyCoordinator")
        require(self.call("DevelopmentEntropyProvider", "coordinator") == (entropy,)
            and self.call("DevelopmentEntropyProvider", "controller") == (self.account,)
            and self.call("DevelopmentEntropyProvider", "isStreamEntropyProvider") == (True,),
            "controlled local entropy provider binding differs")
        self.govern_configuration("StreamEntropyCoordinator", "configureCollection",
            (COLLECTION_ID, provider, schema_id("collection salt"), True, 100))
        entropy_config = self.call("StreamEntropyCoordinator", "collectionEntropyConfig", (COLLECTION_ID,))
        require(entropy_config[0] == provider and entropy_config[1] and not entropy_config[2]
            and entropy_config[3] == 100 and entropy_config[4] != ZERO
            and entropy_config[5] == keccak256(hex_bytes(self.rpc("eth_getCode", [provider, "latest"])))
            and entropy_config[6] == schema_id("collection salt"),
            "controlled local entropy collection configuration differs")
        family, = self.call("DevelopmentEntropyProvider", "streamEntropyProviderFamily")
        version, = self.call("DevelopmentEntropyProvider", "streamEntropyProviderVersion")
        config_hash, = self.call("DevelopmentEntropyProvider", "streamEntropyProviderConfigHash")
        require(family != ZERO and version != ZERO and config_hash == entropy_config[4],
            "controlled local entropy provider identity differs")
        self.token_entropy_evidence = {"provider": provider, "coordinator": entropy,
            "family": family, "version": version, "configHash": config_hash,
            "providerRuntimeHash": entropy_config[5], "collectionSalt": entropy_config[6],
            "publicRequests": True, "timeoutBlocks": "100", "controlledLocalProvider": True,
            "secureRandomnessClaimed": False}
        self.govern_configuration("StreamMetadataRouter", "setCollectionMetadata", (COLLECTION_ID,
            "Stream Genesis", "Current token media capture", media_description(TOKEN_DATA)["uri"],
            "https://example.invalid/art/"))
        self.govern_configuration("StreamMetadataRouter", "setCollectionScript",
            (COLLECTION_ID, "document.body.textContent=tokenHash;"))
        profile = self.token_split_profile
        self.govern_configuration("StreamRoyaltyResolver", "configureCollectionRoyalty",
            (COLLECTION_ID, profile, 690))
        self.govern_configuration("StreamRevenueResolver", "setPrimaryProfileAssignment",
            (PRIMARY_REVENUE_CLASS, 1, COLLECTION_ID, profile, ZERO))
        transition = self.call("StreamRevenueEscrow", "creditProducerTransitionHashes", (sale, True))
        self.govern_configuration("StreamRevenueEscrow", "setCreditProducer", (sale, True), transition)

    def _activate_artist_administrator(self):
        self.govern_configuration("StreamRoleRegistry", "grantRole",
            (ARTIST_ADMIN, self.account), self._role_transition(ARTIST_ADMIN, self.account))
        for expected, value, revision in ((150000, 300000, 1), (300000, 600000, 2)):
            self.govern_configuration("StreamMintManager", "raiseGasParameter",
                (ARTIST_READ_GAS, value), self._gas_transition(expected, value, revision))

    def _activate_token_reveal_policy(self):
        """Declare the original zero-fee policy through an actual role-bound Safe.

        Entropy's operational administrator is distinct from its governance
        executor. The retained native contract requires a code-bearing role
        holder; an executor call without that role is not an authorization.
        """
        entropy, = self._addresses("StreamEntropyCoordinator")
        administrator = self.governor
        require(administrator in self.safe_accounts and len(self.safe_accounts[administrator]) == 2
            and self.rpc("eth_getCode", [administrator, "latest"]) != "0x",
            "actual governor Safe required for reveal administration")
        for role in (ENTROPY_ADMIN, ENTROPY_REVEAL_OWNER):
            require(self.call("StreamRoleRegistry", "hasRole", (role, administrator)) == (False,),
                "token reveal principal already granted")
            if role == ENTROPY_REVEAL_OWNER:
                require(self.call("StreamRoleRegistry", "roleHolderCount", (role,)) == (0,),
                    "token reveal owner must begin unassigned")
            self.govern_configuration("StreamRoleRegistry", "grantRole", (role, administrator),
                self._role_transition(role, administrator))
            require(self.call("StreamRoleRegistry", "hasRole", (role, administrator)) == (True,),
                "actual token reveal role grant missing")
        require(self.call("StreamRoleRegistry", "roleHolderCount", (ENTROPY_REVEAL_OWNER,)) == (1,)
            and self.call("StreamRoleRegistry", "resolveRole", (ENTROPY_REVEAL_OWNER,)) == (administrator,),
            "actual token reveal owner resolution differs")
        values = (COLLECTION_ID, 0, ENTROPY_REVEAL_OWNER, 100, 0)
        receipt = self.transact("StreamEntropyCoordinator", "configureCollectionRevealPolicy", values,
            safe=administrator)
        policy, = self.call("StreamEntropyCoordinator", "collectionRevealPolicy", (COLLECTION_ID,))
        require(policy == (True, 0, ENTROPY_REVEAL_OWNER, 100, 0),
            "actual declared zero-fee reveal policy differs")
        self.token_entropy_evidence["revealPolicy"] = {
            "declared": True, "requestMode": "0", "revealOwnerRole": ENTROPY_REVEAL_OWNER,
            "requestSLOBlocks": "100", "revealFeePerTokenWei": "0",
            "administrator": administrator, "revealOwner": administrator,
            "configurationTransactionHash": receipt["transactionHash"],
            "configurationHost": entropy, "actualSafeCall": True,
        }

    def _onboard_token_artist(self):
        artist, router, coordinator, binding_owner, core, manager = self._addresses(
            "StreamArtistOnboardingRegistry", "StreamMetadataRouter",
            "StreamArtistOnboardingCoordinator", "StreamArtistBindingLifecycle",
            "StreamCore", "StreamMintManager")
        document = b"current-stack artist identity"
        proposal = (ZERO, self.token_artist_safe, keccak256(document),
            "urn:6529stream:local-token:artist-identity", 1, 0, 0, 0, 0, [], [], ZERO, "")
        artist_id, nomination = self._preview_transaction("StreamArtistOnboardingRegistry",
            "proposeArtistBinding", (COLLECTION_ID, proposal, document, "Stream Artist"),
            ("bytes32", "bytes32"))
        self.transact("StreamArtistOnboardingRegistry", "proposeArtistBinding",
            (COLLECTION_ID, proposal, document, "Stream Artist"))
        authorization = self._authorization(False)
        authorization = self._signed_authorization("acceptanceDigest", (COLLECTION_ID,),
            authorization, self.token_artist_safe)
        self.transact("StreamArtistOnboardingRegistry", "acceptArtistBinding",
            (COLLECTION_ID, authorization))
        require(self.call("StreamArtistOnboardingRegistry", "acceptedArtist", (COLLECTION_ID,))
            == (self.token_artist_safe,), "actual accepted token artist differs")

        payout = (artist_id, self.token_artist_safe, ZERO)
        authorization = self._authorization(True)
        authorization = self._signed_authorization("payoutDesignationDigest", (payout,),
            authorization, self.token_artist_safe)
        self.transact("StreamArtistOnboardingRegistry", "recordPayoutDesignation",
            (payout, authorization))

        reads, = self.call("StreamArtistOnboardingCoordinator", "reads")
        expected_reads, = self._addresses("StreamArtistOnboardingReads")
        require(reads == expected_reads, "original Coordinator reader address differs")
        assignments = self.call("StreamArtistOnboardingReads", "currentAssignments", (COLLECTION_ID,))
        for fact in assignments:
            consent = (COLLECTION_ID, *fact)
            authorization = self._authorization(False)
            authorization = self._signed_authorization("economicsConsentDigest", (consent,),
                authorization, self.token_artist_safe)
            self.transact("StreamArtistOnboardingRegistry", "recordEconomicsConsent",
                (consent, authorization))

        metadata_contract, content_state = self.call(
            "StreamMetadataRouter", "currentArtistContentState", (COLLECTION_ID,))
        ratification = (COLLECTION_ID, metadata_contract, content_state)
        authorization = self._authorization(False)
        authorization = self._signed_authorization("contentRatificationDigest", (ratification,),
            authorization, self.token_artist_safe)
        self.transact("StreamArtistOnboardingRegistry", "recordContentRatification",
            (ratification, authorization))

        binding, = self.call("StreamArtistBindingLifecycle", "binding", (COLLECTION_ID,))
        require(binding[0] == artist_id and binding[1] == self.token_artist_safe and binding[9],
            "actual accepted Artist binding differs")
        facts = h(("bytes32", "uint256", "address", "uint256", "bytes32", "uint64", "bytes32"),
            (schema_id("6529STREAM_ARTIST_DEPLOYMENT_FACTS_V1"),
             int(self.rpc("eth_chainId", []), 16), core, COLLECTION_ID,
             binding[0], binding[4], binding[3]))
        self._record_artist_attestation(9, "0x" + (bytes(12) + hex_bytes(core, 20)).hex(), facts,
            schema_id("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1"))
        self._record_artist_attestation(10, artist_id, binding[2],
            schema_id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"))
        self.token_artist_evidence = {"artistId": artist_id, "nominationHash": nomination,
            "artistBinding": binding, "artistAuthorizationNonce": str(self.token_artist_authorization_nonce)}

    def _record_artist_attestation(self, kind, subject, state, schema):
        statement = encode(("uint8", "bytes32", "bytes32", "bytes32"),
            (kind, subject, state, schema))
        attestation = (COLLECTION_ID, kind, subject, state, schema, keccak256(statement),
            "urn:6529stream:local-token:artist-statement")
        authorization = self._authorization(True)
        authorization = self._signed_authorization("attestationDigest", (attestation,),
            authorization, self.token_artist_safe)
        self.transact("StreamArtistOnboardingRegistry", "recordArtistAttestation",
            (attestation, authorization, statement))

    def _record_policy_consent(self, policy):
        consent = (COLLECTION_ID, PHASE_ID, policy)
        authorization = self._authorization(False)
        authorization = self._signed_authorization("policyConsentDigest", (consent,),
            authorization, self.token_artist_safe)
        self.transact("StreamArtistOnboardingRegistry", "recordPolicyConsent",
            (consent, authorization))

    def _configure_sale_phase(self):
        sale, = self._addresses("StreamFixedPriceSaleAdapter")
        config = (False, 0, 0, 1, schema_id("phase"), schema_id("metadata"))
        gate = (ZERO_ADDRESS, ZERO, ZERO, ZERO, 0, 0)
        counter_ids = [schema_id("supply")]
        key_mode = interface_enum_value(self.products, "IStreamMintManager", "CounterKeyMode", "CONSTANT")
        cap_mode = interface_enum_value(self.products, "IStreamMintLedger", "CounterCapMode", "STATIC")
        delta_mode = interface_enum_value(self.products, "IStreamMintLedger", "CounterDeltaMode", "STATIC")
        counters = [(True, key_mode, cap_mode, delta_mode, 10, 1, schema_id("counter"))]
        initial, = self.call("StreamMintManager", "previewPhasePolicyHash",
            (COLLECTION_ID, PHASE_ID, config, gate, counter_ids, counters, []))
        require(initial != ZERO, "initial token phase policy absent")
        self._record_policy_consent(initial)
        self.transact("StreamMintManager", "configurePhase",
            (COLLECTION_ID, PHASE_ID, config, gate, counter_ids, counters))
        final, = self.call("StreamMintManager", "previewPhasePolicyHash",
            (COLLECTION_ID, PHASE_ID, config, gate, counter_ids, counters, [sale]))
        require(final not in (ZERO, initial), "final token phase policy absent or unchanged")
        self._record_policy_consent(final)
        self.transact("StreamMintManager", "setPhaseExecutor",
            (COLLECTION_ID, PHASE_ID, sale, True))
        require(self.call("StreamMintManager", "phasePolicyHash", (COLLECTION_ID, PHASE_ID))
            == (final,), "actual final token phase policy differs")
        self.token_initial_phase_policy, self.token_mint_policy = initial, final

    def configure_token_sale_products(self):
        """Configure economics, actual Artist authority, phase consent, and handoff."""
        ledger, manager, sale, executor = self._addresses("StreamMintLedger", "StreamMintManager",
            "StreamFixedPriceSaleAdapter", "StreamGovernanceExecutor")
        require(self.call("StreamMintLedger", "ledgerWriter", (manager,)) == (True,),
            "root graph did not retain MintManager ledger writer authority")
        self._govern_initial_configuration()
        self._activate_token_reveal_policy()
        self._activate_artist_administrator()
        self.token_artist_authorization_nonce = 0
        self._onboard_token_artist()
        self._configure_sale_phase()
        for name in ("StreamMintLedger", "StreamFixedPriceSaleAdapter", "StreamMintManager"):
            self.transact(name, "transferOwnership", (executor,))
            require(self.call(name, "owner") == (executor,), "token product ownership handoff differs")
        policy, profile, wallet = self.call("StreamFixedPriceSaleAdapter", "primaryPolicy",
            (COLLECTION_ID,))
        require((profile, wallet) == (self.token_split_profile, self.token_split_wallet),
            "actual token primary profile differs")
        self.token_primary_policy = policy
        return {"primaryPolicy": policy, "profile": profile, "wallet": wallet,
            "mintPolicy": self.token_mint_policy}

    def _send_value(self, target, data, sender, value):
        tx = {"from": sender, "to": target, "data": data, "value": hex(value), "gas": "0x1c9c380"}
        tx_hash = self.rpc("eth_sendTransaction", [tx])
        receipt = None
        deadline = time.monotonic() + 30
        while receipt is None and time.monotonic() < deadline:
            receipt = self.rpc("eth_getTransactionReceipt", [tx_hash])
            if receipt is None: time.sleep(0.01)
        row = {"transaction": tx, "transactionHash": tx_hash, "receipt": receipt}
        self.receipts.append(row)
        if receipt is not None and receipt["status"] != "0x1":
            trace = self.rpc("debug_traceTransaction", [tx_hash, {"tracer": "callTracer"}])
            failures = []
            def collect(frame):
                if frame.get("error"):
                    failures.append({key: frame[key] for key in ("to", "error", "output", "gas", "gasUsed") if key in frame})
                for child in frame.get("calls", []): collect(child)
            collect(trace)
            row["revertedFrames"] = failures
            print("Local paid mint reverted frames:", failures, flush=True)
        require(receipt is not None and receipt["status"] == "0x1",
            "actual paid token mint transaction failed")
        return tx_hash, receipt

    def mint_token(self):
        """Execute one paid Safe-authorized sale and retain exact token joins."""
        sale, core = self._addresses("StreamFixedPriceSaleAdapter", "StreamCore")
        policy, profile, wallet = self.call("StreamFixedPriceSaleAdapter", "primaryPolicy",
            (COLLECTION_ID,))
        mint_policy, = self.call("StreamMintManager", "phasePolicyHash", (COLLECTION_ID, PHASE_ID))
        epoch, = self.call("StreamFixedPriceSaleAdapter", "signerEpoch")
        authorization = (COLLECTION_ID, PHASE_ID, self.token_buyer, self.token_buyer,
            self.token_artist_safe, profile, policy, keccak256(TOKEN_DATA),
            schema_id("local token media capture actual mint"), mint_policy, PRICE,
            schema_id("local token media capture sale"), self._now() + 86400, epoch)
        digest, = self.call("StreamFixedPriceSaleAdapter", "authorizationDigest", (authorization,))
        platform = self._safe_proof(self.token_platform_safe, digest)
        artist = self._safe_proof(self.token_artist_safe, digest)
        data = self.data("StreamFixedPriceSaleAdapter", "buy",
            (authorization, TOKEN_DATA, platform, artist))
        tx_hash, receipt = self._send_value(sale, data, self.token_buyer, PRICE)
        events = [row for row in receipt["logs"] if row["address"] == sale
            and len(row["topics"]) == 4 and row["topics"][0] == SALE_EVENT]
        require(len(events) == 1, "one exact NativeSaleSettled event required")
        event = events[0]
        token_id = int(event["topics"][3], 16)
        event_digest, event_profile, event_wallet, amount = decode(
            ("bytes32", "bytes32", "address", "uint256"), hex_bytes(event["data"]))
        require(token_id > 0 and event["topics"][2] != ZERO and event_digest == digest
            and (event_profile, event_wallet, amount) == (profile, wallet, PRICE),
            "actual paid sale event differs")
        owner, = self.call("StreamCore", "ownerOf", (token_id,))
        identity = self.call("StreamCore", "tokenCollectionIdentity", (token_id,))
        lifecycle, = self.call("StreamCore", "tokenLifecycle", (token_id,))
        coordinator, = self.call("StreamCore", "coordinatorAtMint", (token_id,))
        token_data, = self.call("StreamCore", "tokenData", (token_id,))
        minted, = self.call("StreamCore", "collectionMintedEver", (COLLECTION_ID,))
        supply, = self.call("StreamCore", "totalSupply")
        operation_used, = self.call("StreamMintManager", "isOperationRootUsed", (event["topics"][2],))
        authorization_used, = self.call("StreamFixedPriceSaleAdapter", "authorizationUsed",
            (self.token_artist_safe, authorization[11]))
        require(owner == self.token_buyer and identity[0] and identity[1] == COLLECTION_ID
            and identity[2] > 0 and not identity[3] and lifecycle == 2
            and coordinator == self.addresses["StreamEntropyCoordinator"] and token_data == TOKEN_DATA
            and operation_used and authorization_used and minted >= 1 and supply >= 1,
            "actual minted token readback differs")
        self.token_id = token_id
        transaction = self.rpc("eth_getTransactionByHash", [tx_hash])
        require(transaction is not None and transaction["hash"] == tx_hash,
            "actual paid token mint transaction unavailable")
        evidence = {"transaction": transaction, "receipt": receipt,
            "transactionHash": tx_hash, "tokenId": str(token_id), "owner": owner,
            "collectionId": str(identity[1]), "collectionSerial": str(identity[2]),
            "tokenDataHash": keccak256(token_data), "saleAuthorizationDigest": digest,
            "tokenDataSha256": hashlib.sha256(token_data).hexdigest(),
            "tokenData": "0x" + token_data.hex(), "tokenDataBytes": str(len(token_data)),
            "authorizationId": event["topics"][1], "operationRoot": event["topics"][2],
            "profileId": profile, "wallet": wallet, "price": str(PRICE),
            "collectionMintedEver": str(minted), "totalSupply": str(supply),
            "tokenLifecycle": str(lifecycle), "coordinatorAtMint": coordinator,
            "operationRootUsed": operation_used, "authorizationUsed": authorization_used,
            "artist": self.token_artist_safe, "platform": self.token_platform_safe,
            "buyer": self.token_buyer, "developmentEntropyOnly": True}
        self.token_mint_evidence = evidence
        return token_id


# Kept as a compatibility spelling for source-level users of the initial draft.
TokenMintFlow = TokenMintFlowMixin
