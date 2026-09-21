// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentAuthorityScopedPreservationPolicyBundleFixture.sol";
import "./StreamCurrentAuthorityNativeAssemblyFixture.sol";
import {
    StreamFinalityScopedPreservationPolicyInputManifestSchemasV1 as ScopedCeremonySchemas
} from "../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyInputManifestSchemasV1.sol";
import {
    StreamFinalityScopedPreservationPolicyInputManifestTypesV1 as ScopedCeremonyManifest
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityScopedPreservationPolicyInputManifestTypesV1.sol";
import {
    IStreamPreservationRendererV1 as ScopedCeremonyProducer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRendererV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as ScopedCeremonyInventory
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1 as ScopedCeremonyBundle
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    IStreamArtistSanctionArchiveFacts as ScopedCeremonyArchiveFacts
} from "../../smart-contracts/interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";
import {
    IStreamArtistDisplayFacts as ScopedCeremonyDisplay
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import {
    IStreamFinalityTokenScopeInventory as ScopedCeremonyMembership
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityTokenScopeInventory.sol";
import {
    IStreamFinalitySanctionArchive as ScopedCeremonyArchiveAPI
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionArchive.sol";

/// @notice Genuine current-Artist op12, separately archived signature/ceremony and scoped Finality.
/// @dev Complete fresh reference and bundle evidence are prerequisites. No capture is generated.
/// This local fixture retains the existing graph and governed callback budgets; those authored
/// budgets and the complete composition still need native size, gas and runtime validation.
/// All A/B/C migrations finish before sanction. Operation13 remains COLLECTION-only and is never
/// used to confirm TOKEN/RELEASE/SEASON finality. The original collection record remains absent.
abstract contract StreamCurrentAuthorityScopedPreservationPolicyFinalityFixture is
    StreamCurrentAuthorityScopedPreservationPolicyBundleFixture
{
    struct AuthorityScopedFinality {
        StreamFinalityScope scope;
        uint8 authorityEra;
        address artistRegistry;
        bytes32 authorityCapture;
        bytes32 manifestHash;
        bytes32 nonSanctionComponentsHash;
        bytes32 sanctionRecord;
        bytes32 sanctionArchiveHash;
        bytes32 sanctionArtifact;
        bytes32 sanctionCoverage;
        bytes32 finalityRecord;
        bytes32 actionId;
    }

    struct ScopedCeremonyFrame {
        StreamFinalityManifestRef manifest;
        StreamFinalityComponentExpectation[] independent;
        bytes32 independentHash;
        bytes32 coreFactsHash;
        bytes32 authorityCapture;
        bytes32 collectionRecordHash;
        bytes32 sanctionRecord;
        bytes32 liveBefore;
        bytes32 uncoveredTokenBefore;
    }

    bool private scopedCeremonyDefinitions;

    function _authorityPrepareScopedFinalityDefinitions() internal {
        require(!scopedCeremonyDefinitions, "prepare one current-era scoped ceremony");
        _authorityRequireOriginals();
        _authorityRequireRoute();
        // Reuse the real original schema/Safe/Executor setup and its existing 40m callback frame.
        // This registers extra native definitions but does not select native captures or inputs.
        _assemblyPrepareCeremonyDefinitions();
        _assemblyRegisterDocument(
            "6529STREAM_SCOPED_PRESERVATION_POLICY_FINALITY_INPUT_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            ScopedCeremonySchemas.document(ScopedCeremonySchemas.SCHEMA_ID),
            assemblySchemas.RAW_BYTES()
        );
        _assemblyRegisterDocument(
            "6529STREAM_SCOPED_PRESERVATION_POLICY_FINALITY_INPUT_MANIFEST_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            ScopedCeremonySchemas.document(ScopedCeremonySchemas.CANON_ID),
            assemblySchemas.RAW_BYTES()
        );
        scopedCeremonyDefinitions = true;
    }

    function _authorityFinalizeScopedPreservation(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        AuthorityScopedInventory memory inventoryResult,
        AuthorityScopedBundle memory bundleResult
    ) internal returns (AuthorityScopedFinality memory result) {
        require(scopedCeremonyDefinitions && authorityEra <= 2, "prepared actual A B or C ceremony");
        _scopedCeremonyScope(publication.scope);
        require(
            !assemblyFinality.artworkScopeFinalityRecord(publication.scope).finalized
                && !assemblyFinality.collectionFinalityRecord(publication.scope.collectionId)
                .finalized,
            "fresh exact scoped terminal transition"
        );
        _scopedCeremonySources(publication, referenceResult, inventoryResult, bundleResult);
        ScopedCeremonyFrame memory f;
        f.authorityCapture = keccak256(abi.encode(assemblyAuthorityResolver.currentSelection()));
        f.collectionRecordHash = keccak256(
            abi.encode(assemblyFinality.collectionFinalityRecord(publication.scope.collectionId))
        );
        f.coreFactsHash = assemblyFinality.computeScopedCoreFactsHash(publication.scope);
        f.liveBefore = _scopedCeremonyLiveHash(publication);
        if (publication.scope.scopeType == StreamFinalityScopeType.TOKEN) {
            f.uncoveredTokenBefore = keccak256(bytes(assemblyRouter.tokenJSON(2)));
        }
        (uint256 count, bytes32 independentHash) =
            assemblyDiscovery.nonSanctionDiscoveryFacts(publication.scope);
        require(count == 9, "all nine original independent scoped families");
        f.independent = new StreamFinalityComponentExpectation[](count);
        for (uint256 i; i < count; ++i) {
            f.independent[i] = assemblyDiscovery.nonSanctionComponentAt(publication.scope, i);
        }
        f.independentHash = assemblyFinality.computeComponentsHash(f.independent);
        require(f.independentHash == independentHash, "exact ordered independent discovery");
        bytes memory manifestBytes = assemblyProvider.inputManifestBytes(publication.scope);
        _scopedCeremonyManifest(
            manifestBytes, publication, referenceResult, inventoryResult, bundleResult, f
        );
        bytes32[] memory chunks = _assemblyUpload(manifestBytes);
        require(
            chunks.length == 1 && chunks[0] == keccak256(manifestBytes)
                && assemblyFinality.stageFinalityManifest(manifestBytes) == chunks[0]
                && keccak256(assemblyFinality.finalityManifestBytes(chunks[0])) == chunks[0],
            "same exact scoped manifest in the original Store and Registry"
        );
        string memory uri = "urn:fixture:current-authority:scoped-preservation-finality";
        f.manifest = StreamFinalityManifestRef(
            uri,
            keccak256(bytes(uri)),
            chunks[0],
            ScopedCeremonySchemas.SCHEMA_ID,
            ScopedCeremonySchemas.CANON_ID
        );
        bytes memory archive;
        (f.sanctionRecord, archive) = _scopedCeremonySanction(publication.scope, f);
        require(
            _scopedCeremonyLiveHash(publication) != f.liveBefore,
            "the separately readable live sanction display changes"
        );
        _scopedCeremonyParity(publication, referenceResult, inventoryResult, bundleResult, f);
        (bytes32 artifact, bytes32 completion) = _ocCover(
            archive,
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1")
        );
        StreamFinalitySanctionArchiveProof memory proof =
            StreamFinalitySanctionArchiveProof(f.sanctionRecord, artifact, completion);
        StreamFinalityComponentExpectation[] memory components =
            _scopedCeremonyComponents(publication.scope, f);
        bytes32 componentHash = assemblyFinality.computeComponentsHash(components);
        bytes32 finalityRecord = assemblyFinality.computeFinalityRecordHash(
            publication.scope, f.coreFactsHash, componentHash, f.manifest
        );
        StreamFinalityExecutionContext memory execution =
            assemblyFinality.finalityExecutionContextWithArchive(
                publication.scope, components, finalityRecord, f.manifest, proof
            );
        _scopedCeremonyRejectMissingArchive(
            publication.scope, components, finalityRecord, f.manifest
        );
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(assemblyFinality),
            abi.encodeCall(
                assemblyFinality.finalizeArtworkScopeWithArchive,
                (publication.scope, components, finalityRecord, f.manifest, proof)
            ),
            execution.scopeHash,
            execution.oldValueHash,
            execution.newValueHash
        );
        _scopedCeremonySaved(publication.scope, f, proof, componentHash, finalityRecord, action);
        _scopedCeremonyParity(publication, referenceResult, inventoryResult, bundleResult, f);
        result = AuthorityScopedFinality(
            publication.scope,
            uint8(authorityEra),
            address(assemblyArtists),
            f.authorityCapture,
            f.manifest.contentHash,
            f.independentHash,
            f.sanctionRecord,
            keccak256(archive),
            artifact,
            completion,
            finalityRecord,
            action
        );
    }

    function _scopedCeremonySanction(StreamFinalityScope memory scope, ScopedCeremonyFrame memory f)
        private
        returns (bytes32 record, bytes memory archive)
    {
        AssemblySanctionRequest.Request memory request;
        request.manifest = f.manifest;
        request.nonSanctionComponents = f.independent;
        request.terms.scopeType = uint8(scope.scopeType);
        request.terms.collectionId = scope.collectionId;
        request.terms.tokenId = scope.tokenId;
        request.terms.scopeId = scope.scopeId;
        request.statement =
            "I approve this exact scoped artwork, observed reference renders and complete preservation evidence in this local fixture.";
        request.signingToolName = "Current-authority scoped preservation Safe fixture";
        request.signingToolVersion = "1";
        AssemblySanctionRequest.Prepared memory prepared =
            assemblyArtists.prepareArtistSanction(request);
        request.terms.sanctionSubjectHash = StreamArtistSanctionHashes.subject(prepared.subject);
        request.terms.statementHash = keccak256(prepared.ceremony);
        require(
            request.terms.sanctionSubjectHash
                    == assemblyFinality.computeSanctionSubjectHash(
                        scope, f.coreFactsHash, f.independentHash, f.manifest
                    )
                && keccak256(abi.encode(prepared))
                    == keccak256(abi.encode(assemblyArtists.prepareArtistSanction(request))),
            "current Safe approves exact acyclic scoped subject and ceremony"
        );
        T.Authorization memory authorization = _assemblyAuthorization(false);
        bytes32 digest = assemblyArtists.sanctionDigest(request.terms, authorization);
        authorization.signature = _assemblyArtistProof(digest, authorization.nonce);
        record = assemblyArtists.recordArtistSanction(request, authorization);
        AssemblySanction.Record memory saved = assemblyArtists.sanctionRecord(record);
        require(
            record != 0 && saved.recordHash == record && saved.artistId == assemblyArtistId
                && saved.signer == address(assemblyArtist) && saved.authorityClass == 1
                && saved.nonce == authorization.nonce && saved.deadline == authorization.time
                && saved.digest == digest
                && keccak256(abi.encode(saved.terms)) == keccak256(abi.encode(request.terms)),
            "actual current Artist operation12 record, nonce and signature digest"
        );
        archive = assemblyArtists.sanctionArchiveBytes(record);
        bytes memory expected = abi.encode(
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
            uint16(1),
            block.chainid,
            address(assemblyArtists),
            address(assemblyCore),
            address(assemblyFinality),
            saved,
            prepared.ceremony,
            authorization.signature
        );
        ScopedCeremonyArchiveFacts.Facts memory facts = assemblyArtists.sanctionArchiveFacts(record);
        require(
            archive.length != 0 && archive.length <= 13120
                && keccak256(archive) == keccak256(expected) && facts.sanctionRecordHash == record
                && facts.artistId == assemblyArtistId
                && facts.schemaId == keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1")
                && facts.canonicalizationId
                    == keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1")
                && facts.contentHash == keccak256(archive) && facts.byteLength == archive.length,
            "complete exact original sanction record, RFC8785 ceremony and actual signature"
        );
        (bool valid, bytes32 verified, address signer, uint8 authorityClass) = assemblyArtists.verifySanctionForSubject(
            uint8(scope.scopeType),
            scope.collectionId,
            scope.tokenId,
            scope.scopeId,
            request.terms.sanctionSubjectHash
        );
        require(
            valid && verified == record && signer == saved.signer
                && authorityClass == saved.authorityClass
                && keccak256(
                    abi.encode(
                        ScopedCeremonyDisplay(address(assemblyArtists)).displaySanction(scope)
                    )
                ) == keccak256(abi.encode(saved)),
            "actual current scoped sanction public reads"
        );
    }

    function _scopedCeremonyComponents(
        StreamFinalityScope memory scope,
        ScopedCeremonyFrame memory f
    ) private view returns (StreamFinalityComponentExpectation[] memory all) {
        require(assemblyDiscovery.finalityComponentCountForScope(scope) == 10);
        all = new StreamFinalityComponentExpectation[](10);
        uint256 independentIndex;
        uint256 sanctions;
        for (uint256 i; i < all.length; ++i) {
            all[i] = assemblyDiscovery.finalityComponentAtForScope(scope, i);
            if (all[i].componentType == StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
                ++sanctions;
                require(
                    all[i].component == address(assemblyArtists)
                        && all[i].codeHash == address(assemblyArtists).codehash
                        && all[i].dataHash == f.sanctionRecord,
                    "exact current scoped sanction component"
                );
            } else {
                require(
                    independentIndex < f.independent.length
                        && keccak256(abi.encode(all[i]))
                            == keccak256(abi.encode(f.independent[independentIndex++])),
                    "every independent component retained after sanction"
                );
            }
        }
        require(
            sanctions == 1 && independentIndex == 9
                && assemblyFinality.computeComponentsHash(all)
                    == assemblyDiscovery.finalityDiscoveryHashForScope(scope)
        );
    }

    function _scopedCeremonyManifest(
        bytes memory raw,
        AuthorityScopedPublication memory p,
        AuthorityScopedReference memory r,
        AuthorityScopedInventory memory inventoryResult,
        AuthorityScopedBundle memory b,
        ScopedCeremonyFrame memory f
    ) private view {
        require(raw.length != 0 && raw.length <= 8192);
        (
            bytes32 schema,
            bytes32 canon,
            uint256 chain,
            address core,
            address metadata,
            address finality,
            ScopedCeremonyManifest.Statement memory s
        ) = abi.decode(
            raw,
            (bytes32, bytes32, uint256, address, address, address, ScopedCeremonyManifest.Statement)
        );
        require(
            schema == ScopedCeremonySchemas.SCHEMA_ID && canon == ScopedCeremonySchemas.CANON_ID
                && chain == block.chainid && core == address(assemblyCore)
                && metadata == address(assemblyMetadata) && finality == address(assemblyFinality)
                && keccak256(raw)
                    == keccak256(abi.encode(schema, canon, chain, core, metadata, finality, s)),
            "canonical original scoped finality manifest envelope"
        );
        StreamFinalityScopeInputs memory inputs = StreamFinalityScopeInputs(
            p.rootHash,
            p.snapshot.recordHash,
            r.recordHash,
            inventoryResult.evidence.inventory.originals.intentRecordHash,
            bytes32(0),
            inventoryResult.evidence.inventory.originals.interviewEvidenceHash,
            inventoryResult.evidence.inventory.originals.rightsStatementRecordHash,
            inventoryResult.evidence.inventory.originals.workDescriptionRecordHash,
            inventoryResult.evidence.inventory.renderCriticalEvidenceHash,
            b.evidence.coverage.bundleCoverageHash
        );
        require(
            keccak256(abi.encode(s.scope)) == keccak256(abi.encode(p.scope))
                && s.coreFactsHash == f.coreFactsHash && s.contentRoot == p.checkpoint.contentRoot
                && s.leafCount == p.checkpoint.tokenCount
                && s.contentRootSchemaId
                    == keccak256("STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1")
                && s.snapshotManifestHash == p.snapshot.manifestHash
                && s.referenceRenderManifestHash == r.receipt.observation.payloadHash
                && keccak256(abi.encode(s.inputs)) == keccak256(abi.encode(inputs))
                && keccak256(abi.encode(s.nonSanctionComponents))
                    == keccak256(abi.encode(f.independent)) && s.entropyPolicy == 1
                && s.postFreezePolicy == 1 && s.sanctionPolicy == 1,
            "exact actual scoped root, publications, inventory, archive and nine families"
        );
    }

    function _scopedCeremonySources(
        AuthorityScopedPublication memory p,
        AuthorityScopedReference memory r,
        AuthorityScopedInventory memory inventoryResult,
        AuthorityScopedBundle memory b
    ) private view {
        require(
            r.lockAction != 0 && r.recordHash != 0 && inventoryResult.planId != 0
                && inventoryResult.host == p.graph.children[5] && b.host == p.graph.children[6]
                && b.evidence.coverage.bundleCoverageHash != 0
                && b.evidence.coverage.inventoryPlan == inventoryResult.planId
                && b.evidence.coverage.renderCriticalEvidenceHash
                    == inventoryResult.evidence.inventory.renderCriticalEvidenceHash,
            "exact actually locked reference and complete current scoped bundle"
        );
        require(
            keccak256(
                abi.encode(ScopedCeremonyInventory(inventoryResult.host).requireCurrent(p.scope))
            ) == keccak256(abi.encode(inventoryResult.evidence)),
            "complete scoped inventory remains current"
        );
        require(
            keccak256(
                abi.encode(
                    ScopedCeremonyBundle(b.host).requireFullCurrentCoverage(inventoryResult.planId)
                )
            ) == keccak256(abi.encode(b.evidence)),
            "complete archived occurrence diagnostic remains current"
        );
        for (uint256 i; i < p.payloads.length; ++i) {
            uint256 token = p.payloads[i].tokenId;
            address producer = _authorityPreservationProducer(token);
            require(
                producer == p.outputRows[i].preservation.producer
                    && keccak256(
                            bytes(ScopedCeremonyProducer(producer).preservationTokenJSON(token))
                        ) == p.outputRows[i].leaf.metadataHash
                    && keccak256(
                        bytes(ScopedCeremonyProducer(producer).preservationTokenHTML(token))
                    ) == p.outputRows[i].htmlHash,
                "all original preservation bytes retain exact non-sanction facts"
            );
        }
    }

    function _scopedCeremonyParity(
        AuthorityScopedPublication memory p,
        AuthorityScopedReference memory r,
        AuthorityScopedInventory memory inventoryResult,
        AuthorityScopedBundle memory b,
        ScopedCeremonyFrame memory f
    ) private view {
        _scopedCeremonySources(p, r, inventoryResult, b);
        _scopedCeremonyLiveSanction(p, f);
        (uint256 count, bytes32 independentHash) =
            assemblyDiscovery.nonSanctionDiscoveryFacts(p.scope);
        require(
            count == 9 && independentHash == f.independentHash
                && keccak256(assemblyProvider.inputManifestBytes(p.scope)) == f.manifest.contentHash
                && keccak256(abi.encode(assemblyAuthorityResolver.currentSelection()))
                    == f.authorityCapture
                && keccak256(
                    abi.encode(assemblyFinality.collectionFinalityRecord(p.scope.collectionId))
                ) == f.collectionRecordHash,
            "sanction and exact scoped Finality preserve original independent evidence and collection boundary"
        );
    }

    function _scopedCeremonyRejectMissingArchive(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] memory components,
        bytes32 record,
        StreamFinalityManifestRef memory manifest
    ) private view {
        (bool accepted, bytes memory reason) = address(assemblyFinality)
            .staticcall(
                abi.encodeCall(
                    assemblyFinality.finalityExecutionContextWithArchive,
                    (
                        scope,
                        components,
                        record,
                        manifest,
                        StreamFinalitySanctionArchiveProof(0, 0, 0)
                    )
                )
            );
        require(
            !accepted
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            ScopedCeremonyArchiveAPI.FinalitySanctionArchiveInvalid.selector
                        )
                    ) && !assemblyFinality.artworkScopeFinalityRecord(scope).finalized,
            "missing actual sanction archive cannot prepare scoped execution"
        );
    }

    function _scopedCeremonySaved(
        StreamFinalityScope memory scope,
        ScopedCeremonyFrame memory f,
        StreamFinalitySanctionArchiveProof memory proof,
        bytes32 componentHash,
        bytes32 record,
        bytes32 action
    ) private view {
        StreamScopedFinalityRecord memory saved = assemblyFinality.artworkScopeFinalityRecord(scope);
        StreamFinalityExecutionWitness memory witness =
            assemblyFinality.finalityExecutionWitness(record);
        StreamFinalitySanctionArchiveWitness memory archived =
            assemblyFinality.finalitySanctionArchiveWitness(record);
        require(
            saved.finalized && keccak256(abi.encode(saved.scope)) == keccak256(abi.encode(scope))
                && saved.finalityRecordHash == record
                && saved.manifestContentHash == f.manifest.contentHash
                && saved.manifestURIHash == f.manifest.uriHash
                && saved.componentsHash == componentHash
                && keccak256(bytes(saved.finalityManifestURI)) == f.manifest.uriHash
                && saved.manifestPointer.code.length != 0 && saved.finalizedAt != 0
                && witness.actionId == action && action != 0
                && witness.proposer == address(assemblyRoot) && witness.roleRevision != 0
                && archived.evidenceHash != 0
                && keccak256(abi.encode(archived.proof)) == keccak256(abi.encode(proof))
                && assemblyFinality.artworkFreezeMode(scope) == StreamArtworkFreezeMode.EXACT,
            "actual exact scoped class2 finality, original archive proof and governance witness"
        );
        (bool current, bytes32 observedRecord, bytes32 observedComponents) =
            assemblyFinality.verifyArtworkScopeFinality(scope);
        require(
            current && observedRecord == record && observedComponents == componentHash,
            "original Registry current scoped diagnostic agrees"
        );
    }

    function _scopedCeremonyLiveHash(AuthorityScopedPublication memory p)
        private
        view
        returns (bytes32 chain)
    {
        for (uint256 i; i < p.payloads.length; ++i) {
            chain = keccak256(
                abi.encode(chain, bytes(assemblyRouter.tokenJSON(p.payloads[i].tokenId)))
            );
        }
    }

    function _scopedCeremonyLiveSanction(
        AuthorityScopedPublication memory p,
        ScopedCeremonyFrame memory f
    ) private view {
        for (uint256 i; i < p.payloads.length; ++i) {
            uint256 token = p.payloads[i].tokenId;
            if (p.scope.scopeType != StreamFinalityScopeType.TOKEN) {
                ScopedCeremonyMembership membership =
                    ScopedCeremonyMembership(address(assemblyMembership));
                bool found;
                uint256 count = membership.tokenScopeCount(token);
                require(count <= 64, "bounded actual reverse membership roster");
                for (uint256 j; j < count; ++j) {
                    (StreamFinalityScope memory actual, bool complete) =
                        membership.tokenScopeAt(token, j);
                    if (complete && keccak256(abi.encode(actual)) == keccak256(abi.encode(p.scope)))
                    {
                        found = true;
                    }
                }
                require(
                    found && assemblyMembership.scopeCoversToken(p.scope, token),
                    "actual complete scope membership selects the live sanction"
                );
            }
            bytes memory live = bytes(assemblyRouter.tokenJSON(token));
            require(
                _scopedCeremonyContains(live, bytes("artist_sanctioned"))
                    && _scopedCeremonyContains(
                        live, bytes(Strings.toHexString(uint256(f.sanctionRecord), 32))
                    )
                    && _scopedCeremonyContains(
                        live, bytes("\"sanction_authority_class\":\"artist\"")
                    ),
                "covered live token retains the actual current Artist sanction"
            );
        }
        if (p.scope.scopeType == StreamFinalityScopeType.TOKEN) {
            require(
                keccak256(bytes(assemblyRouter.tokenJSON(2))) == f.uncoveredTokenBefore,
                "exact token sanction does not relabel the uncovered token"
            );
        }
    }

    function _scopedCeremonyContains(bytes memory raw, bytes memory needle)
        private
        pure
        returns (bool)
    {
        if (needle.length == 0 || needle.length > raw.length) return false;
        for (uint256 i; i + needle.length <= raw.length; ++i) {
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

    function _scopedCeremonyScope(StreamFinalityScope memory scope) private pure {
        require(
            scope.collectionId != 0
                && ((scope.scopeType == StreamFinalityScopeType.TOKEN
                        && scope.tokenId != 0
                        && scope.scopeId == 0)
                    || ((scope.scopeType == StreamFinalityScopeType.RELEASE
                            || scope.scopeType == StreamFinalityScopeType.SEASON)
                        && scope.tokenId == 0
                        && scope.scopeId != 0)),
            "only exact TOKEN RELEASE SEASON finality; operation13 remains COLLECTION-only"
        );
    }
}
