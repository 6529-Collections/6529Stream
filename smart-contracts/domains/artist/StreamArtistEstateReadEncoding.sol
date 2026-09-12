// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEstateReads.sol";

/// @notice Fixed encoded-return reads over the actual Identity storage; no routing or readiness assertions.
library StreamArtistEstateReadEncoding {
    function request(
        StreamArtistEstateState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        Estate.Request memory p,
        bytes32 envelope
    ) public view returns (bytes memory) {
        return abi.encode(
            StreamArtistEstateReads.requestFacts(
                s, identity, rotations, succession, resolutions, p, envelope
            )
        );
    }

    function execution(
        StreamArtistEstateState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Estate.Execution memory p,
        bytes32 envelope
    ) public view returns (bytes memory) {
        (uint32 caps, Estate.AccelerationContext memory context) = StreamArtistEstateReads.executionFacts(
            s, identity, rotations, succession, resolutions, e, p, envelope
        );
        return abi.encode(caps, context);
    }

    function record(StreamArtistEstateState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.requests[hash], s.phases[hash], s.executions[hash]);
    }

    function authority(
        StreamArtistEstateState.State storage s,
        StreamArtistIdentityState.State storage identity,
        bytes32 id
    ) public view returns (bytes memory) {
        return abi.encode(StreamArtistEstateReads.authority(s, identity, id));
    }

    function designation(StreamArtistSuccessionState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.designations[hash]);
    }

    function directive(StreamArtistSuccessionState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.directives[hash]);
    }
}
