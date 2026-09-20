// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAttestationFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationFacts.sol";
import {
    StreamArtistRecoveredDelegationConsentFacts as Combined
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegationConsentFacts.sol";
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
    StreamArtistPublicationHydrationTypes as PubH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
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
    StreamArtistAttestationTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistDelegationState as Delegation
} from "../../../smart-contracts/domains/artist/StreamArtistDelegationState.sol";

/// @notice Pure component vectors for the cross-owner op24 join, not source certificates or
/// actual Artist/Safe admission. The outer codecs separately authenticate source maps, original
/// grant hashes/epochs, complete nonce words, and publication/personhood semantics.
contract StreamArtistRecoveredAttestationFactsTest {
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant DELEGATE = keccak256("identity_authority.replay.delegated_nonce");
    bytes32 private constant KEY = keccak256("identity_authority.replay.attestation_key");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");

    struct Fixture {
        IH.Bundle identity;
        PubH.Row[] rows;
        AH.Query query;
        RH.Provenance provenance;
    }

    function check(Fixture memory f) external pure returns (uint256[] memory) {
        return Facts.validate(f.identity, f.rows, f.query, f.provenance);
    }

    function checkCombined(Fixture memory f, Consent.Bundle memory consent, uint8 mode, bool added)
        external
        pure
    {
        if (added) Combined.validate(f.identity, consent, f.query, f.provenance, mode, f.rows);
        else Combined.validate(f.identity, consent, f.query, f.provenance, mode);
    }

    function testAttestationFactsPreserveOriginalClassesBackdatedTimeAndSeparateClocks()
        external
        pure
    {
        Fixture memory f = _fixture();
        uint256[] memory uses = Facts.validate(f.identity, f.rows, f.query, f.provenance);
        assert(uses.length == 2 && uses[0] == 1 && uses[1] == 0);
        assert(
            f.rows[1].attestation.record.signedAt < f.identity.delegations[0].record.grant.notBefore
        );
        assert(f.identity.delegations[0].record.revoked);
        assert(f.identity.delegations[0].epoch < f.identity.heads.delegationEpoch);
        assert(f.identity.identity.authorityClass == 3);
        assert(
            f.provenance.journals[4][0].position.point.ownerRevision
                > f.provenance.journals[4][1].position.point.ownerRevision
        );
        assert(f.identity.signatures[0].signature.length == 0);
    }

    function testAttestationFactsRequireCompleteOrderedOriginal24Inventory() external view {
        Fixture memory original = _fixture();
        this.check(original);
        for (uint256 i; i < 5; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.rows = new PubH.Row[](0);
            if (i == 1) {
                PubH.Row memory old = f.rows[0];
                f.rows[0] = f.rows[1];
                f.rows[1] = old;
            }
            if (i == 2) f.provenance.journals[4][1].receipt.operation = 14;
            if (i == 3) f.provenance.journals[4][1].receipt.artistId = bytes32(uint256(99));
            if (i == 4) ++f.provenance.journals[4][1].receipt.collectionId;
            _reject(f);
        }
    }

    function testAttestationFactsBindEveryAvailableOriginalHashField() external view {
        Fixture memory original = _fixture();
        this.check(original);
        for (uint256 i; i < 7; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) ++f.rows[1].attestation.input.nonce;
            if (i == 1) ++f.rows[1].attestation.record.signedAt;
            if (i == 2) f.rows[1].attestation.record.signer = address(999);
            if (i == 3) f.rows[1].attestation.input.terms.statementURI = "urn:changed";
            if (i == 4) f.rows[1].attestation.record.subjectStateHash = bytes32(uint256(99));
            if (i == 5) f.rows[1].attestation.statement = bytes("other bytes");
            if (i == 6) {
                f.provenance.journals[4][1].position.point.environmentHash =
                f.provenance.eras[0].originHash;
            }
            _reject(f);
        }
    }

    function testAttestationFactsRejectUnsupportedClassesAndGrantClassSubstitution() external view {
        Fixture memory original = _fixture();
        this.check(original);
        for (uint256 i; i < 5; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.rows[0].attestation.authorityClass = 4;
            if (i == 1) f.rows[1].attestation.association.delegation = 0;
            if (i == 2) {
                f.rows[0].attestation.association.delegation = f.identity.delegations[0].recordHash;
            }
            if (i == 3) f.rows[1].attestation.association.artistId = bytes32(uint256(99));
            if (i == 4) f.rows[1].attestation.association.bindingHash = bytes32(uint256(99));
            _reject(f);
        }
    }

    function testAttestationFactsRequireCopiedSignatureKeysButNeverReauthorizeBytes()
        external
        view
    {
        Fixture memory f = _fixture();
        this.check(f);
        // Exact bytes are authenticated by the fixed source reader, not reverified here.
        f.identity.signatures[1].signature = "";
        this.check(f);
        f.identity.signatures[1].recordHash = bytes32(uint256(99));
        _reject(f);
        f = _fixture();
        f.identity.signatures[1].signature = new bytes(4097);
        _reject(f);
        f = _fixture();
        f.identity.signatures[2].recordHash = f.identity.signatures[1].recordHash;
        _reject(f);
    }

    function testAttestationFactsRejectWrongReplayKindStatusDigestAndOriginalPoint() external view {
        Fixture memory original = _fixture();
        this.check(original);
        for (uint256 i; i < 6; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.provenance.aliases[2][3].cell.kind = 2;
            if (i == 1) f.provenance.aliases[2][3].cell.status = 1;
            if (i == 2) f.provenance.aliases[2][3].cell.commitment = bytes32(uint256(99));
            if (i == 3) {
                f.provenance.aliases[2][3].admittedAt.environmentHash =
                f.provenance.eras[0].originHash;
            }
            if (i == 4) f.provenance.aliases[2][3].admittedAt.ownerIndex = 4;
            if (i == 5) ++f.provenance.aliases[2][3].cell.touchedRevision;
            _reject(f);
        }
    }

    function testAttestationFactsSeparatePrincipalAndDelegateLanesAndDirectAttestationKey()
        external
        view
    {
        Fixture memory original = _fixture();
        this.check(original);
        for (uint256 i; i < 5; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.provenance.aliases[2][0].surface = DELEGATE;
            if (i == 1) f.provenance.aliases[2][3].surface = NONCE;
            if (i == 2) f.provenance.aliases[2][1].scope = f.rows[0].attestation.record.recordHash;
            if (i == 3) f.provenance.aliases[2][1].cell.commitment = bytes32(uint256(99));
            if (i == 4) {
                ++f.provenance.aliases[2][1].admittedAt.ownerRevision;
                ++f.provenance.aliases[2][1].cell.touchedRevision;
            }
            _reject(f);
        }
    }

    function testAttestationFactsPermitIdenticalRekeyedAliasesAndRejectConflictingPoints()
        external
        view
    {
        Fixture memory f = _fixture();
        this.check(f);
        RH.ReplayAlias memory old =
            abi.decode(abi.encode(f.provenance.aliases[2][0]), (RH.ReplayAlias));
        old.originHash = f.provenance.eras[1].originHash;
        old.originalKey = bytes32(uint256(991));
        _appendAlias(f, old);
        this.check(f);
        ++f.provenance.aliases[2][8].admittedAt.ownerRevision;
        ++f.provenance.aliases[2][8].cell.touchedRevision;
        _reject(f);
    }

    function testAttestationFactsSharedDigestKeepsItsEarlierOriginalObservation() external view {
        Fixture memory f = _fixture();
        this.check(f);
        _sharedDigest(f);
        uint256[] memory uses = this.check(f);
        assert(uses[0] == 1 && uses[1] == 1 && uses[2] == 0);
        assert(_digest(f, 1) == _digest(f, 3));
        assert(f.rows[1].attestation.record.recordHash != f.rows[3].attestation.record.recordHash);
        assert(f.provenance.aliases[2][4].admittedAt.ownerRevision == 5);
        assert(f.provenance.aliases[2][8].admittedAt.ownerRevision == 6);
        f.provenance.aliases[2][4].admittedAt.ownerRevision = 7;
        f.provenance.aliases[2][4].cell.touchedRevision = 7;
        _reject(f);
    }

    function testAttestationFactsRequireGrantScopeSignerAndExactIntentCapability() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.identity.delegations[0].record.grant.collectionId = 999;
        _reject(f);
        f.identity.delegations[0].record.grant.collectionId = 0;
        this.check(f);
        f.identity.delegations[0].record.grant.delegate = address(999);
        _reject(f);
        f = _fixture();
        f.identity.delegations[0].record.grant.capabilities = D.INTENT;
        _reject(f); // Subject10 needs ATTEST, not INTENT.
        f.rows[1].attestation.input.terms.subjectKind = 7;
        _seal(f);
        this.check(f); // Publication semantics are the separately tested owner4 codec boundary.
        f.identity.delegations[0].record.grant.capabilities = D.ATTEST;
        _reject(f);
    }

    function testAttestationFactsRejectAdmissionBeforeGrantOrAfterRevocationAndReplacement()
        external
        view
    {
        Fixture memory original = _fixture();
        this.check(original);
        for (uint256 i; i < 4; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) {
                f.identity.delegations[0].position.point =
                    RH.Point(f.provenance.eras[1].originHash, 2, 5);
            }
            if (i == 1) f.provenance.journals[2][1].position.point.ownerRevision = 5;
            if (i == 2) f.identity.delegations[1].position.point.ownerRevision = 4;
            if (i == 3) f.provenance.journals[2][1].receipt.operation = 26;
            _reject(f);
        }
    }

    function testAttestationFactsMixedConsentAndAttestationUsesCountBeforeFinalEquality()
        external
        view
    {
        Fixture memory f = _fixture();
        this.check(f);
        Consent.Bundle memory c = _consent(f);
        f.identity.delegations[0].record.uses = 2;
        this.checkCombined(f, c, 2, true);
        _combinedReject(f, c, 2, false); // Old path intentionally sees only original14.
        f.identity.delegations[0].record.uses = 1;
        _combinedReject(f, c, 2, true);
        f.identity.delegations[0].record.uses = 3;
        _combinedReject(f, c, 2, true);
    }

    function testAttestationFactsDelegated24WorksInBothBindingModes() external view {
        Fixture memory f = _fixture();
        Consent.Bundle memory c;
        c.artistId = f.query.artistId;
        c.collectionId = f.query.collectionId;
        c.bindingHash = f.query.bindingHash;
        this.checkCombined(f, c, 1, true);
        this.checkCombined(f, c, 2, true);
        _combinedReject(f, c, 0, true);
    }

    function testAttestationFactsOldConsentEntryPointRetainsNoAttestationBehavior() external view {
        Fixture memory f = _fixture();
        Consent.Bundle memory c = _consent(f);
        this.checkCombined(f, c, 2, false);
        // Its original behavior does not inspect owner4 rows or signature witnesses.
        f.rows = new PubH.Row[](0);
        f.identity.signatures = new IH.SignatureRow[](0);
        this.checkCombined(f, c, 2, false);
        _combinedReject(f, c, 2, true);
    }

    function checkGeneration(Fixture memory f, uint64 generation)
        external
        pure
        returns (uint256[] memory)
    {
        return Facts.validateGeneration(f.identity, f.rows, f.query, f.provenance, generation);
    }

    function testFuzzGenerationAttestationFactsDirectClassesAndOriginalClocks(uint64 seed)
        external
        view
    {
        uint64 generation = uint64(2 + seed % 127);
        Fixture memory f = _generationFixture(generation);
        uint256[] memory uses = this.checkGeneration(f, generation);
        assert(
            uses.length == 0 && f.rows[0].attestation.authorityClass == 1
                && f.rows[1].attestation.authorityClass == 3
        );
        assert(
            f.provenance.journals[4][0].position.point.environmentHash
                != f.provenance.journals[4][1].position.point.environmentHash
        );
        // The original entry continues to mean generation one, even with otherwise exact rows.
        _reject(f);
    }

    function testGenerationAttestationFactsRejectWrongGenerationAndOutOfRange() external view {
        Fixture memory f = _generationFixture(3);
        this.checkGeneration(f, 3);
        _rejectGeneration(f, 0);
        _rejectGeneration(f, 1);
        _rejectGeneration(f, 2);
        _rejectGeneration(f, 129);
        f.rows[1].attestation.record.generation = 2;
        _rejectGeneration(f, 3);
        f.rows[1].attestation.record.generation = 3;
        this.checkGeneration(f, 3);
    }

    function testGenerationAttestationFactsRetainNonceSignatureAndOriginalDomainChecks()
        external
        view
    {
        Fixture memory original = _generationFixture(2);
        this.checkGeneration(original, 2);
        Fixture memory f = _copy(original);
        ++f.rows[0].attestation.input.nonce;
        _rejectGeneration(f, 2);
        f = _copy(original);
        f.identity.signatures = new IH.SignatureRow[](0);
        _rejectGeneration(f, 2);
        f = _copy(original);
        f.provenance.journals[4][0].position.point.environmentHash = f.provenance.eras[1].originHash;
        _rejectGeneration(f, 2);
        f = _copy(original);
        f.provenance.aliases[2] = new RH.ReplayAlias[](0);
        _rejectGeneration(f, 2);
    }

    function testGenerationAttestationFactsDoesNotAdmitExistingDelegatedProfileByRelabeling()
        external
        view
    {
        Fixture memory f = _fixture();
        this.check(f);
        for (uint256 i; i < f.rows.length; ++i) {
            f.rows[i].attestation.record.generation = 2;
            if (f.rows[i].attestation.association.artistId != 0) {
                f.rows[i].attestation.association.generation = 2;
            }
        }
        _rejectGeneration(f, 2);
    }

    /// @dev Two exact pre-existing direct records from separate original eras. This is a pure
    /// row-join vector, not a complete source certificate; actual-owner tests cover that join.
    function _generationFixture(uint64 generation) private pure returns (Fixture memory f) {
        f = _fixture();
        PubH.Row[] memory rows = new PubH.Row[](2);
        RH.JournalEntry[] memory entries = new RH.JournalEntry[](2);
        rows[0] = f.rows[0];
        rows[1] = f.rows[2];
        entries[0] = f.provenance.journals[4][0];
        entries[1] = f.provenance.journals[4][2];
        f.rows = rows;
        f.provenance.journals[4] = entries;
        f.identity.delegations = new IH.DelegationRow[](0);
        f.rows[0].attestation.record.generation = generation;
        f.rows[1].attestation.record.generation = generation;
    }

    function _rejectGeneration(Fixture memory f, uint64 generation) private view {
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.checkGeneration, (f, generation)));
        assert(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    )
        );
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.query.artistId = keccak256("component artist");
        f.query.collectionId = 7;
        f.query.bindingHash = keccak256("original binding");
        f.identity.artistId = f.query.artistId;
        f.identity.identity.authorityClass = 3;
        f.identity.identity.authorityAddress = address(9999);
        f.identity.heads.delegationEpoch = 3;
        f.provenance.origins = new RH.OriginEnvironment[](2);
        f.provenance.eras = new RH.Era[](2);
        for (uint256 i; i < 2; ++i) {
            RH.OriginEnvironment memory o;
            o.chainId = 1;
            o.registry = address(uint160(100 + i));
            o.core = address(400);
            o.manager = address(401);
            for (uint8 j; j < 7; ++j) {
                o.owners[j] = address(uint160(500 + i * 10 + j));
                o.ownerCodeHashes[j] = keccak256(abi.encode("synthetic owner", i, j));
                f.provenance.eras[i].checkpoints[j].schema = RH.CHECKPOINT;
                f.provenance.eras[i].checkpoints[j].ownerState.domainId = RH.ownerDomain(j);
                f.provenance.eras[i].checkpoints[j].ownerState.revision = i == 0 ? 100 : 12;
            }
            f.provenance.origins[i] = o;
            f.provenance.eras[i].originHash = RH.originHash(o);
        }
        f.identity.delegations = new IH.DelegationRow[](2);
        f.identity.delegations[0] = IH.DelegationRow(
            RH.Position(RH.Point(f.provenance.eras[0].originHash, 2, 30), 0),
            keccak256("authenticated original grant"),
            D.Record(
                D.Grant(
                    f.query.artistId,
                    address(700),
                    7,
                    D.ATTEST | D.POLICY_CONSENT,
                    100,
                    200,
                    0,
                    keccak256("constraints")
                ),
                address(701),
                1,
                1,
                true,
                keccak256("original revocation")
            ),
            keccak256("authenticated replacement"),
            0
        );
        f.identity.delegations[1] = IH.DelegationRow(
            RH.Position(RH.Point(f.provenance.eras[1].originHash, 2, 10), 1),
            keccak256("authenticated replacement"),
            D.Record(
                D.Grant(
                    f.query.artistId,
                    address(700),
                    7,
                    D.ATTEST,
                    300,
                    400,
                    0,
                    keccak256("new constraints")
                ),
                address(702),
                2,
                0,
                false,
                0
            ),
            keccak256("authenticated replacement"),
            1
        );
        f.provenance.journals[2] = new RH.JournalEntry[](3);
        f.provenance.journals[2][0] = _journal(
            f.identity.delegations[0].position.point,
            0,
            26,
            f.query.artistId,
            0,
            f.identity.delegations[0].recordHash
        );
        f.provenance.journals[2][1] = _journal(
            RH.Point(f.provenance.eras[1].originHash, 2, 9),
            0,
            27,
            f.query.artistId,
            0,
            f.identity.delegations[0].record.revocationRecordHash
        );
        f.provenance.journals[2][2] = _journal(
            f.identity.delegations[1].position.point,
            1,
            26,
            f.query.artistId,
            0,
            f.identity.delegations[1].recordHash
        );
        f.rows = new PubH.Row[](3);
        f.provenance.journals[4] = new RH.JournalEntry[](3);
        for (uint256 i; i < 3; ++i) {
            Ready.AttestationRow memory row;
            row.input.terms = T.Attestation(
                7,
                10,
                f.query.artistId,
                keccak256(abi.encode("operative identity", i)),
                keccak256("synthetic schema"),
                keccak256(abi.encode("original statement", i)),
                "urn:original"
            );
            row.input.nonce = i == 1 ? 257 : i + 1;
            row.statement = abi.encode("original statement", i);
            row.authorityClass = uint8(i + 1);
            row.record = T.AttestationRecord(
                0,
                row.input.terms.subjectStateHash,
                row.input.terms.schemaId,
                row.input.terms.statementHash,
                1,
                50,
                address(uint160(i == 1 ? 700 : 800 + i))
            );
            if (i == 1) {
                row.association = A.Association(
                    f.query.artistId,
                    f.query.bindingHash,
                    1,
                    f.identity.delegations[0].recordHash,
                    A.Fact(
                        address(512),
                        keccak256("original fact owner"),
                        f.query.artistId,
                        row.record.subjectStateHash
                    )
                );
            }
            f.rows[i].attestation = row;
            f.provenance.journals[4][i] = _journal(
                RH.Point(
                    f.provenance.eras[i == 0 ? 0 : 1].originHash, 4, uint64(i == 0 ? 20 : i + 1)
                ),
                i == 0 ? 0 : i - 1,
                24,
                f.query.artistId,
                7,
                0
            );
        }
        _seal(f);
    }

    function _seal(Fixture memory f) private pure {
        f.identity.signatures = new IH.SignatureRow[](3);
        f.provenance.aliases[2] = new RH.ReplayAlias[](8);
        uint256 n;
        for (uint256 i; i < 3; ++i) {
            Ready.AttestationRow memory row = f.rows[i].attestation;
            uint256 era = i == 0 ? 0 : 1;
            bytes32 record = _hash(f, row, era);
            f.rows[i].attestation.record.recordHash = record;
            f.provenance.journals[4][i].receipt.recordHash = record;
            f.identity.signatures[i] =
                IH.SignatureRow(record, i == 0 ? bytes("") : bytes(hex"1234"));
            bytes32 digest = _digest(f, i);
            RH.Point memory at = RH.Point(
                f.provenance.eras[era].originHash, 2, uint64(i == 0 ? 40 : i == 1 ? 5 : 7)
            );
            bytes32 scope = i == 1
                ? keccak256(
                    abi.encode(
                        Delegation.lane(f.query.artistId, row.record.signer), row.input.nonce
                    )
                )
                : keccak256(abi.encode(f.query.artistId, row.input.nonce));
            f.provenance.aliases[2][n++] = _alias(i == 1 ? DELEGATE : NONCE, scope, digest, at);
            if (i != 1) {
                f.provenance.aliases[2][n++] =
                    _alias(KEY, keccak256(abi.encode(record)), record, at);
            }
            f.provenance.aliases[2][n++] =
                _alias(OBSERVED, keccak256(abi.encode(f.query.artistId, digest)), digest, at);
        }
    }

    function _sharedDigest(Fixture memory f) private pure {
        IH.DelegationRow[] memory grants = new IH.DelegationRow[](3);
        grants[0] = f.identity.delegations[0];
        grants[2] = f.identity.delegations[1];
        grants[1] = abi.decode(abi.encode(grants[0]), (IH.DelegationRow));
        grants[1].recordHash = keccak256("other authenticated grant");
        grants[1].record.grant.delegate = address(703);
        grants[1].record.revoked = false;
        grants[1].record.revocationRecordHash = 0;
        grants[1].position.point = RH.Point(f.provenance.eras[1].originHash, 2, 2);
        f.identity.delegations = grants;
        PubH.Row[] memory rows = new PubH.Row[](4);
        RH.JournalEntry[] memory journal = new RH.JournalEntry[](4);
        IH.SignatureRow[] memory signatures = new IH.SignatureRow[](4);
        for (uint256 i; i < 3; ++i) {
            rows[i] = f.rows[i];
            journal[i] = f.provenance.journals[4][i];
            signatures[i] = f.identity.signatures[i];
        }
        rows[3] = abi.decode(abi.encode(rows[1]), (PubH.Row));
        rows[3].attestation.record.signer = address(703);
        rows[3].attestation.association.delegation = grants[1].recordHash;
        rows[3].attestation.record.recordHash = _hash(f, rows[3].attestation, 1);
        journal[3] = _journal(
            RH.Point(f.provenance.eras[1].originHash, 4, 4),
            2,
            24,
            f.query.artistId,
            7,
            rows[3].attestation.record.recordHash
        );
        signatures[3] = IH.SignatureRow(rows[3].attestation.record.recordHash, hex"5678");
        f.rows = rows;
        f.provenance.journals[4] = journal;
        f.identity.signatures = signatures;
        _appendAlias(
            f,
            _alias(
                DELEGATE,
                keccak256(
                    abi.encode(Delegation.lane(f.query.artistId, address(703)), uint256(257))
                ),
                _digest(f, 3),
                RH.Point(f.provenance.eras[1].originHash, 2, 6)
            )
        );
    }

    function _consent(Fixture memory f) private pure returns (Consent.Bundle memory c) {
        c.artistId = f.query.artistId;
        c.collectionId = f.query.collectionId;
        c.bindingHash = f.query.bindingHash;
        c.policies = new DH.Policy[](1);
        c.policies[0] = DH.Policy(keccak256("original14"), f.identity.delegations[0].recordHash);
        f.provenance.journals[6] = new RH.JournalEntry[](1);
        f.provenance.journals[6][0] = _journal(
            RH.Point(f.provenance.eras[1].originHash, 6, 2),
            0,
            14,
            f.query.artistId,
            7,
            c.policies[0].recordHash
        );
    }

    function _hash(Fixture memory f, Ready.AttestationRow memory row, uint256 era)
        private
        pure
        returns (bytes32)
    {
        RH.OriginEnvironment memory o = f.provenance.origins[era];
        return Hashes.attestationRecordForAuthority(
            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
            row.input.terms,
            f.query.artistId,
            row.record.signer,
            row.authorityClass,
            row.input.nonce,
            row.record.signedAt
        );
    }

    function _digest(Fixture memory f, uint256 i) private pure returns (bytes32) {
        Ready.AttestationRow memory row = f.rows[i].attestation;
        RH.OriginEnvironment memory o = f.provenance.origins[i == 0 ? 0 : 1];
        return Hashes.attestationDigest(
            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
            row.input.terms,
            T.Authorization(row.input.nonce, row.record.signedAt, "")
        );
    }

    function _journal(
        RH.Point memory point,
        uint256 index,
        uint16 op,
        bytes32 artist,
        uint256 collection,
        bytes32 record
    ) private pure returns (RH.JournalEntry memory) {
        return RH.JournalEntry(RH.Position(point, index), H.Receipt(op, artist, collection, record));
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
        a.admittedAt = RH.Point(point.environmentHash, point.ownerIndex, point.ownerRevision);
    }

    function _appendAlias(Fixture memory f, RH.ReplayAlias memory a) private pure {
        RH.ReplayAlias[] memory all = new RH.ReplayAlias[](f.provenance.aliases[2].length + 1);
        for (uint256 i; i < f.provenance.aliases[2].length; ++i) {
            all[i] = f.provenance.aliases[2][i];
        }
        all[all.length - 1] = a;
        f.provenance.aliases[2] = all;
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function _reject(Fixture memory f) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(abi.encodeCall(this.check, (f)));
        assert(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    )
        );
    }

    function _combinedReject(Fixture memory f, Consent.Bundle memory c, uint8 mode, bool added)
        private
        view
    {
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.checkCombined, (f, c, mode, added)));
        assert(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    )
        );
    }
}
