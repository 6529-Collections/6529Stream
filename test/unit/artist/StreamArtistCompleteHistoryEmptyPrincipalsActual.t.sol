// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistUnboundPlatformFixture.sol";
import {
    StreamArtistCompleteHistoryPreparationPrincipals as CHPrincipals
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPreparationPrincipals.sol";
import {
    StreamArtistCompleteHistoryAdmission as CHAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAdmission.sol";
import {
    StreamArtistCompleteHistoryTypes as CHType
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationAdmission as CHAdmissionType
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistUnboundPlatformTypes as CHUnbound
} from "../../../smart-contracts/domains/artist/StreamArtistUnboundPlatformTypes.sol";

/// @notice Original allegation10 alone creates the collection lane in a real zero-Artist source.
/// @dev No declaration8 or fabricated registration is needed. Inherited governance/Core boundaries remain.
contract StreamArtistCompleteHistoryEmptyPrincipalsActualTest is ArtistUnboundPlatformFixture {
    function testCompleteEmptyPrincipalsFromOriginalAllegationWithoutDeclaration() external {
        CHAdmissionType.Certificate memory c = _emptySource();
        CHPrincipals.Result memory r = CHPrincipals.collect(c);
        require(
            c.artists.length == 0 && c.provenance.journals[2].length == 0,
            "no original registration or Identity native receipt"
        );
        require(
            c.provenance.journals[4].length == 1
                && c.provenance.journals[4][0].receipt.operation == 10,
            "only original allegation10, no declaration8"
        );
        require(
            r.principals.identities.length == 0 && r.principals.payouts.length == 0
                && r.principals.authoritySupplement.length == 0 && r.emptyIdentity.length != 0,
            "separate canonical empty certificate preserves zero principal rows"
        );
        require(
            r.externalGuards.schema == CHUnbound.TAG && r.externalGuards.artistId == 0
                && r.externalGuards.actions.length == 0 && r.externalGuards.finality.length == 0
                && r.externalGuards.entropy.length == 0
                && r.externalGuards.provenanceCommitment == RH.provenanceHash(c.provenance),
            "original explicit empty external observation"
        );
        require(r.features == CHType.FEATURE, "no fabricated class, recovery or binding feature");
        CHPrincipals.collectValidated(c, r.principals);
    }

    function testCompleteEmptyPrincipalsRejectsSyntheticZeroArtistRow() external {
        CHAdmissionType.Certificate memory c = _emptySource();
        CHPrincipals.Result memory r = CHPrincipals.collect(c);
        r.principals.identities = new bytes[](1);
        r.principals.identities[0] = r.emptyIdentity;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHPrincipals.collectValidated(c, r.principals);
    }

    function _emptySource() private returns (CHAdmissionType.Certificate memory c) {
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce() == 0,
            "fixture creates actual suite without initial binding"
        );
        bytes32 claim = _hpClaim(true);
        require(
            claim != 0 && ingress.platformWorksState(upCollection).declaration.recordHash == 0,
            "real allegation without declaration"
        );
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        Successor memory next = _upCutover();
        c = CHAdmission.collect(next.coordinator.suiteConfiguration(), _upRequest());
    }
}
