// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as T
} from "../../interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";
import {
    IStreamGovernedParameterAuthority as Authority
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

/// @notice Target-side exact Governance V2 context for the terminal one-way source catalogue seal.
/// @dev ADR0004 class2 TERMINAL_FREEZE includes its independent veto window. This is a permanent
/// source binding with no rebind/unbind; it does not reuse that class for ordinary parameter raises.
library StreamCurrentAuthorityDeferredPolicyGovernanceV2 {
    function initialize(Native.Config memory original, bytes32 scopedHash, bytes32 graphHash)
        public
        view
        returns (T.Capability memory c)
    {
        address metadata = original.targets[1];
        if (
            original.chainId != block.chainid || original.readGas < 50000 || scopedHash == 0
                || graphHash == 0
        ) revert T.InvalidCollectionPolicyBinding();
        pin(metadata, original.codeHashes[1]);
        bytes memory raw = Reads.read(
            metadata, abi.encodeWithSignature("governanceAuthority()"), 32, original.readGas
        );
        c.authority = abi.decode(raw, (address));
        if (keccak256(raw) != keccak256(abi.encode(c.authority))) {
            revert T.InvalidCollectionPolicyBinding();
        }
        c.authorityCodeHash = abi.decode(
            Reads.read(
                metadata, abi.encodeWithSignature("executorCodeHash()"), 32, original.readGas
            ),
            (bytes32)
        );
        pin(c.authority, c.authorityCodeHash);
        if (
            abi.decode(
                    Reads.read(
                        c.authority,
                        abi.encodeCall(Authority.isStreamGovernedParameterAuthority, ()),
                        32,
                        original.readGas
                    ),
                    (uint256)
                ) != 1
        ) revert T.CollectionPolicyBindingGovernance();
        c.originalHash = keccak256(abi.encode(original));
        c.scopedHash = scopedHash;
        c.graphHash = graphHash;
        c.capabilityHash = T.hashCapability(block.chainid, address(this), c);
    }

    function requireExecution(
        T.Capability memory capability,
        T.Transition memory expected,
        uint256 readGas
    ) public view returns (bytes32 actionId) {
        pin(capability.authority, capability.authorityCodeHash);
        if (
            msg.sender != capability.authority || capability.capabilityHash == 0
                || capability.capabilityHash
                    != T.hashCapability(block.chainid, address(this), capability)
        ) revert T.CollectionPolicyBindingGovernance();
        bytes memory raw = Reads.read(
            capability.authority, abi.encodeCall(Authority.currentAction, ()), 192, readGas
        );
        (
            bool executing,
            bytes32 id,
            uint8 actionClass,
            bytes32 scopeHash,
            bytes32 oldValueHash,
            bytes32 newValueHash
        ) = abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id == 0 || actionClass != T.ACTION_CLASS
                || scopeHash != expected.scopeHash || oldValueHash != expected.oldValueHash
                || newValueHash != expected.newValueHash
                || keccak256(raw)
                    != keccak256(
                        abi.encode(
                            true,
                            id,
                            T.ACTION_CLASS,
                            expected.scopeHash,
                            expected.oldValueHash,
                            expected.newValueHash
                        )
                    )
        ) revert T.CollectionPolicyBindingGovernance();
        return id;
    }

    function pin(address target, bytes32 hash) internal view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert T.CollectionPolicyBindingDependency(target);
        }
    }
}
