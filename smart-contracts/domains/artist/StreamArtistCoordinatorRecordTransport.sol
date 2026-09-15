// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryActionOperations } from "./StreamArtistRecoveryActionOperations.sol";
import { StreamArtistAttestationOperations } from "./StreamArtistAttestationOperations.sol";
import { StreamArtistIdentityOperations } from "./StreamArtistIdentityOperations.sol";
import { StreamArtistSuccessionOperations } from "./StreamArtistSuccessionOperations.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import { GovernanceCall } from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    StreamArtistIdentityRevisionTypes
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";

/// @notice Fixed decoders for original variable-length Coordinator recipes.
library StreamArtistCoordinatorRecordTransport {
    function prepareRecovery(D.CoordinatorContext memory x, bytes calldata data)
        public
        returns (bytes32)
    {
        (
            address actor,
            bytes32 actionId,
            GovernanceCall[] memory calls,
            IdentityRecovery.Request memory p,
            T.Authorization memory a
        ) = abi.decode(
            data[4:],
            (address, bytes32, GovernanceCall[], IdentityRecovery.Request, T.Authorization)
        );
        return StreamArtistRecoveryActionOperations.prepare(x, actor, actionId, calls, p, a);
    }

    function attest(D.CoordinatorContext memory x, bytes calldata data) public returns (bytes32) {
        (
            address actor,
            T.Attestation memory p,
            Attest.Subject memory subject,
            bool scoped,
            bytes32 grant,
            T.Authorization memory a,
            bytes memory statement
        ) = abi.decode(
            data[4:],
            (address, T.Attestation, Attest.Subject, bool, bytes32, T.Authorization, bytes)
        );
        return StreamArtistAttestationOperations.attest(
            x, actor, p, subject, scoped, grant, a, statement
        );
    }

    function revise(D.CoordinatorContext memory x, bytes calldata data) public returns (bytes32) {
        (
            address actor,
            StreamArtistIdentityRevisionTypes.Revision memory p,
            T.Authorization memory a,
            bytes memory document,
            string memory displayName
        ) = abi.decode(
            data[4:],
            (address, StreamArtistIdentityRevisionTypes.Revision, T.Authorization, bytes, string)
        );
        return StreamArtistIdentityOperations.revise(x, actor, p, a, document, displayName);
    }

    function attestArtist(D.CoordinatorContext memory x, bytes calldata data)
        public
        returns (bytes32)
    {
        (address actor, T.Attestation memory p, T.Authorization memory a, bytes memory statement) =
            abi.decode(data[4:], (address, T.Attestation, T.Authorization, bytes));
        return StreamArtistIdentityOperations.attest(x, actor, p, a, statement);
    }

    function directive(D.CoordinatorContext memory x, bytes calldata data)
        public
        returns (bytes32)
    {
        (
            address actor,
            Succ.Directive memory p,
            T.Authorization memory a,
            Succ.PublicDocument memory document
        ) = abi.decode(data[4:], (address, Succ.Directive, T.Authorization, Succ.PublicDocument));
        return StreamArtistSuccessionOperations.directive(x, actor, p, a, document);
    }
}
