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

import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as M
} from "./StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";
import {
    StreamFinalityScopedPreservationPolicyMetadataPayloadV1 as Payload
} from "./StreamFinalityScopedPreservationPolicyMetadataPayloadV1.sol";
import {
    StreamFinalityScopedPreservationPolicyMetadataRootV1 as RootRead
} from "./StreamFinalityScopedPreservationPolicyMetadataRootV1.sol";

/// @notice Fixed full root-facts orchestration with the original dependency order and delegate context.
library StreamFinalityScopedPreservationPolicyMetadataRootFactsV1 {
    function read(
        M.Config memory c,
        StreamFinalityScope memory scope,
        bool current,
        bytes32 preservationFamily
    ) public view returns (M.RootFacts memory f) {
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
            revert M.InvalidScopedProviderMetadata();
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
            revert M.InvalidScopedProviderMetadata();
        }
        for (uint256 i; i < 11; ++i) {
            if (
                f.dependencies.targets[i].code.length == 0
                    || f.dependencies.targets[i].codehash != f.dependencies.codeHashes[i]
            ) {
                revert M.InvalidScopedProviderMetadata();
            }
        }
        f.source = _payload(c, f.dependencies, original, receipt, preservationFamily);
        _factory(c, f);
        _root(c, scope, original.outputManifestRecord, f, preservationFamily);
    }

    function _scope(M.Config memory c, StreamFinalityScope memory scope, bytes32 preservationFamily)
        private
        view
    {
        if (
            c.snapshots.chainId != block.chainid || c.snapshots.readGas < 50000
                || c.snapshots.validationGas < c.snapshots.readGas
                || (scope.scopeType != StreamFinalityScopeType.TOKEN
                    && scope.scopeType != StreamFinalityScopeType.RELEASE
                    && scope.scopeType != StreamFinalityScopeType.SEASON)
        ) revert M.InvalidScopedProviderMetadata();
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
                revert M.InvalidScopedProviderMetadata();
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
            revert M.InvalidScopedProviderMetadata();
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
            revert M.InvalidScopedProviderMetadata();
        }
    }

    function _factory(M.Config memory c, M.RootFacts memory f) private view {
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
            revert M.InvalidScopedProviderMetadata();
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
            revert M.InvalidScopedProviderMetadata();
        }
    }

    function _payload(
        M.Config memory c,
        S.Dependencies memory source,
        S.Publication memory original,
        S.Receipt memory receipt,
        bytes32 preservationFamily
    ) private view returns (S.Source memory f) {
        f = Payload.read(c, source, original, receipt, preservationFamily);
        // Preserve the original private reader's caller-memory normalization.
        original.expectedSourceHash = 0;
    }

    function _root(
        M.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 outputManifestRecord,
        M.RootFacts memory f,
        bytes32 preservationFamily
    ) private view {
        (f.recordHash, f.record, f.binding) = RootRead.read(
            c, scope, outputManifestRecord, f, preservationFamily
        );
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert M.InvalidScopedProviderMetadata();
    }
}
