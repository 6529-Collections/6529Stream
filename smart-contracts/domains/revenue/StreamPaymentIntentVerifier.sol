// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamPaymentIntentVerifier.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";

/// @notice Shared payer consent and revocation for an allowance-pulling sale adapter.
/// @dev The derived contract must validate commercial terms before calling _authorizePayment,
///      perform the pull itself, and guard its entire settlement with the same nonReentrant lock.
///      The adapter-local raise-only stipend is not the unimplemented factory-wide RSR GGP store.
abstract contract StreamPaymentIntentVerifier is
    IStreamPaymentIntentVerifier,
    Ownable,
    ReentrancyGuard
{
    bytes32 public constant PAYMENT_INTENT_TYPEHASH = keccak256(
        "StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)"
    );
    bytes32 public constant PAYMENT_INTENT_REVOCATION_TYPEHASH =
        keccak256("StreamPaymentIntentRevocation(address payer,bytes32 nonce,uint64 deadline)");
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    uint256 private constant HALF_ORDER =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
    bytes4 private constant MAGIC = 0x1626ba7e;

    uint256 public override signatureGasLimit = 400_000;
    mapping(address => mapping(bytes32 => bool)) private _usedPaymentNonces;

    struct PaymentTerms {
        address payer;
        address asset;
        uint256 amount;
        bytes32 saleRef;
        bytes32 primaryPolicyHash;
    }

    function isPaymentIntentNonceUsed(address payer, bytes32 nonce)
        public
        view
        override
        returns (bool)
    {
        return _usedPaymentNonces[payer][nonce];
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256("6529StreamPaymentIntentVerifier"),
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
            "6529StreamPaymentIntentVerifier",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function paymentIntentDigest(PaymentIntent calldata intent)
        public
        view
        override
        returns (bytes32)
    {
        return _typedDigest(keccak256(abi.encode(PAYMENT_INTENT_TYPEHASH, intent)));
    }

    function paymentIntentRevocationDigest(address payer, bytes32 nonce, uint64 deadline)
        public
        view
        override
        returns (bytes32)
    {
        return _typedDigest(
            keccak256(abi.encode(PAYMENT_INTENT_REVOCATION_TYPEHASH, payer, nonce, deadline))
        );
    }

    function revokePaymentIntent(bytes32 nonce) external override nonReentrant {
        _revoke(msg.sender, nonce);
    }

    function revokePaymentIntentBySignature(
        address payer,
        bytes32 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        if (block.timestamp > deadline) revert PaymentIntentExpired(deadline);
        _requireUnused(payer, nonce);
        if (!_validSignature(
                payer, paymentIntentRevocationDigest(payer, nonce, deadline), signature
            )) {
            revert InvalidPaymentSignature(payer);
        }
        _revoke(payer, nonce);
    }

    function raiseSignatureGasLimit(uint256 value) external override onlyOwner nonReentrant {
        if (value <= signatureGasLimit || value > type(uint64).max) {
            revert InvalidSignatureGasLimit();
        }
        uint256 previous = signatureGasLimit;
        signatureGasLimit = value;
        emit SignatureGasLimitRaised(previous, value);
    }

    /// @notice Transfers administrative authority under the settlement reentrancy lock.
    function transferOwnership(address newOwner) public override onlyOwner nonReentrant {
        super.transferOwnership(newOwner);
    }

    /// @notice Irrevocably removes administrative authority under the settlement lock.
    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }

    function _revoke(address payer, bytes32 nonce) private {
        _requireUnused(payer, nonce);
        _usedPaymentNonces[payer][nonce] = true;
        emit PaymentIntentRevoked(payer, nonce, 1);
    }

    function _requireUnused(address payer, bytes32 nonce) private view {
        if (payer == address(0)) revert InvalidPaymentIntent();
        if (_usedPaymentNonces[payer][nonce]) revert PaymentIntentNonceUsed(payer, nonce);
    }

    function _authorizePayment(
        PaymentTerms memory terms,
        PaymentIntent calldata intent,
        bytes calldata signature
    ) internal {
        // Empty signatures opt into only the literal caller exemption at this allowance puller.
        // No caller allowlist, forwarded sender, tx.origin or unsigned permit can authorize a relayer.
        if (signature.length == 0 && terms.payer == msg.sender) return;
        if (
            intent.payer != terms.payer || intent.asset != terms.asset
                || intent.maxAmount < terms.amount || intent.saleRef != terms.saleRef
                || intent.expectedPrimaryPolicyHash != terms.primaryPolicyHash
        ) {
            revert InvalidPaymentIntent();
        }
        if (block.timestamp > intent.deadline) revert PaymentIntentExpired(intent.deadline);
        _requireUnused(intent.payer, intent.nonce);
        if (!_validSignature(intent.payer, paymentIntentDigest(intent), signature)) {
            revert InvalidPaymentSignature(intent.payer);
        }
        _usedPaymentNonces[intent.payer][intent.nonce] = true;
        emit PaymentIntentConsumed(
            intent.payer, intent.saleRef, intent.nonce, 1, intent.asset, terms.amount
        );
    }

    function _typedDigest(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", domainSeparator(), structHash));
    }

    function _validSignature(address signer, bytes32 digest, bytes calldata signature)
        internal
        view
        returns (bool)
    {
        if (signer == address(0)) return false;
        uint256 codeSize = signer.code.length;
        // EIP-7702 accounts retain their canonical ECDSA path as well as the delegated ERC-1271 path.
        bool delegated;
        if (codeSize == 23) {
            uint256 prefix;
            assembly ("memory-safe") {
                let ptr := mload(0x40)
                extcodecopy(signer, ptr, 0, 3)
                prefix := shr(232, mload(ptr))
            }
            delegated = prefix == 0xef0100;
        }
        if (codeSize == 0 || delegated) {
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
                    && ecrecover(digest, v, r, s) == signer
            ) {
                return true;
            }
            if (codeSize == 0) return false;
        }
        bytes memory payload = abi.encodeWithSelector(MAGIC, digest, signature);
        uint256 limit = signatureGasLimit;
        // Reserve cold-account cost, EIP-150 headroom and bounded parent completion before the call.
        if (gasleft() < limit + (limit + 62) / 63 + 20_000) revert InsufficientSignatureGas();
        bool ok;
        uint256 result;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(limit, signer, add(payload, 32), mload(payload), ptr, 32)
            ok := and(ok, eq(returndatasize(), 32))
            result := mload(ptr)
        }
        return ok && result == uint256(uint32(MAGIC)) << 224;
    }
}
