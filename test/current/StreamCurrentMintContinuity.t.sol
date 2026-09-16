// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintBatchGate.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintLedgerImport.sol";

/// @dev The only eligibility substitute: a lifetime entitlement independent of Manager/Ledger.
/// Authorization still binds the actual caller, Manager, Ledger and every batch field.
/// No first-party launch gate currently supplies this migration-stable entitlement identity.
contract CurrentContinuityEntitlementGate is IStreamMintBatchGate {
    address public immutable core;
    address public immutable predecessor;
    address public immutable successor;
    bytes32 public immutable phase;

    constructor(address core_, address predecessor_, address successor_, bytes32 phase_) {
        core = core_;
        predecessor = predecessor_;
        successor = successor_;
        phase = phase_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamMintBatchGate).interfaceId;
    }

    function validateMint(
        address,
        address,
        uint256,
        bytes32,
        address,
        address,
        address[] calldata,
        address[] calldata,
        bytes32,
        bytes32,
        bytes calldata
    ) external pure returns (IStreamMintGate.GateResult memory) {
        revert("full batch required");
    }

    function claimNullifier(bytes32 claim) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("TEST_CURRENT_MINT_LIFETIME_ENTITLEMENT_V1"),
                block.chainid,
                core,
                phase,
                claim
            )
        );
    }

    function authorization(
        address manager_,
        address caller,
        IStreamMintManager.MintBatch memory batch,
        bytes32 claim,
        bytes32 nonce
    ) public view returns (bytes32) {
        require(manager_ == predecessor || manager_ == successor, "intended Manager");
        require(batch.collectionId == 1 && batch.phaseId == phase, "intended phase");
        batch.authorizationId = 0;
        return keccak256(
            abi.encode(
                keccak256("TEST_CURRENT_MINT_ENTITLEMENT_AUTHORIZATION_V1"),
                block.chainid,
                address(this),
                manager_,
                address(StreamMintManager(manager_).mintLedger()),
                caller,
                batch,
                claim,
                nonce
            )
        );
    }

    function validateMintBatch(
        address manager_,
        address caller,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata data
    ) external view returns (IStreamMintGate.GateResult memory result) {
        require(msg.sender == manager_ && batch.authorizer == address(0), "actual Manager CALL");
        (bytes32 claim, bytes32 nonce) = abi.decode(data, (bytes32, bytes32));
        result.authorizationId = authorization(manager_, caller, batch, claim, nonce);
        require(result.authorizationId == batch.authorizationId, "exact authorization");
        result.nullifiers = new bytes32[](1);
        result.nullifiers[0] = claimNullifier(claim);
        result.maxQuantity = 1;
        result.gateHash = keccak256(abi.encode(result.authorizationId, result.nullifiers));
    }
}

