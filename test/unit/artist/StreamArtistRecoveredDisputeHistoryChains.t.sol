// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveredDisputeHistoryChains as Chains } from
    "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryChains.sol";
import { StreamArtistRecoveredDisputeHistoryTypes as D } from
    "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";
import { StreamArtistRecoveredAcceptedGenerationTypes as G } from
    "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import { StreamArtistRecoveredHydrationTypes as RH } from
    "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistAttributionDisputeTypes as AD } from
    "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";

interface DisputeChainsVm {
    function expectRevert(bytes4) external;
}

/// @notice Pure chain/head regression coverage, independent of producer authentication.
/// @dev Synthetic rows exercise the linked validators; actual original producer and
/// complete hydration/Safe acceptance remain covered by their separate integration suites.
contract StreamArtistRecoveredDisputeHistoryChainsTest {
    DisputeChainsVm private constant vm =
        DisputeChainsVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testEveryGenerationHeadIsChecked() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _base(3);
        Chains.validate(b, p);
        b.heads[1].revocationReason = 4;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validateGenerationChains(b, p);
    }

    function testLatestLifecycleCheckRemainsProfileSpecific() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _base(1);
        b.current.state = 5;
        Chains.validateGenerationChains(b, p);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validateSanctioned(b, p);
    }

    function testVerifiedRestoreRequiresSanctionedProfile() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _open();
        b.heads[0].restoreState = 3;
        Chains.validateSanctioned(b, p);
        Chains.validateGenerationChains(b, p);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
        b.heads[0].restoreState = 2;
        Chains.validate(b, p);
    }

    function testRepudiationMustBeExecutedForExactGeneration() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _base(2);
        b.heads[1].revocationReason = 3;
        b.current.state = 5;
        b.repudiations = new D.RepudiationRow[](1);
        b.repudiations[0].record.terms.bindingGeneration = 2;
        b.repudiations[0].terminal.phase = 4;
        Chains.validate(b, p);
        b.repudiations[0].record.terms.bindingGeneration = 1;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
        b.repudiations[0].record.terms.bindingGeneration = 2;
        b.repudiations[0].terminal.phase = 3;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
    }

    function testAnOpenDisputeCannotClaimAClosedHead() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _open();
        Chains.validate(b, p);
        b.heads[0].open = false;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validateGenerationChains(b, p);
    }

    function testWithdrawalRetainsCounterAndOriginalOpener() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _withdrawn();
        Chains.validate(b, p);
        b.disputes[2].record.signer = address(0xBAD);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
        b.disputes[2].record.signer = b.disputes[0].record.signer;
        b.heads[0].counterStatementRecordHash = bytes32(0);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
    }

    function testWithdrawalHeadMustMatchSavedRestoration() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _withdrawn();
        b.heads[0].restoreState = 3;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validateSanctioned(b, p);
    }

    function testWithdrawalCannotPrecedeOriginalOpening() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _withdrawn();
        b.disputes[2].point.ownerRevision = b.disputes[0].point.ownerRevision;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
    }

    function testReopenedHeadRetainsPriorGovernedResolution() external {
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _open();
        D.DisputeRow memory first = b.disputes[0];
        b.disputes = new D.DisputeRow[](2);
        b.disputes[0] = first;
        b.disputes[1].record.terms.disputeAction = 1;
        b.disputes[1].record.terms.bindingGeneration = 1;
        b.disputes[1].record.bindingHash = first.record.bindingHash;
        b.disputes[1].record.recordHash = bytes32(uint256(33));
        b.disputes[1].record.previousRecordHash = first.record.recordHash;
        b.disputes[1].record.governanceActionId = bytes32(uint256(55));
        b.disputes[1].point = RH.Point(p.eras[0].originHash, 4, 3);
        b.resolutions = new D.ResolutionRow[](1);
        b.resolutions[0].record.terms.bindingGeneration = 1;
        b.resolutions[0].record.terms.disputeRecordHash = first.record.recordHash;
        b.resolutions[0].record.terms.resolution = 2;
        b.resolutions[0].record.actionId = bytes32(uint256(77));
        b.resolutions[0].record.actionClass = 2;
        b.resolutions[0].point = RH.Point(p.eras[0].originHash, 4, 2);
        b.heads[0].disputeRecordHash = b.disputes[1].record.recordHash;
        b.heads[0].resolutionActionId = b.resolutions[0].record.actionId;
        b.heads[0].reopened = true;
        b.heads[0].revocationReason = 4;
        Chains.validate(b, p);
        b.heads[0].reopened = false;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
        b.heads[0].reopened = true;
        b.disputes[1].record.governanceActionId = bytes32(0);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(b, p);
    }

    function testFuzzUnknownHeadHashesCannotBeInvented(bytes32 hash, bool resolution) external {
        if (hash == bytes32(0)) hash = bytes32(uint256(1));
        (D.Bundle memory b, RH.OwnerProvenance memory p) = _open();
        if (resolution) b.heads[0].resolutionActionId = hash;
        else b.heads[0].counterStatementRecordHash = hash;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Chains.validateSanctioned(b, p);
    }

    function _base(uint256 generations)
        private pure returns (D.Bundle memory b, RH.OwnerProvenance memory p)
    {
        b.generations = new G.Generation[](generations);
        b.heads = new AD.Head[](generations);
        b.current.generation = uint64(generations);
        b.current.state = 2;
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0].chainId = 1;
        p.origins[0].owners[4] = address(0xAA);
        p.origins[0].ownerCodeHashes[4] = keccak256("original attribution runtime");
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(p.origins[0]);
        p.eras[0].checkpoint.schema = RH.CHECKPOINT;
        p.eras[0].checkpoint.ownerState.domainId = RH.ownerDomain(4);
        p.eras[0].checkpoint.ownerState.revision = 10;
    }

    function _open() private pure returns (D.Bundle memory b, RH.OwnerProvenance memory p) {
        (b, p) = _base(1);
        b.current.state = 4;
        b.disputes = new D.DisputeRow[](1);
        b.disputes[0].record.terms.disputeAction = 1;
        b.disputes[0].record.terms.bindingGeneration = 1;
        b.disputes[0].record.recordHash = bytes32(uint256(11));
        b.disputes[0].record.bindingHash = bytes32(uint256(22));
        b.disputes[0].record.signer = address(0x123);
        b.disputes[0].point = RH.Point(p.eras[0].originHash, 4, 1);
        b.heads[0].disputeRecordHash = b.disputes[0].record.recordHash;
        b.heads[0].restoreState = 2;
        b.heads[0].open = true;
    }

    function _withdrawn() private pure returns (D.Bundle memory b, RH.OwnerProvenance memory p) {
        (b, p) = _open();
        D.DisputeRow memory first = b.disputes[0];
        b.disputes = new D.DisputeRow[](3);
        b.disputes[0] = first;
        for (uint256 i = 1; i < 3; ++i) {
            b.disputes[i].record.terms.bindingGeneration = 1;
            b.disputes[i].record.bindingHash = first.record.bindingHash;
            b.disputes[i].record.disputeRecordHash = first.record.recordHash;
            b.disputes[i].record.recordHash = bytes32(uint256(11 + i));
            b.disputes[i].point = RH.Point(p.eras[0].originHash, 4, uint64(i + 1));
        }
        b.disputes[1].record.terms.disputeAction = 3;
        b.disputes[2].record.terms.disputeAction = 2;
        b.disputes[2].record.previousRecordHash = b.disputes[1].record.recordHash;
        b.disputes[2].record.signer = first.record.signer;
        b.disputes[0].withdrawal.recordHash = b.disputes[2].record.recordHash;
        b.disputes[0].withdrawal.counterStatementRecordHash = b.disputes[1].record.recordHash;
        b.disputes[0].withdrawal.restoredState = 2;
        b.heads[0].counterStatementRecordHash = b.disputes[1].record.recordHash;
        b.heads[0].open = false;
        b.current.state = 2;
    }
}
