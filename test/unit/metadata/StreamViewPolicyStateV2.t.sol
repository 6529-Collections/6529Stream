// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamViewAdoptionState as Original
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionState.sol";
import {
    StreamViewAdoptionStateV2 as Policy
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionStateV2.sol";
import {
    StreamViewPolicyTypesV2 as T
} from "../../../smart-contracts/domains/metadata/StreamViewPolicyTypesV2.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Actual compiler-owned State/Store. Authority and source rows are explicit typed inputs;
/// this harness is not the original Router, Source.prepare or Artist op17 ceremony.
contract TaggedViewStateProbe {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function write(V.Record memory r, bytes32 consent, bool policy) external returns (bytes32) {
        return policy ? Policy.commit(core, r, consent) : Original.commit(core, r, consent);
    }

    function encoded(bytes32 key) external view returns (bytes memory) {
        return Original.encoded(key);
    }

    function profile(bytes32 key) external view returns (bytes32) {
        return Policy.profile(key);
    }

    function head(StreamFinalityScope memory scope) external view returns (bytes32) {
        return Original.state().heads[Original.subject(core, scope)];
    }

    function aggregate(uint256 cid) external view returns (V.Aggregate memory) {
        return Original.state().aggregates[cid];
    }

    function family(uint256 cid, bytes32 legacy) external view returns (bytes32) {
        return Original.wrap(core, cid, legacy, Original.state().aggregates[cid]);
    }

    function prior(bytes32 key) external view returns (uint64) {
        return Original.previousRevision(core, key);
    }

    function forceTag(bytes32 key, bytes32 tag) external {
        Original.state().profiles[key] = tag;
    }

    function rawTag(bytes32 key) external view returns (bytes32) {
        return Original.state().profiles[key];
    }

    function carrier(bytes32 key) external view returns (address, bytes32, uint32) {
        Original.Carrier storage c = Original.state().records[key];
        return (c.pointer, c.hash, c.size);
    }

    function candidate(V.Record memory r, bytes32 consent)
        external
        view
        returns (bytes32 key, bytes memory raw)
    {
        r.aggregate = Policy.next(core, r);
        r.revision = r.input.expectedPrevious == 0
            ? 1
            : Original.previousRevision(core, r.input.expectedPrevious) + 1;
        r.artistConsent = consent;
        r.adoptedAt = uint64(block.timestamp);
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                T.PROFILE,
                block.chainid,
                address(this),
                core,
                r
            )
        );
        r.recordHash = key;
        raw = abi.encode(r);
    }
}

