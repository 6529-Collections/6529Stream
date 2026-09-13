// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamPrimarySettlementBindings.sol";
import "./IStreamRevenueEscrow.sol";
import "./StreamPrimarySettlementTypes.sol";

/// @notice Contract 9: official revenue recorder. It cannot spend payer allowances.
interface IStreamPrimarySaleSettlement is IStreamPrimarySettlementBindings {
    error InvalidPrimarySale();
    error SettlementAlreadyConsumed(bytes32 settlementKey);
    error PrimarySettlementRightsMismatch();
    error PrimarySettlementPolicyMismatch();
    error PrimarySettlementPaymentBindingInvalid(address paymentAdapter);
    error PrimarySettlementEscrowMismatch();

    event PrimaryRevenueSettled(
        bytes32 indexed settlementKey,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        uint16 schemaVersion,
        address wallet,
        address asset,
        address payer,
        uint256 amount,
        bytes32 saleContextHash,
        bool policyDrift,
        uint8 assignmentType
    );
    event PrimaryRevenueSettlementContext(
        bytes32 indexed settlementKey,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        uint16 schemaVersion,
        address settlementCaller,
        bytes32 settlementId,
        uint8 policyMode,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 operationRoot,
        bytes32 operationId,
        uint256 saleNonce,
        address poster,
        address beneficiary,
        bytes32 templateId
    );
    event PrimaryRevenueSettlementPolicy(
        bytes32 indexed settlementKey,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        uint16 schemaVersion,
        bytes32 expectedPrimaryPolicyHash,
        bytes32 resolvedPrimaryPolicyHash,
        bytes32 resolvedAssignmentHash,
        bytes32 templateId
    );
    /// @notice Authenticated execution joins the canonical RSR context without redefining its ABI.
    event PrimaryRevenueExecutionBound(
        bytes32 indexed settlementKey,
        address indexed saleAdapter,
        bytes32 indexed executionId,
        uint16 schemaVersion,
        address executor,
        address paymentAdapter,
        bytes32 candidateCommitment,
        bytes32 currentPolicyHash,
        bytes32 boundPolicyHash
    );

    function isStreamPrimarySaleSettlement() external pure returns (bool);
    function revenueEscrow() external view returns (IStreamRevenueEscrow);
    function settleERC20PrimarySaleFromAdapter(
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate
    ) external returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
    function settlementKey(address saleAdapter, bytes32 executionId) external view returns (bytes32);
    function settlementConsumed(bytes32 key) external view returns (bool);
    function settlementResult(bytes32 key)
        external
        view
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
    function officialSettled(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        external
        view
        returns (uint256);
    function totalOfficialSettled(address asset) external view returns (uint256);
}
