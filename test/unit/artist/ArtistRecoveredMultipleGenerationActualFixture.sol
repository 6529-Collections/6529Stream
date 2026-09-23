// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistExtendedHydrationFeatures as XF
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistExtendedHydrationFeatures.sol";
import "./ArtistRecoveredMultipleGenerationFixture.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecoveredAttestationHydration as AttestationBundle
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationConservation as Conservation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationConservation.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationValidation as Validation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationAttestationValidation.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads as Credentials
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistPersonhoodEvidence as Personhood
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    IStreamArtistAuthenticatedAttestationOwner as Associations
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistReadinessAttributionOwner as Classes
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistRecordPublicationOwner as AttestationPublications
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationQueries as Queries
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationAttestationQueries.sol";

import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistBindingCorrectionAdmission as CorrectionAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistBindingCorrectionState as CorrectionState
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionState.sol";
import {
    StreamSchemaDocumentStore as StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamCollectionMetadataV1 as IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCollectionArchivalCoverage as IStreamCollectionArchivalCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";
import {
    StreamArchivalTypes as Archival
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD,
    IStreamArtistAttributionDisputes as Disputes,
    IStreamArtistAttributionDisputesOwner as DisputeOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection as Correction,
    IStreamArtistBindingCorrectionOwner as CorrectionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    IStreamArtistDelegationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationOwner.sol";
import {
    StreamArtistRecoveredMultipleGenerationCurrent as Current
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationCurrent.sol";
import {
    IStreamArtistDelegatedConsentOwner as DelegatedRecordOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistRecoveredHistoryRecordRouting as Routing
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryRecordRouting.sol";

interface GenerationTestVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @notice Actual original Safe/owner/Archive records over complete multiple-generation imports.
/// @dev Core, scoped governance and archival coverage retain the inherited explicit unit boundaries.
abstract contract ArtistRecoveredMultipleGenerationActualFixture is ArtistRecoveredMultipleGenerationFixture
{
    struct Saved {
        Ready.AttestationInput input;
        bytes32 record;
        bytes statement;
        T.Authorization authorization;
        uint8 authorityClass;
    }
    Saved[] internal maRows;
    bytes32 internal constant CREDENTIAL_SCHEMA =
        keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");
    StreamSchemaDocumentStore internal documents;
    uint256 internal actionNonce;
    T.EconomicsConsent[] internal mgEconomics;
    T.RoyaltyFreeze[] internal mgRoyalties;
    bool internal interleave;
    bool internal leavePending;

    function _multiEstateCapabilities() internal pure override returns (uint32) {
        return 2305;
    }

    function _maShared(bytes32 grant) internal override {
        bytes32 first = _maCredential(1, 0, grant, 4, grant == 0);
        bytes32 second = _maCredential(2, first, grant, 5, false);
        _maCredential(1, second, 0, 0, false);
        bytes memory statement = abi.encode("original aggregate personhood waiver", artistId);
        T.Attestation memory terms = T.Attestation(
            2,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"),
            keccak256(statement),
            "urn:aggregate:waiver"
        );
        _maWrite(terms, statement, 0, 0, false);
        statement = bytes("original aggregate deployment statement");
        terms = T.Attestation(
            1,
            9,
            bytes32(uint256(uint160(address(core)))),
            Hashes.deploymentFacts(
                Hashes.Environment(
                    block.chainid, address(ingress), address(core), address(manager)
                ),
                1,
                ingress.displayBinding(1)
            ),
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1"),
            keccak256(statement),
            "urn:aggregate:deployment"
        );
        _maWrite(terms, statement, 0, 0, false);
    }

    function _maCredential(
        uint256 collection,
        bytes32 previous,
        bytes32 grant,
        uint256 nonce,
        bool safe
    ) internal returns (bytes32) {
        C2PA.Credential[] memory items = new C2PA.Credential[](1);
        items[0] = C2PA.Credential(1, keccak256("aggregate SPKI"), keccak256("aggregate key"), 1, 0);
        bytes memory statement = abi.encode(
            C2PA.Payload(1, artistId, ingress.operativeIdentityRecord(artistId), previous, items)
        );
        T.Attestation memory terms = T.Attestation(
            collection,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            CREDENTIAL_SCHEMA,
            keccak256(statement),
            "urn:aggregate:credential"
        );
        return _maWrite(terms, statement, grant, nonce, safe);
    }

    function _maWrite(
        T.Attestation memory terms,
        bytes memory statement,
        bytes32 grant,
        uint256 nonce,
        bool safe
    ) internal returns (bytes32 record) {
        T.Authorization memory a = grant == 0
            ? _authorization(true)
            : T.Authorization(nonce, uint64(block.timestamp), "");
        bytes32 digest = ingress.attestationDigest(terms, a);
        address signer = grant == 0 ? address(artist) : address(delegateSafe);
        uint8 class_ = grant == 0
            ? IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityClass
            : 2;
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(core),
                terms.collectionId,
                terms.subjectKind,
                terms.subjectId,
                terms.subjectStateHash,
                terms.schemaId,
                terms.statementHash,
                keccak256(bytes(terms.statementURI)),
                artistId,
                signer,
                class_,
                a.nonce,
                a.time
            )
        );
        if (safe) {
            require(grant == 0, "direct original Safe fixture");
            require(
                executeSafe(
                    artist,
                    keys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistOnboarding.recordArtistAttestation, (terms, a, statement)
                    ),
                    0
                ),
                "original op24 Safe"
            );
        } else {
            a.signature = grant == 0 ? _signature(digest) : _delegateSignature(digest);
            bytes32 actual = grant == 0
                ? ingress.recordArtistAttestation(terms, a, statement)
                : ingress.recordDelegatedArtistAttestation(terms, grant, a, statement);
            require(actual == record, "literal original24 domain/preimage");
        }
        require(
            Attribution(suite.owners[4]).attestationRecord(record).recordHash == record,
            "actual native record"
        );
        _mcRemember(record, digest, a, grant != 0);
        if (grant == 0) {
            _rhCandidate(
                2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record))
            );
        }
        maRows.push(Saved(Ready.AttestationInput(terms, a.nonce), record, statement, a, class_));
    }

    function _maSemantics(T.SuiteConfiguration memory s) internal view returns (bytes32 h) {
        for (uint256 i; i < maRows.length; ++i) {
            bytes32 record = maRows[i].record;
            T.Attestation memory terms = maRows[i].input.terms;
            h = keccak256(
                abi.encode(
                    h,
                    Attribution(s.owners[4]).attestationRecord(record),
                    Classes(s.owners[4]).attestationAuthorityClass(record),
                    Associations(s.owners[4]).attestationAssociation(record),
                    Attribution(s.owners[4]).statementBytes(terms.statementHash),
                    AttestationPublications(s.owners[4]).publicationAttestation(record),
                    Credentials(s.owners[4]).c2paCredentialRecord(record),
                    Personhood(s.owners[4]).personhoodProofSummary(record),
                    Personhood(s.owners[4]).personhoodProofSummaryHash(record),
                    Attribution(s.owners[4])
                        .attestation(terms.collectionId, terms.subjectKind, terms.subjectId)
                )
            );
        }
        for (uint256 a; a < multiArtists.length; ++a) {
            h = keccak256(
                abi.encode(h, Credentials(s.owners[4]).c2paCredentialHead(multiArtists[a]))
            );
        }
        for (uint256 k; k < 2; ++k) {
            h = keccak256(
                abi.encode(
                    h,
                    Credentials(s.owners[4]).personhoodAttestation(k + 1, multiCollectionArtists[k])
                )
            );
        }
    }

    function _mgCorrect(uint256 collection) internal {
        T.Binding memory previous = Binding(suite.owners[0]).binding(collection);
        bytes32 evidence =
            _mgEvidence(collection, 0, keccak256(abi.encode("opening", previous.generation)));
        AD.Filing memory filing = AD.Filing(collection, previous.generation, 1, evidence, evidence);
        AD.Standing memory noStanding;
        T.Authorization memory noAuthorization;
        bytes32 openingAction = _govern(
            abi.encodeCall(Disputes.openAttributionDispute, (filing, noStanding, noAuthorization)),
            ingress.attributionDisputeOpeningContext(filing),
            evidence,
            1
        );
        AD.Head memory head = ingress.attributionDispute(collection, previous.generation);
        AD.Record memory opening = ingress.attributionDisputeRecord(head.disputeRecordHash);
        require(
            opening.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DISPUTE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        collection,
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
                    collection, previous.generation, bytes32(0), address(artist), evidence, evidence
                )
            )
        );
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", openingAction);
        if (interleave) {
            _maCredential(
                collection == 1 ? 2 : 1,
                Credentials(suite.owners[4]).c2paCredentialHead(artistId).recordHash,
                0,
                0,
                true
            );
        }
        evidence = _mgEvidence(
            collection, opening.recordHash, keccak256(abi.encode("resolution", previous.generation))
        );
        AD.ResolutionRequest memory resolution = AD.ResolutionRequest(
            collection, previous.generation, opening.recordHash, 2, evidence, evidence, 0
        );
        bytes32 resolutionAction = _govern(
            abi.encodeCall(Disputes.resolveAttributionDispute, (resolution)),
            ingress.attributionDisputeResolutionContext(resolution),
            evidence,
            2
        );
        _rhCandidate(4, "attribution_lifecycle.replay.dispute_resolution_key", opening.recordHash);
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", resolutionAction);
        T.Identity memory identity = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        T.BindingProposal memory proposal = _multiProposal(artistId);
        proposal.identityRecordHash = identity.identityRecordHash;
        proposal.reasonHash = keccak256(abi.encode("fresh exact corrective1", previous.generation));
        bytes memory document = IStreamArtistIdentityOwner(suite.owners[2])
            .identityDocumentBytes(identity.identityRecordHash);
        (BC.Context memory c,) = CorrectionAdmission.context(
            suite, collection, proposal, document, identity.displayName, 0
        );
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        bytes32 action = _govern(
            abi.encodeCall(
                Correction.proposeArtistBindingAfterRevocation,
                (collection, proposal, document, identity.displayName, bytes32(0))
            ),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            proposal.reasonHash,
            2
        );
        _rhCandidate(0, "binding_lifecycle.replay.correction_action", action);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(collection, previous.generation + 1))
        );
        if (!leavePending) _mgAccept(collection);
    }

    function _mgAccept(uint256 collection) internal {
        T.Authorization memory authorization = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(collection, authorization);
        authorization.signature = _signature(digest);
        _rhAuthorization(digest, authorization.nonce);
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (collection, authorization))
        );
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(
                abi.encode(
                    collection,
                    Binding(suite.owners[0]).binding(collection).generation,
                    IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityClass,
                    address(artist)
                )
            )
        );
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
        // Match the inherited typed governance boundary for each exact original action;
        // a prior recovery's inactive currentAction mock must not mask this context.
        avm.mockCall(
            address(authority),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, action, cls, c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        authority.executeModuleContextWithAction(
            action, address(ingress), data, cls, c.scopeHash, c.oldValueHash, c.newValueHash
        );
        avm.mockCall(
            address(authority),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
    }

    function _mgEvidence(uint256 collection, bytes32 parent, bytes32 narrative)
        internal
        returns (bytes32 hash)
    {
        if (address(documents) == address(0)) {
            documents = StreamSchemaDocumentStore(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol:StreamSchemaDocumentStore",
                        abi.encode()
                    ))
            );
        }
        T.Binding memory b = Binding(suite.owners[0]).binding(collection);
        bytes memory data =
            abi.encode(AD.Evidence(1, collection, b.generation, b.bindingHash, parent, narrative));
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
                IStreamCollectionArchivalCoverage.requireCollectionEvidence, (collection, hash)
            ),
            abi.encode(f)
        );
    }

    function _mgSource(bool delegated) internal {
        _mcSource(delegated);
        mgEconomics.push(mcEconomics);
        mgRoyalties.push(mcRoyalty);
        interleave = true;
        _mgCorrect(1);
        bytes32 grant = delegated ? mcGrants[mcGrants.length - 1] : bytes32(0);
        _mcEconomics(grant, 8);
        mgEconomics.push(mcEconomics);
        _mcSale(grant, 9);
        _mcContentAndFreeze();
        _mcRoyalty(grant, 10);
        mgRoyalties.push(mcRoyalty);
        _maCredential(
            1,
            Credentials(suite.owners[4]).c2paCredentialHead(artistId).recordHash,
            grant,
            11,
            grant == 0
        );
        if (grant != 0) _mcRevoke(grant);
    }

    function _mgPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _multiRequest();
        for (uint256 k; k < 2; ++k) {
            uint256 n = 1;
            for (uint256 j; j < mcPolicies.length; ++j) {
                if (mcPolicies[j].collectionId == k + 1) ++n;
            }
            AH.PolicyKey[] memory keys_ = new AH.PolicyKey[](n);
            keys_[0] = AH.PolicyKey(PHASE, multiPolicies[k]);
            n = 1;
            for (uint256 j; j < mcPolicies.length; ++j) {
                if (mcPolicies[j].collectionId == k + 1) {
                    keys_[n++] = AH.PolicyKey(mcPolicies[j].phaseId, mcPolicies[j].policyHash);
                }
            }
            r.records.authority.collections[k].policies = keys_;
        }
        uint256[2] memory counts;
        for (uint256 j; j < maRows.length; ++j) {
            ++counts[maRows[j].input.terms.collectionId - 1];
        }
        uint256 n = (counts[0] != 0 || mgEconomics.length != 0 ? 1 : 0) + (counts[1] != 0 ? 1 : 0);
        r.records.witnesses = new MR.CollectionWitness[](n);
        uint256 at;
        for (uint256 k; k < 2; ++k) {
            if (counts[k] == 0 && (k != 0 || mgEconomics.length == 0)) continue;
            MR.CollectionWitness memory w;
            w.collectionId = k + 1;
            w.economics = new T.EconomicsConsent[](k == 0 ? mgEconomics.length : 0);
            if (k == 0) for (uint256 j; j < mgEconomics.length; ++j) {
                w.economics[j] = mgEconomics[j];
            }
            w.attestations = new Ready.AttestationInput[](counts[k]);
            uint256 c;
            for (uint256 j; j < maRows.length; ++j) {
                if (maRows[j].input.terms.collectionId == k + 1) w.attestations[c++] =
                maRows[j].input;
            }
            r.records.witnesses[at++] = w;
        }
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r, mgRoyalties);
        r.expectedSemanticInventory = Prepared.inventory(p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h, Payload.Payload memory local) =
                Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & (2097152 | 512)) == (2097152 | 512),
                "all seven additive generation flags"
            );
            (M.State memory scope, bytes memory auxiliary) =
                ConsentCodec.decodeAuxiliary(i, local.semanticState, local.provenance);
            require(
                keccak256(local.semanticState)
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1"),
                            uint16(1),
                            i,
                            scope,
                            auxiliary
                        )
                    ),
                "literal typed owner envelope"
            );
            require(
                (i == 0 || i == 3 || i == 4) ? auxiliary.length != 0 : auxiliary.length == 0,
                "complete original Archive inventory only in selected owners"
            );
        }
    }

    function _mgImport(
        Successor memory next,
        RH.Request memory r,
        Commit.Prepared memory p,
        bool safe
    ) internal {
        if (safe) {
            require(
                this.rhExecuteNewSafe(
                    address(next.registry),
                    abi.encodeCall(
                        ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents,
                        (r, mgRoyalties)
                    )
                ),
                "actual Safe aggregate60"
            );
        } else {
            ConsentHydration(address(next.registry))
                .hydrateRecoveredArtistAuthorityWithConsents(r, mgRoyalties);
        }
        _multiAssert(next, p);
        require(
            _mgSemantics(next.coordinator.suiteConfiguration()) == _mgSemantics(suite),
            "all original generation, signature, association and head state"
        );
    }

    function _mgSemantics(T.SuiteConfiguration memory target) internal view returns (bytes32 h) {
        h = _maSemantics(target);
        for (uint256 c = 1; c <= 2; ++c) {
            uint64 count = Binding(suite.owners[0]).binding(c).generation;
            for (uint64 g = 1; g <= count; ++g) {
                bytes32 hash = Binding(suite.owners[0]).bindingAt(c, g).bindingHash;
                (BC.Approval memory correction, bytes32 correctionRecord) =
                    CorrectionOwner(target.owners[0]).bindingCorrection(hash);
                AD.Head memory original = DisputeOwner(suite.owners[4]).attributionDispute(c, g);
                bytes32 accepted = Acceptance(suite.owners[3]).acceptanceRecord(hash);
                h = keccak256(
                    abi.encode(
                        h,
                        Binding(target.owners[0]).bindingAt(c, g),
                        Terms(target.owners[0]).bindingTerms(c, g),
                        Lifecycle(target.owners[0]).bindingTermination(c, g),
                        correction,
                        correctionRecord,
                        Acceptance(target.owners[3]).acceptanceRecord(hash),
                        Acceptance(target.owners[3]).acceptedAt(hash),
                        IStreamArtistIdentityOwner(target.owners[2]).signatureBundle(accepted),
                        DisputeOwner(target.owners[4]).attributionDispute(c, g),
                        DisputeOwner(target.owners[4])
                            .attributionDisputeRecord(original.disputeRecordHash),
                        DisputeOwner(target.owners[4])
                            .attributionDisputeResolution(original.resolutionActionId)
                    )
                );
            }
        }
        for (uint256 i; i < mcRecords.length; ++i) {
            bytes32 record = mcRecords[i];
            h = keccak256(
                abi.encode(
                    h,
                    IStreamArtistIdentityOwner(target.owners[2]).signatureBundle(record),
                    Economics(target.owners[6]).economicsRecordAssociation(record),
                    Sales(target.owners[6]).saleConsentRecord(record),
                    ContentOwner(target.owners[6]).contentConsentRecord(record),
                    ContentOwner(target.owners[6]).contentFreezeRecord(record)
                )
            );
        }
        for (uint256 i; i < mcRecords.length; ++i) {
            bytes32 record = mcRecords[i];
            ContentOwner.ConsentRecord memory content =
                ContentOwner(suite.owners[6]).contentConsentRecord(record);
            if (content.recordHash != 0) {
                h = keccak256(
                    abi.encode(
                        h,
                        ContentOwner(target.owners[6])
                            .contentConsentAt(content.terms, content.bindingGeneration)
                    )
                );
            }
            Content.FreezeRecord memory freeze =
                ContentOwner(suite.owners[6]).contentFreezeRecord(record);
            for (uint256 k; k < freeze.lockClasses.length; ++k) {
                h = keccak256(
                    abi.encode(
                        h,
                        ContentOwner(target.owners[6])
                            .contentFreezeAt(
                                1,
                                freeze.bindingGeneration,
                                freeze.metadataContract,
                                freeze.lockClasses[k]
                            )
                    )
                );
            }
            Sale.Record memory sale = Sales(suite.owners[6]).saleConsentRecord(record);
            if (sale.recordHash != 0) {
                h = keccak256(
                    abi.encode(
                        h,
                        Sales(target.owners[6])
                            .saleConsentAt(
                                sale.terms.collectionId,
                                sale.terms.saleId,
                                sale.terms.saleConfigHash
                            )
                    )
                );
            }
            h = keccak256(
                abi.encode(h, DelegatedRecordOwner(target.owners[6]).recordDelegation(record))
            );
        }
        for (uint256 i; i < mcPolicies.length; ++i) {
            h = keccak256(
                abi.encode(
                    h,
                    Consent(target.owners[6])
                        .policyRecord(
                            mcPolicies[i].collectionId,
                            mcPolicies[i].phaseId,
                            mcPolicies[i].policyHash
                        )
                )
            );
        }
        for (uint256 i; i < mgEconomics.length; ++i) {
            h = keccak256(abi.encode(h, Consent(target.owners[6]).economicsRecord(mgEconomics[i])));
            uint64 count = Binding(suite.owners[0]).binding(1).generation;
            for (uint64 g = 1; g <= count; ++g) {
                h = keccak256(
                    abi.encode(
                        h,
                        Economics(target.owners[6])
                            .economicsRecordForBinding(
                                mgEconomics[i],
                                multiCollectionArtists[0],
                                g,
                                Binding(suite.owners[0]).bindingAt(1, g).bindingHash
                            )
                    )
                );
            }
        }
        for (uint256 i; i < mcGrants.length; ++i) {
            h = keccak256(
                abi.encode(
                    h, IStreamArtistDelegationOwner(target.owners[2]).delegationRecord(mcGrants[i])
                )
            );
        }
        for (uint256 i; i < mgRoyalties.length; ++i) {
            for (uint64 g = 1; g <= Binding(suite.owners[0]).binding(1).generation; ++g) {
                h = keccak256(
                    abi.encode(
                        h,
                        Consent(target.owners[6])
                            .royaltyFreezeRecord(mgRoyalties[i], multiCollectionArtists[0], g)
                    )
                );
            }
        }
        for (uint256 i; i < maRows.length; ++i) {
            if (maRows[i].authorityClass == 2) {
                (bool used, uint256 hint) = IStreamArtistDelegationOwner(target.owners[2])
                    .delegatedNonceState(
                        Associations(suite.owners[4])
                        .attestationAssociation(maRows[i].record)
                        .artistId,
                        address(delegateSafe),
                        maRows[i].input.nonce
                    );
                h = keccak256(abi.encode(h, used, hint));
            }
        }
    }

    function _mgHash(Successor memory next) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _multiDestinationHash(next), _mgSemantics(next.coordinator.suiteConfiguration())
            )
        );
    }

    function _mgBad(Successor memory next, RH.Request memory r) internal {
        bytes32 before_ = _mgHash(next);
        (bool ok,) = address(next.registry)
            .call(
                abi.encodeCall(
                    ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mgRoyalties)
                )
            );
        require(!ok && before_ == _mgHash(next), "refused before any retained destination change");
    }

    function _mgRepropose(uint256 collection) internal {
        T.Identity memory identity = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        T.BindingProposal memory proposal = _multiProposal(artistId);
        proposal.identityRecordHash = identity.identityRecordHash;
        ingress.proposeArtistBinding(
            collection,
            proposal,
            IStreamArtistIdentityOwner(suite.owners[2])
                .identityDocumentBytes(identity.identityRecordHash),
            identity.displayName
        );
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(
                abi.encode(collection, Binding(suite.owners[0]).binding(collection).generation)
            )
        );
    }

    function _mgRatificationWrite(uint256 collection, uint256 salt, bool direct)
        internal
        returns (bytes memory saved)
    {
        bytes32 content = keccak256(abi.encode("actual G original52 content", collection, salt));
        metadata.setContent(content);
        T.Ratification memory terms = T.Ratification(collection, address(metadata), content);
        T.Identity memory identity = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            identity.authorityAddress == address(artist) && identity.authorityClass == 1,
            "actual recovered living authority for original52"
        );
        nextNonce = identity.nonceHint;
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentRatificationDigest(terms, a);
        _rhAuthorization(digest, a.nonce);
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 count = Native(suite.owners[6]).artistNativeReceiptCount();
        bytes32 record;
        if (direct) {
            require(
                this.rhExecuteNewSafe(
                    address(ingress),
                    abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (terms, a))
                ),
                "actual original G Safe52"
            );
            record = Consent(suite.owners[6]).firstReleaseRatification(collection).recordHash;
        } else {
            a.signature = _signature(digest);
            record = ingress.recordContentRatification(terms, a);
        }
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        collection,
                        content,
                        artistId,
                        address(artist),
                        uint8(1),
                        a.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original52 authority and nonce record domain"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == identityCount
                && Native(suite.owners[6]).artistNativeReceiptCount() == count + 1
                && Native(suite.owners[6]).artistNativeReceiptAt(count).operation == 52
                && Native(suite.owners[6]).artistNativeReceiptAt(count).artistId == artistId
                && Native(suite.owners[6]).artistNativeReceiptAt(count).collectionId == collection
                && Native(suite.owners[6]).artistNativeReceiptAt(count).recordHash == record,
            "one original Consent52 and no fabricated Identity52 receipt"
        );
        _rhCandidate(
            6, "consent_finality.replay.ratification_key", keccak256(abi.encode(collection, record))
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
                && keccak256(IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record))
                    == keccak256(a.signature),
            "genuine nonce and exact signed or empty direct evidence"
        );
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(52),
                direct ? address(artist) : address(this),
                record
            )
        );
        saved = abi.encode(
            collection,
            Consent(suite.owners[6]).ratificationRecord(record),
            a.signature,
            a.nonce,
            evidenceId,
            _mgRatificationArchiveCut(evidenceId)
        );
    }

    function _mgRatificationHeaders(Commit.Prepared memory p) internal pure {
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & (XF.MULTIPLE_GENERATIONS | RH.RATIFICATIONS))
                    == (XF.MULTIPLE_GENERATIONS | RH.RATIFICATIONS),
                "all seven original G headers explicitly carry52"
            );
        }
    }

    function _mgRatificationAssert(T.SuiteConfiguration memory target, bytes[] memory saved)
        internal
        view
    {
        for (uint256 i; i < saved.length; ++i) {
            (
                uint256 collection,
                T.RatificationRecord memory row,
                bytes memory signature,
                uint256 nonce,
                bytes32 evidenceId,
                bytes32 archiveCut
            ) = abi.decode(
                saved[i], (uint256, T.RatificationRecord, bytes, uint256, bytes32, bytes32)
            );
            require(
                keccak256(abi.encode(Consent(target.owners[6]).ratificationRecord(row.recordHash)))
                        == keccak256(abi.encode(row))
                    && keccak256(
                        IStreamArtistIdentityOwner(target.owners[2]).signatureBundle(row.recordHash)
                    ) == keccak256(signature)
                    && IStreamArtistIdentityOwner(target.owners[2]).nonceUsed(artistId, nonce)
                    && DelegatedRecordOwner(target.owners[6]).recordDelegation(row.recordHash) == 0,
                "exact original G52 record signature nonce and nondelegated provenance"
            );
            bool latest = true;
            for (uint256 j = i + 1; j < saved.length; ++j) {
                if (abi.decode(saved[j], (uint256)) == collection) latest = false;
            }
            if (latest) {
                require(
                    keccak256(
                        abi.encode(Consent(target.owners[6]).firstReleaseRatification(collection))
                    ) == keccak256(abi.encode(row)),
                    "latest original52 head per collection"
                );
            }
            require(
                _mgRatificationArchiveCut(evidenceId) == archiveCut,
                "retained exact original Archive pointer metadata and bytes"
            );
        }
    }

    function _mgRatificationState(T.SuiteConfiguration memory target, bytes[] memory saved)
        internal
        view
        returns (bytes32 value)
    {
        for (uint256 i; i < saved.length; ++i) {
            (uint256 collection, T.RatificationRecord memory row,, uint256 nonce,,) = abi.decode(
                saved[i], (uint256, T.RatificationRecord, bytes, uint256, bytes32, bytes32)
            );
            value = keccak256(
                abi.encode(
                    value,
                    Consent(target.owners[6]).ratificationRecord(row.recordHash),
                    Consent(target.owners[6]).firstReleaseRatification(collection),
                    IStreamArtistIdentityOwner(target.owners[2]).signatureBundle(row.recordHash),
                    IStreamArtistIdentityOwner(target.owners[2]).nonceUsed(artistId, nonce),
                    DelegatedRecordOwner(target.owners[6]).recordDelegation(row.recordHash)
                )
            );
        }
    }

    function _mgRatificationSourceCut(bytes[] memory saved) internal view returns (bytes32 value) {
        value = _mgRatificationState(suite, saved);
        for (uint8 i; i < 7; ++i) {
            value = keccak256(
                abi.encode(
                    value,
                    CP(suite.owners[i]).authorityCheckpoint(),
                    Publications.collect(suite.owners[i], i)
                )
            );
        }
        for (uint256 i; i < saved.length; ++i) {
            (,,,, bytes32 evidenceId,) = abi.decode(
                saved[i], (uint256, T.RatificationRecord, bytes, uint256, bytes32, bytes32)
            );
            value = keccak256(abi.encode(value, _mgRatificationArchiveCut(evidenceId)));
        }
    }

    function _mgRatificationArchiveCut(bytes32 evidenceId) internal view returns (bytes32) {
        (bytes32 hash, address pointer, uint32 size, uint64 at) =
            IStreamArtistArchiveV2(suite.archive).artistEvidenceMetadataV2(evidenceId, 1);
        bytes memory raw =
            IStreamArtistArchiveV2(suite.archive).artistEvidenceBytesV2(evidenceId, 1);
        require(
            hash == keccak256(raw) && raw.length == size && pointer.code.length == size + 1,
            "actual original52 immutable Archive evidence"
        );
        return keccak256(abi.encode(hash, pointer, size, at, raw));
    }
}
