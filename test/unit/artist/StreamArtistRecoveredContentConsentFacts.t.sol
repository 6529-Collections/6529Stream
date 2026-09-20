// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredContentConsentFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentFacts.sol";
import {
    StreamArtistRecoveredDelegationConsentFacts as Combined
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegationConsentFacts.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Consent
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistDelegationState as Delegation
} from "../../../smart-contracts/domains/artist/StreamArtistDelegationState.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

import {
    StreamArtistRecoveredContentConsentFactRows as Leaf
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentFactRows.sol";

/// @notice Pure component vectors for cross-owner reconciliation, not complete certificates or
/// real signed admissions. Owner6 map/replay authentication, Identity nonce inventory and actual
/// Safe/Archive import behavior are exercised in the separate codec and actual-owner hosts.
contract StreamArtistRecoveredContentConsentFactsTest {
    struct Fixture {
        IH.Bundle identity;
        ContentH.Bundle consent;
        AH.Query query;
        RH.Provenance provenance;
        PubH.Row[] attestations;
        uint8 mode;
    }

    function check(Fixture memory f) external pure {
        Combined.validate(f.identity, f.consent, f.query, f.provenance, f.mode, f.attestations);
    }

    function leaf(Fixture memory f) external pure returns (uint256[] memory) {
        return Facts.validate(f.identity, f.consent, f.query, f.provenance);
    }

    function generationLeaf(Fixture memory f, uint64 generation, bool grants)
        external
        pure
        returns (uint256[] memory)
    {
        if (grants) {
            return Leaf.validateGenerationRowsWithGrants(
                Leaf.IdentityRows(
                    f.identity.artistId, f.identity.signatures, f.identity.delegations
                ),
                Leaf.ConsentRows(
                        f.consent.original.artistId,
                        f.consent.original.collectionId,
                        f.consent.original.bindingHash,
                        f.consent.consents,
                        f.consent.royalties,
                        f.consent.freezes
                    ),
                Leaf.Scope(f.query.artistId, f.query.collectionId, f.query.bindingHash),
                f.provenance,
                generation
            );
        }
        return Leaf.validateGenerationRows(
            Leaf.IdentityRows(f.identity.artistId, f.identity.signatures, f.identity.delegations),
            Leaf.ConsentRows(
                f.consent.original.artistId,
                f.consent.original.collectionId,
                f.consent.original.bindingHash,
                f.consent.consents,
                f.consent.royalties,
                f.consent.freezes
            ),
            Leaf.Scope(f.query.artistId, f.query.collectionId, f.query.bindingHash),
            f.provenance,
            generation
        );
    }

    function testGenerationGrantEntryPreservesUseTotalsAndOldProfileRefusal() external view {
        Fixture memory f = _fixture();
        uint256[] memory original = Facts.validate(f.identity, f.consent, f.query, f.provenance);
        for (uint256 i; i < f.consent.consents.length; ++i) {
            f.consent.consents[i].bindingGeneration = 2;
        }
        for (uint256 i; i < f.consent.royalties.length; ++i) {
            f.consent.royalties[i].item.bindingGeneration = 2;
        }
        for (uint256 i; i < f.consent.freezes.length; ++i) {
            f.consent.freezes[i].bindingGeneration = 2;
        }
        uint256[] memory actual = this.generationLeaf(f, 2, true);
        assert(keccak256(abi.encode(actual)) == keccak256(abi.encode(original)));
        assert(actual.length != 0 && actual[0] == 1);
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.generationLeaf, (f, uint64(2), false)));
        assert(!ok && bytes4(reason) == RH.InvalidRecoveredHydrationProfile.selector);
        this.generationLeaf(f, 2, true);
    }

    function testGenerationGrantEntryRetainsGenerationAndCapabilityRefusals() external view {
        Fixture memory f = _fixture();
        for (uint256 i; i < f.consent.consents.length; ++i) {
            f.consent.consents[i].bindingGeneration = 2;
        }
        for (uint256 i; i < f.consent.royalties.length; ++i) {
            f.consent.royalties[i].item.bindingGeneration = 2;
        }
        for (uint256 i; i < f.consent.freezes.length; ++i) {
            f.consent.freezes[i].bindingGeneration = 2;
        }
        this.generationLeaf(f, 2, true);
        for (uint64 generation = 1; generation < 4; ++generation) {
            if (generation == 2) continue;
            (bool ok, bytes memory reason) =
                address(this).staticcall(abi.encodeCall(this.generationLeaf, (f, generation, true)));
            assert(!ok && bytes4(reason) == RH.InvalidRecoveredHydrationProfile.selector);
        }
        f.identity.delegations[0].record.grant.capabilities = 0;
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.generationLeaf, (f, uint64(2), true)));
        assert(!ok && bytes4(reason) == RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testContentFactsCompleteMixedUsesAcrossOriginalOwnerClocks() external pure {
        Fixture memory f = _fixture();
        uint256[] memory uses = Facts.validate(f.identity, f.consent, f.query, f.provenance);
        assert(uses.length == 1 && uses[0] == 1);
        Combined.validate(f.identity, f.consent, f.query, f.provenance, f.mode, f.attestations);
        assert(f.identity.delegations[0].position.point.ownerRevision == 900);
        assert(f.provenance.journals[6][4].position.point.ownerRevision == 3);
        assert(f.identity.delegations[0].record.revoked);
    }

    function testContentFactsCountRoyaltyOnlyOnceAlongside14_15_16_24() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.identity.delegations[0].record.uses = 4;
        _reject(f, true);
        f.identity.delegations[0].record.uses = 6;
        _reject(f, true);
        f.identity.delegations[0].record.uses = 5;
        this.check(f);
    }

    function testContentFactsDirect17And21CannotBecomeDelegatedOrClass4() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.consent.consents[0].authorityClass = 2;
        _reject(f, false);
        f.consent.consents[0].authorityClass = 3;
        f.consent.freezes[0].authorityClass = 4;
        _reject(f, false);
        f.consent.freezes[0].authorityClass = 3;
        this.check(f);
    }

    function testContentFactsBindArtistGenerationCollectionAndNativeHash() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.consent.consents[0].artistId = bytes32(uint256(77));
        _reject(f, false);
        f.consent.consents[0].artistId = f.query.artistId;
        f.consent.royalties[0].item.bindingGeneration = 2;
        _reject(f, false);
        f.consent.royalties[0].item.bindingGeneration = 1;
        f.consent.royalties[0].terms.collectionId = 8;
        _reject(f, false);
        f.consent.royalties[0].terms.collectionId = 7;
        f.consent.freezes[0].recordHash = bytes32(uint256(99));
        _reject(f, false);
    }

    function testContentFactsRequireEveryFilteredRowAndRejectUnusedRows() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.consent.freezes = new Content.FreezeRecord[](0);
        _reject(f, false);
        f = _fixture();
        ContentH.Royalty[] memory rows = new ContentH.Royalty[](2);
        rows[0] = f.consent.royalties[0];
        rows[1] = rows[0];
        f.consent.royalties = rows;
        _reject(f, false);
    }

    function testContentFactsRejectDuplicateWrongFamilyOrForeignNativeRows() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.provenance.journals[6][5].receipt.recordHash =
        f.provenance.journals[6][2].receipt.recordHash;
        _reject(f, false);
        f = _fixture();
        f.provenance.journals[6][4].receipt.operation = 19;
        _reject(f, false);
        f.provenance.journals[6][4].receipt.operation = 20;
        f.provenance.journals[6][4].receipt.artistId = bytes32(uint256(999));
        _reject(f, false);
    }

    function testContentFactsExactRetainedSignaturesAllowEmptyAndRejectOmission() external view {
        Fixture memory f = _fixture();
        this.check(f);
        assert(f.identity.signatures[0].signature.length == 0);
        f.identity.signatures[0].recordHash = bytes32(uint256(111));
        _reject(f, false);
        f = _fixture();
        IH.SignatureRow[] memory rows = new IH.SignatureRow[](5);
        for (uint256 i; i < 4; ++i) {
            rows[i] = f.identity.signatures[i];
        }
        rows[4] = rows[0];
        f.identity.signatures = rows;
        _reject(f, false);
        f = _fixture();
        f.identity.signatures[1].signature = new bytes(4097);
        _reject(f, false);
    }

    function testContentFactsRoyaltyRequiresOriginalGrantCapabilityScopeAndIdentity()
        external
        view
    {
        Fixture memory f = _fixture();
        this.check(f);
        f.identity.delegations[0].record.grant.capabilities &= ~D.ROYALTY_FREEZE;
        _reject(f, false);
        f.identity.delegations[0].record.grant.capabilities |= D.ROYALTY_FREEZE;
        f.identity.delegations[0].record.grant.collectionId = 8;
        _reject(f, false);
        f.identity.delegations[0].record.grant.collectionId = 0;
        this.check(f);
        f.consent.royalties[0].grant = bytes32(uint256(999));
        _reject(f, false);
    }

    function testContentFactsRoyaltyAllowsModeOneAndDirectDoesNotConsumeGrant() external view {
        Fixture memory f = _fixture();
        _onlyNewFamilies(f);
        f.mode = 1;
        f.identity.delegations[0].record.uses = 1;
        this.check(f);
        f.mode = 2;
        this.check(f);
        f.consent.royalties[0].grant = 0;
        f.identity.delegations[0].record.uses = 0;
        this.check(f);
        f.mode = 0;
        _reject(f, true);
    }

    function testContentFactsNoCurrentPrincipalEpochOrValidityReauthorization() external pure {
        Fixture memory f = _fixture();
        f.identity.identity.authorityClass = 3;
        f.identity.identity.status = 4;
        f.identity.identity.authorityAddress = address(3333);
        f.identity.delegations[0].epoch = 0;
        f.identity.delegations[0].record.grant.notBefore = 1;
        f.identity.delegations[0].record.grant.expiresAt = 2;
        Combined.validate(f.identity, f.consent, f.query, f.provenance, f.mode, f.attestations);
    }

    function testContentFactsRejectGrantFromLaterEraAndEarlierRevocation() external view {
        Fixture memory f = _fixture();
        this.check(f);
        // Put the use in A and its purported grant in B: no raw revision comparison helps.
        f.provenance.journals[6][4].position.point =
            RH.Point(f.provenance.eras[0].originHash, 6, 40);
        f.identity.delegations[0].position.point = RH.Point(f.provenance.eras[1].originHash, 2, 2);
        _reject(f, false);
        f = _fixture();
        f.provenance.journals[2][1].position.point =
            RH.Point(f.provenance.eras[0].originHash, 2, 950);
        _reject(f, false);
    }

    function testContentFactsRevocationMustBeUniqueGenuineOriginal27() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.provenance.journals[2][1].receipt.operation = 54;
        _reject(f, false);
        f.provenance.journals[2][1].receipt.operation = 27;
        RH.JournalEntry[] memory rows = new RH.JournalEntry[](3);
        rows[0] = f.provenance.journals[2][0];
        rows[1] = f.provenance.journals[2][1];
        rows[2] = rows[1];
        f.provenance.journals[2] = rows;
        _reject(f, false);
    }

    function testContentFactsEarlierReplacementRejectsWithoutComparingPeerRevisions()
        external
        view
    {
        Fixture memory f = _fixture();
        this.check(f);
        IH.DelegationRow[] memory rows = new IH.DelegationRow[](2);
        rows[0] = f.identity.delegations[0];
        rows[1] = abi.decode(abi.encode(rows[0]), (IH.DelegationRow));
        rows[1].recordHash = bytes32(uint256(999));
        rows[1].position.point = RH.Point(f.provenance.eras[0].originHash, 2, 950);
        rows[1].record.uses = 0;
        f.identity.delegations = rows;
        _reject(f, false);
        // Same-era producer ordering cannot be reconstructed from independent owner clocks.
        rows[1].position.point = RH.Point(f.provenance.eras[1].originHash, 2, 10);
        this.check(f);
    }

    function testContentFactsCombinedAttestationStillBindsActualIdentityNonce() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.provenance.aliases[2][1].scope = bytes32(uint256(99));
        _reject(f, true);
        f = _fixture();
        f.attestations = new PubH.Row[](0);
        _reject(f, true);
    }

    function testContentFactsOriginalFiveAndSixArgumentJoinsRemainSelectedSeparately()
        external
        pure
    {
        Fixture memory f = _fixture();
        f.identity.delegations[0].record.uses = 3;
        Combined.validate(f.identity, f.consent.original, f.query, f.provenance, f.mode);
        f.identity.delegations[0].record.uses = 4;
        Combined.validate(
            f.identity, f.consent.original, f.query, f.provenance, f.mode, f.attestations
        );
        f.identity.delegations[0].record.uses = 5;
        Combined.validate(f.identity, f.consent, f.query, f.provenance, f.mode, f.attestations);
    }

    function _reject(Fixture memory f, bool combined) private view {
        bytes memory input =
            combined ? abi.encodeCall(this.check, (f)) : abi.encodeCall(this.leaf, (f));
        (bool ok, bytes memory reason) = address(this).staticcall(input);
        assert(!ok);
        assert(
            keccak256(reason)
                == keccak256(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector))
        );
    }

    function _onlyNewFamilies(Fixture memory f) private pure {
        f.consent.original.policies = new DH.Policy[](0);
        f.consent.original.economics = new Consent.Economics[](0);
        f.consent.original.sales = new DH.Sale[](0);
        f.attestations = new PubH.Row[](0);
        f.provenance.journals[4] = new RH.JournalEntry[](0);
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.mode = 2;
        f.query.artistId = keccak256("artist");
        f.query.collectionId = 7;
        f.query.bindingHash = keccak256("binding");
        f.identity.artistId = f.query.artistId;
        f.provenance.origins = new RH.OriginEnvironment[](2);
        f.provenance.eras = new RH.Era[](2);
        for (uint256 i; i < 2; ++i) {
            RH.OriginEnvironment memory origin;
            origin.chainId = 1;
            origin.registry = address(uint160(100 + i));
            origin.core = address(1111);
            origin.manager = address(1112);
            for (uint8 owner; owner < 7; ++owner) {
                origin.owners[owner] = address(uint160(200 + 10 * i + owner));
                origin.ownerCodeHashes[owner] = keccak256("synthetic owner runtime");
                f.provenance.eras[i].checkpoints[owner].schema = RH.CHECKPOINT;
                f.provenance.eras[i].checkpoints[owner].ownerState.domainId = RH.ownerDomain(owner);
                f.provenance.eras[i].checkpoints[owner].ownerState.revision = i == 0 ? 1000 : 20;
            }
            f.provenance.origins[i] = origin;
            f.provenance.eras[i].originHash = RH.originHash(origin);
        }
        bytes32 first = f.provenance.eras[0].originHash;
        bytes32 second = f.provenance.eras[1].originHash;
        bytes32 grant = keccak256("original grant");
        bytes32 revoked = keccak256("original revocation");
        D.Grant memory terms = D.Grant(
            f.query.artistId,
            address(777),
            7,
            D.POLICY_CONSENT | D.ECONOMICS | D.SALE_CONSENT | D.ROYALTY_FREEZE | D.ATTEST,
            1,
            1000,
            0,
            0
        );
        f.identity.delegations = new IH.DelegationRow[](1);
        f.identity.delegations[0] = IH.DelegationRow(
            RH.Position(RH.Point(first, 2, 900), 0),
            grant,
            D.Record(terms, address(778), 1, 5, true, revoked),
            grant,
            0
        );
        f.provenance.journals[2] = new RH.JournalEntry[](2);
        f.provenance.journals[2][0] = RH.JournalEntry(
            f.identity.delegations[0].position, H.Receipt(26, f.query.artistId, 0, grant)
        );
        f.provenance.journals[2][1] = RH.JournalEntry(
            RH.Position(RH.Point(second, 2, 9), 0), H.Receipt(27, f.query.artistId, 0, revoked)
        );
        Consent.Bundle memory old;
        old.artistId = f.query.artistId;
        old.collectionId = 7;
        old.bindingHash = f.query.bindingHash;
        old.policies = new DH.Policy[](1);
        old.policies[0] = DH.Policy(bytes32(uint256(11)), grant);
        old.economics = new Consent.Economics[](1);
        old.economics[0].item.recordHash = bytes32(uint256(12));
        old.economics[0].grant = grant;
        old.sales = new DH.Sale[](1);
        old.sales[0].item.recordHash = bytes32(uint256(13));
        old.sales[0].item.signer = terms.delegate;
        old.sales[0].item.authorityClass = 2;
        old.sales[0].item.nonce = 514;
        old.sales[0].grant = grant;
        f.consent.original = old;
        f.consent.consents = new ContentOwner.ConsentRecord[](1);
        f.consent.consents[0] = ContentOwner.ConsentRecord(
            bytes32(uint256(17)),
            f.query.artistId,
            1,
            Content.Consent(7, address(444), keccak256("content family"), keccak256("new state")),
            1
        );
        f.consent.royalties = new ContentH.Royalty[](1);
        f.consent.royalties[0] = ContentH.Royalty(
            T.RoyaltyFreeze(address(555), 7, keccak256("ROYALTY_ERC2981"), keccak256("assignment")),
            T.RoyaltyFreezeRecord(bytes32(uint256(20)), f.query.artistId, 1),
            grant
        );
        bytes32[] memory locks = new bytes32[](1);
        locks[0] = bytes32(uint256(1));
        f.consent.freezes = new Content.FreezeRecord[](1);
        f.consent.freezes[0] = Content.FreezeRecord(
            bytes32(uint256(21)),
            f.query.artistId,
            1,
            address(444),
            locks,
            keccak256("freeze state"),
            3
        );
        f.provenance.journals[6] = new RH.JournalEntry[](6);
        uint16[6] memory ops = [uint16(14), 15, 17, 16, 20, 21];
        uint256[6] memory hashes = [uint256(11), 12, 17, 13, 20, 21];
        for (uint256 i; i < 6; ++i) {
            f.provenance.journals[6][i] = RH.JournalEntry(
                RH.Position(
                    RH.Point(i < 3 ? first : second, 6, uint64(i < 3 ? 31 + i : i - 1)),
                    i < 3 ? i : i - 3
                ),
                H.Receipt(ops[i], f.query.artistId, 7, bytes32(hashes[i]))
            );
        }
        f.identity.signatures = new IH.SignatureRow[](4);
        f.identity.signatures[0] = IH.SignatureRow(bytes32(uint256(17)), "");
        f.identity.signatures[1] = IH.SignatureRow(bytes32(uint256(20)), hex"1234");
        f.identity.signatures[2] = IH.SignatureRow(bytes32(uint256(21)), "");
        _attestation(f, terms.delegate, grant);
    }

    function _attestation(Fixture memory f, address signer, bytes32 grant) private pure {
        RH.OriginEnvironment memory origin = f.provenance.origins[1];
        bytes32 second = f.provenance.eras[1].originHash;
        Hashes.Environment memory e =
            Hashes.Environment(origin.chainId, origin.registry, origin.core, origin.manager);
        f.attestations = new PubH.Row[](1);
        PubH.Row memory row;
        row.attestation.input.terms = T.Attestation(
            7,
            6,
            bytes32(uint256(3)),
            keccak256("subject"),
            keccak256("schema"),
            keccak256("statement"),
            "urn:test"
        );
        row.attestation.input.nonce = 257;
        row.attestation.statement = bytes("statement");
        row.attestation.authorityClass = 2;
        row.attestation.record.recordHash = Hashes.attestationRecordForAuthority(
            e, row.attestation.input.terms, f.query.artistId, signer, 2, 257, 1
        );
        row.attestation.record.signer = signer;
        row.attestation.record.signedAt = 1;
        row.attestation.record.generation = 1;
        row.attestation.record.subjectStateHash = row.attestation.input.terms.subjectStateHash;
        row.attestation.record.schemaId = row.attestation.input.terms.schemaId;
        row.attestation.record.statementHash = row.attestation.input.terms.statementHash;
        row.attestation.association.artistId = f.query.artistId;
        row.attestation.association.generation = 1;
        row.attestation.association.bindingHash = f.query.bindingHash;
        row.attestation.association.delegation = grant;
        f.attestations[0] = row;
        f.identity.signatures[3] = IH.SignatureRow(row.attestation.record.recordHash, hex"1234");
        f.provenance.journals[4] = new RH.JournalEntry[](1);
        f.provenance.journals[4][0] = RH.JournalEntry(
            RH.Position(RH.Point(second, 4, 2), 0),
            H.Receipt(24, f.query.artistId, 7, row.attestation.record.recordHash)
        );
        bytes32 digest =
            Hashes.attestationDigest(e, row.attestation.input.terms, T.Authorization(257, 1, ""));
        f.provenance.aliases[2] = new RH.ReplayAlias[](3);
        bytes32 lane = Delegation.lane(f.query.artistId, signer);
        _alias(
            f,
            0,
            keccak256("identity_authority.replay.delegated_nonce"),
            keccak256(abi.encode(lane, uint256(514))),
            keccak256("sale digest"),
            4
        );
        _alias(
            f,
            1,
            keccak256("identity_authority.replay.delegated_nonce"),
            keccak256(abi.encode(lane, uint256(257))),
            digest,
            5
        );
        _alias(
            f,
            2,
            keccak256("identity_authority.replay.authorization_consumed_digest"),
            keccak256(abi.encode(f.query.artistId, digest)),
            digest,
            5
        );
    }

    function _alias(
        Fixture memory f,
        uint256 index,
        bytes32 surface,
        bytes32 scope,
        bytes32 digest,
        uint64 revision
    ) private pure {
        bytes32 second = f.provenance.eras[1].originHash;
        f.provenance.aliases[2][index] = RH.ReplayAlias(
            second,
            2,
            surface,
            scope,
            keccak256(abi.encode(surface, scope)),
            T.ReplayCell(digest, revision, 1, 2),
            RH.Point(second, 2, revision)
        );
    }
}
