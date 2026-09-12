// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";

/// @notice Current-principal classification and explicit estate action capabilities.
/// @dev The fixed self read resolves directly from Identity's local estate records.
library StreamArtistAuthorityPolicy {
    function ordinary(uint8 authorityClass, uint8 status, bool defensive)
        internal
        pure
        returns (bool)
    {
        return (authorityClass == 1 && status == 1) || (authorityClass == 3 && status == 3)
            || (defensive && status == 4 && (authorityClass == 1 || authorityClass == 3));
    }

    function requireOperation(T.Identity memory principal, bytes32 artistId, uint16 operation)
        internal
        view
    {
        bool defensive = operation == 20 || operation == 21 || operation == 27 || operation == 54;
        if (
            principal.authorityAddress == address(0)
                || !ordinary(principal.authorityClass, principal.status, defensive)
        ) revert T.InvalidIdentity(artistId);
        if (principal.authorityClass == 1) return;
        uint32 required;
        if (operation == 14) {
            required = 2;
        } else if (operation == 15) {
            required = 4;
        } else if (operation == 16) {
            required = 1024;
        } else if (operation == 17 || operation == 21 || operation == 52) {
            required = 128;
        } else if (operation == 18 || operation == 25) {
            required = 512;
        } else if (operation == 20) {
            required = 32;
        } else if (operation == 24) {
            required = 1;
        } else if (operation == 28) {
            required = 256;
        } else if (
            operation != 2 && operation != 3 && operation != 7 && operation != 27 && operation != 29
                && operation != 51 && operation != 54
        ) {
            revert T.InvalidIdentity(artistId);
        }
        _requireCapability(principal, artistId, required);
    }

    /// @dev AA-INTENT gives subject7 CAP_INTENT_RECORDS alone; ordinary attestations retain CAP_ATTEST.
    function requireIntentAttestation(T.Identity memory principal, bytes32 artistId) internal view {
        if (
            principal.authorityAddress == address(0)
                || !ordinary(principal.authorityClass, principal.status, false)
        ) revert T.InvalidIdentity(artistId);
        if (principal.authorityClass == 1) return;
        _requireCapability(principal, artistId, 64);
    }

    function _requireCapability(T.Identity memory principal, bytes32 artistId, uint32 required)
        private
        view
    {
        Estate.AuthorityCapabilities memory actual = capabilities(artistId);
        if (
            actual.authorityAddress != principal.authorityAddress
                || actual.authorityClass != principal.authorityClass
                || actual.status != principal.status
                || (actual.effectiveCapabilities & required) != required
        ) {
            revert Estate.EstateCapabilityUnavailable(artistId, required);
        }
    }

    function capabilities(bytes32 artistId)
        internal
        view
        returns (Estate.AuthorityCapabilities memory result)
    {
        bytes memory data =
            abi.encodeCall(IStreamArtistEstateOwner.currentAuthorityCapabilities, (artistId));
        bytes memory raw = new bytes(160);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), address(), add(data, 32), mload(data), add(raw, 32), 160)
            size := returndatasize()
        }
        if (!ok || size != 160) revert T.InvalidIdentity(artistId);
        result = abi.decode(raw, (Estate.AuthorityCapabilities));
        if (result.activationRecordHash == bytes32(0)) revert T.InvalidIdentity(artistId);
    }
}
