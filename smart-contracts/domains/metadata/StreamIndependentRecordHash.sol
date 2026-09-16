// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCollectionAttestations as A
} from "../../interfaces/stream/metadata/IStreamCollectionAttestations.sol";

/// @notice Permanent independent-lane EIP-712 preimages; no record authority or storage.
library StreamIndependentRecordHash {
    bytes32 internal constant RECORD_TYPEHASH =
        0xcb13914f7a4c90b3e2d3d1513c3009284117ccab71b2a60935a620486947c768;
    bytes32 internal constant REVOCATION_TYPEHASH =
        0x4522059fc24afcc4dadcbf6fc6e0c577c17c5faf11aa8d03b270af3369d3359c;
    bytes32 internal constant NAME = keccak256("6529StreamCollectionAttestations");

    function domain() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                NAME,
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function words(A.IndependentRecord calldata r) internal pure returns (bytes32[14] memory w) {
        w[0] = RECORD_TYPEHASH;
        w[1] = bytes32(uint256(uint160(r.attestor)));
        w[2] = bytes32(r.scopeKey);
        w[3] = r.subjectId;
        w[4] = r.recordType;
        w[5] = r.schemaId;
        w[6] = bytes32(uint256(r.algorithmId));
        w[7] = keccak256(r.digest);
        w[8] = r.canonicalizationId;
        w[9] = keccak256(bytes(r.uri));
        w[10] = keccak256(r.payload);
        w[11] = bytes32(uint256(r.effectiveAt));
        w[12] = bytes32(r.nonce);
        w[13] = bytes32(uint256(r.deadline));
    }

    function record(A.IndependentRecord calldata r) internal view returns (bytes32) {
        return digest(keccak256(abi.encode(words(r))));
    }

    function revocation(address attestor, uint256 nonce, uint64 deadline)
        internal
        view
        returns (bytes32)
    {
        return digest(keccak256(abi.encode(REVOCATION_TYPEHASH, attestor, nonce, deadline)));
    }

    function digest(bytes32 body) private view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", domain(), body));
    }
}
