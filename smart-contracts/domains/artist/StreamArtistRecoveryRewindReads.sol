// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistDormancyState as Dormancy } from "./StreamArtistDormancyState.sol";
import {
    StreamArtistRecoveryRewindContext as Context
} from "./StreamArtistRecoveryRewindContext.sol";
import {
    StreamArtistRecoveryRewindState as Supplemental
} from "./StreamArtistRecoveryRewindState.sol";
import {
    StreamArtistIdentityRecoveryState as Recovery
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolutions
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState as Estate } from "./StreamArtistEstateState.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3 as Owner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @dev Only explicit owner wrappers call this fixed, read-only selector adapter.
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";

library StreamArtistRecoveryRewindReads {
    function read(
        Recovery.State storage s,
        Supplemental.State storage supplemental,
        Identity.State storage identity,
        Rotations.State storage rotations,
        Resolutions.State storage resolutions,
        Estate.State storage estate,
        Dormancy.State storage dormancy,
        Identity.OwnerContext memory o,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        if (selector == Owner.identityRecoveryEvidenceStateV3.selector) {
            (bytes32 artistId, bytes32 actionId) = abi.decode(data[4:], (bytes32, bytes32));
            W.EvidenceStateV3 memory evidence = supplemental.actions[actionId];
            if (evidence.manifestHash != 0 && s.actions[actionId].artistId != artistId) {
                revert T.InvalidRecord();
            }
            return abi.encode(evidence);
        }
        if (selector == Owner.recoveryRewindBasisV3.selector) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return abi.encode(
                Context.base(
                    s, supplemental, identity, rotations, resolutions, estate, dormancy, o, hash
                )
                .selectionBasis
            );
        }
        if (
            selector == Owner.identityRecoveryContextV3.selector
                || selector == Owner.guardianRecoveryAuthorityRoleV3.selector
        ) {
            (
                I.Request memory request,
                T.Authorization memory acceptance,
                bytes32 hash,
                W.CrossOwnerFactsV3 memory facts
            ) = abi.decode(data[4:], (I.Request, T.Authorization, bytes32, W.CrossOwnerFactsV3));
            Context.Facts memory f = Context.read(
                s,
                supplemental,
                identity,
                rotations,
                resolutions,
                estate,
                dormancy,
                o,
                request,
                acceptance,
                hash,
                facts
            );
            if (selector == Owner.identityRecoveryContextV3.selector) return abi.encode(f.context);
            return abi.encode(f.guardians.requiredRole);
        }
        revert T.InvalidRecord();
    }
}
