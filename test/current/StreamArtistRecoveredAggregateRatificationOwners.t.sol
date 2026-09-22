// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ArtistRecoveredMultipleDisputeFixture
} from "../unit/artist/ArtistRecoveredMultipleDisputeFixture.sol";
import {
    ArtistPrimaryCollaboratorFixture
} from "../unit/artist/ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistOnboarding
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistOwner as Owner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistNativeReceipts as Native
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistRecoveredHydration as Recovered
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredConsentHydration as ConsentHydration
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeCodec as MDCodec
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeCodec.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Rows
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Validation
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationConsentValidation.sol";

/// @dev Real original Registry, seven owners, Archive, threshold Safes and op52/op60 writers.
/// Core, governance scheduling and Metadata content use the inherited typed unit boundaries.
/// These cases do not establish current-Core, native-size or full ceremony acceptance.
abstract contract AggregateMultipleDisputeRatificationOwnersFixture is
    ArtistRecoveredMultipleDisputeFixture
{
    struct OriginalRatification {
        uint256 collectionId;
        bytes32 artist;
        uint256 nonce;
        T.RatificationRecord record;
        bytes signature;
        address archiveAddress;
        bytes32 evidenceId;
        bytes evidence;
        bytes32 archiveReceipt;
    }

    OriginalRatification[] internal arOriginals;
    mapping(uint256 => bytes32) internal arHeads;

    function _arRatify(uint256 collection, uint256 salt, bool direct) internal {
        // Fixture selection supplies the actual current principal/Safe; the nonce is read afresh
        // because prior dispute/collaborator operations may have consumed its allocator.
        nextNonce = Identity(suite.owners[2]).identity(artistId).nonceHint;
        bytes32 content = keccak256(abi.encode("aggregate original52", collection, salt));
        metadata.setContent(content);
        T.Ratification memory terms = T.Ratification(collection, address(metadata), content);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentRatificationDigest(terms, a);
        _rhAuthorization(digest, a.nonce);
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 consentCount = Native(suite.owners[6]).artistNativeReceiptCount();
        uint256 archiveCount = archive.storedPayloadCount();
        T.Snapshot[7] memory before_;
        for (uint8 i; i < 7; ++i) {
            before_[i] = Owner(suite.owners[i]).ownerStateSnapshotV2();
        }
        bytes32 record;
        if (direct) {
            require(
                this.rhExecuteNewSafe(
                    address(ingress),
                    abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (terms, a))
                ),
                "real direct Safe52"
            );
            record = Consent(suite.owners[6]).firstReleaseRatification(collection).recordHash;
        } else {
            a.signature = _signature(digest);
            record = ingress.recordContentRatification(terms, a);
        }
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        collection,
                        content,
                        artistId,
                        address(artist),
                        uint8(1),
                        a.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "independent original52 record preimage"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == identityCount
                && Native(suite.owners[6]).artistNativeReceiptCount() == consentCount + 1
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).operation == 52
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).artistId == artistId
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).collectionId
                    == collection
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).recordHash == record,
            "original Consent52 only, no fabricated Identity52"
        );
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory after_ = Owner(suite.owners[i]).ownerStateSnapshotV2();
            if (i == 2 || i == 6) {
                require(after_.revision == before_[i].revision + 1, "two genuine owner writes");
            } else {
                require(
                    keccak256(abi.encode(after_)) == keccak256(abi.encode(before_[i])),
                    "read-only owner clock unchanged"
                );
            }
        }
        _rhCandidate(
            6, "consent_finality.replay.ratification_key", keccak256(abi.encode(collection, record))
        );
        require(archive.storedPayloadCount() == archiveCount + 1, "one actual Archive append");
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(52),
                direct ? address(artist) : address(this),
                record
            )
        );
        bytes memory evidence = Archive(address(archive)).artistEvidenceBytesV2(evidenceId, 1);
        arOriginals.push(
            OriginalRatification(
                collection,
                artistId,
                a.nonce,
                Consent(suite.owners[6]).ratificationRecord(record),
                a.signature,
                address(archive),
                evidenceId,
                evidence,
                _arArchiveReceipt(address(archive), evidenceId)
            )
        );
        arHeads[collection] = record;
        _arAssert(suite);
    }

    function _arArchiveReceipt(address source, bytes32 id) private view returns (bytes32) {
        (bytes32 hash, address pointer, uint32 size, uint64 appendedAt) =
            Archive(source).artistEvidenceMetadataV2(id, 1);
        bytes memory raw = Archive(source).artistEvidenceBytesV2(id, 1);
        require(
            hash == keccak256(raw) && size == raw.length && pointer != address(0),
            "real Archive bytes and receipt"
        );
        return keccak256(abi.encode(hash, pointer, size, appendedAt));
    }

    function _arAssert(T.SuiteConfiguration memory target) internal view {
        for (uint256 i; i < arOriginals.length; ++i) {
            OriginalRatification storage r = arOriginals[i];
            require(
                keccak256(
                    abi.encode(Consent(target.owners[6]).ratificationRecord(r.record.recordHash))
                ) == keccak256(abi.encode(r.record)),
                "retained exact record"
            );
            require(
                Consent(target.owners[6]).firstReleaseRatification(r.collectionId).recordHash
                    == arHeads[r.collectionId],
                "exact latest per-collection head"
            );
            require(
                Identity(target.owners[2]).nonceUsed(r.artist, r.nonce),
                "original nonce remains consumed"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(r.record.recordHash))
                    == keccak256(r.signature),
                "original signed or direct-empty proof bytes"
            );
            require(
                keccak256(abi.encode(Identity(target.owners[2]).identity(r.artist)))
                    == keccak256(abi.encode(Identity(suite.owners[2]).identity(r.artist))),
                "exact allocator and authority head"
            );
            require(
                _arArchiveReceipt(r.archiveAddress, r.evidenceId) == r.archiveReceipt
                    && keccak256(Archive(r.archiveAddress).artistEvidenceBytesV2(r.evidenceId, 1))
                        == keccak256(r.evidence),
                "original evidence location, bytes and append receipt retained"
            );
        }
    }

    function _arState(T.SuiteConfiguration memory target) internal view returns (bytes32 hash) {
        for (uint256 i; i < arOriginals.length; ++i) {
            OriginalRatification storage r = arOriginals[i];
            hash = keccak256(
                abi.encode(
                    hash,
                    Consent(target.owners[6]).ratificationRecord(r.record.recordHash),
                    Consent(target.owners[6]).firstReleaseRatification(r.collectionId),
                    Identity(target.owners[2]).signatureBundle(r.record.recordHash),
                    Identity(target.owners[2]).nonceUsed(r.artist, r.nonce),
                    Identity(target.owners[2]).identity(r.artist)
                )
            );
        }
    }

    function _arFeatures(Commit.Prepared memory p) internal view {
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require((h.requiredFeatures & RH.RATIFICATIONS) != 0, "actual52 required feature");
        }
        uint256 seen;
        for (uint256 i; i < p.admission.provenance.journals[6].length; ++i) {
            RH.JournalEntry memory row = p.admission.provenance.journals[6][i];
            if (row.receipt.operation != 52) continue;
            require(
                seen < arOriginals.length
                    && row.receipt.recordHash == arOriginals[seen].record.recordHash
                    && row.receipt.collectionId == arOriginals[seen].collectionId
                    && row.receipt.artistId == arOriginals[seen].artist,
                "complete global original52 occurrence order"
            );
            ++seen;
        }
        require(seen == arOriginals.length, "no omitted or invented ratification occurrence");
    }
}

