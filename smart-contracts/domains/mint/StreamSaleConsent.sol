// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCorePointers.sol";

/// @notice Caller-preserving sale-consent admission at the immutable current artist facade.
/// @dev Linked invocation keeps the original consumer as the facade's caller. NONE versus
///      REQUIRED is decided by the actual facade; failed/unknown reads never mean NONE.
library StreamSaleConsent {
    error SaleConsentFacadeChanged(address facade);
    error SaleConsentNotSatisfied(address facade, uint256 collectionId, bytes32 saleId);

    function requireConsent(
        address core,
        address facade,
        bytes32 admittedCodeHash,
        uint256 collectionId,
        bytes32 saleId,
        bytes32 actualConfigHash
    ) public view {
        if (facade.code.length == 0 || facade.codehash != admittedCodeHash) {
            revert SaleConsentFacadeChanged(facade);
        }
        bytes memory data =
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY")));
        uint256[10] memory pointer;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), core, add(data, 32), mload(data), pointer, 320)
            size := returndatasize()
        }
        if (
            !ok || size != 320 || pointer[0] != uint256(uint160(facade))
                || bytes32(pointer[1]) != admittedCodeHash
        ) {
            revert SaleConsentFacadeChanged(facade);
        }
        data = abi.encodeWithSelector(
            bytes4(keccak256("requireSaleConsent(uint256,bytes32,bytes32)")),
            collectionId,
            saleId,
            actualConfigHash
        );
        // No dynamic returndata/revert copying. This trusted current-facade read uses available
        // gas, matching existing sale artist admission; it is not a direct ERC1271 call.
        assembly ("memory-safe") {
            ok := staticcall(gas(), facade, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        if (!ok || size != 0) revert SaleConsentNotSatisfied(facade, collectionId, saleId);
    }
}
