// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./GovernedParameterTestMocks.sol";
import {
    IStreamEntropyProviderLifecycle,
    EntropyProviderState
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";

interface IEntropyProviderCompatibility {
    function setProviderRevoked(address provider, bool revoked) external;
}
import "../../smart-contracts/interfaces/stream/parameters/IStreamTimeParameterHost.sol";

/// @notice Explicit unit execution-context boundary; actual Executor coverage lives in current tests.
abstract contract EntropyTimeAuthorityFixture is MockGovernedParameterAuthority {
    constructor() MockGovernedParameterAuthority(true) { }

    uint256 private _providerActionNonce;

    function _admitEntropyProvider(address coordinator, address provider) internal {
        IStreamEntropyProviderLifecycle target = IStreamEntropyProviderLifecycle(coordinator);
        string memory reason = "urn:stream:test:provider-admission";
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls) =
            target.entropyProviderTransition(provider, EntropyProviderState.ACTIVE, reason);
        this.setCurrentAction(
            true,
            keccak256(abi.encode(coordinator, ++_providerActionNonce)),
            cls,
            scope,
            oldHash,
            newHash
        );
        target.activateEntropyProvider(provider, reason);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _setEntropyProviderRevoked(address coordinator, address provider, bool revoked)
        internal
    {
        IStreamEntropyProviderLifecycle target = IStreamEntropyProviderLifecycle(coordinator);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.providerRevocationTransition(provider, revoked);
        this.setCurrentAction(
            true,
            keccak256(abi.encode(coordinator, ++_providerActionNonce)),
            1,
            scope,
            oldHash,
            newHash
        );
        IEntropyProviderCompatibility(coordinator).setProviderRevoked(provider, revoked);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }
}

library EntropyTimeTestConfigs {
    function parameters()
        internal
        pure
        returns (IStreamTimeParameterHost.TimeParameterConfig[3] memory rows)
    {
        rows[0] = IStreamTimeParameterHost.TimeParameterConfig(
            "ENTROPY_REQUEST_TIMEOUT_BLOCKS", 10, 5, 60
        );
        rows[1] =
            IStreamTimeParameterHost.TimeParameterConfig("ENTROPY_REVEAL_SLO_BLOCKS", 10, 5, 60);
        rows[2] = IStreamTimeParameterHost.TimeParameterConfig(
            "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS", 10, 5, 60
        );
    }
}
