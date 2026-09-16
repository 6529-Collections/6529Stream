// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";

import "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";
import "../../interfaces/stream/mint/IStreamMintLedgerContinuity.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @dev Existing immutable Manager getters, used only to authenticate exact continuity pairs.
interface IStreamMintArtistManagerBinding {
    function core() external view returns (address);
    function mintLedger() external view returns (address);
}

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
        // Mode3 supplies the immutable declaration as evidence; it does not fabricate an Artist signature.
        if (mode != 1 && mode != 3) revert UnsupportedArtistConsentMode(collectionId, mode);
        if (
            mode == 3
                && !abi.decode(
                    _read(
                        authority,
                        abi.encodeCall(
                            IERC165.supportsInterface,
                            (type(IStreamArtistPlatformWorks).interfaceId)
                        ),
                        32,
                        cap
                    ),
                    (bool)
                )
        ) revert UnsupportedArtistConsentMode(collectionId, mode);
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
        if (mode == 3) {
            (bool declared, bytes32 declaration, uint64 declaredAt) = abi.decode(
                _read(
                    authority,
                    abi.encodeCall(
                        IStreamArtistPlatformWorks.platformWorksDeclaration, (collectionId)
                    ),
                    96,
                    cap
                ),
                (bool, bytes32, uint64)
            );
            if (!declared || declaration != evidence || declaredAt > block.timestamp) {
                revert ArtistPolicyNotConsented(collectionId, phaseId, policyHash);
            }
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
        authority = _selected(core, keccak256("ARTIST_REGISTRY"), cap);
        address originalManager = abi.decode(
            _read(authority, abi.encodeCall(IStreamArtistMintConsent.mintManager, ()), 32, cap),
            (address)
        );
        if (
            abi.decode(
                        _read(
                            authority, abi.encodeCall(IStreamArtistMintConsent.core, ()), 32, cap
                        ),
                        (address)
                    ) != core
                || (originalManager != address(this) && !_successor(core, originalManager, cap))
        ) {
            revert ArtistAuthorityUnavailable(authority);
        }
    }

    function _successor(address core, address originalManager, uint256 cap)
        private
        view
        returns (bool)
    {
        // Historical Artist signatures retain their original immutable Manager domain.
        // A different consumer needs both current Core selection and completed exact-pair ancestry.
        if (
            originalManager.code.length == 0
                || _selected(core, keccak256("MINT_MANAGER"), cap) != address(this)
        ) {
            return false;
        }
        address ledger = abi.decode(
            _read(
                address(this),
                abi.encodeCall(IStreamMintArtistManagerBinding.mintLedger, ()),
                32,
                cap
            ),
            (address)
        );
        if (_selected(core, keccak256("MINT_LEDGER"), cap) != ledger) return false;
        address originalLedger = abi.decode(
            _read(
                originalManager,
                abi.encodeCall(IStreamMintArtistManagerBinding.mintLedger, ()),
                32,
                cap
            ),
            (address)
        );
        if (
            abi.decode(
                    _read(
                        originalManager,
                        abi.encodeCall(IStreamMintArtistManagerBinding.core, ()),
                        32,
                        cap
                    ),
                    (address)
                ) != core
        ) {
            return false;
        }
        return abi.decode(
            _read(
                ledger,
                abi.encodeCall(
                    IStreamMintLedgerContinuity.isCompletedMintDescendant,
                    (originalLedger, originalManager, address(this))
                ),
                32,
                cap
            ),
            (bool)
        );
    }

    function _selected(address core, bytes32 kind, uint256 cap)
        private
        view
        returns (address selected)
    {
        (address target, bytes32 codeHash) = abi.decode(
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, cap),
            (address, bytes32)
        );
        if (target.code.length == 0 || codeHash != target.codehash) {
            revert ArtistAuthorityUnavailable(target);
        }
        return target;
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
