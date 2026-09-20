// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    StreamArtistRecoveredAuthorityActualTest
} from "./StreamArtistRecoveredAuthorityActual.t.sol";
import { ArtistUnitGovernance, ArtistUnitRoles } from "./ArtistOnboardingFixture.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection as Correction,
    IStreamArtistBindingCorrectionOwner as CorrectionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistBindingCorrectionAdmission as Admission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamGovernanceReads
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceReads.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistRecoveredHydration as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationEvidence as Evidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationEvidence.sol";
import {
    StreamArtistRecoveredBindingCorrectionHydration as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionHydration.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistBindingCorrectionState as CorrectionState
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistRecoveredBindingGenerations as OldCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";

interface CorrectionHydrationVm {
    function expectCall(address, bytes calldata, uint64) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
}

/// @notice Actual canonical corrective op1, original2/3/4, living35 and seven-owner60/Safe.
/// @dev Core/governance scheduling are typed inherited boundaries. No source approval, owner
/// checkpoint or semantic state is fabricated. Native/current-stack acceptance is separate.
contract StreamArtistRecoveredBindingCorrectionsActualTest is
    StreamArtistRecoveredAuthorityActualTest
{
    CorrectionHydrationVm private constant cv =
        CorrectionHydrationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    T.Binding[] private originals;
    L.Terminal[] private terminals;
    CorrectionState.Correction[] private approvals;
    mapping(bytes32 => bytes) private signatures;
    bytes32[] private signedRecords;

    function testCorrectedWithdrawalThenRefusalPreservesExactApprovalsAndAllSevenOwners() external {
        _baseline(1, true);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory payload) = Payload.decode(p.data[0].typedState, 0);
        CB.Bundle memory b = Codec.decode(p.query, payload.provenance, payload.semanticState);
        require(
            b.corrections.length == 3 && b.corrections[0].recordHash == 0,
            "complete first/second/third history"
        );
        require(
            keccak256(payload.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_BINDING_CORRECTIONS_V1"),
                        uint16(1),
                        b
                    )
                ),
            "literal new codec"
        );
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & 2560) == 2560,
                "all owners require generation and correction capability"
            );
        }
        _import(next, request, p);
        _assert(next.coordinator.suiteConfiguration());
    }

    function testCorrectedModeTwoUsesSameCompleteApprovalAndOriginalRecovery() external {
        _baseline(2, false);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        (RH.ExportHeader memory h,) = Payload.decode(p.data[6].typedState, 6);
        require((h.requiredFeatures & 64) != 0, "actual mode2 composition");
        _import(next, request, p);
        _assert(next.coordinator.suiteConfiguration());
    }

    function testCorrectedRepeatedImportRetainsOriginalDomainApprovalAndReplay() external {
        _baseline(1, true);
        T.SuiteConfiguration memory source = suite;
        Successor memory middle = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory first) = _prepare(middle);
        _import(middle, request, first);
        _rhAdopt(middle);
        Successor memory last = _rhCutover();
        Commit.Prepared memory second;
        (request, second) = _prepare(last);
        require(second.admission.provenance.eras.length == 2, "two authentic original eras");
        for (uint8 i; i < 7; ++i) {
            require(
                keccak256(abi.encode(first.admission.provenance.journals[i]))
                    == keccak256(abi.encode(second.admission.provenance.journals[i])),
                "no invented native correction/import receipts"
            );
        }
        _import(last, request, second);
        _assert(last.coordinator.suiteConfiguration());
        _assert(source);
    }

    function testCorrectedCodecRejectsMissingForeignCauseActionAndOldCodec() external {
        _baseline(1, true);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory payload) = Payload.decode(p.data[0].typedState, 0);
        CB.Bundle memory original = Codec.decode(p.query, payload.provenance, payload.semanticState);
        for (uint8 i; i < 7; ++i) {
            CB.Bundle memory b = abi.decode(abi.encode(original), (CB.Bundle));
            if (i == 0) b.corrections = new CorrectionState.Correction[](0);
            if (i == 1) delete b.corrections[1];
            if (i == 2) b.corrections[1].approval.cause = 4;
            if (i == 3) b.corrections[1].approval.previous = b.bindings.current;
            if (i == 4) {
                b.corrections[1].approval.governance.actionId =
                b.corrections[2].approval.governance.actionId;
            }
            if (i == 5) {
                b.corrections[1].approval.governance.newValueHash = keccak256("foreign value");
            }
            if (i == 6) b.corrections[1].recordHash = keccak256("foreign origin");
            cv.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
            this.decodeCorrection(p.query, payload.provenance, abi.encode(CB.SCHEMA, uint16(1), b));
        }
        cv.expectRevert();
        this.decodeOld(p.query, payload.provenance, payload.semanticState);
        require(_rhDestinationHash(next) != 0, "destination remains a real fresh graph");
    }

    function testCorrectedApprovalSourceDriftAndMissingCapabilityAreAtomic() external {
        _baseline(1, false);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        request.expectedCapabilities[0].supportedFeatures &= ~uint256(2048);
        cv.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request.expectedCapabilities[0].supportedFeatures |= 2048;
        BC.Approval memory wrong = approvals[1].approval;
        wrong.governance.actionClass = 1;
        avm.mockCall(
            suite.owners[0],
            abi.encodeCall(CorrectionOwner.bindingCorrection, (originals[1].bindingHash)),
            abi.encode(wrong, approvals[1].recordHash)
        );
        cv.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        avm.mockCall(
            suite.owners[0],
            abi.encodeCall(CorrectionOwner.bindingCorrection, (originals[1].bindingHash)),
            abi.encode(approvals[1].approval, approvals[1].recordHash)
        );
        require(_rhDestinationHash(next) == before_, "no partial seven-owner writes");
        _import(next, request, p);
        _assert(next.coordinator.suiteConfiguration());
    }

    function testCorrectedMissingGovernanceActionReplayCannotImport() external {
        _baseline(1, false);
        Successor memory next = _rhCutover();
        (RH.Request memory request,) = _prepare(next);
        for (uint256 i; i < request.records.authority.replayOrigins[0].length; ++i) {
            if (
                request.records.authority.replayOrigins[0][i].surface
                    == keccak256("binding_lifecycle.replay.correction_action")
            ) {
                request.records.authority.replayOrigins[0][i].scope = keccak256("missing action");
                break;
            }
        }
        bytes32 before_ = _rhDestinationHash(next);
        cv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        require(_rhDestinationHash(next) == before_, "complete original guard inventory required");
    }

    function testCorrectedLateArchiveRollbackIncludesApprovalMapsAndSameSafeRetry() external {
        _baseline(1, false);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        cv.expectCall(
            next.coordinator.suiteConfiguration().archive, _firstPage(next, request, p), 2
        );
        bytes32 before_ = _rhDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        cv.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        (, bytes32 saved) = CorrectionOwner(next.coordinator.suiteConfiguration().owners[0])
            .bindingCorrection(originals[1].bindingHash);
        require(
            saved == 0 && _rhDestinationHash(next) == before_ && rotationSafe.nonce() == nonce,
            "all imported maps/roots/Safe rollback"
        );
        vm.roll(height);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_), "identical Safe request retries"
        );
        require(rotationSafe.nonce() == nonce + 1, "one committed execution");
        _assert(next.coordinator.suiteConfiguration());
    }

    function decodeCorrection(
        AH.Query calldata q,
        RH.OwnerProvenance calldata p,
        bytes calldata raw
    ) external pure {
        Codec.decode(q, p, raw);
    }

    function decodeOld(AH.Query calldata q, RH.OwnerProvenance calldata p, bytes calldata raw)
        external
        pure
    {
        OldCodec.decode(q, p, raw);
    }

    function _baseline(uint8 mode, bool third) private {
        _capture();
        _terminate(false);
        _correct(mode);
        if (third) {
            _terminate(true);
            _correct(mode);
        }
        uint64 generation = uint64(originals.length);
        T.Authorization memory accepted =
            T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        accepted.signature = _signature(ingress.acceptanceDigest(1, accepted));
        uint64 acceptedAt = uint64(block.timestamp);
        address acceptedSigner = address(artist);
        _rhBaseline();
        bytes32 acceptedRecord =
            Acceptance(suite.owners[3]).acceptanceRecord(originals[generation - 1].bindingHash);
        require(
            acceptedRecord
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(1),
                        generation,
                        originals[generation - 1].bindingHash,
                        uint8(1),
                        acceptedSigner,
                        uint8(1),
                        accepted.nonce,
                        acceptedAt
                    )
                ),
            "independent final generation original2 preimage"
        );
        signatures[acceptedRecord] = accepted.signature;
        signedRecords.push(acceptedRecord);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), generation, uint8(1), address(artist)))
        );
        originals[generation - 1] = Binding(suite.owners[0]).binding(1);
        _adoptRotatedSafe();
        uint64 end = ingress.artistTransitionState(rhRecovery).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
    }

    function _capture() private {
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        originals.push(b);
        terminals.push();
        approvals.push();
        (approvals[originals.length - 1].approval, approvals[originals.length - 1].recordHash) =
            CorrectionOwner(suite.owners[0]).bindingCorrection(b.bindingHash);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(1), b.generation))
        );
    }

    function _terminate(bool refusal) private {
        L.Termination memory p = _termination(1);
        if (refusal) {
            T.Authorization memory a = _authorization(false);
            bytes32 digest = ingress.bindingRefusalDigest(p, a);
            a.signature = _signature(digest);
            bytes32 record = ingress.refuseArtistBinding(p, a);
            _rhAuthorization(digest, a.nonce);
            signatures[record] = a.signature;
            signedRecords.push(record);
            _rhCandidate(
                0,
                "binding_lifecycle.replay.refusal_uniqueness",
                keccak256(abi.encode(uint256(1), p.generation))
            );
        } else {
            ingress.withdrawArtistBinding(p);
            _rhCandidate(
                0,
                "binding_lifecycle.replay.proposal_terminal_transition_key",
                keccak256(abi.encode(uint256(1), p.generation))
            );
        }
        terminals[originals.length - 1] =
            Lifecycle(suite.owners[0]).bindingTermination(1, p.generation);
    }

    function _correct(uint8 mode) private {
        T.BindingProposal memory p = _proposal(artistId);
        p.consentMode = mode;
        p.reasonHash = keccak256(abi.encode("canonical corrected generation", originals.length));
        (BC.Context memory c,) =
            Admission.context(suite, 1, p, bytes("unit identity document"), "Artist Safe", 0);
        address authority = manager.governanceAuthority();
        ArtistUnitRoles(suite.roleRegistry).setAdmin(authority, true);
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance(authority)
            .configureContestReads(
                suite.roleRegistry, address(artist), p.reasonHash, "urn:correction:governance"
            );
        bytes32 action = keccak256(abi.encode("original class2 correction", c, originals.length));
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, action, uint8(2), c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        ArtistUnitGovernance(authority)
            .executeModuleContext(
                address(ingress),
                abi.encodeCall(
                    Correction.proposeArtistBindingAfterRevocation,
                    (uint256(1), p, bytes("unit identity document"), "Artist Safe", bytes32(0))
                ),
                2,
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            );
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
        _rhCandidate(0, "binding_lifecycle.replay.correction_action", action);
        _capture();
        CorrectionState.Correction memory row = approvals[approvals.length - 1];
        require(
            row.approval.governance.actionId == action
                && row.recordHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1"),
                            block.chainid,
                            address(ingress),
                            address(core),
                            address(manager),
                            uint256(1),
                            originals[originals.length - 1].bindingHash,
                            row.approval
                        )
                    ),
            "literal original approval hash before any import"
        );
    }

    function _prepare(Successor memory next)
        private
        view
        returns (RH.Request memory request, Commit.Prepared memory p)
    {
        request = _rhRequest();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _import(Successor memory next, RH.Request memory request, Commit.Prepared memory p)
        private
    {
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request))
            ),
            "actual Safe60"
        );
        _rhImported(next, p, HydrationOwner(next.identity).authorityHydrationCommitment());
    }

    function _assert(T.SuiteConfiguration memory target) private view {
        for (uint256 i; i < originals.length; ++i) {
            require(
                keccak256(abi.encode(Binding(target.owners[0]).bindingAt(1, uint64(i + 1))))
                    == keccak256(abi.encode(originals[i])),
                "original full generation"
            );
            require(
                keccak256(
                    abi.encode(Lifecycle(target.owners[0]).bindingTermination(1, uint64(i + 1)))
                ) == keccak256(abi.encode(terminals[i])),
                "original full terminal"
            );
            (BC.Approval memory a, bytes32 record) =
                CorrectionOwner(target.owners[0]).bindingCorrection(originals[i].bindingHash);
            require(
                record == approvals[i].recordHash
                    && keccak256(abi.encode(a)) == keccak256(abi.encode(approvals[i].approval)),
                "full original immutable approval"
            );
            if (record != 0) {
                bytes32 key = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                        block.chainid,
                        target.registry,
                        Owner(target.owners[0]).operationCoordinator(),
                        target.archive,
                        target.owners[0],
                        Owner(target.owners[0]).domainId(),
                        keccak256("binding_lifecycle.replay.correction_action"),
                        a.governance.actionId
                    )
                );
                T.ReplayCell memory cell = Owner(target.owners[0]).replayCell(key);
                require(
                    cell.kind == 1 && cell.status == 2 && cell.commitment == record,
                    "original action cannot be resurrected"
                );
            }
        }
        for (uint256 i; i < signedRecords.length; ++i) {
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(signedRecords[i]))
                    == keccak256(signatures[signedRecords[i]]),
                "original refusal and final acceptance signature bytes"
            );
        }
    }

    function _firstPage(Successor memory next, RH.Request memory request, Commit.Prepared memory p)
        private
        view
        returns (bytes memory)
    {
        bytes32 value = keccak256(
            abi.encode(
                RH.PROFILE,
                RH.VERSION,
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                request,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
        bytes memory profile = abi.encode(
            RH.PROFILE,
            RH.VERSION,
            p.admission.prior,
            p.admission.sourceCoordinator,
            request,
            p.admission.artists,
            p.admission.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
        Evidence.Descriptor memory descriptor = Evidence.describe(profile);
        bytes32 id = Evidence.pageId(
            address(next.registry), address(next.coordinator), value, descriptor, 0
        );
        return abi.encodePacked(Archive.appendArtistEvidenceV2.selector, id);
    }
}
