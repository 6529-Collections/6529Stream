// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/domains/metadata/StreamConservationFloor.sol";
import "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleFloorCall.sol";

/// @notice Opt-in commerce setup through the actual Core, Metadata, delayed Executor and Safe.
/// @dev Explicit WAIVED commerce coverage is not evidence of the MUSEUM/LITE documentary floor.
/// These gas values are fixture configuration, not production defaults or a 500k gas acceptance.
abstract contract CurrentCommerceConservationFixture is StreamCurrentSafeGovernanceFixture {
    uint256 internal constant FIXTURE_FLOOR_READ_GAS = 300_000;
    uint256 internal constant FIXTURE_FLOOR_PRODUCER_GAS = 1_000_000;
    uint256 internal constant FIXTURE_FLOOR_CALL_GAS = 2_000_000;
    bytes32 internal constant COMMERCE_WAIVED = keccak256("CONSERVATION_WAIVED");
    StreamConservationFloor internal commerceFloor;
    bytes32 private floorBindingAction;
    bytes32 private floorWriterAction;
    bytes private floorBindingData;
    bytes private floorWriterData;

    function _commerceFloorPolicies(GovernanceActionPolicyEntry[] memory existing)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](2);
        additions[0] = _commerceFloorPolicy(address(core), core.bindConservationFloor.selector);
        additions[1] = _commerceFloorPolicy(
            address(assemblyMetadata), assemblyMetadata.setFamilyWriter.selector
        );
        uint256 count = existing.length;
        bool[2] memory present;
        for (uint256 i; i < 2; ++i) {
            for (uint256 j; j < existing.length; ++j) {
                if (
                    existing[j].actionClass == additions[i].actionClass
                        && existing[j].target == additions[i].target
                        && existing[j].selector == additions[i].selector
                ) {
                    require(
                        keccak256(abi.encode(existing[j])) == keccak256(abi.encode(additions[i])),
                        "exact duplicate floor policy"
                    );
                    present[i] = true;
                }
            }
            if (!present[i]) ++count;
        }
        rows = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < existing.length; ++i) {
            rows[i] = existing[i];
        }
        count = existing.length;
        for (uint256 i; i < 2; ++i) {
            if (!present[i]) rows[count++] = additions[i];
        }
    }

    function _commerceFloorPolicy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            0
        );
    }

    /// @dev Schedule and wait before signing a paid transaction so its exact retry cannot expire
    /// while the real class-1 delay elapses. Scheduling does not bind or declare anything.
    function _prepareCommerceFloor() internal {
        require(address(commerceFloor) == address(0), "one fixture floor");
        (uint256 callbackGas,,,) =
            manager.gasParameterInfo(manager.GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT());
        // Necessary reservation compatibility; this does not prove total callback gas usage.
        require(callbackGas == 4_000_000, "original prepared callback genesis");
        require(
            FIXTURE_FLOOR_CALL_GAS + FIXTURE_FLOOR_CALL_GAS / 63 + 103_300 < callbackGas,
            "waived floor reservation fits callback ceiling"
        );
        commerceFloor = StreamConservationFloor(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamConservationFloor.sol:StreamConservationFloor",
                abi.encode(
                    address(core),
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_READ_GAS",
                        FIXTURE_FLOOR_READ_GAS,
                        FIXTURE_FLOOR_READ_GAS,
                        2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_PRODUCER_GAS",
                        FIXTURE_FLOOR_PRODUCER_GAS,
                        FIXTURE_FLOOR_PRODUCER_GAS,
                        2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_CALL_GAS",
                        FIXTURE_FLOOR_CALL_GAS,
                        FIXTURE_FLOOR_CALL_GAS,
                        2
                    )
                )
            )
        );
        _assertDeployableProductionInstance(address(commerceFloor));
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            core.conservationFloorTransition(address(commerceFloor));
        floorBindingData = abi.encodeCall(core.bindConservationFloor, (address(commerceFloor)));
        GovernanceActionRequest memory binding =
            _governanceRequest(1, address(core), floorBindingData, scope, oldState, newState);
        floorBindingAction = _scheduleAsGovernor(binding);
        (scope, oldState, newState) = assemblyMetadata.familyWriterTransition(
            1, StreamRecordFamilies.CONSERVATION, 7, address(governorSafe), true
        );
        floorWriterData = abi.encodeCall(
            assemblyMetadata.setFamilyWriter,
            (1, StreamRecordFamilies.CONSERVATION, 7, address(governorSafe), true)
        );
        GovernanceActionRequest memory writer = _governanceRequest(
            1, address(assemblyMetadata), floorWriterData, scope, oldState, newState
        );
        floorWriterAction = _scheduleAsGovernor(writer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                floorBindingAction,
                binding.notBefore
            )
        );
        executor.executeGovernanceAction(floorBindingAction, floorBindingData);
        vm.warp(binding.notBefore > writer.notBefore ? binding.notBefore : writer.notBefore);
        (address bound, bytes32 runtime) = core.conservationFloor();
        require(
            bound == address(0) && runtime == 0 && core.declaredConservationTier(1) == 0,
            "scheduled actions leave floor unbound and undeclared"
        );
        _assertNoCommerceFloorReceipt(bytes32(0));
    }

    function _bindCommerceFloor() internal {
        _executeAsGovernor(floorBindingAction, floorBindingData);
        (address bound, bytes32 runtime) = core.conservationFloor();
        require(
            bound == address(commerceFloor) && runtime == address(commerceFloor).codehash,
            "permanent actual Core floor binding"
        );
        require(core.declaredConservationTier(1) == 0, "binding is not a waiver");
    }

    function _declareWaivedCommerce() internal {
        _executeAsGovernor(floorWriterAction, floorWriterData);
        (bool collectionWriter, uint64 revision) = assemblyMetadata.familyWriter(
            1, StreamRecordFamilies.CONSERVATION, 7, address(governorSafe)
        );
        (bool globalWriter,) = assemblyMetadata.familyWriter(
            0, StreamRecordFamilies.CONSERVATION, 8, address(governorSafe)
        );
        require(
            collectionWriter && revision == 1 && !globalWriter,
            "only explicit collection-scoped conservation grant"
        );
        require(
            executeSafe(
                governorSafe,
                governorKeys,
                address(assemblyMetadata),
                0,
                abi.encodeCall(assemblyMetadata.declareConservationTier, (1, COMMERCE_WAIVED)),
                0
            ),
            "actual narrow-grant Safe declaration"
        );
        (bytes32 declared, bytes32 effective) = assemblyMetadata.conservationTier(1);
        require(
            core.declaredConservationTier(1) == COMMERCE_WAIVED && declared == COMMERCE_WAIVED
                && effective == COMMERCE_WAIVED,
            "explicit original declaration"
        );
        require(
            core.collectionMintedEver(1) == 0 && commerceFloor.firstSale(1).receiptHash == 0,
            "declaration precedes first mint and sale"
        );
    }

    function _enableWaivedCommerceFloor() internal {
        _prepareCommerceFloor();
        _bindCommerceFloor();
        _declareWaivedCommerce();
    }

    function _assertNoCommerceFloorReceipt(bytes32 settlementKey) internal view {
        require(
            commerceFloor.firstSale(1).receiptHash == 0
                && commerceFloor.settlementReceipt(settlementKey).receiptHash == 0,
            "failed sale cannot persist floor receipts"
        );
    }

    function _assertWaivedCommerceReceipt(address recorder, bytes32 settlementKey) internal view {
        // Original native settlement pays before mint; the receipt retains candidate token zero.
        _assertWaivedCommerceReceipt(recorder, settlementKey, 0);
    }

    function _assertWaivedCommerceReceipt(
        address recorder,
        bytes32 settlementKey,
        uint256 expectedTokenId
    ) internal view {
        StreamConservationFloorTypes.SettlementReceipt memory receipt =
            commerceFloor.settlementReceipt(settlementKey);
        StreamConservationFloorTypes.FirstSaleReceipt memory first = commerceFloor.firstSale(1);
        require(
            receipt.receiptHash != 0 && receipt.recorder == recorder
                && receipt.recorderCodeHash == recorder.codehash
                && receipt.settlementKey == settlementKey && receipt.collectionId == 1
                && receipt.tokenId == expectedTokenId && receipt.effectiveTier == COMMERCE_WAIVED
                && receipt.firstSaleReceiptHash == first.receiptHash && first.receiptHash != 0
                && first.collectionId == 1 && first.effectiveTier == COMMERCE_WAIVED,
            "genuine original paid WAIVED receipt"
        );
    }
}
