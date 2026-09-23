// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

/// @notice Fixed stateless manifest reads for the original rewind selection host.
library StreamArtistRecoveryRewindManifest {
    function read(
        address owner,
        address artistRegistry,
        address coordinator,
        uint256 deploymentChainId,
        W.EnvironmentV3 memory e,
        bytes32 hash
    ) public view returns (W.ResolutionManifestV3 memory m) {
        (address target, bytes32 pin) =
            IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRewindEvidenceBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        IStreamArtistRecoveryRewindEvidence publisher = IStreamArtistRecoveryRewindEvidence(target);
        if (
            publisher.owner() != owner || publisher.payoutOwner() != e.payoutOwner
                || publisher.artistRegistry() != artistRegistry
                || publisher.deploymentChainId() != deploymentChainId
                || publisher.coordinator() != coordinator || publisher.archive() != e.archive
                || publisher.core() != e.core || publisher.mintManager() != e.manager
        ) revert W.RecoveryRewindDependencyChanged(target);
        bytes32 identityPin;
        bytes32 payoutPin;
        (m, identityPin, payoutPin) = publisher.resolutionManifestV3(hash);
        if (
            hash == 0 || identityPin != e.identityCodeHash || payoutPin != e.payoutCodeHash
                || hash != W.manifestHash(e, m) || m.supersededRecords.length > W.MAX_SUPERSESSIONS
        ) {
            revert W.InvalidRecoveryRewindSelection(hash);
        }
        bytes32 previous;
        for (uint256 i; i < m.supersededRecords.length; ++i) {
            if (m.supersededRecords[i].recordHash <= previous) {
                revert W.InvalidRecoveryRewindSelection(hash);
            }
            previous = m.supersededRecords[i].recordHash;
        }
    }
}
