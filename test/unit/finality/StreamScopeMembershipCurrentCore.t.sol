// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipCoreFixture.sol";

contract StreamScopeMembershipCurrentCoreTest is ScopeMembershipCoreFixture {
    function testActualCoreAllFamiliesGovernedPublicationBurnsAndLaterMint() public {
        _initializeScope();
        uint256[] memory ids = new uint256[](2);
        ids[0] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        uint256 other = scopeManager.mint(address(configuration.core), 2, address(0xbeef));
        ids[1] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        require(
            ids[0] == 1 && other == 2 && ids[1] == 3
                && configuration.core.collectionMintedEver(1) == 2
        );
        scopeInventory.appendCollectionTokens(1, ids);
        StreamFinalityScope memory retained;
        for (uint8 family = 2; family <= 4; ++family) {
            (bytes32 recordHash, StreamFinalityScope memory s) =
                _scopePublish(family, ids, "ipfs://scope/actual");
            vm.prank(address(0xca11));
            scopeMembership.continueScopeMembership(s, 1);
            StreamScopeMembershipFacts memory f = scopeMembership.requireScopeMembership(s);
            require(f.sourceRecordHash == recordHash && f.tokenCount == 2 && f.inventoryCount == 0);
            require(
                scopeMembership.scopeTokenAt(s, 0) == 1 && scopeMembership.scopeTokenAt(s, 1) == 3
            );
            require(
                scopeMembership.scopeCoversToken(s, 1) && !scopeMembership.scopeCoversToken(s, 2)
            );
            retained = s;
        }
        bytes32 beforeFacts =
            keccak256(abi.encode(scopeMembership.requireScopeMembership(retained)));
        vm.prank(address(0xbeef));
        configuration.core.burn(1);
        require(
            configuration.core.tokenLifecycle(1) == 3
                && configuration.core.collectionMintedEver(1) == 2
        );
        uint256 next = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        require(
            next == 4 && configuration.core.tokenLifecycle(4) == 2
                && configuration.core.ownerOf(4) == address(0xbeef) && scopeEntropy.callbacks() == 4
        );
        require(
            keccak256(abi.encode(scopeMembership.requireScopeMembership(retained))) == beforeFacts
                && scopeMembership.scopeCoversToken(retained, 1)
                && !scopeMembership.scopeCoversToken(retained, 4)
        );
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipReadFailed.selector,
                address(scopeInventory),
                IStreamCollectionTokenInventory.requireCompleteCollection.selector
            )
        );
        scopeMembership.requireScopeMembership(collection);
        uint256[] memory one = new uint256[](1);
        one[0] = next;
        scopeInventory.appendCollectionTokens(1, one);
        StreamScopeMembershipFacts memory current =
            scopeMembership.requireScopeMembership(collection);
        require(
            current.tokenCount == 3 && current.inventoryCount == 3 && current.scopeManifestHash == 0
                && current.inventoryPrefixHash != 0
        );
        require(
            address(scopeMembership).code.length <= 24576
                && address(configuration.core).code.length <= 24576
                && address(scopeMetadata).code.length <= 24576
        );
    }

    function testActualCoreUnindexedScopeRetryAndSavedWriterProvenance() public {
        _initializeScope();
        uint256[] memory ids = new uint256[](1);
        ids[0] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        (bytes32 recordHash, StreamFinalityScope memory s) =
            _scopePublish(2, ids, "ipfs://scope/retry");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipReadFailed.selector,
                address(scopeInventory),
                IStreamCollectionTokenInventory.collectionTokenAt.selector
            )
        );
        scopeMembership.continueScopeMembership(s, 1);
        require(scopeMembership.scopeMembershipProgress(s).processedTokens == 0);
        _scopeGrant(address(this), false);
        scopeInventory.appendCollectionTokens(1, ids);
        vm.prank(address(0xca11));
        scopeMembership.continueScopeMembership(s, 1);
        require(scopeMembership.requireScopeMembership(s).tokenCount == 1);
        IStreamFinalityScopeMembership.Publication memory p =
            scopeMembership.scopeMembershipPublication(s);
        require(
            p.recordHash == recordHash && p.receipt.recorder == address(this)
                && p.receipt.authorizationClass == 7 && p.receipt.artistAuthorization == 0
        );
        (bool enabled,) =
            scopeMetadata.familyWriter(1, StreamRecordFamilies.IDENTITY, 7, address(this));
        require(!enabled);
        StreamFinalityScope memory token =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, ids[0], 0);
        require(
            scopeMembership.requireScopeMembership(token).tokenCount == 1
                && scopeMembership.scopeTokenAt(token, 0) == ids[0]
        );
    }
}
