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
contract StreamArtistRecoveredMultipleGenerationActualTest is
    ArtistRecoveredMultipleGenerationFixture
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
    StreamSchemaDocumentStore private documents;
    uint256 private actionNonce;
    T.EconomicsConsent[] private mgEconomics;
    T.RoyaltyFreeze[] private mgRoyalties;
    bool private interleave;
    bool private leavePending;

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

    function _mgCorrect(uint256 collection) private {
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

    function _mgAccept(uint256 collection) private {
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
        private
        returns (bytes32 hash)
    {
        if (address(documents) == address(0)) documents = new StreamSchemaDocumentStore();
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

    function _mgSource(bool delegated) private {
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
        private
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
    ) private {
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

    function _mgSemantics(T.SuiteConfiguration memory target) private view returns (bytes32 h) {
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

    function _mgHash(Successor memory next) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _multiDestinationHash(next), _mgSemantics(next.coordinator.suiteConfiguration())
            )
        );
    }

    function _mgBad(Successor memory next, RH.Request memory r) private {
        bytes32 before_ = _mgHash(next);
        (bool ok,) = address(next.registry)
            .call(
                abi.encodeCall(
                    ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mgRoyalties)
                )
            );
        require(!ok && before_ == _mgHash(next), "refused before any retained destination change");
    }

    function testGenerationAggregatePreservesSameTermsEconomicsSalesAndGlobalGrants() external {
        _mgSource(true);
        require(
            mgEconomics.length == 2
                && keccak256(abi.encode(mgEconomics[0])) == keccak256(abi.encode(mgEconomics[1])),
            "genuine identical original15 terms"
        );
        bytes32 first = Consent(suite.owners[6]).economicsRecord(mgEconomics[0]);
        Economics.Association memory later =
            Economics(suite.owners[6]).economicsRecordAssociation(mcEconomicsRecord);
        require(
            first != mcEconomicsRecord && later.originalRecord == first
                && later.bindingGeneration == 2,
            "original terms anchor and distinct continuation"
        );
        require(
            ingress.delegationRecord(mcGrants[0]).uses == 7
                && ingress.delegationRecord(mcGrants[1]).uses == 4,
            "global all-version use totals"
        );
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        _mgImport(next, r, p, false);
    }

    function testGenerationAggregateDirectSafeKeepsInterleavedResolutionCoordinates() external {
        _mgSource(false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        RH.OwnerProvenance memory owner = RH.ownerProvenance(p.admission.provenance, 4);
        bool found;
        for (uint256 i; i < owner.journal.length; ++i) {
            if (owner.journal[i].receipt.operation == 44) {
                require(
                    owner.journal[i + 1].receipt.operation == 24,
                    "actual other collection write inside governed dispute"
                );
                for (uint256 j; j < owner.aliases.length; ++j) {
                    if (
                        owner.aliases[j].surface
                                == keccak256("attribution_lifecycle.replay.dispute_resolution_key")
                            && owner.aliases[j].scope == owner.journal[i].receipt.recordHash
                    ) {
                        require(
                            owner.aliases[j].admittedAt.ownerRevision
                                == owner.journal[i].position.point.ownerRevision + 2,
                            "authentic resolution is not opening plus one"
                        );
                        found = true;
                    }
                }
            }
        }
        require(found, "original resolution alias");
        _mgImport(next, r, p, true);
    }

    function testGenerationAggregateMixedClassThreeCorrectionAndOriginalSafe() external {
        _multiSource(false, true);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(multiRecovery[1]).postWindowEndsAt);
        _mgCorrect(2);
        _maCredential(2, 0, 0, 0, true);
        require(maRows[0].authorityClass == 3, "actual recovered class3 generation2");
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        _mgImport(next, r, p, true);
    }

    function testGenerationAggregateRepeatedImportRetainsAllOriginalEraPoints() external {
        _mgSource(false);
        Successor memory middle = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(middle);
        _mgImport(middle, r, p, true);
        _rhAdopt(middle);
        Successor memory next = _multiCutover();
        (r, p) = _mgPrepare(next);
        require(p.admission.provenance.eras.length == 2, "full inherited and current provenance");
        _mgImport(next, r, p, true);
    }

    function testGenerationAggregateCompleteHeadersAndEconomicsWitnessRestore() external {
        _mgSource(true);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        bytes memory saved = abi.encode(r);
        for (uint256 i; i < 7; ++i) {
            r = abi.decode(saved, (RH.Request));
            ++r.records.authority.expectedSource[i].ownerState.revision;
            _mgBad(next, r);
        }
        r = abi.decode(saved, (RH.Request));
        r.records.witnesses[0].economics = new T.EconomicsConsent[](1);
        r.records.witnesses[0].economics[0] = mgEconomics[0];
        _mgBad(next, r);
        r = abi.decode(saved, (RH.Request));
        r.records.witnesses[0].economics[1].assignmentHash = keccak256("foreign continuation terms");
        _mgBad(next, r);
        _mgImport(next, abi.decode(saved, (RH.Request)), p, true);
    }

    function testGenerationAggregateLateArchiveFailureRollsBackAllScopesThenSafeRetries() external {
        _mgSource(true);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        bytes32 before_ = _mgHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 at = block.number;
        bytes memory data = abi.encodeCall(
            ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mgRoyalties)
        );
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, mgRoyalties);
        require(_mgHash(next) == before_, "all seven owners and generation maps rolled back");
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), data);
        require(
            rotationSafe.nonce() == nonce && _mgHash(next) == before_,
            "Safe nonce and full graph rollback"
        );
        vm.roll(at);
        _mgImport(next, r, p, true);
    }

    function _mgRepropose(uint256 collection) private {
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

    function testGenerationAggregateAcceptedRefusedWithdrawnThenAcceptedGenerationFour() external {
        _multiSource(true, false);
        leavePending = true;
        _mgCorrect(1);
        L.Termination memory termination = _termination(1);
        T.Authorization memory authorization = _authorization(false);
        bytes32 digest = ingress.bindingRefusalDigest(termination, authorization);
        authorization.signature = _signature(digest);
        bytes32 refused = ingress.refuseArtistBinding(termination, authorization);
        _mcRemember(refused, digest, authorization, false);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.refusal_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(2)))
        );
        _mgRepropose(1);
        termination = _termination(1);
        ingress.withdrawArtistBinding(termination);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_terminal_transition_key",
            keccak256(abi.encode(uint256(1), uint64(3)))
        );
        _mgRepropose(1);
        _mgAccept(1);
        _maCredential(1, 0, 0, 0, true);
        require(
            Binding(suite.owners[0]).binding(1).generation == 4
                && Lifecycle(suite.owners[0]).bindingTermination(1, 2).kind == 1
                && Lifecycle(suite.owners[0]).bindingTermination(1, 3).kind == 2,
            "original accepted/refusal/withdrawal/final acceptance combination"
        );
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _mgPrepare(next);
        _mgImport(next, r, prepared, true);
    }

    function testGenerationAggregateTwoArtistsKeepIndependentSameDelegateNonce() external {
        _multiSource(false, false);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(multiRecovery[1]).postWindowEndsAt);
        uint256[] memory secondKeys = keys;
        artistId = multiCollectionArtists[0];
        artist = OfficialSafe(multiAuthorities[0]);
        keys = new uint256[](2);
        keys[0] = 0xCA1100 + 36001;
        keys[1] = 0xCA2200 + 36001;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        _mgCorrect(1);
        bytes32 first = _mcGrant(1);
        _maCredential(1, 0, first, 77, false);
        artistId = multiCollectionArtists[1];
        artist = OfficialSafe(multiAuthorities[1]);
        keys = secondKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        _mgCorrect(2);
        bytes32 second = _mcGrant(1);
        _maCredential(2, 0, second, 77, false);
        require(first != second, "independent authentic Artist grants");
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _mgPrepare(next);
        _mgImport(next, r, prepared, false);
        for (uint256 k; k < 2; ++k) {
            (bool used,) = next.registry
            .delegatedNonceState(multiCollectionArtists[k], address(delegateSafe), 77);
            require(
                used && next.registry.delegationRecord(mcGrants[k]).uses == 1,
                "full distinct nonce lanes and counters"
            );
        }
    }

    function testGenerationAggregateGlobalGrantConservationCannotResetAtGenerationBoundary()
        external
    {
        _mgSource(true);
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory prepared) = _mgPrepare(next);
        (, Payload.Payload memory idPayload) = Payload.decode(prepared.data[2].typedState, 2);
        M.State memory identities =
            ConsentCodec.decode(2, idPayload.semanticState, idPayload.provenance);
        (, Payload.Payload memory consentPayload) = Payload.decode(prepared.data[6].typedState, 6);
        M.State memory rows =
            ConsentCodec.decode(6, consentPayload.semanticState, consentPayload.provenance);
        G.Consents[] memory consents = new G.Consents[](rows.rows.length);
        for (uint256 k; k < consents.length; ++k) {
            consents[k] = abi.decode(rows.rows[k], (G.Consents));
        }
        (, Payload.Payload memory ap) = Payload.decode(prepared.data[4].typedState, 4);
        (M.State memory attested, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, ap.semanticState, ap.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        for (uint256 k; k < attested.rows.length; ++k) {
            attested.rows[k] = abi.encode(abi.decode(attested.rows[k], (G.Attribution)).records);
        }
        Conservation.Context memory x = Conservation.Context(
            identities.rows,
            identities,
            consents,
            attested.rows,
            inventory,
            prepared.admission.provenance
        );
        Conservation.validate(x);
        bytes memory saved = x.identities[0];
        for (uint256 n = 3; n <= 5; n += 2) {
            IH.Bundle memory b = abi.decode(saved, (IH.Bundle));
            b.delegations[1].record.uses = n;
            x.identities[0] = abi.encode(b);
            (bool ok,) = address(Conservation)
                .staticcall(abi.encodeWithSelector(Conservation.validate.selector, x));
            require(!ok, "missing or double-counted generation use rejects");
        }
        x.identities[0] = saved;
        Conservation.validate(x);
    }

    function testGenerationAggregateFinalCurrentnessRejectsOriginalArchiveInventoryDrift()
        external
    {
        _mgSource(false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _mgPrepare(next);
        Current.requireCurrent(
            prepared.admission.provenance, prepared.query, prepared.data[4].typedState
        );
        (RH.ExportHeader memory header, Payload.Payload memory payload) =
            Payload.decode(prepared.data[4].typedState, 4);
        (M.State memory scope, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, payload.semanticState, payload.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        ++inventory.catalogues[0].upper[0];
        payload.semanticState =
            ConsentCodec.encode(4, scope, payload.provenance, abi.encode(inventory));
        header.semanticInventory = keccak256(payload.semanticState);
        (bool ok,) = address(Current)
            .staticcall(
                abi.encodeWithSelector(
                    Current.requireCurrent.selector,
                    prepared.admission.provenance,
                    prepared.query,
                    Payload.encode(4, header, payload)
                )
            );
        require(!ok, "full owner0 cutoff cannot hide inside owner4 envelope");
        Current.requireCurrent(
            prepared.admission.provenance, prepared.query, prepared.data[4].typedState
        );
        _mgImport(next, r, prepared, true);
    }

    function testGenerationAggregateWithoutAttestationsStillRechecksArchiveAfterImport() external {
        _multiSource(true, false);
        _mgCorrect(1);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _mgPrepare(next);
        (RH.ExportHeader memory header, Payload.Payload memory payload) =
            Payload.decode(prepared.data[4].typedState, 4);
        require(
            (header.requiredFeatures & RH.ATTESTATIONS) == 0
                && (header.requiredFeatures & XF.MULTIPLE_GENERATIONS) != 0,
            "closed generation profile without op24"
        );
        Routing.requireCurrent(
            prepared.admission.provenance, prepared.query, prepared.data[4].typedState
        );
        (M.State memory scope, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, payload.semanticState, payload.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        ++inventory.catalogues[0].upper[0];
        payload.semanticState =
            ConsentCodec.encode(4, scope, payload.provenance, abi.encode(inventory));
        header.semanticInventory = keccak256(payload.semanticState);
        (bool ok, bytes memory reason) = address(Routing)
            .staticcall(
                abi.encodeWithSelector(
                    Routing.requireCurrent.selector,
                    prepared.admission.provenance,
                    prepared.query,
                    Payload.encode(4, header, payload)
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "actual post-import router cannot skip new profile without op24"
        );
        Routing.requireCurrent(
            prepared.admission.provenance, prepared.query, prepared.data[4].typedState
        );
        _mgImport(next, r, prepared, true);
    }
}
