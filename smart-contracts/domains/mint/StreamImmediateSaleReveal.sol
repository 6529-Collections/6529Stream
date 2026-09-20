// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import {
    StreamImmediateSaleEntropyPolicy as EntropyPolicy
} from "./StreamImmediateSaleEntropyPolicy.sol";

/// @notice Linked current-coordinator fee funding and failure-isolated AT_MINT requests.
/// @dev The caller owns credits and replay. Fixed-size reads and bounded return copies keep
///      an external provider's returndata out of the parent's allocation budget.
library StreamImmediateSaleReveal {
    event ImmediateRevealAttempt(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bool succeeded,
        bytes32 requestKey,
        uint256 providerRequestId,
        uint256 returnDataSize,
        bytes failurePrefix
    );
    bytes32 private constant _ENTROPY = keccak256("ENTROPY_COORDINATOR");

    function quote(address core, uint256 collectionId)
        public
        view
        returns (IStreamImmediateSaleReveal.RevealQuote memory q)
    {
        uint256[10] memory pointer = abi.decode(
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (_ENTROPY)), 320),
            (uint256[10])
        );
        if (pointer[0] > type(uint160).max) {
            revert IStreamImmediateSaleReveal.SaleRevealDependencyInvalid(core);
        }
        q.coordinator = address(uint160(pointer[0]));
        q.coordinatorCodeHash = bytes32(pointer[1]);
        _requireSelected(core, q);
        uint256[5] memory words = abi.decode(
            _read(
                q.coordinator,
                abi.encodeCall(IStreamRevealFeeEscrow.collectionRevealPolicy, (collectionId)),
                160
            ),
            (uint256[5])
        );
        uint8 terminal = EntropyPolicy.terminalStatus(q.coordinator, collectionId);
        if (terminal == 1) {
            // The canonical DISABLED policy has no reveal promise or fee. Do not invent one.
            if (words[0] != 0 || words[1] != 0 || words[2] != 0 || words[3] != 0 || words[4] != 0) {
                revert IStreamImmediateSaleReveal.SaleRevealDependencyInvalid(q.coordinator);
            }
            return q;
        }
        if (words[0] != 1 || words[1] > 1 || words[3] > type(uint64).max) {
            revert IStreamImmediateSaleReveal.SaleRevealDependencyInvalid(q.coordinator);
        }
        q.policy = IStreamRevealFeeEscrow.CollectionRevealPolicy(
            true, uint8(words[1]), bytes32(words[2]), uint64(words[3]), words[4]
        );
    }

    function preflight(
        IStreamImmediateSaleReveal.RevealQuote memory q,
        uint256 allowance,
        uint256 cap
    ) public view returns (uint256 excess) {
        uint256 fee = q.policy.revealFeePerTokenWei;
        if (allowance < fee) {
            revert IStreamImmediateSaleReveal.SaleRevealFeeBelowRequired(allowance, fee);
        }
        if (q.policy.declared && q.policy.requestMode == 0) _requireGas(cap);
        return allowance - fee;
    }

    /// @dev The pre-mint policy is the transaction's captured fee quote, even if an external
    ///      receiver changes an Operational fee later. Funding is separate from requesting.
    function fundAndAttempt(
        address core,
        uint256 collectionId,
        uint256 tokenId,
        IStreamImmediateSaleReveal.RevealQuote memory q,
        uint256 cap
    ) public {
        _requireSelected(core, q);
        address target = q.coordinator;
        bool terminal = EntropyPolicy.requireTerminalToken(core, target, collectionId, tokenId);
        if (
            !q.policy.declared
                && (!terminal || EntropyPolicy.terminalStatus(target, collectionId) != 1)
        ) {
            revert IStreamImmediateSaleReveal.SaleRevealDependencyInvalid(target);
        }
        uint256 fee = q.policy.revealFeePerTokenWei;
        if (fee != 0) {
            bytes memory readData =
                abi.encodeCall(IStreamRevealFeeEscrow.revealFeeEscrow, (collectionId));
            uint256 beforeEscrow = abi.decode(_read(target, readData, 32), (uint256));
            bytes memory data =
                abi.encodeCall(IStreamRevealFeeEscrow.fundRevealFeeEscrow, (collectionId));
            bool ok;
            uint256 size;
            assembly ("memory-safe") {
                ok := call(gas(), target, fee, add(data, 32), mload(data), 0, 0)
                size := returndatasize()
            }
            if (!ok || size != 0) {
                revert IStreamImmediateSaleReveal.SaleRevealDependencyInvalid(target);
            }
            uint256 afterEscrow = abi.decode(_read(target, readData, 32), (uint256));
            if (afterEscrow != beforeEscrow + fee) {
                revert IStreamImmediateSaleReveal.SaleRevealAccountingMismatch();
            }
        }
        if (!terminal && q.policy.requestMode == 0) {
            _requireGas(cap);
            bytes memory data = abi.encodeCall(IStreamEntropyCoordinator.requestEntropy, (tokenId));
            uint256[2] memory result;
            bool ok;
            uint256 size;
            assembly ("memory-safe") {
                ok := call(cap, target, 0, add(data, 32), mload(data), result, 64)
                size := returndatasize()
            }
            if (ok && size == 64 && result[0] != 0) {
                emit ImmediateRevealAttempt(
                    1, collectionId, tokenId, true, bytes32(result[0]), result[1], size, ""
                );
            } else {
                bytes memory prefix = new bytes(size > 256 ? 256 : size);
                assembly ("memory-safe") { returndatacopy(add(prefix, 32), 0, mload(prefix)) }
                emit ImmediateRevealAttempt(1, collectionId, tokenId, false, 0, 0, size, prefix);
            }
        }
        _requireSelected(core, q);
    }

    function _requireSelected(address core, IStreamImmediateSaleReveal.RevealQuote memory q)
        private
        view
    {
        address target = q.coordinator;
        if (target.code.length == 0 || target.codehash != q.coordinatorCodeHash) {
            revert IStreamImmediateSaleReveal.SaleRevealDependencyInvalid(target);
        }
        uint256[10] memory pointer = abi.decode(
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (_ENTROPY)), 320),
            (uint256[10])
        );
        if (
            pointer[0] != uint256(uint160(target)) || bytes32(pointer[1]) != q.coordinatorCodeHash
                || abi.decode(
                        _read(target, abi.encodeCall(IStreamRevealFeeEscrow.core, ()), 32),
                        (uint256)
                    ) != uint256(uint160(core))
        ) {
            revert IStreamImmediateSaleReveal.SaleRevealDependencyInvalid(target);
        }
    }

    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(raw, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) {
            revert IStreamImmediateSaleReveal.SaleRevealDependencyInvalid(target);
        }
    }

    function _requireGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30_000) {
            revert IStreamImmediateSaleReveal.SaleRevealCallGasInsufficient(cap, available);
        }
    }
}
