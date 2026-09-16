// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamEscrowRecoveryState as S } from "./StreamEscrowRecoveryState.sol";
import {
    StreamEscrowRecoveryTypes as R
} from "../../interfaces/stream/revenue/StreamEscrowRecoveryTypes.sol";
import {
    IStreamGasParameterHost as G
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Original escrow EIP-712 consent and cap-independent direct recording.
/// @dev Accounts may pre-consent to a fully specified recovery ID before its delayed
///      scheduling. That confers no sweep authority and never replaces affected-set proof.
library StreamEscrowRecoveryConsent {
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant ERC1271_GAS = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
    uint256 private constant HALF_ORDER =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
    bytes4 private constant MAGIC = 0x1626ba7e;

    event EscrowRecoveryConsentRecorded(
        uint16 schemaVersion, bytes32 indexed recoveryId, address indexed account, bytes32 nonce
    );
    event EscrowRecoveryConsentRevoked(
        uint16 schemaVersion, bytes32 indexed recoveryId, address indexed account
    );

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256("6529StreamRevenueEscrow"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function digest(address account, bytes32 id, bytes32 nonce, uint64 deadline)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                domainSeparator(),
                keccak256(abi.encode(R.CONSENT_TYPEHASH, account, id, nonce, deadline))
            )
        );
    }

    function submit(
        address account,
        bytes32 id,
        bytes32 nonce,
        uint64 deadline,
        bytes calldata signature
    ) public {
        _available(account, id, nonce);
        if (
            deadline < block.timestamp
                || !_valid(account, digest(account, id, nonce, deadline), signature)
        ) {
            revert S.EscrowRecoveryConsentInvalid();
        }
        _record(account, id, nonce);
    }

    function record(bytes32 id, bytes32 nonce) public {
        _available(msg.sender, id, nonce);
        _record(msg.sender, id, nonce);
    }

    function revoke(bytes32 id) public {
        S.State storage s = S.state();
        if (
            s.recoveries[id].record.status == R.EscrowRecoveryStatus.EXECUTED
                || !s.consents[id][msg.sender]
        ) revert S.EscrowRecoveryConsentInvalid();
        s.consents[id][msg.sender] = false;
        emit EscrowRecoveryConsentRevoked(1, id, msg.sender);
    }

    function recorded(bytes32 id, address account) public view returns (bool) {
        return S.state().consents[id][account];
    }

    function nonceUsed(address account, bytes32 nonce) public view returns (bool) {
        return S.state().usedConsentNonces[account][nonce];
    }

    function _available(address account, bytes32 id, bytes32 nonce) private view {
        S.State storage s = S.state();
        if (
            account == address(0) || id == 0 || s.usedConsentNonces[account][nonce]
                || s.recoveries[id].record.status == R.EscrowRecoveryStatus.EXECUTED
                || s.recoveries[id].record.status == R.EscrowRecoveryStatus.CANCELLED
        ) {
            revert S.EscrowRecoveryConsentInvalid();
        }
    }

    function _record(address account, bytes32 id, bytes32 nonce) private {
        S.State storage s = S.state();
        s.usedConsentNonces[account][nonce] = true;
        s.consents[id][account] = true;
        emit EscrowRecoveryConsentRecorded(1, id, account, nonce);
    }

    // Same EOA/EIP-2098/EIP-7702 and exact-word ERC-1271 rules as the original
    // revenue release authorization. Only its domain and governed host differ.
    function _valid(address account, bytes32 hash, bytes calldata signature)
        private
        view
        returns (bool)
    {
        uint256 size = account.code.length;
        bool delegated;
        if (size == 23) {
            uint256 prefix;
            assembly ("memory-safe") {
                let ptr := mload(0x40)
                extcodecopy(account, ptr, 0, 3)
                prefix := shr(232, mload(ptr))
            }
            delegated = prefix == 0xef0100;
        }
        if (size == 0 || delegated) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            if (signature.length == 65) {
                assembly ("memory-safe") {
                    r := calldataload(signature.offset)
                    s := calldataload(add(signature.offset, 32))
                    v := byte(0, calldataload(add(signature.offset, 64)))
                }
            } else if (signature.length == 64) {
                bytes32 vs;
                assembly ("memory-safe") {
                    r := calldataload(signature.offset)
                    vs := calldataload(add(signature.offset, 32))
                }
                s = vs & bytes32(type(uint256).max >> 1);
                v = uint8(uint256(vs) >> 255) + 27;
            }
            if (
                uint256(s) <= HALF_ORDER && (v == 27 || v == 28)
                    && ecrecover(hash, v, r, s) == account
            ) return true;
            if (size == 0) return false;
        }
        bytes memory payload = abi.encodeWithSelector(MAGIC, hash, signature);
        uint256 cap = G(address(this)).gasParameter(ERC1271_GAS);
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 20_000) {
            revert S.EscrowRecoveryConsentInvalid();
        }
        bool ok;
        uint256 result;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(cap, account, add(payload, 32), mload(payload), ptr, 32)
            ok := and(ok, eq(returndatasize(), 32))
            result := mload(ptr)
        }
        return ok && result == uint256(uint32(MAGIC)) << 224;
    }
}
