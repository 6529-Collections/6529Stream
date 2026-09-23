// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistSuiteReads
} from "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";

/// @notice Original Coordinator suite joins, evaluated only after its fixed owners exist.
/// @dev Returned runtime hashes are observed facts; consumers must join saved evidence pins.
library StreamArtistRecoveryRewindEnvironment {
    function fromFixed(
        address owner,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public view returns (W.EnvironmentV3 memory e) {
        if (
            owner.code.length == 0 || registry.code.length == 0 || coordinator.code.length == 0
                || archive.code.length == 0 || core.code.length == 0 || manager.code.length == 0
        ) revert W.RecoveryRewindDependencyChanged(coordinator);
        IStreamArtistSuiteReads source = IStreamArtistSuiteReads(coordinator);
        T.SuiteConfiguration memory suite = source.suiteConfiguration();
        address payout = suite.owners[5];
        if (
            source.deploymentChainId() != block.chainid || suite.registry != registry
                || suite.archive != archive || suite.core != core || suite.mintManager != manager
                || suite.owners[2] != owner || payout == owner || payout.code.length == 0
        ) revert W.RecoveryRewindDependencyChanged(coordinator);
        e = W.EnvironmentV3(
            block.chainid,
            registry,
            owner,
            owner.codehash,
            payout,
            payout.codehash,
            coordinator,
            archive,
            core,
            manager
        );
        _owner(e, owner, keccak256("domain:identity_authority"));
        _owner(e, payout, keccak256("domain:payout_lifecycle"));
    }

    function _owner(W.EnvironmentV3 memory e, address target, bytes32 domain) private view {
        IStreamArtistOwner source = IStreamArtistOwner(target);
        if (
            source.deploymentChainId() != e.chainId || source.artistRegistry() != e.registry
                || source.operationCoordinator() != e.coordinator || source.archiveV2() != e.archive
                || source.core() != e.core || source.mintManager() != e.manager
                || source.domainId() != domain
        ) revert W.RecoveryRewindDependencyChanged(target);
    }
}
