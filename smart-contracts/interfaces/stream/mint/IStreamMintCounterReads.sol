// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Counter accounting reads, separate from mint eligibility and authorization.
interface IStreamMintCounterReads is IERC165 {
    struct CounterKeyContext {
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 counterId;
        address payer;
        address initialRecipient;
        address beneficiary;
        address executor;
        address authorizer;
        uint256 tokenIndex;
        bytes32 contextHash;
        bytes resolverData;
    }

    struct CounterResolution {
        bytes32 subjectKey;
        uint64 effectiveCap;
        uint64 increment;
        bytes32 resolutionHash;
    }

    error MintCounterProofRequired(bytes32 counterId);
    error MintCounterTokenIndexInvalid(bytes32 counterId, uint256 tokenIndex);
    error MintCounterProofEncodingInvalid(bytes32 counterId);

    function rawCounterValue(bytes32 valueKey) external view returns (uint64);
    function counterValue(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        bytes32 subjectKey
    ) external view returns (uint64);

    /// @notice Remaining counter units, not token quantity; divide by the configured increment.
    /// @dev STATIC saturates at zero. NONE returns uint64 storage headroom, not a mint limit.
    /// MERKLE_STATIC needs a proof and reverts MintCounterProofRequired.
    function remainingForCounter(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        bytes32 subjectKey
    ) external view returns (uint64);

    /// @notice Resolves one original counter row without authorizing a mint.
    /// @dev CONTEXT requires the original uint256-max batch sentinel; other modes use index <10.
    /// MERKLE_STATIC resolverData is canonical abi.encode(one AllowlistProof).
    /// Other modes ignore resolverData as ordinary batch counter preparation does.
    function resolveCounter(CounterKeyContext calldata context)
        external
        view
        returns (CounterResolution memory);

    /// @notice Resolves a proof-aware cap and reads its current/remaining counter units atomically.
    function remainingForResolvedCounter(CounterKeyContext calldata context)
        external
        view
        returns (CounterResolution memory resolution, uint64 current, uint64 remaining);
}
