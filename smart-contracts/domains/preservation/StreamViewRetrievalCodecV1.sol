// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewRetrievalWitnessTypesV1 as T
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamMetadataRenderer as URI } from "../metadata/StreamMetadataRenderer.sol";
import {
    StreamViewPreservationMediaCorrespondenceV1 as Exact
} from "./StreamViewPreservationMediaCorrespondenceV1.sol";

/// @notice Closed complete observation codec. Every route mapping remains an attributed claim.
library StreamViewRetrievalCodecV1 {
    function sourceKey(T.Source memory s) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                T.SOURCE,
                s.scope,
                s.core,
                s.router,
                s.adoptionRecord,
                s.adoptionSourceHash,
                s.declaration,
                s.declarationRecord,
                s.payloadHash,
                s.requestedURI
            )
        );
    }

    function digest(T.Configuration memory c, address host, T.Observation memory o)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(T.OBSERVATION, c.chainId, host, keccak256(abi.encode(T.PROFILE, c)), o)
        );
    }

    function canonical(bytes memory raw)
        public
        pure
        returns (T.Observation memory o, bytes memory signature)
    {
        if (raw.length == 0 || raw.length > T.MAX_BYTES) revert T.InvalidViewRetrieval();
        (o, signature) = abi.decode(raw, (T.Observation, bytes));
        if (signature.length > 4096 || keccak256(raw) != keccak256(abi.encode(o, signature))) {
            revert T.InvalidViewRetrieval();
        }
        shape(o);
    }

    function shape(T.Observation memory o) public pure {
        T.Source memory s = o.source;
        if (
            s.scope.scopeType != StreamFinalityScopeType.VIEW || s.scope.collectionId == 0
                || s.scope.tokenId != 0 || s.scope.scopeId == 0 || s.core == address(0)
                || s.router == address(0) || s.adoptionRecord == 0 || s.adoptionSourceHash == 0
                || s.declaration == address(0) || s.declarationRecord == 0 || s.payloadHash == 0
                || s.checkpointContextHash == 0 || o.writer == address(0) || o.observedAt == 0
                || o.deadline < o.observedAt || o.coverage.objectHash == 0
                || o.coverage.coverageHash == 0 || o.object.contentHash == 0
                || o.object.sha256Digest == 0 || o.object.byteSize == 0
        ) revert T.InvalidViewRetrieval();
        uri(s.requestedURI);
        (uint8 finalKind,) = uri(o.resolvedURI);
        // A remaining Arweave subpath is not a completed resolution.
        if (finalKind == 3 || abi.encode(o, bytes("")).length > T.MAX_BYTES) {
            revert T.InvalidViewRetrieval();
        }
        // Zero hops is an explicit direct retrieval; the final equality below remains mandatory.
        bytes32 previous = keccak256(bytes(s.requestedURI));
        for (uint256 i; i < o.steps.length; ++i) {
            T.Step memory step = o.steps[i];
            (uint8 fromKind,) = uri(step.fromURI);
            uri(step.toURI);
            bytes32 next = keccak256(bytes(step.toURI));
            if (keccak256(bytes(step.fromURI)) != previous || previous == next) {
                revert T.InvalidViewRetrieval();
            }
            if (step.kind == 1) {
                if (
                    fromKind != 1
                        || !(step.status == 301
                            || step.status == 302
                            || step.status == 303
                            || step.status == 307
                            || step.status == 308)
                ) revert T.InvalidViewRetrieval();
            } else if (step.kind == 2) {
                // Explicitly attributed byte-identical copy; never fabricated HTTP redirect.
                if (fromKind == 3 || step.status != 0) revert T.InvalidViewRetrieval();
            } else if (step.kind == 3) {
                (uint8 toKind,) = uri(step.toURI);
                if (
                    fromKind != 3 || toKind == 1 || step.status != 0 || step.manifestObject == 0
                        || step.manifestCoverage == 0 || step.manifestBytes.length == 0
                ) revert T.InvalidViewRetrieval();
            } else {
                revert T.InvalidViewRetrieval();
            }
            if (
                step.kind != 3
                    && (step.manifestObject != 0
                        || step.manifestCoverage != 0
                        || step.manifestBytes.length != 0)
            ) revert T.InvalidViewRetrieval();
            previous = next;
        }
        if (previous != keccak256(bytes(o.resolvedURI))) revert T.InvalidViewRetrieval();
    }

    /// @return kind HTTPS1, canonical Arweave transaction2, exact Arweave path3.
    /// @dev The path is retained literally, not normalized or interpreted as a content digest.
    function uri(string memory value) public pure returns (uint8 kind, bytes32 transactionId) {
        URI.requireValidUtf8ContentUri("viewRetrievalURI", value, 2048, false);
        bytes memory b = bytes(value);
        if (b.length >= 8 && bytes8(b) == bytes8("https://")) return (1, 0);
        if (b.length < 48 || bytes5(b) != bytes5("ar://")) revert T.InvalidViewRetrieval();
        bytes memory root = new bytes(48);
        for (uint256 i; i < 48; ++i) {
            root[i] = b[i];
        }
        (, transactionId) = Exact.locator(string(root));
        if (b.length == 48) return (2, transactionId);
        if (b[48] != "/" || b.length == 49) revert T.InvalidViewRetrieval();
        return (3, transactionId);
    }
}
