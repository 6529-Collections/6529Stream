// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintOperationIdentity.sol";

/// @notice Typed stored-counter preparation shared by the immutable Manager's linked calls.
/// @dev Reads only the exact storage references supplied by Manager; adds no authority or state.
library StreamMintManagerAccounting {
    function counterConsumptions(
        IStreamMintManager.MintBatch calldata request,
        uint256 quantity,
        address authorizer,
        address ledger,
        bytes32[] storage storedCounterIds,
        mapping(
            bytes32 => IStreamMintManager.MintCounterConfig
        ) storage storedConfigs
    ) public view returns (IStreamMintLedger.CounterConsumption[] memory) {
        bytes32[] memory counterIds = new bytes32[](storedCounterIds.length);
        IStreamMintManager.MintCounterConfig[] memory counterConfigs =
            new IStreamMintManager.MintCounterConfig[](storedCounterIds.length);
        for (uint256 i = 0; i < storedCounterIds.length; i++) {
            bytes32 counterId = storedCounterIds[i];
            counterIds[i] = counterId;
            counterConfigs[i] = storedConfigs[counterId];
        }
        StreamMintOperationIdentity.CounterContext memory context =
            StreamMintOperationIdentity.CounterContext({
                chainId: block.chainid,
                manager: address(this),
                ledger: ledger,
                executor: msg.sender,
                authorizer: authorizer
            });
        return StreamMintOperationIdentity.deriveCounterConsumptions(
            request, quantity, counterIds, counterConfigs, context
        );
    }

    function ledgerPolicies(
        bytes32[] storage counterIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage storedConfigs
    )
        public
        view
        returns (bytes32[] memory ids, IStreamMintLedger.LedgerCounterPolicy[] memory policies)
    {
        ids = new bytes32[](counterIds.length);
        policies = new IStreamMintLedger.LedgerCounterPolicy[](counterIds.length);
        for (uint256 i = 0; i < counterIds.length; i++) {
            bytes32 counterId = counterIds[i];
            ids[i] = counterId;
            IStreamMintManager.MintCounterConfig memory config = storedConfigs[counterId];
            policies[i] = IStreamMintLedger.LedgerCounterPolicy({
                enabled: config.enabled,
                capMode: config.capMode,
                deltaMode: config.deltaMode,
                staticCap: config.staticCap,
                staticIncrement: config.staticIncrement,
                counterConfigHash: config.counterConfigHash
            });
        }
    }
}
