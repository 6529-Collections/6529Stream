// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../current/helpers/NativeCuratedSaleFixture.sol";
import "../../smart-contracts/domains/metadata/StreamConservationFloor.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

/// @dev Explicit selected-Metadata writer boundary for typed commerce fixtures only.
contract NativeCommerceTierWriter {
    address public immutable core;

    constructor(address core_) {
        core = core_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamCollectionMetadataV1).interfaceId;
    }

    function declareWaived() external {
        IStreamCoreConservationTier(core)
            .recordConservationTier(1, keccak256("CONSERVATION_WAIVED"));
    }
}

/// @notice Opt-in actual Core/floor ledger for the existing typed native commerce graph.
/// @dev Governance, Artist, entropy and selected Metadata writer are explicit boundaries.
/// This does not demonstrate actual Artist onboarding or Metadata class-7/8 authorization.
abstract contract NativeCuratedCommerceConservationFixture is NativeCuratedSaleFixture {
    StreamConservationFloor internal nativeCommerceFloor;
    bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");

    function _enableNativeCommerceFloor() internal {
        uint256 floorCallGas = 2_000_000;
        (uint256 callbackGas,,,) =
            manager.gasParameterInfo(manager.GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT());
        require(callbackGas == 4_000_000, "original prepared callback genesis");
        require(
            floorCallGas + floorCallGas / 63 + 103_300 < callbackGas,
            "waived floor reservation fits callback ceiling"
        );
        (address bound, bytes32 runtime) = core.conservationFloor();
        require(
            address(nativeCommerceFloor) == address(0) && bound == address(0) && runtime == 0
                && core.declaredConservationTier(1) == 0 && core.collectionMintedEver(1) == 0,
            "explicit floor setup precedes mint"
        );
        NativeCommerceTierWriter metadata = new NativeCommerceTierWriter(address(core));
        _register(
            address(metadata),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("COLLECTION_METADATA"), address(metadata));
        metadata.declareWaived();
        IStreamGasParameterHost.GasParameterConfig memory reads =
            IStreamGasParameterHost.GasParameterConfig(
                "CONSERVATION_FLOOR_READ_GAS", 300000, 300000, 2
            );
        IStreamGasParameterHost.GasParameterConfig memory producer =
            IStreamGasParameterHost.GasParameterConfig(
                "CONSERVATION_FLOOR_PRODUCER_GAS", 1000000, 1000000, 2
            );
        IStreamGasParameterHost.GasParameterConfig memory callGas =
            IStreamGasParameterHost.GasParameterConfig(
                "CONSERVATION_FLOOR_CALL_GAS", floorCallGas, floorCallGas, 2
            );
        require(
            type(StreamConservationFloor).creationCode.length
                    + abi.encode(address(core), address(revenueAuthority), reads, producer, callGas)
                    .length <= 49152,
            "actual floor initcode cap"
        );
        nativeCommerceFloor = new StreamConservationFloor(
            address(core), address(revenueAuthority), reads, producer, callGas
        );
        require(address(nativeCommerceFloor).code.length <= 24576, "actual floor runtime cap");
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            core.conservationFloorTransition(address(nativeCommerceFloor));
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        core.bindConservationFloor(address(nativeCommerceFloor));
        _clearContext();
        (bound, runtime) = core.conservationFloor();
        require(
            bound == address(nativeCommerceFloor)
                && runtime == address(nativeCommerceFloor).codehash
                && core.declaredConservationTier(1) == WAIVED
                && nativeCommerceFloor.firstSale(1).receiptHash == 0,
            "actual bound ledger and explicit tier, without a sale"
        );
    }

    function _assertNativeCommerceReceipt(bytes32 key, uint256 tokenId) internal view {
        StreamConservationFloorTypes.SettlementReceipt memory receipt =
            nativeCommerceFloor.settlementReceipt(key);
        StreamConservationFloorTypes.FirstSaleReceipt memory first =
            nativeCommerceFloor.firstSale(1);
        require(
            key != 0 && receipt.receiptHash != 0 && receipt.recorder == address(recorder)
                && receipt.recorderCodeHash == address(recorder).codehash
                && receipt.settlementKey == key && receipt.collectionId == 1
                && receipt.tokenId == tokenId && receipt.effectiveTier == WAIVED
                && first.receiptHash != 0 && first.collectionId == 1
                && first.effectiveTier == WAIVED
                && receipt.firstSaleReceiptHash == first.receiptHash,
            "original prepared settlement floor receipt"
        );
    }
}
