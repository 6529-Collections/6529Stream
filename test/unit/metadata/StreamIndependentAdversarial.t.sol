// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionAttestations.t.sol";

contract IndependentGasWitness {
    uint256 public minimum;
    bytes32 public digest;

    function set(uint256 amount, bytes32 value) external {
        minimum = amount;
        digest = value;
    }

    function isValidSignature(bytes32 value, bytes calldata) external view returns (bytes4) {
        require(gasleft() >= minimum, "full configured cap");
        return value == digest ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract StreamIndependentAdversarialTest is IndependentAttestationTestBase {
    function testAllEightBuiltinTypesAreOpenAndOperatorTypesReject() public {
        string[8] memory names = [
            "INDEPENDENT_FIXITY",
            "INDEPENDENT_PRESERVATION_EVENT",
            "INDEPENDENT_EXHIBITION",
            "INDEPENDENT_CONDITION",
            "INDEPENDENT_CONSERVATION_TREATMENT",
            "INDEPENDENT_ENVIRONMENT_MIGRATION",
            "INDEPENDENT_EXPORT_MIRROR",
            "INDEPENDENT_SEMANTIC_ASSERTION"
        ];
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(this), 0);
        // This proves attributed type admission, not JSON-schema meaning validation.
        for (uint256 i; i < 8; ++i) {
            r.nonce = i;
            r.recordType = keccak256(bytes(names[i]));
            require(host.isIndependentRecordType(r.recordType), "catalog exact");
            host.recordIndependentPreservation(s, r, "");
        }
        r.nonce = 99;
        r.recordType = keccak256("ARTIST_SEMANTIC_ASSERTION");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionAttestations.InvalidIndependentRecord.selector)
        );
        host.recordIndependentPreservation(s, r, "");
        require(
            !host.isIndependentRecordType(0)
                && !host.isIndependentAttestorNonceUsed(address(this), 99),
            "closed independent family"
        );
    }

    function testFullGenericRecordPreimageAndAllRecordedEventFields() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(this), 25);
        vm.recordLogs();
        bytes32 hash = host.recordIndependentPreservation(s, r, "");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (
            IStreamPreservationRecords.CollectionRecord memory record,
            IStreamCollectionAttestations.Receipt memory receipt
        ) = host.collectionRecord(hash);
        bytes32[14] memory w;
        w[0] = keccak256("6529stream.preservation-record.v2");
        w[1] = bytes32(block.chainid);
        w[2] = bytes32(uint256(uint160(address(host))));
        w[3] = bytes32(uint256(uint160(address(core))));
        w[4] = bytes32(uint256(uint160(address(this))));
        w[5] = bytes32(uint256(1));
        w[6] = r.recordType;
        w[7] = r.subjectId;
        w[8] = keccak256(abi.encode(uint16(1), keccak256(r.digest), r.canonicalizationId));
        w[9] = keccak256(bytes(r.uri));
        w[10] = r.schemaId;
        w[11] = keccak256("DIRECT");
        (, bytes memory bundle) = host.recordSignatureBundle(hash);
        w[12] = keccak256(
            abi.encode(uint16(1), keccak256(abi.encode(keccak256(bundle))), keccak256("RAW_BYTES"))
        );
        w[13] = bytes32(uint256(r.effectiveAt));
        require(hash == keccak256(abi.encode(w)), "independent fourteen-word generic hash");
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(host)) continue;
            ++found;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == r.recordType && logs[i].topics[3] == r.subjectId,
                "indexed fields"
            );
            require(
                logs[i].topics[0]
                    == keccak256(
                        "IndependentPreservationRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)"
                    ),
                "event identity"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(
                        abi.encode(
                            record,
                            hash,
                            receipt.recordChainHash,
                            address(this),
                            bytes32(uint256(5)),
                            uint16(1)
                        )
                    ),
                "all event data"
            );
        }
        require(found == 1, "one host event");
        vm.recordLogs();
        host.revokeIndependentAttestorNonce(26);
        logs = vm.getRecordedLogs();
        require(
            logs.length == 1 && logs[0].emitter == address(host) && logs[0].topics.length == 4,
            "revocation event count"
        );
        require(
            logs[0].topics[0]
                    == keccak256("IndependentAttestorNonceRevoked(address,uint256,address,uint16)")
                && logs[0].topics[1] == bytes32(uint256(uint160(address(this))))
                && logs[0].topics[2] == bytes32(uint256(26))
                && logs[0].topics[3] == bytes32(uint256(uint160(address(this))))
                && keccak256(logs[0].data) == keccak256(abi.encode(uint16(1))),
            "revocation exact"
        );
    }

    function testEveryNamedSignedFieldAndVerifierDriftChangesDigest() public {
        (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamCollectionAttestations.IndependentRecord memory original
        ) = _request(signer, 7);
        bytes32 digest = host.independentRecordDigest(original);
        for (uint256 i; i < 13; ++i) {
            IStreamCollectionAttestations.IndependentRecord memory r =
                abi.decode(abi.encode(original), (IStreamCollectionAttestations.IndependentRecord));
            if (i == 0) r.attestor = address(1);
            else if (i == 1) ++r.scopeKey;
            else if (i == 2) r.subjectId = bytes32(uint256(1));
            else if (i == 3) r.recordType = keccak256("INDEPENDENT_CONDITION");
            else if (i == 4) r.schemaId = keccak256("another schema");
            else if (i == 5) ++r.algorithmId;
            else if (i == 6) r.digest = hex"22";
            else if (i == 7) r.canonicalizationId = keccak256("another canonicalization");
            else if (i == 8) r.uri = "ipfs://other";
            else if (i == 9) r.payload = hex"01";
            else if (i == 10) ++r.effectiveAt;
            else if (i == 11) ++r.nonce;
            else ++r.deadline;
            bytes32 expected = keccak256(
                abi.encodePacked(hex"1901", _domain(block.chainid, address(host)), _body(r))
            );
            require(
                host.independentRecordDigest(r) == expected && expected != digest,
                "named changed field"
            );
        }
        bytes memory wrongVerifier = _sign(
            keccak256(
                abi.encodePacked(hex"1901", _domain(block.chainid, address(1)), _body(original))
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.InvalidIndependentSignature.selector, signer
            )
        );
        host.recordIndependentPreservation(subject, original, wrongVerifier);
        host.recordIndependentPreservation(subject, original, _sign(digest));
    }

    function testMissingWrongKindDefinitionsAndMalformedPayloadDoNotConsumeProof() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(this), 76);
        r.schemaId = keccak256("missing");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.IndependentDefinitionUnavailable.selector, r.schemaId
            )
        );
        host.recordIndependentPreservation(s, r, "");
        r.schemaId = keccak256("RAW_BYTES");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.IndependentDefinitionUnavailable.selector, r.schemaId
            )
        );
        host.recordIndependentPreservation(s, r, "");
        r.schemaId = schemaId;
        r.digest = abi.encode(bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionAttestations.InvalidIndependentRecord.selector)
        );
        host.recordIndependentPreservation(s, r, "");
        r.digest = abi.encode(keccak256(r.payload));
        r.canonicalizationId = schemaId;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.IndependentDefinitionUnavailable.selector, schemaId
            )
        );
        host.recordIndependentPreservation(s, r, "");
        r.canonicalizationId = keccak256("RAW_BYTES");
        require(
            !host.isIndependentAttestorNonceUsed(address(this), 76)
                && host.payloadPointerCount(1) == 0,
            "no partial write"
        );
        host.recordIndependentPreservation(s, r, "");
    }

    function testFullSignatureLengthParentGasRejectionAndGovernedCapPropagation() public {
        IndependentGasWitness wallet = new IndependentGasWitness();
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(wallet), 101);
        bytes memory sig = new bytes(4096);
        bytes32 digest = host.independentRecordDigest(r);
        wallet.set(220000, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.InvalidIndependentSignature.selector, address(wallet)
            )
        );
        host.recordIndependentPreservation(s, r, sig);
        bytes32 id = host.GGP_METADATA_ERC1271_VERIFY_GAS();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = _raiseHashes(id, 300000);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterActionClassMismatch.selector, uint8(1), uint8(2)
            )
        );
        executor.execute(
            address(host),
            abi.encodeCall(host.raiseGasParameter, (id, 300000)),
            scope,
            oldHash,
            newHash,
            2
        );
        executor.execute(
            address(host),
            abi.encodeCall(host.raiseGasParameter, (id, 300000)),
            scope,
            oldHash,
            newHash,
            1
        );
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        require(value == 300000 && floor == 90000 && failure == 2 && revision == 2, "governed row");
        (bool ok, bytes memory result) = address(host).call{ gas: 330000 }(
            abi.encodeCall(host.recordIndependentPreservation, (s, r, sig))
        );
        require(
            !ok && result.length == 68
                && bytes4(result) == IStreamCollectionAttestations.IndependentParentGas.selector,
            "exact parent precheck"
        );
        require(
            !host.isIndependentAttestorNonceUsed(address(wallet), 101), "rejected call no nonce"
        );
        host.recordIndependentPreservation(s, r, sig);
    }

    function testRetiredCanonicalizationAndIndependentDeploymentRecordsSurviveCoreLoss() public {
        bytes32 canon = _register(
            "TEST_BYTES_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes("{\"rule\":\"exact bytes\"}")
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.statusTransition(canon, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (canon, IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
            ),
            scope,
            oldHash,
            newHash,
            1
        );
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(this), 44);
        s.collectionId = 0;
        r.scopeKey = 0;
        r.subjectId = host.deriveSubject(s);
        r.canonicalizationId = canon;
        vm.etch(address(core), hex"00");
        vm.etch(address(executor), hex"00");
        host.recordIndependentPreservation(s, r, "");
        host.revokeIndependentAttestorNonce(45);
    }

    function testFuzzUnorderedNonceRevocationIsSignerScoped(uint256 nonce) public {
        host.revokeIndependentAttestorNonce(nonce);
        require(
            host.isIndependentAttestorNonceUsed(address(this), nonce)
                && !host.isIndependentAttestorNonceUsed(signer, nonce),
            "scoped void"
        );
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(signer, nonce);
        host.recordIndependentPreservation(s, r, _sign(host.independentRecordDigest(r)));
    }

    function _raiseHashes(bytes32 id, uint256 next)
        internal
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(host),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        oldHash = keccak256(abi.encode(domain, scope, value, floor, failure, revision));
        newHash = keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1));
    }
}
