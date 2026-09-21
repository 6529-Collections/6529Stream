// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSanctionHashes.sol";
import {
    StreamFinalityViewSanctionReviewCodecV1 as ViewReview
} from "../finality/StreamFinalityViewSanctionReviewCodecV1.sol";
import "./StreamArtistSanctionCeremony.sol";
import "../finality/StreamFinalitySanctionReviewReads.sol";
import "../../interfaces/stream/finality/IStreamArtistSanctionReviewPreparation.sol";
import {
    StreamArtistSanctionRequestTypes as Q
} from "../../interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";
import "../../interfaces/stream/finality/IStreamArtistSanctionPreparation.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeEvidence.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";

/// @notice Actual candidate joins before signing or nonce consumption; no caller-supplied review inventory.
library StreamArtistSanctionCandidate {
    struct Pins {
        address finalityRegistry;
        bytes32 finalityCodeHash;
        address provider;
        bytes32 providerCodeHash;
        uint256 readGas;
    }

    error SanctionReadFailed(address target);
    error SanctionParentGas(uint256 available, uint256 required);

    function prepare(StreamArtistHashes.Environment memory e, Pins memory pins, Q.Request memory q)
        public
        view
        returns (Q.Prepared memory result)
    {
        if (
            pins.finalityRegistry.code.length == 0
                || pins.finalityRegistry.codehash != pins.finalityCodeHash
                || pins.provider.code.length == 0 || pins.provider.codehash != pins.providerCodeHash
        ) revert T.InvalidBinding();
        _selected(e.core, keccak256("ARTIST_REGISTRY"), e.registry, pins.readGas);
        _selected(
            e.core, keccak256("ARTWORK_FINALITY_REGISTRY"), pins.finalityRegistry, pins.readGas
        );
        if (q.terms.scopeType > 4) revert S.InvalidSanction();
        StreamFinalityScope memory scope = StreamFinalityScope(
            StreamFinalityScopeType(q.terms.scopeType),
            q.terms.collectionId,
            q.terms.tokenId,
            q.terms.scopeId
        );
        StreamArtistSanctionPreparation memory actual;
        bytes memory raw;
        if (StreamFinalityBoundedReads.supportsOptional(
                pins.finalityRegistry,
                type(IStreamArtistSanctionReviewPreparation).interfaceId,
                pins.readGas
            )) {
            bytes memory combined = StreamFinalitySanctionReviewReads.read(
                pins.finalityRegistry,
                abi.encodeCall(
                    IStreamArtistSanctionReviewPreparation.prepareSanctionWithReview,
                    (scope, q.nonSanctionComponents, q.manifest)
                ),
                scope.scopeType == StreamFinalityScopeType.VIEW ? ViewReview.PREPARATION : 896,
                pins.readGas
            );
            IStreamFinalitySanctionReview.ReviewFacts memory review =
                StreamFinalitySanctionReviewReads.review(combined, 160);
            actual = abi.decode(combined, (StreamArtistSanctionPreparation));
            raw = abi.encode(review);
        } else {
            actual = abi.decode(
                _read(
                    pins.finalityRegistry,
                    abi.encodeCall(
                        IStreamArtistSanctionPreparation.prepareSanction,
                        (scope, q.nonSanctionComponents, q.manifest)
                    ),
                    128,
                    pins.readGas
                ),
                (StreamArtistSanctionPreparation)
            );
        }
        S.Subject memory p;
        p.domain = keccak256("6529STREAM_ARTIST_SANCTION_SUBJECT_V1");
        p.chainId = e.chainId;
        p.core = e.core;
        p.finalityRegistry = pins.finalityRegistry;
        p.scopeType = q.terms.scopeType;
        p.collectionId = q.terms.collectionId;
        p.tokenId = q.terms.tokenId;
        p.scopeId = q.terms.scopeId;
        p.coreFactsHash = actual.coreFactsHash;
        p.nonSanctionComponentsHash = actual.nonSanctionComponentsHash;
        p.manifestURIHash = q.manifest.uriHash;
        p.manifestContentHash = q.manifest.contentHash;
        p.manifestSchemaId = q.manifest.schemaId;
        p.manifestCanonicalizationHash = q.manifest.canonicalizationHash;
        if (
            actual.sanctionSubjectHash != StreamArtistSanctionHashes.subject(p)
                || actual.scopeInputsHash == 0
        ) revert S.InvalidSanction();
        if (raw.length == 0) {
            raw = _readReview(
                pins.provider,
                abi.encodeCall(
                    IStreamFinalitySanctionReview.requireSanctionReviewFacts,
                    (scope, q.manifest.contentHash)
                ),
                pins.readGas,
                scope.scopeType == StreamFinalityScopeType.VIEW
            );
        }
        IStreamFinalitySanctionReview.ReviewFacts memory reviewed;
        if (raw.length >= 288 && _word(raw, 64) == 3) {
            ViewReview.requireScope(scope, q.manifest.schemaId, q.manifest.canonicalizationHash);
            reviewed = ViewReview.review(raw, 32);
        } else {
            uint256 referenceCount = _word(raw, 224);
            uint256 profile = _word(raw, 64);
            // Two explicitly admitted native ONCHAIN profiles. Both retain every ordered original
            // reference artifact occurrence, including repeated bytes, and have no media objects.
            if (
                _word(raw, 0) != 32 || _word(raw, 32) != 1 || _word(raw, 96) == 0
                    || _word(raw, 128) != 160 || _word(raw, 160) != 192 || _word(raw, 192) != 0
                    || referenceCount == 0 || referenceCount > 16
                    || raw.length != 256 + referenceCount * 32
                    || !((profile == 1 && referenceCount == 1)
                        || (profile == 2 && referenceCount >= 2))
            ) revert S.InvalidSanctionCeremony();
            for (uint256 i; i < referenceCount; ++i) {
                if (_word(raw, 256 + i * 32) == 0) revert S.InvalidSanctionCeremony();
            }
            reviewed = abi.decode(raw, (IStreamFinalitySanctionReview.ReviewFacts));
        }
        S.Ceremony memory c = S.Ceremony(
            reviewed.contentRoot,
            reviewed.mediaContentHashes,
            reviewed.referenceRenderContentHashes,
            q.statement,
            q.signingToolName,
            q.signingToolVersion
        );
        result = Q.Prepared(
            p, StreamArtistSanctionCeremony.document(p, c), actual.scopeInputsHash, keccak256(raw)
        );
    }

    function _selected(address core, bytes32 key, address expected, uint256 cap) private view {
        bytes memory raw =
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)), 320, cap);
        uint256 addressWord = _word(raw, 0);
        address actual = address(uint160(addressWord));
        if (
            addressWord >> 160 != 0 || actual != expected || actual.code.length == 0
                || actual.codehash != bytes32(_word(raw, 32))
        ) revert T.ComponentChanged(expected);
    }

    function _word(bytes memory value, uint256 offset) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(value, 32), offset)) }
    }

    // Match the shared finality reader: cap is an upper bound, measured after allocation.
    function _readReview(address target, bytes memory data, uint256 cap, bool viewScope)
        private
        view
        returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint256).max / 64) revert T.InvalidBinding();
        uint256 maximum = viewScope ? ViewReview.STANDALONE : 768;
        raw = new bytes(maximum);
        uint256 available = gasleft();
        if (available <= 100000) revert SanctionParentGas(available, 100000);
        uint256 forwarded = available - 100000;
        if (cap < forwarded) forwarded = cap;
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(forwarded, target, add(data, 32), mload(data), add(raw, 32), maximum)
            returned := returndatasize()
        }
        if (!ok || returned < 288 || returned > maximum || (_word(raw, 64) != 3 && returned > 768))
        {
            revert SanctionReadFailed(target);
        }
        assembly ("memory-safe") { mstore(raw, returned) }
    }

    function _read(address target, bytes memory data, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint256).max / 64) revert T.InvalidBinding();
        raw = new bytes(size);
        uint256 available = gasleft();
        if (available <= 100000) revert SanctionParentGas(available, 100000);
        uint256 forwarded = available - 100000;
        if (cap < forwarded) forwarded = cap;
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(forwarded, target, add(data, 32), mload(data), add(raw, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert SanctionReadFailed(target);
    }
}
