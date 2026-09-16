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
import "../../interfaces/stream/preservation/IStreamRenderCriticalInventory.sol";
import "../../interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol";

/// @notice Complete role-qualified archival admission for one actual deterministic inventory.
/// @dev Explicit immutable-STOP aggregate profile: every whole-byte part/state bundle is
/// checked fully at admission/refresh, under one complete environment/epoch. Ordinary EVM
/// STOP-only code immutability permits bounded current use. The full slow diagnostic retains
/// stronger per-call byte/runtime checks (including artificial test-state code mutation).
contract StreamBundleArchiveCoverage is IStreamBundleArchiveCoverage {
    bytes32 public constant PROFILE = keccak256("6529STREAM_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1");
    B.Dependencies private _dependencies;
    bytes32 public dependencyHash;
    mapping(bytes32 => T.Evidence) private _inventories;
    mapping(bytes32 => B.Progress) private _progress;
    mapping(bytes32 => T.Item[]) private _items;
    mapping(bytes32 => B.Admission[]) private _admissions;
    mapping(bytes32 => T.BundleEvidence) private _completed;
    mapping(bytes32 => B.Refresh) private _refreshes;
    mapping(bytes32 => bytes32) private _admissionObservation;

    event BundleCoverageStarted(
        bytes32 indexed inventoryPlan, bytes32 indexed renderCriticalEvidenceHash
    );
    event BundleItemAdmitted(
        bytes32 indexed inventoryPlan, uint64 indexed index, bytes32 itemHash, B.Admission admission
    );
    event BundleCoverageCompleted(
        bytes32 indexed inventoryPlan, bytes32 indexed bundleCoverageHash, T.BundleEvidence evidence
    );
    event BundleRefreshAdvanced(
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
        bytes32 environment = Reads.environment(_dependencies);
        if (_inventories[id].planId != 0) return;
        bytes memory raw = IO.fixedRead(
            _dependencies.targets[2],
            abi.encodeCall(IStreamRenderCriticalInventory.inventoryEvidence, (id)),
            608,
            _dependencies.readGas
        );
        T.Evidence memory e = abi.decode(raw, (T.Evidence));
        IO.canonical(_dependencies.targets[2], raw, abi.encode(e));
        if (
            e.planId != id || id == 0 || e.renderCriticalEvidenceHash == 0 || e.segmentCount == 0
                || e.itemCount == 0 || e.artistId == 0 || e.collectionId == 0 || e.scopeSubject == 0
        ) revert T.InventoryIncomplete();
        _inventories[id] = e;
        _progress[id].environmentHash = environment;
        _progress[id].nextLink = _segment(id, 0).firstLink;
        emit BundleCoverageStarted(id, e.renderCriticalEvidenceHash);
    }

    function coverNext(bytes32 id, T.Item calldata item, bytes32 nextLink, B.Proof calldata proof)
        external
    {
        B.Progress storage p = _progress[id];
        if (_inventories[id].planId == 0 || p.complete) revert T.InventoryIncomplete();
        T.Segment memory s = _segment(id, p.segmentIndex);
        if (Chains.link(s.key, s.itemCount, p.segmentItemIndex, item, nextLink) != p.nextLink) {
            revert T.InvalidInventorySegment();
        }
        bytes32 environment = Reads.environment(_dependencies);
        (B.Admission memory a, bytes32 observation) =
            Reads.admit(_dependencies, _inventories[id].artistId, item, proof);
        if (Reads.environment(_dependencies) != environment) revert T.InventorySourceChanged();
        if (environment != p.environmentHash) p.environmentHash = 0;
        bytes32 itemHash = Chains.itemHash(item);
        p.evidenceChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_BUNDLE_COVERED_ITEM_V1"),
                p.evidenceChainHash,
                id,
                p.itemCount,
                itemHash,
                a
            )
        );
        _admissionObservation[id] =
            _observation(_admissionObservation[id], p.itemCount, itemHash, observation);
        _items[id].push(item);
        _admissions[id].push(a);
        emit BundleItemAdmitted(id, p.itemCount, itemHash, a);
        p.itemCount += 1;
        p.segmentItemIndex += 1;
        p.nextLink = nextLink;
        if (p.segmentItemIndex == s.itemCount) _finishSegment(id, s);
    }

    /// @notice A source-authenticated explicit empty segment is still consumed in exact order.
    function coverEmptySegment(bytes32 id) external {
        B.Progress storage p = _progress[id];
        if (_inventories[id].planId == 0 || p.complete) revert T.InventoryIncomplete();
        T.Segment memory s = _segment(id, p.segmentIndex);
        if (s.itemCount != 0 || s.firstLink != 0 || p.segmentItemIndex != 0 || p.nextLink != 0) {
            revert T.InvalidInventorySegment();
        }
        if (Reads.environment(_dependencies) != p.environmentHash) p.environmentHash = 0;
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
        if (p.segmentIndex != _inventories[id].segmentCount) {
            p.nextLink = _segment(id, p.segmentIndex).firstLink;
            return;
        }
        T.Evidence storage e = _inventories[id];
        if (p.itemCount != e.itemCount || p.segmentChainHash != e.segmentChainHash) {
            revert T.InventoryIncomplete();
        }
        p.complete = true;
        T.BundleEvidence memory result =
            T.BundleEvidence(id, e.renderCriticalEvidenceHash, p.itemCount, p.evidenceChainHash, 0);
        result.bundleCoverageHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_BUNDLE_ARCHIVE_COVERAGE_V1"),
                block.chainid,
                address(this),
                dependencyHash,
                PROFILE,
                e,
                result
            )
        );
        _completed[id] = result;
        if (p.environmentHash != 0) {
            bytes32 key = _refreshId(id, p.environmentHash);
            _refreshes[key] =
                B.Refresh(p.environmentHash, p.itemCount, _admissionObservation[id], true);
        }
        emit BundleCoverageCompleted(id, result.bundleCoverageHash, result);
    }

    /// @notice Canonical progress is keyed by environment; another caller cannot reset it.
    function beginRefresh(bytes32 id) external returns (bytes32 key) {
        if (!_progress[id].complete) revert T.InventoryIncomplete();
        bytes32 environment = Reads.environment(_dependencies);
        key = _refreshId(id, environment);
        if (_refreshes[key].environmentHash == 0) _refreshes[key].environmentHash = environment;
    }

    function refreshNext(bytes32 id, uint64 expectedIndex) external {
        if (!_progress[id].complete) revert T.InventoryIncomplete();
        bytes32 environment = Reads.environment(_dependencies);
        bytes32 key = _refreshId(id, environment);
        B.Refresh storage r = _refreshes[key];
        if (
            r.environmentHash != environment || r.complete || r.nextIndex != expectedIndex
                || expectedIndex >= _items[id].length
        ) revert T.InventoryIncomplete();
        bytes32 observation = Reads.current(
            _dependencies,
            _inventories[id].artistId,
            _items[id][expectedIndex],
            _admissions[id][expectedIndex]
        );
        if (Reads.environment(_dependencies) != environment) revert T.InventorySourceChanged();
        r.currentObservationChain = _observation(
            r.currentObservationChain,
            expectedIndex,
            Chains.itemHash(_items[id][expectedIndex]),
            observation
        );
        r.nextIndex = expectedIndex + 1;
        r.complete = r.nextIndex == _completed[id].itemCount;
        emit BundleRefreshAdvanced(id, key, r.nextIndex, r.currentObservationChain, r.complete);
    }

    function bundleEvidence(bytes32 id) external view override returns (T.BundleEvidence memory) {
        if (!_progress[id].complete) revert T.InventoryIncomplete();
        return _completed[id];
    }

    function requireCoverage(bytes32 id, bytes32 expectedHash)
        external
        view
        override
        returns (T.BundleEvidence memory result)
    {
        result = _completed[id];
        if (result.bundleCoverageHash == 0 || result.renderCriticalEvidenceHash != expectedHash) {
            revert T.InventoryIncomplete();
        }
        bytes32 environment = Reads.environment(_dependencies);
        B.Refresh storage r = _refreshes[_refreshId(id, environment)];
        if (!r.complete || r.environmentHash != environment || r.nextIndex != result.itemCount) {
            revert T.InventoryIncomplete();
        }
    }

    /// @notice Full per-entry diagnostic, without the immutable-STOP cache shortcut.
    /// @dev Cost grows with complete item count; this is not the bounded provider entrypoint.
    function requireFullCurrentCoverage(bytes32 id)
        external
        view
        returns (T.BundleEvidence memory)
    {
        if (!_progress[id].complete) {
            revert T.InventoryIncomplete();
        }
        Reads.environment(_dependencies);
        for (uint256 i; i < _items[id].length; ++i) {
            Reads.current(
                _dependencies, _inventories[id].artistId, _items[id][i], _admissions[id][i]
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
        if (index >= _inventories[id].segmentCount) revert T.InvalidInventorySegment();
        bytes memory raw = IO.fixedRead(
            _dependencies.targets[2],
            abi.encodeCall(IStreamRenderCriticalInventory.inventorySegment, (id, index)),
            128,
            _dependencies.readGas
        );
        result = abi.decode(raw, (T.Segment));
        IO.canonical(_dependencies.targets[2], raw, abi.encode(result));
    }

    function _refreshId(bytes32 id, bytes32 environment) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_BUNDLE_REFRESH_V1"),
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
            abi.encode(
                keccak256("6529STREAM_BUNDLE_CURRENT_OBSERVATION_V1"),
                previous,
                index,
                itemHash,
                observation
            )
        );
    }
}
