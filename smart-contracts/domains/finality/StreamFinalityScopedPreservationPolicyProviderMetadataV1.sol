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
    StreamFinalityScopedPreservationPolicyMetadataRootFactsV1 as Facts
} from "./StreamFinalityScopedPreservationPolicyMetadataRootFactsV1.sol";

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
    // Preserve the original surfaced ABI error now emitted by the fixed root reader.
    error InvalidPreservationRootFamily();

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
        return Facts.read(c, scope, current, preservationFamily);
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

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert InvalidScopedProviderMetadata();
    }
}
