// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionEvidenceCodec as Codec
} from "./StreamArtistRecoveredSanctionEvidenceCodec.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistAuthorityHydrationCoordinator as Coordinator
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamArtistReconstruction as Reconstruction
} from "../../interfaces/stream/artist/IStreamArtistReconstruction.sol";
import {
    StreamArtistRecoveredPlatformTypes as PLH
} from "./StreamArtistRecoveredPlatformTypes.sol";
import { SSTORE2 } from "../../libraries/SSTORE2.sol";

interface IStreamRecoveredPlatformConfiguration {
    function configurationHash() external view returns (bytes32);
}

/// @notice Exhaustive bounded original Archive catalogue, authenticated independently of callers.
/// @dev The original immutable Archive records transport integrity, not authority. Callers must
/// additionally join every selected original Platform/binding operation to the complete owner provenance and typed history.
library StreamArtistRecoveredPlatformCatalogue {
    function collect(RH.Provenance memory p)
        public
        view
        returns (PLH.Catalogue[] memory catalogues, H.OperationEvidence[] memory operations)
    {
        if (
            p.origins.length == 0 || p.origins.length != p.eras.length
                || p.origins.length > RH.MAX_ERAS
        ) {
            _invalid();
        }
        catalogues = new PLH.Catalogue[](p.origins.length);
        operations = new H.OperationEvidence[](RH.MAX_JOURNAL_ENTRIES + 2 * PLH.MAX_ROWS);
        uint256 count;
        uint256 rows;
        uint256 bytesRead;
        for (uint256 era; era < p.origins.length; ++era) {
            RH.OriginEnvironment memory o = p.origins[era];
            PLH.Catalogue memory c = _catalogue(o);
            if (c.originHash != p.eras[era].originHash) _invalid();
            c.lower = p.eras[era].lowerRevisions;
            for (uint8 owner; owner < 7; ++owner) {
                c.upper[owner] = p.eras[era].checkpoints[owner].ownerState.revision;
            }
            rows += c.count;
            if (rows > H.MAX_CATALOGUE_ROWS) _invalid();
            for (uint256 i; i < c.count; ++i) {
                (address pointer, bytes32 kind, bytes32 hash) =
                    Reconstruction(o.archive).storedPayloadAt(i);
                c.rowsHash = keccak256(abi.encode(c.rowsHash, i, pointer, kind, hash));
                if (kind != H.OPERATION_EVIDENCE) continue;
                if (pointer.code.length <= 1 || pointer.code.length > SSTORE2.MAX_DATA_LENGTH + 1) {
                    _invalid();
                }
                bytesRead += pointer.code.length - 1;
                if (bytesRead > H.MAX_OPERATION_BYTES) _invalid();
                bytes memory raw = SSTORE2.read(pointer);
                if (keccak256(raw) != hash || raw.length < 96) _invalid();
                uint256 op;
                assembly ("memory-safe") { op := mload(add(raw, 96)) }
                if (!PLH.archivedOperation(op)) continue;
                H.Envelope memory e = Codec.envelope(raw);
                H.Evidence memory evidence = H.Evidence(i, pointer, hash, _id(o, e));
                _evidence(o, c, evidence, e, raw);
                // Earlier origins can append after their frozen import checkpoint. Preserve
                // that catalogue in the commitment, but never import its later mutations.
                uint64 revision = e.after_[4].revision;
                if (
                    revision <= p.eras[era].lowerRevisions[4]
                        || revision > p.eras[era].checkpoints[4].ownerState.revision
                ) continue;
                if (count == operations.length) _invalid();
                operations[count++] = H.OperationEvidence(c.originHash, e.operation, evidence);
            }
            if (Reconstruction(o.archive).storedPayloadCount() != c.count) _invalid();
            catalogues[era] = c;
        }
        assembly ("memory-safe") { mstore(operations, count) }
    }

    function requireCurrent(
        RH.Provenance memory p,
        PLH.Catalogue[] memory expected,
        H.OperationEvidence[] memory operations
    ) public view {
        (PLH.Catalogue[] memory current, H.OperationEvidence[] memory observed) = collect(p);
        if (keccak256(abi.encode(current, observed)) != keccak256(abi.encode(expected, operations)))
        {
            _invalid();
        }
    }

    /// @notice Reconstructs the complete saved scan at a fixed owner import boundary.
    /// @dev Its own cutoffs must match the authenticated local owner header. The Coordinator
    /// separately compares all seven owner cutoffs with complete provenance before and after writes.
    function requireLocal(
        RH.OwnerProvenance memory local,
        uint8 owner,
        PLH.Catalogue[] memory expected,
        H.OperationEvidence[] memory operations
    ) public view {
        if (
            (owner != 0 && owner != 4) || expected.length != local.eras.length
                || expected.length != local.origins.length
        ) _invalid();
        RH.Provenance memory p;
        p.origins = local.origins;
        p.eras = new RH.Era[](expected.length);
        for (uint256 i; i < expected.length; ++i) {
            PLH.Catalogue memory c = expected[i];
            if (
                c.originHash != local.eras[i].originHash
                    || c.lower[owner] != local.eras[i].lowerRevision
                    || c.upper[owner] != local.eras[i].checkpoint.ownerState.revision
            ) _invalid();
            p.eras[i].originHash = c.originHash;
            p.eras[i].lowerRevisions = c.lower;
            for (uint8 j; j < 7; ++j) {
                p.eras[i].checkpoints[j].ownerState.revision = c.upper[j];
            }
        }
        requireCurrent(p, expected, operations);
    }

    function read(RH.OriginEnvironment memory o, PLH.Catalogue memory c, H.Evidence memory evidence)
        public
        view
        returns (H.Envelope memory e)
    {
        if (
            evidence.catalogueIndex >= c.count || c.originHash != RH.originHash(o)
                || o.archive.codehash != c.archiveCodeHash
        ) _invalid();
        (address pointer, bytes32 kind, bytes32 hash) =
            Reconstruction(o.archive).storedPayloadAt(evidence.catalogueIndex);
        if (
            pointer != evidence.pointer || kind != H.OPERATION_EVIDENCE
                || hash != evidence.payloadHash || pointer.code.length <= 1
                || pointer.code.length > SSTORE2.MAX_DATA_LENGTH + 1
        ) _invalid();
        bytes memory raw = SSTORE2.read(pointer);
        e = Codec.envelope(raw);
        _evidence(o, c, evidence, e, raw);
    }

    function _catalogue(RH.OriginEnvironment memory o)
        private
        view
        returns (PLH.Catalogue memory c)
    {
        T.SuiteConfiguration memory suite = Coordinator(o.coordinator).authorityHydrationSuite();
        Archive a = Archive(o.archive);
        if (
            o.chainId != block.chainid || o.archive.code.length == 0
                || keccak256(abi.encode(suite)) != o.suiteConfigurationHash
                || suite.registry != o.registry || suite.archive != o.archive
                || suite.core != o.core || suite.mintManager != o.manager
                || keccak256(abi.encode(suite.owners)) != keccak256(abi.encode(o.owners))
                || a.artistRegistry() != o.registry || a.operationCoordinator() != o.coordinator
                || a.artistArchiveMarkerV2() != keccak256("6529STREAM_ARTIST_ARCHIVE_V2")
                || a.artistArchiveSchemaV2() != 2
                || a.artistArchiveMaxEvidenceBytesV2() != SSTORE2.MAX_DATA_LENGTH
                || a.artistArchiveBindingHashV2()
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_ARCHIVE_BINDING_V2"),
                            o.chainId,
                            o.registry,
                            o.coordinator,
                            type(Archive).interfaceId,
                            keccak256("6529STREAM_ARTIST_ARCHIVE_V2"),
                            uint16(2),
                            SSTORE2.MAX_DATA_LENGTH
                        )
                    )
        ) _invalid();
        c.originHash = RH.originHash(o);
        c.archiveCodeHash = o.archive.codehash;
        c.configurationHash =
            IStreamRecoveredPlatformConfiguration(o.coordinator).configurationHash();
        c.count = Reconstruction(o.archive).storedPayloadCount();
        if (c.configurationHash == 0 || c.count > H.MAX_CATALOGUE_ROWS) _invalid();
        c.rowsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_PLATFORM_CATALOGUE_V1"),
                c.originHash,
                o.archive,
                c.archiveCodeHash,
                c.configurationHash,
                c.count
            )
        );
    }

    function _evidence(
        RH.OriginEnvironment memory o,
        PLH.Catalogue memory c,
        H.Evidence memory evidence,
        H.Envelope memory e,
        bytes memory raw
    ) private view {
        if (
            e.version != 1 || e.configurationHash != c.configurationHash
                || !PLH.archivedOperation(e.operation) || e.actor == address(0) || e.value == 0
                || evidence.evidenceId != _id(o, e) || evidence.payloadHash != keccak256(raw)
        ) _invalid();
        (bytes32 hash, address pointer, uint32 size, uint64 atBlock) =
            Archive(o.archive).artistEvidenceMetadataV2(evidence.evidenceId, 1);
        if (
            hash != evidence.payloadHash || pointer != evidence.pointer || size != raw.length
                || atBlock > block.number
                || keccak256(Archive(o.archive).artistEvidenceBytesV2(evidence.evidenceId, 1))
                    != hash
        ) _invalid();
    }

    function _id(RH.OriginEnvironment memory o, H.Envelope memory e)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                o.chainId,
                o.registry,
                o.coordinator,
                e.operation,
                e.actor,
                e.value
            )
        );
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
