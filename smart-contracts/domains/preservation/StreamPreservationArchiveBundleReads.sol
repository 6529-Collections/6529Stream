// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArchivalTypes as A
} from "../../interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import "../../interfaces/stream/preservation/IStreamArchivalCoverage.sol";
import "../../interfaces/stream/preservation/IStreamArchivalCheckpointVerifier.sol";

/// @notice Exact state-readable original small-object archival signed bundles.
/// @dev Historical getter bytes are authenticated through the fixed artifact/coverage graph;
/// this neither replays historical signatures nor recursively archives its own new evidence.
library StreamPreservationArchiveBundleReads {
    function chunk(
        address host,
        bytes32 hash,
        bytes32 artist,
        bytes32 content,
        bytes32 first,
        bytes32 second,
        uint256 gasCap
    ) public view returns (bytes32) {
        bytes memory raw = IO.fixedRead(
            host, abi.encodeCall(IStreamArchivalCoverage.coverage, (hash)), 384, gasCap
        );
        A.CoverageFacts memory c = abi.decode(raw, (A.CoverageFacts));
        IO.canonical(host, raw, abi.encode(c));
        if (
            hash == 0 || c.coverageRecordHash != hash || c.artistId != artist
                || c.evidenceHash != content || c.firstFamilyRecordHash != first
                || c.secondFamilyRecordHash != second
        ) revert T.InvalidInventoryItem();
        return _bundles(host, c, gasCap);
    }

    function _bundles(address host, A.CoverageFacts memory c, uint256 gasCap)
        private
        view
        returns (bytes32)
    {
        bytes32[6] memory hashes;
        hashes[0] = _receipt(host, c.firstReceiptRecordHash, gasCap);
        hashes[1] = _receipt(host, c.secondReceiptRecordHash, gasCap);
        hashes[2] = _fixity(host, c.firstFixityRecordHash, gasCap);
        hashes[3] = _fixity(host, c.secondFixityRecordHash, gasCap);
        hashes[4] = _checkpoint(host, c.checkpointRecordHash, gasCap);
        bytes memory raw = IO.read(
            host, abi.encodeCall(IStreamArchivalCoverage.envelope, (c.envelopeHash)), 16384, gasCap
        );
        (A.Envelope memory e, bytes memory payload) = abi.decode(raw, (A.Envelope, bytes));
        IO.canonical(host, raw, abi.encode(e, payload));
        if (
            e.artistId != c.artistId || e.evidenceHash != c.evidenceHash
                || e.byteSize != payload.length || keccak256(payload) != c.evidenceHash
                || sha256(payload) != e.payloadDigest
        ) revert T.InvalidInventoryItem();
        hashes[5] = keccak256(raw);
        return keccak256(abi.encode(host, host.codehash, c, hashes));
    }

    function _receipt(address host, bytes32 hash, uint256 gasCap) private view returns (bytes32) {
        bytes memory raw =
            IO.read(host, abi.encodeCall(IStreamArchivalCoverage.receipt, (hash)), 16384, gasCap);
        (A.ReceiptTerms memory r, bytes memory locator, bytes memory signature) =
            abi.decode(raw, (A.ReceiptTerms, bytes, bytes));
        IO.canonical(host, raw, abi.encode(r, locator, signature));
        if (
            r.writer == address(0) || r.storageIdentifierHash != keccak256(locator)
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1"),
                            block.chainid,
                            host,
                            r
                        )
                    ) != hash
        ) revert T.InvalidInventoryItem();
        return keccak256(abi.encode(hash, raw));
    }

    function _fixity(address host, bytes32 hash, uint256 gasCap) private view returns (bytes32) {
        bytes memory raw =
            IO.read(host, abi.encodeCall(IStreamArchivalCoverage.fixity, (hash)), 16384, gasCap);
        (A.FixityTerms memory f, bytes memory signature) = abi.decode(raw, (A.FixityTerms, bytes));
        IO.canonical(host, raw, abi.encode(f, signature));
        if (
            f.verifier == address(0)
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARCHIVAL_FIXITY_RECORD_V1"),
                            block.chainid,
                            host,
                            f
                        )
                    ) != hash
        ) revert T.InvalidInventoryItem();
        return keccak256(abi.encode(hash, raw));
    }

    function _checkpoint(address host, bytes32 hash, uint256 gasCap)
        private
        view
        returns (bytes32)
    {
        address verifier = IO.addressWord(
            host, abi.encodeCall(IStreamArchivalCoverage.checkpointVerifier, ()), gasCap
        );
        bytes memory raw = IO.read(
            verifier,
            abi.encodeCall(IStreamArchivalCheckpointVerifier.checkpointRecord, (hash)),
            65536,
            gasCap
        );
        A.CheckpointRecord memory r = abi.decode(raw, (A.CheckpointRecord));
        IO.canonical(verifier, raw, abi.encode(r));
        if (hash == 0 || r.recordHash != hash || r.recordedAt == 0 || r.certificate.length == 0) {
            revert T.InvalidInventoryItem();
        }
        return keccak256(abi.encode(verifier, verifier.codehash, hash, raw));
    }
}
