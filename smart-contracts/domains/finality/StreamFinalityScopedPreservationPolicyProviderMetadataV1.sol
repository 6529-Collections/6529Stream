// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamPreservationPolicyRootFamiliesV2 as RootFamilies
} from "./StreamPreservationPolicyRootFamiliesV2.sol";

import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as SnapshotReads
} from "./StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as RootSchemas
} from "./StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "./StreamPreservationPolicyOutputSchemasV1.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Fixed full-scope source projections for the combined provider's new scoped profile.
/// @dev The host supplies only its constructor-pinned configuration. Membership establishes
/// scope existence; selected snapshots/root records establish their own exact identities.
/// Neither this worker nor its arguments grant publication or finality authority.
library StreamFinalityScopedPreservationPolicyProviderMetadataV1 {
    struct Config {
        SnapshotReads.Dependencies snapshots;
        address membership;
        bytes32 membershipCodeHash;
    }

    struct RootFacts {
        bytes32 recordHash;
        Root.Record record;
        PreservationRoot.Binding binding;
        S.Receipt snapshot;
        S.Source source;
        S.Dependencies dependencies;
    }
    error InvalidScopedProviderMetadata();

    function root(Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32 value, uint64 count, bytes32 schema)
    {
        return root(c, scope, Producers.ORIGINAL_PROFILE);
    }

    function root(Config memory c, StreamFinalityScope memory scope, bytes32 preservationFamily)
        public
        view
        returns (bytes32 value, uint64 count, bytes32 schema)
    {
        SnapshotFamilies.version2(preservationFamily);
        RootFacts memory f = rootFacts(c, scope, true, preservationFamily);
        return (f.record.contentRoot, f.record.leafCount, OutputSchemas.LEAF_SCHEMA);
    }

    /// @notice Exact selected root and immutable full-policy snapshot carrier.
    /// @dev The false branch only projects original records. Callers admitting current/locked
    /// state must independently authenticate current inventory or require the new snapshot lock.
    function rootFacts(Config memory c, StreamFinalityScope memory scope, bool current)
        public
        view
        returns (RootFacts memory f)
    {
        return rootFacts(c, scope, current, Producers.ORIGINAL_PROFILE);
    }

    function rootFacts(
        Config memory c,
        StreamFinalityScope memory scope,
        bool current,
        bytes32 preservationFamily
    ) public view returns (RootFacts memory f) {
        SnapshotFamilies.version2(preservationFamily);
        _scope(c, scope, preservationFamily);
        bytes memory raw = Reads.read(
            c.snapshots.snapshots,
            abi.encodeCall(Snapshot.currentSnapshot, (scope)),
            544,
            c.snapshots.readGas
        );
        f.snapshot = abi.decode(raw, (S.Receipt));
        _canonical(raw, abi.encode(f.snapshot));
        (S.Publication memory original, S.Receipt memory receipt) = SnapshotReads.original(
            c.snapshots, scope, f.snapshot.recordHash, f.snapshot.revision, preservationFamily
        );
        if (keccak256(raw) != keccak256(abi.encode(receipt))) {
            revert InvalidScopedProviderMetadata();
        }
        if (current) {
            SnapshotReads.requireCurrent(
                c.snapshots, scope, receipt.recordHash, receipt.revision, preservationFamily
            );
        }
        raw = Reads.read(
            c.snapshots.snapshots,
            abi.encodeCall(Snapshot.dependencies, ()),
            832,
            c.snapshots.readGas
        );
        f.dependencies = abi.decode(raw, (S.Dependencies));
        _canonical(raw, abi.encode(f.dependencies));
        if (
            f.dependencies.targets[5] != c.membership
                || f.dependencies.codeHashes[5] != c.membershipCodeHash
        ) {
            revert InvalidScopedProviderMetadata();
        }
        for (uint256 i; i < 11; ++i) {
            if (
                f.dependencies.targets[i].code.length == 0
                    || f.dependencies.targets[i].codehash != f.dependencies.codeHashes[i]
            ) {
                revert InvalidScopedProviderMetadata();
            }
        }
        f.source = _payload(c, f.dependencies, original, receipt, preservationFamily);
        _factory(c, f);
        _root(c, scope, original.outputManifestRecord, f, preservationFamily);
    }

    function snapshot(Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32)
    {
        return snapshot(c, scope, Producers.ORIGINAL_PROFILE);
    }

    function snapshot(Config memory c, StreamFinalityScope memory scope, bytes32 preservationFamily)
        public
        view
        returns (bytes32)
    {
        SnapshotFamilies.version2(preservationFamily);
        _scope(c, scope, preservationFamily);
        return _snapshot(c, scope, preservationFamily).manifestHash;
    }

    function manifest(Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bool, bytes32)
    {
        return manifest(c, scope, Producers.ORIGINAL_PROFILE);
    }

    function manifest(Config memory c, StreamFinalityScope memory scope, bytes32 preservationFamily)
        public
        view
        returns (bool, bytes32)
    {
        SnapshotFamilies.version2(preservationFamily);
        _scope(c, scope, preservationFamily);
        bytes memory raw = Reads.read(
            c.membership,
            abi.encodeWithSignature(
                "requireScopeMembership((uint8,uint256,uint256,bytes32))", scope
            ),
            256,
            c.snapshots.validationGas
        );
        StreamScopeMembershipFacts memory f = abi.decode(raw, (StreamScopeMembershipFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f))
                || f.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(
                        c.snapshots.chainId, c.snapshots.core, scope
                    ) || f.membershipHash == 0
        ) revert InvalidScopedProviderMetadata();
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            if (f.tokenCount != 1 || f.sourceRecordHash != 0 || f.scopeManifestHash != 0) {
                revert InvalidScopedProviderMetadata();
            }
            return (false, bytes32(0));
        }
        if (f.sourceRecordHash == 0 || f.scopeManifestHash == 0) {
            revert InvalidScopedProviderMetadata();
        }
        return (true, f.scopeManifestHash);
    }

    function _snapshot(
        Config memory c,
        StreamFinalityScope memory scope,
        bytes32 preservationFamily
    ) private view returns (S.Receipt memory r) {
        bytes memory raw = Reads.read(
            c.snapshots.snapshots,
            abi.encodeCall(Snapshot.currentSnapshot, (scope)),
            544,
            c.snapshots.readGas
        );
        r = abi.decode(raw, (S.Receipt));
        if (keccak256(raw) != keccak256(abi.encode(r))) revert InvalidScopedProviderMetadata();
        SnapshotReads.requireCurrent(
            c.snapshots, scope, r.recordHash, r.revision, preservationFamily
        );
    }

    function _scope(Config memory c, StreamFinalityScope memory scope, bytes32 preservationFamily)
        private
        view
    {
        if (
            c.snapshots.chainId != block.chainid || c.snapshots.readGas < 50000
                || c.snapshots.validationGas < c.snapshots.readGas
                || (scope.scopeType != StreamFinalityScopeType.TOKEN
                    && scope.scopeType != StreamFinalityScopeType.RELEASE
                    && scope.scopeType != StreamFinalityScopeType.SEASON)
        ) revert InvalidScopedProviderMetadata();
        // Original subject derivation enforces the complete canonical scope tuple.
        StreamMetadataSubjects.scopeSubject(c.snapshots.chainId, c.snapshots.core, scope);
        address[5] memory targets = [
            c.snapshots.core,
            c.snapshots.metadata,
            c.snapshots.router,
            c.snapshots.snapshots,
            c.membership
        ];
        bytes32[5] memory hashes = [
            c.snapshots.coreCodeHash,
            c.snapshots.metadataCodeHash,
            c.snapshots.routerCodeHash,
            c.snapshots.snapshotsCodeHash,
            c.membershipCodeHash
        ];
        for (uint256 i; i < 5; ++i) {
            if (targets[i].code.length == 0 || hashes[i] == 0 || targets[i].codehash != hashes[i]) {
                revert InvalidScopedProviderMetadata();
            }
        }
        if (
            abi.decode(
                        Reads.read(
                            c.snapshots.router,
                            abi.encodeCall(
                                IERC165.supportsInterface, (type(PreservationRoot).interfaceId)
                            ),
                            32,
                            c.snapshots.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            c.snapshots.snapshots,
                            abi.encodeCall(IERC165.supportsInterface, (type(Snapshot).interfaceId)),
                            32,
                            c.snapshots.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            c.snapshots.snapshots,
                            abi.encodeCall(Snapshot.scopedPreservationPolicySnapshotProfile, ()),
                            32,
                            c.snapshots.readGas
                        ),
                        (bytes32)
                    ) != SnapshotFamilies.profile(preservationFamily, true)
        ) {
            revert InvalidScopedProviderMetadata();
        }
        if (
            abi.decode(
                        Reads.read(
                            c.membership, abi.encodeWithSignature("core()"), 32, c.snapshots.readGas
                        ),
                        (address)
                    ) != c.snapshots.core
                || abi.decode(
                        Reads.read(
                            c.membership,
                            abi.encodeWithSignature("metadataHost()"),
                            32,
                            c.snapshots.readGas
                        ),
                        (address)
                    ) != c.snapshots.metadata
        ) {
            revert InvalidScopedProviderMetadata();
        }
    }

    function _payload(
        Config memory c,
        S.Dependencies memory source,
        S.Publication memory original,
        S.Receipt memory receipt,
        bytes32 preservationFamily
    ) private view returns (S.Source memory f) {
        bytes memory out = Reads.dynamicRead(
            c.snapshots.snapshots,
            abi.encodeCall(Snapshot.snapshotPayload, (receipt.recordHash)),
            receipt.manifestBytes + 96,
            c.snapshots.validationGas
        );
        bytes memory raw = abi.decode(out, (bytes));
        _canonical(out, abi.encode(raw));
        if (raw.length != receipt.manifestBytes || keccak256(raw) != receipt.manifestHash) {
            revert InvalidScopedProviderMetadata();
        }
        (
            bytes32 domain,
            uint256 chain,
            address host,
            address[11] memory targets,
            bytes32[11] memory hashes,
            S.Publication memory p,
            S.Receipt memory fields,
            S.Source memory value
        ) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                S.Publication,
                S.Receipt,
                S.Source
            )
        );
        _canonical(raw, abi.encode(domain, chain, host, targets, hashes, p, fields, value));
        // The caller retains the original receipt for the root/source join below.
        receipt = abi.decode(abi.encode(receipt), (S.Receipt));
        original.expectedSourceHash = 0;
        receipt.recordHash = 0;
        receipt.chainHash = 0;
        receipt.manifestHash = 0;
        receipt.manifestBytes = 0;
        receipt.recordedAt = 0;
        if (
            domain != SnapshotFamilies.payloadDomain(preservationFamily, true)
                || chain != c.snapshots.chainId || host != c.snapshots.snapshots
                || keccak256(abi.encode(targets, hashes))
                    != keccak256(abi.encode(source.targets, source.codeHashes))
                || keccak256(abi.encode(p)) != keccak256(abi.encode(original))
                || keccak256(abi.encode(fields)) != keccak256(abi.encode(receipt))
                || keccak256(abi.encode(value.scope)) != keccak256(abi.encode(p.scope))
                || fields.sourceHash
                    != keccak256(
                        abi.encode(
                            SnapshotFamilies.sourcesDomain(preservationFamily, true),
                            chain,
                            host,
                            targets,
                            hashes,
                            value
                        )
                    )
        ) revert InvalidScopedProviderMetadata();
        if (
            value.outputs.metadataRouter != c.snapshots.router
                || value.outputs.preservationProfile != preservationFamily
                || value.content.preservationProfile != value.outputs.preservationProfile
        ) revert InvalidScopedProviderMetadata();
        f = value;
    }

    function _factory(Config memory c, RootFacts memory f) private view {
        address factory = f.source.sourceFactory;
        if (
            factory.code.length == 0 || factory.codehash != f.source.sourceFactoryCodeHash
                || abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)),
                            32,
                            c.snapshots.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(Factory.scopedPolicyFactoryProfile, ()),
                            32,
                            c.snapshots.readGas
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) {
            revert InvalidScopedProviderMetadata();
        }
        bytes memory raw =
            Reads.read(factory, abi.encodeCall(Factory.dependencies, ()), 352, c.snapshots.readGas);
        Policies.Dependencies memory d = abi.decode(raw, (Policies.Dependencies));
        _canonical(raw, abi.encode(d));
        if (
            keccak256(raw) != f.source.factoryDependenciesHash || d.chainId != c.snapshots.chainId
                || d.targets[0] != c.snapshots.core || d.codeHashes[0] != c.snapshots.coreCodeHash
                || d.targets[1] != c.snapshots.metadata
                || d.codeHashes[1] != c.snapshots.metadataCodeHash || d.targets[2] != c.membership
                || d.codeHashes[2] != c.membershipCodeHash || d.targets[3].code.length == 0
                || d.targets[3].codehash != d.codeHashes[3]
                || abi.decode(
                        Reads.read(
                            f.dependencies.targets[10],
                            abi.encodeWithSignature("factory()"),
                            32,
                            c.snapshots.readGas
                        ),
                        (address)
                    ) != factory
                || abi.decode(
                        Reads.read(
                            f.dependencies.targets[7],
                            abi.encodeWithSignature("sourceFactory()"),
                            32,
                            c.snapshots.readGas
                        ),
                        (address)
                    ) != factory
                || abi.decode(
                        Reads.read(
                            f.dependencies.targets[7],
                            abi.encodeWithSignature("factoryDependenciesHash()"),
                            32,
                            c.snapshots.readGas
                        ),
                        (bytes32)
                    ) != f.source.factoryDependenciesHash
        ) {
            revert InvalidScopedProviderMetadata();
        }
    }

    function _root(
        Config memory c,
        StreamFinalityScope memory scope,
        bytes32 outputManifestRecord,
        RootFacts memory f,
        bytes32 preservationFamily
    ) private view {
        f.recordHash = abi.decode(
            Reads.read(
                c.snapshots.router,
                abi.encodeCall(Root.scopedContentRootHead, (scope)),
                32,
                c.snapshots.readGas
            ),
            (bytes32)
        );
        bytes memory raw = Reads.dynamicRead(
            c.snapshots.router,
            abi.encodeCall(Root.scopedContentRootRecord, (f.recordHash)),
            4096,
            c.snapshots.validationGas
        );
        f.record = abi.decode(raw, (Root.Record));
        _canonical(raw, abi.encode(f.record));
        raw = Reads.read(
            c.snapshots.router,
            abi.encodeCall(
                PreservationRoot.scopedPreservationPolicyContentRootBinding, (f.recordHash)
            ),
            800,
            c.snapshots.validationGas
        );
        f.binding = abi.decode(raw, (PreservationRoot.Binding));
        _canonical(raw, abi.encode(f.binding));
        PreservationRoot.Binding memory expected =
            _binding(f.dependencies, f.source, f.snapshot, preservationFamily);
        if (keccak256(raw) != keccak256(abi.encode(expected))) {
            revert InvalidScopedProviderMetadata();
        }
        // The root-free snapshot declaration names the actual output receipt. Its payload
        // hash is a different value and must never stand in for this original record key.
        raw = Reads.read(
            f.dependencies.targets[8],
            abi.encodeCall(Outputs.manifestRecord, (outputManifestRecord)),
            608,
            c.snapshots.validationGas
        );
        Outputs.Manifest memory savedManifest = abi.decode(raw, (Outputs.Manifest));
        _canonical(raw, abi.encode(savedManifest));
        if (outputManifestRecord == 0 || keccak256(raw) != keccak256(abi.encode(f.source.outputs)))
        {
            revert InvalidScopedProviderMetadata();
        }
        Root.Record memory r = f.record;
        if (
            f.recordHash == 0
                || keccak256(abi.encode(r.publication.scope)) != keccak256(abi.encode(scope))
                || r.publication.snapshotRecordHash != f.snapshot.recordHash
                || r.publication.snapshotRevision != f.snapshot.revision
                || r.snapshotHost != c.snapshots.snapshots
                || r.snapshotCodeHash != c.snapshots.snapshotsCodeHash
                || r.snapshotManifestHash != f.snapshot.manifestHash
                || r.snapshotSourceHash != f.snapshot.sourceHash
                || r.contentRoot != f.source.outputs.contentRoot || r.contentRoot == 0
                || r.leafCount != f.source.membership.tokenCount || r.leafCount == 0
                || r.outputManifestHash != f.source.outputs.manifestHash
                || r.artistId != f.source.artist.artistId
                || r.bindingGeneration != f.source.artist.bindingGeneration
                || r.bindingHash != f.source.artist.bindingHash || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8) || r.grantRevision == 0
                || r.routeHash == 0 || r.stateHash == 0 || r.artistConsent == 0
                || r.publishedAt == 0 || r.publishedAt > block.timestamp
        ) revert InvalidScopedProviderMetadata();
        Root.Record memory fields = abi.decode(abi.encode(r), (Root.Record));
        fields.stateHash = 0;
        fields.artistConsent = 0;
        fields.publishedAt = 0;
        if (
            r.stateHash
                != keccak256(
                    abi.encode(
                        RootFamilies.stateDomain(preservationFamily, true),
                        c.snapshots.chainId,
                        c.snapshots.router,
                        c.snapshots.core,
                        fields,
                        f.binding
                    )
                )
        ) revert InvalidScopedProviderMetadata();
        raw = Reads.read(
            c.snapshots.router,
            abi.encodeCall(Root.scopedTokenContentRoot, (scope)),
            96,
            c.snapshots.readGas
        );
        (bytes32 value, uint64 count, bytes32 schema) = abi.decode(raw, (bytes32, uint64, bytes32));
        _canonical(raw, abi.encode(value, count, schema));
        if (value != r.contentRoot || count != r.leafCount || schema != OutputSchemas.LEAF_SCHEMA) {
            revert InvalidScopedProviderMetadata();
        }
    }

    function _binding(
        S.Dependencies memory d,
        S.Source memory source,
        S.Receipt memory receipt,
        bytes32 preservationFamily
    ) private pure returns (PreservationRoot.Binding memory b) {
        b.profileId = RootFamilies.profile(preservationFamily, true);
        bytes32[5] memory ids = RootFamilies.ids(preservationFamily, true);
        b.outputManifest = d.targets[8];
        b.outputManifestCodeHash = d.codeHashes[8];
        b.checkpoint = d.targets[7];
        b.checkpointCodeHash = d.codeHashes[7];
        b.checkpointHash = source.outputs.checkpointHash;
        b.checkpointStateHash = source.outputs.checkpointStateHash;
        b.entropySourceSet = d.targets[10];
        b.entropySourceSetCodeHash = d.codeHashes[10];
        b.inventoryHash = source.outputs.inventoryHash;
        b.policyChainHash = source.outputs.policyChainHash;
        b.outputRoot = source.outputs.outputRoot;
        b.outputSchemaHash = RootFamilies.definitionHash(preservationFamily, true, ids[0]);
        b.outputCanonicalizationHash = RootFamilies.definitionHash(preservationFamily, true, ids[1]);
        b.leafSchemaHash = RootFamilies.definitionHash(preservationFamily, true, ids[2]);
        b.rootSchemaHash = RootFamilies.definitionHash(preservationFamily, true, ids[3]);
        b.rootCanonicalizationHash = RootFamilies.definitionHash(preservationFamily, true, ids[4]);
        b.sourceFactory = source.sourceFactory;
        b.sourceFactoryCodeHash = source.sourceFactoryCodeHash;
        b.factoryDependenciesHash = source.factoryDependenciesHash;
        b.snapshotSchemaHash = receipt.schemaHash;
        b.snapshotProfileHash = receipt.profileHash;
        b.snapshotCanonicalizationHash = receipt.canonicalizationHash;
        b.metadataRouter = d.targets[4];
        b.preservationOutputProfile = source.outputs.preservationProfile;
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert InvalidScopedProviderMetadata();
    }
}
