// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCodec.sol";

/// @dev Synthetic exact getter boundary. It proves transport fidelity, not original nonce admission.
contract RecoveredHydrationNonceBoundary {
    function authorityCheckpoint() external pure returns (CP.Checkpoint memory cp) {
        cp.schema = RH.CHECKPOINT;
        cp.ownerState = T.Snapshot(RH.ownerDomain(2), 100, bytes32(uint256(1)), bytes32(uint256(2)));
        cp.nonceRoot = bytes32(uint256(3));
        cp.nonceIndexCount = 5;
    }

    function authorityNonceIndexAt(uint256 index) external pure returns (CP.NonceIndex memory) {
        require(index < 5);
        return CP.NonceIndex(uint8(index + 1), bytes32(index + 1), 1);
    }

    function authorityNonceWordAt(uint8 kind, bytes32 key, uint256 index)
        external
        pure
        returns (uint256 prefix, uint256[32] memory words, bool exhausted)
    {
        require(kind != 0 && kind <= 5 && key == bytes32(uint256(kind)) && index == 0);
        prefix = uint256(kind) * 256;
        for (uint256 i; i < 32; ++i) {
            words[i] = uint256(kind) + i;
        }
        exhausted = kind == 5;
    }
}

/// @notice Synthetic common-codec and chronology controls. Actual operation60 admission is separate.
contract StreamArtistRecoveredHydrationProvenanceTest {
    function check(RH.Provenance memory p) external pure returns (bytes32) {
        return Provenance.validate(p);
    }

    function compare(RH.Provenance memory p, RH.Point memory a, RH.Point memory b)
        external
        pure
        returns (int8)
    {
        return Chronology.compare(p, a, b);
    }

    function checkNonces(address owner, CP.Checkpoint memory cp, RH.NonceInventory[] memory n)
        external
        view
        returns (bytes32)
    {
        return Provenance.validateNonces(owner, cp, n);
    }

    function decode(bytes memory data, uint8 ownerIndex)
        external
        pure
        returns (RH.Envelope memory)
    {
        return Codec.decode(data, ownerIndex);
    }

    function checkPrefix(
        RH.Provenance memory p,
        RH.OwnerProvenance memory prefix,
        bytes32 commitment,
        uint64 revision
    ) external pure {
        Provenance.validate(p);
        Provenance.validateImportedPrefix(p, 2, prefix, commitment, revision);
    }

    function testRecoveredImportedPrefixMatchesExactOriginalOccurrencesAndAliases() external {
        RH.Provenance memory p = _withAliases();
        RH.OwnerProvenance memory prefix;
        prefix.origins = new RH.OriginEnvironment[](1);
        prefix.origins[0] = p.origins[0];
        prefix.eras = new RH.OwnerEra[](1);
        prefix.eras[0] = RH.ownerProvenance(p, 2).eras[0];
        prefix.journal = new RH.JournalEntry[](2);
        prefix.journal[0] = p.journals[2][0];
        prefix.journal[1] = p.journals[2][1];
        prefix.aliases = new RH.ReplayAlias[](1);
        for (uint256 i; i < p.aliases[2].length; ++i) {
            if (p.aliases[2][i].originHash == p.eras[0].originHash) {
                prefix.aliases[0] = p.aliases[2][i];
            }
        }
        this.checkPrefix(p, prefix, p.eras[1].priorImportCommitment, 3);
        RH.JournalEntry memory saved = prefix.journal[1];
        prefix.journal[1] = prefix.journal[0];
        (bool ok,) = address(this)
            .call(
                abi.encodeCall(
                    this.checkPrefix, (p, prefix, p.eras[1].priorImportCommitment, uint64(3))
                )
            );
        assert(!ok);
        prefix.journal[1] = saved;
        prefix.aliases = new RH.ReplayAlias[](0);
        (ok,) = address(this)
            .call(
                abi.encodeCall(
                    this.checkPrefix, (p, prefix, p.eras[1].priorImportCommitment, uint64(3))
                )
            );
        assert(!ok);
    }

    function testRecoveredFirstSourceRequiresCompletelyEmptySavedPrefixAndMarkers() external {
        RH.Provenance memory both = _provenance();
        RH.Provenance memory p;
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0] = both.origins[0];
        p.eras = new RH.Era[](1);
        p.eras[0] = both.eras[0];
        p.journals[2] = new RH.JournalEntry[](2);
        p.journals[2][0] = both.journals[2][0];
        p.journals[2][1] = both.journals[2][1];
        RH.OwnerProvenance memory empty;
        this.checkPrefix(p, empty, 0, 0);
        (bool ok,) = address(this)
            .call(abi.encodeCall(this.checkPrefix, (p, empty, bytes32(uint256(1)), uint64(0))));
        assert(!ok);
        (ok,) =
            address(this).call(abi.encodeCall(this.checkPrefix, (p, empty, bytes32(0), uint64(1))));
        assert(!ok);
        empty.origins = p.origins;
        (ok,) =
            address(this).call(abi.encodeCall(this.checkPrefix, (p, empty, bytes32(0), uint64(0))));
        assert(!ok);
    }

    function testRecoveredProvenanceCompleteFlattenedTwoEraJournal() external pure {
        RH.Provenance memory p = _provenance();
        assert(Provenance.validate(p) == RH.provenanceHash(p));
        assert(Provenance.environment(p, p.eras[0].originHash).registry == address(1));
    }

    function testRecoveredChronologyOldRawRevisionGreaterThanNewLocalRevision() external pure {
        RH.Provenance memory p = _provenance();
        RH.Point memory old = p.journals[2][0].position.point;
        RH.Point memory fresh = p.journals[2][2].position.point;
        assert(old.ownerRevision == 90 && fresh.ownerRevision == 5);
        assert(Chronology.before(p, old, fresh));
        assert(Chronology.compare(p, fresh, old) == 1);
        assert(Chronology.compare(p, old, old) == 0);
    }

    function testRecoveredOwnerHeaderDoesNotHashAnotherOwnersMutableCheckpoint() external pure {
        RH.Provenance memory p = _provenance();
        bytes32 local = RH.ownerProvenanceHash(p, 2);
        assert(Provenance.validateOwner(RH.ownerProvenance(p, 2), 2) == local);
        bytes32 joined = RH.provenanceHash(p);
        p.eras[1].checkpoints[5].ownerState.stateRoot = bytes32(uint256(1234));
        assert(RH.ownerProvenanceHash(p, 2) == local);
        assert(RH.provenanceHash(p) != joined);
        assert(RH.ownerProvenanceHash(RH.ownerProvenance(p, 2), 2) == local);
        assert(Provenance.validateOwner(RH.ownerProvenance(p, 2), 2) == local);
    }

    function testRecoveredChronologyRejectsCrossOwnerComparison() external {
        RH.Provenance memory p = _provenance();
        RH.Point memory a = p.journals[2][0].position.point;
        RH.Point memory b = RH.Point(p.eras[1].originHash, 5, 5);
        (bool ok,) = address(this).call(abi.encodeCall(this.compare, (p, a, b)));
        assert(!ok);
    }

    function testRecoveredChronologyRejectsZeroMissingAndBoundaryPoints() external {
        RH.Provenance memory p = _provenance();
        RH.Point memory valid = p.journals[2][0].position.point;
        RH.Point memory bad;
        (bool ok,) = address(this).call(abi.encodeCall(this.compare, (p, valid, bad)));
        assert(!ok);
        bad = RH.Point(bytes32(uint256(999)), 2, 5);
        (ok,) = address(this).call(abi.encodeCall(this.compare, (p, valid, bad)));
        assert(!ok);
        bad = RH.Point(p.eras[1].originHash, 2, 0);
        (ok,) = address(this).call(abi.encodeCall(this.compare, (p, valid, bad)));
        assert(!ok);
        bad.ownerRevision = 9;
        (ok,) = address(this).call(abi.encodeCall(this.compare, (p, valid, bad)));
        assert(!ok);
        // Real55/56 precede local60 but remain valid auxiliary points in this later era.
        RH.Point memory preparation = RH.Point(p.eras[1].originHash, 2, 2);
        assert(Chronology.before(p, valid, preparation));
        assert(Chronology.before(p, preparation, p.journals[2][2].position.point));
        // Native rows, unlike auxiliary points, must strictly follow the actual local60 boundary.
        p.journals[2][2].position.point.ownerRevision = p.eras[1].lowerRevisions[2];
        _reject(p);
    }

    function testRecoveredProvenanceRejectsZeroMissingAndDuplicateOrigin() external {
        RH.Provenance memory p = _provenance();
        p.origins[0].registry = address(0);
        _reject(p);
        p = _provenance();
        p.origins = new RH.OriginEnvironment[](0);
        _reject(p);
        p = _provenance();
        p.origins[1] = p.origins[0];
        p.eras[1].originHash = p.eras[0].originHash;
        _reject(p);
    }

    function testRecoveredProvenanceRejectsReorderedJournal() external {
        RH.Provenance memory p = _provenance();
        RH.JournalEntry memory old = p.journals[2][0];
        p.journals[2][0] = p.journals[2][2];
        p.journals[2][2] = old;
        _reject(p);
    }

    function testRecoveredProvenanceRejectsOmittedJournalOccurrence() external {
        RH.Provenance memory p = _provenance();
        RH.JournalEntry[] memory missing = new RH.JournalEntry[](2);
        missing[0] = p.journals[2][0];
        missing[1] = p.journals[2][2];
        p.journals[2] = missing;
        _reject(p);
    }

    function testRecoveredProvenanceRetainsRepeatedSecondaryHashOccurrences() external pure {
        RH.Provenance memory p = _provenance();
        // Equal receipt hashes do not merge different original native occurrences.
        p.journals[2][2].receipt.recordHash = p.journals[2][1].receipt.recordHash;
        assert(p.journals[2][1].position.nativeIndex == 1);
        assert(p.journals[2][2].position.nativeIndex == 0);
        Provenance.validate(p);
    }

    function testRecoveredAliasKeepsMutationOriginSeparateFromRekeyOrigin() external pure {
        RH.Provenance memory p = _withAliases();
        Provenance.validate(p);
        bool seen;
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias memory a = p.aliases[2][i];
            if (a.originHash != p.eras[1].originHash) continue;
            assert(a.admittedAt.environmentHash == p.eras[0].originHash);
            assert(
                a.cell.touchedRevision == 90 && p.eras[1].checkpoints[2].ownerState.revision == 8
            );
            seen = true;
        }
        assert(seen);
    }

    function testRecoveredAliasRejectsRawRevisionRelabeledAsCurrentEra() external {
        RH.Provenance memory p = _withAliases();
        for (uint256 i; i < p.aliases[2].length; ++i) {
            if (p.aliases[2][i].originHash == p.eras[1].originHash) {
                p.aliases[2][i].admittedAt.environmentHash = p.eras[1].originHash;
            }
        }
        _reject(p);
    }

    function testRecoveredAliasRejectsDuplicateKeyAndMissingEraInventory() external {
        RH.Provenance memory p = _withAliases();
        p.aliases[2][1] = p.aliases[2][0];
        _reject(p);
        p = _withAliases();
        p.aliases[2] = new RH.ReplayAlias[](0);
        _reject(p);
    }

    function testRecoveredNonceInventoryIncludesEveryKindAndExhaustedTree() external {
        RecoveredHydrationNonceBoundary owner = new RecoveredHydrationNonceBoundary();
        RH.NonceInventory[] memory n = _nonces(owner);
        assert(n[4].words[0].exhausted);
        assert(Provenance.validateNonces(address(owner), owner.authorityCheckpoint(), n) != 0);
    }

    function testRecoveredNonceInventoryRejectsMissingAncestorAndExhaustionMismatch() external {
        RecoveredHydrationNonceBoundary owner = new RecoveredHydrationNonceBoundary();
        CP.Checkpoint memory cp = owner.authorityCheckpoint();
        RH.NonceInventory[] memory n = new RH.NonceInventory[](0);
        (bool ok,) = address(this).call(abi.encodeCall(this.checkNonces, (address(owner), cp, n)));
        assert(!ok);
        n = _nonces(owner);
        n[3].words[0].words[31] ^= 1;
        (ok,) = address(this).call(abi.encodeCall(this.checkNonces, (address(owner), cp, n)));
        assert(!ok);
        n = _nonces(owner);
        n[4].words[0].exhausted = false;
        (ok,) = address(this).call(abi.encodeCall(this.checkNonces, (address(owner), cp, n)));
        assert(!ok);
        n = _nonces(owner);
        assert(Provenance.validateNonces(address(owner), cp, n) != 0);
    }

    function testRecoveredCodecRequiresExactOwnerVersionAndCanonicalBytes() external {
        RH.Envelope memory envelope;
        envelope.header = RH.ExportHeader(
            RH.PROFILE,
            RH.VERSION,
            2,
            bytes32(uint256(1)),
            0,
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(4)),
            RH.CLASS_ONE,
            0,
            0,
            1
        );
        envelope.payload = abi.encode(uint256(17));
        bytes memory raw = Codec.encode(2, envelope);
        assert(keccak256(Codec.decode(raw, 2).payload) == keccak256(envelope.payload));
        (bool ok,) = address(this).call(abi.encodeCall(this.decode, (raw, uint8(5))));
        assert(!ok);
        bytes memory wrong = abi.encode(RH.ownerTag(2), uint16(2), envelope);
        (ok,) = address(this).call(abi.encodeCall(this.decode, (wrong, uint8(2))));
        assert(!ok);
        wrong = bytes.concat(raw, bytes32(0));
        (ok,) = address(this).call(abi.encodeCall(this.decode, (wrong, uint8(2))));
        assert(!ok);
    }

    function testRecoveredProvenanceRejectsUnsupportedEraCount() external {
        RH.Provenance memory p;
        p.origins = new RH.OriginEnvironment[](RH.MAX_ERAS + 1);
        p.eras = new RH.Era[](RH.MAX_ERAS + 1);
        _reject(p);
    }

    function _reject(RH.Provenance memory p) private {
        (bool ok,) = address(this).call(abi.encodeCall(this.check, (p)));
        assert(!ok);
    }

    function _provenance() private pure returns (RH.Provenance memory p) {
        p.origins = new RH.OriginEnvironment[](2);
        p.eras = new RH.Era[](2);
        for (uint256 era; era < 2; ++era) {
            RH.OriginEnvironment memory o;
            o.chainId = 1;
            o.registry = address(uint160(1 + era * 100));
            o.coordinator = address(uint160(2 + era * 100));
            o.archive = address(uint160(3 + era * 100));
            o.core = address(500);
            o.manager = address(501);
            o.suiteConfigurationHash = bytes32(uint256(600 + era));
            for (uint8 i; i < 7; ++i) {
                o.owners[i] = address(uint160(10 + uint256(i) + era * 100));
                o.ownerCodeHashes[i] = bytes32(uint256(700) + i);
                p.eras[era].checkpoints[i].schema = RH.CHECKPOINT;
                p.eras[era].checkpoints[i].ownerState = T.Snapshot(
                    RH.ownerDomain(i),
                    era == 0 ? uint64(100) : uint64(8),
                    bytes32(uint256(800)),
                    bytes32(uint256(900))
                );
                p.eras[era].lowerRevisions[i] = era == 0 ? 0 : 3;
            }
            p.origins[era] = o;
            p.eras[era].originHash = RH.originHash(o);
            if (era != 0) p.eras[era].priorImportCommitment = bytes32(uint256(1000));
        }
        p.eras[0].nativeCounts[2] = 2;
        p.eras[1].nativeCounts[2] = 1;
        p.journals[2] = new RH.JournalEntry[](3);
        for (uint256 i; i < 3; ++i) {
            bool firstEra = i < 2;
            p.journals[2][i] = RH.JournalEntry(
                RH.Position(
                    RH.Point(
                        p.eras[firstEra ? 0 : 1].originHash, 2, firstEra ? uint64(90) : uint64(5)
                    ),
                    firstEra ? i : 0
                ),
                H.Receipt(35, bytes32(uint256(111)), 0, bytes32(uint256(222 + i)))
            );
        }
    }

    function _withAliases() private pure returns (RH.Provenance memory p) {
        p = _provenance();
        p.aliases[2] = new RH.ReplayAlias[](2);
        for (uint256 i; i < 2; ++i) {
            RH.OriginEnvironment memory o = p.origins[i];
            RH.ReplayAlias memory a;
            a.originHash = p.eras[i].originHash;
            a.ownerIndex = 2;
            a.surface = keccak256("synthetic.original.nonce");
            a.scope = bytes32(uint256(12));
            a.originalKey = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                    o.chainId,
                    o.registry,
                    o.coordinator,
                    o.archive,
                    o.owners[2],
                    RH.ownerDomain(2),
                    a.surface,
                    a.scope
                )
            );
            a.cell = T.ReplayCell(bytes32(uint256(13)), 90, 1, 2);
            a.admittedAt = RH.Point(p.eras[0].originHash, 2, 90);
            p.aliases[2][i] = a;
            p.eras[i].checkpoints[2].replayCount = 1;
        }
        if (p.aliases[2][1].originalKey < p.aliases[2][0].originalKey) {
            RH.ReplayAlias memory first = p.aliases[2][0];
            p.aliases[2][0] = p.aliases[2][1];
            p.aliases[2][1] = first;
        }
    }

    function _nonces(RecoveredHydrationNonceBoundary owner)
        private
        view
        returns (RH.NonceInventory[] memory n)
    {
        n = new RH.NonceInventory[](5);
        for (uint256 i; i < 5; ++i) {
            n[i].index = owner.authorityNonceIndexAt(i);
            n[i].words = new AH.NonceWord[](1);
            (n[i].words[0].prefix, n[i].words[0].words, n[i].words[0].exhausted) =
                owner.authorityNonceWordAt(uint8(i + 1), bytes32(i + 1), 0);
        }
    }
}
