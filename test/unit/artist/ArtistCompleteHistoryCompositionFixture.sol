// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryIdentityFixture.sol";
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
abstract contract ArtistCompleteHistoryCompositionFixture is ArtistCompleteHistoryIdentityFixture {
    function _compositionSource()
        internal
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
        internal
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
        internal
        pure
        returns (M.State memory scope)
    {
        scope.artists = c.artists;
        scope.collections = c.collections;
    }
}
