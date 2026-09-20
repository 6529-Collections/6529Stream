// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamFinalityProfileSources as I
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamStaticMetadataRouter as Static
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    StreamSnapshotDefinitions as OriginalDefinitions
} from "../records/StreamSnapshotDefinitions.sol";
import {
    StreamScopedSnapshotDefinitions as ScopedDefinitions
} from "../records/StreamScopedSnapshotDefinitions.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "./StreamFinalityBoundedReads.sol";

/// @notice Fixed acyclic selector for constructor-owned source profiles.
/// @dev The caller is the actual provider host in delegate context. No caller-supplied profile is
/// accepted by its public endpoint. Selection is not a proof of source currentness or finality.
library StreamFinalityFactoryProfileSourceReadsV2 {
    struct Context {
        address core;
        address router;
        bytes32 routerCodeHash;
        uint256 chainId;
        uint256 readGas;
        I.Profile[2] profiles;
    }
    error InvalidFinalitySourceProfile();
    error FinalitySourceDependency(address target);

    function profileHash(uint8 index) internal pure returns (bytes32) {
        if (index == 0) return OriginalDefinitions.PROFILE_HASH;
        if (index == 1) return ScopedDefinitions.PROFILE_HASH;
        revert InvalidFinalitySourceProfile();
    }

    function validate(Context memory c) internal pure {
        if (
            c.core == address(0) || c.router == address(0) || c.routerCodeHash == 0
                || c.chainId == 0 || c.readGas < 50000
        ) revert InvalidFinalitySourceProfile();
        for (uint8 i; i < 2; ++i) {
            I.Profile memory p = c.profiles[i];
            if (
                p.profileHash != profileHash(i) || p.configurationHash == 0
                    || p.referenceRender == address(0) || p.referenceRenderCodeHash == 0
                    || p.snapshots == address(0) || p.snapshotsCodeHash == 0
                    || p.entropyFactory == address(0) || p.entropyFactoryCodeHash == 0
            ) revert InvalidFinalitySourceProfile();
        }
    }

    function current(Context memory c, StreamFinalityScope memory scope)
        public
        view
        returns (I.Sources memory result)
    {
        validate(c);
        if (c.chainId != block.chainid) revert InvalidFinalitySourceProfile();
        _pin(c.router, c.routerCodeHash);
        StreamMetadataSubjects.scopeSubject(c.chainId, c.core, scope);
        uint8 index;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            index = 0;
        } else if (
            scope.scopeType == StreamFinalityScopeType.TOKEN
                || scope.scopeType == StreamFinalityScopeType.RELEASE
                || scope.scopeType == StreamFinalityScopeType.SEASON
        ) {
            _static(c, scope.collectionId);
            index = 1;
        } else {
            revert InvalidFinalitySourceProfile();
        }
        I.Profile memory p = c.profiles[index];
        _pin(p.referenceRender, p.referenceRenderCodeHash);
        _pin(p.snapshots, p.snapshotsCodeHash);
        _pin(p.entropyFactory, p.entropyFactoryCodeHash);
        result = I.Sources(scope, p);
    }

    function _static(Context memory c, uint256 cid) private view {
        bytes memory raw =
            _read(c, c.router, abi.encodeCall(Static.staticMetadataActivation, (cid)), 96);
        (bytes32 record, uint64 revision, bytes32 overridesHead) =
            abi.decode(raw, (bytes32, uint64, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(record, revision, overridesHead)) || record == 0
                || revision == 0
        ) {
            revert InvalidFinalitySourceProfile();
        }
    }

    function _read(Context memory c, address target, bytes memory input, uint256 size)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityBoundedReads.read(target, input, size, c.readGas);
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert FinalitySourceDependency(target);
        }
    }
}
