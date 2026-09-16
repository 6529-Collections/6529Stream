// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamMintAllowlistGate.sol";

/// @notice Exercises the allowlist gate against the actual Manager, Ledger and module registry.
contract StreamMintAllowlistGateTest is MintEngineTestBase {
    bytes32 private constant ALLOWLIST = keccak256("allowlist allocation");
    bytes32 private constant LEADING_ALLOWLIST = keccak256("leading payer allocation");
    bytes32 private constant ALLOW_PHASE = keccak256("allowlist gate phase");
    uint256 private constant COLLECTION = 2;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    uint256 private actionNonce;

    struct ExpectedBinding {
        address manager;
        address ledger;
        address executor;
        uint256 collectionId;
        bytes32 phaseId;
        address payer;
        bytes32 expectedPolicyHash;
        bytes32 contextHash;
        bytes32 initialRecipientsHash;
        bytes32 beneficiariesHash;
        bytes32 tokenDataHash;
        bytes32 mintCommitmentsHash;
        bytes32 proofValuesHash;
        bytes32 nonce;
    }

    function _proof(uint64 maxCount)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof memory p)
    {
        p.maxCount = maxCount;
    }

    function _pair(bytes32 left, bytes32 right) private pure returns (bytes32) {
        return
            left < right ? keccak256(abi.encode(left, right)) : keccak256(abi.encode(right, left));
    }

    function _recipientGate(uint64 aliceCap, uint64 bobCap)
        private
        returns (
            StreamMintAllowlistGate gate,
            IStreamMintCounterPolicy.AllowlistProof memory alice,
            IStreamMintCounterPolicy.AllowlistProof memory bob
        )
    {
        alice = _proof(aliceCap);
        bob = _proof(bobCap);
        bytes32 aliceLeaf = StreamMintCounterPolicy.allowlistLeaf(
            address(manager), COLLECTION, ALLOW_PHASE, ALLOWLIST, ALICE, alice
        );
        bytes32 bobLeaf = StreamMintCounterPolicy.allowlistLeaf(
            address(manager), COLLECTION, ALLOW_PHASE, ALLOWLIST, BOB, bob
        );
        bytes32 root = _pair(aliceLeaf, bobLeaf);
        alice.proof = new bytes32[](1);
        alice.proof[0] = bobLeaf;
        bob.proof = new bytes32[](1);
        bob.proof[0] = aliceLeaf;
        gate = new StreamMintAllowlistGate(root, ALLOWLIST);
        _configure(
            gate, IStreamMintManager.CounterKeyMode.RECIPIENT, aliceCap > bobCap ? aliceCap : bobCap
        );
    }

    function _payerGate(uint64 cap)
        private
        returns (StreamMintAllowlistGate gate, IStreamMintCounterPolicy.AllowlistProof memory proof)
    {
        proof = _proof(cap);
        bytes32 root = StreamMintCounterPolicy.allowlistLeaf(
            address(manager), COLLECTION, ALLOW_PHASE, ALLOWLIST, signer, proof
        );
        gate = new StreamMintAllowlistGate(root, ALLOWLIST);
        _configure(gate, IStreamMintManager.CounterKeyMode.PAYER, cap);
    }

    function _configure(
        StreamMintAllowlistGate gate,
        IStreamMintManager.CounterKeyMode keyMode,
        uint64 ceiling
    ) private {
        _registerGate(address(gate));
        IStreamMintCounterPolicy.Definition memory definition = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            keyMode,
            gate.capRoot(),
            keccak256("published allowlist metadata")
        );
        bytes32 definitionHash = ledger.registerCounterDefinition(definition);
        IStreamMintManager.MintGateConfig memory gateConfig;
        gateConfig.gate = address(gate);
        gateConfig.gateConfigHash = gate.gateConfigHash();
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = ALLOWLIST;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            keyMode,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            ceiling,
            1,
            definitionHash
        );
        manager.configurePhase(
            COLLECTION,
            ALLOW_PHASE,
            IStreamMintManager.MintPhaseConfig(
                false, 0, 0, 10, keccak256("published allowlist file"), keccak256("allowlist phase")
            ),
            gateConfig,
            ids,
            counters
        );
        manager.setPhaseExecutor(COLLECTION, ALLOW_PHASE, address(this), true);
    }

    function _batch(address[] memory recipients)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = COLLECTION;
        b.phaseId = ALLOW_PHASE;
        b.payer = signer;
        b.initialRecipients = recipients;
        b.beneficiaries = recipients;
        b.tokenData = new bytes[](recipients.length);
        b.mintCommitments = new bytes32[](recipients.length);
        for (uint256 i; i < recipients.length; ++i) {
            b.tokenData[i] = abi.encode("allowlist token", i);
            b.mintCommitments[i] = keccak256(abi.encode("allowlist commitment", i));
        }
        b.contextHash = keccak256("allowlist context");
        b.expectedPolicyHash = manager.phasePolicyHash(COLLECTION, ALLOW_PHASE);
    }

    function _one(address recipient) private pure returns (address[] memory recipients) {
        recipients = new address[](1);
        recipients[0] = recipient;
    }

    function _resolver(IStreamMintCounterPolicy.AllowlistProof[] memory selected)
        private
        pure
        returns (bytes memory)
    {
        IStreamMintCounterPolicy.AllowlistProof[][] memory all =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        all[0] = selected;
        return abi.encode(all);
    }

    function _singleProof(IStreamMintCounterPolicy.AllowlistProof memory proof)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof[] memory selected)
    {
        selected = new IStreamMintCounterPolicy.AllowlistProof[](1);
        selected[0] = proof;
    }

    function _authorize(
        StreamMintAllowlistGate gate,
        IStreamMintManager.MintBatch memory b,
        bytes32 nonce
    ) private view returns (IStreamMintManager.MintBatch memory) {
        b.authorizationId = gate.previewAuthorizationId(address(manager), address(this), b, nonce);
        return b;
    }

    function _value(address account, IStreamMintManager.CounterKeyMode keyMode)
        private
        view
        returns (uint64)
    {
        return _counterValue(ALLOWLIST, account, keyMode);
    }

    function _counterValue(bytes32 id, address account, IStreamMintManager.CounterKeyMode keyMode)
        private
        view
        returns (uint64)
    {
        bytes32 subject = manager.previewSubjectKey(
            keyMode,
            COLLECTION,
            ALLOW_PHASE,
            id,
            signer,
            account,
            address(this),
            address(0),
            keccak256("allowlist context")
        );
        return
            ledger.counterValue(
                manager.previewCounterValueKey(COLLECTION, ALLOW_PHASE, id, subject)
            );
    }

    function _nullifier(StreamMintAllowlistGate gate, bytes32 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_ALLOWLIST_GATE_NONCE_V1"),
                block.chainid,
                address(gate),
                address(manager),
                address(ledger),
                COLLECTION,
                ALLOW_PHASE,
                signer,
                nonce
            )
        );
    }

    function testConstructorInterfacesAndLegacyAbiFailClosed() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAllowlistGate.MintAllowlistGateInvalidConfiguration.selector
            )
        );
        new StreamMintAllowlistGate(0, ALLOWLIST);
        StreamMintAllowlistGate gate = new StreamMintAllowlistGate(bytes32(uint256(1)), ALLOWLIST);
        require(
            gate.supportsInterface(type(IStreamMintAllowlistGate).interfaceId),
            "allowlist interface"
        );
        require(gate.supportsInterface(type(IStreamMintBatchGate).interfaceId), "batch interface");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAllowlistGate.MintAllowlistGateFullBatchRequired.selector
            )
        );
        gate.validateMint(
            address(manager),
            address(this),
            COLLECTION,
            ALLOW_PHASE,
            signer,
            address(0),
            _one(ALICE),
            _one(ALICE),
            bytes32(0),
            bytes32(uint256(1)),
            ""
        );
    }

    function testRecipientProofsBindCanonicalResultAndLedgerConsumesExactCaps() public {
        (
            StreamMintAllowlistGate gate,
            IStreamMintCounterPolicy.AllowlistProof memory alice,
            IStreamMintCounterPolicy.AllowlistProof memory bob
        ) = _recipientGate(2, 1);
        address[] memory recipients = new address[](2);
        recipients[0] = ALICE;
        recipients[1] = BOB;
        IStreamMintCounterPolicy.AllowlistProof[] memory selected =
            new IStreamMintCounterPolicy.AllowlistProof[](2);
        selected[0] = alice;
        selected[1] = bob;
        IStreamMintManager.MintBatch memory b = _batch(recipients);
        b.resolverData = _resolver(selected);
        bytes32 nonce = keccak256("recipient batch nonce");
        b = _authorize(gate, b, nonce);

        require(
            gate.previewAuthorizationId(address(manager), address(this), b, nonce)
                == b.authorizationId,
            "stable preview"
        );
        IStreamMintGate.GateResult memory result = _directResult(gate, b, nonce);
        require(result.authorizationId == b.authorizationId, "exact authorization id");
        require(result.authorizer == address(0) && result.authorizerKind == 0, "NONE authorizer");
        require(result.maxQuantity == 2 && result.nullifiers.length == 1, "batch bounds");
        require(result.nullifiers[0] == _nullifier(gate, nonce), "stable nonce nullifier");
        require(
            result.authorizationId == _expectedAuthorization(gate, b, nonce, alice, bob),
            "canonical id"
        );
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = StreamMintCounterPolicy.allowlistLeaf(
            address(manager), COLLECTION, ALLOW_PHASE, ALLOWLIST, ALICE, alice
        );
        leaves[1] = StreamMintCounterPolicy.allowlistLeaf(
            address(manager), COLLECTION, ALLOW_PHASE, ALLOWLIST, BOB, bob
        );
        require(
            result.gateHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_GATE_RESULT_V1"),
                        gate.gateConfigHash(),
                        result.authorizationId,
                        keccak256(
                            abi.encode(
                                keccak256("6529STREAM_MINT_ALLOWLIST_GATE_LEAVES_V1"), leaves
                            )
                        )
                    )
                ),
            "canonical gate result"
        );

        manager.executeSingleStepMint(b, abi.encode(nonce));
        require(
            core.minted() == 2 && _value(ALICE, IStreamMintManager.CounterKeyMode.RECIPIENT) == 1,
            "alice consumed"
        );
        require(_value(BOB, IStreamMintManager.CounterKeyMode.RECIPIENT) == 1, "bob consumed");
        require(
            manager.isAuthorizationUsed(b.authorizationId)
                && manager.isNullifierUsed(result.nullifiers[0]),
            "ledger replay state"
        );
    }

    function testNonceReplayAndCapAccountingRemainIndependent() public {
        (StreamMintAllowlistGate gate, IStreamMintCounterPolicy.AllowlistProof memory alice,) =
            _recipientGate(2, 1);
        IStreamMintManager.MintBatch memory first = _batch(_one(ALICE));
        first.resolverData = _resolver(_singleProof(alice));
        bytes32 nonce = keccak256("stable nonce");
        first = _authorize(gate, first, nonce);
        manager.executeSingleStepMint(first, abi.encode(nonce));

        IStreamMintManager.MintBatch memory replay = _batch(_one(ALICE));
        replay.contextHash = keccak256("changed context");
        replay.resolverData = _resolver(_singleProof(alice));
        replay = _authorize(gate, replay, nonce);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.NullifierAlreadyConsumed.selector, _nullifier(gate, nonce)
            )
        );
        manager.executeSingleStepMint(replay, abi.encode(nonce));
        require(
            !manager.isAuthorizationUsed(replay.authorizationId), "changed payload id rolled back"
        );

        bytes32 secondNonce = keccak256("second nonce");
        replay.contextHash = keccak256("allowlist context");
        replay = _authorize(gate, replay, secondNonce);
        manager.executeSingleStepMint(replay, abi.encode(secondNonce));
        IStreamMintManager.MintBatch memory over = _batch(_one(ALICE));
        over.resolverData = _resolver(_singleProof(alice));
        bytes32 thirdNonce = keccak256("third nonce");
        over = _authorize(gate, over, thirdNonce);
        vm.expectRevert();
        manager.executeSingleStepMint(over, abi.encode(thirdNonce));
        require(
            core.minted() == 2 && _value(ALICE, IStreamMintManager.CounterKeyMode.RECIPIENT) == 2
                && !manager.isAuthorizationUsed(over.authorizationId)
                && !manager.isNullifierUsed(_nullifier(gate, thirdNonce)),
            "gate never substitutes for cap accounting"
        );
    }

    function testPayerUsesOneProofForWholeBatch() public {
        (StreamMintAllowlistGate gate, IStreamMintCounterPolicy.AllowlistProof memory proof) =
            _payerGate(2);
        address[] memory recipients = new address[](2);
        recipients[0] = ALICE;
        recipients[1] = BOB;
        IStreamMintManager.MintBatch memory b = _batch(recipients);
        b.resolverData = _resolver(_singleProof(proof));
        bytes32 nonce = keccak256("payer batch nonce");
        b = _authorize(gate, b, nonce);
        manager.executeSingleStepMint(b, abi.encode(nonce));
        require(
            _value(signer, IStreamMintManager.CounterKeyMode.PAYER) == 2,
            "one payer proof, two debits"
        );
    }

    function testProofGroupsFollowConfiguredMerkleCounterOrder() public {
        IStreamMintCounterPolicy.AllowlistProof memory leading = _proof(1);
        IStreamMintCounterPolicy.AllowlistProof memory selected = _proof(1);
        bytes32 leadingRoot = StreamMintCounterPolicy.allowlistLeaf(
            address(manager), COLLECTION, ALLOW_PHASE, LEADING_ALLOWLIST, signer, leading
        );
        bytes32 selectedRoot = StreamMintCounterPolicy.allowlistLeaf(
            address(manager), COLLECTION, ALLOW_PHASE, ALLOWLIST, ALICE, selected
        );
        StreamMintAllowlistGate gate = new StreamMintAllowlistGate(selectedRoot, ALLOWLIST);
        _registerGate(address(gate));
        bytes32 leadingDefinition = ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                IStreamMintCounterPolicy.CounterScope.PHASE,
                IStreamMintManager.CounterKeyMode.PAYER,
                leadingRoot,
                keccak256("leading published list")
            )
        );
        bytes32 selectedDefinition = ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                IStreamMintCounterPolicy.CounterScope.PHASE,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                selectedRoot,
                keccak256("selected published list")
            )
        );
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = LEADING_ALLOWLIST;
        ids[1] = ALLOWLIST;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](2);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            leadingDefinition
        );
        counters[1] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            selectedDefinition
        );
        IStreamMintManager.MintGateConfig memory gateConfig;
        gateConfig.gate = address(gate);
        gateConfig.gateConfigHash = gate.gateConfigHash();
        manager.configurePhase(
            COLLECTION,
            ALLOW_PHASE,
            IStreamMintManager.MintPhaseConfig(
                false, 0, 0, 10, keccak256("ordered allowlists"), keccak256("allowlist phase")
            ),
            gateConfig,
            ids,
            counters
        );
        manager.setPhaseExecutor(COLLECTION, ALLOW_PHASE, address(this), true);
        IStreamMintCounterPolicy.AllowlistProof[][] memory ordered =
            new IStreamMintCounterPolicy.AllowlistProof[][](2);
        ordered[0] = _singleProof(leading);
        ordered[1] = _singleProof(selected);
        IStreamMintManager.MintBatch memory b = _batch(_one(ALICE));
        b.resolverData = abi.encode(ordered);
        bytes32 nonce = keccak256("ordered groups");
        b = _authorize(gate, b, nonce);
        manager.executeSingleStepMint(b, abi.encode(nonce));
        require(
            _counterValue(LEADING_ALLOWLIST, signer, IStreamMintManager.CounterKeyMode.PAYER) == 1
                && _value(ALICE, IStreamMintManager.CounterKeyMode.RECIPIENT) == 1,
            "configured Merkle order"
        );
    }

    function testMalformedProofShapePayloadAndAuthorizationFailClosed() public {
        (StreamMintAllowlistGate gate, IStreamMintCounterPolicy.AllowlistProof memory alice,) =
            _recipientGate(2, 1);
        IStreamMintManager.MintBatch memory b = _batch(_one(ALICE));
        b.resolverData = _resolver(_singleProof(alice));
        bytes32 nonce = keccak256("negative nonce");
        b = _authorize(gate, b, nonce);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAllowlistGate.MintAllowlistGateManagerMismatch.selector, address(manager)
            )
        );
        gate.validateMintBatch(address(manager), address(this), b, abi.encode(nonce));

        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAllowlistGate.MintAllowlistGatePayloadMismatch.selector
            )
        );
        gate.validateMintBatch(address(manager), address(this), b, hex"01");

        IStreamMintManager.MintBatch memory wrongId = b;
        wrongId.authorizationId = bytes32(uint256(1));
        vm.prank(address(manager));
        vm.expectRevert();
        gate.validateMintBatch(address(manager), address(this), wrongId, abi.encode(nonce));

        alice.maxCount = 1;
        b.resolverData = _resolver(_singleProof(alice));
        vm.expectRevert();
        gate.previewAuthorizationId(address(manager), address(this), b, nonce);

        IStreamMintCounterPolicy.AllowlistProof[] memory none =
            new IStreamMintCounterPolicy.AllowlistProof[](0);
        b.resolverData = _resolver(none);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistProofCountMismatch.selector,
                uint256(0),
                uint256(1)
            )
        );
        gate.previewAuthorizationId(address(manager), address(this), b, nonce);
    }

    function _directResult(
        StreamMintAllowlistGate gate,
        IStreamMintManager.MintBatch memory b,
        bytes32 nonce
    ) private returns (IStreamMintGate.GateResult memory result) {
        vm.prank(address(manager));
        return gate.validateMintBatch(address(manager), address(this), b, abi.encode(nonce));
    }

    function _expectedAuthorization(
        StreamMintAllowlistGate gate,
        IStreamMintManager.MintBatch memory b,
        bytes32 nonce,
        IStreamMintCounterPolicy.AllowlistProof memory alice,
        IStreamMintCounterPolicy.AllowlistProof memory bob
    ) private view returns (bytes32) {
        bytes32[] memory values = new bytes32[](2);
        values[0] =
            keccak256(abi.encode(alice.maxCount, alice.hasPriceOverride, alice.priceOverride));
        values[1] = keccak256(abi.encode(bob.maxCount, bob.hasPriceOverride, bob.priceOverride));
        bytes32[] memory groups = new bytes32[](1);
        groups[0] = keccak256(abi.encode(ALLOWLIST, values));
        ExpectedBinding memory binding = ExpectedBinding(
            address(manager),
            address(ledger),
            address(this),
            b.collectionId,
            b.phaseId,
            b.payer,
            b.expectedPolicyHash,
            b.contextHash,
            keccak256(
                abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
            ),
            keccak256(
                abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
            ),
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData)),
            keccak256(
                abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
            ),
            keccak256(
                abi.encode(keccak256("6529STREAM_MINT_ALLOWLIST_GATE_PROOF_VALUES_V1"), groups)
            ),
            nonce
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_ALLOWLIST_GATE_AUTHORIZATION_V1"),
                block.chainid,
                address(gate),
                gate.gateConfigHash(),
                binding
            )
        );
    }

    function _registerGate(address gate) private {
        bytes32 version = keccak256("allowlist gate v1");
        bytes32 manifest = keccak256(abi.encode("allowlist gate manifest", gate));
        StreamModuleRegistration memory registration = StreamModuleRegistration(
            gate,
            keccak256("6529STREAM_MINT_GATE_V1"),
            version,
            type(IStreamMintGate).interfaceId,
            600000,
            gate.codehash,
            keccak256("local allowlist gate deployment"),
            manifest,
            "urn:stream:mint-allowlist-gate"
        );
        (bytes32 scope, bytes32 oldState, bytes32 nextState) = _registrationTransition(registration);
        authority.setCurrentAction(true, bytes32(++actionNonce), 1, scope, oldState, nextState);
        vm.prank(address(authority));
        registry.registerModule(registration);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _registrationTransition(StreamModuleRegistration memory registration)
        private
        view
        returns (bytes32 scope, bytes32 oldState, bytes32 nextState)
    {
        uint256 count = registry.moduleCount();
        (bytes32 chain, uint64 recordCount) = registry.registrationChainHash();
        bytes32 record = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                registration.module,
                registration.moduleType,
                registration.interfaceId,
                registration.moduleVersion,
                registration.expectedRuntimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                registry.STREAM_RECORD_CHAIN_V1(),
                block.chainid,
                address(registry),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                chain,
                record,
                recordCount
            )
        );
        scope = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_SCOPE_V1(),
                block.chainid,
                address(registry),
                registration.module
            )
        );
        StreamModuleRegistration memory empty;
        oldState = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                false,
                _recordFacts(ModuleRegistryStatus.UNKNOWN, empty, 0),
                count,
                chain,
                recordCount,
                address(0)
            )
        );
        nextState = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                true,
                _recordFacts(ModuleRegistryStatus.ACTIVE, registration, 1),
                count + 1,
                nextChain,
                recordCount + 1,
                registration.module
            )
        );
    }

    function _recordFacts(
        ModuleRegistryStatus status,
        StreamModuleRegistration memory registration,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                registration.moduleType,
                registration.moduleVersion,
                registration.interfaceId,
                registration.moduleGasLimit,
                registration.expectedRuntimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash,
                keccak256(bytes(registration.moduleManifestURI)),
                revision
            )
        );
    }
}
