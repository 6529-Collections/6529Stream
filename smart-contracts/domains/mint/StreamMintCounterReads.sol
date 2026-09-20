// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintCounterReads.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "./StreamMintManagerAccounting.sol";

/// @notice Fixed counter-only reads in Manager context; these never establish mint authority.
library StreamMintCounterReads {
    /// @notice Fixed dispatch for five counter reads and four retained accounting reads.
    /// @dev The facade passes its original calldata explicitly; library msg.data is never used.
    function read(bytes calldata callData) external view returns (bytes memory) {
        bytes4 selector = bytes4(callData[:4]);
        bytes calldata arguments = callData[4:];
        if (selector == IStreamMintReads.isAuthorizationUsed.selector) {
            return abi.encode(
                IStreamMintReads(address(this)).mintLedger()
                    .isManagerAuthorizationUsed(address(this), abi.decode(arguments, (bytes32)))
            );
        }
        if (selector == IStreamMintReads.isNullifierUsed.selector) {
            return abi.encode(
                IStreamMintReads(address(this)).mintLedger()
                    .isManagerNullifierUsed(address(this), abi.decode(arguments, (bytes32)))
            );
        }
        if (selector == IStreamMintReads.isOperationRootUsed.selector) {
            return abi.encode(
                IStreamMintReads(address(this)).mintLedger()
                    .isManagerOperationRootUsed(address(this), abi.decode(arguments, (bytes32)))
            );
        }
        if (selector == IStreamMintReads.phasePolicyGrace.selector) {
            (uint256 collectionId, bytes32 phaseId) = abi.decode(arguments, (uint256, bytes32));
            (bytes32 previousPolicyHash,, uint64 graceUntil) = IStreamMintReads(address(this))
                .mintLedger().policyGrace(address(this), collectionId, phaseId);
            return abi.encode(previousPolicyHash, graceUntil);
        }
        if (selector == IStreamMintCounterReads.rawCounterValue.selector) {
            return abi.encode(
                IStreamMintReads(address(this)).mintLedger()
                    .counterValue(abi.decode(arguments, (bytes32)))
            );
        }
        if (
            selector == IStreamMintCounterReads.counterValue.selector
                || selector == IStreamMintCounterReads.remainingForCounter.selector
        ) {
            return abi.encode(
                _valueRead(
                    arguments, selector == IStreamMintCounterReads.remainingForCounter.selector
                )
            );
        }
        // No user-supplied target, call, storage location or selector outside this fixed table.
        assert(
            selector == IStreamMintCounterReads.resolveCounter.selector
                || selector == IStreamMintCounterReads.remainingForResolvedCounter.selector
        );
        return _resolveEncoded(
            arguments, selector == IStreamMintCounterReads.remainingForResolvedCounter.selector
        );
    }

    /// @notice Decodes the original four-word counter read at the fixed boundary.
    function _valueRead(bytes calldata arguments, bool withRemaining)
        private
        view
        returns (uint64)
    {
        (uint256 collectionId, bytes32 phaseId, bytes32 counterId, bytes32 subject) =
            abi.decode(arguments, (uint256, bytes32, bytes32, bytes32));
        IStreamMintManager.MintCounterConfig memory config =
            _config(collectionId, phaseId, counterId);
        if (withRemaining && config.capMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC) {
            revert IStreamMintCounterReads.MintCounterProofRequired(counterId);
        }
        uint64 current = _value(collectionId, phaseId, counterId, subject);
        return withRemaining ? _remaining(config.capMode, config.staticCap, current) : current;
    }

    /// @notice Returns the exact static 128/192-byte caller ABI without facade tuple re-encoding.
    function _resolveEncoded(bytes calldata arguments, bool withRemaining)
        private
        view
        returns (bytes memory)
    {
        IStreamMintCounterReads.CounterKeyContext memory x =
            abi.decode(arguments, (IStreamMintCounterReads.CounterKeyContext));
        (
            IStreamMintCounterReads.CounterResolution memory resolution,
            uint64 current,
            uint64 remainingUnits
        ) = _resolve(x);
        return
            withRemaining ? abi.encode(resolution, current, remainingUnits) : abi.encode(resolution);
    }

    function _resolve(IStreamMintCounterReads.CounterKeyContext memory x)
        private
        view
        returns (
            IStreamMintCounterReads.CounterResolution memory result,
            uint64 current,
            uint64 allowance
        )
    {
        IStreamMintManager.MintCounterConfig memory config =
            _config(x.collectionId, x.phaseId, x.counterId);
        bool batchScoped = config.keyMode == IStreamMintManager.CounterKeyMode.CONTEXT;
        if (batchScoped ? x.tokenIndex != type(uint256).max : x.tokenIndex >= 10) {
            revert IStreamMintCounterReads.MintCounterTokenIndexInvalid(x.counterId, x.tokenIndex);
        }
        address ledger = address(IStreamMintReads(address(this)).mintLedger());
        StreamMintOperationIdentity.CounterContext memory counterContext =
            StreamMintOperationIdentity.CounterContext(
                block.chainid, address(this), ledger, x.executor, x.authorizer
            );
        IStreamMintLedger.CounterConsumption memory row =
            StreamMintOperationIdentity.counterConsumption(
                StreamMintOperationIdentity.SubjectContext(
                    block.chainid,
                    ledger,
                    x.collectionId,
                    x.phaseId,
                    x.counterId,
                    x.payer,
                    batchScoped ? address(0) : x.beneficiary,
                    x.executor,
                    x.authorizer,
                    x.contextHash
                ),
                config,
                x.tokenIndex,
                counterContext
            );
        row = StreamMintCounterPreparation.resolveCounter(
            row, config, counterContext, x.resolverData
        );
        result = IStreamMintCounterReads.CounterResolution(
            row.subjectKey, row.cap, row.increment, row.resolutionHash
        );
        current = IStreamMintLedger(ledger).counterValue(row.valueKey);
        allowance = _remaining(config.capMode, row.cap, current);
    }

    function _config(uint256 collectionId, bytes32 phaseId, bytes32 counterId)
        private
        view
        returns (IStreamMintManager.MintCounterConfig memory config)
    {
        if (collectionId == 0 || phaseId == bytes32(0)) {
            revert IStreamMintManager.InvalidMintPhase(collectionId, phaseId);
        }
        IStreamMintReads host = IStreamMintReads(address(this));
        (bool exists,) = host.phase(collectionId, phaseId);
        if (!exists) revert IStreamMintManager.MintPhaseDoesNotExist(collectionId, phaseId);
        config = host.counterConfig(collectionId, phaseId, counterId);
        if (!config.enabled) revert IStreamMintManager.InvalidMintCounter(counterId);
    }

    function _value(uint256 collectionId, bytes32 phaseId, bytes32 counterId, bytes32 subject)
        private
        view
        returns (uint64)
    {
        if (subject == bytes32(0)) revert IStreamMintManager.InvalidMintCounter(counterId);
        address ledger = address(IStreamMintReads(address(this)).mintLedger());
        bytes32 key = StreamMintManagerAccounting.previewValue(
            ledger, collectionId, phaseId, counterId, subject
        );
        return IStreamMintLedger(ledger).counterValue(key);
    }

    function _remaining(IStreamMintLedger.CounterCapMode mode, uint64 cap, uint64 current)
        private
        pure
        returns (uint64)
    {
        if (mode == IStreamMintLedger.CounterCapMode.NONE) {
            return type(uint64).max - current;
        }
        return current >= cap ? 0 : cap - current;
    }
}
