// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UniversalSettlementTestBase.sol";

/// @dev Native-domain opt-in after replacing the typed Core or real recorder. Shared Universal
///      setup is unchanged; Core/Metadata remain explicit seams and every floor receipt is real.
abstract contract NativeSaleConservationFixture is UniversalSettlementTestBase {
    function _bindNativeSaleConservationFloor() internal {
        _register(
            address(recorder), keccak256("PRIMARY_SALE_SETTLEMENT"),
            type(IStreamPrimarySaleSettlement).interfaceId
        );
        (address bound, bytes32 runtime) = core.conservationFloor();
        if (bound == address(0)) {
            conservationFloor = new StreamConservationFloor(
                address(core), address(revenueAuthority),
                IStreamGasParameterHost.GasParameterConfig(
                    "CONSERVATION_FLOOR_READ_GAS", 300_000, 300_000, 2
                ),
                IStreamGasParameterHost.GasParameterConfig(
                    "CONSERVATION_FLOOR_PRODUCER_GAS", 1_000_000, 1_000_000, 2
                ),
                IStreamGasParameterHost.GasParameterConfig(
                    "CONSERVATION_FLOOR_CALL_GAS", 2_000_000, 2_000_000, 2
                )
            );
            core.configureConservationFloor(address(conservationFloor), keccak256("CONSERVATION_WAIVED"));
            (bound, runtime) = core.conservationFloor();
        } else {
            // Clearing templates replace the recorder while retaining this Core and its floor.
            conservationFloor = StreamConservationFloor(bound);
        }
        require(bound == address(conservationFloor) && runtime == bound.codehash
            && bound.code.length != 0 && bound.code.length <= 24576
            && conservationFloor.core() == address(core)
            && conservationFloor.coreCodeHash() == address(core).codehash
            && core.declaredConservationTier(1) == keccak256("CONSERVATION_WAIVED")
            && conservationFloor.firstSale(1).receiptHash == 0,
            "original native fixture floor bound before any sale receipt");
        StreamModuleRecord memory r = registry.moduleRecord(address(recorder));
        require(r.status == ModuleRegistryStatus.ACTIVE
            && r.moduleType == keccak256("PRIMARY_SALE_SETTLEMENT")
            && r.runtimeCodeHash == address(recorder).codehash,
            "replacement official recorder admitted to original registry");
    }
}
