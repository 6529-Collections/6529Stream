// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentDynamicRoyaltyCommerceFixture.sol";
import "../mocks/MockStreamPaymentToken.sol";
import "../../script/current/StreamRevenueRuntimePlan.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueRuntimeRegistry.sol";
import {
    StreamEscrowRecoveryState as RecoveryErrors
} from "../../smart-contracts/domains/revenue/StreamEscrowRecoveryState.sol";
import {
    StreamEscrowRecoveryTypes as EscrowTerms
} from "../../smart-contracts/interfaces/stream/revenue/StreamEscrowRecoveryTypes.sol";
import {
    IStreamRevenueEscrowRecoveryManifest as RecoveryManifest
} from "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueEscrowRecoveryManifest.sol";

interface CurrentEscrowLifecycleVm {
    function mockCallRevert(
        address target,
        uint256 value,
        bytes calldata data,
        bytes calldata reason
    ) external;
    function clearMockedCalls() external;
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Original current auction proceeds remain owed through Safe flush and incident recovery.
/// @dev Uses genuine deferred-template credit, Recorder, WAIVED floor and delayed governance.
///      Passive ETH/ERC20 are separately accounted surplus. Only explicitly selected later
///      wallet deposits fail by fault injection; no escrow credit, authority or receipt is mocked.
contract StreamCurrentRevenueEscrowLifecycleTest is CurrentDynamicRoyaltyCommerceFixture {
    bytes32 private constant WHY = keccak256("current earned escrow incident");
    string private constant WHERE = "urn:stream:test:earned-escrow-lifecycle";
    bytes32 private constant FLUSHED =
        keccak256("EscrowFlushed(bytes32,bytes32,address,uint16,address,uint256,uint256)");
    bytes32 private constant RECOVERED = keccak256(
        "EscrowRecoveryExecuted(uint16,bytes32,bytes32,bytes32,address,address,uint256,bytes32,bytes32,string)"
    );
    StreamRevenueRuntimeRegistry private lifecycle;
    StreamSplitFactory private successor;
    MockStreamPaymentToken private passiveToken;
    StreamSaleTemplate.Selection private original;
    bytes32 private auctionId;
    bytes32 private originalKey;
    bytes32 private originalResult;
    bytes32 private originalFloor;
    bytes32 private originalFacts;
    bytes32 private originalCreditIdentity;

    function setUp() public {
        _deployJoinedCommerce();
        this.joinedSnapshotSetup(0);
        bytes32 templateId = this.joinedCreateTemplate();
        this.joinedApproveTemplate(templateId);
        this.joinedInstallTemplate(templateId);
        this.joinedInstallPhase();
        original = _joinedSelection();
        require(
            !factory.profileExists(original.profileId) && original.wallet.code.length == 0,
            "preview has no manufactured profile or wallet"
        );
        auctionId = this.joinedCreateAuction();
        _joinedBid(auctionId);
        require(_joinedSettle(auctionId) == 1, "first actual prepared mint");
        originalKey = joinedHouse.auction(auctionId).settlementKey;
        originalResult = keccak256(abi.encode(joinedRecorder.settlementResult(originalKey)));
        originalFacts = joinedRecorder.preparedNativeRightsFactsHash(originalKey);
        originalFloor = commerceFloor.settlementReceipt(originalKey).receiptHash;
        originalCreditIdentity = _creditIdentity();
        require(
            factory.profileExists(original.profileId)
                && !factory.splitWalletExists(original.profileId)
                && original.wallet.code.length == 0 && original.wallet.balance == 0
                && joinedRecorder.settlementResult(originalKey).escrowed
                && joinedRecorder.settlementResult(originalKey).profileId == original.profileId
                && joinedRecorder.settlementResult(originalKey).wallet == original.wallet,
            "genuine deferred dynamic-template credit remains unflushed"
        );
        (bool enabled, bytes32 producerHash, uint64 revision) =
            revenueEscrow.creditProducer(address(joinedRecorder));
        require(
            enabled && producerHash == address(joinedRecorder).codehash && revision == 1,
            "original Recorder is the actually governed credit producer"
        );
        passiveToken = new MockStreamPaymentToken();
        vm.deal(address(this), 10 ether);
        _assertOwed(JOINED_PRICE, 0);
        _assertOriginalReceipts();
        _activateRecovery();
        _assertOwed(JOINED_PRICE, 0);
        _assertOriginalReceipts();
    }

    function testCurrentEscrowRetiredProducerCannotEraseOwedOrSurplusOnExactSafeFlushRetry()
        public
    {
        _donate(address(revenueEscrow), 23);
        passiveToken.mint(address(revenueEscrow), 17);
        _joinedSafe(
            joinedBuyer,
            address(factory),
            0,
            abi.encodeCall(factory.deployWallet, (original.profileId))
        );
        _retireRecorder();
        bytes memory input = _flushInput(false);
        bytes memory envelope = _envelope(joinedCollector, address(revenueEscrow), input);
        bytes memory fault = abi.encodeWithSignature("CurrentEscrowDepositRejected()");
        _depositFault(original.wallet, factory, fault);
        CurrentEscrowLifecycleVm(address(vm))
            .expectCall(original.wallet, JOINED_PRICE, bytes(""), 3);
        _exactFailure(input, _depositError(original.wallet, fault));
        _rejectEnvelope(joinedCollector, envelope);
        _assertOwed(JOINED_PRICE, 23);
        require(
            original.wallet.balance == 0 && revenueEscrow.surplus(address(passiveToken)) == 17
                && revenueEscrow.totalOwed(address(passiveToken)) == 0,
            "failed payout cannot relabel actual owed or passive token surplus"
        );
        CurrentEscrowLifecycleVm(address(vm)).clearMockedCalls();
        vm.recordLogs();
        _runEnvelope(joinedCollector, envelope);
        _assertFlushEvent(vm.getRecordedLogs());
        _assertOwed(0, 23);
        require(
            original.wallet.balance == JOINED_PRICE
                && passiveToken.rawBalance(address(revenueEscrow)) == 17,
            "same Safe envelope flushes original owed while retired producer stays disabled"
        );
        (bool enabled,, uint64 revision) = revenueEscrow.creditProducer(address(joinedRecorder));
        require(!enabled && revision == 2, "flush needs no producer reinstatement");
        _assertOriginalReceipts();
    }

    function testCurrentEscrowIncidentToDeprecatedRestoresSameSafeDeferredFlush() public {
        _factoryStatus(address(factory), 3);
        bytes memory input = _flushInput(true);
        bytes memory envelope = _envelope(joinedCollector, address(revenueEscrow), input);
        _exactFailure(
            input,
            abi.encodeWithSelector(
                IStreamRevenueRuntimeRegistry.RevenueRuntimeUnavailable.selector,
                address(factory),
                factory.splitWalletRuntimeCodeHash(),
                uint8(1)
            )
        );
        _rejectEnvelope(joinedCollector, envelope);
        _assertOwed(JOINED_PRICE, 0);
        require(original.wallet.code.length == 0, "incident denies flush before deployment");
        (uint8 cls,,,) = lifecycle.factoryTransitionHashes(address(factory), 2, WHY, WHERE, 0);
        require(cls == 1, "incident restoration requires delayed loosening");
        _factoryStatus(address(factory), 2);
        require(lifecycle.factoryRecord(address(factory)).status == 2, "actual deprecated factory");
        vm.recordLogs();
        _runEnvelope(joinedCollector, envelope);
        _assertFlushEvent(vm.getRecordedLogs());
        _assertOwed(0, 0);
        require(
            factory.splitWalletExists(original.profileId)
                && original.wallet.balance == JOINED_PRICE,
            "same Safe envelope deploys and flushes original retained profile under deprecation"
        );
        _assertOriginalReceipts();
    }

    function testCurrentEscrowClass4RecoveryRestoresOwedOnLateDepositFailureAndExactRetry() public {
        _factoryStatus(address(factory), 3);
        (, EscrowTerms.EscrowRecoveryRecord memory p, bytes32 id) = _prepareRecovery(false);
        _scheduleRecovery(p, id);
        bytes memory input = abi.encodeCall(revenueEscrow.executeEscrowRecovery, (id));
        bytes memory envelope = _envelope(joinedCollector, address(revenueEscrow), input);
        _exactFailure(
            input,
            abi.encodeWithSelector(
                RecoveryErrors.EscrowRecoveryDelayNotElapsed.selector, p.executeAfter
            )
        );
        _rejectEnvelope(joinedCollector, envelope);
        _assertOwed(JOINED_PRICE, 0);
        vm.warp(p.executeAfter);
        _joinedSafe(
            joinedBuyer,
            address(successor),
            0,
            abi.encodeCall(successor.deployWallet, (p.successorProfileId))
        );
        bytes memory fault = abi.encodeWithSignature("CurrentSuccessorDepositRejected()");
        _depositFault(p.successorWallet, successor, fault);
        CurrentEscrowLifecycleVm(address(vm))
            .expectCall(p.successorWallet, JOINED_PRICE, bytes(""), 3);
        _exactFailure(input, _depositError(p.successorWallet, fault));
        _rejectEnvelope(joinedCollector, envelope);
        require(
            revenueEscrow.escrowRecoveryRecord(id).status
                    == EscrowTerms.EscrowRecoveryStatus.SCHEDULED && p.successorWallet.balance == 0,
            "late failure restores recovery state and original liability"
        );
        _assertOwed(JOINED_PRICE, 0);
        CurrentEscrowLifecycleVm(address(vm)).clearMockedCalls();
        vm.recordLogs();
        _runEnvelope(joinedCollector, envelope);
        _assertRecoveryEvent(vm.getRecordedLogs(), p, id);
        _assertRecovered(p, id, 0);
        _exactFailure(
            input, abi.encodeWithSelector(RecoveryErrors.InvalidEscrowRecoveryState.selector, id)
        );
        _assertOriginalReceipts();
    }

    function testCurrentEscrowRecoveryMovesOnlyEarnedOwedAndPreservesResidentMoneyAndPassiveAssets()
        public
    {
        _joinedSafe(
            joinedBuyer,
            address(factory),
            0,
            abi.encodeCall(factory.deployWallet, (original.profileId))
        );
        _donate(original.wallet, 71);
        _donate(address(revenueEscrow), 23);
        passiveToken.mint(address(revenueEscrow), 17);
        _factoryStatus(address(factory), 3);
        (, EscrowTerms.EscrowRecoveryRecord memory p, bytes32 id) = _prepareRecovery(false);
        _scheduleRecovery(p, id);
        vm.warp(p.executeAfter);
        vm.recordLogs();
        _joinedSafe(
            joinedCollector,
            address(revenueEscrow),
            0,
            abi.encodeCall(revenueEscrow.executeEscrowRecovery, (id))
        );
        _assertRecoveryEvent(vm.getRecordedLogs(), p, id);
        _assertRecovered(p, id, 23);
        require(
            original.wallet.balance == 71 && passiveToken.rawBalance(address(revenueEscrow)) == 17
                && revenueEscrow.totalOwed(address(passiveToken)) == 0
                && revenueEscrow.surplus(address(passiveToken)) == 17,
            "only the authentic sale credit moves; old wallet and passive assets are outside recovery"
        );
        _joinedSafe(
            joinedArtist,
            p.successorWallet,
            0,
            abi.encodeCall(
                IStreamSplitWallet.release,
                (address(0), address(joinedArtist), payable(address(joinedArtist)))
            )
        );
        require(
            address(joinedArtist).balance == 300_000 && p.successorWallet.balance == 700_000
                && original.wallet.balance == 71,
            "actual original Artist receives exactly its successor entitlement"
        );
        _assertOriginalReceipts();
    }

    function testCurrentEscrowChangedEntriesNeedOriginalArtistSafeConsentAndHonorRevocationOnRetry()
        public
    {
        _factoryStatus(address(factory), 3);
        (, EscrowTerms.EscrowRecoveryRecord memory p, bytes32 id) = _prepareRecovery(true);
        require(
            address(joinedArtist) != address(joinedCollector)
                && keccak256(abi.encode(joinedArtist.getOwners()))
                    == keccak256(abi.encode(joinedCollector.getOwners()))
                && joinedArtist.getThreshold() == 2 && joinedCollector.getThreshold() == 2,
            "same owners remain distinct Safe principals"
        );
        _joinedSafe(
            joinedCollector,
            address(revenueEscrow),
            0,
            abi.encodeCall(revenueEscrow.recordEscrowRecoveryConsent, (id, bytes32(0)))
        );
        require(
            revenueEscrow.escrowRecoveryConsentRecorded(id, address(joinedCollector))
                && !revenueEscrow.escrowRecoveryConsentRecorded(id, address(joinedArtist)),
            "nonentitled same-owner Safe cannot consent for affected Artist"
        );
        uint64 deadline = uint64(block.timestamp + 30 days);
        bytes32 digest =
            revenueEscrow.escrowRecoveryConsentDigest(address(joinedArtist), id, 0, deadline);
        bytes memory wrong = _joinedProof(joinedCollector, digest);
        _exactFailure(
            abi.encodeCall(
                revenueEscrow.submitEscrowRecoveryConsent,
                (address(joinedArtist), id, bytes32(0), deadline, wrong)
            ),
            abi.encodeWithSelector(RecoveryErrors.EscrowRecoveryConsentInvalid.selector)
        );
        require(
            !revenueEscrow.isEscrowRecoveryConsentNonceUsed(address(joinedArtist), 0),
            "wrong Safe signature leaves original account nonce unused"
        );
        uint256 artistNonce = joinedArtist.nonce();
        _joinedSafe(
            joinedBuyer,
            address(revenueEscrow),
            0,
            abi.encodeCall(
                revenueEscrow.submitEscrowRecoveryConsent,
                (
                    address(joinedArtist),
                    id,
                    bytes32(0),
                    deadline,
                    _joinedProof(joinedArtist, digest)
                )
            )
        );
        require(
            joinedArtist.nonce() == artistNonce
                && revenueEscrow.isEscrowRecoveryConsentNonceUsed(address(joinedArtist), 0),
            "relayed threshold consent uses escrow nonce zero without executing Artist Safe"
        );
        _scheduleRecovery(p, id);
        vm.warp(p.executeAfter);
        bytes memory input = abi.encodeCall(revenueEscrow.executeEscrowRecovery, (id));
        bytes memory envelope = _envelope(joinedBuyer, address(revenueEscrow), input);
        _joinedSafe(
            joinedArtist,
            address(revenueEscrow),
            0,
            abi.encodeCall(revenueEscrow.revokeEscrowRecoveryConsent, (id))
        );
        _exactFailure(
            input,
            abi.encodeWithSelector(
                RecoveryErrors.EscrowRecoveryConsentMissing.selector, id, address(joinedArtist)
            )
        );
        _rejectEnvelope(joinedBuyer, envelope);
        _assertOwed(JOINED_PRICE, 0);
        require(
            revenueEscrow.isEscrowRecoveryConsentNonceUsed(address(joinedArtist), 0)
                && !revenueEscrow.escrowRecoveryConsentRecorded(id, address(joinedArtist))
                && p.successorWallet.code.length == 0,
            "revocation retains used nonce and denies deployment"
        );
        _joinedSafe(
            joinedArtist,
            address(revenueEscrow),
            0,
            abi.encodeCall(revenueEscrow.recordEscrowRecoveryConsent, (id, bytes32(uint256(1))))
        );
        vm.recordLogs();
        _runEnvelope(joinedBuyer, envelope);
        _assertRecoveryEvent(vm.getRecordedLogs(), p, id);
        _assertRecovered(p, id, 0);
        IStreamSplitWallet target = IStreamSplitWallet(p.successorWallet);
        require(
            target.aggregateSharePpm(address(joinedArtist)) == 0
                && target.aggregateSharePpm(address(joinedCollector)) == 300_000
                && !revenueEscrow.isEscrowRecoveryConsentNonceUsed(vm.addr(joinedKeys[0]), 0),
            "changed entitlement is consented by affected Safe without aliasing owner EOA"
        );
        uint256 beforeCollector = address(joinedCollector).balance;
        _joinedSafe(
            joinedCollector,
            p.successorWallet,
            0,
            abi.encodeCall(
                IStreamSplitWallet.release,
                (address(0), address(joinedCollector), payable(address(joinedCollector)))
            )
        );
        require(
            address(joinedCollector).balance == beforeCollector + 300_000,
            "exact consented successor payout"
        );
        _assertOriginalReceipts();
    }

    function testCurrentEscrowCancellationPreservesOwedAndRetainedManifestConsentHistory() public {
        _factoryStatus(address(factory), 3);
        (
            RecoveryManifest.ManifestDocument memory d,
            EscrowTerms.EscrowRecoveryRecord memory p,
            bytes32 id
        ) = _prepareRecovery(false);
        _joinedSafe(
            joinedArtist,
            address(revenueEscrow),
            0,
            abi.encodeCall(revenueEscrow.recordEscrowRecoveryConsent, (id, bytes32(0)))
        );
        _scheduleRecovery(p, id);
        bytes memory input = abi.encodeCall(revenueEscrow.executeEscrowRecovery, (id));
        bytes memory envelope = _envelope(joinedCollector, address(revenueEscrow), input);
        _runPlan(StreamRevenueRuntimePlan.cancellation(revenueEscrow, id, WHY, WHERE));
        require(
            revenueEscrow.escrowRecoveryRecord(id).status
                == EscrowTerms.EscrowRecoveryStatus.CANCELLED,
            "real class0 cancellation"
        );
        vm.warp(p.executeAfter);
        _exactFailure(
            input, abi.encodeWithSelector(RecoveryErrors.InvalidEscrowRecoveryState.selector, id)
        );
        _rejectEnvelope(joinedCollector, envelope);
        _joinedSafe(
            joinedArtist,
            address(revenueEscrow),
            0,
            abi.encodeCall(revenueEscrow.revokeEscrowRecoveryConsent, (id))
        );
        require(
            !revenueEscrow.escrowRecoveryConsentRecorded(id, address(joinedArtist))
                && revenueEscrow.isEscrowRecoveryConsentNonceUsed(address(joinedArtist), 0),
            "cancelled record permits revocation while nonce history remains"
        );
        bytes memory fresh =
            abi.encodeCall(revenueEscrow.recordEscrowRecoveryConsent, (id, bytes32(uint256(1))));
        _exactFailure(
            fresh, abi.encodeWithSelector(RecoveryErrors.EscrowRecoveryConsentInvalid.selector)
        );
        _rejectEnvelope(joinedArtist, _envelope(joinedArtist, address(revenueEscrow), fresh));
        _assertOwed(JOINED_PRICE, 0);
        require(
            p.successorWallet.code.length == 0, "cancelled recovery never materializes successor"
        );
        (bytes memory retained, uint64 publishedAt) =
            revenueEscrow.escrowRecoveryManifest(p.recoveryManifest.contentHash);
        _factoryStatus(address(factory), 2);
        _joinedSafe(joinedCollector, address(revenueEscrow), 0, _flushInput(true));
        _assertOwed(0, 0);
        vm.recordLogs();
        _joinedSafe(
            joinedBuyer,
            address(revenueEscrow),
            0,
            abi.encodeCall(revenueEscrow.publishEscrowRecoveryManifest, (d, p.recoveryManifest))
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            require(
                logs[i].emitter != address(revenueEscrow),
                "retained publication is eventless despite changed incident and credit state"
            );
        }
        (bytes memory afterBytes, uint64 afterTime) =
            revenueEscrow.escrowRecoveryManifest(p.recoveryManifest.contentHash);
        require(
            keccak256(retained) == keccak256(abi.encode(d))
                && keccak256(afterBytes) == keccak256(retained) && afterTime == publishedAt
                && original.wallet.balance == JOINED_PRICE,
            "immutable recovery document and original credit destination survive cancellation"
        );
        _assertOriginalReceipts();
    }

    function _activateRecovery() private {
        successor = StreamSplitFactory(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory",
                abi.encode(assetPolicy, address(executor), _walletGasConfigs())
            )
        );
        lifecycle = StreamRevenueRuntimeRegistry(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamRevenueRuntimeRegistry.sol:StreamRevenueRuntimeRegistry",
                abi.encode(
                    address(executor),
                    address(assetPolicy),
                    IStreamGasParameterHost.GasParameterConfig(
                        "REVENUE_RUNTIME_READ_GAS", 150_000, 100_000, 2
                    )
                )
            )
        );
        _assertDeployableProductionInstance(address(successor));
        _assertDeployableProductionInstance(address(lifecycle));
        _extendCatalog();
        _runPlan(
            StreamRevenueRuntimePlan.classifier(
                executor, address(lifecycle), lifecycle.setFactoryStatus.selector
            )
        );
        _runPlan(
            StreamRevenueRuntimePlan.classifier(
                executor, address(revenueEscrow), revenueEscrow.cancelEscrowRecovery.selector
            )
        );
        _factoryStatus(address(factory), 1);
        _factoryStatus(address(successor), 1);
        _runPlan(StreamRevenueRuntimePlan.bind(factory, address(lifecycle)));
        _runPlan(StreamRevenueRuntimePlan.bind(successor, address(lifecycle)));
        _runPlan(StreamRevenueRuntimePlan.bind(revenueEscrow, address(lifecycle)));
        StreamRevenueRuntimePlan.requireActivated(address(factory), address(revenueEscrow));
    }

    function _extendCatalog() private {
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](7);
        rows[0] = _policy(1, address(lifecycle), lifecycle.setFactoryStatus.selector);
        rows[1] = _policy(0, address(lifecycle), lifecycle.setFactoryStatus.selector);
        rows[2] = _policy(1, address(factory), factory.initializeRevenueRuntimeRegistry.selector);
        rows[3] =
            _policy(1, address(successor), successor.initializeRevenueRuntimeRegistry.selector);
        rows[4] = _policy(
            1, address(revenueEscrow), revenueEscrow.initializeRevenueRuntimeRegistry.selector
        );
        rows[5] = _policy(4, address(revenueEscrow), revenueEscrow.scheduleEscrowRecovery.selector);
        rows[6] = _policy(0, address(revenueEscrow), revenueEscrow.cancelEscrowRecovery.selector);
        for (uint256 i = 1; i < rows.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && _escrowPolicyKey(rows[j - 1]) > _escrowPolicyKey(rows[j]);
                --j
            ) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) =
            StreamGenesisManifestPlan.writePayload(bytes("current earned escrow lifecycle test"));
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            WHERE,
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        require(count == 7, "seven exact additive operating policies");
        _runPlan(batch);
    }

    function _policy(uint8 cls, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            cls,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            0
        );
    }

    function _escrowPolicyKey(GovernanceActionPolicyEntry memory row)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _runPlan(GenesisBatch memory batch) private returns (bytes32 id) {
        uint64 ready;
        (id, ready) = _scheduleBatchAsGovernor(batch.actionClass, batch.calls, batch.callDatas);
        vm.warp(ready);
        _joinedSafe(
            governorSafe,
            address(executor),
            0,
            abi.encodeCall(executor.executeGovernanceBatch, (id, batch.calls, batch.callDatas))
        );
        require(
            executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED
                && executor.governanceAction(id).actionClass == batch.actionClass,
            "actual delayed Safe-governed batch and original action class"
        );
    }

    function _factoryStatus(address target, uint8 status) private {
        _runPlan(
            StreamRevenueRuntimePlan.factoryStatus(
                lifecycle, target, status, WHY, WHERE, status == 3 ? WHY : bytes32(0)
            )
        );
        require(
            lifecycle.factoryRecord(target).status == status, "governed factory lifecycle readback"
        );
    }

    function _retireRecorder() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            revenueEscrow.creditProducerTransitionHashes(address(joinedRecorder), false);
        bytes memory input =
            abi.encodeCall(revenueEscrow.setCreditProducer, (address(joinedRecorder), false));
        _exactFailure(
            input, abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowProducerAction.selector)
        );
        _rejectEnvelope(joinedBuyer, _envelope(joinedBuyer, address(revenueEscrow), input));
        _govern(_governanceRequest(1, address(revenueEscrow), input, scope, oldHash, newHash));
    }

    function _prepareRecovery(bool changed)
        private
        returns (
            RecoveryManifest.ManifestDocument memory d,
            EscrowTerms.EscrowRecoveryRecord memory p,
            bytes32 id
        )
    {
        d.creditKey = EscrowTerms.EscrowCreditKey(
            PRIMARY_REVENUE_CLASS, original.profileId, original.wallet, address(0)
        );
        d.successorFactory = address(successor);
        uint256 count = factory.profileEntryCount(original.profileId);
        d.oldEntries = new IStreamSplitWallet.SplitEntry[](count);
        d.successorEntries = new IStreamSplitWallet.SplitEntry[](count);
        uint256 artistRows;
        for (uint256 i; i < count; ++i) {
            (address account, uint32 share, bytes32 label) =
                factory.profileEntry(original.profileId, i);
            d.oldEntries[i] = IStreamSplitWallet.SplitEntry(account, share, label);
            if (account == address(joinedArtist)) {
                require(share == 300_000, "actual artist share");
                ++artistRows;
                if (changed) account = address(joinedCollector);
            }
            d.successorEntries[i] = IStreamSplitWallet.SplitEntry(account, share, label);
        }
        require(artistRows == 1 && count == 4, "original four canonical concrete rows");
        for (uint256 i = 1; i < count; ++i) {
            for (
                uint256 j = i;
                j > 0 && _entryAfter(d.successorEntries[j - 1], d.successorEntries[j]);
                --j
            ) {
                (d.successorEntries[j - 1], d.successorEntries[j]) =
                (d.successorEntries[j], d.successorEntries[j - 1]);
            }
        }
        d.oldMetadataURIHash = factory.profileMetadataURIHash(original.profileId);
        (d.successorProfileId, d.successorWallet) =
            successor.registerProfile(d.successorEntries, keccak256("earned escrow successor"));
        d.successorRuntimeCodeHash = successor.splitWalletRuntimeCodeHash();
        d.expectedAmount = JOINED_PRICE;
        d.route = changed ? 1 : 0;
        d.incidentEvidenceHash = WHY;
        bytes32 content = keccak256(
            abi.encode(
                keccak256("6529STREAM_ESCROW_RECOVERY_MANIFEST_V1"),
                block.chainid,
                address(revenueEscrow),
                d
            )
        );
        EscrowTerms.EscrowRecoveryManifestRef memory ref = EscrowTerms.EscrowRecoveryManifestRef(
            WHERE,
            keccak256(bytes(WHERE)),
            content,
            keccak256("STREAM_ESCROW_RECOVERY_MANIFEST_V1"),
            keccak256("6529STREAM_ESCROW_RECOVERY_ABI_V1")
        );
        _joinedSafe(
            joinedBuyer,
            address(revenueEscrow),
            0,
            abi.encodeCall(revenueEscrow.publishEscrowRecoveryManifest, (d, ref))
        );
        (bytes memory retained, uint64 published) = revenueEscrow.escrowRecoveryManifest(content);
        require(
            keccak256(retained) == keccak256(abi.encode(d)) && published == block.timestamp,
            "original canonical recovery bytes retained by actual Safe publication"
        );
        require(
            revenueEscrow.escrowRecoveryAffectedAccountCount(content) == (changed ? 1 : 0),
            "exact affected set"
        );
        if (changed) {
            require(
                revenueEscrow.escrowRecoveryAffectedAccountAt(content, 0) == address(joinedArtist),
                "only Artist loses entitlement"
            );
        }
        p = EscrowTerms.EscrowRecoveryRecord(
            EscrowTerms.EscrowRecoveryStatus.SCHEDULED,
            d.creditKey,
            address(factory),
            d.successorWallet,
            d.successorProfileId,
            d.successorRuntimeCodeHash,
            JOINED_PRICE,
            ref,
            uint64(block.timestamp + 14 days + 2 hours),
            WHY,
            WHERE
        );
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ESCROW_RECOVERY_V1"),
                block.chainid,
                address(revenueEscrow),
                PRIMARY_REVENUE_CLASS,
                original.profileId,
                original.wallet,
                address(0),
                p.successorWallet,
                p.successorProfileId,
                p.successorRuntimeCodeHash,
                p.expectedAmount,
                content,
                p.executeAfter,
                WHY
            )
        );
    }

    function _entryAfter(
        IStreamSplitWallet.SplitEntry memory a,
        IStreamSplitWallet.SplitEntry memory b
    ) private pure returns (bool) {
        return uint160(a.account) > uint160(b.account)
            || (a.account == b.account && a.labelId > b.labelId);
    }

    function _scheduleRecovery(EscrowTerms.EscrowRecoveryRecord memory p, bytes32 id) private {
        (bytes32 expected, GenesisBatch memory batch) =
            StreamRevenueRuntimePlan.recovery(revenueEscrow, p);
        require(
            expected == id && batch.actionClass == 4,
            "independent original recovery ID and FUNDS_RECOVERY class"
        );
        _exactFailure(
            batch.callDatas[0],
            abi.encodeWithSelector(RecoveryErrors.InvalidEscrowRecoveryAction.selector)
        );
        _runPlan(batch);
        require(
            keccak256(abi.encode(revenueEscrow.escrowRecoveryRecord(id)))
                == keccak256(abi.encode(p)),
            "actual governed recovery preserves every original term"
        );
        _assertOwed(JOINED_PRICE, revenueEscrow.surplus(address(0)));
        _assertOriginalReceipts();
    }

    function _flushInput(bool mayDeploy) private view returns (bytes memory) {
        return abi.encodeWithSelector(
            mayDeploy
                ? revenueEscrow.flushEscrow.selector
                : revenueEscrow.flushToVerifiedWalletBestEffort.selector,
            PRIMARY_REVENUE_CLASS,
            original.profileId,
            original.wallet,
            address(0)
        );
    }

    function _envelope(OfficialSafe account, address target, bytes memory input)
        private
        returns (bytes memory)
    {
        bytes32 digest = account.getTransactionHash(
            target, 0, input, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (
                target,
                uint256(0),
                input,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, digest)
            )
        );
    }

    function _rejectEnvelope(OfficialSafe account, bytes memory envelope) private {
        uint256 nonce = account.nonce();
        (bool ok, bytes memory reason) = address(account).call(envelope);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && account.nonce() == nonce,
            "original failed Safe envelope preserves nonce"
        );
    }

    function _runEnvelope(OfficialSafe account, bytes memory envelope) private {
        uint256 nonce = account.nonce();
        (bool ok, bytes memory result) = address(account).call(envelope);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)) && account.nonce() == nonce + 1,
            "byte-identical threshold Safe envelope succeeds exactly once"
        );
    }

    function _exactFailure(bytes memory input, bytes memory expected) private {
        (bool ok, bytes memory reason) = address(revenueEscrow).call(input);
        require(
            !ok && keccak256(reason) == keccak256(expected),
            "exact original escrow negative control"
        );
    }

    function _depositFault(address target, IStreamSplitFactory expectedFactory, bytes memory reason)
        private
    {
        require(
            target.codehash == expectedFactory.splitWalletRuntimeCodeHash()
                && IStreamSplitWallet(target).initialized()
                && IStreamSplitWallet(target).factory() == address(expectedFactory),
            "fault only after genuine wallet deployment"
        );
        CurrentEscrowLifecycleVm(address(vm))
            .mockCallRevert(target, JOINED_PRICE, bytes(""), reason);
    }

    function _depositError(address target, bytes memory reason)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IStreamRevenueEscrow.EscrowExternalCallFailed.selector,
            target,
            bytes4(0),
            reason.length,
            reason
        );
    }

    function _donate(address target, uint256 amount) private {
        (bool ok,) = target.call{ value: amount }("");
        require(ok, "explicit passive native donation");
    }

    function _creditIdentity() private view returns (bytes32) {
        (address originFactory, bytes32 factoryHash, bytes32 runtime) = revenueEscrow.escrowCreditIdentity(
            PRIMARY_REVENUE_CLASS, original.profileId, original.wallet, address(0)
        );
        require(
            originFactory == address(factory) && factoryHash == address(factory).codehash
                && runtime == factory.splitWalletRuntimeCodeHash(),
            "actual immutable credit identity"
        );
        return keccak256(abi.encode(originFactory, factoryHash, runtime));
    }

    function _assertOwed(uint256 amount, uint256 surplus) private view {
        require(
            revenueEscrow.escrowOwed(
                    PRIMARY_REVENUE_CLASS, original.profileId, original.wallet, address(0)
                ) == amount && revenueEscrow.totalOwed(address(0)) == amount
                && address(revenueEscrow).balance == amount + surplus
                && revenueEscrow.surplus(address(0)) == surplus
                && _creditIdentity() == originalCreditIdentity,
            "exact earned owed, aggregate solvency, passive surplus and original identity"
        );
    }

    function _assertRecovered(
        EscrowTerms.EscrowRecoveryRecord memory p,
        bytes32 id,
        uint256 surplus
    ) private view {
        _assertOwed(0, surplus);
        require(
            revenueEscrow.escrowRecoveryRecord(id).status
                    == EscrowTerms.EscrowRecoveryStatus.EXECUTED
                && p.successorWallet.balance == JOINED_PRICE
                && successor.splitWalletExists(p.successorProfileId)
                && IStreamSplitWallet(p.successorWallet).factory() == address(successor)
                && IStreamSplitWallet(p.successorWallet).profileId() == p.successorProfileId,
            "original owed arrives once at genuinely initialized successor"
        );
    }

    function _assertFlushEvent(Vm.Log[] memory logs) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(revenueEscrow) || logs[i].topics.length == 0
                    || logs[i].topics[0] != FLUSHED
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == PRIMARY_REVENUE_CLASS
                    && logs[i].topics[2] == original.profileId
                    && logs[i].topics[3] == bytes32(uint256(uint160(original.wallet)))
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(uint16(1), address(0), uint256(JOINED_PRICE), uint256(0))
                        ),
                "exact original flush amount and credit-key event"
            );
            ++count;
        }
        require(count == 1, "one original flush event");
    }

    function _assertRecoveryEvent(
        Vm.Log[] memory logs,
        EscrowTerms.EscrowRecoveryRecord memory p,
        bytes32 id
    ) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(revenueEscrow) || logs[i].topics.length == 0
                    || logs[i].topics[0] != RECOVERED
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == id
                    && logs[i].topics[2] == PRIMARY_REVENUE_CLASS
                    && logs[i].topics[3] == original.profileId
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                original.wallet,
                                p.successorWallet,
                                uint256(JOINED_PRICE),
                                p.recoveryManifest.contentHash,
                                WHY,
                                WHERE
                            )
                        ),
                "exact original recovery identity, moved amount and retained manifest event"
            );
            ++count;
        }
        require(count == 1, "one original recovery event");
    }

    function _assertOriginalReceipts() private view {
        _assertWaivedCommerceReceipt(address(joinedRecorder), originalKey, 1);
        require(
            joinedRecorder.settlementConsumed(originalKey) && originalFacts != 0
                && joinedRecorder.preparedNativeRightsFactsHash(originalKey) == originalFacts
                && keccak256(abi.encode(joinedRecorder.settlementResult(originalKey)))
                    == originalResult
                && commerceFloor.settlementReceipt(originalKey).receiptHash == originalFloor
                && joinedRecorder.totalOfficialSettled(address(0)) == JOINED_PRICE
                && joinedRecorder.officialSettled(
                    PRIMARY_REVENUE_CLASS, original.profileId, original.wallet, address(0)
                ) == JOINED_PRICE && joinedRecorder.totalOfficialSettled(address(passiveToken)) == 0
                && core.ownerOf(1) == address(joinedCollector) && manager.nextOperationNonce() == 1
                && entropy.revealFeeEscrow(1) == 100 && joinedHouse.auction(auctionId).status == 3
                && address(joinedRecorder).balance == 0,
            "escrow lifecycle cannot rewrite the actual mint, first sale floor or lifetime official revenue"
        );
    }
}
