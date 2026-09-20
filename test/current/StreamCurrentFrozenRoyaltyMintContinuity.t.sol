// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../script/current/StreamMintPhaseFreezePlan.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintManagerImport.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";

interface FrozenRoyaltyCallVm {
    function expectCall(address target, bytes calldata data) external;
}

/// @dev Explicit late delivery failure after the actual resolver has written a prepared snapshot.
contract CurrentFrozenRoyaltyReceiver {
    StreamCore private immutable source;
    StreamRoyaltyResolver private immutable royalty;
    address private immutable manager;
    bool private accepts;

    constructor(StreamCore core_, StreamRoyaltyResolver royalty_, address manager_) {
        source = core_;
        royalty = royalty_;
        manager = manager_;
    }

    function accept() external {
        accepts = true;
    }

    function onERC721Received(address operator, address, uint256 token, bytes calldata)
        external
        view
        returns (bytes4)
    {
        IStreamRoyaltySnapshot.Snapshot memory saved = royalty.royaltySnapshot(token);
        require(
            msg.sender == address(source) && operator == manager && saved.exists
                && saved.manager == manager && saved.tokenId == token && saved.operationRoot != 0
                && saved.preparedProofHash != 0 && royalty.tokenRoyalty(token).frozen,
            "actual successor snapshot exists before delivery"
        );
        require(accepts, "frozen royalty receiver rejected");
        return 0x150b7a02;
    }
}

