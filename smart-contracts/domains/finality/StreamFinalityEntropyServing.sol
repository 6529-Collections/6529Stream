// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityRouterEvidence.sol";
import "../../interfaces/stream/finality/IStreamFinalityEntropySourceSet.sol";

/// @notice Exact typed entropy dispatch for a previously authenticated frozen route.
/// @dev The Router first validates the original/recovered route and adapter/host runtime bindings.
/// This read helper itself grants no authority to caller-selected addresses.
library StreamFinalityEntropyServing {
    error EntropyServingResponse(address target);

    function read(address adapter, address host, uint256 tokenId)
        public
        view
        returns (bytes32 seed, bool finalized)
    {
        uint256 supported = abi.decode(
            StreamFinalityRouterEvidence.read(
                adapter,
                abi.encodeCall(
                    IERC165.supportsInterface, (type(IStreamFinalityEntropySourceSet).interfaceId)
                ),
                32,
                100000
            ),
            (uint256)
        );
        if (supported > 1) revert EntropyServingResponse(adapter);
        bool composite = supported == 1;
        address target = composite ? adapter : host;
        bytes memory input = composite
            ? abi.encodeCall(IStreamFinalityEntropySourceSet.tokenSeedForFinality, (tokenId))
            : abi.encodeWithSignature("tokenSeed(uint256)", tokenId);
        (seed, supported) = abi.decode(
            StreamFinalityRouterEvidence.read(target, input, 64, composite ? 6000000 : 150000),
            (bytes32, uint256)
        );
        if (supported > 1) revert EntropyServingResponse(target);
        finalized = supported == 1;
    }
}
