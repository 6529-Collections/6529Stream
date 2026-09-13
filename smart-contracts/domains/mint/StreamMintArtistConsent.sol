// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Mandatory, bounded artist-authority reads shared by Manager registration and execution.
library StreamMintArtistConsent {
    error ArtistAuthorityUnavailable(address authority);
    error ArtistAuthorityReadFailed(address authority, bytes4 selector);
    error ArtistAuthorityParentGas(uint256 available, uint256 required);
    error ArtistPolicyNotConsented(uint256 collectionId, bytes32 phaseId, bytes32 policyHash);
    error UnsupportedArtistConsentMode(uint256 collectionId, uint8 mode);
    error InvalidCanonicalMintRegistry(address registry);

    function governance(address core, address registry) internal view returns (address authority) {
        (address selected, bytes32 codeHash,,,,,,,,) =
            IStreamCorePointers(core).getSatellitePointer(keccak256("MODULE_REGISTRY"));
        if (registry.code.length == 0 || selected != registry || codeHash != registry.codehash) {
            revert InvalidCanonicalMintRegistry(registry);
        }
        if (!IERC165(registry).supportsInterface(type(IStreamModuleRegistry).interfaceId)) {
            revert InvalidCanonicalMintRegistry(registry);
        }
        authority = IStreamMintGovernanceRegistry(registry).governanceExecutor();
        if (authority == address(0) || authority.code.length == 0) {
            revert InvalidCanonicalMintRegistry(registry);
        }
    }

    function registration(
        address core,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash,
        uint256 cap
    ) external view returns (uint8 mode, bytes32 evidence) {
        address authority = _authority(core, cap);
        mode = abi.decode(
            _read(
                authority,
                abi.encodeCall(IStreamArtistMintConsent.consentMode, (collectionId)),
                32,
                cap
            ),
            (uint8)
        );
        // This vertical profile implements signed policy only. Missing attribution, delegated
        // and platform-work modes remain closed until their own records are implemented.
        if (mode != 1) revert UnsupportedArtistConsentMode(collectionId, mode);
        bool consented;
        (consented, evidence) = abi.decode(
            _read(
                authority,
                abi.encodeCall(
                    IStreamArtistMintConsent.isPolicyConsented, (collectionId, phaseId, policyHash)
                ),
                64,
                cap
            ),
            (bool, bytes32)
        );
        if (!consented || evidence == bytes32(0)) {
            revert ArtistPolicyNotConsented(collectionId, phaseId, policyHash);
        }
        _read(
            authority,
            abi.encodeCall(
                IStreamArtistMintConsent.requireMintConsent, (collectionId, phaseId, policyHash)
            ),
            0,
            cap
        );
    }

    function mint(
        address core,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash,
        uint256 cap
    ) external view {
        address authority = _authority(core, cap);
        _read(
            authority,
            abi.encodeCall(
                IStreamArtistMintConsent.requireMintConsent, (collectionId, phaseId, policyHash)
            ),
            0,
            cap
        );
    }

    function _authority(address core, uint256 cap) private view returns (address authority) {
        (address selected, bytes32 codeHash,,,,,,,,) =
            IStreamCorePointers(core).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        authority = selected;
        if (authority.code.length == 0 || codeHash != authority.codehash) {
            revert ArtistAuthorityUnavailable(authority);
        }
        if (
            abi.decode(
                        _read(
                            authority, abi.encodeCall(IStreamArtistMintConsent.core, ()), 32, cap
                        ),
                        (address)
                    ) != core
                || abi.decode(
                        _read(
                            authority,
                            abi.encodeCall(IStreamArtistMintConsent.mintManager, ()),
                            32,
                            cap
                        ),
                        (address)
                    ) != address(this)
        ) {
            revert ArtistAuthorityUnavailable(authority);
        }
    }

    function _read(address target, bytes memory data, uint256 expected, uint256 cap)
        private
        view
        returns (bytes memory output)
    {
        uint256 available = gasleft();
        if (available < 6000 || (available - 6000) / 64 * 63 < cap) {
            revert ArtistAuthorityParentGas(available, cap);
        }
        output = new bytes(expected);
        bool success;
        uint256 size;
        assembly ("memory-safe") {
            success := staticcall(
                cap,
                target,
                add(data, 32),
                mload(data),
                add(output, 32),
                expected
            )
            size := returndatasize()
        }
        if (!success || size != expected) revert ArtistAuthorityReadFailed(target, bytes4(data));
    }
}
