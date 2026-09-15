// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/NativeSupplementalTestBase.sol";

contract StreamNativeSupplementalRightsTest is NativeSupplementalTestBase {
    function testCollectionThenDefaultPrecedenceUsesActualTokenAndRejectsStaleRights() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        (bytes32 p, address w) = _newProfile(address(0xBEEF), keccak256("collection replacement"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, p, 0);
        (bool ok,) = address(clearing).call{ value: 2000 }(abi.encodeCall(clearing.supplement, (c)));
        require(!ok, "stale concrete rights");
        _unchanged(c, 0, 1000);
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        resolver.setPrimaryProfileAssignment(CLASS, 0, 0, p, 0);
        _freshRights(c);
        _submit(c);
        require(
            w.balance == 2000 && wallet.balance == 1000,
            "default after collection removal, old floor unchanged"
        );
    }

    function testBoundCollectionCannotSilentlyUseUnsupportedTokenOverride() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        (bytes32 p,) = _newProfile(address(0xBEEF), keccak256("preconfigured token"));
        resolver.setPrimaryProfileAssignment(CLASS, 2, 1, p, 0);
        _freshRights(c);
        supplementalArtist.accept(artist);
        (bool ok,) = address(clearing).call{ value: 2000 }(abi.encodeCall(clearing.supplement, (c)));
        require(!ok, "actual resolver bound-token support remains closed");
        _unchanged(c, 0, 0);
    }

    function testTemplateNewPayoutMaterializesCurrentRightsAndBothOldWalletsRemainPayable()
        external
    {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 1_000_000, keccak256("artist")
        );
        bytes32 templateId =
            resolver.createPrimaryTemplate(entries, keccak256("immutable clearing template"));
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, templateId, 0);
        supplementalArtist.accept(artist);
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        bytes32 oldProfile = c.originalFloor.rights.profileId;
        address oldWallet = c.originalFloor.rights.wallet;
        require(
            oldWallet.code.length == 0
                && escrow.escrowOwed(CLASS, oldProfile, oldWallet, address(0)) == 1000,
            "real empty-template floor"
        );
        address next = address(0xBEEF);
        supplementalArtist.changePayout(next);
        _freshRights(c);
        require(
            c.currentRights.profileId != oldProfile
                && !factory.profileExists(c.currentRights.profileId),
            "new current payout preview only"
        );
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result = _submit(c);
        require(
            result.escrowed && factory.profileExists(result.profileId)
                && result.wallet.code.length == 0,
            "registered without deployment"
        );
        require(
            escrow.escrowOwed(CLASS, result.profileId, result.wallet, address(0)) == 2000,
            "current supplemental rights owed"
        );
        escrow.flushEscrow(CLASS, oldProfile, oldWallet, address(0));
        escrow.flushEscrow(CLASS, result.profileId, result.wallet, address(0));
        uint256 beforeArtist = artist.balance;
        uint256 beforeNext = next.balance;
        IStreamSplitWallet(oldWallet).release(address(0), artist, payable(artist));
        IStreamSplitWallet(result.wallet).release(address(0), next, payable(next));
        require(
            artist.balance == beforeArtist + 1000 && next.balance == beforeNext + 2000
                && supplementalManager.nonce() == 1,
            "old and current independently payable no remint"
        );
    }

    function testAdmittedProducerCannotReenterRecorderFromStaticFacts() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        clearing.configureFault(8, 0, true);
        _submit(c);
        require(wallet.balance == 3000, "both facts reads pin exact OZ5 guard then succeed");
    }

    function testProducerRevocationLeavesOrdinaryDirectFundingAvailable() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        _producer(false);
        _submit(c);
        require(
            wallet.balance == 3000 && escrow.escrowOwed(CLASS, profile, wallet, address(0)) == 0,
            "fallback admission not required for direct transfer"
        );
    }
}
