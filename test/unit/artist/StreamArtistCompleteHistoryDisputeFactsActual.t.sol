// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistAttributionDisputeFixture.sol";
import {
    StreamArtistCompleteHistoryDisputeFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryDisputeFacts.sol";
import {
    StreamArtistRecoveredDisputeHistoryRowFacts as OldFacts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryRowFacts.sol";
import {
    StreamArtistRecoveredDisputeHistoryChains as Chains
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryChains.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as CHD
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as CHRH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as BG
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as AG
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistBindingCorrectionState as CS
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistBindingCorrectionAdmission as CorrectionAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection as Correction,
    IStreamArtistBindingCorrectionOwner as CorrectionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistNativeReceipts as Native
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistCollaboratorRecordsOwner as Joins
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";

interface CompleteHistoryDisputeVm {
    function prank(address) external;
}

/// @notice Original producers exercise standing and latest-state family joins.
/// @dev The inherited Core/governance boundaries remain explicit. Clock points and records
/// are read from actual owners; these focused leaves do not claim a full provenance/import proof.
contract StreamArtistCompleteHistoryDisputeFactsActualTest is ArtistAttributionDisputeFixture {
    struct Observed {
        CHD.Bundle history;
        PC.BindingInventory bindings;
        PC.Inventory archive;
        CHRH.OwnerProvenance provenance;
        G.Timeline timeline;
    }

    uint64[] private proposals;
    uint64[] private completions;

    function testCompleteDisputeGovernedPendingCounterKeepsOriginalEligibility() external {
        _begin();
        AD.Filing memory filing = _filing(1, keccak256("governed pending opening"));
        AD.Standing memory empty;
        T.Authorization memory authorization;
        _govern(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute,
                (filing, empty, authorization)
            ),
            ingress.attributionDisputeOpeningContext(filing),
            filing.reasonHash,
            1
        );
        bytes32 counter = _counter(keccak256("pending primary counter"));
        Observed memory x = _observe();
        CHD.DisputeRow memory row = _find(x.history, counter);
        require(!x.history.generations[0].accepted, "genuinely pending original binding");
        _check(x, row, 9);
        Chains.validateGenerationChains(x.history, x.provenance);
        Facts.current(x.history, x.bindings.bindings[0]);
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        OldFacts.dispute(x.history, row, x.provenance);
        row.record.standing.collaboratorIndex = 1;
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Facts.dispute(x.history, row, x.provenance, x.bindings, x.archive, x.timeline, 0, 9);
    }

    function testCompleteDisputeActualLatestWithdrawalDoesNotInventRevocation() external {
        _begin();
        ingress.withdrawArtistBinding(_termination(1));
        completions[0] = _revision();
        Observed memory x = _observe();
        require(
            x.history.current.state == 5 && x.history.heads[0].revocationReason == 0,
            "original binding terminal"
        );
        Chains.validateGenerationChains(x.history, x.provenance);
        Facts.current(x.history, x.bindings.bindings[0]);
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Chains.validate(x.history, x.provenance);
        x.bindings.bindings[0].bindings.rows[0].terminal.kind = 0;
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Facts.current(x.history, x.bindings.bindings[0]);
    }

    function testCompleteDisputeAcceptedCollaboratorRequiresOriginalJoinAndEarlierArchivePosition()
        external
    {
        _begin();
        _collaboratorIdentity(false);
        C.BindingAcceptance memory acceptance = _collaborativeProposal(false);
        proposals.push(_revision());
        completions.push(0);
        _collaboratorAcceptance(acceptance, false);
        _accept();
        completions[1] = _revision();
        AD.Filing memory filing = _filing(1, keccak256("accepted collaborator standing"));
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint, 2000, ""
        );
        authorization.signature =
            _delegateSignature(ingress.attributionDisputeDigest(filing, authorization));
        bytes32 opening = ingress.openAttributionDispute(
            filing, AD.Standing(collaboratorId, acceptance.generation, 0, 0), authorization
        );
        Observed memory x = _observe();
        x.archive.accepted = new PC.AcceptedRow[](1);
        x.archive.accepted[0].acceptance = acceptance;
        x.archive.accepted[0].join = Joins(suite.owners[1])
            .acceptedRow(
                acceptance.bindingHash, acceptance.account, acceptance.role, acceptance.shareLabelId
            );
        // Explicit family boundary: full Catalogue authentication supplies these positions.
        x.archive.accepted[0].operationIndex = 6;
        CHD.DisputeRow memory row = _find(x.history, opening);
        require(
            row.record.artistId == artistId && row.record.standing.artistId == collaboratorId,
            "bound Artist differs from original author"
        );
        _check(x, row, 9);
        x.archive.accepted[0].operationIndex = 9;
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Facts.dispute(x.history, row, x.provenance, x.bindings, x.archive, x.timeline, 0, 9);
        x.archive.accepted[0].operationIndex = 6;
        x.archive.accepted[0].join.artistId = artistId;
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Facts.dispute(x.history, row, x.provenance, x.bindings, x.archive, x.timeline, 0, 9);
    }

    function testCompleteDisputeOriginalArtistSurvivesCorrectionToDifferentPendingPrincipal()
        external
    {
        _begin();
        _accept();
        completions[0] = _revision();
        bytes32 opening = _open(keccak256("former original bound Artist"));
        _resolve(_resolution(2, keccak256("class2 original revocation")), 2);
        _correctNew();
        proposals.push(_revision());
        completions.push(0);
        Observed memory x = _observe();
        CHD.DisputeRow memory row = _find(x.history, opening);
        require(
            x.history.artistId != row.record.artistId && row.record.artistId == artistId,
            "genuine per-generation Artist"
        );
        _check(x, row, 9);
        Facts.current(x.history, x.bindings.bindings[0]);
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        OldFacts.dispute(x.history, row, x.provenance);
        x.bindings.bindings[0].bindings.rows[0].item.artistId = x.history.artistId;
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Facts.dispute(x.history, row, x.provenance, x.bindings, x.archive, x.timeline, 0, 9);
    }

    function testCompleteDisputeFormerAcceptedArtistRetainsOriginalOpeningStanding() external {
        _begin();
        _accept();
        completions[0] = _revision();
        _open(keccak256("former accepted Artist first opening"));
        _resolve(_resolution(2, keccak256("former accepted Artist class2 revocation")), 2);
        _correctNew();
        proposals.push(_revision());
        completions.push(0);
        T.Binding memory current = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        T.Authorization memory acceptance = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(current.artistId).nonceHint, 0, ""
        );
        CompleteHistoryDisputeVm(address(avm)).prank(address(0xB0B));
        ingress.acceptArtistBinding(1, acceptance);
        completions[1] = _revision();
        AD.Filing memory filing = _filing(1, keccak256("genuine former Artist standing"));
        bytes32 opening = ingress.openAttributionDispute(
            filing, AD.Standing(artistId, 1, 0, 0), _signed(filing)
        );
        Observed memory x = _observe();
        CHD.DisputeRow memory row = _find(x.history, opening);
        require(
            row.record.artistId == current.artistId && row.record.standing.artistId == artistId,
            "actual former accepted Artist is the original author"
        );
        _check(x, row, 12);
        x.bindings.bindings[0].bindings.rows[0].item.accepted = false;
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Facts.dispute(x.history, row, x.provenance, x.bindings, x.archive, x.timeline, 0, 12);
    }

    function _check(Observed memory x, CHD.DisputeRow memory row, uint256 operationIndex)
        private
        pure
    {
        Facts.dispute(
            x.history, row, x.provenance, x.bindings, x.archive, x.timeline, 0, operationIndex
        );
    }

    function _begin() private {
        proposals.push(_revision());
        completions.push(0);
    }

    function _revision() private view returns (uint64) {
        return Owner(suite.owners[4]).ownerStateSnapshotV2().revision;
    }

    function _correctNew() private {
        bytes memory document = bytes("different complete-history Artist document");
        T.BindingProposal memory proposal = _proposal(0);
        proposal.artistAddress = address(0xB0B);
        proposal.identityRecordHash = keccak256(document);
        proposal.identityRecordURI = "urn:complete:dispute:artist-b";
        proposal.reasonHash = keccak256("original governed A to B correction");
        (BC.Context memory c,) =
            CorrectionAdmission.context(suite, 1, proposal, document, "Artist B", 0);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        _govern(
            abi.encodeCall(
                Correction.proposeArtistBindingAfterRevocation,
                (uint256(1), proposal, document, "Artist B", bytes32(0))
            ),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            proposal.reasonHash,
            2
        );
    }

    function _observe() private view returns (Observed memory x) {
        CHRH.OriginEnvironment memory origin;
        origin.chainId = block.chainid;
        origin.registry = address(ingress);
        origin.core = address(core);
        origin.manager = address(manager);
        origin.owners = suite.owners;
        for (uint8 i; i < 7; ++i) {
            origin.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        bytes32 env = CHRH.originHash(origin);
        x.provenance.origins = new CHRH.OriginEnvironment[](1);
        x.provenance.origins[0] = origin;
        x.provenance.eras = new CHRH.OwnerEra[](1);
        x.provenance.eras[0].originHash = env;
        x.provenance.eras[0].checkpoint = CP(suite.owners[4]).authorityCheckpoint();
        CB.Bundle memory binding;
        binding.bindings.current = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        uint256 n = binding.bindings.current.generation;
        binding.bindings.collectionId = 1;
        binding.bindings.artistId = binding.bindings.current.artistId;
        binding.bindings.bindingHash = binding.bindings.current.bindingHash;
        binding.bindings.rows = new BG.Row[](n);
        binding.corrections = new CS.Correction[](n);
        x.bindings.collaborators = new T.CollaboratorRecord[][][](1);
        x.bindings.collaborators[0] = new T.CollaboratorRecord[][](n);
        x.history.collectionId = 1;
        x.history.artistId = binding.bindings.artistId;
        x.history.bindingHash = binding.bindings.bindingHash;
        (x.history.current.state, x.history.current.generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(1);
        x.history.generations = new AG.Generation[](n);
        x.history.heads = new AD.Head[](n);
        x.timeline.attributionProposals = new CHRH.Point[](n);
        x.timeline.attributionCompletions = new CHRH.Point[](n);
        for (uint256 i; i < n; ++i) {
            uint64 g = uint64(i + 1);
            binding.bindings.rows[i] = BG.Row(
                IStreamArtistBindingOwner(suite.owners[0]).bindingAt(1, g),
                Terms(suite.owners[0]).bindingTerms(1, g),
                ingress.bindingTermination(1, g)
            );
            (binding.corrections[i].approval, binding.corrections[i].recordHash) = CorrectionOwner(
                    suite.owners[0]
                ).bindingCorrection(binding.bindings.rows[i].item.bindingHash);
            x.history.generations[i].generation = g;
            x.history.generations[i].bindingHash = binding.bindings.rows[i].item.bindingHash;
            x.history.generations[i].accepted = binding.bindings.rows[i].item.accepted;
            x.history.heads[i] = ingress.attributionDispute(1, g);
            x.timeline.attributionProposals[i] = CHRH.Point(env, 4, proposals[i]);
            if (completions[i] != 0) {
                x.timeline.attributionCompletions[i] = CHRH.Point(env, 4, completions[i]);
            }
            uint256 count = binding.bindings.rows[i].terms.count;
            x.bindings.collaborators[0][i] = new T.CollaboratorRecord[](count);
            for (uint256 j; j < count; ++j) {
                x.bindings.collaborators[0][i][j] = Terms(suite.owners[0]).collaboratorTerm(1, g, j);
            }
        }
        x.bindings.bindings = new CB.Bundle[](1);
        x.bindings.bindings[0] = binding;
        uint256 count = Native(suite.owners[4]).artistNativeReceiptCount();
        x.history.disputes = new CHD.DisputeRow[](count);
        uint256 at;
        for (uint256 i; i < count; ++i) {
            uint16 op = Native(suite.owners[4]).artistNativeReceiptAt(i).operation;
            if (op != 44 && op != 45 && op != 61) continue;
            x.history.disputes[at].record = ingress.attributionDisputeRecord(
                Native(suite.owners[4]).artistNativeReceiptAt(i).recordHash
            );
            x.history.disputes[at].point =
                CHRH.Point(env, 4, NativeClock(suite.owners[4]).artistNativeReceiptRevisionAt(i));
            ++at;
        }
        CHD.DisputeRow[] memory rows = x.history.disputes;
        assembly ("memory-safe") { mstore(rows, at) }
    }

    function _find(CHD.Bundle memory b, bytes32 record)
        private
        pure
        returns (CHD.DisputeRow memory)
    {
        for (uint256 i; i < b.disputes.length; ++i) {
            if (b.disputes[i].record.recordHash == record) {
                return b.disputes[i];
            }
        }
        revert("missing original native dispute");
    }
}
