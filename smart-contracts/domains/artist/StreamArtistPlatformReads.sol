// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";

/// @notice A declaration is a historical fact, never an Artist signature or accepted binding.
library StreamArtistPlatformReads {
    function state(T.SuiteConfiguration memory s, uint256 id)
        public
        view
        returns (PW.State memory)
    {
        return IStreamArtistPlatformOwner(s.owners[4]).platformWorksState(id);
    }

    function admission(T.SuiteConfiguration memory s, uint256 id)
        public
        view
        returns (PW.Admission memory)
    {
        return IStreamArtistPlatformOwner(s.owners[4]).platformWorksAdmission(id);
    }

    function mintAllowed(PW.Admission memory p, uint256 id) public pure {
        if (
            p.declarationHash == 0 || p.contestState == 1 || p.contestState == 3
                || p.correctiveGeneration != 0
        ) {
            revert PW.InvalidPlatformWorks(id);
        }
    }

    function finalized(T.SuiteConfiguration memory s, StreamFinalityScope memory scope)
        public
        view
        returns (bool)
    {
        address registry = IStreamArtistFinalityBinding(s.registry).finalityRegistry();
        if (
            registry.code.length == 0
                || registry.codehash
                    != IStreamArtistFinalityBinding(s.registry).finalityRegistryCodeHash()
        ) revert T.ComponentChanged(registry);
        IStreamArtworkFinalityRegistry f = IStreamArtworkFinalityRegistry(registry);
        bool collection = scope.scopeType == StreamFinalityScopeType.COLLECTION;
        if (collection
                ? !f.collectionFinalityRecord(scope.collectionId).finalized
                : !f.artworkScopeFinalityRecord(scope).finalized) return false;
        uint256 count = collection
            ? f.finalityComponentCount(scope.collectionId)
            : f.finalityComponentCountForScope(scope);
        if (count == 0 || count > 64) revert T.InvalidRecord();
        StreamFinalityComponentExpectation[] memory rows = collection
            ? f.finalityComponents(scope.collectionId, 0, count)
            : f.finalityComponentsForScope(scope, 0, count);
        if (rows.length != count) revert T.InvalidRecord();
        bytes32 declaration = state(s, scope.collectionId).declaration.recordHash;
        for (uint256 i; i < count; ++i) {
            if (
                rows[i].component == s.registry
                    && rows[i].componentType == keccak256("PLATFORM_WORKS_DECLARATION")
            ) {
                if (declaration == 0 || rows[i].dataHash != declaration) revert T.InvalidRecord();
                return true;
            }
        }
        return false;
    }
}
