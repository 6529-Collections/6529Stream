// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/records/StreamMasterWaiverJson.sol";
import "../../../smart-contracts/domains/records/StreamMediaMasterDefinitions.sol";

contract StreamMasterWaiverJsonTest is CharacterizationTestBase {
    function testExactMasterAssociationHasNoInventedArtistSignature() public view {
        StreamMediaMasterTypes.Master memory m;
        m.subjectId = bytes32(uint256(1)); m.selectedMediaManifestHash = bytes32(uint256(2));
        m.mediaSlot = 1; m.displayHash = bytes32(uint256(3));
        m.masterObjectHash = bytes32(uint256(4)); m.coverageHash = bytes32(uint256(5));
        StreamRecordJson.requirePayload(StreamMasterWaiverJson.master(m),
            bytes(vm.readFile("schemas/records/examples/genesis-preservation/media-master-association.json")));
    }

    function testExistingSchemaExampleIsExactOriginalPayload() public view {
        StreamMediaMasterTypes.Waiver memory w;
        w.subjectId = bytes32(uint256(1)); w.scopeSubjectId = w.subjectId;
        w.artist = StreamMediaMasterTypes.Artist(bytes32(uint256(2)), 7, bytes32(uint256(3)));
        w.reason = "Artist-authored fixture waiver; carrier signature authority is checked separately.";
        w.mediaObjects = new StreamMediaMasterTypes.WaivedObject[](2);
        w.mediaObjects[0].objectId = bytes32(uint256(4));
        w.mediaObjects[0].mediaClass = StreamMediaMasterTypes.MediaClass.VIDEO;
        w.mediaObjects[0].masterRoles = new StreamMediaMasterTypes.Role[](1);
        w.mediaObjects[1].objectId = bytes32(uint256(5));
        w.mediaObjects[1].masterRoles = new StreamMediaMasterTypes.Role[](2);
        w.mediaObjects[1].masterRoles[1] = StreamMediaMasterTypes.Role.PRINT_MASTER;
        w.waiverStatement.algorithm = 1;
        w.waiverStatement.canonicalizationId = 0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f;
        w.waiverStatement.digest = abi.encodePacked(bytes32(uint256(6)));
        w.waiverStatement.uri = "ipfs://artist-master-waiver";
        bytes memory fixture = bytes(vm.readFile("schemas/records/examples/genesis-preservation/master-waiver.json"));
        // The checked-in example ends with LF; the canonical JSON payload excludes it.
        if (fixture.length > 0 && fixture[fixture.length - 1] == 0x0a) {
            assembly ("memory-safe") { mstore(fixture, sub(mload(fixture), 1)) }
        }
        StreamRecordJson.requirePayload(StreamMasterWaiverJson.waiver(w), fixture);
    }

    function testDefinitionsMatchExactProspectiveFiles() public view {
        bytes memory schema = bytes(vm.readFile("schemas/records/STREAM_MEDIA_MASTER_ASSOCIATION_V1.json"));
        bytes memory waiver = bytes(vm.readFile("schemas/records/STREAM_MASTER_WAIVER_V1.json"));
        bytes memory profile = bytes(vm.readFile("schemas/records/STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1.json"));
        require(keccak256(schema) == StreamMediaMasterDefinitions.MASTER_SCHEMA_HASH
            && schema.length == StreamMediaMasterDefinitions.MASTER_SCHEMA_BYTES, "exact master definition");
        require(keccak256(waiver) == StreamMediaMasterDefinitions.WAIVER_SCHEMA_HASH
            && waiver.length == StreamMediaMasterDefinitions.WAIVER_SCHEMA_BYTES, "existing waiver schema unchanged");
        require(keccak256(profile) == StreamMediaMasterDefinitions.PROFILE_HASH
            && profile.length == StreamMediaMasterDefinitions.PROFILE_BYTES, "exact narrowed interpretation");
    }

    function testEmptyArtistAndDuplicateRoleRejected() public {
        StreamMediaMasterTypes.Artist memory a;
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.InvalidMasterWitness.selector));
        StreamMasterWaiverJson.artistJSON(a);
        StreamMediaMasterTypes.Waiver memory w;
        w.subjectId = bytes32(uint256(1)); w.scopeSubjectId = w.subjectId;
        w.mediaObjects = new StreamMediaMasterTypes.WaivedObject[](1);
        w.mediaObjects[0].objectId = bytes32(uint256(2));
        w.mediaObjects[0].masterRoles = new StreamMediaMasterTypes.Role[](2);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.InvalidMasterWitness.selector));
        StreamMasterWaiverJson.waiver(w);
    }
}
