// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAuthorityActualTest
} from "./StreamArtistRecoveredAuthorityActual.t.sol";
import { PersonhoodDocumentFixture } from "./StreamArtistPersonhoodEvidence.t.sol";
import { ArtistUnitGovernance } from "./ArtistOnboardingFixture.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistRecoveredHydration as Recovered,
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner,
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistReconstruction as Reconstruction
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    StreamArtistIdentityRevisionTypes as Doc
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads as Credentials
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistPersonhoodEvidence as PersonhoodRead,
    StreamArtistPersonhoodTypes as P
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistPersonhoodJSON as PersonhoodJSON
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodJSON.sol";
import {
    StreamArtistPersonhoodDefinitions as PersonhoodDefinitions
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";
import {
    StreamGeneralAttestations
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestations.sol";
import {
    IStreamGeneralAttestations as General
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import {
    IStreamCollectionAttestations as Subjects
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import {
    StreamGeneralAttestationDefinitions as GeneralDefinitions
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestationDefinitions.sol";
import {
    StreamOwnerNoticeTypes as Notice
} from "../../../smart-contracts/interfaces/stream/metadata/StreamOwnerNoticeTypes.sol";
import {
    IStreamSchemaRegistry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamModuleRegistration
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

import {
    StreamSchemaRegistry
} from "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamCollectionMetadataV1
} from "../../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import {
    IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamPreservationRecords
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    StreamC2PAReconciliation
} from "../../../smart-contracts/domains/metadata/StreamC2PAReconciliation.sol";
import {
    IStreamC2PAReconciliation as CR
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import { MetadataExecutorBoundary } from "../metadata/StreamCollectionMetadataV1.t.sol";
import {
    IStreamStaticMetadataRouter as SR
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    StreamCollectionManifestTypes as CM
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamCollectionManifestWriter,
    IStreamMetadataManifestSelection
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    IStreamMetadataServingFacts as C2PAServing
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Actual original35/24, seven owners, Registry, Coordinator, Archive and threshold Safes.
/// @dev Core and governance remain explicit typed fixture boundaries. General/Schema/Store and
/// original signed documentary receipts are real; synthetic instrument references assert no legal
/// person or cryptographic C2PA truth. No capability, checkpoint, imported state or provenance mocks.
contract StreamArtistRecoveredAttestationAuthorityActualTest is
    StreamArtistRecoveredAuthorityActualTest
{
    bytes32 internal constant CREDENTIAL_SCHEMA =
        keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");
    uint256 private constant NOTARY_KEY = 0x123451;
    uint256 private constant ATTESTATION_FEATURE = 128;

    struct Original {
        Ready.AttestationInput input;
        T.AttestationRecord record;
        uint8 authorityClass;
        Attest.Association association;
        bytes statement;
        bytes signature;
        bytes32 digest;
        RH.Position position;
        RH.Point authorizationPoint;
        C2PA.Head credential;
        P.Summary summary;
        bytes32 summaryHash;
        address registry;
    }

    Original[] internal raRows;
    PersonhoodDocumentFixture internal raDocuments;
    StreamGeneralAttestations internal raNotary;
    uint256 private raNotaryNonce;
    uint64 private raDelegateSignedAt;
    uint256 private constant SECOND_DELEGATE_KEY = 0xD311;

    constructor() {
        actualSaleRegistryFixture = true;
    }

    function testRecoveredAttestationActualOriginalsAndIndependentHeads() external {
        _raBaseline();
        bytes32 primaryRecord = _raPrimary(0, 0);
        bytes32 deployment = _raDeployment();
        bytes32 notarized = _raNotarize(0);
        bytes32 personhood = _raPersonhood(notarized);
        bytes32 first = _raCredential(0, false);
        bytes32 empty = _raCredential(first, true);
        bytes32 last = _raCredential(empty, false);
        require(primaryRecord != deployment && last != personhood, "separate original subjects");
        _raStatus(suite.owners[4], P.Status.RESOLVED, personhood);
        T.SuiteConfiguration memory original = suite;
        uint256 count = raRows.length;
        Successor memory next = _rhCutover();
        bytes32 before_ = _raSource(original, count);
        _raTransfer(next);
        _raAssert(next.coordinator.suiteConfiguration(), count);
        _raStatus(next.coordinator.suiteConfiguration().owners[4], P.Status.RESOLVED, personhood);
        require(
            _raSource(original, count) == before_,
            "all original owners and documentary bytes unchanged"
        );
        _rhAdopt(next);
        bytes32 sameFacts = Hashes.deploymentFacts(
            Hashes.Environment(block.chainid, address(ingress), address(core), address(manager)),
            1,
            ingress.displayBinding(1)
        );
        require(
            sameFacts == raRows[1].record.subjectStateHash,
            "registry cutover alone does not stale original deployment facts"
        );
        bytes32 fresh = _raCredential(last, true);
        require(
            Credentials(suite.owners[4]).c2paCredentialRecord(fresh).sourceRegistry
                == address(ingress),
            "new credential uses actual successor domain"
        );
        _raStatus(suite.owners[4], P.Status.RESOLVED, personhood);
        require(
            _raSource(original, count) == before_,
            "frozen source count excludes newly authored successor rows"
        );
    }

    function testRecoveredAttestationSecondImportKeepsUltimateOriginsAndFreshIdentityTruth()
        external
    {
        _raBaseline();
        bytes32 initialIdentity = ingress.operativeIdentityRecord(artistId);
        bytes32 oldPersonhood = _raPersonhood(_raNotarize(0));
        bytes32 oldCredentials = _raCredential(0, false);
        T.SuiteConfiguration memory first = suite;
        uint256 firstCount = raRows.length;
        Successor memory middle = _rhCutover();
        _raTransfer(middle);
        bytes32 firstBefore = _raSource(first, firstCount);
        _rhAdopt(middle);
        _raRevise(bytes("genuine successor B operative identity document"));
        require(
            ingress.displayBinding(1).identityRecordHash == initialIdentity
                && ingress.operativeIdentityRecord(artistId) != initialIdentity,
            "original registration differs from current operative identity"
        );
        _raStatus(suite.owners[4], P.Status.STALE, oldPersonhood);
        require(
            Credentials(suite.owners[4]).c2paCredentialHead(artistId).identityRecordHash
                == initialIdentity,
            "old credential head stays exact, not relabeled current"
        );
        _raDocumentary();
        bytes32 freshPersonhood = _raPersonhood(_raNotarize(0));
        bytes32 freshCredentials = _raCredential(oldCredentials, false);
        _raStatus(suite.owners[4], P.Status.RESOLVED, freshPersonhood);
        T.SuiteConfiguration memory second = suite;
        uint256 secondCount = raRows.length;
        Successor memory last = _rhCutover();
        bytes32 secondBefore = _raSource(second, secondCount);
        _raTransfer(last);
        _raAssert(last.coordinator.suiteConfiguration(), secondCount);
        _raStatus(
            last.coordinator.suiteConfiguration().owners[4], P.Status.RESOLVED, freshPersonhood
        );
        require(
            _raSource(first, firstCount) == firstBefore
                && _raSource(second, secondCount) == secondBefore,
            "second import never rewrites A or B source states"
        );
        _rhAdopt(last);
        bytes32 withdrawn = _raCredential(freshCredentials, true);
        require(
            Credentials(suite.owners[4]).c2paCredentialRecord(withdrawn).previousRecordHash
                == freshCredentials,
            "fresh C continues B head without reusing A authority"
        );
        _raStatus(suite.owners[4], P.Status.RESOLVED, freshPersonhood);
        require(
            _raSource(first, firstCount) == firstBefore
                && _raSource(second, secondCount) == secondBefore,
            "fresh C does not pollute saved source oracle inventories"
        );
    }

    function testRecoveredAttestationStaleNotarizationDoesNotRewriteNativeSelection() external {
        _raBaseline();
        bytes32 old = _raNotarize(0);
        bytes32 selected = _raPersonhood(old);
        bytes32 nextNotarization = _raNotarize(old);
        _raStatus(suite.owners[4], P.Status.STALE, selected);
        P.Selection memory before_ = PersonhoodRead(suite.owners[4]).personhoodEvidence(1, artistId);
        require(
            before_.notarizationHead == nextNotarization
                && before_.evidenceReference.notarizationRecordHash == old,
            "real latest General receipt differs from retained native selection"
        );
        Successor memory next = _rhCutover();
        _raTransfer(next);
        address target = next.coordinator.suiteConfiguration().owners[4];
        _raStatus(target, P.Status.STALE, selected);
        require(
            PersonhoodRead(target).personhoodProofSummaryHash(selected) == raRows[0].summaryHash,
            "validated historical summary survives a changed current head"
        );
        _rhAdopt(next);
        _raDocumentary();
        bytes32 fresh = _raPersonhood(_raNotarize(0));
        _raStatus(suite.owners[4], P.Status.RESOLVED, fresh);
        require(
            PersonhoodRead(suite.owners[4]).personhoodProofSummary(selected).evidenceReference
                .notarizationRecordHash == old,
            "new explicit selection leaves old original summary intact"
        );
    }

    function testRecoveredAttestationDelegatedOriginalsAndRevokedLaneSurviveRepeatedImport()
        external
    {
        _raBaseline();
        bytes32 grant = _raGrant();
        raDelegateSignedAt = uint64(block.timestamp - 1);
        bytes32 delegated = _raPrimary(grant, 257);
        bytes32 otherGrant = _raOtherGrant();
        bytes32 sameDigest = _raPrimary(otherGrant, 257);
        require(
            delegated != sameDigest && raRows[0].digest == raRows[1].digest
                && raRows[0].authorizationPoint.ownerRevision
                    < raRows[1].authorizationPoint.ownerRevision,
            "two genuine delegates share a digest but have separate nonce admissions"
        );
        raDelegateSignedAt = 0;
        D.Record memory granted = ingress.delegationRecord(grant);
        require(
            granted.uses == 1 && ingress.attestationAuthorityClass(delegated) == 2,
            "actual delegate nonce lane and original class2"
        );
        _raRevoke(grant);
        D.Record memory originalGrant = ingress.delegationRecord(grant);
        Successor memory next = _rhCutover();
        _raTransfer(next);
        _rhAdopt(next);
        require(
            keccak256(abi.encode(ingress.delegationRecord(grant)))
                == keccak256(abi.encode(originalGrant)),
            "grant, use count and original revocation preserved"
        );
        (T.Attestation memory p, bytes memory statement) = _raPrimaryTerms();
        T.Authorization memory a = T.Authorization(258, uint64(block.timestamp), "");
        a.signature = _delegateSignature(ingress.attestationDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        bytes32 freshGrant = _raGrant();
        bytes32 fresh = _raPrimary(freshGrant, 258);
        require(
            ingress.recordDelegation(fresh) == freshGrant,
            "fresh B authorizes through a new genuine grant"
        );
        Successor memory last = _rhCutover();
        _raTransfer(last);
        _raAssert(last.coordinator.suiteConfiguration(), raRows.length);
        _rhAdopt(last);
        a = T.Authorization(258, uint64(block.timestamp), "");
        a.signature = _delegateSignature(ingress.attestationDigest(p, a));
        bytes32 lane = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                artistId,
                address(delegateSafe)
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _raKey(
                    suite,
                    "identity_authority.replay.delegated_nonce",
                    keccak256(abi.encode(lane, uint256(258)))
                )
            )
        );
        ingress.recordDelegatedArtistAttestation(p, freshGrant, a, statement);
        _raPrimary(freshGrant, 259);
    }

    function testRecoveredAttestationCompletePrepareGatesBadWitnessAndExactArchiveRetry() external {
        _raBaseline();
        _raPrimary(0, 0);
        bytes32 selected = _raPersonhood(_raNotarize(0));
        _raCredential(0, false);
        T.SuiteConfiguration memory original = suite;
        Successor memory next = _rhCutover();
        RH.Request memory request = _raRequest();
        Commit.Prepared memory prepared = _raPrepared(next, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _raSource(original, raRows.length);
        request.expectedCapabilities[4].supportedFeatures &= ~ATTESTATION_FEATURE;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request.expectedCapabilities[4].supportedFeatures |= ATTESTATION_FEATURE;
        Ready.AttestationInput[] memory full = request.records.witnesses[0].attestations;
        request.records.witnesses[0].attestations = new Ready.AttestationInput[](0);
        avm.expectRevert(T.UnsupportedProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request.records.witnesses[0].attestations = full;
        (
            request.records.witnesses[0].attestations[0],
            request.records.witnesses[0].attestations[1]
        ) = (full[1], full[0]);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request = _raRequest();
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        ++request.records.authority.expectedSource[4].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        --request.records.authority.expectedSource[4].ownerState.revision;
        require(
            _rhDestinationHash(next) == before_,
            "valid-preparation-gated negatives preserve complete destination"
        );
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        uint256 blockBefore = block.number;
        uint256 nonceBefore = rotationSafe.nonce();
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            rotationSafe.nonce() == nonceBefore && _rhDestinationHash(next) == before_,
            "late Archive restores all owner roots, catalogs and Safe nonce"
        );
        address target = next.coordinator.suiteConfiguration().owners[4];
        require(
            PersonhoodRead(target).personhoodProofSummaryHash(selected) == 0
                && Credentials(target).c2paCredentialHead(artistId).recordHash == 0,
            "derived documentary and credential maps rolled back"
        );
        require(
            Attribution(target).attestationRecord(selected).recordHash == 0,
            "original keyed record rolled back"
        );
        require(
            _raSource(original, raRows.length) == sourceBefore, "failed imports preserve source"
        );
        vm.roll(blockBefore);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_),
            "identical original Safe request retries"
        );
        require(rotationSafe.nonce() == nonceBefore + 1, "one accepted Safe execution");
        _rhImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function _raBaseline() internal {
        _rhBaseline();
        _adoptRotatedSafe();
        uint64 end = ingress.artistTransitionState(rhRecovery).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
        _raDocumentary();
    }

    function _raPrimaryTerms()
        internal
        view
        returns (T.Attestation memory p, bytes memory statement)
    {
        bytes32 assignment =
            primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash;
        statement = abi.encode("original verified assignment", assignment);
        p = T.Attestation(
            1,
            6,
            bytes32(uint256(uint160(address(primary)))),
            assignment,
            keccak256("recovered subject fixture"),
            keccak256(statement),
            "urn:recovered:primary"
        );
    }

    function _raPrimary(bytes32 grant, uint256 nonce) internal returns (bytes32) {
        (T.Attestation memory p, bytes memory statement) = _raPrimaryTerms();
        return _raRecord(p, statement, grant, nonce);
    }

    function _raDeployment() internal returns (bytes32) {
        bytes memory statement = bytes("original deployment facts");
        bytes32 facts = Hashes.deploymentFacts(
            Hashes.Environment(block.chainid, address(ingress), address(core), suite.mintManager),
            1,
            ingress.displayBinding(1)
        );
        T.Attestation memory p = T.Attestation(
            1,
            9,
            bytes32(uint256(uint160(address(core)))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1"),
            keccak256(statement),
            "urn:recovered:deployment"
        );
        return _raRecord(p, statement, 0, 0);
    }

    function _raCredential(bytes32 previous, bool empty) internal returns (bytes32) {
        C2PA.Credential[] memory items = new C2PA.Credential[](empty ? 0 : 1);
        if (!empty) {
            items[0] = C2PA.Credential(1, keccak256("test SPKI"), keccak256("identity key"), 1, 0);
        }
        bytes memory statement = abi.encode(
            C2PA.Payload(1, artistId, ingress.operativeIdentityRecord(artistId), previous, items)
        );
        return _raRecord(_raIdentityTerms(statement, CREDENTIAL_SCHEMA), statement, 0, 0);
    }

    function _raPersonhood(bytes32 record) internal returns (bytes32) {
        P.Reference memory ref = P.Reference(
            1,
            PersonhoodDefinitions.PROFILE_HASH,
            address(ingress),
            artistId,
            ingress.operativeIdentityRecord(artistId),
            address(raNotary),
            address(raNotary).codehash,
            record
        );
        bytes memory statement = PersonhoodJSON.encode(ref);
        return _raRecord(
            _raIdentityTerms(statement, PersonhoodDefinitions.EVIDENCE_SCHEMA), statement, 0, 0
        );
    }

    function _raIdentityTerms(bytes memory statement, bytes32 schema)
        internal
        view
        returns (T.Attestation memory)
    {
        return T.Attestation(
            1,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            schema,
            keccak256(statement),
            "urn:recovered:identity-evidence"
        );
    }

    function _raRecord(T.Attestation memory p, bytes memory statement, bytes32 grant, uint256 nonce)
        internal
        returns (bytes32 record)
    {
        T.Authorization memory a = grant == 0
            ? _authorization(true)
            : T.Authorization(
                nonce, raDelegateSignedAt == 0 ? uint64(block.timestamp) : raDelegateSignedAt, ""
            );
        bytes32 digest = ingress.attestationDigest(p, a);
        address signer =
            grant == 0 ? address(artist) : ingress.delegationRecord(grant).grant.delegate;
        if (grant == 0) {
            a.signature = _signature(digest);
        } else if (signer == address(delegateSafe)) {
            a.signature = _delegateSignature(digest);
        } else {
            require(signer == vm.addr(SECOND_DELEGATE_KEY), "explicit second fixture signer");
            (uint8 v, bytes32 r, bytes32 s_) = vm.sign(SECOND_DELEGATE_KEY, digest);
            a.signature = abi.encodePacked(r, s_, v);
        }
        uint8 class_ = grant == 0 ? uint8(1) : uint8(2);
        record = grant == 0
            ? ingress.recordArtistAttestation(p, a, statement)
            : ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        p.collectionId,
                        p.subjectKind,
                        p.subjectId,
                        p.subjectStateHash,
                        p.schemaId,
                        p.statementHash,
                        keccak256(bytes(p.statementURI)),
                        artistId,
                        signer,
                        class_,
                        a.nonce,
                        a.time
                    )
                ),
            "independent unchanged original24 preimage"
        );
        if (grant == 0) {
            _rhAuthorization(digest, a.nonce);
            _rhCandidate(
                2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record))
            );
        } else {
            bytes32 lane = keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), artistId, signer)
            );
            _rhCandidate(
                2, "identity_authority.replay.delegated_nonce", keccak256(abi.encode(lane, a.nonce))
            );
            _rhCandidate(
                2,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, digest))
            );
        }
        Original memory item;
        item.input = Ready.AttestationInput(p, a.nonce);
        item.record = Attribution(suite.owners[4]).attestationRecord(record);
        item.authorityClass = class_;
        item.association = ingress.attestationAssociation(record);
        item.statement = statement;
        item.signature = a.signature;
        item.digest = digest;
        item.registry = address(ingress);
        item.position = _raPosition(4, 24, record);
        item.authorizationPoint = RH.Point(
            RH.originHash(_raOrigin(suite)),
            2,
            Owner(suite.owners[2]).ownerStateSnapshotV2().revision
        );
        item.credential = Credentials(suite.owners[4]).c2paCredentialRecord(record);
        item.summary = PersonhoodRead(suite.owners[4]).personhoodProofSummary(record);
        item.summaryHash = PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(record);
        require(
            item.association.artistId == artistId
                && item.association.bindingHash == ingress.displayBinding(1).bindingHash
                && item.association.delegation == grant,
            "original binding and delegate association"
        );
        require(
            _operationPayload(24, address(this), record).length != 0,
            "original Archive24 evidence retained"
        );
        if (item.summaryHash != 0) {
            require(
                item.summaryHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), item.summary
                        )
                    ),
                "literal original summary commitment"
            );
        }
        raRows.push(item);
    }

    function _raRevise(bytes memory document) internal {
        Doc.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.identityRevisionDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordIdentityRevision(p, a, document, "Successor document");
        Doc.Record memory r = ingress.identityRevisionRecord(record);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            2,
            "identity_authority.replay.identity_revision_chain",
            keccak256(abi.encode(artistId, r.previousRevisionRecord, r.previousRecordHash))
        );
        require(
            r.revisedRecordHash == keccak256(document)
                && ingress.operativeIdentityRecord(artistId) == r.revisedRecordHash,
            "actual signed original25 became operative"
        );
    }

    function _raGrant() internal returns (bytes32 record) {
        D.Grant memory p =
            _delegation(1, 1, uint64(block.timestamp), uint64(block.timestamp + 365 days), 10);
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(p, a);
        record = _grant(p);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
    }

    function _raOtherGrant() private returns (bytes32 record) {
        D.Grant memory p =
            _delegation(1, 1, uint64(block.timestamp), uint64(block.timestamp + 365 days), 10);
        p.delegate = vm.addr(SECOND_DELEGATE_KEY);
        T.Authorization memory a = _authorization(false);
        a.time = 0;
        bytes32 digest = ingress.delegationGrantDigest(p, a);
        a.signature = _signature(digest);
        record = ingress.grantArtistDelegation(p, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
    }

    function _raRevoke(bytes32 grant) internal {
        D.Revocation memory p =
            D.Revocation(artistId, address(delegateSafe), grant, keccak256("artist revocation"));
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.delegationRevocationDigest(p, a);
        _revoke(grant);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(2, "identity_authority.replay.one_way_delegation_revocation", grant);
    }

    function _raRequest() internal view returns (RH.Request memory p) {
        p = _rhRequest();
        p.records.witnesses = new MR.CollectionWitness[](1);
        p.records.witnesses[0].collectionId = 1;
        p.records.witnesses[0].economics = new T.EconomicsConsent[](0);
        p.records.witnesses[0].attestations = new Ready.AttestationInput[](raRows.length);
        for (uint256 i; i < raRows.length; ++i) {
            p.records.witnesses[0].attestations[i] = raRows[i].input;
        }
    }

    function _raPrepared(Successor memory next, RH.Request memory p)
        internal
        view
        returns (Commit.Prepared memory prepared)
    {
        for (uint8 i; i < 7; ++i) {
            require(
                p.expectedCapabilities[i].supportedFeatures == 255,
                "actual explicit source capability mask255"
            );
            require(
                RecoveredOwner(next.coordinator.suiteConfiguration().owners[i])
                .recoveredAuthorityHydrationCapability()
                .supportedFeatures == 255,
                "actual explicit successor mask255"
            );
        }
        prepared = Prepared.prepare(next.coordinator.suiteConfiguration(), p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(prepared.data[i].typedState, i);
            require(
                (h.requiredFeatures & ATTESTATION_FEATURE) != 0,
                "complete source journal explicitly requires op24 capability"
            );
        }
        require(
            prepared.data[4].typedState.length != 0 && Prepared.inventory(prepared) != 0,
            "complete authentic prepared owner payload"
        );
    }

    function _raTransfer(Successor memory next) internal returns (Commit.Prepared memory prepared) {
        RH.Request memory p = _raRequest();
        prepared = _raPrepared(next, p);
        p.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(p);
        _rhImported(next, prepared, value);
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function _raAssert(T.SuiteConfiguration memory target, uint256 count) internal view {
        StreamArtistOnboardingRegistry registry = StreamArtistOnboardingRegistry(target.registry);
        (RH.OwnerProvenance memory prefix,,) =
            RecoveredOwner(target.owners[4]).recoveredHydrationImportedPrefix();
        uint256 matched;
        for (uint256 i; i < prefix.journal.length; ++i) {
            if (prefix.journal[i].receipt.operation != 24) continue;
            Original memory item = raRows[matched++];
            require(
                prefix.journal[i].receipt.recordHash == item.record.recordHash
                    && keccak256(abi.encode(prefix.journal[i].position))
                        == keccak256(abi.encode(item.position)),
                "every exact original24 occurrence and ultimate coordinates"
            );
        }
        require(matched == count, "complete flattened original24 prefix");
        for (uint256 i; i < count; ++i) {
            Original memory item = raRows[i];
            bytes32 hash = item.record.recordHash;
            require(
                keccak256(abi.encode(Attribution(target.owners[4]).attestationRecord(hash)))
                    == keccak256(abi.encode(item.record)),
                "original record bytes unchanged"
            );
            require(
                registry.attestationAuthorityClass(hash) == item.authorityClass
                    && keccak256(abi.encode(registry.attestationAssociation(hash)))
                        == keccak256(abi.encode(item.association)),
                "original class and full verified subject association"
            );
            require(
                keccak256(Attribution(target.owners[4]).statementBytes(item.record.statementHash))
                    == keccak256(item.statement),
                "exact original statement bytes"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(hash))
                    == keccak256(item.signature),
                "original signer bundle not reauthorized"
            );
            bytes32 nonceScope;
            string memory nonceSurface;
            if (item.association.delegation == 0) {
                nonceScope = keccak256(abi.encode(artistId, item.input.nonce));
                nonceSurface = "identity_authority.replay.nonce_allocator";
                T.ReplayCell memory receiptGuard = Owner(target.owners[2])
                    .replayCell(
                        _raKey(
                            target,
                            "identity_authority.replay.attestation_key",
                            keccak256(abi.encode(hash))
                        )
                    );
                require(
                    receiptGuard.commitment == hash && receiptGuard.status != 0,
                    "original direct24 one-way record guard"
                );
            } else {
                bytes32 lane = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                        artistId,
                        item.record.signer
                    )
                );
                nonceScope = keccak256(abi.encode(lane, item.input.nonce));
                nonceSurface = "identity_authority.replay.delegated_nonce";
                require(
                    Owner(target.owners[2])
                    .replayCell(
                        _raKey(
                            target,
                            "identity_authority.replay.attestation_key",
                            keccak256(abi.encode(hash))
                        )
                    )
                    .status == 0,
                    "delegated24 never invents the direct record guard"
                );
            }
            bytes32 nonceKey = _raKey(target, nonceSurface, nonceScope);
            T.ReplayCell memory nonceCell = Owner(target.owners[2]).replayCell(nonceKey);
            require(
                nonceCell.commitment == item.digest && nonceCell.kind == 1 && nonceCell.status == 2
                    && nonceCell.touchedRevision == item.authorizationPoint.ownerRevision,
                "exact original Identity nonce admission, independent of signedAt"
            );
            require(
                keccak256(
                    abi.encode(
                        RecoveredOwner(target.owners[2]).recoveredHydrationReplayPoint(nonceKey)
                    )
                ) == keccak256(abi.encode(item.authorizationPoint)),
                "Identity clock stays distinct from original Attribution native clock"
            );
            RH.Point memory observedAt = item.authorizationPoint;
            for (uint256 j; j < i; ++j) {
                if (raRows[j].digest == item.digest) {
                    observedAt = raRows[j].authorizationPoint;
                    break;
                }
            }
            bytes32 observation = _raKey(
                target,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, item.digest))
            );
            require(
                Owner(target.owners[2]).replayCell(observation).commitment == item.digest
                    && keccak256(
                        abi.encode(
                            RecoveredOwner(target.owners[2])
                                .recoveredHydrationReplayPoint(observation)
                        )
                    ) == keccak256(abi.encode(observedAt)),
                "shared digest observation retains its FIRST genuine admission point"
            );
            require(
                keccak256(abi.encode(Credentials(target.owners[4]).c2paCredentialRecord(hash)))
                    == keccak256(abi.encode(item.credential)),
                "full credential history including explicit withdrawals"
            );
            require(
                PersonhoodRead(target.owners[4]).personhoodProofSummaryHash(hash)
                        == item.summaryHash
                    && keccak256(
                        abi.encode(PersonhoodRead(target.owners[4]).personhoodProofSummary(hash))
                    ) == keccak256(abi.encode(item.summary)),
                "exact sparse original summary tuple"
            );
            bool last = true;
            for (uint256 j = i + 1; j < count; ++j) {
                if (
                    raRows[j].input.terms.subjectKind == item.input.terms.subjectKind
                        && raRows[j].input.terms.subjectId == item.input.terms.subjectId
                ) last = false;
            }
            if (last) {
                require(
                    Attribution(target.owners[4])
                    .attestation(1, item.input.terms.subjectKind, item.input.terms.subjectId)
                    .recordHash == hash,
                    "latest subject map follows original occurrence order"
                );
            }
        }
        bytes32 credential;
        bytes32 personhood;
        for (uint256 i; i < count; ++i) {
            if (raRows[i].credential.recordHash != 0) {
                credential = raRows[i].record.recordHash;
            } else if (raRows[i].input.terms.subjectKind == 10) {
                personhood = raRows[i].record.recordHash;
            }
        }
        require(
            Credentials(target.owners[4]).c2paCredentialHead(artistId).recordHash == credential
                && Credentials(target.owners[4]).personhoodAttestation(1, artistId).recordHash
                    == personhood,
            "separate personhood and credential heads never overwrite each other"
        );
    }

    function _raSource(T.SuiteConfiguration memory target, uint256 count)
        internal
        view
        returns (bytes32 hash)
    {
        for (uint8 i; i < 7; ++i) {
            hash = keccak256(
                abi.encode(
                    hash,
                    CP(target.owners[i]).authorityCheckpoint(),
                    Publications.collect(target.owners[i], i),
                    Native(target.owners[i]).artistNativeReceiptCount()
                )
            );
        }
        for (uint256 i; i < count; ++i) {
            bytes32 record = raRows[i].record.recordHash;
            hash = keccak256(
                abi.encode(
                    hash,
                    Attribution(target.owners[4]).attestationRecord(record),
                    StreamArtistOnboardingRegistry(target.registry).attestationAssociation(record),
                    PersonhoodRead(target.owners[4]).personhoodProofSummary(record),
                    PersonhoodRead(target.owners[4]).personhoodProofSummaryHash(record),
                    Credentials(target.owners[4]).c2paCredentialRecord(record),
                    Identity(target.owners[2]).signatureBundle(record)
                )
            );
        }
        return keccak256(
            abi.encode(
                hash,
                Credentials(target.owners[4]).c2paCredentialHead(artistId),
                Credentials(target.owners[4]).personhoodAttestation(1, artistId)
            )
        );
    }

    function _raStatus(address owner, P.Status status, bytes32 record) internal view {
        P.Selection memory selected = PersonhoodRead(owner).personhoodEvidence(1, artistId);
        require(
            selected.nativeRecord.recordHash == record && selected.status == status,
            "actual current personhood truth and unchanged native selection"
        );
    }

    function _raPosition(uint8 index, uint16 operation, bytes32 record)
        internal
        view
        returns (RH.Position memory)
    {
        uint256 nativeIndex = Native(suite.owners[index]).artistNativeReceiptCount() - 1;
        H.Receipt memory row = Native(suite.owners[index]).artistNativeReceiptAt(nativeIndex);
        require(
            row.operation == operation && row.recordHash == record && row.artistId == artistId,
            "actual native producer receipt"
        );
        return RH.Position(
            RH.Point(
                RH.originHash(_raOrigin(suite)),
                index,
                NativeClock(suite.owners[index]).artistNativeReceiptRevisionAt(nativeIndex)
            ),
            nativeIndex
        );
    }

    function _raKey(T.SuiteConfiguration memory target, string memory surface, bytes32 scope)
        internal
        view
        returns (bytes32)
    {
        return Guards.replayKey(_raOrigin(target), 2, AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _raOrigin(T.SuiteConfiguration memory target)
        internal
        view
        returns (RH.OriginEnvironment memory e)
    {
        e.chainId = block.chainid;
        e.registry = target.registry;
        e.coordinator = Owner(target.owners[2]).operationCoordinator();
        e.archive = target.archive;
        e.owners = target.owners;
        for (uint8 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = target.owners[i].codehash;
        }
        e.core = target.core;
        e.manager = target.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(target));
    }

    function _raDocumentary() internal {
        raDocuments = new PersonhoodDocumentFixture();
        raDocuments.deploy();
        raDocuments.register(
            "STREAM_IDENTITY_NOTARIZATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json"))
        );
        raDocuments.register(
            "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1.json"))
        );
        raDocuments.register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        _raRegisterReferenceProfile();
        StreamGeneralAttestations.Configuration memory c;
        c.core = address(core);
        c.schemas = address(raDocuments.schemas());
        c.metadata = address(metadata);
        c.artistRegistry = address(ingress);
        c.artistAttribution = suite.owners[4];
        c.executor = address(raDocuments);
        c.deploymentManifestHash = keccak256("personhood fixture deployment");
        c.manifestURI = "urn:personhood:fixture";
        c.manifestHash = keccak256("personhood fixture manifest");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 50000, 2
        );
        raNotary = StreamGeneralAttestations(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamGeneralAttestations.sol:StreamGeneralAttestations",
                abi.encode(c)
            )
        );
        _raRegisterNotary();
    }

    function _raRegisterReferenceProfile() private {
        bytes memory raw = bytes(
            vm.readFile("schemas/records/STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1.json")
        );
        require(
            raw.length == PersonhoodDefinitions.PROFILE_BYTES
                && keccak256(raw) == PersonhoodDefinitions.PROFILE_HASH,
            "exact pinned profile bytes"
        );
        raDocuments.register(
            "STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            raw
        );
    }

    function _raRegisterNotary() private {
        // Exact original ModuleRegistry class-1 registration, with the General module's actual version.
        StreamModuleRegistration memory r = StreamModuleRegistration(
            address(raNotary),
            keccak256("GENERAL_ATTESTATIONS"),
            keccak256("6529stream.general-attestations.v2"),
            type(General).interfaceId,
            0,
            address(raNotary).codehash,
            keccak256("personhood fixture deployment"),
            keccak256("personhood fixture manifest"),
            "urn:personhood:fixture"
        );
        (bytes32 chain, uint64 count) = saleModules.registrationChainHash();
        bytes32 record = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                r.module,
                r.moduleType,
                r.interfaceId,
                r.moduleVersion,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                saleModules.STREAM_RECORD_CHAIN_V1(),
                block.chainid,
                address(saleModules),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                chain,
                record,
                count
            )
        );
        bytes32 scope = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_SCOPE_V1(),
                block.chainid,
                address(saleModules),
                address(raNotary)
            )
        );
        StreamModuleRegistration memory empty;
        bytes32 oldState = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                false,
                _raRegistrationFacts(empty, 0, 0),
                uint256(count),
                chain,
                count,
                address(0)
            )
        );
        bytes32 nextState = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                true,
                _raRegistrationFacts(r, 1, 1),
                uint256(count) + 1,
                next,
                count + 1,
                address(raNotary)
            )
        );
        address authority = factory.governanceAuthority();
        bytes memory active = abi.encode(
            true, keccak256("unit authority gas raise"), uint8(1), scope, oldState, nextState
        );
        avm.mockCall(authority, abi.encodeWithSignature("currentAction()"), active);
        (bool ok, bytes memory observed) =
            authority.staticcall(abi.encodeWithSignature("currentAction()"));
        require(
            ok && keccak256(observed) == keccak256(active),
            "exact original ModuleRegistry governance context"
        );
        ArtistUnitGovernance(authority)
            .executeModuleContext(
                address(saleModules),
                abi.encodeCall(saleModules.registerModule, (r)),
                1,
                scope,
                oldState,
                nextState
            );
        _inactive();
        (ok, observed) = authority.staticcall(abi.encodeWithSignature("currentAction()"));
        require(
            ok
                && keccak256(observed)
                    == keccak256(
                        abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
                    ),
            "fully inactive after actual module registration"
        );
    }

    function _raRegistrationFacts(StreamModuleRegistration memory r, uint8 status, uint64 revision)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                status,
                r.moduleType,
                r.moduleVersion,
                r.interfaceId,
                r.moduleGasLimit,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash,
                keccak256(bytes(r.moduleManifestURI)),
                revision
            )
        );
    }

    function _raNotarize(bytes32 supersedes) private returns (bytes32 hash) {
        Subjects.SubjectKind kind = Subjects.SubjectKind.COLLECTION;
        bool safeIssuer = false;
        Subjects.Subject memory subject = Subjects.Subject(kind, 1, 0, 0);
        General.Notarization memory n;
        n.artistId = artistId;
        n.operativeIdentityRecordHash = ingress.operativeIdentityRecord(artistId);
        Notice.Reference memory ref = Notice.Reference(
            2,
            keccak256("RAW_BYTES"),
            abi.encode(keccak256("synthetic instrument bytes")),
            "ipfs://personhood-fixture"
        );
        n.legalPersonRef = ref;
        n.instrumentRef = ref;
        n.officiatingAuthorityIdentityRef = ref;
        n.verifyingInstitutionIdentityRef = ref;
        General.Request memory r;
        r.attester = safeIssuer ? address(artist) : vm.addr(NOTARY_KEY);
        r.collectionId = 1;
        r.subjectId = raNotary.deriveSubject(subject);
        r.attestationType = keccak256("INSTITUTIONAL_VERIFICATION");
        r.attesterDID = "did:example:fixture-only";
        r.schemaId = GeneralDefinitions.SCHEMA_ID;
        r.canonicalizationId = keccak256("RFC8785_JCS");
        r.statementURI = "urn:personhood:instrument";
        r.payload = raNotary.notarizationPayload(n);
        r.supersedes = supersedes;
        r.effectiveAt = uint64(block.timestamp);
        r.nonce = ++raNotaryNonce;
        r.deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = raNotary.attestationDigest(r);
        bytes memory signature;
        if (safeIssuer) {
            signature = _signature(digest);
        } else {
            (uint8 v, bytes32 r_, bytes32 s_) = vm.sign(NOTARY_KEY, digest);
            signature = abi.encodePacked(r_, s_, v);
        }
        hash = raNotary.recordIdentityNotarization(subject, r, n, signature);
        (General.Attestation memory a, General.Receipt memory receipt) = raNotary.attestation(hash);
        require(
            receipt.recorder == r.attester && receipt.authorizationDigest == digest
                && receipt.verificationClass == General.VerificationClass.SIGNER_VERIFIED
                && receipt.authorityQualification
                    == General.AuthorityQualification.GENERAL_SIGNER_CLAIM,
            "actual original signer-qualified receipt, not legal truth"
        );
        General.Receipt memory original = abi.decode(abi.encode(receipt), (General.Receipt));
        original.recordIndex = 0;
        original.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_GENERAL_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(raNotary),
                        a,
                        original
                    )
                ),
            "independent original record preimage"
        );
    }

    struct C2PAJoin {
        MetadataExecutorBoundary governance;
        StreamSchemaRegistry schemas;
        StreamSchemaDocumentStore store;
        StreamCollectionMetadataV1 host;
        StreamC2PAReconciliation companion;
        CR.Report report;
    }

    function testRecoveredAttestationImportedCredentialsDriveRealReconciliationCurrentness()
        external
    {
        _raBaseline();
        bytes32 credential = _raCredential(0, false);
        Successor memory next = _rhCutover();
        _raTransfer(next);
        _rhAdopt(next);
        C2PAJoin memory j = _raJoin(credential);
        bytes32 report = _raPublishReport(j, 6);
        bytes32 selection = j.companion.adopt(1, j.report.subjectId, report, 0, 0);
        CR.Display memory current = j.companion.display(1, j.report.subjectId);
        require(
            current.current && current.recordHash == report
                && current.authorship == CR.AuthorshipStatus.CONSISTENT,
            "actual reconciliation consumes imported original credential head"
        );
        bytes32 withdrawn = _raCredential(credential, true);
        CR.Display memory stale = j.companion.display(1, j.report.subjectId);
        require(
            !stale.current && stale.authorship == CR.AuthorshipStatus.UNEVALUATED,
            "fresh original24 withdrawal makes old report unevaluated"
        );
        require(
            j.companion.currentSelection(1, j.report.subjectId).recordHash == report,
            "display staleness never erases historical selection"
        );
        j.report.credentialRecordHash = withdrawn;
        j.report.credentialEnumerationHash =
        Credentials(suite.owners[4]).c2paCredentialHead(artistId).statementHash;
        j.report.authorship = CR.AuthorshipStatus.UNEVALUATED;
        bytes32 nextReport = _raPublishReport(j, 6);
        j.companion.adopt(1, j.report.subjectId, nextReport, selection, 1);
        require(
            j.companion.selectionAt(1, j.report.subjectId, 1).recordHash == report
                && j.companion.display(1, j.report.subjectId).current,
            "explicit new observation retains original report history"
        );
    }

    function _raJoin(bytes32 credentials) private returns (C2PAJoin memory j) {
        j.governance = new MetadataExecutorBoundary();
        j.schemas = new StreamSchemaRegistry(address(j.governance));
        j.store = StreamSchemaDocumentStore(j.schemas.chunkStore());
        _raDefinition(
            j,
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(j.schemas.RAW_BYTES_DEFINITION())
        );
        _raDefinition(
            j,
            "6529STREAM_C2PA_RECONCILIATION_REPORT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/6529STREAM_C2PA_RECONCILIATION_REPORT_V1.json"))
        );
        StreamCollectionMetadataV1.Configuration memory config;
        config.core = address(core);
        config.executor = address(j.governance);
        config.schemas = address(j.schemas);
        config.artistRegistry = address(ingress);
        config.deploymentManifestHash = keccak256("C2PA metadata test deployment");
        config.manifestHash = keccak256("C2PA metadata test module");
        config.manifestURI = "ipfs://c2pa-test";
        config.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        config.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        j.host = new StreamCollectionMetadataV1(config);
        core.set(keccak256("COLLECTION_METADATA"), address(j.host), false);
        core.set(keccak256("METADATA_ROUTER"), address(metadata), false);
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            j.host.recordTypeTransition(keccak256("C2PA_VALIDATION"), family, 0x150);
        j.governance
            .execute(
                address(j.host),
                abi.encodeCall(
                    j.host.admitRecordType, (keccak256("C2PA_VALIDATION"), family, uint16(0x150))
                ),
                scope,
                oldHash,
                nextHash
            );
        _raVerifier(j, address(artist), 6);
        C2PAServing.ServingSource memory source;
        source.imageURI = "ipfs://actual-committed-media";
        avm.mockCall(
            address(metadata),
            abi.encodeWithSignature("renderingProfile()"),
            abi.encode(
                keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
                keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
                keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
            )
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(C2PAServing.collectionServingSource, (uint256(1))),
            abi.encode(source)
        );
        CM.MediaManifest memory media;
        media.imageSourceType = CM.PayloadSourceType.IPFS;
        media.imageURI = source.imageURI;
        media.imageHash = keccak256("actual local media");
        media.imageMimeType = "image/png";
        vm.prank(address(metadata));
        bytes32 mediaManifest =
            IStreamCollectionManifestWriter(address(j.host)).storeMediaManifest(1, media);
        CM.Selection memory selected =
            CM.Selection(address(j.host), address(j.host).codehash, mediaManifest);
        avm.mockCall(
            address(metadata),
            abi.encodeCall(
                IStreamMetadataManifestSelection.selectedCollectionManifest, (uint256(1), uint8(3))
            ),
            abi.encode(selected)
        );
        SR.RawSource memory raw;
        raw.chainId = block.chainid;
        raw.configured = true;
        raw.imageURI = source.imageURI;
        raw.mediaManifest = selected;
        avm.mockCall(
            address(metadata), abi.encodeCall(SR.staticRenderSource, (uint256(1))), abi.encode(raw)
        );
        j.companion = new StreamC2PAReconciliation(
            address(core),
            address(j.host),
            address(ingress),
            address(metadata),
            address(artist),
            address(j.governance),
            IStreamGasParameterHost.GasParameterConfig(
                "C2PA_DEPENDENCY_READ_GAS", 1000000, 100000, 2
            )
        );
        CR.Report memory p;
        p.version = 1;
        p.profile = j.companion.PROFILE();
        p.collectionId = 1;
        p.subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        p.artistId = artistId;
        p.bindingHash = ingress.displayBinding(1).bindingHash;
        p.generation = 1;
        p.identityRecordHash = ingress.operativeIdentityRecord(artistId);
        p.identityDocumentHash = p.identityRecordHash;
        p.credentialRecordHash = credentials;
        p.publicKeyHistoryHash = keccak256("synthetic verifier key history observation");
        p.credentialEnumerationHash =
        Credentials(suite.owners[4]).c2paCredentialHead(artistId).statementHash;
        p.selectedMediaManifestHash = mediaManifest;
        p.mediaSlot = 1;
        p.mediaHash = media.imageHash;
        p.claimAssetHash = media.imageHash;
        p.manifestHash = keccak256("manifest");
        p.claimHash = keccak256("claim");
        p.claimSignatureHash = keccak256("signature");
        p.signerKind = 1;
        p.signerFingerprint = keccak256("test SPKI");
        p.signerKeyFingerprint = p.signerFingerprint;
        p.keyId = keccak256("identity key");
        p.signedAt = uint64(block.timestamp);
        p.validation = CR.ValidationStatus.VALID;
        p.authorship = CR.AuthorshipStatus.CONSISTENT;
        p.assertsAuthorship = true;
        p.validatorIdentityHash = keccak256("explicit fixture verifier");
        p.softwareVersionHash = keccak256("test-only-observation-1");
        (p.validationReportHash,) =
            j.store.publishChunk(bytes("synthetic selected verifier observation; no crypto claim"));
        (p.trustAnchorsHash,) = j.store.publishChunk(bytes("explicit test trust anchors"));
        p.reportURI = "ipfs://synthetic-c2pa-report";
        j.report = p;
    }

    function _raDefinition(
        C2PAJoin memory j,
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = j.store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, j.schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = j.schemas.registrationTransition(spec, chunks);
        j.governance
            .execute(
                address(j.schemas),
                abi.encodeCall(j.schemas.registerDocument, (spec, chunks)),
                s,
                o,
                n
            );
    }

    function _raVerifier(C2PAJoin memory j, address account, uint8 authClass) private {
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
        (bytes32 s, bytes32 o, bytes32 n) =
            j.host.familyWriterTransition(1, family, authClass, account, true);
        j.governance
            .execute(
                address(j.host),
                abi.encodeCall(
                    j.host.setFamilyWriter, (uint256(1), family, authClass, account, true)
                ),
                s,
                o,
                n
            );
    }

    function _raPublishReport(C2PAJoin memory j, uint8 expectedClass)
        private
        returns (bytes32 hash)
    {
        bytes memory payload = abi.encode(j.report);
        IStreamPreservationRecords.CollectionRecord memory r;
        r.recordType = keccak256("C2PA_VALIDATION");
        r.subjectId = j.report.subjectId;
        r.schemaId = j.companion.SCHEMA();
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), j.schemas.RAW_BYTES()
        );
        r.uri = j.report.reportURI;
        r.effectiveAt = uint64(block.timestamp);
        hash = j.host.deriveCollectionRecordHashFor(address(artist), 1, r);
        require(
            this.executeTargetSafe(
                address(j.host),
                abi.encodeCall(j.host.recordCollectionRecordWithPayload, (uint256(1), r, payload))
            )
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) = j.host.collectionRecord(hash);
        require(
            receipt.recorder == address(artist) && receipt.authorizationClass == expectedClass
                && receipt.artistAuthorization == 0,
            "explicit receipt class, not op24 authority"
        );
    }
}
