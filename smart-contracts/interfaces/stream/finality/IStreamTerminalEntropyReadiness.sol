// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "./IStreamFinalityEntropyPolicySourceSet.sol";

/// @notice Additive reference/readiness evidence for the governed terminal STATIC profile only.
interface IStreamTerminalEntropyReadiness {
    struct Evidence {
        E.TokenReadiness entropy;
        bytes32 configRecordHash;
        bytes32 versionKey;
        address renderer;
        bytes32 rendererCodeHash;
        address registry;
        bytes32 registryCodeHash;
        bytes32 admissionHash;
        bytes32 policyChainHash;
        bytes32 evidenceHash;
    }
    function requireTerminalRenderReady(uint256 tokenId) external view returns (Evidence memory);
}
