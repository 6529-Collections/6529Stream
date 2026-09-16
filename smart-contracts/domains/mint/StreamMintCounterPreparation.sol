// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintOperationIdentity.sol";
import "./StreamMintCounterPolicy.sol";

/// @notice Applies immutable scoped policy and inline proof-bound caps to canonical consumptions.
library StreamMintCounterPreparation {
    bytes32 private constant VALUE_KEY_DOMAIN = keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1");
    bytes32 private constant RESOLUTION_DOMAIN =
        keccak256("6529STREAM_MINT_ALLOWLIST_RESOLUTION_V1");

    function prepare(
        IStreamMintManager.MintBatch calldata batch,
        uint256 quantity,
        bytes32[] memory ids,
        IStreamMintManager.MintCounterConfig[] memory configs,
        StreamMintOperationIdentity.CounterContext memory context
    ) external view returns (IStreamMintLedger.CounterConsumption[] memory rows) {
        rows = StreamMintOperationIdentity.deriveCounterConsumptions(
            batch, quantity, ids, configs, context
        );
        uint256 merkleCount;
        for (uint256 i; i < configs.length; ++i) {
            if (configs[i].capMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC) {
                ++merkleCount;
            }
        }
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs;
        if (merkleCount != 0) {
            proofs = abi.decode(batch.resolverData, (IStreamMintCounterPolicy.AllowlistProof[][]));
            if (proofs.length != merkleCount) {
                revert IStreamMintCounterPolicy.MintAllowlistProofCountMismatch(
                    proofs.length, merkleCount
                );
            }
        }
        uint256 cursor;
        uint256 proofIndex;
        for (uint256 i; i < configs.length; ++i) {
            (, IStreamMintCounterPolicy.Definition memory d) =
                StreamMintCounterPolicy.read(context.ledger, configs[i].counterConfigHash);
            uint256 count =
                configs[i].keyMode == IStreamMintManager.CounterKeyMode.CONTEXT ? 1 : quantity;
            bool merkle = configs[i].capMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC;
            if (merkle) {
                uint256 expected =
                    configs[i].keyMode == IStreamMintManager.CounterKeyMode.PAYER ? 1 : quantity;
                if (proofs[proofIndex].length != expected) {
                    revert IStreamMintCounterPolicy.MintAllowlistProofCountMismatch(
                        proofs[proofIndex].length, expected
                    );
                }
            }
            for (uint256 j; j < count; ++j) {
                IStreamMintLedger.CounterConsumption memory row = rows[cursor++];
                _scope(row, configs[i], d.scope, context);
                if (merkle) {
                    uint256 index =
                        configs[i].keyMode == IStreamMintManager.CounterKeyMode.PAYER ? 0 : j;
                    _prove(row, configs[i], d.capRoot, proofs[proofIndex][index], context.manager);
                }
            }
            if (merkle) ++proofIndex;
        }
        _checkProjectedValues(context.ledger, rows);
    }

    function _checkProjectedValues(
        address ledger,
        IStreamMintLedger.CounterConsumption[] memory rows
    ) private view {
        // Sum the complete batch for every key before the Ledger or Core can write.
        // Repeated keys use each applicable effective cap, including mixed valid leaf presentations.
        for (uint256 i; i < rows.length; ++i) {
            uint256 projected = IStreamMintLedger(ledger).counterValue(rows[i].valueKey);
            for (uint256 j; j < rows.length; ++j) {
                if (rows[i].valueKey == rows[j].valueKey) projected += rows[j].increment;
            }
            if (projected > type(uint64).max) {
                revert IStreamMintLedger.CounterValueOverflow(rows[i].valueKey);
            }
            if (rows[i].cap != 0 && projected > rows[i].cap) {
                revert IStreamMintLedger.CounterCapExceeded(
                    rows[i].valueKey, projected, rows[i].cap
                );
            }
        }
    }

    function _scope(
        IStreamMintLedger.CounterConsumption memory row,
        IStreamMintManager.MintCounterConfig memory config,
        IStreamMintCounterPolicy.CounterScope scope,
        StreamMintOperationIdentity.CounterContext memory context
    ) private pure {
        (uint256 collectionId, bytes32 phaseId) =
            StreamMintCounterPolicy.scopeIds(scope, row.collectionId, row.phaseId);
        if (config.keyMode == IStreamMintManager.CounterKeyMode.CONSTANT) {
            StreamMintOperationIdentity.SubjectContext memory subject;
            subject.chainId = context.chainId;
            subject.ledger = context.ledger;
            subject.collectionId = collectionId;
            subject.phaseId = phaseId;
            subject.counterId = row.counterId;
            row.subjectKey = StreamMintOperationIdentity.subjectKey(config.keyMode, subject);
        }
        row.valueKey = keccak256(
            abi.encode(
                VALUE_KEY_DOMAIN,
                context.manager,
                collectionId,
                phaseId,
                row.counterId,
                row.subjectKey
            )
        );
    }

    function _prove(
        IStreamMintLedger.CounterConsumption memory row,
        IStreamMintManager.MintCounterConfig memory config,
        bytes32 root,
        IStreamMintCounterPolicy.AllowlistProof memory proof,
        address manager
    ) private view {
        address account = config.keyMode == IStreamMintManager.CounterKeyMode.PAYER
            ? row.payer
            : row.recipient;
        bytes32 leaf = StreamMintCounterPolicy.allowlistLeaf(
            manager, row.collectionId, row.phaseId, row.counterId, account, proof
        );
        if (
            proof.maxCount == 0 || proof.maxCount > config.staticCap
                || !StreamMintCounterPolicy.verify(root, leaf, proof.proof)
        ) {
            revert IStreamMintCounterPolicy.MintAllowlistProofInvalid(row.counterId, account);
        }
        row.cap = proof.maxCount;
        row.resolutionHash = keccak256(abi.encode(RESOLUTION_DOMAIN, row.resolutionHash, leaf));
    }
}
