// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StreamDistributionFixture.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintCounterPolicy.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintCounterReads.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamOperatorDistributionMerkle.sol";

/// @notice Actual current Manager/Ledger and Safe; typed Core, Artist, registry and entropy boundaries.
contract StreamOperatorDistributionTest is OfficialSafeFixture {
    DistributionVm private constant vm =
        DistributionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    DistributionCoreBoundary private core;
    DistributionRegistryBoundary private registry;
    DistributionArtistBoundary private artist;
    DistributionEntropyBoundary private entropy;
    DistributionDelegationBoundary private delegates;
    StreamMintManager private manager;
    StreamMintLedger private ledger;
    StreamOperatorDistribution private distribution;
    bytes32 private constant PHASE = keccak256("airdrop phase");
    bytes32 private constant SUPPLY = keccak256("airdrop supply");
    bytes32 private constant RECIPIENT = keccak256("airdrop recipient");
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    IStreamOperatorDistribution.Program private program;
    bytes32 private rootOverride;
    bytes32 private supplyConfigHash = keccak256("supply config");
    bytes32 private recipientConfigHash = keccak256("recipient config");
    IStreamMintLedger.CounterCapMode private recipientCapMode =
    IStreamMintLedger.CounterCapMode.STATIC;
    bytes32 private constant EXTRA_RECIPIENT = keccak256("second distribution recipient list");
    bytes32 private extraRecipientConfigHash;
    bytes32 private applicationHashOverride;
    bool private legacyMerkleHash;

    struct RecipientList {
        address first;
        address second;
        bytes32 root;
        IStreamMintCounterPolicy.AllowlistProof firstProof;
        IStreamMintCounterPolicy.AllowlistProof secondProof;
    }

    function setUp() public {
        vm.warp(100);
        vm.deal(address(this), 10 ether);
        core = new DistributionCoreBoundary();
        registry = new DistributionRegistryBoundary(address(new DistributionAuthorityBoundary()));
        artist = new DistributionArtistBoundary(address(core));
        entropy = new DistributionEntropyBoundary(address(core));
        delegates = new DistributionDelegationBoundary();
        core.configure(address(registry), address(artist), address(entropy), address(0));
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(IStreamCore(address(core)), ledger, registry);
        core.configure(address(registry), address(artist), address(entropy), address(manager));
        artist.configure(address(manager));
        ledger.setLedgerWriter(address(manager), true);
        distribution = new StreamOperatorDistribution(
            StreamOperatorDistribution.DeploymentConfig(
                address(core),
                address(manager),
                address(registry),
                registry.governanceExecutor(),
                address(delegates),
                1,
                keccak256("distribution manifest")
            )
        );
        registry.register(distribution);
        program = IStreamOperatorDistribution.Program(
            address(this),
            0,
            SUPPLY,
            RECIPIENT,
            10,
            3,
            IStreamOperatorDistribution.DeliveryMode.FAILURE_ISOLATED,
            false
        );
    }

    function testDistinctRecipientsUseOneCurrentBatchAndNoRevenueEvents() public {
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        vm.recordLogs();
        (uint256[] memory ids, bytes32 root) = _send(batch);
        require(
            ids.length == 2 && root != 0 && manager.nextOperationNonce() == 2,
            "one batch nonce range"
        );
        require(core.ownerOf(ids[0]) == ALICE && core.ownerOf(ids[1]) == BOB, "recipient delivery");
        require(
            _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0)) == 2,
            "supply ledger"
        );
        require(
            _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 1,
            "alice ledger"
        );
        require(
            _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, address(distribution))
                == 0,
            "custody not recipient"
        );
        DistributionVm.Log[] memory logs = vm.getRecordedLogs();
        uint256 batches;
        bytes32 batchEvent = keccak256(
            "MintBatchExecuted(uint16,bytes32,uint256,bytes32,address,address,address,uint256,uint256,bytes32,bytes32,bytes32,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == batchEvent) ++batches;
            require(
                logs[i].emitter == address(manager) || logs[i].emitter == address(ledger)
                    || logs[i].emitter == address(core) || logs[i].emitter == address(distribution),
                "no settlement writer"
            );
        }
        require(batches == 1 && distribution.sliceUsed(1, PHASE, 0), "single batch durable slice");
    }

    function testDuplicateRecipientsAggregateAndEnforceLedgerCap() public {
        program.perRecipientCap = 1;
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, ALICE));
        _configure(batch);
        vm.expectPartialRevert(IStreamMintLedger.CounterCapExceeded.selector);
        _send(batch);
        _rolledBack();
    }

    function testSupplyCounterEnforcedByLedger() public {
        program.totalQuantity = 1;
        program.perRecipientCap = 1;
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        vm.expectPartialRevert(IStreamMintLedger.CounterCapExceeded.selector);
        _send(batch);
        _rolledBack();
    }

    function testCollectionSupplyScopeRejectsBeforeMintCountersOrReplay() public {
        _rejectSupplyScope(IStreamMintCounterPolicy.CounterScope.COLLECTION);
    }

    function testGlobalSupplyScopeRejectsBeforeMintCountersOrReplay() public {
        _rejectSupplyScope(IStreamMintCounterPolicy.CounterScope.GLOBAL);
    }

    function testExplicitPhaseSupplyDefinitionDistributesNormally() public {
        supplyConfigHash = ledger.registerCounterDefinition(
            _definition(
                IStreamMintCounterPolicy.CounterScope.PHASE,
                IStreamMintManager.CounterKeyMode.CONSTANT
            )
        );
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        (bool defined, IStreamMintCounterPolicy.Definition memory selected) =
            ledger.counterDefinitionForManager(address(manager), supplyConfigHash);
        require(
            defined && selected.scope == IStreamMintCounterPolicy.CounterScope.PHASE,
            "explicit phase selected"
        );
        require(
            _resolvedSubject(SUPPLY, address(0)) == _supplySubject(1, PHASE),
            "original phase supply subject"
        );
        _send(batch);
        require(core.ownerOf(1) == ALICE && core.ownerOf(2) == BOB, "explicit phase delivered");
        require(
            _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0)) == 2,
            "explicit phase supply consumed"
        );
        require(manager.isAuthorizationUsed(batch.authorizationId), "authorization consumed");
    }

    function testLateGlobalDefinitionCannotReinterpretLegacyDistributionSupply() public {
        IStreamMintCounterPolicy.Definition memory definition = _definition(
            IStreamMintCounterPolicy.CounterScope.GLOBAL, IStreamMintManager.CounterKeyMode.CONSTANT
        );
        supplyConfigHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition));
        (bool known,) = ledger.counterDefinition(supplyConfigHash);
        require(!known, "definition initially absent");
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        require(
            _resolvedSubject(SUPPLY, address(0)) == _supplySubject(1, PHASE),
            "legacy phase subject selected"
        );
        require(
            ledger.registerCounterDefinition(definition) == supplyConfigHash,
            "same hash registered later"
        );
        (bool nowKnown, IStreamMintCounterPolicy.Definition memory registered) =
            ledger.counterDefinition(supplyConfigHash);
        require(
            nowKnown && registered.scope == IStreamMintCounterPolicy.CounterScope.GLOBAL,
            "real global definition exists"
        );
        (bool selected, IStreamMintCounterPolicy.Definition memory retained) =
            ledger.counterDefinitionForManager(address(manager), supplyConfigHash);
        require(
            !selected && retained.scope == IStreamMintCounterPolicy.CounterScope.PHASE,
            "manager retains absent legacy definition"
        );
        require(
            _resolvedSubject(SUPPLY, address(0)) == _supplySubject(1, PHASE),
            "late registration preserves phase subject"
        );
        _send(batch);
        require(core.ownerOf(1) == ALICE && core.ownerOf(2) == BOB, "legacy phase delivered");
        require(
            _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0)) == 2,
            "legacy phase supply consumed"
        );
        require(
            ledger.counterValue(_valueKey(0, 0, SUPPLY, _supplySubject(0, 0))) == 0,
            "late global storage remains unused"
        );
    }

    function testCollectionRecipientScopeRemainsAllowed() public {
        _sharedRecipientScope(IStreamMintCounterPolicy.CounterScope.COLLECTION);
    }

    function testGlobalRecipientScopeRemainsAllowed() public {
        _sharedRecipientScope(IStreamMintCounterPolicy.CounterScope.GLOBAL);
    }

    function testDirectRejectRollsBackWholeBatchAndLedger() public {
        program.deliveryMode = IStreamOperatorDistribution.DeliveryMode.DIRECT;
        IStreamMintManager.MintBatch memory batch =
            _batch(_recipients(ALICE, address(new DistributionReceiver(1))));
        _configure(batch);
        vm.expectRevert();
        _send(batch);
        _rolledBack();
    }

    function testDirectBatchDeliversAndUsesBeneficiaryCounter() public {
        program.deliveryMode = IStreamOperatorDistribution.DeliveryMode.DIRECT;
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        _send(batch);
        require(core.ownerOf(1) == ALICE && core.ownerOf(2) == BOB, "direct delivered");
    }

    function testRejectingReceiverDivertsExactElementAndClaimSurvivesRevocation() public {
        DistributionReceiver receiver = new DistributionReceiver(1);
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(address(receiver), BOB));
        _configure(batch);
        vm.recordLogs();
        _send(batch);
        require(
            core.ownerOf(1) == address(distribution) && core.ownerOf(2) == BOB, "sibling delivery"
        );
        require(distribution.nftClaim(1).beneficiary == address(receiver), "claim beneficiary");
        _event(keccak256("AirdropDeliveryDiverted(uint16,uint256,bytes32,uint256,address)"), 1);
        registry.revoke(address(distribution));
        manager.setPhasePaused(1, PHASE, true);
        require(
            !receiver.claim(distribution, 1, address(receiver)), "failed retry remains available"
        );
        require(receiver.claim(distribution, 1, ALICE), "beneficiary redirects owed token");
        require(
            core.ownerOf(1) == ALICE && distribution.nftClaim(1).beneficiary == address(0),
            "claim completed"
        );
        vm.expectRevert();
        receiver.claim(distribution, 1, ALICE);
    }

    function testReturnBombAndGasBombCannotBlockSibling() public {
        DistributionReceiver bomb = new DistributionReceiver(2);
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(address(bomb), BOB));
        _configure(batch);
        _send(batch);
        require(
            core.ownerOf(2) == BOB && distribution.nftClaim(1).beneficiary == address(bomb),
            "return bomb isolated"
        );
        bomb.setMode(3);
        require(!bomb.claim(distribution, 1, address(bomb)), "gas bomb isolated");
        require(distribution.nftClaim(1).beneficiary == address(bomb), "retained claim");
    }

    function testClaimCannotReenterAndStealSibling() public {
        DistributionReceiver receiver = new DistributionReceiver(1);
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(address(receiver), BOB));
        _configure(batch);
        _send(batch);
        receiver.setMode(4);
        receiver.setReentry(distribution, 1);
        require(receiver.claim(distribution, 1, address(receiver)), "outer claim completes");
        require(!receiver.reentrySucceeded(), "guarded claim");
    }

    function testOnlyBeneficiaryCanRedirectClaim() public {
        IStreamMintManager.MintBatch memory batch =
            _batch(_recipients(address(new DistributionReceiver(1)), BOB));
        _configure(batch);
        _send(batch);
        vm.expectPartialRevert(IStreamOperatorDistribution.DistributionClaimUnavailable.selector);
        distribution.claimNft(1, ALICE);
    }

    function testLiveDelegateTriggersOnlyBeneficiaryAndExpiryFails() public {
        DistributionReceiver receiver = new DistributionReceiver(1);
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(address(receiver), BOB));
        _configure(batch);
        _send(batch);
        delegates.set(
            address(receiver), address(this), address(core), 1, this.distributionTime() + 100
        );
        require(!distribution.claimNftFor(1, false, 0), "delegate cannot substitute a receiver");
        receiver.setMode(0);
        vm.warp(this.distributionTime() + 100);
        vm.expectPartialRevert(StreamNativeAuctionDelegation.DelegationNotFound.selector);
        distribution.claimNftFor(1, false, 0);
        delegates.set(
            address(receiver), address(this), address(core), 1, this.distributionTime() + 100
        );
        require(
            distribution.claimNftFor(1, false, 0) && core.ownerOf(1) == address(receiver),
            "live exact delegated delivery"
        );
    }

    /// @dev Read after vm.warp in a fresh frame; via-IR may cache timestamp within the test frame.
    function distributionTime() external view returns (uint256) {
        return block.timestamp;
    }

    function testReplayAndRecipientCommitmentCannotBeChanged() public {
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        batch.beneficiaries[0] = BOB;
        vm.expectPartialRevert(IStreamOperatorDistribution.DistributionCommitmentMismatch.selector);
        _send(batch);
        batch.beneficiaries[0] = ALICE;
        _send(batch);
        vm.expectPartialRevert(IStreamOperatorDistribution.DistributionSliceUsed.selector);
        _send(batch);
    }

    function testTwoCommittedSlicesConsumeIndependentlyWithExactProofs() public {
        IStreamMintManager.MintBatch memory first = _batch(_recipients(ALICE, BOB));
        IStreamMintManager.MintBatch memory second = _batch(_recipients(BOB, ALICE));
        second.authorizationId = distribution.sliceAuthorization(1, PHASE, 1);
        second.contextHash = distribution.sliceHash(1, second);
        bytes32 a = first.contextHash;
        bytes32 b = second.contextHash;
        rootOverride = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
        _configure(first);
        second.expectedPolicyHash = first.expectedPolicyHash;
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = b;
        distribution.distribute(program, 0, proof, first, "");
        proof[0] = a;
        distribution.distribute(program, 1, proof, second, "");
        require(
            core.minted() == 4 && distribution.sliceUsed(1, PHASE, 0)
                && distribution.sliceUsed(1, PHASE, 1),
            "independent committed slices"
        );
        require(
            _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 2,
            "cross-slice recipient ledger"
        );
        require(
            manager.isAuthorizationUsed(first.authorizationId)
                && manager.isAuthorizationUsed(second.authorizationId),
            "distinct durable authorizations"
        );
    }

    function testHashPreimagesUseExactDomainsAndAbiArrays() public view {
        IStreamMintManager.MintBatch memory b = _batch(_recipients(ALICE, BOB));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_OPERATOR_DISTRIBUTION_SLICE_V1"),
                block.chainid,
                address(distribution),
                address(core),
                address(manager),
                uint256(1),
                PHASE,
                uint256(0),
                b.beneficiaries,
                b.tokenData,
                b.mintCommitments
            )
        );
        require(b.contextHash == expected, "exact slice encoding");
        require(
            b.authorizationId
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_OPERATOR_DISTRIBUTION_AUTHORIZATION_V1"),
                        block.chainid,
                        address(distribution),
                        address(core),
                        address(manager),
                        uint256(1),
                        PHASE,
                        uint256(0)
                    )
                ),
            "exact authorization encoding"
        );
        require(distribution.sliceHash(1, b) != expected, "index domain isolation");
    }

    function testModuleRevocationBlocksNewBatchWithoutConsumingSlice() public {
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        registry.revoke(address(distribution));
        vm.expectPartialRevert(IStreamOperatorDistribution.DistributionNotActive.selector);
        _send(batch);
        _rolledBack();
    }

    function testUnknownOperatorAndPayerRejectBeforeMint() public {
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        vm.prank(ALICE);
        vm.expectPartialRevert(IStreamOperatorDistribution.DistributionNotOperator.selector);
        _send(batch);
        batch.payer = ALICE;
        vm.expectPartialRevert(IStreamOperatorDistribution.InvalidDistribution.selector);
        _send(batch);
        _rolledBack();
    }

    function testExactOperatorRevealFeeFundsAllTokensAndFailureRetainsEscrow() public {
        entropy.setFee(0.01 ether);
        entropy.fail(false, true);
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        vm.expectPartialRevert(IStreamOperatorDistribution.DistributionFeeMismatch.selector);
        _send(batch);
        distribution.distribute{ value: 0.02 ether }(program, 0, new bytes32[](0), batch, "");
        require(
            entropy.revealFeeEscrow(1) == 0.02 ether && address(distribution).balance == 0,
            "all obligations funded"
        );
        require(
            core.ownerOf(1) == ALICE && core.ownerOf(2) == BOB,
            "provider outage cannot undo distribution"
        );
    }

    function testFundingFailureRollsBackMintSliceAndLedger() public {
        entropy.setFee(1);
        entropy.fail(true, false);
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        vm.expectRevert();
        distribution.distribute{ value: 2 }(program, 0, new bytes32[](0), batch, "");
        _rolledBack();
    }

    function testOwnerWindowFundsWithoutAutomaticRequest() public {
        entropy.setMode(1);
        entropy.setFee(1);
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        distribution.distribute{ value: 2 }(program, 0, new bytes32[](0), batch, "");
        require(entropy.revealFeeEscrow(1) == 2 && entropy.requests() == 0, "owner window funding");
    }

    function testPreparedFreeBatchUsesCurrentManagerAndLedger() public {
        program.prepared = true;
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        _send(batch);
        require(
            core.ownerOf(1) == ALICE && core.ownerOf(2) == BOB && manager.nextOperationNonce() == 2,
            "prepared batch"
        );
    }

    function testRealSafe141OperatorExecutesAndSafeRecipientReceives() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xD151;
        keys[1] = 0xD152;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 6529);
        program.operator = address(safe);
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(address(safe), BOB));
        _configure(batch);
        require(
            executeSafe(
                safe,
                keys,
                address(distribution),
                0,
                abi.encodeCall(
                    distribution.distribute, (program, 0, new bytes32[](0), batch, bytes(""))
                ),
                0
            ),
            "Safe threshold CALL"
        );
        require(
            core.ownerOf(1) == address(safe) && core.ownerOf(2) == BOB && safe.nonce() == 1,
            "Safe received and executed"
        );
    }

    function testFuzzDistinctRecipientsConserveSupply(uint8 input) public {
        uint256 quantity = uint256(input) % 10 + 1;
        address[] memory recipients = new address[](quantity);
        for (uint256 i; i < quantity; ++i) {
            recipients[i] = address(uint160(1000 + i));
        }
        IStreamMintManager.MintBatch memory batch = _batch(recipients);
        _configure(batch);
        _send(batch);
        require(
            core.minted() == quantity
                && _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0))
                    == quantity,
            "supply conservation"
        );
        for (uint256 i; i < quantity; ++i) {
            require(core.ownerOf(i + 1) == recipients[i], "ordered delivery");
        }
    }

    function testMerklePhaseCapsUseHeterogeneousOriginalLeavesAndProjectedDuplicates() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        address[] memory recipients = new address[](3);
        recipients[0] = ALICE;
        recipients[1] = BOB;
        recipients[2] = BOB;
        IStreamMintManager.MintBatch memory b =
            _merkleBatch(recipients, list, IStreamMintCounterPolicy.CounterScope.PHASE);
        bytes32 root = _merklePreflight(b);
        require(
            _resolvedCap(b, 0, list.firstProof) == 1 && _resolvedCap(b, 1, list.secondProof) == 3,
            "leaf caps differ below registered ceiling"
        );
        (uint256[] memory ids, bytes32 actualRoot) = _send(b);
        require(
            actualRoot == root && ids.length == 3 && core.ownerOf(ids[0]) == ALICE
                && core.ownerOf(ids[1]) == BOB && core.ownerOf(ids[2]) == BOB,
            "ordered heterogeneous distribution"
        );
        require(
            _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 1
                && _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, BOB) == 2
                && _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0)) == 3,
            "beneficiary counts and phase supply conserved"
        );
        _merkleConsumed(b, root, 0);
    }

    function testMerkleCollectionScopeUsesSharedRecipientKeyWithPhaseSupply() public {
        RecipientList memory list = _recipientList(ALICE, 2, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, ALICE), list, IStreamMintCounterPolicy.CounterScope.COLLECTION
        );
        bytes32 root = _merklePreflight(b);
        _send(b);
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            PHASE,
            RECIPIENT,
            address(0),
            ALICE,
            address(distribution),
            address(0),
            bytes32(0)
        );
        require(
            ledger.counterValue(_valueKey(1, 0, RECIPIENT, subject)) == 2
                && ledger.counterValue(_valueKey(1, PHASE, RECIPIENT, subject)) == 0,
            "collection recipient scope is genuine"
        );
        require(
            _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0)) == 2,
            "supply remains phase scoped"
        );
        _merkleConsumed(b, root, 0);
    }

    function testMerkleMissingBadAndReorderedRecipientProofsRollbackAndIdenticalRetry() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, BOB), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        bytes32 root = _merklePreflight(b);
        bytes memory original = b.resolverData;
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](0);
        b.resolverData = abi.encode(groups);
        _merkleReject(
            b,
            root,
            0,
            new bytes32[](0),
            0,
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistProofCountMismatch.selector,
                uint256(0),
                uint256(1)
            )
        );
        groups = abi.decode(original, (IStreamMintCounterPolicy.AllowlistProof[][]));
        groups[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        groups[0][0] = list.firstProof;
        b.resolverData = abi.encode(groups);
        _merkleReject(
            b,
            root,
            0,
            new bytes32[](0),
            0,
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistProofCountMismatch.selector,
                uint256(1),
                uint256(2)
            )
        );
        groups = abi.decode(original, (IStreamMintCounterPolicy.AllowlistProof[][]));
        groups[0][0].proof[0] = keccak256("incorrect original sibling");
        b.resolverData = abi.encode(groups);
        _merkleReject(b, root, 0, new bytes32[](0), 0, _proofError(ALICE));
        groups = abi.decode(original, (IStreamMintCounterPolicy.AllowlistProof[][]));
        groups[0][0] = list.secondProof;
        groups[0][1] = list.firstProof;
        b.resolverData = abi.encode(groups);
        _merkleReject(b, root, 0, new bytes32[](0), 0, _proofError(ALICE));
        b.resolverData = original;
        require(_merklePreflight(b) == root, "same valid root after every failed witness");
        (, bytes32 actualRoot) = _send(b);
        require(actualRoot == root, "identical request succeeds after witness repair");
        _merkleConsumed(b, root, 0);
    }

    function testMerkleOtherPhaseLeafCannotAuthorizeCurrentBeneficiary() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        bytes32 wrongLeaf = _recipientLeaf(ALICE, 1, RECIPIENT, keccak256("other phase"));
        list.root = _pair(wrongLeaf, list.firstProof.proof[0]);
        list.secondProof.proof[0] = wrongLeaf;
        require(
            _pair(wrongLeaf, list.firstProof.proof[0]) == list.root,
            "rejected proof genuinely belongs to the other phase"
        );
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, BOB), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        // A correct-domain BOB leaf proves the actual counter configuration is usable.
        require(_resolvedCap(b, 1, list.secondProof) == 3, "valid same-root current-domain sibling");
        IStreamMintManager.MintBatch memory valid = _batch(_one(BOB));
        valid.expectedPolicyHash = b.expectedPolicyHash;
        _withRecipientProofs(valid, list);
        bytes32 root = _merklePreflight(valid);
        _merkleReject(b, root, 0, new bytes32[](0), 0, _proofError(ALICE));
    }

    function testMerkleZeroLeafRejectsEvenWithValidMembership() public {
        _invalidRecipientCap(0);
    }

    function testMerkleOverCeilingLeafRejectsEvenWithValidMembership() public {
        _invalidRecipientCap(4);
    }

    function testMerkleDuplicateProjectionRejectsBeforeAnyWrite() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, ALICE), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        require(
            _resolvedCap(b, 0, list.firstProof) == 1 && _resolvedCap(b, 1, list.firstProof) == 1,
            "both duplicate proofs individually valid"
        );
        IStreamMintManager.MintBatch memory single = _batch(_one(ALICE));
        single.expectedPolicyHash = b.expectedPolicyHash;
        _withRecipientProofs(single, list);
        bytes32 root = _merklePreflight(single);
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            PHASE,
            RECIPIENT,
            address(0),
            ALICE,
            address(distribution),
            address(0),
            bytes32(0)
        );
        _merkleReject(
            b,
            root,
            0,
            new bytes32[](0),
            0,
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector,
                manager.previewCounterValueKey(1, PHASE, RECIPIENT, subject),
                uint256(2),
                uint256(1)
            )
        );
    }

    function testMerkleCrossSliceCapAndReplayPreserveFirstConsumption() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        recipientCapMode = IStreamMintLedger.CounterCapMode.MERKLE_STATIC;
        recipientConfigHash = _listDefinition(list, IStreamMintCounterPolicy.CounterScope.PHASE);
        IStreamMintManager.MintBatch memory first = _batch(_recipients(ALICE, BOB));
        IStreamMintManager.MintBatch memory second = _batch(_recipients(ALICE, BOB));
        second.authorizationId = distribution.sliceAuthorization(1, PHASE, 1);
        second.contextHash = distribution.sliceHash(1, second);
        rootOverride = _pair(first.contextHash, second.contextHash);
        _withRecipientProofs(first, list);
        _withRecipientProofs(second, list);
        _configure(first);
        second.expectedPolicyHash = first.expectedPolicyHash;
        bytes32 firstRoot = _merklePreflight(first);
        bytes32 unusedSecondRoot = _merklePreflight(second);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = second.contextHash;
        distribution.distribute(program, 0, proof, first, "");
        _merkleConsumed(first, firstRoot, 0);
        _merkleReject(
            first,
            firstRoot,
            0,
            proof,
            0,
            abi.encodeWithSelector(
                IStreamOperatorDistribution.DistributionSliceUsed.selector, uint256(0)
            )
        );
        proof[0] = first.contextHash;
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            PHASE,
            RECIPIENT,
            address(0),
            ALICE,
            address(distribution),
            address(0),
            bytes32(0)
        );
        _merkleReject(
            second,
            unusedSecondRoot,
            1,
            proof,
            0,
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector,
                manager.previewCounterValueKey(1, PHASE, RECIPIENT, subject),
                uint256(2),
                uint256(1)
            )
        );
        require(
            core.minted() == 2 && manager.nextOperationNonce() == 2
                && !distribution.sliceUsed(1, PHASE, 1)
                && !manager.isAuthorizationUsed(second.authorizationId)
                && _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 1,
            "later slice cannot reset earlier leaf use"
        );
        _merkleConsumed(first, firstRoot, 0);
    }

    function testMerkleConfiguredCounterOrderIsPreservedThroughDistribution() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        RecipientList memory extra = _recipientList(ALICE, 3, BOB, 2, EXTRA_RECIPIENT);
        extraRecipientConfigHash =
            _listDefinition(extra, IStreamMintCounterPolicy.CounterScope.PHASE);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, BOB), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](2);
        groups[0] = _proofGroup(b, list);
        groups[1] = _proofGroup(b, extra);
        b.resolverData = abi.encode(groups);
        bytes memory original = b.resolverData;
        bytes32 root = _merklePreflight(b);
        groups[0] = _proofGroup(b, extra);
        groups[1] = _proofGroup(b, list);
        b.resolverData = abi.encode(groups);
        _merkleReject(b, root, 0, new bytes32[](0), 0, _proofError(ALICE));
        b.resolverData = original;
        require(_merklePreflight(b) == root, "configured order restores exact original root");
        _send(b);
        require(
            _count(EXTRA_RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 1
                && _count(EXTRA_RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, BOB) == 1,
            "both original Merkle counters consumed"
        );
        _merkleConsumed(b, root, 0);
    }

    function testMerkleDirectReceiverFailureRollsBackAndIdenticalBatchRetries() public {
        program.deliveryMode = IStreamOperatorDistribution.DeliveryMode.DIRECT;
        DistributionReceiver receiver = new DistributionReceiver(1);
        RecipientList memory list = _recipientList(ALICE, 1, address(receiver), 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, address(receiver)), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        bytes32 root = _merklePreflight(b);
        _merkleReject(
            b, root, 0, new bytes32[](0), 0, abi.encodeWithSignature("Error(string)", "reject")
        );
        _rolledBack();
        receiver.setMode(0);
        require(_merklePreflight(b) == root, "receiver repair does not change original request");
        (, bytes32 actualRoot) = _send(b);
        require(
            actualRoot == root && core.ownerOf(1) == ALICE && core.ownerOf(2) == address(receiver),
            "exact DIRECT retry succeeds"
        );
        _merkleConsumed(b, root, 0);
    }

    function testMerkleLateRevealFundingFailureRollsBackAndIdenticalBatchRetries() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, BOB), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        entropy.setFee(1);
        bytes32 root = _merklePreflight(b);
        entropy.fail(true, false);
        _merkleReject(
            b,
            root,
            0,
            new bytes32[](0),
            2,
            abi.encodeWithSelector(
                IStreamImmediateSaleReveal.SaleRevealDependencyInvalid.selector, address(entropy)
            )
        );
        _rolledBack();
        entropy.fail(false, false);
        require(
            _merklePreflight(b) == root, "late funding failure restored exact operation identity"
        );
        (, bytes32 actualRoot) =
            distribution.distribute{ value: 2 }(program, 0, new bytes32[](0), b, "");
        require(
            actualRoot == root && entropy.revealFeeEscrow(1) == 2 && entropy.requests() == 2
                && address(distribution).balance == 0,
            "each reveal obligation funded once"
        );
        _merkleConsumed(b, root, 0);
    }

    function testMerkleIsolatedClaimKeepsOriginalBeneficiaryCapAfterRedirection() public {
        DistributionReceiver receiver = new DistributionReceiver(1);
        RecipientList memory list = _recipientList(address(receiver), 1, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(address(receiver), BOB),
            list,
            IStreamMintCounterPolicy.CounterScope.COLLECTION
        );
        bytes32 root = _merklePreflight(b);
        _send(b);
        IStreamOperatorDistribution.NftClaim memory claim = distribution.nftClaim(1);
        require(
            claim.collectionId == 1 && claim.phaseId == PHASE
                && claim.beneficiary == address(receiver)
                && core.ownerOf(1) == address(distribution) && core.ownerOf(2) == BOB,
            "exact failed element retained under original identity"
        );
        require(
            _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, address(receiver)) == 1
                && _count(
                    RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, address(distribution)
                ) == 0,
            "custody does not own recipient allocation"
        );
        vm.expectPartialRevert(IStreamOperatorDistribution.DistributionClaimUnavailable.selector);
        distribution.claimNft(1, ALICE);
        registry.revoke(address(distribution));
        manager.setPhasePaused(1, PHASE, true);
        require(
            receiver.claim(distribution, 1, ALICE),
            "original beneficiary can redirect after phase revocation"
        );
        require(
            core.ownerOf(1) == ALICE && distribution.nftClaim(1).beneficiary == address(0)
                && _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 0
                && _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, address(receiver))
                == 1,
            "claim delivery never migrates or consumes allocation twice"
        );
        _merkleConsumed(b, root, 0);
    }

    function testMerklePreparedConsumerKeepsOriginalManagerRootAndCaps() public {
        program.prepared = true;
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b =
            _merkleBatch(_one(ALICE), list, IStreamMintCounterPolicy.CounterScope.PHASE);
        bytes32 root = _merklePreflight(b);
        (, bytes32 actualRoot) = _send(b);
        require(
            actualRoot == root && core.ownerOf(1) == ALICE && manager.nextOperationNonce() == 1
                && _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 1,
            "prepared path consumes authenticated beneficiary cap"
        );
        _merkleConsumed(b, root, 0);
    }

    function testMerklePublicationPreimageAndOriginalInterfaceRemainExact() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, BOB), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        (, IStreamMintCounterPolicy.Definition memory d) =
            ledger.counterDefinition(recipientConfigHash);
        bytes32 original = keccak256(
            abi.encode(
                keccak256("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1"),
                block.chainid,
                address(distribution),
                address(core),
                address(manager),
                uint256(1),
                PHASE,
                program
            )
        );
        bytes32 published = keccak256(
            abi.encode(
                keccak256("6529STREAM_OPERATOR_DISTRIBUTION_MERKLE_CONFIG_V1"),
                original,
                recipientConfigHash,
                d.metadataHash
            )
        );
        require(
            d.capRoot == list.root && d.metadataHash != 0
                && recipientConfigHash
                    == keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), d)),
            "original definition preimage"
        );
        (, IStreamMintManager.MintPhaseConfig memory phase) = manager.phase(1, PHASE);
        require(
            distribution.programHash(1, PHASE, program) == original
                && distribution.merkleProgramHash(1, PHASE, program, recipientConfigHash)
                    == published && phase.configHash == published && published != original,
            "additive literal publication binding"
        );
        bytes4 originalInterface = IStreamOperatorDistribution.programHash.selector
            ^ IStreamOperatorDistribution.sliceHash.selector
            ^ IStreamOperatorDistribution.sliceAuthorization.selector
            ^ IStreamOperatorDistribution.distribute.selector
            ^ IStreamOperatorDistribution.sliceUsed.selector
            ^ IStreamOperatorDistribution.nftClaim.selector
            ^ IStreamOperatorDistribution.claimNft.selector
            ^ IStreamOperatorDistribution.claimNftFor.selector;
        require(
            originalInterface == type(IStreamOperatorDistribution).interfaceId
                && distribution.supportsInterface(originalInterface)
                && distribution.supportsInterface(
                    type(IStreamOperatorDistributionMerkle).interfaceId
                ),
            "original interface remains separately advertised"
        );
        bytes32 root = _merklePreflight(b);
        _send(b);
        _merkleConsumed(b, root, 0);
    }

    function testMerkleLegacyProgramHashCannotOmitPublicationCommitment() public {
        legacyMerkleHash = true;
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, BOB), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        bytes32 root = _merklePreflight(b);
        require(
            b.expectedPolicyHash == manager.phasePolicyHash(1, PHASE),
            "actual current policy supplied"
        );
        _merkleReject(
            b,
            root,
            0,
            new bytes32[](0),
            0,
            abi.encodeWithSelector(
                IStreamOperatorDistribution.DistributionCommitmentMismatch.selector
            )
        );
    }

    function testMerkleSameRootDifferentPublicationCannotReuseEarlierApplicationHash() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        bytes32 oldDefinition = _listDefinition(list, IStreamMintCounterPolicy.CounterScope.PHASE);
        IStreamMintManager.MintBatch memory b = _batch(_recipients(ALICE, BOB));
        program.slicesRoot = distribution.sliceHash(0, b);
        // Getter is usable before any phase pins the registered definition.
        applicationHashOverride = distribution.merkleProgramHash(1, PHASE, program, oldDefinition);
        (, IStreamMintCounterPolicy.Definition memory changed) =
            ledger.counterDefinition(oldDefinition);
        changed.metadataHash = keccak256("different published recipient list bytes");
        recipientConfigHash = ledger.registerCounterDefinition(changed);
        recipientCapMode = IStreamMintLedger.CounterCapMode.MERKLE_STATIC;
        _withRecipientProofs(b, list);
        _configure(b);
        bytes32 root = _merklePreflight(b);
        require(
            changed.capRoot == list.root && recipientConfigHash != oldDefinition
                && distribution.merkleProgramHash(1, PHASE, program, recipientConfigHash)
                    != applicationHashOverride
                && manager.counterConfig(1, PHASE, RECIPIENT).counterConfigHash
                == recipientConfigHash && b.expectedPolicyHash == manager.phasePolicyHash(1, PHASE),
            "new actual definition and current policy cannot disguise old publication binding"
        );
        _merkleReject(
            b,
            root,
            0,
            new bytes32[](0),
            0,
            abi.encodeWithSelector(
                IStreamOperatorDistribution.DistributionCommitmentMismatch.selector
            )
        );
    }

    function testMerkleGetterRejectsUnknownUnpublishedAndUnsupportedDefinitions() public {
        _invalidMerkleDefinition(keccak256("unregistered distribution definition"));
        IStreamMintCounterPolicy.Definition memory d = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            keccak256("root"),
            0
        );
        _invalidMerkleDefinition(ledger.registerCounterDefinition(d));
        d.metadataHash = keccak256("published list");
        d.keyMode = IStreamMintManager.CounterKeyMode.PAYER;
        _invalidMerkleDefinition(ledger.registerCounterDefinition(d));
        d.keyMode = IStreamMintManager.CounterKeyMode.RECIPIENT;
        d.capRoot = 0;
        _invalidMerkleDefinition(ledger.registerCounterDefinition(d));
        d.keyMode = IStreamMintManager.CounterKeyMode.CONSTANT;
        _invalidMerkleDefinition(ledger.registerCounterDefinition(d));
        d.keyMode = IStreamMintManager.CounterKeyMode.RECIPIENT;
        d.scope = IStreamMintCounterPolicy.CounterScope.GLOBAL;
        _invalidMerkleDefinition(ledger.registerCounterDefinition(d));
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0,
            "getter grants no mint authority"
        );
    }

    function testMerkleGetterCannotReinterpretAnAbsentDefinitionPinnedByStaticPhase() public {
        RecipientList memory list = _recipientList(ALICE, 1, BOB, 3, RECIPIENT);
        IStreamMintCounterPolicy.Definition memory d = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            list.root,
            keccak256("late publication")
        );
        recipientConfigHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), d));
        IStreamMintManager.MintBatch memory b = _batch(_recipients(ALICE, BOB));
        _configure(b);
        require(
            ledger.registerCounterDefinition(d) == recipientConfigHash,
            "actual late definition registered"
        );
        (bool rawKnown,) = ledger.counterDefinition(recipientConfigHash);
        (bool selected,) = ledger.counterDefinitionForManager(address(manager), recipientConfigHash);
        require(rawKnown && !selected, "manager retains actual first-use absent interpretation");
        _invalidMerkleDefinition(recipientConfigHash);
        _send(b);
        require(
            core.ownerOf(1) == ALICE && core.ownerOf(2) == BOB, "original STATIC path remains valid"
        );
    }

    function _invalidMerkleDefinition(bytes32 hash) private view {
        (bool ok, bytes memory errorData) = address(distribution)
            .staticcall(abi.encodeCall(distribution.merkleProgramHash, (1, PHASE, program, hash)));
        require(
            !ok
                && keccak256(errorData)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamOperatorDistributionMerkle.DistributionMerkleDefinitionInvalid
                            .selector,
                            hash
                        )
                    ),
            "exact invalid original definition rejection"
        );
    }

    function _invalidRecipientCap(uint64 cap) private {
        RecipientList memory list = _recipientList(ALICE, cap, BOB, 3, RECIPIENT);
        IStreamMintManager.MintBatch memory b = _merkleBatch(
            _recipients(ALICE, BOB), list, IStreamMintCounterPolicy.CounterScope.PHASE
        );
        require(
            _pair(_recipientLeaf(ALICE, cap, RECIPIENT, PHASE), list.firstProof.proof[0])
                == list.root,
            "rejected cap still has authentic membership"
        );
        require(
            _resolvedCap(b, 1, list.secondProof) == 3,
            "valid in-ceiling sibling proves usable configuration"
        );
        IStreamMintManager.MintBatch memory valid = _batch(_one(BOB));
        valid.expectedPolicyHash = b.expectedPolicyHash;
        _withRecipientProofs(valid, list);
        bytes32 root = _merklePreflight(valid);
        _merkleReject(b, root, 0, new bytes32[](0), 0, _proofError(ALICE));
    }

    /// @dev Literal MPA-MERKLE preimage, independent of the production leaf helper.
    function _recipientLeaf(address account, uint64 cap, bytes32 counterId, bytes32 phaseId)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(manager),
                        uint256(1),
                        phaseId,
                        counterId,
                        account,
                        cap,
                        false,
                        uint256(0)
                    )
                )
            )
        );
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _recipientList(
        address first,
        uint64 firstCap,
        address second,
        uint64 secondCap,
        bytes32 counterId
    ) private view returns (RecipientList memory list) {
        list.first = first;
        list.second = second;
        bytes32 a = _recipientLeaf(first, firstCap, counterId, PHASE);
        bytes32 b = _recipientLeaf(second, secondCap, counterId, PHASE);
        list.root = _pair(a, b);
        list.firstProof =
            IStreamMintCounterPolicy.AllowlistProof(firstCap, false, 0, new bytes32[](1));
        list.secondProof =
            IStreamMintCounterPolicy.AllowlistProof(secondCap, false, 0, new bytes32[](1));
        list.firstProof.proof[0] = b;
        list.secondProof.proof[0] = a;
    }

    function _listDefinition(RecipientList memory list, IStreamMintCounterPolicy.CounterScope scope)
        private
        returns (bytes32)
    {
        // The original Program stays unchanged; the additive Merkle profile commits this
        // actual definition and its published list hash through the phase application hash.
        bytes32 publication = keccak256(
            abi.encode(
                "published distribution recipient list",
                list.first,
                list.firstProof.maxCount,
                list.second,
                list.secondProof.maxCount
            )
        );
        return ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                scope, IStreamMintManager.CounterKeyMode.RECIPIENT, list.root, publication
            )
        );
    }

    function _proofGroup(IStreamMintManager.MintBatch memory b, RecipientList memory list)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof[] memory proofs)
    {
        proofs = new IStreamMintCounterPolicy.AllowlistProof[](b.beneficiaries.length);
        for (uint256 i; i < proofs.length; ++i) {
            require(
                b.beneficiaries[i] == list.first || b.beneficiaries[i] == list.second,
                "fixture recipient belongs to original list"
            );
            proofs[i] = b.beneficiaries[i] == list.first ? list.firstProof : list.secondProof;
        }
    }

    function _withRecipientProofs(IStreamMintManager.MintBatch memory b, RecipientList memory list)
        private
        pure
    {
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        groups[0] = _proofGroup(b, list);
        b.resolverData = abi.encode(groups);
    }

    function _merkleBatch(
        address[] memory recipients,
        RecipientList memory list,
        IStreamMintCounterPolicy.CounterScope scope
    ) private returns (IStreamMintManager.MintBatch memory b) {
        recipientCapMode = IStreamMintLedger.CounterCapMode.MERKLE_STATIC;
        recipientConfigHash = _listDefinition(list, scope);
        b = _batch(recipients);
        _withRecipientProofs(b, list);
        _configure(b);
    }

    function _one(address recipient) private pure returns (address[] memory recipients) {
        recipients = new address[](1);
        recipients[0] = recipient;
    }

    function _merklePreflight(IStreamMintManager.MintBatch memory b)
        private
        returns (bytes32 root)
    {
        // Actual Manager authorization, proof verification, projected accounting and identity.
        vm.prank(address(distribution));
        bytes32[] memory ids;
        if (program.prepared) (root, ids) = manager.previewPreparedNativeMintOperation(b, "");
        else (root, ids) = manager.previewSingleStepMintOperation(b, "");
        require(root != 0 && ids.length == b.beneficiaries.length, "valid actual Manager preflight");
        require(
            !manager.isAuthorizationUsed(b.authorizationId) && !manager.isOperationRootUsed(root),
            "preflight reserves nothing"
        );
    }

    function _resolvedCap(
        IStreamMintManager.MintBatch memory b,
        uint256 index,
        IStreamMintCounterPolicy.AllowlistProof memory proof
    ) private view returns (uint64) {
        IStreamMintCounterReads.CounterKeyContext memory c;
        c.collectionId = b.collectionId;
        c.phaseId = b.phaseId;
        c.counterId = RECIPIENT;
        c.initialRecipient = b.initialRecipients[index];
        c.beneficiary = b.beneficiaries[index];
        c.executor = address(distribution);
        c.tokenIndex = index;
        c.contextHash = b.contextHash;
        c.resolverData = abi.encode(proof);
        IStreamMintCounterReads.CounterResolution memory r =
            IStreamMintCounterReads(address(manager)).resolveCounter(c);
        require(r.increment == 1 && r.resolutionHash != 0, "original resolved leaf accounting");
        return r.effectiveCap;
    }

    function _merkleState(IStreamMintManager.MintBatch memory b, bytes32 root, uint256 index)
        private
        view
        returns (bytes32 state)
    {
        state = keccak256(
            abi.encode(
                core.minted(),
                manager.nextOperationNonce(),
                distribution.sliceUsed(1, PHASE, index),
                manager.isAuthorizationUsed(b.authorizationId),
                manager.isOperationRootUsed(root),
                ledger.isManagerOperationRootUsed(address(manager), root),
                manager.phasePolicyHash(1, PHASE)
            )
        );
        state = keccak256(
            abi.encode(
                state,
                _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0)),
                core.balanceOf(address(distribution)),
                address(this).balance,
                address(distribution).balance,
                address(entropy).balance,
                entropy.revealFeeEscrow(1),
                entropy.requests()
            )
        );
        for (uint256 i; i < b.beneficiaries.length; ++i) {
            state = keccak256(
                abi.encode(
                    state,
                    core.balanceOf(b.beneficiaries[i]),
                    _count(
                        RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, b.beneficiaries[i]
                    ),
                    distribution.nftClaim(i + 1)
                )
            );
            if (extraRecipientConfigHash != 0) {
                state = keccak256(
                    abi.encode(
                        state,
                        _count(
                            EXTRA_RECIPIENT,
                            IStreamMintManager.CounterKeyMode.RECIPIENT,
                            b.beneficiaries[i]
                        )
                    )
                );
            }
        }
    }

    function _merkleReject(
        IStreamMintManager.MintBatch memory b,
        bytes32 root,
        uint256 index,
        bytes32[] memory sliceProof,
        uint256 value,
        bytes memory expected
    ) private {
        bytes32 beforeState = _merkleState(b, root, index);
        (bool ok, bytes memory errorData) = address(distribution).call{ value: value }(
            abi.encodeCall(distribution.distribute, (program, index, sliceProof, b, bytes("")))
        );
        require(
            !ok && keccak256(errorData) == keccak256(expected), "exact intended Merkle rejection"
        );
        require(
            _merkleState(b, root, index) == beforeState,
            "all Merkle accounting and replay rolled back"
        );
    }

    function _merkleConsumed(IStreamMintManager.MintBatch memory b, bytes32 root, uint256 index)
        private
        view
    {
        require(
            distribution.sliceUsed(1, PHASE, index)
                && manager.isAuthorizationUsed(b.authorizationId)
                && manager.isOperationRootUsed(root)
                && ledger.isManagerOperationRootUsed(address(manager), root),
            "all original replay owners consumed"
        );
    }

    function _proofError(address recipient) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IStreamMintCounterPolicy.MintAllowlistProofInvalid.selector, RECIPIENT, recipient
        );
    }

    function _batch(address[] memory recipients)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.beneficiaries = recipients;
        b.initialRecipients = new address[](recipients.length);
        b.tokenData = new bytes[](recipients.length);
        b.mintCommitments = new bytes32[](recipients.length);
        for (uint256 i; i < recipients.length; ++i) {
            b.initialRecipients[i] = program.deliveryMode
                == IStreamOperatorDistribution.DeliveryMode.DIRECT
                ? recipients[i]
                : address(distribution);
            b.tokenData[i] = abi.encode("artwork", i);
            b.mintCommitments[i] = keccak256(abi.encode("commitment", i));
        }
        b.authorizationId = distribution.sliceAuthorization(1, PHASE, 0);
        b.contextHash = distribution.sliceHash(0, b);
    }

    function _configure(IStreamMintManager.MintBatch memory batch) private {
        batch.expectedPolicyHash = this.configureDistribution(batch);
    }

    function configureDistribution(IStreamMintManager.MintBatch calldata batch)
        external
        returns (bytes32)
    {
        require(msg.sender == address(this), "fixture only");
        program.slicesRoot = rootOverride == 0 ? distribution.sliceHash(0, batch) : rootOverride;
        uint256 count = extraRecipientConfigHash == 0 ? 2 : 3;
        bytes32[] memory ids = new bytes32[](count);
        ids[0] = SUPPLY;
        ids[1] = RECIPIENT;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](count);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            program.totalQuantity,
            1,
            supplyConfigHash
        );
        counters[1] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            recipientCapMode,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            program.perRecipientCap,
            1,
            recipientConfigHash
        );
        if (count == 3) {
            ids[2] = EXTRA_RECIPIENT;
            counters[2] = IStreamMintManager.MintCounterConfig(
                true,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
                IStreamMintLedger.CounterDeltaMode.STATIC,
                program.perRecipientCap,
                1,
                extraRecipientConfigHash
            );
        }
        bytes32 applicationHash = distribution.programHash(1, PHASE, program);
        if (recipientCapMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC && !legacyMerkleHash)
        {
            applicationHash = distribution.merkleProgramHash(1, PHASE, program, recipientConfigHash);
        }
        if (applicationHashOverride != 0) applicationHash = applicationHashOverride;
        IStreamMintManager.MintPhaseConfig memory phase = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 10, applicationHash, keccak256("published recipient manifest")
        );
        IStreamMintManager.MintGateConfig memory gate;
        artist.consent(
            manager.previewPhasePolicyHash(1, PHASE, phase, gate, ids, counters, new address[](0))
        );
        manager.configurePhase(1, PHASE, phase, gate, ids, counters);
        address[] memory executors = new address[](1);
        executors[0] = address(distribution);
        artist.consent(
            manager.previewPhasePolicyHash(1, PHASE, phase, gate, ids, counters, executors)
        );
        manager.setPhaseExecutor(1, PHASE, address(distribution), true);
        return manager.phasePolicyHash(1, PHASE);
    }

    function _send(IStreamMintManager.MintBatch memory b)
        private
        returns (uint256[] memory, bytes32)
    {
        return distribution.distribute(program, 0, new bytes32[](0), b, "");
    }

    function _rejectSupplyScope(IStreamMintCounterPolicy.CounterScope scope) private {
        supplyConfigHash = ledger.registerCounterDefinition(
            _definition(scope, IStreamMintManager.CounterKeyMode.CONSTANT)
        );
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, BOB));
        _configure(batch);
        (bool defined, IStreamMintCounterPolicy.Definition memory selected) =
            ledger.counterDefinitionForManager(address(manager), supplyConfigHash);
        require(defined && selected.scope == scope, "actual shared supply definition selected");
        uint256 scopeCollection = scope == IStreamMintCounterPolicy.CounterScope.GLOBAL ? 0 : 1;
        bytes32 subject = _supplySubject(scopeCollection, 0);
        require(
            _resolvedSubject(SUPPLY, address(0)) == subject && subject != _supplySubject(1, PHASE),
            "genuine non-phase supply subject"
        );
        vm.prank(address(distribution));
        (bytes32 operationRoot,) = manager.previewSingleStepMintOperation(batch, "");
        require(operationRoot != 0, "ordinary manager request is valid");
        vm.expectRevert(IStreamOperatorDistribution.InvalidDistribution.selector);
        _send(batch);
        _rolledBack();
        require(
            !manager.isAuthorizationUsed(batch.authorizationId)
                && !manager.isOperationRootUsed(operationRoot),
            "replay state untouched"
        );
        require(
            ledger.counterValue(_valueKey(scopeCollection, 0, SUPPLY, subject)) == 0,
            "shared supply counter untouched"
        );
        require(
            ledger.counterValue(_valueKey(1, PHASE, SUPPLY, _supplySubject(1, PHASE))) == 0,
            "phase supply counter untouched"
        );
        require(
            _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 0
                && _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, BOB) == 0,
            "recipient counters untouched"
        );
    }

    function _sharedRecipientScope(IStreamMintCounterPolicy.CounterScope scope) private {
        recipientConfigHash = ledger.registerCounterDefinition(
            _definition(scope, IStreamMintManager.CounterKeyMode.RECIPIENT)
        );
        IStreamMintManager.MintBatch memory batch = _batch(_recipients(ALICE, ALICE));
        _configure(batch);
        (bool defined, IStreamMintCounterPolicy.Definition memory selected) =
            ledger.counterDefinitionForManager(address(manager), recipientConfigHash);
        require(defined && selected.scope == scope, "actual shared recipient definition selected");
        _send(batch);
        require(core.ownerOf(1) == ALICE && core.ownerOf(2) == ALICE, "shared recipient delivered");
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                ALICE
            )
        );
        uint256 scopeCollection = scope == IStreamMintCounterPolicy.CounterScope.GLOBAL ? 0 : 1;
        require(
            ledger.counterValue(_valueKey(scopeCollection, 0, RECIPIENT, subject)) == 2,
            "duplicates consume actual shared recipient key"
        );
        require(
            ledger.counterValue(_valueKey(1, PHASE, RECIPIENT, subject)) == 0,
            "recipient value is not phase scoped"
        );
        require(
            _count(RECIPIENT, IStreamMintManager.CounterKeyMode.RECIPIENT, ALICE) == 2,
            "manager reads the same shared recipient value"
        );
        require(
            _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0)) == 2,
            "supply remains phase scoped"
        );
    }

    function _definition(
        IStreamMintCounterPolicy.CounterScope scope,
        IStreamMintManager.CounterKeyMode keyMode
    ) private pure returns (IStreamMintCounterPolicy.Definition memory) {
        return IStreamMintCounterPolicy.Definition(
            scope, keyMode, bytes32(0), keccak256("distribution scope definition")
        );
    }

    function _resolvedSubject(bytes32 id, address beneficiary) private view returns (bytes32) {
        IStreamMintCounterReads.CounterKeyContext memory context;
        context.collectionId = 1;
        context.phaseId = PHASE;
        context.counterId = id;
        context.beneficiary = beneficiary;
        context.executor = address(distribution);
        return IStreamMintCounterReads(address(manager)).resolveCounter(context).subjectKey;
    }

    function _supplySubject(uint256 collectionId, bytes32 phaseId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                collectionId,
                phaseId,
                SUPPLY
            )
        );
    }

    function _valueKey(uint256 collectionId, bytes32 phaseId, bytes32 id, bytes32 subject)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                collectionId,
                phaseId,
                id,
                subject
            )
        );
    }

    function _recipients(address first, address second) private pure returns (address[] memory r) {
        r = new address[](2);
        r[0] = first;
        r[1] = second;
    }

    function _count(bytes32 id, IStreamMintManager.CounterKeyMode mode, address recipient)
        private
        view
        returns (uint256)
    {
        bytes32 subject = manager.previewSubjectKey(
            mode, 1, PHASE, id, address(0), recipient, address(distribution), address(0), bytes32(0)
        );
        return ledger.counterValue(manager.previewCounterValueKey(1, PHASE, id, subject));
    }

    function _rolledBack() private view {
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0
                && !distribution.sliceUsed(1, PHASE, 0),
            "whole operation rollback"
        );
        require(
            _count(SUPPLY, IStreamMintManager.CounterKeyMode.CONSTANT, address(0)) == 0,
            "ledger rollback"
        );
    }

    function _event(bytes32 topic, uint256 expected) private {
        DistributionVm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(distribution) && logs[i].topics[0] == topic) ++count;
        }
        require(count == expected, "normative event count");
    }
}
