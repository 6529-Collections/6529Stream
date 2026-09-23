// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicySnapshotAdmissionV2 as Admission
} from "./StreamScopedPolicySnapshotAdmissionV2.sol";
import {
    StreamScopedPolicySnapshotWriterV2 as Writer
} from "./StreamScopedPolicySnapshotWriterV2.sol";
import {
    StreamScopedPolicySnapshotAssemblyV2 as Assembly
} from "./StreamScopedPolicySnapshotAssemblyV2.sol";

import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamGovernedParameterAuthority
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

import {
    IStreamScopedPolicySnapshotPublicationV2 as I
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    StreamScopedPolicySnapshotSourceReadsV2 as Sources
} from "../records/StreamScopedPolicySnapshotSourceReadsV2.sol";

import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";

import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";

/// @notice Exact full-policy scope-bound source publication, preceding separate scoped root adoption.
/// @dev Source snapshots are separate from Artist CONTENT_ROOT authority, complete output bytes,
/// reference-mode evidence and finality. VIEW requires its own actual presentation adoption profile.
contract StreamScopedPolicySnapshotPublicationV2 is I, StreamGasParameterHost {
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_SCOPED_POLICY_SNAPSHOT_READ_GAS");
    bytes32 public constant SOURCE_GAS =
        keccak256("6529STREAM_GGP_SCOPED_POLICY_SNAPSHOT_SOURCE_GAS");
    bytes32 public constant INVENTORY_GAS =
        keccak256("6529STREAM_GGP_SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS");
    address public immutable override core;
    address public immutable override metadataHost;
    bytes32 public immutable authorityCodeHash;
    S.Dependencies private _fixed;
    mapping(bytes32 => S.Publication) private _publications;
    mapping(bytes32 => S.Receipt) private _receipts;
    mapping(bytes32 => Bytes.Manifest) private _payloads;
    mapping(bytes32 => bytes32[]) private _history;
    mapping(bytes32 => mapping(bytes32 => bytes32)) private _ids;
    mapping(bytes32 => S.Lock) private _locks;
    bool private _entered;

    constructor(S.Dependencies memory d, address executor, GasParameterConfig[3] memory configs)
        StreamGasParameterHost(executor)
    {
        if (
            _registerGasParameter(configs[0]) != READ_GAS
                || _registerGasParameter(configs[1]) != SOURCE_GAS
                || _registerGasParameter(configs[2]) != INVENTORY_GAS
        ) revert S.InvalidScopedPolicySnapshot();
        for (uint256 i; i < 3; ++i) {
            if (configs[i].failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK) {
                revert S.InvalidScopedPolicySnapshot();
            }
        }
        _fixed = d;
        core = d.targets[0];
        metadataHost = d.targets[1];
        Sources.bindings(dependencies());
        authorityCodeHash = abi.decode(
            Reads.read(
                metadataHost,
                abi.encodeWithSignature("executorCodeHash()"),
                32,
                configs[0].genesisValue
            ),
            (bytes32)
        );
        if (
            executor.code.length == 0 || executor.codehash != authorityCodeHash
                || abi.decode(
                        Reads.read(
                            metadataHost,
                            abi.encodeWithSignature("governanceAuthority()"),
                            32,
                            configs[0].genesisValue
                        ),
                        (address)
                    ) != executor
        ) revert S.InvalidScopedPolicySnapshot();
    }

    modifier guarded() {
        if (_entered) revert S.InvalidScopedPolicySnapshot();
        _entered = true;
        _;
        _entered = false;
    }

    function scopedPolicySnapshotProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2");
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(I).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function dependencies() public view override returns (S.Dependencies memory d) {
        d = _fixed;
        d.readGas = gasParameter(READ_GAS);
        d.sourceGas = gasParameter(SOURCE_GAS);
        d.inventoryGas = gasParameter(INVENTORY_GAS);
    }

    function previewSnapshot(S.Publication calldata p, address publisher)
        external
        view
        override
        returns (bytes32 sourceHash, bytes memory canonical)
    {
        S.Receipt memory r = Admission.prepare(
            _fixed, _locks, _ids, _history, metadataHost, gasParameter(READ_GAS), p, publisher
        );
        return _assemble(p, r);
    }

    function publishSnapshot(S.Publication calldata p)
        external
        override
        guarded
        returns (bytes32 hash)
    {
        S.Receipt memory r = Admission.prepare(
            _fixed, _locks, _ids, _history, metadataHost, gasParameter(READ_GAS), p, msg.sender
        );
        bytes memory canonical;
        (r.sourceHash, canonical) = _assemble(p, r);
        return Writer.publish(
            _publications,
            _receipts,
            _payloads,
            _ids,
            _history,
            _fixed,
            core,
            metadataHost,
            p,
            r,
            canonical
        );
    }

    function currentSnapshot(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (S.Receipt memory)
    {
        S.Receipt memory r = _receipts[_head(Sources.scopeSubject(_fixed, scope))];
        if (r.recordHash != 0) _requireExactScope(r.recordHash, scope);
        return r;
    }

    function snapshotRecord(bytes32 hash)
        external
        view
        override
        returns (S.Publication memory, S.Receipt memory)
    {
        return (_publications[hash], _known(hash));
    }

    function snapshotPayload(bytes32 hash) external view override returns (bytes memory) {
        _known(hash);
        return Bytes.read(_payloads[hash]);
    }

    function requireCurrent(StreamFinalityScope calldata scope, bytes32 hash, uint64 revision)
        public
        view
        override
        returns (S.Receipt memory r)
    {
        r = _known(hash);
        _requireExactScope(hash, scope);
        bytes32 subject = Sources.scopeSubject(_fixed, scope);
        if (r.scopeSubject != subject || _head(subject) != hash || r.revision != revision) {
            revert S.ScopedPolicySnapshotLineage(hash, _head(subject));
        }
        S.Receipt memory fields = abi.decode(abi.encode(r), (S.Receipt));
        fields.recordHash = 0;
        fields.chainHash = 0;
        fields.manifestHash = 0;
        fields.manifestBytes = 0;
        fields.recordedAt = 0;
        (bytes32 sourceHash, bytes memory canonical) = _assemble(_publications[hash], fields);
        if (
            sourceHash != r.sourceHash || keccak256(canonical) != r.manifestHash
                || canonical.length != r.manifestBytes
                || Bytes.requireIntact(_payloads[hash]) != r.manifestHash
        ) revert S.InvalidScopedPolicySnapshot();
    }

    function lockTransition(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32 actionScope, bytes32 oldState, bytes32 newState)
    {
        S.Receipt memory r = currentSnapshot(scope);
        if (r.recordHash == 0) revert S.ScopedPolicySnapshotUnknown(0);
        if (_locks[r.scopeSubject].actionId != 0) {
            revert S.ScopedPolicySnapshotLocked(r.scopeSubject);
        }
        actionScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_LOCK_V2"),
                _fixed.chainId,
                address(this),
                core,
                scope
            )
        );
        oldState = keccak256(abi.encode(actionScope, r.recordHash, r.revision, false));
        newState = keccak256(abi.encode(actionScope, r.recordHash, r.revision, true));
    }

    function lockSnapshot(StreamFinalityScope calldata scope) external override guarded {
        if (msg.sender != governanceAuthority || governanceAuthority.codehash != authorityCodeHash)
        {
            revert S.ScopedPolicySnapshotAuthority(msg.sender);
        }
        (bytes32 actionScope, bytes32 oldState, bytes32 newState) = lockTransition(scope);
        (
            bool executing,
            bytes32 action,
            uint8 cls,
            bytes32 suppliedScope,
            bytes32 oldHash,
            bytes32 newHash
        ) = abi.decode(
            Reads.read(
                governanceAuthority,
                abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
                192,
                gasParameter(READ_GAS)
            ),
            (bool, bytes32, uint8, bytes32, bytes32, bytes32)
        );
        if (
            !executing || action == 0 || cls != 2 || suppliedScope != actionScope
                || oldHash != oldState || newHash != newState
        ) revert S.ScopedPolicySnapshotAuthority(msg.sender);
        S.Receipt memory r = currentSnapshot(scope);
        requireCurrent(scope, r.recordHash, r.revision);
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert S.InvalidScopedPolicySnapshot();
        }
        _locks[r.scopeSubject] = S.Lock(r.recordHash, r.revision, action, uint64(block.timestamp));
        emit ScopedPolicySnapshotLocked(2, r.scopeSubject, _locks[r.scopeSubject]);
    }

    function snapshotLock(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (S.Lock memory)
    {
        return _locks[Sources.scopeSubject(_fixed, scope)];
    }

    function snapshotCount(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        return _history[Sources.scopeSubject(_fixed, scope)].length;
    }

    function snapshotAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _history[Sources.scopeSubject(_fixed, scope)][index];
    }

    function _assemble(S.Publication memory p, S.Receipt memory r)
        private
        view
        returns (bytes32 hash, bytes memory canonical)
    {
        (hash, canonical) = Assembly.assemble(dependencies(), p, r);
        r.sourceHash = hash;
        p.expectedSourceHash = 0;
    }

    function _head(bytes32 subject) private view returns (bytes32) {
        uint256 n = _history[subject].length;
        return n == 0 ? bytes32(0) : _history[subject][n - 1];
    }

    /// @dev TOKEN subjects identify a global tokenId and do not encode collectionId. Scope-bound
    /// currentness and lock actions additionally authenticate the complete recorded scope tuple.
    function _requireExactScope(bytes32 hash, StreamFinalityScope memory scope) private view {
        if (keccak256(abi.encode(_publications[hash].scope)) != keccak256(abi.encode(scope))) {
            revert S.InvalidScopedPolicySnapshot();
        }
    }

    function _known(bytes32 hash) private view returns (S.Receipt memory r) {
        r = _receipts[hash];
        if (hash == 0 || r.recordHash != hash) revert S.ScopedPolicySnapshotUnknown(hash);
    }
}
