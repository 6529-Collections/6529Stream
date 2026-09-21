// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityBoundedReads.sol";
import "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Registered composite interpretation for native multi-capture artist review.
/// @dev Base ceremony/archive documents and their permanent preimages remain unchanged.
library StreamFinalityViewSanctionProfileV1 {
    bytes32 internal constant ID = keccak256("6529STREAM_ARTIST_SANCTION_VIEW_MEDIA_V1");
    error ViewSanctionProfileUnavailable();

    function document() public pure returns (bytes memory) {
        return bytes(
            '{"name":"6529STREAM_ARTIST_SANCTION_VIEW_MEDIA_V1","version":1,"documentKind":"CATALOG","canonicalization":"RAW_BYTES","baseDefinitions":[{"path":"docs/schemas/finality/sanction-ceremony-v1.schema.json","keccak256":"0xd964c877b4256e4e829aa2630470b85832e4aa1e8a59da32094334550341600a"},{"path":"docs/schemas/finality/sanction-ceremony-jcs-v1.json","keccak256":"0x0d8a4197d8a294bd36eb4fd400c1ecc88ac8104c7091223b5436892a4797eef4"},{"path":"docs/schemas/finality/sanction-archive-v1.schema.json","keccak256":"0xd55474e8f3ce5aacaa70ca4a40aee030b39b366143118c9d27ff2547e85efb1a"},{"path":"docs/schemas/finality/sanction-archive-abi-v1.json","keccak256":"0x4b09880c931db919d35159b9974e21dcf1583bfaa65c18e3636e8721140cc690"}],"interpretation":"Composite interpretation with the exact four base definitions. The base SCHEMA remains unchanged and is not superseded or retired.","override":"Only native producer applicability is extended for schemaVersion1/profile3, canonical VIEW, complete nonempty media and reference lists. All original subject, ceremony, signature, archive and nonce rules stay normative.","profile":{"schemaVersion":1,"profile":3,"scope":"VIEW exact complete current preservation manifest","contentRoot":"Nonzero original op17 VIEW content root","mediaContentHashes":"Ordered1..16 complete actual media Keccak content hashes; no deduplication; actual VIEW payload presently has one optional image occurrence","referenceRenderContentHashes":"Ordered1..16 complete actual PNG capture Keccak content hashes, including repeated occurrences"},"source":"Exact current completed VIEW inventory and matching current bundle coverage authenticate all media. Canonical raw IPFS SHA256 identifies the complete image, never the URI hash. Digest-bearing rows retain the original external/onchain Archive correspondence rules. An admitted locator requires backend1 external Archive evidence to supply content Keccak and nonzero full size after full correspondence validation. Exact closed HTTPS locators must equal the signed institutional receipt locator in that same current pair; canonical ar:// transaction IDs must equal its endowed receipt locator and native checkpoint. Those locator-obligation rows contain no file digest or size, and are not cryptographic URI-to-content claims. The companion-enabled inventory profile 6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1 additionally admits exact origin/redirect/mirror/Arweave-path correspondence only through the immutable selected satellite and explicit Bundle witness coordinate. The original institutional storing agent signs a fresh full source, locked Artist presentation, object, pair and complete ordered route; direct retrieval has identical requested/resolved URI and zero hops. Arweave path interpretation is attributed and retains separately admitted complete manifest bytes, not a generic resolver proof. Current acceptance rejoins exact scope/adoption/payload/Artist/row plus original current pair and nonrevoked witness; scope-keyed revocation epoch authenticates aggregate refresh. Original locator rows stay byte-exact and require the old receipt equality unless the explicit witness path is selected. No URI is treated as a file digest, caller-selected resolver or arbitrary object. Unsupported URI grammars remain refused. Actual original PNG capture object identity supplies each reference hash. No caller-selected digest/object list.","admission":"Fixed VIEW provider requires this exact ACTIVE catalogue and full bytes, complete current scope/input manifest, original selection receipt and media/capture evidence before profile3. Empty-media views retain profile1/2 and their original rules. Canonical decoder retains both original16-array bounds; no truncated inventory or invented token identity.","historical":"Retirement stops new profile3 admission. Existing signed arrays, original ceremony/archive bytes and source records remain historical. This exact catalogue accompanies the four unchanged base definitions; original provider runtime and signed VIEW manifest profile identify the admitted interpretation.","unchanged":["Permanent AA-SANCTION subject and record preimages","Ceremony JSON fields, schema string, canonicalization and statementHash","Original signature and archive encoding","Bounded maximum16 entries and array order"],"limits":"This profile does not prove arbitrary script dependency closure, other media profiles, full-system correctness or transaction gas capacity."}'
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
        ) revert ViewSanctionProfileUnavailable();
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
        ) revert ViewSanctionProfileUnavailable();
        bytes memory encoded = abi.encode(expected);
        raw = StreamFinalityBoundedReads.read(
            registry,
            abi.encodeCall(IStreamSchemaRegistry.documentBytes, (ID)),
            encoded.length,
            readGas
        );
        if (keccak256(raw) != keccak256(encoded)) revert ViewSanctionProfileUnavailable();
        raw = StreamFinalityBoundedReads.read(
            store,
            abi.encodeCall(StreamSchemaDocumentStore.readChunk, (contentHash)),
            encoded.length,
            readGas
        );
        if (keccak256(raw) != keccak256(encoded)) revert ViewSanctionProfileUnavailable();
    }
}
