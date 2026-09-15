// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamNativeSaleCredits
} from "../../interfaces/stream/mint/IStreamNativeSaleCredits.sol";
import { StreamNativeSaleCreditReads } from "./StreamNativeSaleCreditReads.sol";

/// @notice Storage-free, terminal read transport through a fixed linked worker.
abstract contract StreamNativeSaleCreditHost is IStreamNativeSaleCredits {
    function nativeSaleCreditState() external view override returns (CreditState memory) {
        bytes memory out = _nativeSaleCreditRead();
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function nativeSaleCreditPage(uint256, uint256, uint256)
        external
        view
        override
        returns (CreditPage memory)
    {
        bytes memory out = _nativeSaleCreditRead();
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }
    function _nativeSaleCreditRead() internal view virtual returns (bytes memory);
}
