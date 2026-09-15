// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceStagePlan.t.sol";
import "../helpers/ArtistArtifactCreate.sol";
import "../../script/current/StreamRevenueRuntimePlan.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueRuntimeRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";

/// @notice Real foundation Executor/catalog/manifest, split factories, escrow and threshold Safe.
/// @dev Tests feed escrow credit directly as an explicitly governed producer. No sale/mint join,
///      actual offchain notice delivery or complete network-history assertion is inferred.
contract StreamCurrentEscrowRecoveryTest is
    StreamCurrentGovernanceStagePlanTest,
    ArtistArtifactCreate
{
    StreamAssetPolicyRegistry private assets;
    StreamSplitFactory private first;
    StreamSplitFactory private second;
    StreamRevenueEscrow private escrow;
    StreamRevenueRuntimeRegistry private runtimeRegistry;
    bytes32 private constant WHY = keccak256("current escrow incident evidence");
    string private constant WHERE = "urn:stream:test:current-escrow";
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant META = keccak256("current escrow original");

    function testCurrentEscrowGovernedRegistryOptInAndClass4RecoveryToSameRecipients() public {
        _ready();
        (bytes32 originalProfile, address originalWallet) =
            first.registerProfile(_entries(address(governor)), META);
        _fund(originalProfile, originalWallet);
        _run(
            StreamRevenueRuntimePlan.factoryStatus(
                runtimeRegistry, address(first), 3, WHY, WHERE, WHY
            )
        );
        (StreamEscrowRecoveryTypes.EscrowRecoveryRecord memory p, bytes32 recoveryId) =
            _document(originalProfile, originalWallet, false);
        (bytes32 expected, GenesisBatch memory batch) = StreamRevenueRuntimePlan.recovery(escrow, p);
        require(
            recoveryId == expected && batch.actionClass == 4, "original recovery identity and floor"
        );
        StreamGovernanceStagePlan.Plan memory saved = _build(keccak256("RECOVERY_SCHEDULE"), batch);
        bytes32 actionId = _schedule(saved);
        require(
            saved.proposer == address(governor) && saved.batch.calls[0].value == 0,
            "actual Safe proposer, zero-value governance"
        );
        vm.expectRevert();
        this.executeSaved(saved, actionId);
        require(
            escrow.escrowRecoveryRecord(recoveryId).status
                == StreamEscrowRecoveryTypes.EscrowRecoveryStatus.NONE,
            "not prematurely scheduled"
        );
        vm.warp(saved.notBefore);
        require(
            this.executeSaved(saved, actionId), "actual class 4 execution records escrow schedule"
        );
        require(
            configuration.executor.governanceAction(actionId).status
                == GovernanceActionStatus.EXECUTED,
            "real FUNDS_RECOVERY action"
        );
        vm.warp(p.executeAfter);
        require(
            executeSafe(
                governor,
                signers,
                address(escrow),
                0,
                abi.encodeCall(escrow.executeEscrowRecovery, (recoveryId)),
                0
            ),
            "Safe permissionless recovery call"
        );
        require(
            originalWallet.balance == 0 && p.successorWallet.balance == 2 ether
                && escrow.totalOwed(address(0)) == 0,
            "exact owed move"
        );
        IStreamSplitWallet(p.successorWallet)
            .release(address(0), address(governor), payable(address(governor)));
        require(
            address(governor).balance == 2 ether,
            "original recipient can release actual recovered money"
        );
        require(
            !this.executeSaved(saved, actionId),
            "saved completed governance action resumes historically"
        );
    }

    function testCurrentEscrowChangedEconomicsRequiresSeparateTerminalActionAndGuardianDelay()
        public
    {
        _ready();
        (bytes32 originalProfile, address originalWallet) =
            first.registerProfile(_entries(address(governor)), META);
        _fund(originalProfile, originalWallet);
        _run(
            StreamRevenueRuntimePlan.factoryStatus(
                runtimeRegistry, address(first), 3, WHY, WHERE, WHY
            )
        );
        (StreamEscrowRecoveryTypes.EscrowRecoveryRecord memory p, bytes32 id) =
            _document(originalProfile, originalWallet, true);
        (, GenesisBatch memory schedule) = StreamRevenueRuntimePlan.recovery(escrow, p);
        bytes32 fundsAction = _run(schedule);
        StreamGovernanceStagePlan.Plan memory terminal =
            _build(keccak256("RECOVERY_TERMINAL"), StreamRevenueRuntimePlan.terminal(escrow, id));
        bytes32 terminalAction = _schedule(terminal);
        require(
            terminalAction != fundsAction && terminal.batch.actionClass == 2,
            "distinct retained terminal action"
        );
        vm.expectRevert();
        this.executeSaved(terminal, terminalAction);
        require(escrow.totalOwed(address(0)) == 2 ether, "guardian window preserves owed");
        vm.warp(terminal.notBefore);
        require(this.executeSaved(terminal, terminalAction), "actual terminal classifier and delay");
        if (block.timestamp < p.executeAfter) vm.warp(p.executeAfter);
        escrow.executeEscrowRecovery(id);
        require(
            p.successorWallet.balance == 2 ether && escrow.totalOwed(address(0)) == 0,
            "notice document plus two actions"
        );
        require(
            configuration.executor.governanceAction(fundsAction).status
                    == GovernanceActionStatus.EXECUTED
                && configuration.executor.governanceAction(terminalAction).status
                    == GovernanceActionStatus.EXECUTED,
            "both actual action receipts"
        );
    }

    function _ready() private {
        _initialize();
        assets = StreamAssetPolicyRegistry(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol:StreamAssetPolicyRegistry",
                abi.encode(address(configuration.executor))
            )
        );
        IStreamGasParameterHost.GasParameterConfig[3] memory caps;
        caps[0] =
            IStreamGasParameterHost.GasParameterConfig("ERC_1271_GAS_LIMIT", 400_000, 350_000, 2);
        caps[1] = IStreamGasParameterHost.GasParameterConfig(
            "ASSET_POLICY_GAS_LIMIT", 150_000, 100_000, 2
        );
        caps[2] = IStreamGasParameterHost.GasParameterConfig(
            "WALLET_DEPOSIT_GAS_LIMIT", 500_000, 100_000, 2
        );
        first = StreamSplitFactory(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory",
                abi.encode(assets, address(configuration.executor), caps)
            )
        );
        second = StreamSplitFactory(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory",
                abi.encode(assets, address(configuration.executor), caps)
            )
        );
        escrow = StreamRevenueEscrow(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow",
                    abi.encode(
                        first,
                        address(configuration.executor),
                        IStreamGasParameterHost.GasParameterConfig(
                            "FLUSH_GAS_FLOOR", 12_000_000, 100_000, 3
                        )
                    )
                ))
        );
        runtimeRegistry = StreamRevenueRuntimeRegistry(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamRevenueRuntimeRegistry.sol:StreamRevenueRuntimeRegistry",
                abi.encode(
                    address(configuration.executor),
                    address(assets),
                    IStreamGasParameterHost.GasParameterConfig(
                        "REVENUE_RUNTIME_READ_GAS", 150_000, 100_000, 2
                    )
                )
            )
        );
        _catalog();
        _run(
            StreamRevenueRuntimePlan.classifier(
                configuration.executor,
                address(runtimeRegistry),
                runtimeRegistry.setFactoryStatus.selector
            )
        );
        _run(
            StreamRevenueRuntimePlan.classifier(
                configuration.executor,
                address(escrow),
                escrow.authorizeTerminalEscrowRecovery.selector
            )
        );
        _run(
            StreamRevenueRuntimePlan.factoryStatus(
                runtimeRegistry, address(first), 1, WHY, WHERE, 0
            )
        );
        _run(
            StreamRevenueRuntimePlan.factoryStatus(
                runtimeRegistry, address(second), 1, WHY, WHERE, 0
            )
        );
        _run(StreamRevenueRuntimePlan.bind(first, address(runtimeRegistry)));
        _run(StreamRevenueRuntimePlan.bind(second, address(runtimeRegistry)));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRevenueRuntimePlan.RevenueRuntimeActivationIncomplete.selector
            )
        );
        this.requireActivation();
        _run(StreamRevenueRuntimePlan.bind(escrow, address(runtimeRegistry)));
        this.requireActivation();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            escrow.creditProducerTransitionHashes(address(this), true);
        GenesisBatch memory b;
        b.actionClass = 1;
        b.calls = new GovernanceCall[](1);
        b.callDatas = new bytes[](1);
        b.callDatas[0] = abi.encodeCall(escrow.setCreditProducer, (address(this), true));
        b.calls[0] =
            StreamCurrentStackPlan.call(address(escrow), b.callDatas[0], scope, oldHash, newHash);
        _run(b);
        vm.deal(address(this), 10 ether);
    }

    function requireActivation() external view {
        StreamRevenueRuntimePlan.requireActivated(address(first), address(escrow));
    }

    function _run(GenesisBatch memory batch) private returns (bytes32 id) {
        StreamGovernanceStagePlan.Plan memory plan =
            _build(keccak256(abi.encode("RECOVERY_STEP", batch)), batch);
        id = _schedule(plan);
        vm.warp(plan.notBefore);
        require(this.executeSaved(plan, id), "actual saved action execution");
    }

    function _fund(bytes32 p, address wallet) private {
        escrow.creditNative{ value: 2 ether }(CLASS, p, wallet, true);
    }

    function _entries(address who) private pure returns (IStreamSplitWallet.SplitEntry[] memory e) {
        e = new IStreamSplitWallet.SplitEntry[](1);
        e[0] = IStreamSplitWallet.SplitEntry(who, 1_000_000, keccak256("author"));
    }

    function _document(bytes32 p, address wallet, bool changed)
        private
        returns (StreamEscrowRecoveryTypes.EscrowRecoveryRecord memory record, bytes32 id)
    {
        IStreamRevenueEscrowRecoveryManifest.ManifestDocument memory d;
        d.creditKey = StreamEscrowRecoveryTypes.EscrowCreditKey(CLASS, p, wallet, address(0));
        d.successorFactory = address(second);
        (d.successorProfileId, d.successorWallet) = second.registerProfile(
            _entries(changed ? address(0xB0B) : address(governor)), keccak256("successor metadata")
        );
        d.successorRuntimeCodeHash = second.splitWalletRuntimeCodeHash();
        d.expectedAmount = 2 ether;
        d.route = changed ? 2 : 0;
        d.oldEntries = _entries(address(governor));
        d.oldMetadataURIHash = META;
        d.successorEntries = _entries(changed ? address(0xB0B) : address(governor));
        d.incidentEvidenceHash = WHY;
        if (changed) {
            d.coverageStatementHash =
                keccak256("explicit test-only coverage assertion, no notice delivery attestation");
            d.recipientNotices = new IStreamRevenueEscrowRecoveryManifest.RecipientNotice[](1);
            d.recipientNotices[0] = IStreamRevenueEscrowRecoveryManifest.RecipientNotice(
                address(governor), WHY, uint64(block.timestamp)
            );
            d.collectionNotices = new IStreamRevenueEscrowRecoveryManifest.CollectionNotice[](1);
            // This fixture's direct producer has no collection-bearing sale receipt. These
            // typed citations exercise governance evidence admission, not actual sale history.
            d.collectionNotices[0] = IStreamRevenueEscrowRecoveryManifest.CollectionNotice(
                address(configuration.core), 1, false, address(0), 0, 0
            );
            d.sourceCredits = new IStreamRevenueEscrowRecoveryManifest.SourceCredit[](1);
            vm.roll(block.number + 2);
            d.sourceCredits[0] = IStreamRevenueEscrowRecoveryManifest.SourceCredit(
                address(this),
                keccak256("typed source tx"),
                keccak256("typed source block"),
                uint64(block.number - 1),
                0,
                0
            );
        }
        bytes32 content = keccak256(
            abi.encode(
                keccak256("6529STREAM_ESCROW_RECOVERY_MANIFEST_V1"),
                block.chainid,
                address(escrow),
                d
            )
        );
        StreamEscrowRecoveryTypes.EscrowRecoveryManifestRef memory ref =
            StreamEscrowRecoveryTypes.EscrowRecoveryManifestRef(
                WHERE,
                keccak256(bytes(WHERE)),
                content,
                keccak256("STREAM_ESCROW_RECOVERY_MANIFEST_V1"),
                keccak256("6529STREAM_ESCROW_RECOVERY_ABI_V1")
            );
        escrow.publishEscrowRecoveryManifest(d, ref);
        record = StreamEscrowRecoveryTypes.EscrowRecoveryRecord(
            StreamEscrowRecoveryTypes.EscrowRecoveryStatus.SCHEDULED,
            d.creditKey,
            address(first),
            d.successorWallet,
            d.successorProfileId,
            d.successorRuntimeCodeHash,
            d.expectedAmount,
            ref,
            uint64(block.timestamp + 14 days + (changed ? 73 hours : 2 hours)),
            WHY,
            WHERE
        );
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ESCROW_RECOVERY_V1"),
                block.chainid,
                address(escrow),
                CLASS,
                p,
                wallet,
                address(0),
                d.successorWallet,
                d.successorProfileId,
                d.successorRuntimeCodeHash,
                d.expectedAmount,
                content,
                record.executeAfter,
                WHY
            )
        );
    }

    function _catalog() private {
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](9);
        rows[0] = _row(
            1, address(configuration.executor), configuration.executor.setTighteningCall.selector
        );
        rows[1] = _row(
            0,
            address(configuration.executor),
            configuration.executor.registerFreezeSelector.selector
        );
        rows[2] = _row(1, address(runtimeRegistry), runtimeRegistry.setFactoryStatus.selector);
        rows[3] = _row(0, address(runtimeRegistry), runtimeRegistry.setFactoryStatus.selector);
        rows[4] = _row(1, address(first), first.initializeRevenueRuntimeRegistry.selector);
        rows[5] = _row(1, address(second), second.initializeRevenueRuntimeRegistry.selector);
        rows[6] = _row(1, address(escrow), escrow.initializeRevenueRuntimeRegistry.selector);
        rows[7] = _row(1, address(escrow), escrow.setCreditProducer.selector);
        rows[8] = _row(4, address(escrow), escrow.scheduleEscrowRecovery.selector);
        // Include terminal in the same original catalog extension, prior to any action scheduling.
        GovernanceActionPolicyEntry[] memory all = new GovernanceActionPolicyEntry[](10);
        for (uint256 i; i < 9; ++i) {
            all[i] = rows[i];
        }
        all[9] = _row(2, address(escrow), escrow.authorizeTerminalEscrowRecovery.selector);
        for (uint256 i = 1; i < all.length; ++i) {
            for (uint256 j = i; j > 0 && _key(all[j - 1]) > _key(all[j]); --j) {
                (all[j - 1], all[j]) = (all[j], all[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(configuration.executor, all);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(configuration.manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes('{"purpose":"governed escrow recovery test"}')
        );
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
            configuration.manifest,
            payload,
            update
        );
        require(count == 10, "all exact new catalog entries");
        _run(batch);
    }

    function _row(uint8 cls, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            cls,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(configuration.deploymentHash, target)),
            1,
            0,
            0,
            0
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }
}
