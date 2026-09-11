// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamSplitWallet.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";

/// @notice Wallet-domain consent and signer-scoped revocation for full-amount releases.
/// @dev Derived wallets must use this same guard around observation and all payment effects.
abstract contract StreamReleaseAuthorization is IStreamSplitWallet, ReentrancyGuard {
    bytes32 public constant RELEASE_AUTHORIZATION_TYPEHASH = keccak256(
        "StreamReleaseAuthorization(address asset,address account,address recipient,uint256 releasableSnapshot,bytes32 nonce,uint64 deadline)"
    );
    bytes32 public constant RELEASE_AUTHORIZATION_REVOCATION_TYPEHASH = keccak256(
        "StreamReleaseAuthorizationRevocation(address account,bytes32 nonce,uint64 deadline)"
    );
    bytes32 private constant _DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    uint256 private constant _HALF_ORDER =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
    bytes4 private constant _MAGIC = 0x1626ba7e;
    mapping(address => mapping(bytes32 => bool)) private _releaseNonces;

    function domainSeparator() public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                _DOMAIN_TYPEHASH,
                keccak256("6529StreamSplitWallet"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function eip712Domain()
        external
        view
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            0x0f,
            "6529StreamSplitWallet",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function releaseAuthorizationDigest(ReleaseAuthorization calldata authorization)
        public
        view
        override
        returns (bytes32)
    {
        return _typedReleaseDigest(
            keccak256(abi.encode(RELEASE_AUTHORIZATION_TYPEHASH, authorization))
        );
    }

    function releaseRevocationDigest(address account, bytes32 nonce, uint64 deadline)
        public
        view
        override
        returns (bytes32)
    {
        return _typedReleaseDigest(
            keccak256(
                abi.encode(RELEASE_AUTHORIZATION_REVOCATION_TYPEHASH, account, nonce, deadline)
            )
        );
    }

    function isReleaseAuthorizationNonceUsed(address account, bytes32 nonce)
        public
        view
        override
        returns (bool)
    {
        return _releaseNonces[account][nonce];
    }

    function revokeReleaseAuthorization(bytes32 nonce) external override nonReentrant {
        _revokeRelease(msg.sender, nonce);
    }

    function revokeReleaseAuthorizationBySignature(
        address account,
        bytes32 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        _requireReleaseUnused(account, nonce);
        if (block.timestamp > deadline) revert ReleaseAuthorizationExpired(deadline);
        if (!_validReleaseSignature(
                account, releaseRevocationDigest(account, nonce, deadline), signature
            )) {
            revert InvalidReleaseSignature(account);
        }
        _revokeRelease(account, nonce);
    }

    function _consumeReleaseAuthorization(
        ReleaseAuthorization calldata authorization,
        bytes calldata signature,
        uint256 actualAmount
    ) internal {
        _requireReleaseUnused(authorization.account, authorization.nonce);
        if (block.timestamp > authorization.deadline) {
            revert ReleaseAuthorizationExpired(authorization.deadline);
        }
        if (authorization.releasableSnapshot != actualAmount) {
            revert ReleaseSnapshotMismatch(authorization.releasableSnapshot, actualAmount);
        }
        if (!_validReleaseSignature(
                authorization.account, releaseAuthorizationDigest(authorization), signature
            )) {
            revert InvalidReleaseSignature(authorization.account);
        }
        _releaseNonces[authorization.account][authorization.nonce] = true;
    }

    function _revokeRelease(address account, bytes32 nonce) private {
        _requireReleaseUnused(account, nonce);
        _releaseNonces[account][nonce] = true;
        emit ReleaseAuthorizationRevoked(account, nonce, 1);
    }

    function _requireReleaseUnused(address account, bytes32 nonce) private view {
        if (account == address(0)) revert InvalidReleaseAccount();
        if (_releaseNonces[account][nonce]) revert ReleaseAuthorizationNonceUsed(account, nonce);
    }

    function _typedReleaseDigest(bytes32 hash) private view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", domainSeparator(), hash));
    }

    function _releaseSignatureGasLimit() internal view virtual returns (uint256);

    function _requireWalletCallGas(uint256 limit) internal view {
        uint256 available = gasleft();
        // The subtraction avoids overflow for even a malformed or unreachable very large limit.
        if (
            limit > available || available - limit < limit / 63 + (limit % 63 == 0 ? 0 : 1) + 20_000
        ) {
            revert InsufficientWalletCallGas(limit);
        }
    }

    function _validReleaseSignature(address account, bytes32 digest, bytes calldata signature)
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
                uint256(s) <= _HALF_ORDER && (v == 27 || v == 28)
                    && ecrecover(digest, v, r, s) == account
            ) return true;
            if (size == 0) return false;
        }
        // Contract signatures have no EOA length constraint (e.g. Safe threshold signatures).
        bytes memory payload = abi.encodeWithSelector(_MAGIC, digest, signature);
        uint256 limit = _releaseSignatureGasLimit();
        _requireWalletCallGas(limit);
        bool success;
        uint256 result;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            success := staticcall(limit, account, add(payload, 32), mload(payload), ptr, 32)
            success := and(success, eq(returndatasize(), 32))
            result := mload(ptr)
        }
        return success && result == uint256(uint32(_MAGIC)) << 224;
    }
}
