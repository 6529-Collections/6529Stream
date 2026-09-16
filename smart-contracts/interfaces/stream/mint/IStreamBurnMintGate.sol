// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamMintGate } from "./IStreamMintGate.sol";
import { IStreamMintManager } from "./IStreamMintManager.sol";

/// @notice Same-transaction native Stream burn eligibility and atomic free mint executor.
interface IStreamBurnMintGate is IStreamMintGate {
    struct ProgramConfig {
        address manager;
        uint256 targetCollectionId;
        bytes32 phaseId;
        uint256[] sourceCollectionIds;
        uint8 sourcesPerMint;
        uint64 startsAt;
        uint64 endsAt;
        bool prepared;
        address nativeSaleAdapter;
    }

    struct Program {
        ProgramConfig config;
        bytes32 configHash;
        bytes32 managerCodeHash;
        bytes32 nativeSaleCodeHash;
    }

    error InvalidBurnMintConfiguration();
    error BurnMintProgramAlreadyConfigured(uint256 targetCollectionId);
    error BurnMintProgramUnavailable(uint256 targetCollectionId);
    error BurnMintPolicyMismatch();
    error BurnMintTokenInvalid(uint256 tokenId);
    error BurnMintAuthorityRequired(uint256 tokenId, address actor);
    error BurnMintExecutionFailed(uint256 tokenId);
    error BurnMintProofUnavailable();
    error BurnMintResultInvalid();
    error BurnMintDependencyInvalid(address target);
    error BurnMintParentGasInsufficient(uint256 cap, uint256 available);

    event BurnMintProgramConfigured(
        uint16 schemaVersion,
        uint256 indexed targetCollectionId,
        address indexed manager,
        bytes32 indexed phaseId,
        bytes32 configHash,
        ProgramConfig config
    );
    event BurnMintExecuted(
        uint16 schemaVersion,
        uint256 indexed sourceTokenId,
        uint256 indexed mintedTokenId,
        uint256 indexed targetCollectionId,
        bytes32 burnNullifier,
        address redeemer
    );
    event BurnMintBatchExecuted(
        uint16 schemaVersion,
        uint256 indexed targetCollectionId,
        bytes32 indexed operationRoot,
        address indexed burnCaller,
        uint256[] sourceTokenIds,
        address[] sourceOwners,
        uint256[] mintedTokenIds
    );

    function core() external view returns (address);
    function configureProgram(ProgramConfig calldata config) external returns (bytes32 configHash);
    function program(uint256 targetCollectionId) external view returns (Program memory);
    function programConfigHash(ProgramConfig calldata config) external view returns (bytes32);
    function allowedSourceCollections(uint256 targetCollectionId)
        external
        view
        returns (uint256[] memory sourceCollectionIds);
    function burnNullifier(uint256 sourceTokenId) external view returns (bytes32);

    /// @notice Caller must own or be approved for every source; this host separately needs burn approval.
    /// @dev Sorted distinct source IDs; no preburns, external sources or token-custody substitution.
    ///      msg.value is exactly the captured reveal fee for the entire free batch.
    function burnAndMint(
        IStreamMintManager.MintBatch calldata batch,
        uint256[] calldata sourceTokenIds
    )
        external
        payable
        returns (uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds);
}
