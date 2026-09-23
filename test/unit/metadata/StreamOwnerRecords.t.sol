// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import "../../../smart-contracts/domains/metadata/StreamOwnerRecords.sol";

contract OwnerSignatureBoundary {
    bytes32 public allowed;
    uint256 public mode;

    function configure(bytes32 digest, uint256 value) external {
        allowed = digest;
        mode = value;
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        if (mode == 1) revert("unavailable");
        if (mode == 2) assembly ("memory-safe") { return(0, 0) }
        if (mode == 3) {
            assembly ("memory-safe") {
                mstore(0, or(shl(224, 0x1626ba7e), 1))
                return(0, 32)
            }
        }
        return digest == allowed ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// @notice Actual owner host, registered definitions and Store; Core/Executor are explicit boundaries.
contract StreamOwnerRecordsTest is CollectionMetadataV1Fixture {
    StreamOwnerRecords private dossier;
    uint256 private deploymentChain;
    bytes32 private constant ACCESSION = keccak256("ACCESSION");

    function _prepare(address owner) private {
        deploymentChain = block.chainid;
        StreamOwnerRecords.Configuration memory c;
        c.core = address(core);
        c.schemas = address(schemas);
        c.executor = address(executor);
        c.deploymentManifestHash = bytes32(uint256(1));
        c.manifestHash = bytes32(uint256(2));
        c.manifestURI = "ipfs://owner-records";
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        dossier = new StreamOwnerRecords(c);
        core.setToken(7, owner, 2);
    }

    function _ownerRecord(bytes memory payload)
        private
        view
        returns (IStreamOwnerRecords.OwnerRecord memory r)
    {
        r.recordType = ACCESSION;
        r.subjectId = dossier.deriveOwnerSubject(7);
        r.schemaId = schemaId;
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), schemas.RAW_BYTES()
        );
        r.uri = "ipfs://owner-record";
        r.payload = payload;
        r.effectiveAt = 1;
    }

    function _signature(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _relay(IStreamOwnerRecords.OwnerRecord memory r, uint256 key, uint256 nonce) private {
        address owner = vm.addr(key);
        bytes32 digest = dossier.ownerRecordDigest(7, r, owner, nonce, 2000);
        dossier.recordOwnerRecordFor(7, r, owner, nonce, 2000, _signature(key, digest));
    }

    function testActualRecordsPreservePayloadOwnerHistoryAndExactEvent() public {
        _prepare(address(this));
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("{\"accession\":1}"));
        vm.recordLogs();
        dossier.recordOwnerRecord(7, r);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 hash = dossier.recordHashAt(7, ACCESSION, 0);
        (bytes32 chain, uint64 count) = dossier.recordChainHash(7, ACCESSION);
        require(
            count == 1
                && chain
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RECORD_CHAIN_V1"),
                            block.chainid,
                            address(dossier),
                            uint256(7),
                            ACCESSION,
                            bytes32(0),
                            hash,
                            uint64(0)
                        )
                    ),
            "literal owner lane chain"
        );
        (IStreamOwnerRecords.OwnerRecord memory saved, IStreamOwnerRecords.Receipt memory receipt) =
            dossier.ownerRecord(hash);
        require(keccak256(abi.encode(saved)) == keccak256(abi.encode(r)), "complete retained bytes");
        require(
            receipt.owner == address(this) && !receipt.relayed && receipt.tokenId == 7
                && receipt.recordIndex == 0,
            "owner provenance"
        );
        Vm.Log memory log = logs[logs.length - 1];
        require(
            log.emitter == address(dossier) && log.topics.length == 4
                && log.topics[0]
                    == keccak256(
                        "OwnerRecordRecorded(uint256,bytes32,address,(bytes32,bytes32,bytes32,(uint16,bytes,bytes32),string,bytes,uint64),bytes32,bytes32,bool,uint16)"
                    ) && log.topics[1] == bytes32(uint256(7)) && log.topics[2] == ACCESSION
                && log.topics[3] == bytes32(uint256(uint160(address(this)))),
            "exact event topics"
        );
        require(
            keccak256(log.data) == keccak256(abi.encode(r, hash, chain, false, uint16(1))),
            "exact event body"
        );
    }

    function testCurrentOwnerOnlyAndTransferDoesNotEraseEarlierCustody() public {
        _prepare(address(this));
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("first"));
        dossier.recordOwnerRecord(7, r);
        bytes32 first = dossier.recordHashAt(7, ACCESSION, 0);
        core.setToken(7, address(0xbeef), 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOwnerRecords.OwnerRecordAuthorityRequired.selector, address(this)
            )
        );
        dossier.recordOwnerRecord(7, r);
        r.payload = bytes("new owner");
        r.contentHash.digest = abi.encode(keccak256(r.payload));
        vm.prank(address(0xbeef));
        dossier.recordOwnerRecord(7, r);
        (, IStreamOwnerRecords.Receipt memory earlier) = dossier.ownerRecord(first);
        require(
            earlier.owner == address(this)
                && dossier.latestOwnerRecordHashFor(7, ACCESSION, address(this)) == first,
            "old owner permanent"
        );
        (, uint64 count) = dossier.recordChainHash(7, ACCESSION);
        require(count == 2, "custody history append");
    }

    function testLiteralTypehashDomainAndFourteenSignedFields() public {
        _prepare(address(this));
        require(
            dossier.STREAM_OWNER_RECORD_TYPEHASH()
                == keccak256(
                    "StreamOwnerRecord(address owner,uint256 tokenId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,uint16 algorithmId,bytes digest,bytes32 canonicalizationId,string uri,bytes payload,uint64 effectiveAt,uint256 nonce,uint64 deadline)"
                ),
            "record type literal"
        );
        require(
            dossier.STREAM_OWNER_RECORD_REVOCATION_TYPEHASH()
                == keccak256(
                    "StreamOwnerRecordRevocation(address owner,uint256 nonce,uint64 deadline)"
                ),
            "revocation literal"
        );
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("record"));
        bytes32[14] memory words;
        words[0] = dossier.STREAM_OWNER_RECORD_TYPEHASH();
        words[1] = bytes32(uint256(uint160(address(this))));
        words[2] = bytes32(uint256(7));
        words[3] = r.subjectId;
        words[4] = r.recordType;
        words[5] = r.schemaId;
        words[6] = bytes32(uint256(1));
        words[7] = keccak256(r.contentHash.digest);
        words[8] = r.contentHash.canonicalizationId;
        words[9] = keccak256(bytes(r.uri));
        words[10] = keccak256(r.payload);
        words[11] = bytes32(uint256(1));
        words[12] = bytes32(uint256(123));
        words[13] = bytes32(uint256(2000));
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamOwnerRecords"),
                keccak256("1"),
                block.chainid,
                address(dossier)
            )
        );
        require(
            dossier.ownerRecordDigest(7, r, address(this), 123, 2000)
                == keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(words)))),
            "independent signed preimage"
        );
    }

    function testUnorderedOwnerNoncesAndReplayAreIndependentOfRelayOrder() public {
        address owner = vm.addr(777);
        _prepare(owner);
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("statement"));
        _relay(r, 777, type(uint256).max);
        _relay(r, 777, 1);
        require(
            dossier.isOwnerRecordNonceUsed(vm.addr(777), 1)
                && dossier.isOwnerRecordNonceUsed(vm.addr(777), type(uint256).max),
            "unordered keys"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOwnerRecords.OwnerRecordNonceUsed.selector, owner, uint256(1)
            )
        );
        dossier.recordOwnerRecordFor(7, r, owner, 1, 2000, bytes(""));
    }

    function testTransferAfterSigningRejectsOldOwnerWithoutConsumingNonce() public {
        address owner = vm.addr(777);
        _prepare(owner);
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("statement"));
        bytes memory sig = _signature(777, dossier.ownerRecordDigest(7, r, owner, 11, 2000));
        core.setToken(7, address(0xbeef), 2);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerRecords.OwnerRecordAuthorityRequired.selector, owner)
        );
        dossier.recordOwnerRecordFor(7, r, owner, 11, 2000, sig);
        require(!dossier.isOwnerRecordNonceUsed(owner, 11), "authority failure atomic");
        core.setToken(7, owner, 2);
        dossier.recordOwnerRecordFor(7, r, owner, 11, 2000, sig);
    }

    function testRevocationIsSignerScopedDirectAndRelayedAndEmitsExactEvent() public {
        _prepare(address(this));
        vm.recordLogs();
        dossier.revokeOwnerRecordNonce(9);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 1
                && logs[0].topics[0]
                    == keccak256("OwnerRecordNonceRevoked(address,uint256,bool,uint16)")
                && keccak256(logs[0].data) == keccak256(abi.encode(false, uint16(1))),
            "revocation event"
        );
        address owner = vm.addr(777);
        dossier.revokeOwnerRecordNonceFor(
            owner, 9, 2000, _signature(777, dossier.ownerRecordRevocationDigest(owner, 9, 2000))
        );
        require(
            dossier.isOwnerRecordNonceUsed(owner, 9)
                && dossier.isOwnerRecordNonceUsed(address(this), 9),
            "distinct signers"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOwnerRecords.OwnerRecordNonceUsed.selector, owner, uint256(9)
            )
        );
        dossier.revokeOwnerRecordNonceFor(owner, 9, 2000, bytes(""));
    }

    function testExpiredWrongChainAndTamperedRecordKeepNonceFree() public {
        address owner = vm.addr(777);
        _prepare(owner);
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("one"));
        bytes memory sig = _signature(777, dossier.ownerRecordDigest(7, r, owner, 7, 2000));
        r.uri = "ipfs://changed";
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecordSignature.selector, owner)
        );
        dossier.recordOwnerRecordFor(7, r, owner, 7, 2000, sig);
        r.uri = "ipfs://owner-record";
        vm.chainId(deploymentChain + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecordSignature.selector, owner)
        );
        dossier.recordOwnerRecordFor(7, r, owner, 7, 2000, sig);
        vm.chainId(deploymentChain);
        vm.warp(2001);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOwnerRecords.OwnerRecordDeadlineExpired.selector, uint64(2000)
            )
        );
        dossier.recordOwnerRecordFor(7, r, owner, 7, 2000, sig);
        require(!dossier.isOwnerRecordNonceUsed(owner, 7), "bad auth never consumes");
    }

    function testContractSignatureMalformedFailureThenIdenticalRetry() public {
        OwnerSignatureBoundary owner = new OwnerSignatureBoundary();
        _prepare(address(owner));
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("statement"));
        bytes32 digest = dossier.ownerRecordDigest(7, r, address(owner), 1, 2000);
        for (uint256 mode = 1; mode <= 3; ++mode) {
            owner.configure(digest, mode);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamOwnerRecords.InvalidOwnerRecordSignature.selector, address(owner)
                )
            );
            dossier.recordOwnerRecordFor(7, r, address(owner), 1, 2000, bytes(""));
            require(!dossier.isOwnerRecordNonceUsed(address(owner), 1), "malformed return atomic");
        }
        owner.configure(digest, 0);
        dossier.recordOwnerRecordFor(7, r, address(owner), 1, 2000, bytes(""));
    }

    function testLateStoreFailureRollsBackNonceAndHistoryThenExactRetry() public {
        address owner = vm.addr(777);
        _prepare(owner);
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("statement"));
        bytes memory sig = _signature(777, dossier.ownerRecordDigest(7, r, owner, 1, 2000));
        bytes memory runtime = address(store).code;
        vm.etch(address(store), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOwnerRecords.OwnerRecordDependencyChanged.selector, address(store)
            )
        );
        dossier.recordOwnerRecordFor(7, r, owner, 1, 2000, sig);
        require(
            !dossier.isOwnerRecordNonceUsed(owner, 1), "late failure rolls back signature replay"
        );
        (, uint64 count) = dossier.recordChainHash(7, ACCESSION);
        require(count == 0, "no partial record");
        vm.etch(address(store), runtime);
        dossier.recordOwnerRecordFor(7, r, owner, 1, 2000, sig);
    }

    function testOwnerLaneRemainsWritableAfterMetadataPointerAndSchemaRetirement() public {
        _prepare(address(this));
        core.setPointer(keccak256("COLLECTION_METADATA"), address(0));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.statusTransition(schemaId, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus,
                (schemaId, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            oldHash,
            newHash
        );
        dossier.recordOwnerRecord(7, _ownerRecord(bytes("post-finality registrar evidence")));
        (, uint64 count) = dossier.recordChainHash(7, ACCESSION);
        require(count == 1, "operator retirement cannot lock owner evidence");
    }

    function testBurnedPreparedAndWrongSubjectHaveNoOwnerWriteAuthority() public {
        _prepare(address(this));
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("statement"));
        core.setToken(7, address(this), 1);
        vm.expectRevert();
        dossier.recordOwnerRecord(7, r);
        core.setToken(7, address(0), 3);
        vm.expectRevert();
        dossier.recordOwnerRecord(7, r);
        core.setToken(7, address(this), 2);
        r.subjectId = bytes32(uint256(123));
        vm.expectRevert(abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecord.selector));
        dossier.recordOwnerRecord(7, r);
    }

    function testAllTenFamiliesAndGovernedAdditiveAdmission() public {
        _prepare(address(this));
        string[10] memory names = [
            "ACCESSION",
            "CONDITION_REPORT",
            "EXHIBITION",
            "LOAN",
            "DEACCESSION",
            "CITATION",
            "VALUATION",
            "STEWARD_DESIGNATION",
            "RECOVERY_RESPONSE",
            "REDEMPTION_CLAIM"
        ];
        for (uint256 i; i < names.length; ++i) {
            IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("notice"));
            r.recordType = keccak256(bytes(names[i]));
            dossier.recordOwnerRecord(7, r);
        }
        bytes32 added = keccak256("FUTURE_OWNER_DOCUMENT");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerRecords.OwnerRecordGovernanceRequired.selector)
        );
        dossier.admitOwnerRecordType(added);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = dossier.ownerRecordTypeTransition(added);
        executor.execute(
            address(dossier),
            abi.encodeCall(dossier.admitOwnerRecordType, (added)),
            scope,
            oldHash,
            newHash
        );
        IStreamOwnerRecords.OwnerRecord memory r2 = _ownerRecord(bytes("new family"));
        r2.recordType = added;
        dossier.recordOwnerRecord(7, r2);
    }

    function testEmptyExternalAndSha256PayloadsRetainAllExactBytes() public {
        _prepare(address(this));
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes(""));
        r.contentHash.algorithm = 3;
        r.contentHash.digest = abi.encode(bytes32(uint256(987)));
        dossier.recordOwnerRecord(7, r);
        (IStreamOwnerRecords.OwnerRecord memory saved,) =
            dossier.ownerRecord(dossier.recordHashAt(7, ACCESSION, 0));
        require(
            saved.payload.length == 0
                && keccak256(saved.contentHash.digest) == keccak256(r.contentHash.digest),
            "external commitment"
        );
        r.payload = bytes("sha256 record");
        r.contentHash.algorithm = 2;
        r.contentHash.digest = abi.encode(sha256(r.payload));
        dossier.recordOwnerRecord(7, r);
        (saved,) = dossier.ownerRecord(dossier.recordHashAt(7, ACCESSION, 1));
        require(keccak256(saved.payload) == keccak256(r.payload), "sha256 payload");
    }

    function testThresholdSafeDirectRelayedRevocationAndHistoricalReads() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 101;
        keys[1] = 202;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1);
        _prepare(address(account));
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("institutional accession"));
        require(
            executeSafe(
                account,
                keys,
                address(dossier),
                0,
                abi.encodeCall(dossier.recordOwnerRecord, (7, r)),
                0
            ),
            "Safe direct custody write"
        );
        bytes32 digest = dossier.ownerRecordDigest(7, r, address(account), 77, 2000);
        dossier.recordOwnerRecordFor(
            7,
            r,
            address(account),
            77,
            2000,
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)))
        );
        require(
            executeSafe(
                account,
                keys,
                address(dossier),
                0,
                abi.encodeCall(dossier.revokeOwnerRecordNonce, (uint256(88))),
                0
            ),
            "Safe revokes"
        );
        bytes32 hash = dossier.recordHashAt(7, ACCESSION, 0);
        require(
            executeSafe(
                account, keys, address(dossier), 0, abi.encodeCall(dossier.ownerRecord, (hash)), 0
            ),
            "Safe full historic record"
        );
        require(
            executeSafe(
                account,
                keys,
                address(dossier),
                0,
                abi.encodeCall(dossier.recordChainHash, (uint256(7), ACCESSION)),
                0
            ),
            "Safe chain read"
        );
        require(
            executeSafe(
                account,
                keys,
                address(dossier),
                0,
                abi.encodeCall(dossier.isOwnerRecordNonceUsed, (address(account), uint256(77))),
                0
            ),
            "Safe explicit nonce read"
        );
        (, IStreamOwnerRecords.Receipt memory receipt) =
            dossier.ownerRecord(dossier.recordHashAt(7, ACCESSION, 1));
        require(
            receipt.owner == address(account) && receipt.relayed
                && receipt.signatureScheme == keccak256("ERC1271"),
            "actual Safe original provenance"
        );
    }

    function testFuzzExactPayloadAndIndependentOwnerLane(bytes32 value, uint64 nonce) public {
        address owner = vm.addr(777);
        _prepare(owner);
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(abi.encode(value));
        _relay(r, 777, nonce);
        bytes32 hash = dossier.recordHashAt(7, ACCESSION, 0);
        (IStreamOwnerRecords.OwnerRecord memory saved, IStreamOwnerRecords.Receipt memory receipt) =
            dossier.ownerRecord(hash);
        require(
            keccak256(saved.payload) == keccak256(abi.encode(value)) && receipt.nonce == nonce,
            "exact fuzzed bytes and replay value"
        );
        core.setToken(8, owner, 2);
        r.subjectId = dossier.deriveOwnerSubject(8);
        vm.prank(owner);
        dossier.recordOwnerRecord(8, r);
        (bytes32 a,) = dossier.recordChainHash(7, ACCESSION);
        (bytes32 b,) = dossier.recordChainHash(8, ACCESSION);
        require(a != b, "token-separated complete lanes");
    }

    function testMaximumPayloadStoredExactlyAndOversizeRollsBack() public {
        address owner = vm.addr(777);
        _prepare(owner);
        bytes memory payload = new bytes(8192);
        payload[8191] = 0x42;
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(payload);
        _relay(r, 777, 19);
        (IStreamOwnerRecords.OwnerRecord memory saved,) =
            dossier.ownerRecord(dossier.recordHashAt(7, ACCESSION, 0));
        require(
            saved.payload.length == 8192 && keccak256(saved.payload) == keccak256(payload),
            "full8192"
        );
        r.payload = new bytes(8193);
        r.contentHash.digest = abi.encode(keccak256(r.payload));
        bytes memory sig = _signature(777, dossier.ownerRecordDigest(7, r, owner, 20, 2000));
        vm.expectRevert(abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecord.selector));
        dossier.recordOwnerRecordFor(7, r, owner, 20, 2000, sig);
        require(!dossier.isOwnerRecordNonceUsed(owner, 20), "oversize nonce rollback");
        (, uint64 count) = dossier.recordChainHash(7, ACCESSION);
        require(count == 1, "oversize no history");
    }

    function testEveryHashAlgorithmShapeAndExactPayloadVerification() public {
        _prepare(address(this));
        for (uint16 algorithm = 1; algorithm <= 6; ++algorithm) {
            IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(abi.encode(algorithm));
            r.contentHash.algorithm = algorithm;
            if (algorithm == 2) r.contentHash.digest = abi.encode(sha256(r.payload));
            if (algorithm == 4 || algorithm == 5) r.contentHash.digest = new bytes(128);
            dossier.recordOwnerRecord(7, r);
            r.contentHash.digest = new bytes(algorithm == 4 || algorithm == 5 ? 129 : 31);
            vm.expectRevert(abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecord.selector));
            dossier.recordOwnerRecord(7, r);
            r.contentHash.digest = bytes("");
            vm.expectRevert(abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecord.selector));
            dossier.recordOwnerRecord(7, r);
            if (algorithm == 4 || algorithm == 5) {
                r.contentHash.digest = hex"01";
                dossier.recordOwnerRecord(7, r);
            } else if (algorithm <= 2) {
                r.contentHash.digest = abi.encode(bytes32(0));
                vm.expectRevert(
                    abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecord.selector)
                );
                dossier.recordOwnerRecord(7, r);
            }
        }
        (, uint64 count) = dossier.recordChainHash(7, ACCESSION);
        require(count == 8, "six algorithms plus both opaque minimums");
    }

    function testOpaqueDigestCannotHideSignedPayloadTampering() public {
        address owner = vm.addr(777);
        _prepare(owner);
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("original"));
        r.contentHash.algorithm = 3;
        bytes memory sig = _signature(777, dossier.ownerRecordDigest(7, r, owner, 21, 2000));
        r.payload = bytes("tampered");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecordSignature.selector, owner)
        );
        dossier.recordOwnerRecordFor(7, r, owner, 21, 2000, sig);
        require(!dossier.isOwnerRecordNonceUsed(owner, 21), "opaque bytes still signed");
        r.payload = bytes("original");
        dossier.recordOwnerRecordFor(7, r, owner, 21, 2000, sig);
    }

    function testCompactEoaSignatureAndMalformedControls() public {
        address owner = vm.addr(777);
        _prepare(owner);
        IStreamOwnerRecords.OwnerRecord memory record = _ownerRecord(bytes("compact"));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(777, dossier.ownerRecordDigest(7, record, owner, 22, 2000));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecordSignature.selector, owner)
        );
        dossier.recordOwnerRecordFor(7, record, owner, 22, 2000, abi.encodePacked(r, s, uint8(1)));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecordSignature.selector, owner)
        );
        dossier.recordOwnerRecordFor(
            7, record, owner, 22, 2000, abi.encodePacked(r, bytes32(type(uint256).max), v)
        );
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecordSignature.selector, owner)
        );
        dossier.recordOwnerRecordFor(7, record, owner, 22, 2000, bytes(""));
        require(!dossier.isOwnerRecordNonceUsed(owner, 22), "relayed EOA has no direct bypass");
        bytes32 vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
        dossier.recordOwnerRecordFor(7, record, owner, 22, 2000, abi.encodePacked(r, vs));
    }

    function testLowParentGasFailsWithoutNonceConsumptionThenExactRetry() public {
        address owner = vm.addr(777);
        _prepare(owner);
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("gas retry"));
        bytes memory sig = _signature(777, dossier.ownerRecordDigest(7, r, owner, 23, 2000));
        (bool ok, bytes memory reason) = address(dossier).call{ gas: 100000 }(
            abi.encodeCall(dossier.recordOwnerRecordFor, (7, r, owner, 23, 2000, sig))
        );
        require(
            !ok && reason.length == 68
                && bytes4(reason) == IStreamOwnerRecords.OwnerRecordParentGas.selector,
            "specific parent gas failure"
        );
        require(!dossier.isOwnerRecordNonceUsed(owner, 23), "gas nonce unchanged");
        (, uint64 count) = dossier.recordChainHash(7, ACCESSION);
        require(count == 0, "gas history unchanged");
        dossier.recordOwnerRecordFor(7, r, owner, 23, 2000, sig);
    }

    function testTimestampOverflowRejectsDirectRecordThenRestoresHealthyWrite() public {
        _prepare(address(this));
        IStreamOwnerRecords.OwnerRecord memory r = _ownerRecord(bytes("timestamp"));
        vm.warp(uint256(type(uint64).max) + 1);
        vm.expectRevert(abi.encodeWithSelector(IStreamOwnerRecords.InvalidOwnerRecord.selector));
        dossier.recordOwnerRecord(7, r);
        (, uint64 count) = dossier.recordChainHash(7, ACCESSION);
        require(count == 0, "timestamp cannot truncate");
        vm.warp(1000);
        dossier.recordOwnerRecord(7, r);
    }
}
