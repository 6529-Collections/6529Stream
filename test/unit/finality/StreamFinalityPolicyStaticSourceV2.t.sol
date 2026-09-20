// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PolicySnapshotFixtureV2.sol";
import {
    StreamFinalityPolicyStaticSourceV2 as Source
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyStaticSourceV2.sol";
import {
    StreamFinalityPolicySnapshotReadsV2 as Reader
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicySnapshotReadsV2.sol";

/// @notice Actual snapshot payload/Store and current source projection; source hosts retain the
/// explicit typed boundaries of PolicySnapshotFixtureV2. No combined-provider acceptance claim.
contract StreamFinalityPolicyStaticSourceV2Test is PolicySnapshotFixtureV2 {
    function _dependencies() private view returns (Reader.Dependencies memory) {
        return Reader.Dependencies(
            address(core),
            address(metadata),
            address(host),
            address(core).codehash,
            address(metadata).codehash,
            address(host).codehash,
            block.chainid,
            1000000,
            12000000
        );
    }

    function testActualSnapshotProjectsExactSelectedProfileAndOriginalCoordinates() public {
        _initializePolicySnapshot();
        bytes32 record = _publishSnapshot();
        Source.Projection memory p = Source.current(
            _dependencies(), address(route), address(route).codehash, publication.scope
        );
        require(
            p.snapshotRecordHash == record
                && p.snapshotSourceHash == host.currentSnapshot(publication.scope).sourceHash
                && p.contentRootRecordHash == publication.contentRootRecord
        );
        require(
            p.selection == address(selected) && p.selectionCodeHash == address(selected).codehash
                && p.sourceProfile
                    == 0xd8338f881f829b89f9ddebc5b9ca77b263953d6f9479a9c9d40da92a445b8433
        );
        require(
            keccak256(abi.encode(p.scope)) == keccak256(abi.encode(publication.scope))
                && p.selectionId == contentPlan.selectionId
                && p.membershipHash == selectionPlan.membershipHash
                && p.selectionRoot == selectionPlan.selectionRoot
                && p.tokenCount == selectionPlan.tokenCount
                && p.lockedArtistSnapshotHash == keccak256("locked presentation")
        );
    }

    function testForeignRouterAndHistoricalSnapshotCannotFillCurrentProjection() public {
        _initializePolicySnapshot();
        bytes32 record = _publishSnapshot();
        Reader.Dependencies memory d = _dependencies();
        vm.expectRevert();
        Source.current(d, address(content), address(content).codehash, publication.scope);
        bytes32 saved = keccak256(host.snapshotPayload(record));
        route.set(
            "collectionContentRootHead(uint256)", abi.encode(keccak256("other admitted head"))
        );
        vm.expectRevert();
        Source.current(d, address(route), address(route).codehash, publication.scope);
        require(keccak256(host.snapshotPayload(record)) == saved, "historical bytes not repurposed");
    }

    function testPayloadCodeFaultAndExactRestoreAreObservedByProjection() public {
        _initializePolicySnapshot();
        bytes32 record = _publishSnapshot();
        Reader.Dependencies memory d = _dependencies();
        (address pointer,,) = host.snapshotChunkAt(record, 0);
        bytes memory old = pointer.code;
        vm.etch(pointer, hex"00");
        vm.expectRevert();
        Source.current(d, address(route), address(route).codehash, publication.scope);
        vm.etch(pointer, old);
        require(
            Source.current(d, address(route), address(route).codehash, publication.scope)
            .snapshotRecordHash == record
        );
    }

    function testSourceSetCurrentnessIsRequiredWithoutReferenceOrInventoryReads() public {
        _initializePolicySnapshot();
        bytes32 record = _publishSnapshot();
        Reader.Dependencies memory d = _dependencies();
        entropy.setCurrent(false);
        vm.expectRevert();
        Source.current(d, address(route), address(route).codehash, publication.scope);
        entropy.setCurrent(true);
        require(
            Source.current(d, address(route), address(route).codehash, publication.scope)
            .snapshotRecordHash == record
        );
    }
}
