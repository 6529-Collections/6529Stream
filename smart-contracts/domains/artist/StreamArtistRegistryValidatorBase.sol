// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Stateless canonical EOA/ERC1271 verification; never owns artist authority or replay.
/// @dev The coordinator supplies the current governed cap and binds the result to one typed payload.
contract StreamArtistRegistryValidatorBase {
    function validateSignerProof(
        address signer,
        bytes32 digest,
        bytes calldata signature,
        uint256 gasCap
    ) external view returns (bool) {
        if (signer == address(0) || signature.length > 4096 || gasCap < 90_000) return false;
        bool designated;
        if (signer.code.length == 23) {
            bytes3 prefix;
            assembly ("memory-safe") {
                extcodecopy(signer, 0, 0, 3)
                prefix := mload(0)
            }
            designated = prefix == 0xef0100;
        }
        if (signer.code.length == 0) return _validateEOA(signer, digest, signature);
        if (designated && _validateEOA(signer, digest, signature)) return true;
        return _validateSignerProof(signer, digest, signature, gasCap);
    }

    function _validateEOA(address signer, bytes32 digest, bytes calldata signature)
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

    function _validateSignerProof(
        address signer,
        bytes32 digest,
        bytes calldata signature,
        uint256 gasCap
    ) private view returns (bool) {
        bytes memory input = abi.encodeWithSelector(bytes4(0x1626ba7e), digest, signature);
        uint256 remaining = gasleft();
        if (
            gasCap > type(uint256).max / 64 || remaining <= 5_000
                || (remaining - 5_000) / 64 * 63 < gasCap
        ) revert T.InvalidSignature();
        bool ok;
        uint256 word;
        uint256 size;
        // Exactly one word is copied, even if the wallet returns an adversarial byte array.
        assembly ("memory-safe") {
            let output := mload(0x40)
            ok := staticcall(gasCap, signer, add(input, 32), mload(input), output, 32)
            size := returndatasize()
            word := mload(output)
        }
        return ok && size == 32 && word == uint256(uint32(0x1626ba7e)) << 224;
    }
}
