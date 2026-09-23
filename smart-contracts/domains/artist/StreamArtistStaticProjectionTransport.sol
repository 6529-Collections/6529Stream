// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistStaticCalls as Calls } from "./StreamArtistStaticCalls.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistStaticIdentityProjection
} from "../../interfaces/stream/artist/IStreamArtistStaticIdentityProjection.sol";

/// @notice Permissionless derivative-write transport; never reached by staticDisplayRead.
library StreamArtistStaticProjectionTransport {
    function checkpoint(address coordinator, bytes32 artistId) public returns (bytes32) {
        T.SuiteConfiguration memory s = abi.decode(
            _read(coordinator, abi.encodeWithSignature("suiteConfiguration()"), 544),
            (T.SuiteConfiguration)
        );
        address owner = s.owners[2];
        if (
            s.registry != address(this)
                || abi.decode(
                        _read(owner, abi.encodeCall(IStreamArtistOwner.artistRegistry, ()), 32),
                        (address)
                    ) != s.registry
                || abi.decode(
                        _read(
                            owner, abi.encodeCall(IStreamArtistOwner.operationCoordinator, ()), 32
                        ),
                        (address)
                    ) != coordinator
                || abi.decode(
                        _read(owner, abi.encodeCall(IStreamArtistOwner.core, ()), 32), (address)
                    ) != s.core
                || abi.decode(
                        _read(owner, abi.encodeCall(IStreamArtistOwner.deploymentChainId, ()), 32),
                        (uint256)
                    ) != block.chainid
        ) revert T.InvalidBinding();
        return
            IStreamArtistStaticIdentityProjection(owner).checkpointStaticIdentityMaturity(artistId);
    }

    function _read(address target, bytes memory data, uint256 size)
        private
        view
        returns (bytes memory)
    {
        return Calls.fixedRead(target, data, size, 100000);
    }
}
