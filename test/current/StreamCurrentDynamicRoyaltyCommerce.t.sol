// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/CurrentDynamicRoyaltyCommerceFixture.sol";

interface JoinedCommerceVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice One actual Artist/Core/Manager/Resolver/Safe graph from symbolic terms through frozen-royalty resale.
/// @dev Authored aggregate transaction recipes; native execution and transaction capacity remain separate evidence.
contract StreamCurrentDynamicRoyaltyCommerceTest is CurrentDynamicRoyaltyCommerceFixture {
    function setUp() public {
        _deployJoinedCommerce();
    }

    function _joinedReady(uint8 sourceKind) private returns (bytes32 templateId) {
        this.joinedSnapshotSetup(sourceKind);
        templateId = this.joinedCreateTemplate();
        this.joinedApproveTemplate(templateId);
        this.joinedInstallTemplate(templateId);
        this.joinedInstallPhase();
    }

    function _mintAndRead()
        private
        returns (bytes32 id, IStreamRoyaltySnapshot.Snapshot memory snapshot)
    {
        id = this.joinedCreateAuction();
        _joinedBid(id);
        _joinedSettle(id);
        snapshot = _joinedAssertMint(id);
    }

    function _resell(IStreamRoyaltySnapshot.Snapshot memory snapshot) private {
        bytes32 saleId = this.joinedConfigureResale(snapshot.tokenId);
        _joinedCustody(saleId, snapshot.tokenId);
        (address receiver, uint256 amount, bool secondary, bool disclosure) =
            joinedPrivate.royaltyQuote(saleId);
        require(
            receiver == joinedSource.config.wallet
                && amount == uint256(RESALE_PRICE) * joinedSource.config.royaltyBps / 10000
                && secondary && !disclosure,
            "actual Core snapshot quote, no external disclosure substitution"
        );
        _joinedResale(saleId, snapshot);
    }

    function testConfiguredZeroCollectionDynamicMintThenSameNftActualSafeCustodySale() public {
        _joinedReady(1);
        require(
            royalties.defaultRoyalty().royaltyBps == 600 && joinedSource.config.royaltyBps == 0,
            "explicit zero suppresses positive default"
        );
        (, IStreamRoyaltySnapshot.Snapshot memory snapshot) = _mintAndRead();
        require(
            snapshot.tokenAssignmentHash != 0 && snapshot.tokenRoyaltyPolicyHash != 0
                && royalties.tokenRoyalty(snapshot.tokenId).configured,
            "configured zero retains full nonzero token authority"
        );
        this.joinedGovern(
            address(royalties),
            abi.encodeCall(royalties.configureDefaultRoyalty, (profile, uint16(900)))
        );
        _resell(snapshot);
    }

    function testPositiveDefaultSnapshotPaysFrozenRoyaltyOnSameNftResaleAfterDefaultChange()
        public
    {
        _joinedReady(0);
        require(
            !royalties.collectionRoyalty(1).configured && joinedSource.config.royaltyBps == 600,
            "actual missing key chooses original positive default"
        );
        (, IStreamRoyaltySnapshot.Snapshot memory snapshot) = _mintAndRead();
        this.joinedGovern(
            address(royalties),
            abi.encodeCall(royalties.configureDefaultRoyalty, (bytes32(0), uint16(0)))
        );
        (bool admitted,) = address(royalties)
            .staticcall(abi.encodeCall(royalties.currentRoyaltySnapshotSource, (uint256(1))));
        require(!admitted, "new unapproved default cannot authorize another snapshot mint");
        (address receiver, uint256 amount) = core.royaltyInfo(snapshot.tokenId, RESALE_PRICE);
        require(
            receiver == wallet && amount == RESALE_PRICE * 600 / 10000,
            "old token disclosure survives loss of current source approval"
        );
        _resell(snapshot);
    }

    function testZeroDefaultSnapshotSurvivesLaterApprovedPositiveCollectionOverrideAndResale()
        public
    {
        _joinedReady(2);
        require(
            !royalties.collectionRoyalty(1).configured && joinedSource.config.profileId == 0,
            "actual configured-zero default selected"
        );
        (, IStreamRoyaltySnapshot.Snapshot memory snapshot) = _mintAndRead();
        this.joinedReplaceCollectionSource(700);
        IStreamRoyaltySnapshot.Source memory current = royalties.currentRoyaltySnapshotSource(1);
        require(
            current.config.royaltyBps == 700
                && current.sourceAssignmentHash != joinedSource.sourceAssignmentHash,
            "later collection override has its own exact Safe approval"
        );
        (address receiver, uint256 amount) = core.royaltyInfo(snapshot.tokenId, RESALE_PRICE);
        require(
            receiver == address(0) && amount == 0,
            "frozen zero token suppresses later positive override"
        );
        _resell(snapshot);
    }

    function testActualDefaultDriftRollsBackSignedSafeSettlementThenIdenticalCallRetries() public {
        _joinedReady(0);
        bytes32 id = this.joinedCreateAuction();
        _joinedBid(id);
        this.joinedGovern(
            address(royalties),
            abi.encodeCall(royalties.configureDefaultRoyalty, (profile, uint16(500)))
        );
        bytes memory data = abi.encodeCall(joinedHouse.settle, (id));
        uint256 nonce = joinedCollector.nonce();
        bytes32 digest = joinedCollector.getTransactionHash(
            address(joinedHouse), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory original = abi.encodeCall(
            joinedCollector.execTransaction,
            (
                address(joinedHouse),
                uint256(0),
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, digest)
            )
        );
        JoinedCommerceVm(address(uint160(uint256(keccak256("hevm cheat code")))))
            .expectCall(address(joinedHouse), 0, data, 2);
        uint256 beforeBalance = address(joinedCollector).balance;
        (bool ok, bytes memory failed) = address(joinedCollector).call(original);
        require(
            !ok && keccak256(failed) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedCollector.nonce() == nonce
                && address(joinedCollector).balance == beforeBalance
                && core.lastAllocatedTokenId() == 0 && core.pendingPreparedMintTokenId() == 0
                && manager.nextOperationNonce() == 0 && !royalties.royaltySnapshot(1).exists
                && joinedHouse.totalBuyerLiabilities() == JOINED_PRICE + 100
                && joinedRecorder.totalOfficialSettled(address(0)) == 0,
            "original Safe failure preserves whole unpaid mint/payment state"
        );
        this.joinedGovern(
            address(royalties),
            abi.encodeCall(royalties.configureDefaultRoyalty, (profile, uint16(600)))
        );
        // Assignment preimages exclude revision; returning the exact original terms restores the original approval.
        require(
            royalties.currentRoyaltySnapshotSource(1).modeAssignmentHash
                == joinedSource.modeAssignmentHash,
            "original exact source approval restored"
        );
        vm.recordLogs();
        (ok,) = address(joinedCollector).call(original);
        _joinedReceipt(id, vm.getRecordedLogs());
        require(
            ok && joinedCollector.nonce() == nonce + 1, "byte-identical fully signed Safe retry"
        );
        IStreamRoyaltySnapshot.Snapshot memory snapshot = _joinedAssertMint(id);
        require(
            core.ownerOf(snapshot.tokenId) == address(joinedCollector),
            "one final actual collector delivery"
        );
    }

    function testActualTemplateConsentRepairsSameGovernanceAndPayoutRotationKeepsOriginalRow()
        public
    {
        this.joinedSnapshotSetup(1);
        bytes32 templateId = this.joinedCreateTemplate();
        bytes memory data = abi.encodeCall(
            primaryResolver.setPrimaryTemplateAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), templateId, bytes32(0))
        );
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        calls[0] = StreamCurrentStackPlan.call(
            address(primaryResolver),
            data,
            keccak256(abi.encode(address(primaryResolver), data)),
            0,
            keccak256(data)
        );
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(1, calls, datas);
        vm.warp(ready);
        bytes memory original =
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, datas));
        bytes32 beforeAssignment = primaryResolver.primaryEconomicsFacts(1, 1, 1).assignmentHash;
        (bool ok,) = address(executor).call(original);
        require(
            !ok && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && primaryResolver.primaryEconomicsFacts(1, 1, 1).assignmentHash
                    == beforeAssignment,
            "missing original op15 leaves scheduled action and old key"
        );
        bytes32 approval = this.joinedApproveTemplate(templateId);
        (ok,) = address(executor).call(original);
        require(ok, "same actual governor action after actual Safe op15");
        StreamSaleTemplate.Selection memory beforeRotation = _joinedSelection();
        T.Binding memory b = artistCoordinator.reads().acceptedBinding(1);
        C.Row memory row = artists.collaboratorAt(1, b.generation, 0);
        this.joinedRotateCollaboratorPayout(address(joinedBuyer));
        StreamSaleTemplate.Selection memory afterRotation = _joinedSelection();
        C.Row memory current = artists.collaboratorAt(1, b.generation, 0);
        require(
            keccak256(abi.encode(row)) == keccak256(abi.encode(current))
                && row.account == address(joinedCollaborator) && row.role == 0
                && row.acceptanceRecordHash != 0 && afterRotation.assignmentHash == approval
                && afterRotation.profileId != beforeRotation.profileId,
            "current money destination changes without replacing original accepted row or consent"
        );
        this.joinedInstallPhase();
        (, IStreamRoyaltySnapshot.Snapshot memory snapshot) = _mintAndRead();
        require(
            snapshot.exists && core.ownerOf(snapshot.tokenId) == address(joinedCollector),
            "rotated actual collaborator participates in actual prepared mint"
        );
    }
}
