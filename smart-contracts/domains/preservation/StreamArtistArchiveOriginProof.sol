// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    StreamArtistHistoryTypes as H,
    IStreamArtistNativeReceipts as Native
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Recovered,
    IStreamArtistRecoveredNativeChronology as Chronology
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistImportedReceiptRead as Imported
} from "../../interfaces/stream/artist/IStreamArtistImportedReceiptRead.sol";
import {
    IStreamArtistRecordPublicationOwner as Publication
} from "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    IStreamArtistContentRecordsOwner as Content
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistArchiveOriginEnvironment as Environment
} from "./StreamArtistArchiveOriginEnvironment.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";

/// @notice Exact native/imported occurrence and semantic-record joins, before Archive decoding.
/// @dev A certificate proves an environment only. Imported records also require their actual
/// current-owner journal row and the original producer's native receipt/revision/semantic row.
library StreamArtistArchiveOriginProof {
    function currentOrigin(S.Dependencies memory d) public view returns (O.Origin memory, bytes32) {
        Environment.Context memory c = Environment.current(d);
        return (c.origin, c.completion);
    }

    function publicationOrigin(
        S.Dependencies memory d,
        P.Evidence memory expected,
        bytes32 originalRecord,
        address actor,
        bytes32 sourceContextHash,
        O.ReceiptWitness memory witness
    ) public view returns (O.RecordOrigin memory result) {
        _inputs(actor, sourceContextHash);
        if (expected.attestationRecordHash == 0 || expected.artistId == 0 || originalRecord == 0) {
            revert O.InvalidArchiveOrigin();
        }
        Environment.Context memory c = Environment.current(d);
        Publication.Record memory saved =
            _publication(c.suite.owners[4], expected.attestationRecordHash, d.readGas);
        if (
            keccak256(abi.encode(saved.evidence)) != keccak256(abi.encode(expected))
                || saved.metadataHostCodeHash != d.codeHashes[1]
                || saved.publication.metadataHost != d.targets[1]
                || saved.publication.candidateRecordHash != originalRecord
                || saved.publication.recorder != expected.signer || expected.signer == address(0)
                || saved.publication.collectionId == 0
                || keccak256(abi.encode(saved.publication)) != expected.publicationHash
        ) revert O.InvalidArchiveOrigin();
        result = _occurrence(
            d,
            c,
            H.Receipt(
                24,
                expected.artistId,
                saved.publication.collectionId,
                expected.attestationRecordHash
            ),
            witness
        );
        bytes32 semantic = keccak256(abi.encode(saved));
        if (
            semantic
                != keccak256(
                    abi.encode(
                        _publication(
                            result.producer.environment.owners[4],
                            expected.attestationRecordHash,
                            d.readGas
                        )
                    )
                )
        ) revert O.InvalidArchiveOrigin();
        result.actor = actor;
        result.semanticRecordHash = semantic;
        result.role = keccak256("ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION");
        result.sourceContextHash = sourceContextHash;
    }

    function contentOrigin(
        S.Dependencies memory d,
        uint256 cid,
        bytes32 artistId,
        bytes32 consentRecord,
        address actor,
        O.ContentRole role,
        bytes32 ctx,
        O.ReceiptWitness memory witness
    ) public view returns (O.RecordOrigin memory result) {
        _inputs(actor, ctx);
        if (cid == 0 || artistId == 0 || consentRecord == 0) revert O.InvalidArchiveOrigin();
        Environment.Context memory c = Environment.current(d);
        Content.ConsentRecord memory saved = _content(c.suite.owners[6], consentRecord, d.readGas);
        if (
            saved.recordHash != consentRecord || saved.artistId != artistId
                || saved.bindingGeneration == 0
                || (saved.authorityClass != 1 && saved.authorityClass != 3)
                || saved.terms.collectionId != cid || saved.terms.metadataContract != d.targets[4]
                || saved.terms.familyId != keccak256("CONTENT_ROOT")
                || saved.terms.newStateHash == 0
        ) revert O.InvalidArchiveOrigin();
        result = _occurrence(d, c, H.Receipt(17, artistId, cid, consentRecord), witness);
        bytes32 semantic = keccak256(abi.encode(saved));
        if (
            semantic
                != keccak256(
                    abi.encode(
                        _content(result.producer.environment.owners[6], consentRecord, d.readGas)
                    )
                )
        ) revert O.InvalidArchiveOrigin();
        result.actor = actor;
        result.semanticRecordHash = semantic;
        result.role = _contentRole(role);
        result.sourceContextHash = ctx;
    }

    function ancestorOrigin(S.Dependencies memory d, address registry, bytes32 registryHash)
        public
        view
        returns (O.Origin memory origin)
    {
        Environment.Context memory c = Environment.current(d);
        if (registry == c.origin.environment.registry) {
            if (registryHash != c.origin.registryCodeHash) revert O.InvalidArchiveOrigin();
            return c.origin;
        }
        A.SuiteConfiguration memory originalSuite;
        (origin, originalSuite) = Environment.configured(d, registry, registryHash);
        Environment.sameDependencies(originalSuite, c.suite);
        bytes32 hash = RH.originHash(origin.environment);
        address owner = c.suite.owners[2];
        _certificate(owner, hash, c.completion, 0, 2, d.readGas);
        RH.OriginEnvironment memory saved = _environment(owner, hash, d.readGas);
        if (keccak256(abi.encode(saved)) != keccak256(abi.encode(origin.environment))) {
            revert O.InvalidArchiveOrigin();
        }
    }

    function _occurrence(
        S.Dependencies memory d,
        Environment.Context memory c,
        H.Receipt memory receipt,
        O.ReceiptWitness memory witness
    ) private view returns (O.RecordOrigin memory result) {
        uint8 index = receipt.operation == 24 ? 4 : 6;
        address owner = c.suite.owners[index];
        if (witness.lane == O.Lane.NATIVE) {
            result.producer = c.origin;
            H.Receipt memory local = _native(owner, witness.index, d.readGas);
            result.occurrence = RH.JournalEntry(
                RH.Position(
                    RH.Point(
                        RH.originHash(c.origin.environment),
                        index,
                        _revision(owner, witness.index, d.readGas)
                    ),
                    witness.index
                ),
                local
            );
            _snapshot(owner, index, result.occurrence.position.point.ownerRevision, d.readGas);
        } else if (witness.lane == O.Lane.IMPORTED) {
            bytes memory raw = IO.fixedRead(
                owner,
                abi.encodeCall(Imported.recoveredHydrationImportedReceiptAt, (witness.index)),
                320,
                d.readGas
            );
            (result.occurrence, result.importCommitment, result.importedAtRevision) =
                abi.decode(raw, (RH.JournalEntry, bytes32, uint64));
            IO.canonical(
                owner,
                raw,
                abi.encode(result.occurrence, result.importCommitment, result.importedAtRevision)
            );
            if (
                result.occurrence.position.point.ownerIndex != index
                    || result.importedAtRevision == 0 || result.importCommitment != c.completion
                    || keccak256(abi.encode(result.occurrence.receipt))
                        != keccak256(abi.encode(receipt))
            ) revert O.InvalidArchiveOrigin();
            bytes32 hash = result.occurrence.position.point.environmentHash;
            _certificate(owner, hash, c.completion, result.importedAtRevision, index, d.readGas);
            RH.OriginEnvironment memory saved = _environment(owner, hash, d.readGas);
            result.producer = Environment.imported(d, c, saved);
            address originalOwner = saved.owners[index];
            if (
                keccak256(
                            abi.encode(
                                _native(
                                    originalOwner, result.occurrence.position.nativeIndex, d.readGas
                                )
                            )
                        ) != keccak256(abi.encode(result.occurrence.receipt))
                    || _revision(originalOwner, result.occurrence.position.nativeIndex, d.readGas)
                        != result.occurrence.position.point.ownerRevision
            ) revert O.InvalidArchiveOrigin();
        } else {
            revert O.InvalidArchiveOrigin();
        }
        if (keccak256(abi.encode(result.occurrence.receipt)) != keccak256(abi.encode(receipt))) {
            revert O.InvalidArchiveOrigin();
        }
    }

    function _certificate(
        address owner,
        bytes32 hash,
        bytes32 completion,
        uint64 expectedRevision,
        uint8 index,
        uint256 cap
    ) private view {
        bytes memory raw = IO.fixedRead(
            owner,
            abi.encodeCall(Recovered.recoveredHydrationImportedOriginCertificate, (hash)),
            128,
            cap
        );
        (bytes32 actualHash, bytes32 actual, uint64 revision, uint8 ownerIndex) =
            abi.decode(raw, (bytes32, bytes32, uint64, uint8));
        IO.canonical(owner, raw, abi.encode(actualHash, actual, revision, ownerIndex));
        if (
            hash == 0 || actualHash != hash || completion == 0 || actual != completion
                || revision == 0 || ownerIndex != index
                || (expectedRevision != 0 && revision != expectedRevision)
        ) revert O.InvalidArchiveOrigin();
        _snapshot(owner, index, revision, cap);
    }

    function _environment(address owner, bytes32 hash, uint256 cap)
        private
        view
        returns (RH.OriginEnvironment memory e)
    {
        bytes memory raw = IO.fixedRead(
            owner, abi.encodeCall(Recovered.recoveredHydrationOrigin, (hash)), 672, cap
        );
        e = abi.decode(raw, (RH.OriginEnvironment));
        IO.canonical(owner, raw, abi.encode(e));
        if (RH.originHash(e) != hash) revert O.InvalidArchiveOrigin();
    }

    function _native(address owner, uint256 index, uint256 cap)
        private
        view
        returns (H.Receipt memory receipt)
    {
        if (
            index
                >= uint256(IO.word(owner, abi.encodeCall(Native.artistNativeReceiptCount, ()), cap))
        ) revert O.InvalidArchiveOrigin();
        bytes memory raw =
            IO.fixedRead(owner, abi.encodeCall(Native.artistNativeReceiptAt, (index)), 128, cap);
        receipt = abi.decode(raw, (H.Receipt));
        IO.canonical(owner, raw, abi.encode(receipt));
    }

    function _revision(address owner, uint256 index, uint256 cap)
        private
        view
        returns (uint64 revision)
    {
        bytes memory raw = IO.fixedRead(
            owner, abi.encodeCall(Chronology.artistNativeReceiptRevisionAt, (index)), 32, cap
        );
        revision = abi.decode(raw, (uint64));
        IO.canonical(owner, raw, abi.encode(revision));
        if (revision == 0) revert O.InvalidArchiveOrigin();
    }

    function _snapshot(address owner, uint8 index, uint64 revision, uint256 cap) private view {
        bytes memory raw = IO.fixedRead(
            owner, abi.encodeCall(IStreamArtistOwner.ownerStateSnapshotV2, ()), 128, cap
        );
        A.Snapshot memory snapshot = abi.decode(raw, (A.Snapshot));
        IO.canonical(owner, raw, abi.encode(snapshot));
        if (
            snapshot.domainId != RH.ownerDomain(index) || revision == 0
                || revision > snapshot.revision
        ) revert O.InvalidArchiveOrigin();
    }

    function _publication(address owner, bytes32 record, uint256 cap)
        private
        view
        returns (Publication.Record memory saved)
    {
        bytes memory raw = IO.fixedRead(
            owner, abi.encodeCall(Publication.publicationAttestation, (record)), 704, cap
        );
        saved = abi.decode(raw, (Publication.Record));
        IO.canonical(owner, raw, abi.encode(saved));
    }

    function _content(address owner, bytes32 record, uint256 cap)
        private
        view
        returns (Content.ConsentRecord memory saved)
    {
        bytes memory raw = IO.fixedRead(
            owner, abi.encodeCall(Content.contentConsentRecord, (record)), 256, cap
        );
        saved = abi.decode(raw, (Content.ConsentRecord));
        IO.canonical(owner, raw, abi.encode(saved));
    }

    function _inputs(address actor, bytes32 context) private pure {
        if (actor == address(0) || context == 0) revert O.InvalidArchiveOrigin();
    }

    function _contentRole(O.ContentRole role) private pure returns (bytes32) {
        if (role == O.ContentRole.COLLECTION) {
            return keccak256("ORIGINAL_CONTENT_ROOT_AUTHORIZATION");
        }
        if (role == O.ContentRole.SCOPED) {
            return keccak256("ORIGINAL_SCOPED_CONTENT_ROOT_AUTHORIZATION");
        }
        if (role == O.ContentRole.POLICY_COLLECTION) {
            return keccak256("ORIGINAL_POLICY_CONTENT_ROOT_AUTHORIZATION_V2");
        }
        if (role == O.ContentRole.POLICY_SCOPED) {
            return keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_AUTHORIZATION_V2");
        }
        revert O.InvalidArchiveOrigin();
    }
}
