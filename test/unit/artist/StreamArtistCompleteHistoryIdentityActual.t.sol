// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistCompleteHistoryTypes as CHType
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryIdentitySource as CHIdentity
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryIdentitySource.sol";
import {
    StreamArtistCompleteHistoryIdentityFacts as CHFacts
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryIdentityFacts.sol";
import {
    StreamArtistCompleteHistoryScope as CHScope
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistRecoveredHydrationSource as CHProvenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationSource.sol";
import {
    StreamArtistRecoveredHydrationGuards as CHGuards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistCompleteHistoryBindingSource as CHBindings
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingSource.sol";
import {
    StreamArtistCompleteHistoryBindingProof as CHBindingProof
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingProof.sol";
import {
    StreamArtistCompleteHistoryCatalogue as CHCatalogue
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryCollaborators as CHCollaborators
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCollaborators.sol";
import {
    StreamArtistCompleteHistoryPlatformSource as CHPlatform
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPlatformSource.sol";
import {
    StreamArtistCompleteHistoryClocks as CHClocks
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryClocks.sol";
import {
    StreamArtistPrimaryCollaboratorAccountNonces as CHAccounts
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAccountNonces.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as CHClockType
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as CHFrame
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as CHIH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistCompleteHistoryPreparationPrincipals as CHPrincipals
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPreparationPrincipals.sol";
import {
    StreamArtistRecoveredHydrationAdmission as CHAdmissionType
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationAdmission.sol";

/// @notice Real native registrations, threshold signatures, original Archive and global nonces.
/// @dev Inherited Core/governance unit boundaries remain explicit. No op60 or runtime pass is claimed.
contract StreamArtistCompleteHistoryIdentityActualTest is ArtistPrimaryCollaboratorFixture {
    struct IdentityObserved {
        M.State scope;
        CHType.Inventory inventory;
        CHClockType.Result clocks;
        RH.NonceInventory[] nonces;
        bytes[] identities;
    }

    function testCompleteIdentityNewCorrectionKeepsAllThreeOriginalRegistrationSlots() external {
        bytes32 latest = _history(false);
        IdentityObserved memory x = _observeIdentities(latest);
        require(x.identities.length == 3, "A, ordinary collaborator, genuinely new B");
        require(
            x.inventory.bindings.bindings[1].corrections[1].approval.registrationNonce == 2,
            "new correction uses real allocator slot two"
        );
        require(
            this.recoveries(x.identities[_principal(x.scope, collaboratorId)]) == 0,
            "ordinary collaborator has zero recoveries"
        );
        require(
            this.recoveries(x.identities[_principal(x.scope, latest)]) == 0,
            "new primary needs no fabricated recovery"
        );
        require(
            x.inventory.bindings.bindings[1].bindings.rows[0].item.artistId == artistId,
            "former primary retained separately from latest B"
        );
    }

    function testCompleteIdentityReusedCorrectionKeepsZeroRegistrationNonceWithoutNewSlot()
        external
    {
        bytes32 latest = _history(true);
        IdentityObserved memory x = _observeIdentities(latest);
        require(latest == collaboratorId && x.identities.length == 2, "B is existing collaborator");
        require(
            x.inventory.bindings.bindings[1].corrections[1].approval.registrationNonce == 0,
            "reused B keeps original zero correction nonce"
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce() == 2,
            "reuse does not allocate another original identity"
        );
    }

    function testCompleteIdentityRejectsFormerPrincipalDocumentCorruptionAndRestores() external {
        IdentityObserved memory x = _observeIdentities(_history(false));
        uint256 a = _principal(x.scope, artistId);
        bytes memory saved = x.identities[a];
        x.identities[a] = this.tamper(x.identities[a], 0, false);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
    }

    function testCompleteIdentityRetainsOriginalCollaboratorSignatureAcrossPrimaryCorrection()
        external
    {
        IdentityObserved memory x = _observeIdentities(_historyWithPartial(true, true));
        require(x.clocks.accepted[1][0] == 1, "former generation's genuine collaborator join");
        uint256 a = _principal(x.scope, collaboratorId);
        bytes memory saved = x.identities[a];
        x.identities[a] = this.tamper(x.identities[a], pcAccepted[0], true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
    }

    function testCompleteIdentityRejectsFormerPrimaryAndCollaboratorSignatureCorruption() external {
        IdentityObserved memory x = _observeIdentities(_history(true));
        uint256 a = _principal(x.scope, artistId);
        bytes memory saved = x.identities[a];
        x.identities[a] = this.tamper(x.identities[a], pcPrimary[0], true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        x.identities[a] = this.tamper(x.identities[a], pcRecords[pcRecords.length - 1], true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        a = _principal(x.scope, collaboratorId);
        saved = x.identities[a];
        x.identities[a] = this.tamper(x.identities[a], collaboratorId, true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
        x.identities[a] = saved;
        CHFacts.validate(CHFacts.Context(x.identities, x.scope, x.inventory, x.clocks));
    }

    function testCompleteIdentityRejectsOmittedGlobalAccountNonceLane() external {
        IdentityObserved memory x = _observeIdentities(_history(true));
        RH.NonceInventory[] memory changed = new RH.NonceInventory[](x.nonces.length - 1);
        uint256 count;
        for (uint256 i; i < x.nonces.length; ++i) {
            if (x.nonces[i].index.kind == 3) continue;
            changed[count++] = x.nonces[i];
        }
        require(count == changed.length, "one real collaborator account lane removed");
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        CHIdentity.validateCollected(x.scope, x.inventory, x.clocks, x.identities, changed);
    }

    function testCompletePrincipalsCollectAllActualIdentityPayoutTimingAndFeatures() external {
        IdentityObserved memory x = _observeIdentities(_history(false));
        CHPrincipals.Result memory r = CHPrincipals.collect(_certificate(x));
        require(
            keccak256(abi.encode(r.principals.identities)) == keccak256(abi.encode(x.identities)),
            "same canonical source identity bytes"
        );
        require(
            r.principals.payouts.length == 3 && r.principals.authoritySupplement.length == 3,
            "every real principal has complete payout and explicit supplement slot"
        );
        require(
            r.emptyIdentity.length == 0 && r.externalGuards.artistId != 0,
            "real principals never use empty certificate"
        );
        require(
            r.features == (CHType.FEATURE | RH.CLASS_ONE),
            "feature bits describe actual class1 zero-recovery source"
        );
        CHPrincipals.collectValidated(_certificate(x), r.principals);
    }

    function testCompletePrincipalsCannotAuthorizeSuppliedIdentityOrSupplementBytes() external {
        IdentityObserved memory x = _observeIdentities(_history(true));
        CHAdmissionType.Certificate memory c = _certificate(x);
        CHPrincipals.Result memory r = CHPrincipals.collect(c);
        bytes memory saved = r.principals.identities[0];
        r.principals.identities[0] = this.tamper(saved, 0, false);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHPrincipals.collectValidated(c, r.principals);
        r.principals.identities[0] = saved;
        r.principals.authoritySupplement[0] = abi.encode("not fixed-source authority");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHPrincipals.collectValidated(c, r.principals);
        delete r.principals.authoritySupplement[0];
        bytes memory payout = r.principals.payouts[0];
        r.principals.payouts[0] = abi.encode("substituted payout");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHPrincipals.collectValidated(c, r.principals);
        r.principals.payouts[0] = payout;
        CHPrincipals.collectValidated(c, r.principals);
    }

    function _certificate(IdentityObserved memory x)
        private
        view
        returns (CHAdmissionType.Certificate memory c)
    {
        // This phase test supplies real current source fields. Governed predecessor/lane
        // admission is exercised separately; no operation60 admission is claimed here.
        c.prior = address(ingress);
        c.sourceCoordinator = address(coordinator);
        c.source = suite;
        c.provenance = x.inventory.provenance;
        c.artists = x.scope.artists;
        c.collections = x.scope.collections;
    }

    function recoveries(bytes calldata raw) external pure returns (uint256) {
        return CHFrame.bundle(raw).recoveries.length;
    }

    function tamper(bytes calldata raw, bytes32 record, bool signature)
        external
        pure
        returns (bytes memory changed)
    {
        CHIH.Bundle calldata b = CHFrame.bundle(raw);
        bytes calldata value = b.documents[0].document;
        if (signature) {
            bool found;
            for (uint256 i; i < b.signatures.length; ++i) {
                if (b.signatures[i].recordHash != record) continue;
                require(!found, "unique actual signature row");
                value = b.signatures[i].signature;
                found = true;
            }
            require(found, "original signature exists");
        }
        require(value.length != 0, "real source bytes");
        uint256 offset;
        assembly ("memory-safe") { offset := sub(value.offset, raw.offset) }
        changed = raw;
        changed[offset] = bytes1(uint8(changed[offset]) ^ 1);
    }

    function _history(bool reuse) private returns (bytes32 latest) {
        return _historyWithPartial(reuse, false);
    }

    function _historyWithPartial(bool reuse, bool collaboratorPartial)
        private
        returns (bytes32 latest)
    {
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        _pcIdentity();
        C.BindingAcceptance memory row = _pcPropose();
        if (collaboratorPartial) _pcAccept(row, false);
        else _pcPrimaryAccept();
        _pcRefuse();
        bytes memory document = reuse
            ? bytes("actual collaborator hydration identity")
            : bytes("complete history new correction identity");
        string memory name = reuse ? "Collaborator Safe" : "New correction B";
        T.BindingProposal memory proposal = _proposal(reuse ? collaboratorId : bytes32(0));
        proposal.artistAddress = reuse ? address(delegateSafe) : address(0xB0B);
        proposal.identityRecordHash = keccak256(document);
        proposal.identityRecordURI = reuse ? "urn:pc:identity" : "urn:complete:new-b";
        proposal.reasonHash = keccak256("complete identity original correction");
        uint256 allocation = IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce();
        (PCBC.Context memory context,) =
            PCCorrectionAdmission.context(suite, 2, proposal, document, name, 0);
        address authority = manager.governanceAuthority();
        ArtistUnitRoles(suite.roleRegistry).setAdmin(authority, true);
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance(authority)
            .configureContestReads(
                suite.roleRegistry, address(artist), proposal.reasonHash, "urn:complete:correction"
            );
        bytes32 action = keccak256(abi.encode("complete identity correction", context));
        ArtistUnitGovernance(authority)
            .executeModuleContextWithAction(
                action,
                address(ingress),
                abi.encodeCall(
                    PCCorrection.proposeArtistBindingAfterRevocation,
                    (uint256(2), proposal, document, name, bytes32(0))
                ),
                2,
                context.scopeHash,
                context.oldValueHash,
                context.newValueHash
            );
        _rhCandidate(0, "binding_lifecycle.replay.correction_action", action);
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(2), uint64(2)))
        );
        if (!reuse) {
            _rhCandidate(
                2,
                "identity_authority.replay.nonce_allocator",
                keccak256(abi.encode(bytes32(0), allocation))
            );
        }
        latest = Binding(suite.owners[0]).binding(2).artistId;
    }

    function _observeIdentities(bytes32 latest) private view returns (IdentityObserved memory x) {
        RH.Request memory request = _rhRequest();
        x.inventory.provenance = CHProvenance.collect(
            suite, address(coordinator), request.records.authority.replayOrigins
        );
        MH.Request memory selected;
        selected.artistIds = new bytes32[](latest == collaboratorId ? 2 : 3);
        selected.artistIds[0] = artistId;
        selected.artistIds[1] = collaboratorId;
        if (selected.artistIds.length == 3) selected.artistIds[2] = latest;
        for (uint256 i; i < selected.artistIds.length; ++i) {
            for (uint256 j; j < i; ++j) {
                if (selected.artistIds[i] < selected.artistIds[j]) {
                    (selected.artistIds[i], selected.artistIds[j]) =
                    (selected.artistIds[j], selected.artistIds[i]);
                }
            }
        }
        selected.collections = new MH.Collection[](2);
        T.Binding[] memory heads = new T.Binding[](2);
        for (uint256 k; k < 2; ++k) {
            heads[k] = Binding(suite.owners[0]).binding(k + 1);
            selected.collections[k] = MH.Collection(heads[k].artistId, k + 1, new AH.PolicyKey[](0));
        }
        x.scope = CHScope.partition(selected, heads, x.inventory.provenance);
        x.inventory.bindings = CHBindings.collect(
            suite.owners[0], x.scope, RH.ownerProvenance(x.inventory.provenance, 0)
        );
        (x.inventory.archive.catalogues, x.inventory.archive.operations) =
            CHCatalogue.collect(x.inventory.provenance);
        x.inventory.archive = CHCollaborators.collect(
            x.inventory.provenance, x.inventory.archive.catalogues, x.inventory.archive.operations
        );
        x.inventory.platforms = CHPlatform.collect(
            suite.owners[4],
            x.scope,
            RH.ownerProvenance(x.inventory.provenance, 4),
            x.inventory.archive.catalogues,
            x.inventory.archive.operations
        );
        x.clocks = CHClocks.validate(
            x.scope,
            x.inventory.provenance,
            x.inventory.bindings,
            x.inventory.archive,
            x.inventory.platforms
        );
        CHBindingProof.validate(
            x.scope,
            RH.ownerProvenance(x.inventory.provenance, 0),
            x.inventory.bindings,
            x.inventory.archive,
            x.clocks
        );
        x.inventory.accounts = CHAccounts.collect(x.inventory.provenance, x.inventory.archive);
        (, x.nonces) =
            CHGuards.collect(x.inventory.provenance, 2, request.records.authority.replayOrigins[2]);
        x.identities = CHIdentity.collect(x.scope, x.inventory, x.clocks, x.nonces);
    }

    function _principal(M.State memory s, bytes32 id) private pure returns (uint256) {
        for (uint256 i; i < s.artists.length; ++i) {
            if (s.artists[i].artistId == id) return i;
        }
        revert("principal not selected");
    }
}
