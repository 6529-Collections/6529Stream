// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamC2PAReconciliation as C
} from "../../interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamPreservationRecords as P
} from "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamArtistC2PAReads,
    StreamArtistC2PATypes as A
} from "../../interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistDisplayFacts
} from "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import {
    IStreamArtistIdentityRevisionReads
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistSuiteReads
} from "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import {
    IStreamStaticArtistSource
} from "../../interfaces/stream/metadata/IStreamStaticArtistSource.sol";
import {
    IStreamStaticMetadataRouter as R
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamCollectionManifestReads
} from "../../interfaces/stream/metadata/IStreamCollectionManifestReads.sol";
import {
    StreamCollectionManifestTypes as Media
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import { StreamSchemaDocumentStore } from "./StreamSchemaDocumentStore.sol";
import { StreamArtistC2PACredentials } from "../artist/StreamArtistC2PACredentials.sol";
import {
    IStreamC2PAConflicts as Conflicts
} from "../../interfaces/stream/metadata/IStreamC2PAConflicts.sol";
import { StreamC2PAConflicts as ConflictState } from "./StreamC2PAConflicts.sol";

/// @notice Explicit selected-verifier C2PA reports and superseding-aware authorship display.
/// @dev Admission authenticates an original Metadata receipt; it never authorizes a signer,
/// parses an identity JSON document, executes a C2PA validator, or changes Artist authority.
/// The selected verifier attests the report/identity-key-history reconciliation. The companion
/// independently checks current source identity, credential enumeration, media and record pins.
contract StreamC2PAReconciliation is C, Conflicts, StreamGasParameterHost {
    bytes32 public constant PROFILE = keccak256("6529STREAM_C2PA_RECONCILIATION_V1");
    bytes32 public constant RECORD_TYPE = keccak256("C2PA_VALIDATION");
    bytes32 public constant SCHEMA = keccak256("6529STREAM_C2PA_RECONCILIATION_REPORT_V1");
    bytes32 public constant SCHEMA_DEFINITION_HASH =
        0x9c896dc177954cc145f240cbcd4097a3b953b0121360c7f2acef053bc17e68cb;
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_C2PA_DEPENDENCY_READ_GAS");
    address public immutable override core;
    address public immutable override metadata;
    address public immutable override artist;
    address public immutable override verifier;
    address public immutable router;
    address public immutable chunkStore;
    uint256 public immutable sourceChainId;
    // Core, Metadata, Artist facade, Router, Store. No witness can replace these sources.
    bytes32[5] private _codeHashes;
    address[4] private _artistTargets; // Coordinator, Identity, Binding, Attribution
    bytes32[4] private _artistCodeHashes;
    mapping(bytes32 => Selection[]) private _history;
    ConflictState.Store private _conflicts;

    constructor(
        address core_,
        address metadata_,
        address artist_,
        address router_,
        address verifier_,
        address executor,
        GasParameterConfig memory readGas
    ) StreamGasParameterHost(executor) {
        core = core_;
        metadata = metadata_;
        artist = artist_;
        router = router_;
        verifier = verifier_;
        if (
            verifier_ == address(0) || readGas.failureClass != 2
                || _registerGasParameter(readGas) != READ_GAS
        ) revert InvalidC2PAConfiguration();
        chunkStore = M(metadata_).chunkStore();
        sourceChainId = block.chainid;
        address[5] memory targets = [core_, metadata_, artist_, router_, chunkStore];
        for (uint256 i; i < targets.length; ++i) {
            if (targets[i].code.length == 0) revert InvalidC2PAConfiguration();
            _codeHashes[i] = targets[i].codehash;
        }
        _context();
        if (
            _address(metadata_, "core()") != core_ || _address(artist_, "core()") != core_
                || _address(router_, "core()") != core_
        ) revert InvalidC2PAConfiguration();
        address coordinator = _address(artist_, "operationCoordinator()");
        T.SuiteConfiguration memory suite = abi.decode(
            _read(coordinator, abi.encodeCall(IStreamArtistSuiteReads.suiteConfiguration, ()), 544),
            (T.SuiteConfiguration)
        );
        if (suite.registry != artist_ || suite.core != core_ || suite.metadata != router_) {
            revert InvalidC2PAConfiguration();
        }
        _artistTargets = [coordinator, suite.owners[2], suite.owners[0], suite.owners[4]];
        for (uint256 i; i < 4; ++i) {
            address target = _artistTargets[i];
            if (target.code.length == 0) revert InvalidC2PAConfiguration();
            _artistCodeHashes[i] = target.codehash;
            if (
                i != 0
                    && (_address(target, "core()") != core_
                        || _address(target, "artistRegistry()") != artist_
                        || _address(target, "operationCoordinator()") != coordinator)
            ) revert InvalidC2PAConfiguration();
        }
    }

    function sourceCodeHashes() external view returns (bytes32[5] memory) {
        return _codeHashes;
    }

    function artistSourceBindings() external view returns (address[4] memory, bytes32[4] memory) {
        return (_artistTargets, _artistCodeHashes);
    }

    function adopt(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedSelection,
        uint64 expectedRevision
    ) external override returns (bytes32) {
        _context();
        Selection[] storage history = _history[_key(collectionId, subjectId)];
        if (
            history.length != expectedRevision || expectedRevision == type(uint64).max
                || (history.length == 0 ? bytes32(0) : history[history.length - 1].selectionHash)
                    != expectedSelection
        ) {
            revert C2PASelectionConflict();
        }
        bytes memory raw = _read(metadata, abi.encodeCall(M.collectionRecord, (recordHash)), 8192);
        (P.CollectionRecord memory record, M.RecordReceipt memory receipt) =
            abi.decode(raw, (P.CollectionRecord, M.RecordReceipt));
        _canonical(raw, abi.encode(record, receipt));
        if (
            receipt.collectionId != collectionId || receipt.recorder != verifier
                || (receipt.authorizationClass != 4 && receipt.authorizationClass != 6)
                || record.recordType != RECORD_TYPE || record.subjectId != subjectId
                || record.schemaId != SCHEMA || record.contentHash.algorithm != 1
                || record.contentHash.digest.length != 32
                || record.contentHash.canonicalizationId != keccak256("RAW_BYTES")
                || receipt.schemaDefinitionHash != SCHEMA_DEFINITION_HASH
                || receipt.canonicalizationDefinitionHash == 0 || receipt.artistAuthorization != 0
                || !_latest(collectionId, subjectId, recordHash)
        ) revert InvalidC2PAReport();
        M.RecordPolicy memory policy = abi.decode(
            _read(metadata, abi.encodeCall(M.recordPolicy, (RECORD_TYPE)), 96), (M.RecordPolicy)
        );
        if (!policy.admitted || policy.family != keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1")) {
            revert InvalidC2PAReport();
        }
        if (history.length != 0 && receipt.recordIndex <= history[history.length - 1].recordIndex) {
            revert C2PASelectionConflict();
        }
        raw = _read(metadata, abi.encodeCall(M.recordPayload, (recordHash)), 8448);
        (address pointer, bytes memory payload) = abi.decode(raw, (address, bytes));
        _canonical(raw, abi.encode(pointer, payload));
        if (
            pointer == address(0) || payload.length > 8192
                || abi.decode(record.contentHash.digest, (bytes32)) != keccak256(payload)
        ) revert InvalidC2PAReport();
        Report memory report = abi.decode(payload, (Report));
        _canonical(payload, abi.encode(report));
        if (report.collectionId != collectionId || report.subjectId != subjectId) {
            revert InvalidC2PAReport();
        }
        _shape(report);
        _current(report);
        _credentials(report);
        _retained(report.validationReportHash);
        _retained(report.trustAnchorsHash);
        _media(report);
        Selection memory selected = Selection(
            recordHash,
            expectedSelection,
            0,
            expectedRevision + 1,
            receipt.recordIndex,
            receipt.authorizationClass,
            report
        );
        selected.selectionHash = keccak256(
            abi.encode(
                PROFILE,
                sourceChainId,
                address(this),
                core,
                metadata,
                artist,
                router,
                verifier,
                selected
            )
        );
        history.push(selected);
        emit C2PAReconciliationSelected(collectionId, subjectId, recordHash, selected);
        if (report.assertsAuthorship && report.authorship == AuthorshipStatus.DIVERGENT) {
            emit C2PAAttributionDivergence(
                collectionId, subjectId, recordHash, expectedSelection, selected.selectionHash
            );
        }
        ConflictState.note(_conflicts, core, artist, selected);
        return selected.selectionHash;
    }

    /// @notice Current report staleness never erases an unresolved historical adverse finding.
    /// @dev Direct local reads only, so this source remains suitable for transitive STATIC serving.
    function standingConflict(uint256 collectionId, bytes32 subjectId)
        external
        view
        returns (Conflicts.Standing memory v)
    {
        ConflictState.Head storage h = _conflicts.heads[_key(collectionId, subjectId)];
        Conflicts.Conflict storage c = _conflicts.records[h.tail];
        return
            Conflicts.Standing(
                h.tail, h.chain, c.recordHash, c.selectionHash, h.revision, h.openCount
            );
    }

    function conflictRecord(bytes32 id) external view returns (Conflicts.Conflict memory) {
        return _conflicts.records[id];
    }

    function conflictResolution(bytes32 id) external view returns (Conflicts.Resolution memory) {
        return _conflicts.resolutions[id];
    }

    function conflictAt(uint256 collectionId, bytes32 subjectId, uint64 revision)
        external
        view
        returns (bytes32)
    {
        return _conflicts.history[_key(collectionId, subjectId)][revision];
    }

    function resolutionNarrative(bytes32 id) external view returns (bytes memory) {
        return ConflictState.narrative(_conflictEnvironment(), _conflicts.records[id]);
    }

    function clearStandingConflict(bytes32 id, bytes32 originalActionId) external {
        _context();
        ConflictState.clear(_conflicts, _conflictEnvironment(), id, originalActionId);
    }

    function _conflictEnvironment() private view returns (ConflictState.Environment memory) {
        return ConflictState.Environment(
            sourceChainId, core, artist, _artistTargets[3], chunkStore, _gasParameterValue(READ_GAS)
        );
    }

    function currentSelection(uint256 collectionId, bytes32 subjectId)
        public
        view
        override
        returns (Selection memory s)
    {
        Selection[] storage history = _history[_key(collectionId, subjectId)];
        if (history.length != 0) s = history[history.length - 1];
    }

    function selectionAt(uint256 collectionId, bytes32 subjectId, uint64 revision)
        external
        view
        override
        returns (Selection memory)
    {
        Selection[] storage history = _history[_key(collectionId, subjectId)];
        if (revision == 0 || revision > history.length) revert C2PASelectionConflict();
        return history[revision - 1];
    }

    function display(uint256 collectionId, bytes32 subjectId)
        external
        view
        override
        returns (Display memory d)
    {
        Selection memory s = currentSelection(collectionId, subjectId);
        d.recordHash = s.recordHash;
        d.selectionHash = s.selectionHash;
        d.assertsAuthorship = s.report.assertsAuthorship;
        if (s.recordHash == 0) return d;
        try this.requireCurrent(collectionId, subjectId, s.selectionHash) {
            d.current = true;
            d.validation = s.report.validation;
            d.authorship = s.report.authorship;
        } catch { /* Explicitly unevaluated; stale evidence remains in immutable history. */ }
    }

    /// @dev Direct STATIC calls only. No byte parsing/linked delegatecall on the serving path.
    function requireCurrent(uint256 collectionId, bytes32 subjectId, bytes32 expected)
        external
        view
    {
        _context();
        Selection memory s = currentSelection(collectionId, subjectId);
        if (
            s.selectionHash == 0 || s.selectionHash != expected
                || !_latest(collectionId, subjectId, s.recordHash)
        ) {
            revert C2PASelectionConflict();
        }
        _current(s.report);
    }

    function _shape(Report memory p) private pure {
        if (
            p.version != 1 || p.profile != PROFILE || p.collectionId == 0 || p.subjectId == 0
                || p.artistId == 0 || p.bindingHash == 0 || p.generation == 0
                || p.identityRecordHash == 0 || p.identityDocumentHash != p.identityRecordHash
                || p.publicKeyHistoryHash == 0 || p.credentialEnumerationHash == 0
                || p.selectedMediaManifestHash == 0 || p.mediaSlot == 0 || p.mediaSlot > 3
                || p.mediaHash == 0 || p.claimAssetHash == 0 || p.manifestHash == 0
                || p.claimHash == 0 || p.claimSignatureHash == 0 || p.signerFingerprint == 0
                || p.signerKeyFingerprint == 0 || p.keyId == 0 || p.signedAt == 0
                || p.validatorIdentityHash == 0 || p.softwareVersionHash == 0
                || p.validationReportHash == 0 || p.trustAnchorsHash == 0
                || bytes(p.reportURI).length == 0 || bytes(p.reportURI).length > 2048
        ) {
            revert InvalidC2PAReport();
        }
        if (p.mediaHash != p.claimAssetHash && p.validation != ValidationStatus.INVALID) {
            revert InvalidC2PAReport();
        }
        if (p.signerKind == 1 && p.signerFingerprint != p.signerKeyFingerprint) {
            revert InvalidC2PAReport();
        }
        if (
            (p.validation != ValidationStatus.VALID
                    || !p.assertsAuthorship
                    || (p.signerKind != 1 && p.signerKind != 2))
                && p.authorship != AuthorshipStatus.UNEVALUATED
        ) revert InvalidC2PAReport();
    }

    function _current(Report memory p) private view {
        T.Binding memory b = abi.decode(
            _artistRead(abi.encodeCall(IStreamArtistDisplayFacts.displayBinding, (p.collectionId))),
            (T.Binding)
        );
        if (
            b.artistId != p.artistId || b.bindingHash != p.bindingHash
                || b.generation != p.generation || !b.accepted
        ) {
            revert C2PASelectionConflict();
        }
        bytes32 identity = abi.decode(
            _artistRead(
                abi.encodeCall(
                    IStreamArtistIdentityRevisionReads.operativeIdentityRecord, (p.artistId)
                )
            ),
            (bytes32)
        );
        if (identity != p.identityRecordHash) revert C2PASelectionConflict();
        A.Head memory head = abi.decode(
            _read(
                _artistTargets[3],
                abi.encodeCall(IStreamArtistC2PAReads.c2paCredentialHead, (p.artistId)),
                320
            ),
            (A.Head)
        );
        if (head.recordHash != p.credentialRecordHash) revert C2PASelectionConflict();
        if (
            head.recordHash != 0
                && (head.artistId != p.artistId
                    || head.identityRecordHash != identity
                    || head.statementHash != p.credentialEnumerationHash)
        ) revert C2PASelectionConflict();
        R.RawSource memory source = _source(p.collectionId);
        if (
            source.mediaManifest.host != metadata || source.mediaManifest.codeHash != _codeHashes[1]
                || source.mediaManifest.manifestHash != p.selectedMediaManifestHash
        ) revert C2PASelectionConflict();
    }

    function _media(Report memory p) private view {
        bytes memory raw = _read(
            metadata,
            abi.encodeCall(IStreamCollectionManifestReads.mediaManifest, (p.collectionId)),
            16384
        );
        Media.MediaManifest memory m = abi.decode(raw, (Media.MediaManifest));
        _canonical(raw, abi.encode(m));
        bytes32 hash = abi.decode(
            _read(
                metadata,
                abi.encodeCall(IStreamCollectionManifestReads.mediaManifestHash, (p.collectionId)),
                32
            ),
            (bytes32)
        );
        if (
            hash != p.selectedMediaManifestHash
                || p.mediaHash
                    != (p.mediaSlot == 1
                            ? m.imageHash
                            : p.mediaSlot == 2 ? m.animationHash : m.contentHash)
        ) {
            revert InvalidC2PAReport();
        }
    }

    function _credentials(Report memory p) private view {
        if (p.credentialRecordHash == 0) return; // Explicit verifier checks the exact identity JSON.
        bytes memory raw = _read(
            _artistTargets[3],
            abi.encodeWithSignature("statementBytes(bytes32)", p.credentialEnumerationHash),
            8256
        );
        bytes memory statement = abi.decode(raw, (bytes));
        _canonical(raw, abi.encode(statement));
        if (keccak256(statement) != p.credentialEnumerationHash) revert InvalidC2PAReport();
        A.Payload memory credentials =
            StreamArtistC2PACredentials.decode(statement, p.artistId, p.identityRecordHash);
        bool matched;
        bool opaque;
        for (uint256 i; i < credentials.credentials.length; ++i) {
            A.Credential memory row = credentials.credentials[i];
            if (row.kind != 1 && row.kind != 2) opaque = true;
            if (
                row.kind == p.signerKind && row.fingerprint == p.signerFingerprint
                    && row.keyId == p.keyId && row.validFrom <= p.signedAt
                    && (row.validUntil == 0 || p.signedAt < row.validUntil)
            ) matched = true;
        }
        if (
            (!matched && p.authorship == AuthorshipStatus.CONSISTENT)
                || ((credentials.credentials.length == 0 || (!matched && opaque))
                    && p.authorship != AuthorshipStatus.UNEVALUATED)
        ) {
            revert InvalidC2PAReport();
        }
    }

    function _retained(bytes32 hash) private view {
        bytes memory raw =
            _read(chunkStore, abi.encodeCall(StreamSchemaDocumentStore.readChunk, (hash)), 8256);
        bytes memory payload = abi.decode(raw, (bytes));
        _canonical(raw, abi.encode(payload));
        if (payload.length == 0 || payload.length > 8192 || keccak256(payload) != hash) {
            revert InvalidC2PAReport();
        }
    }

    function _source(uint256 collection) private view returns (R.RawSource memory s) {
        bytes memory raw = _read(router, abi.encodeCall(R.staticRenderSource, (collection)), 32768);
        s = abi.decode(raw, (R.RawSource));
        _canonical(raw, abi.encode(s));
        if (s.chainId != sourceChainId || !s.configured) revert InvalidC2PAReport();
    }

    function _latest(uint256 collection, bytes32 subject, bytes32 hash)
        private
        view
        returns (bool)
    {
        return abi.decode(
            _read(
            metadata,
            abi.encodeCall(
            M.latestCollectionRecordHashFor, (collection, RECORD_TYPE, subject, verifier)
        ),
            32
        ),
            (bytes32)
        ) == hash;
    }

    function _context() private view {
        if (block.chainid != sourceChainId) revert InvalidC2PAConfiguration();
        address[5] memory targets = [core, metadata, artist, router, chunkStore];
        for (uint256 i; i < targets.length; ++i) {
            if (targets[i].codehash != _codeHashes[i]) revert C2PADependencyChanged(targets[i]);
        }
        for (uint256 i; i < _artistTargets.length; ++i) {
            if (
                _artistTargets[i] != address(0)
                    && _artistTargets[i].codehash != _artistCodeHashes[i]
            ) {
                revert C2PADependencyChanged(_artistTargets[i]);
            }
        }
        _selected(keccak256("COLLECTION_METADATA"), metadata, _codeHashes[1]);
        _selected(keccak256("ARTIST_REGISTRY"), artist, _codeHashes[2]);
        _selected(keccak256("METADATA_ROUTER"), router, _codeHashes[3]);
    }

    function _selected(bytes32 kind, address target, bytes32 codeHash) private view {
        bytes memory raw =
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320);
        (address actual, bytes32 hash,,,,, uint8 status,,, uint64 revision) = abi.decode(
            raw, (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (actual != target || hash != codeHash || status != 1 || revision == 0) {
            revert C2PADependencyChanged(target);
        }
    }

    function _address(address target, string memory signature) private view returns (address) {
        return abi.decode(_read(target, abi.encodeWithSignature(signature), 32), (address));
    }

    function _artistRead(bytes memory input) private view returns (bytes memory result) {
        bytes memory raw = _read(
            artist, abi.encodeCall(IStreamStaticArtistSource.staticDisplayRead, (input)), 704
        );
        result = abi.decode(raw, (bytes));
        _canonical(raw, abi.encode(result));
    }

    function _read(address target, bytes memory input, uint256 maximum)
        private
        view
        returns (bytes memory output)
    {
        uint256 cap = _gasParameterValue(READ_GAS);
        output = new bytes(maximum);
        if (gasleft() <= cap + cap / 63 + 10000) revert C2PAReadFailed(target);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || size == 0) revert C2PAReadFailed(target);
        assembly ("memory-safe") { mstore(output, size) }
    }

    function _canonical(bytes memory original, bytes memory encoded) private pure {
        if (original.length != encoded.length || keccak256(original) != keccak256(encoded)) {
            revert InvalidC2PAReport();
        }
    }

    function _key(uint256 collection, bytes32 subject) private pure returns (bytes32) {
        return keccak256(abi.encode(collection, subject));
    }
}
