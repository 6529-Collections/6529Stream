// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/metadata/StreamTokenContentTree.sol";
import "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

contract TokenContentTreeHarness {
    function root(uint256 chain, address core, StreamTokenContentLeaf[] memory leaves)
        external
        pure
        returns (bytes32)
    {
        return StreamTokenContentTree.root(chain, core, leaves);
    }

    function subject(uint256 chain, address core, StreamFinalityScope memory scope)
        external
        pure
        returns (bytes32)
    {
        return StreamMetadataSubjects.scopeSubject(chain, core, scope);
    }
}

contract StreamTokenContentTreeTest is CharacterizationTestBase {
    uint256 private constant CHAIN = 11155111;
    address private constant CORE = 0x1234567890123456789012345678901234567890;
    TokenContentTreeHarness private harness = new TokenContentTreeHarness();

    // Independent vectors use Python PyCryptodome Keccak over explicit 32-byte ABI words.
    // Leaves i use tokenId=3*i+1 and keccak256(UTF8("<field>:<i>")) in the five hash fields.
    function testIndependentOrderedTreeVectors() public pure {
        uint256[6] memory counts = [uint256(1), 2, 3, 5, 8, 37];
        bytes32[6] memory roots = [
            bytes32(0x249a9aa88f1d67e053b01d82a52f3b87cde5f594d2a802781d17ef78575f032c),
            0xa1a8bedcc1ce4966887df8087307fb605199133b34ed2ef15ece8800bd9bfb72,
            0x7ff81836082f972574397915c2c209e9048736cf0faac729a810521ca2db45e1,
            0x0212371ee488a82515c61609360339ddb79adbeb85e38523c064bdfd22e2254f,
            0xc0539a20aa460146e51a8e06ad4fb9fc1293c6e893c215657a176a4718ce84eb,
            0x8d9a566342c739139265758502412fd8253dabfc5c556adac8d683722c37ecaf
        ];
        for (uint256 i; i < counts.length; ++i) {
            StreamTokenContentLeaf[] memory leaves = _leaves(counts[i]);
            bytes32 beforeHash = keccak256(abi.encode(leaves));
            require(StreamTokenContentTree.root(CHAIN, CORE, leaves) == roots[i], "root vector");
            require(keccak256(abi.encode(leaves)) == beforeHash, "caller leaves mutated");
        }
    }

    function testRejectsEmptyMissingIdentityAndMetadata() public {
        vm.expectRevert(abi.encodeWithSelector(StreamTokenContentTree.EmptyContentTree.selector));
        harness.root(CHAIN, CORE, new StreamTokenContentLeaf[](0));
        StreamTokenContentLeaf[] memory leaves = _leaves(1);
        leaves[0].tokenId = 0;
        vm.expectRevert(
            abi.encodeWithSelector(StreamTokenContentTree.InvalidContentLeaf.selector, 0, 0)
        );
        harness.root(CHAIN, CORE, leaves);
        leaves[0].tokenId = 1;
        leaves[0].metadataHash = 0;
        vm.expectRevert(
            abi.encodeWithSelector(StreamTokenContentTree.InvalidContentLeaf.selector, 0, 1)
        );
        harness.root(CHAIN, CORE, leaves);
    }

    function testRejectsDuplicateAndDescendingIds() public {
        StreamTokenContentLeaf[] memory leaves = _leaves(3);
        leaves[2].tokenId = 4;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamTokenContentTree.ContentTokensNotAscending.selector, 2, 4, 4
            )
        );
        harness.root(CHAIN, CORE, leaves);
        leaves[2].tokenId = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamTokenContentTree.ContentTokensNotAscending.selector, 2, 4, 2
            )
        );
        harness.root(CHAIN, CORE, leaves);
    }

    function testMissingOptionalAssetsRemainExplicitZero() public pure {
        StreamTokenContentLeaf[] memory leaves = _leaves(1);
        leaves[0].imageHash = 0;
        leaves[0].animationHash = 0;
        leaves[0].contentHash = 0;
        leaves[0].tokenDataHash = 0;
        require(
            StreamTokenContentTree.root(CHAIN, CORE, leaves)
                == StreamTokenContentTree.leafHash(CHAIN, CORE, leaves[0]),
            "one leaf"
        );
    }

    function testFuzzEveryFieldAndDeploymentDomainAffectCommitment(uint128 token, bytes32 change)
        public
        pure
    {
        StreamTokenContentLeaf memory leaf = _leaves(1)[0];
        leaf.tokenId = uint256(token) + 1;
        bytes32 original = StreamTokenContentTree.leafHash(CHAIN, CORE, leaf);
        require(original != StreamTokenContentTree.leafHash(CHAIN + 1, CORE, leaf), "chain binding");
        require(
            original != StreamTokenContentTree.leafHash(CHAIN, address(uint160(CORE) + 1), leaf),
            "core binding"
        );
        leaf.tokenId += 1;
        require(original != StreamTokenContentTree.leafHash(CHAIN, CORE, leaf), "token binding");
        leaf.tokenId -= 1;
        bytes32 delta = change == 0 ? bytes32(uint256(1)) : change;
        for (uint256 i; i < 5; ++i) {
            StreamTokenContentLeaf memory changed = StreamTokenContentLeaf(
                leaf.tokenId,
                leaf.metadataHash,
                leaf.imageHash,
                leaf.animationHash,
                leaf.contentHash,
                leaf.tokenDataHash
            );
            if (i == 0) changed.metadataHash ^= delta;
            if (i == 1) changed.imageHash ^= delta;
            if (i == 2) changed.animationHash ^= delta;
            if (i == 3) changed.contentHash ^= delta;
            if (i == 4) changed.tokenDataHash ^= delta;
            require(
                original != StreamTokenContentTree.leafHash(CHAIN, CORE, changed), "asset binding"
            );
        }
    }

    function testIndependentSubjectVectorsForEveryScopeClass() public pure {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        require(
            StreamMetadataSubjects.scopeSubject(CHAIN, CORE, scope)
                == 0x0b11c7ea6508eb70df919746c7000952fe9ee1ce79cd81d38a22c9c9822b2da4,
            "collection"
        );
        scope.scopeType = StreamFinalityScopeType.TOKEN;
        scope.tokenId = 19;
        require(
            StreamMetadataSubjects.scopeSubject(CHAIN, CORE, scope)
                == 0x0cb869b5b3a48a5575e4c1537724386b4e850144e24be096f815e176a8a9a4fb,
            "token"
        );
        scope.tokenId = 0;
        scope.scopeId = bytes32(uint256(123));
        bytes32[3] memory expected = [
            bytes32(0x8e37d29250bbc22c86bde2fa8b84f6146ea5190fd3ae188bb3b170e8bb2da6e6),
            0xb4ab4c2243f7def8f4dfaa9171e020f712d6157372d884d214e7c307f37b7b44,
            0xcca972e1473b79236b25f99c9a77eacf28bd00bd73011f3275cffc2c9d580c11
        ];
        for (uint256 i; i < 3; ++i) {
            scope.scopeType = StreamFinalityScopeType(i + 2);
            require(
                StreamMetadataSubjects.scopeSubject(CHAIN, CORE, scope) == expected[i],
                "scoped vector"
            );
        }
        require(
            StreamMetadataSubjects.mediaSubject(CHAIN, CORE, 7, bytes32(uint256(123)))
                == 0xc9a44ce9bf3b68556861bc33b4927a5d6b0e1a4b47331795bd7c1795749b9088,
            "media"
        );
    }

    function testRejectsScopeAliasesAndMissingIdentity() public {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 1, 0);
        _reject(scope, CORE);
        scope.tokenId = 0;
        scope.scopeId = bytes32(uint256(1));
        _reject(scope, CORE);
        scope.scopeType = StreamFinalityScopeType.TOKEN;
        _reject(scope, CORE);
        scope.scopeId = 0;
        _reject(scope, CORE);
        scope.scopeType = StreamFinalityScopeType.RELEASE;
        _reject(scope, CORE);
        scope.scopeId = bytes32(uint256(1));
        scope.tokenId = 1;
        _reject(scope, CORE);
        scope.tokenId = 0;
        _reject(scope, address(0));
        scope.collectionId = 0;
        _reject(scope, CORE);
    }

    function _reject(StreamFinalityScope memory scope, address core) private {
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataSubjects.InvalidMetadataScope.selector)
        );
        harness.subject(CHAIN, core, scope);
    }

    function _leaves(uint256 count) private pure returns (StreamTokenContentLeaf[] memory leaves) {
        leaves = new StreamTokenContentLeaf[](count);
        for (uint256 i; i < count; ++i) {
            string memory suffix = Strings.toString(i);
            leaves[i] = StreamTokenContentLeaf(
                i * 3 + 1,
                keccak256(bytes(string.concat("metadata:", suffix))),
                keccak256(bytes(string.concat("image:", suffix))),
                keccak256(bytes(string.concat("animation:", suffix))),
                keccak256(bytes(string.concat("content:", suffix))),
                keccak256(bytes(string.concat("data:", suffix)))
            );
        }
    }
}
