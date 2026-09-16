// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistRecoveryApprovalScopes.sol";

contract ApprovalScopeCoreBoundary {
    bytes private identity;
    bytes private lifecycle;

    function set(bytes memory identity_, bytes memory lifecycle_) external {
        identity = identity_;
        lifecycle = lifecycle_;
    }

    fallback() external {
        bytes memory result =
            msg.sig == IStreamCoreIdentity.tokenCollectionIdentity.selector ? identity : lifecycle;
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

contract ApprovalScopeHarness {
    function supported(StreamFinalityScope memory original, StreamFinalityScope memory requested)
        external
        pure
        returns (bool)
    {
        return StreamArtistRecoveryApprovalScopes.supported(original, requested);
    }

    function check(
        address core,
        StreamFinalityScope memory original,
        StreamFinalityScope memory requested
    ) external view {
        StreamArtistRecoveryApprovalScopes.requireFresh(core, original, requested, 100000);
    }
}

/// @dev The helper validates supplied Core return bytes; actual Artist/companion composition is separate.
contract StreamArtistRecoveryApprovalScopesTest {
    ApprovalScopeHarness private harness;
    ApprovalScopeCoreBoundary private core;
    StreamFinalityScope private original;
    StreamFinalityScope private token;

    function setUp() public {
        harness = new ApprovalScopeHarness();
        core = new ApprovalScopeCoreBoundary();
        original = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        token = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 9, 0);
        _set(1, 7, 2, 0, 2);
    }

    function _set(uint256 mapped, uint256 collection, uint256 serial, uint256 burned, uint256 state)
        private
    {
        core.set(abi.encode(mapped, collection, serial, burned), abi.encode(state));
    }

    function _reject(StreamFinalityScope memory requested) private {
        (bool ok, bytes memory reason) = address(harness)
            .call(abi.encodeCall(harness.check, (address(core), original, requested)));
        require(
            !ok && bytes4(reason) == StreamArtistRecoveryTypes.InvalidRecoveryApproval.selector,
            "exact invalid approval"
        );
    }

    function testAllFiveExactScopesPreserveHistoricalRelationWithoutCoreRead() public {
        for (uint8 i; i < 5; ++i) {
            StreamFinalityScope memory s = StreamFinalityScope(
                StreamFinalityScopeType(i),
                7,
                i == 1 ? 9 : 0,
                i > 1 ? bytes32(uint256(i)) : bytes32(0)
            );
            require(harness.supported(s, s), "exact scope");
            harness.check(address(0), s, s);
        }
    }

    function testInheritedMintedAndBurnedTokenAndHistoricalRelation() public {
        harness.check(address(core), original, token);
        _set(1, 7, 2, 1, 3);
        harness.check(address(core), original, token);
        _set(0, 0, 0, 0, 0);
        require(harness.supported(original, token), "saved shape does not recheck current token");
        _reject(token);
    }

    function testInvalidTokenIdentityWidthsAndLifecycleReject() public {
        _set(1, 7, 2, 0, 1);
        _reject(token);
        _set(1, 8, 2, 0, 2);
        _reject(token);
        _set(1, 7, 0, 0, 2);
        _reject(token);
        _set(2, 7, 2, 0, 2);
        _reject(token);
        _set(1, 7, 2, 2, 3);
        _reject(token);
        _set(1, 7, 2, 0, 3);
        _reject(token);
        _set(1, 7, 2, 1, 2);
        _reject(token);
        _set(1, 7, 2, 0, 256);
        _reject(token);
        _set(1, 7, 2, 0, 2);
        harness.check(address(core), original, token);
    }

    function testOnlyCanonicalSameCollectionTokenInheritance() public {
        StreamFinalityScope memory s = token;
        s.tokenId = 0;
        _reject(s);
        s = token;
        s.scopeId = bytes32(uint256(1));
        _reject(s);
        s = token;
        s.collectionId = 8;
        _reject(s);
        for (uint8 i = 2; i < 5; ++i) {
            s = StreamFinalityScope(StreamFinalityScopeType(i), 7, 0, bytes32(uint256(i)));
            _reject(s);
        }
        s = token;
        require(!harness.supported(s, original), "no reverse inheritance");
    }

    function testMalformedCoreReturnsRejectAndRestore() public {
        core.set(new bytes(96), abi.encode(uint256(2)));
        (bool ok, bytes memory reason) =
            address(harness).call(abi.encodeCall(harness.check, (address(core), original, token)));
        require(
            !ok
                && bytes4(reason)
                    == StreamArtistRecoveryApprovalScopes.RecoveryApprovalScopeReadFailed.selector,
            "short identity"
        );
        core.set(
            abi.encode(uint256(1), uint256(7), uint256(2), uint256(0), uint256(0)),
            abi.encode(uint256(2))
        );
        (ok,) =
            address(harness).call(abi.encodeCall(harness.check, (address(core), original, token)));
        require(!ok, "long identity");
        core.set(abi.encode(uint256(1), uint256(7), uint256(2), uint256(0)), new bytes(0));
        (ok,) =
            address(harness).call(abi.encodeCall(harness.check, (address(core), original, token)));
        require(!ok, "short lifecycle");
        _set(1, 7, 2, 0, 2);
        harness.check(address(core), original, token);
    }

    function testFuzzFullWidthTokenAndSerial(uint256 tokenId, uint256 serial, bool burned) public {
        if (tokenId == 0) tokenId = 1;
        if (serial == 0) serial = 1;
        StreamFinalityScope memory s = token;
        s.tokenId = tokenId;
        _set(1, 7, serial, burned ? 1 : 0, burned ? 3 : 2);
        harness.check(address(core), original, s);
        require(harness.supported(original, s), "stored supported relation");
    }
}
