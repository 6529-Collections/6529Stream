// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicySealingFixture
} from "../helpers/StreamCurrentAuthorityScopedPreservationPolicySealingFixture.sol";
import {
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamConservationRecordTypes as PreservationScopedConservation
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    IStreamPreservationRecords as PreservationScopedRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1 as PreservationScopedMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamFinalityPreservationFactoryProfileSourcesV1 as PreservationScopedSources
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityPreservationFactoryProfileSourcesV1.sol";
import {
    IStreamFinalityProfileSources as PreservationScopedProfiles
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as PreservationScopedFamily
} from "../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    IStreamPreservationRegistryV1 as PreservationScopedRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as PreservationScopedCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as PreservationScopedSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as PreservationScopedSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as PreservationScopedDefinitions
} from "../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV2 as PreservationScopedRootDefinitions
} from "../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentRootSchemasV2.sol";

/// @notice Actual scoped preservation V2 publication and original records across A/B/C imports.
/// @dev The real Safe, Core, Artist, governed Registry admission and publication kernels execute
/// when these source-authored tests run. Admission analysis/goldens remain explicit fixture evidence,
/// not independent STATIC conformance. These cases publish no browser/reference evidence and do
/// not complete source inventory, whole-bundle coverage or Finality. Runtime/gas/size remain pending.
contract StreamCurrentAuthorityScopedPreservationPolicyTest is
    StreamCurrentAuthorityScopedPreservationPolicySealingFixture
{
    function testActualTokenPreservationV2RootAndScopedRecordsThroughBAndC() public {
        _throughSuccessors(StreamFinalityScopeType.TOKEN);
    }

    function testActualReleasePreservationV2RootAndScopedRecordsThroughBAndC() public {
        _throughSuccessors(StreamFinalityScopeType.RELEASE);
    }

    function testActualSeasonPreservationV2RootAndScopedRecordsThroughBAndC() public {
        _throughSuccessors(StreamFinalityScopeType.SEASON);
    }

    function _throughSuccessors(StreamFinalityScopeType kind) private {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _authorityRecoverOriginal();
        _assemblyPrepareDescriptionDefinitions();
        // Retain the original independently sealed collection-level history as well as the
        // new scope's own unsealed record lineage. This reuses every original invariant.
        _assemblySelectDescriptionsAndWaiver();
        AuthorityScopedPublication memory publication =
            _authorityPublishScopedPreservationPolicy(kind);
        _authorityCaptureOriginalPreservation();
        bytes32 presentation = authorityOriginalPresentationHash;
        bytes32 originalRoot = assemblyRouter.scopedContentRootHead(publication.scope);
        require(originalRoot != 0, "actual scoped root published under A");
        bytes32 originalSource =
            keccak256(abi.encode(assemblyRouter.scopedContentRootRecord(originalRoot)));
        require(assemblyRouter.collectionContentRootHead(1) == 0, "STATIC keeps native head empty");
        _assertV2Publication(publication);
        _assertCurrentArtistAndAdmission(publication);
        bytes32 originalPublication = _savedPublicationHash(publication);
        bytes32 sourceConfiguration =
            PreservationScopedSources(address(assemblyProvider)).finalitySourceConfigurationHash();
        require(sourceConfiguration != 0, "actual immutable four-argument provider catalogue");
        bytes32 originalSources = _assertSources(publication, sourceConfiguration);

        _authorityMigrateNext();
        _assertCurrentArtistAndAdmission(publication);
        require(_assertSources(publication, sourceConfiguration) == originalSources);
        require(_savedPublicationHash(publication) == originalPublication);
        ScopedRecordHeads memory expected;
        expected.contentTag = keccak256("B original scoped op24 records");
        ScopedRecordSet memory b = _publishScopedRecords(publication.scope, expected);
        AuthorityScopedRights memory rightsResult = _authorityPublishScopedRights(publication.scope);
        bytes32 originalRights = _savedMetadataRecordHash(rightsResult.recordHash);
        require(
            authorityEra == 1 && b.workPublication.receipt.recordIndex != 0,
            "B WORK appends after actual original collection record"
        );
        require(b.workSelection.revision == 1 && b.intentSelection.revision == 1);
        bytes32 bWork = _savedMetadataRecordHash(b.workPublication.recordHash);
        bytes32 bInterview = _savedMetadataRecordHash(b.interviewPublication.recordHash);
        bytes32 bIntent = _savedMetadataRecordHash(b.intentPublication.recordHash);
        bytes32 bWorkSelection = keccak256(abi.encode(b.workSelection));
        bytes32 bIntentSelection = keccak256(abi.encode(b.intentSelection));
        _authorityRequireOriginals();
        _authorityRequireRoute();

        _authorityMigrateNext();
        require(authorityEra == 2, "actual C completes all seven owner imports");
        _assertCurrentArtistAndAdmission(publication);
        require(_assertSources(publication, sourceConfiguration) == originalSources);
        require(_savedPublicationHash(publication) == originalPublication);
        require(_savedMetadataRecordHash(b.workPublication.recordHash) == bWork);
        require(_savedMetadataRecordHash(b.interviewPublication.recordHash) == bInterview);
        require(_savedMetadataRecordHash(b.intentPublication.recordHash) == bIntent);
        require(_savedMetadataRecordHash(rightsResult.recordHash) == originalRights);
        require(
            keccak256(
                abi.encode(
                    assemblyRights.requireCurrent(
                        1, rightsResult.subject, rightsResult.recordHash, 1
                    )
                )
            ) == keccak256(abi.encode(rightsResult.selection)),
            "original RIGHTS instance and scope survive C"
        );
        require(
            keccak256(abi.encode(assemblyWork.workSelectionAt(1, b.subject, 1))) == bWorkSelection,
            "same original WORK instance preserves B selection"
        );
        require(
            keccak256(
                abi.encode(
                    assemblyConservation.conservationSelectionAt(
                        1,
                        b.subject,
                        PreservationScopedConservation.StatementOrigin.ARTIST_INTENT,
                        1
                    )
                )
            ) == bIntentSelection,
            "same original Conservation instance preserves B selection"
        );
        expected.workHead = b.workPublication.recordHash;
        expected.workRevision = 1;
        expected.intentHead = b.intentPublication.recordHash;
        expected.intentRevision = 1;
        expected.interviewPredecessor = b.interviewPublication.recordHash;
        expected.contentTag = keccak256("C successor scoped op24 records");
        ScopedRecordSet memory c = _publishScopedRecords(publication.scope, expected);
        require(c.workSelection.revision == 2 && c.intentSelection.revision == 2);
        require(c.workPublication.recordHash != b.workPublication.recordHash);
        require(c.intentPublication.recordHash != b.intentPublication.recordHash);
        require(c.interviewPublication.recordHash != b.interviewPublication.recordHash);
        require(c.workPublication.receipt.recordIndex == b.workPublication.receipt.recordIndex + 1);
        require(
            c.intentPublication.receipt.recordIndex == b.intentPublication.receipt.recordIndex + 1
        );
        require(_savedMetadataRecordHash(b.workPublication.recordHash) == bWork);
        require(_savedMetadataRecordHash(b.interviewPublication.recordHash) == bInterview);
        require(_savedMetadataRecordHash(b.intentPublication.recordHash) == bIntent);
        require(assemblyRouter.scopedContentRootHead(publication.scope) == originalRoot);
        require(
            keccak256(abi.encode(assemblyRouter.scopedContentRootRecord(originalRoot)))
                == originalSource
        );
        require(keccak256(abi.encode(assemblyRouter.artistPresentation(1))) == presentation);
        require(assemblyRouter.collectionContentRootHead(1) == 0);
        AuthorityScopedSeals memory seals = _authoritySealScopedRecords(c, rightsResult);
        require(
            seals.work.revision == 2 && seals.rights.revision == 1 && seals.intent.revision == 2
        );
        require(_savedPublicationHash(publication) == originalPublication);
        require(_assertSources(publication, sourceConfiguration) == originalSources);
        _assertCurrentArtistAndAdmission(publication);
        _authorityRequireOriginals();
        _authorityRequireRoute();
    }

    function _assertV2Publication(AuthorityScopedPublication memory p) private view {
        require(p.binding.profileId == PreservationScopedRootDefinitions.PROFILE);
        require(p.binding.preservationOutputProfile == PreservationScopedFamily.FAMILY_PROFILE);
        require(p.checkpoint.preservationProfile == PreservationScopedFamily.FAMILY_PROFILE);
        require(p.output.preservationProfile == PreservationScopedFamily.FAMILY_PROFILE);
        require(p.outputRows.length == p.membership.tokenCount && p.outputRows.length != 0);
        require(abi.encode(p.binding).length == 800, "full original preservation root binding");
        require(p.binding.snapshotProfileHash == PreservationScopedDefinitions.PROFILE_HASH);
        require(p.snapshot.schemaHash == PreservationScopedDefinitions.SCHEMA_HASH);
        require(p.snapshot.profileHash == PreservationScopedDefinitions.PROFILE_HASH);
        require(p.snapshot.canonicalizationHash == PreservationScopedDefinitions.CANON_HASH);
        (
            bytes32 domain,
            uint256 chain,
            address snapshotHost,,,,,
            PreservationScopedSnapshotTypes.Source memory source
        ) = abi.decode(
            p.snapshotPayload,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                PreservationScopedSnapshotTypes.Publication,
                PreservationScopedSnapshotTypes.Receipt,
                PreservationScopedSnapshotTypes.Source
            )
        );
        require(domain == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2"));
        require(chain == block.chainid && snapshotHost == p.graph.children[3]);
        require(keccak256(abi.encode(source.scope)) == keccak256(abi.encode(p.scope)));
        require(keccak256(abi.encode(source.content)) == keccak256(abi.encode(p.checkpoint)));
        require(keccak256(abi.encode(source.outputs)) == keccak256(abi.encode(p.output)));
        require(source.content.preservationProfile == PreservationScopedFamily.FAMILY_PROFILE);
        require(source.outputs.preservationProfile == PreservationScopedFamily.FAMILY_PROFILE);
        require(assemblyRouter.consumedArtistContentConsent(p.consentRecord));
        require(
            p.rootHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        address(assemblyRouter),
                        address(assemblyCore),
                        p.root,
                        p.binding,
                        p.aggregate
                    )
                ),
            "actual V2 record domain preserves original op17 history"
        );
    }

    function _assertCurrentArtistAndAdmission(AuthorityScopedPublication memory p) private view {
        require(
            keccak256(abi.encode(assemblyStaticArtistSource.currentSuite()))
                == keccak256(abi.encode(assemblySuite)),
            "finite lineage source follows the actual selected complete suite"
        );
        require(address(assemblyArtists) == authorityRegistries[authorityEra]);
        for (uint256 i; i < p.outputRows.length; ++i) {
            PreservationScopedCheckpoint.Output memory row = p.outputRows[i];
            address producer = _authorityPreservationProducer(row.leaf.tokenId);
            require(row.preservation.producer == producer);
            require(
                row.preservation.profile == PreservationScopedFamily.CURRENT_ARTIST_PROFILE,
                "actual current-Artist marker is never relabeled as the family"
            );
            require(row.preservation.producerCodeHash == producer.codehash);
            PreservationScopedRegistry registry =
                PreservationScopedRegistry(row.preservationAdmission.registry);
            (
                PreservationScopedRegistry.ProducerBinding memory binding,
                PreservationScopedRegistry.Admission memory admission
            ) = registry.requirePreservation(
                row.preservationAdmission.versionKey,
                producer,
                PreservationScopedFamily.CURRENT_ARTIST_PROFILE
            );
            require(abi.encode(binding).length == 288 && abi.encode(admission).length == 224);
            require(keccak256(abi.encode(binding)) == keccak256(abi.encode(row.preservation)));
            require(
                keccak256(abi.encode(admission)) == keccak256(abi.encode(row.preservationAdmission))
            );
            require(
                admission.registry == address(assemblyStaticProducts.versions)
                    && admission.registryCodeHash == address(registry).codehash
                    && admission.versionKey == assemblyStaticVersion
            );
            bytes32 key = registry.preservationKey(admission.versionKey, producer, binding.profile);
            PreservationScopedRegistry.PreservationRecord memory registered =
                registry.preservationRecord(key);
            require(
                registered.actionId != 0
                    && registered.registrationHash == admission.registrationHash
            );
            require(
                registered.readSetHash == admission.readSetHash
                    && registered.analysisHash == admission.analysisHash
                    && registered.goldenHash == admission.goldenHash
            );
        }
    }

    function _assertSources(AuthorityScopedPublication memory p, bytes32 expected)
        private
        view
        returns (bytes32)
    {
        PreservationScopedSources provider = PreservationScopedSources(address(assemblyProvider));
        require(provider.finalitySourceConfigurationHash() == expected);
        require(
            provider.preservationFactorySourceProfile()
                == keccak256("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_PROFILE_SOURCES_V1")
        );
        PreservationScopedProfiles.Sources memory sources =
            provider.finalitySourcesForScope(p.scope);
        require(keccak256(abi.encode(sources.scope)) == keccak256(abi.encode(p.scope)));
        require(sources.profile.profileHash == PreservationScopedDefinitions.PROFILE_HASH);
        require(
            sources.profile.snapshots == p.graph.children[3]
                && sources.profile.snapshotsCodeHash == p.graph.codeHashes[3]
        );
        require(
            sources.profile.referenceRender == p.graph.children[4]
                && sources.profile.referenceRenderCodeHash == p.graph.codeHashes[4]
        );
        require(sources.profile.configurationHash != 0);
        require(
            assemblyRouter.collectionContentRootHead(1) == 0,
            "scoped preservation never fabricates a collection root"
        );
        return keccak256(abi.encode(sources));
    }

    function _savedPublicationHash(AuthorityScopedPublication memory p)
        private
        view
        returns (bytes32)
    {
        PreservationScopedSnapshot snapshot = PreservationScopedSnapshot(p.graph.children[3]);
        (
            PreservationScopedSnapshotTypes.Publication memory publication,
            PreservationScopedSnapshotTypes.Receipt memory receipt
        ) = snapshot.snapshotRecord(p.snapshot.recordHash);
        require(snapshot.snapshotCount(p.scope) == 1);
        require(snapshot.snapshotAt(p.scope, 0) == p.snapshot.recordHash);
        require(assemblyRouter.scopedContentRootHead(p.scope) == p.rootHash);
        return keccak256(
            abi.encode(
                assemblyRouter.scopedContentRootRecord(p.rootHash),
                assemblyRouter.scopedPreservationPolicyContentRootBinding(p.rootHash),
                assemblyRouter.scopedContentRootAggregate(p.scope.collectionId),
                publication,
                receipt,
                snapshot.snapshotPayload(p.snapshot.recordHash)
            )
        );
    }

    function _savedMetadataRecordHash(bytes32 recordHash) private view returns (bytes32) {
        (
            PreservationScopedRecords.CollectionRecord memory record,
            PreservationScopedMetadata.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        (, bytes memory payload) = assemblyMetadata.recordPayload(recordHash);
        return keccak256(abi.encode(record, receipt, payload));
    }
}
