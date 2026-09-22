// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredDisputeHistoryFixture.sol";
import {
    StreamArtistCompleteHistoryDisputeIdentityUses as CHUses
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryDisputeIdentityUses.sol";
import {
    StreamArtistCompleteHistoryIdentitySource as CHIdentity
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryIdentitySource.sol";
import {
    StreamArtistCompleteHistorySource as CHSource
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistorySource.sol";
import {
    StreamArtistCompleteHistoryScope as CHScope
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistCompleteHistoryDisputeSource as CHDisputes
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryDisputeSource.sol";
import {
    StreamArtistRecoveredHydrationSource as CHProvenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationSource.sol";
import {
    StreamArtistRecoveredHydrationGuards as CHGuards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as CHClocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as CHFrame
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as CHIH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistMultipleHydrationTypes as CHMH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistCollaboratorTypes as CHC
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";

/// @notice Original signatures, nonce trees, revoked grants and paired veto records.
/// @dev Complete source collectors authenticate canonical bundles and all original Archive
/// rows. Inherited Core/governance/documentary boundaries do not model an operation60 import.
contract StreamArtistCompleteHistoryDisputeIdentityActualTest is
    ArtistRecoveredDisputeHistoryFixture
{
    function testCompleteDisputeIdentityRetainsOriginalRevokedGrantUses() external {
        _baseline();
        bytes32 grant = _grantDispute(2);
        _delegatedDispute(1, grant, 0);
        _delegatedDispute(2, grant, 1);
        _revokeDisputeGrant(grant);
        CHUses.Context memory x = _observeUses(false);
        uint256[][] memory uses = CHUses.validate(x);
        require(
            uses.length == 1 && uses[0].length == 1 && uses[0][0] == 2,
            "both original delegated uses counted once"
        );
        require(
            ingress.delegationRecord(grant).revoked && ingress.delegationRecord(grant).uses == 2,
            "actual exhausted revoked source grant"
        );
        x.histories[0].disputes[0].record.standing.delegation = keccak256("not the original grant");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHUses.validate(x);
    }

    function testCompleteDisputeIdentityPairedVetoCountAndOriginalGuardianAreExact() external {
        _baseline();
        RP.Record memory staged = _stage(keccak256("complete original guardian veto"), false);
        _veto(staged);
        CHUses.Context memory x = _observeUses(false);
        CHUses.validate(x);
        uint256 nativeVetoes;
        for (uint256 i; i < x.inventory.provenance.journals[2].length; ++i) {
            if (x.inventory.provenance.journals[2][i].receipt.operation == 48) ++nativeVetoes;
        }
        require(
            nativeVetoes == 2 && x.histories[0].repudiations.length == 1,
            "one original Contest/Cause pair"
        );
        x.histories[0].repudiations[0].terminal.actor = address(0xBAD);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHUses.validate(x);
        x.histories[0].repudiations[0].terminal.actor = address(delegateSafe);
        CHUses.validate(x);
        // Omitting the repudiation cannot make its two original Identity occurrences vanish.
        x.histories[0].repudiations = new D.RepudiationRow[](0);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHUses.validate(x);
    }

    function testCompleteDisputeIdentityCollaboratorAuthorUsesOwnNonceWithBoundSignatureCarrier()
        external
    {
        bytes32 record = _collaboratorOpening();
        CHUses.Context memory x = _observeUses(true);
        uint256 carrier = CHScope.artist(x.scope, artistId);
        uint256 author = CHScope.artist(x.scope, collaboratorId);
        require(carrier != author, "genuinely different source principals");
        require(
            this.hasSignature(x.identities[carrier], record),
            "original global signature is under native bound Artist"
        );
        require(
            !this.hasSignature(x.identities[author], record), "no invented author-native record"
        );
        require(
            this.recoveries(x.identities[author]) == 0, "ordinary collaborator needs no recovery"
        );
        uint256[][] memory uses = CHUses.validate(x);
        require(
            uses.length == 2 && uses[carrier].length == 0 && uses[author].length == 0,
            "ordinary filing invents no delegation"
        );
        bytes memory saved = x.identities[carrier];
        x.identities[carrier] = this.removeSignatureIndex(saved, record);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHUses.validate(x);
        x.identities[carrier] = saved;
        CHUses.validate(x);
        x.identities[author] = this.removePrincipalNonceIndex(x.identities[author], collaboratorId);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHUses.validate(x);
    }

    function hasSignature(bytes calldata raw, bytes32 record) external pure returns (bool) {
        CHIH.Bundle calldata b = CHFrame.bundle(raw);
        for (uint256 i; i < b.signatures.length; ++i) {
            if (b.signatures[i].recordHash == record) return true;
        }
        return false;
    }

    function recoveries(bytes calldata raw) external pure returns (uint256) {
        return CHFrame.bundle(raw).recoveries.length;
    }

    function removeSignatureIndex(bytes calldata raw, bytes32 record)
        external
        pure
        returns (bytes memory changed)
    {
        CHIH.Bundle calldata b = CHFrame.bundle(raw);
        for (uint256 i; i < b.signatures.length; ++i) {
            CHIH.SignatureRow calldata row = b.signatures[i];
            if (row.recordHash != record) continue;
            uint256 offset;
            assembly ("memory-safe") { offset := sub(row, raw.offset) }
            changed = raw;
            assembly ("memory-safe") { mstore(add(add(changed, 32), offset), 0) }
            return changed;
        }
        revert("missing authentic signature");
    }

    function removePrincipalNonceIndex(bytes calldata raw, bytes32 artist)
        external
        pure
        returns (bytes memory changed)
    {
        CHIH.Bundle calldata b = CHFrame.bundle(raw);
        for (uint256 i; i < b.nonces.length; ++i) {
            CHIH.NonceLane calldata row = b.nonces[i];
            if (row.kind != 1 || row.key != artist) continue;
            uint256 offset;
            assembly ("memory-safe") { offset := sub(row, raw.offset) }
            changed = raw;
            // kind occupies the first ABI word, key the second. Nested offsets stay intact.
            assembly ("memory-safe") { mstore(add(add(changed, 64), offset), 0) }
            return changed;
        }
        revert("missing authentic author nonce lane");
    }

    function _collaboratorOpening() private returns (bytes32 record) {
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        _collaboratorIdentity(false);
        bytes32 document = keccak256("collaborator unit document");
        bytes32 digest = ingress.collaboratorIdentityDigest(
            address(delegateSafe), document, T.Authorization(0, 2000, "")
        );
        _rhCandidate(
            1,
            "collaborator_lifecycle.replay.collaborator_proposal_key",
            keccak256(abi.encode(address(delegateSafe), document))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(1)))
        );
        _rhCandidate(2, "identity_authority.replay.identity_uniqueness", collaboratorId);
        _rhCandidate(
            2,
            "identity_authority.replay.collaborator_account_nonce",
            keccak256(abi.encode(address(delegateSafe), uint256(0)))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.collaborator_account_digest",
            keccak256(abi.encode(address(delegateSafe), digest))
        );
        _authorAuthorization(collaboratorId, digest, 0);
        CHC.BindingAcceptance memory acceptance = _collaborativeProposal(false);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_terminal_transition_key",
            keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(2)))
        );
        uint256 nonce = Identity(suite.owners[2]).identity(collaboratorId).nonceHint;
        digest = ingress.collaboratorAcceptanceDigest(acceptance, T.Authorization(nonce, 2000, ""));
        _collaboratorAcceptance(acceptance, false);
        _authorAuthorization(collaboratorId, digest, nonce);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(
                abi.encode(
                    uint256(1),
                    uint64(2),
                    uint8(2),
                    acceptance.account,
                    acceptance.role,
                    acceptance.shareLabelId
                )
            )
        );
        T.Authorization memory primary =
            T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        _rhAuthorization(ingress.acceptanceDigest(1, primary), primary.nonce);
        _accept();
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(2), uint8(1), address(artist)))
        );
        bytes32 evidence = _evidence(0, keccak256("actual ordinary collaborator opening"));
        AD.Filing memory filing = AD.Filing(1, 2, 1, evidence, evidence);
        T.Authorization memory authorization = T.Authorization(
            Identity(suite.owners[2]).identity(collaboratorId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        digest = ingress.attributionDisputeDigest(filing, authorization);
        authorization.signature = _delegateSignature(digest);
        record = ingress.openAttributionDispute(
            filing, AD.Standing(collaboratorId, 2, 0, 0), authorization
        );
        _authorAuthorization(collaboratorId, digest, authorization.nonce);
        _rhCandidate(
            4,
            "attribution_lifecycle.replay.dispute_key",
            keccak256(
                abi.encode(
                    uint256(1), uint64(2), bytes32(0), address(delegateSafe), evidence, evidence
                )
            )
        );
    }

    function _authorAuthorization(bytes32 principal, bytes32 digest, uint256 nonce) private {
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(principal, digest))
        );
        _rhCandidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(principal, nonce))
        );
    }

    function _observeUses(bool collaborator) private view returns (CHUses.Context memory x) {
        RH.Request memory request = _rhRequest();
        RH.Provenance memory provenance = CHProvenance.collect(
            suite, address(coordinator), request.records.authority.replayOrigins
        );
        CHMH.Request memory selected;
        selected.artistIds = new bytes32[](collaborator ? 2 : 1);
        selected.artistIds[0] = artistId;
        if (collaborator) {
            selected.artistIds[1] = collaboratorId;
            if (collaboratorId < artistId) {
                (selected.artistIds[0], selected.artistIds[1]) = (collaboratorId, artistId);
            }
        }
        selected.collections = new CHMH.Collection[](1);
        T.Binding[] memory heads = new T.Binding[](1);
        heads[0] = Binding(suite.owners[0]).binding(1);
        selected.collections[0] = CHMH.Collection(heads[0].artistId, 1, new AH.PolicyKey[](0));
        x.scope = CHScope.partition(selected, heads, provenance);
        CHClocks.Result memory clocks;
        (x.inventory, clocks) = CHSource.collect(x.scope, provenance);
        x.histories = CHDisputes.collect(
            suite.owners[4], x.scope, provenance, x.inventory.bindings, x.inventory.archive, clocks
        );
        (, RH.NonceInventory[] memory nonces) =
            CHGuards.collect(provenance, 2, request.records.authority.replayOrigins[2]);
        x.identities = CHIdentity.collect(x.scope, x.inventory, clocks, nonces);
    }
}
