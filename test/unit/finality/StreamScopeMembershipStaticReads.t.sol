// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopeMembershipPublicationFixture.sol";

interface ScopeStaticVm {
    function etch(address target, bytes calldata code) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

/// @notice Actual Metadata/Schema/store/inventory/membership, with explicitly typed Core/governance boundaries.
/// @dev Authored source cases only until executed. Disabling linked helper code checks this call
/// boundary; it is not whole-program STATIC opcode/read-set or genuine current-Core acceptance.
contract StreamScopeMembershipStaticReadsTest is ScopeMembershipPublicationFixture {
    function testPublishedScopesKeepOriginalFactsWithBothLegacyHelpersUnavailable() public {
        uint256[] memory ids = _tokens(3);
        _index(ids, 0, 3);
        StreamFinalityScope[] memory scopes = new StreamFinalityScope[](3);
        bytes32[] memory hashes = new bytes32[](3);
        for (uint8 kind = 2; kind <= 4; ++kind) {
            scopes[kind - 2] = _seal(kind, ids, "ipfs://static-scope");
            StreamScopeMembershipFacts memory f = membership.requireScopeMembership(
                scopes[kind - 2]
            );
            hashes[kind - 2] = keccak256(abi.encode(f));
            require(
                f.membershipHash == _independent(scopes[kind - 2], f),
                "original seven-field preimage"
            );
        }
        _disableHelpers();
        require(membership.tokenScopeCount(ids[0]) == 3);
        for (uint256 i; i < 3; ++i) {
            (StreamFinalityScope memory actual, bool complete) = membership.tokenScopeAt(ids[0], i);
            require(complete && keccak256(abi.encode(actual)) == keccak256(abi.encode(scopes[i])));
            require(
                membership.scopeCoversToken(actual, ids[0])
                    && membership.scopeTokenAt(actual, 2) == ids[2]
            );
            require(keccak256(abi.encode(membership.requireScopeMembership(actual))) == hashes[i]);
        }
        core.setToken(ids[0], 1, 1, 3);
        require(membership.scopeCoversToken(scopes[0], ids[0]), "retained burned identity");
    }

    function testCollectionAndTokenCoverageKeepInventoryAndIdentityValidation() public {
        uint256[] memory ids = _tokens(2);
        _index(ids, 0, 2);
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        StreamFinalityScope memory token =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, ids[1], 0);
        _disableHelpers();
        require(membership.requireScopeMembership(collection).tokenCount == 2);
        require(
            membership.scopeTokenAt(collection, 1) == ids[1]
                && membership.scopeCoversToken(token, ids[1])
        );
        require(!membership.scopeCoversToken(token, ids[0]));
        core.setToken(100, 1, 3, 2);
        vm.expectRevert();
        membership.requireScopeMembership(collection);
        require(
            membership.scopeCoversToken(token, ids[1]),
            "exact token does not invent inventory completeness"
        );
    }

    function testPendingPrefixNeverBecomesCompleteWhenLegacyHelpersAreUnavailable() public {
        uint256[] memory ids = _tokens(257);
        _index(ids, 0, 257);
        StreamFinalityScope memory scope =
            membership.beginScopeMembership(_publish(_manifest(2, ids), "ipfs://pending-static"));
        membership.continueScopeMembership(scope, 1);
        _disableHelpers();
        (, bool complete) = membership.tokenScopeAt(ids[0], 0);
        require(!complete && membership.tokenScopeCount(ids[256]) == 0);
        vm.expectRevert();
        membership.scopeCoversToken(scope, ids[0]);
    }

    function testStaticCoverageStillRejectsMalformedCoreAndChangedRecordedBlob() public {
        uint256[] memory ids = _tokens(1);
        _index(ids, 0, 1);
        StreamFinalityScope memory scope = _seal(2, ids, "ipfs://pins-static");
        IStreamFinalityScopeMembership.Publication memory original =
            membership.scopeMembershipPublication(scope);
        _disableHelpers();
        ScopeStaticVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (ids[0])),
                new bytes(160)
            );
        vm.expectRevert();
        membership.scopeCoversToken(scope, ids[0]);
        ScopeStaticVm(address(vm)).etch(original.payloadPointer, hex"fe");
        vm.expectRevert();
        membership.tokenScopeAt(ids[0], 0);
    }

    function _disableHelpers() private {
        ScopeStaticVm(address(vm)).etch(address(StreamScopeMembershipReads), hex"fe");
        ScopeStaticVm(address(vm)).etch(address(StreamScopeMembershipEncoding), hex"fe");
    }

    function _independent(StreamFinalityScope memory scope, StreamScopeMembershipFacts memory f)
        private
        view
        returns (bytes32)
    {
        bytes32 facts = keccak256(
            abi.encode(
                f.scopeSubject,
                f.scopeManifestHash,
                f.sourceRecordHash,
                f.tokenCount,
                f.tokenListHash,
                f.inventoryCount,
                f.inventoryPrefixHash
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPE_MEMBERSHIP_FACTS_V1"),
                block.chainid,
                address(core),
                address(metadata),
                address(inventory),
                scope,
                facts
            )
        );
    }
}