// The duplicate driver preserves each actual fixture's single inheritance chain.
abstract contract AggregatePrimaryCollaboratorRatificationOwnersFixture is
    ArtistPrimaryCollaboratorFixture
{
    struct OriginalRatification {
        uint256 collectionId;
        bytes32 artist;
        uint256 nonce;
        T.RatificationRecord record;
        bytes signature;
        address archiveAddress;
        bytes32 evidenceId;
        bytes evidence;
        bytes32 archiveReceipt;
    }

    OriginalRatification[] internal arOriginals;
    mapping(uint256 => bytes32) internal arHeads;

    function _arRatify(uint256 collection, uint256 salt, bool direct) internal {
        // Fixture selection supplies the actual current principal/Safe; the nonce is read afresh
        // because prior dispute/collaborator operations may have consumed its allocator.
        nextNonce = Identity(suite.owners[2]).identity(artistId).nonceHint;
        bytes32 content = keccak256(abi.encode("aggregate original52", collection, salt));
        metadata.setContent(content);
        T.Ratification memory terms = T.Ratification(collection, address(metadata), content);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentRatificationDigest(terms, a);
        _rhAuthorization(digest, a.nonce);
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 consentCount = Native(suite.owners[6]).artistNativeReceiptCount();
        uint256 archiveCount = archive.storedPayloadCount();
        T.Snapshot[7] memory before_;
        for (uint8 i; i < 7; ++i) {
            before_[i] = Owner(suite.owners[i]).ownerStateSnapshotV2();
        }
        bytes32 record;
        if (direct) {
            require(
                this.rhExecuteNewSafe(
                    address(ingress),
                    abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (terms, a))
                ),
                "real direct Safe52"
            );
            record = Consent(suite.owners[6]).firstReleaseRatification(collection).recordHash;
        } else {
            a.signature = _signature(digest);
            record = ingress.recordContentRatification(terms, a);
        }
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        collection,
                        content,
                        artistId,
                        address(artist),
                        uint8(1),
                        a.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "independent original52 record preimage"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == identityCount
                && Native(suite.owners[6]).artistNativeReceiptCount() == consentCount + 1
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).operation == 52
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).artistId == artistId
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).collectionId
                    == collection
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).recordHash == record,
            "original Consent52 only, no fabricated Identity52"
        );
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory after_ = Owner(suite.owners[i]).ownerStateSnapshotV2();
            if (i == 2 || i == 6) {
                require(after_.revision == before_[i].revision + 1, "two genuine owner writes");
            } else {
                require(
                    keccak256(abi.encode(after_)) == keccak256(abi.encode(before_[i])),
                    "read-only owner clock unchanged"
                );
            }
        }
        _rhCandidate(
            6, "consent_finality.replay.ratification_key", keccak256(abi.encode(collection, record))
        );
        require(archive.storedPayloadCount() == archiveCount + 1, "one actual Archive append");
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(52),
                direct ? address(artist) : address(this),
                record
            )
        );
        bytes memory evidence = Archive(address(archive)).artistEvidenceBytesV2(evidenceId, 1);
        arOriginals.push(
            OriginalRatification(
                collection,
                artistId,
                a.nonce,
                Consent(suite.owners[6]).ratificationRecord(record),
                a.signature,
                address(archive),
                evidenceId,
                evidence,
                _arArchiveReceipt(address(archive), evidenceId)
            )
        );
        arHeads[collection] = record;
        _arAssert(suite);
    }

    function _arArchiveReceipt(address source, bytes32 id) private view returns (bytes32) {
        (bytes32 hash, address pointer, uint32 size, uint64 appendedAt) =
            Archive(source).artistEvidenceMetadataV2(id, 1);
        bytes memory raw = Archive(source).artistEvidenceBytesV2(id, 1);
        require(
            hash == keccak256(raw) && size == raw.length && pointer != address(0),
            "real Archive bytes and receipt"
        );
        return keccak256(abi.encode(hash, pointer, size, appendedAt));
    }

    function _arAssert(T.SuiteConfiguration memory target) internal view {
        for (uint256 i; i < arOriginals.length; ++i) {
            OriginalRatification storage r = arOriginals[i];
            require(
                keccak256(
                    abi.encode(Consent(target.owners[6]).ratificationRecord(r.record.recordHash))
                ) == keccak256(abi.encode(r.record)),
                "retained exact record"
            );
            require(
                Consent(target.owners[6]).firstReleaseRatification(r.collectionId).recordHash
                    == arHeads[r.collectionId],
                "exact latest per-collection head"
            );
            require(
                Identity(target.owners[2]).nonceUsed(r.artist, r.nonce),
                "original nonce remains consumed"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(r.record.recordHash))
                    == keccak256(r.signature),
                "original signed or direct-empty proof bytes"
            );
            require(
                keccak256(abi.encode(Identity(target.owners[2]).identity(r.artist)))
                    == keccak256(abi.encode(Identity(suite.owners[2]).identity(r.artist))),
                "exact allocator and authority head"
            );
            require(
                _arArchiveReceipt(r.archiveAddress, r.evidenceId) == r.archiveReceipt
                    && keccak256(Archive(r.archiveAddress).artistEvidenceBytesV2(r.evidenceId, 1))
                        == keccak256(r.evidence),
                "original evidence location, bytes and append receipt retained"
            );
        }
    }

    function _arState(T.SuiteConfiguration memory target) internal view returns (bytes32 hash) {
        for (uint256 i; i < arOriginals.length; ++i) {
            OriginalRatification storage r = arOriginals[i];
            hash = keccak256(
                abi.encode(
                    hash,
                    Consent(target.owners[6]).ratificationRecord(r.record.recordHash),
                    Consent(target.owners[6]).firstReleaseRatification(r.collectionId),
                    Identity(target.owners[2]).signatureBundle(r.record.recordHash),
                    Identity(target.owners[2]).nonceUsed(r.artist, r.nonce),
                    Identity(target.owners[2]).identity(r.artist)
                )
            );
        }
    }

    function _arFeatures(Commit.Prepared memory p) internal view {
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require((h.requiredFeatures & RH.RATIFICATIONS) != 0, "actual52 required feature");
        }
        uint256 seen;
        for (uint256 i; i < p.admission.provenance.journals[6].length; ++i) {
            RH.JournalEntry memory row = p.admission.provenance.journals[6][i];
            if (row.receipt.operation != 52) continue;
            require(
                seen < arOriginals.length
                    && row.receipt.recordHash == arOriginals[seen].record.recordHash
                    && row.receipt.collectionId == arOriginals[seen].collectionId
                    && row.receipt.artistId == arOriginals[seen].artist,
                "complete global original52 occurrence order"
            );
            ++seen;
        }
        require(seen == arOriginals.length, "no omitted or invented ratification occurrence");
    }
}

