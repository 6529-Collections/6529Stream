// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPreservationReferenceRecordsHistoryV1 as History
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceRecordsHistoryV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamSnapshotManifestBytes as Bytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ExactScopeVm {
    function expectRevert(bytes calldata expected) external;
    function etch(address target, bytes calldata code) external;
}

contract ReferenceExactScopeHarness {
    Store public immutable store;
    mapping(bytes32 => Bytes.Manifest) private _publications;

    constructor() {
        store = new Store();
    }

    function retain(bytes memory raw) external returns (bytes32 hash, address pointer) {
        (, pointer) = store.publishChunk(raw);
        hash = keccak256(raw);
        Bytes.retain(_publications[hash], address(store), raw);
    }

    function check(bytes32 hash, StreamFinalityScope memory scope) external view {
        if (hash == 0) return;
        History.requireExactScope(_publications[hash], scope);
    }

    // Frozen original host body: complete read/canonical decode precedes scope comparison.
    function original(bytes32 hash, StreamFinalityScope memory scope) external view {
        if (hash == 0) return;
        T.Publication memory p = History.publication(_publications[hash]);
        if (keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))) {
            revert T.InvalidScopedPolicyReference();
        }
    }
}

contract StreamReferenceExactScopeTest {
    ExactScopeVm private constant vm =
        ExactScopeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ReferenceExactScopeHarness private h;

    function setUp() public {
        h = new ReferenceExactScopeHarness();
    }

    function testTokenReleaseSeasonKeepCompleteCanonicalHistory() public {
        for (uint8 kind = 1; kind <= 3; ++kind) {
            T.Publication memory p = _publication(kind);
            (bytes32 hash,) = h.retain(abi.encode(p));
            h.original(hash, p.scope);
            h.check(hash, p.scope);
        }
    }

    function testZeroHeadDoesNotReadMissingManifest() public {
        StreamFinalityScope memory scope = _publication(1).scope;
        h.original(0, scope);
        h.check(0, scope);
        vm.expectRevert(abi.encodeWithSelector(Bytes.InvalidSnapshotManifest.selector));
        h.check(bytes32(uint256(1)), scope);
    }

    function testEachScopeFieldRejectsAndExactRetrySucceeds() public {
        T.Publication memory p = _publication(1);
        (bytes32 hash,) = h.retain(abi.encode(p));
        for (uint8 field; field < 4; ++field) {
            StreamFinalityScope memory bad = abi.decode(abi.encode(p.scope), (StreamFinalityScope));
            if (field == 0) bad.scopeType = StreamFinalityScopeType.RELEASE;
            else if (field == 1) ++bad.collectionId;
            else if (field == 2) ++bad.tokenId;
            else bad.scopeId = bytes32(uint256(99));
            vm.expectRevert(abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector));
            h.original(hash, bad);
            vm.expectRevert(abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector));
            h.check(hash, bad);
            h.check(hash, p.scope);
        }
    }

    function testCanonicalPaddingRejectsEvenWhenScopeMatches() public {
        T.Publication memory p = _publication(2);
        (bytes32 hash,) = h.retain(bytes.concat(abi.encode(p), bytes32(0)));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector));
        h.original(hash, p.scope);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector));
        h.check(hash, p.scope);
    }

    function testDamagedChunkFailsBeforeWrongScopeAndExactRetrySucceeds() public {
        T.Publication memory p = _publication(3);
        (bytes32 hash, address pointer) = h.retain(abi.encode(p));
        bytes memory originalCode = pointer.code;
        StreamFinalityScope memory bad = abi.decode(abi.encode(p.scope), (StreamFinalityScope));
        ++bad.collectionId;
        vm.etch(pointer, hex"00");
        vm.expectRevert(abi.encodeWithSelector(Bytes.SnapshotChunkChanged.selector, pointer));
        h.original(hash, bad);
        vm.expectRevert(abi.encodeWithSelector(Bytes.SnapshotChunkChanged.selector, pointer));
        h.check(hash, bad);
        vm.etch(pointer, originalCode);
        h.check(hash, p.scope);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector));
        h.check(hash, bad);
    }

    function testFuzzExactScopeMatchesOriginal(
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId
    ) public {
        T.Publication memory p = _publication(1);
        p.scope.collectionId = collectionId;
        p.scope.tokenId = tokenId;
        p.scope.scopeId = scopeId;
        (bytes32 hash,) = h.retain(abi.encode(p));
        h.original(hash, p.scope);
        h.check(hash, p.scope);
        // Historical comparison authenticates the full tuple without imposing live scope policy.
        p.scope.scopeId ^= bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector));
        h.check(hash, p.scope);
    }

    function _publication(uint8 kind) private pure returns (T.Publication memory p) {
        p.scope = StreamFinalityScope(StreamFinalityScopeType(kind), 7, 123, bytes32(uint256(11)));
    }
}
