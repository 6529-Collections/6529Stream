// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "./IStreamFinalityEntropyPolicySourceSet.sol";
import { StreamTokenContentLeaf } from "../metadata/StreamTokenContentTypes.sol";

/// @notice Distinct V2 current output evidence for a complete TOKEN/RELEASE/SEASON scope and frozen V1/V2 policy set.
/// @dev This is current-byte evidence, not publication authority, archive coverage or a finality mode decision.
interface IStreamScopedPolicyContentCheckpointV2 {
    struct Plan {
        bytes32 selectionId;
        bytes32 selectionHash;
        bytes32 inventoryHash;
        bytes32 policyChainHash;
        StreamFinalityScope scope;
        uint64 tokenCount;
        uint64 nextIndex;
        bytes32 leafChainHash;
        bytes32 contentRoot;
        bytes32 outputRoot;
    }

    struct Payload {
        uint256 tokenId;
        bytes image;
        bytes animation;
    }

    struct Output {
        StreamTokenContentLeaf leaf;
        bytes32 selectionRowHash;
        bytes32 sourceFactsHash;
        bytes32 htmlHash;
        E.TokenReadiness entropy;
        bytes32 terminalAdmissionHash;
    }
    error InvalidStaticContentConfiguration();
    error StaticContentParentGas(uint256 available, uint256 required);
    error StaticContentChanged(bytes32 id);
    error StaticContentPayload(uint256 tokenId);
    error StaticContentBatch(uint256 count);
    error StaticContentIncomplete(bytes32 id);
    error StaticContentIndex(uint256 index);
    event StaticContentStarted(uint16 schemaVersion, bytes32 indexed id, bytes32 salt, Plan plan);
    event StaticContentAppended(
        uint16 schemaVersion,
        bytes32 indexed id,
        uint64 indexed index,
        Output output,
        bytes32 leafHash
    );
    event StaticContentCompleted(
        uint16 schemaVersion,
        bytes32 indexed id,
        bytes32 contentRoot,
        bytes32 outputRoot,
        uint64 count
    );
    function core() external view returns (address);
    function scopedPolicyProfile() external pure returns (bytes32);
    function sourceFactory() external view returns (address);
    function factoryDependenciesHash() external view returns (bytes32);
    function metadataRouter() external view returns (address);
    function selectionCheckpoint() external view returns (address);
    function entropySourceSet() external view returns (address);
    function terminalReadiness() external view returns (address);
    function begin(bytes32 selectionId, bytes32 salt) external returns (bytes32);
    function append(bytes32 id, Payload[] calldata payloads) external;
    function checkpoint(bytes32 id) external view returns (Plan memory);
    function outputAt(bytes32 id, uint256 index) external view returns (Output memory);
    /// @notice Re-renders every original row; live Artist/lifecycle changes cannot masquerade as current output.
    function requireCurrentCheckpoint(bytes32 id) external view returns (Plan memory);
}
