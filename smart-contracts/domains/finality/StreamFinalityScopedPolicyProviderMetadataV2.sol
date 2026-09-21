// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as SnapshotReads
} from "./StreamFinalityScopedPolicySnapshotReadsV2.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    IStreamScopedPolicyContentRootPublicationV2 as RootV2
} from "../../interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as RootSchemas
} from "./StreamScopedPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputSchemas
} from "./StreamScopedPolicyOutputSchemasV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

import {
    StreamFinalityScopedPolicyMetadataPayloadV2 as Payload
} from "./StreamFinalityScopedPolicyMetadataPayloadV2.sol";
import {
    StreamFinalityScopedPolicyMetadataRootV2 as RootRead
} from "./StreamFinalityScopedPolicyMetadataRootV2.sol";

/// @notice Fixed full-scope source projections for the combined provider's new scoped profile.
/// @dev The host supplies only its constructor-pinned configuration. Membership establishes
/// scope existence; selected snapshots/root records establish their own exact identities.
/// Neither this worker nor its arguments grant publication or finality authority.
library StreamFinalityScopedPolicyProviderMetadataV2 {
    struct Config {
        SnapshotReads.Dependencies snapshots;
        address membership;
        bytes32 membershipCodeHash;
    }

    struct RootFacts {
        bytes32 recordHash;
        Root.Record record;
        RootV2.Binding binding;
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
        RootFacts memory f = rootFacts(c, scope, true);
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
        _scope(c, scope);
        bytes memory raw = Reads.read(
            c.snapshots.snapshots,
            abi.encodeCall(Snapshot.currentSnapshot, (scope)),
            544,
            c.snapshots.readGas
        );
        f.snapshot = abi.decode(raw, (S.Receipt));
        _canonical(raw, abi.encode(f.snapshot));
        (S.Publication memory original, S.Receipt memory receipt) =
            SnapshotReads.original(c.snapshots, scope, f.snapshot.recordHash, f.snapshot.revision);
        if (keccak256(raw) != keccak256(abi.encode(receipt))) {
            revert InvalidScopedProviderMetadata();
        }
        if (current) {
            SnapshotReads.requireCurrent(c.snapshots, scope, receipt.recordHash, receipt.revision);
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
        f.source = _payload(c, f.dependencies, original, receipt);
        _factory(c, f);
        _root(c, scope, original.outputManifestRecord, f);
    }

    function snapshot(Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32)
    {
        _scope(c, scope);
        return _snapshot(c, scope).manifestHash;
    }

    function manifest(Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bool, bytes32)
    {
        _scope(c, scope);
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

    function _snapshot(Config memory c, StreamFinalityScope memory scope)
        private
        view
        returns (S.Receipt memory r)
    {
        bytes memory raw = Reads.read(
            c.snapshots.snapshots,
            abi.encodeCall(Snapshot.currentSnapshot, (scope)),
            544,
            c.snapshots.readGas
        );
        r = abi.decode(raw, (S.Receipt));
        if (keccak256(raw) != keccak256(abi.encode(r))) revert InvalidScopedProviderMetadata();
        SnapshotReads.requireCurrent(c.snapshots, scope, r.recordHash, r.revision);
    }

    function _scope(Config memory c, StreamFinalityScope memory scope) private view {
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
                            abi.encodeCall(IERC165.supportsInterface, (type(RootV2).interfaceId)),
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
                            abi.encodeCall(Snapshot.scopedPolicySnapshotProfile, ()),
                            32,
                            c.snapshots.readGas
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2")
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
        S.Receipt memory receipt
    ) private view returns (S.Source memory f) {
        f = Payload.read(c, source, original, receipt);
        // Preserve the original private reader's caller-memory normalization.
        original.expectedSourceHash = 0;
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
        RootFacts memory f
    ) private view {
        (f.recordHash, f.record, f.binding) = RootRead.read(c, scope, outputManifestRecord, f);
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert InvalidScopedProviderMetadata();
    }
}
