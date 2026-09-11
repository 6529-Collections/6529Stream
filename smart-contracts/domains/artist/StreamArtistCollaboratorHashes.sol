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
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_V1"),
                e.chainId,
                e.registry,
                e.core,
                collectionId,
                b.generation,
                b.artistId,
                b.artistAddress,
                b.identityRecordHash,
                b.consentMode,
                b.saleConsentScope,
                b.registryImmutabilityElection,
                uint8(0),
                uint32(0),
                collaboratorSetHash(rows),
                StreamArtistHashes.emptyCapabilities()
            )
        );
    }

    function collaboratorSetHash(T.CollaboratorRecord[] memory rows) public pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), rows));
    }
}