contract StreamArtistRecoveredMultipleDisputeRatificationOwnersTest is
    AggregateMultipleDisputeRatificationOwnersFixture
{
    function _arDisputeSource() private {
        _mdSource(false);
        _arRatify(1, 101, false);
        _arRatify(1, 102, true);
        _mdSigned(1, 1, keccak256("ratified collection original dispute"), false);
        _mdSelect(2);
        _arRatify(2, 201, true);
    }

    function testMultipleDisputeRatificationsRetainBothArtistsHeadsNoncesAndOriginalArchive()
        external
    {
        _arDisputeSource();
        require(
            arOriginals[0].signature.length != 0 && arOriginals[1].signature.length == 0
                && arOriginals[0].artist != arOriginals[2].artist,
            "two actual Artists and both authorization modes"
        );
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        _arFeatures(p);
        _mdImport(next, r, p);
        _arAssert(next.coordinator.suiteConfiguration());
    }

    function validateDisputeRatificationPayload(bytes memory raw) external pure {
        (, Payload.Payload memory payload) = Payload.decode(raw, 6);
        M.State memory s = MDCodec.decode(6, payload.semanticState, payload.provenance);
        (G.Consents[] memory all, T.RatificationRecord[][] memory rats) =
            Rows.decodeOwnerRows(s.rows, raw);
        Validation.validate(all, rats, s.collections, payload.provenance);
    }

    function testMalformedRatificationPayloadCommitmentRollsBackAndCanonicalRequestRetries()
        external
    {
        _arDisputeSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        bytes32 canonical = Prepared.inventory(p);
        Commit.Prepared memory changed = abi.decode(abi.encode(p), (Commit.Prepared));
        (RH.ExportHeader memory h, Payload.Payload memory local) =
            Payload.decode(changed.data[6].typedState, 6);
        (M.State memory s, bytes memory auxiliary) =
            MDCodec.decodeAuxiliary(6, local.semanticState, local.provenance);
        (G.Consents memory old, T.RatificationRecord[] memory rats) = Rows.decode(s.rows[0]);
        require(rats.length == 2, "actual first collection pair");
        rats[0].recordHash = keccak256("not an original52 receipt");
        s.rows[0] = Rows.encode(old, rats);
        local.semanticState = MDCodec.encode(6, s, local.provenance, auxiliary);
        h.semanticInventory = keccak256(local.semanticState);
        changed.data[6].typedState = Payload.encode(6, h, local);
        this.validateDisputeRatificationPayload(p.data[6].typedState);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.validateDisputeRatificationPayload(changed.data[6].typedState);
        RH.Request memory bad = abi.decode(abi.encode(r), (RH.Request));
        bad.expectedSemanticInventory = Prepared.inventory(changed);
        require(
            Prepared.inventory(p) == canonical && bad.expectedSemanticInventory != canonical,
            "deep copy preserves canonical certificate"
        );
        bytes32 before_ = keccak256(
            abi.encode(_mdState(next, p), _arState(next.coordinator.suiteConfiguration()))
        );
        uint256 nonce = rotationSafe.nonce();
        // Public op60 accepts Request, not a caller-supplied Prepared payload. The malformed
        // payload is independently rejected above; its inventory commitment cannot select it.
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(
            address(next.registry),
            abi.encodeCall(
                ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (bad, mdRoyalties)
            )
        );
        require(
            rotationSafe.nonce() == nonce
                && before_
                    == keccak256(
                        abi.encode(
                            _mdState(next, p), _arState(next.coordinator.suiteConfiguration())
                        )
                    ),
            "failed commitment consumes no Safe nonce or owner cell"
        );
        require(r.expectedSemanticInventory == canonical, "canonical retry request unchanged");
        _mdImport(next, r, p);
        _arAssert(next.coordinator.suiteConfiguration());
    }

    function testMultipleDisputeRatificationLateArchiveFailureRollsBackAllMapsAndRetries()
        external
    {
        _arDisputeSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        bytes32 before_ = keccak256(
            abi.encode(_mdState(next, p), _arState(next.coordinator.suiteConfiguration()))
        );
        uint256 nonce = rotationSafe.nonce();
        uint256 at = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Archive.ArtistArchiveBlockNumberOverflow.selector, uint256(type(uint64).max) + 1
            )
        );
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, mdRoyalties);
        require(
            before_
                == keccak256(
                    abi.encode(_mdState(next, p), _arState(next.coordinator.suiteConfiguration()))
                ),
            "late direct failure restores ratification cells and all owners"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(
            address(next.registry),
            abi.encodeCall(
                ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mdRoyalties)
            )
        );
        require(
            rotationSafe.nonce() == nonce
                && before_
                    == keccak256(
                        abi.encode(
                            _mdState(next, p), _arState(next.coordinator.suiteConfiguration())
                        )
                    ),
            "late Safe failure restores nonce and all cells"
        );
        _arAssert(suite);
        vm.roll(at);
        _mdImport(next, r, p);
        _arAssert(next.coordinator.suiteConfiguration());
    }

    function testMultipleDisputeSecondSuccessorKeepsOriginal52PositionsAndFreshLocal52() external {
        _arDisputeSource();
        Successor memory middle = _multiCutover();
        (RH.Request memory firstRequest, Commit.Prepared memory first) = _mdPrepare(middle);
        _mdImport(middle, firstRequest, first);
        _arAssert(middle.coordinator.suiteConfiguration());
        bytes32 firstValue = HydrationOwner(middle.identity).authorityHydrationCommitment();
        _rhAdopt(middle);
        _mdSelect(2); // Collection1 remains disputed; only the still-accepted collection signs.
        _arRatify(2, 202, false);
        Successor memory last = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(last);
        require(
            r.expectedSourceImportCommitment == firstValue
                && p.admission.provenance.eras.length == 2,
            "real repeated import"
        );
        RH.JournalEntry[] memory oldRows = first.admission.provenance.journals[6];
        RH.JournalEntry[] memory rows = p.admission.provenance.journals[6];
        require(rows.length == oldRows.length + 1, "exact one new original52");
        for (uint256 i; i < oldRows.length; ++i) {
            require(
                keccak256(abi.encode(rows[i])) == keccak256(abi.encode(oldRows[i])),
                "original positions and receipts preserved"
            );
        }
        RH.JournalEntry memory fresh = rows[rows.length - 1];
        require(
            fresh.receipt.operation == 52 && fresh.position.nativeIndex == 0
                && fresh.position.point.environmentHash == p.admission.provenance.eras[1].originHash
                && fresh.position.point.environmentHash != rows[0].position.point.environmentHash,
            "fresh local occurrence, never renumbered prefix"
        );
        _arFeatures(p);
        _mdImport(last, r, p);
        _arAssert(last.coordinator.suiteConfiguration());
    }
}

