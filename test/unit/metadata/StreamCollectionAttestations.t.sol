// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/metadata/StreamCollectionAttestations.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Explicit Core identity boundary. There is no operator, renderer, artist or module admission.
contract IndependentCoreBoundary {
    uint8 public lifecycle = 2;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }

    function tokenCollectionIdentity(uint256 token)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (token == 71, 1, 1, lifecycle == 3);
    }

    function tokenLifecycle(uint256) external view returns (uint8) {
        return lifecycle;
    }

    function setLifecycle(uint8 value) external {
        lifecycle = value;
    }
}

/// @dev Target-side Governance V2 context; actual Executor scheduling is a separate integration.
contract IndependentExecutorBoundary {
    bool private active;
    bytes32 private scope;
    bytes32 private oldHash;
    bytes32 private newHash;
    uint8 private actionClass;
    uint256 private nonce;

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return active
            ? (true, bytes32(nonce), actionClass, scope, oldHash, newHash)
            : (false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0));
    }

    function execute(address target, bytes memory data, bytes32 s, bytes32 o, bytes32 n, uint8 c)
        external
        returns (bytes memory)
    {
        active = true;
        ++nonce;
        scope = s;
        oldHash = o;
        newHash = n;
        actionClass = c;
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        active = false;
        return result;
    }
}

contract IndependentSignatureBoundary {
    bytes32 public approved;
    uint256 public mode;

    function set(bytes32 digest, uint256 nextMode) external {
        approved = digest;
        mode = nextMode;
    }

    function isValidSignature(bytes32 digest, bytes memory) external view returns (bytes4) {
        if (mode == 1) revert("unavailable");
        if (mode == 2) assembly ("memory-safe") { return(0, 0) }
        if (mode == 3) assembly ("memory-safe") {
            mstore(0, shl(224, 0x1626ba7e))
            return(0, 64)
        }
        if (mode == 4) {
            assembly ("memory-safe") {
                mstore(0, or(shl(224, 0x1626ba7e), 1))
                return(0, 32)
            }
        }
        if (mode == 5) assembly ("memory-safe") { for { } 1 { } { } }
        return digest == approved ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

abstract contract IndependentAttestationTestBase is CharacterizationTestBase {
    StreamCollectionAttestations internal host;
    IndependentCoreBoundary internal core;
    IndependentExecutorBoundary internal executor;
    StreamSchemaRegistry internal schemas;
    StreamSchemaDocumentStore internal store;
    bytes32 internal schemaId;
    uint256 internal constant KEY = 0xA771;
    address internal signer;

    function setUp() public virtual {
        vm.warp(1000);
        signer = vm.addr(KEY);
        core = new IndependentCoreBoundary();
        executor = new IndependentExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        schemaId = _register(
            "STREAM_SEMANTIC_ASSERTION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes("{\"type\":\"object\"}")
        );
        host = new StreamCollectionAttestations(_configuration(address(executor)));
    }

    function _configuration(address authority)
        internal
        view
        returns (StreamCollectionAttestations.Configuration memory c)
    {
        c.core = address(core);
        c.schemas = address(schemas);
        c.executor = authority;
        c.deploymentManifestHash = keccak256("deployment fixture");
        c.manifestURI = "ipfs://fixture";
        c.manifestHash = keccak256("manifest fixture");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2
        );
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) internal returns (bytes32) {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas),
                abi.encodeCall(schemas.registerDocument, (spec, chunks)),
                s,
                o,
                n,
                1
            ),
            (bytes32)
        );
    }

    function _request(address attestor, uint256 nonce)
        internal
        view
        returns (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        )
    {
        s = IStreamCollectionAttestations.Subject(
            IStreamCollectionAttestations.SubjectKind.COLLECTION, 1, 0, 0
        );
        r.attestor = attestor;
        r.scopeKey = 1;
        r.subjectId = host.deriveSubject(s);
        r.recordType = keccak256("INDEPENDENT_SEMANTIC_ASSERTION");
        r.schemaId = schemaId;
        r.algorithmId = 1;
        r.payload = bytes("{\"claim\":\"independent fixture\"}");
        r.digest = abi.encode(keccak256(r.payload));
        r.canonicalizationId = keccak256("RAW_BYTES");
        r.uri = "ipfs://independent";
        r.effectiveAt = 999;
        r.nonce = nonce;
        r.deadline = 2000;
    }

    function _sign(bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _domain(uint256 chainId, address verifier) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamCollectionAttestations"),
                keccak256("1"),
                chainId,
                verifier
            )
        );
    }

    function _body(IStreamCollectionAttestations.IndependentRecord memory r)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256(
                    "StreamIndependentPreservationRecord(address attestor,uint256 scopeKey,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,uint16 algorithmId,bytes digest,bytes32 canonicalizationId,string uri,bytes payload,uint64 effectiveAt,uint256 nonce,uint64 deadline)"
                ),
                r.attestor,
                r.scopeKey,
                r.subjectId,
                r.recordType,
                r.schemaId,
                r.algorithmId,
                keccak256(r.digest),
                r.canonicalizationId,
                keccak256(bytes(r.uri)),
                keccak256(r.payload),
                r.effectiveAt,
                r.nonce,
                r.deadline
            )
        );
    }
}

