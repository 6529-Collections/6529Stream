// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAttributionAttestations.sol";

/// @notice Fixed transport for the original Attribution record recipes.
/// @dev The owner checks the original context and retains its commit/native receipt sequence.
library StreamArtistAttestationTransport {
    function recordAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata encoded
    ) public returns (AttrState.Mutation memory) {
        (
            ,
            T.Binding memory b,
            T.Attestation memory p,
            address signer,
            uint256 nonce,
            uint64 signedAt,
            bytes memory statement
        ) = abi.decode(
            encoded[4:],
            (T.ActionContext, T.Binding, T.Attestation, address, uint256, uint64, bytes)
        );
        return StreamArtistAttributionAttestations.recordAttestation(
            s, e, b, p, signer, nonce, signedAt, statement
        );
    }

    function recordIdentityAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata encoded
    ) public returns (AttrState.Mutation memory) {
        (
            ,
            T.Binding memory b,
            T.Attestation memory p,
            bytes32 operativeIdentityHash,
            address signer,
            uint256 nonce,
            uint64 signedAt,
            bytes memory statement
        ) = abi.decode(
            encoded[4:],
            (T.ActionContext, T.Binding, T.Attestation, bytes32, address, uint256, uint64, bytes)
        );
        return StreamArtistAttributionAttestations.recordIdentityAttestation(
            s, e, b, p, operativeIdentityHash, signer, nonce, signedAt, statement
        );
    }

    function recordAuthenticatedAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata encoded
    ) public returns (AttrState.Mutation memory) {
        (
            ,
            T.Binding memory b,
            T.Attestation memory p,
            Attest.Admission memory a,
            bytes memory statement
        ) = abi.decode(
            encoded[4:], (T.ActionContext, T.Binding, T.Attestation, Attest.Admission, bytes)
        );
        return StreamArtistAttributionAttestations.recordAuthenticatedAttestation(
            s, e, b, p, a, statement
        );
    }

    function recordAttestationWithAuthority(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata encoded
    ) public returns (AttrState.Mutation memory) {
        (
            ,
            T.Binding memory b,
            T.Attestation memory p,
            bytes32 operativeIdentityHash,
            R.AuthorityFact memory authority,
            address signer,
            uint256 nonce,
            uint64 signedAt,
            bytes memory statement
        ) = abi.decode(
            encoded[4:],
            (
                T.ActionContext,
                T.Binding,
                T.Attestation,
                bytes32,
                R.AuthorityFact,
                address,
                uint256,
                uint64,
                bytes
            )
        );
        return StreamArtistAttributionAttestations.recordAttestationWithAuthority(
            s, e, b, p, operativeIdentityHash, authority, signer, nonce, signedAt, statement
        );
    }

    function recordPublicationAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata encoded
    ) public returns (AttrState.Mutation memory) {
        (
            ,
            T.Binding memory b,
            T.Attestation memory p,
            R.AuthorityFact memory authority,
            uint256 nonce,
            uint64 signedAt,
            bytes memory statement,
            bytes32 metadataHostCodeHash
        ) = abi.decode(
            encoded[4:],
            (
                T.ActionContext,
                T.Binding,
                T.Attestation,
                R.AuthorityFact,
                uint256,
                uint64,
                bytes,
                bytes32
            )
        );
        return StreamArtistAttributionAttestations.recordPublicationAttestation(
            s, e, b, p, authority, nonce, signedAt, statement, metadataHostCodeHash
        );
    }

    function confirmSanctionFinalized(AttrState.State storage s, bytes calldata encoded)
        public
        returns (AttrState.Mutation memory)
    {
        (
            T.ActionContext memory c,
            T.Binding memory b,
            Confirmation.Transition memory p,
            address savedSigner,
            uint8 savedAuthorityClass
        ) = abi.decode(
            encoded[4:], (T.ActionContext, T.Binding, Confirmation.Transition, address, uint8)
        );
        return StreamArtistAttributionAttestations.confirmSanctionFinalized(
            s, c, b, p, savedSigner, savedAuthorityClass
        );
    }
}
