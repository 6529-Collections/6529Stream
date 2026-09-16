// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintOperationIdentity.sol";
import "./StreamMintCounterPreparation.sol";

/// @notice Typed stored-counter preparation shared by the immutable Manager's linked calls.
/// @dev Reads only the exact storage references supplied by Manager; adds no authority or state.
library StreamMintManagerAccounting {
    function previewSubject(
        IStreamMintManager.CounterKeyMode keyMode,
        StreamMintOperationIdentity.SubjectContext memory context
    ) external view returns (bytes32) {
        bytes32 definitionHash =
            IStreamMintManager(address(this))
        .counterConfig(context.collectionId, context.phaseId, context.counterId)
        .counterConfigHash;
        (, IStreamMintCounterPolicy.Definition memory d) =
            StreamMintCounterPolicy.read(context.ledger, definitionHash);
        (context.collectionId, context.phaseId) =
            StreamMintCounterPolicy.scopeIds(d.scope, context.collectionId, context.phaseId);
        return StreamMintOperationIdentity.subjectKey(keyMode, context);
    }

    function previewValue(
        address ledger,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        bytes32 subject
    ) external view returns (bytes32) {
        bytes32 definitionHash =
            IStreamMintManager(address(this))
        .counterConfig(collectionId, phaseId, counterId)
        .counterConfigHash;
        (, IStreamMintCounterPolicy.Definition memory d) =
            StreamMintCounterPolicy.read(ledger, definitionHash);
        (collectionId, phaseId) = StreamMintCounterPolicy.scopeIds(d.scope, collectionId, phaseId);
        return IStreamMintLedger(ledger)
            .deriveCounterValueKey(address(this), collectionId, phaseId, counterId, subject);
    }

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
        return StreamMintCounterPreparation.prepare(
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
