// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryCompositionFixture.sol";

contract StreamArtistCompleteHistoryCompositionActualTest is
    ArtistCompleteHistoryCompositionFixture
{
    function testCompleteCompositionActualNewBPendingWithHistoricalCollaboratorAndUnboundSibling()
        external
    {
        (CHAdmissionType.Certificate memory c, bytes32 latest) = _compositionSource();
        (CHPrincipals.Result memory principals, CHComposition.Result memory result) = _compose(c);
        require(c.artists.length == 3 && c.collections.length == 3, "whole source graph");
        require(principals.principals.identities.length == 3, "all actual principal bundles");
        for (uint256 i; i < principals.principals.identities.length; ++i) {
            require(
                this.recoveries(principals.principals.identities[i]) == 0,
                "ordinary zero recoveries"
            );
        }
        require(
            result.inventory.bindings.bindings[1].bindings.rows[0].item.artistId == artistId
                && result.inventory.bindings.bindings[1].bindings.current.artistId == latest
                && latest != artistId && latest != collaboratorId,
            "former A and genuinely newly registered B remain distinct"
        );
        require(
            !result.inventory.bindings.bindings[1].bindings.current.accepted
                && result.inventory.bindings.bindings[1].bindings.rows[0].terminal.kind == 1,
            "original refusal followed by actual latest pending correction"
        );
        require(
            result.inventory.archive.accepted.length == 1
                && result.inventory.archive.accepted[0].join.artistId == collaboratorId
                && result.inventory.accepted[1].rows[0].recordHash == 0
                && result.inventory.accepted[1].rows[1].recordHash == 0,
            "real partial collaborator join never creates primary acceptance"
        );
        require(
            result.inventory.bindings.bindings[1].corrections[1].approval.registrationNonce == 2,
            "new B keeps authentic global allocation two"
        );
        require(
            result.inventory.bindings.generations[2].length == 0
                && result.inventory.platforms[2].state.declaration.recordHash != 0
                && result.inventory.accepted[2].rows.length == 0,
            "original unbound sibling creates no generation or acceptance"
        );
        require(
            result.bindings.length == 3 && result.accepted.length == 3
                && result.consents.length == 3 && result.attribution.length == 3,
            "every collection has all complete family rows"
        );
        require(
            (result.features & (CHType.FEATURE | RH.HISTORY_PLATFORM | RH.BINDING_CORRECTIONS))
                    == (CHType.FEATURE | RH.HISTORY_PLATFORM | RH.BINDING_CORRECTIONS)
                && (result.features & ~CHType.ALLOWED) == 0,
            "actual composed feature union"
        );
        M.State memory scope = _compositionScope(c);
        scope.rows = result.attribution;
        CHAttributionProof.validate(scope, RH.ownerProvenance(c.provenance, 4), result.inventory);
    }

    function testCompleteCompositionActualRejectsTamperedFamilyAtFixedRereadAndRestores() external {
        (CHAdmissionType.Certificate memory c,) = _compositionSource();
        (, CHComposition.Result memory result) = _compose(c);
        bytes32 complete = keccak256(abi.encode(result));
        M.State memory scope = _compositionScope(c);
        scope.rows = result.attribution;
        bytes memory saved = scope.rows[1];
        CHMD.Attribution memory changed = abi.decode(saved, (CHMD.Attribution));
        require(changed.history.current.state == 1, "actual source still pending");
        // Keep the two encoded current-state views mutually consistent. The actual owner
        // reread must reject this invented accepted state, not just a wrapper disagreement.
        changed.history.current.state = 2;
        changed.records.item.state = 2;
        scope.rows[1] = abi.encode(changed);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHAttributionProof.validate(scope, RH.ownerProvenance(c.provenance, 4), result.inventory);
        scope.rows[1] = saved;
        CHAttributionProof.validate(scope, RH.ownerProvenance(c.provenance, 4), result.inventory);
        (, CHComposition.Result memory restored) = _compose(c);
        require(keccak256(abi.encode(restored)) == complete, "full fixed composition unchanged");
    }
}