/// @notice Actual Artist EOA consent, RoyaltyResolver, Safe governance and frozen Manager succession.
/// @dev Only external entropy and a rejecting delivery recipient are test inputs. These cases
/// exercise prepared mint authority and royalty receipts; they make no paid-sale acceptance claim.
contract StreamCurrentFrozenRoyaltyMintContinuityTest is StreamCurrentSafeGovernanceFixture {
    bytes32 private constant SNAP_PHASE = keccak256("frozen actual royalty succession");
    bytes32 private constant COUNTER = keccak256("frozen actual royalty supply");
    bytes32 private constant COUNTER_CONFIG = keccak256("frozen actual royalty counter config");
    bytes32 private constant APPLICATION = keccak256("original frozen royalty application");
    bytes32 private constant ROYALTY_CLASS = keccak256("ROYALTY_ERC2981");
    bytes32 private constant IMPORT_MANIFEST = keccak256("one actual counter and no nullifiers");
    bytes32 private constant MANAGER_POINTER = keccak256("MINT_MANAGER");
    StreamMintManager private successor;
    IStreamMintRoyaltyPolicy.Policy private originalPolicy;
    IStreamRoyaltySnapshot.Source private originalSource;
    IStreamRoyaltySnapshot.Snapshot private originalSnapshot;
    bytes32 private originalPhasePolicy;
    bytes32 private importRoot;
    bytes32 private counterLeafHash;
    bytes32 private descriptorLeafHash;
    IStreamMintLedgerImport.CounterImportLeaf private importedCounter;

    function setUp() public {
        vm.roll(20);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xF20501;
        keys[1] = 0xF20502;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 2051);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(safe, keys);
        _registerCandidate();
        require(core.collectionNextSerial(1) == 1, "election precedes every mint");
        _ordinary(address(royalties), abi.encodeCall(royalties.electCollectionRoyaltyMode, (1, 2)));
        _approveAndInstallRoyalty(600);
        originalSource = royalties.currentRoyaltySnapshotSource(1);
        originalPolicy = _policyFor(originalSource);
        _registerRoyalty(manager, originalPolicy);
        _configureOriginal();
        IStreamMintManager.MintBatch memory first =
            _batch(manager, BUYER, keccak256("original prepared mint"));
        this.executeCurrentGovernorCall(
            address(manager), abi.encodeCall(manager.executePreparedMint, (first, bytes("")))
        );
        originalSnapshot = _assertSnapshot(manager, 1, BUYER);
        originalPhasePolicy = manager.phasePolicyHash(1, SNAP_PHASE);
        _freezeAndImport();
        _cutover();
        _raiseSuccessorArtistBudget(300_000);
        _raiseSuccessorArtistBudget(600_000);
    }

    function _deployAdditionalProducts() internal override {
        successor = StreamMintManager(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager",
                abi.encode(core, ledger, IERC165(address(registry)))
            )
        );
        ledger.setLedgerWriter(address(successor), true);
        successor.transferOwnership(address(executor));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](8);
        rows[0] = _policyRow(address(manager), manager.registerPhaseRoyaltyPolicy.selector);
        rows[1] = _policyRow(address(royalties), royalties.electCollectionRoyaltyMode.selector);
        rows[2] = _policyRow(address(ledger), ledger.retireLedgerWriter.selector);
        rows[3] = _policyRow(address(ledger), ledger.commitCounterImportRoot.selector);
        rows[4] = _policyRow(address(successor), successor.importMintState.selector);
        rows[5] = _policyRow(address(successor), successor.configurePhase.selector);
        rows[6] = _policyRow(address(successor), successor.registerPhaseRoyaltyPolicy.selector);
        rows[7] = _policyRow(address(successor), successor.raiseGasParameter.selector);
    }

    function _policyRow(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1, target, selector, target.codehash, DEPLOYMENT_HASH, 1, 0, 0, 0
        );
    }

    function _record() private view returns (StreamModuleRegistration memory) {
        return StreamModuleRegistration(
            address(successor),
            MANAGER_POINTER,
            keccak256("frozen royalty successor v1"),
            type(IStreamMintManager).interfaceId,
            300_000,
            address(successor).codehash,
            DEPLOYMENT_HASH,
            keccak256("actual frozen royalty successor"),
            "urn:stream:current:frozen-royalty-successor"
        );
    }

    function _registerCandidate() private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = _record();
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _run(1, calls, data);
    }

    function _ordinary(address target, bytes memory data) private returns (bytes32) {
        return _govern(
            _governanceRequest(
                1, target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
            )
        );
    }

    function _run(uint8 cls, GovernanceCall[] memory calls, bytes[] memory data) private {
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(cls, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "actual batch executed"
        );
    }

    function _approveAndInstallRoyalty(uint16 bps) private {
        T.AssignmentFact memory fact =
            royalties.previewArtistSnapshotRoyaltyAssignment(1, profile, bps, false);
        T.EconomicsConsent memory consent =
            T.EconomicsConsent(1, address(royalties), ROYALTY_CLASS, 1, 1, fact.assignmentHash);
        T.Authorization memory auth = _artistAuthorization(false);
        auth.signature = _artistProof(artists.economicsConsentDigest(consent, auth));
        IStreamArtistEconomicsAuthority(address(artists))
            .recordProspectiveEconomicsConsent(
                consent, T.FixedEconomicsCandidate(profile, 0, bps, false), auth
            );
        _ordinary(
            address(royalties),
            abi.encodeCall(royalties.configureCollectionRoyalty, (1, profile, bps))
        );
        IStreamRoyaltySnapshot.Source memory source = royalties.currentRoyaltySnapshotSource(1);
        require(
            source.modeAssignmentHash == fact.assignmentHash && source.config.royaltyBps == bps
                && source.config.profileId == profile && source.config.wallet == wallet,
            "actual op15 consent and governed royalty source"
        );
    }

    function _policyFor(IStreamRoyaltySnapshot.Source memory source)
        private
        view
        returns (IStreamMintRoyaltyPolicy.Policy memory)
    {
        return IStreamMintRoyaltyPolicy.Policy(
            true,
            APPLICATION,
            address(royalties),
            address(royalties).codehash,
            source.electionHash,
            source.modeAssignmentHash,
            source.sourceRoyaltyPolicyHash
        );
    }

    function _registerRoyalty(
        StreamMintManager target,
        IStreamMintRoyaltyPolicy.Policy memory policy
    ) private {
        _ordinary(
            address(target),
            abi.encodeCall(target.registerPhaseRoyaltyPolicy, (1, SNAP_PHASE, policy))
        );
    }

    function _terms(bytes32 wrapper)
        private
        pure
        returns (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gate,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory counters
        )
    {
        config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, wrapper, keccak256("frozen royalty metadata")
        );
        ids = new bytes32[](1);
        ids[0] = COUNTER;
        counters = new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            3,
            1,
            COUNTER_CONFIG
        );
    }

    function _phaseData(StreamMintManager target, bytes32 wrapper, bool executorIncluded)
        private
        view
        returns (bytes memory data, bytes32 policyHash)
    {
        (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gate,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory counters
        ) = _terms(wrapper);
        address[] memory allowed = new address[](executorIncluded ? 1 : 0);
        if (executorIncluded) allowed[0] = address(governorSafe);
        policyHash =
            target.previewPhasePolicyHash(1, SNAP_PHASE, config, gate, ids, counters, allowed);
        data = abi.encodeCall(target.configurePhase, (1, SNAP_PHASE, config, gate, ids, counters));
    }

    function _configureOriginal() private {
        bytes32 wrapper = manager.phaseRoyaltyConfigHash(1, SNAP_PHASE, originalPolicy);
        (bytes memory data, bytes32 policy) = _phaseData(manager, wrapper, false);
        _recordFixturePolicy(SNAP_PHASE, policy);
        _ordinary(address(manager), data);
        (, policy) = _phaseData(manager, wrapper, true);
        _recordFixturePolicy(SNAP_PHASE, policy);
        _ordinary(
            address(manager),
            abi.encodeCall(manager.setPhaseExecutor, (1, SNAP_PHASE, address(governorSafe), true))
        );
        require(manager.phasePolicyHash(1, SNAP_PHASE) == policy, "original Safe executor policy");
    }

    function _batch(StreamMintManager target, address recipient, bytes32 authorization)
        private
        view
        returns (IStreamMintManager.MintBatch memory batch)
    {
        batch.collectionId = 1;
        batch.phaseId = SNAP_PHASE;
        batch.payer = BUYER;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = recipient;
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = BUYER;
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] =
            keccak256(abi.encode("frozen royalty prepared commitment", authorization));
        batch.expectedPolicyHash = target.phasePolicyHash(1, SNAP_PHASE);
        batch.authorizationId = authorization;
    }

    function _subject() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                uint256(1),
                SNAP_PHASE,
                COUNTER
            )
        );
    }

    function _value(StreamMintManager target) private view returns (uint64) {
        return ledger.counterValue(
            ledger.deriveCounterValueKey(address(target), 1, SNAP_PHASE, COUNTER, _subject())
        );
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _proof(bytes32 sibling) private pure returns (bytes32[] memory proof) {
        proof = new bytes32[](1);
        proof[0] = sibling;
    }

    function _freezeAndImport() private {
        GenesisBatch memory action = StreamMintPhaseFreezePlan.classifier(executor, manager);
        _run(action.actionClass, action.calls, action.callDatas);
        action = StreamMintPhaseFreezePlan.freeze(manager, 1, SNAP_PHASE);
        require(
            action.actionClass == 2 && executor.minimumDelay(2) >= 72 hours,
            "original freeze veto floor"
        );
        _run(action.actionClass, action.calls, action.callDatas);
        require(
            manager.phaseFrozen(1, SNAP_PHASE) && _value(manager) == 1, "real consumed frozen phase"
        );
        _ordinary(address(ledger), abi.encodeCall(ledger.retireLedgerWriter, (address(manager))));
        uint64 atBlock = uint64(block.number);
        importedCounter = IStreamMintLedgerImport.CounterImportLeaf(
            1,
            SNAP_PHASE,
            COUNTER,
            uint8(IStreamMintManager.CounterKeyMode.CONSTANT),
            0,
            _subject(),
            1
        );
        counterLeafHash = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(manager),
                        importedCounter
                    )
                )
            )
        );
        descriptorLeafHash = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(ledger),
                        address(manager),
                        address(successor),
                        atBlock,
                        IMPORT_MANIFEST,
                        uint64(1),
                        uint64(0)
                    )
                )
            )
        );
        importRoot = _pair(counterLeafHash, descriptorLeafHash);
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1"),
                block.chainid,
                address(ledger),
                address(successor)
            )
        );
        bytes32 commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"),
                scope,
                address(ledger),
                address(manager),
                address(successor),
                atBlock,
                importRoot,
                IMPORT_MANIFEST
            )
        );
        _govern(
            _governanceRequest(
                1,
                address(ledger),
                abi.encodeCall(
                    ledger.commitCounterImportRoot,
                    (
                        address(ledger),
                        address(manager),
                        address(successor),
                        atBlock,
                        importRoot,
                        IMPORT_MANIFEST
                    )
                ),
                scope,
                0,
                commitment
            )
        );
        ledger.importCounterDefinitions(importRoot, 32);
        IStreamMintManagerImport.ImportBatch memory batch;
        batch.importRoot = importRoot;
        batch.counters = new IStreamMintLedgerImport.CounterImportLeaf[](1);
        batch.counters[0] = importedCounter;
        batch.counterProofs = new bytes32[][](1);
        batch.counterProofs[0] = _proof(descriptorLeafHash);
        batch.nullifiers = new bytes32[](0);
        batch.nullifierProofs = new bytes32[][](0);
        _ordinary(
            address(successor), abi.encodeCall(successor.importMintState, (abi.encode(batch)))
        );
        vm.expectRevert();
        ledger.completeCounterImport(importRoot, 1, 0, _proof(counterLeafHash));
        ledger.importPhaseFreezes(importRoot, 1);
        _assertUnconfigured();
        require(
            _value(successor) == 1 && !ledger.mintImportCommitment(importRoot).complete,
            "original counter copied before import seal"
        );
    }

    function _activation() private returns (GovernanceCall[] memory calls, bytes[] memory data) {
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        StreamCorePointerState memory old =
            StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER);
        StreamCorePointerState memory next = StreamCurrentStackPlan.pointerState(
            address(registry), _record(), false, old.revision + 1
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            StreamCurrentStackPlan.pointerTransitionHashes(core, MANAGER_POINTER, old, next);
        data[0] = abi.encodeCall(core.updateSatellitePointer, (MANAGER_POINTER, address(successor)));
        calls[0] = StreamCurrentStackPlan.call(address(core), data[0], scope, before_, after_);
        StreamSystemManifest.AggregateState memory state =
            StreamGenesisManifestPlan.readAggregate(manifest);
        state.modules.mintManager = address(successor);
        (address payload, bytes32 content) = StreamGenesisManifestPlan.writePayload(
            abi.encode("frozen royalty succession", importRoot)
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            content,
            "urn:stream:current:frozen-royalty-succession",
            state.discovery.eventCatalogHash,
            state.discovery.compatibilityMatrixHash,
            state.discovery.numericIdCatalogHash,
            state.discovery.schemaCatalogHash,
            state.discovery.canonicalizationCatalogHash,
            state.discovery.specBundleHash,
            state.discovery.reconstructionClientHash
        );
        (calls[1], data[1]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, state.modules);
    }

    function _cutover() private {
        (GovernanceCall[] memory calls, bytes[] memory data) = _activation();
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(3, calls, data);
        vm.warp(ready);
        bytes memory callData =
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data));
        bytes memory signed = _signedSafe(address(executor), callData);
        uint256 nonce = governorSafe.nonce();
        (bool ok,) = address(governorSafe).call(signed);
        require(
            !ok && governorSafe.nonce() == nonce
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target
                    == address(manager)
                && StreamGenesisManifestPlan.readAggregate(manifest).modules.mintManager
                    == address(manager),
            "unsealed import rolls back the whole exact Safe cutover"
        );
        ledger.completeCounterImport(importRoot, 1, 0, _proof(counterLeafHash));
        (ok,) = address(governorSafe).call(signed);
        require(
            ok && governorSafe.nonce() == nonce + 1
                && executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED
                && StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target
                    == address(successor)
                && StreamCurrentStackPlan.readPointer(core, keccak256("MINT_LEDGER")).target
                    == address(ledger)
                && StreamGenesisManifestPlan.readAggregate(manifest).modules.mintManager
                    == address(successor)
                && ledger.isCompletedMintDescendant(
                    address(ledger), address(manager), address(successor)
                ) && artists.mintManager() == address(manager),
            "same saved Safe cutover selects completed lineage and preserves original Artist anchor"
        );
        _assertOriginalReceipt();
    }

    function _raiseSuccessorArtistBudget(uint256 nextValue) private {
        // Governed fixture setup follows the existing actual-current successor recipe.
        // This does not change any production default or claim a measured minimum gas allowance.
        bytes32 parameter = successor.GGP_ARTIST_AUTHORITY_GAS_LIMIT();
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            successor.gasParameterInfo(parameter);
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"),
                block.chainid,
                address(successor),
                parameter
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        _govern(
            _governanceRequest(
                1,
                address(successor),
                abi.encodeCall(successor.raiseGasParameter, (parameter, nextValue)),
                scope,
                keccak256(abi.encode(domain, scope, value, floor, failureClass, revision)),
                keccak256(abi.encode(domain, scope, nextValue, floor, failureClass, revision + 1))
            )
        );
    }

    function _signedSafe(address target, bytes memory data) private returns (bytes memory) {
        bytes32 digest = governorSafe.getTransactionHash(
            target, 0, data, 0, 0, 0, 0, address(0), address(0), governorSafe.nonce()
        );
        return abi.encodeCall(
            governorSafe.execTransaction,
            (
                target,
                uint256(0),
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(governorKeys, digest)
            )
        );
    }

    function _assertUnconfigured() private view {
        (bool exists,) = successor.phase(1, SNAP_PHASE);
        require(
            !exists && successor.phaseFrozen(1, SNAP_PHASE)
                && successor.phasePolicyHash(1, SNAP_PHASE) == 0
                && ledger.registeredPhasePolicyHash(address(successor), 1, SNAP_PHASE) == 0
                && successor.phaseExecutors(1, SNAP_PHASE).length == 0
                && !successor.phaseExecutor(1, SNAP_PHASE, address(governorSafe))
                && ledger.frozenPhaseExecutors(address(successor), 1, SNAP_PHASE).length == 1,
            "unconfigured candidate retains canonical freeze but no phase or bootstrapped executor"
        );
    }

    function _configureSuccessorWithFreshConsent() private {
        bytes32 wrapper = successor.phaseRoyaltyConfigHash(1, SNAP_PHASE, originalPolicy);
        (bytes memory data, bytes32 policy) = _phaseData(successor, wrapper, true);
        (bool already,) = artists.isPolicyConsented(1, SNAP_PHASE, policy);
        require(
            !already && policy != originalPhasePolicy,
            "original Artist receipt is not successor consent"
        );
        GovernanceActionRequest memory request = _governanceRequest(
            1,
            address(successor),
            data,
            keccak256(abi.encode(address(successor), data)),
            0,
            keccak256(data)
        );
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        bytes memory signed = _signedSafe(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        uint256 nonce = governorSafe.nonce();
        (bool ok,) = address(governorSafe).call(signed);
        require(
            !ok && governorSafe.nonce() == nonce
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "missing fresh Artist consent leaves exact Safe configuration retryable"
        );
        _assertUnconfigured();
        _recordFixturePolicy(SNAP_PHASE, policy);
        (ok,) = address(governorSafe).call(signed);
        require(
            ok && governorSafe.nonce() == nonce + 1
                && executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED
                && successor.phasePolicyHash(1, SNAP_PHASE) == policy
                && successor.phaseExecutor(1, SNAP_PHASE, address(governorSafe))
                && successor.phaseExecutors(1, SNAP_PHASE).length == 1,
            "same saved Safe call uses fresh original Artist receipt and inherited executor"
        );
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory previous =
            ledger.phaseFreeze(address(manager), 1, SNAP_PHASE);
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory current =
            ledger.phaseFreeze(address(successor), 1, SNAP_PHASE);
        require(
            previous.policyHash == current.policyHash && previous.policyHash == originalPhasePolicy
                && previous.configurationHash == current.configurationHash
                && _value(successor) == 1,
            "fresh Manager policy retains frozen provenance, normalized terms and imported counter"
        );
    }

    function _expectConfigurationFailure(bytes32 wrapper) private {
        (bytes memory data, bytes32 policy) = _phaseData(successor, wrapper, true);
        _recordFixturePolicy(SNAP_PHASE, policy);
        GovernanceActionRequest memory request = _governanceRequest(
            1,
            address(successor),
            data,
            keccak256(abi.encode(address(successor), data)),
            0,
            keccak256(data)
        );
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        uint256 nonce = governorSafe.nonce();
        bytes memory signed = _signedSafe(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        (bool ok,) = address(governorSafe).call(signed);
        require(
            !ok && governorSafe.nonce() == nonce
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "fresh Artist consent cannot change inherited frozen royalty terms"
        );
        _assertUnconfigured();
        require(
            _value(successor) == 1 && successor.nextOperationNonce() == 0,
            "rejected configuration preserves imported state"
        );
        _assertOriginalReceipt();
    }

    function _assertSnapshot(StreamMintManager writer, uint256 token, address owner)
        private
        view
        returns (IStreamRoyaltySnapshot.Snapshot memory saved)
    {
        saved = royalties.royaltySnapshot(token);
        IStreamRoyaltyResolver.RoyaltyConfig memory config = royalties.tokenRoyalty(token);
        require(
            saved.exists && saved.collectionId == 1 && saved.tokenId == token
                && saved.manager == address(writer) && saved.operationRoot != 0
                && saved.operationId != 0 && saved.preparedProofHash != 0
                && saved.electionHash == originalSource.electionHash
                && saved.modeAssignmentHash == originalSource.modeAssignmentHash
                && saved.sourceAssignmentHash == originalSource.sourceAssignmentHash
                && saved.sourceRoyaltyPolicyHash == originalSource.sourceRoyaltyPolicyHash
                && ledger.isManagerOperationRootUsed(address(writer), saved.operationRoot)
                && config.configured && config.frozen && config.revision == 1
                && config.profileId == originalSource.config.profileId
                && config.wallet == originalSource.config.wallet
                && config.royaltyBps == originalSource.config.royaltyBps
                && core.ownerOf(token) == owner,
            "actual prepared snapshot preserves every original source and token fact"
        );
        (T.AssignmentFact memory fact,, bytes32 policy) =
            royalties.resolveRoyaltyAssignment(1, token);
        require(
            fact.scope == 2 && fact.scopeId == token
                && fact.assignmentHash == saved.tokenAssignmentHash
                && policy == saved.tokenRoyaltyPolicyHash
                && saved.tokenConfigHash == keccak256(abi.encode(config)),
            "actual token-scoped assignment and canonical frozen config"
        );
    }

    function _assertOriginalReceipt() private view {
        require(
            keccak256(abi.encode(royalties.royaltySnapshot(1)))
                    == keccak256(abi.encode(originalSnapshot))
                && keccak256(abi.encode(royalties.tokenRoyalty(1)))
                    == originalSnapshot.tokenConfigHash && core.ownerOf(1) == BUYER
                && manager.nextOperationNonce() == 1 && _value(manager) == 1
                && ledger.isManagerOperationRootUsed(
                    address(manager), originalSnapshot.operationRoot
                ),
            "original snapshot and retired Manager accounting remain byte-exact"
        );
    }

    function testFrozenSnapshotSuccessorRebindsOnlyManagerDomainAndRequiresFreshArtistConsent()
        public
    {
        _registerRoyalty(successor, originalPolicy);
        bytes32 oldWrapper = manager.phaseRoyaltyConfigHash(1, SNAP_PHASE, originalPolicy);
        bytes32 newWrapper = successor.phaseRoyaltyConfigHash(1, SNAP_PHASE, originalPolicy);
        require(
            oldWrapper != newWrapper
                && keccak256(abi.encode(successor.phaseRoyaltyPolicy(1, SNAP_PHASE)))
                    == keccak256(abi.encode(manager.phaseRoyaltyPolicy(1, SNAP_PHASE))),
            "only Manager-domain wrapper changes; all seven original royalty fields remain exact"
        );
        _configureSuccessorWithFreshConsent();
        IStreamMintManager.MintBatch memory batch =
            _batch(successor, BUYER, keccak256("fresh successor prepared mint"));
        this.executeCurrentGovernorCall(
            address(successor), abi.encodeCall(successor.executePreparedMint, (batch, bytes("")))
        );
        IStreamRoyaltySnapshot.Snapshot memory saved = _assertSnapshot(successor, 2, BUYER);
        require(
            core.totalSupply() == 2 && core.lastAllocatedTokenId() == 2
                && core.collectionNextSerial(1) == 3 && successor.nextOperationNonce() == 1
                && _value(successor) == 2 && saved.operationRoot != originalSnapshot.operationRoot
                && saved.operationId != originalSnapshot.operationId
                && successor.phaseFrozen(1, SNAP_PHASE),
            "new lifetime token and snapshot under original inherited freeze"
        );
        _assertOriginalReceipt();
    }

    function testFrozenSnapshotRejectsMissingRoyaltyBranchAndOriginalManagerWrapper() public {
        _expectConfigurationFailure(successor.phaseRoyaltyConfigHash(1, SNAP_PHASE, originalPolicy));
        _registerRoyalty(successor, originalPolicy);
        _expectConfigurationFailure(manager.phaseRoyaltyConfigHash(1, SNAP_PHASE, originalPolicy));
        require(
            successor.phaseRoyaltyPolicy(1, SNAP_PHASE).configured,
            "original policy registration remains separate from rejected phase"
        );
    }

    function testFrozenSnapshotRejectsGenuinelyConsentedChangedCurrentRoyaltyEconomics() public {
        _approveAndInstallRoyalty(700);
        IStreamRoyaltySnapshot.Source memory changedSource =
            royalties.currentRoyaltySnapshotSource(1);
        IStreamMintRoyaltyPolicy.Policy memory changed = _policyFor(changedSource);
        require(
            changed.applicationConfigHash == originalPolicy.applicationConfigHash
                && changed.resolver == originalPolicy.resolver
                && changed.resolverRuntimeHash == originalPolicy.resolverRuntimeHash
                && changed.electionHash == originalPolicy.electionHash
                && changed.expectedModeAssignmentHash != originalPolicy.expectedModeAssignmentHash
                && changed.expectedSourceRoyaltyPolicyHash
                    != originalPolicy.expectedSourceRoyaltyPolicyHash,
            "real current Artist approved new economics under same original resolver and election"
        );
        _registerRoyalty(successor, changed);
        _expectConfigurationFailure(successor.phaseRoyaltyConfigHash(1, SNAP_PHASE, changed));
        require(
            royalties.tokenRoyalty(1).royaltyBps == 600
                && royalties.collectionRoyalty(1).royaltyBps == 700,
            "new source cannot rewrite original token or inherited frozen phase"
        );
    }

    function _preparedRoot(IStreamMintManager.MintBatch memory batch)
        private
        view
        returns (bytes32 root)
    {
        (,, bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs) =
            _terms(successor.phaseRoyaltyConfigHash(1, SNAP_PHASE, originalPolicy));
        IStreamMintLedger.CounterConsumption[] memory rows =
            StreamMintOperationIdentity.deriveCounterConsumptions(
                batch,
                1,
                ids,
                configs,
                StreamMintOperationIdentity.CounterContext(
                    block.chainid,
                    address(successor),
                    address(ledger),
                    address(governorSafe),
                    address(0)
                )
            );
        StreamMintOperationIdentity.MintAuthorization memory authorization =
            StreamMintOperationIdentity.MintAuthorization(
                batch.authorizationId,
                new bytes32[](0),
                address(0),
                IStreamMintManager.AuthorizerKind.NONE,
                0,
                bytes32(0)
            );
        (root,) = StreamMintOperationIdentity.derive(
            batch,
            authorization,
            rows,
            StreamMintOperationIdentity.TranscriptContext(
                block.chainid,
                address(successor),
                address(core),
                address(ledger),
                address(0),
                address(governorSafe),
                successor.MINT_EXECUTION_PATH_PREPARED(),
                batch.expectedPolicyHash,
                batch.expectedPolicyHash,
                successor.nextOperationNonce(),
                1
            )
        );
    }

    function _mintWitness(bytes32 authorization, bytes32 root) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                core.totalSupply(),
                core.lastAllocatedTokenId(),
                core.collectionNextSerial(1),
                core.collectionMintedEver(1),
                core.pendingPreparedMintTokenId(),
                successor.nextOperationNonce(),
                _value(successor),
                ledger.isManagerAuthorizationUsed(address(successor), authorization),
                ledger.isManagerOperationRootUsed(address(successor), root),
                royalties.royaltySnapshot(2),
                royalties.tokenRoyalty(2),
                royalties.royaltySnapshot(1),
                royalties.tokenRoyalty(1),
                governorSafe.nonce()
            )
        );
    }

    function testFrozenSnapshotLateReceiverFailureRollsBackAndExactSignedSafeCallRetries() public {
        _registerRoyalty(successor, originalPolicy);
        _configureSuccessorWithFreshConsent();
        CurrentFrozenRoyaltyReceiver receiver =
            new CurrentFrozenRoyaltyReceiver(core, royalties, address(successor));
        IStreamMintManager.MintBatch memory batch =
            _batch(successor, address(receiver), keccak256("receiver retry authorization"));
        bytes32 root = _preparedRoot(batch);
        bytes memory signed = _signedSafe(
            address(successor), abi.encodeCall(successor.executePreparedMint, (batch, bytes("")))
        );
        uint256 nonce = governorSafe.nonce();
        bytes32 before_ = _mintWitness(batch.authorizationId, root);
        FrozenRoyaltyCallVm(address(vm))
            .expectCall(
                address(royalties), abi.encodePacked(royalties.snapshotTokenRoyaltyAtMint.selector)
            );
        FrozenRoyaltyCallVm(address(vm))
            .expectCall(address(receiver), abi.encodePacked(receiver.onERC721Received.selector));
        (bool ok,) = address(governorSafe).call(signed);
        require(
            !ok && _mintWitness(batch.authorizationId, root) == before_
                && !ledger.isManagerOperationRootUsed(address(successor), root)
                && !ledger.isManagerAuthorizationUsed(address(successor), batch.authorizationId)
                && !royalties.royaltySnapshot(2).exists && !royalties.tokenRoyalty(2).configured,
            "late receiver failure rolls back actual snapshot, root, authorization, counter, token and Safe nonce"
        );
        receiver.accept();
        (ok,) = address(governorSafe).call(signed);
        require(
            ok && governorSafe.nonce() == nonce + 1, "byte-identical threshold Safe call retries"
        );
        IStreamRoyaltySnapshot.Snapshot memory saved =
            _assertSnapshot(successor, 2, address(receiver));
        require(
            saved.operationRoot == root && successor.nextOperationNonce() == 1
                && _value(successor) == 2 && core.totalSupply() == 2
                && core.pendingPreparedMintTokenId() == 0
                && ledger.isManagerAuthorizationUsed(address(successor), batch.authorizationId),
            "retry consumes the exact prepared identity once"
        );
        (ok,) = address(governorSafe).call(signed);
        require(
            !ok && governorSafe.nonce() == nonce + 1 && _value(successor) == 2,
            "saved Safe transaction cannot replay"
        );
        _assertOriginalReceipt();
    }
}
