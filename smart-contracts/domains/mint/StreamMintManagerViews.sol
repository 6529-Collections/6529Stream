// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMintOperationIdentity.sol";
import "./StreamMintPhaseState.sol";
import "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import "../../interfaces/stream/revenue/StreamPreparedNativeRightsTypes.sol";

/// @notice Fixed decoding for the retained policy preview ABI, outside Manager runtime headroom.
library StreamMintManagerViews {
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