contract StreamViewPolicyStateV2Test is CharacterizationTestBase {
    TaggedViewStateProbe private host;
    Store private store;
    address private constant CORE = address(0xC012E);
    bytes32 private constant CONSENT = keccak256("typed original op17 consent");
    bytes32 private constant LEGACY = keccak256("original RENDERER_CONFIG family");
    uint256 private originalChain;

    function setUp() public {
        vm.warp(1000);
        originalChain = block.chainid;
        store = new Store();
        host = new TaggedViewStateProbe(CORE);
    }

    function testOriginalV1RecordBytesAndRevisionZeroFamilyRemainExact() public {
        require(host.family(1, LEGACY) == LEGACY);
        V.Record memory r = _record(bytes32(uint256(8)), 0, false);
        bytes32 key = host.write(r, CONSENT, false);
        V.Record memory saved = abi.decode(host.encoded(key), (V.Record));
        require(host.profile(key) == 0 && saved.revision == 1);
        saved.recordHash = 0;
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_ADOPTION_RECORD_V1"),
                        originalChain,
                        address(host),
                        CORE,
                        saved
                    )
                )
        );
        require(
            key
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                        T.PROFILE,
                        originalChain,
                        address(host),
                        CORE,
                        saved
                    )
                )
        );
    }

    function testV2TagPreparedAggregateAndRecordDomainsAreIndependentLiterals() public {
        V.Record memory r = _record(bytes32(uint256(8)), 0, true);
        bytes32 prepared = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_PREPARED_STATE_V2"),
                T.PROFILE,
                r.input,
                r.sourceHash,
                r.actor,
                r.authorizationClass,
                r.grantCollectionId,
                r.grantRevision
            )
        );
        bytes32 subject = _subject(r.input.scope);
        bytes32 chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_AGGREGATE_V2"),
                T.PROFILE,
                originalChain,
                address(host),
                CORE,
                uint256(1),
                bytes32(0),
                uint64(1),
                subject,
                bytes32(0),
                prepared
            )
        );
        bytes32 key = host.write(r, CONSENT, true);
        V.Record memory saved = abi.decode(host.encoded(key), (V.Record));
        require(
            host.profile(key) == T.PROFILE && saved.aggregate.transitionChain == chain
                && saved.aggregate.revision == 1
        );
        saved.recordHash = 0;
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                        T.PROFILE,
                        originalChain,
                        address(host),
                        CORE,
                        saved
                    )
                )
        );
        require(
            host.family(1, LEGACY)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_RENDERER_CONFIG_WITH_VIEWS_V1"),
                        originalChain,
                        address(host),
                        CORE,
                        uint256(1),
                        LEGACY,
                        saved.aggregate
                    )
                )
        );
    }

    function testMixedV1ToV2ToV1UsesOneHeadAndPreservesAllHistory() public {
        bytes32 id = bytes32(uint256(8));
        V.Record memory r = _record(id, 0, false);
        bytes32 first = host.write(r, CONSENT, false);
        bytes memory old = host.encoded(first);
        bytes32 second = host.write(_record(id, first, true), keccak256("second consent"), true);
        bytes memory middle = host.encoded(second);
        bytes32 third = host.write(_record(id, second, false), keccak256("third consent"), false);
        require(
            host.head(r.input.scope) == third && host.prior(first) == 1 && host.prior(second) == 2
                && host.prior(third) == 3
        );
        require(
            host.profile(first) == 0 && host.profile(second) == T.PROFILE
                && host.profile(third) == 0
        );
        require(
            keccak256(host.encoded(first)) == keccak256(old)
                && keccak256(host.encoded(second)) == keccak256(middle)
        );
        require(host.aggregate(1).revision == 3);
    }

    function testTwoScopeHeadsShareAggregateAndStalePreviousRefuses() public {
        V.Record memory a = _record(bytes32(uint256(8)), 0, true);
        V.Record memory b = _record(bytes32(uint256(9)), 0, true);
        bytes32 first = host.write(a, CONSENT, true);
        bytes32 family = host.family(1, LEGACY);
        bytes32 second = host.write(b, CONSENT, true);
        require(
            host.head(a.input.scope) == first && host.head(b.input.scope) == second
                && host.family(1, LEGACY) != family && host.aggregate(1).revision == 2
        );
        vm.expectRevert(abi.encodeWithSelector(V.ViewAdoptionLineage.selector, bytes32(0), first));
        host.write(a, CONSENT, true);
        require(host.head(a.input.scope) == first && host.head(b.input.scope) == second);
    }

    function testMissingUnknownOrSwappedTagRefusesBothSuccessorProfiles() public {
        V.Record memory r = _record(bytes32(uint256(8)), 0, true);
        bytes32 key = host.write(r, CONSENT, true);
        bytes32[2] memory wrong = [bytes32(0), keccak256("unknown profile")];
        for (uint256 i; i < 2; ++i) {
            host.forceTag(key, wrong[i]);
            V.Record memory next = _record(r.input.scope.scopeId, key, false);
            vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
            host.write(next, CONSENT, false);
            next = _record(r.input.scope.scopeId, key, true);
            vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
            host.write(next, CONSENT, true);
            require(host.head(r.input.scope) == key && host.aggregate(1).revision == 1);
        }
        host.forceTag(key, T.PROFILE);
        require(host.prior(key) == 1);
        bytes32 legacy = host.write(_record(r.input.scope.scopeId, key, false), CONSENT, false);
        host.forceTag(legacy, T.PROFILE);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        host.prior(legacy);
        host.forceTag(legacy, 0);
        require(host.prior(legacy) == 2);
    }

    function testUnknownIsNotV1AndWrongContextCannotWritePolicyRecord() public {
        bytes32 unknown = keccak256("absent");
        vm.expectRevert(abi.encodeWithSelector(V.UnknownViewAdoption.selector, unknown));
        host.profile(unknown);
        V.Record memory r = _record(bytes32(uint256(8)), 0, false);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        host.write(r, CONSENT, true);
        require(host.head(r.input.scope) == 0 && host.aggregate(1).revision == 0);
        r = _record(bytes32(uint256(8)), 0, true);
        bytes32 key = host.write(r, CONSENT, true);
        require(host.profile(key) == T.PROFILE);
    }

    function testLateCarrierFailureRollsBackTagHeadAndAggregateThenExactRetry() public {
        V.Record memory first = _record(bytes32(uint256(8)), 0, false);
        bytes32 previous = host.write(first, CONSENT, false);
        V.Record memory r = _record(first.input.scope.scopeId, previous, true);
        (bytes32 expected, bytes memory raw) = host.candidate(r, CONSENT);
        (, address pointer) = store.publishChunk(raw);
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00fe");
        vm.expectRevert();
        host.write(r, CONSENT, true);
        (address absent,,) = host.carrier(expected);
        require(
            absent == address(0) && host.rawTag(expected) == 0
                && host.head(r.input.scope) == previous && host.aggregate(1).revision == 1
        );
        vm.etch(pointer, code);
        require(
            host.write(r, CONSENT, true) == expected && host.profile(expected) == T.PROFILE
                && host.prior(expected) == 2
        );
    }

    function testRecordDomainIncludesActualHostAndOriginalChain() public {
        V.Record memory r = _record(bytes32(uint256(8)), 0, true);
        bytes32 key = host.write(r, CONSENT, true);
        V.Record memory saved = abi.decode(host.encoded(key), (V.Record));
        saved.recordHash = 0;
        require(
            key
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                        T.PROFILE,
                        originalChain,
                        address(this),
                        CORE,
                        saved
                    )
                )
        );
        vm.chainId(originalChain + 1);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        host.prior(key);
        vm.chainId(originalChain);
        require(host.prior(key) == 1);
    }

    function _record(bytes32 id, bytes32 previous, bool policy)
        private
        view
        returns (V.Record memory r)
    {
        r.input.scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, id);
        r.input.viewId = keccak256("independent view declaration");
        r.input.viewRecordHash = keccak256("typed full declaration");
        r.input.expectedPrevious = previous;
        r.source.route.core = CORE;
        r.source.route.router = address(host);
        r.source.route.store = address(store);
        r.source.route.storeCodeHash = address(store).codehash;
        r.source.renderer.contextVersion = policy ? T.CONTEXT : V.CONTEXT;
        r.sourceHash = keccak256(abi.encode("typed complete source", id, policy));
        r.input.expectedSourceHash = r.sourceHash;
        r.actor = address(this);
        r.authorizationClass = 7;
        r.grantCollectionId = 1;
        r.grantRevision = 2;
    }

    function _subject(StreamFinalityScope memory scope) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                originalChain,
                CORE,
                scope.collectionId,
                uint8(scope.scopeType),
                scope.scopeId
            )
        );
    }
}
