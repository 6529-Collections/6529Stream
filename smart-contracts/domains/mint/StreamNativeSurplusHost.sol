// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamNativeSurplus } from "../../interfaces/stream/mint/IStreamNativeSurplus.sol";
import { StreamNativeSurplus } from "./StreamNativeSurplus.sol";

/// @notice Storage-free transport. Each concrete host uses its original shared guard for sweep.
abstract contract StreamNativeSurplusHost is IStreamNativeSurplus {
    function _nativeSurplusPrivateRegistry() internal pure virtual returns (bool) {
        return false;
    }
    function _nativeSurplusOwed() internal view virtual returns (uint256);

    function nativeSurplusState() external view override returns (NativeSurplusState memory) {
        bytes memory out = _nativeSurplusRead();
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function nativeSurplusQuote(uint256 amount, bytes32 reasonHash)
        external
        view
        override
        returns (NativeSurplusQuote memory)
    {
        bytes memory out = _nativeSurplusRead();
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function nativeSurplusActionUsed(bytes32 id) external view override returns (bool) {
        bytes memory out = _nativeSurplusRead();
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function _nativeSurplusRead() private view returns (bytes memory) {
        return
            StreamNativeSurplus.read(
                _nativeSurplusPrivateRegistry(), _nativeSurplusOwed(), msg.data
            );
    }

    function _sweepNativeSurplus(uint256 amount, bytes32 reasonHash)
        internal
        returns (uint256 swept)
    {
        uint256 owed = _nativeSurplusOwed();
        swept = StreamNativeSurplus.sweep(_nativeSurplusPrivateRegistry(), owed, amount, reasonHash);
        if (_nativeSurplusOwed() != owed) revert NativeSurplusCallbackChanged();
    }
}
