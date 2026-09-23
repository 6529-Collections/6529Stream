// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistAttributionDisputeFixture.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection as Correction,
    IStreamArtistBindingCorrectionOwner as Corrections
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    StreamArtistBindingCorrectionAdmission as Admission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistCompleteHistoryBindingTypes as BT
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingTypes.sol";
import {
    StreamArtistCompleteHistoryBindingLeaves as Leaves
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingLeaves.sol";
import {
    StreamArtistPrimaryCollaboratorBindingLeaves as OldLeaves
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorBindingLeaves.sol";
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
    StreamArtistBindingCorrectionState as CS
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as Generations
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as CHRH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as CHM
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistBindingCorrectionHashes as CorrectionHash
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionHashes.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

/// @notice Genuine original owner/Coordinator correction histories through the new binding leaves.
/// @dev Inherited Core/governance admission boundaries are explicit. These tests do not claim
/// whole-source hydration or runtime acceptance until that distinct suite is executed.
contract StreamArtistCompleteHistoryBindingActualTest is ArtistAttributionDisputeFixture {
    function testCompleteBindingCorrectsWithdrawnAIntoNewBPendingWithoutLosingFormerPrincipal()
        external
    {
        bytes32 former = artistId;
        ingress.withdrawArtistBinding(_termination(1));
        uint256 allocation = IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce();
        _correctNew();
        (CHM.State memory scope, PC.BindingInventory memory inventory) = _inventory();
        CB.Bundle memory b = inventory.bindings[0];
        require(
            scope.collections[0].artistId != former && b.bindings.rows[0].item.artistId == former,
            "actual former/current Artist identities differ"
        );
        require(
            b.corrections[1].approval.registrationNonce == allocation && allocation != 0,
            "original global registration allocation survives"
        );
        require(
            !b.bindings.current.accepted && b.bindings.rows[0].terminal.kind == 2,
            "latest is genuinely pending; original withdrawal retained"
        );
        _validate(scope, inventory);
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        OldLeaves.row(
            b.bindings.rows[0], scope.collections[0], 1, _origin(), inventory.collaborators[0][0]
        );
        // The old profile still requires its original same-principal row boundary.
        _validate(scope, inventory);
    }

    function testCompleteBindingRejectsMissingFormerPrincipalAndWrongCurrentQueryThenRestores()
        external
    {
        ingress.withdrawArtistBinding(_termination(1));
        _correctNew();
        (CHM.State memory scope, PC.BindingInventory memory inventory) = _inventory();
        AH.Query[] memory original = scope.artists;
        scope.artists = new AH.Query[](1);
        scope.artists[0] = original[1];
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        BT.validate(scope, inventory, bytes32(uint256(99)));
        scope.artists = original;
        bytes32 latest = scope.collections[0].artistId;
        scope.collections[0].artistId = artistId;
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        BT.validate(scope, inventory, bytes32(uint256(99)));
        scope.collections[0].artistId = latest;
        _validate(scope, inventory);
    }

    function testCompleteBindingRejectsRehashedWrongRegistrationNonce() external {
        ingress.withdrawArtistBinding(_termination(1));
        _correctNew();
        (CHM.State memory scope, PC.BindingInventory memory inventory) = _inventory();
        CB.Bundle memory original = inventory.bindings[0];
        CB.Bundle memory changed = abi.decode(abi.encode(original), (CB.Bundle));
        ++changed.corrections[1].approval.registrationNonce;
        BC.Approval memory a = changed.corrections[1].approval;
        a.governance.newValueHash = keccak256(
            abi.encode(
                a.governance.scopeHash,
                a.governance.oldValueHash,
                a.proposalHash,
                a.proposedArtistId,
                a.registrationNonce
            )
        );
        changed.corrections[1].approval = a;
        CHRH.OriginEnvironment memory o = _origin();
        changed.corrections[1].recordHash = CorrectionHash.hash(
            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
            1,
            changed.bindings.rows[1].item.bindingHash,
            a
        );
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Leaves.correction(changed, scope.collections[0], 1, o);
        require(
            Leaves.correction(original, scope.collections[0], 1, o), "original approval restored"
        );
    }

    function testCompleteBindingRevokedAcceptedAUsesOriginalOpeningPrincipalAfterNewBCorrection()
        external
    {
        _accept();
        _open(keccak256("complete chronology original accepted opening"));
        _resolve(_resolution(2, keccak256("complete chronology class2 revocation")), 2);
        _correctNew();
        (CHM.State memory scope, PC.BindingInventory memory inventory) = _inventory();
        CB.Bundle memory b = inventory.bindings[0];
        require(
            b.bindings.rows[0].item.accepted && !b.bindings.current.accepted
                && b.corrections[1].approval.cause == 4,
            "actual accepted-to-revoked-to-corrected history"
        );
        _validate(scope, inventory);
        BC.Approval memory a = b.corrections[1].approval;
        (
            L.Terminal memory end,
            AD.Head memory head,
            AD.Record memory opening,
            AD.Resolution memory resolution
        ) = abi.decode(a.causeData, (L.Terminal, AD.Head, AD.Record, AD.Resolution));
        require(
            opening.artistId == artistId && opening.artistId != b.bindings.current.artistId,
            "dispute joins the genuine former Artist"
        );
        opening.artistId = b.bindings.current.artistId;
        a.causeData = abi.encode(end, head, opening, resolution);
        a.governance.oldValueHash =
            keccak256(abi.encode(a.previous, uint8(5), a.cause, a.causeRecord, a.causeData));
        a.governance.newValueHash = keccak256(
            abi.encode(
                a.governance.scopeHash,
                a.governance.oldValueHash,
                a.proposalHash,
                a.proposedArtistId,
                a.registrationNonce
            )
        );
        b.corrections[1].approval = a;
        CHRH.OriginEnvironment memory o = _origin();
        b.corrections[1].recordHash = CorrectionHash.hash(
            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
            1,
            b.bindings.current.bindingHash,
            a
        );
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        Leaves.correction(b, scope.collections[0], 1, _origin());
    }

    function testCompleteBindingEmptyUnboundSlotCannotHideNonemptyBinding() external {
        (CHM.State memory scope, PC.BindingInventory memory inventory) = _inventory();
        _validate(scope, inventory);
        require(inventory.bindings[1].bindings.rows.length == 0, "actual never-bound sibling");
        inventory.bindings[1].bindings.current.artistAddress = address(artist);
        avm.expectRevert(CHRH.InvalidRecoveredHydrationProfile.selector);
        BT.validate(scope, inventory, bytes32(uint256(99)));
        delete inventory.bindings[1].bindings.current.artistAddress;
        _validate(scope, inventory);
    }

    function _correctNew() private {
        bytes memory document = bytes("complete chronology new Artist B document");
        T.BindingProposal memory p = _proposal(0);
        p.artistAddress = address(0xB0B);
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:complete:artist-b";
        p.reasonHash = keccak256("genuine governed correction to a newly registered Artist");
        (BC.Context memory c,) = Admission.context(suite, 1, p, document, "Artist B", 0);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        _govern(
            abi.encodeCall(
                Correction.proposeArtistBindingAfterRevocation,
                (uint256(1), p, document, "Artist B", bytes32(0))
            ),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            p.reasonHash,
            2
        );
    }

    function _origin() private view returns (CHRH.OriginEnvironment memory o) {
        o.chainId = block.chainid;
        o.registry = address(ingress);
        o.core = address(core);
        o.manager = address(manager);
    }

    function _inventory()
        private
        view
        returns (CHM.State memory scope, PC.BindingInventory memory result)
    {
        T.Binding memory current = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        scope.artists = new AH.Query[](current.artistId == artistId ? 1 : 2);
        scope.artists[0].artistId = artistId;
        if (scope.artists.length == 2) scope.artists[1].artistId = current.artistId;
        scope.collections = new AH.Query[](2);
        scope.collections[0].artistId = current.artistId;
        scope.collections[0].collectionId = 1;
        scope.collections[0].bindingHash = current.bindingHash;
        scope.collections[1].collectionId = 2;
        result.bindings = new CB.Bundle[](2);
        result.generations = new Generations.Generation[][](2);
        result.collaborators = new T.CollaboratorRecord[][][](2);
        for (uint256 k; k < 2; ++k) {
            uint256 id = k + 1;
            CB.Bundle memory b;
            b.bindings.artistId = scope.collections[k].artistId;
            b.bindings.collectionId = id;
            b.bindings.bindingHash = scope.collections[k].bindingHash;
            b.bindings.provenanceCommitment = bytes32(uint256(99));
            b.bindings.current = IStreamArtistBindingOwner(suite.owners[0]).binding(id);
            uint256 n = b.bindings.current.generation;
            b.bindings.rows = new BG.Row[](n);
            b.corrections = new CS.Correction[](n);
            result.generations[k] = new Generations.Generation[](n);
            result.collaborators[k] = new T.CollaboratorRecord[][](n);
            for (uint256 i; i < n; ++i) {
                uint64 g = uint64(i + 1);
                b.bindings.rows[i] = BG.Row(
                    IStreamArtistBindingOwner(suite.owners[0]).bindingAt(id, g),
                    Terms(suite.owners[0]).bindingTerms(id, g),
                    ingress.bindingTermination(id, g)
                );
                (b.corrections[i].approval, b.corrections[i].recordHash) = Corrections(
                        suite.owners[0]
                    ).bindingCorrection(b.bindings.rows[i].item.bindingHash);
                result.generations[k][i].bindingHash = b.bindings.rows[i].item.bindingHash;
                result.generations[k][i].generation = g;
                result.generations[k][i].accepted = b.bindings.rows[i].item.accepted;
                result.collaborators[k][i] =
                    new T.CollaboratorRecord[](b.bindings.rows[i].terms.count);
                for (uint256 j; j < result.collaborators[k][i].length; ++j) {
                    result.collaborators[k][i][j] =
                        Terms(suite.owners[0]).collaboratorTerm(id, g, j);
                }
            }
            result.bindings[k] = b;
        }
    }

    function _validate(CHM.State memory scope, PC.BindingInventory memory inventory) private view {
        BT.validate(scope, inventory, bytes32(uint256(99)));
        for (uint256 k; k < scope.collections.length; ++k) {
            CB.Bundle memory b = inventory.bindings[k];
            for (uint256 i; i < b.bindings.rows.length; ++i) {
                Leaves.row(
                    b.bindings.rows[i],
                    scope.collections[k],
                    uint64(i + 1),
                    _origin(),
                    inventory.collaborators[k][i]
                );
                Leaves.correction(b, scope.collections[k], i, _origin());
            }
        }
    }
}
