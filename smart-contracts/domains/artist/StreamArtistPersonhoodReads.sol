// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPersonhoodTypes as P,
    IStreamArtistPersonhoodReadFrame
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    IStreamArtistSuiteReads
} from "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import {
    IStreamArtistBindingOwner
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistIdentityRevisionReads
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    StreamGeneralAttestationReads as Bounded
} from "../metadata/StreamGeneralAttestationReads.sol";
import { StreamArtistAttributionStateTypes } from "./StreamArtistAttributionStateTypes.sol";
import { StreamArtistC2PACredentials } from "./StreamArtistC2PACredentials.sol";
import { StreamArtistPersonhoodSummary } from "./StreamArtistPersonhoodSummary.sol";
import { StreamArtistPersonhoodCurrent } from "./StreamArtistPersonhoodCurrent.sol";
import {
    StreamArtistPersonhoodDefinitions as Definitions
} from "./StreamArtistPersonhoodDefinitions.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Documentary status of the exact original native personhood head.
library StreamArtistPersonhoodReads {
    function read(
        StreamArtistAttributionStateTypes.State storage s,
        uint256 collectionId,
        bytes32 artist
    ) public view returns (P.Selection memory result) {
        bytes32 key = StreamArtistC2PACredentials.personhoodKey(collectionId, artist);
        result.nativeRecord = key != 0
            ? s.records[key]
            : s.attestations[keccak256(abi.encode(collectionId, uint8(10), artist))];
        if (
            result.nativeRecord.recordHash == 0
                || !StreamArtistC2PACredentials.isPersonhood(result.nativeRecord.schemaId)
        ) {
            delete result.nativeRecord;
            return result;
        }
        result.sourceRegistry = StreamArtistPersonhoodSummary.origin(result.nativeRecord.recordHash);
        bool evidence = result.nativeRecord.schemaId == Definitions.EVIDENCE_SCHEMA;
        P.Summary memory summary = StreamArtistPersonhoodSummary.get(result.nativeRecord.recordHash);
        bool admitted = evidence && summary.version == 1
            && summary.nativeRecordHash == result.nativeRecord.recordHash
            && summary.statementHash == result.nativeRecord.statementHash
            && summary.artistId == artist && summary.collectionId == collectionId
            && summary.identityRecordHash == result.nativeRecord.subjectStateHash
            && summary.generation == result.nativeRecord.generation
            && summary.evidenceReference.artistRegistry == result.sourceRegistry;
        if (admitted) result.evidenceReference = summary.evidenceReference;
        result.status = P.Status.UNRESOLVED;
        try IStreamArtistPersonhoodReadFrame(address(this))
            .personhoodResolution(collectionId, artist, result.nativeRecord, admitted) returns (
            bool current, P.NotarizationFacts memory f
        ) {
            result.identityCurrent = current;
            result.notarizationType = f.attestationType;
            result.recorder = f.recorder;
            result.notarizationHead = f.head;
            result.notarizationCurrent = f.current;
            if (!evidence) {
                result.status = current ? P.Status.WAIVER : P.Status.STALE;
            } else if (admitted) {
                result.status = current && f.current ? P.Status.RESOLVED : P.Status.STALE;
            }
        } catch { }
    }

    function resolve(
        StreamArtistHashes.Environment memory e,
        address coordinator,
        uint256 collectionId,
        bytes32 artist,
        T.AttestationRecord memory record,
        bool checkEvidence
    ) public view returns (bool current, P.NotarizationFacts memory facts) {
        if (e.chainId != block.chainid) revert P.InvalidPersonhoodReference();
        uint256 cap = StreamArtistPersonhoodCurrent.cap(e.registry);
        bytes memory raw = Bounded.fixedRead(
            coordinator, abi.encodeCall(IStreamArtistSuiteReads.suiteConfiguration, ()), 544, cap
        );
        T.SuiteConfiguration memory suite = abi.decode(raw, (T.SuiteConfiguration));
        if (
            keccak256(raw) != keccak256(abi.encode(suite)) || suite.registry != e.registry
                || suite.core != e.core || suite.owners[4] != address(this)
        ) revert P.InvalidPersonhoodReference();
        raw = Bounded.bounded(
            suite.owners[0],
            abi.encodeCall(IStreamArtistBindingOwner.binding, (collectionId)),
            4096,
            cap
        );
        T.Binding memory binding_ = abi.decode(raw, (T.Binding));
        if (keccak256(raw) != keccak256(abi.encode(binding_))) {
            revert P.InvalidPersonhoodReference();
        }
        bytes32 identity = abi.decode(
            Bounded.fixedRead(
                suite.owners[2],
                abi.encodeCall(
                    IStreamArtistIdentityRevisionReads.operativeIdentityRecord, (artist)
                ),
                32,
                cap
            ),
            (bytes32)
        );
        current = binding_.accepted && binding_.artistId == artist
            && binding_.generation == record.generation && identity != 0
            && identity == record.subjectStateHash;
        if (checkEvidence) {
            P.Summary memory summary = StreamArtistPersonhoodSummary.get(record.recordHash);
            current = current && summary.bindingHash == binding_.bindingHash;
            facts = StreamArtistPersonhoodCurrent.read(summary, cap);
        }
    }
}
