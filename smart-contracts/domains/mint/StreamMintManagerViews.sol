// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMintOperationIdentity.sol";

/// @notice Fixed decoding for the retained policy preview ABI, outside Manager runtime headroom.
library StreamMintManagerViews {
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
