// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerRecords.t.sol";

/// @notice Real owner/schema/store/threshold Safe; custody and governance are explicit boundaries.
contract StreamOwnerStewardRecordsTest is CollectionMetadataV1Fixture {
    StreamOwnerRecords private dossier;
    bytes32 private constant STEWARD = keccak256("STEWARD_DESIGNATION");

    function _text(uint256 length, bytes1 letter) private pure returns (string memory) {
        bytes memory out = new bytes(length);
        for (uint256 i; i < length; ++i) {
            out[i] = letter;
        }
        return string(out);
    }

    function _url(uint256 length, bytes1 letter) private pure returns (string memory) {
        return string.concat("https://museum.example/", _text(length - 23, letter));
    }

    function testActualThresholdSafeBothTypedWritesAndEveryNewRead() public {
        SafeComponents memory components = deploySafeComponents("1.4.1");
        uint256[] memory keys = new uint256[](2);
        keys[0] = 743;
        keys[1] = 927;
        OfficialSafe account = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 702);
        _prepare(address(account), false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        require(
            executeSafe(
                account,
                keys,
                address(dossier),
                0,
                abi.encodeCall(dossier.recordStewardDesignation, (7, r, d)),
                0
            ),
            "actual Safe typed direct"
        );
        d = _designation(dossier.stewardDesignationFor(7, address(account)));
        r = _recordFor(d);
        bytes32 digest = dossier.ownerRecordDigest(7, r, address(account), 63, 2000);
        dossier.recordStewardDesignationFor(
            7,
            r,
            address(account),
            63,
            2000,
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest))),
            d
        );
        require(
            executeSafe(
                account,
                keys,
                address(dossier),
                0,
                abi.encodeCall(dossier.stewardDesignationFor, (7, address(account))),
                0
            ),
            "Safe attributed read"
        );
        require(
            executeSafe(
                account,
                keys,
                address(dossier),
                0,
                abi.encodeCall(dossier.currentStewardDesignation, (7)),
                0
            ),
            "Safe current recipient read"
        );
        (, IStreamOwnerRecords.Receipt memory receipt) =
            dossier.ownerRecord(dossier.stewardDesignationFor(7, address(account)));
        require(
            receipt.owner == address(account) && receipt.relayed
                && receipt.signatureScheme == keccak256("ERC1271"),
            "original actual Safe signature authority"
        );
    }

    function testColdExact8192Payload2048RecordURIAndLargeEndpoints() public {
        _prepare(address(this), false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        d.name = _text(512, 0x61);
        d.identity.uri = _url(2048, 0x61);
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](4);
        for (uint256 i; i < 4; ++i) {
            d.contactEndpoints[i] = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.HTTPS,
                _url(1024, bytes1(uint8(98 + i))),
                0,
                address(0)
            );
        }
        uint256 initialLength = StreamStewardDesignationJson.serialize(d).length;
        require(
            initialLength < 8192 && 1024 + 8192 - initialLength <= 2048,
            "maximum payload construction"
        );
        d.contactEndpoints[3].uri = _url(1024 + 8192 - initialLength, 0x65);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        require(r.payload.length == 8192, "exact maximum typed JSON");
        r.uri = _url(2048, 0x66);
        safeVm.cool(address(core));
        safeVm.cool(address(schemas));
        safeVm.cool(address(store));
        safeVm.cool(address(dossier));
        dossier.recordStewardDesignation(7, r, d);
        (IStreamOwnerRecords.OwnerRecord memory saved,) =
            dossier.ownerRecord(dossier.stewardDesignationFor(7, address(this)));
        require(
            saved.payload.length == 8192 && bytes(saved.uri).length == 2048
                && keccak256(saved.payload) == keccak256(r.payload),
            "full maximum original owner bytes"
        );
        require(address(dossier).code.length <= 24576, "owner production runtime fits EIP170");
    }

    function testAllSixOuterHashAlgorithmsRetainAuthenticatedTypedPayload() public {
        _prepare(address(this), false);
        bytes32 previous;
        for (uint16 algorithm = 1; algorithm <= 6; ++algorithm) {
            StreamOwnerNoticeTypes.Designation memory d = _designation(previous);
            d.identity.algorithm = algorithm;
            if (algorithm == 4 || algorithm == 5) d.identity.digest = hex"010203";
            IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
            r.contentHash.algorithm = algorithm;
            if (algorithm == 2) r.contentHash.digest = abi.encode(sha256(r.payload));
            if (algorithm == 4 || algorithm == 5) r.contentHash.digest = hex"1234";
            dossier.recordStewardDesignation(7, r, d);
            previous = dossier.stewardDesignationFor(7, address(this));
            (IStreamOwnerRecords.OwnerRecord memory saved,) = dossier.ownerRecord(previous);
            require(
                saved.contentHash.algorithm == algorithm
                    && keccak256(saved.payload) == keccak256(r.payload),
                "all opaque references retain actual signed bytes"
            );
        }
    }

    function testSignedPayloadMutationAfterValidInterpretationRollsBackAndRetries() public {
        uint256 key = 8173;
        address owner = vm.addr(key);
        _prepare(owner, false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        bytes memory signature = _sign(key, r, 27);
        d.name = "Different valid institution";
        IStreamOwnerRecords.OwnerRecord memory changed = _recordFor(d);
        (bool ok,) = address(dossier)
            .call(
                abi.encodeCall(
                    dossier.recordStewardDesignationFor, (7, changed, owner, 27, 2000, signature, d)
                )
            );
        require(
            !ok && !dossier.isOwnerRecordNonceUsed(owner, 27)
                && dossier.stewardDesignationFor(7, owner) == 0,
            "valid interpretation cannot replace signed meaning"
        );
        d = _designation(0);
        dossier.recordStewardDesignationFor(7, r, owner, 27, 2000, signature, d);
        require(dossier.isOwnerRecordNonceUsed(owner, 27), "original signature exact retry");
    }

    function _prepare(address owner, bool badProfile) private {
        _register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        _register(
            "STREAM_STEWARD_DESIGNATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_STEWARD_DESIGNATION_V1.json"))
        );
        _register(
            "STREAM_STEWARD_DESIGNATION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            badProfile
                ? bytes("wrong definition")
                : bytes(
                    vm.readFile("schemas/records/STREAM_STEWARD_DESIGNATION_JSON_PROFILE_V1.json")
                )
        );
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

    function _designation(bytes32 predecessor)
        private
        view
        returns (StreamOwnerNoticeTypes.Designation memory d)
    {
        d.subjectId = dossier.deriveOwnerSubject(7);
        d.profileHash = StreamOwnerNoticeDefinitions.STEWARD_PROFILE_HASH;
        d.predecessor = predecessor;
        d.kind = StreamOwnerNoticeTypes.StewardKind.INSTITUTION;
        d.name = "Museum registrar";
        d.identity = StreamOwnerNoticeTypes.Reference(
            2,
            keccak256("RAW_BYTES"),
            abi.encode(bytes32(uint256(123))),
            "https://museum.example/identity"
        );
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](1);
        d.contactEndpoints[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.MAILTO,
            "mailto:registrar@museum.example",
            0,
            address(0)
        );
    }

    function _recordFor(StreamOwnerNoticeTypes.Designation memory d)
        private
        pure
        returns (IStreamOwnerRecords.OwnerRecord memory r)
    {
        r.recordType = STEWARD;
        r.subjectId = d.subjectId;
        r.schemaId = StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_ID;
        r.payload = StreamStewardDesignationJson.serialize(d);
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(r.payload)), StreamWorkRecordDefinitions.CANON_ID
        );
        r.uri = "ipfs://steward";
        r.effectiveAt = 1;
    }

    function _sign(uint256 key, IStreamOwnerRecords.OwnerRecord memory r, uint256 nonce)
        private
        returns (bytes memory)
    {
        bytes32 digest = dossier.ownerRecordDigest(7, r, vm.addr(key), nonce, 2000);
        (uint8 v, bytes32 a, bytes32 b) = vm.sign(key, digest);
        return abi.encodePacked(a, b, v);
    }

    function testTypedDesignationUsesOriginalReceiptLaneAndExactExtraEvent() public {
        _prepare(address(this), false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        vm.recordLogs();
        dossier.recordStewardDesignation(7, r, d);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 hash = dossier.recordHashAt(7, STEWARD, 0);
        (IStreamOwnerRecords.OwnerRecord memory saved, IStreamOwnerRecords.Receipt memory receipt) =
            dossier.ownerRecord(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r)), "original retained record"
        );
        require(
            receipt.owner == address(this) && !receipt.relayed && receipt.recordIndex == 0,
            "original direct receipt"
        );
        require(
            dossier.stewardDesignationFor(7, address(this)) == hash, "index exact original hash"
        );
        (address owner, bytes32 current) = dossier.currentStewardDesignation(7);
        require(owner == address(this) && current == hash, "actual custody recipient");
        Vm.Log memory last = logs[logs.length - 1];
        require(
            last.emitter == address(dossier) && last.topics.length == 4
                && last.topics[0]
                    == keccak256("OwnerStewardDesignated(uint256,address,bytes32,bytes32,uint16)")
                && last.topics[1] == bytes32(uint256(7))
                && last.topics[2] == bytes32(uint256(uint160(address(this))))
                && last.topics[3] == hash
                && keccak256(last.data) == keccak256(abi.encode(bytes32(0), uint16(1))),
            "exact designation event"
        );
        require(
            dossier.supportsInterface(type(IStreamOwnerStewardRecords).interfaceId)
                && dossier.supportsInterface(type(IStreamOwnerRecords).interfaceId)
                && dossier.supportsInterface(0x20279cd8) && !dossier.supportsInterface(0xffffffff),
            "additive truthful capabilities"
        );
    }

    function testGenericPathsCannotBypassTypedIndexIncludingEmptyAlternateCanonicalization()
        public
    {
        uint256 key = 9281;
        address owner = vm.addr(key);
        _prepare(owner, false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        bytes memory signature = _sign(key, r, 19);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerStewardRecords.TypedOwnerRecordRequired.selector)
        );
        dossier.recordOwnerRecordFor(7, r, owner, 19, 2000, signature);
        r.payload = "";
        r.contentHash.canonicalizationId = keccak256("RAW_BYTES");
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerStewardRecords.TypedOwnerRecordRequired.selector)
        );
        dossier.recordOwnerRecord(7, r);
        require(!dossier.isOwnerRecordNonceUsed(owner, 19), "generic rejection preserves nonce");
        (, uint64 count) = dossier.recordChainHash(7, STEWARD);
        require(
            count == 0 && dossier.stewardDesignationFor(7, owner) == 0,
            "no hidden record/index mutation"
        );
        r = _recordFor(d);
        dossier.recordStewardDesignationFor(7, r, owner, 19, 2000, signature, d);
        require(
            dossier.isOwnerRecordNonceUsed(owner, 19),
            "identical signed record retry via typed path"
        );
    }

    function testOriginalOwnerSignatureBindsCompleteTypedBytesAndAllowsUnorderedNonces() public {
        uint256 key = 2847;
        address owner = vm.addr(key);
        _prepare(owner, false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        bytes memory signature = _sign(key, r, 901);
        dossier.recordStewardDesignationFor(7, r, owner, 901, 2000, signature, d);
        bytes32 first = dossier.stewardDesignationFor(7, owner);
        (, IStreamOwnerRecords.Receipt memory receipt) = dossier.ownerRecord(first);
        require(
            receipt.relayed
                && receipt.authorizationDigest == dossier.ownerRecordDigest(7, r, owner, 901, 2000),
            "original digest and relay provenance"
        );
        d = _designation(first);
        d.name = "Replacement registrar";
        r = _recordFor(d);
        signature = _sign(key, r, 2);
        dossier.recordStewardDesignationFor(7, r, owner, 2, 2000, signature, d);
        require(
            dossier.isOwnerRecordNonceUsed(owner, 901) && dossier.isOwnerRecordNonceUsed(owner, 2),
            "unordered signer-scoped nonce"
        );
    }

    function testPerAuthorSupersessionRemainsDistinctFromAllAuthorRecordLane() public {
        _prepare(address(this), false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        dossier.recordStewardDesignation(7, _recordFor(d), d);
        bytes32 first = dossier.stewardDesignationFor(7, address(this));
        core.setToken(7, address(0xbeef), 2);
        d.name = "Second owner registrar";
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        vm.prank(address(0xbeef));
        dossier.recordStewardDesignation(7, r, d);
        core.setToken(7, address(this), 2);
        (address current, bytes32 selected) = dossier.currentStewardDesignation(7);
        require(
            current == address(this) && selected == first,
            "durable author designation reactivates on reacquisition"
        );
        d = _designation(first);
        r = _recordFor(d);
        dossier.recordStewardDesignation(7, r, d);
        (, IStreamOwnerRecords.Receipt memory receipt) =
            dossier.ownerRecord(dossier.recordHashAt(7, STEWARD, 2));
        require(receipt.recordIndex == 2, "global lane includes other owner");
        require(
            dossier.stewardDesignationFor(7, address(0xbeef)) != 0,
            "other author's permanent statement"
        );
    }

    function testStalePredecessorCannotOverwriteAndFailureLeavesNoAppend() public {
        _prepare(address(this), false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        dossier.recordStewardDesignation(7, _recordFor(d), d);
        bytes32 first = dossier.stewardDesignationFor(7, address(this));
        d.name = "New name";
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOwnerStewardRecords.StewardPredecessorChanged.selector, first, bytes32(0)
            )
        );
        dossier.recordStewardDesignation(7, r, d);
        (, uint64 count) = dossier.recordChainHash(7, STEWARD);
        require(
            count == 1 && dossier.stewardDesignationFor(7, address(this)) == first,
            "atomic stale rejection"
        );
    }

    function testWrongRegisteredProfileRejectedEvenWhenWitnessNamesExpectedHash() public {
        _prepare(address(this), true);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOwnerStewardRecords.OwnerNoticeDefinitionUnavailable.selector,
                StreamOwnerNoticeDefinitions.STEWARD_PROFILE_ID
            )
        );
        dossier.recordStewardDesignation(7, r, d);
        require(
            dossier.stewardDesignationFor(7, address(this)) == 0,
            "no self-asserted profile authority"
        );
    }

    function testWrongProfileSubjectAndPayloadCannotBecomeTypedMeaning() public {
        _prepare(address(this), false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        d.profileHash = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerStewardRecords.InvalidOwnerNoticeRecord.selector)
        );
        dossier.recordStewardDesignation(7, r, d);
        d = _designation(0);
        d.subjectId = bytes32(uint256(2));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamOwnerStewardRecords.InvalidOwnerNoticeRecord.selector)
        );
        dossier.recordStewardDesignation(7, r, d);
        d = _designation(0);
        r.payload = bytes.concat(r.payload, bytes(" "));
        r.contentHash.digest = abi.encode(keccak256(r.payload));
        (bool ok,) =
            address(dossier).call(abi.encodeCall(dossier.recordStewardDesignation, (7, r, d)));
        require(
            !ok && dossier.stewardDesignationFor(7, address(this)) == 0,
            "exact serialized bytes required"
        );
    }

    function testDesignationGivesContactNoOwnerWriteAuthorityAndBurnPreservesHistory() public {
        _prepare(address(this), false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        d.contactEndpoints[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.EIP155, "", block.chainid, address(0xbeef)
        );
        dossier.recordStewardDesignation(7, _recordFor(d), d);
        bytes32 hash = dossier.stewardDesignationFor(7, address(this));
        d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        vm.prank(address(0xbeef));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOwnerRecords.OwnerRecordAuthorityRequired.selector, address(0xbeef)
            )
        );
        dossier.recordStewardDesignation(7, r, d);
        core.setToken(7, address(0), 3);
        require(
            dossier.stewardDesignationFor(7, address(this)) == hash,
            "burn keeps attributed designation"
        );
        (, IStreamOwnerRecords.Receipt memory receipt) = dossier.ownerRecord(hash);
        require(receipt.owner == address(this), "burn preserves authenticated statement");
        (bool ok,) =
            address(dossier).staticcall(abi.encodeCall(dossier.currentStewardDesignation, (7)));
        require(!ok, "burn has no fabricated current owner");
    }

    function testRetiredDefinitionsAndRemovedMetadataPointerCannotLockOwnerDesignation() public {
        _prepare(address(this), false);
        bytes32[3] memory ids = [
            StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_ID,
            StreamOwnerNoticeDefinitions.STEWARD_PROFILE_ID,
            StreamWorkRecordDefinitions.CANON_ID
        ];
        for (uint256 i; i < 3; ++i) {
            (bytes32 s, bytes32 o, bytes32 n) =
                schemas.statusTransition(ids[i], IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
            executor.execute(
                address(schemas),
                abi.encodeCall(
                    schemas.setDocumentStatus,
                    (ids[i], IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
                ),
                s,
                o,
                n
            );
        }
        core.setPointer(keccak256("COLLECTION_METADATA"), address(0));
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        dossier.recordStewardDesignation(7, _recordFor(d), d);
        require(
            dossier.stewardDesignationFor(7, address(this)) != 0,
            "owner firewall preserves retired interpretation"
        );
    }

    function testChangedDefinitionChunkRollsBackThenExactRetrySucceeds() public {
        _prepare(address(this), false);
        StreamOwnerNoticeTypes.Designation memory d = _designation(0);
        IStreamOwnerRecords.OwnerRecord memory r = _recordFor(d);
        (address pointer,) = store.chunk(StreamOwnerNoticeDefinitions.STEWARD_PROFILE_HASH);
        bytes memory originalCode = pointer.code;
        vm.etch(pointer, hex"00");
        (bool ok,) =
            address(dossier).call(abi.encodeCall(dossier.recordStewardDesignation, (7, r, d)));
        require(
            !ok && dossier.stewardDesignationFor(7, address(this)) == 0,
            "changed actual bytes fail atomically"
        );
        vm.etch(pointer, originalCode);
        dossier.recordStewardDesignation(7, r, d);
        require(dossier.stewardDesignationFor(7, address(this)) != 0, "exact record retry");
    }
}
