// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamOwnerRecords as O } from "../../interfaces/stream/metadata/IStreamOwnerRecords.sol";

library StreamOwnerRecordSignatures {
    function verify(address signer, bytes32 digest, bytes calldata signature, uint256 cap)
        internal
        view
        returns (bytes32 scheme)
    {
        if (signer == address(0) || signature.length > 4096) {
            revert O.InvalidOwnerRecordSignature(signer);
        }
        bool delegated;
        if (signer.code.length == 23) {
            bytes3 prefix;
            assembly ("memory-safe") {
                extcodecopy(signer, 0, 0, 3)
                prefix := mload(0)
            }
            delegated = prefix == 0xef0100;
        }
        if (signer.code.length == 0 || delegated) {
            if (_ownKey(signer, digest, signature)) return keccak256("EIP712");
            if (!delegated) revert O.InvalidOwnerRecordSignature(signer);
        }
        _contract(signer, abi.encodeWithSelector(bytes4(0x1626ba7e), digest, signature), cap);
        return keccak256("ERC1271");
    }

    function _contract(address signer, bytes memory input, uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > type(uint256).max / 64 || available <= 5000 || (available - 5000) / 64 * 63 < cap)
        {
            revert O.OwnerRecordParentGas(available, cap);
        }
        bool ok;
        uint256 size;
        uint256 output;
        assembly ("memory-safe") {
            let p := mload(0x40)
            ok := staticcall(cap, signer, add(input, 32), mload(input), p, 32)
            size := returndatasize()
            output := mload(p)
        }
        if (!ok || size != 32 || output != uint256(uint32(0x1626ba7e)) << 224) {
            revert O.InvalidOwnerRecordSignature(signer);
        }
    }

    function _ownKey(address signer, bytes32 digest, bytes calldata signature)
        private
        pure
        returns (bool)
    {
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
        return uint256(s) <= 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0
            && (v == 27 || v == 28) && ecrecover(digest, v, r, s) == signer;
    }
}
