// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityProfileSourceReads as Original
} from "./StreamFinalityProfileSourceReads.sol";
import {
    IStreamFinalityProfileSources as I
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPolicyContentRootPublicationV2 as Policy
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    IStreamPolicyOutputManifestV2 as Output
} from "../../interfaces/stream/finality/IStreamPolicyOutputManifestV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as Checkpoint
} from "../../interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamStaticMetadataRouter as Static
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamFinalityBoundedReads } from "./StreamFinalityBoundedReads.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as T
} from "../../interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Acyclic source selection for the distinct once-bound collection-policy capability.
/// @dev Original and scoped profiles are fixed before Finality deployment. A canonical policy
/// root cannot fall through to the original profile while its source binding is pending.
library StreamFinalityDeferredProfileSourceReadsV2 {
    struct Context {
        address core;
        address router;
        bytes32 routerCodeHash;
        uint256 chainId;
        uint256 readGas;
        address policyOutput;
        bytes32 policyOutputCodeHash;
        I.Profile[3] profiles;
        bool policyBound;
    }
    error InvalidFinalitySourceProfile();
    error FinalitySourceDependency(address target);

    function profileHash(uint8 index) internal pure returns (bytes32) {
        return Original.profileHash(index);
    }

    function validate(Context memory c) internal pure {
        if (
            c.core == address(0) || c.router == address(0) || c.routerCodeHash == 0
                || c.chainId == 0 || c.readGas < 50000
        ) revert InvalidFinalitySourceProfile();
        for (uint8 i; i < (c.policyBound ? 3 : 2); ++i) {
            I.Profile memory p = c.profiles[i];
            if (
                p.profileHash != profileHash(i) || p.configurationHash == 0
                    || p.referenceRender == address(0) || p.referenceRenderCodeHash == 0
                    || p.snapshots == address(0) || p.snapshotsCodeHash == 0
                    || p.entropyFactory == address(0) || p.entropyFactoryCodeHash == 0
            ) revert InvalidFinalitySourceProfile();
        }
        if (c.policyBound) {
            if (c.policyOutput == address(0) || c.policyOutputCodeHash == 0) {
                revert InvalidFinalitySourceProfile();
            }
        } else {
            I.Profile memory empty;
            if (
                c.policyOutput != address(0) || c.policyOutputCodeHash != 0
                    || keccak256(abi.encode(c.profiles[2])) != keccak256(abi.encode(empty))
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
            index = _policy(c, scope.collectionId) ? 2 : 0;
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

    function _policy(Context memory c, uint256 cid) private view returns (bool) {
        uint256 supported = abi.decode(
            _read(
                c,
                c.router,
                abi.encodeCall(IERC165.supportsInterface, (type(Policy).interfaceId)),
                32
            ),
            (uint256)
        );
        if (supported > 1) revert InvalidFinalitySourceProfile();
        if (supported == 0) return false;
        bytes32 head = abi.decode(
            _read(c, c.router, abi.encodeCall(Root.collectionContentRootHead, (cid)), 32), (bytes32)
        );
        if (head == 0) return false;
        bytes memory raw =
            _read(c, c.router, abi.encodeCall(Policy.policyContentRootBinding, (head)), 544);
        Policy.Binding memory b = abi.decode(raw, (Policy.Binding));
        if (keccak256(raw) != keccak256(abi.encode(b))) revert InvalidFinalitySourceProfile();
        if (b.profileId == 0) {
            Policy.Binding memory empty;
            if (keccak256(raw) != keccak256(abi.encode(empty))) {
                revert InvalidFinalitySourceProfile();
            }
            return false;
        }
        if (
            b.profileId != keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
                || b.outputManifest == address(0) || b.outputManifestCodeHash == 0
                || b.checkpoint == address(0) || b.checkpointCodeHash == 0
                || b.entropySourceSet == address(0) || b.entropySourceSetCodeHash == 0
                || b.checkpointHash == 0 || b.checkpointStateHash == 0 || b.outputRoot == 0
                || b.inventoryHash == 0 || b.policyChainHash == 0 || b.outputSchemaHash == 0
                || b.outputCanonicalizationHash == 0 || b.leafSchemaHash == 0
                || b.rootSchemaHash == 0 || b.rootCanonicalizationHash == 0
        ) revert InvalidFinalitySourceProfile();
        if (!c.policyBound) revert T.CollectionPolicyPending();
        if (
            b.outputManifest != c.policyOutput || b.outputManifestCodeHash != c.policyOutputCodeHash
        ) revert InvalidFinalitySourceProfile();
        _pin(c.policyOutput, c.policyOutputCodeHash);
        _pin(b.checkpoint, b.checkpointCodeHash);
        _pin(b.entropySourceSet, b.entropySourceSetCodeHash);
        if (
            abi.decode(
                        _read(c, c.policyOutput, abi.encodeCall(Output.contentCheckpoint, ()), 32),
                        (address)
                    ) != b.checkpoint
                || abi.decode(
                        _read(c, b.checkpoint, abi.encodeCall(Checkpoint.entropySourceSet, ()), 32),
                        (address)
                    ) != b.entropySourceSet
        ) revert InvalidFinalitySourceProfile();
        _static(c, cid);
        return true;
    }

    function _static(Context memory c, uint256 cid) private view {
        bytes memory raw =
            _read(c, c.router, abi.encodeCall(Static.staticMetadataActivation, (cid)), 96);
        (bytes32 record, uint64 revision, bytes32 overridesHead) =
            abi.decode(raw, (bytes32, uint64, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(record, revision, overridesHead)) || record == 0
                || revision == 0
        ) revert InvalidFinalitySourceProfile();
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
