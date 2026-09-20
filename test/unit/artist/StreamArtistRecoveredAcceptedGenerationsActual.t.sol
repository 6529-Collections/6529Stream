// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAuthorityActualTest
} from "./StreamArtistRecoveredAuthorityActual.t.sol";
import { ArtistUnitGovernance, ArtistUnitRoles } from "./ArtistOnboardingFixture.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydration as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection as Correction,
    IStreamArtistBindingCorrectionOwner as CorrectionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistBindingCorrectionAdmission as Admission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistAttributionDisputeTypes as AD,
    IStreamArtistAttributionDisputes as Disputes,
    IStreamArtistAttributionDisputesOwner as DisputeOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
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
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedBindingHydration as BindingCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedBindingHydration.sol";
import {
    StreamArtistRecoveredAcceptanceHistory as AcceptanceCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptanceHistory.sol";
import {
    StreamArtistRecoveredRevokedAttribution as AttributionCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRevokedAttribution.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionHydration as OldCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionHydration.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCollectionArchivalCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";
import {
    StreamArchivalTypes as Archival
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    IStreamArtistIdentityRecovery
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";

import {
    IStreamArtistHistory as History,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

interface AcceptedHistoryVm {
    function expectCall(address, bytes calldata, uint64) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
}

/// @notice Actual original governed44/46, corrective1, Safe2/recovery35 and atomic seven-owner60.
/// @dev Core, exact governance action/roles, Metadata getters and archival coverage facts are typed
/// boundaries. Documentary Store, all Artist owner maps/replays, Safe and Archive are actual.
/// These authored cases do not claim delayed Executor/full current graph or runtime acceptance.
contract StreamArtistRecoveredAcceptedGenerationsActualTest is
    StreamArtistRecoveredAuthorityActualTest
{
    AcceptedHistoryVm private constant tv =
        AcceptedHistoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamSchemaDocumentStore private documents;
    uint256 private actionNonce;
    T.Binding[] private bindings;
    bytes32[] private acceptances;
    uint64[] private acceptanceTimes;
    bytes[] private acceptanceSignatures;
    A.Revocation[] private revocations;

    function testAcceptedRevocationCorrectionRetainsEveryOriginalMapAndSignature() external {
        _baseline();
        _correctAccepted();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory bp) = Payload.decode(p.data[0].typedState, 0);
        CB.Bundle memory b = BindingCodec.decode(p.query, bp.provenance, bp.semanticState);
        require(
            keccak256(bp.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_ACCEPTED_BINDINGS_V1"), uint16(1), b
                    )
                ),
            "literal accepted binding codec"
        );
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & 6656) == 6656,
                "all seven generation/correction/accepted capabilities"
            );
        }
        _import(next, r, p);
        _assert(next.coordinator.suiteConfiguration());
        _assert(suite);
    }

    function testAcceptedCorrectionAfterImportUsesActualSecondEraDomainsAndClocks() external {
        _baseline();
        Successor memory middle = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(middle);
        _import(middle, r, p);
        _rhAdopt(middle);
        _correctAccepted();
        Successor memory last = _rhCutover();
        (r, p) = _prepare(last);
        require(p.admission.provenance.eras.length == 2, "complete A and B provenance");
        require(
            p.admission.provenance.journals[0][1].position.point.ownerRevision == 2,
            "B proposal after import revision1"
        );
        require(
            p.admission.provenance.journals[4][0].position.point.ownerRevision == 2,
            "B opening after import revision1"
        );
        require(
            p.admission.provenance.journals[0][1].position.point.environmentHash
                != p.admission.provenance.journals[0][0].position.point.environmentHash,
            "original distinct registry domains"
        );
        _import(last, r, p);
        _assert(last.coordinator.suiteConfiguration());
        _assert(suite);
    }

    function testThreeAcceptedGenerationsRetainBothRevocationCausesAndRepeatedImport() external {
        _baseline();
        _correctAccepted();
        _correctAccepted();
        Successor memory middle = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(middle);
        _import(middle, r, p);
        _assert(middle.coordinator.suiteConfiguration());
        _rhAdopt(middle);
        Successor memory last = _rhCutover();
        (r, p) = _prepare(last);
        require(
            p.admission.provenance.journals[3].length == 3
                && p.admission.provenance.journals[4].length == 2,
            "no hidden original receipt subset"
        );
        _import(last, r, p);
        _assert(last.coordinator.suiteConfiguration());
    }

    function testAcceptedBindingRejectsMissingCauseWrongOriginAndOldPendingCodec() external {
        _baseline();
        _correctAccepted();
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory local) = Payload.decode(p.data[0].typedState, 0);
        CB.Bundle memory original =
            BindingCodec.decode(p.query, local.provenance, local.semanticState);
        for (uint8 i; i < 5; ++i) {
            CB.Bundle memory b = abi.decode(abi.encode(original), (CB.Bundle));
            if (i == 0) delete b.corrections[1];
            if (i == 1) b.corrections[1].approval.cause = 1;
            if (i == 2) b.corrections[1].approval.governance.actionClass = 1;
            if (i == 3) b.bindings.rows[0].item.accepted = false;
            if (i == 4) b.corrections[1].recordHash = keccak256("wrong original registry");
            tv.expectRevert();
            this.decodeBinding(p.query, local.provenance, abi.encode(A.BINDING, uint16(1), b));
        }
        tv.expectRevert();
        this.decodeOld(p.query, local.provenance, local.semanticState);
    }

    function testAcceptedAttributionRejectsIncompleteHistoryHeadResolutionAndReplay() external {
        _baseline();
        _correctAccepted();
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory local) = Payload.decode(p.data[4].typedState, 4);
        A.AttributionBundle memory original =
            AttributionCodec.decode(p.query, local.provenance, local.semanticState);
        for (uint8 i; i < 5; ++i) {
            A.AttributionBundle memory b = abi.decode(abi.encode(original), (A.AttributionBundle));
            if (i == 0) b.revocations = new A.Revocation[](0);
            if (i == 1) b.revocations[0].head.open = true;
            if (i == 2) b.revocations[0].resolution.actionClass = 1;
            if (i == 3) b.revocations[0].opening.bindingHash = p.query.bindingHash;
            if (i == 4) b.generations[0].proposal.environmentHash = keccak256("missing era");
            tv.expectRevert();
            this.decodeAttribution(
                p.query, local.provenance, abi.encode(A.ATTRIBUTION, uint16(1), b)
            );
        }
        local.provenance.aliases[0].cell.commitment = keccak256("foreign replay");
        tv.expectRevert();
        this.decodeAttribution(p.query, local.provenance, local.semanticState);
    }

    function testAcceptedMissingReplayAndCapabilityRefuseBeforeAnyImport() external {
        _baseline();
        _correctAccepted();
        Successor memory next = _rhCutover();
        (RH.Request memory r,) = _prepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        r.expectedCapabilities[4].supportedFeatures &= ~uint256(4096);
        tv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        r.expectedCapabilities[4].supportedFeatures |= 4096;
        r.records.authority.replayOrigins[4][0].scope = keccak256("omitted original action");
        tv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(_rhDestinationHash(next) == before_, "original roots remain empty");
    }

    function testAcceptedLateArchiveFailureRollsBackAllMapsAndSameSafeRequestRetries() external {
        _baseline();
        _correctAccepted();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        bytes memory data = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r));
        tv.expectCall(next.coordinator.suiteConfiguration().archive, _firstPage(next, r, p), 2);
        bytes32 before_ = _rhDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        tv.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), data);
        require(
            _rhDestinationHash(next) == before_ && rotationSafe.nonce() == nonce,
            "all owner maps/roots and Safe nonce rollback"
        );
        require(
            DisputeOwner(next.coordinator.suiteConfiguration().owners[4])
            .attributionDispute(1, 1)
            .disputeRecordHash == 0,
            "imported dispute removed by rollback"
        );
        require(
            Acceptance(next.coordinator.suiteConfiguration().owners[3])
                .acceptanceRecord(bindings[0].bindingHash) == 0,
            "old acceptance removed by rollback"
        );
        vm.roll(height);
        require(this.rhExecuteNewSafe(address(next.registry), data), "identical request retry");
        require(rotationSafe.nonce() == nonce + 1, "one committed Safe execution");
        _assert(next.coordinator.suiteConfiguration());
    }

    function testAcceptedSourceResolutionDriftFailsThenRestoredExactSourceImports() external {
        _baseline();
        _correctAccepted();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        AD.Resolution memory bad = revocations[0].resolution;
        bad.previousResolutionActionId = keccak256("hidden earlier resolution");
        bytes memory input =
            abi.encodeCall(DisputeOwner.attributionDisputeResolution, (bad.actionId));
        avm.mockCall(suite.owners[4], input, abi.encode(bad));
        tv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(_rhDestinationHash(next) == before_, "drift before imports");
        avm.mockCall(suite.owners[4], input, abi.encode(revocations[0].resolution));
        _import(next, r, p);
        _assert(next.coordinator.suiteConfiguration());
    }

    function decodeBinding(AH.Query calldata q, RH.OwnerProvenance calldata p, bytes calldata raw)
        external
        pure
    {
        BindingCodec.decode(q, p, raw);
    }

    function decodeOld(AH.Query calldata q, RH.OwnerProvenance calldata p, bytes calldata raw)
        external
        pure
    {
        OldCodec.decode(q, p, raw);
    }

    function decodeAttribution(
        AH.Query calldata q,
        RH.OwnerProvenance calldata p,
        bytes calldata raw
    ) external pure {
        AttributionCodec.decode(q, p, raw);
    }

    function _rhExecuteRecovery(Recovery.Request memory p, T.Authorization memory a)
        internal
        override
        returns (bytes32)
    {
        Recovery.Context memory c = ingress.identityRecoveryContext(p, a);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.executeModuleContextWithAction(
            currentId,
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRecovery.recoverArtistIdentity, (p, a)),
            2,
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        (bool active, bytes32 action, uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            authority.currentAction();
        require(
            !active && action == 0 && cls == 0 && scope == 0 && oldHash == 0 && newHash == 0,
            "scoped actual recovery context cleared without persistent mocks"
        );
        return ingress.latestIdentityRecovery(artistId);
    }

    function _rhCommitHistory(
        Successor memory next,
        HT.Context memory c,
        bytes32 root,
        bytes32 manifest
    ) internal override {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        require(
            this.executeTargetSafe(
                address(authority),
                abi.encodeCall(
                    ArtistUnitGovernance.executeModuleContextWithAction,
                    (
                        keccak256("unit authority gas raise"),
                        address(next.registry),
                        abi.encodeCall(
                            History.commitArtistHistoryImportRoot,
                            (address(ingress), uint64(block.number), root, manifest)
                        ),
                        uint8(1),
                        c.scopeHash,
                        c.oldValueHash,
                        c.newValueHash
                    )
                )
            ),
            "actual Safe governed55 with scoped original witness"
        );
        (bool active, bytes32 action, uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            authority.currentAction();
        require(
            !active && action == 0 && cls == 0 && scope == 0 && oldHash == 0 && newHash == 0,
            "all-zero actual55 context without persistent mock"
        );
    }

    function _baseline() private {
        _rhBaseline();
        _adoptRotatedSafe();
        uint64 end = ingress.artistTransitionState(rhRecovery).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
        _saveAcceptance();
    }

    function _saveAcceptance() private {
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        bindings.push(b);
        bytes32 record = Acceptance(suite.owners[3]).acceptanceRecord(b.bindingHash);
        require(record != 0 && b.accepted, "actual original acceptance");
        acceptances.push(record);
        acceptanceTimes.push(Acceptance(suite.owners[3]).acceptedAt(b.bindingHash));
        acceptanceSignatures.push(Identity(suite.owners[2]).signatureBundle(record));
    }

    function _correctAccepted() private {
        T.Binding memory previous = Binding(suite.owners[0]).binding(1);
        bytes32 evidence = _evidence(0, keccak256(abi.encode("opening", previous.generation)));
        AD.Filing memory filing = AD.Filing(1, previous.generation, 1, evidence, evidence);
        AD.Standing memory noStanding;
        T.Authorization memory noAuthorization;
        bytes32 openingAction = _govern(
            abi.encodeCall(Disputes.openAttributionDispute, (filing, noStanding, noAuthorization)),
            ingress.attributionDisputeOpeningContext(filing),
            evidence,
            1
        );
        AD.Head memory head = ingress.attributionDispute(1, previous.generation);
        AD.Record memory opening = ingress.attributionDisputeRecord(head.disputeRecordHash);
        require(
            opening.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DISPUTE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        uint256(1),
                        previous.generation,
                        uint8(1),
                        address(artist),
                        uint8(0),
                        evidence,
                        evidence,
                        uint256(0),
                        uint64(block.timestamp)
                    )
                ),
            "literal original governed44 record"
        );
        _rhCandidate(
            4,
            "attribution_lifecycle.replay.dispute_key",
            keccak256(
                abi.encode(
                    uint256(1), previous.generation, bytes32(0), address(artist), evidence, evidence
                )
            )
        );
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", openingAction);
        evidence =
            _evidence(opening.recordHash, keccak256(abi.encode("resolution", previous.generation)));
        AD.ResolutionRequest memory resolution = AD.ResolutionRequest(
            1, previous.generation, opening.recordHash, 2, evidence, evidence, 0
        );
        bytes32 resolutionAction = _govern(
            abi.encodeCall(Disputes.resolveAttributionDispute, (resolution)),
            ingress.attributionDisputeResolutionContext(resolution),
            evidence,
            2
        );
        _rhCandidate(4, "attribution_lifecycle.replay.dispute_resolution_key", opening.recordHash);
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", resolutionAction);
        revocations.push(
            A.Revocation(
                ingress.attributionDispute(1, previous.generation),
                opening,
                ingress.attributionDisputeResolution(resolutionAction)
            )
        );
        T.Identity memory identity = Identity(suite.owners[2]).identity(artistId);
        T.BindingProposal memory proposal = _proposal(artistId);
        proposal.identityRecordHash = identity.identityRecordHash;
        proposal.reasonHash = keccak256(abi.encode("fresh exact corrective1", previous.generation));
        bytes memory document =
            Identity(suite.owners[2]).identityDocumentBytes(identity.identityRecordHash);
        (BC.Context memory c,) =
            Admission.context(suite, 1, proposal, document, identity.displayName, 0);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        bytes32 action = _govern(
            abi.encodeCall(
                Correction.proposeArtistBindingAfterRevocation,
                (uint256(1), proposal, document, identity.displayName, bytes32(0))
            ),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            proposal.reasonHash,
            2
        );
        _rhCandidate(0, "binding_lifecycle.replay.correction_action", action);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(1), previous.generation + 1))
        );
        T.Authorization memory authorization = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(1, authorization);
        authorization.signature = _signature(digest);
        _rhAuthorization(digest, authorization.nonce);
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (uint256(1), authorization))
        );
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), previous.generation + 1, uint8(1), address(artist)))
        );
        _saveAcceptance();
    }

    function _govern(bytes memory data, AD.Context memory c, bytes32 reason, uint8 cls)
        private
        returns (bytes32 action)
    {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:accepted-generation:typed-governance"
        );
        action = keccak256(
            abi.encode("scoped original action", address(ingress), ++actionNonce, data, c)
        );
        authority.executeModuleContextWithAction(
            action, address(ingress), data, cls, c.scopeHash, c.oldValueHash, c.newValueHash
        );
    }

    function _evidence(bytes32 parent, bytes32 narrative) private returns (bytes32 hash) {
        if (address(documents) == address(0)) documents = new StreamSchemaDocumentStore();
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        bytes memory data =
            abi.encode(AD.Evidence(1, 1, b.generation, b.bindingHash, parent, narrative));
        (hash,) = documents.publishChunk(data);
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.core, ()),
            abi.encode(address(core))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.chunkStore, ()),
            abi.encode(address(documents))
        );
        Archival.CoverageFacts memory f;
        f.coverageRecordHash = keccak256(abi.encode("typed original coverage", hash));
        f.envelopeHash = keccak256(abi.encode("typed original envelope", hash));
        f.evidenceHash = hash;
        avm.mockCall(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence, (uint256(1), hash)
            ),
            abi.encode(f)
        );
    }

    function _prepare(Successor memory next)
        private
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _rhRequest();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r);
        r.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _import(Successor memory next, RH.Request memory r, Commit.Prepared memory p) private {
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r))
            ),
            "actual Safe60"
        );
        _rhImported(next, p, HydrationOwner(next.identity).authorityHydrationCommitment());
    }

    function _assert(T.SuiteConfiguration memory target) private view {
        for (uint256 i; i < bindings.length; ++i) {
            require(
                keccak256(abi.encode(Binding(target.owners[0]).bindingAt(1, uint64(i + 1))))
                    == keccak256(abi.encode(bindings[i])),
                "every original accepted binding"
            );
            require(
                Acceptance(target.owners[3]).acceptanceRecord(bindings[i].bindingHash)
                    == acceptances[i],
                "every original acceptance record"
            );
            require(
                Acceptance(target.owners[3]).acceptedAt(bindings[i].bindingHash)
                    == acceptanceTimes[i],
                "every original acceptance timestamp"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(acceptances[i]))
                    == keccak256(acceptanceSignatures[i]),
                "original signed acceptance bytes"
            );
        }
        for (uint256 i; i < revocations.length; ++i) {
            A.Revocation memory r = revocations[i];
            require(
                keccak256(
                    abi.encode(DisputeOwner(target.owners[4]).attributionDispute(1, uint64(i + 1)))
                ) == keccak256(abi.encode(r.head)),
                "original closed head"
            );
            require(
                keccak256(
                    abi.encode(
                        DisputeOwner(target.owners[4])
                            .attributionDisputeRecord(r.opening.recordHash)
                    )
                ) == keccak256(abi.encode(r.opening)),
                "original governed opening"
            );
            require(
                keccak256(
                    abi.encode(
                        DisputeOwner(target.owners[4])
                            .attributionDisputeResolution(r.resolution.actionId)
                    )
                ) == keccak256(abi.encode(r.resolution)),
                "original immutable class2 resolution"
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
