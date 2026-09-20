// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    PreservationSnapshotFixtureV1
} from "./StreamPreservationPolicySnapshotPublicationV1.t.sol";
import {
    ScopedPreservationSnapshotFixtureV1
} from "./StreamScopedPreservationPolicySnapshotPublicationV1.t.sol";
import {
    StreamPreservationPolicySnapshotPublicationV1 as C1
} from "../../../smart-contracts/domains/metadata/StreamPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationPolicySnapshotPublicationV2 as C2
} from "../../../smart-contracts/domains/metadata/StreamPreservationPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPreservationPolicySnapshotPublicationV1 as S1
} from "../../../smart-contracts/domains/metadata/StreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotPublicationV2 as S2
} from "../../../smart-contracts/domains/metadata/StreamScopedPreservationPolicySnapshotPublicationV2.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @notice Real thin writer constructors over the existing V1 governance/source topology fixture.
/// @dev Only three child profile getter words are mocked. No V2 publication, root adoption,
/// producer conformance, current-authority ceremony, native runtime or gas claim is made.
contract StreamCollectionPreservationSnapshotV2ConstructorTest is PreservationSnapshotFixtureV1 {
    function testFixedV2ConstructorRequiresExactChildFamilyAndOldWrapperStaysStrict() public {
        _initialize();
        C.Dependencies memory d = snapshotHost.dependencies();
        vm.expectRevert(abi.encodeWithSelector(C.InvalidPolicySnapshot.selector));
        new C2(d, address(executor), _snapshotGas());
        snapshotVm.mockCall(
            d.targets[7],
            abi.encodeWithSignature("preservationPolicyProfile()"),
            abi.encode(Profiles.COLLECTION_CHECKPOINT_PROFILE)
        );
        snapshotVm.mockCall(
            d.targets[8],
            abi.encodeWithSignature("outputProfile()"),
            abi.encode(Profiles.OUTPUT_MANIFEST_PROFILE)
        );
        // A V2 checkpoint marker does not substitute for the fixed family marker.
        vm.expectRevert(abi.encodeWithSelector(C.InvalidPolicySnapshot.selector));
        new C2(d, address(executor), _snapshotGas());
        snapshotVm.mockCall(
            d.targets[7],
            abi.encodeWithSignature("preservationOutputProfile()"),
            abi.encode(Profiles.FAMILY_PROFILE)
        );
        C2 current = new C2(d, address(executor), _snapshotGas());
        require(
            current.preservationPolicySnapshotProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2")
        );
        require(
            snapshotHost.preservationPolicySnapshotProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1")
        );
        require(keccak256(abi.encode(current.dependencies())) == keccak256(abi.encode(d)));
        require(current.snapshotCount(publication.scope) == 0);
        vm.expectRevert(abi.encodeWithSelector(C.InvalidPolicySnapshot.selector));
        new C1(d, address(executor), _snapshotGas());
    }
}

contract StreamScopedPreservationSnapshotV2ConstructorTest is ScopedPreservationSnapshotFixtureV1 {
    function testFixedV2ConstructorRequiresExactChildFamilyAndOldWrapperStaysStrict() public {
        _initialize(1);
        S.Dependencies memory d = snapshotHost.dependencies();
        vm.expectRevert(abi.encodeWithSelector(S.InvalidScopedPolicySnapshot.selector));
        new S2(d, address(executor), _snapshotGas());
        snapshotVm.mockCall(
            d.targets[7],
            abi.encodeWithSignature("preservationPolicyProfile()"),
            abi.encode(Profiles.SCOPED_CHECKPOINT_PROFILE)
        );
        snapshotVm.mockCall(
            d.targets[8],
            abi.encodeWithSignature("outputProfile()"),
            abi.encode(Profiles.OUTPUT_MANIFEST_PROFILE)
        );
        // A V2 checkpoint marker does not substitute for the fixed family marker.
        vm.expectRevert(abi.encodeWithSelector(S.InvalidScopedPolicySnapshot.selector));
        new S2(d, address(executor), _snapshotGas());
        snapshotVm.mockCall(
            d.targets[7],
            abi.encodeWithSignature("preservationOutputProfile()"),
            abi.encode(Profiles.FAMILY_PROFILE)
        );
        S2 current = new S2(d, address(executor), _snapshotGas());
        require(
            current.scopedPreservationPolicySnapshotProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2")
        );
        require(
            snapshotHost.scopedPreservationPolicySnapshotProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
        );
        require(keccak256(abi.encode(current.dependencies())) == keccak256(abi.encode(d)));
        require(current.snapshotCount(publication.scope) == 0);
        vm.expectRevert(abi.encodeWithSelector(S.InvalidScopedPolicySnapshot.selector));
        new S1(d, address(executor), _snapshotGas());
    }
}
