// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPreservationPolicyViewFinalityAuthorityFixture
} from "./StreamCurrentFullPreservationPolicyViewFinalityAuthorityFixture.sol";
import {
    StreamFinalityScopeType,
    StreamFinalityComponentExpectation,
    StreamFinalityComponentState,
    StreamFinalityManifestRef,
    StreamScopedFinalityRecord,
    StreamFinalityDomains
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityScopeInputs
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import {
    StreamFinalityExecutionContext,
    StreamFinalityExecutionWitness
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityGovernanceTypes.sol";
import {
    StreamFinalitySanctionArchiveProof,
    StreamFinalitySanctionArchiveWitness
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalitySanctionArchiveTypes.sol";
import {
    IStreamArtistSanctionArchiveFacts
} from "../../smart-contracts/interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";
import {
    IStreamArtworkFinalityComponent
} from "../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamArtistSanctionTypes as ViewSanction
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionRequestTypes as ViewSanctionRequest
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";
import {
    StreamArtistOnboardingTypes as ViewAuthorization
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistIdentityOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistSanctionConfirmation
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    StreamArtistSanctionConfirmationTypes as ViewConfirmation
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import {
    StreamPreservationInventoryTypes as ViewOriginalInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamViewAdoptionRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import {
    IStreamSchemaRegistry as ViewFinalitySchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as ViewFinalityDocuments
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @notice Actual original op12, sanction archive and class2 scoped finality for an adopted VIEW.
/// @dev Requires the genuine complete VIEW graph and explicitly supplied reference observations.
/// No browser evidence, gas measurement or transaction-fit claim is created by this helper.
/// The concrete host supplies the new producer's exact VIEW definitions; no COLLECTION or old
/// scoped statement/receipt is decoded as VIEW, and no budget is raised by this ceremony.
abstract contract StreamCurrentFullPreservationPolicyViewFinalityFixture is
    StreamCurrentFullPreservationPolicyViewFinalityAuthorityFixture
{
    bytes32 internal viewSanctionRecord;
    bytes32 internal viewFinalityRecord;
    bytes32 internal viewFinalityManifestHash;
    bytes32 internal viewFinalityAction;
    bytes32 internal viewNonSanctionComponentsHash;
    bytes32 internal viewFinalityComponentsHash;
    StreamFinalityManifestRef internal viewFinalityManifest;
    StreamFinalityScopeInputs internal viewFinalityInputs;
    StreamFinalitySanctionArchiveProof internal viewSanctionArchiveProof;

    /// @dev Register the exact new VIEW input schema/canon and VIEW sanction profile from C.
    /// The original native-captures catalogue is COLLECTION-specific and must not be reused.
    function _viewPrepareFinalityDefinitions() internal virtual;

    function _viewPerformSanctionAndFinality() internal {
        require(
            fullPolicyViewScope.scopeType == StreamFinalityScopeType.VIEW
                && fullPolicyViewScope.collectionId == 1 && fullPolicyViewScope.tokenId == 0
                && fullPolicyViewScope.scopeId != 0
                && viewCompleteBundle.coverage.bundleCoverageHash != 0 && viewSanctionRecord == 0
                && viewFinalityRecord == 0
                && !assemblyFinality.collectionFinalityRecord(1).finalized,
            "complete actual VIEW and no COLLECTION finality"
        );
        _viewPrepareCommonCeremonyDefinitions();
        _viewPrepareFinalityDefinitions();
        _viewRequireCurrentPublication();
        bytes32 liveBefore = _viewLiveSanctionCommitment();
        _viewStageFinalityManifest();
        StreamFinalityComponentExpectation[] memory independent = _viewIndependentComponents();
        _viewRecordAndArchiveSanction(independent);
        _viewAssertFinalityPreservationParity();
        require(_viewLiveSanctionCommitment() != liveBefore, "actual live VIEW sanction changes");
        _viewAssertLiveSanction();
        StreamFinalityComponentExpectation[] memory complete = _viewCompleteComponents(independent);
        _viewExecuteScopedFinality(complete);
        _viewAssertFinalityPreservationParity();
        _viewAssertLiveSanction();
        _viewRejectCollectionConfirmation();
    }

    function _viewStageFinalityManifest() private {
        bytes memory raw = assemblyProvider.inputManifestBytes(fullPolicyViewScope);
        require(raw.length != 0, "actual VIEW input producer bytes");
        viewFinalityManifestHash = keccak256(raw);
        bytes32[] memory chunks = _assemblyUpload(raw);
        bytes memory reconstructed;
        for (uint256 i; i < chunks.length; ++i) {
            reconstructed = bytes.concat(reconstructed, assemblyStore.readChunk(chunks[i]));
        }
        require(
            reconstructed.length == raw.length
                && keccak256(reconstructed) == viewFinalityManifestHash
                && assemblyFinality.stageFinalityManifest(raw) == viewFinalityManifestHash
                && assemblyFinality.finalityManifestStored(viewFinalityManifestHash)
                && keccak256(assemblyFinality.finalityManifestBytes(viewFinalityManifestHash))
                    == viewFinalityManifestHash,
            "complete identical Store and original Registry bytes"
        );
        (StreamFinalityScopeInputs memory inputs, bytes32 schema, bytes32 canon) = assemblyProvider.requireFinalityScopeInputs(
            fullPolicyViewScope, viewFinalityManifestHash
        );
        require(schema != 0 && canon != 0 && schema != canon, "actual VIEW interpretation returned");
        _viewRequireFinalityDefinition(schema, ViewFinalitySchema.DocumentKind.SCHEMA);
        _viewRequireFinalityDefinition(canon, ViewFinalitySchema.DocumentKind.CANONICALIZATION);
        _viewAssertOriginalInputJoins(inputs);
        viewFinalityInputs = inputs;
        string memory uri =
            "https://fixtures.example.invalid/view-preservation/finality-input-manifest";
        viewFinalityManifest = StreamFinalityManifestRef(
            uri, keccak256(bytes(uri)), viewFinalityManifestHash, schema, canon
        );
    }

    function _viewRequireFinalityDefinition(bytes32 id, ViewFinalitySchema.DocumentKind kind)
        private
        view
    {
        ViewFinalityDocuments.DocumentFacts memory f = assemblySchemas.documentFacts(id);
        bytes memory raw = assemblySchemas.documentBytes(id);
        require(
            f.exists && f.kind == kind && f.status == ViewFinalitySchema.DocumentStatus.ACTIVE
                && f.contentHash != 0 && f.declarationHash != 0 && f.chunkCount != 0
                && f.totalBytes == raw.length && keccak256(raw) == f.contentHash
                && f.canonicalizationId == assemblySchemas.RAW_BYTES(),
            "actual registered producer definition and complete bytes"
        );
    }

    function _viewAssertOriginalInputJoins(StreamFinalityScopeInputs memory inputs) private view {
        ViewOriginalInventory.Evidence memory e = viewRenderInventoryEvidence.inventory;
        ViewOriginalInventory.OriginalInputs memory o = e.originals;
        StreamFinalityScopeInputs memory expected = StreamFinalityScopeInputs(
            assemblyViewOriginalContentRoot,
            assemblyViewSnapshotRecord,
            assemblyViewReferenceRecord,
            o.intentRecordHash,
            viewWaiverRecord,
            o.interviewEvidenceHash,
            viewRightsRecord,
            viewWorkRecord,
            e.renderCriticalEvidenceHash,
            viewCompleteBundle.coverage.bundleCoverageHash
        );
        require(
            keccak256(abi.encode(viewRenderInventoryEvidence.scope))
                    == keccak256(abi.encode(fullPolicyViewScope))
                && keccak256(abi.encode(viewCompleteBundle.scope))
                    == keccak256(abi.encode(fullPolicyViewScope))
                && e.scopeSubject == _viewRecordsSubject() && e.collectionId == 1
                && e.artistId == assemblyArtistId && e.planId == viewRenderInventoryPlan
                && e.tokenCount == fullPolicyTokens.length && e.itemCount != 0
                && viewCompleteBundle.coverage.inventoryPlan == e.planId
                && viewCompleteBundle.coverage.renderCriticalEvidenceHash
                    == e.renderCriticalEvidenceHash
                && viewCompleteBundle.coverage.itemCount == e.itemCount
                && o.rootRecordHash == expected.rootRecordHash
                && o.snapshotRecordHash == expected.snapshotRecordHash
                && o.referenceRenderRecordHash == expected.referenceRenderRecordHash
                && o.intentRecordHash == 0
                && o.intentWaiverRecordHash == expected.intentWaiverRecordHash
                && o.interviewEvidenceHash != 0
                && o.rightsStatementRecordHash == expected.rightsStatementRecordHash
                && o.workDescriptionRecordHash == expected.workDescriptionRecordHash
                && expected.rootRecordHash != 0 && expected.snapshotRecordHash != 0
                && expected.referenceRenderRecordHash != 0 && expected.intentWaiverRecordHash != 0
                && expected.rightsStatementRecordHash != 0
                && expected.workDescriptionRecordHash != 0
                && expected.renderCriticalEvidenceHash != 0 && expected.bundleCoverageHash != 0
                && keccak256(abi.encode(inputs)) == keccak256(abi.encode(expected)),
            "all ten original VIEW inputs with genuine archive coverage and explicit waivers"
        );
    }

    function _viewIndependentComponents()
        private
        returns (StreamFinalityComponentExpectation[] memory out)
    {
        (uint256 count, bytes32 advertised) =
            assemblyDiscovery.nonSanctionDiscoveryFacts(fullPolicyViewScope);
        require(count == 9, "actual nine independent VIEW families");
        out = new StreamFinalityComponentExpectation[](count);
        for (uint256 i; i < count; ++i) {
            out[i] = assemblyDiscovery.nonSanctionComponentAt(fullPolicyViewScope, i);
            require(
                out[i].componentType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION,
                "independent family"
            );
        }
        _viewRequireComponentOrder(out);
        viewNonSanctionComponentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), out));
        require(
            advertised == viewNonSanctionComponentsHash
                && assemblyFinality.computeComponentsHash(out) == advertised,
            "independently encoded discovery commitment"
        );
    }

    function _viewRecordAndArchiveSanction(StreamFinalityComponentExpectation[] memory independent)
        private
    {
        ViewSanctionRequest.Request memory request;
        request.nonSanctionComponents = independent;
        request.manifest = viewFinalityManifest;
        request.terms.scopeType = uint8(StreamFinalityScopeType.VIEW);
        request.terms.collectionId = fullPolicyViewScope.collectionId;
        request.terms.tokenId = fullPolicyViewScope.tokenId;
        request.terms.scopeId = fullPolicyViewScope.scopeId;
        request.statement =
            "I approve this exact adopted VIEW, supplied reference observations and complete preservation records for this fixture's scoped finality ceremony.";
        request.signingToolName = "Actual VIEW Artist Safe fixture";
        request.signingToolVersion = "1";
        ViewSanctionRequest.Prepared memory prepared =
            assemblyArtists.prepareArtistSanction(request);
        request.terms.sanctionSubjectHash = keccak256(abi.encode(prepared.subject));
        request.terms.statementHash = keccak256(prepared.ceremony);
        _viewAssertPreparedSanction(prepared, request.terms.sanctionSubjectHash);
        require(
            keccak256(abi.encode(assemblyArtists.prepareArtistSanction(request)))
                == keccak256(abi.encode(prepared)),
            "acyclic actual VIEW sanction preparation"
        );
        ViewAuthorization.Authorization memory authorization = _assemblyAuthorization(false);
        IStreamArtistIdentityOwner identity = IStreamArtistIdentityOwner(assemblySuite.owners[2]);
        require(
            !identity.nonceUsed(assemblyArtistId, authorization.nonce), "fresh original op12 nonce"
        );
        bytes32 digest = assemblyArtists.sanctionDigest(request.terms, authorization);
        authorization.signature = _assemblyArtistProof(digest);
        viewSanctionRecord = assemblyArtists.recordArtistSanction(request, authorization);
        ViewSanction.Record memory saved = assemblyArtists.sanctionRecord(viewSanctionRecord);
        (, uint64 generation, bytes32 artistId,, bytes32 bindingHash) =
            assemblyArtists.collectionArtistState(1);
        require(
            viewSanctionRecord != 0 && saved.recordHash == viewSanctionRecord
                && saved.artistId == assemblyArtistId && saved.artistId == artistId
                && saved.signer == address(assemblyArtist) && saved.authorityClass == 1
                && saved.bindingGeneration == generation && saved.bindingHash == bindingHash
                && saved.nonce == authorization.nonce && saved.deadline == authorization.time
                && saved.signedAt != 0 && saved.digest == digest
                && identity.nonceUsed(assemblyArtistId, authorization.nonce)
                && keccak256(abi.encode(saved.terms)) == keccak256(abi.encode(request.terms)),
            "actual original Safe signature, nonce and immutable VIEW sanction admission"
        );
        require(
            viewSanctionRecord == _viewPermanentSanctionHash(saved),
            "original fourteen-field sanction preimage"
        );
        (bool valid, bytes32 record, address signer, uint8 authorityClass) = assemblyArtists.verifySanctionForSubject(
            uint8(StreamFinalityScopeType.VIEW),
            1,
            0,
            fullPolicyViewScope.scopeId,
            request.terms.sanctionSubjectHash
        );
        require(
            valid && record == viewSanctionRecord && signer == address(assemblyArtist)
                && authorityClass == 1,
            "actual exact VIEW sanction verification"
        );
        _viewArchiveSanction(saved, prepared.ceremony, authorization.signature);
    }

    function _viewAssertPreparedSanction(ViewSanctionRequest.Prepared memory p, bytes32 subjectHash)
        private
        view
    {
        ViewSanction.Subject memory s = p.subject;
        StreamFinalityManifestRef memory m = viewFinalityManifest;
        require(
            s.domain == keccak256("6529STREAM_ARTIST_SANCTION_SUBJECT_V1")
                && s.chainId == block.chainid && s.core == address(assemblyCore)
                && s.finalityRegistry == address(assemblyFinality)
                && s.scopeType == uint8(StreamFinalityScopeType.VIEW) && s.collectionId == 1
                && s.tokenId == 0 && s.scopeId == fullPolicyViewScope.scopeId
                && s.coreFactsHash
                    == assemblyFinality.computeScopedCoreFactsHash(fullPolicyViewScope)
                && s.nonSanctionComponentsHash == viewNonSanctionComponentsHash
                && s.manifestURIHash == m.uriHash && s.manifestContentHash == m.contentHash
                && s.manifestSchemaId == m.schemaId
                && s.manifestCanonicalizationHash == m.canonicalizationHash
                && subjectHash
                    == assemblyFinality.computeSanctionSubjectHash(
                        fullPolicyViewScope, s.coreFactsHash, viewNonSanctionComponentsHash, m
                    ) && p.ceremony.length != 0 && p.reviewFactsHash != 0
                && p.scopeInputsHash == _viewInputsHash(),
            "complete original subject and actual VIEW review/input commitments"
        );
    }

    function _viewPermanentSanctionHash(ViewSanction.Record memory r)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_SANCTION_RECORD_V1"),
                    block.chainid,
                    address(assemblyArtists),
                    r.artistId,
                    r.signer,
                    r.authorityClass,
                    r.terms.scopeType
                ),
                abi.encode(
                    r.terms.collectionId,
                    r.terms.tokenId,
                    r.terms.scopeId,
                    r.terms.sanctionSubjectHash,
                    r.terms.statementHash,
                    r.nonce,
                    r.signedAt
                )
            )
        );
    }

    function _viewArchiveSanction(
        ViewSanction.Record memory r,
        bytes memory ceremony,
        bytes memory signature
    ) private {
        bytes32 schema = keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1");
        bytes32 canon = keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1");
        bytes memory raw = assemblyArtists.sanctionArchiveBytes(viewSanctionRecord);
        bytes memory expected = abi.encode(
            schema,
            uint16(1),
            block.chainid,
            address(assemblyArtists),
            address(assemblyCore),
            address(assemblyFinality),
            r,
            ceremony,
            signature
        );
        IStreamArtistSanctionArchiveFacts.Facts memory f =
            assemblyArtists.sanctionArchiveFacts(viewSanctionRecord);
        require(
            raw.length == expected.length && keccak256(raw) == keccak256(expected)
                && f.sanctionRecordHash == viewSanctionRecord && f.artistId == assemblyArtistId
                && f.schemaId == schema && f.canonicalizationId == canon
                && f.contentHash == keccak256(raw) && f.byteLength == raw.length,
            "exact original sanction archive including actual signature and ceremony bytes"
        );
        (bytes32 artifact, bytes32 completion) = _ocCover(raw, schema, canon);
        require(
            artifact != 0 && completion != 0, "actual complete two-family sanction archive coverage"
        );
        viewSanctionArchiveProof =
            StreamFinalitySanctionArchiveProof(viewSanctionRecord, artifact, completion);
    }

    function _viewCompleteComponents(StreamFinalityComponentExpectation[] memory independent)
        private
        returns (StreamFinalityComponentExpectation[] memory complete)
    {
        require(
            assemblyDiscovery.finalityComponentCountForScope(fullPolicyViewScope) == 10,
            "exact ten-family VIEW discovery"
        );
        complete = new StreamFinalityComponentExpectation[](10);
        uint256 retained;
        uint256 sanctions;
        for (uint256 i; i < complete.length; ++i) {
            complete[i] = assemblyDiscovery.finalityComponentAtForScope(fullPolicyViewScope, i);
            if (complete[i].componentType == StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
                ++sanctions;
                require(
                    complete[i].component == address(assemblyArtists)
                        && complete[i].codeHash == address(assemblyArtists).codehash
                        && complete[i].dataHash == viewSanctionRecord,
                    "actual original scoped sanction component"
                );
            } else {
                require(
                    retained < independent.length
                        && keccak256(abi.encode(complete[i]))
                            == keccak256(abi.encode(independent[retained++])),
                    "all nine original components survive unchanged"
                );
            }
        }
        require(sanctions == 1 && retained == 9, "exact nine-to-ten join");
        _viewRequireComponentOrder(complete);
        viewFinalityComponentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), complete));
        require(
            assemblyFinality.computeComponentsHash(complete) == viewFinalityComponentsHash
                && assemblyDiscovery.finalityDiscoveryHashForScope(fullPolicyViewScope)
                    == viewFinalityComponentsHash
                && assemblyFinality.computeNonSanctionComponentsHash(complete)
                == viewNonSanctionComponentsHash,
            "complete and independent original component preimages"
        );
    }

    function _viewRequireComponentOrder(StreamFinalityComponentExpectation[] memory rows)
        private
        pure
    {
        // These discovery families are unique, so strictly increasing type IDs also prove the
        // Registry's full seven-field lexicographic order and exclude duplicate families.
        for (uint256 i; i < rows.length; ++i) {
            require(
                rows[i].componentType != 0 && rows[i].component != address(0)
                    && rows[i].codeHash != 0 && rows[i].interfaceId != bytes4(0),
                "actual component identity"
            );
            if (i != 0) {
                require(
                    rows[i - 1].componentType < rows[i].componentType,
                    "canonical distinct component ordering"
                );
            }
        }
    }

    function _viewExecuteScopedFinality(StreamFinalityComponentExpectation[] memory complete)
        private
    {
        bytes32 coreHash = assemblyFinality.computeScopedCoreFactsHash(fullPolicyViewScope);
        viewFinalityRecord = assemblyFinality.computeFinalityRecordHash(
            fullPolicyViewScope, coreHash, viewFinalityComponentsHash, viewFinalityManifest
        );
        StreamFinalityExecutionContext memory e =
            assemblyFinality.finalityExecutionContextWithArchive(
                fullPolicyViewScope,
                complete,
                viewFinalityRecord,
                viewFinalityManifest,
                viewSanctionArchiveProof
            );
        require(
            e.scopeHash != 0 && e.oldValueHash != e.newValueHash
                && e.finalityRecordHash == viewFinalityRecord && e.coreFactsHash == coreHash
                && e.componentsHash == viewFinalityComponentsHash
                && e.inputsHash == _viewInputsHash(),
            "actual scoped archive-aware governed transition"
        );
        viewFinalityAction = _assemblyGovernanceCall(
            2,
            address(assemblyFinality),
            abi.encodeCall(
                assemblyFinality.finalizeArtworkScopeWithArchive,
                (
                    fullPolicyViewScope,
                    complete,
                    viewFinalityRecord,
                    viewFinalityManifest,
                    viewSanctionArchiveProof
                )
            ),
            e.scopeHash,
            e.oldValueHash,
            e.newValueHash
        );
        _viewAssertFinalityRecord(complete);
    }

    function _viewAssertFinalityRecord(StreamFinalityComponentExpectation[] memory complete)
        private
        view
    {
        StreamScopedFinalityRecord memory r =
            assemblyFinality.artworkScopeFinalityRecord(fullPolicyViewScope);
        StreamFinalityExecutionWitness memory w =
            assemblyFinality.finalityExecutionWitness(viewFinalityRecord);
        StreamFinalitySanctionArchiveWitness memory a =
            assemblyFinality.finalitySanctionArchiveWitness(viewFinalityRecord);
        (bytes32 roleHash, uint64 roleRevision) =
            assemblyRoles.roleMutationState(keccak256("ROLE_COLLECTION_FINALITY_ADMIN"));
        require(
            r.finalized
                && keccak256(abi.encode(r.scope)) == keccak256(abi.encode(fullPolicyViewScope))
                && r.finalityRecordHash == viewFinalityRecord
                && r.manifestContentHash == viewFinalityManifestHash
                && r.manifestURIHash == viewFinalityManifest.uriHash
                && r.componentsHash == viewFinalityComponentsHash
                && keccak256(bytes(r.finalityManifestURI)) == viewFinalityManifest.uriHash
                && r.manifestPointer == address(assemblyFinality) && r.finalizedAt != 0
                && w.actionId == viewFinalityAction && w.actionId != 0
                && w.proposer == address(assemblyRoot) && w.reasonHash != 0
                && w.roleMutationHash == roleHash && w.roleRevision == roleRevision
                && roleRevision != 0
                && keccak256(abi.encode(a.proof)) == keccak256(abi.encode(viewSanctionArchiveProof))
                && a.evidenceHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                            block.chainid,
                            address(assemblyCore),
                            address(assemblyFinality),
                            address(assemblyArtifact),
                            viewSanctionArchiveProof
                        )
                    ),
            "exact original scoped record, execution witness and immutable archive preimage"
        );
        require(
            assemblyFinality.finalityComponentCountForScope(fullPolicyViewScope) == 10
                && keccak256(
                    abi.encode(
                        assemblyFinality.finalityComponentsForScope(fullPolicyViewScope, 0, 10)
                    )
                ) == keccak256(abi.encode(complete)),
            "all ten exact original stored components"
        );
        (bool current, bytes32 record, bytes32 components) =
            assemblyFinality.verifyArtworkScopeFinality(fullPolicyViewScope);
        require(
            current && record == viewFinalityRecord && components == viewFinalityComponentsHash,
            "actual finality route remains current"
        );
        require(
            !assemblyFinality.collectionFinalityRecord(1).finalized,
            "VIEW finality does not finalize COLLECTION"
        );
    }

    function _viewInputsHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SCOPE_INPUTS_V1"),
                block.chainid,
                address(assemblyCore),
                address(assemblyMetadata),
                fullPolicyViewScope,
                viewFinalityInputs
            )
        );
    }

    function _viewAssertFinalityPreservationParity() internal view {
        _viewRequireCurrentPublication();
        assemblyViewPreservationSnapshot.requireCurrent(
            fullPolicyViewScope, assemblyViewSnapshotRecord, 1
        );
        viewReference.requireCurrent(fullPolicyViewScope, assemblyViewReferenceRecord, 1);
        require(
            keccak256(abi.encode(viewInventory.requireCurrent(fullPolicyViewScope)))
                == keccak256(abi.encode(viewRenderInventoryEvidence)),
            "actual complete VIEW inventory remains current"
        );
        require(
            keccak256(
                abi.encode(
                    viewBundle.requireCoverage(
                        fullPolicyViewScope,
                        viewRenderInventoryPlan,
                        viewRenderInventoryEvidence.inventory.renderCriticalEvidenceHash
                    )
                )
            ) == keccak256(abi.encode(viewCompleteBundle)),
            "actual full VIEW bundle remains covered"
        );
        require(
            keccak256(assemblyProvider.inputManifestBytes(fullPolicyViewScope))
                == viewFinalityManifestHash,
            "independent non-sanction VIEW manifest unchanged"
        );
        (uint256 count, bytes32 hash) =
            assemblyDiscovery.nonSanctionDiscoveryFacts(fullPolicyViewScope);
        require(
            count == 9 && hash == viewNonSanctionComponentsHash,
            "all nine independent VIEW commitments unchanged"
        );
        (StreamFinalityScopeInputs memory inputs, bytes32 schema, bytes32 canon) = assemblyProvider.requireFinalityScopeInputs(
            fullPolicyViewScope, viewFinalityManifestHash
        );
        require(
            keccak256(abi.encode(inputs)) == keccak256(abi.encode(viewFinalityInputs))
                && schema == viewFinalityManifest.schemaId
                && canon == viewFinalityManifest.canonicalizationHash,
            "same actual VIEW interpretation and original input joins"
        );
    }

    function _viewLiveSanctionCommitment() private view returns (bytes32 chain) {
        for (uint256 i; i < fullPolicyTokens.length; ++i) {
            chain = keccak256(
                abi.encode(
                    chain,
                    bytes(
                        IStreamViewAdoptionRouter(address(assemblyRouter))
                            .tokenJSONForView(fullPolicyTokens[i], fullPolicyViewScope.scopeId)
                    )
                )
            );
        }
    }

    function _viewAssertLiveSanction() private view {
        for (uint256 i; i < fullPolicyTokens.length; ++i) {
            bytes memory raw = bytes(
                IStreamViewAdoptionRouter(address(assemblyRouter))
                    .tokenJSONForView(fullPolicyTokens[i], fullPolicyViewScope.scopeId)
            );
            require(
                _viewContains(raw, bytes("artist_sanctioned"))
                    && _viewContains(
                        raw, bytes(Strings.toHexString(uint256(viewSanctionRecord), 32))
                    ) && _viewContains(raw, bytes('"sanction_authority_class":"artist"')),
                "live VIEW output includes its actual Artist sanction"
            );
            require(
                keccak256(_viewCurrentPreservationBytes(fullPolicyTokens[i], false))
                        == keccak256(viewPublicationJSON[fullPolicyTokens[i]])
                    && keccak256(_viewCurrentPreservationBytes(fullPolicyTokens[i], true))
                        == keccak256(viewPublicationHTML[fullPolicyTokens[i]]),
                "preservation JSON and HTML exclude only the later sanction layer"
            );
        }
    }

    function _viewRejectCollectionConfirmation() private {
        (uint8 state,,,,) = assemblyArtists.collectionArtistState(1);
        require(
            state == 2 && !assemblyFinality.collectionFinalityRecord(1).finalized,
            "accepted attribution with only VIEW finality"
        );
        StreamFinalityComponentState memory collectionSanction =
            IStreamArtworkFinalityComponent(address(assemblyArtists)).finalityState(1);
        require(
            !collectionSanction.frozen && collectionSanction.dataHash == 0,
            "no original COLLECTION sanction component"
        );
        bytes32 beforeState = _viewAttributionStateHash();
        bytes32 beforeSanction =
            keccak256(abi.encode(assemblyArtists.sanctionRecord(viewSanctionRecord)));
        bytes32 beforeFinality =
            keccak256(abi.encode(assemblyFinality.artworkScopeFinalityRecord(fullPolicyViewScope)));
        (bool ok, bytes memory reason) = address(assemblyArtists)
            .call(abi.encodeCall(IStreamArtistSanctionConfirmation.confirmSanctionFinalized, (1)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            ViewConfirmation.InvalidSanctionConfirmation.selector
                        )
                    ),
            "original COLLECTION-only op13 rejects VIEW finality"
        );
        require(
            _viewAttributionStateHash() == beforeState
                && keccak256(abi.encode(assemblyArtists.sanctionRecord(viewSanctionRecord)))
                    == beforeSanction
                && keccak256(
                    abi.encode(assemblyFinality.artworkScopeFinalityRecord(fullPolicyViewScope))
                ) == beforeFinality && !assemblyFinality.collectionFinalityRecord(1).finalized,
            "rejected op13 preserves accepted attribution and both original VIEW records"
        );
        _viewAssertFinalityPreservationParity();
        _viewAssertLiveSanction();
    }

    function _viewAttributionStateHash() private view returns (bytes32) {
        (
            uint8 state,
            uint64 generation,
            bytes32 artistId,
            uint8 authorityStatus,
            bytes32 bindingHash
        ) = assemblyArtists.collectionArtistState(1);
        return keccak256(abi.encode(state, generation, artistId, authorityStatus, bindingHash));
    }

    function _viewContains(bytes memory raw, bytes memory needle) private pure returns (bool) {
        if (needle.length == 0 || raw.length < needle.length) return false;
        for (uint256 i; i <= raw.length - needle.length; ++i) {
            bool same = true;
            for (uint256 j; j < needle.length; ++j) {
                if (raw[i + j] != needle[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }
}
