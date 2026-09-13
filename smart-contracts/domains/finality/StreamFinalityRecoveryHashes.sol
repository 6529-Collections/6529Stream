// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityComponentExpectation
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityRecoveryRequest,
    StreamFinalityRecoveryEvidenceSnapshot
} from "../../interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";

/// @notice Stateless exact ADR0020 recovery preimages.
/// @dev Values are supplied by the fixed owning companion. Encoding establishes no scope,
///      manifest, route, governance, artist or owner-evidence eligibility.
library StreamFinalityRecoveryHashes {
    struct Environment {
        uint256 chainId;
        address companion;
    }

    struct Execution {
        bytes32 recoveryId;
        bytes32 originalFinalityRecordHash;
        bytes32 predecessorRecoveryId;
        uint64 generation;
    }

    struct IntentTail {
        bytes32 predecessorRecoveryId;
        bytes32 oldRouteHash;
        StreamFinalityComponentExpectation replacementRoute;
        bytes32 manifestURIHash;
        bytes32 manifestSchemaId;
        bytes32 manifestCanonicalizationHash;
        bytes32 reasonHash;
        bytes32 reasonURIHash;
    }

    bytes32 internal constant SCOPE = keccak256("6529STREAM_FINALITY_RECOVERY_SCOPE_V1");
    bytes32 internal constant OLD = keccak256("6529STREAM_FINALITY_RECOVERY_OLD_STATE_V1");
    bytes32 internal constant NEW = keccak256("6529STREAM_FINALITY_RECOVERY_NEW_STATE_V1");
    bytes32 internal constant INTENT = keccak256("6529STREAM_FINALITY_RECOVERY_INTENT_V1");
    bytes32 internal constant COLLECTION_ROUTE = keccak256("6529STREAM_FINALITY_RECOVERY_V1");
    bytes32 internal constant SCOPED_ROUTE = keccak256("6529STREAM_SCOPED_FINALITY_RECOVERY_V1");

    function scopeKey(StreamFinalityScope memory s) public pure returns (bytes32) {
        return keccak256(abi.encode(uint8(s.scopeType), s.collectionId, s.tokenId, s.scopeId));
    }

    function scopeHash(Environment memory e, StreamFinalityScope memory s)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(SCOPE, e.chainId, e.companion, s));
    }

    function oldValueHash(
        StreamFinalityScope memory s,
        bytes32 originalFinalityRecordHash,
        bytes32 predecessorRecoveryId,
        uint64 oldGeneration,
        bytes32 oldRouteHash
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                OLD,
                scopeKey(s),
                originalFinalityRecordHash,
                predecessorRecoveryId,
                oldGeneration,
                oldRouteHash
            )
        );
    }

    function newValueHash(
        Environment memory e,
        uint64 newGeneration,
        StreamFinalityRecoveryRequest memory r
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(NEW, e.chainId, e.companion, newGeneration, r));
    }

    /// @notice Exactly 704 bytes: the eight-word intent prefix followed by fourteen static words.
    /// @dev contentHash is excluded from its own preimage; manifest URI is bound through uriHash.
    function intentBytes(Environment memory e, StreamFinalityRecoveryRequest memory r)
        public
        pure
        returns (bytes memory)
    {
        IntentTail memory t;
        t.predecessorRecoveryId = r.expectedPredecessorRecoveryId;
        t.oldRouteHash = r.expectedOldRouteHash;
        t.replacementRoute = r.replacementRoute;
        t.manifestURIHash = r.recoveryManifest.uriHash;
        t.manifestSchemaId = r.recoveryManifest.schemaId;
        t.manifestCanonicalizationHash = r.recoveryManifest.canonicalizationHash;
        t.reasonHash = r.reasonHash;
        t.reasonURIHash = keccak256(bytes(r.reasonURI));
        return bytes.concat(
            abi.encode(
                INTENT, e.chainId, e.companion, r.scope, r.expectedOriginalFinalityRecordHash
            ),
            abi.encode(t)
        );
    }

    function componentRouteHash(StreamFinalityComponentExpectation memory route)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(route));
    }

    function recoveredRouteHash(
        Environment memory e,
        Execution memory x,
        StreamFinalityRecoveryRequest memory r,
        StreamFinalityRecoveryEvidenceSnapshot memory evidence
    ) public pure returns (bytes32) {
        bytes32 domain = r.scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? COLLECTION_ROUTE
            : SCOPED_ROUTE;
        return keccak256(
            bytes.concat(
                abi.encode(
                    domain,
                    e.chainId,
                    e.companion,
                    x.recoveryId,
                    x.originalFinalityRecordHash,
                    x.predecessorRecoveryId,
                    x.generation
                ),
                abi.encode(
                    r.scope,
                    r.replacementRoute,
                    r.recoveryManifest.contentHash,
                    evidence,
                    r.reasonHash
                )
            )
        );
    }
}
