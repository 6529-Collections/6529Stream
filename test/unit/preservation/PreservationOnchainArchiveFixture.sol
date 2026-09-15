// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArchivalCoverage
} from "../../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import {
    StreamArweaveCheckpointVerifier
} from "../../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import {
    StreamRoleRegistry
} from "../../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamFinalityArtifactCoverage
} from "../../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamArchivalTypes as OcA
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamFinalityArtifactTypes as OcF
} from "../../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";

interface PreservationOnchainArchiveVm {
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8, bytes32, bytes32);
}

interface PreservationOnchainArchiveExecutor {
    function roleRegistry() external view returns (address);
    function execute(
        address target,
        bytes calldata data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) external returns (bytes memory);
}

interface PreservationOnchainArchiveFacade {
    function core() external view returns (address);
    function archivalCoverage() external view returns (address);
}

/// @dev Actual RoleRegistry, single-chunk native verifier, dual-family Archive, STOP-byte
/// store and artifact coverage. Network observations use synthetic local ECDSA fixture
/// keys; they are not real Arweave uploads or consensus evidence. The outer fixture owns
/// Core/Artist/Executor boundaries, including role binding through the explicit hook.
/// This helper performs no mocking and introduces no Safe inheritance or test methods.
abstract contract PreservationOnchainArchiveFixture {
    PreservationOnchainArchiveVm private constant ocVm =
        PreservationOnchainArchiveVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant OC_OBSERVER_A = 0x652981;
    uint256 private constant OC_OBSERVER_B = 0x652982;
    uint256 private constant OC_FIRST_WRITER = 0x652983;
    uint256 private constant OC_SECOND_WRITER = 0x652984;
    uint256 private constant OC_FIXITY_OPERATOR = 0x652985;
    uint256 private constant OC_CHUNK_BYTES = 8192;

    StreamRoleRegistry internal ocRoles;
    StreamArweaveCheckpointVerifier internal ocVerifier;
    StreamArchivalCoverage internal ocArchive;
    StreamFinalityArtifactCoverage internal ocArtifact;
    StreamSchemaDocumentStore internal ocStore;
    address internal ocCore;
    address internal ocExecutor;
    address internal ocFacade;
    bytes32 internal ocFirstFamily;
    bytes32 internal ocSecondFamily;
    uint256 private ocSerial;

    struct OcCoveredArtifact {
        bytes32 artifactHash;
        bytes32 completionHash;
    }
    mapping(bytes32 => bytes32) private ocChunkCoverage;
    mapping(bytes32 => OcCoveredArtifact) private ocCoveredArtifacts;

    /// @dev Called after ocRoles exists and before the actual Archive constructor.
    /// The caller must bind Executor.roleRegistry and the selected module's Executor.
    function _ocBindArchiveRoles(address executor_, address roles_) internal virtual;
    function _ocArtistId() internal view virtual returns (bytes32);

    function _ocSetupArchive(address core_, address executor_, address facade_) internal {
        require(address(ocArchive) == address(0), "oc archive already initialized");
        require(
            core_.code.length != 0 && executor_.code.length != 0 && facade_.code.length != 0,
            "oc graph code"
        );
        require(
            block.timestamp != 0 && block.timestamp <= type(uint64).max - 1 days, "oc timestamp"
        );
        ocCore = core_;
        ocExecutor = executor_;
        ocFacade = facade_;
        ocRoles = new StreamRoleRegistry(executor_);
        _ocBindArchiveRoles(executor_, address(ocRoles));
        require(
            PreservationOnchainArchiveExecutor(executor_).roleRegistry() == address(ocRoles),
            "oc bound roles"
        );
        OcA.Observer[] memory observers = new OcA.Observer[](2);
        observers[0] = OcA.Observer(ocVm.addr(OC_OBSERVER_A), keccak256("oc observer one"));
        observers[1] = OcA.Observer(ocVm.addr(OC_OBSERVER_B), keccak256("oc observer two"));
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        ocVerifier =
            new StreamArweaveCheckpointVerifier(executor_, observers, 2, _ocSignatureConfig());
        ocArchive = new StreamArchivalCoverage(
            core_,
            executor_,
            address(ocRoles),
            address(ocVerifier),
            _ocSignatureConfig(),
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2
            )
        );
        _ocGrantFixity(ocVm.addr(OC_FIXITY_OPERATOR));
        ocFirstFamily = _ocAdmit("oc-arweave-family", true, ocVm.addr(OC_FIRST_WRITER));
        ocSecondFamily = _ocAdmit("oc-ipfs-family", false, ocVm.addr(OC_SECOND_WRITER));
    }

    /// @dev Exactly one CREATE here. Caller predicts finality after its own intervening
    /// deployments, then supplies its reciprocal selection before _ocCover is called.
    function _ocDeployArtifact(address schema_, address store_, address predictedFinality_)
        internal
        returns (address)
    {
        require(
            address(ocArchive) != address(0) && address(ocArtifact) == address(0),
            "oc artifact setup order"
        );
        ocStore = StreamSchemaDocumentStore(store_);
        ocArtifact = new StreamFinalityArtifactCoverage(
            ocCore,
            address(ocArchive),
            schema_,
            store_,
            predictedFinality_,
            ocExecutor,
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 500000, 300000, 2
            )
        );
        return address(ocArtifact);
    }

    /// @dev Covers all bytes, in canonical full 8192-byte chunks plus the final tail.
    /// Empty bytes have their separate inventory grammar and cannot become an artifact.
    /// Repeated content reuses its original receipt/fixity evidence, without refreshes
    /// that would invalidate earlier plans. Actual current checks still run on reuse.
    function _ocCover(bytes memory raw, bytes32 schema_, bytes32 canon_)
        internal
        returns (bytes32 artifactHash, bytes32 completionHash)
    {
        require(address(ocArtifact) != address(0), "oc artifact missing");
        require(raw.length != 0 && raw.length <= 64 * OC_CHUNK_BYTES, "oc artifact length");
        require(schema_ != 0 && canon_ != 0, "oc artifact schema");
        require(PreservationOnchainArchiveFacade(ocFacade).core() == ocCore, "oc facade core");
        require(
            PreservationOnchainArchiveFacade(ocFacade).archivalCoverage() == address(ocArchive),
            "oc facade archive"
        );
        bytes32 artistId = _ocArtistId();
        require(artistId != 0, "oc artist missing");
        bytes32 cacheKey =
            keccak256(abi.encode(artistId, schema_, canon_, keccak256(raw), raw.length));
        OcCoveredArtifact memory cached = ocCoveredArtifacts[cacheKey];
        if (cached.artifactHash != 0) {
            ocArtifact.requireArtifactCoverage(cached.completionHash, artistId, cached.artifactHash);
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
        artifactHash = ocArtifact.recordArtifact(a);
        bytes32 plan = ocArtifact.beginCoverage(artifactHash, ocFirstFamily, ocSecondFamily);
        for (uint32 i; i < count; ++i) {
            completionHash = ocArtifact.coverNextChunk(plan, i, originalCoverage[i]);
        }
        require(completionHash != 0, "oc completion missing");
        ocArtifact.requireArtifactCoverage(completionHash, artistId, artifactHash);
        ocCoveredArtifacts[cacheKey] = OcCoveredArtifact(artifactHash, completionHash);
    }

    function _ocCoverChunk(bytes32 artistId, bytes memory raw) private returns (bytes32 covered) {
        bytes32 key = keccak256(abi.encode(artistId, keccak256(raw)));
        covered = ocChunkCoverage[key];
        if (covered != 0) {
            ocArchive.requireCoverage(covered, artistId, keccak256(raw));
            return covered;
        }
        (bytes32 chunkHash, address pointer) = ocStore.publishChunk(raw);
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
        bytes32 envelopeHash = ocArchive.recordChunkEnvelope(e, pointer);
        uint256 serial = ++ocSerial;
        (bytes32 checkpointHash, bytes32 transactionId) = _ocCheckpoint(raw, serial);
        bytes32 first = _ocReceipt(e, envelopeHash, true, checkpointHash, transactionId, serial);
        bytes32 second = _ocReceipt(e, envelopeHash, false, checkpointHash, transactionId, serial);
        _ocFixity(e, first, serial);
        _ocFixity(e, second, serial);
        covered = ocArchive.recordCoverage(first, second);
        ocArchive.requireCoverage(covered, artistId, chunkHash);
        ocChunkCoverage[key] = covered;
    }

    function _ocCheckpoint(bytes memory raw, uint256 serial)
        private
        returns (bytes32 hash, bytes32 transactionId)
    {
        OcA.Checkpoint memory c;
        c.networkId = ocVerifier.networkId();
        c.blockHash = abi.encodePacked(
            keccak256(abi.encode("oc synthetic block", serial)), bytes16(uint128(serial))
        );
        c.blockHeight = 1500000 + uint64(serial);
        c.dataRoot = _ocNativeLeaf(sha256(raw), raw.length);
        c.transactionRoot = _ocNativeLeaf(c.dataRoot, raw.length);
        c.blockDataSize = raw.length;
        c.transactionId = keccak256(
            abi.encode("oc synthetic transaction", address(ocVerifier), serial, keccak256(raw))
        );
        c.dataSize = uint64(raw.length);
        c.transactionEnd = raw.length;
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = ocVerifier.configurationHash();
        bytes32 digest = ocVerifier.checkpointDigest(c);
        OcA.ObserverProof[] memory proofs = new OcA.ObserverProof[](2);
        proofs[0] = OcA.ObserverProof(ocVm.addr(OC_OBSERVER_A), _ocSign(OC_OBSERVER_A, digest));
        proofs[1] = OcA.ObserverProof(ocVm.addr(OC_OBSERVER_B), _ocSign(OC_OBSERVER_B, digest));
        if (proofs[0].account > proofs[1].account) (proofs[0], proofs[1]) = (proofs[1], proofs[0]);
        hash = ocVerifier.recordCheckpoint(
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
            endowed ? ocVerifier.profileHash() : ocArchive.POSSESSION_PROFILE(),
            endowed ? checkpointHash : bytes32(0),
            ocVm.addr(writerKey),
            uint64(block.timestamp),
            serial,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) {
            r.proofRecordHash = ocArchive.possessionHash(
                OcA.Possession(
                    r.envelopeHash,
                    r.familyRecordHash,
                    r.storageIdentifierHash,
                    r.writer,
                    r.observedAt
                )
            );
        }
        hash = ocArchive.recordReceipt(r, locator, _ocSign(writerKey, ocArchive.receiptDigest(r)));
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1"),
                        block.chainid,
                        address(ocArchive),
                        r
                    )
                ),
            "oc receipt hash"
        );
        (OcA.ReceiptTerms memory saved, bytes memory savedLocator, bytes memory signature) =
            ocArchive.receipt(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                && keccak256(savedLocator) == keccak256(locator) && signature.length == 65,
            "oc original receipt"
        );
    }

    function _ocFixity(OcA.Envelope memory e, bytes32 receiptHash, uint256 serial) private {
        (OcA.ReceiptTerms memory r,,) = ocArchive.receipt(receiptHash);
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
            ocVm.addr(OC_FIXITY_OPERATOR),
            serial,
            uint64(block.timestamp + 1 days)
        );
        bytes32 hash =
            ocArchive.recordFixity(f, _ocSign(OC_FIXITY_OPERATOR, ocArchive.fixityDigest(f)));
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARCHIVAL_FIXITY_RECORD_V1"),
                        block.chainid,
                        address(ocArchive),
                        f
                    )
                ),
            "oc fixity hash"
        );
        require(ocArchive.latestFixity(receiptHash) == hash, "oc original fixity");
    }

    function _ocAdmit(string memory name, bool endowed, address writer)
        private
        returns (bytes32 hash)
    {
        bytes memory salt = bytes(endowed ? "oc-one" : "oc-two");
        OcA.Family memory f = OcA.Family(
            keccak256(bytes(name)),
            endowed ? ocVerifier.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256("same jurisdiction allowed"),
            endowed ? 1 : 2,
            writer,
            endowed ? ocVerifier.profileHash() : ocArchive.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = ocArchive.familyRegistrationContext(name, f);
        bytes memory result = PreservationOnchainArchiveExecutor(ocExecutor)
            .execute(
                address(ocArchive),
                abi.encodeCall(ocArchive.admitFamily, (name, f)),
                scope,
                oldHash,
                newHash
            );
        (OcA.Family memory saved, uint8 status) = ocArchive.family(hash);
        require(
            abi.decode(result, (bytes32)) == hash && status == 1
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(f)),
            "oc family admitted"
        );
    }

    function _ocGrantFixity(address holder) private {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        (bytes32 chain, uint64 revision) = ocRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = ocRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(ocRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(ocRoles),
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
                address(ocRoles),
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
                address(ocRoles),
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
                address(ocRoles),
                scope,
                true,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        PreservationOnchainArchiveExecutor(ocExecutor)
            .execute(
                address(ocRoles),
                abi.encodeCall(ocRoles.grantRole, (role, holder)),
                scope,
                oldHash,
                newHash
            );
        require(ocRoles.hasRole(role, holder), "oc actual fixity role");
    }

    function _ocSignatureConfig()
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(
            "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
        );
    }

    function _ocSign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = ocVm.sign(key, digest);
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
}
