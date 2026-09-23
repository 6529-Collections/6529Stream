// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityState.sol";
import "./StreamArtistEstateState.sol";
import "./StreamArtistDormancyState.sol";
import "./StreamArtistUnavailabilityState.sol";
import "./StreamArtistEntropyFindingHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Typed baseline export/import; advanced state never defaults to a living principal.
library StreamArtistIdentityHydration {
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
            p.item.authorityClass != 1 || p.item.status != 1 || s.nextRegistrationNonce != 1
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

    function importState(
        StreamArtistIdentityState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dorm,
        StreamArtistUnavailabilityState.State storage finding,
        AH.Query memory q,
        AH.OwnerData memory data
    ) public {
        AH.Identity memory p = abi.decode(data.typedState, (AH.Identity));
        if (
            s.nextRegistrationNonce != 0 || s.identities[q.artistId].authorityAddress != address(0)
                || s.activeIdentity[p.item.authorityAddress] != 0 || p.item.authorityClass != 1
                || p.item.status != 1 || p.nextRegistrationNonce != 1
                || p.signatures.length != q.records.length
                || keccak256(p.document) != p.item.identityRecordHash
        ) revert T.InvalidRecord();
        s.identities[q.artistId] = p.item;
        s.activeIdentity[p.item.authorityAddress] = q.artistId;
        s.nextRegistrationNonce = p.nextRegistrationNonce;
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

    /// @dev Decode original owner calldata in the fixed worker, avoiding owner-side nested re-encoding.
    function exportEncoded(
        StreamArtistIdentityState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dorm,
        StreamArtistUnavailabilityState.State storage finding,
        bytes calldata encoded
    ) public view returns (bytes memory) {
        AH.Query memory q = abi.decode(encoded, (AH.Query));
        return exportState(s, estate, dorm, finding, q);
    }

    function exportFindingEncoded(
        StreamArtistIdentityState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dorm,
        StreamArtistUnavailabilityState.State storage finding,
        bytes calldata encoded
    ) public view returns (bytes memory) {
        AH.Query memory q = abi.decode(encoded, (AH.Query));
        return StreamArtistEntropyFindingHydration.exportState(
            finding, q, exportState(s, estate, dorm, finding, q)
        );
    }

    function importEncoded(
        StreamArtistIdentityState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dorm,
        StreamArtistUnavailabilityState.State storage finding,
        bytes calldata encoded
    ) public {
        (, AH.Query memory q, AH.OwnerData memory data,) =
            abi.decode(encoded, (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        if (StreamArtistEntropyFindingHydration.isState(data.typedState)) {
            FH.Bundle memory b = StreamArtistEntropyFindingHydration.decode(data.typedState);
            data.typedState = b.identityState;
            importState(s, estate, dorm, finding, q, data);
            StreamArtistEntropyFindingHydration.importState(finding, q, b);
        } else {
            importState(s, estate, dorm, finding, q, data);
        }
    }
}
