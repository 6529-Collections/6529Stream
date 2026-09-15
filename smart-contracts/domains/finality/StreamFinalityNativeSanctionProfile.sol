// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityBoundedReads.sol";
import "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Registered composite interpretation for native multi-capture artist review.
/// @dev Base ceremony/archive documents and their permanent preimages remain unchanged.
library StreamFinalityNativeSanctionProfile {
    bytes32 internal constant ID = keccak256("6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1");
    error NativeSanctionProfileUnavailable();

    function document() public pure returns (bytes memory) {
        return bytes(
            '{"name":"6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1","version":1,"documentKind":"CATALOG","canonicalization":"RAW_BYTES","baseDefinitions":[{"path":"docs/schemas/finality/sanction-ceremony-v1.schema.json","keccak256":"0xd964c877b4256e4e829aa2630470b85832e4aa1e8a59da32094334550341600a"},{"path":"docs/schemas/finality/sanction-ceremony-jcs-v1.json","keccak256":"0x0d8a4197d8a294bd36eb4fd400c1ecc88ac8104c7091223b5436892a4797eef4"},{"path":"docs/schemas/finality/sanction-archive-v1.schema.json","keccak256":"0xd55474e8f3ce5aacaa70ca4a40aee030b39b366143118c9d27ff2547e85efb1a"},{"path":"docs/schemas/finality/sanction-archive-abi-v1.json","keccak256":"0x4b09880c931db919d35159b9974e21dcf1583bfaa65c18e3636e8721140cc690"}],"interpretation":"Composite interpretation with the exact four base definitions. The base SCHEMA remains unchanged and is not superseded or retired.","override":"Only the exactly-one producer applicability restriction in sanction-ceremony-v1.schema.json is extended for ReviewFacts schemaVersion1/profile2. All other base rules remain normative.","profile":{"schemaVersion":1,"profile":2,"scope":"native ONCHAIN artist-associated COLLECTION","contentRoot":"Nonzero actual original content root from the exact admitted current scope and manifest","mediaContentHashes":"Empty under the supported native inline-content profile","referenceRenderContentHashes":"Ordered2..16 complete original PNG artifact Keccak content hashes, preserving every original occurrence and repetition"},"source":"Each original capture object resolves through the fixed archive to canonical ObjectIdentity with matching artist, both nonzero equal repeated PNG SHA256 digests, native root, nonzero size and exact PNG schema/format/catalog. The capture sourceSha256 identifies the original HTML and is validated separately by original reference admission; it is not the rendered PNG digest. Never substitute a record hash, object descriptor hash, coverage hash or SHA256 for an image content hash.","admission":"The fixed provider validates the complete current scope/manifest and exact ACTIVE profile facts and bytes before emitting profile2. Count1 remains profile1. A source producer may not exceed its own admitted capture-sampling profile.","historical":"Profile retirement stops new profile2 admission. It does not erase or reinterpret an original signature, ceremony, sanction or archived object. Portable profile2 interpretation requires this fifth document alongside all four exact base definitions. The original ceremony/archive finalityRegistry resolves its fixed scopeEvidenceProvider() and scopeEvidenceProviderCodeHash(); that original provider runtime pins this profile ID and exact content hash. Signed array count identifies profile2. The unchanged four-definition Archive verifier trusts the original Artist admission; it does not independently parse this fifth document.","unchanged":["Permanent AA-SANCTION subject and record preimages","Ceremony JSON fields, schema string, canonicalization and statementHash","Original signature and archive encoding","Bounded maximum16 entries and array order"],"limits":"This profile does not prove arbitrary script dependency closure, other media profiles, full-system correctness or transaction gas capacity."}'
        );
    }

    function requireCurrent(
        address registry,
        bytes32 registryHash,
        address store,
        bytes32 storeHash,
        uint256 readGas
    ) public view {
        if (
            registry.code.length == 0 || registry.codehash != registryHash || store.code.length == 0
                || store.codehash != storeHash
        ) revert NativeSanctionProfileUnavailable();
        bytes memory expected = document();
        bytes32 contentHash = keccak256(expected);
        bytes memory raw = StreamFinalityBoundedReads.read(
            registry, abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (ID)), 288, readGas
        );
        IStreamSchemaDocumentFacts.DocumentFacts memory f =
            abi.decode(raw, (IStreamSchemaDocumentFacts.DocumentFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.exists
                || f.kind != IStreamSchemaRegistry.DocumentKind.CATALOG
                || f.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                || f.contentHash != contentHash || f.canonicalizationId != keccak256("RAW_BYTES")
                || f.supersedesId != 0 || f.totalBytes != expected.length || f.chunkCount != 1
                || f.declarationHash == 0
        ) revert NativeSanctionProfileUnavailable();
        bytes memory encoded = abi.encode(expected);
        raw = StreamFinalityBoundedReads.read(
            registry,
            abi.encodeCall(IStreamSchemaRegistry.documentBytes, (ID)),
            encoded.length,
            readGas
        );
        if (keccak256(raw) != keccak256(encoded)) revert NativeSanctionProfileUnavailable();
        raw = StreamFinalityBoundedReads.read(
            store,
            abi.encodeCall(StreamSchemaDocumentStore.readChunk, (contentHash)),
            encoded.length,
            readGas
        );
        if (keccak256(raw) != keccak256(encoded)) revert NativeSanctionProfileUnavailable();
    }
}
