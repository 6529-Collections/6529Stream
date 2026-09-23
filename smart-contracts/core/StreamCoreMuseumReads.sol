// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamConditionSources as Sources
} from "../interfaces/stream/metadata/IStreamConditionSources.sol";
import {
    IStreamConservationFloor as Floor
} from "../interfaces/stream/metadata/IStreamConservationFloor.sol";
import {
    IStreamGasParameterHost
} from "../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IERC165 } from "../vendor/openzeppelin/IERC165.sol";

/// @notice Bounded one-time deployment identity checks; no storage or mutation authority.
library StreamCoreMuseumReads {
    uint256 private constant CAP = 100_000;
    uint256 private constant RESERVE = 20_000;

    function isConditionSources(address candidate, address core, address executor)
        public
        view
        returns (bool)
    {
        return _isSource(candidate, core, executor, type(Sources).interfaceId);
    }

    function isConservationFloor(address candidate, address core, address executor)
        public
        view
        returns (bool)
    {
        return _isSource(candidate, core, executor, type(Floor).interfaceId);
    }

    // Both immutable source owners expose the same fixed identity/head selectors.
    // The requested interface ID keeps the two admitted capabilities distinct.
    function _isSource(address candidate, address core, address executor, bytes4 interfaceId)
        private
        view
        returns (bool)
    {
        if (candidate.code.length == 0) return false;
        // Delegated EOAs do not provide an immutable catalog implementation.
        if (candidate.code.length == 23) {
            bytes memory code = candidate.code;
            if (code[0] == 0xef && code[1] == 0x01 && code[2] == 0x00) return false;
        }
        if (
            !_equals(
                    candidate,
                    abi.encodeCall(IERC165.supportsInterface, (interfaceId)),
                    1
                ) || !_equals(candidate, abi.encodeCall(Sources.core, ()), uint256(uint160(core)))
                || !_equals(
                    candidate, abi.encodeCall(Sources.coreCodeHash, ()), uint256(core.codehash)
                )
                || !_equals(
                    candidate,
                    abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ()),
                    uint256(uint160(executor))
                )
                || !_equals(
                    candidate,
                    abi.encodeCall(Sources.executorCodeHash, ()),
                    uint256(executor.codehash)
                )
                || !_equals(candidate, abi.encodeCall(Sources.deploymentChainId, ()), block.chainid)
        ) return false;
        bytes memory data = abi.encodeCall(Sources.sourceSetHead, ());
        if (gasleft() <= CAP + CAP / 63 + RESERVE) return false;
        uint256 count;
        bytes32 head;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let p := mload(0x40)
            ok := staticcall(CAP, candidate, add(data, 32), mload(data), p, 64)
            size := returndatasize()
            count := mload(p)
            head := mload(add(p, 32))
        }
        return ok && size == 64 && count <= type(uint64).max && head != 0;
    }

    function _equals(address target, bytes memory data, uint256 expected)
        private
        view
        returns (bool)
    {
        if (gasleft() <= CAP + CAP / 63 + RESERVE) return false;
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            let p := mload(0x40)
            ok := staticcall(CAP, target, add(data, 32), mload(data), p, 32)
            size := returndatasize()
            word := mload(p)
        }
        return ok && size == 32 && word == expected;
    }
}
