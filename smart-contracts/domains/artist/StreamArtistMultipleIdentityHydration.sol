// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityHydration.sol";
import "./StreamArtistMultipleHydrationCodec.sol";
import "./StreamArtistHistoryState.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";

/// @notice Fixed typed multiplicity import; the original identity domain and per-identity nonce trees remain distinct.
library StreamArtistMultipleIdentityHydration {
    function exportEncoded(
        StreamArtistIdentityState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dorm,
        StreamArtistUnavailabilityState.State storage finding,
        bytes calldata encoded
    ) public view returns (bytes memory) {
        return exportState(s, estate, dorm, finding, abi.decode(encoded, (AH.Query)));
    }

    function exportState(
        StreamArtistIdentityState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dorm,
        StreamArtistUnavailabilityState.State storage finding,
        AH.Query memory q
    ) public view returns (bytes memory) {
        AH.Identity memory p;
        p.item = s.identities[q.artistId];
        if (
            p.item.authorityClass != 1 || p.item.status != 1
                || s.activeIdentity[p.item.authorityAddress] != q.artistId
        ) revert T.UnsupportedProfile();
        p.document = s.documents[p.item.identityRecordHash];
        p.nextRegistrationNonce = s.nextRegistrationNonce;
        if (p.document.length == 0 || keccak256(p.document) != p.item.identityRecordHash) {
            revert T.InvalidRecord();
        }
        p.estateActivity = estate.livingActivity[q.artistId];
        p.dormancyActivity = dorm.activity[q.artistId];
        p.findingActivity = finding.activityEpoch[q.artistId];
        p.signatures = new bytes[](q.records.length);
        for (uint256 j; j < q.records.length; ++j) {
            p.signatures[j] = s.signatures[q.records[j]];
        }
        return abi.encode(p);
    }

    function importEncoded(
        StreamArtistIdentityState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dorm,
        StreamArtistUnavailabilityState.State storage finding,
        bytes calldata encoded
    ) public {
        (, AH.Query memory anchor, AH.OwnerData memory outer, bytes32 value) =
            abi.decode(encoded, (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        MH.Bundle memory b = StreamArtistMultipleHydrationCodec.decode(outer.typedState);
        if (
            s.nextRegistrationNonce != 0 || outer.nonces.length != 0
                || b.rows.length != b.artistIds.length || b.registrationCount != b.artistIds.length
                || b.collectionIds.length == 0 || anchor.collectionId != b.collectionIds[0]
        ) revert T.InvalidRecord();
        for (uint256 i; i < b.rows.length; ++i) {
            MH.Row memory row = b.rows[i];
            AH.Identity memory p = abi.decode(row.state, (AH.Identity));
            if (
                row.query.artistId != b.artistIds[i] || row.query.artistId == 0
                    || (i != 0 && b.artistIds[i] <= b.artistIds[i - 1])
                    || s.identities[row.query.artistId].authorityAddress != address(0)
                    || s.activeIdentity[p.item.authorityAddress] != 0
                    || p.item.authorityAddress == address(0) || p.item.authorityClass != 1
                    || p.item.status != 1 || p.nextRegistrationNonce != b.registrationCount
                    || row.nonces.length == 0 || p.signatures.length != row.query.records.length
                    || p.document.length == 0 || keccak256(p.document) != p.item.identityRecordHash
            ) {
                revert T.InvalidRecord();
            }
            _import(s, estate, dorm, finding, row.query, p, row.nonces);
        }
        s.nextRegistrationNonce = b.registrationCount;
        StreamArtistHistoryState.activateMultiple(b.artistIds, b.collectionIds, value);
    }

    function _import(
        StreamArtistIdentityState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dorm,
        StreamArtistUnavailabilityState.State storage finding,
        AH.Query memory q,
        AH.Identity memory p,
        AH.NonceWord[] memory nonces
    ) private {
        AH.OwnerData memory data;
        data.nonces = nonces;
        s.identities[q.artistId] = p.item;
        s.activeIdentity[p.item.authorityAddress] = q.artistId;
        s.documents[p.item.identityRecordHash] = p.document;
        StreamArtistPayloadStore.store(keccak256("ARTIST_IDENTITY_DOCUMENT"), p.document);
        for (uint256 j; j < q.records.length; ++j) {
            s.signatures[q.records[j]] = p.signatures[j];
            StreamArtistPayloadStore.store(keccak256("ARTIST_SIGNATURE_BUNDLE"), p.signatures[j]);
        }
        estate.livingActivity[q.artistId] = p.estateActivity;
        dorm.activity[q.artistId] = p.dormancyActivity;
        finding.activityEpoch[q.artistId] = p.findingActivity;
        for (uint256 j; j < data.nonces.length; ++j) {
            AH.NonceWord memory n = data.nonces[j];
            uint256 prefix = n.prefix;
            for (uint8 level; level < 32; ++level) {
                uint256 old = s.nonceAvailability[q.artistId].full[level][prefix];
                if (old != 0 && old != n.words[level]) revert T.InvalidRecord();
                s.nonceAvailability[q.artistId].full[level][prefix] = n.words[level];
                prefix >>= 8;
            }
            s.nonceAvailability[q.artistId].exhausted = n.exhausted;
            StreamArtistAuthorityCheckpoint.noteNonce(
                1, q.artistId, n.prefix, keccak256(abi.encode(n))
            );
        }
        (bool available, uint256 hint) =
            StreamArtistNonceAvailability.firstUnused(s.nonceAvailability[q.artistId]);
        if (!available || hint != p.item.nonceHint) revert T.InvalidRecord();
    }
}
