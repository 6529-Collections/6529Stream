// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryConsentUses as Uses
} from "../../smart-contracts/domains/artist/StreamArtistCompleteHistoryConsentUses.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistDelegationState as Delegation
} from "../../smart-contracts/domains/artist/StreamArtistDelegationState.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistContentTypes as Content
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";

/// @dev Synthetic complete typed worker inputs, not source admission or original writer tests.
/// No calls are mocked: the real Uses and chronology workers consume canonical full Identity
/// frames and both complete eras. Full map/nonce/Archive admission and all-family final counts
/// remain enclosing-profile prerequisites. Records here are labelled synthetic original facts.
contract StreamArtistCompleteHistoryConsentUsesTest {
    bytes32 private constant A = bytes32(uint256(1));
    bytes32 private constant B = bytes32(uint256(2));
    bytes32 private constant GRANT_A = bytes32(uint256(81));
    bytes32 private constant GRANT_B = bytes32(uint256(82));
    bytes32 private constant BINDING_A = bytes32(uint256(11));
    bytes32 private constant BINDING_B = bytes32(uint256(12));
    bytes32 private constant PENDING_B = bytes32(uint256(13));
    bytes32 private constant NONCE = keccak256("identity_authority.replay.delegated_nonce");

    function invoke(Uses.Context calldata x) external pure returns (uint256[][] memory) {
        return Uses.validate(x);
    }

    function testHistoricalArtistCountsSurviveDifferentPendingCurrentArtistAndEmptyU() public view {
        Uses.Context memory x = _fixture();
        _counts(x, 2, 2);
        require(x.consents[0].bindings[2].artistId == B && !x.consents[0].bindings[2].accepted);
        // The retained grant's actual final total may include other families. This worker must
        // return Consent increments, not prematurely require equality to that final total.
        IH.Bundle memory a = abi.decode(x.identities[0], (IH.Bundle));
        a.delegations[0].record.uses = 99;
        x.identities[0] = abi.encode(a);
        _counts(x, 2, 2);
    }

    function testTrueUHasNoIdentityAndNoConsentUses() public view {
        Uses.Context memory x;
        x.identities = new bytes[](0);
        x.scope.artists = new AH.Query[](0);
        x.scope.collections = new AH.Query[](1);
        x.scope.collections[0].collectionId = 7;
        x.consents = new G.Consents[](1);
        x.consents[0].rows.original.collectionId = 7;
        require(this.invoke(x).length == 0);
        x.consents[0].rows.original.policies = new DH.Policy[](1);
        x.consents[0].rows.original.policies[0].recordHash = bytes32(uint256(101));
        _reject(x);
        x.consents[0].rows.original.policies = new DH.Policy[](0);
        require(this.invoke(x).length == 0);
    }

    function testDelegatedPolicyNeedsSameHistoricalArtistModeTwoWithoutInventingGeneration()
        public
        view
    {
        Uses.Context memory x = _fixture();
        // B's accepted mode2 and current pending mode1 cannot authorize historical Artist A.
        x.consents[0].bindings[0].consentMode = 1;
        _reject(x);
        x.consents[0].bindings[0].consentMode = 2;
        _counts(x, 2, 2);
        // Policy is located by original record, not by policy-key order or current head.
        DH.Policy memory first =
            abi.decode(abi.encode(x.consents[0].rows.original.policies[0]), (DH.Policy));
        x.consents[0].rows.original.policies[0] = x.consents[0].rows.original.policies[1];
        x.consents[0].rows.original.policies[1] = first;
        _counts(x, 2, 2);
    }

    function testReceiptPrincipalCannotBeReplacedByCurrentCollectionArtist() public view {
        Uses.Context memory x = _fixture();
        x.provenance.journals[6][0].receipt.artistId = B;
        _reject(x);
        x.provenance.journals[6][0].receipt.artistId = A;
        _counts(x, 2, 2);
    }

    function testEverySavedGenerationMustBelongToReceiptArtistAndBeAccepted() public view {
        Uses.Context memory x = _fixture();
        x.consents[0].rows.consents[0].bindingGeneration = 2;
        _reject(x);
        x.consents[0].rows.consents[0].bindingGeneration = 1;
        x.consents[0].rows.royalties[0].item.bindingGeneration = 3;
        _reject(x);
        x.consents[0].rows.royalties[0].item.bindingGeneration = 2;
        x.consents[0].rows.original.economics[0].item.association.bindingHash = BINDING_A;
        _reject(x);
        x.consents[0].rows.original.economics[0].item.association.bindingHash = BINDING_B;
        _counts(x, 2, 2);
    }

    function testMissingDuplicateAndOversizedSignaturesRejectButEmptyDirectEvidenceSurvives()
        public
        view
    {
        Uses.Context memory x = _fixture();
        IH.Bundle memory a = abi.decode(x.identities[0], (IH.Bundle));
        a.signatures[3].recordHash = bytes32(uint256(999));
        x.identities[0] = abi.encode(a);
        _reject(x); // Missing original52; it must not be ignored as zero delegation use.
        a.signatures[3].recordHash = bytes32(uint256(108));
        a.signatures[0].signature = new bytes(4097);
        x.identities[0] = abi.encode(a);
        _reject(x);
        a.signatures[0].signature = "";
        IH.SignatureRow[] memory doubled = new IH.SignatureRow[](5);
        for (uint256 i; i < 4; ++i) {
            doubled[i] = a.signatures[i];
        }
        doubled[4] = a.signatures[0];
        a.signatures = doubled;
        x.identities[0] = abi.encode(a);
        _reject(x);
        x = _fixture();
        _counts(x, 2, 2);
    }

    function testIdentityUnionMustBeExactAndOrdered() public view {
        Uses.Context memory x = _fixture();
        bytes memory a = x.identities[0];
        x.identities[0] = x.identities[1];
        _reject(x);
        x.identities[0] = a;
        x.scope.artists[1].artistId = A;
        _reject(x);
        x.scope.artists[1].artistId = B;
        _counts(x, 2, 2);
    }

    function testUnmatchedDuplicateAndCrossCollectionOccurrencesReject() public view {
        Uses.Context memory x = _fixture();
        x.provenance.journals[6][1].receipt.recordHash = bytes32(uint256(101));
        _reject(x);
        x.provenance.journals[6][1].receipt.recordHash = bytes32(uint256(102));
        x.provenance.journals[6][0].receipt.collectionId = 2;
        _reject(x);
        x.provenance.journals[6][0].receipt.collectionId = 1;
        x.consents[0].rows.original.policies[1].recordHash = bytes32(uint256(199));
        _reject(x);
        x.consents[0].rows.original.policies[1].recordHash = bytes32(uint256(102));
        _counts(x, 2, 2);
    }

    function testWrongGrantArtistScopeCapabilityAndZeroDelegateReject() public view {
        Uses.Context memory x = _fixture();
        IH.Bundle memory a = abi.decode(x.identities[0], (IH.Bundle));
        a.delegations[0].record.grant.artistId = B;
        x.identities[0] = abi.encode(a);
        _reject(x);
        a.delegations[0].record.grant.artistId = A;
        a.delegations[0].record.grant.collectionId = 2;
        x.identities[0] = abi.encode(a);
        _reject(x);
        a.delegations[0].record.grant.collectionId = 0;
        a.delegations[0].record.grant.capabilities = D.POLICY_CONSENT;
        x.identities[0] = abi.encode(a);
        _reject(x);
        a.delegations[0].record.grant.capabilities |= D.SALE_CONSENT;
        a.delegations[0].record.grant.delegate = address(0);
        x.identities[0] = abi.encode(a);
        _reject(x);
        a.delegations[0].record.grant.delegate = address(0xA1);
        x.identities[0] = abi.encode(a);
        _counts(x, 2, 2);
    }

    function testSameEraCrossOwnerRevisionsAreNotOrderedAsLocalClock() public view {
        Uses.Context memory x = _fixture();
        IH.Bundle memory b = abi.decode(x.identities[1], (IH.Bundle));
        b.delegations[0].position.point = RH.Point(x.provenance.eras[1].originHash, 2, 19);
        x.identities[1] = abi.encode(b);
        // Economics and royalty receipt revisions3/6 cannot be ordered against Identity19.
        _counts(x, 2, 2);
    }

    function testEarlierEraRevocationRejectsAndSameEraOriginalUseRetains() public view {
        Uses.Context memory x = _fixture();
        IH.Bundle memory b = abi.decode(x.identities[1], (IH.Bundle));
        b.delegations[0].record.revoked = true;
        b.delegations[0].record.revocationRecordHash = bytes32(uint256(901));
        x.identities[1] = abi.encode(b);
        x.provenance.journals[2] = new RH.JournalEntry[](1);
        x.provenance.journals[2][0] = _receipt(x.provenance.eras[0].originHash, 2, 4, 27, B, 0, 901);
        _reject(x);
        x.provenance.journals[2][0].position.point.environmentHash = x.provenance.eras[1].originHash;
        _counts(x, 2, 2);
        x.provenance.journals[2][0].receipt.artistId = A;
        _reject(x);
    }

    function testEarlierEraReplacementCannotAuthorizeLaterUse() public view {
        Uses.Context memory x = _fixture();
        IH.Bundle memory b = abi.decode(x.identities[1], (IH.Bundle));
        IH.DelegationRow[] memory rows = new IH.DelegationRow[](2);
        rows[0] = b.delegations[0];
        rows[1] = abi.decode(abi.encode(b.delegations[0]), (IH.DelegationRow));
        rows[1].recordHash = bytes32(uint256(83));
        rows[1].position.point.ownerRevision = 3;
        b.delegations = rows;
        x.identities[1] = abi.encode(b);
        _reject(x);
        b.delegations[1].position.point.environmentHash = x.provenance.eras[1].originHash;
        x.identities[1] = abi.encode(b);
        uint256[][] memory totals = this.invoke(x);
        require(totals[0][0] == 2 && totals[1][0] == 2 && totals[1][1] == 0);
    }

    function testDelegatedSaleNeedsExactOriginalLaneSignerAndAdmittedNonce() public view {
        Uses.Context memory x = _fixture();
        x.consents[0].rows.original.sales[0].item.signer = address(0xB1);
        _reject(x);
        x.consents[0].rows.original.sales[0].item.signer = address(0xA1);
        x.provenance.aliases[2][0].cell.commitment = 0;
        _reject(x);
        x.provenance.aliases[2][0].cell.commitment = bytes32(uint256(701));
        x.consents[0].rows.original.sales[0].item.nonce = 8;
        _reject(x);
        x.consents[0].rows.original.sales[0].item.nonce = 7;
        _counts(x, 2, 2);
    }

    function testDelegatedSaleSameOwnerAdmissionPrecedesRevocationAndReplacement() public view {
        Uses.Context memory x = _fixture();
        IH.Bundle memory a = abi.decode(x.identities[0], (IH.Bundle));
        a.delegations[0].record.revoked = true;
        a.delegations[0].record.revocationRecordHash = bytes32(uint256(902));
        x.identities[0] = abi.encode(a);
        x.provenance.journals[2] = new RH.JournalEntry[](1);
        x.provenance.journals[2][0] = _receipt(x.provenance.eras[1].originHash, 2, 4, 27, A, 0, 902);
        _reject(x); // Original nonce admitted at owner2 revision5, after revocation4.
        x.provenance.journals[2][0].position.point.ownerRevision = 6;
        _counts(x, 2, 2);
        IH.DelegationRow[] memory rows = new IH.DelegationRow[](2);
        rows[0] = a.delegations[0];
        rows[1] = abi.decode(abi.encode(a.delegations[0]), (IH.DelegationRow));
        rows[1].recordHash = bytes32(uint256(84));
        rows[1].position.point = RH.Point(x.provenance.eras[1].originHash, 2, 5);
        rows[1].record.revoked = false;
        a.delegations = rows;
        x.identities[0] = abi.encode(a);
        _reject(x);
        a.delegations[1].position.point.ownerRevision = 6;
        x.identities[0] = abi.encode(a);
        uint256[][] memory totals = this.invoke(x);
        require(totals[0][0] == 2 && totals[0][1] == 0 && totals[1][0] == 2);
    }

    function testRekeyedSaleAliasesMustKeepOneOriginalAdmission() public view {
        Uses.Context memory x = _fixture();
        // A later synthetic import era changes the alias origin, not its original admission.
        // Complete provenance authentication remains the enclosing profile's prerequisite.
        RH.OriginEnvironment[] memory origins = new RH.OriginEnvironment[](3);
        RH.Era[] memory eras = new RH.Era[](3);
        for (uint256 e; e < 2; ++e) {
            origins[e] = x.provenance.origins[e];
            eras[e] = x.provenance.eras[e];
        }
        origins[2] = abi.decode(abi.encode(origins[1]), (RH.OriginEnvironment));
        origins[2].registry = address(102);
        for (uint8 o; o < 7; ++o) {
            origins[2].owners[o] = address(uint160(220 + uint256(o)));
            origins[2].ownerCodeHashes[o] = bytes32(uint256(320) + o);
        }
        eras[2] = abi.decode(abi.encode(eras[1]), (RH.Era));
        eras[2].originHash = RH.originHash(origins[2]);
        x.provenance.origins = origins;
        x.provenance.eras = eras;
        RH.ReplayAlias[] memory aliases = new RH.ReplayAlias[](2);
        aliases[0] = x.provenance.aliases[2][0];
        aliases[1] = abi.decode(abi.encode(x.provenance.aliases[2][0]), (RH.ReplayAlias));
        aliases[1].originHash = eras[2].originHash;
        bytes32 originalAdmission = keccak256(abi.encode(aliases[0].admittedAt));
        require(aliases[0].originHash != aliases[1].originHash);
        require(aliases[1].admittedAt.environmentHash == eras[1].originHash);
        require(keccak256(abi.encode(aliases[1].admittedAt)) == originalAdmission);
        x.provenance.aliases[2] = aliases;
        _counts(x, 2, 2);
        x.provenance.aliases[2][1].admittedAt.ownerRevision = 6;
        _reject(x);
        x.provenance.aliases[2][1].admittedAt =
            abi.decode(abi.encode(x.provenance.aliases[2][0].admittedAt), (RH.Point));
        require(keccak256(abi.encode(x.provenance.aliases[2][1].admittedAt)) == originalAdmission);
        _counts(x, 2, 2);
    }

    function testNativeSanctionHasNoUseButNativeConfirmationIsRejected() public view {
        Uses.Context memory x = _fixture();
        RH.JournalEntry[] memory journal = new RH.JournalEntry[](9);
        for (uint256 i; i < 8; ++i) {
            journal[i] = x.provenance.journals[6][i];
        }
        journal[8] = _receipt(x.provenance.eras[1].originHash, 6, 9, 12, A, 1, 109);
        x.provenance.journals[6] = journal;
        _counts(x, 2, 2); // Sanction proof/signature belongs to the enclosing fixed validator.
        x.provenance.journals[6][8].receipt.operation = 13;
        IH.Bundle memory a = abi.decode(x.identities[0], (IH.Bundle));
        IH.SignatureRow[] memory signatures = new IH.SignatureRow[](5);
        for (uint256 i; i < 4; ++i) {
            signatures[i] = a.signatures[i];
        }
        signatures[4].recordHash = bytes32(uint256(109));
        a.signatures = signatures;
        x.identities[0] = abi.encode(a);
        _reject(x);
    }

    function _counts(Uses.Context memory x, uint256 a, uint256 b) private view {
        uint256[][] memory totals = this.invoke(x);
        require(totals.length == 2 && totals[0].length == 1 && totals[1].length == 1);
        require(totals[0][0] == a && totals[1][0] == b);
    }

    function _reject(Uses.Context memory x) private view {
        try this.invoke(x) returns (uint256[][] memory) {
            revert("accepted invalid historical use");
        } catch (bytes memory reason) {
            require(
                keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
                "unexpected failure"
            );
        }
    }

    function _fixture() private pure returns (Uses.Context memory x) {
        x.scope.artists = new AH.Query[](2);
        x.scope.artists[0].artistId = A;
        x.scope.artists[1].artistId = B;
        x.scope.collections = new AH.Query[](2);
        x.scope.collections[0].collectionId = 1;
        x.scope.collections[0].artistId = B;
        x.scope.collections[0].bindingHash = PENDING_B;
        x.scope.collections[1].collectionId = 2; // Empty unbound collection partition.
        x.consents = new G.Consents[](2);
        x.consents[0].rows.original.artistId = B;
        x.consents[0].rows.original.collectionId = 1;
        x.consents[0].rows.original.bindingHash = PENDING_B;
        x.consents[1].rows.original.collectionId = 2;
        x.consents[0].bindings = new T.Binding[](3);
        x.consents[0].bindings[0] = _binding(A, 1, BINDING_A, 2, true);
        x.consents[0].bindings[1] = _binding(B, 2, BINDING_B, 2, true);
        x.consents[0].bindings[2] = _binding(B, 3, PENDING_B, 1, false);
        x.provenance = _provenance();
        x.identities = new bytes[](2);
        IH.Bundle memory a;
        IH.Bundle memory b;
        a.artistId = A;
        b.artistId = B;
        a.signatures = new IH.SignatureRow[](4);
        b.signatures = new IH.SignatureRow[](4);
        a.signatures[0].recordHash = bytes32(uint256(101));
        a.signatures[1].recordHash = bytes32(uint256(104));
        a.signatures[2].recordHash = bytes32(uint256(105));
        a.signatures[3].recordHash = bytes32(uint256(108));
        b.signatures[0].recordHash = bytes32(uint256(102));
        b.signatures[1].recordHash = bytes32(uint256(103));
        b.signatures[2].recordHash = bytes32(uint256(106));
        b.signatures[3].recordHash = bytes32(uint256(107));
        a.delegations = new IH.DelegationRow[](1);
        b.delegations = new IH.DelegationRow[](1);
        a.delegations[0] = _grant(
            A,
            address(0xA1),
            GRANT_A,
            D.POLICY_CONSENT | D.SALE_CONSENT,
            x.provenance.eras[0].originHash
        );
        b.delegations[0] = _grant(
            B,
            address(0xB1),
            GRANT_B,
            D.ECONOMICS | D.ROYALTY_FREEZE,
            x.provenance.eras[0].originHash
        );
        x.identities[0] = abi.encode(a);
        x.identities[1] = abi.encode(b);
        _rows(x.consents[0]);
    }

    function _rows(G.Consents memory c) private pure {
        c.rows.original.policies = new DH.Policy[](2);
        c.rows.original.policies[0] = DH.Policy(bytes32(uint256(101)), GRANT_A);
        c.rows.original.policies[1] = DH.Policy(bytes32(uint256(102)), 0);
        c.rows.original.economics = new Base.Economics[](1);
        c.rows.original.economics[0].item.recordHash = bytes32(uint256(103));
        c.rows.original.economics[0].item.terms.collectionId = 1;
        c.rows.original.economics[0].item.association.artistId = B;
        c.rows.original.economics[0].item.association.bindingGeneration = 2;
        c.rows.original.economics[0].item.association.bindingHash = BINDING_B;
        c.rows.original.economics[0].grant = GRANT_B;
        c.rows.original.sales = new DH.Sale[](1);
        c.rows.original.sales[0].item.recordHash = bytes32(uint256(104));
        c.rows.original.sales[0].item.terms.collectionId = 1;
        c.rows.original.sales[0].item.artistId = A;
        c.rows.original.sales[0].item.bindingGeneration = 1;
        c.rows.original.sales[0].item.bindingHash = BINDING_A;
        c.rows.original.sales[0].item.signer = address(0xA1);
        c.rows.original.sales[0].item.authorityClass = 2;
        c.rows.original.sales[0].item.nonce = 7;
        c.rows.original.sales[0].grant = GRANT_A;
        c.rows.consents = new ContentOwner.ConsentRecord[](1);
        c.rows.consents[0].recordHash = bytes32(uint256(105));
        c.rows.consents[0].artistId = A;
        c.rows.consents[0].bindingGeneration = 1;
        c.rows.consents[0].terms.collectionId = 1;
        c.rows.consents[0].authorityClass = 1;
        c.rows.royalties = new ContentH.Royalty[](1);
        c.rows.royalties[0].item = T.RoyaltyFreezeRecord(bytes32(uint256(106)), B, 2);
        c.rows.royalties[0].terms.collectionId = 1;
        c.rows.royalties[0].grant = GRANT_B;
        c.rows.freezes = new Content.FreezeRecord[](1);
        c.rows.freezes[0].recordHash = bytes32(uint256(107));
        c.rows.freezes[0].artistId = B;
        c.rows.freezes[0].bindingGeneration = 2;
        c.rows.freezes[0].authorityClass = 3;
    }

    function _binding(bytes32 artist, uint64 generation, bytes32 hash, uint8 mode, bool accepted)
        private
        pure
        returns (T.Binding memory b)
    {
        b.artistId = artist;
        b.generation = generation;
        b.bindingHash = hash;
        b.consentMode = mode;
        b.accepted = accepted;
    }

    function _grant(
        bytes32 artist,
        address delegate,
        bytes32 hash,
        uint32 capabilities,
        bytes32 era
    ) private pure returns (IH.DelegationRow memory row) {
        row.position.point = RH.Point(era, 2, 2);
        row.recordHash = hash;
        row.record.grant.artistId = artist;
        row.record.grant.delegate = delegate;
        row.record.grant.capabilities = capabilities;
        row.record.uses = 2;
    }

    function _provenance() private pure returns (RH.Provenance memory p) {
        p.origins = new RH.OriginEnvironment[](2);
        p.eras = new RH.Era[](2);
        for (uint256 e; e < 2; ++e) {
            p.origins[e].chainId = 31337;
            p.origins[e].registry = address(uint160(100 + e));
            for (uint8 o; o < 7; ++o) {
                p.origins[e].owners[o] = address(uint160(200 + 10 * e + o));
                p.origins[e].ownerCodeHashes[o] = bytes32(uint256(300 + 10 * e + o));
                p.eras[e].checkpoints[o].schema = RH.CHECKPOINT;
                p.eras[e].checkpoints[o].ownerState.domainId = RH.ownerDomain(o);
                p.eras[e].checkpoints[o].ownerState.revision = 20;
            }
            p.eras[e].originHash = RH.originHash(p.origins[e]);
        }
        p.journals[6] = new RH.JournalEntry[](8);
        uint16[8] memory ops = [uint16(14), 14, 15, 16, 17, 20, 21, 52];
        bytes32[8] memory artists = [A, B, B, A, A, B, B, A];
        for (uint256 i; i < 8; ++i) {
            p.journals[6][i] =
                _receipt(p.eras[1].originHash, 6, uint64(i + 1), ops[i], artists[i], 1, 101 + i);
        }
        p.aliases[2] = new RH.ReplayAlias[](1);
        p.aliases[2][0].ownerIndex = 2;
        p.aliases[2][0].originHash = p.eras[1].originHash;
        p.aliases[2][0].surface = NONCE;
        p.aliases[2][0].scope = keccak256(abi.encode(Delegation.lane(A, address(0xA1)), uint256(7)));
        p.aliases[2][0].cell.commitment = bytes32(uint256(701));
        p.aliases[2][0].cell.touchedRevision = 5;
        p.aliases[2][0].cell.kind = 1;
        p.aliases[2][0].cell.status = 2;
        p.aliases[2][0].admittedAt = RH.Point(p.eras[1].originHash, 2, 5);
    }

    function _receipt(
        bytes32 era,
        uint8 owner,
        uint64 revision,
        uint16 op,
        bytes32 artist,
        uint256 collection,
        uint256 record
    ) private pure returns (RH.JournalEntry memory row) {
        row.position.point = RH.Point(era, owner, revision);
        row.receipt.operation = op;
        row.receipt.artistId = artist;
        row.receipt.collectionId = collection;
        row.receipt.recordHash = bytes32(record);
    }
}
