// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamMetadataScopedContentState as State
} from "../../../smart-contracts/domains/metadata/StreamMetadataScopedContentState.sol";
import {
    StreamMetadataViewPreservationContentStateV1 as Saved
} from "../../../smart-contracts/domains/metadata/StreamMetadataViewPreservationContentStateV1.sol";
import {
    IStreamScopedContentRootPublication as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamViewPreservationContentRootV1 as B
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as D
} from "../../../smart-contracts/domains/records/StreamViewPreservationContentDefinitionsV1.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Actual original state and new immutable binding. Source/Artist authorization is explicitly
/// supplied at this unit boundary; the probe is not an alternate production writer.
interface ViewContentTestVm {
    function expectRevert(bytes4) external;
}

contract ViewContentBindingProbe {
    State.State private state;
    address public constant CORE = address(0xC0);

    function commit(R.Record memory r, B.Binding memory binding, bytes32 consent, bool corrupt)
        external
        returns (bytes32 key)
    {
        key = State.commitView(state, CORE, r, consent);
        if (corrupt) binding.adoptionRecord = keccak256("late substituted adoption");
        Saved.retain(state, CORE, key, binding);
    }

    function legacy(R.Record memory r, bytes32 consent) external returns (bytes32) {
        return State.commit(state, CORE, r, consent);
    }

    function retainAgain(bytes32 key, B.Binding memory binding) external {
        Saved.retain(state, CORE, key, binding);
    }

    function binding(bytes32 key) external view returns (B.Binding memory) {
        return Saved.binding(state, CORE, key);
    }

    function required(bytes32 key) external view returns (B.Binding memory) {
        return Saved.requireBinding(state, CORE, key);
    }

    function record(bytes32 key) external view returns (R.Record memory) {
        return state.records[key];
    }

    function head(StreamFinalityScope memory scope) external view returns (bytes32) {
        return state.heads[Subjects.scopeSubject(block.chainid, CORE, scope)];
    }

    function aggregate(uint256 cid) external view returns (R.Aggregate memory) {
        return state.aggregates[cid];
    }

    function family(uint256 cid, bytes32 legacyHash) external view returns (bytes32) {
        return State.family(CORE, cid, legacyHash, state.aggregates[cid]);
    }
}

