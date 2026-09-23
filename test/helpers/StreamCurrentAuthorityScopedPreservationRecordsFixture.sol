// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationStaticPrefixFixture
} from "./StreamCurrentAuthorityPreservationStaticPrefixFixture.sol";
import {
    StreamArtistOnboardingTypes as ScopedRecordArtist
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as ScopedRecordAuthority
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamArtistBindingOwner as ScopedBindingOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    StreamArtistRecordPublicationRules as ScopedPublicationRules
} from "../../smart-contracts/domains/artist/StreamArtistRecordPublicationRules.sol";
import {
    IStreamPreservationRecords as ScopedRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1 as ScopedMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamFinalityScope
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipFacts as ScopedMembershipFacts
} from "../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamMetadataSubjects as ScopedSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamWorkRecordTypes as ScopedWork
} from "../../smart-contracts/interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamWorkRecordDefinitions as ScopedWorkDefinitions
} from "../../smart-contracts/domains/records/StreamWorkRecordDefinitions.sol";
import {
    StreamWorkRecordJson as ScopedWorkJSON
} from "../../smart-contracts/domains/records/StreamWorkRecordJson.sol";
import {
    IStreamWorkRecordSelection as ScopedWorkSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import {
    StreamConservationRecordTypes as ScopedConservation
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    StreamConservationDefinitions as ScopedConservationDefinitions
} from "../../smart-contracts/domains/records/StreamConservationDefinitions.sol";
import {
    StreamArtistInterviewJson as ScopedInterviewJSON
} from "../../smart-contracts/domains/records/StreamArtistInterviewJson.sol";
import {
    StreamArtistIntentJson as ScopedIntentJSON
} from "../../smart-contracts/domains/records/StreamArtistIntentJson.sol";
import {
    IStreamConservationRecordSelection as ScopedConservationSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    Strings as ScopedRecordStrings
} from "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @notice Actual scope-aware op24 WORK, Interview and full Artist Intent publication and adoption.
/// @dev The caller registers the canonical subject, schema/profile documents and record policies.
/// Current original/successor owners are read from assemblySuite; no global dependency is changed.
/// Documentary reference bytes are deterministic fixture statements, not real-world testimony,
/// participant identity verification or external archive coverage. Returned bytes support later
/// genuine coverage; this helper never marks a reference covered. It does not publish Rights or
/// lock these heads, so a caller may append exact successors before separately sealing a scope.
abstract contract StreamCurrentAuthorityScopedPreservationRecordsFixture is
    StreamCurrentAuthorityPreservationStaticPrefixFixture
{
    struct ScopedRecordHeads {
        bytes32 workHead;
        uint64 workRevision;
        bytes32 intentHead;
        uint64 intentRevision;
        bytes32 interviewPredecessor;
        bytes32 contentTag;
    }

    /// @dev An exact prospective archive input. No archive receipt or delivery is implied.
    struct ScopedReferencePayload {
        bytes32 purpose;
        ScopedConservation.Reference sourceRef;
        bytes payload;
    }

    struct ScopedRecordSet {
        StreamFinalityScope scope;
        bytes32 subject;
        ScopedRecordArtist.Binding binding;
        ScopedWorkSelection.Witness work;
        ScopedConservationSelection.IntentWitness intent;
        ActualPublication workPublication;
        ActualPublication interviewPublication;
        ActualPublication intentPublication;
        bytes workPayload;
        bytes interviewPayload;
        bytes intentPayload;
        // 0..3 questionnaire, artist identity, interviewer identity, transcript;
        // 4..12 scale, timing, color, interaction, motion, frame rate, variability,
        // dependency aging, significant properties; 13 exact JCS Interview payload.
        ScopedReferencePayload[] references;
        ScopedWorkSelection.Selection previousWork;
        ScopedConservationSelection.Selection previousIntent;
        ScopedWorkSelection.Selection workSelection;
        ScopedConservationSelection.Selection intentSelection;
        // WORK_DESCRIPTION, ARTIST_STATEMENT and ARTIST_INTENT complete collection lanes.
        uint64[3] countsBefore;
        uint64[3] countsAfter;
        bytes32[3] chainsBefore;
        bytes32[3] chainsAfter;
    }

    function _publishScopedRecords(
        StreamFinalityScope memory scope,
        ScopedRecordHeads memory expected
    ) internal returns (ScopedRecordSet memory result) {
        require(
            scope.collectionId == 1 && expected.contentTag != 0,
            "explicit fixture collection and revision tag"
        );
        result.scope = scope;
        result.subject = ScopedSubjects.scopeSubject(block.chainid, address(assemblyCore), scope);
        ScopedMembershipFacts memory membership = assemblyMembership.requireScopeMembership(scope);
        require(
            membership.scopeSubject == result.subject && membership.tokenCount != 0,
            "actual complete scope membership matches local subject"
        );
        result.binding = _scopedRecordBinding();
        result.previousWork = assemblyWork.currentWork(1, result.subject);
        result.previousIntent = assemblyConservation.currentConservation(
            1, result.subject, ScopedConservation.StatementOrigin.ARTIST_INTENT
        );
        require(
            result.previousWork.recordHash == expected.workHead
                && result.previousWork.revision == expected.workRevision
                && result.previousIntent.record.recordHash == expected.intentHead
                && result.previousIntent.revision == expected.intentRevision,
            "exact previous selected heads and revisions"
        );
        if (expected.interviewPredecessor != 0) {
            (ScopedRecords.CollectionRecord memory predecessor,) =
                assemblyMetadata.collectionRecord(expected.interviewPredecessor);
            require(
                predecessor.subjectId == result.subject
                    && predecessor.recordType == keccak256("ARTIST_STATEMENT")
                    && predecessor.schemaId == ScopedConservationDefinitions.INTERVIEW_SCHEMA_ID,
                "explicit prior Interview belongs to this scope"
            );
        }
        bytes32[3] memory priorRecords =
            [expected.workHead, expected.interviewPredecessor, expected.intentHead];
        bytes32[3] memory priorHashes;
        for (uint256 i; i < 3; ++i) {
            priorHashes[i] = _scopedRecordOriginalHash(priorRecords[i]);
            (result.chainsBefore[i], result.countsBefore[i]) =
                assemblyMetadata.recordChainHash(1, _scopedRecordType(i));
        }
        result.references =
            _scopedRecordReferences(result.subject, expected.contentTag, result.binding);
        _scopedPublishWork(result, expected);
        _scopedPublishInterview(result, expected);
        _scopedPublishIntent(result, expected);
        _scopedVerifySelections(result, expected);
        for (uint256 i; i < 3; ++i) {
            (result.chainsAfter[i], result.countsAfter[i]) =
                assemblyMetadata.recordChainHash(1, _scopedRecordType(i));
            require(
                result.countsAfter[i] == result.countsBefore[i] + 1
                    && result.chainsAfter[i] != result.chainsBefore[i]
                    && _scopedRecordOriginalHash(priorRecords[i]) == priorHashes[i],
                "append each lane once while preserving prior original and receipt"
            );
        }
        require(
            result.workPublication.receipt.recordIndex == result.countsBefore[0]
                && result.interviewPublication.receipt.recordIndex == result.countsBefore[1]
                && result.intentPublication.receipt.recordIndex == result.countsBefore[2],
            "actual scoped append uses existing complete-lane indices"
        );
        if (expected.workRevision != 0) {
            require(
                keccak256(
                    abi.encode(
                        assemblyWork.workSelectionAt(1, result.subject, expected.workRevision)
                    )
                ) == keccak256(abi.encode(result.previousWork)),
                "prior Work selection immutable"
            );
        }
        if (expected.intentRevision != 0) {
            require(
                keccak256(
                    abi.encode(
                        assemblyConservation.conservationSelectionAt(
                            1,
                            result.subject,
                            ScopedConservation.StatementOrigin.ARTIST_INTENT,
                            expected.intentRevision
                        )
                    )
                ) == keccak256(abi.encode(result.previousIntent)),
                "prior Intent selection immutable"
            );
        }
    }

    function _scopedRecordBinding() private view returns (ScopedRecordArtist.Binding memory b) {
        ScopedRecordAuthority.Anchors memory original = assemblyAuthorityResolver.anchors();
        ScopedRecordAuthority.Selection memory selected =
            assemblyAuthorityResolver.currentSelection();
        require(
            assemblySuite.registry == address(assemblyArtists)
                && assemblyMetadata.artistRegistry() == original.targets[3]
                && assemblyMetadata.artistRegistryCodeHash() == original.codeHashes[3],
            "current fixture registry and preserved original Metadata Artist pin"
        );
        require(
            selected.selectionHash != 0
                && selected.selectionHash
                    == ScopedRecordAuthority.hashSelection(
                        original, selected.origin, selected.completion
                    ) && selected.origin.environment.chainId == block.chainid
                && selected.origin.environment.registry == assemblySuite.registry
                && selected.origin.registryCodeHash == assemblySuite.registry.codehash
                && selected.origin.environment.coordinator == address(assemblyCoordinator)
                && selected.origin.coordinatorCodeHash == address(assemblyCoordinator).codehash
                && selected.origin.environment.archive == assemblySuite.archive
                && selected.origin.archiveCodeHash == assemblySuite.archive.codehash
                && selected.origin.environment.core == assemblySuite.core
                && selected.origin.environment.manager == assemblySuite.mintManager
                && selected.origin.environment.suiteConfigurationHash
                    == keccak256(abi.encode(assemblySuite))
                && (assemblySuite.registry == original.targets[3] || selected.completion != 0),
            "resolver authenticates the complete selected current suite"
        );
        for (uint256 i; i < 7; ++i) {
            require(
                selected.origin.environment.owners[i] == assemblySuite.owners[i]
                    && selected.origin.environment.ownerCodeHashes[i]
                        == assemblySuite.owners[i].codehash,
                "all seven current owner identities and runtime pins"
            );
        }
        b = ScopedBindingOwner(assemblySuite.owners[0]).binding(1);
        require(
            b.accepted && b.artistAddress == address(assemblyArtist)
                && b.artistId == assemblyArtistId && b.generation != 0 && b.bindingHash != 0
                && b.identityRecordHash != 0,
            "current owner's actual accepted Safe binding"
        );
    }

    function _scopedPublishWork(ScopedRecordSet memory result, ScopedRecordHeads memory expected)
        private
    {
        ScopedWork.Description memory description;
        description.subjectId = result.subject;
        description.profileHash = ScopedWorkDefinitions.PROFILE_HASH;
        description.predecessor = expected.workHead;
        description.full.title = string.concat(
            "Scoped current-authority fixture ",
            ScopedRecordStrings.toHexString(uint256(expected.contentTag), 32)
        );
        description.full.creator = ScopedWork.Creator(
            ScopedWork.CreatorKind.ARTIST,
            result.binding.artistId,
            result.binding.generation,
            result.binding.bindingHash,
            ""
        );
        description.full.creation.start = 20240229;
        description.full.medium = "Generative JavaScript instructions";
        description.full.format.kind = ScopedWork.FormatKind.PRONOM;
        description.full.format.formatId = keccak256("PRONOM:fmt/111");
        description.full.format.puid = "fmt/111";
        description.full.measurements.kind = ScopedWork.MeasurementKind.DIMENSIONLESS_GENERATIVE;
        description.full.creditLine = "Source-authored fixture, signed by the actual Artist Safe";
        result.workPayload = ScopedWorkJSON.serialize(description);
        result.work = ScopedWorkSelection.Witness(
            _scopedRecord(
                _scopedRecordType(0),
                ScopedWorkDefinitions.SCHEMA_ID,
                result.subject,
                expected.contentTag,
                "work",
                result.workPayload
            ),
            description
        );
        _scopedPublicationProfile(result.work.original, 8, 1);
        result.workPublication =
            _publishCurrentAuthorityRecord(result.work.original, result.workPayload);
        _scopedRequirePublication(result.workPublication, result.binding, 8, 1);
        result.workSelection = assemblyWork.adoptArtistRecord(
            1,
            result.subject,
            result.workPublication.recordHash,
            expected.workHead,
            expected.workRevision,
            result.work
        );
    }

    function _scopedPublishInterview(
        ScopedRecordSet memory result,
        ScopedRecordHeads memory expected
    ) private {
        ScopedConservation.Interview memory interview;
        interview.subjectId = result.subject;
        interview.profileHash = ScopedConservationDefinitions.INTERVIEW_PROFILE_HASH;
        interview.predecessor = expected.interviewPredecessor;
        interview.instrument.kind = ScopedConservation.InstrumentKind.NAMED_DERIVATIVE;
        interview.instrument.name = "Source-authored conservation fixture questionnaire";
        interview.instrument.document = result.references[0].sourceRef;
        interview.participants = new ScopedConservation.Participant[](2);
        interview.participants[0] = ScopedConservation.Participant(
            ScopedConservation.ParticipantRole.ARTIST, "", result.references[1].sourceRef
        );
        interview.participants[1] = ScopedConservation.Participant(
            ScopedConservation.ParticipantRole.INTERVIEWER, "", result.references[2].sourceRef
        );
        interview.interviewDate = 20240229;
        interview.languages = new string[](1);
        interview.languages[0] = "en-US";
        interview.transcript.content = result.references[3].sourceRef;
        interview.transcript.format.kind = ScopedConservation.FormatKind.PRONOM;
        interview.transcript.format.formatId = keccak256("PRONOM:fmt/111");
        interview.transcript.format.puid = "fmt/111";
        interview.captures = new ScopedConservation.Capture[](0);
        result.interviewPayload = ScopedInterviewJSON.serialize(interview);
        result.intent.interview = ScopedConservationSelection.InterviewWitness(
            _scopedRecord(
                _scopedRecordType(1),
                ScopedConservationDefinitions.INTERVIEW_SCHEMA_ID,
                result.subject,
                expected.contentTag,
                "interview",
                result.interviewPayload
            ),
            interview
        );
        _scopedPublicationProfile(result.intent.interview.original, 8, 1);
        result.interviewPublication = _publishCurrentAuthorityRecord(
            result.intent.interview.original, result.interviewPayload
        );
        _scopedRequirePublication(result.interviewPublication, result.binding, 8, 1);
        result.references[13] = ScopedReferencePayload(
            keccak256("interview-jcs"),
            ScopedConservation.Reference(
                1,
                ScopedWorkDefinitions.CANON_ID,
                abi.encode(keccak256(result.interviewPayload)),
                _scopedReferenceURI(result.subject, expected.contentTag, "interview-jcs")
            ),
            result.interviewPayload
        );
    }

    function _scopedPublishIntent(ScopedRecordSet memory result, ScopedRecordHeads memory expected)
        private
    {
        ScopedConservation.Intent memory intent;
        intent.subjectId = result.subject;
        intent.profileHash = ScopedConservationDefinitions.INTENT_PROFILE_HASH;
        intent.predecessor = expected.intentHead;
        intent.artist = ScopedConservation.ArtistClaim(
            result.binding.artistId,
            result.binding.generation,
            result.binding.bindingHash,
            ScopedConservation.StatementOrigin.ARTIST_INTENT
        );
        intent.display = ScopedConservation.Display(
            result.references[4].sourceRef,
            result.references[5].sourceRef,
            result.references[6].sourceRef,
            result.references[7].sourceRef,
            result.references[8].sourceRef,
            result.references[9].sourceRef
        );
        intent.variabilityTolerances = result.references[10].sourceRef;
        intent.dependencyAging = result.references[11].sourceRef;
        intent.significantProperties = result.references[12].sourceRef;
        intent.interview.status = ScopedConservation.InterviewStatus.PRESENT;
        intent.interview.record = ScopedConservation.InterviewRecord(
            block.chainid,
            address(assemblyCore),
            address(assemblyMetadata),
            result.interviewPublication.recordHash,
            ScopedConservationDefinitions.INTERVIEW_SCHEMA_ID,
            ScopedConservationDefinitions.INTERVIEW_PROFILE_HASH,
            result.references[13].sourceRef
        );
        result.intent.intent = intent;
        result.intentPayload = ScopedIntentJSON.serialize(intent);
        result.intent.original = _scopedRecord(
            _scopedRecordType(2),
            ScopedConservationDefinitions.INTENT_SCHEMA_ID,
            result.subject,
            expected.contentTag,
            "intent",
            result.intentPayload
        );
        _scopedPublicationProfile(result.intent.original, 7, 64);
        result.intentPublication =
            _publishCurrentAuthorityRecord(result.intent.original, result.intentPayload);
        _scopedRequirePublication(result.intentPublication, result.binding, 7, 64);
        result.intentSelection = assemblyConservation.adoptIntent(
            1,
            result.subject,
            result.intentPublication.recordHash,
            expected.intentHead,
            expected.intentRevision,
            result.intent
        );
    }

    function _scopedVerifySelections(
        ScopedRecordSet memory result,
        ScopedRecordHeads memory expected
    ) private view {
        ScopedWorkSelection.Selection memory work = result.workSelection;
        require(
            work.recordHash == result.workPublication.recordHash
                && work.predecessor == expected.workHead
                && work.revision == expected.workRevision + 1 && work.selectionHash != 0
                && work.payloadHash == keccak256(result.workPayload)
                && work.mode == ScopedWorkSelection.AdoptionMode.ARTIST_RECORD_ADOPTION
                && work.recorder == address(assemblyArtist) && work.recorderAuthorizationClass == 1
                && work.recordIndex == result.workPublication.receipt.recordIndex
                && work.recordChainHash == result.workPublication.receipt.recordChainHash
                && keccak256(abi.encode(work.artistPublication))
                    == keccak256(abi.encode(result.workPublication.evidence))
                && work.artistPublicationEvidenceHash
                    == _scopedPublicationHash(result.workPublication),
            "actual Work op24 adoption and complete publication witness"
        );
        require(
            work.creatorAssociation.artistId == result.binding.artistId
                && work.creatorAssociation.bindingHash == result.binding.bindingHash
                && work.creatorAssociation.generation == result.binding.generation
                && work.creatorAssociation.identityRecordHash == result.binding.identityRecordHash,
            "selected Work uses the current actual binding claim"
        );
        ScopedConservationSelection.Selection memory selected = result.intentSelection;
        require(
            selected.record.recordHash == result.intentPublication.recordHash
                && selected.record.kind == ScopedConservationSelection.RecordKind.INTENT
                && selected.record.payloadHash == keccak256(result.intentPayload)
                && selected.predecessor == expected.intentHead
                && selected.revision == expected.intentRevision + 1 && selected.selectionHash != 0
                && selected.origin == ScopedConservation.StatementOrigin.ARTIST_INTENT
                && selected.interviewStatus == ScopedConservation.InterviewStatus.PRESENT
                && selected.interview.recordHash == result.interviewPublication.recordHash
                && selected.interview.kind == ScopedConservationSelection.RecordKind.INTERVIEW
                && selected.interview.payloadHash == keccak256(result.interviewPayload)
                && selected.interviewPayloadCorrespondence
                    == ScopedConservationSelection.PayloadCorrespondence.EXACT_JCS_KECCAK256
                && selected.interviewArchiveReferenceHash
                    == keccak256(abi.encode(result.references[13].sourceRef)),
            "full Intent and exact PRESENT original Interview correspondence"
        );
        require(
            keccak256(abi.encode(selected.record.publication))
                    == keccak256(abi.encode(result.intentPublication.evidence))
                && keccak256(abi.encode(selected.interview.publication))
                    == keccak256(abi.encode(result.interviewPublication.evidence))
                && selected.record.recordIndex == result.intentPublication.receipt.recordIndex
                && selected.interview.recordIndex == result.interviewPublication.receipt.recordIndex
                && selected.record.receiptHash
                    == keccak256(abi.encode(result.intentPublication.receipt))
                && selected.interview.receiptHash
                    == keccak256(abi.encode(result.interviewPublication.receipt))
                && selected.record.publicationEvidenceHash
                    == _scopedPublicationHash(result.intentPublication)
                && selected.interview.publicationEvidenceHash
                    == _scopedPublicationHash(result.interviewPublication)
                && selected.association.artistId == result.binding.artistId
                && selected.association.bindingHash == result.binding.bindingHash
                && selected.association.generation == result.binding.generation
                && selected.association.identityRecordHash == result.binding.identityRecordHash,
            "actual Intent and Interview publication classes and current association"
        );
        require(
            keccak256(
                abi.encode(
                    assemblyWork.requireCurrent(1, result.subject, work.recordHash, work.revision)
                )
            ) == keccak256(abi.encode(work)),
            "actual Work currentness"
        );
        require(
            keccak256(
                abi.encode(
                    assemblyConservation.requireCurrent(
                        1,
                        result.subject,
                        ScopedConservation.StatementOrigin.ARTIST_INTENT,
                        selected.record.recordHash,
                        selected.revision
                    )
                )
            ) == keccak256(abi.encode(selected)),
            "actual Conservation currentness"
        );
        for (uint256 i; i < result.references.length; ++i) {
            ScopedReferencePayload memory ref = result.references[i];
            require(
                ref.payload.length != 0 && ref.sourceRef.algorithm == 1
                    && ref.sourceRef.canonicalizationId
                        == (i == 13 ? ScopedWorkDefinitions.CANON_ID : keccak256("RAW_BYTES"))
                    && keccak256(ref.sourceRef.digest)
                        == keccak256(abi.encode(keccak256(ref.payload))),
                "every prospective reference has exact exposed bytes; no archive proof implied"
            );
        }
    }

    function _scopedPublicationProfile(
        ScopedRecords.CollectionRecord memory record,
        uint8 kind,
        uint32 capability
    ) private pure {
        (uint8 actualKind, uint32 actualCapability) =
            ScopedPublicationRules.family(record.recordType, record.schemaId);
        require(
            actualKind == kind && actualCapability == capability,
            "exact admitted op24 record profile"
        );
    }

    function _scopedRequirePublication(
        ActualPublication memory publication,
        ScopedRecordArtist.Binding memory binding_,
        uint8 kind,
        uint32 capability
    ) private view {
        require(
            publication.attestation.subjectKind == kind
                && publication.evidence.requiredCapability == capability
                && publication.evidence.authorityClass == 1
                && publication.evidence.signer == address(assemblyArtist)
                && publication.evidence.artistId == binding_.artistId
                && publication.evidence.bindingGeneration == binding_.generation
                && publication.evidence.bindingHash == binding_.bindingHash,
            "actual selected owner op24 evidence with exact capability and subject kind"
        );
    }

    /// @dev The selector hashes the full static publication-owner Record, including its Metadata pin.
    function _scopedPublicationHash(ActualPublication memory publication)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                publication.publication, publication.evidence, address(assemblyMetadata).codehash
            )
        );
    }

    function _scopedRecord(
        bytes32 recordType,
        bytes32 schema,
        bytes32 subject,
        bytes32 tag,
        string memory name,
        bytes memory raw
    ) private view returns (ScopedRecords.CollectionRecord memory record) {
        record.recordType = recordType;
        record.subjectId = subject;
        record.schemaId = schema;
        record.contentHash =
            ScopedRecords.HashRef(1, abi.encode(keccak256(raw)), ScopedWorkDefinitions.CANON_ID);
        record.uri = _scopedReferenceURI(subject, tag, name);
        require(block.timestamp <= type(uint64).max);
        record.effectiveAt = uint64(block.timestamp);
    }

    function _scopedRecordReferences(
        bytes32 subject,
        bytes32 tag,
        ScopedRecordArtist.Binding memory binding_
    ) private pure returns (ScopedReferencePayload[] memory references) {
        string[13] memory names = [
            string("questionnaire"),
            "artist-identity",
            "interviewer-identity",
            "transcript",
            "scale",
            "timing",
            "color",
            "interaction",
            "motion",
            "frame-rate",
            "variability",
            "dependency-aging",
            "significant-properties"
        ];
        references = new ScopedReferencePayload[](14);
        for (uint256 i; i < names.length; ++i) {
            bytes memory payload = bytes(
                string.concat(
                    "SOURCE-AUTHORED FIXTURE DOCUMENT. Purpose: ",
                    names[i],
                    ". Scope: ",
                    ScopedRecordStrings.toHexString(uint256(subject), 32),
                    ". Revision: ",
                    ScopedRecordStrings.toHexString(uint256(tag), 32),
                    ". Actual Artist binding: ",
                    ScopedRecordStrings.toHexString(uint256(binding_.bindingHash), 32),
                    ". This fixture supplies deterministic preservation bytes; no real-world interview, identity verification or archive delivery is asserted."
                )
            );
            references[i] = ScopedReferencePayload(
                keccak256(bytes(names[i])),
                ScopedConservation.Reference(
                    1,
                    keccak256("RAW_BYTES"),
                    abi.encode(keccak256(payload)),
                    _scopedReferenceURI(subject, tag, names[i])
                ),
                payload
            );
        }
    }

    function _scopedReferenceURI(bytes32 subject, bytes32 tag, string memory name)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            "https://fixtures.example.invalid/scoped-records/",
            ScopedRecordStrings.toHexString(uint256(subject), 32),
            "/",
            ScopedRecordStrings.toHexString(uint256(tag), 32),
            "/",
            name
        );
    }

    function _scopedRecordOriginalHash(bytes32 recordHash) private view returns (bytes32) {
        if (recordHash == 0) return bytes32(0);
        (
            ScopedRecords.CollectionRecord memory record,
            ScopedMetadata.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        (, bytes memory raw) = assemblyMetadata.recordPayload(recordHash);
        return keccak256(abi.encode(record, receipt, raw));
    }

    function _scopedRecordType(uint256 index) private pure returns (bytes32) {
        require(index < 3);
        return index == 0
            ? keccak256("WORK_DESCRIPTION")
            : index == 1 ? keccak256("ARTIST_STATEMENT") : keccak256("ARTIST_INTENT");
    }
}
