// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PolicyReferenceFixtureV2.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

/// @notice Actual V2 Snapshot/reference/Metadata/Schema/Store/Membership component route.
/// @dev Original action context, Core, Artist, Router, output, entropy and Archive are typed
/// fixture boundaries. This does not stand in for complete Discovery/provider execution.
contract StreamPolicyReferenceCollectionComponentV2Test is PolicyReferenceFixtureV2 {
    function _locked() private returns (bytes32 hash) {
        _reference(true);
        hash = _publishReference();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            referenceHost.lockTransition(referenceInput.scope);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("actual V2 lock action"), uint8(2), scope, oldHash, newHash)
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
    }

    function testBothComponentSelectorsRetainLiteralV2RecordAndLockCommitment() public {
        bytes32 hash = _locked();
        T.Receipt memory r = referenceHost.currentReference(referenceInput.scope);
        R.Lock memory l = referenceHost.referenceLock(referenceInput.scope);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_LOCKED_POLICY_REFERENCE_COMPONENT_V2"),
                block.chainid,
                address(referenceHost),
                address(core),
                referenceInput.scope,
                r,
                l
            )
        );
        bytes32 payload = keccak256(referenceHost.referencePayload(hash));
        StreamFinalityComponentState memory a = referenceHost.finalityState(1);
        StreamFinalityComponentState memory b =
            referenceHost.finalityStateForScope(referenceInput.scope);
        require(a.frozen && a.dataHash == expected && b.dataHash == expected);
        require(a.interfaceId == type(IStreamArtworkFinalityComponent).interfaceId);
        require(b.interfaceId == type(IStreamArtworkScopedFinalityComponent).interfaceId);
        require(
            referenceHost.supportsInterface(a.interfaceId)
                && referenceHost.supportsInterface(b.interfaceId)
        );
        b.interfaceId = a.interfaceId;
        require(keccak256(abi.encode(a)) == keccak256(abi.encode(b)), "only vocabulary differs");
        require(keccak256(referenceHost.referencePayload(hash)) == payload, "history unchanged");
        require(referenceHost.currentReference(referenceInput.scope).observation.recordHash == hash);
    }

    function testCollectionRouteCannotReadUnlockedOrWrongCollectionOrScope() public {
        _reference(true);
        _publishReference();
        vm.expectRevert();
        referenceHost.finalityState(1);
        vm.expectRevert();
        referenceHost.finalityState(0);
        vm.expectRevert();
        referenceHost.finalityState(2);
        StreamFinalityScope memory scope = referenceInput.scope;
        scope.scopeType = StreamFinalityScopeType.TOKEN;
        scope.tokenId = 1;
        vm.expectRevert();
        referenceHost.finalityStateForScope(scope);
    }

    function testBothSelectorsRejectCurrentDriftAndRecoverWithoutChangingHistory() public {
        bytes32 hash = _locked();
        bytes32 payload = keccak256(referenceHost.referencePayload(hash));
        route.set("collectionContentRootHead(uint256)", abi.encode(keccak256("later root")));
        vm.expectRevert();
        referenceHost.finalityState(1);
        vm.expectRevert();
        referenceHost.finalityStateForScope(referenceInput.scope);
        require(keccak256(referenceHost.referencePayload(hash)) == payload);
        route.set("collectionContentRootHead(uint256)", abi.encode(publication.contentRootRecord));
        require(referenceHost.finalityState(1).frozen);
        require(referenceHost.finalityStateForScope(referenceInput.scope).frozen);
    }
}
