// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleAttestationFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleAttestationFacts.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistC2PATypes as C2PA
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRecordPublicationTypes as Publication
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamArtistDelegationState as Delegation
} from "../../../smart-contracts/domains/artist/StreamArtistDelegationState.sol";

/// @notice Actual aggregate/semantic/fact workers with canonical typed source evidence.
/// @dev No actual owner admission, source authenticity, Safe, op60 import or current standing
/// is inferred from these pure vectors. The full owner4 and Binding journals are shape-valid.
contract StreamArtistRecoveredMultipleAttestationFactsTest {
    bytes32 private constant CREDENTIALS = keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant DELEGATE = keccak256("identity_authority.replay.delegated_nonce");
    bytes32 private constant KEY = keccak256("identity_authority.replay.attestation_key");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");

    struct Fixture {
        IH.Bundle[] identities;
        M.State scope;
        Original.Bundle[] attestations;
        RH.Provenance p;
    }

    function check(Fixture memory f) external pure returns (uint256[][] memory uses) {
        (bytes[] memory ids, bytes[] memory rows) = _encoded(f);
        return Facts.validate(ids, f.scope, rows, f.p);
    }

    function checkRaw(
        bytes[] memory ids,
        M.State memory scope,
        bytes[] memory rows,
        RH.Provenance memory p
    ) external pure returns (uint256[][] memory) {
        return Facts.validate(ids, scope, rows, p);
    }

    function testInterleavedArtistsCollectionsAndGrantIncrements() external view {
        Fixture memory f = _fixture();
        uint256[][] memory uses = this.check(f);
        assert(uses.length == 2 && uses[0].length == 2 && uses[1].length == 0);
        assert(uses[0][0] == 2 && uses[0][1] == 0);
        // The saved grant includes consent uses. Only the owning composition concludes equality.
        assert(f.identities[0].delegations[0].record.uses == 9);
        f.identities[0].delegations[0].record.uses = 999;
        assert(this.check(f)[0][0] == 2);
        // Scope rows belong to other owner codecs, not this fact worker.
        f.scope.rows = new bytes[](1);
        f.scope.rows[0] = hex"cafe";
        assert(this.check(f)[0][0] == 2);
    }

    function testC2PAChainCannotResetAcrossCollectionsOrBorrowAnotherArtistHead() external view {
        Fixture memory good = _fixture();
        this.check(good);
        for (uint256 i; i < 2; ++i) {
            Fixture memory f = _copy(good);
            C2PA.Payload memory payload =
                abi.decode(f.attestations[0].records[0].attestation.statement, (C2PA.Payload));
            payload.previousRecordHash =
                i == 0 ? bytes32(0) : f.attestations[1].records[0].attestation.record.recordHash;
            f.attestations[0].records[0].attestation.statement = abi.encode(payload);
            _seal(f); // Update original record, query, signature and nonce joins to isolate chain failure.
            _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        }
        this.check(good);
    }

    function testCompleteGlobalOrderAndCollectionBijectionRejectOmissionDuplicateAndRegrouping()
        external
        view
    {
        Fixture memory good = _fixture();
        this.check(good);
        Fixture memory f = _copy(good);
        f.attestations[2].records[1] = f.attestations[2].records[0];
        f.scope.collections[2].records[1] = f.scope.collections[2].records[0];
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.attestations[2].records = new PubH.Row[](0);
        f.scope.collections[2].records = new bytes32[](0);
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        // Maintain original native indices/clocks while swapping full occurrences: collection
        // grouping would reset A's predecessor; actual journal order must reject the reversal.
        H.Receipt memory first = f.p.journals[4][0].receipt;
        f.p.journals[4][0].receipt = f.p.journals[4][2].receipt;
        f.p.journals[4][2].receipt = first;
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.p.journals[4][3].receipt.operation = 12;
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testGrantScopeCapabilityAdmissionRevocationAndReplacement() external view {
        Fixture memory good = _fixture();
        this.check(good);
        for (uint256 i; i < 5; ++i) {
            Fixture memory f = _copy(good);
            if (i == 0) f.identities[0].delegations[0].record.grant.collectionId = 2;
            if (i == 1) {
                f.identities[0].delegations[0].record.grant.capabilities = D.POLICY_CONSENT;
            }
            if (i == 2) f.identities[0].delegations[0].position.point.ownerRevision = 14;
            if (i == 3) {
                f.identities[0].delegations[0].record.revoked = true;
                f.identities[0].delegations[0].record.revocationRecordHash = bytes32(uint256(777));
                f.p.journals[2] = new RH.JournalEntry[](1);
                f.p.journals[2][0] = _entry(
                    f.p.eras[0].originHash,
                    2,
                    12,
                    0,
                    27,
                    bytes32(uint256(1)),
                    0,
                    bytes32(uint256(777))
                );
            }
            if (i == 4) {
                f.identities[0].delegations[1].record.grant.delegate = address(700);
                f.identities[0].delegations[1].position.point.ownerRevision = 14;
            }
            _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        }
        // Signed time and current epoch are not original admission time or current authority.
        good.identities[0].delegations[0].record.grant.notBefore = 9000;
        good.identities[0].heads.delegationEpoch = 100;
        assert(this.check(good)[0][0] == 2);
    }

    function testRetainedSignaturesNonceObservationAndOriginAreRequired() external view {
        Fixture memory good = _fixture();
        this.check(good);
        for (uint256 i; i < 5; ++i) {
            Fixture memory f = _copy(good);
            if (i == 0) f.identities[0].signatures = new IH.SignatureRow[](0);
            if (i == 1) f.identities[0].signatures[0].signature = new bytes(4097);
            if (i == 2) f.p.aliases[2][0].cell.commitment = bytes32(uint256(9));
            if (i == 3) f.p.aliases[2] = new RH.ReplayAlias[](0);
            if (i == 4) ++f.attestations[0].records[1].attestation.input.nonce;
            _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        }
    }

    function testCanonicalEnvelopesWrongArrayOrderAndUnrecognizedScopeRefuse() external view {
        Fixture memory good = _fixture();
        (bytes[] memory ids, bytes[] memory rows) = _encoded(good);
        ids[0] = bytes.concat(ids[0], bytes32(0));
        _rejectRaw(ids, good.scope, rows, good.p);
        (ids, rows) = _encoded(good);
        rows[1] = bytes.concat(rows[1], bytes32(0));
        _rejectRaw(ids, good.scope, rows, good.p);
        (ids, rows) = _encoded(good);
        bytes memory first = ids[0];
        ids[0] = ids[1];
        ids[1] = first;
        _rejectRaw(ids, good.scope, rows, good.p);
        Fixture memory f = _copy(good);
        f.scope.collections[0].bindingHash = bytes32(uint256(99));
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.scope.collections[1].artistId = bytes32(uint256(99));
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.scope.collections[2].collectionId = 1;
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        this.check(good);
    }

    function testOwnerCounterReplayAndQueryRecordInventoryRemainComplete() external view {
        Fixture memory good = _fixture();
        this.check(good);
        Fixture memory f = _copy(good);
        ++f.p.eras[0].checkpoints[4].ownerState.revision;
        _commitments(f);
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.p.eras[0].checkpoints[4].replayRoot = bytes32(uint256(8));
        _commitments(f);
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.scope.collections[0].records[0] = bytes32(uint256(77));
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.p.journals[0][0].receipt.operation = 3;
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.p.journals[4][1].position.point.ownerRevision = 7;
        _commitments(f);
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testSemanticAssociationAndPublicationCannotHideBehindValidNativeHash() external view {
        Fixture memory good = _fixture();
        this.check(good);
        Fixture memory f = _copy(good);
        f.attestations[0].records[1].attestation.association.fact.owner = address(0);
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.attestations[0].records[1].attestation.association.bindingHash = bytes32(uint256(77));
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.attestations[0].records[1].publication.metadataHostCodeHash = bytes32(uint256(77));
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f = _copy(good);
        f.attestations[1].personhood = new Original.PersonhoodRow[](1);
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testPersonhoodSummaryUsesOriginalRegistryAndRemainsSeparateFromCredentials()
        external
        view
    {
        Fixture memory f = _fixture();
        PubH.Row memory row = f.attestations[0].records[2];
        row.attestation.input.terms.subjectKind = 10;
        row.attestation.input.terms.subjectId = f.scope.collections[0].artistId;
        row.attestation.input.terms.schemaId = keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1");
        row.attestation.association.artistId = 0;
        // Original class3 legacy personhood permits only a completely empty association.
        delete row.attestation.association;
        row.attestation.statement = bytes("original personhood waiver");
        _seal(f);
        f.attestations[0].personhood = new Original.PersonhoodRow[](1);
        f.attestations[0].personhood[0].recordHash =
        f.attestations[0].records[2].attestation.record.recordHash;
        f.attestations[0].personhood[0].originalRegistry = f.p.origins[0].registry;
        assert(this.check(f)[0][0] == 2);
        f.attestations[0].personhood[0].originalRegistry = address(888);
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
        f.attestations[0].personhood[0].originalRegistry = f.p.origins[0].registry;
        this.check(f);
    }

    function testEmptyCollectionAndZeroAttestationAggregateDoNotInventGrantEquality()
        external
        view
    {
        Fixture memory f = _fixture();
        for (uint256 k; k < 3; ++k) {
            f.attestations[k].records = new PubH.Row[](0);
            f.scope.collections[k].records = new bytes32[](0);
        }
        f.p.journals[4] = new RH.JournalEntry[](0);
        f.p.eras[0].nativeCounts[4] = 0;
        f.p.eras[0].checkpoints[4].ownerState.revision = 6;
        _commitments(f);
        uint256[][] memory uses = this.check(f);
        assert(uses.length == 2 && uses[0][0] == 0 && uses[0][1] == 0);
    }

    function testRepeatedEraPreservesOriginalDomainsAndGlobalCredentialChain() external view {
        Fixture memory f = _fixture();
        RH.OriginEnvironment[] memory origins = new RH.OriginEnvironment[](2);
        RH.Era[] memory eras = new RH.Era[](2);
        origins[0] = f.p.origins[0];
        origins[1] = abi.decode(abi.encode(origins[0]), (RH.OriginEnvironment));
        origins[1].registry = address(110);
        origins[1].coordinator = address(111);
        for (uint8 j; j < 7; ++j) {
            origins[1].owners[j] = address(uint160(300 + j));
        }
        eras[0] = f.p.eras[0];
        eras[1] = abi.decode(abi.encode(eras[0]), (RH.Era));
        eras[1].originHash = RH.originHash(origins[1]);
        eras[1].priorImportCommitment = bytes32(uint256(123));
        for (uint8 j; j < 7; ++j) {
            eras[1].lowerRevisions[j] = 1;
            eras[1].nativeCounts[j] = 0;
        }
        eras[0].nativeCounts[4] = 2;
        eras[0].checkpoints[4].ownerState.revision = 8;
        eras[1].nativeCounts[4] = 4;
        eras[1].checkpoints[4].ownerState.revision = 5;
        eras[1].checkpoints[0].ownerState.revision = 1;
        f.p.origins = origins;
        f.p.eras = eras;
        _seal(f);
        assert(this.check(f)[0][0] == 2);
        // Preserve canonical row/hash/nonce facts under the later original Registry while
        // replacing only the cross-era predecessor. A local-era reset must still refuse.
        C2PA.Payload memory payload =
            abi.decode(f.attestations[0].records[0].attestation.statement, (C2PA.Payload));
        payload.previousRecordHash = 0;
        f.attestations[0].records[0].attestation.statement = abi.encode(payload);
        _seal(f);
        _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testOriginalPublicationIntentAndStatementCapabilitiesAcrossCollections()
        external
        view
    {
        for (uint256 kind = 7; kind <= 8; ++kind) {
            Fixture memory f = _fixture();
            PubH.Row memory row = f.attestations[0].records[1];
            Publication.Publication memory publication = Publication.Publication(
                address(500),
                address(700),
                1,
                bytes32(uint256(1)),
                keccak256(kind == 7 ? bytes("ARTIST_INTENT") : bytes("WORK_DESCRIPTION")),
                keccak256(
                    kind == 7
                        ? bytes("STREAM_ARTIST_INTENT_V1")
                        : bytes("STREAM_WORK_DESCRIPTION_V1")
                ),
                keccak256("RAW_BYTES"),
                1,
                bytes32(uint256(88)),
                keccak256(bytes("urn:original")),
                10,
                bytes32(uint256(99))
            );
            row.attestation.input.terms.subjectKind = uint8(kind);
            row.attestation.input.terms.schemaId =
                keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1");
            row.attestation.input.terms.subjectStateHash =
                kind == 7 ? publication.candidateRecordHash : bytes32(0);
            row.attestation.association.fact.stateHash =
            row.attestation.input.terms.subjectStateHash;
            row.attestation.statement = abi.encode(uint16(1), publication);
            f.identities[0].delegations[0].record.grant.capabilities = D.ATTEST | D.INTENT;
            _seal(f);
            row.publication.publication = publication;
            row.publication.metadataHostCodeHash = bytes32(uint256(501));
            row.publication.evidence = Publication.Evidence(
                row.attestation.record.recordHash,
                bytes32(uint256(1)),
                f.scope.collections[0].bindingHash,
                1,
                address(700),
                2,
                kind == 7 ? D.INTENT : D.ATTEST,
                50,
                keccak256(abi.encode(publication))
            );
            assert(this.check(f)[0][0] == 2);
            row.publication.evidence.publicationHash = bytes32(uint256(77));
            _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
            row.publication.evidence.publicationHash = keccak256(abi.encode(publication));
            this.check(f);
            if (kind == 7) {
                f.identities[0].delegations[0].record.grant.capabilities = D.ATTEST;
                _reject(f, RH.InvalidRecoveredHydrationProfile.selector);
            }
        }
    }

    function testFuzzCanonicalOriginalStatementAndGrantUses(uint128 nonce, bytes32 contents)
        external
        view
    {
        Fixture memory f = _fixture();
        f.attestations[0].records[2].attestation.input.nonce = uint256(nonce) + 100;
        f.attestations[0].records[2].attestation.statement = abi.encode(contents);
        _seal(f);
        uint256[][] memory uses = this.check(f);
        assert(uses[0][0] == 2 && uses[0][1] == 0);
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.scope.artists = new AH.Query[](2);
        f.scope.collections = new AH.Query[](3);
        f.identities = new IH.Bundle[](2);
        f.attestations = new Original.Bundle[](3);
        for (uint256 a; a < 2; ++a) {
            f.scope.artists[a].artistId = bytes32(a + 1);
            f.identities[a].artistId = bytes32(a + 1);
        }
        f.p.origins = new RH.OriginEnvironment[](1);
        f.p.eras = new RH.Era[](1);
        RH.OriginEnvironment memory o;
        o.chainId = 1;
        o.registry = address(100);
        o.coordinator = address(101);
        o.archive = address(102);
        o.core = address(103);
        o.manager = address(104);
        o.suiteConfigurationHash = bytes32(uint256(105));
        for (uint8 j; j < 7; ++j) {
            o.owners[j] = address(uint160(200 + j));
            o.ownerCodeHashes[j] = keccak256(abi.encode("owner", j));
            f.p.eras[0].checkpoints[j].schema = RH.CHECKPOINT;
            f.p.eras[0].checkpoints[j].ownerState.domainId = RH.ownerDomain(j);
            f.p.eras[0].checkpoints[j].ownerState.stateRoot = bytes32(uint256(1000 + j));
            f.p.eras[0].checkpoints[j].ownerState.recordChainTip = bytes32(uint256(2000 + j));
            f.p.eras[0].checkpoints[j].ownerState.revision = 100;
        }
        f.p.origins[0] = o;
        f.p.eras[0].originHash = RH.originHash(o);
        f.p.eras[0].nativeCounts[0] = 3;
        f.p.eras[0].nativeCounts[4] = 6;
        f.p.eras[0].checkpoints[0].ownerState.revision = 6;
        f.p.eras[0].checkpoints[4].ownerState.revision = 12;
        f.p.journals[0] = new RH.JournalEntry[](3);
        f.p.journals[4] = new RH.JournalEntry[](6);
        for (uint256 k; k < 3; ++k) {
            bytes32 artist = bytes32(uint256(k == 1 ? 2 : 1));
            f.scope.collections[k].artistId = artist;
            f.scope.collections[k].collectionId = k + 1;
            f.scope.collections[k].bindingHash = keccak256(abi.encode("binding", k));
            Original.Bundle memory b;
            b.artistId = artist;
            b.collectionId = k + 1;
            b.bindingHash = f.scope.collections[k].bindingHash;
            b.item.state = 2;
            b.item.generation = 1;
            b.records = new PubH.Row[](k == 0 ? 3 : k == 1 ? 1 : 2);
            f.attestations[k] = b;
            f.p.journals[0][k] =
                _entry(
                f.p.eras[0].originHash, 0, uint64(2 * k + 2), k, 1, artist, k + 1, b.bindingHash
            );
        }
        f.identities[0].delegations = new IH.DelegationRow[](2);
        for (uint256 g; g < 2; ++g) {
            IH.DelegationRow memory d;
            d.recordHash = keccak256(abi.encode("retained grant", g));
            d.position = RH.Position(RH.Point(f.p.eras[0].originHash, 2, uint64(g + 1)), g);
            d.record.grant = D.Grant(
                bytes32(uint256(1)),
                address(uint160(700 + g)),
                0,
                D.ATTEST | D.POLICY_CONSENT,
                1,
                20,
                100,
                bytes32(uint256(1))
            );
            d.record.uses = 9;
            d.record.grantor = address(702);
            d.record.nonce = g;
            f.identities[0].delegations[g] = d;
        }
        for (uint256 n; n < 6; ++n) {
            (uint256 k, uint256 r) = _coordinate(n);
            PubH.Row memory row = f.attestations[k].records[r];
            row.attestation.input.terms.collectionId = k + 1;
            row.attestation.input.terms.subjectKind = n < 3 ? 10 : 1;
            row.attestation.input.terms.subjectId = f.scope.collections[k].artistId;
            row.attestation.input.terms.subjectStateHash = bytes32(uint256(800 + n));
            row.attestation.input.terms.schemaId = n < 3 ? CREDENTIALS : bytes32(uint256(900));
            row.attestation.input.terms.statementURI = "urn:original";
            row.attestation.input.nonce = n + 1;
            row.attestation.record.generation = 1;
            row.attestation.record.signedAt = 50;
            row.attestation.record.signer =
                n == 3 || n == 4 ? address(700) : address(uint160(800 + n));
            row.attestation.authorityClass = n == 3 || n == 4 ? 2 : n == 5 ? 3 : 1;
            if (n >= 3) {
                row.attestation.association.artistId = f.scope.collections[k].artistId;
                row.attestation.association.bindingHash = f.scope.collections[k].bindingHash;
                row.attestation.association.generation = 1;
                row.attestation.association.delegation =
                    n == 5 ? bytes32(0) : f.identities[0].delegations[0].recordHash;
                row.attestation.association.fact.owner = address(500);
                row.attestation.association.fact.ownerCodeHash = bytes32(uint256(501));
                row.attestation.association.fact.subjectId = row.attestation.input.terms.subjectId;
                row.attestation.association.fact.stateHash =
                row.attestation.input.terms.subjectStateHash;
            }
            row.attestation.statement = n < 3
                ? abi.encode(
                    C2PA.Payload(
                        1,
                        f.scope.collections[k].artistId,
                        row.attestation.input.terms.subjectStateHash,
                        bytes32(0),
                        new C2PA.Credential[](0)
                    )
                )
                : abi.encode("original", n);
        }
        _seal(f);
        // A's second credential crosses from collection3 to collection1, across B's record.
        C2PA.Payload memory next =
            abi.decode(f.attestations[0].records[0].attestation.statement, (C2PA.Payload));
        next.previousRecordHash = f.attestations[2].records[0].attestation.record.recordHash;
        f.attestations[0].records[0].attestation.statement = abi.encode(next);
        _seal(f);
    }

    function _coordinate(uint256 n) private pure returns (uint256 k, uint256 r) {
        if (n == 0) return (2, 0);
        if (n == 1) return (1, 0);
        if (n == 2) return (0, 0);
        if (n == 3) return (2, 1);
        if (n == 4) return (0, 1);
        return (0, 2);
    }

    function _seal(Fixture memory f) private pure {
        f.identities[0].signatures = new IH.SignatureRow[](5);
        f.identities[1].signatures = new IH.SignatureRow[](1);
        f.p.aliases[2] = new RH.ReplayAlias[](16);
        for (uint256 k; k < 3; ++k) {
            f.scope.collections[k].records = new bytes32[](f.attestations[k].records.length);
        }
        uint256 ai;
        uint256 aliasIndex;
        for (uint256 n; n < 6; ++n) {
            (uint256 k, uint256 r) = _coordinate(n);
            PubH.Row memory row = f.attestations[k].records[r];
            T.Attestation memory t = row.attestation.input.terms;
            uint256 era = f.p.eras.length == 2 && n >= 2 ? 1 : 0;
            RH.OriginEnvironment memory o = f.p.origins[era];
            t.statementHash = keccak256(row.attestation.statement);
            row.attestation.record.statementHash = t.statementHash;
            row.attestation.record.subjectStateHash = t.subjectStateHash;
            row.attestation.record.schemaId = t.schemaId;
            // Literal original 16-word preimage, separate from the production Hashes helper.
            bytes32[16] memory w;
            w[0] = keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1");
            w[1] = bytes32(o.chainId);
            w[2] = bytes32(uint256(uint160(o.registry)));
            w[3] = bytes32(uint256(uint160(o.core)));
            w[4] = bytes32(t.collectionId);
            w[5] = bytes32(uint256(t.subjectKind));
            w[6] = t.subjectId;
            w[7] = t.subjectStateHash;
            w[8] = t.schemaId;
            w[9] = t.statementHash;
            w[10] = keccak256(bytes(t.statementURI));
            w[11] = f.scope.collections[k].artistId;
            w[12] = bytes32(uint256(uint160(row.attestation.record.signer)));
            w[13] = bytes32(uint256(row.attestation.authorityClass));
            w[14] = bytes32(row.attestation.input.nonce);
            w[15] = bytes32(uint256(row.attestation.record.signedAt));
            bytes32 record = keccak256(abi.encode(w));
            row.attestation.record.recordHash = record;
            f.scope.collections[k].records[r] = record;
            f.p.journals[4][n] = _entry(
                f.p.eras[era].originHash,
                4,
                uint64(era == 0 ? 7 + n : n),
                era == 0 ? n : n - 2,
                24,
                f.scope.collections[k].artistId,
                k + 1,
                record
            );
            IH.SignatureRow memory sig =
                IH.SignatureRow(record, n == 0 ? bytes("") : bytes(hex"1234"));
            if (k == 1) f.identities[1].signatures[0] = sig;
            else f.identities[0].signatures[ai++] = sig;
            bytes32 digest = Hashes.attestationDigest(
                Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                t,
                T.Authorization(row.attestation.input.nonce, row.attestation.record.signedAt, "")
            );
            RH.Point memory point = RH.Point(f.p.eras[era].originHash, 2, uint64(10 + n));
            bool delegated = row.attestation.authorityClass == 2;
            bytes32 scope = delegated
                ? keccak256(
                    abi.encode(
                        Delegation.lane(
                            f.scope.collections[k].artistId, row.attestation.record.signer
                        ),
                        row.attestation.input.nonce
                    )
                )
                : keccak256(
                    abi.encode(f.scope.collections[k].artistId, row.attestation.input.nonce)
                );
            f.p.aliases[2][aliasIndex++] = _alias(
                delegated ? DELEGATE : NONCE, scope, digest, point
            );
            if (!delegated) {
                f.p.aliases[2][aliasIndex++] =
                    _alias(KEY, keccak256(abi.encode(record)), record, point);
            }
            f.p.aliases[2][aliasIndex++] = _alias(
                OBSERVED,
                keccak256(abi.encode(f.scope.collections[k].artistId, digest)),
                digest,
                point
            );
        }
        assert(aliasIndex == 16);
        _commitments(f);
    }

    function _commitments(Fixture memory f) private pure {
        bytes32 h = RH.ownerProvenanceHash(RH.ownerProvenance(f.p, 4), 4);
        for (uint256 k; k < f.attestations.length; ++k) {
            f.attestations[k].provenance = h;
        }
    }

    function _entry(
        bytes32 env,
        uint8 owner,
        uint64 rev,
        uint256 index,
        uint16 op,
        bytes32 artist,
        uint256 cid,
        bytes32 record
    ) private pure returns (RH.JournalEntry memory) {
        return RH.JournalEntry(
            RH.Position(RH.Point(env, owner, rev), index), H.Receipt(op, artist, cid, record)
        );
    }

    function _alias(bytes32 surface, bytes32 scope, bytes32 commitment, RH.Point memory point)
        private
        pure
        returns (RH.ReplayAlias memory a)
    {
        a.originHash = point.environmentHash;
        a.ownerIndex = 2;
        a.surface = surface;
        a.scope = scope;
        a.cell = T.ReplayCell(commitment, point.ownerRevision, 1, 2);
        a.admittedAt = point;
    }

    function _encoded(Fixture memory f)
        private
        pure
        returns (bytes[] memory ids, bytes[] memory rows)
    {
        ids = new bytes[](f.identities.length);
        rows = new bytes[](f.attestations.length);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = abi.encode(f.identities[i]);
        }
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = abi.encode(f.attestations[i]);
        }
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function _reject(Fixture memory f, bytes4 selector) private view {
        (bool ok, bytes memory why) = address(this).staticcall(abi.encodeCall(this.check, (f)));
        assert(!ok && keccak256(why) == keccak256(abi.encodeWithSelector(selector)));
    }

    function _rejectRaw(
        bytes[] memory ids,
        M.State memory scope,
        bytes[] memory rows,
        RH.Provenance memory p
    ) private view {
        (bool ok, bytes memory why) = address(this)
            .staticcall(abi.encodeCall(this.checkRaw, (ids, scope, rows, p)));
        assert(
            !ok
                && keccak256(why)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    )
        );
    }
}
