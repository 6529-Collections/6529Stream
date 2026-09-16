// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./IStreamMintManager.sol";

/// @notice Immutable, content-addressed extensions to the retained counter configuration ABI.
interface IStreamMintCounterPolicy is IERC165 {
    enum CounterScope {
        GLOBAL,
        COLLECTION,
        PHASE
    }

    struct Definition {
        CounterScope scope;
        IStreamMintManager.CounterKeyMode keyMode;
        bytes32 capRoot;
        bytes32 metadataHash;
    }

    struct AllowlistProof {
        uint64 maxCount;
        bool hasPriceOverride;
        uint256 priceOverride;
        bytes32[] proof;
    }

    error InvalidCounterDefinition();
    error MintAllowlistProofInvalid(bytes32 counterId, address account);
    error MintAllowlistProofCountMismatch(uint256 supplied, uint256 required);
    error MintAllowlistPriceOverrideUnsupported(
        bytes32 counterId, address account, bool hasPriceOverride, uint256 priceOverride
    );

    event MintCounterDefinitionRegistered(
        bytes32 indexed definitionHash,
        CounterScope scope,
        IStreamMintManager.CounterKeyMode keyMode,
        bytes32 capRoot,
        bytes32 metadataHash
    );

    /// @notice Registers immutable data; registration grants no configuration or mint authority.
    function registerCounterDefinition(Definition calldata definition) external returns (bytes32);
    /// @notice Returns an existing hash preimage. Unknown hashes retain the original phase scope.
    function counterDefinition(bytes32 definitionHash)
        external
        view
        returns (bool exists, Definition memory definition);
    /// @notice First policy use pins the interpretation, including an absent legacy definition.
    function counterDefinitionForManager(address manager, bytes32 definitionHash)
        external
        view
        returns (bool exists, Definition memory definition);
    function managerDefinitionCount(address manager) external view returns (uint256);
    function managerDefinitionAt(address manager, uint256 index)
        external
        view
        returns (bytes32 definitionHash, bool defined, Definition memory definition);
}
