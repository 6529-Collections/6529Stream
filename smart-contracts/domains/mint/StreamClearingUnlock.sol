// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamDutchSaleSupport.sol";
import "../../interfaces/stream/mint/IStreamNativeClearingSale.sol";

/// @notice Typed failures relevant to an already-minted financial leg; no mint-phase inference.
library StreamClearingUnlock {
    /// @dev Known INCIDENT stops new use. UNKNOWN and DEPRECATED retain the existing
    /// native-recorder admission profile; this is not an invented ACTIVE-only policy.
    function requireRecorderNotIncident(address registry, address recorder) public view {
        if (_incident(registry, recorder)) {
            revert IStreamNativeClearingSale.ClearingRecorderIncident(recorder);
        }
    }

    function reasonHash(
        StreamDutchSaleSupport.Context memory x,
        address registry,
        bytes32 registryHash,
        address recorder,
        IStreamNativeClearingSale.ClearingSaleRecord memory sale,
        uint8 reason
    ) public view returns (bytes32) {
        if (reason == 1 && sale.artistId != 0) {
            StreamDutchSaleSupport.ArtistAssociation memory a =
                StreamDutchSaleSupport.artistAssociation(x, sale.config.collectionId);
            if (
                (a.state == 4 || a.state == 5) && a.artistId == sale.artistId
                    && a.generation == sale.bindingGeneration && a.bindingHash == sale.bindingHash
            ) {
                return keccak256("CLEARING_BOUND_ATTRIBUTION_STOPPED");
            }
        } else if (reason == 2) {
            if (
                registry.codehash != registryHash || !StreamSettlementAdmission.isContract(registry)
            ) {
                revert IStreamNativeClearingSale.ClearingDependencyInvalid(registry);
            }
            if (_incident(registry, address(this)) || _incident(registry, recorder)) {
                return keccak256("CLEARING_REFERENCED_MODULE_INCIDENT_REVOKED");
            }
        }
        return 0;
    }

    function _incident(address registry, address module) private view returns (bool) {
        bytes memory data = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (module));
        uint256[14] memory w;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), registry, add(data, 32), mload(data), w, 448)
            size := returndatasize()
        }
        if (
            !ok || size < 448 || w[0] != 32 || w[1] > 3 || w[5] > type(uint32).max || w[9] != 384
                || w[10] > type(uint64).max || w[11] > type(uint64).max || w[12] > type(uint64).max
                || w[13] > size - 448 || size - 448 != ((w[13] + 31) / 32) * 32
                || uint224(w[4]) != 0
        ) {
            revert IStreamNativeClearingSale.ClearingDependencyReadMalformed(registry, size);
        }
        if (w[1] != 3) return false;
        if (
            w[2] == 0 || w[3] == 0 || w[4] == 0 || w[6] == 0 || w[7] == 0 || w[8] == 0 || w[10] == 0
                || w[10] > block.timestamp || w[11] < w[10] || w[11] > block.timestamp || w[12] == 0
        ) {
            revert IStreamNativeClearingSale.ClearingDependencyReadMalformed(registry, size);
        }
        return true;
    }
}
