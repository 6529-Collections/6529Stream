// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPersonhoodTypes as P
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    IStreamGeneralAttestations as A
} from "../../interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import {
    IStreamCollectionAttestations as C
} from "../../interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import { IStreamModule } from "../../interfaces/stream/modules/IStreamModule.sol";
import {
    IStreamModuleRegistry,
    StreamModuleRecord,
    ModuleRegistryStatus
} from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { IStreamSchemaRegistry } from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamGeneralAttestationReads as Reads
} from "../metadata/StreamGeneralAttestationReads.sol";
import {
    StreamGeneralAttestationDefinitions as General
} from "../metadata/StreamGeneralAttestationDefinitions.sol";
import { StreamGeneralAttestationHash } from "../metadata/StreamGeneralAttestationHash.sol";
import { StreamWorkRecordDefinitions as Work } from "../records/StreamWorkRecordDefinitions.sol";
import { StreamArtistPersonhoodCurrent } from "./StreamArtistPersonhoodCurrent.sol";
import {
    StreamArtistPersonhoodDefinitions as Definitions
} from "./StreamArtistPersonhoodDefinitions.sol";

/// @notice Stateless reconciliation of an original typed General receipt with an artist-selected reference.
/// @dev Recorded signature verification is retained evidence; this never reauthorizes an old signature.
library StreamArtistPersonhoodProof {
    function verify(address core, P.Reference memory p, uint256 cap, bool writing)
        public
        view
        returns (P.Summary memory summary, P.NotarizationFacts memory facts)
    {
        _source(core, p, cap, writing);
        // The registered, runtime-pinned original producer validated the typed payload at recording.
        // Current inspection authenticates those immutable bytes and original signed receipt; it
        // does not reinterpret legal instruments or call today's ERC1271 signer set.
        bytes memory raw = Reads.bounded(
            p.notarizationHost,
            abi.encodeCall(A.attestation, (p.notarizationRecordHash)),
            12288,
            cap
        );
        (A.Attestation memory a, A.Receipt memory r) = abi.decode(raw, (A.Attestation, A.Receipt));
        if (keccak256(raw) != keccak256(abi.encode(a, r))) revert P.InvalidPersonhoodReference();
        if (
            (a.attestationType != keccak256("INSTITUTIONAL_VERIFICATION")
                    && a.attestationType != keccak256("ESTATE_VERIFICATION"))
                || a.attester == address(0) || r.recorder != a.attester
                || r.verificationClass != A.VerificationClass.SIGNER_VERIFIED
                || r.authorityQualification != A.AuthorityQualification.GENERAL_SIGNER_CLAIM
                || a.schemaId != General.SCHEMA_ID || a.canonicalizationId != Work.CANON_ID
                || r.schemaDefinitionHash != General.SCHEMA_HASH
                || r.profileDefinitionHash != General.PROFILE_HASH
                || r.canonicalizationDefinitionHash != Work.CANON_HASH
                || r.identityRegistry != p.artistRegistry
                || r.identityRegistryCodeHash != p.artistRegistry.codehash
                || r.artistId != p.artistId
                || r.operativeIdentityRecordHash != p.operativeIdentityRecordHash
                || r.recordedAt == 0 || r.authorizationDigest == 0 || r.signatureBundleHash == 0
                || a.subjectId == 0 || a.statementHash == 0 || a.artistAuthorizationRecordHash != 0
                || r.nativeArtistEvidenceHash != 0 || r.nativeArtistAuthorityClass != 0
                || r.authorityFamily != 0 || r.authorizationClass != 0 || r.grantCollectionId != 0
                || r.grantRevision != 0
        ) revert P.InvalidPersonhoodReference();
        A.Receipt memory hashed = abi.decode(abi.encode(r), (A.Receipt));
        hashed.recordIndex = 0;
        hashed.recordChainHash = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_GENERAL_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        p.notarizationHost,
                        a,
                        hashed
                    )
                ) != p.notarizationRecordHash
        ) revert P.InvalidPersonhoodReference();
        if (
            abi.decode(
                    Reads.fixedRead(
                        p.notarizationHost,
                        abi.encodeCall(
                            A.recordHashAt, (a.collectionId, a.attestationType, r.recordIndex)
                        ),
                        32,
                        cap
                    ),
                    (bytes32)
                ) != p.notarizationRecordHash
        ) revert P.InvalidPersonhoodReference();
        bytes32 subjectHash = _subject(core, p.notarizationHost, p.notarizationRecordHash, a, cap);
        (bytes32 carriersHash, address[2] memory reportCarriers) = _carriers(p, a, r, cap);
        _definitions(p.notarizationHost, cap);
        summary.version = 1;
        summary.chainId = block.chainid;
        summary.evidenceReference = p;
        summary.originalRegistryCodeHash = p.artistRegistry.codehash;
        summary.core = core;
        summary.coreCodeHash = core.codehash;
        (summary.moduleRegistry, summary.moduleRegistryCodeHash,,,,,,,,) = abi.decode(
            Reads.fixedRead(
                core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))
                ),
                320,
                cap
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        summary.schemaRegistry =
            _address(p.notarizationHost, abi.encodeCall(A.schemaRegistry, ()), cap);
        summary.schemaRegistryCodeHash = summary.schemaRegistry.codehash;
        summary.chunkStore = _address(p.notarizationHost, abi.encodeCall(A.chunkStore, ()), cap);
        summary.chunkStoreCodeHash = summary.chunkStore.codehash;
        summary.definitionFactsHashes =
            StreamArtistPersonhoodCurrent.definitions(summary.schemaRegistry, cap);
        StreamModuleRecord memory module_ = abi.decode(
            Reads.bounded(
                summary.moduleRegistry,
                abi.encodeCall(IStreamModuleRegistry.moduleRecord, (p.notarizationHost)),
                8192,
                cap
            ),
            (StreamModuleRecord)
        );
        summary.moduleIdentityHash = StreamArtistPersonhoodCurrent.moduleIdentity(module_);
        address[4] memory definitionCarriers = StreamArtistPersonhoodCurrent.definitionCarriers(
            summary.schemaRegistry, summary.chunkStore, cap
        );
        summary.carriers[0] = reportCarriers[0];
        summary.carriers[1] = reportCarriers[1];
        for (uint256 i; i < 4; ++i) {
            summary.carriers[i + 2] = definitionCarriers[i];
        }
        for (uint256 i; i < 6; ++i) {
            summary.carrierCodeHashes[i] = summary.carriers[i].codehash;
        }
        summary.notarizationCollectionId = a.collectionId;
        summary.attestationType = a.attestationType;
        summary.subjectId = a.subjectId;
        summary.recorder = r.recorder;
        summary.documentaryHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_PERSONHOOD_DOCUMENTARY_PROOF_V1"),
                block.chainid,
                core,
                p,
                a,
                r,
                subjectHash,
                carriersHash,
                summary.schemaRegistry,
                summary.schemaRegistryCodeHash,
                summary.chunkStore,
                summary.chunkStoreCodeHash,
                summary.definitionFactsHashes
            )
        );
        facts.attestationType = a.attestationType;
        facts.recorder = r.recorder;
        facts.head = abi.decode(
            Reads.fixedRead(
                p.notarizationHost,
                abi.encodeCall(
                    A.latestAttestationHashFor,
                    (a.collectionId, a.attestationType, a.subjectId, r.recorder)
                ),
                32,
                cap
            ),
            (bytes32)
        );
        facts.current = facts.head == p.notarizationRecordHash;
        if (writing && !facts.current) revert P.InvalidPersonhoodReference();
    }

    function _source(address core, P.Reference memory p, uint256 cap, bool writing) private view {
        if (
            p.notarizationHost.code.length == 0
                || p.notarizationHost.codehash != p.notarizationRuntimeHash
                || p.artistRegistry.code.length == 0
        ) revert P.PersonhoodDependencyChanged(p.notarizationHost);
        bytes memory raw = Reads.fixedRead(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))),
            320,
            cap
        );
        (address modules, bytes32 hash,,,,,,,,) = abi.decode(
            raw, (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        Reads.code(modules, hash);
        Reads.code(
            core,
            abi.decode(
                Reads.fixedRead(
                    p.notarizationHost, abi.encodeWithSignature("coreCodeHash()"), 32, cap
                ),
                (bytes32)
            )
        );
        raw = Reads.bounded(
            modules,
            abi.encodeCall(IStreamModuleRegistry.moduleRecord, (p.notarizationHost)),
            8192,
            cap
        );
        StreamModuleRecord memory m = abi.decode(raw, (StreamModuleRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(m))
                || (m.status != ModuleRegistryStatus.ACTIVE
                    && (writing || m.status != ModuleRegistryStatus.DEPRECATED))
                || m.moduleType != keccak256("GENERAL_ATTESTATIONS")
                || m.moduleVersion != keccak256("6529stream.general-attestations.v2")
                || m.interfaceId != type(A).interfaceId
                || m.runtimeCodeHash != p.notarizationRuntimeHash || m.revision == 0
        ) revert P.PersonhoodDependencyChanged(p.notarizationHost);
        if (
            _address(p.notarizationHost, abi.encodeCall(A.core, ()), cap) != core
                || _address(p.notarizationHost, abi.encodeCall(A.artistRegistry, ()), cap)
                    != p.artistRegistry
                || abi.decode(
                        Reads.fixedRead(
                            p.notarizationHost,
                            abi.encodeCall(IStreamModule.streamModuleType, ()),
                            32,
                            cap
                        ),
                        (bytes32)
                    ) != m.moduleType
                || abi.decode(
                        Reads.fixedRead(
                            p.notarizationHost,
                            abi.encodeCall(IStreamModule.streamModuleVersion, ()),
                            32,
                            cap
                        ),
                        (bytes32)
                    ) != m.moduleVersion
        ) revert P.PersonhoodDependencyChanged(p.notarizationHost);
    }

    function _subject(
        address core,
        address host,
        bytes32 record,
        A.Attestation memory a,
        uint256 cap
    ) private view returns (bytes32) {
        bytes memory raw = Reads.fixedRead(
            host, abi.encodeCall(A.recordSubject, (record)), 128, cap
        );
        C.Subject memory s = abi.decode(raw, (C.Subject));
        if (keccak256(raw) != keccak256(abi.encode(s)) || s.collectionId != a.collectionId) {
            revert P.InvalidPersonhoodReference();
        }
        bytes32 subject;
        if (s.kind == C.SubjectKind.COLLECTION) {
            if (s.tokenId != 0 || s.objectId != 0) revert P.InvalidPersonhoodReference();
            subject = keccak256(
                abi.encode(
                    bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                    block.chainid,
                    core,
                    s.collectionId
                )
            );
        } else if (s.kind == C.SubjectKind.TOKEN) {
            if (s.collectionId == 0 || s.tokenId == 0 || s.objectId != 0) {
                revert P.InvalidPersonhoodReference();
            }
            subject = keccak256(
                abi.encode(
                    bytes32(0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e),
                    block.chainid,
                    core,
                    s.tokenId
                )
            );
        } else {
            if (s.collectionId == 0 || s.tokenId != 0 || s.objectId == 0) {
                revert P.InvalidPersonhoodReference();
            }
            subject = keccak256(
                abi.encode(
                    bytes32(0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b),
                    block.chainid,
                    core,
                    s.collectionId,
                    s.objectId
                )
            );
        }
        if (subject != a.subjectId) revert P.InvalidPersonhoodReference();
        return keccak256(abi.encode(s));
    }

    function _carriers(
        P.Reference memory p,
        A.Attestation memory a,
        A.Receipt memory r,
        uint256 cap
    ) private view returns (bytes32, address[2] memory) {
        bytes memory raw = Reads.bounded(
            p.notarizationHost,
            abi.encodeCall(A.recordPayload, (p.notarizationRecordHash)),
            8288,
            cap
        );
        (address pointer, bytes memory payload) = abi.decode(raw, (address, bytes));
        if (
            keccak256(raw) != keccak256(abi.encode(pointer, payload)) || pointer.code.length == 0
                || payload.length == 0 || payload.length > 8192
                || keccak256(payload) != a.statementHash
        ) revert P.InvalidPersonhoodReference();
        address payloadPointer = pointer;
        raw = Reads.bounded(
            p.notarizationHost,
            abi.encodeCall(A.recordSignatureBundle, (p.notarizationRecordHash)),
            8288,
            cap
        );
        bytes memory bundle;
        (pointer, bundle) = abi.decode(raw, (address, bytes));
        if (
            keccak256(raw) != keccak256(abi.encode(pointer, bundle)) || pointer.code.length == 0
                || bundle.length == 0 || bundle.length > 8192
                || keccak256(bundle) != r.signatureBundleHash
        ) revert P.InvalidPersonhoodReference();
        (bytes32 domain, bytes32[15] memory words, bytes memory signature) =
            abi.decode(bundle, (bytes32, bytes32[15], bytes));
        if (
            keccak256(bundle) != keccak256(abi.encode(domain, words, signature))
                || signature.length == 0 || signature.length > 4096
                || (r.signatureScheme != keccak256("EIP712")
                    && r.signatureScheme != keccak256("ERC1271"))
        ) revert P.InvalidPersonhoodReference();
        bytes32 expectedDomain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamGeneralAttestations"),
                keccak256("1"),
                block.chainid,
                p.notarizationHost
            )
        );
        bytes32[15] memory expected = [
            StreamGeneralAttestationHash.TYPEHASH,
            bytes32(uint256(uint160(a.attester))),
            bytes32(a.collectionId),
            a.subjectId,
            a.attestationType,
            keccak256(bytes(a.attesterDID)),
            a.schemaId,
            a.canonicalizationId,
            keccak256(bytes(a.statementURI)),
            a.statementHash,
            a.supersedes,
            a.artistAuthorizationRecordHash,
            bytes32(uint256(a.effectiveAt)),
            bytes32(r.nonce),
            bytes32(uint256(r.deadline))
        ];
        if (
            domain != expectedDomain
                || keccak256(abi.encode(words)) != keccak256(abi.encode(expected))
                || keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(words))))
                    != r.authorizationDigest
        ) revert P.InvalidPersonhoodReference();
        return (keccak256(abi.encode(payload, bundle)), [payloadPointer, pointer]);
    }

    function _definitions(address host, uint256 cap) private view {
        address schemas = _address(host, abi.encodeCall(A.schemaRegistry, ()), cap);
        address store = _address(host, abi.encodeCall(A.chunkStore, ()), cap);
        Reads.code(
            schemas,
            abi.decode(
                Reads.fixedRead(host, abi.encodeWithSignature("schemaRegistryCodeHash()"), 32, cap),
                (bytes32)
            )
        );
        Reads.code(
            store,
            abi.decode(
                Reads.fixedRead(host, abi.encodeWithSignature("chunkStoreCodeHash()"), 32, cap),
                (bytes32)
            )
        );
        if (_address(schemas, abi.encodeCall(IStreamSchemaRegistry.chunkStore, ()), cap) != store) {
            revert P.InvalidPersonhoodReference();
        }
        Reads.exactDefinition(
            schemas,
            store,
            General.SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            General.SCHEMA_HASH,
            General.SCHEMA_BYTES,
            cap
        );
        Reads.exactDefinition(
            schemas,
            store,
            General.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            General.PROFILE_HASH,
            General.PROFILE_BYTES,
            cap
        );
        Reads.exactDefinition(
            schemas,
            store,
            Work.CANON_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            Work.CANON_HASH,
            Work.CANON_BYTES,
            cap
        );
        Reads.exactDefinition(
            schemas,
            store,
            Definitions.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            Definitions.PROFILE_HASH,
            Definitions.PROFILE_BYTES,
            cap
        );
    }

    function _address(address target, bytes memory input, uint256 cap)
        private
        view
        returns (address)
    {
        return abi.decode(Reads.fixedRead(target, input, 32, cap), (address));
    }
}
