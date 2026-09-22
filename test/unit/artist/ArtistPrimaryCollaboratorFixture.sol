// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistCollaboratorTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    IStreamArtistCollaboratorLifecycle
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";
import "./ArtistRecoveredMultipleFixture.sol";
import {
    StreamArtistBindingCorrectionTypes as PCBC,
    IStreamArtistBindingCorrection as PCCorrection,
    IStreamArtistBindingCorrectionOwner as PCCorrectionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistBindingCorrectionAdmission as PCCorrectionAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as PCCodec
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as PCSource
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorSourceProof.sol";
import {
    StreamArtistPrimaryCollaboratorSelection as PCSelection
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorSelection.sol";
import {
    StreamArtistPrimaryCollaboratorCurrent as PCCurrent
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorCurrent.sol";
import {
    IStreamArtistCollaboratorRecordsOwner as Collaborators
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import {
    IStreamArtistCollaboratorAcceptanceOwner as CollaboratorAcceptance
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorAcceptanceOwner.sol";
import {
    StreamArtistRecoveredHistoryRecordRouting as Routing
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryRecordRouting.sol";

/// @notice Original Registry/seven owners/Archive and threshold Safes; inherited Core and
/// scheduled governance are explicit unit boundaries. No hydration state or chronology is mocked.
abstract contract ArtistPrimaryCollaboratorFixture is ArtistRecoveredMultipleFixture {
    C.IdentityProposal internal pcProposal;
    C.BindingAcceptance[] internal pcRows;
    bytes32[] internal pcAccepted;
    bytes32[] internal pcPrimary;
    bytes32[] internal pcDigests;
    bytes32[] internal pcRecords;
    bytes[] internal pcSignatures;
    uint256 internal pcRegistrationNonce;

    function _pcRemember(bytes32 id, bytes32 record, bytes32 digest, T.Authorization memory a)
        internal
    {
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(id, digest))
        );
        _rhCandidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(id, a.nonce))
        );
        pcRecords.push(record);
        pcDigests.push(digest);
        pcSignatures.push(a.signature);
    }

    function _pcIdentity() internal {
        _delegateSetup();
        bytes memory doc = bytes("actual collaborator hydration identity");
        pcProposal = C.IdentityProposal(
            address(delegateSafe),
            keccak256(doc),
            "urn:pc:identity",
            keccak256("pc registration"),
            "urn:pc:reason"
        );
        ingress.proposeCollaboratorIdentity(pcProposal);
        _rhCandidate(
            1,
            "collaborator_lifecycle.replay.collaborator_proposal_key",
            keccak256(abi.encode(pcProposal.account, pcProposal.identityRecordHash))
        );
        pcRegistrationNonce = IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce();
        T.Authorization memory a = T.Authorization(300, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.collaboratorIdentityDigest(
            pcProposal.account, pcProposal.identityRecordHash, a
        );
        a.signature = safeThresholdSignature(
            delegateKeys, safeMessageDigest(delegateSafe, abi.encode(digest))
        );
        collaboratorId = ingress.acceptCollaboratorIdentity(
            pcProposal.account, pcProposal.identityRecordHash, a, doc, "Collaborator Safe"
        );
        _pcRemember(collaboratorId, collaboratorId, digest, a);
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), pcRegistrationNonce))
        );
        _rhCandidate(2, "identity_authority.replay.identity_uniqueness", collaboratorId);
        _rhCandidate(
            2,
            "identity_authority.replay.collaborator_account_nonce",
            keccak256(abi.encode(pcProposal.account, a.nonce))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.collaborator_account_digest",
            keccak256(abi.encode(pcProposal.account, digest))
        );
        (bool used, uint256 hint) =
            ingress.collaboratorRegistrationNonceState(pcProposal.account, 300);
        require(
            used && hint == 0 && pcRegistrationNonce == 1,
            "sparse account nonce is not global allocation"
        );
    }

    function _pcPropose() internal returns (C.BindingAcceptance memory row) {
        T.BindingProposal memory p = _proposal(artistId);
        p.collaborators = new T.CollaboratorRecord[](1);
        p.collaborators[0] = T.CollaboratorRecord(
            address(delegateSafe), keccak256("composer"), keccak256("composer-share")
        );
        T.Binding memory previous = Binding(suite.owners[0]).binding(2);
        if (previous.generation == 0) {
            ingress.proposeArtistBinding(2, p, bytes("unit identity document"), "Artist Safe");
        } else {
            // Actual original correction admission reads the saved refusal. Only the
            // inherited governance approval context is an explicit typed unit boundary.
            p.reasonHash = keccak256(
                abi.encode(
                    "original collaborator refusal correction",
                    previous.bindingHash,
                    previous.generation
                )
            );
            (PCBC.Context memory context,) = PCCorrectionAdmission.context(
                suite, 2, p, bytes("unit identity document"), "Artist Safe", 0
            );
            address authority = manager.governanceAuthority();
            ArtistUnitRoles(suite.roleRegistry).setAdmin(authority, true);
            ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
            ArtistUnitGovernance(authority)
                .configureContestReads(
                    suite.roleRegistry,
                    address(artist),
                    p.reasonHash,
                    "urn:pc:correction:governance"
                );
            bytes32 action = keccak256(
                abi.encode("pc original refusal correction", context, previous.generation)
            );
            ArtistUnitGovernance(authority)
                .executeModuleContextWithAction(
                    action,
                    address(ingress),
                    abi.encodeCall(
                        PCCorrection.proposeArtistBindingAfterRevocation,
                        (uint256(2), p, bytes("unit identity document"), "Artist Safe", bytes32(0))
                    ),
                    2,
                    context.scopeHash,
                    context.oldValueHash,
                    context.newValueHash
                );
            T.Binding memory corrected = Binding(suite.owners[0]).binding(2);
            (PCBC.Approval memory approval, bytes32 record) =
                PCCorrectionOwner(suite.owners[0]).bindingCorrection(corrected.bindingHash);
            require(
                approval.cause == 1
                    && approval.causeRecord
                        == Lifecycle(suite.owners[0])
                        .bindingTermination(2, previous.generation)
                        .recordHash && approval.governance.actionId == action
                    && approval.previous.bindingHash == previous.bindingHash
                    && corrected.generation == previous.generation + 1 && !corrected.accepted
                    && record != 0,
                "genuine original refused-binding correction and retained cause"
            );
            (
                bool active,
                bytes32 id,
                uint8 kind,
                bytes32 scope_,
                bytes32 oldValue,
                bytes32 newValue
            ) = IStreamGovernanceReads(authority).currentAction();
            require(
                !active && id == 0 && kind == 0 && scope_ == 0 && oldValue == 0 && newValue == 0,
                "typed correction context cleared before original recovery"
            );
            _rhCandidate(0, "binding_lifecycle.replay.correction_action", action);
        }
        T.Binding memory b = Binding(suite.owners[0]).binding(2);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(2), b.generation))
        );
        row = C.BindingAcceptance(
            2,
            b.generation,
            b.bindingHash,
            address(delegateSafe),
            p.collaborators[0].role,
            p.collaborators[0].shareLabelId
        );
        pcRows.push(row);
    }

    function _pcPrimaryAccept() internal returns (bytes32 record) {
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(2, a);
        a.signature = _signature(digest);
        record = ingress.acceptArtistBinding(2, a);
        _pcRemember(artistId, record, digest, a);
        pcPrimary.push(record);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(
                abi.encode(
                    uint256(2),
                    Binding(suite.owners[0]).binding(2).generation,
                    uint8(1),
                    address(artist)
                )
            )
        );
    }

    function _pcAccept(C.BindingAcceptance memory row, bool direct)
        internal
        returns (bytes32 record)
    {
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        bytes32 digest = ingress.collaboratorAcceptanceDigest(row, a);
        if (direct) {
            require(
                this.executeDelegate(
                    address(ingress),
                    abi.encodeCall(IStreamArtistCollaboratorLifecycle.acceptCollaborator, (row, a))
                ),
                "actual threshold Safe op7"
            );
            record = CollaboratorAcceptance(suite.owners[3])
                .collaboratorAcceptanceRecord(
                    row.bindingHash, row.account, row.role, row.shareLabelId
                );
        } else {
            a.signature = safeThresholdSignature(
                delegateKeys, safeMessageDigest(delegateSafe, abi.encode(digest))
            );
            record = ingress.acceptCollaborator(row, a);
        }
        _pcRemember(collaboratorId, record, digest, a);
        pcAccepted.push(record);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(
                abi.encode(
                    row.collectionId,
                    row.generation,
                    uint8(2),
                    row.account,
                    row.role,
                    row.shareLabelId
                )
            )
        );
    }

    function _pcRefuse() internal {
        T.Binding memory b = Binding(suite.owners[0]).binding(2);
        L.Termination memory p = L.Termination(
            2, b.generation, b.bindingHash, keccak256("partial original refusal"), "urn:pc:refusal"
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.bindingRefusalDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.refuseArtistBinding(p, a);
        _pcRemember(artistId, record, digest, a);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.refusal_uniqueness",
            keccak256(abi.encode(uint256(2), b.generation))
        );
    }

    function _pcPayout() internal {
        (, bytes32 previous) = ingress.artistPayoutAccount(collaboratorId);
        T.PayoutDesignation memory p =
            T.PayoutDesignation(collaboratorId, address(delegateSafe), previous);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        bytes32 digest = ingress.payoutDesignationDigest(p, a);
        a.signature = safeThresholdSignature(
            delegateKeys, safeMessageDigest(delegateSafe, abi.encode(digest))
        );
        bytes32 record = ingress.recordPayoutDesignation(p, a);
        _pcRemember(collaboratorId, record, digest, a);
        _rhCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(collaboratorId))
        );
    }

    /// @param mode 0 repeated primary then last collaborator;1 collaborator then primary;
    /// 2 retained partial collaborator/refusal then a new accepted generation.
    function _pcSource(uint8 mode) internal {
        _pcIdentity();
        C.BindingAcceptance memory row = _pcPropose();
        if (mode == 0) {
            _pcPrimaryAccept();
        } else {
            _pcAccept(row, false);
            if (mode == 2) {
                _pcRefuse();
                row = _pcPropose();
            }
        }
        require(!Binding(suite.owners[0]).binding(2).accepted, "genuine pending collaborator graph");
        _rhBaseline();
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(rhRecovery).postWindowEndsAt);
        multiRecovery = [rhRecovery, rhRecovery];
        multiCollectionArtists = [artistId, artistId];
        multiArtists = new bytes32[](2);
        multiArtists[0] = artistId;
        multiArtists[1] = collaboratorId;
        if (collaboratorId < artistId) {
            multiArtists[0] = collaboratorId;
            multiArtists[1] = artistId;
        }
        _pcPrimaryAccept();
        if (mode != 1) _pcAccept(row, true);
        require(Binding(suite.owners[0]).binding(2).accepted, "original completed binding");
        _multiPolicy(1);
        _multiPolicy(2);
        _multiPayout();
        _pcPayout();
    }

    function _pcPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _multiRequest();
        require(
            PCSelection.required(next.coordinator.suiteConfiguration(), r),
            "actual source selects new profile"
        );
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r);
        r.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _pcProof(Commit.Prepared memory p, uint8 owner)
        internal
        pure
        returns (PC.Proof memory proof, M.State memory scope)
    {
        (, Payload.Payload memory payload) = Payload.decode(p.data[owner].typedState, owner);
        bytes memory raw;
        (scope, raw) = PCCodec.decodeAuxiliary(owner, payload.semanticState, payload.provenance);
        proof = abi.decode(raw, (PC.Proof));
    }

    function _pcSemantics(T.SuiteConfiguration memory s) internal view returns (bytes32 h) {
        h = keccak256(
            abi.encode(
                Collaborators(s.owners[1])
                    .identityProposal(pcProposal.account, pcProposal.identityRecordHash),
                Collaborators(s.owners[1]).identityLinked(collaboratorId, pcProposal.account)
            )
        );
        for (uint256 i; i < pcRows.length; ++i) {
            C.BindingAcceptance memory r = pcRows[i];
            h = keccak256(
                abi.encode(
                    h,
                    Terms(s.owners[0]).bindingTerms(r.collectionId, r.generation),
                    Terms(s.owners[0]).collaboratorTerm(r.collectionId, r.generation, 0),
                    Binding(s.owners[0]).bindingAt(r.collectionId, r.generation),
                    Lifecycle(s.owners[0]).bindingTermination(r.collectionId, r.generation),
                    Collaborators(s.owners[1])
                        .acceptedRow(r.bindingHash, r.account, r.role, r.shareLabelId),
                    Collaborators(s.owners[1]).acceptedCount(r.bindingHash),
                    CollaboratorAcceptance(s.owners[3])
                        .collaboratorAcceptanceRecord(
                            r.bindingHash, r.account, r.role, r.shareLabelId
                        ),
                    Acceptance(s.owners[3]).acceptanceRecord(r.bindingHash),
                    Acceptance(s.owners[3]).acceptedAt(r.bindingHash)
                )
            );
        }
        for (uint256 i; i < pcRecords.length; ++i) {
            h = keccak256(
                abi.encode(h, IStreamArtistIdentityOwner(s.owners[2]).signatureBundle(pcRecords[i]))
            );
        }
    }

    function _pcDestination(Successor memory next) internal view returns (bytes32) {
        // Empty target term arrays intentionally cannot be indexed. Full raw owner roots/checkpoints
        // plus all keyed collaborator cells and dynamic signature values remain in this rollback hash.
        T.SuiteConfiguration memory s = next.coordinator.suiteConfiguration();
        bytes32 h = keccak256(
            abi.encode(
                _multiDestinationHash(next),
                Collaborators(s.owners[1])
                    .identityProposal(pcProposal.account, pcProposal.identityRecordHash),
                Collaborators(s.owners[1]).identityLinked(collaboratorId, pcProposal.account)
            )
        );
        for (uint256 i; i < pcRows.length; ++i) {
            C.BindingAcceptance memory r = pcRows[i];
            h = keccak256(
                abi.encode(
                    h,
                    Collaborators(s.owners[1])
                        .acceptedRow(r.bindingHash, r.account, r.role, r.shareLabelId),
                    Collaborators(s.owners[1]).acceptedCount(r.bindingHash),
                    CollaboratorAcceptance(s.owners[3])
                        .collaboratorAcceptanceRecord(
                            r.bindingHash, r.account, r.role, r.shareLabelId
                        )
                )
            );
        }
        return h;
    }

    function _pcAssert(Successor memory next, Commit.Prepared memory p) internal view {
        T.SuiteConfiguration memory s = next.coordinator.suiteConfiguration();
        bytes32 value = HydrationOwner(s.owners[2]).authorityHydrationCommitment();
        require(value != 0, "actual op60 commitment");
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h, Payload.Payload memory payload) =
                Payload.decode(p.data[i].typedState, i);
            require(
                h.requiredFeatures & PC.FEATURE != 0,
                "explicit nonempty primary collaborator profile"
            );
            (RH.OwnerProvenance memory prefix, bytes32 commitment,) =
                RecoveredOwner(s.owners[i]).recoveredHydrationImportedPrefix();
            require(
                commitment == value
                    && keccak256(abi.encode(prefix)) == keccak256(abi.encode(payload.provenance)),
                "full original seven-owner prefix"
            );
            require(
                Owner(s.owners[i]).ownerStateSnapshotV2().revision
                        == p.admission.before_[i].revision + 1
                    && Native(s.owners[i]).artistNativeReceiptCount() == 0,
                "one commit, no fake native receipt"
            );
            require(
                keccak256(
                    abi.encode(
                        Guards.collectNonces(s.owners[i], CP(s.owners[i]).authorityCheckpoint())
                    )
                ) == keccak256(abi.encode(payload.nonces)),
                "every original nonce tree word"
            );
        }
        require(
            _pcSemantics(s) == _pcSemantics(suite),
            "all original terms, proposal, joins, counts, links, receipts and signature bytes"
        );
        require(
            IStreamArtistIdentityOwner(s.owners[2]).nextRegistrationNonce() == 2,
            "original global allocation"
        );
        for (uint256 i; i < multiArtists.length; ++i) {
            require(
                keccak256(
                    abi.encode(IStreamArtistIdentityOwner(s.owners[2]).identity(multiArtists[i]))
                )
                == keccak256(
                    abi.encode(
                        IStreamArtistIdentityOwner(suite.owners[2]).identity(multiArtists[i])
                    )
                ),
                "both exact identity heads"
            );
        }
        (address paid, bytes32 designation) =
            next.registry.collaboratorPayoutAccount(collaboratorId, address(delegateSafe));
        (address oldPaid, bytes32 oldDesignation) =
            ingress.collaboratorPayoutAccount(collaboratorId, address(delegateSafe));
        require(
            paid == oldPaid && paid == address(delegateSafe) && designation == oldDesignation
                && designation != 0,
            "actual selected collaborator payout"
        );
        for (uint256 i; i < pcRows.length; ++i) {
            require(
                keccak256(abi.encode(next.registry.collaboratorAt(2, pcRows[i].generation, 0)))
                    == keccak256(abi.encode(ingress.collaboratorAt(2, pcRows[i].generation, 0))),
                "actual retained attribution row"
            );
        }
        (bool used, uint256 hint) =
            next.registry.collaboratorRegistrationNonceState(address(delegateSafe), 300);
        require(used && hint == 0, "account nonce persists independently of principal");
        Routing.requireCurrent(p.admission.provenance, p.query, p.data[4].typedState);
    }

    function _pcImport(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        internal
    {
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r))
            ),
            "actual threshold Safe op60"
        );
        _pcAssert(next, p);
    }
}
