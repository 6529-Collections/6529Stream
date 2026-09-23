// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionRequestTypes as Q
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as Confirmation
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import {
    StreamArtistSanctionConfirmationReads
} from "../../../smart-contracts/domains/artist/StreamArtistSanctionConfirmationReads.sol";
import {
    IStreamArtistSanctionConfirmation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    IStreamArtworkFinalityRegistry
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import {
    IStreamArtistSanctionOwner as CHSanctionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSanctionOwner.sol";
import {
    IStreamArtistSanctionArchiveFacts as CHSanctionFacts
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";

/// @notice Real signed52/12 and original Safe13 for an accepted collection1 in a mixed graph.
/// @dev Core, metadata/discovery/coverage and immutable executed Finality remain the explicit
/// inherited unit boundaries. The helper does not execute Finality governance. Registry, Safe,
/// seven owners, original signatures, nonces, replay, native receipts and Archive are real.
/// No additional request witness is needed:12/13/52 retain their complete inputs in Archive.
abstract contract ArtistCompleteHistorySanctionRatificationFixture is
    ArtistPrimaryCollaboratorFixture
{
    S.Record internal chsSanction;
    T.RatificationRecord internal chsRatification;
    Confirmation.Transition internal chsConfirmation;
    uint256 internal chsRatificationNonce;
    bytes internal chsSanctionSignature;
    bytes internal chsRatificationSignature;
    bytes32 internal chsSanctionArchiveHash;
    bytes32 internal chsSanctionFactsHash;

    /// @dev Call after original2 and before an opening44/repudiation47. Original13 changes
    /// Attribution2 to3; original44/61 may restore3, and original47 permits either2 or3.
    function _chSanctionRatification() internal {
        require(
            chsSanction.recordHash == 0 && chsRatification.recordHash == 0,
            "single original sanction and ratification fixture"
        );
        T.Binding memory binding_ = Binding(suite.owners[0]).binding(1);
        T.Identity memory principal = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        (uint8 state, uint64 generation) = Attribution(suite.owners[4]).attributionState(1);
        require(
            binding_.artistId == artistId && binding_.accepted && state == 2
                && generation == binding_.generation
                && principal.authorityAddress == address(artist)
                && (principal.authorityClass == 1 || principal.authorityClass == 3),
            "actual accepted ordinary principal before confirmation"
        );
        _chsRatify(principal.authorityClass);
        _chsSanction();
        _chsConfirm();
        _chAssertSanctionRatification(suite);
    }

    function _chsRatify(uint8 principalClass) private {
        bytes32 content = keccak256("complete graph original signed52 current content");
        // The inherited metadata producer is an explicit unit boundary. Its real getter is
        // read by the original Registry/Coordinator before the52 write; no owner read is mocked.
        metadata.setContent(content);
        T.Ratification memory terms = T.Ratification(1, address(metadata), content);
        T.Authorization memory authorization = _chsAuthorization();
        bytes32 digest = ingress.contentRatificationDigest(terms, authorization);
        authorization.signature =
            safeThresholdSignature(keys, safeMessageDigest(artist, abi.encode(digest)));
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 consentCount = Native(suite.owners[6]).artistNativeReceiptCount();
        bytes32 record = ingress.recordContentRatification(terms, authorization);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        uint256(1),
                        content,
                        artistId,
                        address(artist),
                        principalClass,
                        authorization.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original signed52 preimage"
        );
        _chsSignedNative(52, record, authorization.nonce, identityCount, consentCount);
        _pcRemember(artistId, record, digest, authorization);
        _rhCandidate(
            6, "consent_finality.replay.ratification_key", keccak256(abi.encode(uint256(1), record))
        );
        chsRatification = Consent(suite.owners[6]).ratificationRecord(record);
        chsRatificationNonce = authorization.nonce;
        chsRatificationSignature = authorization.signature;
        require(
            chsRatification.recordHash == record && chsRatification.contentStateHash == content
                && chsRatification.metadataContract == address(metadata),
            "original three-field52 body"
        );
    }

    function _chsSanction() private {
        (Q.Request memory request,) = _sanctionPrepared();
        T.Authorization memory authorization = _chsAuthorization();
        bytes32 digest = ingress.sanctionDigest(request.terms, authorization);
        authorization.signature =
            safeThresholdSignature(keys, safeMessageDigest(artist, abi.encode(digest)));
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 consentCount = Native(suite.owners[6]).artistNativeReceiptCount();
        bytes32 record = ingress.recordArtistSanction(request, authorization);
        chsSanction = ingress.sanctionRecord(record);
        S.Record memory r = chsSanction;
        bytes32[14] memory words;
        words[0] = keccak256("6529STREAM_ARTIST_SANCTION_RECORD_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(ingress))));
        words[3] = artistId;
        words[4] = bytes32(uint256(uint160(address(artist))));
        words[5] = bytes32(uint256(r.authorityClass));
        words[6] = bytes32(uint256(r.terms.scopeType));
        words[7] = bytes32(r.terms.collectionId);
        words[8] = bytes32(r.terms.tokenId);
        words[9] = r.terms.scopeId;
        words[10] = r.terms.sanctionSubjectHash;
        words[11] = r.terms.statementHash;
        words[12] = bytes32(authorization.nonce);
        words[13] = bytes32(uint256(r.signedAt));
        require(
            record != 0 && r.recordHash == record && keccak256(abi.encode(words)) == record
                && r.digest == digest && r.nonce == authorization.nonce
                && r.signer == address(artist) && r.artistId == artistId,
            "literal original signed12 body and domain"
        );
        _chsSignedNative(12, record, authorization.nonce, identityCount, consentCount);
        _pcRemember(artistId, record, digest, authorization);
        _rhCandidate(
            6, "consent_finality.replay.sanction_uniqueness", keccak256(abi.encode(record))
        );
        chsSanctionSignature = authorization.signature;
        chsSanctionArchiveHash =
            keccak256(CHSanctionOwner(suite.owners[6]).sanctionArchiveBytes(record));
        chsSanctionFactsHash =
            keccak256(abi.encode(CHSanctionFacts(suite.owners[6]).sanctionArchiveFacts(record)));
    }

    function _chsConfirm() private {
        (Confirmation.Transition memory transition, Confirmation.Observation memory observed) =
            _confirmationStored(chsSanction.recordHash, 1, 20);
        // Keep the disclosed immutable Finality boundary at the actual producer time rather
        // than the inherited fixture's fixed1001. Re-observe the same fixed Finality getter set.
        observed.finalityRecord.finalizedAt = uint64(block.timestamp);
        address finality = address(sanctionFixture.registry());
        avm.mockCall(
            finality,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (1)),
            abi.encode(observed.finalityRecord)
        );
        observed = StreamArtistSanctionConfirmationReads.observe(
            suite,
            StreamArtistSanctionConfirmationReads.Pins(
                finality,
                finality.codehash,
                address(core).codehash,
                address(ingress).codehash,
                2000000
            ),
            1
        );
        T.Snapshot[7] memory before_ = _confirmationSnapshots();
        uint256[7] memory counts;
        for (uint8 i; i < 7; ++i) {
            counts[i] = Native(suite.owners[i]).artistNativeReceiptCount();
        }
        require(
            this.executeTargetSafe(
                address(ingress),
                abi.encodeCall(
                    IStreamArtistSanctionConfirmation.confirmSanctionFinalized, (uint256(1))
                )
            ),
            "actual original Safe13"
        );
        _confirmationAfter(transition, observed, address(artist), before_);
        for (uint8 i; i < 7; ++i) {
            require(
                Native(suite.owners[i]).artistNativeReceiptCount() == counts[i],
                "original13 has no fabricated primary native receipt"
            );
        }
        chsConfirmation = transition;
        _rhCandidate(
            6,
            "consent_finality.replay.sanction_finalization_transition_key",
            _confirmationScope(transition)
        );
    }

    function _chsAuthorization() private view returns (T.Authorization memory) {
        return T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
    }

    function _chsSignedNative(
        uint16 operation,
        bytes32 record,
        uint256 nonce,
        uint256 identityCount,
        uint256 consentCount
    ) private view {
        require(
            Native(suite.owners[6]).artistNativeReceiptCount() == consentCount + 1
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).operation
                    == operation
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).recordHash == record
                && Native(suite.owners[6]).artistNativeReceiptAt(consentCount).artistId == artistId
                && IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, nonce)
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint
                    == nonce + 1,
            "one actual Consent record and original principal nonce consumption"
        );
        // Ordinary fresh authority emits no Identity12/52. If a surrounding legal authority
        // fixture has dormant activity, preserve its genuine original42 companion instead.
        uint256 after_ = Native(suite.owners[2]).artistNativeReceiptCount();
        for (uint256 i = identityCount; i < after_; ++i) {
            require(
                Native(suite.owners[2]).artistNativeReceiptAt(i).operation == 42,
                "only actual activity companion may append to Identity"
            );
        }
    }

    /// @notice Includes concrete original maps and signatures; safe for an empty destination.
    function _chSanctionRatificationHash(T.SuiteConfiguration memory target)
        internal
        view
        returns (bytes32)
    {
        S.Record memory sanction =
            CHSanctionOwner(target.owners[6]).sanctionRecord(chsSanction.recordHash);
        bytes32 documentary;
        bytes32 facts;
        // Original documentary getters reject unknown sanctions. The record getter still
        // exposes the empty target and any failed import that accidentally left a body.
        if (sanction.recordHash != 0) {
            documentary = keccak256(
                CHSanctionOwner(target.owners[6]).sanctionArchiveBytes(chsSanction.recordHash)
            );
            facts = keccak256(
                abi.encode(
                    CHSanctionFacts(target.owners[6]).sanctionArchiveFacts(chsSanction.recordHash)
                )
            );
        }
        return keccak256(
            abi.encode(
                sanction,
                documentary,
                facts,
                _chsAssociation(target.owners[6]),
                Consent(target.owners[6]).ratificationRecord(chsRatification.recordHash),
                Consent(target.owners[6]).firstReleaseRatification(1),
                IStreamArtistIdentityOwner(target.owners[2])
                    .signatureBundle(chsSanction.recordHash),
                IStreamArtistIdentityOwner(target.owners[2])
                    .signatureBundle(chsRatification.recordHash),
                IStreamArtistIdentityOwner(target.owners[2]).nonceUsed(artistId, chsSanction.nonce),
                IStreamArtistIdentityOwner(target.owners[2])
                    .nonceUsed(artistId, chsRatificationNonce),
                _chsConfirmationCell(target)
            )
        );
    }

    function _chAssertSanctionRatification(T.SuiteConfiguration memory target) internal view {
        require(
            chsSanction.recordHash != 0 && chsRatification.recordHash != 0
                && keccak256(
                    abi.encode(
                        CHSanctionOwner(target.owners[6]).sanctionRecord(chsSanction.recordHash)
                    )
                ) == keccak256(abi.encode(chsSanction))
                && keccak256(
                    CHSanctionOwner(target.owners[6]).sanctionArchiveBytes(chsSanction.recordHash)
                ) == chsSanctionArchiveHash
                && keccak256(
                    abi.encode(
                        CHSanctionFacts(target.owners[6])
                            .sanctionArchiveFacts(chsSanction.recordHash)
                    )
                ) == chsSanctionFactsHash
                && _chsAssociation(target.owners[6]) == chsSanction.recordHash,
            "complete original12 record bytes facts and association"
        );
        require(
            keccak256(
                    abi.encode(
                        Consent(target.owners[6]).ratificationRecord(chsRatification.recordHash)
                    )
                ) == keccak256(abi.encode(chsRatification))
                && keccak256(abi.encode(Consent(target.owners[6]).firstReleaseRatification(1)))
                    == keccak256(abi.encode(chsRatification)),
            "complete original52 body and first-release head"
        );
        require(
            keccak256(
                    IStreamArtistIdentityOwner(target.owners[2])
                        .signatureBundle(chsSanction.recordHash)
                ) == keccak256(chsSanctionSignature)
                && keccak256(
                    IStreamArtistIdentityOwner(target.owners[2])
                        .signatureBundle(chsRatification.recordHash)
                ) == keccak256(chsRatificationSignature)
                && IStreamArtistIdentityOwner(target.owners[2])
                    .nonceUsed(artistId, chsSanction.nonce)
                && IStreamArtistIdentityOwner(target.owners[2])
                    .nonceUsed(artistId, chsRatificationNonce),
            "both original signed authorizations and nonce bits retained"
        );
        T.ReplayCell memory cell = _chsConfirmationCell(target);
        require(
            cell.commitment == chsSanction.recordHash && cell.kind == 1 && cell.status == 2,
            "original13 confirmation consumed in destination domain"
        );
    }

    function _chsAssociation(address owner) private view returns (bytes32) {
        S.Record memory r = chsSanction;
        return CHSanctionOwner(owner)
            .sanctionForAssociation(
                r.artistId,
                r.bindingGeneration,
                r.bindingHash,
                r.terms.scopeType,
                r.terms.collectionId,
                r.terms.tokenId,
                r.terms.scopeId
            );
    }

    function _chsConfirmationCell(T.SuiteConfiguration memory target)
        private
        view
        returns (T.ReplayCell memory)
    {
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                target.registry,
                StreamArtistOnboardingRegistry(payable(target.registry)).operationCoordinator(),
                target.archive,
                target.owners[6],
                Owner(target.owners[6]).domainId(),
                keccak256("consent_finality.replay.sanction_finalization_transition_key"),
                _confirmationScope(chsConfirmation)
            )
        );
        return Owner(target.owners[6]).replayCell(key);
    }
}
