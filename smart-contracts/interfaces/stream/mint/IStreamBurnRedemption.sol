// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Same-transaction native Stream burns against immutable redemption terms.
interface IStreamBurnRedemption is IERC165 {
    struct ProgramConfig {
        uint256 collectionId;
        uint64 startTime;
        uint64 endTime;
        bytes32 termsHash;
    }

    struct Program {
        ProgramConfig config;
        bytes32 saleConfigHash;
        uint256 saleNonce;
        uint64 createdAt;
        uint64 registryRevision;
        bool cancelled;
    }

    struct Redemption {
        bytes32 saleId;
        uint256 tokenId;
        uint256 collectionId;
        uint256 collectionSerial;
        address redeemer;
        address tokenOwner;
        bytes32 termsHash;
        bytes32 fulfillmentReferenceHash;
        string fulfillmentURI;
        uint64 recordedAt;
    }

    struct Fulfillment {
        bytes32 referenceHash;
        string fulfillmentURI;
        bytes32 previousUpdateHash;
        bytes32 updateHash;
        address recorder;
        uint64 recordedAt;
    }

    error InvalidRedemptionConfiguration();
    error InvalidRedemptionProgram();
    error UnknownRedemption(bytes32 redemptionId);
    error RedemptionProgramClosed(bytes32 saleId);
    error RedemptionTermsMismatch();
    error RedemptionAuthorityRequired(uint256 tokenId);
    error RedemptionTokenInvalid(uint256 tokenId);
    error RedemptionBurnFailed(uint256 tokenId);
    error RedemptionDependencyChanged(address target);
    error RedemptionReadFailed(address target);
    error RedemptionModuleNotAdmitted();
    error RedemptionIndexOutOfBounds();

    event SaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint8 saleKind,
        address asset,
        bytes32 saleConfigHash,
        bytes32 expectedPrimaryPolicyHash,
        uint8 primaryPolicyMode
    );
    event RedemptionTermsRecorded(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed termsHash,
        uint64 startTime,
        uint64 endTime,
        uint256 saleNonce,
        address operator
    );
    event RedemptionProgramCancelled(uint16 schemaVersion, bytes32 indexed saleId);
    event RedemptionRecorded(
        uint16 schemaVersion,
        bytes32 indexed redemptionId,
        uint256 indexed burnedTokenId,
        uint256 indexed collectionId,
        address redeemer,
        bytes32 fulfillmentHash,
        string fulfillmentURI
    );
    event RedemptionFulfilled(
        uint16 schemaVersion,
        bytes32 indexed redemptionId,
        bytes32 fulfillmentHash,
        string fulfillmentURI
    );
    event RedemptionContextRecorded(
        uint16 schemaVersion,
        bytes32 indexed redemptionId,
        bytes32 indexed saleId,
        Redemption record
    );
    event RedemptionFulfillmentContext(
        uint16 schemaVersion,
        bytes32 indexed redemptionId,
        uint256 indexed updateIndex,
        Fulfillment update
    );

    function core() external view returns (address);
    function registerProgram(ProgramConfig calldata config) external returns (bytes32 saleId);
    function cancelProgram(bytes32 saleId) external;
    function program(bytes32 saleId) external view returns (Program memory);
    /// @dev Caller authority and this executor's ERC721 approval are checked separately.
    ///      The expected terms and reference are chosen by the redeemer, including a Safe.
    function redeem(
        bytes32 saleId,
        uint256 tokenId,
        bytes32 expectedTermsHash,
        bytes32 fulfillmentReferenceHash,
        string calldata fulfillmentURI
    ) external returns (bytes32 redemptionId);
    function redemptionIdFor(uint256 tokenId) external view returns (bytes32);
    function redemption(bytes32 redemptionId) external view returns (Redemption memory);
    function recordFulfillment(
        bytes32 redemptionId,
        bytes32 referenceHash,
        string calldata fulfillmentURI
    ) external returns (bytes32 updateHash);
    function fulfillmentCount(bytes32 redemptionId) external view returns (uint256);
    function fulfillmentAt(bytes32 redemptionId, uint256 index)
        external
        view
        returns (Fulfillment memory);
    function redemptionCount(bytes32 saleId) external view returns (uint256);
    function redemptionAt(bytes32 saleId, uint256 index) external view returns (bytes32);
}
