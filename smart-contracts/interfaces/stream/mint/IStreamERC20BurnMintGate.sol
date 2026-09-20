// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamMintGate } from "./IStreamMintGate.sol";
import { IStreamMintManager as M } from "./IStreamMintManager.sol";
import { IStreamBurnMintGate as B } from "./IStreamBurnMintGate.sol";
import { StreamERC20BurnMintTypes as E, S } from "./StreamERC20BurnMintTypes.sol";

/// @notice Dedicated paid ERC20 burn capability; this interface grants no free burn entry.
interface IStreamERC20BurnMintGate is IStreamMintGate {
    function core() external view returns (address);
    function erc20SaleAdapter() external view returns (address);
    function erc20SaleCodeHash() external view returns (bytes32);
    function configureProgram(B.ProgramConfig calldata config) external returns (bytes32);
    function program(uint256 targetCollectionId) external view returns (B.Program memory);
    function programConfigHash(B.ProgramConfig calldata config) external view returns (bytes32);
    function allowedSourceCollections(uint256 targetCollectionId)
        external
        view
        returns (uint256[] memory);
    function burnNullifier(uint256 sourceTokenId) external view returns (bytes32);

    /// @dev Guarded temporary proof; sole continuation is the immutable carrier's typed STATICCALL.
    /// Simulate through eth_call. It makes no burn, mint, payment or lasting proof/replay mutation.
    function previewERC20Burn(M.MintBatch calldata batch, E.Execution calldata execution)
        external
        returns (S.ERC20SettlementCandidate memory);

    /// @dev Genuine burn proof surrounds only the fixed carrier's exact typed settlement callback.
    function executeERC20Burn(M.MintBatch calldata batch, E.Execution calldata execution)
        external
        returns (E.Result memory);
}

/// @notice Fixed callbacks from the immutable gate; never arbitrary targets or call payloads.
interface IStreamERC20BurnMintContinuation {
    function previewBurnExecution(E.Execution calldata execution)
        external
        view
        returns (S.ERC20SettlementCandidate memory);
    function executeBurnMint(E.Execution calldata execution) external returns (E.Result memory);
}
