// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCatalogue as Catalogue
} from "./StreamArtistPrimaryCollaboratorCatalogue.sol";
import {
    StreamArtistPrimaryCollaboratorLeaves as Leaves
} from "./StreamArtistPrimaryCollaboratorLeaves.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    IStreamArtistCollaboratorRecordsOwner as Records
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import { StreamArtistCollaboratorHashes as Hashes } from "./StreamArtistCollaboratorHashes.sol";

/// @notice Complete original owner1 proposal/identity/link/count reconstruction in Archive order.
/// @dev The enclosing profile independently proves binding terms, historical identity authority,
/// account/principal nonces, every other owner and full source currentness. This worker does not
/// interpret PRIMARY_ONLY as an obligation for collaborators to sign policy consents.
library StreamArtistPrimaryCollaboratorRecords {
    struct Work {
        PC.Inventory result;
        bool[] aliases;
        bool[] identities;
        bool[] acceptances;
        uint64[] revisions;
        uint256 proposals;
        uint256 rows;
    }

    function collect(
        RH.Provenance memory p,
        P.Catalogue[] memory catalogues,
        H.OperationEvidence[] memory operations
    ) public view returns (PC.Inventory memory result) {
        // All catalogue rows and all selected original occurrences are authenticated. No
        // caller-supplied slice can stand in for the owner1 lifetime mutation inventory.
        Catalogue.requireCurrent(p, catalogues, operations);
        RH.OwnerProvenance memory local = RH.ownerProvenance(p, 1);
        address source = p.origins[p.origins.length - 1].owners[1];
        Provenance.validateOwnerSource(local, 1, source);
        if (local.journal.length != 0) _invalid();
        Work memory w;
        w.result.catalogues = catalogues;
        w.result.operations = operations;
        w.result.proposals = new PC.Proposal[](operations.length);
        w.result.accepted = new PC.AcceptedRow[](operations.length);
        w.aliases = new bool[](local.aliases.length);
        w.identities = new bool[](p.journals[2].length);
        w.acceptances = new bool[](p.journals[3].length);
        w.revisions = new uint64[](p.eras.length);
        for (uint256 i; i < p.eras.length; ++i) {
            if (
                p.eras[i].nativeCounts[1] != 0 || p.eras[i].lowerRevisions[1] != (i == 0 ? 0 : 1)
                    || p.eras[i].checkpoints[1].nonceIndexCount != 0
                    || p.eras[i].checkpoints[1].nonceRoot != 0
            ) _invalid();
            w.revisions[i] = p.eras[i].lowerRevisions[1];
        }
        for (uint256 i; i < operations.length; ++i) {
            H.OperationEvidence memory op = operations[i];
            if (op.operation < 5 || op.operation > 7) continue;
            uint256 era = _era(p, op.originHash);
            H.Envelope memory e = Catalogue.read(p.origins[era], catalogues[era], op.evidence);
            if (
                e.operation != op.operation || e.before_[1].revision != w.revisions[era]
                    || e.after_[1].revision != e.before_[1].revision + 1
            ) _invalid();
            w.revisions[era] = e.after_[1].revision;
            RH.Point memory point = RH.Point(op.originHash, 1, e.after_[1].revision);
            if (op.operation == 5) {
                C.IdentityProposalState memory state = Leaves.proposal(p.origins[era], e);
                for (uint256 j; j < w.proposals; ++j) {
                    C.IdentityProposal memory prior = w.result.proposals[j].state.proposal;
                    if (
                        prior.account == state.proposal.account
                            && prior.identityRecordHash == state.proposal.identityRecordHash
                    ) _invalid();
                }
                Guards.mark(
                    local,
                    w.aliases,
                    keccak256("collaborator_lifecycle.replay.collaborator_proposal_key"),
                    keccak256(
                        abi.encode(state.proposal.account, state.proposal.identityRecordHash)
                    ),
                    state.proposalHash,
                    point
                );
                w.result.proposals[w.proposals++] =
                    PC.Proposal(state, point, RH.Point(bytes32(0), 0, 0), i, 0);
            } else if (op.operation == 6) {
                PC.IdentityAcceptance memory x = Leaves.identity(p.origins[era], e);
                uint256 selected = type(uint256).max;
                for (uint256 j; j < w.proposals; ++j) {
                    if (w.result.proposals[j].state.proposalHash == x.proposal.proposalHash) {
                        if (selected != type(uint256).max) _invalid();
                        selected = j;
                    }
                }
                if (
                    selected == type(uint256).max
                        || keccak256(abi.encode(w.result.proposals[selected].state))
                            != keccak256(abi.encode(x.proposal))
                ) _invalid();
                _native(
                    p,
                    w.identities,
                    2,
                    6,
                    e.value,
                    0,
                    e.value,
                    RH.Point(op.originHash, 2, e.after_[2].revision)
                );
                w.result.proposals[selected].state.acceptedArtistId = e.value;
                w.result.proposals[selected].completedAt = point;
                w.result.proposals[selected].identityOperationPlusOne = i + 1;
            } else {
                PC.BindingAcceptance memory x = Leaves.acceptance(p.origins[era], e);
                bytes32 key = Hashes.rowKey(
                    x.acceptance.bindingHash,
                    x.acceptance.account,
                    x.acceptance.role,
                    x.acceptance.shareLabelId
                );
                uint256 count;
                for (uint256 j; j < w.rows; ++j) {
                    C.BindingAcceptance memory prior = w.result.accepted[j].acceptance;
                    if (
                        Hashes.rowKey(
                                prior.bindingHash, prior.account, prior.role, prior.shareLabelId
                            ) == key
                    ) _invalid();
                    if (prior.bindingHash == x.acceptance.bindingHash) ++count;
                }
                if (count != x.priorCount) _invalid();
                RH.Point memory at = RH.Point(op.originHash, 3, e.after_[3].revision);
                _native(p, w.acceptances, 3, 7, x.artistId, x.acceptance.collectionId, e.value, at);
                w.result.accepted[w.rows++] =
                    PC.AcceptedRow(x.acceptance, C.Join(x.artistId, e.value), at, i);
            }
        }
        uint256 replayCount;
        for (uint256 i; i < p.eras.length; ++i) {
            for (uint256 j; j < w.proposals; ++j) {
                if (w.result.proposals[j].proposedAt.environmentHash == p.eras[i].originHash) {
                    ++replayCount;
                }
            }
            if (
                w.revisions[i] != p.eras[i].checkpoints[1].ownerState.revision
                    || p.eras[i].checkpoints[1].replayCount != replayCount
                    || (replayCount == 0 && p.eras[i].checkpoints[1].replayRoot != 0)
            ) _invalid();
        }
        for (uint256 i; i < p.journals[2].length; ++i) {
            if (p.journals[2][i].receipt.operation == 6 && !w.identities[i]) _invalid();
        }
        for (uint256 i; i < p.journals[3].length; ++i) {
            if (p.journals[3][i].receipt.operation == 7 && !w.acceptances[i]) _invalid();
        }
        Guards.complete(w.aliases);
        result = w.result;
        uint256 proposals = w.proposals;
        uint256 rows = w.rows;
        PC.Proposal[] memory ps = result.proposals;
        PC.AcceptedRow[] memory rs = result.accepted;
        assembly ("memory-safe") {
            mstore(ps, proposals)
            mstore(rs, rows)
        }
        _source(source, result);
    }

    function _source(address source, PC.Inventory memory x) private view {
        for (uint256 i; i < x.proposals.length; ++i) {
            C.IdentityProposalState memory row = x.proposals[i].state;
            if (
                keccak256(
                        abi.encode(
                            Records(source)
                                .identityProposal(
                                    row.proposal.account, row.proposal.identityRecordHash
                                )
                        )
                    ) != keccak256(abi.encode(row))
            ) _invalid();
        }
        for (uint256 i; i < x.accepted.length; ++i) {
            PC.AcceptedRow memory row = x.accepted[i];
            C.BindingAcceptance memory a = row.acceptance;
            if (
                keccak256(
                            abi.encode(
                                Records(source)
                                    .acceptedRow(a.bindingHash, a.account, a.role, a.shareLabelId)
                            )
                        ) != keccak256(abi.encode(row.join))
                    || !Records(source).identityLinked(row.join.artistId, a.account)
            ) _invalid();
            uint256 count;
            for (uint256 j; j < x.accepted.length; ++j) {
                if (x.accepted[j].acceptance.bindingHash == a.bindingHash) ++count;
            }
            if (Records(source).acceptedCount(a.bindingHash) != count) _invalid();
        }
    }

    function _native(
        RH.Provenance memory p,
        bool[] memory used,
        uint8 owner,
        uint16 op,
        bytes32 artist,
        uint256 collection,
        bytes32 record,
        RH.Point memory point
    ) private pure {
        uint256 count;
        for (uint256 i; i < p.journals[owner].length; ++i) {
            RH.JournalEntry memory j = p.journals[owner][i];
            if (j.receipt.recordHash != record) continue;
            if (
                used[i] || j.receipt.operation != op || j.receipt.artistId != artist
                    || j.receipt.collectionId != collection
                    || keccak256(abi.encode(j.position.point)) != keccak256(abi.encode(point))
            ) _invalid();
            used[i] = true;
            ++count;
        }
        if (count != 1) _invalid();
    }

    function _era(RH.Provenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
        return 0;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
