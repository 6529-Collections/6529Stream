// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamViewAdoptionState as State } from "./StreamViewAdoptionState.sol";
import { StreamViewAdoptionRouting as Routing } from "./StreamViewAdoptionRouting.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import {
    StreamMetadataDisplayParameters as Parameters
} from "./StreamMetadataDisplayParameters.sol";

/// @notice Fixed delegate transport for the new Router surface. Original Router context is
/// preserved; the serving worker receives an explicit STATICCALL from that original host.
library StreamViewAdoptionTransport {
    function serve(bytes32 runtimeHash, bytes calldata original)
        public
        view
        returns (bytes memory)
    {
        Read.pin(address(Routing), runtimeHash);
        bytes memory input = abi.encodeWithSelector(Routing.serveEncoded.selector, original);
        return Read.bounded(
            address(Routing), input, 262208, Parameters.value(Parameters.FULL_VIEW_GAS), false
        );
    }

    function encoded(bytes32 key) public view returns (bytes memory) {
        return abi.encode(State.encoded(key));
    }
}
