// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipCoreFixture.sol";
import "../../../smart-contracts/domains/artist/StreamArtistRecoveryApprovalScopes.sol";

/// @notice Exact approval membership reader against actual governed Core identity/lifecycle.
/// @dev Mint admission and entropy policy remain boundaries; no Artist or recovery execution claim.
contract StreamArtistRecoveryApprovalCurrentCoreTest is ScopeMembershipCoreFixture {
    function checkApprovalToken(uint256 collectionId, uint256 tokenId) external view {
        StreamArtistRecoveryApprovalScopes.requireFresh(
            address(configuration.core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0),
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, collectionId, tokenId, 0),
            2000000
        );
    }

    function testActualCoreApprovalPreparedIdentityRejectsUntilCompletedAndRetainsBurn() public {
        _initializeScope();
        bytes memory data = bytes("prepared approval token");
        bytes32 operation = keccak256("prepared approval operation");
        vm.prank(address(scopeManager));
        (uint256 id, uint256 serial) =
            configuration.core.prepareMintFromManager(1, data, keccak256(data), operation);
        (bool mapped, uint256 cid, uint256 actualSerial, bool burned) =
            configuration.core.tokenCollectionIdentity(id);
        require(
            mapped && cid == 1 && actualSerial == serial && serial != 0 && !burned
                && configuration.core.tokenLifecycle(id) == 1,
            "actual mapped prepared identity"
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistRecoveryTypes.InvalidRecoveryApproval.selector)
        );
        this.checkApprovalToken(1, id);
        vm.prank(address(scopeManager));
        configuration.core
            .completePreparedMintFromManager(
                id, address(0xbeef), operation, keccak256("mint commitment")
            );
        require(
            configuration.core.tokenLifecycle(id) == 2
                && configuration.core.ownerOf(id) == address(0xbeef)
        );
        this.checkApprovalToken(1, id);
        vm.prank(address(0xbeef));
        configuration.core.burn(id);
        (mapped, cid, actualSerial, burned) = configuration.core.tokenCollectionIdentity(id);
        require(
            mapped && cid == 1 && actualSerial == serial && burned
                && configuration.core.tokenLifecycle(id) == 3,
            "actual burned identity retained"
        );
        this.checkApprovalToken(1, id);
    }

    function testActualCoreApprovalRejectsUnknownAndOtherCollectionButAcceptsExactIdentity()
        public
    {
        _initializeScope();
        uint256 id = scopeManager.mint(address(configuration.core), 2, address(0xbeef));
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistRecoveryTypes.InvalidRecoveryApproval.selector)
        );
        this.checkApprovalToken(1, id);
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistRecoveryTypes.InvalidRecoveryApproval.selector)
        );
        this.checkApprovalToken(1, id + 1);
        this.checkApprovalToken(2, id);
        require(
            configuration.core.collectionMintedEver(2) == 1
                && configuration.core.tokenLifecycle(id) == 2,
            "exact actual collection and completed identity"
        );
    }
}
