// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPersonhoodTypes as P,
    IStreamArtistPersonhoodEvidence
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistSuiteReads
} from "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import {
    StreamGeneralAttestationReads as Reads
} from "../metadata/StreamGeneralAttestationReads.sol";
import { StreamArtistPersonhoodJSON } from "./StreamArtistPersonhoodJSON.sol";
import { StreamArtistPersonhoodProof } from "./StreamArtistPersonhoodProof.sol";
import {
    StreamArtistPersonhoodDefinitions as Definitions
} from "./StreamArtistPersonhoodDefinitions.sol";
import { StreamArtistHistoryProof } from "./StreamArtistHistoryProof.sol";
import { StreamArtistHydrationGuards } from "./StreamArtistHydrationGuards.sol";
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";

/// @notice Derived, immutable documentary summaries inside the original op24/op60 transaction.
/// @dev No external owner mutation, independent nonce, new signer, or caller-selected source owner.
library StreamArtistPersonhoodSummary {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOFS_V1");
    bytes32 private constant TAG = keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1");

    struct State {
        mapping(bytes32 => address) origins;
        mapping(bytes32 => P.Summary) summaries;
        mapping(bytes32 => bytes32) hashes;
    }
    event ArtistPersonhoodProofRetained(
        uint16 schemaVersion,
        bytes32 indexed nativeRecordHash,
        address indexed originalRegistry,
        bytes32 summaryHash,
        P.Summary summary
    );

    function state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function note(
        address origin,
        bytes32 artist,
        bytes32 bindingHash,
        T.Attestation memory terms,
        T.AttestationRecord memory record,
        bytes memory statement,
        bool fresh
    ) public {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        address registry = owner.artistRegistry();
        address coordinator = owner.operationCoordinator();
        if (
            msg.sender != coordinator || origin == address(0) || record.recordHash == 0
                || terms.subjectKind != 10 || terms.subjectId != artist || artist == 0
                || bindingHash == 0 || record.generation == 0 || terms.schemaId != record.schemaId
                || terms.subjectStateHash != record.subjectStateHash
                || terms.statementHash != record.statementHash
                || keccak256(statement) != record.statementHash
                || state().origins[record.recordHash] != address(0)
        ) revert P.InvalidPersonhoodReference();
        uint256 cap = StreamArtistHistoryProof.cap(registry);
        T.SuiteConfiguration memory suite = _suite(coordinator, cap);
        if (
            suite.registry != registry || suite.owners[4] != address(this)
                || suite.core != owner.core()
        ) revert P.InvalidPersonhoodReference();
        if (fresh
                ? origin != registry
                : (origin == registry || StreamArtistHydrationGuards.commitment() == 0)) revert P.InvalidPersonhoodReference();
        state().origins[record.recordHash] = origin;
        if (record.schemaId != Definitions.EVIDENCE_SCHEMA) return; // Original explicit waiver remains separate.
        (bool canonical, P.Reference memory p) = StreamArtistPersonhoodJSON.tryDecode(statement);
        if (!canonical) return; // Opaque historical evidence never obtains a validated summary.
        if (
            p.artistRegistry != origin || p.artistId != artist
                || p.operativeIdentityRecordHash != record.subjectStateHash
        ) revert P.InvalidPersonhoodReference();
        P.Summary memory summary;
        if (fresh) {
            (summary,) = StreamArtistPersonhoodProof.verify(suite.core, p, cap, true);
            summary.nativeRecordHash = record.recordHash;
            summary.statementHash = record.statementHash;
            summary.artistId = artist;
            summary.bindingHash = bindingHash;
            summary.generation = record.generation;
            summary.collectionId = terms.collectionId;
            summary.identityRecordHash = record.subjectStateHash;
        } else {
            address sourceCoordinator =
                _address(origin, abi.encodeWithSignature("operationCoordinator()"), cap);
            T.SuiteConfiguration memory original = _suite(sourceCoordinator, cap);
            address sourceOwner = original.owners[4];
            if (
                original.registry != origin || original.core != suite.core
                    || sourceOwner == address(this) || sourceOwner.code.length == 0
                    || sourceCoordinator.code.length == 0
                    || _address(
                            sourceOwner, abi.encodeCall(IStreamArtistOwner.artistRegistry, ()), cap
                        ) != origin
                    || _address(
                            sourceOwner,
                            abi.encodeCall(IStreamArtistOwner.operationCoordinator, ()),
                            cap
                        ) != sourceCoordinator
                    || _address(sourceOwner, abi.encodeCall(IStreamArtistOwner.core, ()), cap)
                        != suite.core
            ) revert P.InvalidPersonhoodReference();
            // Exactly 48 static words. Legacy/unsupported owners cannot fabricate an empty proof.
            bytes memory raw = Reads.fixedRead(
                sourceOwner,
                abi.encodeCall(
                    IStreamArtistPersonhoodEvidence.personhoodProofSummary, (record.recordHash)
                ),
                1536,
                cap
            );
            summary = abi.decode(raw, (P.Summary));
            if (keccak256(raw) != keccak256(abi.encode(summary))) {
                revert P.InvalidPersonhoodReference();
            }
            bytes32 retainedHash = abi.decode(
                Reads.fixedRead(
                    sourceOwner,
                    abi.encodeCall(
                        IStreamArtistPersonhoodEvidence.personhoodProofSummaryHash,
                        (record.recordHash)
                    ),
                    32,
                    cap
                ),
                (bytes32)
            );
            if (retainedHash == 0 || retainedHash != keccak256(abi.encode(TAG, summary))) {
                revert P.InvalidPersonhoodReference();
            }
            // The full original import has independently rehashed this native record and all journals.
            // This join only copies its source owner's immutable summary, never today's replacement report.
            if (
                summary.nativeRecordHash != record.recordHash
                    || summary.statementHash != record.statementHash || summary.artistId != artist
                    || summary.bindingHash != bindingHash
                    || summary.collectionId != terms.collectionId
                    || summary.generation != record.generation
                    || summary.identityRecordHash != record.subjectStateHash
                    || keccak256(abi.encode(summary.evidenceReference)) != keccak256(abi.encode(p))
            ) revert P.InvalidPersonhoodReference();
        }
        if (
            summary.version != 1 || summary.chainId != block.chainid || summary.documentaryHash == 0
                || summary.originalRegistryCodeHash != origin.codehash || summary.core != suite.core
                || summary.coreCodeHash != suite.core.codehash
        ) revert P.InvalidPersonhoodReference();
        bytes32 hash = keccak256(abi.encode(TAG, summary));
        state().summaries[record.recordHash] = summary;
        state().hashes[record.recordHash] = hash;
        StreamArtistPayloadStore.store(
            keccak256("ARTIST_PERSONHOOD_PROOF_SUMMARY"), abi.encode(TAG, summary)
        );
        emit ArtistPersonhoodProofRetained(1, record.recordHash, origin, hash, summary);
    }

    function origin(bytes32 record) public view returns (address) {
        return state().origins[record];
    }

    function get(bytes32 record) public view returns (P.Summary memory s) {
        s = state().summaries[record];
        if (
            s.version != 0
                && (s.nativeRecordHash != record
                    || state().hashes[record] != keccak256(abi.encode(TAG, s)))
        ) revert P.InvalidPersonhoodReference();
    }

    function hashOf(bytes32 record) public view returns (bytes32) {
        get(record); // Validate the stored summary against this retained hash before serving it.
        return state().hashes[record];
    }

    function audit(bytes32 record) public view returns (bytes32, P.NotarizationFacts memory facts) {
        P.Summary memory s = get(record);
        if (s.version != 1) revert P.InvalidPersonhoodReference();
        uint256 cap =
            StreamArtistHistoryProof.cap(IStreamArtistOwner(address(this)).artistRegistry());
        P.Summary memory documentary;
        (documentary, facts) =
            StreamArtistPersonhoodProof.verify(s.core, s.evidenceReference, cap, false);
        if (documentary.documentaryHash != s.documentaryHash) {
            revert P.InvalidPersonhoodReference();
        }
        return (s.documentaryHash, facts);
    }

    function _suite(address coordinator, uint256 cap)
        private
        view
        returns (T.SuiteConfiguration memory s)
    {
        bytes memory raw = Reads.fixedRead(
            coordinator, abi.encodeCall(IStreamArtistSuiteReads.suiteConfiguration, ()), 544, cap
        );
        s = abi.decode(raw, (T.SuiteConfiguration));
        if (keccak256(raw) != keccak256(abi.encode(s))) revert P.InvalidPersonhoodReference();
    }

    function _address(address target, bytes memory input, uint256 cap)
        private
        view
        returns (address)
    {
        return abi.decode(Reads.fixedRead(target, input, 32, cap), (address));
    }
}
