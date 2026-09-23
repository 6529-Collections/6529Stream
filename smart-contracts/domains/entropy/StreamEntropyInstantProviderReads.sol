// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../vendor/openzeppelin/IERC165.sol";

import "../../interfaces/stream/entropy/IStreamInstantEntropyProvider.sol";
import {
    IStreamInstantEntropyProviderIdentity as I
} from "../../interfaces/stream/entropy/IStreamInstantEntropyProviderIdentity.sol";
import { IStreamEntropyProvider } from "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import "./StreamEntropyIncidentParameters.sol";

/// @notice Exact bounded synchronous provider reads under the Coordinator's own hard-fail GGP.
library StreamEntropyInstantProviderReads {
    error InvalidInstantProvider(address provider);
    error InstantEntropyReadFailed(address provider);
    bytes32 internal constant READ_GAS = keccak256("6529STREAM_GGP_ENTROPY_INSTANT_READ_GAS_LIMIT");

    function supportsInstant(address provider) public view returns (bool) {
        return _supports(provider, type(IStreamInstantEntropyProvider).interfaceId);
    }

    function configuration(address provider) public view returns (bytes32 hash) {
        if (
            provider.code.length == 0 || !_supports(provider, type(IERC165).interfaceId)
                || !supportsInstant(provider) || !_supports(provider, type(I).interfaceId)
                || _supports(provider, 0xffffffff)
                || _supports(provider, type(IStreamEntropyProvider).interfaceId)
                || abi.decode(
                        _read(provider, abi.encodeCall(I.isStreamInstantEntropyProvider, ()), 32),
                        (uint256)
                    ) != 1
        ) {
            revert InvalidInstantProvider(provider);
        }
        hash = configHash(provider);
        (I.InstantMode mode, bytes32 assumptions) = profile(provider);
        if (
            hash == 0 || mode != I.InstantMode.DELAYED_BLOCKHASH || assumptions == 0
                || abi.decode(
                        _read(provider, abi.encodeCall(I.streamEntropyProviderFamily, ()), 32),
                        (bytes32)
                    ) == 0
                || abi.decode(
                        _read(provider, abi.encodeCall(I.streamEntropyProviderVersion, ()), 32),
                        (bytes32)
                    ) == 0
        ) {
            revert InvalidInstantProvider(provider);
        }
    }

    function configHash(address provider) public view returns (bytes32) {
        return abi.decode(
            _read(provider, abi.encodeCall(I.streamEntropyProviderConfigHash, ()), 32), (bytes32)
        );
    }

    function profile(address provider)
        public
        view
        returns (I.InstantMode mode, bytes32 assumptions)
    {
        (uint256 word, bytes32 hash) = abi.decode(
            _read(provider, abi.encodeCall(I.instantEntropyProfile, ()), 64), (uint256, bytes32)
        );
        if (word != uint256(I.InstantMode.DELAYED_BLOCKHASH) || hash == 0) {
            revert InvalidInstantProvider(provider);
        }
        return (I.InstantMode(word), hash);
    }

    function entropy(address provider, bytes32 key, bytes memory context)
        public
        view
        returns (bytes32, bytes32)
    {
        return abi.decode(
            _read(
                provider,
                abi.encodeCall(IStreamInstantEntropyProvider.instantEntropy, (key, context)),
                64
            ),
            (bytes32, bytes32)
        );
    }

    function _supports(address provider, bytes4 id) private view returns (bool) {
        uint256 word = abi.decode(
            _read(provider, abi.encodeCall(IERC165.supportsInterface, (id)), 32), (uint256)
        );
        if (word > 1) revert InvalidInstantProvider(provider);
        return word == 1;
    }

    function _read(address provider, bytes memory data, uint256 size)
        private
        view
        returns (bytes memory result)
    {
        uint256 cap = StreamEntropyIncidentParameters.value(READ_GAS);
        result = new bytes(size);
        // Class 2 requires enough parent gas to forward the complete current cap.
        // Divide before multiplying: even a near-uint256 governed value fails closed.
        uint256 available = gasleft();
        if (available <= 10000 || (available - 10000) / 64 * 63 < cap) {
            revert InstantEntropyReadFailed(provider);
        }
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, provider, add(data, 32), mload(data), add(result, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert InstantEntropyReadFailed(provider);
    }
}
