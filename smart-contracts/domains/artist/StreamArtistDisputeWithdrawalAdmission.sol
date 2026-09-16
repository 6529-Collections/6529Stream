// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeAdmission.sol";

/// @notice The immutable opener must still possess its original live authority lane.
library StreamArtistDisputeWithdrawalAdmission {
    function admit(T.SuiteConfiguration memory s, AD.Filing memory p, AD.Standing memory standing)
        public
        view
        returns (AD.Admission memory a, AD.Head memory h)
    {
        StreamArtistDisputeHashes.validateWithdrawal(p);
        uint8 state;
        (a.binding_, state, h) =
            StreamArtistDisputeAdmission.binding(s, p.collectionId, p.bindingGeneration);
        AD.Record memory opening = IStreamArtistAttributionDisputesOwner(s.owners[4])
            .attributionDisputeRecord(h.disputeRecordHash);
        if (
            state != 4 || !h.open || h.reopened || !a.binding_.accepted || opening.recordHash == 0
                || opening.recordHash != h.disputeRecordHash || opening.terms.disputeAction != 1
                || opening.governanceActionId != 0 || opening.bindingHash != a.binding_.bindingHash
                || opening.authorityClass == 0
                || keccak256(abi.encode(opening.standing)) != keccak256(abi.encode(standing))
                || block.timestamp > type(uint64).max
        ) revert AD.InvalidAttributionDispute(p.collectionId);
        R.AuthorityFact memory current =
            StreamArtistCurrentAuthorityFacts.read(s.owners[2], standing.artistId, true);
        a.signer = current.authorityAddress;
        a.authorityClass = current.authorityClass;
        if (standing.delegation != 0) {
            if (
                standing.artistId != a.binding_.artistId
                    || standing.bindingGeneration != a.binding_.generation
            ) {
                revert AD.DisputeStandingUnavailable(standing.artistId);
            }
            D.Record memory grant =
                IStreamArtistDelegationOwner(s.owners[2]).delegationRecord(standing.delegation);
            a.signer = grant.grant.delegate;
            a.authorityClass = 2;
        }
        if (a.signer != opening.signer || a.authorityClass != opening.authorityClass) {
            revert AD.DisputeStandingUnavailable(standing.artistId);
        }
        a.standing = standing;
        a.recordedAt = uint64(block.timestamp);
    }
}
