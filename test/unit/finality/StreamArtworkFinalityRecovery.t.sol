// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RecoveryCompanionBoundaryFixture.sol";

/// @dev Actual companion contract, exact original record fixture, and explicit raw Core/artist/
///      OwnerRecords/Executor boundaries. This does not prove their real authorization systems.
contract StreamArtworkFinalityRecoveryTest is RecoveryCompanionBoundaryFixture {
    StreamArtworkFinalityRecovery private recovery;
    RecoveryOriginalRecordFixture private history;
    CompanionExecutorBoundary private actionExecutor;
    CompanionDependencyBoundary private renderer;
    StreamFinalityScope private scope;
    bytes32 private originalHash;
    bytes32 private savedArtistId;
    uint256 private fixtureChain;
    StreamFinalityComponentExpectation private oldRoute;
    StreamFinalityRecoveryRequest private request;
    bytes32 private constant ACTION = keccak256("actual target fixture action");
    bytes32 private constant APPROVAL = keccak256("saved approval evidence boundary");
    bytes32 private constant OWNER = keccak256("elapsed owner evidence boundary");

    function setUp() public override {
        super.setUp();
        vm.warp(1000000);
        fixtureChain = block.chainid;
        actionExecutor = new CompanionExecutorBoundary();
        executor = CompanionDependencyBoundary(address(actionExecutor));
        _address(executor, IStreamFinalityGovernanceBindings.roleRegistry.selector, address(roles));
        _address(roles, IStreamFinalityGovernanceBindings.owner.selector, address(executor));
        _address(
            ownerEvidence,
            IStreamFinalityRecoveryOwnerBindings.governanceAuthority.selector,
            address(executor)
        );
        history = new RecoveryOriginalRecordFixture(address(core), address(artist));
        finality = CompanionDependencyBoundary(address(history));
        _address(
            coordinator, IStreamArtistRecoveryDeployment.finalityRegistry.selector, address(history)
        );
        _word(
            coordinator,
            IStreamArtistRecoveryDeployment.finalityRegistryCodeHash.selector,
            uint256(address(history).codehash)
        );
        IStreamGasParameterHost.GasParameterConfig[3] memory caps;
        caps[0] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_DEPENDENCY_READ_GAS", 150000, 50000, 2
        );
        caps[1] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_ARTIST_READ_GAS", 2000000, 50000, 2
        );
        caps[2] =
            IStreamGasParameterHost.GasParameterConfig("RECOVERY_OWNER_READ_GAS", 500000, 50000, 2);
        recovery = new StreamArtworkFinalityRecovery(
            StreamFinalityRecoveryTargets(
                address(core),
                address(executor),
                address(history),
                address(artist),
                address(ownerEvidence)
            ),
            caps,
            StreamFinalityRecoveryDeploymentConfiguration(
                keccak256("deployment"), "urn:recovery:module", keccak256("module bytes")
            )
        );
        _pointer(
            keccak256("MODULE_REGISTRY"),
            address(modules),
            keccak256("MODULE_REGISTRY"),
            0x11223344,
            address(modules).codehash
        );
        _pointer(RECOVERY, address(recovery), KIND, 0x83685f5c, address(recovery).codehash);
        modules.answer(
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (address(recovery), KIND, bytes4(0x83685f5c))
            ),
            abi.encode(true)
        );
        _pointer(
            keccak256("ARTIST_REGISTRY"),
            address(artist),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            address(artist).codehash
        );
        _module(
            artist, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId, true
        );
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        savedArtistId = keccak256("original artist");
        originalHash = keccak256("executed original finality");
        renderer = new CompanionDependencyBoundary();
        oldRoute = StreamFinalityComponentExpectation(
            bytes32(uint256(1)),
            address(renderer),
            type(IStreamArtworkFinalityComponent).interfaceId,
            address(renderer).codehash,
            keccak256("version"),
            keccak256("renderer manifest"),
            keccak256("original data")
        );
        S.Record memory sanction = S.Record(
            0,
            savedArtistId,
            address(0xA11CE),
            1,
            S.Terms(0, 7, 0, 0, keccak256("subject"), keccak256("ceremony")),
            1,
            1000,
            2000,
            3,
            keccak256("saved binding"),
            keccak256("digest")
        );
        sanction.recordHash = StreamArtistSanctionHashes.record(
            StreamArtistHashes.Environment(
                block.chainid, address(artist), address(core), suite.mintManager
            ),
            sanction
        );
        StreamFinalityComponentExpectation[] memory items =
            new StreamFinalityComponentExpectation[](2);
        items[0] = oldRoute;
        items[1] = StreamFinalityComponentExpectation(
            keccak256("ARTIST_SANCTION"),
            address(artist),
            type(IStreamArtworkFinalityComponent).interfaceId,
            address(artist).codehash,
            keccak256("artist version"),
            keccak256("artist manifest"),
            sanction.recordHash
        );
        history.set(scope, originalHash, sanction, items);
        CompanionDependencyBoundary(suite.owners[6])
            .answer(
                abi.encodeCall(IStreamArtistSanctionOwner.sanctionRecord, (sanction.recordHash)),
                abi.encode(sanction)
            );
        request.scope = scope;
        request.expectedOriginalFinalityRecordHash = originalHash;
        request.expectedOldRouteHash = keccak256(abi.encode(oldRoute));
        request.replacementRoute = oldRoute;
        request.replacementRoute.dataHash = keccak256("replacement artwork bytes");
        request.recoveryManifest = StreamFinalityManifestRef(
            "urn:actual:recovery",
            keccak256("urn:actual:recovery"),
            0,
            keccak256("intent schema"),
            keccak256("binary ABI canonicalization")
        );
        request.reasonHash = keccak256("recovery reason");
        request.reasonURI = "urn:recovery:reason";
        renderer.answer(
            abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (7)),
            abi.encode(
                StreamFinalityComponentState(
                    true,
                    request.replacementRoute.componentType,
                    request.replacementRoute.component,
                    request.replacementRoute.interfaceId,
                    request.replacementRoute.codeHash,
                    request.replacementRoute.moduleVersion,
                    request.replacementRoute.manifestHash,
                    request.replacementRoute.dataHash
                )
            )
        );
        bytes memory intent = recovery.finalityRecoveryIntentBytes(request);
        request.recoveryManifest.contentHash = recovery.stageFinalityRecoveryManifest(intent);
        recovery.registerFinalityRecoveryIntent(request);
        artist.answer(_approvalRead(), abi.encode(true, APPROVAL, address(0xA11CE), uint8(1)));
        _owner(true, 999000);
        core.answer(
            abi.encodeCall(IStreamFinalityRecoveryCore.lastAllocatedTokenId, ()),
            abi.encode(uint256(3))
        );
    }

    function _approvalRead() private view returns (bytes memory) {
        return abi.encodeCall(
            IStreamArtistRecoveryApproval.verifyRecoveryApproval,
            (uint256(7), originalHash, request.recoveryManifest.contentHash)
        );
    }

    function _owner(bool valid, uint64 end) private {
        ownerEvidence.answer(
            abi.encodeCall(
                IStreamFinalityRecoveryOwnerEvidence.verifyRecoveryOwnerEvidence,
                (scope, ACTION, request.recoveryManifest.contentHash)
            ),
            abi.encode(valid, OWNER, uint64(1), end, uint32(3), uint32(0))
        );
    }

    function _facts() private view returns (IStreamArtistRecoveryIntent.Facts memory) {
        return recovery.requireArtistRecoveryIntent(
            scope, originalHash, request.recoveryManifest.contentHash
        );
    }

    function _run(uint8 cls, bytes32 scopeHash) private returns (bool, bytes memory) {
        IStreamArtistRecoveryIntent.Facts memory f = _facts();
        bytes32[4] memory words =
            [ACTION, scopeHash == 0 ? f.scopeHash : scopeHash, f.oldValueHash, f.newValueHash];
        return actionExecutor.run(
            address(recovery),
            abi.encodeCall(recovery.executeFinalityRecovery, (request)),
            words,
            cls
        );
    }

    function _error(bool ok, bytes memory output, bytes memory wanted) private pure {
        require(!ok && keccak256(output) == keccak256(wanted), "exact rejection");
    }

    function currentTestChainId() external view returns (uint256) {
        return block.chainid;
    }

    function testCompanionActualContractRegistersIntentAndExecutesApprovalSnapshot() public {
        require(
            address(recovery).code.length <= 24576
                && address(StreamFinalityRecoveryExecution).code.length <= 24576,
            "production runtime limit"
        );
        require(
            recovery.streamModuleInterfaceId() == 0x83685f5c
                && recovery.supportsInterface(0x83685f5c)
                && !recovery.supportsInterface(0xffffffff),
            "canonical module interface"
        );
        require(
            keccak256(recovery.finalityRecoveryManifestBytes(request.recoveryManifest.contentHash))
                == request.recoveryManifest.contentHash,
            "retained actual704 bytes"
        );
        require(
            keccak256(
                abi.encode(
                    recovery.finalityRecoveryIntentRequest(request.recoveryManifest.contentHash)
                )
            ) == keccak256(abi.encode(request)),
            "retained full Request"
        );
        IStreamArtistRecoveryIntent.Facts memory facts = _facts();
        require(facts.requestHash == keccak256(abi.encode(request)), "exact request commitment");
        require(
            facts.scopeHash == recovery.finalityRecoveryScopeHash(scope)
                && facts.oldValueHash == recovery.finalityRecoveryOldValueHash(request)
                && facts.newValueHash == recovery.finalityRecoveryNewValueHash(request),
            "same preparation selectors"
        );
        (bool ok,) = _run(2, 0);
        require(ok, "actual companion execution");
        StreamFinalityRecoveryRecord memory r = recovery.finalityRecoveryRecord(ACTION);
        require(
            r.executed && r.recoveryId == ACTION && r.originalFinalityRecordHash == originalHash
                && r.predecessorRecoveryId == 0 && r.generation == 1 && r.artworkBytesChanged
                && r.executedAt == 1000000,
            "executed append"
        );
        require(
            r.evidence.artistEvidenceKind == StreamFinalityRecoveryArtistEvidenceKind.APPROVAL
                && r.evidence.artistEvidenceHash == APPROVAL
                && r.evidence.artistSigner == address(0xA11CE)
                && r.evidence.artistId == savedArtistId && r.evidence.artistAuthorityClass == 1
                && r.evidence.ownerEvidenceHash == OWNER && r.evidence.ownerNoticeEndsAt == 999000
                && r.evidence.ownerAcknowledgementCount == 3,
            "exact evidence snapshot"
        );
        (bool pin, address target, bytes32 hash, bytes32 base, bytes32 id) =
            recovery.resolvedFinalityRoute(oldRoute.componentType, scope);
        require(
            pin && target == address(renderer)
                && hash == keccak256(abi.encode(request.replacementRoute)) && base == originalHash
                && id == ACTION,
            "actual selected route"
        );
        (bool pin2, bool healthy, bytes32 hash2, bytes32 id2) =
            recovery.finalityRecoveryRouteStatus(oldRoute.componentType, scope);
        require(pin2 && healthy && hash2 == hash && id2 == id, "resolved/status parity");
        require(recovery.incompleteFinalityRecoveryRefreshPlanCount() == 1, "plan created");
    }

    function testCompanionOwnerLateNoticeFailureRollsBackAndSameActionRetries() public {
        _owner(true, 1000001);
        (bool ok, bytes memory error) = _run(2, 0);
        _error(
            ok,
            error,
            abi.encodeWithSelector(
                StreamFinalityRecoveryOwnerReads.FinalityRecoveryOwnerNoticeOpen.selector,
                uint64(1000001)
            )
        );
        require(
            !recovery.finalityRecoveryRecord(ACTION).executed
                && recovery.incompleteFinalityRecoveryRefreshPlanCount() == 0,
            "record/count rollback"
        );
        (bytes32 head,, uint64 generation) = recovery.activeFinalityRecovery(scope);
        require(head == 0 && generation == 0, "head rollback");
        _owner(true, 999000);
        (ok,) = _run(2, 0);
        require(ok, "identical action/request retry");
        bytes32 saved = keccak256(abi.encode(recovery.finalityRecoveryRecord(ACTION)));
        _owner(false, 1000001);
        artist.answer(_approvalRead(), hex"");
        require(
            saved == keccak256(abi.encode(recovery.finalityRecoveryRecord(ACTION))),
            "executed immutable history ignores later evidence"
        );
        vm.chainId(fixtureChain + 1);
        require(this.currentTestChainId() == fixtureChain + 1, "changed chain observed");
        (ok, error) = address(recovery)
            .call(abi.encodeCall(recovery.continueFinalityRecoveryRefresh, (scope, ACTION)));
        _error(
            ok,
            error,
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector, address(0)
            )
        );
        vm.chainId(fixtureChain);
        require(this.currentTestChainId() == fixtureChain, "original chain restored");
        recovery.continueFinalityRecoveryRefresh(scope, ACTION);
        require(
            recovery.finalityRecoveryRefreshPlan(ACTION).complete
                && recovery.incompleteFinalityRecoveryRefreshPlanCount() == 0,
            "refresh independent from artist/owner readiness"
        );
    }

    function testCompanionCallerContextAndArtistReadFailuresThenFindingSnapshot() public {
        (bool ok, bytes memory error) =
            address(recovery).call(abi.encodeCall(recovery.executeFinalityRecovery, (request)));
        _error(
            ok,
            error,
            abi.encodeWithSelector(
                StreamArtworkFinalityRecovery.FinalityRecoveryCallerNotExecutor.selector,
                address(this)
            )
        );
        (ok, error) = _run(1, 0);
        _error(
            ok,
            error,
            abi.encodeWithSelector(
                StreamFinalityRecoveryExecution.FinalityRecoveryActionClassInvalid.selector,
                uint8(1)
            )
        );
        (ok, error) = _run(2, keccak256("wrong scope"));
        _error(
            ok,
            error,
            abi.encodeWithSelector(
                StreamFinalityRecoveryExecution.FinalityRecoveryTransitionContextMismatch.selector
            )
        );
        artist.answer(_approvalRead(), hex"");
        (ok, error) = _run(2, 0);
        _error(
            ok,
            error,
            abi.encodeWithSelector(
                StreamFinalityRecoveryExecution.FinalityRecoveryArtistEvidenceUnreadable.selector
            )
        );
        artist.answer(_approvalRead(), abi.encode(false, bytes32(0), address(0), uint8(0)));
        U.Target memory target = U.Target(
            address(recovery), ACTION, scope, originalHash, request.recoveryManifest.contentHash
        );
        artist.answer(
            abi.encodeCall(IStreamArtistUnavailability.verifyRecoveryUnavailability, (target)),
            abi.encode(true, keccak256("finding"), savedArtistId, uint64(999000))
        );
        (ok,) = _run(2, 0);
        require(ok, "actual companion finding branch");
        StreamFinalityRecoveryRecord memory r = recovery.finalityRecoveryRecord(ACTION);
        require(
            r.evidence.artistEvidenceKind == StreamFinalityRecoveryArtistEvidenceKind.UNAVAILABILITY
                && r.evidence.artistSigner == address(0) && r.evidence.artistAuthorityClass == 0
                && r.evidence.artistNoticeEndsAt == 999000 && r.evidence.artistId == savedArtistId,
            "finding snapshot without invented signer"
        );
    }
}
