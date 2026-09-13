// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/records/StreamRightsRecordJson.sol";

interface RightsJsonVm {
    function expectRevert(bytes calldata reason) external;
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

/// @notice Exact interpretation tests only; no onchain record provenance or current selection claim.
contract StreamRightsRecordJsonTest {
    RightsJsonVm private constant vm =
        RightsJsonVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _statement() private pure returns (StreamRightsRecordTypes.Statement memory s) {
        s.subjectId = bytes32(uint256(1));
        s.profileHash = bytes32(uint256(2));
        s.licensor.artistId = bytes32(uint256(3));
        s.startDate = 20260912;
        s.openEnd = true;
    }

    function testAllUnspecifiedIsAnExplicitCompleteDatedRecordAgainstIndependentJsonGolden()
        public
        view
    {
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes memory golden = vm.readFileBinary("test/fixtures/metadata/rights-unspecified-v1.json");
        require(
            StreamRightsRecordJson.requireExact(s, golden) == keccak256(golden),
            "literal independent canonical JSON"
        );
        require(
            keccak256(StreamRightsRecordJson.serialize(s)) == keccak256(golden),
            "six explicit unspecified grants, never missing record fallback"
        );
    }

    function testEveryBasisStatusLicensorAndConditionBranch() public {
        StreamRightsRecordTypes.Statement memory s = _statement();
        for (uint8 basis; basis < 6; ++basis) {
            s.basis = StreamRightsRecordTypes.Basis(basis);
            for (uint8 status; status < 4; ++status) {
                s.grants.reproduction.status = StreamRightsRecordTypes.Status(status);
                s.grants.reproduction.conditions.kind = StreamRightsRecordTypes.ConditionKind.TEXT;
                s.grants.reproduction.conditions.text = "Exact authored condition.";
                require(
                    StreamRightsRecordJson.serialize(s).length > 800,
                    "every closed vocabulary branch serializes"
                );
            }
        }
        s.licensor.artistId = 0;
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        s.licensor.account = address(0x123);
        StreamRightsRecordJson.serialize(s);
        s.licensor.account = address(0);
        s.licensor.name = "Named rights-holding entity";
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.ESTATE;
        StreamRightsRecordJson.serialize(s);
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.INSTITUTION;
        StreamRightsRecordJson.serialize(s);
        s.grants.reproduction.conditions.kind = StreamRightsRecordTypes.ConditionKind.DOCUMENT;
        s.grants.reproduction.conditions.text = "";
        s.grants.reproduction.conditions.document =
            StreamRightsRecordTypes.Document(true, "ipfs://conditions", bytes32(uint256(4)));
        s.instrument = StreamRightsRecordTypes.Document(
            true, "https://example.org/license", bytes32(uint256(5))
        );
        s.licensor.instrumentDigest = s.instrument.digest;
        s.hasAiTrainingPermission = true;
        s.aiTrainingPermission = StreamRightsRecordTypes.Status.DENIED;
        s.grants.aiTraining.status = StreamRightsRecordTypes.Status.DENIED;
        s.endDate = 20261231;
        s.openEnd = false;
        s.predecessor = bytes32(uint256(6));
        bytes memory golden = vm.readFileBinary("test/fixtures/metadata/rights-complete-v1.json");
        require(
            StreamRightsRecordJson.requireExact(s, golden) == keccak256(golden),
            "independent complete instrument and optional-field golden"
        );
    }

    function testMissingUnknownDuplicateNoncanonicalAndChangedBytesNeverMatchWitness() public {
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes memory golden = vm.readFileBinary("test/fixtures/metadata/rights-unspecified-v1.json");
        bytes[] memory invalid = new bytes[](6);
        invalid[0] = bytes("{}");
        invalid[1] = bytes.concat(golden, bytes(" "));
        invalid[2] = bytes.concat(bytes(" "), golden);
        invalid[3] = bytes('{"version":1,"version":1}');
        invalid[4] = bytes('{"extra":"ignored", "version":1}');
        invalid[5] = bytes("");
        for (uint256 i; i < invalid.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.RecordPayloadMismatch.selector));
            StreamRightsRecordJson.requireExact(s, invalid[i]);
        }
        s.grants.aiTraining.status = StreamRightsRecordTypes.Status.GRANTED;
        vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.RecordPayloadMismatch.selector));
        StreamRightsRecordJson.requireExact(s, golden);
    }

    function testConditionalGrantAndAiConsistencyRejectInsteadOfDefaulting() public {
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.grants.exhibition.status = StreamRightsRecordTypes.Status.GRANTED_WITH_CONDITIONS;
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.grants.exhibition.conditions.kind = StreamRightsRecordTypes.ConditionKind.TEXT;
        vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.InvalidJsonWitness.selector));
        StreamRightsRecordJson.serialize(s);
        s.grants.exhibition.conditions.text = "Credit the artist.";
        s.hasAiTrainingPermission = true;
        s.aiTrainingPermission = StreamRightsRecordTypes.Status.DENIED;
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.grants.aiTraining.status = StreamRightsRecordTypes.Status.DENIED;
        StreamRightsRecordJson.serialize(s);
        s.hasAiTrainingPermission = false;
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
    }

    function testInactiveBranchesAndHalfDocumentCannotBeSilentlyDiscarded() public {
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.instrument.uri = "ipfs://hidden-document";
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.instrument.uri = "";
        s.licensor.name = "hidden alternate licensor";
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.licensor.name = "";
        s.grants.print.conditions.text = "hidden condition";
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.grants.print.conditions.text = "";
        s.instrument.exists = true;
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.instrument.digest = bytes32(uint256(5));
        s.instrument.uri = "ipfs://license";
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.licensor.instrumentDigest = s.instrument.digest;
        StreamRightsRecordJson.serialize(s);
    }

    function testExactCalendarAndExplicitOrderedOrOpenEffectiveInterval() public {
        require(
            keccak256(bytes(StreamRecordJson.date(20000229))) == keccak256(bytes('"2000-02-29"')),
            "century leap year"
        );
        require(
            keccak256(bytes(StreamRecordJson.date(10101))) == keccak256(bytes('"0001-01-01"')),
            "explicit early year"
        );
        uint32[7] memory invalid =
            [uint32(19000229), 20260229, 20260431, 20260001, 20261301, 0, 100000101];
        for (uint256 i; i < invalid.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.InvalidJsonWitness.selector));
            StreamRecordJson.date(invalid[i]);
        }
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.endDate = 20260913;
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.openEnd = false;
        s.endDate = 20260911;
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
        s.endDate = s.startDate;
        StreamRightsRecordJson.serialize(s);
    }

    function testUtf8ControlNonBmpEscapesAndFullWidthDecimalStrings() public {
        string memory text =
            string(bytes.concat(bytes('"\\'), hex"080c0a0d09001f", bytes(unicode"é𝄞")));
        bytes memory expected = bytes.concat(
            bytes('"\\\"\\\\\\b\\f\\n\\r\\t\\u0000\\u001f'), bytes(unicode"é𝄞"), bytes('"')
        );
        require(
            keccak256(bytes(StreamRecordJson.quote(text, 100, false))) == keccak256(expected),
            "RFC8785 scalar string escaping without normalization"
        );
        bytes memory invalidUtf8 = hex"eda080";
        vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.InvalidJsonWitness.selector));
        StreamRecordJson.quote(string(invalidUtf8), 100, true);
        require(
            keccak256(bytes(StreamRecordJson.unsigned(type(uint256).max)))
                == keccak256(
                    bytes(
                        '"115792089237316195423570985008687907853269984665640564039457584007913129639935"'
                    )
                ),
            "complete uint256, no ECMAScript rounding"
        );
        require(
            keccak256(bytes(StreamRecordJson.unsigned(0))) == keccak256(bytes('"0"')),
            "canonical zero string"
        );
    }

    function testCompleteEncodedPayloadBoundIncludesEscapingAndOverhead() public {
        bytes memory full = new bytes(8192);
        full[8191] = 0x01;
        require(
            StreamRecordJson.requirePayload(full, full) == keccak256(full),
            "exact inclusive byte bound"
        );
        bytes memory tooLarge = new bytes(8193);
        vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.RecordPayloadMismatch.selector));
        StreamRecordJson.requirePayload(tooLarge, tooLarge);
        StreamRightsRecordTypes.Statement memory s = _statement();
        string memory control = string(new bytes(1024));
        s.grants.aiTraining.conditions = StreamRightsRecordTypes.Conditions(
            StreamRightsRecordTypes.ConditionKind.TEXT,
            control,
            StreamRightsRecordTypes.Document(false, "", 0)
        );
        s.grants.derivative.conditions = s.grants.aiTraining.conditions;
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
    }

    function testActualSerializedRecordAccepts8192AndRejects8193Bytes() public {
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.grants.aiTraining.conditions.kind = StreamRightsRecordTypes.ConditionKind.TEXT;
        s.grants.aiTraining.conditions.text = string(new bytes(1024)); // Canonically escapes to6144 bytes.
        s.grants.derivative.extension = _ascii(512);
        uint256 missing = 8192 - StreamRightsRecordJson.serialize(s).length;
        if (missing > 512) {
            s.grants.exhibition.extension = _ascii(512);
            missing -= 512;
        }
        require(missing < 512, "remaining field has room for the8193 negative");
        s.grants.print.extension = _ascii(missing);
        bytes memory complete = StreamRightsRecordJson.serialize(s);
        require(complete.length == 8192, "full actual JSON byte boundary including escapes");
        require(
            StreamRightsRecordJson.requireExact(s, complete) == keccak256(complete),
            "complete typed record accepted"
        );
        s.grants.print.extension = _ascii(missing + 1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamRightsRecordJson.InvalidRightsWitness.selector)
        );
        StreamRightsRecordJson.serialize(s);
    }

    function _ascii(uint256 length) private pure returns (string memory) {
        bytes memory value = new bytes(length);
        for (uint256 i; i < length; ++i) {
            value[i] = 0x61;
        }
        return string(value);
    }

    function testFuzzAnyChangedRecordedByteRejects(bytes32 entropy, uint16 position) public {
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.predecessor = entropy;
        bytes memory body = StreamRightsRecordJson.serialize(s);
        uint256 index = position % body.length;
        body[index] = bytes1(uint8(body[index]) ^ 1);
        vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.RecordPayloadMismatch.selector));
        StreamRightsRecordJson.requireExact(s, body);
    }
}
