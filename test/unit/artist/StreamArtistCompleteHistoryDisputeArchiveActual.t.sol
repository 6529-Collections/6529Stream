// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredDisputeHistoryFixture.sol";
import {
    StreamArtistCompleteHistoryTypes as CHT
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistorySource as CHSource
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistorySource.sol";
import {
    StreamArtistCompleteHistoryScope as CHScope
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistRecoveredHydrationSource as CHProvenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationSource.sol";
import {
    StreamArtistCompleteHistoryCatalogue as CHCatalogue
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryDisputeSource as CHDisputes
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryDisputeSource.sol";
import {
    StreamArtistCompleteHistoryDisputeArchive as CHArchive
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryDisputeArchive.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as CHClocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredMultipleTypes as CHM
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as CHH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistIdentityContestTypes as CHContest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";

/// @notice Actual immutable Archive evidence for pending resolution followed by acceptance.
/// @dev Core, documentary coverage and governance admission retain the inherited fixture
/// boundaries. No Archive bytes, source lineage, owner record or completion point is forged.
contract StreamArtistCompleteHistoryDisputeArchiveActualTest is
    ArtistRecoveredDisputeHistoryFixture
{
    function testCompleteArchivePendingResolutionThenAcceptancePreservesOriginalAcceptedFlag()
        external
    {
        _pendingResolved();
        _baseline();
        RH.Request memory request = _rhRequest();
        RH.Provenance memory provenance = CHProvenance.collect(
            suite, address(coordinator), request.records.authority.replayOrigins
        );
        T.Binding[] memory heads = new T.Binding[](1);
        heads[0] = Binding(suite.owners[0]).binding(1);
        CHM.State memory scope = CHScope.partition(request.records.authority, heads, provenance);
        (CHT.Inventory memory inventory, CHClocks.Result memory clocks) =
            CHSource.collect(scope, provenance);
        D.Bundle[] memory rows = CHDisputes.collect(
            suite.owners[4], scope, provenance, inventory.bindings, inventory.archive, clocks
        );
        RH.OwnerProvenance memory owner4 = RH.ownerProvenance(provenance, 4);
        CHArchive.validate(rows, owner4, inventory, clocks);
        require(
            rows.length == 1 && rows[0].resolutions.length == 1, "one actual original resolution"
        );
        require(heads[0].accepted && heads[0].generation == 1, "same generation accepted later");
        require(
            clocks.clocks.collections[0].attributionCompletions[0].ownerRevision
                > rows[0].resolutions[0].point.ownerRevision,
            "actual Archive completion follows the original resolution"
        );
        bytes memory original = _resolutionPayload(inventory);
        bytes memory mutant = _acceptedPayload(original);
        CHArchive.resolution(
            rows[0].resolutions[0].record,
            rows[0],
            inventory,
            clocks,
            owner4,
            rows[0].resolutions[0].point,
            0,
            original
        );
        // The mutant is independently canonical ABI. It changes only the claimed accepted
        // flag and is checked against the authentic timeline, outside the immutable Archive.
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHArchive.resolution(
            rows[0].resolutions[0].record,
            rows[0],
            inventory,
            clocks,
            owner4,
            rows[0].resolutions[0].point,
            0,
            mutant
        );
        require(
            keccak256(_resolutionPayload(inventory)) == keccak256(original),
            "original Archive untouched"
        );
        CHArchive.validate(rows, owner4, inventory, clocks);
    }

    function _pendingResolved() private {
        T.Binding memory binding_ = Binding(suite.owners[0]).binding(1);
        require(!binding_.accepted && binding_.generation == 1, "original pending source");
        bytes32 evidence = _evidence(0, keccak256("pending original governed opening"));
        AD.Filing memory filing = AD.Filing(1, 1, 1, evidence, evidence);
        AD.Standing memory standing;
        T.Authorization memory authorization;
        bytes32 action = _govern(
            abi.encodeCall(Disputes.openAttributionDispute, (filing, standing, authorization)),
            ingress.attributionDisputeOpeningContext(filing),
            evidence,
            1
        );
        _rhCandidate(
            4,
            "attribution_lifecycle.replay.dispute_key",
            keccak256(
                abi.encode(uint256(1), uint64(1), bytes32(0), address(artist), evidence, evidence)
            )
        );
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", action);
        _resolve(1, 1);
        require(
            !Binding(suite.owners[0]).binding(1).accepted, "resolution restores pending binding"
        );
    }

    function _resolutionPayload(CHT.Inventory memory inventory)
        private
        view
        returns (bytes memory)
    {
        for (uint256 i; i < inventory.archive.operations.length; ++i) {
            CHH.OperationEvidence memory row = inventory.archive.operations[i];
            if (row.operation != 46) continue;
            return CHCatalogue.read(
                inventory.provenance.origins[0], inventory.archive.catalogues[0], row.evidence
            )
            .payload;
        }
        revert("missing authentic original46");
    }

    function _acceptedPayload(bytes memory raw) private pure returns (bytes memory) {
        (
            AD.ResolutionRequest memory terms,
            T.Binding memory binding_,
            AD.Context memory context,
            CHContest.GovernanceWitness memory governance,
            bytes32 evidence,
            bytes32 reason
        ) = abi.decode(
            raw,
            (
                AD.ResolutionRequest,
                T.Binding,
                AD.Context,
                CHContest.GovernanceWitness,
                bytes32,
                bytes32
            )
        );
        require(!binding_.accepted, "original46 captured pending flag");
        require(
            keccak256(raw)
                == keccak256(abi.encode(terms, binding_, context, governance, evidence, reason)),
            "canonical original46"
        );
        binding_.accepted = true;
        return abi.encode(terms, binding_, context, governance, evidence, reason);
    }
}
