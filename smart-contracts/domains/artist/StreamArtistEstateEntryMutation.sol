// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import "./StreamArtistStewardSanctionState.sol";
import "./StreamArtistIdentityResolutionState.sol";
import "./StreamArtistDelegatedMutation.sol";
import "./StreamArtistIdentityRecoveryApprovalState.sol";
import "./StreamArtistIdentityConsentState.sol";
import "./StreamArtistDormancyReadEncoding.sol";
import "./StreamArtistEstateExecutionMutation.sol";

/// @notice Fixed decoders for the original Estate typed entry tuples.
/// @dev Original delegated outputs remain separate from zero-record owner mutations.
library StreamArtistEstateEntryMutation {
    function delegated(
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistUnavailabilityState.State storage findings,
        StreamArtistDormancyState.State storage dormancy,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        uint16 operation,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        if (operation == 14) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.PolicyConsent memory p,
                bytes32 grant,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (
                    T.ActionContext,
                    T.Binding,
                    T.PolicyConsent,
                    bytes32,
                    T.Authorization,
                    T.SignerApproval
                )
            );
            return StreamArtistDelegatedMutation.consumeDelegatedPolicyConsent(
                estate,
                succession,
                rotations,
                identity,
                delegations,
                findings,
                dormancy,
                replay,
                o,
                c,
                b,
                p,
                grant,
                a,
                proof
            );
        }
        if (operation == 16) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                Sale.Consent memory p,
                bytes32 grant,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (
                    T.ActionContext,
                    T.Binding,
                    Sale.Consent,
                    bytes32,
                    T.Authorization,
                    T.SignerApproval
                )
            );
            return StreamArtistDelegatedMutation.consumeDelegatedSaleConsent(
                estate,
                succession,
                rotations,
                identity,
                delegations,
                findings,
                dormancy,
                replay,
                o,
                c,
                b,
                p,
                grant,
                a,
                proof
            );
        }
        if (operation == 24) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.Attestation memory p,
                bytes32 grant,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (
                    T.ActionContext,
                    T.Binding,
                    T.Attestation,
                    bytes32,
                    T.Authorization,
                    T.SignerApproval
                )
            );
            return StreamArtistDelegatedMutation.consumeDelegatedAttestation(
                estate,
                succession,
                rotations,
                identity,
                delegations,
                findings,
                dormancy,
                replay,
                o,
                c,
                b,
                p,
                grant,
                a,
                proof
            );
        }
        if (operation == 15) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.EconomicsConsent memory p,
                bytes32 designation,
                bytes32 grant,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (
                    T.ActionContext,
                    T.Binding,
                    T.EconomicsConsent,
                    bytes32,
                    bytes32,
                    T.Authorization,
                    T.SignerApproval
                )
            );
            return StreamArtistDelegatedMutation.consumeDelegatedEconomics(
                estate,
                succession,
                rotations,
                identity,
                delegations,
                findings,
                dormancy,
                replay,
                o,
                c,
                b,
                p,
                designation,
                grant,
                a,
                proof
            );
        }
        if (operation == 20) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.RoyaltyFreeze memory p,
                bytes32 grant,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (
                    T.ActionContext,
                    T.Binding,
                    T.RoyaltyFreeze,
                    bytes32,
                    T.Authorization,
                    T.SignerApproval
                )
            );
            return StreamArtistDelegatedMutation.consumeDelegatedRoyaltyFreeze(
                estate,
                succession,
                rotations,
                identity,
                delegations,
                findings,
                dormancy,
                replay,
                o,
                c,
                b,
                p,
                grant,
                a,
                proof
            );
        }
        revert T.InvalidOperation(operation);
    }

    function unavailability(
        StreamArtistUnavailabilityState.State storage finding,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistUnavailabilityState.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (StreamArtistUnavailabilityState.Mutation memory) {
        (, U.Input memory p) = abi.decode(encoded, (T.ActionContext, U.Input));
        return StreamArtistUnavailabilityState.record(
            finding, replay, o, identity.identities[p.terms.artistId], p
        );
    }

    function initiate(
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityResolutionState.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        address authority,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            StreamArtistDormancyTypes.Initiation memory p,
            Contest.GovernanceWitness memory g
        ) = abi.decode(
            encoded,
            (T.ActionContext, StreamArtistDormancyTypes.Initiation, Contest.GovernanceWitness)
        );
        return StreamArtistDormancyState.initiate(
            dormancy, identity, rotations, estate, resolutions, replay, o, c, p, g, authority
        );
    }

    function guardians(
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.State storage identity,
        StreamArtistIdentityResolutionState.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            R.GuardianSet memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(encoded, (T.ActionContext, R.GuardianSet, T.Authorization, T.SignerApproval));
        return StreamArtistRotationState.setGuardiansWithResolution(
            rotations,
            identity,
            replay,
            o,
            c,
            p,
            a,
            proof,
            resolutions.closures[rotations.latestExecution[p.artistId]]
        );
    }

    function stewardGrant(
        StreamArtistStewardSanctionState.State storage grants,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            IStreamArtistStewardSanctionGrant.Grant memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            encoded,
            (
                T.ActionContext,
                IStreamArtistStewardSanctionGrant.Grant,
                T.Authorization,
                T.SignerApproval
            )
        );
        return StreamArtistStewardSanctionState.recordWithResolution(
            grants,
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

    function sanction(
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        (
            T.ActionContext memory c,
            T.Binding memory b,
            S.Terms memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            encoded, (T.ActionContext, T.Binding, S.Terms, T.Authorization, T.SignerApproval)
        );
        StreamArtistDormancyReadEncoding.requireStewardCollection(
            dormancy,
            identity,
            o.environment.core,
            b.artistId,
            p.scopeType,
            p.collectionId,
            p.tokenId,
            p.scopeId
        );
        return StreamArtistIdentityConsentState.sanction(identity, replay, o, c, b, p, a, proof);
    }

    function recoveryApproval(
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        (
            T.ActionContext memory c,
            T.Binding memory b,
            Recovery.ApprovalTerms memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            encoded,
            (T.ActionContext, T.Binding, Recovery.ApprovalTerms, T.Authorization, T.SignerApproval)
        );
        StreamArtistDormancyReadEncoding.requireStewardCollection(
            dormancy, identity, o.environment.core, b.artistId, 0, p.collectionId, 0, bytes32(0)
        );
        return
            StreamArtistIdentityRecoveryApprovalState.consume(
                identity, replay, o, c, b, p, a, proof
            );
    }

    function executeEstate(
        StreamArtistIdentityRecoveryState.State storage recovery,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            Estate.Execution memory p,
            StreamArchivalTypes.CoverageFacts memory coverage,
            Contest.GovernanceWitness memory governance
        ) = abi.decode(
            encoded,
            (
                T.ActionContext,
                Estate.Execution,
                StreamArchivalTypes.CoverageFacts,
                Contest.GovernanceWitness
            )
        );
        return StreamArtistEstateExecutionMutation.execute(
            recovery,
            identity,
            rotations,
            succession,
            resolutions,
            estate,
            replay,
            o,
            c,
            p,
            coverage,
            governance
        );
    }

    function revokeStanding(
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            R.StandingRevocation memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            encoded, (T.ActionContext, R.StandingRevocation, T.Authorization, T.SignerApproval)
        );
        (bool revoked,) = StreamArtistIdentityDismissalState.standingRevoked(
            resolutions, rotations, p.artistId, p.revokedAddress
        );
        if (revoked) revert R.InvalidPriorStanding(p.revokedAddress);
        return
            StreamArtistRotationState.revokeStanding(rotations, identity, replay, o, c, p, a, proof);
    }

    function executeRotation(
        StreamArtistIdentityRecoveryState.State storage recovery,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.State storage identity,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        (T.ActionContext memory c, bytes32 artistId, bytes32 expected) =
            abi.decode(encoded, (T.ActionContext, bytes32, bytes32));
        bytes32 previousVesting = rotations.latestExecution[artistId];
        m = StreamArtistRotationState.execute(rotations, identity, replay, o, c, artistId, expected);
        bytes32 commitment = StreamArtistGuardianVestingAdmission.record(
            recovery,
            identity,
            rotations,
            estate,
            o.environment,
            V.Input(artistId, expected, previousVesting, o.revision + 1, 32)
        );
        m.state = keccak256(abi.encode(m.state, commitment));
    }
}
