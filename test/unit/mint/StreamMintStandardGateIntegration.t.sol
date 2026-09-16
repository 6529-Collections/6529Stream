// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/mint/StreamMintTicketGate.sol";
import "../../../smart-contracts/domains/mint/StreamDelegateRegistryGate.sol";

/// @dev Explicit delegate.xyz-v2-compatible provider seam; not deployed upstream registry bytecode.
contract StandardGateDelegateProvider {
    mapping(bytes32 => bool) private _grants;

    function delegateContract(address to, address contract_, bytes32 rights, bool enable)
        external
        returns (bytes32 hash)
    {
        hash = keccak256(abi.encode(msg.sender, to, contract_, rights));
        _grants[hash] = enable;
    }

    function checkDelegateForContract(address to, address from, address contract_, bytes32 rights)
        external
        view
        returns (bool)
    {
        return _grants[keccak256(abi.encode(from, to, contract_, bytes32(0)))]
            || _grants[keccak256(abi.encode(from, to, contract_, rights))];
    }
}

/// @notice Actual gates, Manager, Ledger, ModuleRegistry and Safe1.4.1 form this composition.
/// @dev Core receipt/pointers, Artist consent, v2 delegation provider and Governance-V2 context
///      are explicit typed fixtures. This suite does not claim full current Core or upstream
///      registry runtime acceptance, Safe ERC721 delivery callbacks, or governance delay proof.
contract StreamMintStandardGateIntegrationTest is MintEngineTestBase, OfficialSafeFixture {
    bytes32 private constant COUNTER = keccak256("standard gate recipient counter");
    bytes32 private constant USECASE = keccak256("standard gate vault mint usecase");
    address private constant HOT_ONE = address(0xA101);
    address private constant HOT_TWO = address(0xA102);
    address private constant RECIPIENT = address(0xAC01);
    uint256 private actionNonce;

    function _configure(address gate, bytes32 config, bytes32 version, bytes32 manifest, uint64 cap)
        private
    {
        _registerGate(gate, version, manifest);
        IStreamMintManager.MintGateConfig memory gc;
        gc.gate = gate;
        gc.gateConfigHash = config;
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            cap,
            1,
            keccak256("recipient allowance policy")
        );
        manager.configurePhase(
            1,
            PHASE,
            IStreamMintManager.MintPhaseConfig(
                false, 0, 0, 10, keccak256("standard gate phase"), keccak256("phase metadata")
            ),
            gc,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, PHASE, address(this), true);
        StreamModuleRecord memory record = registry.moduleRecord(gate);
        IStreamMintManager.MintGateConfig memory active = manager.phaseGate(1, PHASE);
        require(
            record.status == ModuleRegistryStatus.ACTIVE && record.runtimeCodeHash == gate.codehash,
            "actual registry admission"
        );
        require(
            active.gateCodehash == gate.codehash
                && active.gateMetadataHash == keccak256(abi.encode(version, manifest)),
            "actual Manager pins"
        );
        require(active.gateGasLimit == 600000, "outer cap sized for nested signature check");
    }

    function _ticketGate(address authorizer, uint8 kind)
        private
        returns (StreamMintTicketGate gate)
    {
        gate = new StreamMintTicketGate(address(authority), authorizer, kind);
        _configure(
            address(gate),
            gate.gateConfigHash(),
            keccak256("standard ticket gate v1"),
            keccak256(abi.encode("ticket gate manifest", address(gate), gate.gateConfigHash())),
            10
        );
    }

    function _delegateGate()
        private
        returns (StreamDelegateRegistryGate gate, StandardGateDelegateProvider provider)
    {
        provider = new StandardGateDelegateProvider();
        gate = new StreamDelegateRegistryGate(
            address(core), address(provider), USECASE, address(authority)
        );
        _configure(
            address(gate),
            gate.gateConfigHash(),
            gate.MODULE_VERSION(),
            gate.moduleManifestHash(),
            2
        );
    }

    function _safe() private returns (OfficialSafe account, uint256[] memory keys) {
        keys = new uint256[](2);
        keys[0] = 0x71AB01;
        keys[1] = 0x71AB02;
        uint256[] memory owners = new uint256[](3);
        owners[0] = keys[0];
        owners[1] = keys[1];
        owners[2] = 0x71AB03;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 1);
        require(keccak256(bytes(account.VERSION())) == keccak256("1.4.1"), "real Safe version");
    }

    function _ticketBatch(StreamMintTicketGate gate, uint256 nonce, address recipient)
        private
        view
        returns (IStreamMintManager.MintBatch memory b, StreamMintTicketTypes.MintTicket memory t)
    {
        b = _batch(0);
        b.authorizer = gate.ticketSigner();
        b.initialRecipients[0] = recipient;
        b.beneficiaries[0] = recipient;
        t = _ticket(nonce);
        t.authorizer = b.authorizer;
        t.authorizerKind = gate.ticketSignerKind();
        t.contextHash = b.contextHash;
        t.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        t.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        t.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        t.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        b.authorizationId = manager.mintTicketAuthorizationId(t, address(gate));
        require(
            b.authorizationId
                == StreamMintTicketHash.authorizationId(
                    StreamMintTicketHash.digest(block.chainid, address(gate), t)
                ),
            "revocation and positive consumer exact ID"
        );
    }

    function _ticketProof(StreamMintTicketGate gate, StreamMintTicketTypes.MintTicket memory t)
        private
        returns (bytes memory)
    {
        return abi.encode(
            t, _signature(SIGNER_KEY, StreamMintTicketHash.digest(block.chainid, address(gate), t))
        );
    }

    function _safeTicketProof(
        StreamMintTicketGate gate,
        StreamMintTicketTypes.MintTicket memory t,
        OfficialSafe account,
        uint256[] memory keys
    ) private returns (bytes memory) {
        bytes32 digest = StreamMintTicketHash.digest(block.chainid, address(gate), t);
        return abi.encode(
            t, safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)))
        );
    }

    function _counterKey(address recipient) private view returns (bytes32) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            PHASE,
            COUNTER,
            signer,
            recipient,
            address(this),
            address(0),
            bytes32(0)
        );
        return manager.previewCounterValueKey(1, PHASE, COUNTER, subject);
    }

    function _mint(IStreamMintManager.MintBatch memory b, bytes memory data)
        private
        returns (bytes32 root)
    {
        (uint256[] memory ids, bytes32 operationRoot, bytes32[] memory operations) =
            manager.executeSingleStepMint(b, data);
        require(
            ids.length == 1 && operations.length == 1 && operations[0] != 0, "actual Manager result"
        );
        require(
            MintEngineCoreFixture(address(core)).ownerOf(ids[0]) == b.initialRecipients[0],
            "typed Core receipt owner"
        );
        require(
            manager.isAuthorizationUsed(b.authorizationId)
                && ledger.isManagerAuthorizationUsed(address(manager), b.authorizationId),
            "actual Ledger consumed exact authorization"
        );
        require(manager.isOperationRootUsed(operationRoot), "actual Ledger operation replay");
        return operationRoot;
    }

    function testEOATicketConsumesExactLedgerIdAndEmitsManagerAndLedgerEvidence() public {
        StreamMintTicketGate gate = _ticketGate(signer, 1);
        (IStreamMintManager.MintBatch memory b, StreamMintTicketTypes.MintTicket memory t) =
            _ticketBatch(gate, 1, RECIPIENT);
        bytes memory proof = _ticketProof(gate, t);
        vm.recordLogs();
        bytes32 root = _mint(b, proof);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool gateEvent;
        bool ledgerEvent;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(manager)
                    && logs[i].topics[0]
                        == keccak256(
                            "MintGateValidated(uint256,bytes32,address,bytes32,address,uint256,bytes32,bytes32,bytes32)"
                        )
            ) gateEvent = true;
            if (
                logs[i].emitter == address(ledger)
                    && logs[i].topics[0]
                        == keccak256(
                            "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
                        )
            ) {
                ledgerEvent = logs[i].topics[1] == b.authorizationId && logs[i].topics[2] == root
                    && address(uint160(uint256(logs[i].topics[3]))) == address(manager);
            }
        }
        require(
            gateEvent && ledgerEvent && ledger.counterValue(_counterKey(RECIPIENT)) == 1,
            "gate and durable accounting evidence"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        manager.executeSingleStepMint(b, proof);
        require(core.minted() == 1 && manager.nextOperationNonce() == 1, "replay is atomic");
    }

    function testActualSafeTicketSignerJoinsManagerLedgerAndReceipt() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        StreamMintTicketGate gate = _ticketGate(address(account), 2);
        (IStreamMintManager.MintBatch memory b, StreamMintTicketTypes.MintTicket memory t) =
            _ticketBatch(gate, 2, address(account));
        _mint(b, _safeTicketProof(gate, t, account, keys));
        require(ledger.counterValue(_counterKey(address(account))) == 1, "Safe recipient counted");
        require(
            b.payer != b.authorizer && b.payer != address(this), "payer signer executor separated"
        );
    }

    function testTicketPayloadMutationAndCoreFailureRollBackAuthorizationCounterAndNonce() public {
        StreamMintTicketGate gate = _ticketGate(signer, 1);
        (IStreamMintManager.MintBatch memory b, StreamMintTicketTypes.MintTicket memory t) =
            _ticketBatch(gate, 3, RECIPIENT);
        bytes memory proof = _ticketProof(gate, t);
        bytes memory original = b.tokenData[0];
        b.tokenData[0] = hex"deadbeef";
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintGateValidator.MintGateCallFailed.selector, address(gate)
            )
        );
        manager.executeSingleStepMint(b, proof);
        require(
            !manager.isAuthorizationUsed(b.authorizationId) && manager.nextOperationNonce() == 0
                && ledger.counterValue(_counterKey(RECIPIENT)) == 0,
            "bad payload no effects"
        );
        b.tokenData[0] = original;
        MintEngineCoreFixture(address(core)).setRejectMint(true);
        vm.expectRevert();
        manager.executeSingleStepMint(b, proof);
        require(
            !manager.isAuthorizationUsed(b.authorizationId) && manager.nextOperationNonce() == 0
                && ledger.counterValue(_counterKey(RECIPIENT)) == 0,
            "Core revert rolls Ledger back"
        );
        MintEngineCoreFixture(address(core)).setRejectMint(false);
        _mint(b, proof);
    }

    function testEOADirectTicketVoidPreventsSignedMintAndConsumedTicketCannotVoid() public {
        StreamMintTicketGate gate = _ticketGate(signer, 1);
        (IStreamMintManager.MintBatch memory b, StreamMintTicketTypes.MintTicket memory t) =
            _ticketBatch(gate, 4, RECIPIENT);
        bytes memory proof = _ticketProof(gate, t);
        vm.prank(signer);
        manager.voidMintTicket(t, address(gate), hex"");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        manager.executeSingleStepMint(b, proof);
        require(
            core.minted() == 0 && ledger.counterValue(_counterKey(RECIPIENT)) == 0,
            "void consumes only replay ID"
        );
        (b, t) = _ticketBatch(gate, 5, RECIPIENT);
        _mint(b, _ticketProof(gate, t));
        vm.prank(signer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        manager.voidMintTicket(t, address(gate), hex"");
    }

    function testActualSafeDirectTicketRevocationPreventsPositiveGateConsumption() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        StreamMintTicketGate gate = _ticketGate(address(account), 2);
        (IStreamMintManager.MintBatch memory b, StreamMintTicketTypes.MintTicket memory t) =
            _ticketBatch(gate, 6, address(account));
        bytes memory proof = _safeTicketProof(gate, t, account, keys);
        require(
            executeSafe(
                account,
                keys,
                address(manager),
                0,
                abi.encodeCall(manager.voidMintTicket, (t, address(gate), bytes(""))),
                0
            ),
            "actual Safe void transaction"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        manager.executeSingleStepMint(b, proof);
        require(core.minted() == 0 && manager.nextOperationNonce() == 0, "Safe void no mint");
    }

    function testActualSafeRelayedRevocationRequiresSeparateRevocationEnvelope() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        StreamMintTicketGate gate = _ticketGate(address(account), 2);
        (IStreamMintManager.MintBatch memory b, StreamMintTicketTypes.MintTicket memory t) =
            _ticketBatch(gate, 7, address(account));
        bytes memory proof = _safeTicketProof(gate, t, account, keys);
        (, bytes memory originalSignature) =
            abi.decode(proof, (StreamMintTicketTypes.MintTicket, bytes));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector,
                address(account)
            )
        );
        manager.voidMintTicket(t, address(gate), originalSignature);
        bytes32 revocation = _revokeDigest(
            StreamMintTicketHash.domain(block.chainid, address(gate)), b.authorizationId
        );
        bytes memory signature =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(revocation)));
        manager.voidMintTicket(t, address(gate), signature);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        manager.executeSingleStepMint(b, proof);
    }

    function _grant(
        OfficialSafe vault,
        uint256[] memory keys,
        StandardGateDelegateProvider provider,
        address hot,
        bool enabled
    ) private {
        require(
            executeSafe(
                vault,
                keys,
                address(provider),
                0,
                abi.encodeCall(provider.delegateContract, (hot, address(core), USECASE, enabled)),
                0
            ),
            "real Safe grant/revoke transaction"
        );
    }

    function _delegateBatch(
        StreamDelegateRegistryGate gate,
        address vault,
        address hot,
        bytes32 nonce
    )
        private
        view
        returns (IStreamMintManager.MintBatch memory b, bytes memory proof, bytes32 nullifier)
    {
        b = _batch(0);
        b.payer = hot;
        b.initialRecipients[0] = vault;
        b.beneficiaries[0] = vault;
        proof = abi.encode(vault, nonce);
        b.authorizationId = _delegateId(gate, b, proof);
        nullifier = keccak256(
            abi.encode(
                keccak256("6529STREAM_DELEGATE_MINT_NONCE_V1"),
                block.chainid,
                address(gate),
                address(manager),
                b.collectionId,
                b.phaseId,
                hot,
                vault,
                nonce
            )
        );
    }

    function _delegateId(
        StreamDelegateRegistryGate gate,
        IStreamMintManager.MintBatch memory b,
        bytes memory proof
    ) private view returns (bytes32) {
        StreamDelegateRegistryGate.MintRequest memory r =
            StreamDelegateRegistryGate.MintRequest(
                address(manager),
                address(this),
                b.collectionId,
                b.phaseId,
                b.payer,
                b.authorizer,
                b.initialRecipients,
                b.beneficiaries,
                b.contextHash,
                b.expectedPolicyHash,
                proof
            );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DELEGATE_MINT_AUTHORIZATION_V1"),
                block.chainid,
                address(gate),
                gate.gateConfigHash(),
                r
            )
        );
    }

    function testTwoHotWalletsShareActualLedgerVaultRecipientCap() public {
        (OfficialSafe vault, uint256[] memory keys) = _safe();
        (StreamDelegateRegistryGate gate, StandardGateDelegateProvider provider) = _delegateGate();
        _grant(vault, keys, provider, HOT_ONE, true);
        _grant(vault, keys, provider, HOT_TWO, true);
        (IStreamMintManager.MintBatch memory a, bytes memory first, bytes32 n1) =
            _delegateBatch(gate, address(vault), HOT_ONE, bytes32(uint256(1)));
        _mint(a, first);
        (IStreamMintManager.MintBatch memory b, bytes memory second, bytes32 n2) =
            _delegateBatch(gate, address(vault), HOT_TWO, bytes32(uint256(2)));
        _mint(b, second);
        require(
            manager.isNullifierUsed(n1) && manager.isNullifierUsed(n2),
            "actual Ledger consumed gate nonces"
        );
        bytes32 key = _counterKey(address(vault));
        require(
            ledger.counterValue(key) == 2 && ledger.counterValue(_counterKey(HOT_ONE)) == 0
                && ledger.counterValue(_counterKey(HOT_TWO)) == 0,
            "allowance keyed to vault only"
        );
        (IStreamMintManager.MintBatch memory c, bytes memory third, bytes32 n3) =
            _delegateBatch(gate, address(vault), HOT_ONE, bytes32(uint256(3)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector, key, uint256(3), uint256(2)
            )
        );
        manager.executeSingleStepMint(c, third);
        require(
            !manager.isAuthorizationUsed(c.authorizationId) && !manager.isNullifierUsed(n3)
                && core.minted() == 2,
            "fresh nonce cannot reset vault allowance"
        );
    }

    function testLiveSafeDelegationRevocationRejectsNextMintButRetainsOtherDelegate() public {
        (OfficialSafe vault, uint256[] memory keys) = _safe();
        (StreamDelegateRegistryGate gate, StandardGateDelegateProvider provider) = _delegateGate();
        _grant(vault, keys, provider, HOT_ONE, true);
        _grant(vault, keys, provider, HOT_TWO, true);
        _grant(vault, keys, provider, HOT_ONE, false);
        (IStreamMintManager.MintBatch memory b, bytes memory proof, bytes32 nullifier) =
            _delegateBatch(gate, address(vault), HOT_ONE, bytes32(uint256(4)));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintGateValidator.MintGateCallFailed.selector, address(gate)
            )
        );
        manager.executeSingleStepMint(b, proof);
        require(
            !manager.isAuthorizationUsed(b.authorizationId) && !manager.isNullifierUsed(nullifier)
                && ledger.counterValue(_counterKey(address(vault))) == 0,
            "revoked delegate no effects"
        );
        (b, proof,) = _delegateBatch(gate, address(vault), HOT_TWO, bytes32(uint256(4)));
        _mint(b, proof);
    }

    function testActualLedgerNullifierRejectsChangedContextReplay() public {
        (OfficialSafe vault, uint256[] memory keys) = _safe();
        (StreamDelegateRegistryGate gate, StandardGateDelegateProvider provider) = _delegateGate();
        _grant(vault, keys, provider, HOT_ONE, true);
        (IStreamMintManager.MintBatch memory b, bytes memory proof, bytes32 nullifier) =
            _delegateBatch(gate, address(vault), HOT_ONE, bytes32(uint256(5)));
        _mint(b, proof);
        b.contextHash = keccak256("different context same gate nonce");
        b.authorizationId = _delegateId(gate, b, proof);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.NullifierAlreadyConsumed.selector, nullifier)
        );
        manager.executeSingleStepMint(b, proof);
        require(
            !manager.isAuthorizationUsed(b.authorizationId)
                && ledger.counterValue(_counterKey(address(vault))) == 1 && core.minted() == 1,
            "nullifier rollback includes new authorization"
        );
    }

    function testWrongDelegateDeliveryAndBeneficiaryFailThroughActualManager() public {
        (OfficialSafe vault, uint256[] memory keys) = _safe();
        (StreamDelegateRegistryGate gate, StandardGateDelegateProvider provider) = _delegateGate();
        _grant(vault, keys, provider, HOT_ONE, true);
        for (uint256 i; i < 2; ++i) {
            (IStreamMintManager.MintBatch memory b, bytes memory proof, bytes32 nullifier) =
                _delegateBatch(gate, address(vault), HOT_ONE, bytes32(uint256(6)));
            if (i == 0) b.initialRecipients[0] = HOT_ONE;
            else b.beneficiaries[0] = HOT_ONE;
            b.authorizationId = _delegateId(gate, b, proof);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMintGateValidator.MintGateCallFailed.selector, address(gate)
                )
            );
            manager.executeSingleStepMint(b, proof);
            require(
                !manager.isAuthorizationUsed(b.authorizationId)
                    && !manager.isNullifierUsed(nullifier),
                "wrong route not consumed"
            );
        }
        require(
            core.minted() == 0 && ledger.counterValue(_counterKey(address(vault))) == 0,
            "no wrong delivery or debit"
        );
    }

    function _registerGate(address gate, bytes32 version, bytes32 manifest) private {
        StreamModuleRegistration memory r = StreamModuleRegistration(
            gate,
            keccak256("6529STREAM_MINT_GATE_V1"),
            version,
            type(IStreamMintGate).interfaceId,
            600000,
            gate.codehash,
            keccak256("local composition deployment"),
            manifest,
            "urn:stream:standard-gate-composition"
        );
        (bytes32 scope, bytes32 oldState, bytes32 nextState) = _registrationTransition(r);
        authority.setCurrentAction(true, bytes32(++actionNonce), 1, scope, oldState, nextState);
        vm.prank(address(authority));
        registry.registerModule(r);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _registrationTransition(StreamModuleRegistration memory r)
        private
        view
        returns (bytes32 scope, bytes32 oldState, bytes32 nextState)
    {
        uint256 count = registry.moduleCount();
        (bytes32 chain, uint64 recordCount) = registry.registrationChainHash();
        bytes32 record = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                r.module,
                r.moduleType,
                r.interfaceId,
                r.moduleVersion,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash
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
                r.module
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
                _recordFacts(ModuleRegistryStatus.ACTIVE, r, 1),
                count + 1,
                nextChain,
                recordCount + 1,
                r.module
            )
        );
    }

    function _recordFacts(
        ModuleRegistryStatus status,
        StreamModuleRegistration memory r,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                r.moduleType,
                r.moduleVersion,
                r.interfaceId,
                r.moduleGasLimit,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash,
                keccak256(bytes(r.moduleManifestURI)),
                revision
            )
        );
    }
}
