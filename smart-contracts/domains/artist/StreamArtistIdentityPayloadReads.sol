// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityData.sol";

/// @notice Fixed encoded reads; all original typed facade returns remain unchanged.
library StreamArtistIdentityPayloadReads {
    function identityRevisionRecord(
        StreamArtistIdentityRevisionState.State storage _identityRevisions,
        bytes32 record
    ) public view returns (bytes memory) {
        return abi.encode(_identityRevisions.records[record]);
    }

    function artistAuthorizationState(
        StreamArtistIdentityState.State storage _identity,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        bytes32 digest,
        uint256 nonce
    ) public view returns (bytes memory) {
        return abi.encode(
            StreamArtistAuthorizationState.authorizationState(
                _identity, _replay, o, artistId, digest, nonce
            )
        );
    }

    function identityRevisionProvisionalAssociation(
        StreamArtistIdentityRevisionState.State storage _identityRevisions,
        bytes32 record
    ) public view returns (bytes memory) {
        return abi.encode(_identityRevisions.associations[record]);
    }

    function stewardSanctionGrantRecord(
        StreamArtistStewardSanctionState.State storage _stewardGrants,
        bytes32 hash
    ) public view returns (bytes memory) {
        return abi.encode(_stewardGrants.records[hash]);
    }

    function identityDocumentBytes(
        StreamArtistIdentityState.State storage _identity,
        bytes32 documentHash
    ) public view returns (bytes memory) {
        return abi.encode(_identity.documents[documentHash]);
    }

    function signatureBundle(StreamArtistIdentityState.State storage _identity, bytes32 recordHash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(_identity.signatures[recordHash]);
    }

    function estateDirectivePayload(
        StreamArtistSuccessionState.State storage _succession,
        bytes32 record
    ) public view returns (bytes memory) {
        return abi.encode(_succession.payloads[record]);
    }

    function operativeIdentityMetadata(
        StreamArtistIdentityRevisionState.State storage _identityRevisions,
        StreamArtistIdentityState.State storage _identity,
        StreamArtistRotationState.State storage _rotations,
        bytes32 artistId
    ) public view returns (bytes memory) {
        (bytes32 hash, string memory uri, string memory display) = StreamArtistIdentityRevisionState.metadata(
            _identityRevisions, _identity, _rotations, artistId
        );

        return abi.encode(hash, uri, display);
    }

    function artistDisplayName(
        StreamArtistIdentityRevisionState.State storage _identityRevisions,
        StreamArtistIdentityState.State storage _identity,
        StreamArtistRotationState.State storage _rotations,
        bytes32 artistId
    ) public view returns (bytes memory) {
        string memory name;
        bytes32 hash;
        (hash,, name) = StreamArtistIdentityRevisionState.metadata(
            _identityRevisions, _identity, _rotations, artistId
        );

        return abi.encode(name, hash);
    }
}
