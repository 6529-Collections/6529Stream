// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPolicyPublicationBase
} from "./StreamCurrentFullPolicyPublicationBase.sol";
import {
    StreamArchivalTypes as OcA
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamFinalityArtifactTypes as OcF
} from "../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import {
    StreamExternalArtifactTypes as AxE
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamArchivalTypes as AxA
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @notice Actual archival receipt and full-byte coverage helpers for the current full-policy graph.
/// @dev Archive methods and their state are preserved from StreamNativeFinalityAssemblyFixture.
/// Governance, Artist, Schema Store, verifiers and both coverage products are the genuine products
/// constructed by the inherited base. Checkpoint and retrieval observations are locally signed
/// fixture evidence, not public network publication or independent human retrieval attestations.
abstract contract StreamCurrentFullPolicyArchiveFixture is StreamCurrentFullPolicyPublicationBase {
    uint256 private constant OC_OBSERVER_A = 0xE5701;
    uint256 private constant OC_OBSERVER_B = 0xE5702;
    uint256 private constant OC_FIRST_WRITER = 0x652983;
    uint256 private constant OC_SECOND_WRITER = 0x652984;
    uint256 private constant OC_FIXITY_OPERATOR = 0x652985;
    uint256 private constant OC_CHUNK_BYTES = 8192;
    bytes32 private ocFirstFamily;
    bytes32 private ocSecondFamily;
    uint256 private ocSerial;

    struct OcCoveredArtifact {
        bytes32 artifactHash;
        bytes32 completionHash;
    }
    mapping(bytes32 => bytes32) private ocChunkCoverage;
    mapping(bytes32 => OcCoveredArtifact) private ocCoveredArtifacts;

    function _assemblySetupArchiveAdmissions() internal {
        _ocGrantFixity(safeVm.addr(OC_FIXITY_OPERATOR));
        ocFirstFamily = _ocAdmit("native-assembly-arweave", true, safeVm.addr(OC_FIRST_WRITER));
        ocSecondFamily = _ocAdmit("native-assembly-ipfs", false, safeVm.addr(OC_SECOND_WRITER));
        _assemblySetupExternalFamilies();
    }

    function _ocCover(bytes memory raw, bytes32 schema_, bytes32 canon_)
        internal
        returns (bytes32 artifactHash, bytes32 completionHash)
    {
        require(address(assemblyArtifact) != address(0), "oc artifact missing");
        require(raw.length != 0 && raw.length <= 64 * OC_CHUNK_BYTES, "oc artifact length");
        require(schema_ != 0 && canon_ != 0, "oc artifact schema");
        require(assemblyArtists.core() == address(assemblyCore), "oc facade core");
        require(assemblyArtists.archivalCoverage() == address(assemblyArchive), "oc facade archive");
        bytes32 artistId = assemblyArtistId;
        require(artistId != 0, "oc artist missing");
        bytes32 cacheKey =
            keccak256(abi.encode(artistId, schema_, canon_, keccak256(raw), raw.length));
        OcCoveredArtifact memory cached = ocCoveredArtifacts[cacheKey];
        if (cached.artifactHash != 0) {
            assemblyArtifact.requireArtifactCoverage(
                cached.completionHash, artistId, cached.artifactHash
            );
            return (cached.artifactHash, cached.completionHash);
        }
        uint256 count = (raw.length + OC_CHUNK_BYTES - 1) / OC_CHUNK_BYTES;
        OcF.Artifact memory a;
        a.artistId = artistId;
        a.schemaId = schema_;
        a.canonicalizationId = canon_;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        a.chunkHashes = new bytes32[](count);
        a.chunkLengths = new uint32[](count);
        bytes32[] memory originalCoverage = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 offset = i * OC_CHUNK_BYTES;
            uint256 length = raw.length - offset;
            if (length > OC_CHUNK_BYTES) length = OC_CHUNK_BYTES;
            bytes memory part = _ocSlice(raw, offset, length);
            a.chunkHashes[i] = keccak256(part);
            a.chunkLengths[i] = uint32(length);
            originalCoverage[i] = _ocCoverChunk(artistId, part);
        }
        artifactHash = assemblyArtifact.recordArtifact(a);
        bytes32 plan = assemblyArtifact.beginCoverage(artifactHash, ocFirstFamily, ocSecondFamily);
        for (uint32 i; i < count; ++i) {
            completionHash = assemblyArtifact.coverNextChunk(plan, i, originalCoverage[i]);
        }
        require(completionHash != 0, "oc completion missing");
        assemblyArtifact.requireArtifactCoverage(completionHash, artistId, artifactHash);
        ocCoveredArtifacts[cacheKey] = OcCoveredArtifact(artifactHash, completionHash);
    }

    function _ocCoverChunk(bytes32 artistId, bytes memory raw) private returns (bytes32 covered) {
        bytes32 key = keccak256(abi.encode(artistId, keccak256(raw)));
        covered = ocChunkCoverage[key];
        if (covered != 0) {
            assemblyArchive.requireCoverage(covered, artistId, keccak256(raw));
            return covered;
        }
        (bytes32 chunkHash, address pointer) = assemblyStore.publishChunk(raw);
        require(
            chunkHash == keccak256(raw) && pointer.code.length == raw.length + 1,
            "oc exact STOP chunk"
        );
        OcA.Envelope memory e = OcA.Envelope(
            artistId,
            chunkHash,
            keccak256("6529STREAM_FINALITY_ARTIFACT_CHUNK_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(raw),
            uint64(raw.length),
            1,
            0
        );
        bytes32 envelopeHash = assemblyArchive.recordChunkEnvelope(e, pointer);
        uint256 serial = ++ocSerial;
        (bytes32 checkpointHash, bytes32 transactionId) = _ocCheckpoint(raw, serial);
        bytes32 first = _ocReceipt(e, envelopeHash, true, checkpointHash, transactionId, serial);
        bytes32 second = _ocReceipt(e, envelopeHash, false, checkpointHash, transactionId, serial);
        _ocFixity(e, first, serial);
        _ocFixity(e, second, serial);
        covered = assemblyArchive.recordCoverage(first, second);
        assemblyArchive.requireCoverage(covered, artistId, chunkHash);
        ocChunkCoverage[key] = covered;
    }

    function _ocCheckpoint(bytes memory raw, uint256 serial)
        private
        returns (bytes32 hash, bytes32 transactionId)
    {
        OcA.Checkpoint memory c;
        c.networkId = assemblyCheckpointVerifier.networkId();
        c.blockHash = abi.encodePacked(
            keccak256(abi.encode("oc synthetic block", serial)), bytes16(uint128(serial))
        );
        c.blockHeight = 1500000 + uint64(serial);
        c.dataRoot = _ocNativeLeaf(sha256(raw), raw.length);
        c.transactionRoot = _ocNativeLeaf(c.dataRoot, raw.length);
        c.blockDataSize = raw.length;
        c.transactionId = keccak256(
            abi.encode(
                "oc synthetic transaction",
                address(assemblyCheckpointVerifier),
                serial,
                keccak256(raw)
            )
        );
        c.dataSize = uint64(raw.length);
        c.transactionEnd = raw.length;
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = assemblyCheckpointVerifier.configurationHash();
        bytes32 digest = assemblyCheckpointVerifier.checkpointDigest(c);
        OcA.ObserverProof[] memory proofs = new OcA.ObserverProof[](2);
        proofs[0] = OcA.ObserverProof(safeVm.addr(OC_OBSERVER_A), _ocSign(OC_OBSERVER_A, digest));
        proofs[1] = OcA.ObserverProof(safeVm.addr(OC_OBSERVER_B), _ocSign(OC_OBSERVER_B, digest));
        if (proofs[0].account > proofs[1].account) (proofs[0], proofs[1]) = (proofs[1], proofs[0]);
        hash = assemblyCheckpointVerifier.recordCheckpoint(
            c,
            abi.encodePacked(c.dataRoot, uint256(raw.length)),
            abi.encodePacked(sha256(raw), uint256(raw.length)),
            raw,
            proofs
        );
        return (hash, c.transactionId);
    }

    function _ocReceipt(
        OcA.Envelope memory e,
        bytes32 envelopeHash,
        bool endowed,
        bytes32 checkpointHash,
        bytes32 transactionId,
        uint256 serial
    ) private returns (bytes32 hash) {
        uint256 writerKey = endowed ? OC_FIRST_WRITER : OC_SECOND_WRITER;
        bytes memory locator = endowed
            ? abi.encodePacked(transactionId)
            : abi.encodePacked(bytes4(0x01551220), e.payloadDigest);
        OcA.ReceiptTerms memory r = OcA.ReceiptTerms(
            envelopeHash,
            endowed ? ocFirstFamily : ocSecondFamily,
            keccak256(locator),
            keccak256(bytes(endowed ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            endowed
                ? assemblyCheckpointVerifier.profileHash()
                : assemblyArchive.POSSESSION_PROFILE(),
            endowed ? checkpointHash : bytes32(0),
            safeVm.addr(writerKey),
            uint64(block.timestamp),
            serial,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) {
            r.proofRecordHash = assemblyArchive.possessionHash(
                OcA.Possession(
                    r.envelopeHash,
                    r.familyRecordHash,
                    r.storageIdentifierHash,
                    r.writer,
                    r.observedAt
                )
            );
        }
        hash = assemblyArchive.recordReceipt(
            r, locator, _ocSign(writerKey, assemblyArchive.receiptDigest(r))
        );
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1"),
                        block.chainid,
                        address(assemblyArchive),
                        r
                    )
                ),
            "oc receipt hash"
        );
        (OcA.ReceiptTerms memory saved, bytes memory savedLocator, bytes memory signature) =
            assemblyArchive.receipt(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                && keccak256(savedLocator) == keccak256(locator) && signature.length == 65,
            "oc original receipt"
        );
    }

    function _ocFixity(OcA.Envelope memory e, bytes32 receiptHash, uint256 serial) private {
        (OcA.ReceiptTerms memory r,,) = assemblyArchive.receipt(receiptHash);
        OcA.FixityTerms memory f = OcA.FixityTerms(
            receiptHash,
            r.envelopeHash,
            r.familyRecordHash,
            e.payloadDigest,
            e.payloadDigest,
            e.byteSize,
            uint64(block.timestamp),
            1,
            keccak256(
                abi.encode(
                    "oc independent full-byte fixity", receiptHash, e.payloadDigest, e.byteSize
                )
            ),
            bytes32(0),
            bytes32(0),
            safeVm.addr(OC_FIXITY_OPERATOR),
            serial,
            uint64(block.timestamp + 1 days)
        );
        bytes32 hash = assemblyArchive.recordFixity(
            f, _ocSign(OC_FIXITY_OPERATOR, assemblyArchive.fixityDigest(f))
        );
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARCHIVAL_FIXITY_RECORD_V1"),
                        block.chainid,
                        address(assemblyArchive),
                        f
                    )
                ),
            "oc fixity hash"
        );
        require(assemblyArchive.latestFixity(receiptHash) == hash, "oc original fixity");
    }

    function _ocAdmit(string memory name, bool endowed, address writer)
        private
        returns (bytes32 hash)
    {
        bytes memory salt = bytes(endowed ? "oc-one" : "oc-two");
        OcA.Family memory f = OcA.Family(
            keccak256(bytes(name)),
            endowed ? assemblyCheckpointVerifier.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256("same jurisdiction allowed"),
            endowed ? 1 : 2,
            writer,
            endowed
                ? assemblyCheckpointVerifier.profileHash()
                : assemblyArchive.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = assemblyArchive.familyRegistrationContext(name, f);
        _assemblyGovernanceCall(
            1,
            address(assemblyArchive),
            abi.encodeCall(assemblyArchive.admitFamily, (name, f)),
            scope,
            oldHash,
            newHash
        );
        (OcA.Family memory saved, uint8 status) = assemblyArchive.family(hash);
        require(
            status == 1 && keccak256(abi.encode(saved)) == keccak256(abi.encode(f)),
            "oc family admitted"
        );
    }

    function _ocGrantFixity(address holder) private {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        (bytes32 chain, uint64 revision) = assemblyRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = assemblyRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(assemblyRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(assemblyRoles),
                scope,
                false,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(assemblyRoles),
                scope,
                true,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        _assemblyGovernanceCall(
            1,
            address(assemblyRoles),
            abi.encodeCall(assemblyRoles.grantRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
        require(assemblyRoles.hasRole(role, holder), "oc actual fixity role");
    }

    function _ocSign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _ocNativeLeaf(bytes32 data, uint256 end) private pure returns (bytes32) {
        return
            sha256(abi.encodePacked(sha256(abi.encodePacked(data)), sha256(abi.encodePacked(end))));
    }

    function _ocSlice(bytes memory raw, uint256 offset, uint256 length)
        private
        pure
        returns (bytes memory part)
    {
        require(offset <= raw.length && length <= raw.length - offset, "oc slice bounds");
        part = new bytes(length);
        assembly ("memory-safe") {
            let source := add(add(raw, 32), offset)
            let target := add(part, 32)
            for { let i := 0 } lt(i, length) { i := add(i, 32) } {
                mstore(add(target, i), mload(add(source, i)))
            }
        }
    }

    uint256 internal constant AX_OBSERVER_A = 0xE5701;
    uint256 internal constant AX_OBSERVER_B = 0xE5702;
    uint256 internal constant AX_WRITER_A = 0x652983;
    uint256 internal constant AX_WRITER_B = 0x652984;
    uint256 internal constant AX_FIXITY = 0x652985;
    bytes32 internal axFirstFamily;
    bytes32 internal axSecondFamily;
    mapping(bytes32 => bytes32) internal axOriginalCoverage;

    function _assemblySetupExternalFamilies() internal {
        // The actual old-Archive setup already admitted this role. Do not repeat
        // a false-to-true role transition after it has become true.
        require(
            assemblyRoles.hasRole(keccak256("ROLE_FIXITY_OPERATOR"), safeVm.addr(AX_FIXITY)),
            "ax actual fixity role missing"
        );
        require(axFirstFamily == 0 && axSecondFamily == 0, "ax already initialized");
        axFirstFamily = _axAdmitFamily("assembly-external-endowed", true, AX_WRITER_A);
        axSecondFamily = _axAdmitFamily("assembly-external-institution", false, AX_WRITER_B);
    }

    function _axAdmitFamily(string memory name, bool endowed, uint256 key)
        internal
        returns (bytes32 hash)
    {
        bytes memory salt = bytes(endowed ? "assembly-one" : "assembly-two");
        AxA.Family memory f = AxA.Family(
            keccak256(bytes(name)),
            endowed ? assemblyObjectVerifier.networkId() : keccak256("INSTITUTIONAL_ARCHIVE"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256("same jurisdiction allowed"),
            endowed ? 1 : 2,
            safeVm.addr(key),
            endowed ? assemblyObjectVerifier.profileHash() : assemblyExternal.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = assemblyExternal.familyRegistrationContext(name, f);
        _assemblyGovernanceCall(
            1,
            address(assemblyExternal),
            abi.encodeCall(assemblyExternal.admitFamily, (name, f)),
            scope,
            oldHash,
            newHash
        );
        (AxA.Family memory saved, uint8 status, uint64 revision) = assemblyExternal.family(hash);
        require(
            status == 1 && revision == 1
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(f)),
            "ax actual family admission"
        );
    }

    function _assemblyCoverExternal(
        AxE.ObjectIdentity memory object,
        bytes memory firstPath,
        bytes memory lastPath,
        bytes memory firstChunk,
        bytes memory lastChunk
    ) internal returns (AxE.Coverage memory result) {
        require(axFirstFamily != 0 && axSecondFamily != 0, "ax families missing");
        require(object.artistId == assemblyArtistId && assemblyArtistId != 0, "ax original artist");
        require(object.byteSize != 0, "ax empty object");
        bytes32 objectHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_V1"),
                block.chainid,
                address(assemblyExternal),
                address(assemblyCore),
                object
            )
        );
        bytes32 known = axOriginalCoverage[objectHash];
        if (known != 0) return _axOriginalCurrentCoverage(known, objectHash);
        // Verify endpoint bytes against the exact native leaf intervals. The real
        // verifier below independently verifies every supplied path and its root.
        _axEndpointBytes(firstPath, firstChunk, object.byteSize, 0);
        _axEndpointBytes(lastPath, lastChunk, object.byteSize, object.byteSize - 1);
        if (firstChunk.length == object.byteSize) {
            // Only this one-leaf case has the complete object bytes on this call.
            require(
                keccak256(firstChunk) == object.contentHash
                    && sha256(firstChunk) == object.sha256Digest,
                "ax full small object hashes"
            );
        }
        require(assemblyExternal.recordObject(object) == objectHash, "ax original object hash");
        (bytes32 checkpointHash, bytes32 transactionId) =
            _axCheckpoint(object, objectHash, firstPath, lastPath, firstChunk, lastChunk);
        bytes32 first =
            _axReceipt(objectHash, object.sha256Digest, checkpointHash, transactionId, true);
        bytes32 second =
            _axReceipt(objectHash, object.sha256Digest, checkpointHash, transactionId, false);
        _assemblyExternalFixity(first, 1, bytes32(0));
        _assemblyExternalFixity(second, 1, bytes32(0));
        bytes32 coverageHash = assemblyExternal.recordCoverage(first, second);
        result = assemblyExternal.requireCoverage(coverageHash, assemblyArtistId, objectHash);
        axOriginalCoverage[objectHash] = coverageHash;
    }

    function _axCheckpoint(
        AxE.ObjectIdentity memory object,
        bytes32 objectHash,
        bytes memory firstPath,
        bytes memory lastPath,
        bytes memory firstChunk,
        bytes memory lastChunk
    ) internal returns (bytes32 checkpointHash, bytes32 transactionId) {
        AxA.Checkpoint memory c;
        c.networkId = assemblyObjectVerifier.networkId();
        c.configurationHash = assemblyObjectVerifier.configurationHash();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1;
        c.transactionId =
            keccak256(abi.encode("explicit local assembly external checkpoint", objectHash));
        c.dataRoot = object.arweaveDataRoot;
        c.dataSize = object.byteSize;
        c.transactionRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(c.dataRoot)), sha256(abi.encode(uint256(c.dataSize)))
            )
        );
        c.transactionEnd = c.dataSize;
        c.blockDataSize = c.dataSize;
        c.observedAt = uint64(block.timestamp);
        bytes32 digest = assemblyObjectVerifier.checkpointDigest(c);
        AxA.ObserverProof[] memory proofs = new AxA.ObserverProof[](2);
        proofs[0] = AxA.ObserverProof(safeVm.addr(AX_OBSERVER_A), _axSign(AX_OBSERVER_A, digest));
        proofs[1] = AxA.ObserverProof(safeVm.addr(AX_OBSERVER_B), _axSign(AX_OBSERVER_B, digest));
        if (proofs[0].account > proofs[1].account) (proofs[0], proofs[1]) = (proofs[1], proofs[0]);
        checkpointHash = assemblyObjectVerifier.recordCheckpoint(
            c, abi.encode(c.dataRoot, uint256(c.dataSize)), firstPath, lastPath, proofs
        );
        AxE.NativeFacts memory facts = assemblyObjectVerifier.checkpointFacts(checkpointHash);
        require(
            facts.recordHash == checkpointHash && facts.dataRoot == object.arweaveDataRoot
                && facts.dataSize == object.byteSize && facts.transactionId == c.transactionId
                && facts.firstChunkDigest == sha256(firstChunk)
                && facts.lastChunkDigest == sha256(lastChunk),
            "ax actual native endpoint facts"
        );
        return (checkpointHash, c.transactionId);
    }

    function _axReceipt(
        bytes32 objectHash,
        bytes32 shaDigest,
        bytes32 checkpointHash,
        bytes32 transactionId,
        bool first
    ) internal returns (bytes32) {
        bytes memory locator = first
            ? abi.encodePacked(transactionId)
            : bytes(
                string.concat(
                    "https://institution.example.invalid/objects/sha256/",
                    Strings.toHexString(uint256(shaDigest), 32)
                )
            );
        uint256 key = first ? AX_WRITER_A : AX_WRITER_B;
        AxE.Receipt memory r = AxE.Receipt(
            objectHash,
            first ? axFirstFamily : axSecondFamily,
            keccak256(locator),
            keccak256(bytes(first ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            first ? assemblyObjectVerifier.profileHash() : assemblyExternal.POSSESSION_PROFILE(),
            first ? checkpointHash : bytes32(0),
            safeVm.addr(key),
            uint64(block.timestamp),
            uint256(objectHash),
            uint64(block.timestamp + 1 days)
        );
        if (!first) r.proofRecordHash = assemblyExternal.possessionHash(r);
        return assemblyExternal.recordReceipt(
            r, locator, _axSign(key, assemblyExternal.receiptDigest(r))
        );
    }

    function _assemblyExternalFixity(bytes32 receiptHash, uint8 outcome, bytes32 repairReport)
        internal
        returns (bytes32)
    {
        (AxE.Receipt memory receipt,,) = assemblyExternal.receipt(receiptHash);
        AxE.ObjectIdentity memory object = assemblyExternal.objectIdentity(receipt.objectHash);
        AxE.Fixity memory f;
        f.receiptHash = receiptHash;
        f.objectHash = receipt.objectHash;
        f.familyRecordHash = receipt.familyRecordHash;
        f.storageIdentifierHash = receipt.storageIdentifierHash;
        f.profileHash = assemblyExternal.FIXITY_PROFILE();
        f.expectedSha256 = object.sha256Digest;
        f.expectedKeccak256 = object.contentHash;
        f.expectedArweaveRoot = object.arweaveDataRoot;
        f.expectedSize = object.byteSize;
        if (outcome == 1) {
            f.observedSha256 = object.sha256Digest;
            f.observedKeccak256 = object.contentHash;
            f.observedArweaveRoot = object.arweaveDataRoot;
            f.observedSize = object.byteSize;
        }
        f.checkedAt = uint64(block.timestamp);
        f.outcome = outcome;
        f.reportHash = keccak256(
            abi.encode(
                "local full retrieval declaration fixture", receiptHash, receipt, object, outcome
            )
        );
        f.previousFixityHash = assemblyExternal.latestFixity(receiptHash);
        f.repairReportHash = repairReport;
        f.verifier = safeVm.addr(AX_FIXITY);
        f.nonce = uint256(f.previousFixityHash);
        f.deadline = uint64(block.timestamp + 1 days);
        return
            assemblyExternal.recordFixity(f, _axSign(AX_FIXITY, assemblyExternal.fixityDigest(f)));
    }

    function _axOriginalCurrentCoverage(bytes32 coverageHash, bytes32 objectHash)
        internal
        view
        returns (AxE.Coverage memory original)
    {
        original = assemblyExternal.coverage(coverageHash);
        require(
            original.coverageHash == coverageHash && original.objectHash == objectHash
                && original.artistId == assemblyArtistId,
            "ax original coverage"
        );
        AxE.CurrentPair memory current = assemblyExternal.currentReceiptPair(
            original.firstReceiptHash,
            original.secondReceiptHash,
            original.artistId,
            original.objectHash
        );
        // Preserve all twelve stable identities. Today's two passing fixity heads
        // gate availability; they never replace the original coverage preimage.
        require(
            current.objectHash == original.objectHash && current.artistId == original.artistId
                && current.contentHash == original.contentHash
                && current.sha256Digest == original.sha256Digest
                && current.arweaveDataRoot == original.arweaveDataRoot
                && current.byteSize == original.byteSize
                && current.firstFamilyRecordHash == original.firstFamilyRecordHash
                && current.secondFamilyRecordHash == original.secondFamilyRecordHash
                && current.firstReceiptHash == original.firstReceiptHash
                && current.secondReceiptHash == original.secondReceiptHash
                && current.checkpointHash == original.checkpointHash
                && current.profileHash == original.profileHash && current.firstFixityHash != 0
                && current.secondFixityHash != 0,
            "ax original pair liveness"
        );
    }

    function _axEndpointBytes(bytes memory path, bytes memory raw, uint256 size, uint256 offset)
        internal
        pure
    {
        require(
            size != 0 && offset < size && path.length >= 64 && path.length <= 6208
                && (path.length - 64) % 96 == 0 && raw.length != 0 && raw.length <= 262144,
            "ax endpoint shape"
        );
        uint256 left;
        uint256 right = size;
        uint256 cursor;
        while (cursor + 64 < path.length) {
            uint256 split = uint256(_axPathWord(path, cursor + 64));
            if (offset < split) {
                if (split < right) {
                    right = split;
                }
            } else {
                if (split > left) {
                    left = split;
                }
            }
            cursor += 96;
        }
        uint256 end = uint256(_axPathWord(path, cursor + 32));
        require(
            left < right && end > left && end <= right && offset >= left && offset < end
                && end - left == raw.length && _axPathWord(path, cursor) == sha256(raw),
            "ax endpoint bytes"
        );
    }

    function _axPathWord(bytes memory data, uint256 at) internal pure returns (bytes32 word) {
        require(at + 32 <= data.length, "ax path word");
        assembly ("memory-safe") { word := mload(add(add(data, 32), at)) }
    }

    function _axSign(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
