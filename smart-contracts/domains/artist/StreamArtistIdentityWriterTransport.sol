// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeIdentityMutation.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "./StreamArtistIdentityDismissalState.sol";
import "./StreamArtistCollaboratorIdentityState.sol";

/// @notice Fixed original argument decoders; host guards, activity and commits remain in the host.
library StreamArtistIdentityWriterTransport {
    function registerEncoded(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            ,
            address artist,
            bytes32 documentHash,
            string memory uri,
            bytes memory document,
            string memory displayName
        ) = abi.decode(data[4:], (T.ActionContext, address, bytes32, string, bytes, string));
        return StreamArtistIdentityState.register(
            identity, replay, o, artist, documentHash, uri, document, displayName
        );
    }

    function collaboratorEncoded(
        StreamArtistIdentityState.State storage identity,
        StreamArtistCollaboratorIdentityState.State storage accounts,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            C.IdentityProposal memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof,
            bytes memory document,
            string memory displayName
        ) = abi.decode(
            data[4:],
            (T.ActionContext, C.IdentityProposal, T.Authorization, T.SignerApproval, bytes, string)
        );
        return StreamArtistCollaboratorIdentityState.register(
            identity, accounts, replay, o, c, p, a, proof, document, displayName
        );
    }

    function designateEncoded(
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            Succ.Designation memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            data[4:], (T.ActionContext, Succ.Designation, T.Authorization, T.SignerApproval)
        );
        return StreamArtistSuccessionState.designateWithResolution(
            succession,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            a,
            proof,
            resolutions.closures[rotations.latestExecution[p.artistId]]
        );
    }

    function directiveEncoded(
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            Succ.Directive memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof,
            Succ.PublicDocument memory document
        ) = abi.decode(
            data[4:],
            (
                T.ActionContext,
                Succ.Directive,
                T.Authorization,
                T.SignerApproval,
                Succ.PublicDocument
            )
        );
        return StreamArtistSuccessionState.directiveWithResolution(
            succession,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            a,
            proof,
            document,
            resolutions.closures[rotations.latestExecution[p.artistId]]
        );
    }

    function reviseEncoded(
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            StreamArtistIdentityRevisionTypes.Revision memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof,
            bytes memory document,
            string memory displayName
        ) = abi.decode(
            data[4:],
            (
                T.ActionContext,
                StreamArtistIdentityRevisionTypes.Revision,
                T.Authorization,
                T.SignerApproval,
                bytes,
                string
            )
        );
        return StreamArtistIdentityRevisionState.reviseWithResolution(
            revisions,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            a,
            proof,
            document,
            displayName,
            resolutions.closures[rotations.latestExecution[p.artistId]],
            resolutions.continuations[resolutions.continuationHead[p.artistId]]
        );
    }

    function disputeEncoded(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistRotationState.State storage rotations,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistUnavailabilityState.State storage findings,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        (
            T.ActionContext memory c,
            AD.Filing memory p,
            T.Binding memory b,
            AD.Standing memory standing,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            data[4:],
            (T.ActionContext, AD.Filing, T.Binding, AD.Standing, T.Authorization, T.SignerApproval)
        );
        return StreamArtistDisputeIdentityMutation.consume(
            identity,
            replay,
            estate,
            succession,
            rotations,
            delegations,
            findings,
            dormancy,
            o,
            c,
            p,
            b,
            standing,
            a,
            proof
        );
    }

    function grantEncoded(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            D.Grant memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(data[4:], (T.ActionContext, D.Grant, T.Authorization, T.SignerApproval));
        return StreamArtistIdentityState.grantDelegation(
            identity, replay, delegations, o, c, p, a, proof
        );
    }

    function revokeGrantEncoded(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            D.Revocation memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(data[4:], (T.ActionContext, D.Revocation, T.Authorization, T.SignerApproval));
        return
            StreamArtistIdentityState.revokeDelegation(
                identity, replay, delegations, o, c, p, a, proof
            );
    }

    function revokeEncoded(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            StreamArtistAuthorizationTypes.Revocation memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            data[4:],
            (
                T.ActionContext,
                StreamArtistAuthorizationTypes.Revocation,
                T.Authorization,
                T.SignerApproval
            )
        );
        return StreamArtistAuthorizationState.revoke(identity, replay, o, c, p, a, proof);
    }

    function dismissEncoded(
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistSuccessionState.State storage succession,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        address executor,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (T.ActionContext memory c, Dismissal.Request memory p, Contest.GovernanceWitness memory g) =
            abi.decode(data[4:], (T.ActionContext, Dismissal.Request, Contest.GovernanceWitness));
        return StreamArtistIdentityDismissalState.dismiss(
            resolutions, identity, rotations, revisions, succession, replay, o, c, p, g, executor
        );
    }
}
