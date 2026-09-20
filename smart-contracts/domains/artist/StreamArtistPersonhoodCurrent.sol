// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPersonhoodTypes as P
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    IStreamGeneralAttestations as A
} from "../../interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import {
    IStreamModuleRegistry,
    StreamModuleRecord,
    ModuleRegistryStatus
} from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { IStreamSchemaRegistry } from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts
} from "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamGeneralAttestationReads as Reads
} from "../metadata/StreamGeneralAttestationReads.sol";
import {
    StreamGeneralAttestationDefinitions as General
} from "../metadata/StreamGeneralAttestationDefinitions.sol";
import { StreamWorkRecordDefinitions as Work } from "../records/StreamWorkRecordDefinitions.sol";
import {
    StreamArtistPersonhoodDefinitions as Definitions
} from "./StreamArtistPersonhoodDefinitions.sol";

/// @notice Bounded liveness checks over an admitted immutable documentary summary.
/// @dev Never reparses report payloads, follows a replacement head, or rechecks an old signature.
library StreamArtistPersonhoodCurrent {
    function cap(address registry) public view returns (uint256 value) {
        uint8 failure;
        uint64 revision;
        (value,, failure, revision) = IStreamGasParameterHost(registry)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_SALE_FACTS_READ_GAS"));
        if (value == 0 || value > type(uint256).max / 64 || failure != 2 || revision == 0) {
            revert P.InvalidPersonhoodReference();
        }
    }

    function moduleIdentity(StreamModuleRecord memory m) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                m.moduleType,
                m.moduleVersion,
                m.interfaceId,
                m.runtimeCodeHash,
                m.deploymentManifestHash,
                m.moduleManifestHash,
                keccak256(bytes(m.moduleManifestURI)),
                m.registeredAt
            )
        );
    }

    function definitions(address schemas, uint256 gasCap)
        public
        view
        returns (bytes32[4] memory hashes)
    {
        bytes32[4] memory ids =
            [General.SCHEMA_ID, General.PROFILE_ID, Work.CANON_ID, Definitions.PROFILE_ID];
        for (uint256 i; i < 4; ++i) {
            IStreamSchemaDocumentFacts.DocumentFacts memory f = _definition(schemas, ids[i], gasCap);
            // Retirement affects admission, not the bytes of an immutable recorded definition.
            hashes[i] = keccak256(
                abi.encode(
                    f.exists,
                    f.kind,
                    f.contentHash,
                    f.canonicalizationId,
                    f.supersedesId,
                    f.totalBytes,
                    f.chunkCount,
                    f.declarationHash
                )
            );
        }
    }

    function definitionCarriers(address schemas, address store, uint256 gasCap)
        public
        view
        returns (address[4] memory pointers)
    {
        bytes32[4] memory ids =
            [General.SCHEMA_ID, General.PROFILE_ID, Work.CANON_ID, Definitions.PROFILE_ID];
        for (uint256 i; i < 4; ++i) {
            IStreamSchemaDocumentFacts.DocumentFacts memory f = _definition(schemas, ids[i], gasCap);
            // All four exact pinned definitions fit one original 8192-byte Store chunk.
            if (!f.exists || f.chunkCount != 1 || f.totalBytes == 0 || f.totalBytes > 8192) {
                revert P.InvalidPersonhoodReference();
            }
            bytes32 hash = abi.decode(
                Reads.fixedRead(
                    schemas,
                    abi.encodeCall(
                        IStreamSchemaDocumentFacts.documentChunkHashAt, (ids[i], uint256(0))
                    ),
                    32,
                    gasCap
                ),
                (bytes32)
            );
            uint32 length;
            (pointers[i], length) = abi.decode(
                Reads.fixedRead(store, abi.encodeWithSignature("chunk(bytes32)", hash), 64, gasCap),
                (address, uint32)
            );
            if (
                hash != f.contentHash || length != f.totalBytes
                    || pointers[i].code.length != uint256(length) + 1
            ) revert P.InvalidPersonhoodReference();
        }
    }

    function read(P.Summary memory s, uint256 gasCap)
        public
        view
        returns (P.NotarizationFacts memory f)
    {
        f.attestationType = s.attestationType;
        f.recorder = s.recorder;
        P.Reference memory r = s.evidenceReference;
        if (
            s.version != 1 || s.chainId != block.chainid || s.documentaryHash == 0
                || !_code(s.core, s.coreCodeHash)
                || !_code(r.artistRegistry, s.originalRegistryCodeHash)
                || !_code(r.notarizationHost, r.notarizationRuntimeHash)
                || !_code(s.moduleRegistry, s.moduleRegistryCodeHash)
                || !_code(s.schemaRegistry, s.schemaRegistryCodeHash)
                || !_code(s.chunkStore, s.chunkStoreCodeHash)
        ) return f;
        for (uint256 i; i < 6; ++i) {
            if (!_code(s.carriers[i], s.carrierCodeHashes[i])) return f;
        }
        (address selected, bytes32 selectedHash,,,,,,,,) = abi.decode(
            Reads.fixedRead(
                s.core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))
                ),
                320,
                gasCap
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (selected != s.moduleRegistry || selectedHash != s.moduleRegistryCodeHash) return f;
        bytes memory raw = Reads.bounded(
            s.moduleRegistry,
            abi.encodeCall(IStreamModuleRegistry.moduleRecord, (r.notarizationHost)),
            8192,
            gasCap
        );
        StreamModuleRecord memory m = abi.decode(raw, (StreamModuleRecord));
        if (keccak256(raw) != keccak256(abi.encode(m))) revert P.InvalidPersonhoodReference();
        if (
            (m.status != ModuleRegistryStatus.ACTIVE && m.status != ModuleRegistryStatus.DEPRECATED)
                || m.revision == 0 || moduleIdentity(m) != s.moduleIdentityHash
        ) return f;
        if (
            keccak256(abi.encode(definitions(s.schemaRegistry, gasCap)))
                != keccak256(abi.encode(s.definitionFactsHashes))
        ) return f;
        f.head = abi.decode(
            Reads.fixedRead(
                r.notarizationHost,
                abi.encodeCall(
                    A.latestAttestationHashFor,
                    (s.notarizationCollectionId, s.attestationType, s.subjectId, s.recorder)
                ),
                32,
                gasCap
            ),
            (bytes32)
        );
        f.current = f.head == r.notarizationRecordHash;
    }

    function _definition(address schemas, bytes32 id, uint256 gasCap)
        private
        view
        returns (IStreamSchemaDocumentFacts.DocumentFacts memory f)
    {
        bytes memory raw = Reads.fixedRead(
            schemas, abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)), 288, gasCap
        );
        f = abi.decode(raw, (IStreamSchemaDocumentFacts.DocumentFacts));
        if (keccak256(raw) != keccak256(abi.encode(f))) revert P.InvalidPersonhoodReference();
    }

    function _code(address target, bytes32 expected) private view returns (bool) {
        return target.code.length != 0 && target.codehash == expected;
    }
}
