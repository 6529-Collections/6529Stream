// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/IStreamArchivalCoverage.sol";
import "../../interfaces/stream/preservation/IStreamArchivalChunkCoverage.sol";
import "../../interfaces/stream/preservation/IStreamArchivalBindings.sol";
import "../../interfaces/stream/preservation/IStreamArchivalCheckpointVerifier.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamArchivalSignatures.sol";

/// @notice Actual public bytes, independent family receipts and current independent fixity evidence.
/// @dev Its endowed profile trusts a pinned observer quorum for network anchoring, not governance roots.
contract StreamArchivalCoverage is
    StreamGasParameterHost,
    IStreamArchivalCoverage,
    IStreamArchivalChunkCoverage
{
    bytes32 public constant override profileHash =
        keccak256("6529STREAM_PUBLIC_DUAL_FAMILY_ARCHIVAL_V1");
    bytes32 public constant POSSESSION_PROFILE =
        keccak256("6529STREAM_RAW_CID_SHA256_POSSESSION_V1");
    bytes32 private constant _CAI = keccak256("CONTENT_ADDRESSED_INCLUSION");
    bytes32 private constant _POSSESSION = keccak256("ATTESTED_POSSESSION");
    bytes32 private constant _SIGNATURE_GAS =
        keccak256("6529STREAM_GGP_ARCHIVAL_ERC1271_VERIFY_GAS");
    bytes32 private constant _READ_GAS = keccak256("6529STREAM_GGP_ARCHIVAL_DEPENDENCY_READ_GAS");
    bytes32 private constant _RECEIPT_TYPEHASH = keccak256(
        "StreamArchivalReceipt(bytes32 envelopeHash,bytes32 familyRecordHash,bytes32 storageIdentifierHash,bytes32 evidenceClass,bytes32 proofProfileHash,bytes32 proofRecordHash,address writer,uint64 observedAt,uint256 nonce,uint64 deadline)"
    );
    bytes32 private constant _FIXITY_TYPEHASH = keccak256(
        "StreamArchivalFixity(bytes32 receiptRecordHash,bytes32 envelopeHash,bytes32 familyRecordHash,bytes32 expectedDigest,bytes32 observedDigest,uint64 observedSize,uint64 checkedAt,uint8 outcome,bytes32 reportHash,bytes32 previousFixityHash,bytes32 repairReportHash,address verifier,uint256 nonce,uint64 deadline)"
    );

    address public immutable override core;
    address public immutable override roleRegistry;
    address public immutable override checkpointVerifier;
    bytes32 private immutable _coreCodeHash;
    bytes32 private immutable _roleCodeHash;
    bytes32 private immutable _verifierCodeHash;
    bytes32 private immutable _endowedProfile;
    bytes32 private immutable _endowedConfiguration;
    bytes32 private immutable _endowedNetwork;
    mapping(bytes32 => A.Envelope) private _envelopes;
    mapping(bytes32 => bytes) private _payloads;
    mapping(bytes32 => A.Family) private _families;
    mapping(bytes32 => uint8) private _familyStatus;
    mapping(bytes32 => uint64) private _familyRevisions;
    mapping(bytes32 => A.ReceiptTerms) private _receipts;
    mapping(bytes32 => bytes) private _identifiers;
    mapping(bytes32 => bytes) private _receiptSignatures;
    mapping(bytes32 => A.FixityTerms) private _fixities;
    mapping(bytes32 => bytes) private _fixitySignatures;
    mapping(bytes32 => bytes32) private _latestFixities;
    mapping(bytes32 => A.CoverageFacts) private _coverage;
    mapping(bytes32 => bool) private _nonces;

    struct ChunkPointer {
        address pointer;
        bytes32 codeHash;
    }
    mapping(bytes32 => ChunkPointer) private _chunkPointers;
    uint64 public override coverageValidationEpoch = 1;
    bytes32 private constant _CHUNK_SCHEMA = keccak256("6529STREAM_FINALITY_ARTIFACT_CHUNK_V1");

    constructor(
        address core_,
        address executor,
        address roles,
        address verifier,
        GasParameterConfig memory signatureGas,
        GasParameterConfig memory readGas
    ) StreamGasParameterHost(executor) {
        if (
            core_.code.length == 0 || roles.code.length == 0 || verifier.code.length == 0
                || executor == address(0)
                || keccak256(bytes(signatureGas.name)) != keccak256("ARCHIVAL_ERC1271_VERIFY_GAS")
                || signatureGas.floor < 90000 || signatureGas.failureClass != 2
                || keccak256(bytes(readGas.name)) != keccak256("ARCHIVAL_DEPENDENCY_READ_GAS")
                || readGas.floor < 50000 || readGas.failureClass != 2
        ) revert A.InvalidArchivalConfiguration();
        _registerGasParameter(signatureGas);
        _registerGasParameter(readGas);
        core = core_;
        roleRegistry = roles;
        checkpointVerifier = verifier;
        _coreCodeHash = core_.codehash;
        _roleCodeHash = roles.codehash;
        _verifierCodeHash = verifier.codehash;
        address modules = _selected(core_, keccak256("MODULE_REGISTRY"));
        if (
            _address(
                        modules,
                        abi.encodeCall(IStreamArchivalGovernanceBinding.governanceExecutor, ())
                    ) != executor
                || _address(
                        executor, abi.encodeCall(IStreamArchivalGovernanceBinding.roleRegistry, ())
                    ) != roles
                || _address(roles, abi.encodeCall(IStreamArchivalGovernanceBinding.owner, ()))
                    != executor
                || _address(
                        verifier, abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ())
                    ) != executor
                || abi.decode(
                        _read(
                            roles,
                            abi.encodeCall(
                                IStreamRoleRegistry.supportsInterface,
                                (type(IStreamRoleRegistry).interfaceId)
                            ),
                            32
                        ),
                        (bool)
                    ) != true
                || abi.decode(
                        _read(
                            verifier,
                            abi.encodeCall(
                                IStreamArchivalCheckpointVerifier.supportsInterface,
                                (type(IStreamArchivalCheckpointVerifier).interfaceId)
                            ),
                            32
                        ),
                        (bool)
                    ) != true
        ) {
            revert A.InvalidArchivalConfiguration();
        }
        _endowedProfile = abi.decode(
            _read(verifier, abi.encodeCall(IStreamArchivalCheckpointVerifier.profileHash, ()), 32),
            (bytes32)
        );
        _endowedConfiguration = abi.decode(
            _read(
                verifier,
                abi.encodeCall(IStreamArchivalCheckpointVerifier.configurationHash, ()),
                32
            ),
            (bytes32)
        );
        _endowedNetwork = abi.decode(
            _read(verifier, abi.encodeCall(IStreamArchivalCheckpointVerifier.networkId, ()), 32),
            (bytes32)
        );
        if (
            _endowedProfile != keccak256("6529STREAM_ARWEAVE_SINGLE_CHUNK_QUORUM_V1")
                || _endowedNetwork != keccak256("ARWEAVE_MAINNET")
                || _endowedConfiguration == bytes32(0)
        ) {
            revert A.InvalidArchivalConfiguration();
        }
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArchivalCoverage).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId
            || id == type(IStreamArchivalChunkCoverage).interfaceId;
    }

    function recordEnvelope(A.Envelope calldata e, bytes calldata payload)
        external
        override
        returns (bytes32 hash)
    {
        if (
            e.artistId == bytes32(0)
                || e.schemaId != keccak256("6529STREAM_PUBLIC_ESTATE_EVIDENCE_V1")
                || e.canonicalizationId != keccak256("BINARY_EXACT_V1") || e.digestAlgorithm != 2
                || e.visibility != 1 || e.custodyPolicyHash != bytes32(0) || payload.length == 0
                || payload.length > 8192 || e.byteSize != payload.length
                || e.evidenceHash != keccak256(payload) || e.payloadDigest != sha256(payload)
        ) revert A.InvalidArchivalEnvelope();
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_ENVELOPE_V1"), block.chainid, address(this), e
            )
        );
        if (_envelopes[hash].artistId != bytes32(0)) revert A.ArchivalRecordExists(hash);
        _envelopes[hash] = e;
        _payloads[hash] = payload;
        emit ArchivalEnvelopeRecorded(1, hash, e);
    }

    function envelope(bytes32 hash)
        external
        view
        override
        returns (A.Envelope memory, bytes memory)
    {
        if (_envelopes[hash].schemaId == _CHUNK_SCHEMA) {
            return (_envelopes[hash], _chunkPayload(hash));
        }
        return (_envelopes[hash], _payloads[hash]);
    }

    function recordChunkEnvelope(A.Envelope calldata e, address pointer)
        external
        override
        returns (bytes32 hash)
    {
        if (
            e.artistId == bytes32(0) || e.schemaId != _CHUNK_SCHEMA
                || e.canonicalizationId != keccak256("BINARY_EXACT_V1") || e.digestAlgorithm != 2
                || e.visibility != 1 || e.custodyPolicyHash != bytes32(0) || e.byteSize == 0
                || e.byteSize > 8192 || pointer.code.length != uint256(e.byteSize) + 1
        ) {
            revert A.InvalidArchivalEnvelope();
        }
        bytes memory payload = _pointerPayload(pointer, e.byteSize);
        if (e.evidenceHash != keccak256(payload) || e.payloadDigest != sha256(payload)) {
            revert A.InvalidArchivalEnvelope();
        }
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_CHUNK_ENVELOPE_V1"),
                block.chainid,
                address(this),
                e,
                pointer,
                pointer.codehash
            )
        );
        if (_envelopes[hash].artistId != bytes32(0)) revert A.ArchivalRecordExists(hash);
        _envelopes[hash] = e;
        _chunkPointers[hash] = ChunkPointer(pointer, pointer.codehash);
        emit ArchivalEnvelopeRecorded(1, hash, e);
        emit ArchivalChunkEnvelopeRecorded(1, hash, pointer, pointer.codehash);
    }

    function chunkEnvelopePointer(bytes32 hash) external view override returns (address, bytes32) {
        ChunkPointer storage p = _chunkPointers[hash];
        return (p.pointer, p.codeHash);
    }

    function familyRegistrationContext(string calldata name, A.Family calldata f)
        public
        view
        override
        returns (bytes32 hash, bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        _validateFamily(name, f);
        hash = keccak256(
            abi.encode(keccak256("6529STREAM_ARCHIVAL_FAMILY_V1"), block.chainid, address(this), f)
        );
        if (_familyStatus[hash] != 0) revert A.ArchivalRecordExists(hash);
        scope = _familyScope(hash);
        oldHash = _familyState(hash, 0, 0);
        newHash = _familyState(hash, 1, 1);
    }

    function admitFamily(string calldata name, A.Family calldata f)
        external
        override
        returns (bytes32 hash)
    {
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = familyRegistrationContext(name, f);
        bytes32 action = _governed(scope, oldHash, newHash);
        _families[hash] = f;
        _familyStatus[hash] = 1;
        _familyRevisions[hash] = 1;
        emit ArchivalFamilyRecorded(1, hash, action, name, f);
    }

    function familyStatusContext(bytes32 hash, uint8 next)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        uint8 prior = _familyStatus[hash];
        uint64 revision = _familyRevisions[hash];
        if (prior == 0 || next == 0 || next > 3 || next == prior || revision == type(uint64).max) {
            revert A.InvalidArchivalFamily();
        }
        return (
            _familyScope(hash),
            _familyState(hash, prior, revision),
            _familyState(hash, next, revision + 1)
        );
    }

    function setFamilyStatus(bytes32 hash, uint8 next) external override {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = familyStatusContext(hash, next);
        bytes32 action = _governed(scope, oldHash, newHash);
        uint8 prior = _familyStatus[hash];
        _familyStatus[hash] = next;
        uint64 revision = ++_familyRevisions[hash];
        _advanceValidationEpoch();
        emit ArchivalFamilyStatusChanged(1, hash, action, prior, next, revision);
    }

    function family(bytes32 hash) external view override returns (A.Family memory, uint8) {
        return (_families[hash], _familyStatus[hash]);
    }

    function familyRevision(bytes32 hash) external view override returns (uint64) {
        return _familyRevisions[hash];
    }

    function possessionHash(A.Possession calldata p) external view override returns (bytes32) {
        return _possessionHash(
            p.envelopeHash, p.familyRecordHash, p.storageIdentifierHash, p.writer, p.observedAt
        );
    }

    function receiptDigest(A.ReceiptTerms calldata t) public view override returns (bytes32) {
        return _typed(keccak256(abi.encode(_RECEIPT_TYPEHASH, t)));
    }

    function recordReceipt(
        A.ReceiptTerms calldata t,
        bytes calldata identifier,
        bytes calldata signature
    ) external override returns (bytes32 hash) {
        A.Envelope storage e = _envelopes[t.envelopeHash];
        A.Family storage f = _families[t.familyRecordHash];
        if (e.schemaId == _CHUNK_SCHEMA) _chunkPayload(t.envelopeHash);
        if (
            e.artistId == bytes32(0) || _familyStatus[t.familyRecordHash] != 1
                || t.writer != f.storingAgent || t.observedAt == 0 || t.observedAt > block.timestamp
                || t.deadline < block.timestamp || t.storageIdentifierHash != keccak256(identifier)
                || t.proofProfileHash != f.verifierProfileHash
        ) {
            revert A.InvalidArchivalReceipt();
        }
        if (f.economics == 1) {
            if (t.evidenceClass != _CAI || identifier.length != 32) {
                revert A.InvalidArchivalReceipt();
            }
            _checkpoint(t.proofRecordHash, e, bytes32(identifier));
        } else {
            if (
                t.evidenceClass != _POSSESSION || identifier.length != 36
                    || bytes4(identifier) != 0x01551220
                    || bytes32(identifier[4:]) != e.payloadDigest
                    || t.proofRecordHash
                        != _possessionHash(
                            t.envelopeHash,
                            t.familyRecordHash,
                            t.storageIdentifierHash,
                            t.writer,
                            t.observedAt
                        )
            ) revert A.InvalidArchivalReceipt();
        }
        StreamArchivalSignatures.requireValid(
            t.writer, receiptDigest(t), signature, _gasParameterValue(_SIGNATURE_GAS)
        );
        _consume(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARCHIVAL_RECEIPT_NONCE_V1"),
                    t.writer,
                    t.familyRecordHash,
                    t.nonce
                )
            )
        );
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1"), block.chainid, address(this), t
            )
        );
        if (_receipts[hash].writer != address(0)) revert A.ArchivalRecordExists(hash);
        _receipts[hash] = t;
        _identifiers[hash] = identifier;
        _receiptSignatures[hash] = signature;
        emit ArchivalReceiptRecorded(1, hash, t.envelopeHash, t.familyRecordHash, t);
    }

    function receipt(bytes32 hash)
        external
        view
        override
        returns (A.ReceiptTerms memory, bytes memory, bytes memory)
    {
        return (_receipts[hash], _identifiers[hash], _receiptSignatures[hash]);
    }

    function fixityDigest(A.FixityTerms calldata t) public view override returns (bytes32) {
        return _typed(keccak256(abi.encode(_FIXITY_TYPEHASH, t)));
    }

    function recordFixity(A.FixityTerms calldata t, bytes calldata signature)
        external
        override
        returns (bytes32 hash)
    {
        A.ReceiptTerms storage r = _receipts[t.receiptRecordHash];
        A.Envelope storage e = _envelopes[r.envelopeHash];
        bytes32 prior = _latestFixities[t.receiptRecordHash];
        A.FixityTerms storage p = _fixities[prior];
        if (
            r.writer == address(0) || t.envelopeHash != r.envelopeHash
                || t.familyRecordHash != r.familyRecordHash || t.expectedDigest != e.payloadDigest
                || t.checkedAt < r.observedAt || t.checkedAt == 0 || t.checkedAt > block.timestamp
                || t.deadline < block.timestamp || t.outcome == 0 || t.outcome > 2
                || t.reportHash == bytes32(0) || t.previousFixityHash != prior
                || t.verifier == r.writer || t.verifier == address(0) || t.checkedAt < p.checkedAt
                || (t.outcome == 1
                    && (t.observedDigest != e.payloadDigest || t.observedSize != e.byteSize))
                || (p.outcome == 2 && t.outcome == 1 && t.repairReportHash == bytes32(0))
                || ((p.outcome != 2 || t.outcome != 1) && t.repairReportHash != bytes32(0))
        ) revert A.InvalidArchivalFixity();
        if (
            roleRegistry.codehash != _roleCodeHash
                || _address(
                        governanceAuthority,
                        abi.encodeCall(IStreamArchivalGovernanceBinding.roleRegistry, ())
                    ) != roleRegistry
                || _address(
                        roleRegistry, abi.encodeCall(IStreamArchivalGovernanceBinding.owner, ())
                    ) != governanceAuthority
        ) revert A.ArchivalComponentChanged(roleRegistry);
        if (!abi.decode(
                _read(
                    roleRegistry,
                    abi.encodeCall(
                        IStreamRoleRegistry.hasRole, (keccak256("ROLE_FIXITY_OPERATOR"), t.verifier)
                    ),
                    32
                ),
                (bool)
            )) revert A.ArchivalUnauthorized(t.verifier);
        StreamArchivalSignatures.requireValid(
            t.verifier, fixityDigest(t), signature, _gasParameterValue(_SIGNATURE_GAS)
        );
        _consume(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARCHIVAL_FIXITY_NONCE_V1"),
                    t.verifier,
                    t.receiptRecordHash,
                    t.nonce
                )
            )
        );
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_FIXITY_RECORD_V1"), block.chainid, address(this), t
            )
        );
        _fixities[hash] = t;
        _fixitySignatures[hash] = signature;
        _latestFixities[t.receiptRecordHash] = hash;
        if (prior != bytes32(0)) _advanceValidationEpoch();
        emit ArchivalFixityRecorded(1, hash, t.receiptRecordHash, t);
    }

    function fixity(bytes32 hash)
        external
        view
        override
        returns (A.FixityTerms memory, bytes memory)
    {
        return (_fixities[hash], _fixitySignatures[hash]);
    }

    function latestFixity(bytes32 receiptHash) external view override returns (bytes32) {
        return _latestFixities[receiptHash];
    }

    function recordCoverage(bytes32 first, bytes32 second)
        external
        override
        returns (bytes32 hash)
    {
        A.CoverageFacts memory f = _coverageFacts(first, second);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_COVERAGE_RECORD_V1"), block.chainid, address(this), f
            )
        );
        if (_coverage[hash].coverageRecordHash != bytes32(0)) revert A.ArchivalRecordExists(hash);
        f.coverageRecordHash = hash;
        _coverage[hash] = f;
        emit ArchivalCoverageRecorded(1, hash, f.envelopeHash, f);
    }

    function coverage(bytes32 hash) external view override returns (A.CoverageFacts memory) {
        return _coverage[hash];
    }

    function requireCoverage(bytes32 hash, bytes32 artistId, bytes32 evidenceHash)
        external
        view
        override
        returns (A.CoverageFacts memory saved)
    {
        _requireArtistBinding();
        saved = _coverage[hash];
        if (
            saved.coverageRecordHash == bytes32(0) || saved.artistId != artistId
                || saved.evidenceHash != evidenceHash
        ) revert A.InvalidArchivalCoverage();
        A.CoverageFacts memory actual =
            _coverageFacts(saved.firstReceiptRecordHash, saved.secondReceiptRecordHash);
        actual.coverageRecordHash = hash;
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(saved))) {
            revert A.InvalidArchivalCoverage();
        }
    }

    function requireCoverageEnvironment() external view override returns (bytes32) {
        address facade = _requireArtistBinding();
        if (
            checkpointVerifier.codehash != _verifierCodeHash
                || abi.decode(
                        _read(
                            checkpointVerifier,
                            abi.encodeCall(IStreamArchivalCheckpointVerifier.profileHash, ()),
                            32
                        ),
                        (bytes32)
                    ) != _endowedProfile
                || abi.decode(
                        _read(
                            checkpointVerifier,
                            abi.encodeCall(IStreamArchivalCheckpointVerifier.configurationHash, ()),
                            32
                        ),
                        (bytes32)
                    ) != _endowedConfiguration
                || abi.decode(
                        _read(
                            checkpointVerifier,
                            abi.encodeCall(IStreamArchivalCheckpointVerifier.networkId, ()),
                            32
                        ),
                        (bytes32)
                    ) != _endowedNetwork
        ) {
            revert A.ArchivalComponentChanged(checkpointVerifier);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_COVERAGE_ENVIRONMENT_V1"),
                block.chainid,
                address(this),
                address(this).codehash,
                core,
                _coreCodeHash,
                facade,
                facade.codehash,
                checkpointVerifier,
                _verifierCodeHash,
                _endowedProfile,
                _endowedConfiguration,
                _endowedNetwork
            )
        );
    }

    function _requireArtistBinding() private view returns (address facade) {
        if (core.codehash != _coreCodeHash) revert A.ArchivalComponentChanged(core);
        facade = _selected(core, keccak256("ARTIST_REGISTRY"));
        if (
            _address(facade, abi.encodeCall(IStreamArtistArchivalBinding.core, ())) != core
                || _address(
                        facade, abi.encodeCall(IStreamArtistArchivalBinding.archivalCoverage, ())
                    ) != address(this)
        ) {
            revert A.ArchivalComponentChanged(facade);
        }
    }

    function _advanceValidationEpoch() private {
        if (coverageValidationEpoch == type(uint64).max) revert ArchivalValidationEpochOverflow();
        ++coverageValidationEpoch;
        emit ArchivalValidationEpochAdvanced(1, coverageValidationEpoch);
    }

    function _chunkPayload(bytes32 hash) private view returns (bytes memory payload) {
        ChunkPointer storage p = _chunkPointers[hash];
        A.Envelope storage e = _envelopes[hash];
        if (
            p.pointer == address(0) || p.pointer.codehash != p.codeHash
                || p.pointer.code.length != uint256(e.byteSize) + 1
        ) revert A.ArchivalComponentChanged(p.pointer);
        payload = _pointerPayload(p.pointer, e.byteSize);
        if (keccak256(payload) != e.evidenceHash || sha256(payload) != e.payloadDigest) {
            revert A.InvalidArchivalEnvelope();
        }
    }

    function _pointerPayload(address pointer, uint64 length)
        private
        view
        returns (bytes memory payload)
    {
        bytes1 prefix;
        assembly ("memory-safe") {
            let scratch := mload(0x40)
            extcodecopy(pointer, scratch, 0, 1)
            prefix := mload(scratch)
        }
        if (prefix != 0) revert A.InvalidArchivalEnvelope();
        payload = new bytes(length);
        assembly ("memory-safe") { extcodecopy(pointer, add(payload, 32), 1, length) }
    }

    function nonceUsed(bytes32 key) external view override returns (bool) {
        return _nonces[key];
    }

    function _coverageFacts(bytes32 first, bytes32 second)
        private
        view
        returns (A.CoverageFacts memory f)
    {
        A.ReceiptTerms storage a = _receipts[first];
        A.ReceiptTerms storage b = _receipts[second];
        A.Family storage x = _families[a.familyRecordHash];
        A.Family storage y = _families[b.familyRecordHash];
        bytes32 fixA = _latestFixities[first];
        bytes32 fixB = _latestFixities[second];
        if (
            first == second || a.writer == address(0) || b.writer == address(0)
                || a.envelopeHash != b.envelopeHash || _familyStatus[a.familyRecordHash] != 1
                || _familyStatus[b.familyRecordHash] != 1 || x.economics != 1
                || a.evidenceClass != _CAI || b.evidenceClass != _POSSESSION || y.economics != 2
                || x.networkId == y.networkId || x.protocolLineage == y.protocolLineage
                || x.addressingLineage == y.addressingLineage || x.custodianId == y.custodianId
                || x.fundingDependency == y.fundingDependency
                || x.retrievalDependency == y.retrievalDependency
                || x.storingAgent == y.storingAgent || _fixities[fixA].outcome != 1
                || _fixities[fixB].outcome != 1
        ) revert A.InvalidArchivalCoverage();
        A.Envelope storage e = _envelopes[a.envelopeHash];
        if (e.schemaId == _CHUNK_SCHEMA) _chunkPayload(a.envelopeHash);
        _checkpoint(a.proofRecordHash, e, bytes32(_identifiers[first]));
        f = A.CoverageFacts(
            0,
            a.envelopeHash,
            e.artistId,
            e.evidenceHash,
            a.familyRecordHash,
            b.familyRecordHash,
            first,
            second,
            fixA,
            fixB,
            a.proofRecordHash,
            profileHash
        );
    }

    function _checkpoint(bytes32 hash, A.Envelope storage e, bytes32 transactionId) private view {
        if (checkpointVerifier.codehash != _verifierCodeHash) {
            revert A.ArchivalComponentChanged(checkpointVerifier);
        }
        A.CheckpointFacts memory f = abi.decode(
            _read(
                checkpointVerifier,
                abi.encodeCall(IStreamArchivalCheckpointVerifier.checkpointFacts, (hash)),
                224
            ),
            (A.CheckpointFacts)
        );
        if (
            f.networkId != _endowedNetwork || f.configurationHash != _endowedConfiguration
                || f.transactionId != transactionId || f.payloadDigest != e.payloadDigest
                || f.contentHash != e.evidenceHash || f.dataSize != e.byteSize
        ) revert A.InvalidArchivalReceipt();
    }

    function _validateFamily(string calldata name, A.Family calldata f) private view {
        bytes memory n = bytes(name);
        if (
            n.length == 0 || n.length > 64 || keccak256(n) != f.familyId
                || f.networkId == bytes32(0) || f.protocolLineage == bytes32(0)
                || f.addressingLineage == bytes32(0) || f.custodianId == bytes32(0)
                || f.fundingDependency == bytes32(0) || f.retrievalDependency == bytes32(0)
                || f.jurisdiction == bytes32(0) || f.storingAgent == address(0) || f.economics == 0
                || f.economics > 2
        ) revert A.InvalidArchivalFamily();
        for (uint256 i; i < n.length; ++i) {
            if (!((n[i] >= 0x61 && n[i] <= 0x7a) || (n[i] >= 0x30 && n[i] <= 0x39) || n[i] == 0x2d))
            {
                revert A.InvalidArchivalFamily();
            }
        }
        if (f.economics == 1
                ? f.verifierProfileHash != _endowedProfile || f.networkId != _endowedNetwork
                : f.verifierProfileHash != POSSESSION_PROFILE) revert A.InvalidArchivalFamily();
    }

    function _possessionHash(
        bytes32 envelopeHash,
        bytes32 familyHash,
        bytes32 identifierHash,
        address writer,
        uint64 observedAt
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_POSSESSION_V1"),
                block.chainid,
                address(this),
                envelopeHash,
                familyHash,
                identifierHash,
                writer,
                observedAt
            )
        );
    }

    function _typed(bytes32 body) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Archival Coverage"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _consume(bytes32 key) private {
        if (_nonces[key]) revert A.ArchivalReplay(key);
        _nonces[key] = true;
    }

    function _familyScope(bytes32 hash) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_FAMILY_SCOPE_V1"), block.chainid, address(this), hash
            )
        );
    }

    function _familyState(bytes32 hash, uint8 status, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_FAMILY_STATE_V1"),
                block.chainid,
                address(this),
                hash,
                status,
                revision
            )
        );
    }

    function _governed(bytes32 scope, bytes32 oldHash, bytes32 newHash)
        private
        view
        returns (bytes32 action)
    {
        if (msg.sender != governanceAuthority) revert A.ArchivalUnauthorized(msg.sender);
        (
            bool executing,
            bytes32 id,
            uint8 actionClass,
            bytes32 actualScope,
            bytes32 actualOld,
            bytes32 actualNew
        ) = abi.decode(
            _read(
                governanceAuthority,
                abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
                192
            ),
            (bool, bytes32, uint8, bytes32, bytes32, bytes32)
        );
        if (
            !executing || id == bytes32(0) || actionClass != 1 || actualScope != scope
                || actualOld != oldHash || actualNew != newHash
        ) revert A.ArchivalUnauthorized(msg.sender);
        return id;
    }

    function _selected(address host, bytes32 kind) private view returns (address target) {
        bytes memory data =
            _read(host, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320);
        bytes32 hash;
        uint256 word;
        assembly ("memory-safe") {
            word := mload(add(data, 32))
            hash := mload(add(data, 64))
        }
        if (word >> 160 != 0) revert A.ArchivalComponentChanged(host);
        target = address(uint160(word));
        if (target.code.length == 0 || target.codehash != hash) {
            revert A.ArchivalComponentChanged(target);
        }
    }

    function _address(address target, bytes memory data) private view returns (address result) {
        uint256 word = abi.decode(_read(target, data, 32), (uint256));
        if (word >> 160 != 0) revert A.ArchivalComponentChanged(target);
        return address(uint160(word));
    }

    function _read(address target, bytes memory data, uint256 size)
        private
        view
        returns (bytes memory output)
    {
        uint256 cap = _gasParameterValue(_READ_GAS);
        uint256 available = gasleft();
        if (cap > type(uint256).max / 64 || available <= 5000 || (available - 5000) / 64 * 63 < cap)
        {
            revert A.ArchivalParentGas(available, cap);
        }
        output = new bytes(size);
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(output, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) revert A.ArchivalComponentChanged(target);
    }
}