/// @notice Actual current Core, Artist, Manager/Ledger, registry, manifest and Safe governance.
/// @dev The external entropy provider and lifetime eligibility gate are explicit test inputs.
/// Native runtime acceptance is pending the coordinator's frozen current-graph capture.
contract StreamCurrentMintContinuityTest is StreamCurrentSafeGovernanceFixture {
    bytes32 private constant CONTINUITY_PHASE = keccak256("current continuity phase");
    bytes32 private constant GLOBAL_COUNTER = keccak256("global recipient lifetime");
    bytes32 private constant COLLECTION_COUNTER = keccak256("collection lifetime");
    bytes32 private constant CLAIM = keccak256("original lifetime claim");
    bytes32 private constant SNAPSHOT_MANIFEST = keccak256("complete local continuity manifest");
    bytes32 private constant MANAGER_POINTER = keccak256("MINT_MANAGER");
    bytes32 private constant LEDGER_POINTER = keccak256("MINT_LEDGER");
    bytes32 private constant MODULE_VERSION = keccak256("current continuity v1");
    bytes32 private constant GATE_MANIFEST = keccak256("explicit test entitlement boundary");

    bool private replaceLedger;
    StreamMintLedger private nextLedger;
    StreamMintManager private successor;
    StreamMintManager private wrongSuccessor;
    CurrentContinuityEntitlementGate private gate;
    OfficialSafe private continuitySafe;
    uint256[] private signingKeys;
    bytes32 private globalDefinition;
    bytes32 private collectionDefinition;
    bytes32 private paidOperation;
    bytes32 private originalAuthorization;
    bytes32 private originalOperation;
    IStreamMintLedgerImport.CounterImportLeaf[] private leaves;
    bytes32[15] private tree;
    uint64 private snapshotBlock;

    function _setup(bool newLedger) private {
        replaceLedger = newLedger;
        vm.roll(20);
        vm.deal(address(this), 1 ether);
        signingKeys.push(0xC01101);
        signingKeys.push(0xC01102);
        continuitySafe = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(signingKeys), 2, 651
        );
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(continuitySafe, signingKeys);
        _registerCandidates();
        _paidMint();
        globalDefinition = ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                IStreamMintCounterPolicy.CounterScope.GLOBAL,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                0,
                keccak256("global profile")
            )
        );
        collectionDefinition = ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                IStreamMintCounterPolicy.CounterScope.COLLECTION,
                IStreamMintManager.CounterKeyMode.CONSTANT,
                0,
                keccak256("collection profile")
            )
        );
        _configure(manager);
        (IStreamMintManager.MintBatch memory batch, bytes memory data) =
            _mintRequest(manager, CLAIM, keccak256("original authorization nonce"));
        originalAuthorization = batch.authorizationId;
        vm.recordLogs();
        this.executeCurrentGovernorCall(
            address(manager), abi.encodeCall(manager.executeSingleStepMint, (batch, data))
        );
        require(core.collectionMintedEver(1) == 2 && core.ownerOf(2) == BUYER, "actual second mint");
        require(
            ledger.isManagerNullifierUsed(address(manager), gate.claimNullifier(CLAIM)),
            "gate consumed normally"
        );
        require(
            ledger.isManagerAuthorizationUsed(address(manager), originalAuthorization),
            "original authorization consumed"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventTopic = keccak256(
            "MintLedgerOperationRootConsumed(uint16,bytes32,address,bytes32,bytes32,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(ledger) && logs[i].topics.length == 4
                    && logs[i].topics[0] == eventTopic
                    && logs[i].topics[2] == bytes32(uint256(uint160(address(manager))))
            ) {
                require(originalOperation == 0, "one operation");
                originalOperation = logs[i].topics[1];
            }
        }
        require(
            originalOperation != 0 && manager.isOperationRootUsed(originalOperation),
            "event-derived actual operation"
        );
        snapshotBlock = uint64(block.number);
    }

    function _deployAdditionalProducts() internal override {
        nextLedger = replaceLedger
            ? StreamMintLedger(
                _artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamMintLedger.sol:StreamMintLedger", ""
                )
            )
            : ledger;
        successor = _newManager(nextLedger);
        wrongSuccessor = _newManager(nextLedger);
        nextLedger.setLedgerWriter(address(successor), true);
        nextLedger.setLedgerWriter(address(wrongSuccessor), true);
        successor.transferOwnership(address(executor));
        wrongSuccessor.transferOwnership(address(executor));
        if (replaceLedger) nextLedger.transferOwnership(address(executor));
        gate = new CurrentContinuityEntitlementGate(
            address(core), address(manager), address(successor), CONTINUITY_PHASE
        );
    }

    function _newManager(StreamMintLedger target) private returns (StreamMintManager) {
        return StreamMintManager(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager",
                abi.encode(core, target, IERC165(address(registry)))
            )
        );
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](6);
        rows[0] = _policy(address(ledger), ledger.retireLedgerWriter.selector);
        rows[1] = _policy(address(nextLedger), nextLedger.commitCounterImportRoot.selector);
        rows[2] = _policy(address(successor), successor.importMintState.selector);
        rows[3] = _policy(address(successor), successor.configurePhase.selector);
        rows[4] = _policy(address(successor), successor.setPhaseExecutor.selector);
        rows[5] = _policy(address(successor), successor.raiseGasParameter.selector);
    }

    function _policy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1, target, selector, target.codehash, DEPLOYMENT_HASH, 1, 0, 0, 0
        );
    }

    function _candidateRecord(address target, bytes32 kind, bytes4 interfaceId, bytes32 content)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return StreamModuleRegistration(
            target,
            kind,
            MODULE_VERSION,
            interfaceId,
            300_000,
            target.codehash,
            DEPLOYMENT_HASH,
            content,
            "urn:stream:current:mint-continuity"
        );
    }

    function _managerRecord(StreamMintManager target)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return _candidateRecord(
            address(target),
            MANAGER_POINTER,
            type(IStreamMintManager).interfaceId,
            keccak256(abi.encode("successor Manager", address(target)))
        );
    }

    function _ledgerRecord() private view returns (StreamModuleRegistration memory) {
        return _candidateRecord(
            address(nextLedger),
            LEDGER_POINTER,
            type(IStreamMintLedger).interfaceId,
            keccak256("successor Ledger")
        );
    }

    function _registerCandidates() private {
        StreamModuleRegistration[] memory records =
            new StreamModuleRegistration[](replaceLedger ? 4 : 3);
        records[0] = _managerRecord(successor);
        records[1] = _managerRecord(wrongSuccessor);
        records[2] = _candidateRecord(
            address(gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            type(IStreamMintGate).interfaceId,
            GATE_MANIFEST
        );
        if (replaceLedger) records[3] = _ledgerRecord();
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _runBatch(1, calls, data);
    }

    function _paidMint() private {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(this),
                recipient: BUYER,
                artist: artist,
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("paid before succession"),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256("paid baseline"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        (uint256 tokenId, bytes32 operation) = sale.buy{ value: a.price }(
            a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest)
        );
        require(
            tokenId == 1 && core.ownerOf(tokenId) == BUYER && wallet.balance == a.price,
            "real paid baseline"
        );
        paidOperation = operation;
    }

    function _phaseTerms()
        private
        view
        returns (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gateConfig,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory configs
        )
    {
        config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            1,
            keccak256("lifetime eligibility terms"),
            keccak256("published eligibility scope")
        );
        gateConfig = IStreamMintManager.MintGateConfig(
            address(gate),
            keccak256("test entitlement config"),
            address(gate).codehash,
            keccak256(abi.encode(MODULE_VERSION, GATE_MANIFEST)),
            0,
            300_000
        );
        ids = new bytes32[](2);
        ids[0] = GLOBAL_COUNTER;
        ids[1] = COLLECTION_COUNTER;
        configs = new IStreamMintManager.MintCounterConfig[](2);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            globalDefinition
        );
        configs[1] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            collectionDefinition
        );
    }

    function _configure(StreamMintManager target) private {
        (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gateConfig,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory configs
        ) = _phaseTerms();
        address[] memory enabled = new address[](0);
        _recordFixturePolicy(
            CONTINUITY_PHASE,
            target.previewPhasePolicyHash(
                1, CONTINUITY_PHASE, config, gateConfig, ids, configs, enabled
            )
        );
        _ordinary(
            address(target),
            abi.encodeCall(
                target.configurePhase, (1, CONTINUITY_PHASE, config, gateConfig, ids, configs)
            )
        );
        enabled = new address[](1);
        enabled[0] = address(continuitySafe);
        _recordFixturePolicy(
            CONTINUITY_PHASE,
            target.previewPhasePolicyHash(
                1, CONTINUITY_PHASE, config, gateConfig, ids, configs, enabled
            )
        );
        _ordinary(
            address(target),
            abi.encodeCall(
                target.setPhaseExecutor, (1, CONTINUITY_PHASE, address(continuitySafe), true)
            )
        );
    }

    function _mintRequest(StreamMintManager target, bytes32 claim, bytes32 nonce)
        private
        view
        returns (IStreamMintManager.MintBatch memory batch, bytes memory gateData)
    {
        batch.collectionId = 1;
        batch.phaseId = CONTINUITY_PHASE;
        batch.payer = BUYER;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = BUYER;
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = BUYER;
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = keccak256(abi.encode("continuity mint", nonce));
        batch.expectedPolicyHash = target.phasePolicyHash(1, CONTINUITY_PHASE);
        batch.contextHash = keccak256("original lifetime eligibility namespace");
        batch.authorizationId =
            gate.authorization(address(target), address(continuitySafe), batch, claim, nonce);
        gateData = abi.encode(claim, nonce);
    }

    function _ordinary(address target, bytes memory data) private returns (bytes32) {
        return _govern(
            _governanceRequest(
                1, target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
            )
        );
    }

    function _runBatch(uint8 cls, GovernanceCall[] memory calls, bytes[] memory data) private {
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(cls, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "executed batch"
        );
    }

    function _subject(
        StreamMintLedger target,
        IStreamMintLedgerImport.CounterImportLeaf memory leaf
    ) private view returns (bytes32) {
        if (leaf.keyMode == uint8(IStreamMintManager.CounterKeyMode.RECIPIENT)) {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                    block.chainid,
                    address(target),
                    IStreamMintManager.CounterKeyMode.RECIPIENT,
                    BUYER
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(target),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                leaf.collectionId,
                leaf.phaseId,
                leaf.counterId
            )
        );
    }

    function _buildTree() private {
        snapshotBlock = uint64(block.number);
        leaves.push(
            IStreamMintLedgerImport.CounterImportLeaf(
                1,
                PHASE,
                keccak256("supply"),
                uint8(IStreamMintManager.CounterKeyMode.CONSTANT),
                0,
                0,
                1
            )
        );
        leaves.push(
            IStreamMintLedgerImport.CounterImportLeaf(
                0,
                0,
                GLOBAL_COUNTER,
                uint8(IStreamMintManager.CounterKeyMode.RECIPIENT),
                bytes32(uint256(uint160(BUYER))),
                0,
                1
            )
        );
        leaves.push(
            IStreamMintLedgerImport.CounterImportLeaf(
                1, 0, COLLECTION_COUNTER, uint8(IStreamMintManager.CounterKeyMode.CONSTANT), 0, 0, 1
            )
        );
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i].predecessorSubjectKey = _subject(ledger, leaves[i]);
            require(
                _value(ledger, manager, leaves[i]) == 1, "snapshot reads actual predecessor counter"
            );
            tree[7 + i] = keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"),
                            block.chainid,
                            address(ledger),
                            address(manager),
                            leaves[i]
                        )
                    )
                )
            );
        }
        tree[10] = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(manager),
                        gate.claimNullifier(CLAIM)
                    )
                )
            )
        );
        tree[11] = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
                        block.chainid,
                        address(nextLedger),
                        address(ledger),
                        address(manager),
                        address(successor),
                        snapshotBlock,
                        SNAPSHOT_MANIFEST,
                        uint64(3),
                        uint64(1)
                    )
                )
            )
        );
        // Explicit fixed tree padding; there are exactly three counters and one raw nullifier.
        for (uint256 i = 12; i < 15; ++i) {
            tree[i] = tree[11];
        }
        for (uint256 i = 7; i > 0; --i) {
            tree[i - 1] = _pair(tree[2 * i - 1], tree[2 * i]);
        }
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _proof(uint256 index) private view returns (bytes32[] memory proof) {
        proof = new bytes32[](3);
        uint256 node = 7 + index;
        for (uint256 i; i < 3; ++i) {
            proof[i] = tree[node % 2 == 0 ? node - 1 : node + 1];
            node = (node - 1) / 2;
        }
    }

    function _value(
        StreamMintLedger target,
        StreamMintManager writer,
        IStreamMintLedgerImport.CounterImportLeaf memory leaf
    ) private view returns (uint64) {
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(writer),
                leaf.collectionId,
                leaf.phaseId,
                leaf.counterId,
                _subject(target, leaf)
            )
        );
        return target.counterValue(key);
    }

    function _commitRequest() private view returns (GovernanceActionRequest memory) {
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1"),
                block.chainid,
                address(nextLedger),
                address(successor)
            )
        );
        bytes32 value = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"),
                scope,
                address(ledger),
                address(manager),
                address(successor),
                snapshotBlock,
                tree[0],
                SNAPSHOT_MANIFEST
            )
        );
        return _governanceRequest(
            1,
            address(nextLedger),
            abi.encodeCall(
                nextLedger.commitCounterImportRoot,
                (
                    address(ledger),
                    address(manager),
                    address(successor),
                    snapshotBlock,
                    tree[0],
                    SNAPSHOT_MANIFEST
                )
            ),
            scope,
            0,
            value
        );
    }

    function _retire() private {
        _ordinary(address(ledger), abi.encodeCall(ledger.retireLedgerWriter, (address(manager))));
        require(
            !ledger.ledgerWriter(address(manager))
                && ledger.ledgerWriterRetiredAt(address(manager)) == snapshotBlock,
            "permanent actual predecessor retirement"
        );
    }

    function _importCall() private view returns (bytes memory) {
        return _importCall(false);
    }

    function _importCall(bool corruptLaterProof) private view returns (bytes memory) {
        IStreamMintManagerImport.ImportBatch memory batch;
        batch.importRoot = tree[0];
        batch.counters = new IStreamMintLedgerImport.CounterImportLeaf[](3);
        batch.counterProofs = new bytes32[][](3);
        for (uint256 i; i < 3; ++i) {
            batch.counters[i] = leaves[i];
            batch.counterProofs[i] = _proof(i);
        }
        if (corruptLaterProof) batch.counterProofs[2][0] ^= bytes32(uint256(1));
        batch.nullifiers = new bytes32[](1);
        batch.nullifiers[0] = gate.claimNullifier(CLAIM);
        batch.nullifierProofs = new bytes32[][](1);
        batch.nullifierProofs[0] = _proof(3);
        return abi.encodeCall(successor.importMintState, (abi.encode(batch)));
    }

    function _copy() private {
        _retire();
        _buildTree();
        _govern(_commitRequest());
        // Profile selection is copied from the retired onchain inventory, not the offchain counts.
        nextLedger.importCounterDefinitions(tree[0], 1);
        (uint256 copied, uint256 count) = nextLedger.mintImportDefinitionProgress(tree[0]);
        require(copied == 1 && count == 3, "legacy plus both scoped profiles");
        _ordinary(address(successor), _importCall());
        IStreamMintLedgerImport.ImportCommitment memory progress =
            nextLedger.mintImportCommitment(tree[0]);
        require(
            progress.importedCounters == 3 && progress.importedNullifiers == 1,
            "all data leaves imported before isolating missing profiles"
        );
        vm.expectRevert();
        nextLedger.completeCounterImport(tree[0], 3, 1, _proof(4));
        nextLedger.importCounterDefinitions(tree[0], 32);
        require(
            !nextLedger.isMintSuccessorReady(address(ledger), address(manager), address(successor)),
            "unsealed import not ready"
        );
        _assertImported();
    }

    function _assertImported() private view {
        for (uint256 i; i < leaves.length; ++i) {
            require(
                _value(nextLedger, successor, leaves[i]) == leaves[i].value, "every imported floor"
            );
            require(_value(ledger, manager, leaves[i]) == leaves[i].value, "predecessor retained");
        }
        require(
            nextLedger.isManagerNullifierUsed(address(successor), gate.claimNullifier(CLAIM)),
            "raw entitlement carried forward"
        );
        require(
            ledger.isManagerNullifierUsed(address(manager), gate.claimNullifier(CLAIM)),
            "original raw entitlement retained"
        );
        require(
            ledger.managerDefinitionCount(address(manager))
                == nextLedger.managerDefinitionCount(address(successor)),
            "complete profile inventory"
        );
        for (uint256 i; i < ledger.managerDefinitionCount(address(manager)); ++i) {
            (
                bytes32 oldHash,
                bool oldDefined,
                IStreamMintCounterPolicy.Definition memory oldDefinition
            ) = ledger.managerDefinitionAt(address(manager), i);
            (
                bytes32 newHash,
                bool newDefined,
                IStreamMintCounterPolicy.Definition memory newDefinition
            ) = nextLedger.managerDefinitionAt(address(successor), i);
            require(
                oldHash == newHash && oldDefined == newDefined
                    && keccak256(abi.encode(oldDefinition)) == keccak256(abi.encode(newDefinition)),
                "exact profile interpretations"
            );
        }
    }

    function _complete() private {
        nextLedger.completeCounterImport(tree[0], 3, 1, _proof(4));
        require(
            nextLedger.isMintSuccessorReady(address(ledger), address(manager), address(successor)),
            "exact pair ready"
        );
    }

    function _pointerCall(bytes32 pointer, StreamModuleRegistration memory record)
        private
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        StreamCorePointerState memory old = StreamCurrentStackPlan.readPointer(core, pointer);
        StreamCorePointerState memory next = StreamCurrentStackPlan.pointerState(
            address(registry), record, false, old.revision + 1
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            StreamCurrentStackPlan.pointerTransitionHashes(core, pointer, old, next);
        data = abi.encodeCall(core.updateSatellitePointer, (pointer, record.module));
        call_ = StreamCurrentStackPlan.call(address(core), data, scope, before_, after_);
    }

    function _activation(StreamMintManager candidate)
        private
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        calls = new GovernanceCall[](replaceLedger ? 3 : 2);
        data = new bytes[](calls.length);
        uint256 cursor;
        // Inventory updates are atomic in the same real batch; authority reads Manager's own Ledger.
        if (replaceLedger) {
            (calls[cursor], data[cursor]) = _pointerCall(LEDGER_POINTER, _ledgerRecord());
            ++cursor;
        }
        (calls[cursor], data[cursor]) = _pointerCall(MANAGER_POINTER, _managerRecord(candidate));
        ++cursor;
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        current.modules.mintManager = address(candidate);
        current.modules.mintLedger = address(nextLedger);
        (address payload, bytes32 content) = StreamGenesisManifestPlan.writePayload(
            abi.encode("actual mint succession", address(candidate), tree[0])
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            content,
            "urn:stream:current:mint-continuity",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (calls[cursor], data[cursor]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
    }

    function _baseline() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                core.totalSupply(),
                core.collectionMintedEver(1),
                core.lastAllocatedTokenId(),
                core.ownerOf(1),
                core.ownerOf(2),
                manager.nextOperationNonce(),
                successor.nextOperationNonce(),
                wallet.balance,
                ledger.isManagerOperationRootUsed(address(manager), paidOperation),
                ledger.isManagerAuthorizationUsed(address(manager), originalAuthorization),
                ledger.isManagerOperationRootUsed(address(manager), originalOperation)
            )
        );
    }

    function _exerciseCutover(bool newLedger) private {
        _setup(newLedger);
        _copy();
        bytes32 before_ = _baseline();
        StreamCorePointerState memory oldManager =
            StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER);
        StreamCorePointerState memory oldLedger =
            StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER);
        (GovernanceCall[] memory calls, bytes[] memory data) = _activation(successor);
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(3, calls, data);
        bytes memory execution =
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data));
        vm.expectRevert();
        this.executeCurrentGovernorCall(address(executor), execution);
        vm.warp(ready);
        vm.expectRevert();
        this.executeCurrentGovernorCall(address(executor), execution);
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "failed guard keeps action retryable"
        );
        require(
            keccak256(abi.encode(StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER)))
                    == keccak256(abi.encode(oldManager))
                && keccak256(abi.encode(StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER)))
                == keccak256(abi.encode(oldLedger)),
            "whole pointer batch rolled back"
        );
        require(_baseline() == before_, "failed cutover changed no mint state or proceeds");
        _complete();
        this.executeCurrentGovernorCall(address(executor), execution);
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "identical action succeeds after seal"
        );
        require(
            StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target == address(successor)
                && StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER).target
                    == address(nextLedger),
            "actual Core pointers"
        );
        StreamSystemManifest.AggregateState memory published =
            StreamGenesisManifestPlan.readAggregate(manifest);
        require(
            published.modules.mintManager == address(successor)
                && published.modules.mintLedger == address(nextLedger),
            "actual manifest inventory"
        );
        require(
            _baseline() == before_,
            "cutover preserves token lifetime identity, accounting and proceeds"
        );
        _assertImported();
    }

    function testSameLedgerGovernedCutoverRequiresSealAndRetriesExactActionWithoutReset() public {
        _exerciseCutover(false);
    }

    function testNewLedgerGovernedCutoverRollsBackInventoryAndRetriesExactActionWithoutReset()
        public
    {
        _exerciseCutover(true);
    }

    function testWrongActualSuccessorCannotUseAnotherManagersCompletedImport() public {
        _setup(true);
        _copy();
        _complete();
        require(
            !nextLedger.isMintSuccessorReady(
                address(ledger), address(manager), address(wrongSuccessor)
            ),
            "wrong actual pair"
        );
        bytes32 before_ = _baseline();
        (GovernanceCall[] memory calls, bytes[] memory data) = _activation(wrongSuccessor);
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(3, calls, data);
        vm.warp(ready);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "wrong pair not executed"
        );
        require(
            StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target == address(manager)
                && StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER).target
                    == address(ledger),
            "wrong pair inventory rollback"
        );
        require(_baseline() == before_, "wrong pair no resets");
        (calls, data) = _activation(successor);
        _runBatch(3, calls, data);
        require(
            StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target == address(successor),
            "exact pair positive control"
        );
    }

    function testRealImportActionRejectsLiveWriterAndRetriesAfterPermanentRetirement() public {
        _setup(false);
        // Deliberately unretired prospective snapshot for this negative commitment test.
        _buildTree();
        GovernanceActionRequest memory request = _commitRequest();
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceAction, (action, request.callData))
        );
        require(
            nextLedger.mintImportCommitment(tree[0]).successorManager == address(0),
            "failed commit has no import state"
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "live writer action retryable"
        );
        _retire();
        _executeAsGovernor(action, request.callData);
        IStreamMintLedgerImport.ImportCommitment memory saved =
            nextLedger.mintImportCommitment(tree[0]);
        require(
            saved.predecessorLedger == address(ledger)
                && saved.predecessorManager == address(manager)
                && saved.successorManager == address(successor)
                && saved.snapshotBlock == snapshotBlock && saved.manifestHash == SNAPSHOT_MANIFEST,
            "actual action authenticates exact root pair and snapshot"
        );
    }

    function testImportRejectsIncorrectGovernanceCommitmentAndLeafReplayWithoutResidue() public {
        _setup(true);
        _retire();
        _buildTree();
        GovernanceActionRequest memory wrong = _commitRequest();
        wrong.newValueHash = keccak256("different approved transition");
        bytes32 action = _scheduleAsGovernor(wrong);
        vm.warp(wrong.notBefore);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceAction, (action, wrong.callData))
        );
        require(
            nextLedger.mintImportCommitment(tree[0]).successorManager == address(0),
            "wrong commitment leaves no import"
        );
        _govern(_commitRequest());
        nextLedger.importCounterDefinitions(tree[0], 32);
        bytes memory data = _importCall();
        _ordinary(address(successor), data);
        IStreamMintLedgerImport.ImportCommitment memory imported =
            nextLedger.mintImportCommitment(tree[0]);
        GovernanceActionRequest memory replay = _governanceRequest(
            1,
            address(successor),
            data,
            keccak256(abi.encode("retry imported leaves", data)),
            0,
            keccak256(data)
        );
        action = _scheduleAsGovernor(replay);
        vm.warp(replay.notBefore);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            keccak256(abi.encode(nextLedger.mintImportCommitment(tree[0])))
                == keccak256(abi.encode(imported)),
            "leaf replay leaves exact progress unchanged"
        );
        _assertImported();
        _complete();
    }

    function testLaterInvalidImportProofRollsBackEarlierLeavesAndAllowsCorrectedBatch() public {
        _setup(true);
        _retire();
        _buildTree();
        _govern(_commitRequest());
        nextLedger.importCounterDefinitions(tree[0], 32);
        bytes memory bad = _importCall(true);
        GovernanceActionRequest memory request = _governanceRequest(
            1,
            address(successor),
            bad,
            keccak256(abi.encode(address(successor), bad)),
            0,
            keccak256(bad)
        );
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        bytes32 before_ = _baseline();
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, bad))
        );
        IStreamMintLedgerImport.ImportCommitment memory progress =
            nextLedger.mintImportCommitment(tree[0]);
        require(
            progress.importedCounters == 0 && progress.importedNullifiers == 0,
            "later bad proof rolls back earlier progress"
        );
        for (uint256 i; i < leaves.length; ++i) {
            require(_value(nextLedger, successor, leaves[i]) == 0, "earlier writes reverted");
            require(_value(ledger, manager, leaves[i]) == 1, "original floor untouched");
        }
        require(
            !nextLedger.isManagerNullifierUsed(address(successor), gate.claimNullifier(CLAIM)),
            "no nullifier residue"
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && _baseline() == before_,
            "failed import does not complete action or alter Core"
        );
        // The proof bytes changed, so a new exact governance authorization is required.
        _ordinary(address(successor), _importCall());
        _assertImported();
        _complete();
    }
}
