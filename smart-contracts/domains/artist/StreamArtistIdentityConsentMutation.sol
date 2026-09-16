// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityConsentState.sol";

/// @notice Decode original typed consent calldata in a fixed worker; original State owns authorization.
/// @dev Host retains _check, activity, commit and the distinct returned record hash.
library StreamArtistIdentityConsentMutation {
    function consume(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        uint16 operation,
        bytes calldata encoded
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        if (operation == 2) {
            (
                T.ActionContext memory c,
                uint256 collectionId,
                T.Binding memory b,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded, (T.ActionContext, uint256, T.Binding, T.Authorization, T.SignerApproval)
            );
            return StreamArtistIdentityConsentState.acceptance(
                identity, replay, o, c, collectionId, b, a, proof
            );
        }
        if (operation == 3) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                L.Termination memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (T.ActionContext, T.Binding, L.Termination, T.Authorization, T.SignerApproval)
            );
            return StreamArtistIdentityConsentState.refusal(identity, replay, o, c, b, p, a, proof);
        }
        if (operation == 16) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                Sale.Consent memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (T.ActionContext, T.Binding, Sale.Consent, T.Authorization, T.SignerApproval)
            );
            return
                StreamArtistIdentityConsentState.saleConsent(identity, replay, o, c, b, p, a, proof);
        }
        if (operation == 14) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.PolicyConsent memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (T.ActionContext, T.Binding, T.PolicyConsent, T.Authorization, T.SignerApproval)
            );
            return StreamArtistIdentityConsentState.policy(identity, replay, o, c, b, p, a, proof);
        }
        if (operation == 15) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.EconomicsConsent memory p,
                bytes32 designation,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (
                    T.ActionContext,
                    T.Binding,
                    T.EconomicsConsent,
                    bytes32,
                    T.Authorization,
                    T.SignerApproval
                )
            );
            return StreamArtistIdentityConsentState.economics(
                identity, replay, o, c, b, p, designation, a, proof
            );
        }
        if (operation == 18) {
            (
                T.ActionContext memory c,
                T.PayoutDesignation memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded, (T.ActionContext, T.PayoutDesignation, T.Authorization, T.SignerApproval)
            );
            return StreamArtistIdentityConsentState.payout(identity, replay, o, c, p, a, proof);
        }
        if (operation == 24) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.Attestation memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (T.ActionContext, T.Binding, T.Attestation, T.Authorization, T.SignerApproval)
            );
            return
                StreamArtistIdentityConsentState.attestation(identity, replay, o, c, b, p, a, proof);
        }
        if (operation == 52) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.Ratification memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (T.ActionContext, T.Binding, T.Ratification, T.Authorization, T.SignerApproval)
            );
            return
                StreamArtistIdentityConsentState.ratification(
                    identity, replay, o, c, b, p, a, proof
                );
        }
        if (operation == 20) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                T.RoyaltyFreeze memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (T.ActionContext, T.Binding, T.RoyaltyFreeze, T.Authorization, T.SignerApproval)
            );
            return StreamArtistIdentityConsentState.royaltyFreeze(
                identity, replay, o, c, b, p, a, proof
            );
        }
        if (operation == 17) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                Content.Consent memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (T.ActionContext, T.Binding, Content.Consent, T.Authorization, T.SignerApproval)
            );
            return StreamArtistIdentityConsentState.contentConsent(
                identity, replay, o, c, b, p, a, proof
            );
        }
        if (operation == 21) {
            (
                T.ActionContext memory c,
                T.Binding memory b,
                Content.Freeze memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                encoded,
                (T.ActionContext, T.Binding, Content.Freeze, T.Authorization, T.SignerApproval)
            );
            return StreamArtistIdentityConsentState.contentFreeze(
                identity, replay, o, c, b, p, a, proof
            );
        }
        revert T.InvalidOperation(operation);
    }
}
