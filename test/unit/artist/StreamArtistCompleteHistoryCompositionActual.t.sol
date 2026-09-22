// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistCompleteHistoryIdentityActual.t.sol";
import {
    StreamArtistCompleteHistoryComposition as CHComposition
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryComposition.sol";
import {
    StreamArtistCompleteHistoryWitnesses as CHWitnesses
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryWitnesses.sol";
import {
    StreamArtistCompleteHistoryAttributionProof as CHAttributionProof
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAttributionProof.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as CHMD
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeTypes.sol";

/// @notice Actual original owners/Archive/Safe correction and collaborator history feed every family.
/// @dev Source-composition scenarios, unexecuted until the combined native cohort runs. The inherited
/// Core and scheduled governance are unit boundaries; no op60 admission or import is claimed here.
contract StreamArtistCompleteHistoryCompositionActualTest is
    StreamArtistCompleteHistoryIdentityActualTest
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

    function _compositionSource()
        private
        returns (CHAdmissionType.Certificate memory c, bytes32 latest)
    {
        latest = _historyWithPartial(false, true);
        // The inherited Core stub knows only collections1/2. Extend only that explicit
        // fixture boundary; original Platform owners, receipt, Archive and replay are real.
        avm.mockCall(
            address(core), abi.encodeWithSignature("collectionExists(uint256)", 3), abi.encode(true)
        );
        bytes32 declaration =
            ingress.declarePlatformWorks(3, keccak256("actual unbound composition sibling"));
        require(declaration != 0, "original declaration written");
        _rhCandidate(4, string(abi.encode("PLATFORM_WORKS", uint16(8))), bytes32(uint256(3)));
        RH.Request memory request = _rhRequest();
        c.prior = address(ingress);
        c.sourceCoordinator = address(coordinator);
        c.source = suite;
        c.provenance = CHProvenance.collect(
            suite, address(coordinator), request.records.authority.replayOrigins
        );
        MH.Request memory selected;
        selected.artistIds = new bytes32[](3);
        selected.artistIds[0] = artistId;
        selected.artistIds[1] = collaboratorId;
        selected.artistIds[2] = latest;
        for (uint256 i; i < selected.artistIds.length; ++i) {
            for (uint256 j; j < i; ++j) {
                if (selected.artistIds[i] < selected.artistIds[j]) {
                    (selected.artistIds[i], selected.artistIds[j]) =
                    (selected.artistIds[j], selected.artistIds[i]);
                }
            }
        }
        selected.collections = new MH.Collection[](3);
        T.Binding[] memory heads = new T.Binding[](3);
        for (uint256 k; k < 3; ++k) {
            heads[k] = Binding(suite.owners[0]).binding(k + 1);
            selected.collections[k] = MH.Collection(heads[k].artistId, k + 1, new AH.PolicyKey[](0));
        }
        M.State memory scope = CHScope.partition(selected, heads, c.provenance);
        c.artists = scope.artists;
        c.collections = scope.collections;
    }

    function _compose(CHAdmissionType.Certificate memory c)
        private
        view
        returns (CHPrincipals.Result memory principals, CHComposition.Result memory result)
    {
        principals = CHPrincipals.collect(c);
        CHWitnesses.Plan memory witnesses = CHWitnesses.collect(
            c.source,
            c.provenance,
            _compositionScope(c),
            _rhRequest().records.witnesses,
            new T.RoyaltyFreeze[](0)
        );
        result = CHComposition.collect(
            CHComposition.Context(c, principals.principals, witnesses, principals.features)
        );
    }

    function _compositionScope(CHAdmissionType.Certificate memory c)
        private
        pure
        returns (M.State memory scope)
    {
        scope.artists = c.artists;
        scope.collections = c.collections;
    }
}
