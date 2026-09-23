// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistPrimaryCollaboratorAcceptance as PCAcceptance
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAcceptance.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as PCClocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";

/// @notice Actual owner/Archive/Safe scenarios, with inherited Core/governance unit boundaries.
/// @dev Authored and typechecked only until separately pinned native execution.
contract StreamArtistPrimaryCollaboratorActualTest is ArtistPrimaryCollaboratorFixture {
    function testPrimaryCollaboratorRepeatedPrimaryThenLastOp7CompletesAndImports() external {
        _pcSource(0);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        (PC.Proof memory proof, M.State memory scope) = _pcProof(p, 0);
        PCSource.Result memory observed = PCSource.requireCurrent(scope, proof);
        require(
            pcPrimary.length == 2 && pcPrimary[0] != pcPrimary[1],
            "two authentic partial primary records"
        );
        require(
            observed.clocks.primary.length == 3
                && observed.clocks.finalPrimary[1][0] == pcPrimary[1],
            "all occurrences retained, latest map exact"
        );
        require(
            observed.clocks.clocks.collections[1].attributionCompletions[0].ownerRevision
                > observed.clocks.clocks.collections[1].attributionProposals[0].ownerRevision,
            "last op7 completes under original owner4 clock"
        );
        require(
            proof.accepted[1].rows[0].recordHash == pcPrimary[1],
            "only genuine latest primary receipt has saved time"
        );
        _pcImport(next, r, p);
    }

    function testPrimaryCollaboratorFirstThenOp2CompletesWithoutDoubleAdvancingClock() external {
        _pcSource(1);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        (PC.Proof memory proof, M.State memory scope) = _pcProof(p, 0);
        PCSource.Result memory observed = PCSource.requireCurrent(scope, proof);
        require(
            observed.clocks.primary.length == 2 && observed.clocks.accepted[1][0] == 1,
            "authentic primary and collaborator rows"
        );
        require(observed.clocks.clocks.counts[0] == 4, "exact two proposals and two completions");
        _pcImport(next, r, p);
    }

    function testPrimaryCollaboratorPartialRefusedRowSurvivesAcceptedReplacement() external {
        _pcSource(2);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        (PC.Proof memory proof,) = _pcProof(p, 3);
        require(
            proof.accepted[1].rows.length == 2 && proof.accepted[1].rows[0].recordHash == 0
                && proof.accepted[1].rows[0].acceptedAt == 0,
            "no fabricated primary record or timestamp for refused partial generation"
        );
        require(
            proof.archive.accepted.length == 2
                && proof.bindings.bindings[1].bindings.rows[0].terminal.kind == 1,
            "original partial row and refusal retained"
        );
        _pcImport(next, r, p);
    }

    function testPrimaryCollaboratorSourceCheckpointDriftRestoresSameRequest() external {
        _pcSource(0);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        bytes32 before_ = _pcDestination(next);
        ++r.records.authority.expectedSource[1].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(_pcDestination(next) == before_, "all collaborator and owner state unchanged");
        --r.records.authority.expectedSource[1].ownerState.revision;
        _pcImport(next, r, p);
    }

    function testPrimaryCollaboratorActualLateArchiveRollsBackSafeAndEveryMap() external {
        _pcSource(2);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        bytes32 before_ = _pcDestination(next);
        uint256 block_ = block.number;
        uint256 nonce = rotationSafe.nonce();
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(_pcDestination(next) == before_, "actual late Archive reverts all original maps");
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(
            address(next.registry), abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r))
        );
        require(
            rotationSafe.nonce() == nonce && _pcDestination(next) == before_,
            "Safe nonce and owner cells atomically restore"
        );
        vm.roll(block_);
        _pcImport(next, r, p);
    }

    function testPrimaryCollaboratorSecondSuccessorRetainsAccountLaneAndFreshPayout() external {
        _pcSource(0);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        _pcImport(next, r, p);
        bytes32 firstOriginalRoot = RH.provenanceHash(p.admission.provenance);
        _rhAdopt(next);
        _pcPayout();
        Successor memory last = _multiCutover();
        (r, p) = _pcPrepare(last);
        require(
            p.admission.provenance.eras.length == 2
                && p.admission.provenance.origins[0].registry
                    != p.admission.provenance.origins[1].registry,
            "genuine two source environments"
        );
        require(
            p.admission.provenance.eras[1].lowerRevisions[1] == 1,
            "import-only owner1 revision is not an original collaborator mutation"
        );
        require(
            RH.provenanceHash(p.admission.provenance) != firstOriginalRoot,
            "complete prefix plus fresh native suffix"
        );
        _pcImport(last, r, p);
    }

    function testPrimaryCollaboratorFinalMapAndHistoricalRowsRejectIndependentDrift() external {
        _pcSource(0);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        (PC.Proof memory proof, M.State memory scope) = _pcProof(p, 0);
        PCSource.Result memory observed = PCSource.requireCurrent(scope, proof);
        A.AcceptanceBundle[] memory rows =
            abi.decode(abi.encode(proof.accepted), (A.AcceptanceBundle[]));
        rows[1].rows[0].recordHash = pcPrimary[0];
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        PCAcceptance.validate(
            rows, scope, proof.provenance, proof.bindings, proof.archive, observed.clocks
        );
        rows = abi.decode(abi.encode(proof.accepted), (A.AcceptanceBundle[]));
        ++rows[1].rows[0].acceptedAt;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        PCAcceptance.validate(
            rows, scope, proof.provenance, proof.bindings, proof.archive, observed.clocks
        );
        PCAcceptance.validate(
            proof.accepted, scope, proof.provenance, proof.bindings, proof.archive, observed.clocks
        );
        PC.Inventory memory changed = abi.decode(abi.encode(proof.archive), (PC.Inventory));
        changed.accepted[0].join.artistId = artistId;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        PCAcceptance.validate(
            proof.accepted, scope, proof.provenance, proof.bindings, changed, observed.clocks
        );
        _pcImport(next, r, p);
    }

    function testPrimaryCollaboratorWholeProofAndCompletedClockRejectOmissionThenRestore()
        external
    {
        _pcSource(1);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        (PC.Proof memory proof, M.State memory scope) = _pcProof(p, 0);
        PC.BindingInventory memory changed =
            abi.decode(abi.encode(proof.bindings), (PC.BindingInventory));
        changed.collaborators[1][0][0].role = keccak256("wrong original role");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        PCClocks.validate(scope, proof.provenance, changed, proof.archive);
        changed = abi.decode(abi.encode(proof.bindings), (PC.BindingInventory));
        changed.generations[1][0].accepted = false;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        PCClocks.validate(scope, proof.provenance, changed, proof.archive);
        PC.Proof memory omitted = abi.decode(abi.encode(proof), (PC.Proof));
        omitted.accounts = new IH.NonceLane[](0);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        PCSource.requireCurrent(scope, omitted);
        PCSource.requireCurrent(scope, proof);
        _pcImport(next, r, p);
    }
}
