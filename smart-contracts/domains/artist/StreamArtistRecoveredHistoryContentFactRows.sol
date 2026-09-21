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

import {
    StreamArtistRecoveredHistoryContentTypes as HC
} from "./StreamArtistRecoveredHistoryContentTypes.sol";

/// @notice Original content and ratification signature/grant facts across authenticated generations.
library StreamArtistRecoveredHistoryContentFactRows {
    struct IdentityRows {
        bytes32 artistId;
        IH.SignatureRow[] signatures;
        IH.DelegationRow[] delegations;
    }

    function validate(IdentityRows memory identity, HC.Bundle memory b, RH.Provenance memory p)
        public
        pure
        returns (uint256[] memory uses)
    {
        if (identity.artistId != b.base.original.artistId) _invalid();
        uses = new uint256[](identity.delegations.length);
        uint256 contents;
        uint256 royalties;
        uint256 freezes;
        uint256 ratifications;
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry memory n = p.journals[6][i];
            uint16 op = n.receipt.operation;
            if (op == 12 || op == 14 || op == 15 || op == 16) continue;
            if (op != 17 && op != 20 && op != 21 && op != 52) _invalid();
            if (
                n.receipt.artistId != identity.artistId
                    || n.receipt.collectionId != b.base.original.collectionId
                    || n.receipt.recordHash == 0 || n.position.point.ownerIndex != 6
            ) _invalid();
            Chronology.validatePoint(p, n.position.point);
            _signature(identity, n.receipt.recordHash);
            if (op == 17) {
                if (
                    contents == b.consents.length
                        || b.consents[contents++].recordHash != n.receipt.recordHash
                ) _invalid();
            } else if (op == 21) {
                if (
                    freezes == b.freezes.length
                        || b.freezes[freezes++].recordHash != n.receipt.recordHash
                ) _invalid();
            } else if (op == 52) {
                // Original52 stores no generation or signer/nonce/time preimage. Retain its
                // exact source signature (including empty direct evidence), not invented facts.
                if (
                    ratifications == b.ratifications.length
                        || b.ratifications[ratifications++].recordHash != n.receipt.recordHash
                ) _invalid();
            } else {
                if (royalties == b.royalties.length) _invalid();
                ContentH.Royalty memory r = b.royalties[royalties++];
                if (r.item.recordHash != n.receipt.recordHash) _invalid();
                if (r.grant != 0) {
                    ++uses[
                        _grant(identity, p, b.base.original.collectionId, r.grant, n.position.point)
                    ];
                }
            }
        }
        if (
            contents != b.consents.length || royalties != b.royalties.length
                || freezes != b.freezes.length || ratifications != b.ratifications.length
        ) _invalid();
    }

    function _signature(IdentityRows memory identity, bytes32 record) private pure {
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
        IdentityRows memory identity,
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
