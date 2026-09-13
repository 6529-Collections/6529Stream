// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/records/StreamStewardDesignationJson.sol";
import "../../../smart-contracts/domains/records/StreamRecoveryResponseJson.sol";
import "../../../smart-contracts/domains/records/StreamOwnerNoticeDefinitions.sol";

interface OwnerNoticeVm {
    function expectRevert() external;
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

/// @notice Pure meaning and byte parity only; no registered state or owner/independent admission.
contract StreamOwnerNoticeJsonTest {
    OwnerNoticeVm private constant vm =
        OwnerNoticeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant RAW = keccak256("RAW_BYTES");

    function _ref(uint16 algorithm) private pure returns (StreamOwnerNoticeTypes.Reference memory) {
        return StreamOwnerNoticeTypes.Reference(
            algorithm, RAW, abi.encode(bytes32(uint256(3))), "ipfs://identity-document"
        );
    }

    function _d() private pure returns (StreamOwnerNoticeTypes.Designation memory d) {
        d.subjectId = bytes32(uint256(1));
        d.profileHash = StreamOwnerNoticeDefinitions.STEWARD_PROFILE_HASH;
        d.name = "Explicit institution";
        d.identity = _ref(2);
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](3);
        d.contactEndpoints[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS,
            "https://institution.example/notice",
            0,
            address(0)
        );
        d.contactEndpoints[1] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.MAILTO,
            "mailto:registrar+stream@example.org",
            0,
            address(0)
        );
        d.contactEndpoints[2] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.EIP155,
            "",
            type(uint256).max,
            address(0xABaBaBaBABabABabAbAbABAbABabababaBaBABaB)
        );
    }

    function _r() private pure returns (StreamOwnerNoticeTypes.Response memory r) {
        r.subjectId = bytes32(uint256(1));
        r.profileHash = StreamOwnerNoticeDefinitions.RESPONSE_PROFILE_HASH;
        r.recoveryId = bytes32(uint256(4));
        r.recoveryManifestHash = bytes32(uint256(5));
        r.grounds = "Owner or independent authored statement; carrier determines attribution.";
    }

    function _golden(string memory name) private view returns (bytes memory) {
        return
            vm.readFileBinary(
                string.concat("schemas/records/examples/owner-notice/", name, ".json")
            );
    }

    function _equal(bytes memory a, bytes memory b) private pure {
        require(a.length == b.length && keccak256(a) == keccak256(b), "exact bytes");
    }

    function testInstitutionGoldenAllEndpointsAndFullChainWidth() external view {
        _equal(StreamStewardDesignationJson.serialize(_d()), _golden("steward-institution"));
    }

    function testRegistrarGoldenPredecessorOpaqueCIDAndExactUnicode() external view {
        StreamOwnerNoticeTypes.Designation memory d = _d();
        d.predecessor = bytes32(uint256(9));
        d.kind = StreamOwnerNoticeTypes.StewardKind.REGISTRAR_CONTACT;
        d.name = unicode'Exact " \\ /\r\n\x01 🎨 é';
        d.identity.algorithm = 5;
        d.identity.digest = hex"00ff7f";
        _equal(StreamStewardDesignationJson.serialize(d), _golden("steward-registrar"));
    }

    function testAcknowledgedGoldenExplicitEmptyEvidence() external view {
        _equal(StreamRecoveryResponseJson.serialize(_r()), _golden("recovery-acknowledged"));
    }

    function testObjectedGoldenAllSixAlgorithmsAndOpaqueExtremes() external view {
        StreamOwnerNoticeTypes.Response memory r = _r();
        r.response = StreamOwnerNoticeTypes.ResponseClass.OBJECTED;
        r.grounds = unicode'Exact grounds " \\ /\r\n\x01 🎨 é';
        r.evidenceReferences = new StreamOwnerNoticeTypes.Reference[](6);
        for (uint16 i; i < 6; ++i) {
            r.evidenceReferences[i] = _ref(i + 1);
        }
        r.evidenceReferences[3].digest = new bytes(128);
        for (uint256 i = 1; i < 128; i += 2) {
            r.evidenceReferences[3].digest[i] = 0xff;
        }
        r.evidenceReferences[4].digest = hex"00";
        _equal(StreamRecoveryResponseJson.serialize(r), _golden("recovery-objected"));
    }

    function testLiteralHashShapesRejectUnknownAndWrongLengthThenRetry() external {
        for (uint16 a = 1; a <= 6; ++a) {
            this.checkHashShape(a);
        }
        StreamOwnerNoticeTypes.Reference memory r = _ref(7);
        vm.expectRevert();
        StreamOwnerNoticeFields.referenceJSON(r);
        r.algorithm = 0;
        vm.expectRevert();
        StreamOwnerNoticeFields.referenceJSON(r);
        r.algorithm = 2;
        r.canonicalizationId = 0;
        vm.expectRevert();
        StreamOwnerNoticeFields.referenceJSON(r);
    }

    function checkHashShape(uint16 a) external {
        StreamOwnerNoticeTypes.Reference memory r = _ref(a);
        r.digest = new bytes((a == 4 || a == 5) ? 128 : 32);
        StreamOwnerNoticeFields.referenceJSON(r);
        r.digest = new bytes((a == 4 || a == 5) ? 129 : 31);
        vm.expectRevert();
        StreamOwnerNoticeFields.referenceJSON(r);
        r.digest = new bytes((a == 4 || a == 5) ? 1 : 32);
        StreamOwnerNoticeFields.referenceJSON(r);
    }

    function testInactiveContactFieldsRejectEveryVariantAndRetry() external {
        StreamOwnerNoticeTypes.Designation memory d = _d();
        d.contactEndpoints[0].chainId = 1;
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d.contactEndpoints[0].chainId = 0;
        d.contactEndpoints[0].account = address(1);
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d.contactEndpoints[0].account = address(0);
        d.contactEndpoints[1].chainId = 1;
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d.contactEndpoints[1].chainId = 0;
        d.contactEndpoints[1].account = address(1);
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d.contactEndpoints[1].account = address(0);
        d.contactEndpoints[2].uri = "https://example.org";
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d.contactEndpoints[2].uri = "";
        StreamStewardDesignationJson.serialize(d);
    }

    function testCanonicalContactTupleEqualityNoRecipientInference() external {
        StreamOwnerNoticeTypes.Designation memory d = _d();
        d.contactEndpoints[1] = d.contactEndpoints[0];
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](2);
        d.contactEndpoints[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.MAILTO, "mailto:A@example.org", 0, address(0)
        );
        d.contactEndpoints[1] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.MAILTO, "mailto:a@example.org", 0, address(0)
        );
        StreamStewardDesignationJson.serialize(d);
    }

    function testTwelveContactsAndTwelveEvidenceEntriesAreSupported() external pure {
        StreamOwnerNoticeTypes.Designation memory d = _d();
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](12);
        for (uint256 i; i < 12; ++i) {
            d.contactEndpoints[i] = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.EIP155, "", i + 1, address(1)
            );
        }
        require(StreamStewardDesignationJson.serialize(d).length < 8192);
        StreamOwnerNoticeTypes.Response memory r = _r();
        r.evidenceReferences = new StreamOwnerNoticeTypes.Reference[](12);
        for (uint256 i; i < 12; ++i) {
            r.evidenceReferences[i] = _ref(2);
        }
        require(StreamRecoveryResponseJson.serialize(r).length < 8192);
    }

    function testMailboxNegativeControlsFullInputAndHealthyRetry() external {
        string[8] memory bad = [
            "mailto:.a@example.org",
            "mailto:a..b@example.org",
            "mailto:a.@example.org",
            "mailto:a@-example.org",
            "mailto:a@example-.org",
            "mailto:a@example..org",
            "mailto:a@example.org\n",
            "mailto:a@example.org?subject=x"
        ];
        for (uint256 i; i < bad.length; ++i) {
            StreamOwnerNoticeTypes.Contact memory c = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.MAILTO, bad[i], 0, address(0)
            );
            vm.expectRevert();
            StreamOwnerNoticeFields.contact(c);
            c.uri = "mailto:A.a+stream_name-x@a-b.example";
            StreamOwnerNoticeFields.contact(c);
        }
    }

    function testEmptyAndZeroRequiredFieldsReject() external {
        StreamOwnerNoticeTypes.Designation memory d = _d();
        d.name = "";
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d = _d();
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](0);
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d = _d();
        d.subjectId = 0;
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d = _d();
        d.profileHash = 0;
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        StreamOwnerNoticeTypes.Response memory r = _r();
        r.recoveryId = 0;
        vm.expectRevert();
        StreamRecoveryResponseJson.serialize(r);
        r = _r();
        r.recoveryManifestHash = 0;
        vm.expectRevert();
        StreamRecoveryResponseJson.serialize(r);
        r = _r();
        r.grounds = "";
        vm.expectRevert();
        StreamRecoveryResponseJson.serialize(r);
    }

    function testInvalidUtf8AndDecodedByteBoundsReject() external {
        StreamOwnerNoticeTypes.Designation memory d = _d();
        bytes memory invalid = hex"eda080";
        d.name = string(invalid);
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d.name = new string(513);
        vm.expectRevert();
        StreamStewardDesignationJson.serialize(d);
        d.name = unicode"é";
        bytes memory a = StreamStewardDesignationJson.serialize(d);
        d.name = unicode"é";
        bytes memory b = StreamStewardDesignationJson.serialize(d);
        require(keccak256(a) != keccak256(b));
    }

    function testCompletePayload8192Accepts8193Rejects() external {
        StreamOwnerNoticeTypes.Response memory r = _r();
        r.grounds = string(_fill(2048, "g"));
        r.evidenceReferences = new StreamOwnerNoticeTypes.Reference[](3);
        for (uint256 i; i < 3; ++i) {
            r.evidenceReferences[i] = _ref(2);
            r.evidenceReferences[i].uri = "https://x";
        }
        for (uint256 i; i < 3; ++i) {
            uint256 remain = 8192 - StreamRecoveryResponseJson.serialize(r).length;
            uint256 available = 2048 - bytes(r.evidenceReferences[i].uri).length;
            r.evidenceReferences[i].uri = string.concat(
                r.evidenceReferences[i].uri,
                string(_fill(remain < available ? remain : available, "x"))
            );
        }
        bytes memory raw = StreamRecoveryResponseJson.serialize(r);
        require(raw.length == 8192);
        require(StreamRecoveryResponseJson.requireExact(r, raw) == keccak256(raw));
        r.evidenceReferences[2].uri = string.concat(r.evidenceReferences[2].uri, "x");
        vm.expectRevert();
        StreamRecoveryResponseJson.serialize(r);
    }

    function testExactPayloadRejectsExtraFieldMutationAndTruncation() external {
        StreamOwnerNoticeTypes.Response memory r = _r();
        bytes memory raw = StreamRecoveryResponseJson.serialize(r);
        vm.expectRevert();
        StreamRecoveryResponseJson.requireExact(r, bytes.concat(raw, bytes(" ")));
        raw[0] = "[";
        vm.expectRevert();
        StreamRecoveryResponseJson.requireExact(r, raw);
        StreamOwnerNoticeTypes.Designation memory d = _d();
        raw = StreamStewardDesignationJson.serialize(d);
        require(StreamStewardDesignationJson.requireExact(d, raw) == keccak256(raw));
        d.predecessor = bytes32(uint256(9));
        vm.expectRevert();
        StreamStewardDesignationJson.requireExact(d, raw);
    }

    function responseBytes(StreamOwnerNoticeTypes.Response calldata r)
        external
        pure
        returns (bytes memory)
    {
        return StreamRecoveryResponseJson.serialize(r);
    }

    function contactBytes(StreamOwnerNoticeTypes.Contact calldata c)
        external
        pure
        returns (string memory)
    {
        return StreamOwnerNoticeFields.contact(c);
    }

    function testInvalidResponseAndContactEnumsRejectAtActualABI() external {
        bytes memory data = abi.encodeCall(this.responseBytes, (_r()));
        // Dynamic tuple begins at byte36; response is its fifth static word.
        assembly { mstore(add(data, 196), 2) }
        (bool ok,) = address(this).call(data);
        require(!ok, "unknown response admitted");
        _equal(this.responseBytes(_r()), StreamRecoveryResponseJson.serialize(_r()));
        StreamOwnerNoticeTypes.Designation memory d = _d();
        data = abi.encodeCall(this.contactBytes, (d.contactEndpoints[0]));
        assembly { mstore(add(data, 68), 3) }
        (ok,) = address(this).call(data);
        require(!ok, "unknown contact admitted");
        this.contactBytes(d.contactEndpoints[0]);
    }

    function testLiteralDefinitionIdsAndCompleteDocumentHashes() external view {
        require(
            StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_ID
                == keccak256("STREAM_STEWARD_DESIGNATION_V1")
        );
        require(
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID
                == keccak256("STREAM_RECOVERY_RESPONSE_V1")
        );
        require(
            StreamOwnerNoticeDefinitions.STEWARD_PROFILE_ID
                == keccak256("STREAM_STEWARD_DESIGNATION_JSON_PROFILE_V1")
        );
        require(
            StreamOwnerNoticeDefinitions.RESPONSE_PROFILE_ID
                == keccak256("STREAM_RECOVERY_RESPONSE_JSON_PROFILE_V1")
        );
        bytes memory raw = vm.readFileBinary("schemas/records/STREAM_STEWARD_DESIGNATION_V1.json");
        require(
            raw.length == StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_BYTES
                && keccak256(raw) == StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_HASH
        );
        raw = vm.readFileBinary("schemas/records/STREAM_RECOVERY_RESPONSE_V1.json");
        require(
            raw.length == StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_BYTES
                && keccak256(raw) == StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_HASH
        );
        raw = vm.readFileBinary("schemas/records/STREAM_STEWARD_DESIGNATION_JSON_PROFILE_V1.json");
        require(
            raw.length == StreamOwnerNoticeDefinitions.STEWARD_PROFILE_BYTES
                && keccak256(raw) == StreamOwnerNoticeDefinitions.STEWARD_PROFILE_HASH
        );
        raw = vm.readFileBinary("schemas/records/STREAM_RECOVERY_RESPONSE_JSON_PROFILE_V1.json");
        require(
            raw.length == StreamOwnerNoticeDefinitions.RESPONSE_PROFILE_BYTES
                && keccak256(raw) == StreamOwnerNoticeDefinitions.RESPONSE_PROFILE_HASH
        );
    }

    function _fill(uint256 length, bytes1 value) private pure returns (bytes memory out) {
        out = new bytes(length);
        for (uint256 i; i < length; ++i) {
            out[i] = value;
        }
    }
}
