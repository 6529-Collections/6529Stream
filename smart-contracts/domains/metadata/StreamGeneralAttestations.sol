// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import "../../interfaces/standards/IERC5267.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../records/StreamRecordFamilies.sol";
import "../records/StreamWorkRecordDefinitions.sol";
import "./StreamGeneralAttestationHash.sol";
import "./StreamGeneralAttestationSignatures.sol";
import "./StreamGeneralAttestationJSON.sol";
import "./StreamGeneralAttestationReads.sol";
import "./StreamGeneralArtistEvidence.sol";
import { StreamIndependentReads } from "./StreamIndependentReads.sol";

/// @notice Signed general claims and separately attributed configured-operator assertions.
/// @dev Neither class grants protocol authority. Native Artist proof is retained historical
///      evidence; institution/estate signatures do not establish factual legal identity.
contract StreamGeneralAttestations is
    StreamModuleBase,
    StreamGasParameterHost,
    ReentrancyGuard,
    IStreamGeneralAttestations,
    IERC5267
{
    struct Configuration {
        address core;
        address schemas;
        address metadata;
        address artistRegistry;
        address artistAttribution;
        address executor;
        bytes32 deploymentManifestHash;
        string manifestURI;
        bytes32 manifestHash;
        GasParameterConfig signatureGas;
        GasParameterConfig dependencyReadGas;
    }

    struct Stored {
        Attestation value;
        Receipt receipt;
        IStreamCollectionAttestations.Subject subject;
        address payloadPointer;
        address signaturePointer;
        bytes nativeArtistEvidence;
    }

    struct Pointer {
        address pointer;
        bytes32 family;
        bytes32 hash;
    }
    address public immutable override core;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    address public immutable override metadataAuthority;
    address public immutable override artistRegistry;
    address public immutable artistAttribution;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable schemaRegistryCodeHash;
    bytes32 public immutable chunkStoreCodeHash;
    bytes32 public immutable metadataAuthorityCodeHash;
    bytes32 public immutable artistRegistryCodeHash;
    bytes32 public immutable artistAttributionCodeHash;
    uint256 public constant MAX_RECORD_PAYLOAD_BYTES = 8192;
    uint256 public constant MAX_SIGNATURE_BYTES = 4096;
    uint256 public constant MAX_SIGNATURE_BUNDLE_BYTES = 8192;
    uint256 public constant METADATA_ERC1271_VERIFY_GAS_FLOOR = 90000;
    bytes32 public constant GGP_METADATA_ERC1271_VERIFY_GAS =
        keccak256("6529STREAM_GGP_METADATA_ERC1271_VERIFY_GAS");
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant STREAM_GENERAL_ATTESTATION_TYPEHASH =
        StreamGeneralAttestationHash.TYPEHASH;
    bytes32 private constant FAMILY = keccak256("6529STREAM_RECORD_FAMILY_GENERAL_ATTESTATION_V1");
    bytes32 private constant BUNDLE_FAMILY =
        keccak256("STREAM_GENERAL_ATTESTATION_SIGNATURE_BUNDLE_V1");
    mapping(address => mapping(uint256 => bool)) private _used;
    mapping(bytes32 => Stored) private _records;
    mapping(bytes32 => bytes32) private _latest;
    mapping(uint256 => mapping(bytes32 => bytes32[])) private _history;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _chains;
    mapping(uint256 => Pointer[]) private _pointers;
    mapping(uint256 => mapping(bytes32 => bool)) private _pointerSeen;

    constructor(Configuration memory c)
        StreamModuleBase(
            keccak256("6529stream.general-attestations.v1"),
            address(0),
            c.deploymentManifestHash,
            c.manifestURI,
            c.manifestHash
        )
        StreamGasParameterHost(c.executor)
    {
        if (
            c.core.code.length == 0 || c.schemas.code.length == 0 || c.metadata.code.length == 0
                || c.artistRegistry.code.length == 0 || c.artistAttribution.code.length == 0
                || c.deploymentManifestHash == 0 || c.manifestHash == 0
                || c.signatureGas.floor != METADATA_ERC1271_VERIFY_GAS_FLOOR
                || c.signatureGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || c.dependencyReadGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || _registerGasParameter(c.signatureGas) != GGP_METADATA_ERC1271_VERIFY_GAS
                || _registerGasParameter(c.dependencyReadGas) != DEPENDENCY_READ_GAS
        ) revert InvalidGeneralConfiguration();
        core = c.core;
        schemaRegistry = c.schemas;
        metadataAuthority = c.metadata;
        artistRegistry = c.artistRegistry;
        artistAttribution = c.artistAttribution;
        coreCodeHash = c.core.codehash;
        schemaRegistryCodeHash = c.schemas.codehash;
        metadataAuthorityCodeHash = c.metadata.codehash;
        artistRegistryCodeHash = c.artistRegistry.codehash;
        artistAttributionCodeHash = c.artistAttribution.codehash;
        uint256 cap = c.dependencyReadGas.genesisValue;
        chunkStore = abi.decode(
            StreamGeneralAttestationReads.fixedRead(
                c.schemas, abi.encodeCall(IStreamSchemaRegistry.chunkStore, ()), 32, cap
            ),
            (address)
        );
        if (chunkStore.code.length == 0) revert InvalidGeneralConfiguration();
        chunkStoreCodeHash = chunkStore.codehash;
        if (
            !abi.decode(
                    StreamGeneralAttestationReads.fixedRead(
                        c.core,
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0x80ac58cd))),
                        32,
                        cap
                    ),
                    (bool)
                )
                || !abi.decode(
                    StreamGeneralAttestationReads.fixedRead(
                        c.schemas,
                        abi.encodeCall(
                            IERC165.supportsInterface, (type(IStreamSchemaRegistry).interfaceId)
                        ),
                        32,
                        cap
                    ),
                    (bool)
                )
                || abi.decode(
                        StreamGeneralAttestationReads.fixedRead(
                            c.schemas,
                            abi.encodeCall(IStreamSchemaRegistry.governanceAuthority, ()),
                            32,
                            cap
                        ),
                        (address)
                    ) != c.executor
                || abi.decode(
                        StreamGeneralAttestationReads.fixedRead(
                            c.metadata, abi.encodeWithSignature("core()"), 32, cap
                        ),
                        (address)
                    ) != c.core
        ) revert InvalidGeneralConfiguration();
        StreamGeneralArtistEvidence.requireBinding(
            StreamGeneralArtistEvidence.Configuration(
                c.core,
                c.artistRegistry,
                c.artistAttribution,
                c.artistRegistry.codehash,
                c.artistAttribution.codehash,
                cap
            )
        );
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "moduleManifestURI", c.manifestURI, 2048, false
        );
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("GENERAL_ATTESTATIONS");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.general-attestations.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamGeneralAttestations).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamGeneralAttestations).interfaceId
            || id == type(IERC5267).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || super.supportsInterface(id);
    }

    function eip712Domain()
        external
        view
        override
        returns (bytes1, string memory, string memory, uint256, address, bytes32, uint256[] memory)
    {
        return (
            0x0f,
            "6529StreamGeneralAttestations",
            "1",
            block.chainid,
            address(this),
            0,
            new uint256[](0)
        );
    }

    function verificationClass(bytes32 t) public pure override returns (VerificationClass) {
        if (
            t == keccak256("ARTIST_STATEMENT") || t == keccak256("INSTITUTIONAL_VERIFICATION")
                || t == keccak256("ESTATE_VERIFICATION")
        ) return VerificationClass.SIGNER_VERIFIED;
        if (t == keccak256("CURATORIAL_STATEMENT")) return VerificationClass.OPERATOR_ASSERTED;
        return VerificationClass.NONE;
    }

    function operatorPolicy(bytes32 t) public pure override returns (bytes32, uint16) {
        return t == keccak256("CURATORIAL_STATEMENT")
            ? (StreamRecordFamilies.CURATOR, uint16(1 << 3))
            : (bytes32(0), uint16(0));
    }

    function deriveSubject(IStreamCollectionAttestations.Subject calldata s)
        external
        view
        override
        returns (bytes32)
    {
        return StreamIndependentReads.subject(core, s);
    }

    function attestationDigest(Request calldata r) public view override returns (bytes32) {
        return StreamGeneralAttestationHash.digest(r);
    }

    function notarizationPayload(Notarization calldata n)
        external
        pure
        override
        returns (bytes memory)
    {
        return StreamGeneralAttestationJSON.notarization(n);
    }

    function recordSignedAttestation(
        IStreamCollectionAttestations.Subject calldata s,
        Request calldata r,
        bytes calldata signature
    ) external override nonReentrant returns (bytes32) {
        if (
            r.attestationType == keccak256("ARTIST_STATEMENT")
                || r.schemaId == StreamGeneralAttestationDefinitions.SCHEMA_ID
                || r.artistAuthorizationRecordHash != 0
        ) revert InvalidGeneralAttestation();
        _subject(s, r);
        Receipt memory receipt = _signed(r, signature);
        return _commit(s, r, receipt, _bundle(r, signature), "");
    }

    function recordIdentityNotarization(
        IStreamCollectionAttestations.Subject calldata s,
        Request calldata r,
        Notarization calldata n,
        bytes calldata signature
    ) external override nonReentrant returns (bytes32) {
        if (
            (r.attestationType != keccak256("INSTITUTIONAL_VERIFICATION")
                    && r.attestationType != keccak256("ESTATE_VERIFICATION"))
                || r.schemaId != StreamGeneralAttestationDefinitions.SCHEMA_ID
                || r.canonicalizationId != StreamWorkRecordDefinitions.CANON_ID
                || r.artistAuthorizationRecordHash != 0
                || keccak256(r.payload) != keccak256(StreamGeneralAttestationJSON.notarization(n))
        ) revert InvalidGeneralAttestation();
        _subject(s, r);
        Receipt memory receipt = _signed(r, signature);
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        StreamGeneralAttestationReads.selected(
            core,
            coreCodeHash,
            keccak256("ARTIST_REGISTRY"),
            artistRegistry,
            artistRegistryCodeHash,
            cap
        );
        StreamGeneralAttestationReads.operativeIdentity(
            artistRegistry, n.artistId, n.operativeIdentityRecordHash, cap
        );
        _notarizationDefinitions(cap);
        receipt.profileDefinitionHash = StreamGeneralAttestationDefinitions.PROFILE_HASH;
        receipt.identityRegistry = artistRegistry;
        receipt.identityRegistryCodeHash = artistRegistryCodeHash;
        receipt.artistId = n.artistId;
        receipt.operativeIdentityRecordHash = n.operativeIdentityRecordHash;
        return _commit(s, r, receipt, _bundle(r, signature), "");
    }

    function recordArtistStatement(
        Request calldata r,
        ArtistWitness calldata witness,
        bytes calldata signature
    ) external override nonReentrant returns (bytes32) {
        if (
            r.attestationType != keccak256("ARTIST_STATEMENT")
                || r.artistAuthorizationRecordHash == 0
                || r.schemaId == StreamGeneralAttestationDefinitions.SCHEMA_ID
        ) revert InvalidGeneralAttestation();
        Receipt memory receipt = _signed(r, signature);
        (bytes memory evidence, bytes32 artistId, uint8 authorityClass_) =
            StreamGeneralArtistEvidence.evidence(_artistConfiguration(), r, witness);
        receipt.authorityQualification = AuthorityQualification.NATIVE_ARTIST_HISTORY;
        receipt.identityRegistry = artistRegistry;
        receipt.identityRegistryCodeHash = artistRegistryCodeHash;
        receipt.artistId = artistId;
        receipt.nativeArtistEvidenceHash = keccak256(evidence);
        receipt.nativeArtistAuthorityClass = authorityClass_;
        IStreamCollectionAttestations.Subject memory unused;
        return _commit(unused, r, receipt, _bundle(r, signature), evidence);
    }

    function recordOperatorAttestation(
        IStreamCollectionAttestations.Subject calldata s,
        Request calldata r
    ) external override nonReentrant returns (bytes32) {
        if (
            verificationClass(r.attestationType) != VerificationClass.OPERATOR_ASSERTED
                || r.artistAuthorizationRecordHash != 0
                || r.schemaId == StreamGeneralAttestationDefinitions.SCHEMA_ID
        ) revert InvalidGeneralAttestation();
        _subject(s, r);
        Receipt memory receipt = _base(r, msg.sender);
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        StreamGeneralAttestationReads.selected(
            core,
            coreCodeHash,
            keccak256("COLLECTION_METADATA"),
            metadataAuthority,
            metadataAuthorityCodeHash,
            cap
        );
        (receipt.authorityFamily,) = operatorPolicy(r.attestationType);
        receipt.grantRevision = StreamGeneralAttestationReads.operatorGrant(
            metadataAuthority, r.collectionId, receipt.authorityFamily, msg.sender, cap
        );
        receipt.verificationClass = VerificationClass.OPERATOR_ASSERTED;
        receipt.authorityQualification = AuthorityQualification.CONFIGURED_OPERATOR_CLAIM;
        receipt.authorizationClass = 3;
        receipt.grantCollectionId = r.collectionId;
        return _commit(s, r, receipt, "", "");
    }

    function _signed(Request calldata r, bytes calldata signature)
        private
        view
        returns (Receipt memory receipt)
    {
        if (verificationClass(r.attestationType) != VerificationClass.SIGNER_VERIFIED) {
            revert InvalidGeneralAttestation();
        }
        receipt = _base(r, r.attester);
        receipt.verificationClass = VerificationClass.SIGNER_VERIFIED;
        receipt.authorityQualification = AuthorityQualification.GENERAL_SIGNER_CLAIM;
        receipt.authorizationDigest = attestationDigest(r);
        receipt.signatureScheme = StreamGeneralAttestationSignatures.verify(
            r.attester,
            receipt.authorizationDigest,
            signature,
            _gasParameterValue(GGP_METADATA_ERC1271_VERIFY_GAS)
        );
    }

    function _base(Request calldata r, address recorder)
        private
        view
        returns (Receipt memory receipt)
    {
        if (
            r.attester == address(0) || recorder == address(0) || r.collectionId == 0
                || r.subjectId == 0 || r.schemaId == 0 || r.canonicalizationId == 0
                || r.payload.length == 0 || r.payload.length > MAX_RECORD_PAYLOAD_BYTES
                || r.effectiveAt == 0 || block.timestamp > type(uint64).max
        ) revert InvalidGeneralAttestation();
        if (_used[recorder][r.nonce]) revert GeneralNonceUsed(recorder, r.nonce);
        if (r.deadline < block.timestamp) revert GeneralDeadlineExpired(r.deadline);
        bytes32 latest =
            latestAttestationHashFor(r.collectionId, r.attestationType, r.subjectId, recorder);
        if (r.supersedes != latest) revert GeneralSupersessionMismatch(latest, r.supersedes);
        StreamMetadataRenderer.requireValidUtf8Bytes("attesterDID", r.attesterDID, 2048);
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "statementURI", r.statementURI, 2048, true
        );
        StreamGeneralAttestationReads.code(core, coreCodeHash);
        StreamGeneralAttestationReads.code(schemaRegistry, schemaRegistryCodeHash);
        StreamGeneralAttestationReads.code(chunkStore, chunkStoreCodeHash);
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        receipt.schemaDefinitionHash =
        StreamGeneralAttestationReads.definition(
            schemaRegistry, r.schemaId, IStreamSchemaRegistry.DocumentKind.SCHEMA, cap
        )
        .contentHash;
        receipt.canonicalizationDefinitionHash =
        StreamGeneralAttestationReads.definition(
            schemaRegistry,
            r.canonicalizationId,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            cap
        )
        .contentHash;
        receipt.recorder = recorder;
        receipt.recordedAt = uint64(block.timestamp);
        receipt.nonce = r.nonce;
        receipt.deadline = r.deadline;
    }

    function _subject(IStreamCollectionAttestations.Subject calldata s, Request calldata r)
        private
        view
    {
        if (
            s.collectionId != r.collectionId
                || StreamIndependentReads.subject(core, s) != r.subjectId
        ) revert InvalidGeneralAttestation();
        StreamIndependentReads.requireSubject(
            core, coreCodeHash, s, _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function _bundle(Request calldata r, bytes calldata signature)
        private
        view
        returns (bytes memory value)
    {
        value = abi.encode(
            StreamGeneralAttestationHash.domain(), StreamGeneralAttestationHash.words(r), signature
        );
        if (value.length > MAX_SIGNATURE_BUNDLE_BYTES) revert InvalidGeneralAttestation();
    }

    function _notarizationDefinitions(uint256 cap) private view {
        StreamGeneralAttestationReads.exactDefinition(
            schemaRegistry,
            chunkStore,
            StreamGeneralAttestationDefinitions.SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamGeneralAttestationDefinitions.SCHEMA_HASH,
            StreamGeneralAttestationDefinitions.SCHEMA_BYTES,
            cap
        );
        StreamGeneralAttestationReads.exactDefinition(
            schemaRegistry,
            chunkStore,
            StreamGeneralAttestationDefinitions.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamGeneralAttestationDefinitions.PROFILE_HASH,
            StreamGeneralAttestationDefinitions.PROFILE_BYTES,
            cap
        );
        StreamGeneralAttestationReads.exactDefinition(
            schemaRegistry,
            chunkStore,
            StreamWorkRecordDefinitions.CANON_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamWorkRecordDefinitions.CANON_HASH,
            StreamWorkRecordDefinitions.CANON_BYTES,
            cap
        );
    }

    function _artistConfiguration()
        private
        view
        returns (StreamGeneralArtistEvidence.Configuration memory)
    {
        return StreamGeneralArtistEvidence.Configuration(
            core,
            artistRegistry,
            artistAttribution,
            artistRegistryCodeHash,
            artistAttributionCodeHash,
            _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function _commit(
        IStreamCollectionAttestations.Subject memory subject,
        Request calldata r,
        Receipt memory receipt,
        bytes memory bundle,
        bytes memory evidence
    ) private returns (bytes32 hash) {
        if (bundle.length != 0) {
            receipt.signatureBundleHash = keccak256(bundle);
        }
        Attestation memory value = Attestation(
            r.attester,
            r.collectionId,
            r.subjectId,
            r.attestationType,
            r.attesterDID,
            r.schemaId,
            r.canonicalizationId,
            r.statementURI,
            keccak256(r.payload),
            r.supersedes,
            r.artistAuthorizationRecordHash,
            r.effectiveAt
        );
        hash = StreamGeneralAttestationHash.recordHash(value, receipt);
        if (_records[hash].receipt.recorder != address(0)) revert GeneralRecordExists(hash);
        uint256 index = _history[r.collectionId][r.attestationType].length;
        if (index == type(uint64).max) revert InvalidGeneralAttestation();
        _used[receipt.recorder][r.nonce] = true;
        receipt.recordIndex = uint64(index);
        receipt.recordChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GENERAL_ATTESTATION_CHAIN_V1"),
                r.collectionId,
                r.attestationType,
                _chains[r.collectionId][r.attestationType],
                hash,
                uint64(index)
            )
        );
        Stored storage stored = _records[hash];
        stored.value = value;
        stored.receipt = receipt;
        stored.subject = subject;
        stored.nativeArtistEvidence = evidence;
        stored.payloadPointer = _publish(r.collectionId, FAMILY, r.payload);
        if (bundle.length != 0) {
            stored.signaturePointer = _publish(r.collectionId, BUNDLE_FAMILY, bundle);
        }
        _history[r.collectionId][r.attestationType].push(hash);
        _chains[r.collectionId][r.attestationType] = receipt.recordChainHash;
        _latest[
            keccak256(abi.encode(r.collectionId, r.attestationType, r.subjectId, receipt.recorder))
        ] = hash;
        emit GeneralAttestationRecorded(
            r.collectionId,
            r.attestationType,
            r.subjectId,
            hash,
            r.attester,
            receipt.verificationClass,
            receipt.authorityQualification,
            r.supersedes,
            receipt.recordChainHash,
            1
        );
    }

    function _publish(uint256 collectionId, bytes32 family, bytes memory payload)
        private
        returns (address pointer)
    {
        StreamGeneralAttestationReads.code(chunkStore, chunkStoreCodeHash);
        bytes32 hash;
        (hash, pointer) = StreamSchemaDocumentStore(chunkStore).publishChunk(payload);
        if (
            hash != keccak256(payload)
                || pointer.codehash != keccak256(bytes.concat(hex"00", payload))
        ) revert InvalidGeneralAttestation();
        bytes32 key = keccak256(abi.encode(family, hash));
        if (!_pointerSeen[collectionId][key]) {
            _pointerSeen[collectionId][key] = true;
            _pointers[collectionId].push(Pointer(pointer, family, hash));
        }
    }

    function revokeAttesterNonce(uint256 nonce) external override nonReentrant {
        if (_used[msg.sender][nonce]) revert GeneralNonceUsed(msg.sender, nonce);
        _used[msg.sender][nonce] = true;
        emit GeneralAttesterNonceRevoked(msg.sender, nonce, 1);
    }

    function isAttesterNonceUsed(address attester_, uint256 nonce)
        external
        view
        override
        returns (bool)
    {
        return _used[attester_][nonce];
    }

    function attestation(bytes32 hash)
        external
        view
        override
        returns (Attestation memory, Receipt memory)
    {
        Stored storage s = _known(hash);
        return (s.value, s.receipt);
    }

    function recordSubject(bytes32 hash)
        external
        view
        override
        returns (IStreamCollectionAttestations.Subject memory)
    {
        Stored storage s = _known(hash);
        if (s.receipt.nativeArtistEvidenceHash != 0) revert InvalidGeneralAttestation();
        return s.subject;
    }

    function recordArtistEvidence(bytes32 hash) external view override returns (bytes memory) {
        return _known(hash).nativeArtistEvidence;
    }

    function recordPayload(bytes32 hash)
        external
        view
        override
        returns (address pointer, bytes memory payload)
    {
        Stored storage s = _known(hash);
        return (s.payloadPointer, _payload(s.payloadPointer, s.value.statementHash));
    }

    function recordSignatureBundle(bytes32 hash)
        external
        view
        override
        returns (address pointer, bytes memory bundle)
    {
        Stored storage s = _known(hash);
        if (s.signaturePointer == address(0)) return (address(0), new bytes(0));
        return (s.signaturePointer, _payload(s.signaturePointer, s.receipt.signatureBundleHash));
    }

    function _payload(address pointer, bytes32 hash) private view returns (bytes memory payload) {
        if (pointer.code.length == 0 || pointer.code.length > 8193) {
            revert GeneralDependencyChanged(pointer);
        }
        payload = SSTORE2.read(pointer);
        if (
            keccak256(payload) != hash
                || pointer.codehash != keccak256(bytes.concat(hex"00", payload))
        ) revert GeneralDependencyChanged(pointer);
    }

    function latestAttestationHashFor(
        uint256 collectionId,
        bytes32 t,
        bytes32 subjectId,
        address recorder
    ) public view override returns (bytes32) {
        return _latest[keccak256(abi.encode(collectionId, t, subjectId, recorder))];
    }

    function recordChainHash(uint256 collectionId, bytes32 t)
        external
        view
        override
        returns (bytes32, uint64)
    {
        return (_chains[collectionId][t], uint64(_history[collectionId][t].length));
    }

    function recordHashAt(uint256 collectionId, bytes32 t, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _history[collectionId][t][index];
    }

    function payloadPointerCount(uint256 collectionId) external view override returns (uint256) {
        return _pointers[collectionId].length;
    }

    function payloadPointerAt(uint256 collectionId, uint256 index)
        external
        view
        override
        returns (address, bytes32, bytes32)
    {
        Pointer memory p = _pointers[collectionId][index];
        return (p.pointer, p.family, p.hash);
    }

    function _known(bytes32 hash) private view returns (Stored storage s) {
        s = _records[hash];
        if (s.receipt.recorder == address(0)) revert GeneralRecordUnknown(hash);
    }
}
