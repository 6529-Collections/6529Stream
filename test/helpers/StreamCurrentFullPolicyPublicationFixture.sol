// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentFullPolicyPreparationFixture.sol";
import "./StreamCurrentFullPolicyPublicationBase.sol";
import {
    StreamPolicyPublicationGraphTypesV2 as CollectionGraph
} from "../../smart-contracts/interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import {
    IStreamPolicyContentCheckpointV2
} from "../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamPolicyOutputManifestV2
} from "../../smart-contracts/domains/finality/StreamPolicyOutputManifestV2.sol";
import {
    StreamPolicyOutputSchemasV2
} from "../../smart-contracts/domains/finality/StreamPolicyOutputSchemasV2.sol";
import {
    StreamPolicyContentRootSchemasV2
} from "../../smart-contracts/domains/finality/StreamPolicyContentRootSchemasV2.sol";
import {
    StreamPolicySnapshotPublicationV2
} from "../../smart-contracts/domains/metadata/StreamPolicySnapshotPublicationV2.sol";
import {
    StreamPolicySnapshotTypesV2 as PolicySnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicyContentRootPublicationV2
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    StreamOnchainContentBytes
} from "../../smart-contracts/domains/finality/StreamOnchainContentBytes.sol";

/// @notice Actual collection policy graph through covered full outputs, Artist root and snapshot.
/// @dev High configured budgets permit source composition; this fixture does not establish
/// acceptance within the production transaction envelope or execute a reference browser.
abstract contract StreamCurrentFullPolicyPublicationFixture is
    StreamCurrentFullPolicyPreparationFixture
{
    uint256 internal constant PUBLICATION_RENDER_GAS = 16000000;
    CollectionGraph.Graph internal publicationGraph;
    IStreamPolicyContentCheckpointV2 internal publicationCheckpoint;
    StreamPolicyOutputManifestV2 internal publicationOutputs;
    StreamPolicySnapshotPublicationV2 internal publicationSnapshots;
    bytes32 internal assemblyCoordinatorInventoryPlan;
    bytes32 internal assemblyOriginalContentRoot;
    bytes32 internal assemblySnapshotRecord;
    address internal assemblyEntropySourceSet;
    uint64 internal assemblyRootConsentObservedAt;
    bytes32 internal publicationSelection;
    bytes32 internal publicationContent;
    bytes32 internal publicationOutputManifest;
    mapping(uint256 => bytes) internal publicationHTML;
    mapping(uint256 => bytes) internal publicationJSON;

    function _publicationPrepareGraph() internal {
        assemblyCoordinatorInventoryPlan = _fullPolicyIndex(_collectionScope());
        assemblyEntropySourceSet = fullPolicyCollectionSources.prepareSourceSet(_collectionScope());
        IStreamFinalityEntropyPolicySourceSet(assemblyEntropySourceSet).requireCurrentSourceSet();
        publicationGraph = fullPolicyCollectionFactory.prepareGraph(_collectionScope(), 7);
        require(
            publicationGraph.preparedChildren == 7
                && publicationGraph.inventoryPlan == assemblyCoordinatorInventoryPlan
                && publicationGraph.sourceSet == assemblyEntropySourceSet,
            "actual fixed collection graph"
        );
        require(
            keccak256(abi.encode(publicationGraph))
                == keccak256(
                    abi.encode(fullPolicyCollectionFactory.requireCurrentGraph(_collectionScope()))
                ),
            "current graph identical"
        );
        publicationCheckpoint = IStreamPolicyContentCheckpointV2(publicationGraph.children[1]);
        publicationOutputs = StreamPolicyOutputManifestV2(publicationGraph.children[2]);
        publicationSnapshots = StreamPolicySnapshotPublicationV2(publicationGraph.children[3]);
    }

    function _publicationPrepareOutputDefinitions() internal {
        _assemblySetupArchiveAdmissions();
        _assemblyEnsureRawDefinition();
        string[5] memory names = [
            "STREAM_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_ABI_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_POLICY_TOKEN_CONTENT_LEAF_V2",
            "STREAM_POLICY_CONTENT_ROOT_RECORD_V2",
            "STREAM_ABI_POLICY_CONTENT_ROOT_RECORD_V2"
        ];
        for (uint256 i; i < names.length; ++i) {
            _assemblyRegisterDocument(
                names[i],
                i == 1 || i == 4
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                StreamPolicyContentRootSchemasV2.document(keccak256(bytes(names[i]))),
                assemblySchemas.RAW_BYTES()
            );
        }
        _assemblyGrantFamily(StreamRecordFamilies.SNAPSHOT, 7, address(this));
        (bool identityWriter, uint64 identityRevision) =
            assemblyMetadata.familyWriter(1, StreamRecordFamilies.IDENTITY, 7, address(this));
        // The actual description preparation already admitted this exact writer tuple.
        require(identityWriter && identityRevision != 0, "retained original identity grant");
    }

    function _publicationCurrentBytes(uint256 tokenId, bool html)
        internal
        view
        returns (bytes memory raw)
    {
        bytes memory input = html
            ? abi.encodeCall(assemblyRouter.tokenHTML, (tokenId))
            : abi.encodeCall(assemblyRouter.tokenJSON, (tokenId));
        (bool ok, bytes memory output) =
            address(assemblyRouter).staticcall{ gas: PUBLICATION_RENDER_GAS }(input);
        require(ok, "actual full STATIC output");
        raw = bytes(abi.decode(output, (string)));
        require(
            raw.length != 0 && !_publicationContains(raw, bytes("attribution_unavailable")),
            "complete attribution required"
        );
    }

    function _publicationContains(bytes memory haystack, bytes memory needle)
        private
        pure
        returns (bool)
    {
        if (needle.length > haystack.length) return false;
        for (uint256 i; i <= haystack.length - needle.length; ++i) {
            bool same = true;
            for (uint256 j; j < needle.length; ++j) {
                if (haystack[i + j] != needle[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }

    function _publicationCheckpointOutputs() internal {
        publicationSelection = fullPolicySelection.begin(_collectionScope());
        fullPolicySelection.append(publicationSelection, 2);
        require(
            fullPolicySelection.requireCurrentCheckpoint(publicationSelection).tokenCount == 2,
            "all genuine allocated tokens selected"
        );
        publicationContent = publicationCheckpoint.begin(
            publicationSelection, keccak256("current full-policy ceremony")
        );
        IStreamPolicyContentCheckpointV2.Payload[] memory payloads =
            new IStreamPolicyContentCheckpointV2.Payload[](2);
        for (uint256 i; i < 2; ++i) {
            uint256 tokenId = fullPolicyTokens[i];
            bytes memory html = _publicationCurrentBytes(tokenId, true);
            bytes memory json = _publicationCurrentBytes(tokenId, false);
            require(
                StreamOnchainContentBytes.matchesAnimation(json, html),
                "exact live full HTML in JSON"
            );
            publicationHTML[tokenId] = html;
            publicationJSON[tokenId] = json;
            payloads[i] = IStreamPolicyContentCheckpointV2.Payload(tokenId, bytes(""), html);
        }
        publicationCheckpoint.append(publicationContent, payloads);
        IStreamPolicyContentCheckpointV2.Plan memory plan =
            publicationCheckpoint.requireCurrentCheckpoint(publicationContent);
        require(
            plan.tokenCount == 2 && plan.nextIndex == 2 && plan.contentRoot != 0
                && plan.outputRoot != 0,
            "complete current policy outputs"
        );
        IStreamPolicyContentCheckpointV2.Output[] memory rows =
            new IStreamPolicyContentCheckpointV2.Output[](2);
        for (uint256 i; i < 2; ++i) {
            rows[i] = publicationCheckpoint.outputAt(publicationContent, i);
            require(
                rows[i].leaf.tokenId == fullPolicyTokens[i]
                    && rows[i].leaf.metadataHash == keccak256(publicationJSON[fullPolicyTokens[i]])
                    && rows[i].htmlHash == keccak256(publicationHTML[fullPolicyTokens[i]])
                    && rows[i].entropy.finalized && rows[i].entropy.seed != 0,
                "actual full bytes and original finalized entropy"
            );
        }
        bytes memory raw = abi.encode(
            StreamPolicyOutputSchemasV2.SCHEMA,
            block.chainid,
            address(assemblyCore),
            address(publicationCheckpoint),
            publicationContent,
            keccak256(abi.encode(plan)),
            assemblyEntropySourceSet,
            plan.inventoryHash,
            plan.policyChainHash,
            plan.scope,
            plan.contentRoot,
            plan.outputRoot,
            plan.tokenCount,
            rows
        );
        require(raw.length == 576 + 640 * plan.tokenCount, "exact distinct V2 output ABI");
        (bytes32 artifact, bytes32 coverage) =
            _ocCover(raw, StreamPolicyOutputSchemasV2.SCHEMA, StreamPolicyOutputSchemasV2.CANON);
        bytes32 outputPlan = publicationOutputs.beginManifest(
            publicationContent, artifact, coverage, assemblyArtistId
        );
        publicationOutputManifest = publicationOutputs.verifyNextOutputs(outputPlan, 2);
        require(
            publicationOutputManifest != 0
                && publicationOutputs.requireCurrentManifest(
                    publicationOutputManifest, assemblyArtistId
                )
                .manifestHash == keccak256(raw),
            "real archive covered complete output manifest"
        );
    }

    function _publicationAdoptRoot() internal {
        IStreamContentRootPublication.Publication memory publication =
            IStreamContentRootPublication.Publication(
                1, bytes32(0), publicationOutputManifest, "urn:fixture:full-policy:output-manifest"
            );
        bytes32 state =
            assemblyRouter.previewPolicyContentRootPublication(publication, address(this));
        AssemblyContent.Consent memory consent =
            AssemblyContent.Consent(1, address(assemblyRouter), keccak256("CONTENT_ROOT"), state);
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.contentConsentDigest(consent, authorization));
        assemblyRootConsentObservedAt = uint64(block.timestamp);
        bytes32 originalConsent = assemblyArtists.recordContentConsent(consent, authorization);
        assemblyOriginalContentRoot = assemblyRouter.publishVerifiedPolicyContentRoot(publication);
        IStreamContentRootPublication.Record memory record =
            assemblyRouter.contentRootRecord(assemblyOriginalContentRoot);
        IStreamPolicyContentRootPublicationV2.Binding memory binding =
            assemblyRouter.policyContentRootBinding(assemblyOriginalContentRoot);
        require(
            record.artistConsent == originalConsent && record.artistId == assemblyArtistId
                && record.publisher == address(this) && record.stateHash == state
                && assemblyRouter.collectionContentRootHead(1) == assemblyOriginalContentRoot
                && assemblyRouter.consumedArtistContentConsent(originalConsent),
            "actual one-use original op17 root"
        );
        require(
            binding.outputManifest == address(publicationOutputs)
                && binding.checkpoint == address(publicationCheckpoint)
                && binding.checkpointHash == publicationContent
                && binding.entropySourceSet == assemblyEntropySourceSet
                && binding.profileId == keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"),
            "canonical original head with additive17word binding"
        );
        publicationCheckpoint.requireCurrentCheckpoint(publicationContent);
    }

    function _publicationPublishAndLockSnapshot() internal {
        string[3] memory names = [
            "STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2",
            "STREAM_POLICY_COLLECTION_SNAPSHOT_PROFILE_V2",
            "STREAM_ABI_POLICY_COLLECTION_SNAPSHOT_V2"
        ];
        string[3] memory suffixes = ["schema", "profile", "abi"];
        for (uint256 i; i < 3; ++i) {
            _assemblyRegisterDocument(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : i == 1
                        ? IStreamSchemaRegistry.DocumentKind.CATALOG
                        : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                bytes(
                    assemblyVm.readFile(
                        string.concat(
                            "docs/schemas/preservation/policy-collection-snapshot-v2.",
                            suffixes[i],
                            ".json"
                        )
                    )
                ),
                assemblySchemas.RAW_BYTES()
            );
        }
        PolicySnapshot.Publication memory publication = PolicySnapshot.Publication(
            _collectionScope(),
            keccak256("current full-policy original snapshot"),
            bytes32(0),
            0,
            publicationOutputManifest,
            assemblyOriginalContentRoot,
            assemblyCoordinatorInventoryPlan,
            bytes32(0),
            "urn:fixture:full-policy:source-snapshot",
            uint64(block.timestamp),
            keccak256("retain actual full-policy source graph")
        );
        bytes memory canonical;
        (publication.expectedSourceHash, canonical) =
            publicationSnapshots.previewSnapshot(publication, address(this));
        _assemblyUpload(canonical);
        assemblySnapshotRecord = publicationSnapshots.publishSnapshot(publication);
        PolicySnapshot.Receipt memory receipt =
            publicationSnapshots.currentSnapshot(_collectionScope());
        require(
            receipt.recordHash == assemblySnapshotRecord && receipt.revision == 1
                && receipt.manifestHash == keccak256(canonical)
                && keccak256(publicationSnapshots.snapshotPayload(assemblySnapshotRecord))
                    == keccak256(canonical),
            "actual complete policy snapshot bytes"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            publicationSnapshots.lockTransition(_collectionScope());
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(publicationSnapshots.lockSnapshot, (_collectionScope()));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(publicationSnapshots), batch.callDatas[0], scope, oldHash, newHash
        );
        _admitAssemblyBatch(batch);
        bytes32 action = _assemblyGovernance(batch, "urn:fixture:full-policy:seal-source-snapshot");
        PolicySnapshot.Lock memory saved = publicationSnapshots.snapshotLock(_collectionScope());
        require(
            saved.recordHash == assemblySnapshotRecord && saved.revision == 1
                && saved.actionId == action,
            "actual class2 original-authority policy snapshot seal"
        );
        publicationSnapshots.requireCurrent(_collectionScope(), assemblySnapshotRecord, 1);
    }

    /// @dev The next observation producer must capture these exact bytes; old native HTML is not interchangeable.
    function _publicationExportCurrentSources() internal {
        assemblyVm.createDir("artifacts/full-policy-publication", true);
        for (uint256 i; i < 2; ++i) {
            uint256 tokenId = fullPolicyTokens[i];
            require(
                keccak256(publicationHTML[tokenId])
                        == keccak256(_publicationCurrentBytes(tokenId, true))
                    && keccak256(publicationJSON[tokenId])
                        == keccak256(_publicationCurrentBytes(tokenId, false)),
                "export remains exact current full output"
            );
            string memory prefix = string.concat(
                "artifacts/full-policy-publication/token-", Strings.toString(tokenId)
            );
            assemblyVm.writeFile(string.concat(prefix, ".html"), string(publicationHTML[tokenId]));
            assemblyVm.writeFile(string.concat(prefix, ".json"), string(publicationJSON[tokenId]));
        }
    }
}
