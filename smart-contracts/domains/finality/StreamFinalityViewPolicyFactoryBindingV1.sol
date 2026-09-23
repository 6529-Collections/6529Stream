// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as V
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Constructor-recipe policy factory admission, without a scope, plan, or source set.
library StreamFinalityViewPolicyFactoryBindingV1 {
    function validate(
        Native.Config memory original,
        address factory,
        bytes32 codeHash,
        bytes32 dependenciesHash
    ) public view {
        if (
            original.chainId != block.chainid || factory.code.length == 0 || codeHash == 0
                || factory.codehash != codeHash
        ) revert V.ViewPreservationBindingDependency(factory);
        uint256 cap = original.readGas;
        if (
            _word(
                        factory,
                        abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)),
                        cap
                    ) != bytes32(uint256(1))
                || _word(factory, abi.encodeCall(Factory.scopedPolicyFactoryProfile, ()), cap)
                    != keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) revert V.InvalidViewPreservationBinding();
        bytes memory raw = Reads.read(factory, abi.encodeCall(Factory.dependencies, ()), 352, cap);
        Policies.Dependencies memory d = abi.decode(raw, (Policies.Dependencies));
        if (
            dependenciesHash == 0 || keccak256(raw) != dependenciesHash
                || dependenciesHash != keccak256(abi.encode(d)) || d.chainId != original.chainId
        ) revert V.InvalidViewPreservationBinding();
        uint256[3] memory indexes = [uint256(0), 1, 3];
        string[4] memory getters =
            [string("core()"), "metadataHost()", "scopeMembershipHost()", "coordinatorInventory()"];
        for (uint256 i; i < 4; ++i) {
            if (
                _word(factory, abi.encodeWithSignature(getters[i]), cap)
                    != bytes32(uint256(uint160(d.targets[i])))
            ) revert V.InvalidViewPreservationBinding();
            if (
                i < 3
                    && (d.targets[i] != original.targets[indexes[i]]
                        || d.codeHashes[i] != original.codeHashes[indexes[i]])
            ) revert V.InvalidViewPreservationBinding();
        }
        Policies.validateDependencies(d);
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (bytes32) {
        return abi.decode(Reads.read(target, input, 32, cap), (bytes32));
    }
}
