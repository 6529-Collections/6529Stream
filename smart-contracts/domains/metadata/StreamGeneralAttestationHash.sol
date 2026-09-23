// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamGeneralAttestations as A
} from "../../interfaces/stream/metadata/IStreamGeneralAttestations.sol";

/// @notice New general-claim domain; no Artist/independent signature reuse.
library StreamGeneralAttestationHash {
    bytes32 internal constant TYPEHASH = keccak256(
        "StreamGeneralAttestation(address attester,uint256 collectionId,bytes32 subjectId,bytes32 attestationType,string attesterDID,bytes32 schemaId,bytes32 canonicalizationId,string statementURI,bytes payload,bytes32 supersedes,bytes32 artistAuthorizationRecordHash,uint64 effectiveAt,uint256 nonce,uint64 deadline)"
    );

    function domain() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamGeneralAttestations"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function words(A.Request calldata r) internal pure returns (bytes32[15] memory w) {
        w[0] = TYPEHASH;
        w[1] = bytes32(uint256(uint160(r.attester)));
        w[2] = bytes32(r.collectionId);
        w[3] = r.subjectId;
        w[4] = r.attestationType;
        w[5] = keccak256(bytes(r.attesterDID));
        w[6] = r.schemaId;
        w[7] = r.canonicalizationId;
        w[8] = keccak256(bytes(r.statementURI));
        w[9] = keccak256(r.payload);
        w[10] = r.supersedes;
        w[11] = r.artistAuthorizationRecordHash;
        w[12] = bytes32(uint256(r.effectiveAt));
        w[13] = bytes32(r.nonce);
        w[14] = bytes32(uint256(r.deadline));
    }

    function digest(A.Request calldata r) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", domain(), keccak256(abi.encode(words(r)))));
    }

    function recordHash(A.Attestation memory a, A.Receipt memory r)
        internal
        view
        returns (bytes32)
    {
        // Chain position is derived after hashing and deliberately excluded.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GENERAL_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(this),
                a,
                r
            )
        );
    }
}
