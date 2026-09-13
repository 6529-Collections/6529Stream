// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSanctionHashes.sol";
import "./StreamArtistSanctionCeremony.sol";
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
        StreamArtistSanctionPreparation memory actual = abi.decode(
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
        bytes memory raw = _read(
            pins.provider,
            abi.encodeCall(
                IStreamFinalitySanctionReview.requireSanctionReviewFacts,
                (scope, q.manifest.contentHash)
            ),
            288,
            pins.readGas
        );
        // Canonical dynamic tuple for explicitly supported version1/profile1. No arbitrary offsets,
        // unchecked lengths or unknown profiles reach the ABI decoder.
        if (
            _word(raw, 0) != 32 || _word(raw, 32) != 1 || _word(raw, 64) != 1 || _word(raw, 96) == 0
                || _word(raw, 128) != 160 || _word(raw, 160) != 192 || _word(raw, 192) != 0
                || _word(raw, 224) != 1 || _word(raw, 256) == 0
        ) revert S.InvalidSanctionCeremony();
        IStreamFinalitySanctionReview.ReviewFacts memory reviewed =
            abi.decode(raw, (IStreamFinalitySanctionReview.ReviewFacts));
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

    function _read(address target, bytes memory data, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint256).max / 64) revert T.InvalidBinding();
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) revert SanctionParentGas(gasleft(), required);
        raw = new bytes(size);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert SanctionReadFailed(target);
    }
}
