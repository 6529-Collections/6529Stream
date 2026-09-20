// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamEntropyFallbackPlan.sol";
import {
    IStreamEntropyPolicyContinuity as Continuity
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyOriginRelay as RelayCapability
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";

/// @notice Exact delayed plans for a complete policy import and atomic entropy cutover.
/// @dev Build each stage from observed state. Save the resulting batch with the original
/// StagePlan journal before signing. These helpers never schedule or broadcast a call.
library StreamEntropyPolicySuccessionPlan {
    bytes32 internal constant ENTROPY = keccak256("ENTROPY_COORDINATOR");

    function begin(
        StreamEntropyCoordinator predecessor,
        StreamEntropyCoordinator candidate,
        bytes32 manifestHash
    ) internal view returns (GenesisBatch memory batch) {
        StreamEntropyFallbackPlan.requirePair(predecessor, candidate);
        Continuity target = Continuity(address(candidate));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.entropyPolicyImportTransition(address(predecessor), manifestHash);
        return _single(
            address(candidate),
            abi.encodeCall(target.beginEntropyPolicyImport, (address(predecessor), manifestHash)),
            scope,
            oldHash,
            newHash
        );
    }

    function seal(StreamEntropyCoordinator candidate) internal view returns (GenesisBatch memory) {
        Continuity target = Continuity(address(candidate));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.entropyPolicyImportSealTransition();
        return _single(
            address(candidate),
            abi.encodeCall(target.sealEntropyPolicyImport, ()),
            scope,
            oldHash,
            newHash
        );
    }

    function admitRoute(
        StreamEntropyCoordinator origin,
        StreamEntropyCoordinator candidate,
        uint256 collectionId
    ) internal view returns (GenesisBatch memory) {
        StreamEntropyFallbackPlan.requirePair(origin, candidate);
        bytes32 importHash = Continuity(address(candidate)).entropyPolicyImport().importHash;
        RelayCapability target = RelayCapability(address(origin));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.entropyRelayAdmissionTransition(collectionId, address(candidate), importHash);
        return _single(
            address(origin),
            abi.encodeCall(
                target.admitEntropyRelay, (collectionId, address(candidate), importHash)
            ),
            scope,
            oldHash,
            newHash
        );
    }

    /// @notice Pointer replacement, activation and the mandatory updated manifest are indivisible.
    /// @dev The candidate's transition is schedulable while SEALED. Its execution requires
    /// Core's exact next pointer revision. Any activation or publication failure reverts all three.
    function cutover(
        StreamCore core,
        StreamModuleRegistry registry,
        StreamEntropyCoordinator predecessor,
        StreamEntropyCoordinator candidate,
        StreamSystemManifest manifest,
        address payload,
        StreamSystemManifestUpdate memory update
    ) internal view returns (GenesisBatch memory batch) {
        StreamCorePointerState memory pointer = StreamCurrentStackPlan.readPointer(core, ENTROPY);
        require(!pointer.frozen && pointer.revision < type(uint64).max, "mutable entropy pointer");
        require(manifest.core() == address(core), "actual system manifest Core");
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        require(
            current.modules.moduleRegistry == address(registry)
                && current.modules.entropyCoordinator == address(predecessor),
            "current manifest dependencies"
        );
        Continuity target = Continuity(address(candidate));
        (uint256 count, uint64 serial, bytes32 digest) =
            Continuity(address(predecessor)).entropyPolicyInventory();
        require(
            target.entropyPolicyImportReady(
                address(predecessor),
                address(predecessor).codehash,
                pointer.revision,
                count,
                serial,
                digest
            ),
            "complete sealed policy import"
        );
        GenesisBatch memory selection =
            StreamEntropyFallbackPlan.selection(core, registry, predecessor, candidate);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.entropyPolicyImportActivationTransition();
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](3);
        batch.callDatas = new bytes[](3);
        batch.calls[0] = selection.calls[0];
        batch.callDatas[0] = selection.callDatas[0];
        batch.callDatas[1] = abi.encodeCall(target.activateEntropyPolicyImport, ());
        batch.calls[1] = StreamCurrentStackPlan.call(
            address(candidate), batch.callDatas[1], scope, oldHash, newHash
        );
        current.modules.entropyCoordinator = address(candidate);
        (batch.calls[2], batch.callDatas[2]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
    }

    /// @notice Sorted additional admissions for import/activation and every ultimate-origin route.
    /// @dev Existing Core pointer and manifest admissions remain required. This list neither
    /// deduplicates historical entries nor extends the catalog; retain the original inventory
    /// and feed only genuine additions to StreamGovernanceCatalogStagePlan.
    function catalogRows(
        StreamEntropyCoordinator candidate,
        StreamEntropyCoordinator[] memory origins,
        bytes32 deploymentHash
    ) internal view returns (GovernanceActionPolicyEntry[] memory rows) {
        require(
            address(candidate).code.length != 0 && deploymentHash != 0, "deployed candidate profile"
        );
        require(origins.length <= 1021, "catalog capacity");
        rows = new GovernanceActionPolicyEntry[](3 + origins.length);
        rows[0] = _row(
            1, address(candidate), Continuity.beginEntropyPolicyImport.selector, deploymentHash
        );
        rows[1] = _row(
            1, address(candidate), Continuity.sealEntropyPolicyImport.selector, deploymentHash
        );
        rows[2] = _row(
            3, address(candidate), Continuity.activateEntropyPolicyImport.selector, deploymentHash
        );
        for (uint256 i; i < origins.length; ++i) {
            StreamEntropyFallbackPlan.requirePair(origins[i], candidate);
            rows[3 + i] = _row(
                1, address(origins[i]), RelayCapability.admitEntropyRelay.selector, deploymentHash
            );
        }
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        for (uint256 i = 1; i < rows.length; ++i) {
            require(_key(rows[i - 1]) != _key(rows[i]), "duplicate origin admission");
        }
    }

    function _row(uint8 actionClass, address target, bytes4 selector, bytes32 deploymentHash)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            actionClass,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(deploymentHash, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _single(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private pure returns (GenesisBatch memory batch) {
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] = StreamCurrentStackPlan.call(target, data, scope, oldHash, newHash);
    }
}
