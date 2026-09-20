// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentPreservationSuccession.t.sol";
import {
    StreamArtistCurrentAuthorityResolver
} from "../../smart-contracts/domains/preservation/StreamArtistCurrentAuthorityResolver.sol";
import {
    StreamArtistCurrentAuthorityTypes as Authority
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";

/// @notice Actual Core/Safe/Metadata/Coordinator and seven-owner import exercise the resolver.
/// @dev This keeps the fixture's legacy Finality to prove it is NOT silently upgraded. Full
/// capability-aware original Finality deployment, later C and finalization are separate recipes.
contract StreamCurrentAuthoritySelectionTest is StreamCurrentPreservationSuccessionFixture {
    function _resolver() private returns (StreamArtistCurrentAuthorityResolver resolver) {
        Authority.Anchors memory a;
        a.targets = [
            address(core),
            address(assemblyMetadata),
            address(router),
            address(artists),
            address(assemblyProvider)
        ];
        for (uint256 i; i < 5; ++i) {
            a.codeHashes[i] = a.targets[i].codehash;
        }
        a.finalityRegistry = address(assemblyFinality);
        a.chainId = block.chainid;
        a.readGas = 500000;
        resolver = new StreamArtistCurrentAuthorityResolver(a);
    }

    function testActualSameResolverAuthenticatesAThenCompletedSafeHydratedB() public {
        _seedOriginalPublication();
        StreamArtistCurrentAuthorityResolver resolver = _resolver();
        Authority.Anchors memory fixedBefore = resolver.anchors();
        Authority.Selection memory a = resolver.currentSelection();
        require(
            a.origin.environment.registry == address(artists) && a.completion == 0,
            "actual original A has no hydration marker"
        );
        bytes32 sourceBefore = _state(artistSuite);
        _migrate();
        Authority.Selection memory b = resolver.currentSelection();
        require(
            b.origin.environment.registry == address(successor)
                && b.origin.environment.coordinator == address(successorCoordinator)
                && b.origin.environment.suiteConfigurationHash == keccak256(abi.encode(destination))
                && b.completion != 0 && b.selectionHash != a.selectionHash,
            "actual hydrated successor selected"
        );
        require(
            keccak256(abi.encode(fixedBefore)) == keccak256(abi.encode(resolver.anchors())),
            "original anchors unchanged by cutover"
        );
        require(
            assemblyMetadata.artistRegistry() == address(artists)
                && address(assemblyFinality.sanctionReads()) == address(artists),
            "original getters remain A"
        );
        require(
            keccak256(
                IStreamArtistArchiveV2(artistSuite.archive)
                    .artistEvidenceBytesV2(original.archiveId, 1)
            ) == keccak256(original.archiveBytes),
            "original Archive bytes retained"
        );
        bytes32 afterSource = _state(artistSuite);
        bytes32 afterCurrent = _state(destination);
        resolver.currentSelection();
        require(
            _state(artistSuite) == afterSource && _state(destination) == afterCurrent,
            "resolution changes neither semantic owner graph"
        );
        require(sourceBefore != 0, "source state captured before actual cutover");
    }

    function testActualIncompleteCutoverRefusesSelectionUntilAllSevenOwnersHydrated() public {
        _seedOriginalPublication();
        StreamArtistCurrentAuthorityResolver resolver = _resolver();
        _cutover();
        (bool ok,) = address(resolver).staticcall(abi.encodeCall(resolver.currentSelection, ()));
        require(!ok, "governed pointer alone cannot authorize successor");
        (MigrationHydration.Request memory request, Commit.Prepared memory prepared) = _prepared();
        _safeCall(
            address(successor),
            abi.encodeCall(MigrationRecovered.hydrateRecoveredArtistAuthority, (request))
        );
        _assertImported(prepared);
        Authority.Selection memory selected = resolver.currentSelection();
        require(
            selected.origin.environment.registry == address(successor) && selected.completion != 0,
            "same resolver succeeds after genuine atomic completion"
        );
        (ok,) = address(resolver)
            .staticcall(abi.encodeCall(resolver.currentFinalityRoute, (uint256(1))));
        require(!ok, "legacy Finality cannot claim additive route capability");
    }
}
