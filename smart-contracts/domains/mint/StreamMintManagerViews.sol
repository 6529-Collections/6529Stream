// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMintOperationIdentity.sol";
import "./StreamMintPhaseState.sol";
import "./StreamMintManagerAccounting.sol";
import "../../interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";
import "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import "../../interfaces/stream/revenue/StreamPreparedNativeRightsTypes.sol";

/// @notice Fixed decoding for retained Manager preview ABIs, outside Manager runtime headroom.
library StreamMintManagerViews {
    struct SubjectPreview {
        IStreamMintManager.CounterKeyMode keyMode;
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 counterId;
        address payer;
        address recipient;
        address executor;
        address authorizer;
        bytes32 contextHash;
    }

    /// @notice Decodes the original static subject-preview request at the actual Manager.
    /// @dev Enum/address decoding remains strict; the fixed linked accounting call retains
    ///      Manager identity for its counter-config read and the original immutable Ledger.
    function subject(bytes calldata arguments, address ledger) external view returns (bytes32) {
        SubjectPreview memory p = abi.decode(arguments, (SubjectPreview));
        return StreamMintManagerAccounting.previewSubject(
            p.keyMode,
            StreamMintOperationIdentity.SubjectContext(
                block.chainid,
                ledger,
                p.collectionId,
                p.phaseId,
                p.counterId,
                p.payer,
                p.recipient,
                p.executor,
                p.authorizer,
                p.contextHash
            )
        );
    }

    function preparedEncoded(StreamPreparedNativeSettlementTypes.Facts storage facts)
        external view returns (bytes memory) { return abi.encode(facts); }

    function contentEncoded(StreamPreparedNativeContentTypes.Facts storage facts)
        external view returns (bytes memory) { return abi.encode(facts); }

    function rightsEncoded(StreamPreparedNativeRightsTypes.Facts storage facts)
        external view returns (bytes memory) { return abi.encode(facts); }

    function phaseEncoded(StreamMintPhaseState.PhaseState storage state)
        external view returns (bytes memory) { return abi.encode(state.exists, state.config); }

    function counterEncoded(IStreamMintManager.MintCounterConfig storage config)
        external view returns (bytes memory) { return abi.encode(config); }

    function gateEncoded(IStreamMintManager.MintGateConfig storage config)
        external view returns (bytes memory) { return abi.encode(config); }

    function executorsEncoded(address[] storage executors)
        external view returns (bytes memory) { return abi.encode(executors); }

    function counterIdsEncoded(bytes32[] storage ids)
        external view returns (bytes memory) { return abi.encode(ids); }

    function royaltyEncoded(IStreamMintRoyaltyPolicy.Policy storage policy)
        external view returns (bytes memory) { return abi.encode(policy); }

    struct PhasePreview {
        uint256 collectionId;
        bytes32 phaseId;
        IStreamMintManager.MintPhaseConfig config;
        IStreamMintManager.MintGateConfig gate;
        bytes32[] counterIds;
        IStreamMintManager.MintCounterConfig[] counters;
        address[] executors;
    }

    function phasePolicy(bytes calldata arguments, address ledger, address registry)
        external
        view
        returns (bytes32)
    {
        PhasePreview memory p =
            abi.decode(bytes.concat(bytes32(uint256(32)), arguments), (PhasePreview));
        if (
            p.counterIds.length != p.counters.length || p.counterIds.length > 16
                || p.executors.length > 64
        ) {
            revert IStreamMintManager.MintArrayLengthMismatch();
        }
        return StreamMintOperationIdentity.computePolicyHash(
            p.config,
            p.gate,
            p.counterIds,
            p.counters,
            p.executors,
            StreamMintOperationIdentity.PolicyContext(
                block.chainid, address(this), ledger, registry, 1, p.collectionId, p.phaseId
            )
        );
    }
}
