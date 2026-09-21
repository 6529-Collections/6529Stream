// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionAttributionCodec as SanctionCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionAttributionCodec.sol";

import "./ArtistRecoveredDisputeHistoryFixture.sol";
import {
    StreamArtistSanctionRequestTypes as Q
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as Confirmation
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as SH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionAttributionValidation as SanctionAttribution
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionAttributionValidation.sol";
import {
    StreamArtistRecoveredSanctionConsentHistory as SanctionConsent
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionConsentHistory.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionCatalogue.sol";
import {
    IStreamArtistSanctionOwner as SanctionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSanctionOwner.sol";
import {
    IStreamArtistSanctionArchiveFacts as SanctionFacts
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";
import {
    IStreamArtistSanctionConfirmation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    IStreamArtistReconstruction as Reconstruction
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";

/// @notice Actual original op12/13 owners, signature Safe, Archive and recovered seven-owner import.
/// @dev Inherits explicit Core/governance/coverage boundaries. Executed Finality facts alone are
/// typed historical responses; this fixture does not execute the Finality governance transaction.
abstract contract ArtistRecoveredSanctionHistoryFixture is ArtistRecoveredDisputeHistoryFixture {
    bytes32[] internal sanctionHashes;
    bytes[] internal sanctionSignatures;

    function _sanction() internal returns (bytes32 record) {
        (Q.Request memory q,) = _sanctionPrepared();
        T.Authorization memory a = _sanctionAuthorization(q);
        bytes32 digest = ingress.sanctionDigest(q.terms, a);
        record = ingress.recordArtistSanction(q, a);
        S.Record memory r = ingress.sanctionRecord(record);
        require(
            r.digest == digest && r.nonce == a.nonce && r.signer == address(artist),
            "actual signed12"
        );
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
        words[12] = bytes32(a.nonce);
        words[13] = bytes32(uint256(r.signedAt));
        require(keccak256(abi.encode(words)) == record, "literal original sanction domain/preimage");
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6, "consent_finality.replay.sanction_uniqueness", keccak256(abi.encode(record))
        );
        sanctionHashes.push(record);
        sanctionSignatures.push(a.signature);
    }

    function _confirm(bytes32 record) internal {
        (Confirmation.Transition memory t, Confirmation.Observation memory o) =
            _confirmationStored(record, 1, 20);
        T.Snapshot[7] memory before_ = _confirmationSnapshots();
        _artistCall(
            abi.encodeCall(IStreamArtistSanctionConfirmation.confirmSanctionFinalized, (uint256(1)))
        );
        _confirmationAfter(t, o, address(artist), before_);
        _rhCandidate(
            6, "consent_finality.replay.sanction_finalization_transition_key", _confirmationScope(t)
        );
    }

    function _sanctionBundle(Commit.Prepared memory p)
        internal
        view
        returns (SH.AttributionBundle memory b)
    {
        (RH.ExportHeader memory header, Payload.Payload memory local) =
            Payload.decode(p.data[4].typedState, 4);
        require(
            (header.requiredFeatures & 16384) != 0 && (header.requiredFeatures & 8192) != 0,
            "explicit composed profile"
        );
        b = SanctionCodec.decode(p.query, local.provenance, local.semanticState);
        require(
            keccak256(local.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_SANCTION_ATTRIBUTION_V1"),
                        uint16(1),
                        b
                    )
                ),
            "literal owner4 codec"
        );
        (, local) = Payload.decode(p.data[6].typedState, 6);
        SanctionConsent.Bundle memory consent =
            SanctionConsent.decode(p.query, local.provenance, local.semanticState);
        require(
            keccak256(abi.encode(consent.history)) == keccak256(abi.encode(b.history)),
            "same complete Archive inventory in both owners"
        );
        require(
            keccak256(local.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_SANCTION_CONSENT_V1"),
                        uint16(1),
                        consent
                    )
                ),
            "literal owner6 codec"
        );
    }

    function _assertSanctionImport(
        T.SuiteConfiguration memory target,
        SH.AttributionBundle memory b
    ) internal view {
        _assertDisputeImport(target, b.original);
        require(
            b.history.sanctions.length == sanctionHashes.length,
            "complete signed sanction inventory"
        );
        for (uint256 i; i < b.history.sanctions.length; ++i) {
            SH.SanctionRow memory row = b.history.sanctions[i];
            bytes32 hash = row.record.recordHash;
            require(
                hash == sanctionHashes[i]
                    && keccak256(abi.encode(SanctionOwner(target.owners[6]).sanctionRecord(hash)))
                        == keccak256(abi.encode(row.record)),
                "all original sanction fields"
            );
            require(
                keccak256(SanctionOwner(target.owners[6]).sanctionArchiveBytes(hash))
                        == keccak256(row.archiveBytes)
                    && keccak256(
                        abi.encode(SanctionFacts(target.owners[6]).sanctionArchiveFacts(hash))
                    ) == keccak256(abi.encode(row.archiveFacts)),
                "exact original documentary bytes and facts"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(hash))
                        == keccak256(sanctionSignatures[i])
                    && Identity(target.owners[2]).nonceUsed(artistId, row.record.nonce),
                "original signature and consumed nonce"
            );
            bytes32 latest = hash;
            for (uint256 j = i + 1; j < b.history.sanctions.length; ++j) {
                S.Record memory later = b.history.sanctions[j].record;
                if (
                    later.bindingGeneration == row.record.bindingGeneration
                        && later.bindingHash == row.record.bindingHash
                        && later.terms.scopeType == row.record.terms.scopeType
                        && later.terms.tokenId == row.record.terms.tokenId
                        && later.terms.scopeId == row.record.terms.scopeId
                ) latest = later.recordHash;
            }
            require(
                SanctionOwner(target.owners[6])
                    .sanctionForAssociation(
                        artistId,
                        row.record.bindingGeneration,
                        row.record.bindingHash,
                        row.record.terms.scopeType,
                        1,
                        row.record.terms.tokenId,
                        row.record.terms.scopeId
                    ) == latest,
                "original association head"
            );
        }
    }

    function checkSanctionAttribution(
        SH.AttributionBundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) external view {
        SanctionAttribution.validate(b, q, p);
    }
}
