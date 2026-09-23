// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintManager.sol";
import "./StreamMintFallbackRecovery.sol";

/// @notice Distinct full mint Manager with a narrow, governance-bound incident recovery path.
contract StreamMintManagerFallback is StreamMintManager, IStreamMintFallbackRecovery {
    constructor(IStreamCore core_, IStreamMintLedger ledger_, IERC165 registry_)
        StreamMintManager(core_, ledger_, registry_)
    { }

    function recoverPreparedMint(uint256 tokenId, bytes32 operationId)
        external
        override
        nonReentrant
    {
        StreamMintFallbackRecovery.recover(tokenId, operationId);
    }
}
