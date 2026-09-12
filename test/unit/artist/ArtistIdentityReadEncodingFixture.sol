// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/domains/artist/StreamArtistIdentityResolutionReads.sol";

/// @dev Serialization-only boundary: deliberately writable test state, no authority claim.
abstract contract ArtistIdentityReadEncodingState {
    StreamArtistIdentityState.State internal identities;
    StreamArtistRotationState.State internal rotations;
    StreamArtistDelegationState.State internal delegations;

    function install(
        bytes32 id,
        T.Identity calldata identity_,
        R.GuardianRecord calldata guardian_,
        R.RotationRecord calldata rotation_
    ) external {
        identities.identities[id] = identity_;
        rotations.guardians[id] = guardian_;
        rotations.rotations[id] = rotation_;
        D.Record memory delegation_;
        delegation_.grant.artistId = id;
        delegation_.grantor = identity_.authorityAddress;
        delegation_.nonce = identity_.nonceHint;
        delegation_.uses = 11;
        delegation_.revoked = true;
        delegation_.revocationRecordHash = keccak256("test revocation");
        delegations.records[id] = delegation_;
    }
}

/// @dev Exact four pre-extraction storage-return bodies retained as an independent oracle.
contract ArtistIdentityInlineReadOracle is ArtistIdentityReadEncodingState {
    function identity(bytes32 id) external view returns (T.Identity memory) {
        return identities.identities[id];
    }

    function guardianSetRecord(bytes32 id) external view returns (R.GuardianRecord memory) {
        return rotations.guardians[id];
    }

    function rotationRecord(bytes32 id) external view returns (R.RotationRecord memory) {
        return rotations.rotations[id];
    }

    function delegationRecord(bytes32 id) external view returns (D.Record memory) {
        return delegations.records[id];
    }
}

contract ArtistIdentityEncodedReadOracle is ArtistIdentityReadEncodingState {
    function identity(bytes32 id) external view returns (T.Identity memory) {
        _result(StreamArtistIdentityResolutionReads.identity(identities, id));
    }

    function guardianSetRecord(bytes32 id) external view returns (R.GuardianRecord memory) {
        _result(StreamArtistIdentityResolutionReads.guardian(rotations, id));
    }

    function rotationRecord(bytes32 id) external view returns (R.RotationRecord memory) {
        _result(StreamArtistIdentityResolutionReads.rotation(rotations, id));
    }

    function delegationRecord(bytes32 id) external view returns (D.Record memory) {
        _result(StreamArtistIdentityResolutionReads.delegation(delegations, id));
    }

    function _result(bytes memory encoded) private pure {
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }
}
