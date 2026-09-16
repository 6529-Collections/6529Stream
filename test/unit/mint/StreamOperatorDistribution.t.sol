// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StreamDistributionFixture.sol";
import "../../helpers/OfficialSafeFixture.sol";

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
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = SUPPLY;
        ids[1] = RECIPIENT;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](2);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            program.totalQuantity,
            1,
            keccak256("supply config")
        );
        counters[1] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            program.perRecipientCap,
            1,
            keccak256("recipient config")
        );
        IStreamMintManager.MintPhaseConfig memory phase = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            10,
            distribution.programHash(1, PHASE, program),
            keccak256("published recipient manifest")
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
