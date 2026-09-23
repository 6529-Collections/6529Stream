// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    IStreamArtistAcceptanceOwner as Owner
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    IStreamArtistCollaboratorAcceptanceOwner as Collaborator
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorAcceptanceOwner.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistPrimaryCollaboratorLeaves as Leaves
} from "./StreamArtistPrimaryCollaboratorLeaves.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

/// @notice Every original owner3 receipt and replay cell, plus its actually retained maps.
/// @dev Historical overwritten op2 timestamps and op7 timestamps are not fabricated.
/// Original native receipts, immutable Archive bytes and all-era aliases authenticate
/// those occurrences. Only the last op2 per binding is recomputed with its stored time.
library StreamArtistCompleteHistoryAcceptance {
    bytes32 private constant KEY = keccak256("acceptance_lifecycle.replay.record_uniqueness");

    struct Context {
        RH.OwnerProvenance provenance;
        bool[] aliases;
        bool[] nativeRows;
        bool[] primaryRows;
        bool[] collaboratorRows;
    }

    function collect(
        address source,
        M.State memory scope,
        RH.Provenance memory p,
        PC.BindingInventory memory bindings,
        PC.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public view returns (A.AcceptanceBundle[] memory rows) {
        RH.OwnerProvenance memory local = RH.ownerProvenance(p, 3);
        Provenance.validateOwnerSource(local, 3, source);
        rows = new A.AcceptanceBundle[](scope.collections.length);
        for (uint256 k; k < rows.length; ++k) {
            rows[k].provenance = RH.ownerProvenanceHash(local, 3);
            rows[k].artistId = scope.collections[k].artistId;
            rows[k].collectionId = scope.collections[k].collectionId;
            rows[k].bindingHash = scope.collections[k].bindingHash;
            rows[k].rows = new A.Acceptance[](bindings.generations[k].length);
            for (uint256 g; g < rows[k].rows.length; ++g) {
                bytes32 h = bindings.generations[k][g].bindingHash;
                rows[k].rows[g] = A.Acceptance(
                    h, uint64(g + 1), Owner(source).acceptanceRecord(h), Owner(source).acceptedAt(h)
                );
            }
        }
        validate(rows, scope, p, bindings, inventory, clocks);
        for (uint256 i; i < inventory.accepted.length; ++i) {
            PC.AcceptedRow memory row = inventory.accepted[i];
            if (
                Collaborator(source)
                        .collaboratorAcceptanceRecord(
                            row.acceptance.bindingHash,
                            row.acceptance.account,
                            row.acceptance.role,
                            row.acceptance.shareLabelId
                        ) != row.join.acceptanceRecordHash
            ) _invalid();
        }
    }

    function validate(
        A.AcceptanceBundle[] memory rows,
        M.State memory scope,
        RH.Provenance memory p,
        PC.BindingInventory memory bindings,
        PC.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public view {
        Context memory c;
        c.provenance = RH.ownerProvenance(p, 3);
        bytes32 provenance = Provenance.validateOwner(c.provenance, 3);
        Catalogue.requireLocal(c.provenance, 3, inventory.catalogues, inventory.operations);
        c.aliases = new bool[](c.provenance.aliases.length);
        c.nativeRows = new bool[](c.provenance.journal.length);
        c.primaryRows = new bool[](clocks.primary.length);
        c.collaboratorRows = new bool[](inventory.accepted.length);
        if (rows.length != scope.collections.length || clocks.finalPrimary.length != rows.length) {
            _invalid();
        }
        for (uint256 k; k < rows.length; ++k) {
            A.AcceptanceBundle memory b = rows[k];
            if (
                b.provenance != provenance || b.artistId != scope.collections[k].artistId
                    || b.collectionId != scope.collections[k].collectionId
                    || b.bindingHash != scope.collections[k].bindingHash
                    || b.rows.length != bindings.generations[k].length
                    || b.rows.length != clocks.finalPrimary[k].length
            ) _invalid();
            for (uint256 g; g < b.rows.length; ++g) {
                A.Acceptance memory r = b.rows[g];
                if (
                    r.bindingHash != bindings.generations[k][g].bindingHash || r.generation != g + 1
                        || r.recordHash != clocks.finalPrimary[k][g]
                        || ((r.recordHash == 0) != (r.acceptedAt == 0))
                ) _invalid();
            }
        }
        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory item = inventory.operations[i];
            if (item.operation != 2 && item.operation != 7) continue;
            uint256 era = A.era(c.provenance, item.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.catalogues[era], item.evidence);
            if (e.operation != item.operation) _invalid();
            if (e.operation == 2) _primary(rows, scope, bindings, clocks, c, p.origins[era], e, i);
            else _collaborator(inventory, c, p.origins[era], e, i);
        }
        Guards.complete(c.aliases);
        Guards.complete(c.nativeRows);
        Guards.complete(c.primaryRows);
        Guards.complete(c.collaboratorRows);
        _eras(c.provenance);
    }

    function _primary(
        A.AcceptanceBundle[] memory rows,
        M.State memory scope,
        PC.BindingInventory memory bindings,
        Clocks.Result memory clocks,
        Context memory c,
        RH.OriginEnvironment memory origin,
        H.Envelope memory e,
        uint256 index
    ) private pure {
        uint256 occurrence = type(uint256).max;
        for (uint256 i; i < clocks.primary.length; ++i) {
            if (clocks.primary[i].operationIndex == index) {
                if (occurrence != type(uint256).max || c.primaryRows[i]) _invalid();
                occurrence = i;
            }
        }
        if (occurrence == type(uint256).max) _invalid();
        c.primaryRows[occurrence] = true;
        PC.PrimaryReceipt memory saved = clocks.primary[occurrence];
        (uint256 k, uint256 g) =
            _binding(scope, bindings, saved.collectionId, saved.generation, saved.bindingHash);
        PC.PrimaryAcceptance memory a =
            Leaves.primary(origin, e, bindings.bindings[k].bindings.rows[g].terms.count);
        if (
            saved.recordHash != e.value || a.acceptance.id != saved.collectionId
                || a.acceptance.binding_.bindingHash != saved.bindingHash
        ) _invalid();
        RH.Point memory point = _native(
            c,
            2,
            e.value,
            bindings.bindings[k].bindings.rows[g].item.artistId,
            saved.collectionId,
            origin,
            e.after_[3].revision
        );
        if (keccak256(abi.encode(point)) != keccak256(abi.encode(saved.point))) _invalid();
        Guards.mark(
            c.provenance,
            c.aliases,
            KEY,
            keccak256(
                abi.encode(
                    saved.collectionId, saved.generation, uint8(1), a.acceptance.proof.signer
                )
            ),
            e.value,
            point
        );
        A.Acceptance memory last = rows[k].rows[g];
        if (
            last.recordHash == e.value
                && e.value
                    != Hashes.acceptanceRecordForAuthority(
                        Hashes.Environment(
                            origin.chainId, origin.registry, origin.core, origin.manager
                        ),
                        saved.collectionId,
                        a.acceptance.binding_,
                        a.acceptance.proof.signer,
                        a.authority.authorityClass,
                        a.acceptance.authorization.nonce,
                        last.acceptedAt
                    )
        ) _invalid();
    }

    function _collaborator(
        PC.Inventory memory inventory,
        Context memory c,
        RH.OriginEnvironment memory origin,
        H.Envelope memory e,
        uint256 index
    ) private pure {
        PC.BindingAcceptance memory a = Leaves.acceptance(origin, e);
        uint256 occurrence = type(uint256).max;
        for (uint256 i; i < inventory.accepted.length; ++i) {
            if (inventory.accepted[i].operationIndex == index) {
                if (occurrence != type(uint256).max || c.collaboratorRows[i]) _invalid();
                occurrence = i;
            }
        }
        if (occurrence == type(uint256).max) _invalid();
        c.collaboratorRows[occurrence] = true;
        PC.AcceptedRow memory saved = inventory.accepted[occurrence];
        if (
            keccak256(abi.encode(saved.acceptance)) != keccak256(abi.encode(a.acceptance))
                || saved.join.artistId != a.artistId || saved.join.acceptanceRecordHash != e.value
        ) _invalid();
        RH.Point memory point = _native(
            c, 7, e.value, a.artistId, a.acceptance.collectionId, origin, e.after_[3].revision
        );
        if (keccak256(abi.encode(point)) != keccak256(abi.encode(saved.recordedAt))) _invalid();
        Guards.mark(
            c.provenance,
            c.aliases,
            KEY,
            keccak256(
                abi.encode(
                    a.acceptance.collectionId,
                    a.acceptance.generation,
                    uint8(2),
                    a.acceptance.account,
                    a.acceptance.role,
                    a.acceptance.shareLabelId
                )
            ),
            e.value,
            point
        );
    }

    function _native(
        Context memory c,
        uint16 operation,
        bytes32 record,
        bytes32 artist,
        uint256 cid,
        RH.OriginEnvironment memory origin,
        uint64 revision
    ) private pure returns (RH.Point memory point) {
        bool found;
        for (uint256 i; i < c.provenance.journal.length; ++i) {
            if (c.provenance.journal[i].receipt.recordHash == record) {
                RH.JournalEntry memory row = c.provenance.journal[i];
                if (
                    found || c.nativeRows[i] || row.receipt.operation != operation
                        || row.receipt.artistId != artist || row.receipt.collectionId != cid
                        || row.position.point.environmentHash != RH.originHash(origin)
                        || row.position.point.ownerIndex != 3
                        || row.position.point.ownerRevision != revision
                ) _invalid();
                found = true;
                c.nativeRows[i] = true;
                point = row.position.point;
            }
        }
        if (!found) _invalid();
    }

    function _binding(
        M.State memory scope,
        PC.BindingInventory memory b,
        uint256 cid,
        uint64 generation,
        bytes32 hash
    ) private pure returns (uint256 k, uint256 g) {
        bool found;
        for (uint256 i; i < scope.collections.length; ++i) {
            if (scope.collections[i].collectionId == cid) {
                if (
                    found || generation == 0 || generation > b.generations[i].length
                        || b.generations[i][generation - 1].bindingHash != hash
                ) _invalid();
                found = true;
                k = i;
                g = generation - 1;
            }
        }
        if (!found) _invalid();
    }

    function _eras(RH.OwnerProvenance memory p) private pure {
        uint256 total;
        uint256 cursor;
        for (uint256 e; e < p.eras.length; ++e) {
            RH.OwnerEra memory era = p.eras[e];
            total += era.nativeCount;
            if (
                era.lowerRevision != (e == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision != era.lowerRevision + era.nativeCount
                    || era.checkpoint.replayCount != total
                    || (total == 0 && era.checkpoint.replayRoot != 0)
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
            for (uint256 j; j < era.nativeCount; ++j) {
                if (
                    cursor >= p.journal.length
                        || p.journal[cursor].position.point.environmentHash != era.originHash
                        || p.journal[cursor++].position.point.ownerRevision
                            != era.lowerRevision + j + 1
                ) _invalid();
            }
        }
        if (cursor != p.journal.length) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
