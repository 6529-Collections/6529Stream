// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Original17/20/21 Identity evidence and delegated20 use reconciliation.
/// @dev The caller authenticates the complete source certificate, Identity bundle and owner6
/// codec first. These original maps omit signer/nonce/deadline preimages; their exact fixed-source
/// associations, native occurrences and replay cells authenticate the retained hashes. We do not
/// manufacture an Identity admission point, rehash absent fields, or reauthorize old grants.
/// Operation21 is a content-freeze authorization. Intent remains op24 subject7.
library StreamArtistRecoveredContentConsentFacts {
    function validate(
        IH.Bundle memory identity,
        ContentH.Bundle memory consent,
        AH.Query memory q,
        RH.Provenance memory p
    ) public pure returns (uint256[] memory uses) {
        if (
            q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0
                || identity.artistId != q.artistId || consent.original.artistId != q.artistId
                || consent.original.collectionId != q.collectionId
                || consent.original.bindingHash != q.bindingHash
        ) _invalid();
        uses = new uint256[](identity.delegations.length);
        uint256 contents;
        uint256 royalties;
        uint256 freezes;
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry memory native_ = p.journals[6][i];
            uint16 op = native_.receipt.operation;
            if (op == 14 || op == 15 || op == 16) continue;
            if (op != 17 && op != 20 && op != 21) _invalid();
            if (
                native_.receipt.artistId != q.artistId
                    || native_.receipt.collectionId != q.collectionId
                    || native_.receipt.recordHash == 0 || native_.position.point.ownerIndex != 6
            ) _invalid();
            Chronology.validatePoint(p, native_.position.point);
            for (uint256 j; j < i; ++j) {
                if (p.journals[6][j].receipt.recordHash == native_.receipt.recordHash) _invalid();
            }
            _signature(identity, native_.receipt.recordHash);
            if (op == 17) {
                if (contents == consent.consents.length) _invalid();
                ContentOwner.ConsentRecord memory row = consent.consents[contents++];
                if (
                    row.recordHash != native_.receipt.recordHash || row.artistId != q.artistId
                        || row.bindingGeneration != 1 || row.terms.collectionId != q.collectionId
                        || (row.authorityClass != 1 && row.authorityClass != 3)
                ) _invalid();
            } else if (op == 21) {
                if (freezes == consent.freezes.length) _invalid();
                Content.FreezeRecord memory row = consent.freezes[freezes++];
                if (
                    row.recordHash != native_.receipt.recordHash || row.artistId != q.artistId
                        || row.bindingGeneration != 1
                        || (row.authorityClass != 1 && row.authorityClass != 3)
                ) _invalid();
            } else {
                if (royalties == consent.royalties.length) _invalid();
                ContentH.Royalty memory row = consent.royalties[royalties++];
                if (
                    row.item.recordHash != native_.receipt.recordHash
                        || row.item.artistId != q.artistId || row.item.bindingGeneration != 1
                        || row.terms.collectionId != q.collectionId
                ) _invalid();
                if (row.grant != 0) {
                    ++uses[_grant(identity, p, q.collectionId, row.grant, native_.position.point)];
                }
            }
        }
        if (
            contents != consent.consents.length || royalties != consent.royalties.length
                || freezes != consent.freezes.length
        ) _invalid();
    }

    function _signature(IH.Bundle memory identity, bytes32 record) private pure {
        bool found;
        for (uint256 i; i < identity.signatures.length; ++i) {
            if (identity.signatures[i].recordHash != record) continue;
            if (found || identity.signatures[i].signature.length > 4096) _invalid();
            found = true;
        }
        // Empty bytes are valid direct/Safe evidence. Exact source bytes and all nonce/replay
        // inventories are authenticated separately; there is no new ERC1271 check here.
        if (!found) _invalid();
    }

    function _grant(
        IH.Bundle memory identity,
        RH.Provenance memory p,
        uint256 collectionId,
        bytes32 hash,
        RH.Point memory usePoint
    ) private pure returns (uint256 at) {
        uint256 useEra = _era(p, usePoint.environmentHash);
        for (uint256 i; i < identity.delegations.length; ++i) {
            IH.DelegationRow memory row = identity.delegations[i];
            if (row.recordHash != hash) continue;
            D.Grant memory grant = row.record.grant;
            if (
                grant.artistId != identity.artistId || grant.delegate == address(0)
                    || (grant.collectionId != 0 && grant.collectionId != collectionId)
                    || (grant.capabilities & D.ROYALTY_FREEZE) == 0
                    || row.position.point.ownerIndex != 2
                    || _era(p, row.position.point.environmentHash) > useEra
            ) _invalid();
            Chronology.validatePoint(p, row.position.point);
            if (
                row.record.revoked
                    && _revocationEra(p, identity.artistId, row.record.revocationRecordHash)
                        < useEra
            ) _invalid();
            for (uint256 j = i + 1; j < identity.delegations.length; ++j) {
                IH.DelegationRow memory next = identity.delegations[j];
                if (
                    next.record.grant.delegate == grant.delegate
                        && _era(p, next.position.point.environmentHash) < useEra
                ) _invalid();
            }
            // Within one era, Identity and Consent have independent revision counters. The
            // original writer authenticated order, live epoch, validity and grant consumption.
            // Only an earlier/later era supplies an additional cross-owner ordering fact.
            return i;
        }
        _invalid();
    }

    function _revocationEra(RH.Provenance memory p, bytes32 artist, bytes32 record)
        private
        pure
        returns (uint256 era)
    {
        bool found;
        if (record == 0) _invalid();
        for (uint256 i; i < p.journals[2].length; ++i) {
            RH.JournalEntry memory native_ = p.journals[2][i];
            if (native_.receipt.recordHash != record) continue;
            if (
                found || native_.receipt.operation != 27 || native_.receipt.artistId != artist
                    || native_.receipt.collectionId != 0 || native_.position.point.ownerIndex != 2
            ) _invalid();
            Chronology.validatePoint(p, native_.position.point);
            era = _era(p, native_.position.point.environmentHash);
            found = true;
        }
        if (!found) _invalid();
    }

    function _era(RH.Provenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