contract StreamArtistPrimaryCollaboratorRatificationOwnersTest is
    AggregatePrimaryCollaboratorRatificationOwnersFixture
{
    function _arCollaboratorSource() private {
        _pcSource(2); // Real partial collaborator/refusal plus accepted replacement generation.
        _arRatify(1, 301, false);
        _arRatify(2, 401, true);
        _arRatify(2, 402, false);
    }

    function testPrimaryCollaboratorRatificationsRetainPartialHistoryAndBothCollectionHeads()
        external
    {
        _arCollaboratorSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        _arFeatures(p);
        _pcImport(next, r, p);
        _arAssert(next.coordinator.suiteConfiguration());
    }

    function testPrimaryCollaboratorRatificationLateArchiveFailureIsAtomicThenRetries() external {
        _arCollaboratorSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _pcPrepare(next);
        bytes32 before_ = keccak256(
            abi.encode(_pcDestination(next), _arState(next.coordinator.suiteConfiguration()))
        );
        uint256 nonce = rotationSafe.nonce();
        uint256 at = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Archive.ArtistArchiveBlockNumberOverflow.selector, uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(
            before_
                == keccak256(
                    abi.encode(
                        _pcDestination(next), _arState(next.coordinator.suiteConfiguration())
                    )
                ),
            "late direct failure restores collaborator and ratification maps"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(
            address(next.registry), abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r))
        );
        require(
            rotationSafe.nonce() == nonce
                && before_
                    == keccak256(
                        abi.encode(
                            _pcDestination(next), _arState(next.coordinator.suiteConfiguration())
                        )
                    ),
            "Safe nonce and every new ratification cell restored"
        );
        _arAssert(suite);
        vm.roll(at);
        _pcImport(next, r, p);
        _arAssert(next.coordinator.suiteConfiguration());
    }
}
