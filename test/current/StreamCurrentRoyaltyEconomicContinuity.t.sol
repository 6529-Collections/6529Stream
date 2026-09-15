// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/CurrentDynamicRoyaltyCommerceFixture.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import {
    StreamRoyaltyContinuityTypes as RC
} from "../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltyEconomicContinuity.sol";

/// @notice Actual Artist/Safe op15, paid current-Core snapshot and delayed governed Resolver cutover.
/// @dev Source-authored integration; runtime/size acceptance is separate. No new mint authority is inferred from copied receipts.
contract StreamCurrentRoyaltyEconomicContinuityTest is CurrentDynamicRoyaltyCommerceFixture {
    StreamRoyaltyResolver private nextRoyalty;
    bytes32 private constant POINTER = keccak256("ROYALTY_RESOLVER");

    function setUp() public {
        _deployJoinedCommerce();
    }

    function _mintOriginal(uint8 sourceKind)
        private
        returns (IStreamRoyaltySnapshot.Snapshot memory old)
    {
        this.joinedSnapshotSetup(sourceKind);
        bytes32 templateId = this.joinedCreateTemplate();
        this.joinedApproveTemplate(templateId);
        this.joinedInstallTemplate(templateId);
        this.joinedInstallPhase();
        bytes32 saleId = this.joinedCreateAuction();
        _joinedBid(saleId);
        _joinedSettle(saleId);
        return _joinedAssertMint(saleId);
    }

    function _deployNext() private {
        nextRoyalty = StreamRoyaltyResolver(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamRoyaltyResolver.sol:StreamRoyaltyResolver",
                abi.encode(
                    core, factory, address(executor), IStreamArtistAttribution(address(artists))
                )
            )
        );
        _assertDeployableProductionInstance(address(nextRoyalty));
        // Extend only this exact new target/selector through the actual saved catalog and required tail.
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(nextRoyalty),
            nextRoyalty.beginEconomicContinuity.selector,
            address(nextRoyalty).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(nextRoyalty))),
            1,
            0,
            0,
            0
        );
        StreamGovernanceCatalogStagePlan.Inventory memory saved =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) =
            _discovery("continuity admission");
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            saved,
            StreamGovernanceCatalogStagePlan.inventoryHash(saved),
            0,
            manifest,
            payload,
            update
        );
        require(count == 1, "one exact candidate admission");
        _run(3, batch.calls, batch.callDatas);
    }

    function _reference() private view returns (RC.ManifestRef memory r) {
        RC.Header memory h = royalties.continuityHeader();
        r.expectedSourceHeaderHash = keccak256(abi.encode(h));
        r.uri = "ipfs://actual-current-royalty-continuity";
        r.uriHash = keccak256(bytes(r.uri));
        r.schemaId = keccak256("STREAM_ROYALTY_CONTINUITY_MANIFEST_V1");
        r.canonicalizationId = keccak256("STREAM_ROYALTY_CONTINUITY_ABI_V1");
        r.contentHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_CONTINUITY_MANIFEST_V1"),
                block.chainid,
                address(royalties),
                address(royalties).codehash,
                address(nextRoyalty),
                address(core),
                address(factory),
                h,
                r.uri,
                r.uriHash,
                r.schemaId,
                r.canonicalizationId
            )
        );
    }

    function _copy() private returns (bytes32 manifestHash) {
        RC.ManifestRef memory r = _reference();
        (bytes32 hash, bytes32 scope, bytes32 before_, bytes32 after_) =
            nextRoyalty.previewEconomicContinuity(address(royalties), r);
        require(hash == r.contentHash, "canonical original manifest");
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(nextRoyalty.beginEconomicContinuity, (address(royalties), r));
        calls[0] = StreamCurrentStackPlan.call(
            address(nextRoyalty), data[0], scope, before_, after_
        );
        _run(1, calls, data);
        _joinedSafe(
            joinedCollector,
            address(nextRoyalty),
            0,
            abi.encodeCall(nextRoyalty.importEconomicContinuity, (uint256(16), uint256(64)))
        );
        _joinedSafe(
            joinedCollector,
            address(nextRoyalty),
            0,
            abi.encodeCall(nextRoyalty.completeEconomicContinuity, ())
        );
        return hash;
    }

    function _install() private {
        StreamModuleRegistration memory item = StreamModuleRegistration(
            address(nextRoyalty),
            keccak256("REVENUE_RESOLVER"),
            keccak256("exact royalty economic continuity"),
            type(IStreamRoyaltyResolver).interfaceId,
            500000,
            address(nextRoyalty).codehash,
            DEPLOYMENT_HASH,
            keccak256("continuity reconstruction"),
            "ipfs://continuity-reconstruction"
        );
        StreamModuleRegistration[] memory items = new StreamModuleRegistration[](1);
        items[0] = item;
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, items);
        _run(1, calls, data);
        StreamCorePointerState memory old = StreamCurrentStackPlan.readPointer(core, POINTER);
        StreamCorePointerState memory next =
            StreamCurrentStackPlan.pointerState(address(registry), item, false, old.revision + 1);
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            StreamCurrentStackPlan.pointerTransitionHashes(core, POINTER, old, next);
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        data[0] = abi.encodeCall(core.updateSatellitePointer, (POINTER, address(nextRoyalty)));
        calls[0] = StreamCurrentStackPlan.call(address(core), data[0], scope, before_, after_);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        current.modules.revenueResolver = address(nextRoyalty);
        (address payload, StreamSystemManifestUpdate memory update) =
            _discovery("continuity pointer replacement");
        (calls[1], data[1]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
        _run(3, calls, data);
        require(
            StreamCurrentStackPlan.readPointer(core, POINTER).target == address(nextRoyalty),
            "actual governed Core cutover"
        );
    }

    function _discovery(string memory purpose)
        private
        returns (address payload, StreamSystemManifestUpdate memory update)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        bytes32 hash;
        (payload, hash) =
            StreamGenesisManifestPlan.writePayload(abi.encode(purpose, address(nextRoyalty)));
        update = StreamSystemManifestUpdate(
            hash,
            "ipfs://current-royalty-continuity",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
    }

    function _run(uint8 cls, GovernanceCall[] memory calls, bytes[] memory data) private {
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(cls, calls, data);
        vm.warp(ready);
        _joinedSafe(
            governorSafe,
            address(executor),
            0,
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "actual Safe delayed execution"
        );
    }

    function _assertOriginal(IStreamRoyaltySnapshot.Snapshot memory old, bytes32 manifestHash)
        private
        view
    {
        require(
            keccak256(abi.encode(nextRoyalty.royaltySnapshot(old.tokenId)))
                == keccak256(abi.encode(old)),
            "entire original Manager/root/operation/election/source/config and actual token receipt retained"
        );
        require(
            nextRoyalty.tokenRoyalty(old.tokenId).frozen
                && nextRoyalty.continuitySource() == address(royalties)
                && nextRoyalty.supportsEconomicContinuity(
                    address(royalties),
                    royalties.frozenEconomicStateHash(address(core)),
                    manifestHash
                ),
            "complete exact old-resolver economic continuity after actual cutover"
        );
        (address receiver, uint256 amount) = core.royaltyInfo(old.tokenId, RESALE_PRICE);
        require(
            receiver == joinedSource.config.wallet
                && amount == uint256(RESALE_PRICE) * joinedSource.config.royaltyBps / 10000,
            "actual ERC2981 still serves original token terms through successor"
        );
        require(
            core.ownerOf(old.tokenId) == address(joinedCollector),
            "original paid collector remains owner"
        );
    }

    function testActualPositiveDefaultSnapshotSurvivesGovernedResolverCutoverAndSameTokenResale()
        public
    {
        IStreamRoyaltySnapshot.Snapshot memory old = _mintOriginal(0);
        _deployNext();
        bytes32 h = _copy();
        _install();
        _assertOriginal(old, h);
        require(
            nextRoyalty.economicElectionAt(0).hashOrigin == address(royalties)
                && nextRoyalty.protectedEconomicRouteAt(0).hashOrigin == address(royalties),
            "election and token origins retain old domains"
        );
        bytes32 saleId = this.joinedConfigureResale(old.tokenId);
        _joinedCustody(saleId, old.tokenId);
        (address receiver, uint256 due, bool secondary, bool disclosure) =
            joinedPrivate.royaltyQuote(saleId);
        require(
            receiver == joinedSource.config.wallet && due == uint256(RESALE_PRICE) * 600 / 10000
                && secondary && !disclosure,
            "same NFT current Core secondary quote uses copied frozen token, not missing new default"
        );
        _joinedResale(saleId, old);
    }

    function testActualConfiguredZeroSnapshotCopiesOriginalReceiptAndSuppressesFallback() public {
        IStreamRoyaltySnapshot.Snapshot memory old = _mintOriginal(1);
        _deployNext();
        bytes32 h = _copy();
        _install();
        _assertOriginal(old, h);
        require(
            nextRoyalty.tokenRoyalty(old.tokenId).configured
                && nextRoyalty.tokenRoyalty(old.tokenId).royaltyBps == 0,
            "configured zero remains an actual frozen assignment"
        );
        require(
            !nextRoyalty.collectionRoyalty(1).configured
                && !nextRoyalty.defaultRoyalty().configured,
            "only protected ledgers are imported; mutable future configuration is a separate explicit authority action"
        );
        require(
            manager.nextOperationNonce() == 1 && core.lastAllocatedTokenId() == old.tokenId,
            "copying a receipt never repeats original mint or consumes another operation"
        );
    }
}
