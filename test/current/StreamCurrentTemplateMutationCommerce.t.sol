// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeCustodyRightsBatchFixture.sol";

/// @notice Actual current token custody with typed Artist mutation consent.
contract StreamCurrentTemplateMutationCommerceTest is NativeCustodyRightsBatchFixture {
    function testFrozenStrictConsentedDynamicTokenTemplatesSettleActualCustody() public {
        _bindCustody();
        for (uint8 mode = 2; mode <= 4; ++mode) {
            Plan memory p = _custodyPlan(false, address(this), address(this));
            bytes32 id = _openCustody(p);
            (bytes32 tid, bytes32 mutableHash) = _batchTemplate(p.auth.expectedTokenId, mode);
            bytes32 frozen =
                resolver.previewArtistScopedPrimaryTemplateAssignment(
                1, 2, p.auth.expectedTokenId, tid, 0, true
            )
            .assignmentHash;
            scopedArtist.approveScope(address(resolver), 1, 2, p.auth.expectedTokenId, frozen, true);
            require(
                resolver.freezePrimaryAssignment(CLASS, 2, p.auth.expectedTokenId) == frozen
                    && frozen != mutableHash,
                "actual exact template freeze"
            );
            _activateBatch(id, mode);
            _batchBid(id, payer);
            _custodyEnd(id);
            (uint256 token, bytes32 key) = house.settleCustodyRights(id);
            require(
                token == mode - 1 && core.ownerOf(token) == payer
                    && manager.nextOperationNonce() == token
                    && recorder.settlementResult(key).operationIdentityCommitment == 0
                    && resolver.resolvePrimaryAssignment(1, token, CLASS).frozen,
                "actual paid transfer preserves frozen source without another mint"
            );
        }
    }

    function testClearedTokenTemplateBlocksActivatedFamilyUntilApprovedTemplateRestored() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        (bytes32 tid,) = _batchTemplate(1, 3);
        _activateBatch(id, 3);
        scopedArtist.approveScope(address(resolver), 1, 2, 1, 0, true);
        resolver.clearPrimaryAssignment(CLASS, 2, 1);
        require(
            resolver.resolvePrimaryAssignment(1, 1, CLASS).scope == 1, "actual collection fallback"
        );
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (bool ok,) =
            address(house).call{ value: 1000 }(abi.encodeCall(house.bidCustodyRights, (id, payer)));
        require(
            !ok && house.auction(id).winner.amount == 0,
            "token-template sale never skips real fallback"
        );
        resolver.setPrimaryTemplateAssignment(CLASS, 2, 1, tid, 0);
        _batchBid(id, payer);
        _custodyEnd(id);
        house.settleCustodyRights(id);
        require(
            core.ownerOf(1) == payer && manager.nextOperationNonce() == 1,
            "same activated sale resumes on approved token template"
        );
    }
}
