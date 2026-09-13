// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../interfaces/stream/artist/StreamArtistSaleTypes.sol";
import "./StreamArtistEconomicsAssociation.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";

/// @notice Exact historical record encodings for the existing Consent owner getters.
/// @dev Storage lookup keys and returned tuples are unchanged; this performs no operative selection.
library StreamArtistConsentReadEncoding {
    function economicsForBinding(
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => IStreamArtistEconomicsEvidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage original,
        T.EconomicsConsent calldata p,
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash
    ) public view returns (bytes32 record) {
        record = associated[
            StreamArtistEconomicsAssociation.key(p, artistId, generation, bindingHash)
        ];
        if (record == 0) return record;
        IStreamArtistEconomicsEvidence.Association memory a = associations[record];
        if (
            a.artistId != artistId || a.bindingGeneration != generation
                || a.bindingHash != bindingHash || a.payloadHash != keccak256(abi.encode(p))
                || a.originalRecord == 0 || original[a.payloadHash] != a.originalRecord
        ) revert T.InvalidRecord();
    }

    function association(
        mapping(bytes32 => IStreamArtistEconomicsEvidence.Association) storage records,
        bytes32 hash
    ) public view returns (bytes memory) {
        return abi.encode(records[hash]);
    }

    function firstRatification(
        mapping(uint256 => T.RatificationRecord) storage records,
        uint256 collectionId
    ) public view returns (bytes memory) {
        return abi.encode(records[collectionId]);
    }

    function ratification(mapping(bytes32 => T.RatificationRecord) storage records, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(records[hash]);
    }

    function sale(mapping(bytes32 => Sale.Record) storage records, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(records[hash]);
    }

    function content(
        mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) storage records,
        bytes32 hash
    ) public view returns (bytes memory) {
        return abi.encode(records[hash]);
    }

    function contentAt(
        mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) storage records,
        mapping(bytes32 => bytes32) storage latest,
        Content.Consent calldata terms,
        uint64 generation
    ) public view returns (bytes memory) {
        return abi.encode(records[latest[keccak256(abi.encode(terms, generation))]]);
    }

    function freeze(mapping(bytes32 => Content.FreezeRecord) storage records, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(records[hash]);
    }

    function freezeAt(
        mapping(bytes32 => Content.FreezeRecord) storage records,
        mapping(bytes32 => bytes32) storage latest,
        uint256 collectionId,
        uint64 generation,
        address metadata,
        bytes32 lockClass
    ) public view returns (bytes memory) {
        return abi.encode(
            records[latest[keccak256(abi.encode(collectionId, generation, metadata, lockClass))]]
        );
    }
}
