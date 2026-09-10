// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Shared canonical EOA and bounded ERC-1271 verification for signed sale adapters.
library StreamSaleSignatures {
    uint256 private constant SECP256K1_HALF_ORDER =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
    uint256 private constant CONTRACT_SIGNATURE_GAS = 100_000;
    bytes4 private constant ERC1271_MAGIC = 0x1626ba7e;

    function isValid(address signer, bytes32 digest, bytes calldata signature)
        internal
        view
        returns (bool)
    {
        if (signer == address(0)) return false;
        if (signer.code.length == 0) {
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
            } else {
                return false;
            }
            return uint256(s) <= SECP256K1_HALF_ORDER && (v == 27 || v == 28)
                && ecrecover(digest, v, r, s) == signer;
        }
        bytes memory payload = abi.encodeWithSelector(ERC1271_MAGIC, digest, signature);
        bool ok;
        uint256 result;
        uint256 gasLimit = CONTRACT_SIGNATURE_GAS;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(gasLimit, signer, add(payload, 32), mload(payload), ptr, 32)
            ok := and(ok, eq(returndatasize(), 32))
            result := mload(ptr)
        }
        return ok && result == uint256(uint32(ERC1271_MAGIC)) << 224;
    }
}
