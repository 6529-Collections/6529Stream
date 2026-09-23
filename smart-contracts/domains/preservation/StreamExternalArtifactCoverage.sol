// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactEnvironment.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCheckpointVerifier.sol";
import "../../interfaces/stream/preservation/IStreamArchivalBindings.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamArchivalSignatures.sol";

/// @notice Original full-object receipt and independent fixity evidence for bulk external archives.
/// @dev Native data-root inclusion and independently attested full-file correspondence are distinct.
///      No descriptor or small byte sample is substituted for the external object's identity.
///      Taxonomy rows belong to this new proof profile; old bounded receipt rows are not reinterpreted.
contract StreamExternalArtifactCoverage is
    StreamGasParameterHost,
    IStreamExternalArtifactCoverage,
    IStreamExternalArtifactCurrentPair,
    IStreamExternalArtifactEnvironment
{
    bytes32 public constant override profileHash =
        keccak256("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1");
    bytes32 public constant FIXITY_PROFILE = keccak256("STREAM_EXTERNAL_OBJECT_FIXITY_V1");
    bytes32 public constant POSSESSION_PROFILE =
        keccak256("STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1");
    bytes32 private constant _CAI = keccak256("CONTENT_ADDRESSED_INCLUSION");
    bytes32 private constant _POSSESSION = keccak256("ATTESTED_POSSESSION");
    bytes32 private constant _READ_GAS = keccak256("6529STREAM_GGP_EXTERNAL_ARCHIVE_READ_GAS");
    bytes32 private constant _SIGNATURE_GAS =
        keccak256("6529STREAM_GGP_EXTERNAL_ARCHIVE_SIGNATURE_GAS");
    bytes32 private constant _RECEIPT_TYPEHASH = keccak256(
        "StreamExternalArtifactReceipt(bytes32 objectHash,bytes32 familyRecordHash,bytes32 storageIdentifierHash,bytes32 evidenceClass,bytes32 proofProfileHash,bytes32 proofRecordHash,address writer,uint64 observedAt,uint256 nonce,uint64 deadline)"
    );
    bytes32 private constant _FIXITY_TYPEHASH = keccak256(
        "StreamExternalArtifactFixity(bytes32 receiptHash,bytes32 objectHash,bytes32 familyRecordHash,bytes32 storageIdentifierHash,bytes32 profileHash,bytes32 expectedSha256,bytes32 observedSha256,bytes32 expectedKeccak256,bytes32 observedKeccak256,bytes32 expectedArweaveRoot,bytes32 observedArweaveRoot,uint64 expectedSize,uint64 observedSize,uint64 checkedAt,uint8 outcome,bytes32 reportHash,bytes32 previousFixityHash,bytes32 repairReportHash,address verifier,uint256 nonce,uint64 deadline)"
    );
    address public immutable override core;
    address public immutable override roleRegistry;
    address public immutable override checkpointVerifier;
    bytes32 private immutable _coreCodeHash;
    bytes32 private immutable _executorCodeHash;
    bytes32 private immutable _roleCodeHash;
    bytes32 private immutable _verifierCodeHash;
    bytes32 private immutable _endowedConfiguration;
    bytes32 private constant _ENDOWED_PROFILE =
        keccak256("6529STREAM_ARWEAVE_EXTERNAL_OBJECT_QUORUM_V1");
    bytes32 private constant _ENDOWED_NETWORK = keccak256("ARWEAVE_MAINNET");
    mapping(bytes32 => E.ObjectIdentity) private _objects;
    mapping(bytes32 => A.Family) private _families;
    mapping(bytes32 => uint8) private _familyStatus;
    mapping(bytes32 => uint64) private _familyRevisions;
    mapping(bytes32 => E.Receipt) private _receipts;
    mapping(bytes32 => bytes) private _identifiers;
    mapping(bytes32 => bytes) private _receiptSignatures;
    mapping(bytes32 => E.Fixity) private _fixities;
    mapping(bytes32 => bytes) private _fixitySignatures;
    mapping(bytes32 => bytes32) private _latestFixities;
    mapping(bytes32 => E.Coverage) private _coverage;
    mapping(bytes32 => bool) private _nonces;
    uint64 private _healthRevision;

    constructor(
        address core_,
        address executor,
        address roles,
        address verifier,
        GasParameterConfig memory readGas,
        GasParameterConfig memory signatureGas
    ) StreamGasParameterHost(executor) {
        if (
            core_.code.length == 0 || executor.code.length == 0 || roles.code.length == 0
                || verifier.code.length == 0
                || keccak256(bytes(readGas.name)) != keccak256("EXTERNAL_ARCHIVE_READ_GAS")
                || readGas.floor < 150000 || readGas.failureClass != 2
                || keccak256(bytes(signatureGas.name))
                    != keccak256("EXTERNAL_ARCHIVE_SIGNATURE_GAS") || signatureGas.floor < 90000
                || signatureGas.failureClass != 2
        ) revert A.InvalidArchivalConfiguration();
        core = core_;
        roleRegistry = roles;
        checkpointVerifier = verifier;
        _coreCodeHash = core_.codehash;
        _executorCodeHash = executor.codehash;
        _roleCodeHash = roles.codehash;
        _verifierCodeHash = verifier.codehash;
        _registerGasParameter(readGas);
        _registerGasParameter(signatureGas);
        if (
            _address(verifier, abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ()))
                    != executor
                || _word(
                        verifier,
                        abi.encodeCall(IStreamExternalArtifactCheckpointVerifier.profileHash, ())
                    ) != _ENDOWED_PROFILE
                || _word(
                        verifier,
                        abi.encodeCall(IStreamExternalArtifactCheckpointVerifier.networkId, ())
                    ) != _ENDOWED_NETWORK
                || uint256(
                        _word(
                            verifier,
                            abi.encodeCall(
                                IStreamExternalArtifactCheckpointVerifier.supportsInterface,
                                (type(IStreamExternalArtifactCheckpointVerifier).interfaceId)
                            )
                        )
                    ) != 1
        ) revert A.InvalidArchivalConfiguration();
        _endowedConfiguration = _word(
            verifier,
            abi.encodeCall(IStreamExternalArtifactCheckpointVerifier.configurationHash, ())
        );
        if (_endowedConfiguration == 0) revert A.InvalidArchivalConfiguration();
        _context();
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamExternalArtifactCoverage).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId
            || id == type(IStreamExternalArtifactCurrentPair).interfaceId
            || id == type(IStreamExternalArtifactEnvironment).interfaceId;
    }

    function currentExternalArtifactEnvironment()
        external
        view
        override
        returns (bytes32 environmentHash, uint64 healthRevision)
    {
        _context();
        bytes memory pointer = _read(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))),
            320
        );
        environmentHash = keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_EXTERNAL_ARTIFACT_ENVIRONMENT_V1"),
                    block.chainid,
                    address(this),
                    profileHash,
                    core,
                    _coreCodeHash,
                    governanceAuthority,
                    _executorCodeHash
                ),
                abi.encode(
                    roleRegistry,
                    _roleCodeHash,
                    checkpointVerifier,
                    _verifierCodeHash,
                    _endowedConfiguration,
                    _ENDOWED_PROFILE,
                    _ENDOWED_NETWORK,
                    keccak256(pointer)
                )
            )
        );
        healthRevision = _healthRevision;
    }

    /// @notice Register an unverified object commitment. This does not create preservation coverage.
    /// @dev Format/catalog/schema values are retained declarations, interpreted by the authoritative
    ///      reference-render consumer against its complete registered format/profile witnesses.
    function recordObject(E.ObjectIdentity calldata o) external override returns (bytes32 hash) {
        if (
            o.artistId == 0 || o.schemaId == 0 || o.canonicalizationId == 0 || o.contentHash == 0
                || o.sha256Digest == 0 || o.arweaveDataRoot == 0 || o.byteSize == 0
                || o.formatId == 0 || o.formatCatalogId == 0 || o.formatCatalogHash == 0
        ) revert A.InvalidArchivalEnvelope();
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_V1"), block.chainid, address(this), core, o
            )
        );
        if (_objects[hash].artistId != 0) revert A.ArchivalRecordExists(hash);
        _objects[hash] = o;
        emit ExternalObjectRecorded(hash, o);
    }

    function objectIdentity(bytes32 hash) external view override returns (E.ObjectIdentity memory) {
        return _objects[hash];
    }

    function familyRegistrationContext(string calldata name, A.Family calldata f)
        public
        view
        override
        returns (bytes32 hash, bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        bytes memory n = bytes(name);
        if (
            n.length == 0 || n.length > 64 || keccak256(n) != f.familyId || f.networkId == 0
                || f.protocolLineage == 0 || f.addressingLineage == 0 || f.custodianId == 0
                || f.fundingDependency == 0 || f.retrievalDependency == 0 || f.jurisdiction == 0
                || f.storingAgent == address(0) || f.economics == 0 || f.economics > 2
        ) revert A.InvalidArchivalFamily();
        for (uint256 i; i < n.length; ++i) {
            if (!((n[i] >= "a" && n[i] <= "z") || (n[i] >= "0" && n[i] <= "9") || n[i] == "-")) {
                revert A.InvalidArchivalFamily();
            }
        }
        if (f.economics == 1
                ? f.networkId != _ENDOWED_NETWORK || f.verifierProfileHash != _ENDOWED_PROFILE
                : f.verifierProfileHash != POSSESSION_PROFILE) revert A.InvalidArchivalFamily();
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_ARCHIVE_FAMILY_V1"), block.chainid, address(this), f
            )
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
        ++_healthRevision;
        _familyRevisions[hash] = 1;
        emit ExternalFamilyRecorded(hash, action, name, f);
    }

    function familyStatusContext(bytes32 hash, uint8 status)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        uint8 prior = _familyStatus[hash];
        uint64 revision = _familyRevisions[hash];
        if (
            prior == 0 || status == 0 || status > 3 || prior == status
                || revision == type(uint64).max
        ) revert A.InvalidArchivalFamily();
        return (
            _familyScope(hash),
            _familyState(hash, prior, revision),
            _familyState(hash, status, revision + 1)
        );
    }

    function setFamilyStatus(bytes32 hash, uint8 status) external override {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = familyStatusContext(hash, status);
        bytes32 action = _governed(scope, oldHash, newHash);
        _familyStatus[hash] = status;
        ++_healthRevision;
        ++_familyRevisions[hash];
        emit ExternalFamilyStatus(hash, action, status, _familyRevisions[hash]);
    }

    function family(bytes32 hash) external view override returns (A.Family memory, uint8, uint64) {
        return (_families[hash], _familyStatus[hash], _familyRevisions[hash]);
    }

    function possessionHash(E.Receipt calldata r) public view override returns (bytes32) {
        // No circular signature/proof-record field enters the possession statement.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_POSSESSION_V1"),
                block.chainid,
                address(this),
                r.objectHash,
                r.familyRecordHash,
                r.storageIdentifierHash,
                r.proofProfileHash,
                r.writer,
                r.observedAt
            )
        );
    }

    function receiptDigest(E.Receipt calldata r) public view override returns (bytes32) {
        return _typed(keccak256(abi.encode(_RECEIPT_TYPEHASH, r)));
    }

    function recordReceipt(
        E.Receipt calldata r,
        bytes calldata identifier,
        bytes calldata signature
    ) external override returns (bytes32 hash) {
        _context();
        E.ObjectIdentity storage o = _objects[r.objectHash];
        A.Family storage f = _families[r.familyRecordHash];
        if (
            o.artistId == 0 || _familyStatus[r.familyRecordHash] != 1 || r.writer != f.storingAgent
                || r.observedAt == 0 || r.observedAt > block.timestamp
                || r.deadline < block.timestamp || r.storageIdentifierHash != keccak256(identifier)
                || r.proofProfileHash != f.verifierProfileHash
        ) revert A.InvalidArchivalReceipt();
        if (f.economics == 1) {
            if (r.evidenceClass != _CAI || identifier.length != 32) {
                revert A.InvalidArchivalReceipt();
            }
            _checkpoint(r.proofRecordHash, o, bytes32(identifier));
        } else {
            if (r.evidenceClass != _POSSESSION || r.proofRecordHash != possessionHash(r)) {
                revert A.InvalidArchivalReceipt();
            }
            _institutionalIdentifier(identifier);
        }
        StreamArchivalSignatures.requireValid(
            r.writer, receiptDigest(r), signature, _gasParameterValue(_SIGNATURE_GAS)
        );
        _consume(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_EXTERNAL_RECEIPT_NONCE_V1"),
                    r.writer,
                    r.familyRecordHash,
                    r.nonce
                )
            )
        );
        hash = keccak256(
            abi.encode(keccak256("6529STREAM_EXTERNAL_RECEIPT_V1"), block.chainid, address(this), r)
        );
        if (_receipts[hash].writer != address(0)) revert A.ArchivalRecordExists(hash);
        _receipts[hash] = r;
        _identifiers[hash] = identifier;
        _receiptSignatures[hash] = signature;
        emit ExternalReceiptRecorded(hash, r.objectHash, r);
    }

    function receipt(bytes32 hash)
        external
        view
        override
        returns (E.Receipt memory, bytes memory, bytes memory)
    {
        return (_receipts[hash], _identifiers[hash], _receiptSignatures[hash]);
    }

    function fixityDigest(E.Fixity calldata f) public view override returns (bytes32) {
        return _typed(keccak256(abi.encode(_FIXITY_TYPEHASH, f)));
    }

    function recordFixity(E.Fixity calldata f, bytes calldata signature)
        external
        override
        returns (bytes32 hash)
    {
        _context();
        E.Receipt storage r = _receipts[f.receiptHash];
        E.ObjectIdentity storage o = _objects[r.objectHash];
        bytes32 prior = _latestFixities[f.receiptHash];
        E.Fixity storage p = _fixities[prior];
        if (
            r.writer == address(0) || f.objectHash != r.objectHash
                || f.familyRecordHash != r.familyRecordHash
                || f.storageIdentifierHash != r.storageIdentifierHash
                || f.profileHash != FIXITY_PROFILE || f.expectedSha256 != o.sha256Digest
                || f.expectedKeccak256 != o.contentHash
                || f.expectedArweaveRoot != o.arweaveDataRoot || f.expectedSize != o.byteSize
                || f.checkedAt < r.observedAt || f.checkedAt == 0 || f.checkedAt > block.timestamp
                || f.checkedAt < p.checkedAt || f.deadline < block.timestamp || f.outcome == 0
                || f.outcome > 2 || f.reportHash == 0 || f.previousFixityHash != prior
                || f.verifier == address(0) || f.verifier == r.writer
                || (f.outcome == 1
                    && (f.observedSha256 != o.sha256Digest
                        || f.observedKeccak256 != o.contentHash
                        || f.observedArweaveRoot != o.arweaveDataRoot
                        || f.observedSize != o.byteSize))
                || (p.outcome == 2 && f.outcome == 1
                        ? f.repairReportHash == 0
                        : f.repairReportHash != 0)
        ) revert A.InvalidArchivalFixity();
        if (
            uint256(
                    _word(
                        roleRegistry,
                        abi.encodeCall(
                            IStreamRoleRegistry.hasRole,
                            (keccak256("ROLE_FIXITY_OPERATOR"), f.verifier)
                        )
                    )
                ) != 1
        ) revert A.ArchivalUnauthorized(f.verifier);
        StreamArchivalSignatures.requireValid(
            f.verifier, fixityDigest(f), signature, _gasParameterValue(_SIGNATURE_GAS)
        );
        _consume(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_EXTERNAL_FIXITY_NONCE_V1"),
                    f.verifier,
                    f.receiptHash,
                    f.nonce
                )
            )
        );
        hash = keccak256(
            abi.encode(keccak256("6529STREAM_EXTERNAL_FIXITY_V1"), block.chainid, address(this), f)
        );
        _fixities[hash] = f;
        _fixitySignatures[hash] = signature;
        _latestFixities[f.receiptHash] = hash;
        ++_healthRevision;
        emit ExternalFixityRecorded(hash, f.receiptHash, f);
    }

    function fixity(bytes32 hash) external view override returns (E.Fixity memory, bytes memory) {
        return (_fixities[hash], _fixitySignatures[hash]);
    }

    function latestFixity(bytes32 hash) external view override returns (bytes32) {
        return _latestFixities[hash];
    }

    function nonceUsed(bytes32 key) external view override returns (bool) {
        return _nonces[key];
    }

    function recordCoverage(bytes32 first, bytes32 second)
        external
        override
        returns (bytes32 hash)
    {
        _context();
        E.Coverage memory e = _coverageFacts(first, second);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_COVERAGE_V1"), block.chainid, address(this), e
            )
        );
        if (_coverage[hash].coverageHash != 0) revert A.ArchivalRecordExists(hash);
        e.coverageHash = hash;
        _coverage[hash] = e;
        emit ExternalCoverageRecorded(hash, e.objectHash, e);
    }

    function coverage(bytes32 hash) external view override returns (E.Coverage memory) {
        return _coverage[hash];
    }

    function requireCoverage(bytes32 hash, bytes32 artistId, bytes32 objectHash)
        external
        view
        override
        returns (E.Coverage memory saved)
    {
        _context();
        saved = _coverage[hash];
        if (
            hash == 0 || saved.coverageHash != hash || saved.artistId != artistId
                || saved.objectHash != objectHash
        ) revert A.InvalidArchivalCoverage();
        E.Coverage memory actual = _coverageFacts(saved.firstReceiptHash, saved.secondReceiptHash);
        actual.coverageHash = hash;
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(saved))) {
            revert A.InvalidArchivalCoverage();
        }
    }

    /// @notice Current passing observations for the same two retained original receipt identities.
    /// @dev Reuses every original context/independence/checkpoint predicate. It neither records
    ///      coverage nor changes original fixity commitments or their historical meaning.
    function currentReceiptPair(bytes32 first, bytes32 second, bytes32 artistId, bytes32 objectHash)
        external
        view
        override
        returns (E.CurrentPair memory current)
    {
        _context();
        E.Coverage memory e = _coverageFacts(first, second);
        if (e.artistId != artistId || e.objectHash != objectHash) {
            revert A.InvalidArchivalCoverage();
        }
        current.objectHash = e.objectHash;
        current.artistId = e.artistId;
        current.contentHash = e.contentHash;
        current.sha256Digest = e.sha256Digest;
        current.arweaveDataRoot = e.arweaveDataRoot;
        current.byteSize = e.byteSize;
        current.firstFamilyRecordHash = e.firstFamilyRecordHash;
        current.secondFamilyRecordHash = e.secondFamilyRecordHash;
        current.firstReceiptHash = e.firstReceiptHash;
        current.secondReceiptHash = e.secondReceiptHash;
        current.firstFixityHash = e.firstFixityHash;
        current.secondFixityHash = e.secondFixityHash;
        current.checkpointHash = e.checkpointHash;
        current.profileHash = e.profileHash;
    }

    function _coverageFacts(bytes32 first, bytes32 second)
        private
        view
        returns (E.Coverage memory)
    {
        E.Receipt storage a = _receipts[first];
        E.Receipt storage b = _receipts[second];
        A.Family storage x = _families[a.familyRecordHash];
        A.Family storage y = _families[b.familyRecordHash];
        bytes32 fixA = _latestFixities[first];
        bytes32 fixB = _latestFixities[second];
        if (
            first == second || a.writer == address(0) || b.writer == address(0)
                || a.objectHash != b.objectHash || _familyStatus[a.familyRecordHash] != 1
                || _familyStatus[b.familyRecordHash] != 1 || x.economics != 1 || y.economics != 2
                || a.evidenceClass != _CAI || b.evidenceClass != _POSSESSION
                || x.familyId == y.familyId || x.networkId == y.networkId
                || x.protocolLineage == y.protocolLineage
                || x.addressingLineage == y.addressingLineage || x.custodianId == y.custodianId
                || x.fundingDependency == y.fundingDependency
                || x.retrievalDependency == y.retrievalDependency
                || x.storingAgent == y.storingAgent || _fixities[fixA].outcome != 1
                || _fixities[fixB].outcome != 1
        ) revert A.InvalidArchivalCoverage();
        E.ObjectIdentity storage o = _objects[a.objectHash];
        _checkpoint(a.proofRecordHash, o, bytes32(_identifiers[first]));
        return E.Coverage(
            0,
            a.objectHash,
            o.artistId,
            o.contentHash,
            o.sha256Digest,
            o.arweaveDataRoot,
            o.byteSize,
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

    function _checkpoint(bytes32 hash, E.ObjectIdentity storage o, bytes32 transactionId)
        private
        view
    {
        bytes memory raw = _read(
            checkpointVerifier,
            abi.encodeCall(IStreamExternalArtifactCheckpointVerifier.checkpointFacts, (hash)),
            256
        );
        E.NativeFacts memory f = abi.decode(raw, (E.NativeFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || f.recordHash != hash || hash == 0
                || f.networkId != _ENDOWED_NETWORK || f.configurationHash != _endowedConfiguration
                || f.transactionId != transactionId || f.dataRoot != o.arweaveDataRoot
                || f.dataSize != o.byteSize || f.firstChunkDigest == 0 || f.lastChunkDigest == 0
        ) revert A.InvalidArchivalReceipt();
    }

    function _institutionalIdentifier(bytes calldata raw) private pure {
        if (raw.length < 10 || raw.length > 2048 || bytes8(raw) != bytes8("https://")) {
            revert A.InvalidArchivalReceipt();
        }
        // Closed ASCII HTTPS locator; no credentials, fragments, whitespace, escaping or backslash.
        // The preserving institution's exact signed locator is retained, not treated as a CID.
        uint256 hostEnd = raw.length;
        for (uint256 i = 8; i < raw.length; ++i) {
            bytes1 c = raw[i];
            if (c <= 0x20 || c >= 0x7f || c == "@" || c == "#" || c == "\\" || c == "%") {
                revert A.InvalidArchivalReceipt();
            }
            if (hostEnd == raw.length && c == "/") hostEnd = i;
        }
        if (hostEnd == 8 || hostEnd == raw.length || hostEnd + 1 == raw.length) {
            revert A.InvalidArchivalReceipt();
        }
        // ASCII DNS labels, retained exactly. This is a locator grammar, not DNS resolution.
        if (hostEnd - 8 > 253) revert A.InvalidArchivalReceipt();
        uint256 labelStart = 8;
        for (uint256 i = 8; i <= hostEnd; ++i) {
            if (i == hostEnd || raw[i] == ".") {
                if (
                    i == labelStart || i - labelStart > 63 || raw[labelStart] == "-"
                        || raw[i - 1] == "-"
                ) revert A.InvalidArchivalReceipt();
                labelStart = i + 1;
                continue;
            }
            bytes1 c = raw[i];
            if (!((c >= "a" && c <= "z") || (c >= "0" && c <= "9") || c == "-")) {
                revert A.InvalidArchivalReceipt();
            }
        }
    }

    function _context() private view {
        if (
            core.codehash != _coreCodeHash || governanceAuthority.codehash != _executorCodeHash
                || roleRegistry.codehash != _roleCodeHash
                || checkpointVerifier.codehash != _verifierCodeHash
        ) revert A.InvalidArchivalConfiguration();
        bytes memory pointer = _read(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))),
            320
        );
        uint256 word;
        bytes32 codeHash;
        assembly ("memory-safe") {
            word := mload(add(pointer, 32))
            codeHash := mload(add(pointer, 64))
        }
        if (word == 0 || word >> 160 != 0) revert A.InvalidArchivalConfiguration();
        address modules = address(uint160(word));
        if (
            modules.code.length == 0 || modules.codehash != codeHash
                || _address(
                        modules,
                        abi.encodeCall(IStreamArchivalGovernanceBinding.governanceExecutor, ())
                    ) != governanceAuthority
                || _address(
                        governanceAuthority,
                        abi.encodeCall(IStreamArchivalGovernanceBinding.roleRegistry, ())
                    ) != roleRegistry
                || _address(
                        roleRegistry, abi.encodeCall(IStreamArchivalGovernanceBinding.owner, ())
                    ) != governanceAuthority
                || _word(
                        checkpointVerifier,
                        abi.encodeCall(IStreamExternalArtifactCheckpointVerifier.profileHash, ())
                    ) != _ENDOWED_PROFILE
                || _word(
                        checkpointVerifier,
                        abi.encodeCall(
                            IStreamExternalArtifactCheckpointVerifier.configurationHash, ()
                        )
                    ) != _endowedConfiguration
                || _word(
                        checkpointVerifier,
                        abi.encodeCall(IStreamExternalArtifactCheckpointVerifier.networkId, ())
                    ) != _ENDOWED_NETWORK
        ) revert A.InvalidArchivalConfiguration();
    }

    function _typed(bytes32 body) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream External Artifact Coverage"),
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
                keccak256("6529STREAM_EXTERNAL_FAMILY_SCOPE_V1"), block.chainid, address(this), hash
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
                keccak256("6529STREAM_EXTERNAL_FAMILY_STATE_V1"),
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
        returns (bytes32 id)
    {
        _context();
        if (msg.sender != governanceAuthority) revert A.ArchivalUnauthorized(msg.sender);
        bytes memory raw = _read(
            governanceAuthority,
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            192
        );
        bool executing;
        uint8 classId;
        bytes32 actualScope;
        bytes32 actualOld;
        bytes32 actualNew;
        (executing, id, classId, actualScope, actualOld, actualNew) =
            abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            keccak256(raw)
                    != keccak256(
                        abi.encode(executing, id, classId, actualScope, actualOld, actualNew)
                    ) || !executing || id == 0 || classId != 1 || actualScope != scope
                || actualOld != oldHash || actualNew != newHash
        ) revert A.ArchivalUnauthorized(msg.sender);
    }

    function _address(address target, bytes memory data) private view returns (address) {
        uint256 word = uint256(_word(target, data));
        if (word == 0 || word >> 160 != 0) revert A.ArchivalComponentChanged(target);
        return address(uint160(word));
    }

    function _word(address target, bytes memory data) private view returns (bytes32) {
        return abi.decode(_read(target, data, 32), (bytes32));
    }

    function _read(address target, bytes memory data, uint256 size)
        private
        view
        returns (bytes memory raw)
    {
        uint256 cap = _gasParameterValue(_READ_GAS);
        if (cap > type(uint256).max / 2 || gasleft() <= cap + cap / 63 + 100000) {
            revert A.ArchivalParentGas(gasleft(), cap);
        }
        raw = new bytes(size);
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) revert A.ArchivalComponentChanged(target);
    }
}
