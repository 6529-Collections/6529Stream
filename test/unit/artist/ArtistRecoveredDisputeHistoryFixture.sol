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

import {
    IStreamArtistAttributionRepudiation as Repudiation,
    IStreamArtistRepudiationOwner as RepudiationOwner,
    StreamArtistRepudiationTypes as RP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    IStreamArtistDisputeWithdrawal as Withdrawal,
    IStreamArtistDisputeWithdrawalOwner as WithdrawalOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryValidation as DisputeCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryValidation.sol";
import {
    IStreamArtistNativeReceipts as Native
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAttributionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    StreamArtistDelegationTypes as Delegate
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    IStreamArtistDelegation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegation.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistEconomicsEvidence as Economics
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import {
    RecoveredDelegationSaleFacts
} from "./StreamArtistRecoveredDelegationAuthorityActual.t.sol";
import {
    StreamArtistRecoveredDisputeConsentHistory as ConsentCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeConsentHistory.sol";

import {
    IStreamArtistOwner as OriginalOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";

interface DisputeHistoryVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);

    function expectCall(address, bytes calldata, uint64) external;
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
}

/// @notice Original Safe/signature, dispute/repudiation, recovered Identity and seven-owner imports.
/// @dev Core, roles/action execution and documentary coverage facts are explicit typed boundaries.
/// The actual Store/Artist owners/Safe/Archive are used. This source is not runtime acceptance.
abstract contract ArtistRecoveredDisputeHistoryFixture is StreamArtistRecoveredAuthorityActualTest {
    DisputeHistoryVm internal constant dv =
        DisputeHistoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamSchemaDocumentStore internal documents;
    uint256 internal actionNonce;
    T.Binding[] internal bindings;
    bytes32[] internal acceptances;
    uint64[] internal acceptanceTimes;
    bytes[] internal acceptanceSignatures;
    A.Revocation[] internal revocations;
    T.PolicyConsent[] internal basePolicies;
    bytes32[] internal basePolicyRecords;
    bytes[] internal basePolicySignatures;
    T.EconomicsConsent internal baseEconomics;
    Economics.Association internal baseAssociation;
    bytes32 internal baseEconomicsRecord;
    bytes internal baseEconomicsSignature;
    Sale.Record internal baseSale;
    bytes internal baseSaleSignature;

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

    function _baseline() internal {
        _rhBaseline();
        _adoptRotatedSafe();
        uint64 end = ingress.artistTransitionState(rhRecovery).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
        _saveAcceptance();
    }

    function _saveAcceptance() internal {
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        bindings.push(b);
        bytes32 record = Acceptance(suite.owners[3]).acceptanceRecord(b.bindingHash);
        require(record != 0 && b.accepted, "actual original acceptance");
        acceptances.push(record);
        acceptanceTimes.push(Acceptance(suite.owners[3]).acceptedAt(b.bindingHash));
        acceptanceSignatures.push(Identity(suite.owners[2]).signatureBundle(record));
    }

    function _correctAccepted() internal {
        _correctAndPropose(true);
    }

    function _correctAndPropose(bool acceptNew) internal {
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
        if (!acceptNew) return;
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
        internal
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

    function _evidence(bytes32 parent, bytes32 narrative) internal returns (bytes32 hash) {
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
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _rhRequest();
        r.records.authority.collections[0].policies = new AH.PolicyKey[](basePolicies.length);
        for (uint256 i; i < basePolicies.length; ++i) {
            r.records.authority.collections[0].policies[i] =
                AH.PolicyKey(basePolicies[i].phaseId, basePolicies[i].policyHash);
        }
        if (baseEconomicsRecord != 0) {
            r.records.witnesses = new MR.CollectionWitness[](1);
            r.records.witnesses[0].collectionId = 1;
            r.records.witnesses[0].economics = new T.EconomicsConsent[](1);
            r.records.witnesses[0].economics[0] = baseEconomics;
            r.records.witnesses[0].attestations = new Ready.AttestationInput[](0);
        }
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r);
        r.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _import(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        internal
    {
        dv.recordLogs();
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r))
            ),
            "actual Safe60"
        );
        _rhImported(next, p, HydrationOwner(next.identity).authorityHydrationCommitment());
        _assertArchive(next, r, p, dv.getRecordedLogs());
    }

    function _assertArchive(
        Successor memory next,
        RH.Request memory r,
        Commit.Prepared memory p,
        DisputeHistoryVm.Log[] memory logs
    ) private view {
        bytes32 value = keccak256(
            abi.encode(
                RH.PROFILE,
                uint16(1),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                r,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
        require(
            HydrationOwner(next.identity).authorityHydrationCommitment() == value,
            "independent complete original op60 value"
        );
        bytes memory profile = abi.encode(
            RH.PROFILE,
            uint16(1),
            p.admission.prior,
            p.admission.sourceCoordinator,
            r,
            p.admission.artists,
            p.admission.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
        Evidence.Descriptor memory descriptor = Evidence.describe(profile);
        T.Snapshot[7] memory after_;
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        for (uint8 i; i < 7; ++i) {
            after_[i] = OriginalOwner(target.owners[i]).ownerStateSnapshotV2();
        }
        bytes memory expected = abi.encode(
            uint16(1),
            next.coordinator.configurationHash(),
            uint16(60),
            address(rotationSafe),
            value,
            p.admission.before_,
            after_,
            abi.encode(RH.PROFILE, descriptor)
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                uint16(60),
                address(rotationSafe),
                value
            )
        );
        require(
            keccak256(Archive(target.archive).artistEvidenceBytesV2(id, 1)) == keccak256(expected),
            "exact owner snapshots and original evidence carrier"
        );
        require(
            keccak256(
                Evidence.read(
                    target.archive,
                    address(next.registry),
                    address(next.coordinator),
                    value,
                    descriptor
                )
            ) == keccak256(profile),
            "all original profile bytes retained in Archive"
        );
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            DisputeHistoryVm.Log memory item = logs[i];
            if (
                item.emitter != address(next.coordinator) || item.topics.length != 4
                    || item.topics[0]
                        != keccak256(
                            "RecoveredArtistAuthorityHydrated(uint16,address,bytes32,bytes32,bytes32)"
                        )
            ) continue;
            require(
                item.topics[1] == bytes32(uint256(uint160(p.admission.prior)))
                    && item.topics[2] == value && item.topics[3] == r.expectedSemanticInventory
                    && keccak256(item.data) == keccak256(abi.encode(uint16(1), keccak256(profile))),
                "literal original hydration event"
            );
            ++seen;
        }
        require(seen == 1, "one original op60 event after complete Archive append");
    }

    function _firstPage(Successor memory next, RH.Request memory request, Commit.Prepared memory p)
        internal
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

    function _signedDispute(uint8 action, bytes32 label, bool direct)
        internal
        returns (bytes32 hash)
    {
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        AD.Head memory head = ingress.attributionDispute(1, b.generation);
        bytes32 evidence = _evidence(action == 1 ? bytes32(0) : head.disputeRecordHash, label);
        AD.Filing memory filing = AD.Filing(1, b.generation, action, evidence, evidence);
        AD.Standing memory standing = AD.Standing(artistId, b.generation, 0, 0);
        T.Authorization memory authorization = T.Authorization(
            Identity(suite.owners[2]).identity(artistId).nonceHint,
            direct ? 0 : uint64(block.timestamp + 1 days),
            ""
        );
        bytes32 digest = ingress.attributionDisputeDigest(filing, authorization);
        if (!direct) authorization.signature = _signature(digest);
        bytes memory data = action == 1
            ? abi.encodeCall(Disputes.openAttributionDispute, (filing, standing, authorization))
            : action == 3
                ? abi.encodeCall(Disputes.recordCounterStatement, (filing, standing, authorization))
                : abi.encodeCall(
                    Withdrawal.withdrawAttributionDispute, (filing, standing, authorization)
                );
        uint256 nativeBefore = Native(suite.owners[2]).artistNativeReceiptCount();
        if (direct) {
            require(this.rhExecuteNewSafe(address(ingress), data), "actual direct Safe dispute");
        } else {
            _artistCall(data);
        }
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == nativeBefore,
            "signed authorization has zero Identity native record"
        );
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DISPUTE_RECORD_V1"),
                block.chainid,
                address(ingress),
                uint256(1),
                b.generation,
                action,
                address(artist),
                uint8(1),
                evidence,
                evidence,
                authorization.nonce,
                uint64(block.timestamp)
            )
        );
        AD.Record memory actual = ingress.attributionDisputeRecord(hash);
        require(
            actual.recordHash == hash && actual.nonce == authorization.nonce
                && actual.authorityClass == 1,
            "literal original signed record"
        );
        require(
            keccak256(Identity(suite.owners[2]).signatureBundle(hash))
                == keccak256(authorization.signature),
            "original signed or empty-direct signature"
        );
        _rhAuthorization(digest, authorization.nonce);
        _rhCandidate(
            4,
            action == 1
                ? "attribution_lifecycle.replay.dispute_key"
                : action == 3
                    ? "attribution_lifecycle.replay.counter_statement_key"
                    : "attribution_lifecycle.replay.dispute_withdrawal_key",
            action == 2
                ? head.disputeRecordHash
                : keccak256(
                    abi.encode(
                        uint256(1),
                        b.generation,
                        action == 1 ? bytes32(0) : head.disputeRecordHash,
                        address(artist),
                        evidence,
                        evidence
                    )
                )
        );
        nextNonce = Identity(suite.owners[2]).identity(artistId).nonceHint;
    }

    function _stage(bytes32 reason, bool direct) internal returns (RP.Record memory record) {
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        AD.Filing memory filing = AD.Filing(1, b.generation, 4, 0, reason);
        T.Authorization memory authorization = T.Authorization(
            Identity(suite.owners[2]).identity(artistId).nonceHint,
            direct ? 0 : uint64(block.timestamp + 1 days),
            ""
        );
        bytes32 digest = ingress.attributionRepudiationDigest(filing, authorization);
        if (!direct) authorization.signature = _signature(digest);
        bytes memory data = abi.encodeCall(Repudiation.revokeAttribution, (filing, authorization));
        uint256 before_ = Native(suite.owners[2]).artistNativeReceiptCount();
        if (direct) {
            require(this.rhExecuteNewSafe(address(ingress), data), "actual Safe repudiation");
        } else {
            _artistCall(data);
        }
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == before_,
            "47 has zero Identity native occurrence"
        );
        bytes32 hash = RepudiationOwner(suite.owners[4]).rawPendingRepudiation(1);
        record = ingress.attributionRepudiationRecord(hash);
        require(
            record.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        uint256(1),
                        b.generation,
                        artistId,
                        address(artist),
                        uint8(1),
                        filing.evidenceHash,
                        reason,
                        authorization.nonce,
                        uint64(block.timestamp),
                        record.executableAt
                    )
                ),
            "literal original repudiation"
        );
        _rhAuthorization(digest, authorization.nonce);
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_key", hash);
        nextNonce = Identity(suite.owners[2]).identity(artistId).nonceHint;
    }

    function _cancel(RP.Record memory record) internal {
        require(
            this.rhExecuteNewSafe(
                address(ingress),
                abi.encodeCall(
                    Repudiation.cancelAttributionRepudiation, (uint256(1), record.recordHash)
                )
            ),
            "actual signer cancel"
        );
        _rhCandidate(
            4, "attribution_lifecycle.replay.repudiation_cancellation_key", record.recordHash
        );
    }

    function _execute(RP.Record memory record) internal {
        vm.warp(record.executableAt);
        ingress.executeAttributionRepudiation(1, record.recordHash);
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_execution_key", record.recordHash);
    }

    function _resolve(uint8 choice, uint8 cls) internal returns (bytes32 action) {
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        AD.Head memory h = ingress.attributionDispute(1, b.generation);
        bytes32 evidence =
            _evidence(h.disputeRecordHash, keccak256(abi.encode("resolution", ++actionNonce)));
        AD.ResolutionRequest memory resolution = AD.ResolutionRequest(
            1,
            b.generation,
            h.disputeRecordHash,
            choice,
            evidence,
            evidence,
            h.counterStatementRecordHash
        );
        action = _govern(
            abi.encodeCall(Disputes.resolveAttributionDispute, (resolution)),
            ingress.attributionDisputeResolutionContext(resolution),
            evidence,
            cls
        );
        _rhCandidate(4, "attribution_lifecycle.replay.dispute_resolution_key", h.disputeRecordHash);
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", action);
    }

    function _assertDisputeImport(T.SuiteConfiguration memory target, D.Bundle memory b)
        internal
        view
    {
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(target.owners[4]).attributionState(1);
        require(
            state == b.current.state && generation == b.current.generation,
            "exact current open/revoked/accepted state"
        );
        for (uint256 i; i < b.heads.length; ++i) {
            require(
                keccak256(
                    abi.encode(DisputeOwner(target.owners[4]).attributionDispute(1, uint64(i + 1)))
                ) == keccak256(abi.encode(b.heads[i])),
                "full original head"
            );
        }
        for (uint256 i; i < b.disputes.length; ++i) {
            AD.Record memory row = b.disputes[i].record;
            require(
                keccak256(
                    abi.encode(
                        DisputeOwner(target.owners[4]).attributionDisputeRecord(row.recordHash)
                    )
                ) == keccak256(abi.encode(row)),
                "original full dispute row"
            );
            require(
                keccak256(
                    abi.encode(
                        WithdrawalOwner(target.owners[4])
                            .attributionDisputeWithdrawal(row.recordHash)
                    )
                ) == keccak256(abi.encode(b.disputes[i].withdrawal)),
                "original immutable withdrawal"
            );
            if (row.governanceActionId == 0) {
                require(
                    keccak256(Identity(target.owners[2]).signatureBundle(row.recordHash))
                        == keccak256(Identity(suite.owners[2]).signatureBundle(row.recordHash)),
                    "full original signature"
                );
            }
        }
        for (uint256 i; i < b.resolutions.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        DisputeOwner(target.owners[4])
                            .attributionDisputeResolution(b.resolutions[i].record.actionId)
                    )
                ) == keccak256(abi.encode(b.resolutions[i].record)),
                "immutable original resolution action"
            );
        }
        for (uint256 i; i < b.repudiations.length; ++i) {
            RP.Record memory row = b.repudiations[i].record;
            require(
                keccak256(
                    abi.encode(
                        RepudiationOwner(target.owners[4])
                            .attributionRepudiationRecord(row.recordHash)
                    )
                ) == keccak256(abi.encode(row)),
                "complete original staged authority head"
            );
            require(
                keccak256(
                    abi.encode(
                        RepudiationOwner(target.owners[4])
                            .attributionRepudiationTerminal(row.recordHash)
                    )
                ) == keccak256(abi.encode(b.repudiations[i].terminal)),
                "original terminal"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(row.recordHash))
                    == keccak256(Identity(suite.owners[2]).signatureBundle(row.recordHash)),
                "original repudiation signature"
            );
        }
        require(
            RepudiationOwner(target.owners[4]).rawPendingRepudiation(1) == b.pending,
            "original pending pointer"
        );
    }

    function _bundle(Commit.Prepared memory p) internal pure returns (D.Bundle memory b) {
        (RH.ExportHeader memory h, Payload.Payload memory local) =
            Payload.decode(p.data[4].typedState, 4);
        require((h.requiredFeatures & 8192) != 0, "closed additional history capability");
        b = DisputeCodec.decode(p.query, local.provenance, local.semanticState);
        require(
            keccak256(local.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_DISPUTE_HISTORY_V1"), uint16(1), b
                    )
                ),
            "literal canonical history envelope"
        );
    }

    function _correctExecuted(bytes32 witness) internal {
        T.Binding memory previous = Binding(suite.owners[0]).binding(1);
        T.Identity memory identity = Identity(suite.owners[2]).identity(artistId);
        T.BindingProposal memory proposal = _proposal(artistId);
        proposal.identityRecordHash = identity.identityRecordHash;
        proposal.reasonHash = keccak256(abi.encode("fresh exact corrective1", previous.generation));
        bytes memory document =
            Identity(suite.owners[2]).identityDocumentBytes(identity.identityRecordHash);
        (BC.Context memory c,) =
            Admission.context(suite, 1, proposal, document, identity.displayName, witness);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        bytes32 action = _govern(
            abi.encodeCall(
                Correction.proposeArtistBindingAfterRevocation,
                (uint256(1), proposal, document, identity.displayName, witness)
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

    function _veto(RP.Record memory staged) internal returns (bytes32 contest) {
        bytes32 reason = keccak256("guardian veto after recovered original authority");
        uint256 before_ = Native(suite.owners[2]).artistNativeReceiptCount();
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    Repudiation.vetoAttributionRepudiation, (uint256(1), staged.recordHash, reason)
                ),
                0
            ),
            "actual guardian Safe48"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == before_ + 2,
            "exact paired48 native receipts"
        );
        contest = ingress.currentIdentityContestCause(artistId).facts.referenceHash;
        require(
            Native(suite.owners[2]).artistNativeReceiptAt(before_).operation == 48
                && Native(suite.owners[2]).artistNativeReceiptAt(before_).recordHash == contest
                && Native(suite.owners[2]).artistNativeReceiptAt(before_ + 1).operation == 48
                && Native(suite.owners[2]).artistNativeReceiptAt(before_ + 1).recordHash
                    == ingress.currentIdentityContestCause(artistId).causeHash,
            "original Contest then Cause pair"
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(
                abi.encode(keccak256("subject"), artistId, bytes32(0), staged.recordHash, reason)
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), contest))
        );
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_veto_key", staged.recordHash);
    }

    function _grantDispute(uint64 maximum) internal returns (bytes32 record) {
        Delegate.Grant memory terms = _delegation(
            1, 16, uint64(block.timestamp), uint64(block.timestamp + 365 days), maximum
        );
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(terms, a);
        record = _grant(terms);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
    }

    function _delegatedDispute(uint8 action, bytes32 grant, uint256 nonce)
        internal
        returns (bytes32 record)
    {
        T.Binding memory binding = Binding(suite.owners[0]).binding(1);
        bytes32 opening = ingress.attributionDispute(1, binding.generation).disputeRecordHash;
        bytes32 evidence = _evidence(
            action == 1 ? bytes32(0) : opening, keccak256(abi.encode("delegate", action, nonce))
        );
        AD.Filing memory filing = AD.Filing(1, binding.generation, action, evidence, evidence);
        AD.Standing memory standing = AD.Standing(artistId, binding.generation, 0, grant);
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.attributionDisputeDigest(filing, a);
        a.signature = _delegateSignature(digest);
        if (action == 1) {
            record = ingress.openAttributionDispute(filing, standing, a);
        } else {
            record = Withdrawal(address(ingress)).withdrawAttributionDispute(filing, standing, a);
        }
        bytes32 lane = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                artistId,
                address(delegateSafe)
            )
        );
        _rhCandidate(
            2, "identity_authority.replay.delegated_nonce", keccak256(abi.encode(lane, nonce))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _rhCandidate(
            4,
            action == 1
                ? "attribution_lifecycle.replay.dispute_key"
                : "attribution_lifecycle.replay.dispute_withdrawal_key",
            action == 1
                ? keccak256(
                    abi.encode(
                        uint256(1),
                        binding.generation,
                        bytes32(0),
                        address(delegateSafe),
                        evidence,
                        evidence
                    )
                )
                : opening
        );
        require(
            ingress.attributionDisputeRecord(record).standing.delegation == grant,
            "saved historical grant"
        );
    }

    function _revokeDisputeGrant(bytes32 grant) internal {
        T.Authorization memory a = _authorization(false);
        bytes32 reason = keccak256("revoke used dispute grant");
        Delegate.Revocation memory terms =
            Delegate.Revocation(artistId, address(delegateSafe), grant, reason);
        bytes32 digest = ingress.delegationRevocationDigest(terms, a);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistDelegation.revokeArtistDelegation, (terms, a)));
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(2, "identity_authority.replay.one_way_delegation_revocation", grant);
    }

    function _basePolicy() internal {
        T.PolicyConsent memory terms = T.PolicyConsent(
            1,
            keccak256(abi.encode("prior-era phase", basePolicies.length)),
            keccak256(abi.encode("prior-era policy", basePolicies.length))
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.policyConsentDigest(terms, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordPolicyConsent(terms, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(terms.collectionId, terms.phaseId, terms.policyHash))
        );
        basePolicies.push(terms);
        basePolicyRecords.push(record);
        basePolicySignatures.push(a.signature);
    }

    function _baseConsents() internal {
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        T.PayoutDesignation memory payout = T.PayoutDesignation(artistId, b.artistAddress, 0);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.payoutDesignationDigest(payout, a);
        a.signature = _signature(digest);
        ingress.recordPayoutDesignation(payout, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId))
        );
        _basePolicy();
        (T.AssignmentFact memory fact,) = coordinator.reads().currentAssignments(1);
        T.EconomicsConsent memory e = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        a = _authorization(false);
        digest = ingress.economicsConsentDigest(e, a);
        a.signature = _signature(digest);
        baseEconomicsRecord = ingress.recordEconomicsConsent(e, a);
        baseEconomics = e;
        baseAssociation = Economics(suite.owners[6]).economicsRecordAssociation(baseEconomicsRecord);
        baseEconomicsSignature = a.signature;
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(e)));
        RecoveredDelegationSaleFacts facts = new RecoveredDelegationSaleFacts(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(facts),
            facts.streamModuleType(),
            facts.streamModuleInterfaceId()
        );
        Sale.Consent memory sale = Sale.Consent(1, address(facts), facts.ID(), facts.CONFIG());
        a = _authorization(false);
        digest = ingress.saleConsentDigest(sale, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordSaleConsent(sale, a);
        baseSale = Sales(suite.owners[6]).saleConsentRecord(record);
        baseSaleSignature = a.signature;
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.sale_consent_key",
            keccak256(abi.encode(sale, b.generation, b.bindingHash))
        );
        require(
            baseAssociation.bindingGeneration == 1 && baseSale.bindingGeneration == 1,
            "genuine original first-generation consent"
        );
    }

    function _assertBaseConsents(T.SuiteConfiguration memory target) internal view {
        for (uint256 i; i < basePolicies.length; ++i) {
            require(
                Consent(target.owners[6])
                    .policyRecord(1, basePolicies[i].phaseId, basePolicies[i].policyHash)
                == basePolicyRecords[i],
                "all original policy records"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(basePolicyRecords[i]))
                    == keccak256(basePolicySignatures[i]),
                "exact original policy signature"
            );
        }
        require(
            Consent(target.owners[6]).economicsRecord(baseEconomics) == baseEconomicsRecord
                && keccak256(
                    abi.encode(
                        Economics(target.owners[6]).economicsRecordAssociation(baseEconomicsRecord)
                    )
                ) == keccak256(abi.encode(baseAssociation)),
            "exact original economics record and association"
        );
        require(
            Economics(target.owners[6])
                .economicsRecordForBinding(
                    baseEconomics,
                    artistId,
                    baseAssociation.bindingGeneration,
                    baseAssociation.bindingHash
                ) == baseEconomicsRecord,
            "historical generation association remains addressable"
        );
        T.Binding memory current = Binding(target.owners[0]).binding(1);
        require(
            current.generation == 2
                && Economics(target.owners[6])
                    .economicsRecordForBinding(
                        baseEconomics, artistId, current.generation, current.bindingHash
                    ) == 0,
            "no current-generation economics alias"
        );
        require(
            keccak256(abi.encode(Sales(target.owners[6]).saleConsentRecord(baseSale.recordHash)))
                == keccak256(abi.encode(baseSale)),
            "full historical sale preimage"
        );
        require(
            Sales(target.owners[6])
                .saleConsentAt(1, baseSale.terms.saleId, baseSale.terms.saleConfigHash)
            == baseSale.recordHash,
            "retained original sale index"
        );
        require(
            keccak256(Identity(target.owners[2]).signatureBundle(baseSale.recordHash))
                    == keccak256(baseSaleSignature)
                && keccak256(Identity(target.owners[2]).signatureBundle(baseEconomicsRecord))
                    == keccak256(baseEconomicsSignature),
            "exact original15/16 signatures"
        );
    }
}
