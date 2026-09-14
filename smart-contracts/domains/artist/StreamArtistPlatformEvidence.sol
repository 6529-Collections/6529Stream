// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import "../../interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Actual selected metadata byte publication and current collection-subject dual-family coverage.
library StreamArtistPlatformEvidence {
    function read(T.SuiteConfiguration memory s, uint256 id, bytes32 hash)
        public
        view
        returns (PW.Evidence memory e, bytes32 proof)
    {
        if (hash == 0) revert PW.InvalidPlatformEvidence(hash);
        (address selected, bytes32 codeHash,,,,,,,,) =
            IStreamCorePointers(s.core).getSatellitePointer(keccak256("COLLECTION_METADATA"));
        if (
            selected != s.metadata || codeHash != s.metadata.codehash || s.metadata.code.length == 0
                || IStreamCollectionMetadataV1(s.metadata).core() != s.core
        ) revert PW.InvalidPlatformEvidence(hash);
        address store = IStreamCollectionMetadataV1(s.metadata).chunkStore();
        // Both input and output are exactly five words; malformed ABI cannot masquerade as a document.
        bytes memory payload = StreamSchemaDocumentStore(store).readChunk(hash);
        if (payload.length != 160 || keccak256(payload) != hash) revert PW.InvalidPlatformEvidence(hash);
        e = abi.decode(payload, (PW.Evidence));
        if (
            e.schemaVersion != 1 || e.collectionId != id || e.narrativeHash == 0
                || keccak256(abi.encode(e)) != hash
        ) revert PW.InvalidPlatformEvidence(hash);
        address provider = IStreamArtistEstateBinding(s.registry).archivalCoverage();
        if (
            provider.code.length == 0
                || provider.codehash
                    != IStreamArtistEstateBinding(s.registry).archivalCoverageCodeHash()
        ) revert PW.InvalidPlatformEvidence(hash);
        A.CoverageFacts memory f =
            IStreamCollectionArchivalCoverage(provider).requireCollectionEvidence(id, hash);
        if (
            f.coverageRecordHash == 0 || f.artistId != 0 || f.evidenceHash != hash
                || f.envelopeHash == 0
        ) {
            revert PW.InvalidPlatformEvidence(hash);
        }
        proof = keccak256(abi.encode(store, store.codehash, hash, f));
    }
}
