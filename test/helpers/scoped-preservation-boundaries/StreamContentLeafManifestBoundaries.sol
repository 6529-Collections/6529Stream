// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArchivalTypes as A
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

/// @dev Explicit archival-family/receipt boundary; actual whole-object bytes and coverage aggregation below.
contract LeafManifestArchiveBoundary {
    address public immutable core;
    address public immutable governanceAuthority;
    uint64 public coverageValidationEpoch = 1;
    mapping(bytes32 => address) private _pointers;

    constructor(address c, address g) {
        core = c;
        governanceAuthority = g;
    }

    function advanceEpoch() external {
        ++coverageValidationEpoch;
    }

    function requireCoverageEnvironment() external pure returns (bytes32) {
        return keccak256("fixture archival environment");
    }

    function add(bytes32 hash, address pointer) external {
        _pointers[hash] = pointer;
    }

    function requireCoverage(bytes32 hash, bytes32 artistId, bytes32 evidence)
        external
        view
        returns (A.CoverageFacts memory f)
    {
        require(
            hash == evidence && _pointers[evidence] != address(0),
            "unrecognized archival fixture bytes"
        );
        f.coverageRecordHash = hash;
        f.envelopeHash = hash;
        f.artistId = artistId;
        f.evidenceHash = evidence;
        f.firstFamilyRecordHash = keccak256("archive family A");
        f.secondFamilyRecordHash = keccak256("archive family B");
    }

    function chunkEnvelopePointer(bytes32 hash) external view returns (address, bytes32) {
        address p = _pointers[hash];
        return (p, p.codehash);
    }

    function coverage(bytes32 hash) external view returns (A.CoverageFacts memory) {
        return this.requireCoverage(hash, keccak256("artist"), hash);
    }
}

contract LeafManifestFinalityBoundary {
    address public immutable core;
    address public immutable artifactCoverage;

    constructor(address c, address a) {
        core = c;
        artifactCoverage = a;
    }
}
