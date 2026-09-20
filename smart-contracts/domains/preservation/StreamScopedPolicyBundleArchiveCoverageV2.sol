// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "./StreamPreservationInventoryChains.sol";
import { StreamBundleArchiveReads as Reads } from "./StreamBundleArchiveReads.sol";
import {
    IStreamScopedPolicyRenderCriticalInventoryV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyRenderCriticalInventoryV2.sol";
import {
    IStreamScopedPolicyBundleArchiveCoverageV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyBundleArchiveCoverageV2.sol";
import {
    StreamScopedPolicyBundleArchiveTypesV2 as PolicyBundle
} from "../../interfaces/stream/preservation/StreamScopedPolicyBundleArchiveTypesV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";

/// @notice Complete archival admission for an exact TOKEN/RELEASE/SEASON full-policy inventory.
/// @dev This sibling accepts only the explicitly typed V2 scoped inventory capability/profile.
/// Original archival authority, byte correspondence and retained Archive evidence are unchanged.
/// @dev Explicit immutable-STOP aggregate profile: every whole-byte part/state bundle is
/// checked fully at admission/refresh, under one complete environment/epoch. Ordinary EVM
/// STOP-only code immutability permits bounded current use. The full slow diagnostic retains
/// stronger per-call byte/runtime checks (including artificial test-state code mutation).
contract StreamScopedPolicyBundleArchiveCoverageV2 is IStreamScopedPolicyBundleArchiveCoverageV2 {
    bytes32 public constant PROFILE = PolicyBundle.PROFILE;
    B.Dependencies private _dependencies;
    bytes32 public dependencyHash;
    mapping(bytes32 => Scoped.Evidence) private _inventories;
    mapping(bytes32 => B.Progress) private _progress;
    mapping(bytes32 => T.Item[]) private _items;
    mapping(bytes32 => B.Admission[]) private _admissions;
    mapping(bytes32 => PolicyBundle.BundleEvidence) private _completed;
    mapping(bytes32 => B.Refresh) private _refreshes;
    mapping(bytes32 => bytes32) private _admissionObservation;

    event ScopedBundleCoverageStarted(
        uint16 schemaVersion,
        bytes32 indexed inventoryPlan,
        bytes32 indexed renderCriticalEvidenceHash
    );
    event ScopedBundleItemAdmitted(
        uint16 schemaVersion,
        bytes32 indexed inventoryPlan,
        uint64 indexed index,
        bytes32 itemHash,
        B.Admission admission
    );
    event ScopedBundleCoverageCompleted(
        uint16 schemaVersion,
        bytes32 indexed inventoryPlan,
        bytes32 indexed bundleCoverageHash,
        PolicyBundle.BundleEvidence evidence
    );
    event ScopedBundleRefreshAdvanced(
        uint16 schemaVersion,
        bytes32 indexed inventoryPlan,
        bytes32 indexed refreshId,
        uint64 nextIndex,
        bytes32 observationChain,
        bool complete
    );

    constructor(B.Dependencies memory d) {
        if (d.chainId != block.chainid || d.readGas < 50000 || d.archiveGas < d.readGas) {
            revert T.InventorySourceChanged();
        }
        for (uint256 i; i < 6; ++i) {
            if (d.targets[i] == address(0) || d.codeHashes[i] == 0) {
                revert T.InventorySourceChanged();
            }
        }
        _dependencies = d;
        dependencyHash = keccak256(abi.encode(d));
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return
            id == type(IStreamScopedPolicyBundleArchiveCoverageV2).interfaceId || id == 0x01ffc9a7;
    }

    function scopedPolicyBundleArchiveProfile() external pure override returns (bytes32) {
        return PROFILE;
    }

    function core() external view override returns (address) {
        return _dependencies.targets[0];
    }

    function metadataHost() external view override returns (address) {
        return _dependencies.targets[1];
    }

    function renderCriticalInventory() external view override returns (address) {
        return _dependencies.targets[2];
    }

    function artifactCoverage() external view override returns (address) {
        return _dependencies.targets[3];
    }

    function externalCoverage() external view override returns (address) {
        return _dependencies.targets[4];
    }

    function deploymentChainId() external view override returns (uint256) {
        return _dependencies.chainId;
    }

    function coreCodeHash() external view override returns (bytes32) {
        return _dependencies.codeHashes[0];
    }

    function metadataCodeHash() external view override returns (bytes32) {
        return _dependencies.codeHashes[1];
    }

    function inventoryCodeHash() external view override returns (bytes32) {
        return _dependencies.codeHashes[2];
    }

    function dependencies() external view returns (B.Dependencies memory) {
        return _dependencies;
    }

    function beginCoverage(bytes32 id) external {
        bytes32 environment = _environment();
        if (_inventories[id].inventory.planId != 0) return;
        bytes memory raw = IO.fixedRead(
            _dependencies.targets[2],
            abi.encodeCall(IStreamScopedPolicyRenderCriticalInventoryV2.inventoryEvidence, (id)),
            736,
            _dependencies.readGas
        );
        Scoped.Evidence memory full = abi.decode(raw, (Scoped.Evidence));
        T.Evidence memory e = full.inventory;
        IO.canonical(_dependencies.targets[2], raw, abi.encode(full));
        if (
            e.planId != id || id == 0 || e.renderCriticalEvidenceHash == 0 || e.segmentCount == 0
                || e.itemCount == 0 || e.artistId == 0 || e.collectionId == 0 || e.scopeSubject == 0
        ) revert T.InventoryIncomplete();
        _validateInventory(full);
        _inventories[id] = full;
        _progress[id].environmentHash = environment;
        _progress[id].nextLink = _segment(id, 0).firstLink;
        emit ScopedBundleCoverageStarted(2, id, e.renderCriticalEvidenceHash);
    }

    /// @dev The full producer result is authenticated before any archival progress exists.
    /// Current source selection remains the provider's separate inventory.requireCurrent call.
    function _validateInventory(Scoped.Evidence memory full) private view {
        StreamFinalityScope memory scope = full.scope;
        T.Evidence memory e = full.inventory;
        if (
            (scope.scopeType != StreamFinalityScopeType.TOKEN
                    && scope.scopeType != StreamFinalityScopeType.RELEASE
                    && scope.scopeType != StreamFinalityScopeType.SEASON)
                || scope.collectionId != e.collectionId
                || e.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(
                        _dependencies.chainId, _dependencies.targets[0], scope
                    ) || e.tokenCount == 0 || e.tokenInventoryHash == 0 || e.sourceContextHash == 0
                || e.segmentChainHash == 0
        ) revert T.InventorySourceChanged();
        bytes memory raw = IO.fixedRead(
            _dependencies.targets[2],
            abi.encodeCall(IStreamScopedPolicyRenderCriticalInventoryV2.dependencyHash, ()),
            32,
            _dependencies.readGas
        );
        bytes32 dependency = abi.decode(raw, (bytes32));
        bytes32 expected = e.renderCriticalEvidenceHash;
        full.inventory.renderCriticalEvidenceHash = 0;
        if (
            dependency == 0
                || keccak256(
                        abi.encode(
                            PolicyBundle.INVENTORY_EVIDENCE_DOMAIN,
                            _dependencies.chainId,
                            _dependencies.targets[2],
                            dependency,
                            full
                        )
                    ) != expected
        ) {
            revert T.InventorySourceChanged();
        }
        full.inventory.renderCriticalEvidenceHash = expected;
    }

    function coverNext(bytes32 id, T.Item calldata item, bytes32 nextLink, B.Proof calldata proof)
        external
    {
        B.Progress storage p = _progress[id];
        if (_inventories[id].inventory.planId == 0 || p.complete) revert T.InventoryIncomplete();
        T.Segment memory s = _segment(id, p.segmentIndex);
        if (Chains.link(s.key, s.itemCount, p.segmentItemIndex, item, nextLink) != p.nextLink) {
            revert T.InvalidInventorySegment();
        }
        bytes32 environment = _environment();
        (B.Admission memory a, bytes32 observation) =
            Reads.admit(_dependencies, _inventories[id].inventory.artistId, item, proof);
        if (_environment() != environment) revert T.InventorySourceChanged();
        if (environment != p.environmentHash) p.environmentHash = 0;
        bytes32 itemHash = Chains.itemHash(item);
        p.evidenceChainHash = keccak256(
            abi.encode(PolicyBundle.ITEM_DOMAIN, p.evidenceChainHash, id, p.itemCount, itemHash, a)
        );
        _admissionObservation[id] =
            _observation(_admissionObservation[id], p.itemCount, itemHash, observation);
        _items[id].push(item);
        _admissions[id].push(a);
        emit ScopedBundleItemAdmitted(2, id, p.itemCount, itemHash, a);
        p.itemCount += 1;
        p.segmentItemIndex += 1;
        p.nextLink = nextLink;
        if (p.segmentItemIndex == s.itemCount) _finishSegment(id, s);
    }

    /// @notice A source-authenticated explicit empty segment is still consumed in exact order.
    function coverEmptySegment(bytes32 id) external {
        B.Progress storage p = _progress[id];
        if (_inventories[id].inventory.planId == 0 || p.complete) revert T.InventoryIncomplete();
        T.Segment memory s = _segment(id, p.segmentIndex);
        if (s.itemCount != 0 || s.firstLink != 0 || p.segmentItemIndex != 0 || p.nextLink != 0) {
            revert T.InvalidInventorySegment();
        }
        if (_environment() != p.environmentHash) p.environmentHash = 0;
        _finishSegment(id, s);
    }

    function _finishSegment(bytes32 id, T.Segment memory s) private {
        B.Progress storage p = _progress[id];
        if (p.nextLink != 0 || p.segmentItemIndex != s.itemCount) {
            revert T.InvalidInventorySegment();
        }
        p.segmentChainHash = Chains.append(p.segmentChainHash, p.segmentIndex, s);
        p.segmentIndex += 1;
        p.segmentItemIndex = 0;
        if (p.segmentIndex != _inventories[id].inventory.segmentCount) {
            p.nextLink = _segment(id, p.segmentIndex).firstLink;
            return;
        }
        Scoped.Evidence storage full = _inventories[id];
        T.Evidence storage e = full.inventory;
        if (p.itemCount != e.itemCount || p.segmentChainHash != e.segmentChainHash) {
            revert T.InventoryIncomplete();
        }
        p.complete = true;
        PolicyBundle.BundleEvidence memory result = PolicyBundle.BundleEvidence(
            full.scope,
            T.BundleEvidence(id, e.renderCriticalEvidenceHash, p.itemCount, p.evidenceChainHash, 0)
        );
        result.coverage.bundleCoverageHash = keccak256(
            abi.encode(
                PolicyBundle.COVERAGE_DOMAIN,
                block.chainid,
                address(this),
                dependencyHash,
                PROFILE,
                full,
                result
            )
        );
        _completed[id] = result;
        if (p.environmentHash != 0) {
            bytes32 key = _refreshId(id, p.environmentHash);
            _refreshes[key] =
                B.Refresh(p.environmentHash, p.itemCount, _admissionObservation[id], true);
        }
        emit ScopedBundleCoverageCompleted(2, id, result.coverage.bundleCoverageHash, result);
    }

    /// @notice Canonical progress is keyed by environment; another caller cannot reset it.
    function beginRefresh(bytes32 id) external returns (bytes32 key) {
        if (!_progress[id].complete) revert T.InventoryIncomplete();
        bytes32 environment = _environment();
        key = _refreshId(id, environment);
        if (_refreshes[key].environmentHash == 0) _refreshes[key].environmentHash = environment;
    }

    function refreshNext(bytes32 id, uint64 expectedIndex) external {
        if (!_progress[id].complete) revert T.InventoryIncomplete();
        bytes32 environment = _environment();
        bytes32 key = _refreshId(id, environment);
        B.Refresh storage r = _refreshes[key];
        if (
            r.environmentHash != environment || r.complete || r.nextIndex != expectedIndex
                || expectedIndex >= _items[id].length
        ) revert T.InventoryIncomplete();
        bytes32 observation = Reads.current(
            _dependencies,
            _inventories[id].inventory.artistId,
            _items[id][expectedIndex],
            _admissions[id][expectedIndex]
        );
        if (_environment() != environment) revert T.InventorySourceChanged();
        r.currentObservationChain = _observation(
            r.currentObservationChain,
            expectedIndex,
            Chains.itemHash(_items[id][expectedIndex]),
            observation
        );
        r.nextIndex = expectedIndex + 1;
        r.complete = r.nextIndex == _completed[id].coverage.itemCount;
        emit ScopedBundleRefreshAdvanced(
            2, id, key, r.nextIndex, r.currentObservationChain, r.complete
        );
    }

    function bundleEvidence(bytes32 id)
        external
        view
        override
        returns (PolicyBundle.BundleEvidence memory)
    {
        if (!_progress[id].complete) revert T.InventoryIncomplete();
        return _completed[id];
    }

    function requireCoverage(StreamFinalityScope calldata scope, bytes32 id, bytes32 expectedHash)
        external
        view
        override
        returns (PolicyBundle.BundleEvidence memory result)
    {
        result = _completed[id];
        if (
            result.coverage.bundleCoverageHash == 0
                || result.coverage.renderCriticalEvidenceHash != expectedHash
                || keccak256(abi.encode(result.scope)) != keccak256(abi.encode(scope))
        ) {
            revert T.InventoryIncomplete();
        }
        bytes32 environment = _environment();
        B.Refresh storage r = _refreshes[_refreshId(id, environment)];
        if (
            !r.complete || r.environmentHash != environment
                || r.nextIndex != result.coverage.itemCount
        ) {
            revert T.InventoryIncomplete();
        }
    }

    /// @notice Full per-entry diagnostic, without the immutable-STOP cache shortcut.
    /// @dev Cost grows with complete item count; this is not the bounded provider entrypoint.
    function requireFullCurrentCoverage(bytes32 id)
        external
        view
        returns (PolicyBundle.BundleEvidence memory)
    {
        if (!_progress[id].complete) {
            revert T.InventoryIncomplete();
        }
        _environment();
        for (uint256 i; i < _items[id].length; ++i) {
            Reads.current(
                _dependencies,
                _inventories[id].inventory.artistId,
                _items[id][i],
                _admissions[id][i]
            );
        }
        return _completed[id];
    }

    function progress(bytes32 id) external view returns (B.Progress memory) {
        return _progress[id];
    }

    function refresh(bytes32 key) external view returns (B.Refresh memory) {
        return _refreshes[key];
    }

    function admittedItem(bytes32 id, uint64 index)
        external
        view
        returns (T.Item memory, B.Admission memory)
    {
        return (_items[id][index], _admissions[id][index]);
    }

    function _segment(bytes32 id, uint64 index) private view returns (T.Segment memory result) {
        if (index >= _inventories[id].inventory.segmentCount) revert T.InvalidInventorySegment();
        bytes memory raw = IO.fixedRead(
            _dependencies.targets[2],
            abi.encodeCall(
                IStreamScopedPolicyRenderCriticalInventoryV2.inventorySegment, (id, index)
            ),
            128,
            _dependencies.readGas
        );
        result = abi.decode(raw, (T.Segment));
        IO.canonical(_dependencies.targets[2], raw, abi.encode(result));
    }

    /// @dev The shared reader below uses only profile-neutral dependency getters and original
    /// archive bytes. Authenticate the V2 producer before decoding its full Evidence.
    function _environment() private view returns (bytes32) {
        address inventory = _dependencies.targets[2];
        IO.pin(inventory, _dependencies.codeHashes[2]);
        if (
            IO.word(
                        inventory,
                        abi.encodeWithSelector(
                            bytes4(0x01ffc9a7),
                            type(IStreamScopedPolicyRenderCriticalInventoryV2).interfaceId
                        ),
                        _dependencies.readGas
                    ) != bytes32(uint256(1))
                || IO.word(
                        inventory,
                        abi.encodeCall(
                            IStreamScopedPolicyRenderCriticalInventoryV2.scopedPolicyInventoryProfile,
                            ()
                        ),
                        _dependencies.readGas
                    ) != Scoped.PROFILE
        ) revert T.InventorySourceChanged();
        return Reads.environment(_dependencies);
    }

    function _refreshId(bytes32 id, bytes32 environment) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                PolicyBundle.REFRESH_DOMAIN,
                block.chainid,
                address(this),
                dependencyHash,
                id,
                environment
            )
        );
    }

    function _observation(bytes32 previous, uint64 index, bytes32 itemHash, bytes32 observation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(PolicyBundle.OBSERVATION_DOMAIN, previous, index, itemHash, observation)
        );
    }
}
