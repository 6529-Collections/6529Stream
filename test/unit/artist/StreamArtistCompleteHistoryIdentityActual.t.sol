// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryIdentityFixture.sol";

contract StreamArtistCompleteHistoryIdentityActualTest is ArtistCompleteHistoryIdentityFixture {
    function testCompleteIdentityNewCorrectionKeepsAllThreeOriginalRegistrationSlots() external {
        bytes32 latest = _history(false);
        IdentityObserved memory x = _observeIdentities(latest);
        require(x.identities.length == 3, "A, ordinary collaborator, genuinely new B");
        require(
            x.inventory.bindings.bindings[1].corrections[1].approval.registrationNonce == 2,
            "new correction uses real allocator slot two"
        );
        require(
            this.recoveries(x.identities[_principal(x.scope, collaboratorId)]) == 0,
            "ordinary collaborator has zero recoveries"
        );
        require(
            this.recoveries(x.identities[_principal(x.scope, latest)]) == 0,
            "new primary needs no fabricated recovery"
        );
        require(
            x.inventory.bindings.bindings[1].bindings.rows[0].item.artistId == artistId,
            "former primary retained separately from latest B"
        );
    }

    function testCompleteIdentityReusedCorrectionKeepsZeroRegistrationNonceWithoutNewSlot()
        external
    {
        bytes32 latest = _history(true);
        IdentityObserved memory x = _observeIdentities(latest);
        require(latest == collaboratorId && x.identities.length == 2, "B is existing collaborator");
        require(
            x.inventory.bindings.bindings[1].corrections[1].approval.registrationNonce == 0,
            "reused B keeps original zero correction nonce"
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce() == 2,
            "reuse does not allocate another original identity"
        );
    }

    function testCompleteIdentityRejectsFormerPrincipalDocumentCorruptionAndRestores() external {
        IdentityObserved memory x = _observeIdentities(_history(false));
        uint256 a = _principal(x.scope, artistId);
        bytes memory saved = x.identities[a];
        x.identities[a] = this.tamper(x.identities[a], 0, false);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
    }

    function testCompleteIdentityRetainsOriginalCollaboratorSignatureAcrossPrimaryCorrection()
        external
    {
        IdentityObserved memory x = _observeIdentities(_historyWithPartial(true, true));
        require(x.clocks.accepted[1][0] == 1, "former generation's genuine collaborator join");
        uint256 a = _principal(x.scope, collaboratorId);
        bytes memory saved = x.identities[a];
        x.identities[a] = this.tamper(x.identities[a], pcAccepted[0], true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
    }

    function testCompleteIdentityRejectsFormerPrimaryAndCollaboratorSignatureCorruption() external {
        IdentityObserved memory x = _observeIdentities(_history(true));
        uint256 a = _principal(x.scope, artistId);
        bytes memory saved = x.identities[a];
        x.identities[a] = this.tamper(x.identities[a], pcPrimary[0], true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        x.identities[a] = this.tamper(x.identities[a], pcRecords[pcRecords.length - 1], true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        a = _principal(x.scope, collaboratorId);
        saved = x.identities[a];
        x.identities[a] = this.tamper(x.identities[a], collaboratorId, true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
    }

    function testCompleteIdentityRejectsOmittedGlobalAccountNonceLane() external {
        IdentityObserved memory x = _observeIdentities(_history(true));
        RH.NonceInventory[] memory changed = new RH.NonceInventory[](x.nonces.length - 1);
        uint256 count;
        for (uint256 i; i < x.nonces.length; ++i) {
            if (x.nonces[i].index.kind == 3) continue;
            changed[count++] = x.nonces[i];
        }
        require(count == changed.length, "one real collaborator account lane removed");
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        CHIdentity.validateCollected(x.scope, x.inventory, x.clocks, x.identities, changed);
    }

    function testCompletePrincipalsCollectAllActualIdentityPayoutTimingAndFeatures() external {
        IdentityObserved memory x = _observeIdentities(_history(false));
        CHPrincipals.Result memory r = CHPrincipals.collect(_certificate(x));
        require(
            keccak256(abi.encode(r.principals.identities)) == keccak256(abi.encode(x.identities)),
            "same canonical source identity bytes"
        );
        require(
            r.principals.payouts.length == 3 && r.principals.authoritySupplement.length == 3,
            "every real principal has complete payout and explicit supplement slot"
        );
        require(
            r.emptyIdentity.length == 0 && r.externalGuards.artistId != 0,
            "real principals never use empty certificate"
        );
        require(
            r.features == (CHType.FEATURE | RH.CLASS_ONE),
            "feature bits describe actual class1 zero-recovery source"
        );
        CHPrincipals.collectValidated(_certificate(x), r.principals);
    }

    function testCompletePrincipalsCannotAuthorizeSuppliedIdentityOrSupplementBytes() external {
        IdentityObserved memory x = _observeIdentities(_history(true));
        CHAdmissionType.Certificate memory c = _certificate(x);
        CHPrincipals.Result memory r = CHPrincipals.collect(c);
        bytes memory saved = r.principals.identities[0];
        r.principals.identities[0] = this.tamper(saved, 0, false);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHPrincipals.collectValidated(c, r.principals);
        r.principals.identities[0] = saved;
        r.principals.authoritySupplement[0] = abi.encode("not fixed-source authority");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHPrincipals.collectValidated(c, r.principals);
        delete r.principals.authoritySupplement[0];
        bytes memory payout = r.principals.payouts[0];
        r.principals.payouts[0] = abi.encode("substituted payout");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHPrincipals.collectValidated(c, r.principals);
        r.principals.payouts[0] = payout;
        CHPrincipals.collectValidated(c, r.principals);
    }
}
