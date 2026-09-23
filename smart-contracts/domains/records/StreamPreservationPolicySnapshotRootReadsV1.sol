// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamMetadataServingFacts
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    IStreamContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV1 as RootSchemas
} from "../finality/StreamPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as ProducerProfiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV2 as RootSchemasV2
} from "../finality/StreamPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as OutputSchemasV2
} from "../finality/StreamPreservationPolicyOutputSchemasV2.sol";

/// @notice Fixed canonical Router root and retained preservation binding joins.
library StreamPreservationPolicySnapshotRootReadsV1 {
    function current(
        S.Dependencies memory d,
        S.Publication memory p,
        IStreamMetadataServingFacts.ArtistPresentation memory artist,
        Outputs.Manifest memory outputs,
        bytes32 inventoryHash,
        bytes32 policyChainHash,
        bytes32 family
    ) public view returns (Root.Record memory root, PreservationRoot.Binding memory rootBinding) {
        bool v2 = _version2(family);
        if (p.contentRootRecord == 0) revert S.InvalidPolicySnapshot();
        bytes memory raw = _read(
            d,
            4,
            abi.encodeCall(Root.collectionContentRootHead, (p.scope.collectionId)),
            32,
            d.readGas
        );
        if (abi.decode(raw, (bytes32)) != p.contentRootRecord) revert S.InvalidPolicySnapshot();
        raw = Reads.dynamicRead(
            d.targets[4],
            abi.encodeCall(Root.contentRootRecord, (p.contentRootRecord)),
            4096,
            d.readGas
        );
        root = abi.decode(raw, (Root.Record));
        _canonical(raw, abi.encode(root));
        raw = _read(
            d,
            4,
            abi.encodeCall(
                PreservationRoot.preservationPolicyContentRootBinding, (p.contentRootRecord)
            ),
            608,
            d.readGas
        );
        rootBinding = abi.decode(raw, (PreservationRoot.Binding));
        _canonical(raw, abi.encode(rootBinding));
        PreservationRoot.Binding memory b = rootBinding;
        if (
            b.profileId != (v2 ? RootSchemasV2.PROFILE : RootSchemas.PROFILE)
                || b.outputManifest != d.targets[8] || b.outputManifestCodeHash != d.codeHashes[8]
                || b.checkpoint != d.targets[7] || b.checkpointCodeHash != d.codeHashes[7]
                || b.checkpointHash != outputs.checkpointHash
                || b.checkpointStateHash != outputs.checkpointStateHash
                || b.entropySourceSet != d.targets[10]
                || b.entropySourceSetCodeHash != d.codeHashes[10]
                || b.inventoryHash != inventoryHash || b.policyChainHash != policyChainHash
                || b.outputRoot != outputs.outputRoot || b.metadataRouter != d.targets[4]
                || b.preservationOutputProfile != outputs.preservationProfile
                || b.outputSchemaHash
                    != (v2
                            ? RootSchemasV2.definitionHash(OutputSchemasV2.SCHEMA)
                            : RootSchemas.definitionHash(OutputSchemas.SCHEMA))
                || b.outputCanonicalizationHash
                    != (v2
                            ? RootSchemasV2.definitionHash(OutputSchemasV2.CANON)
                            : RootSchemas.definitionHash(OutputSchemas.CANON))
                || b.leafSchemaHash
                    != (v2
                            ? RootSchemasV2.definitionHash(OutputSchemasV2.LEAF_SCHEMA)
                            : RootSchemas.definitionHash(OutputSchemas.LEAF_SCHEMA))
                || b.rootSchemaHash
                    != (v2
                            ? RootSchemasV2.definitionHash(RootSchemasV2.ROOT_SCHEMA)
                            : RootSchemas.definitionHash(RootSchemas.ROOT_SCHEMA))
                || b.rootCanonicalizationHash
                    != (v2
                            ? RootSchemasV2.definitionHash(RootSchemasV2.ROOT_CANON)
                            : RootSchemas.definitionHash(RootSchemas.ROOT_CANON))
        ) revert S.InvalidPolicySnapshot();
        Root.Record memory r = root;
        if (
            r.publication.collectionId != p.scope.collectionId
                || r.publication.verifiedManifestRecordHash != p.outputManifestRecord
                || r.contentRoot != outputs.contentRoot || r.leafCount != outputs.tokenCount
                || r.manifestHash != outputs.manifestHash || r.artistId != artist.artistId
                || r.bindingGeneration != artist.bindingGeneration
                || r.bindingHash != artist.bindingHash || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8) || r.grantRevision == 0
                || r.artistConsent == 0 || r.publishedAt == 0 || r.routeHash == 0
                || keccak256(
                        abi.encode(
                            (v2
                                    ? keccak256(
                                        "6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"
                                    )
                                    : keccak256(
                                        "6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"
                                    )),
                            d.chainId,
                            d.targets[4],
                            r,
                            b
                        )
                    ) != p.contentRootRecord
        ) revert S.InvalidPolicySnapshot();
    }

    function _version2(bytes32 family) private pure returns (bool) {
        if (family == ProducerProfiles.ORIGINAL_PROFILE) return false;
        if (family == ProducerProfiles.FAMILY_PROFILE) return true;
        revert S.InvalidPolicySnapshot();
    }

    function _read(
        S.Dependencies memory d,
        uint256 at,
        bytes memory input,
        uint256 size,
        uint256 cap
    ) private view returns (bytes memory) {
        return Reads.read(d.targets[at], input, size, cap);
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert S.InvalidPolicySnapshot();
    }
}
