// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewMetadataFrozenBefore.sol";
import {
    StreamFinalityViewPreservationMetadataV1 as Metadata
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationMetadataV1.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

interface ViewMetadataVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract ViewMetadataProjectionProbe {
    function full(Native.Config memory c, StreamFinalityScope memory scope, bool locked, bool old)
        external
        view
        returns (bytes memory)
    {
        return old
            ? abi.encode(ViewMetadataFrozenBefore.current(c, scope, locked))
            : abi.encode(Metadata.current(c, scope, locked));
    }

    function root(Native.Config memory c, StreamFinalityScope memory scope, bool old)
        external
        view
        returns (bytes memory)
    {
        if (old) {
            (bytes32 a, uint64 b, bytes32 d) = ViewMetadataFrozenBefore.root(c, scope);
            return abi.encode(a, b, d);
        }
        (bytes32 a, uint64 b, bytes32 d) = Metadata.root(c, scope);
        return abi.encode(a, b, d);
    }

    function snapshot(Native.Config memory c, StreamFinalityScope memory scope, bool old)
        external
        view
        returns (bytes32)
    {
        return old ? ViewMetadataFrozenBefore.snapshot(c, scope) : Metadata.snapshot(c, scope);
    }

    function manifest(Native.Config memory c, StreamFinalityScope memory scope, bool old)
        external
        view
        returns (bytes memory)
    {
        if (old) {
            (bool a, bytes32 b) = ViewMetadataFrozenBefore.manifest(c, scope);
            return abi.encode(a, b);
        }
        (bool a, bytes32 b) = Metadata.manifest(c, scope);
        return abi.encode(a, b);
    }
}

contract ViewMetadataTypedBoundary {
    mapping(bytes32 => bytes) private replies;
    address private expectedHost;

    function setHost(address host) external {
        expectedHost = host;
    }

    function set(bytes memory input, bytes memory output) external {
        replies[keccak256(input)] = output;
    }

    fallback() external {
        require(msg.sender == expectedHost, "delegate host changed");
        bytes memory r = replies[keccak256(msg.data)];
        require(r.length != 0, "unexpected dependency/order");
        assembly ("memory-safe") { return(add(r, 32), mload(r)) }
    }
}

/// @notice Exact extraction parity with explicit typed Configuration/Snapshot/source boundaries.
/// @dev Real current-source/admission/lock ceremonies are not represented by the mocked dependency replies.
contract StreamFinalityViewMetadataCurrentTest is CharacterizationTestBase {
    ViewMetadataVm private constant cheats =
        ViewMetadataVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Native.Config private c;
    Configuration.Context private x;
    Snapshots.Evidence private evidence;
    T.Dependencies private rd;
    S.Dependencies private sd;
    StreamFinalityScope private scope;
    S.Receipt private receipt;
    Root.Record private record_;
    Binding.Binding private binding_;
    C.Configuration private checkpoint;
    StreamScopeMembershipFacts private membership;
    ViewMetadataProjectionProbe private probe;
    ViewMetadataTypedBoundary private router;
    ViewMetadataTypedBoundary private snapshots;
    ViewMetadataTypedBoundary private checkpointHost;
    ViewMetadataTypedBoundary private membershipHost;
    bytes32 private constant ROOT = keccak256("original actual Router head boundary");

    function setUp() public {
        vm.warp(900);
        probe = new ViewMetadataProjectionProbe();
        router = new ViewMetadataTypedBoundary();
        snapshots = new ViewMetadataTypedBoundary();
        checkpointHost = new ViewMetadataTypedBoundary();
        membershipHost = new ViewMetadataTypedBoundary();
        router.setHost(address(probe));
        snapshots.setHost(address(probe));
        checkpointHost.setHost(address(probe));
        membershipHost.setHost(address(probe));
        c.chainId = block.chainid;
        c.targets[0] = address(0xc0);
        c.targets[2] = address(router);
        c.targets[3] = address(membershipHost);
        c.readGas = 300000;
        c.sourceGas = 5000000;
        c.componentSourceGas = 400000;
        scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 71, 0, bytes32(uint256(83)));
        x.snapshots.snapshots = address(snapshots);
        rd.chainId = c.chainId;
        rd.targets[0] = c.targets[0];
        rd.targets[4] = address(router);
        rd.targets[5] = address(snapshots);
        rd.codeHashes[5] = address(snapshots).codehash;
        rd.readGas = c.readGas;
        rd.sourceGas = 500000;
        sd.targets[6] = address(checkpointHost);
        sd.codeHashes[6] = address(checkpointHost).codehash;
        sd.targets[7] = address(0xa7);
        sd.codeHashes[7] = keccak256("output runtime");
        receipt.recordHash = keccak256("snapshot record");
        receipt.revision = 3;
        receipt.manifestHash = keccak256("full manifest");
        receipt.sourceHash = keccak256("full source");
        evidence.receipt = receipt;
        evidence.inputHash = keccak256("full snapshot input");
        evidence.source.scope = scope;
        evidence.source.membership.tokenCount = 17;
        evidence.source.membership.membershipHash = keccak256("membership");
        evidence.source.artist.artistId = keccak256("actual artist");
        evidence.source.artist.bindingGeneration = 3;
        evidence.source.artist.bindingHash = keccak256("binding");
        evidence.source.outputs.header.contentRoot = keccak256("complete ordered root");
        evidence.source.outputs.header.checkpointId = keccak256("checkpoint");
        evidence.source.outputs.header.checkpointStateHash = keccak256("checkpoint state");
        evidence.source.outputs.recordHash = keccak256("output record");
        evidence.source.outputs.carrier.contentHash = keccak256("full index bytes");
        evidence.source.outputs.partChain = keccak256("all parts");
        evidence.source.adoption.adoption.recordHash = keccak256("adoption");
        evidence.source.entropy.policyChainHash = keccak256("all policies");
        evidence.source.adoption.preservation.liveRenderer = address(0xb0);
        evidence.source.adoption.preservation.liveRendererRuntimeHash = keccak256("live runtime");
        evidence.source.adoption.preservation.preservationAttribution = address(0xb1);
        evidence.source.adoption.preservation.preservationAttributionRuntimeHash =
            keccak256("attr runtime");
        checkpoint.serving = address(0xb2);
        checkpoint.servingCodeHash = keccak256("serving runtime");
        checkpoint.servingConfigurationHash = keccak256("serving config");
        record_.publication.scope = scope;
        record_.publication.snapshotRecordHash = receipt.recordHash;
        record_.publication.snapshotRevision = receipt.revision;
        record_.publication.manifestURI = "https://preservation.invalid/complete";
        record_.snapshotHost = address(snapshots);
        record_.snapshotCodeHash = address(snapshots).codehash;
        record_.snapshotManifestHash = receipt.manifestHash;
        record_.snapshotSourceHash = receipt.sourceHash;
        record_.contentRoot = evidence.source.outputs.header.contentRoot;
        record_.leafCount = 17;
        record_.outputManifestHash = evidence.source.outputs.carrier.contentHash;
        record_.artistId = evidence.source.artist.artistId;
        record_.bindingGeneration = 3;
        record_.bindingHash = evidence.source.artist.bindingHash;
        record_.publisher = address(0xca);
        record_.authorizationClass = 7;
        record_.grantRevision = 4;
        record_.routeHash = keccak256("current route");
        binding_ = _literalBinding();
        _rehash();
        membership.scopeSubject =
            StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope);
        membership.tokenCount = 17;
        membership.membershipHash = keccak256("membership");
        membership.sourceRecordHash = keccak256("sealed selection");
        membership.scopeManifestHash = keccak256("scope manifest");
        _install();
    }

    function _literalBinding() private view returns (Binding.Binding memory b) {
        b.profileId = keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_V1");
        b.outputProfile = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1");
        b.adoptionRecord = keccak256("adoption");
        b.adoptionProfile = Policy.PROFILE;
        b.membershipHash = keccak256("membership");
        b.policyChainHash = keccak256("all policies");
        b.checkpoint = address(checkpointHost);
        b.checkpointCodeHash = address(checkpointHost).codehash;
        b.checkpointRecord = keccak256("checkpoint");
        b.checkpointStateHash = keccak256("checkpoint state");
        b.outputManifest = address(0xa7);
        b.outputManifestCodeHash = keccak256("output runtime");
        b.outputManifestRecord = keccak256("output record");
        b.manifestIndexHash = keccak256("full index bytes");
        b.partChain = keccak256("all parts");
        b.preservationRenderer = address(0xb2);
        b.preservationRendererCodeHash = keccak256("serving runtime");
        b.preservationConfigurationHash = keccak256("serving config");
        b.liveRenderer = address(0xb0);
        b.liveRendererCodeHash = keccak256("live runtime");
        b.preservationAttribution = address(0xb1);
        b.preservationAttributionCodeHash = keccak256("attr runtime");
        b.leafSchemaHash = keccak256(
            bytes(
                '{"name":"STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1","version":1,"encoding":"abi.encode(keccak256(6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1),keccak256(6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1),chainId,core,fullScope,adoptionRecord,complete31WordOutput)","node":"keccak256(abi.encode(keccak256(6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1),left,right))","order":"Complete strictly ascending token identities; zero-based row index; pair adjacent left/right without sorting and promote odd node unchanged","scope":"VIEW membership scopeId differs from viewId; full original adopted record binds actual view identity","meaning":"Separately named preservation JSON/HTML with only sanction projection; not original CMC six-field leaf or live outputRoot"}'
            )
        );
        b.rootSchemaHash = 0x71b098d934ddbb3cabec5596e8062caafe5ae9dfed667070ec1de6756bf52d3e;
        b.rootCanonicalizationHash =
        0x4f00c5f5b949500583ddd0e68c30ed863c4496e76dca14b44c963c443eca8103;
        b.snapshotSchemaHash = 0x93318b938a22ba634ffc52b9f726deefd427b96a849d86bf6ed18c6827561b2e;
        b.snapshotProfileHash = 0x2ca42835d28a332a6607518127b566a8ce427f955fb08f7650c00180e15969f4;
        b.snapshotCanonicalizationHash =
        0xa749d9fc1982426d543e3efb2fdf7782fb2cf2a5f4ce723c3b1848f094efc032;
    }

    function _rehash() private {
        Root.Record memory r = record_;
        r.stateHash = 0;
        r.artistConsent = 0;
        r.publishedAt = 0;
        record_.stateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_STATE_V1"),
                c.chainId,
                address(router),
                c.targets[0],
                r,
                binding_
            )
        );
        record_.artistConsent = keccak256("actual op17 boundary");
        record_.publishedAt = 800;
    }

    function _install() private {
        cheats.mockCall(
            address(Configuration),
            abi.encodeWithSelector(Configuration.resolve.selector, c),
            abi.encode(x)
        );
        cheats.mockCall(
            address(InventorySources),
            abi.encodeWithSelector(InventorySources.referenceBindings.selector, x.inventory),
            abi.encode(rd)
        );
        cheats.mockCall(
            address(InventorySources),
            abi.encodeWithSelector(InventorySources.snapshotBindings.selector, x.inventory),
            abi.encode(sd)
        );
        Snapshots.Evidence memory e = evidence;
        cheats.mockCall(
            address(Snapshots),
            abi.encodeWithSelector(
                Snapshots.requireCurrent.selector,
                x.snapshots,
                scope,
                receipt.recordHash,
                receipt.revision
            ),
            abi.encode(e)
        );
        e.locked = true;
        e.lockHash = keccak256("class2 lock");
        cheats.mockCall(
            address(Snapshots),
            abi.encodeWithSelector(
                Snapshots.requireLocked.selector,
                x.snapshots,
                scope,
                receipt.recordHash,
                receipt.revision
            ),
            abi.encode(e)
        );
        snapshots.set(abi.encodeCall(SnapshotHost.currentSnapshot, (scope)), abi.encode(receipt));
        router.set(abi.encodeCall(Root.scopedContentRootHead, (scope)), abi.encode(ROOT));
        router.set(abi.encodeCall(Root.scopedContentRootRecord, (ROOT)), abi.encode(record_));
        router.set(
            abi.encodeCall(Binding.viewPreservationContentRootBinding, (ROOT)), abi.encode(binding_)
        );
        router.set(
            abi.encodeCall(Root.scopedTokenContentRoot, (scope)),
            abi.encode(record_.contentRoot, record_.leafCount, OutputDefinitions.LEAF)
        );
        checkpointHost.set(abi.encodeCall(Checkpoint.configuration, ()), abi.encode(checkpoint));
        membershipHost.set(
            abi.encodeWithSignature(
                "requireScopeMembership((uint8,uint256,uint256,bytes32))", scope
            ),
            abi.encode(membership)
        );
    }

    function _same(bool locked) private view returns (bytes memory result) {
        result = probe.full(c, scope, locked, false);
        assertEq(
            keccak256(result),
            keccak256(probe.full(c, scope, locked, true)),
            "entire Evidence differs"
        );
    }

    function _refuse(bytes memory expected) private view {
        for (uint256 i; i < 2; ++i) {
            (bool ok, bytes memory out) =
                address(probe).staticcall(abi.encodeCall(probe.full, (c, scope, false, i == 1)));
            assertFalse(ok, "accepted invalid metadata");
            assertEq(keccak256(out), keccak256(expected), "exact prior error");
        }
    }

    function testCompleteEvidenceAndBothLockBranchesRetainLiteralRootBinding() public view {
        for (uint256 i; i < 2; ++i) {
            Metadata.Evidence memory e = abi.decode(_same(i == 1), (Metadata.Evidence));
            assertEq(e.snapshot.locked, i == 1, "branch");
            assertEq(
                keccak256(abi.encode(e.root.contentBinding)),
                keccak256(abi.encode(_literalBinding())),
                "literal28word"
            );
            assertEq(e.root.contentRootRecordHash, ROOT, "head");
            assertEq(e.root.contentRoot.stateHash, record_.stateHash, "state");
        }
    }

    function testOriginalRootSnapshotAndManifestEndpointsRemainExact() public view {
        assertEq(
            keccak256(probe.root(c, scope, false)), keccak256(probe.root(c, scope, true)), "root"
        );
        assertEq(probe.snapshot(c, scope, false), receipt.manifestHash, "snapshot literal");
        assertEq(probe.snapshot(c, scope, true), receipt.manifestHash, "old snapshot");
        bytes memory expected = abi.encode(true, membership.scopeManifestHash);
        assertEq(
            keccak256(probe.manifest(c, scope, false)), keccak256(expected), "manifest literal"
        );
        assertEq(keccak256(probe.manifest(c, scope, true)), keccak256(expected), "old manifest");
    }

    function testAll28BindingWordsRefuseThenExactRestoration() public {
        bytes memory saved = abi.encode(binding_);
        for (uint256 i; i < 28; ++i) {
            bytes memory changed = abi.encode(binding_);
            assembly ("memory-safe") {
                let p := add(add(changed, 32), mul(i, 32))
                mstore(p, xor(mload(p), 1))
            }
            router.set(abi.encodeCall(Binding.viewPreservationContentRootBinding, (ROOT)), changed);
            _refuse(abi.encodeWithSelector(T.InvalidViewPreservationReference.selector));
            router.set(abi.encodeCall(Binding.viewPreservationContentRootBinding, (ROOT)), saved);
            _same(false);
        }
    }

    function testCanonicalRootAndPreparedStateRefuseThenRetry() public {
        bytes memory input = abi.encodeCall(Root.scopedContentRootRecord, (ROOT));
        router.set(input, bytes.concat(abi.encode(record_), bytes32(0)));
        _refuse(
            abi.encodeWithSelector(T.ViewPreservationReferenceDependency.selector, address(router))
        );
        record_.stateHash = bytes32(uint256(record_.stateHash) ^ 1);
        router.set(input, abi.encode(record_));
        _refuse(abi.encodeWithSelector(T.InvalidViewPreservationReference.selector));
        _rehash();
        _install();
        _same(false);
    }

    function testScopeAndConfigurationFailureOrderIsUnchanged() public {
        bytes memory failure = abi.encodeWithSignature("TypedConfigurationFailure()");
        cheats.mockCallRevert(
            address(Configuration),
            abi.encodeWithSelector(Configuration.resolve.selector, c),
            failure
        );
        _refuse(failure);
        scope.scopeType = StreamFinalityScopeType.COLLECTION;
        _refuse(abi.encodeWithSelector(Configuration.InvalidViewFinalityConfiguration.selector));
        scope.scopeType = StreamFinalityScopeType.VIEW;
        cheats.clearMockedCalls();
        _install();
        _same(false);
    }

    function testRootScopeSnapshotAndTimeDriftWithValidRehashedStateStillRefuse() public {
        Root.Record memory saved = record_;
        record_.publication.snapshotRevision += 1;
        _rehash();
        _install();
        _refuse(abi.encodeWithSelector(T.InvalidViewPreservationReference.selector));
        record_ = saved;
        record_.publication.scope.scopeId = bytes32(uint256(12));
        _rehash();
        _install();
        _refuse(abi.encodeWithSelector(T.InvalidViewPreservationReference.selector));
        record_ = saved;
        record_.publishedAt = 901;
        router.set(abi.encodeCall(Root.scopedContentRootRecord, (ROOT)), abi.encode(record_));
        _refuse(abi.encodeWithSelector(T.InvalidViewPreservationReference.selector));
        record_ = saved;
        _install();
        _same(false);
    }

    function testFuzzRetainedDynamicManifestAndNonProjectedSourceBytes(bytes32 salt, uint16 count)
        public
    {
        record_.publication.manifestURI =
            string(abi.encodePacked("https://preservation.invalid/", salt));
        evidence.source.outputs.header.tokenCount = uint64(count);
        evidence.source.adoption.adoption.source.payloadHash = salt;
        _rehash();
        _install();
        _same(false);
        _same(true);
    }

    function assertEq(bytes32 a, bytes32 b, string memory why) private pure {
        require(a == b, why);
    }

    function assertEq(bool a, bool b, string memory why) private pure {
        require(a == b, why);
    }

    function assertFalse(bool a, string memory why) private pure {
        require(!a, why);
    }
}
