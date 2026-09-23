// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../unit/artist/ArtistRecoveredMultipleDisputeFixture.sol";
import {
    StreamArtistSanctionRequestTypes as ASQ
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";
import {
    StreamArtistSanctionTypes as ASR
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as ASConfirmation
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import {
    IStreamArtistSanctionConfirmation as ASConfirmationEntry
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    IStreamArtistSanctionOwner as ASOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSanctionOwner.sol";
import {
    IStreamArtistSanctionArchiveFacts as ASArchiveFacts
} from "../../smart-contracts/interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";
import {
    IStreamArtistReconstruction as ASReconstruction
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as ASH
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as ASTransport
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as ASConsentTransport
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionConsentTransport.sol";

interface AggregateSanctionHistoryVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Actual current Artist owners, original signed12/permissionless13, threshold Safes,
/// Archive and aggregate seven-owner preparation/import over two collections.
/// @dev Core, scoped governance and documentary coverage retain the inherited named unit
/// boundaries. Original12 uses the actual Finality candidate path; original13 uses the existing
/// typed retained Finality execution boundary and the actual confirmation writer/Archive.
/// This host does not execute a Finality governance ceremony or claim real Core/Executor coverage.
contract StreamArtistRecoveredAggregateSanctionHistoryTest is
    ArtistRecoveredMultipleDisputeFixture
{
    AggregateSanctionHistoryVm private constant asVm =
        AggregateSanctionHistoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32[] private asRecords;
    bytes[] private asSignatures;

    function testAggregateSanctionOriginalSignedHistoryAndHeadSurviveTwoImports() external {
        _mdSource(false);
        // A real second-collection episode selects the complete MD profile, not a fabricated flag.
        _mdSelect(2);
        _mdSigned(2, 1, keccak256("other Artist opening"), false);
        _mdSigned(2, 2, keccak256("other Artist withdrawal"), true);
        _mdSelect(1);
        bytes32 first = _asSanction();
        bytes32 last = _asSanction();
        require(first != last, "two independently admitted original12 nonces");
        Successor memory middle = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(middle);
        (D.Bundle[] memory all, ASH.Inventory memory history) = _asHistory(p);
        require(
            history.sanctions.length == 2 && history.confirmations.length == 0
                && history.operations.length == 2 && all.length == 2 && all[0].current.state == 2
                && all[1].current.state == 2,
            "unconfirmed12 preserves accepted attribution in both collections"
        );
        bytes32 originals = _asOriginals(history);
        T.SuiteConfiguration memory source = suite;
        bytes32 sealedSource = _asSourceState(source);
        _asImport(middle, r, p);
        require(_asSourceState(source) == sealedSource, "A owners and Archive heads unchanged");
        _rhAdopt(middle);
        Successor memory final_ = _multiCutover();
        (r, p) = _mdPrepare(final_);
        (all, history) = _asHistory(p);
        require(
            p.admission.provenance.eras.length == 2 && history.catalogues.length == 2
                && _asOriginals(history) == originals,
            "same original12 records, points and Archive occurrences across A to B to C"
        );
        T.SuiteConfiguration memory secondSource = suite;
        bytes32 secondSeal = _asSourceState(secondSource);
        _asImport(final_, r, p);
        require(
            _asSourceState(source) == sealedSource && _asSourceState(secondSource) == secondSeal,
            "both sealed predecessor owners and catalogue heads unchanged"
        );
    }

    function testAggregateSanctionTypedFinalityConfirmationAndMixedWithdrawalsRestoreExactStates()
        external
    {
        _mdSource(true);
        bytes32 record = _asSanction();
        _asConfirm(record);
        _mdSigned(1, 1, keccak256("confirmed collection opening"), false);
        _asState(suite, 1, 4);
        _mdSigned(1, 2, keccak256("confirmed collection withdrawal"), true);
        _asState(suite, 1, 3);
        _mdSelect(2);
        _mdSigned(2, 1, keccak256("accepted collection opening"), false);
        _mdSigned(2, 2, keccak256("accepted collection withdrawal"), true);
        _asState(suite, 2, 2);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        (D.Bundle[] memory all, ASH.Inventory memory history) = _asHistory(p);
        require(
            history.sanctions.length == 1 && history.confirmations.length == 1
                && history.operations.length == 2
                && history.confirmations[0].transition.sanctionRecordHash == record
                && history.confirmations[0].transition.collectionId == 1
                && all[0].disputes[0].withdrawal.restoredState == 3
                && all[1].disputes[0].withdrawal.restoredState == 2,
            "one exact original13 cannot confirm or rewrite the other collection"
        );
        require(
            history.confirmations[0].attributionPoint.ownerIndex == 4
                && history.confirmations[0].consentPoint.ownerIndex == 6,
            "confirmation retains two independent original owner coordinates"
        );
        _asImport(next, r, p);
        _asState(next.coordinator.suiteConfiguration(), 1, 3);
        _asState(next.coordinator.suiteConfiguration(), 2, 2);
    }

    function testAggregateSanctionLateArchiveRollbackIdenticalSafeRetryAndSuccessorResolution()
        external
    {
        _mdSource(false);
        bytes32 record = _asSanction();
        _asConfirm(record);
        _mdSigned(1, 1, keccak256("confirmed unresolved original episode"), false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        (D.Bundle[] memory all, ASH.Inventory memory history) = _asHistory(p);
        require(
            all[0].current.state == 4 && all[0].heads[0].restoreState == 3
                && history.confirmations.length == 1,
            "valid preparation retains actual open confirmed episode"
        );
        bytes memory data = abi.encodeCall(
            ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mdRoyalties)
        );
        uint256 nonce = rotationSafe.nonce();
        bytes32 transaction = rotationSafe.getTransactionHash(
            address(next.registry), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(rotationKeys, transaction);
        bytes32 before_ = _asDestinationState(next);
        T.SuiteConfiguration memory source = suite;
        bytes32 sealedSource = _asSourceState(source);
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        asVm.expectCall(target.archive, _asFirstPage(next, r, p), 2);
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(bytes("GS013"));
        this.asExecuteSavedSafe(address(next.registry), data, signatures);
        require(
            rotationSafe.nonce() == nonce && _asDestinationState(next) == before_
                && _asSourceState(source) == sealedSource,
            "late actual Archive failure rolls back Safe, all seven owners and semantic heads"
        );
        _asState(target, 1, 0);
        require(ASOwner(target.owners[6]).sanctionRecord(record).recordHash == 0, "no partial12");
        vm.roll(height);
        dv.recordLogs();
        require(
            this.asExecuteSavedSafe(address(next.registry), data, signatures),
            "byte-identical Safe payload and signatures retry after fixing only block height"
        );
        _asAssertImport(next, r, p, dv.getRecordedLogs());
        require(rotationSafe.nonce() == nonce + 1, "only successful Safe consumes nonce");
        require(_asSourceState(source) == sealedSource, "successful import leaves source sealed");
        _rhAdopt(next);
        _mdSelect(1);
        bytes32 action = _mdResolve(1, 1, 1);
        require(
            ingress.attributionDisputeResolution(action).restoredState == 3,
            "successor original46 restores retained original13 state"
        );
        _asState(suite, 1, 3);
        _asAssertSanctions(suite, history);
    }

    function asExecuteSavedSafe(address target, bytes calldata data, bytes calldata signatures)
        external
        returns (bool)
    {
        require(msg.sender == address(this), "self-only saved transaction fixture");
        return rotationSafe.execTransaction(
            target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
    }

    function _asSanction() private returns (bytes32 record) {
        (ASQ.Request memory q,) = _sanctionPrepared();
        T.Authorization memory a = _sanctionAuthorization(q);
        bytes32 digest = ingress.sanctionDigest(q.terms, a);
        T.Snapshot[7] memory before_ = _confirmationSnapshots();
        uint256 receipts = Native(suite.owners[6]).artistNativeReceiptCount();
        record = ingress.recordArtistSanction(q, a);
        ASR.Record memory row = ingress.sanctionRecord(record);
        require(
            row.digest == digest && row.nonce == a.nonce && row.signer == address(artist),
            "actual signed12"
        );
        bytes32[14] memory words;
        words[0] = keccak256("6529STREAM_ARTIST_SANCTION_RECORD_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(ingress))));
        words[3] = artistId;
        words[4] = bytes32(uint256(uint160(address(artist))));
        words[5] = bytes32(uint256(row.authorityClass));
        words[6] = bytes32(uint256(row.terms.scopeType));
        words[7] = bytes32(row.terms.collectionId);
        words[8] = bytes32(row.terms.tokenId);
        words[9] = row.terms.scopeId;
        words[10] = row.terms.sanctionSubjectHash;
        words[11] = row.terms.statementHash;
        words[12] = bytes32(a.nonce);
        words[13] = bytes32(uint256(row.signedAt));
        require(keccak256(abi.encode(words)) == record, "literal original signed12 preimage");
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory after_ = OriginalOwner(suite.owners[i]).ownerStateSnapshotV2();
            if (i == 2 || i == 6) {
                require(after_.revision == before_[i].revision + 1, "original12 two owner writes");
            } else {
                require(
                    keccak256(abi.encode(after_)) == keccak256(abi.encode(before_[i])),
                    "other owners unchanged by12"
                );
            }
        }
        require(
            Native(suite.owners[6]).artistNativeReceiptCount() == receipts + 1,
            "one actual native12"
        );
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6, "consent_finality.replay.sanction_uniqueness", keccak256(abi.encode(record))
        );
        asRecords.push(record);
        asSignatures.push(a.signature);
    }

    function _asConfirm(bytes32 record) private {
        // This installs only the inherited, explicitly typed retained Finality-history boundary.
        // The permissionless op13 producer and both owner writes/Archive payload are real.
        (ASConfirmation.Transition memory transition, ASConfirmation.Observation memory observed) =
            _confirmationStored(record, 1, 20);
        T.Snapshot[7] memory before_ = _confirmationSnapshots();
        uint256 consentReceipts = Native(suite.owners[6]).artistNativeReceiptCount();
        uint256 attributionReceipts = Native(suite.owners[4]).artistNativeReceiptCount();
        ASConfirmationEntry(address(ingress)).confirmSanctionFinalized(1);
        _confirmationAfter(transition, observed, address(this), before_);
        require(
            Native(suite.owners[6]).artistNativeReceiptCount() == consentReceipts
                && Native(suite.owners[4]).artistNativeReceiptCount() == attributionReceipts,
            "original13 has two mutations and no synthetic native receipt"
        );
        _rhCandidate(
            6,
            "consent_finality.replay.sanction_finalization_transition_key",
            _confirmationScope(transition)
        );
    }

    function _asHistory(Commit.Prepared memory p)
        private
        pure
        returns (D.Bundle[] memory all, ASH.Inventory memory history)
    {
        (RH.ExportHeader memory h, Payload.Payload memory local) =
            Payload.decode(p.data[4].typedState, 4);
        require(
            (h.requiredFeatures & RH.SANCTION_HISTORY) != 0,
            "explicit aggregate sanction capability"
        );
        M.State memory wrapped = ConsentCodec.decode(4, local.semanticState, local.provenance);
        M.State memory original;
        (original, history) = ASTransport.decode(wrapped);
        require(
            keccak256(wrapped.rows[0])
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_AGGREGATE_SANCTION_ATTRIBUTION_V1"),
                        uint16(1),
                        original.rows[0],
                        history
                    )
                ),
            "literal first-row global certificate"
        );
        all = new D.Bundle[](original.rows.length);
        for (uint256 i; i < all.length; ++i) {
            all[i] = abi.decode(original.rows[i], (MD.Attribution)).history;
        }
        (h, local) = Payload.decode(p.data[6].typedState, 6);
        require((h.requiredFeatures & RH.SANCTION_HISTORY) != 0, "owner6 same selected profile");
        M.State memory consent = ConsentCodec.decode(6, local.semanticState, local.provenance);
        (,, ASH.Inventory memory same) = ASConsentTransport.decode(
            consent.rows, (h.requiredFeatures & RH.RATIFICATIONS) != 0, true
        );
        require(
            keccak256(abi.encode(same)) == keccak256(abi.encode(history)),
            "both owners bind one identical complete global certificate"
        );
    }

    function _asOriginals(ASH.Inventory memory h) private pure returns (bytes32) {
        return keccak256(abi.encode(h.operations, h.sanctions, h.confirmations));
    }

    function _asState(T.SuiteConfiguration memory s, uint256 collection, uint8 expected)
        private
        view
    {
        (uint8 actual,) = IStreamArtistAttributionOwner(s.owners[4]).attributionState(collection);
        require(actual == expected, "actual per-collection attribution state");
    }

    function _asImport(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        private
    {
        dv.recordLogs();
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(
                    ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mdRoyalties)
                )
            ),
            "actual aggregate op60 through threshold Safe"
        );
        _asAssertImport(next, r, p, dv.getRecordedLogs());
    }

    function _asAssertImport(
        Successor memory next,
        RH.Request memory r,
        Commit.Prepared memory p,
        MultipleDisputeTestVm.Log[] memory logs
    ) private view {
        _multiAssert(next, p);
        (D.Bundle[] memory all, ASH.Inventory memory history) = _asHistory(p);
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        for (uint256 i; i < all.length; ++i) {
            _mdAssertHistory(i + 1, target, all[i]);
        }
        _asAssertSanctions(target, history);
        _asArchive(next, r, p, logs);
    }

    function _asAssertSanctions(T.SuiteConfiguration memory target, ASH.Inventory memory history)
        private
        view
    {
        require(
            history.sanctions.length == asRecords.length, "all original signed12 records retained"
        );
        for (uint256 i; i < history.sanctions.length; ++i) {
            ASH.SanctionRow memory row = history.sanctions[i];
            bytes32 hash = row.record.recordHash;
            require(
                hash == asRecords[i]
                    && keccak256(abi.encode(ASOwner(target.owners[6]).sanctionRecord(hash)))
                        == keccak256(abi.encode(row.record)),
                "entire original12 record"
            );
            require(
                keccak256(ASOwner(target.owners[6]).sanctionArchiveBytes(hash))
                        == keccak256(row.archiveBytes)
                    && keccak256(
                        abi.encode(ASArchiveFacts(target.owners[6]).sanctionArchiveFacts(hash))
                    ) == keccak256(abi.encode(row.archiveFacts)),
                "exact retained ceremony bytes and Archive facts"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(hash))
                        == keccak256(asSignatures[i])
                    && Identity(target.owners[2]).nonceUsed(row.record.artistId, row.record.nonce),
                "original signer evidence and consumed nonce"
            );
            bytes32 latest = hash;
            for (uint256 j = i + 1; j < history.sanctions.length; ++j) {
                ASR.Record memory later = history.sanctions[j].record;
                if (
                    later.artistId == row.record.artistId
                        && later.bindingGeneration == row.record.bindingGeneration
                        && later.bindingHash == row.record.bindingHash
                        && later.terms.scopeType == row.record.terms.scopeType
                        && later.terms.collectionId == row.record.terms.collectionId
                        && later.terms.tokenId == row.record.terms.tokenId
                        && later.terms.scopeId == row.record.terms.scopeId
                ) latest = later.recordHash;
            }
            require(
                ASOwner(target.owners[6])
                    .sanctionForAssociation(
                        row.record.artistId,
                        row.record.bindingGeneration,
                        row.record.bindingHash,
                        row.record.terms.scopeType,
                        row.record.terms.collectionId,
                        row.record.terms.tokenId,
                        row.record.terms.scopeId
                    ) == latest,
                "exact full-association latest head"
            );
        }
    }

    function _asSourceState(T.SuiteConfiguration memory s) private view returns (bytes32 result) {
        for (uint8 i; i < 7; ++i) {
            result = keccak256(
                abi.encode(
                    result,
                    OriginalOwner(s.owners[i]).ownerStateSnapshotV2(),
                    CP(s.owners[i]).authorityCheckpoint(),
                    Native(s.owners[i]).artistNativeReceiptCount()
                )
            );
        }
        uint256 n = ASReconstruction(s.archive).storedPayloadCount();
        result = keccak256(abi.encode(result, n));
        for (uint256 i; i < n; ++i) {
            (address pointer, bytes32 kind, bytes32 hash) =
                ASReconstruction(s.archive).storedPayloadAt(i);
            result = keccak256(abi.encode(result, pointer, kind, hash));
        }
    }

    function _asDestinationState(Successor memory next) private view returns (bytes32 result) {
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        result = keccak256(abi.encode(_multiDestinationHash(next), _asSourceState(target)));
        for (uint256 i; i < asRecords.length; ++i) {
            ASR.Record memory original = ingress.sanctionRecord(asRecords[i]);
            ASR.Record memory retained = ASOwner(target.owners[6]).sanctionRecord(asRecords[i]);
            result = keccak256(
                abi.encode(
                    result,
                    retained,
                    Identity(target.owners[2]).signatureBundle(asRecords[i]),
                    ASOwner(target.owners[6])
                        .sanctionForAssociation(
                            original.artistId,
                            original.bindingGeneration,
                            original.bindingHash,
                            original.terms.scopeType,
                            original.terms.collectionId,
                            original.terms.tokenId,
                            original.terms.scopeId
                        )
                )
            );
            // Original getters deliberately reject unknown sanctions; never fabricate empty facts.
            if (retained.recordHash != 0) {
                result = keccak256(
                    abi.encode(
                        result,
                        ASOwner(target.owners[6]).sanctionArchiveBytes(asRecords[i]),
                        ASArchiveFacts(target.owners[6]).sanctionArchiveFacts(asRecords[i])
                    )
                );
            }
        }
        for (uint256 i = 1; i <= 2; ++i) {
            result = keccak256(
                abi.encode(result, DisputeOwner(target.owners[4]).attributionDispute(i, 1))
            );
        }
    }

    function _asProfile(RH.Request memory r, Commit.Prepared memory p)
        private
        pure
        returns (bytes memory)
    {
        return abi.encode(
            RH.PROFILE,
            uint16(1),
            p.admission.prior,
            p.admission.sourceCoordinator,
            r,
            p.admission.artists,
            p.admission.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
    }

    function _asValue(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                RH.PROFILE,
                uint16(1),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                r,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
    }

    function _asFirstPage(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        private
        view
        returns (bytes memory)
    {
        bytes32 id = Evidence.pageId(
            address(next.registry),
            address(next.coordinator),
            _asValue(next, r, p),
            Evidence.describe(_asProfile(r, p)),
            0
        );
        return abi.encodePacked(Archive.appendArtistEvidenceV2.selector, id);
    }

    function _asArchive(
        Successor memory next,
        RH.Request memory r,
        Commit.Prepared memory p,
        MultipleDisputeTestVm.Log[] memory logs
    ) private view {
        bytes32 value = _asValue(next, r, p);
        bytes memory profile = _asProfile(r, p);
        Evidence.Descriptor memory descriptor = Evidence.describe(profile);
        require(
            HydrationOwner(next.identity).authorityHydrationCommitment() == value,
            "literal original op60 commitment"
        );
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        T.Snapshot[7] memory after_;
        for (uint8 i; i < 7; ++i) {
            after_[i] = OriginalOwner(target.owners[i]).ownerStateSnapshotV2();
        }
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                uint16(60),
                address(rotationSafe),
                value
            )
        );
        bytes memory expected = abi.encode(
            uint16(1),
            next.coordinator.configurationHash(),
            uint16(60),
            address(rotationSafe),
            value,
            p.admission.before_,
            after_,
            abi.encode(RH.PROFILE, descriptor)
        );
        require(
            keccak256(Archive(target.archive).artistEvidenceBytesV2(id, 1)) == keccak256(expected),
            "actual original Archive envelope and seven snapshots"
        );
        require(
            keccak256(
                Evidence.read(
                    target.archive,
                    address(next.registry),
                    address(next.coordinator),
                    value,
                    descriptor
                )
            ) == keccak256(profile),
            "entire original profile archived"
        );
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            MultipleDisputeTestVm.Log memory log_ = logs[i];
            if (
                log_.emitter != address(next.coordinator) || log_.topics.length != 4
                    || log_.topics[0]
                        != keccak256(
                            "RecoveredArtistAuthorityHydrated(uint16,address,bytes32,bytes32,bytes32)"
                        )
            ) continue;
            require(
                log_.topics[1] == bytes32(uint256(uint160(p.admission.prior)))
                    && log_.topics[2] == value && log_.topics[3] == r.expectedSemanticInventory
                    && keccak256(log_.data) == keccak256(abi.encode(uint16(1), keccak256(profile))),
                "actual hydration event matches whole imported evidence"
            );
            ++seen;
        }
        require(seen == 1, "one emitted op60 event");
    }
}
