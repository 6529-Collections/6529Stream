// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistSanction.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";

/// @notice Saved sanction verification, separate from current signing and producer preparation.
/// @dev Authority rotation, succession and Identity contest do not rewrite this historical authorship.
library StreamArtistSanctionReads {
    function currentRecord(T.SuiteConfiguration memory suite, StreamFinalityScope memory scope)
        public
        view
        returns (S.Record memory r)
    {
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(scope.collectionId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(scope.collectionId);
        if (
            !b.accepted || b.artistId == 0 || b.bindingHash == 0 || generation != b.generation
                || (state != 2 && state != 3)
        ) return r;
        IStreamArtistSanctionOwner owner = IStreamArtistSanctionOwner(suite.owners[6]);
        bytes32 hash = owner.sanctionForAssociation(
            b.artistId,
            generation,
            b.bindingHash,
            uint8(scope.scopeType),
            scope.collectionId,
            scope.tokenId,
            scope.scopeId
        );
        if (hash == 0) return r;
        r = owner.sanctionRecord(hash);
        if (
            r.recordHash != hash || r.artistId != b.artistId || r.bindingGeneration != generation
                || r.bindingHash != b.bindingHash || r.terms.scopeType != uint8(scope.scopeType)
                || r.terms.collectionId != scope.collectionId || r.terms.tokenId != scope.tokenId
                || r.terms.scopeId != scope.scopeId
        ) revert S.InvalidSanction();
    }

    function verify(
        T.SuiteConfiguration memory suite,
        uint8 scopeType,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 subject
    ) public view returns (bool valid, bytes32 recordHash, address signer, uint8 authorityClass) {
        if (scopeType > 4 || subject == 0) return (false, 0, address(0), 0);
        S.Record memory r = currentRecord(
            suite,
            StreamFinalityScope(StreamFinalityScopeType(scopeType), collectionId, tokenId, scopeId)
        );
        valid = r.recordHash != 0 && r.terms.sanctionSubjectHash == subject;
        return (valid, r.recordHash, r.signer, r.authorityClass);
    }

    function component(T.SuiteConfiguration memory suite, StreamFinalityScope memory scope)
        public
        view
        returns (StreamFinalityComponentState memory result)
    {
        S.Record memory r = currentRecord(suite, scope);
        (, bytes32 manifestHash) = IStreamModule(suite.registry).streamModuleManifest();
        result = StreamFinalityComponentState(
            r.recordHash != 0,
            keccak256("ARTIST_SANCTION"),
            suite.registry,
            scope.scopeType == StreamFinalityScopeType.COLLECTION
                ? type(IStreamArtworkFinalityComponent).interfaceId
                : type(IStreamArtworkScopedFinalityComponent).interfaceId,
            suite.registry.codehash,
            IStreamModule(suite.registry).streamModuleVersion(),
            manifestHash,
            r.recordHash
        );
    }

    function componentType(T.SuiteConfiguration memory suite, uint256 collectionId)
        public
        view
        returns (bytes32)
    {
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(collectionId);
        if (b.artistId == 0) revert T.UnsupportedProfile();
        return keccak256("ARTIST_SANCTION");
    }
}
