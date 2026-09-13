// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalitySanctionSchemas.sol";

import "../../interfaces/stream/finality/IStreamFinalitySanctionArchive.sol";
import "../../interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";

/// @notice Fixed whole-object evidence join, separate from the permanent sanction/finality hashes.
library StreamFinalitySanctionArchive {
    struct Pins {
        address core;
        address artist;
        address artifactCoverage;
        bytes32 artifactCodeHash;
        uint256 readGas;
    }

    function requireProof(
        Pins memory pins,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalitySanctionArchiveProof memory proof
    ) public view returns (bytes32 evidenceHash) {
        if (
            proof.sanctionRecordHash == 0 || proof.artifactHash == 0 || proof.completionHash == 0
                || pins.artifactCoverage.code.length == 0
                || pins.artifactCoverage.codehash != pins.artifactCodeHash
        ) revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
        uint256 count;
        for (uint256 i; i < components.length; ++i) {
            if (components[i].componentType == keccak256("ARTIST_SANCTION")) {
                ++count;
                if (
                    components[i].component != pins.artist
                        || components[i].dataHash != proof.sanctionRecordHash
                ) revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
            }
        }
        if (count != 1) revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
        IStreamArtistSanctionArchiveFacts.Facts memory expected = abi.decode(
            _read(
                pins.artist,
                abi.encodeCall(
                    IStreamArtistSanctionArchiveFacts.sanctionArchiveFacts,
                    (proof.sanctionRecordHash)
                ),
                192,
                pins.readGas
            ),
            (IStreamArtistSanctionArchiveFacts.Facts)
        );
        if (
            expected.sanctionRecordHash != proof.sanctionRecordHash || expected.artistId == 0
                || expected.schemaId != keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1")
                || expected.canonicalizationId
                    != keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1")
                || expected.contentHash == 0 || expected.byteLength == 0
                || expected.byteLength > 13120
        ) revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
        F.Coverage memory actual = abi.decode(
            _read(
                pins.artifactCoverage,
                abi.encodeCall(
                    IStreamFinalityArtifactCoverage.requireArtifactCoverage,
                    (proof.completionHash, expected.artistId, proof.artifactHash)
                ),
                384,
                pins.readGas
            ),
            (F.Coverage)
        );
        if (
            actual.completionHash != proof.completionHash
                || actual.artifactHash != proof.artifactHash || actual.artistId != expected.artistId
                || actual.schemaId != expected.schemaId
                || actual.canonicalizationId != expected.canonicalizationId
                || actual.contentHash != expected.contentHash
                || actual.byteLength != expected.byteLength
                || actual.chunkCount != (uint256(actual.byteLength) + 8191) / 8192
                || actual.firstFamilyRecordHash == 0 || actual.secondFamilyRecordHash == 0
                || actual.firstFamilyRecordHash == actual.secondFamilyRecordHash
        ) revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
        StreamFinalitySanctionSchemas.requireDefinitions(pins.artifactCoverage, pins.readGas);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                block.chainid,
                pins.core,
                address(this),
                pins.artifactCoverage,
                proof
            )
        );
    }

    function requireAbsent(StreamFinalityComponentExpectation[] calldata components) public pure {
        for (uint256 i; i < components.length; ++i) {
            if (components[i].componentType == keccak256("ARTIST_SANCTION")) {
                revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveRequired();
            }
        }
    }

    function _read(address target, bytes memory data, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint256).max / 64 || gasleft() <= cap + cap / 63 + 100000) {
            revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveReadFailed(target);
        }
        raw = new bytes(size);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) {
            revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveReadFailed(target);
        }
    }
}
