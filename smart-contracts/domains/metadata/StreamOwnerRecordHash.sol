// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamOwnerRecords as O } from "../../interfaces/stream/metadata/IStreamOwnerRecords.sol";

/// @notice Exact CMC-OWNER-RECORDS EIP-712 commitments; execution authority is checked by the host.
library StreamOwnerRecordHash {
    bytes32 internal constant RECORD_TYPEHASH =
        0x9c8c4f8b7ec1e8731277f53e36271ebf92fc96425f0c082143042400814c6b05;
    bytes32 internal constant REVOCATION_TYPEHASH =
        0x11a07172744cbac614966ef944b190ff3c1b4a7076ab4483c69e48ba2b9ee49c;

    function domain() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamOwnerRecords"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function words(
        uint256 tokenId,
        O.OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline
    ) internal pure returns (bytes32[14] memory w) {
        w[0] = RECORD_TYPEHASH;
        w[1] = bytes32(uint256(uint160(owner)));
        w[2] = bytes32(tokenId);
        w[3] = r.subjectId;
        w[4] = r.recordType;
        w[5] = r.schemaId;
        w[6] = bytes32(uint256(r.contentHash.algorithm));
        w[7] = keccak256(r.contentHash.digest);
        w[8] = r.contentHash.canonicalizationId;
        w[9] = keccak256(bytes(r.uri));
        w[10] = keccak256(r.payload);
        w[11] = bytes32(uint256(r.effectiveAt));
        w[12] = bytes32(nonce);
        w[13] = bytes32(uint256(deadline));
    }

    function record(
        uint256 tokenId,
        O.OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline
    ) internal view returns (bytes32) {
        return digest(keccak256(abi.encode(words(tokenId, r, owner, nonce, deadline))));
    }

    function revocation(address owner, uint256 nonce, uint64 deadline)
        internal
        view
        returns (bytes32)
    {
        return digest(keccak256(abi.encode(REVOCATION_TYPEHASH, owner, nonce, deadline)));
    }

    function digest(bytes32 body) private view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", domain(), body));
    }
}
