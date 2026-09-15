// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";

/// @notice Resolves the actual Identity owner behind the metadata host's artist facade.
/// @dev The authenticated consumer supplies immutable metadata/Core/chain and its governed
///      metadata dependency-read gas cap. No witness chooses an Identity owner or signer.
library StreamRecordArtistIdentityReads {
    error InvalidArtistIdentityContext();
    error ArtistIdentityReadFailed(address target);
    error ArtistIdentityDependencyChanged(address target);
    error UnknownRecordArtist(bytes32 artistId);

    struct Pins {
        // In order: onboarding facade, operation Coordinator, Identity owner.
        address[3] targets;
        bytes32[3] codeHashes;
    }

    function resolve(address metadata, address core, uint256 chainId, uint256 readGas)
        public
        view
        returns (Pins memory pins)
    {
        if (
            core == address(0) || block.chainid != chainId || readGas == 0
                || readGas > type(uint64).max
        ) revert InvalidArtistIdentityContext();
        // The same artistRegistry() ABI selector is present on metadata and the owner.
        // This does not assert that metadata implements the owner interface.
        pins.targets[0] = _address(metadata, IStreamArtistOwner.artistRegistry.selector, readGas);
        pins.codeHashes[0] = _code(pins.targets[0]);
        // Metadata binds this facade runtime immutably at deployment. Initial resolution
        // cannot adopt a coherently substituted graph merely because its current getters agree.
        bytes32 originalFacadeCodeHash = _word(
            _read(metadata, abi.encodeWithSignature("artistRegistryCodeHash()"), 32, readGas), 0
        );
        if (pins.codeHashes[0] != originalFacadeCodeHash) {
            revert ArtistIdentityDependencyChanged(pins.targets[0]);
        }
        if (_address(pins.targets[0], IStreamArtistOwner.core.selector, readGas) != core) {
            revert InvalidArtistIdentityContext();
        }
        pins.targets[1] = _address(
            pins.targets[0], IStreamArtistIngressBinding.operationCoordinator.selector, readGas
        );
        pins.codeHashes[1] = _code(pins.targets[1]);
        if (
            _word(
                    _read(
                        pins.targets[1],
                        abi.encodeWithSelector(IStreamArtistSuiteReads.deploymentChainId.selector),
                        32,
                        readGas
                    ),
                    0
                ) != bytes32(chainId)
        ) {
            revert InvalidArtistIdentityContext();
        }
        bytes memory suite = _read(
            pins.targets[1],
            abi.encodeWithSelector(IStreamArtistSuiteReads.suiteConfiguration.selector),
            544,
            readGas
        );
        // SuiteConfiguration has17 fixed words. Every word except primaryRevenueClass15
        // is an address. Validate even unused words; no aliasing/trailing/dynamic decoding.
        for (uint256 i; i < 17; ++i) {
            if (i != 15 && uint256(_word(suite, i)) > type(uint160).max) {
                revert ArtistIdentityReadFailed(pins.targets[1]);
            }
        }
        if (
            _word(suite, 0) != bytes32(uint256(uint160(pins.targets[0])))
                || _word(suite, 9) != bytes32(uint256(uint160(core)))
        ) revert InvalidArtistIdentityContext();
        pins.targets[2] = address(uint160(uint256(_word(suite, 4)))); // owners[2]
        pins.codeHashes[2] = _code(pins.targets[2]);
        if (
            _address(pins.targets[2], IStreamArtistOwner.core.selector, readGas) != core
                || _address(pins.targets[2], IStreamArtistOwner.artistRegistry.selector, readGas)
                    != pins.targets[0]
                || _address(
                        pins.targets[2], IStreamArtistOwner.operationCoordinator.selector, readGas
                    ) != pins.targets[1]
                || _word(
                        _read(
                            pins.targets[2],
                            abi.encodeWithSelector(IStreamArtistOwner.deploymentChainId.selector),
                            32,
                            readGas
                        ),
                        0
                    ) != bytes32(chainId)
        ) {
            revert InvalidArtistIdentityContext();
        }
    }

    /// @notice Immutable registration identity only; operative authority fields are not returned.
    /// @dev No active/class/signer/collection-association requirement. Caller may retain this hash
    ///      as historical evidence while separately checking current deployment pins.
    function knownIdentity(
        address metadata,
        address core,
        uint256 chainId,
        Pins memory expected,
        bytes32 artistId,
        uint256 readGas
    ) public view returns (bytes32 identityRecordHash) {
        if (artistId == 0) revert UnknownRecordArtist(artistId);
        Pins memory current = resolve(metadata, core, chainId, readGas);
        for (uint256 i; i < 3; ++i) {
            if (
                current.targets[i] != expected.targets[i]
                    || current.codeHashes[i] != expected.codeHashes[i]
            ) {
                revert ArtistIdentityDependencyChanged(current.targets[i]);
            }
        }
        bytes memory facts = _read(
            current.targets[2],
            abi.encodeCall(IStreamArtistIdentityOwner.authorityState, (artistId)),
            128,
            readGas
        );
        if (
            uint256(_word(facts, 0)) > type(uint160).max
                || uint256(_word(facts, 1)) > type(uint8).max
                || uint256(_word(facts, 2)) > type(uint8).max
        ) revert ArtistIdentityReadFailed(current.targets[2]);
        identityRecordHash = _word(facts, 3);
        if (identityRecordHash == 0) revert UnknownRecordArtist(artistId);
    }

    function _code(address target) private view returns (bytes32) {
        if (target.code.length == 0) revert ArtistIdentityDependencyChanged(target);
        return target.codehash;
    }

    function _address(address target, bytes4 selector, uint256 cap) private view returns (address) {
        uint256 value = uint256(_word(_read(target, abi.encodeWithSelector(selector), 32, cap), 0));
        if (value > type(uint160).max) revert ArtistIdentityReadFailed(target);
        return address(uint160(value));
    }

    function _word(bytes memory data, uint256 index) private pure returns (bytes32 value) {
        assembly ("memory-safe") { value := mload(add(add(data, 32), mul(index, 32))) }
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory data)
    {
        if (target.code.length == 0) revert ArtistIdentityReadFailed(target);
        data = new bytes(size);
        // Allocation/calldata construction precede admission. Leave EIP150 and local
        // bookkeeping headroom immediately before the fixed-cap, fixed-copy call.
        if (gasleft() <= cap + cap / 63 + 10000) revert ArtistIdentityReadFailed(target);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert ArtistIdentityReadFailed(target);
    }
}
