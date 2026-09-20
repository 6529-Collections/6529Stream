// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleRecordsAttestations.sol";
import "./StreamArtistMultipleDelegationCollectionHydration.sol";
import "./StreamArtistMultipleCollectionHydration.sol";
import "./StreamArtistAttestationHydration.sol";
import "./StreamArtistPublicationHydration.sol";

/// @notice Decodes the unchanged owner operation60 payload once after the original guard application.
library StreamArtistAttributionHydrationTransport {
    function importEncoded(
        AS.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) public {
        (, AH.Query memory q, AH.OwnerData memory p,) =
            abi.decode(data[4:], (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        if (StreamArtistDelegationHydrationCodec.tagged(p.typedState, MR.ATTRIBUTION)) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistMultipleRecordsAttestations.importState(s, e, p.typedState);
            return;
        }
        if (StreamArtistDelegationHydrationCodec.tagged(p.typedState, MD.ATTRIBUTION)) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistMultipleDelegationCollectionHydration.attributions(s, p.typedState);
            return;
        }
        if (StreamArtistMultipleHydrationCodec.isState(p.typedState)) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistMultipleCollectionHydration.attributions(s, p.typedState);
            return;
        }
        bytes memory raw = p.typedState;
        bytes32 schema;
        if (raw.length >= 32) assembly ("memory-safe") { schema := mload(add(raw, 32)) }
        if (raw.length >= 32 && schema == StreamArtistPublicationHydration.SCHEMA) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistPublicationHydration.importState(s, e, q, raw);
            return;
        }
        if (raw.length >= 32 && schema == StreamArtistAttestationHydration.SCHEMA) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistAttestationHydration.importState(s, e, q, raw);
            return;
        }
        if (s.attributions[q.collectionId].generation != 0 || p.nonces.length != 0) {
            revert T.InvalidRecord();
        }
        s.attributions[q.collectionId] = abi.decode(raw, (AS.Attribution));
    }
}
