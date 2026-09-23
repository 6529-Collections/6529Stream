// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScopedSnapshotReads as SnapshotReads
} from "./StreamFinalityScopedSnapshotReads.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedSnapshotPublication as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    StreamScopedSnapshotTypes as S
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Fixed full-scope source projections for the combined provider's new scoped profile.
/// @dev The host supplies only its constructor-pinned configuration. Membership establishes
/// scope existence; selected snapshots/root records establish their own exact identities.
/// Neither this worker nor its arguments grant publication or finality authority.
library StreamFinalityScopedProviderMetadata {
    struct Config {
        SnapshotReads.Dependencies snapshots;
        address membership;
        bytes32 membershipCodeHash;
    }
    error InvalidScopedProviderMetadata();

    function root(Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32 value, uint64 count, bytes32 schema)
    {
        _scope(c, scope);
        S.Receipt memory saved = _snapshot(c, scope);
        bytes32 head = abi.decode(
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
            abi.encodeCall(Root.scopedContentRootRecord, (head)),
            8192,
            c.snapshots.readGas
        );
        Root.Record memory record = abi.decode(raw, (Root.Record));
        if (
            keccak256(raw) != keccak256(abi.encode(record)) || head == 0
                || keccak256(abi.encode(record.publication.scope)) != keccak256(abi.encode(scope))
                || record.publication.snapshotRecordHash != saved.recordHash
                || record.publication.snapshotRevision != saved.revision
                || record.snapshotHost != c.snapshots.snapshots
                || record.snapshotCodeHash != c.snapshots.snapshotsCodeHash
                || record.snapshotManifestHash != saved.manifestHash
                || record.snapshotSourceHash != saved.sourceHash || record.artistConsent == 0
                || record.stateHash == 0 || record.contentRoot == 0 || record.leafCount == 0
        ) revert InvalidScopedProviderMetadata();
        raw = Reads.read(
            c.snapshots.router,
            abi.encodeCall(Root.scopedTokenContentRoot, (scope)),
            96,
            c.snapshots.readGas
        );
        (value, count, schema) = abi.decode(raw, (bytes32, uint64, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(value, count, schema))
                || value != record.contentRoot || count != record.leafCount || schema == 0
        ) {
            revert InvalidScopedProviderMetadata();
        }
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
}
