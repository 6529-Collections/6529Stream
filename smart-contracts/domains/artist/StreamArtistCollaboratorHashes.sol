// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";

/// @notice Exact permanent collaborator preimages and explicit non-record lookup commitments.
library StreamArtistCollaboratorHashes {
    /// @dev All fields are static: encoding this tuple is exactly the original sixteen words.
    ///      The collaborator policy mode and threshold intentionally retain their zero values.
    struct BindingPreimage {
        bytes32 domain;
        uint256 chainId;
        address registry;
        address core;
        uint256 collectionId;
        uint64 generation;
        bytes32 artistId;
        address artistAddress;
        bytes32 identityRecordHash;
        uint8 consentMode;
        uint8 saleConsentScope;
        uint8 registryImmutabilityElection;
        uint8 collabPolicyMode;
        uint32 collabThreshold;
        bytes32 collaboratorSetHash;
        bytes32 capabilityPolicySetHash;
    }

    function identityDigest(
        StreamArtistHashes.Environment memory e,
        address account,
        bytes32 document,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamCollaboratorIdentityAcceptance(address account,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)"
                    ),
                    account,
                    document,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function acceptanceDigest(
        StreamArtistHashes.Environment memory e,
        C.BindingAcceptance memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamCollaboratorAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,address collaborator,bytes32 role,bytes32 shareLabelId,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    p.collectionId,
                    p.generation,
                    p.bindingHash,
                    p.account,
                    p.role,
                    p.shareLabelId,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function acceptanceRecord(
        StreamArtistHashes.Environment memory e,
        C.BindingAcceptance memory p,
        uint256 nonce,
        uint64 observed
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"),
                e.chainId,
                e.registry,
                e.core,
                p.collectionId,
                p.generation,
                p.bindingHash,
                uint8(2),
                p.account,
                uint8(1),
                nonce,
                observed
            )
        );
    }

    function acceptanceRecordForAuthority(
        StreamArtistHashes.Environment memory e,
        C.BindingAcceptance memory p,
        uint8 authorityClass,
        uint256 nonce,
        uint64 observed
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"),
                e.chainId,
                e.registry,
                e.core,
                p.collectionId,
                p.generation,
                p.bindingHash,
                uint8(2),
                p.account,
                authorityClass,
                nonce,
                observed
            )
        );
    }

    function proposalHash(
        StreamArtistHashes.Environment memory e,
        C.IdentityProposal memory p,
        address proposer
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_COLLABORATOR_IDENTITY_PROPOSAL_V1"),
                e.chainId,
                e.registry,
                p,
                proposer
            )
        );
    }

    function rowKey(bytes32 bindingHash, address account, bytes32 role, bytes32 shareLabelId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(bindingHash, account, role, shareLabelId));
    }

    function binding(
        StreamArtistHashes.Environment memory e,
        uint256 collectionId,
        T.Binding memory b,
        T.CollaboratorRecord[] memory rows
    ) public pure returns (bytes32) {
        BindingPreimage memory p;
        p.domain = keccak256("6529STREAM_ARTIST_BINDING_V1");
        p.chainId = e.chainId;
        p.registry = e.registry;
        p.core = e.core;
        p.collectionId = collectionId;
        p.generation = b.generation;
        p.artistId = b.artistId;
        p.artistAddress = b.artistAddress;
        p.identityRecordHash = b.identityRecordHash;
        p.consentMode = b.consentMode;
        p.saleConsentScope = b.saleConsentScope;
        p.registryImmutabilityElection = b.registryImmutabilityElection;
        p.collaboratorSetHash = collaboratorSetHash(rows);
        p.capabilityPolicySetHash = StreamArtistHashes.emptyCapabilities();
        return keccak256(abi.encode(p));
    }

    function collaboratorSetHash(T.CollaboratorRecord[] memory rows) public pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), rows));
    }
}