contract StreamCollectionAttestationsTest is IndependentAttestationTestBase {
    function testPinnedNamedPreimagesDomainAndOriginalBundleReconstruction() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(signer, 89);
        bytes32 expected =
            keccak256(abi.encodePacked(hex"1901", _domain(block.chainid, address(host)), _body(r)));
        require(host.independentRecordDigest(r) == expected, "full named digest");
        require(
            host.STREAM_INDEPENDENT_PRESERVATION_TYPEHASH()
                == keccak256(
                    "StreamIndependentPreservationRecord(address attestor,uint256 scopeKey,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,uint16 algorithmId,bytes digest,bytes32 canonicalizationId,string uri,bytes payload,uint64 effectiveAt,uint256 nonce,uint64 deadline)"
                ),
            "record typehash"
        );
        require(
            host.STREAM_INDEPENDENT_PRESERVATION_REVOCATION_TYPEHASH()
                == keccak256(
                    "StreamIndependentPreservationRevocation(address attestor,uint256 nonce,uint64 deadline)"
                ),
            "revoke typehash"
        );
        bytes memory sig = _sign(expected);
        bytes32 hash = host.recordIndependentPreservation(s, r, sig);
        (, bytes memory bundle) = host.recordSignatureBundle(hash);
        (bytes32 domain, bytes32[14] memory words, bytes memory retainedSig) =
            abi.decode(bundle, (bytes32, bytes32[14], bytes));
        require(
            domain == _domain(block.chainid, address(host))
                && keccak256(abi.encode(words)) == _body(r),
            "bundle preimages"
        );
        require(keccak256(retainedSig) == keccak256(sig), "signature bytes");
        (
            IStreamPreservationRecords.CollectionRecord memory record,
            IStreamCollectionAttestations.Receipt memory receipt
        ) = host.collectionRecord(hash);
        require(
            record.signatureScheme == keccak256("EIP712")
                && receipt.authorizationDigest == expected,
            "attribution"
        );
        require(
            receipt.attestor == signer && receipt.authorizationClass == 5 && receipt.nonce == 89
                && receipt.deadline == 2000,
            "receipt"
        );
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifier,
            bytes32 salt,
            uint256[] memory ext
        ) = host.eip712Domain();
        require(
            fields == 0x0f
                && keccak256(bytes(name)) == keccak256("6529StreamCollectionAttestations")
                && keccak256(bytes(version)) == keccak256("1"),
            "domain strings"
        );
        require(
            chainId == block.chainid && verifier == address(host) && salt == 0 && ext.length == 0,
            "domain fields"
        );
    }

    function testDirectUnorderedNoncesRevocationsAndAttestorIsolation() public {
        uint256[3] memory nonces = [type(uint256).max, uint256(0), uint256(8)];
        for (uint256 i; i < 3; ++i) {
            (
                IStreamCollectionAttestations.Subject memory s,
                IStreamCollectionAttestations.IndependentRecord memory r
            ) = _request(address(this), nonces[i]);
            host.recordIndependentPreservation(s, r, "");
            require(host.isIndependentAttestorNonceUsed(address(this), nonces[i]), "named nonce");
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamCollectionAttestations.IndependentNonceUsed.selector,
                    address(this),
                    nonces[i]
                )
            );
            host.recordIndependentPreservation(s, r, "");
        }
        host.revokeIndependentAttestorNonce(4);
        (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamCollectionAttestations.IndependentRecord memory revoked
        ) = _request(address(this), 4);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.IndependentNonceUsed.selector, address(this), 4
            )
        );
        host.recordIndependentPreservation(subject, revoked, "");
        revoked.attestor = signer;
        host.recordIndependentPreservation(
            subject, revoked, _sign(host.independentRecordDigest(revoked))
        );
        (, uint64 count) = host.recordChainHash(1, revoked.recordType);
        require(count == 4, "revokes not records");
    }

    function testRelayedRevocationRejectsWriteSignatureAndWrongDomainThenConsumesSameLane() public {
        (, IStreamCollectionAttestations.IndependentRecord memory r) = _request(signer, 777);
        bytes memory writeSig = _sign(host.independentRecordDigest(r));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.InvalidIndependentSignature.selector, signer
            )
        );
        host.revokeIndependentAttestorNonceFor(signer, r.nonce, r.deadline, writeSig);
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamIndependentPreservationRevocation(address attestor,uint256 nonce,uint64 deadline)"
                ),
                signer,
                r.nonce,
                r.deadline
            )
        );
        bytes memory wrong = _sign(
            keccak256(abi.encodePacked(hex"1901", _domain(block.chainid + 1, address(host)), body))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.InvalidIndependentSignature.selector, signer
            )
        );
        host.revokeIndependentAttestorNonceFor(signer, r.nonce, r.deadline, wrong);
        bytes32 digest =
            keccak256(abi.encodePacked(hex"1901", _domain(block.chainid, address(host)), body));
        require(
            digest == host.independentRevocationDigest(signer, r.nonce, r.deadline),
            "named revocation"
        );
        host.revokeIndependentAttestorNonceFor(signer, r.nonce, r.deadline, _sign(digest));
        require(host.isIndependentAttestorNonceUsed(signer, r.nonce), "revoked");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.IndependentNonceUsed.selector, signer, r.nonce
            )
        );
        host.revokeIndependentAttestorNonceFor(signer, r.nonce, r.deadline, "");
    }

    function testStoredBytesPointersAndIndependentRecordChainAreCompleteWithoutProviders() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(this), 1);
        bytes32 previous;
        bytes32 last;
        for (uint256 i; i < 2; ++i) {
            r.nonce = i + 1;
            last = host.recordIndependentPreservation(s, r, "");
            previous = keccak256(
                abi.encode(
                    bytes32(0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609),
                    block.chainid,
                    address(host),
                    uint256(1),
                    r.recordType,
                    previous,
                    last,
                    uint64(i)
                )
            );
            (bytes32 chain, uint64 count) = host.recordChainHash(1, r.recordType);
            require(
                chain == previous && count == i + 1
                    && host.recordHashAt(1, r.recordType, i) == last,
                "chain exact"
            );
        }
        require(host.payloadPointerCount(1) == 3, "one payload two bundles");
        vm.etch(address(core), hex"00");
        vm.etch(address(schemas), hex"00");
        vm.etch(address(store), hex"00");
        vm.etch(address(executor), hex"00");
        for (uint256 i; i < host.payloadPointerCount(1); ++i) {
            (address blob, bytes32 family, bytes32 hash) = host.payloadPointerAt(1, i);
            require(family != 0 && keccak256(SSTORE2.read(blob)) == hash, "state-only bytes");
        }
        (address pointer, bytes memory payload) =
            host.collectionRecordPayload(1, r.recordType, r.subjectId);
        require(
            pointer != address(0) && keccak256(payload) == keccak256(r.payload),
            "history no providers"
        );
        require(
            host.latestCollectionRecordHashFor(1, r.recordType, r.subjectId, address(this)) == last,
            "latest"
        );
        require(host.recordSubject(last).collectionId == 1, "saved subject");
    }

    function testDeploymentCollectionTokenBurnedAndDeclaredMediaSubjects() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(this), 1);
        s.collectionId = 0;
        r.scopeKey = 0;
        r.subjectId = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(core),
                uint256(0)
            )
        );
        host.recordIndependentPreservation(s, r, "");
        s.collectionId = 1;
        s.kind = IStreamCollectionAttestations.SubjectKind.TOKEN;
        s.tokenId = 71;
        r.scopeKey = 1;
        r.nonce = 2;
        r.subjectId = host.deriveSubject(s);
        core.setLifecycle(1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionAttestations.InvalidIndependentSubject.selector)
        );
        host.recordIndependentPreservation(s, r, "");
        require(!host.isIndependentAttestorNonceUsed(address(this), 2), "no partial consumption");
        core.setLifecycle(3);
        host.recordIndependentPreservation(s, r, "");
        s.kind = IStreamCollectionAttestations.SubjectKind.MEDIA;
        s.tokenId = 0;
        s.objectId = keccak256("declared object");
        r.nonce = 3;
        r.subjectId = keccak256(
            abi.encode(
                bytes32(0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b),
                block.chainid,
                address(core),
                uint256(1),
                s.objectId
            )
        );
        host.recordIndependentPreservation(s, r, "");
        s.collectionId = 2;
        r.nonce = 4;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionAttestations.InvalidIndependentRecord.selector)
        );
        host.recordIndependentPreservation(s, r, "");
    }

    function testRetiredDefinitionsAndAbsentGovernanceDoNotBlockEntryOrRevocation() public {
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(schemaId, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (schemaId, IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
            ),
            s,
            o,
            n,
            1
        );
        host = new StreamCollectionAttestations(_configuration(address(0)));
        vm.etch(address(executor), hex"00");
        (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(this), 67);
        bytes32 hash = host.recordIndependentPreservation(subject, r, "");
        (, IStreamCollectionAttestations.Receipt memory receipt) = host.collectionRecord(hash);
        require(
            receipt.schemaDefinitionHash == keccak256(bytes("{\"type\":\"object\"}")),
            "retired bytes pinned"
        );
        host.revokeIndependentAttestorNonce(68);
        require(
            host.isIndependentAttestorNonceUsed(address(this), 68), "zero governance revocation"
        );
    }

    function testExactPayloadBoundaryMalformedAndExpiredRollbackThenIdenticalHealthyProof() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(this), 9);
        r.payload = new bytes(8193);
        r.digest = abi.encode(keccak256(r.payload));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionAttestations.InvalidIndependentRecord.selector)
        );
        host.recordIndependentPreservation(s, r, "");
        r.payload = new bytes(8192);
        r.digest = abi.encode(keccak256(r.payload));
        r.deadline = 999;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.IndependentDeadlineExpired.selector, uint64(999)
            )
        );
        host.recordIndependentPreservation(s, r, "");
        require(
            !host.isIndependentAttestorNonceUsed(address(this), 9)
                && host.payloadPointerCount(1) == 0,
            "full rollback"
        );
        r.deadline = 1000;
        bytes32 hash = host.recordIndependentPreservation(s, r, "");
        (, bytes memory payload) = host.recordPayload(hash);
        require(payload.length == 8192, "exact boundary and equality");
    }

    function testBoundedERC1271FaultsRejectBeforeStateAndSameProofEventuallySucceeds() public {
        IndependentSignatureBoundary wallet = new IndependentSignatureBoundary();
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(wallet), 1);
        bytes32 digest = host.independentRecordDigest(r);
        for (uint256 mode = 1; mode <= 5; ++mode) {
            wallet.set(digest, mode);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamCollectionAttestations.InvalidIndependentSignature.selector,
                    address(wallet)
                )
            );
            host.recordIndependentPreservation(s, r, hex"1234");
            require(
                !host.isIndependentAttestorNonceUsed(address(wallet), 1)
                    && host.payloadPointerCount(1) == 0,
                "invalid signature no effects"
            );
        }
        wallet.set(digest, 0);
        bytes32 hash = host.recordIndependentPreservation(s, r, hex"1234");
        (IStreamPreservationRecords.CollectionRecord memory record,) = host.collectionRecord(hash);
        require(record.signatureScheme == keccak256("ERC1271"), "actual contract verification");
    }
}
