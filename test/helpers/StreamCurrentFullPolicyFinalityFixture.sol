// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentFullPolicyInventoryFixture.sol";
import "./StreamCurrentFullPolicyPublicationBase.sol";
import {
    StreamFinalityPolicyInputManifestSchemasV2 as PolicyCeremonySchemas
} from "../../smart-contracts/domains/finality/StreamFinalityPolicyInputManifestSchemasV2.sol";
import {
    StreamFinalityPolicyInputManifestTypesV2 as PolicyCeremony
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityPolicyInputManifestTypesV2.sol";
import {
    StreamPolicySnapshotTypesV2 as CeremonySnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as CeremonyEntropy
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as CeremonySnapshotDefinitions
} from "../../smart-contracts/domains/records/StreamPolicySnapshotDefinitionsV2.sol";
import {
    StreamPolicyReferenceDefinitionsV2 as CeremonyReferenceDefinitions
} from "../../smart-contracts/domains/records/StreamPolicyReferenceDefinitionsV2.sol";

/// @notice Original Artist Safe sanction, real archive coverage and class2 Registry finality
/// over the actual COLLECTION full-policy V2 publication graph.
/// @dev The 64m Artist / 56m Registry budgets are high-capacity fixture settings. This source
/// ceremony does not establish acceptance within the 16,777,216 transaction gas envelope.
/// Reference browser observations and archive endpoint witnesses retain their stated boundaries.
abstract contract StreamCurrentFullPolicyFinalityFixture is
    StreamCurrentFullPolicyInventoryFixture
{
    bytes32 internal assemblySanctionRecord;
    bytes32 internal assemblyFinalityRecord;
    bytes32 internal assemblyFinalityManifestHash;

    function _assemblyPrepareCeremonyDefinitions() internal {
        string[2] memory names = [
            "6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_V2",
            "6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_ABI_V2"
        ];
        for (uint256 i; i < names.length; ++i) {
            _assemblyRegisterDocument(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                PolicyCeremonySchemas.document(keccak256(bytes(names[i]))),
                assemblySchemas.RAW_BYTES()
            );
        }
        string[4] memory ids = [
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_V1",
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1",
            "6529STREAM_ARTIST_SANCTION_CEREMONY_V1",
            "6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1"
        ];
        string[4] memory files = [
            "sanction-archive-v1.schema.json",
            "sanction-archive-abi-v1.json",
            "sanction-ceremony-v1.schema.json",
            "sanction-ceremony-jcs-v1.json"
        ];
        for (uint256 i; i < ids.length; ++i) {
            _assemblyRegisterDocument(
                ids[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                bytes(assemblyVm.readFile(string.concat("docs/schemas/finality/", files[i]))),
                assemblySchemas.RAW_BYTES()
            );
        }
        // The additional registered CATALOG extends producer applicability only; the four
        // original schema/canonicalization documents and permanent archive bytes stay exact.
        bytes memory profile = bytes(
            assemblyVm.readFile("docs/schemas/finality/sanction-native-captures-v1.profile.json")
        );
        bytes32 profileId = _assemblyRegisterDocument(
            "6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            profile,
            assemblySchemas.RAW_BYTES()
        );
        IStreamSchemaDocumentFacts.DocumentFacts memory profileFacts =
            assemblySchemas.documentFacts(profileId);
        require(
            profileFacts.exists && profileFacts.kind == IStreamSchemaRegistry.DocumentKind.CATALOG
                && profileFacts.status == IStreamSchemaRegistry.DocumentStatus.ACTIVE
                && profileFacts.contentHash == keccak256(profile)
                && profileFacts.canonicalizationId == assemblySchemas.RAW_BYTES()
                && profileFacts.supersedesId == 0 && profileFacts.chunkCount == 1
                && profileFacts.totalBytes == profile.length && profileFacts.declarationHash != 0
                && keccak256(assemblySchemas.documentBytes(profileId)) == keccak256(profile)
                && keccak256(assemblyStore.readChunk(keccak256(profile))) == keccak256(profile),
            "actual registered exact composite interpretation and original bytes"
        );
        StreamFinalitySanctionSchemas.requireDefinitions(address(assemblyArtifact), 500_000);
        _assemblyGrantFinalityRole();
        _assemblyRaiseSanctionReadBudget();
    }

    function _assemblyGrantFinalityRole() private {
        bytes32 role = keccak256("ROLE_COLLECTION_FINALITY_ADMIN");
        address holder = address(assemblyRoot);
        require(!assemblyRoles.hasRole(role, holder), "fresh explicit finality role");
        (bytes32 chain, uint64 revision) = assemblyRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = assemblyRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(assemblyRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 domain = keccak256("6529STREAM_ROLE_MUTATION_STATE_V1");
        bytes32 oldHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(assemblyRoles),
                scope,
                false,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(assemblyRoles),
                scope,
                true,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        _assemblyGovernanceCall(
            1,
            address(assemblyRoles),
            abi.encodeCall(assemblyRoles.grantRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
        require(assemblyRoles.hasRole(role, holder), "actual root finality role admission");
    }

    function _assemblyRaiseSanctionReadBudget() private {
        IStreamGasParameterHost host = IStreamGasParameterHost(address(assemblyArtists));
        bytes32 id = keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(host), id
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        uint256 target = 64_000_000;
        for (uint256 i; i < 5; ++i) {
            (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
                host.gasParameterInfo(id);
            require(
                value == (uint256(2_000_000) << i) && floor == 500_000 && failure == 2
                    && revision == i + 1,
                "original sanction read budget revision"
            );
            uint256 next = value * 2;
            if (next > target) next = target;
            bytes32 oldHash = keccak256(abi.encode(domain, scope, value, floor, failure, revision));
            bytes32 newHash =
                keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1));
            _assemblyGovernanceCall(
                1,
                address(host),
                abi.encodeCall(host.raiseGasParameter, (id, next)),
                scope,
                oldHash,
                newHash
            );
            (uint256 saved, uint256 savedFloor, uint8 savedFailure, uint64 savedRevision) =
                host.gasParameterInfo(id);
            require(
                saved == next && savedFloor == floor && savedFailure == failure
                    && savedRevision == revision + 1,
                "separate governed doubling with exact readback"
            );
        }
        require(host.gasParameter(id) == target, "explicit composed callback cap, not measured gas");
    }

    function _assemblyPerformSanctionAndFinality() internal {
        require(
            assemblyCompleteBundle.bundleCoverageHash != 0,
            "complete original bundle before sanction"
        );
        StreamFinalityScope memory scope = _assemblyScope();
        bytes memory raw = assemblyProvider.inputManifestBytes(scope);
        require(raw.length != 0 && raw.length <= 8192, "actual independent complete input manifest");
        bytes32[] memory chunks = _assemblyUpload(raw);
        require(
            chunks.length == 1 && chunks[0] == keccak256(raw)
                && assemblyFinality.stageFinalityManifest(raw) == chunks[0],
            "same complete original two-store manifest"
        );
        StreamFinalityManifestRef memory manifest = StreamFinalityManifestRef(
            "https://fixtures.example.invalid/full-policy-assembly/finality-input-manifest",
            keccak256(
                bytes(
                    "https://fixtures.example.invalid/full-policy-assembly/finality-input-manifest"
                )
            ),
            chunks[0],
            keccak256("6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_V2"),
            keccak256("6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_ABI_V2")
        );
        (uint256 count, bytes32 independentHash) =
            assemblyDiscovery.nonSanctionDiscoveryFacts(scope);
        require(count == 9, "actual independent nine-family discovery");
        AssemblySanctionRequest.Request memory request;
        request.nonSanctionComponents = new StreamFinalityComponentExpectation[](count);
        for (uint256 i; i < count; ++i) {
            request.nonSanctionComponents[i] = assemblyDiscovery.nonSanctionComponentAt(scope, i);
        }
        require(
            assemblyFinality.computeComponentsHash(request.nonSanctionComponents)
                == independentHash,
            "exact discovery ordering"
        );
        _publicationAssertPolicyManifest(raw, request.nonSanctionComponents);
        assemblyFinalityManifestHash = keccak256(raw);
        request.manifest = manifest;
        request.terms.collectionId = 1;
        request.statement =
            "I approve these exact original onchain artworks, reference renders and preservation records for this fixture's finality ceremony.";
        request.signingToolName = "Full-policy actual Safe fixture";
        request.signingToolVersion = "1";
        AssemblySanctionRequest.Prepared memory prepared =
            assemblyArtists.prepareArtistSanction(request);
        request.terms.sanctionSubjectHash = StreamArtistSanctionHashes.subject(prepared.subject);
        request.terms.statementHash = keccak256(prepared.ceremony);
        AssemblySanctionRequest.Prepared memory repeated =
            assemblyArtists.prepareArtistSanction(request);
        require(
            keccak256(abi.encode(prepared)) == keccak256(abi.encode(repeated)),
            "acyclic exact original ceremony"
        );
        T.Authorization memory authorization = _assemblyAuthorization(false);
        bytes32 digest = assemblyArtists.sanctionDigest(request.terms, authorization);
        authorization.signature = _assemblyArtistProof(digest);
        assemblySanctionRecord = assemblyArtists.recordArtistSanction(request, authorization);
        AssemblySanction.Record memory saved =
            assemblyArtists.sanctionRecord(assemblySanctionRecord);
        require(
            saved.recordHash == assemblySanctionRecord && saved.artistId == assemblyArtistId
                && saved.signer == address(assemblyArtist) && saved.authorityClass == 1
                && saved.nonce == authorization.nonce && saved.digest == digest
                && keccak256(abi.encode(saved.terms)) == keccak256(abi.encode(request.terms)),
            "actual nonce-backed original Safe sanction"
        );
        raw = assemblyArtists.sanctionArchiveBytes(assemblySanctionRecord);
        (bytes32 artifact, bytes32 completion) = _ocCover(
            raw,
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1")
        );
        StreamFinalitySanctionArchiveProof memory proof =
            StreamFinalitySanctionArchiveProof(assemblySanctionRecord, artifact, completion);
        require(
            assemblyDiscovery.finalityComponentCountForScope(scope) == 10,
            "actual complete ten-family discovery"
        );
        StreamFinalityComponentExpectation[] memory components =
            new StreamFinalityComponentExpectation[](10);
        for (uint256 i; i < components.length; ++i) {
            components[i] = assemblyDiscovery.finalityComponentAtForScope(scope, i);
        }
        _publicationAssertSanctionJoin(request.nonSanctionComponents, components);
        require(
            keccak256(assemblyProvider.inputManifestBytes(scope)) == assemblyFinalityManifestHash,
            "sanction and its archive do not mutate independent manifest"
        );
        bytes32 componentHash = assemblyFinality.computeComponentsHash(components);
        require(
            componentHash == assemblyDiscovery.finalityDiscoveryHashForScope(scope),
            "complete actual discovery commitment"
        );
        bytes32 coreHash = assemblyFinality.computeCollectionCoreFactsHash(1);
        assemblyFinalityRecord =
            assemblyFinality.computeFinalityRecordHash(scope, coreHash, componentHash, manifest);
        StreamFinalityExecutionContext memory execution =
            assemblyFinality.finalityExecutionContextWithArchive(
                scope, components, assemblyFinalityRecord, manifest, proof
            );
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(assemblyFinality),
            abi.encodeCall(
                assemblyFinality.finalizeCollectionArtworkWithArchive,
                (1, components, assemblyFinalityRecord, manifest, proof)
            ),
            execution.scopeHash,
            execution.oldValueHash,
            execution.newValueHash
        );
        StreamCollectionFinalityRecord memory finalized =
            assemblyFinality.collectionFinalityRecord(1);
        StreamFinalityExecutionWitness memory witness =
            assemblyFinality.finalityExecutionWitness(assemblyFinalityRecord);
        StreamFinalitySanctionArchiveWitness memory archived =
            assemblyFinality.finalitySanctionArchiveWitness(assemblyFinalityRecord);
        require(
            finalized.finalized && finalized.finalityRecordHash == assemblyFinalityRecord
                && finalized.manifestContentHash == manifest.contentHash
                && finalized.componentsHash == componentHash && witness.actionId == action
                && witness.proposer == address(assemblyRoot) && witness.roleRevision != 0
                && archived.evidenceHash != 0
                && keccak256(abi.encode(archived.proof)) == keccak256(abi.encode(proof)),
            "actual canonical class2 finality with original sanction archive"
        );
    }

    function _publicationAssertPolicyManifest(
        bytes memory raw,
        StreamFinalityComponentExpectation[] memory independent
    ) private view {
        (
            bytes32 schema,
            bytes32 canon,
            uint256 chain,
            address originalCore,
            address originalMetadata,
            address originalRegistry,
            PolicyCeremony.Statement memory statement
        ) = abi.decode(
            raw, (bytes32, bytes32, uint256, address, address, address, PolicyCeremony.Statement)
        );
        require(
            schema == PolicyCeremonySchemas.SCHEMA_ID && canon == PolicyCeremonySchemas.CANON_ID
                && chain == block.chainid && originalCore == address(assemblyCore)
                && originalMetadata == address(assemblyMetadata)
                && originalRegistry == address(assemblyFinality)
                && keccak256(raw)
                    == keccak256(
                        abi.encode(
                            schema,
                            canon,
                            chain,
                            originalCore,
                            originalMetadata,
                            originalRegistry,
                            statement
                        )
                    ),
            "exact canonical V2 input statement"
        );
        require(
            keccak256(abi.encode(statement.scope)) == keccak256(abi.encode(_assemblyScope()))
                && statement.coreFactsHash == assemblyFinality.computeCollectionCoreFactsHash(1)
                && statement.nonSanctionComponents.length == 9
                && keccak256(abi.encode(statement.nonSanctionComponents))
                    == keccak256(abi.encode(independent)) && statement.postFreezePolicy == 1
                && statement.sanctionPolicy == 1,
            "actual scope and all nine independent component identities"
        );
        IStreamPolicyContentCheckpointV2.Plan memory checkpoint =
            publicationCheckpoint.checkpoint(publicationContent);
        CeremonySnapshot.Receipt memory snapshot =
            publicationSnapshots.currentSnapshot(statement.scope);
        require(
            statement.contentRoot == checkpoint.contentRoot && statement.contentRoot != 0
                && statement.leafCount == fullPolicyTokens.length
                && statement.contentRootSchemaId == keccak256("STREAM_POLICY_TOKEN_CONTENT_LEAF_V2")
                && snapshot.recordHash == assemblySnapshotRecord
                && statement.snapshotManifestHash == snapshot.manifestHash
                && statement.referenceRenderManifestHash
                    == publicationReferenceReceipt.observation.payloadHash
                && publicationReferenceReceipt.observation.recordHash == assemblyReferenceRecord,
            "genuine full-output root and original V2 publication bytes"
        );
        AssemblyInventory.OriginalInputs memory originals =
        assemblyRenderInventoryEvidence.originals;
        StreamFinalityScopeInputs memory inputs = StreamFinalityScopeInputs(
            assemblyOriginalContentRoot,
            assemblySnapshotRecord,
            assemblyReferenceRecord,
            originals.intentRecordHash,
            assemblyWaiverRecord,
            originals.interviewEvidenceHash,
            assemblyRightsRecord,
            assemblyWorkRecord,
            assemblyRenderInventoryEvidence.renderCriticalEvidenceHash,
            assemblyCompleteBundle.bundleCoverageHash
        );
        require(
            originals.rootRecordHash == inputs.rootRecordHash
                && originals.snapshotRecordHash == inputs.snapshotRecordHash
                && originals.referenceRenderRecordHash == inputs.referenceRenderRecordHash
                && originals.intentRecordHash == 0
                && originals.intentWaiverRecordHash == inputs.intentWaiverRecordHash
                && originals.interviewEvidenceHash != 0
                && originals.rightsStatementRecordHash == inputs.rightsStatementRecordHash
                && originals.workDescriptionRecordHash == inputs.workDescriptionRecordHash
                && assemblyCompleteBundle.inventoryPlan == assemblyRenderInventoryPlan
                && assemblyCompleteBundle.renderCriticalEvidenceHash
                    == inputs.renderCriticalEvidenceHash
                && assemblyCompleteBundle.itemCount == assemblyRenderInventoryEvidence.itemCount
                && inputs.renderCriticalEvidenceHash != 0 && inputs.bundleCoverageHash != 0
                && keccak256(abi.encode(statement.inputs)) == keccak256(abi.encode(inputs)),
            "all ten exact original input joins; explicit waivers stay explicit"
        );
        _publicationAssertCompletePolicy(statement.entropy, checkpoint);
    }

    function _publicationAssertCompletePolicy(
        PolicyCeremony.Entropy memory entropy,
        IStreamPolicyContentCheckpointV2.Plan memory checkpoint
    ) private view {
        CeremonyEntropy source = CeremonyEntropy(assemblyEntropySourceSet);
        source.requireCurrentSourceSet();
        require(
            entropy.sourceSet == assemblyEntropySourceSet && entropy.sourceSet != address(0)
                && entropy.sourceSetCodeHash == assemblyEntropySourceSet.codehash
                && entropy.sourceSetProfile == keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                && entropy.inventoryPlan == assemblyCoordinatorInventoryPlan
                && entropy.inventoryPlan == source.inventoryPlan()
                && entropy.inventoryHash == source.originalInventoryHash()
                && entropy.policyChainHash == source.originalPolicyChainHash()
                && entropy.inventoryHash == checkpoint.inventoryHash
                && entropy.policyChainHash == checkpoint.policyChainHash
                && entropy.policyCount == source.sourceCount() && entropy.policyCount != 0
                && entropy.snapshotProfileHash == CeremonySnapshotDefinitions.PROFILE_HASH
                && entropy.referenceProfileHash == CeremonyReferenceDefinitions.PROFILE_HASH,
            "actual complete immutable V2 entropy source set"
        );
        bytes memory raw = publicationSnapshots.snapshotPayload(assemblySnapshotRecord);
        (,,,,,,, CeremonySnapshot.Source memory snapshotSource) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                CeremonySnapshot.Publication,
                CeremonySnapshot.Receipt,
                CeremonySnapshot.Source
            )
        );
        require(
            keccak256(abi.encode(snapshotSource.scope))
                    == keccak256(abi.encode(source.sourceScope()))
                && snapshotSource.entropy.planId == entropy.inventoryPlan
                && snapshotSource.entropy.inventoryHash == entropy.inventoryHash
                && snapshotSource.entropy.policyChainHash == entropy.policyChainHash
                && snapshotSource.entropy.policyCount == entropy.policyCount
                && snapshotSource.entropy.allFrozen
                && snapshotSource.entropy.policies.length == entropy.policyCount,
            "original snapshot retains every full frozen source policy"
        );
        for (uint256 i; i < entropy.policyCount; ++i) {
            require(
                keccak256(abi.encode(snapshotSource.entropy.policies[i]))
                    == keccak256(abi.encode(source.sourcePolicyAt(i))),
                "complete ordered policy including original twelve-word H"
            );
        }
        for (uint256 i; i < fullPolicyTokens.length; ++i) {
            CeremonyEntropy.TokenReadiness memory readiness =
                source.tokenEntropyReadiness(fullPolicyTokens[i]);
            IStreamPolicyContentCheckpointV2.Output memory output =
                publicationCheckpoint.outputAt(publicationContent, i);
            require(
                output.leaf.tokenId == fullPolicyTokens[i] && readiness.status == 5
                    && readiness.finalized && readiness.seed != 0
                    && keccak256(abi.encode(readiness)) == keccak256(abi.encode(output.entropy)),
                "this ceremony uses actual finalized seeds; terminal alone is not finalized"
            );
        }
    }

    function _publicationAssertSanctionJoin(
        StreamFinalityComponentExpectation[] memory independent,
        StreamFinalityComponentExpectation[] memory complete
    ) private view {
        uint256 original;
        uint256 sanctions;
        for (uint256 i; i < complete.length; ++i) {
            if (complete[i].componentType == StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
                ++sanctions;
                require(
                    complete[i].component == address(assemblyArtists)
                        && complete[i].codeHash == address(assemblyArtists).codehash,
                    "original Artist sanction component"
                );
            } else {
                require(
                    original < independent.length
                        && keccak256(abi.encode(complete[i]))
                            == keccak256(abi.encode(independent[original++])),
                    "all original independent components survive sanction unchanged"
                );
            }
        }
        require(
            sanctions == 1 && original == 9 && complete.length == 10,
            "exact nine-to-ten original discovery join"
        );
    }
}
