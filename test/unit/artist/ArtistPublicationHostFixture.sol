// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationHost.sol";
import "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

/// @dev Exact metadata read boundary only. Its fixture hash is not the canonical generic record preimage.
contract ArtistPublicationHostFixture {
    address public core;
    uint256 private mode;
    bytes private payload = bytes("actual unit publication bytes");

    constructor(address core_) {
        core = core_;
    }

    function setMode(uint256 mode_) external {
        mode = mode_;
    }

    function setCore(address core_) external {
        core = core_;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("COLLECTION_METADATA");
    }

    function streamModuleVersion() external pure returns (bytes32) {
        return keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtistRecordPublicationHost).interfaceId;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistRecordPublicationHost).interfaceId
            || id == type(IERC165).interfaceId;
    }

    function candidateHash(P.Publication memory publication) public view returns (bytes32) {
        publication.candidateRecordHash = 0;
        return keccak256(
            abi.encode(
                keccak256("EXPLICIT_UNIT_METADATA_CANDIDATE"), core, address(this), publication
            )
        );
    }

    function requireArtistRecordCandidate(P.Publication calldata publication)
        external
        view
        returns (bytes32, uint8)
    {
        uint256 m = mode;
        if (m == 1) revert("unit provider rejection");
        if (m == 2) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(0, 32)
            }
        }
        if (m == 3) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(0, 96)
            }
        }
        if (m == 4) assembly ("memory-safe") { for { } 1 { } { } }
        require(
            publication.metadataHost == address(this)
                && publication.payloadHash == keccak256(payload),
            "actual fixture bytes"
        );
        bytes32 hash = candidateHash(publication);
        require(publication.candidateRecordHash == hash, "exact fixture candidate");
        return (
            hash,
            publication.recordType == keccak256("ARTIST_STATEMENT")
                || publication.recordType == keccak256("ARTIST_SEMANTIC_ASSERTION")
                ? 8
                : 7
        );
    }
}
