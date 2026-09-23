// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamFinalityConservationTypes.sol";
import "../../interfaces/stream/metadata/IStreamCollectionRecordReceipts.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../records/StreamConservationDefinitions.sol";
import "../records/StreamWorkRecordDefinitions.sol";

/// @notice Current conservation facts from a fixed original-record selector and receipt host.
/// @dev The consuming provider supplies constructor-fixed addresses/code pins, including a
/// predicted late selector if needed. Success proves current facts, not finality readiness:
/// sanction, lock/exception policy, scope membership and complete archives remain independent.
/// Historical finalized inputs must use their saved evidence, never this current eligibility API.
library StreamFinalityConservationReads {
    struct Dependencies {
        // Core, generic metadata, schemas, byte store, conservation selector.
        address[5] targets;
        bytes32[5] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 selectionGas;
    }

    error ConservationConfiguration();
    error ConservationDependency(address target);
    error ConservationRead(address target, bytes4 selector);
    error ConservationSelection(bytes32 recordHash);
    error ConservationReceipt(bytes32 recordHash);
    error ConservationLock(bytes32 recordHash);

    /// @notice Requires the current original ARTIST_INTENT lineage, without estate fallback.
    /// @dev An unlocked result is explicit. No zero-reference/non-artist default is returned.
    function requireCurrent(Dependencies memory d, StreamFinalityScope memory scope)
        public
        view
        returns (StreamFinalityConservationEvidence memory e)
    {
        _bindings(d);
        e.scopeSubject = StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
        e.selected = _selected(d, scope.collectionId, e.scopeSubject);
        _original(d, scope.collectionId, e.selected.record, e.selected.association, false);
        if (e.selected.record.kind == IStreamConservationRecordSelection.RecordKind.INTENT) {
            e.intentRecordHash = e.selected.record.recordHash;
        } else if (
            e.selected.record.kind == IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER
        ) {
            e.intentWaiverRecordHash = e.selected.record.recordHash;
        } else {
            revert ConservationSelection(e.selected.record.recordHash);
        }
        _interview(d, scope.collectionId, e.selected);
        e.intentLock = _lock(d, scope.collectionId, e.scopeSubject, e.selected);
        e.interviewEvidenceHash = _interviewCommitment(d, scope, e.scopeSubject, e.selected);
        e.archiveRequirement =
        StreamConservationArchiveRequirement.DUAL_FAMILY_REFERENCES_AND_SIGNATURE_BUNDLES;
    }

    /// @notice The narrower policy additionally requires the exact current artist intent lock.
    /// @dev A matching lock still does not prove sanction, archive coverage or complete finality.
    function requireLocked(Dependencies memory d, StreamFinalityScope memory scope)
        public
        view
        returns (StreamFinalityConservationEvidence memory e)
    {
        e = requireCurrent(d, scope);
        if (!e.intentLock.locked) revert ConservationLock(e.selected.record.recordHash);
    }

    function _selected(Dependencies memory d, uint256 cid, bytes32 subject)
        private
        view
        returns (IStreamConservationRecordSelection.Selection memory s)
    {
        bytes memory raw = _read(
            d.targets[4],
            abi.encodeCall(
                IStreamConservationRecordSelection.currentConservation,
                (cid, subject, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT)
            ),
            1600,
            d.readGas
        );
        s = abi.decode(raw, (IStreamConservationRecordSelection.Selection));
        if (
            s.record.recordHash == 0 || s.record.payloadHash == 0 || s.revision == 0
                || s.origin != StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                || s.association.artistId == 0 || s.association.bindingHash == 0
                || s.association.generation == 0 || s.association.identityRecordHash == 0
                || s.submitter == address(0) || s.selectedAt == 0
                || s.selectedAt < s.record.recordedAt || s.selectedAt > block.timestamp
                || s.catalogsHash == 0 || keccak256(raw) != keccak256(abi.encode(s))
        ) revert ConservationSelection(s.record.recordHash);
        bytes32 retained = s.selectionHash;
        s.selectionHash = 0;
        bytes32 computed = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_SELECTION_V1"),
                d.chainId,
                d.targets[4],
                d.targets[0],
                d.targets[1],
                d.targets[2],
                d.targets[3],
                cid,
                subject,
                s
            )
        );
        s.selectionHash = retained;
        if (retained != computed) revert ConservationSelection(s.record.recordHash);
        bytes memory current = _read(
            d.targets[4],
            abi.encodeCall(
                IStreamConservationRecordSelection.requireCurrent,
                (cid, subject, s.origin, s.record.recordHash, s.revision)
            ),
            1600,
            d.selectionGas
        );
        if (keccak256(current) != keccak256(raw)) {
            revert ConservationSelection(s.record.recordHash);
        }
        // That exact selector rechecks the full current graph, accepted/sanctioned association,
        // all nine fixed definition bytes and every complete selected catalog. Original signer
        // authority was proven on adoption and is not substituted with today's operative key.
    }

    function _interview(
        Dependencies memory d,
        uint256 cid,
        IStreamConservationRecordSelection.Selection memory s
    ) private view {
        if (s.interviewStatus == StreamConservationRecordTypes.InterviewStatus.PRESENT) {
            if (
                s.interview.kind != IStreamConservationRecordSelection.RecordKind.INTERVIEW
                    || s.interviewArchiveReferenceHash == 0
            ) revert ConservationSelection(s.record.recordHash);
            _original(d, cid, s.interview, s.association, true);
        } else {
            IStreamConservationRecordSelection.RecordEvidence memory empty;
            if (
                keccak256(abi.encode(s.interview)) != keccak256(abi.encode(empty))
                    || s.interviewArchiveReferenceHash != 0
                    || s.interviewPayloadCorrespondence
                        != IStreamConservationRecordSelection.PayloadCorrespondence
                            .UNVERIFIED_REFERENCE
            ) revert ConservationSelection(s.record.recordHash);
        }
    }

    function _original(
        Dependencies memory d,
        uint256 cid,
        IStreamConservationRecordSelection.RecordEvidence memory e,
        IStreamConservationRecordSelection.Association memory a,
        bool interview
    ) private view {
        StreamArtistRecordPublicationTypes.Evidence memory p = e.publication;
        if (
            e.recordHash == 0 || e.payloadHash == 0 || e.recorder == address(0) || e.recordedAt == 0
                || e.recordChainHash == 0 || e.receiptHash == 0 || e.publicationEvidenceHash == 0
                || p.attestationRecordHash == 0 || p.artistId != a.artistId
                || p.bindingHash != a.bindingHash || p.bindingGeneration != a.generation
                || p.signer != e.recorder
                || (interview
                        ? (p.authorityClass != 1 && p.authorityClass != 3)
                        : p.authorityClass != 1) || p.requiredCapability != (interview ? 1 : 64)
                || p.signedAt == 0 || p.signedAt > e.recordedAt || p.publicationHash == 0
        ) revert ConservationReceipt(e.recordHash);
        bytes memory raw = _read(
            d.targets[1],
            abi.encodeCall(IStreamCollectionRecordReceipts.collectionRecordReceipt, (e.recordHash)),
            288,
            d.readGas
        );
        IStreamCollectionMetadataV1.RecordReceipt memory r =
            abi.decode(raw, (IStreamCollectionMetadataV1.RecordReceipt));
        bytes32 schemaHash = interview
            ? StreamConservationDefinitions.INTERVIEW_SCHEMA_HASH
            : e.kind == IStreamConservationRecordSelection.RecordKind.INTENT
                ? StreamConservationDefinitions.INTENT_SCHEMA_HASH
                : StreamConservationDefinitions.WAIVER_SCHEMA_HASH;
        if (
            keccak256(raw) != keccak256(abi.encode(r)) || keccak256(raw) != e.receiptHash
                || r.collectionId != cid || r.recorder != e.recorder || r.authorizationClass != 1
                || r.recordedAt != e.recordedAt || r.recordIndex != e.recordIndex
                || r.recordChainHash != e.recordChainHash || r.schemaDefinitionHash != schemaHash
                || r.canonicalizationDefinitionHash != StreamWorkRecordDefinitions.CANON_HASH
                || r.artistAuthorization != p.attestationRecordHash
        ) revert ConservationReceipt(e.recordHash);
        bytes32 recordType = interview
            ? keccak256("ARTIST_STATEMENT")
            : e.kind == IStreamConservationRecordSelection.RecordKind.INTENT
                ? keccak256("ARTIST_INTENT")
                : keccak256("ARTIST_INTENT_WAIVER");
        _word(
            d,
            1,
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordHashAt, (cid, recordType, r.recordIndex)
            ),
            e.recordHash
        );
        _word(
            d,
            1,
            abi.encodeWithSignature(
                "consumedArtistAuthorization(bytes32)", p.attestationRecordHash
            ),
            bytes32(uint256(1))
        );
    }

    function _lock(
        Dependencies memory d,
        uint256 cid,
        bytes32 subject,
        IStreamConservationRecordSelection.Selection memory s
    ) private view returns (IStreamConservationRecordSelection.IntentLock memory locked) {
        bytes memory raw = _read(
            d.targets[4],
            abi.encodeCall(IStreamConservationRecordSelection.intentLock, (cid, subject)),
            288,
            d.readGas
        );
        locked = abi.decode(raw, (IStreamConservationRecordSelection.IntentLock));
        if (keccak256(raw) != keccak256(abi.encode(locked))) {
            revert ConservationLock(s.record.recordHash);
        }
        if (locked.locked) {
            if (
                locked.locker == address(0) || locked.artistId != s.association.artistId
                    || locked.identityRecordHash != s.association.identityRecordHash
                    || locked.bindingHash != s.association.bindingHash
                    || locked.bindingGeneration != s.association.generation
                    || locked.recordHash != s.record.recordHash || locked.revision != s.revision
                    || locked.lockedAt < s.selectedAt || locked.lockedAt > block.timestamp
            ) revert ConservationLock(s.record.recordHash);
        } else {
            IStreamConservationRecordSelection.IntentLock memory empty;
            if (keccak256(raw) != keccak256(abi.encode(empty))) {
                revert ConservationLock(s.record.recordHash);
            }
        }
    }

    function _interviewCommitment(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 subject,
        IStreamConservationRecordSelection.Selection memory s
    ) private pure returns (bytes32) {
        // The exact parent payload commits the complete mandatory interview declaration. For
        // WAIVED there is no separately extracted Reference/subobject hash or interview record.
        bytes32 domain = s.interviewStatus == StreamConservationRecordTypes.InterviewStatus.PRESENT
            ? keccak256("6529STREAM_FINALITY_PRESENT_INTERVIEW_V1")
            : keccak256("6529STREAM_FINALITY_WAIVED_INTERVIEW_V1");
        return keccak256(
            abi.encode(
                domain,
                d.chainId,
                d.targets,
                scope,
                subject,
                s,
                StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
                StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
            )
        );
    }

    function _bindings(Dependencies memory d) private view {
        if (
            block.chainid != d.chainId || d.readGas == 0 || d.selectionGas < d.readGas
                || d.selectionGas > type(uint256).max / 64
        ) revert ConservationConfiguration();
        for (uint256 i; i < 5; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert ConservationDependency(d.targets[i]);
            }
        }
        bytes4[4] memory addressSelectors = [
            IStreamConservationRecordSelection.core.selector,
            IStreamConservationRecordSelection.metadata.selector,
            IStreamConservationRecordSelection.schemaRegistry.selector,
            IStreamConservationRecordSelection.chunkStore.selector
        ];
        bytes4[4] memory hashSelectors = [
            IStreamConservationRecordSelection.coreCodeHash.selector,
            IStreamConservationRecordSelection.metadataCodeHash.selector,
            IStreamConservationRecordSelection.schemaRegistryCodeHash.selector,
            IStreamConservationRecordSelection.chunkStoreCodeHash.selector
        ];
        for (uint256 i; i < 4; ++i) {
            _word(
                d,
                4,
                abi.encodeWithSelector(addressSelectors[i]),
                bytes32(uint256(uint160(d.targets[i])))
            );
            _word(d, 4, abi.encodeWithSelector(hashSelectors[i]), d.codeHashes[i]);
        }
        _word(
            d,
            4,
            abi.encodeCall(IStreamConservationRecordSelection.deploymentChainId, ()),
            bytes32(d.chainId)
        );
        _word(
            d,
            4,
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamConservationRecordSelection).interfaceId)
            ),
            bytes32(uint256(1))
        );
    }

    function _word(Dependencies memory d, uint256 target, bytes memory input, bytes32 expected)
        private
        view
    {
        if (abi.decode(_read(d.targets[target], input, 32, d.readGas), (bytes32)) != expected) {
            revert ConservationDependency(d.targets[target]);
        }
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory out)
    {
        out = new bytes(size);
        if (gasleft() <= cap + cap / 63 + 10000) revert ConservationRead(target, bytes4(input));
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert ConservationRead(target, bytes4(input));
    }
}
