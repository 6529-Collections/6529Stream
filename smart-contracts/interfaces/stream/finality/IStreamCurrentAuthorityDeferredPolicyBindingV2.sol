// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as T
} from "./StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../domains/finality/StreamFinalityNativeProviderReads.sol";

interface IStreamCurrentAuthorityDeferredPolicyBindingV2 is IERC165 {
    event CollectionPolicyBound(
        bytes32 indexed capabilityHash,
        bytes32 indexed bindingHash,
        bytes32 indexed actionId,
        bytes32 proposalHash
    );
    function deferredPolicyBindingProfile() external pure returns (bytes32);
    function policyBindingCapability() external view returns (T.Capability memory);
    function policyBindingHash() external view returns (bytes32);
    function requirePolicyBinding() external view returns (T.Receipt memory);
    function bindingTransition(Native.Config calldata policy, address output, bytes32 outputHash)
        external
        view
        returns (T.Transition memory);
    function bindCollectionPolicy(Native.Config calldata policy, address output, bytes32 outputHash)
        external;
}
