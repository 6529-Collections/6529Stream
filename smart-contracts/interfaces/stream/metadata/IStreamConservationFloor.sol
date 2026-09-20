// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "../parameters/IStreamGasParameterHost.sol";
import "../revenue/StreamPrimarySettlementTypes.sol";
import "../revenue/StreamNativeSupplementalTypes.sol";
import "./StreamConservationFloorTypes.sol";

/// @notice Permanent Core-bound sale-floor receipt owner, independent of Metadata/recorder replacement.
interface IStreamConservationFloor is IERC165, IStreamGasParameterHost {
    error InvalidConservationFloorConfiguration();
    error ConservationFloorNotBound();
    error ConservationFloorDependency(address target);
    error ConservationFloorRead(address target, bytes4 selector);
    error ConservationFloorAuthority(address caller);
    error ConservationFloorSourceUnavailable();
    error ConservationFloorInvalidEvidence();
    error ConservationFloorSettlementMismatch(bytes32 settlementKey);
    error ConservationFloorAlreadyRecorded(bytes32 settlementKey);
    error ConservationFloorOriginalReceiptMissing(bytes32 settlementKey);
    error ConservationFloorReentrant();

    event ConservationFloorSourceAdded(
        uint64 indexed sourceId, address indexed metadata, address indexed provider,
        bytes32 sourceSetHash, StreamConservationFloorTypes.Source source, uint16 schemaVersion
    );
    event ConservationFirstSaleRecorded(
        uint256 indexed collectionId, bytes32 indexed receiptHash,
        StreamConservationFloorTypes.FirstSaleReceipt receipt, uint16 schemaVersion
    );
    event ConservationReleaseFloorRecorded(
        bytes32 indexed releaseKey, bytes32 indexed receiptHash,
        StreamConservationFloorTypes.ReleaseFloorReceipt receipt, uint16 schemaVersion
    );
    event ConservationSettlementRecorded(
        bytes32 indexed settlementKey, bytes32 indexed receiptHash,
        StreamConservationFloorTypes.SettlementReceipt receipt, uint16 schemaVersion
    );

    function core() external view returns (address);
    function coreCodeHash() external view returns (bytes32);
    function executorCodeHash() external view returns (bytes32);
    function deploymentChainId() external view returns (uint256);
    function sourceCount() external view returns (uint64);
    function sourceAt(uint64 sourceId) external view returns (StreamConservationFloorTypes.Source memory);
    function sourceSetHead() external view returns (uint64 count, bytes32 head);
    function sourceSetHashAt(uint64 count) external view returns (bytes32);
    function sourceTransition(address metadata, address provider, uint64 predecessor)
        external view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function appendSource(address metadata, address provider, uint64 predecessor) external;

    function firstSale(uint256 collectionId)
        external view returns (StreamConservationFloorTypes.FirstSaleReceipt memory);
    function releaseFloorReceipt(bytes32 releaseKey)
        external view returns (StreamConservationFloorTypes.ReleaseFloorReceipt memory);
    function settlementReceipt(bytes32 settlementKey)
        external view returns (StreamConservationFloorTypes.SettlementReceipt memory);
    function recordPrimarySale(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        StreamPrimarySettlementTypes.PrimarySettlementResult calldata result
    ) external returns (bytes32 receiptHash);
    /// @notice No new floor: authenticate the exact original sale receipt and current genuine purchase.
    function requireSupplemental(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate calldata candidate,
        StreamNativeSupplementalTypes.NativeSupplementalResult calldata result
    ) external view returns (bytes32 originalReceiptHash);
}
