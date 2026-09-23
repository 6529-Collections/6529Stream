// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RouterScopeMembershipFixture.sol";

contract StreamRouterScopeMembershipTest is RouterScopeMembershipFixture {
    function testActualRouterProviderAndMembershipShareAllFiveScopes() public {
        _routerMembership(true);
        uint256[] memory ids = _tokens(3);
        _index(ids, 0, 3);
        for (uint8 family = 2; family <= 4; ++family) {
            StreamFinalityScope memory s = _seal(family, ids, "ipfs://scope-router-record");
            for (uint256 i; i < 3; ++i) {
                require(
                    scopeRouter.scopeCoversToken(s, ids[i])
                        && scopeRouter.scopeTokenAt(s, i) == ids[i]
                );
                (bool ok, bytes memory raw) = address(scopeRouter)
                    .staticcall(abi.encodeCall(scopeRouter.scopeCoversToken, (s, ids[i])));
                require(ok && raw.length == 32 && keccak256(raw) == keccak256(abi.encode(true)));
                (ok, raw) =
                    address(scopeRouter)
                    .staticcall(abi.encodeCall(scopeRouter.scopeTokenAt, (s, i)));
                require(ok && raw.length == 32 && keccak256(raw) == keccak256(abi.encode(ids[i])));
            }
            require(!scopeRouter.scopeCoversToken(s, 777));
            s.scopeType = family == 4
                ? StreamFinalityScopeType.RELEASE
                : StreamFinalityScopeType.VIEW;
            vm.expectRevert();
            scopeRouter.scopeCoversToken(s, 3);
        }
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        require(
            scopeRouter.scopeTokenAt(collection, 2) == 9
                && scopeRouter.scopeCoversToken(collection, 3)
        );
        StreamFinalityScope memory token = StreamFinalityScope(
            StreamFinalityScopeType.TOKEN, 1, 6, 0
        );
        require(
            scopeRouter.scopeTokenAt(token, 0) == 6 && scopeRouter.scopeCoversToken(token, 6)
                && !scopeRouter.scopeCoversToken(token, 3)
        );
        require(
            realProvider.scopeMembershipHost() == address(membership)
                && realProvider.metadataRouter() == address(scopeRouter)
        );
        require(scopeRouter.supportsInterface(type(IStreamMetadataScopeMembership).interfaceId));
        require(scopeRouter.streamModuleInterfaceId() == type(IStreamMetadataRouter).interfaceId);
        require(
            address(scopeRouter).code.length <= 24576 && address(realProvider).code.length <= 24576
        );
    }

    function testLockedMembershipKeepsOriginalProviderAfterCurrentPointerAndAuthorityLoss() public {
        _routerMembership(true);
        uint256[] memory ids = _tokens(2);
        _index(ids, 0, 2);
        StreamFinalityScope memory s = _seal(4, ids, "ipfs://fixed-membership");
        bytes32 facts = keccak256(abi.encode(membership.requireScopeMembership(s)));
        address replacement = address(new ScopeMetadataArtistBoundary(address(core)));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), replacement);
        core.setPointer(keccak256("COLLECTION_METADATA"), replacement);
        core.setPointer(keccak256("ARTIST_REGISTRY"), replacement);
        bytes memory facadeCode = address(routerArtist).code;
        bytes memory executorCode = address(executor).code;
        vm.etch(address(routerArtist), hex"");
        vm.etch(address(executor), hex"");
        require(scopeRouter.scopeCoversToken(s, 3) && scopeRouter.scopeTokenAt(s, 1) == 6);
        require(keccak256(abi.encode(membership.requireScopeMembership(s))) == facts);
        vm.etch(address(routerArtist), facadeCode);
        vm.etch(address(executor), executorCode);
        require(scopeRouter.scopeCoversToken(s, 3));
    }

    function testUnlockedFacadePinAndMissingOrPartialSavedAnchorsFailClosed() public {
        _routerMembership(false);
        uint256[] memory ids = _tokens(1);
        _index(ids, 0, 1);
        StreamFinalityScope memory s = _seal(2, ids, "ipfs://unlocked-membership");
        require(scopeRouter.scopeCoversToken(s, 3));
        bytes memory facadeCode = address(routerArtist).code;
        vm.etch(address(routerArtist), hex"");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRecoveryRoutes.MetadataRecoveryBindingInvalid.selector,
                address(routerArtist)
            )
        );
        scopeRouter.scopeCoversToken(s, 3);
        vm.etch(address(routerArtist), facadeCode);
        bytes32 slot = _anchorSlot(1);
        vm.store(address(scopeRouter), slot, bytes32(uint256(uint160(address(originalBoundary)))));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataScopeMembership.MetadataScopeBindingInvalid.selector,
                address(originalBoundary)
            )
        );
        scopeRouter.scopeCoversToken(s, 3);
        vm.store(address(scopeRouter), slot, 0);
        scopeRouter.lockArtistIdentity(1);
        bytes32 hashSlot = bytes32(uint256(slot) + 1);
        bytes32 originalHash = vm.load(address(scopeRouter), hashSlot);
        vm.store(address(scopeRouter), hashSlot, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataScopeMembership.MetadataScopeBindingInvalid.selector,
                address(originalBoundary)
            )
        );
        scopeRouter.scopeCoversToken(s, 3);
        vm.store(address(scopeRouter), hashSlot, originalHash);
        vm.store(address(scopeRouter), slot, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataScopeMembership.MetadataScopeBindingInvalid.selector, address(0)
            )
        );
        scopeRouter.scopeCoversToken(s, 3);
        vm.store(address(scopeRouter), slot, bytes32(uint256(uint160(address(originalBoundary)))));
        require(scopeRouter.scopeCoversToken(s, 3));
        s.collectionId = 2;
        vm.expectRevert();
        scopeRouter.scopeCoversToken(s, 3);
    }

    function testOriginalProviderAndMemberRuntimePinsAndCanonicalCalldata() public {
        _routerMembership(true);
        uint256[] memory ids = _tokens(1);
        _index(ids, 0, 1);
        StreamFinalityScope memory s = _seal(3, ids, "ipfs://pins-membership");
        address[3] memory targets =
            [address(originalBoundary), address(realProvider), address(membership)];
        for (uint256 i; i < 3; ++i) {
            bytes memory code = targets[i].code;
            vm.etch(targets[i], hex"00");
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMetadataScopeMembership.MetadataScopeBindingInvalid.selector, targets[i]
                )
            );
            scopeRouter.scopeTokenAt(s, 0);
            vm.etch(targets[i], code);
            require(scopeRouter.scopeTokenAt(s, 0) == 3);
        }
        bytes memory input =
            bytes.concat(abi.encodeCall(scopeRouter.scopeCoversToken, (s, uint256(3))), hex"00");
        (bool ok,) = address(scopeRouter).staticcall(input);
        require(!ok, "no silently accepted trailing bytes");
        input = abi.encodeCall(scopeRouter.scopeCoversToken, (s, uint256(3)));
        assembly { mstore(add(input, 36), 256) }
        (ok,) = address(scopeRouter).staticcall(input);
        require(!ok, "scope enum width");
        vm.expectRevert();
        scopeRouter.scopeTokenAt(s, 1);
        require(scopeRouter.scopeTokenAt(s, 0) == 3);
    }
}