contract StreamViewPreservationContentStateV1Test is CharacterizationTestBase {
    ViewContentBindingProbe private probe;
    uint256 private originalChain;

    function setUp() public {
        vm.warp(100);
        originalChain = block.chainid;
        probe = new ViewContentBindingProbe();
    }

    function _scope(bytes32 id) private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.VIEW, 17, 0, id);
    }

    function _binding(uint256 salt) private pure returns (B.Binding memory b) {
        bytes memory encoded = new bytes(896);
        for (uint256 i; i < 28; ++i) {
            uint256 value = uint160(uint256(keccak256(abi.encode(salt, i))) | 1);
            assembly ("memory-safe") { mstore(add(add(encoded, 32), mul(i, 32)), value) }
        }
        b = abi.decode(encoded, (B.Binding));
        b.profileId = D.PROFILE;
    }

    function _record(
        ViewContentBindingProbe host,
        StreamFinalityScope memory scope,
        B.Binding memory b
    ) private view returns (R.Record memory r) {
        r.publication = R.Publication(
            scope, host.head(scope), keccak256("current snapshot"), 1, "ipfs://complete-index"
        );
        r.snapshotHost = address(0x501);
        r.snapshotCodeHash = keccak256("snapshot runtime");
        r.snapshotManifestHash = keccak256("complete snapshot bytes");
        r.snapshotSourceHash = keccak256("current source");
        r.contentRoot = keccak256("all rows");
        r.leafCount = 2;
        r.outputManifestHash = b.manifestIndexHash;
        r.artistId = keccak256("actual artist at typed boundary");
        r.bindingGeneration = 3;
        r.bindingHash = keccak256("binding");
        r.publisher = address(this);
        r.authorizationClass = 7;
        r.grantRevision = 4;
        r.routeHash = keccak256("selected route");
        r.stateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_STATE_V1"),
                block.chainid,
                address(host),
                host.CORE(),
                r,
                b
            )
        );
    }

    function _commit(StreamFinalityScope memory scope, uint256 salt)
        private
        returns (bytes32 key, B.Binding memory b)
    {
        b = _binding(salt);
        key = probe.commit(
            _record(probe, scope, b), b, keccak256(abi.encode("original op17", salt)), false
        );
    }

    function testLiteralOriginalRecordAndNewBindingPreimagesAndZeroFamily() public {
        bytes32 legacy = keccak256("original nine-root content family");
        require(probe.family(17, legacy) == legacy, "revision zero");
        StreamFinalityScope memory scope = _scope(keccak256("view membership A"));
        B.Binding memory b = _binding(1);
        R.Record memory p = _record(probe, scope, b);
        bytes32 consent = keccak256("original consumed op17");
        bytes32 key = probe.commit(p, b, consent, false);
        R.Record memory r = probe.record(key);
        R.Aggregate memory a = probe.aggregate(17);
        require(
            r.artistConsent == consent && r.publishedAt == 100 && a.revision == 1,
            "original completed fields"
        );
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"),
                        block.chainid,
                        address(probe),
                        probe.CORE(),
                        r,
                        a
                    )
                ),
            "literal original outer record"
        );
        bytes32 subject = Subjects.scopeSubject(block.chainid, probe.CORE(), scope);
        require(
            a.transitionChain
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1"),
                        block.chainid,
                        address(probe),
                        probe.CORE(),
                        uint256(17),
                        bytes32(0),
                        uint64(1),
                        subject,
                        bytes32(0),
                        p.stateHash
                    )
                ),
            "literal ordered aggregate"
        );
        require(
            probe.family(17, legacy)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                        block.chainid,
                        address(probe),
                        probe.CORE(),
                        uint256(17),
                        legacy,
                        a
                    )
                ),
            "literal original family"
        );
        require(
            keccak256(abi.encode(probe.required(key))) == keccak256(abi.encode(b)),
            "complete binding"
        );
    }

    function testTwoViewsAndOriginalTokenShareAggregateWithoutSharingHeads() public {
        StreamFinalityScope memory a = _scope(keccak256("same numeric id"));
        StreamFinalityScope memory b = _scope(keccak256("other view"));
        (bytes32 first,) = _commit(a, 1);
        (bytes32 second,) = _commit(b, 2);
        R.Record memory legacy;
        legacy.publication = R.Publication(
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 17, 11, 0),
            0,
            keccak256("old snapshot"),
            1,
            "ipfs://old"
        );
        legacy.publisher = address(this);
        legacy.stateHash = keccak256("unchanged original prepared state");
        bytes32 token = probe.legacy(legacy, keccak256("original token consent"));
        (bytes32 next,) = _commit(a, 3);
        require(
            probe.head(a) == next && probe.head(b) == second
                && probe.head(legacy.publication.scope) == token,
            "three independent heads"
        );
        require(
            probe.aggregate(17).revision == 4
                && probe.record(next).publication.expectedPredecessor == first,
            "one aggregate/lineage"
        );
        require(
            probe.binding(token).profileId == 0 && probe.required(first).profileId == D.PROFILE,
            "legacy zero, immutable history"
        );
    }

    function testEveryBindingWordAndHistoricalAggregateAreAuthenticated() public {
        (bytes32 key,) = _commit(_scope(keccak256("a")), 1);
        bytes32 start = keccak256(
            abi.encode(key, keccak256("6529STREAM_ROUTER_VIEW_PRESERVATION_CONTENT_BINDINGS_V1"))
        );
        for (uint256 i; i < 30; ++i) {
            bytes32 slot = bytes32(uint256(start) + i);
            bytes32 old = vm.load(address(probe), slot);
            vm.store(address(probe), slot, bytes32(uint256(old) ^ 1));
            (bool ok,) = address(probe).staticcall(abi.encodeCall(probe.required, (key)));
            require(!ok, "every full binding/aggregate word bound");
            vm.store(address(probe), slot, old);
            require(probe.required(key).profileId == D.PROFILE, "exact restore");
        }
    }

    function testAbsentAndWrongProfileCannotReplaceBindingOrLegacyRecord() public {
        bytes32 absent = keccak256("absent");
        require(probe.binding(absent).profileId == 0, "absence explicit");
        ViewContentTestVm(address(vm)).expectRevert(R.InvalidScopedContentRoot.selector);
        probe.required(absent);
        (bytes32 key, B.Binding memory b) = _commit(_scope(keccak256("a")), 1);
        ViewContentTestVm(address(vm)).expectRevert(R.InvalidScopedContentRoot.selector);
        probe.retainAgain(key, b);
        b.profileId = keccak256("different profile");
        R.Record memory wrongProfile = _record(probe, _scope(keccak256("b")), b);
        ViewContentTestVm(address(vm)).expectRevert(R.InvalidScopedContentRoot.selector);
        probe.commit(wrongProfile, b, keccak256("consent"), false);
        require(probe.aggregate(17).revision == 1, "no second transition");
    }

    function testLateBindingFailureRollsBackOriginalHeadAggregateAndIdenticalRetry() public {
        StreamFinalityScope memory scope = _scope(keccak256("a"));
        B.Binding memory b = _binding(5);
        R.Record memory r = _record(probe, scope, b);
        bytes32 consent = keccak256("same approved op17 at unit boundary");
        ViewContentTestVm(address(vm)).expectRevert(R.InvalidScopedContentRoot.selector);
        probe.commit(r, b, consent, true);
        require(
            probe.head(scope) == 0 && probe.aggregate(17).revision == 0,
            "whole original transition rolled back"
        );
        bytes32 key = probe.commit(r, b, consent, false);
        require(probe.required(key).adoptionRecord == b.adoptionRecord, "identical retry");
    }

    function testHostAndChainDomainsCannotSubstituteRecord() public {
        StreamFinalityScope memory scope = _scope(keccak256("a"));
        B.Binding memory b = _binding(1);
        R.Record memory r = _record(probe, scope, b);
        ViewContentBindingProbe other = new ViewContentBindingProbe();
        ViewContentTestVm(address(vm)).expectRevert(R.InvalidScopedContentRoot.selector);
        other.commit(r, b, keccak256("consent"), false);
        bytes32 key = probe.commit(r, b, keccak256("consent"), false);
        vm.chainId(originalChain + 1);
        ViewContentTestVm(address(vm)).expectRevert(R.InvalidScopedContentRoot.selector);
        probe.required(key);
        vm.chainId(originalChain);
        require(probe.required(key).profileId == D.PROFILE, "original domain restored");
    }

    function testFuzzCompleteBindingAndHistoricalRecord(uint160 salt) public {
        (bytes32 key, B.Binding memory b) = _commit(_scope(keccak256("a")), uint256(salt));
        require(
            keccak256(abi.encode(probe.required(key))) == keccak256(abi.encode(b)),
            "all words exact"
        );
        _commit(_scope(keccak256("a")), uint256(salt) + 1);
        require(
            keccak256(abi.encode(probe.required(key))) == keccak256(abi.encode(b)),
            "historical aggregate retained"
        );
    }
}
