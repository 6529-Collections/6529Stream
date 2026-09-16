// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import {
    StreamRoyaltyContinuityTypes as RC
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltyEconomicContinuity.sol";

/// @dev Explicit typed Core/Artist boundary; actual current graph is a separate integration suite.
contract ContinuityCoreFacts {
    address public artist;
    address public royalty;

    function select(address a, address r) external {
        artist = a;
        royalty = r;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id > 0 && id < 10;
    }

    function collectionNextSerial(uint256) external pure returns (uint256) {
        return 1;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        pure
        returns (bool, uint256, uint256, bool)
    {
        return (id == 41, uint256(1), uint256(41), true);
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address selected = kind == keccak256("ARTIST_REGISTRY") ? artist : royalty;
        return (
            selected,
            selected.codehash,
            false,
            bytes32(0),
            bytes4(0),
            address(0),
            1,
            bytes32(0),
            bytes32(0),
            1
        );
    }
}

contract ContinuityArtistFacts {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId || id == type(IERC165).interfaceId;
    }
    function attribution(uint256)
        external
        pure
        returns (IStreamCollectionArtistRegistry.Attribution memory empty)
    { }
}

interface ContinuityTestCalls {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Actual Resolver, Factory, Wallet, original ledgers and threshold Safe; typed Core/Artist/Executor-context boundary.
contract StreamRoyaltyEconomicContinuityTest is RevenueV1TestBase, OfficialSafeFixture {
    ContinuityCoreFacts private coreFacts;
    ContinuityArtistFacts private artistFacts;
    StreamSplitFactory private factory;
    StreamRoyaltyResolver private source;
    StreamRoyaltyResolver private target;
    OfficialSafe private runner;
    uint256[] private signingKeys;
    bytes32 private profile;
    address private wallet;
    bytes32 private constant ROYALTY = keccak256("ROYALTY_ERC2981");
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_ROYALTY_CONTINUITY_READ_GAS");
    uint256 private nextAction;

    function setUp() public {
        vm.warp(1_000_000);
        _revenueAuthority();
        StreamAssetPolicyRegistry policy = new StreamAssetPolicyRegistry(address(revenueAuthority));
        factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
        coreFacts = new ContinuityCoreFacts();
        artistFacts = new ContinuityArtistFacts(address(coreFacts));
        source = _resolver();
        target = _resolver();
        coreFacts.select(address(artistFacts), address(source));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(
            address(0xB0B), 1_000_000, keccak256("original recipient")
        );
        (profile, wallet) = factory.registerProfile(entries, keccak256("original profile metadata"));
        signingKeys.push(0xC0171);
        signingKeys.push(0xC0172);
        runner = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(signingKeys), 2, 0xC0173
        );
    }

    function _resolver() private returns (StreamRoyaltyResolver) {
        return new StreamRoyaltyResolver(
            IStreamCore(address(coreFacts)),
            factory,
            address(revenueAuthority),
            IStreamArtistAttribution(address(artistFacts))
        );
    }

    function _owner(StreamRoyaltyResolver r, bytes memory data) private {
        vm.prank(address(revenueAuthority));
        (bool ok, bytes memory why) = address(r).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(why, 32), mload(why)) }
    }

    function ownerCall(StreamRoyaltyResolver r, bytes calldata data) external {
        require(msg.sender == address(this), "fixture self");
        _owner(r, data);
    }

    function _state() private {
        _owner(source, abi.encodeCall(source.configureDefaultRoyalty, (profile, uint16(500))));
        _owner(source, abi.encodeCall(source.freezeDefaultRoyalty, ()));
        _owner(
            source,
            abi.encodeCall(source.configureCollectionRoyalty, (uint256(1), bytes32(0), uint16(0)))
        );
        _owner(source, abi.encodeCall(source.freezeCollectionRoyalty, (uint256(1))));
        _owner(
            source,
            abi.encodeCall(source.configureTokenRoyalty, (uint256(41), profile, uint16(700)))
        );
        _owner(source, abi.encodeCall(source.freezeTokenRoyalty, (uint256(41))));
        _owner(source, abi.encodeCall(source.electCollectionRoyaltyMode, (uint256(2), uint8(2))));
        _owner(source, abi.encodeCall(source.electCollectionRoyaltyMode, (uint256(3), uint8(1))));
    }

    function _reference(StreamRoyaltyResolver old, StreamRoyaltyResolver next)
        private
        view
        returns (RC.ManifestRef memory r)
    {
        RC.Header memory h = old.continuityHeader();
        r.expectedSourceHeaderHash = keccak256(abi.encode(h));
        r.uri = "ipfs://continuity-test-canonical-manifest";
        r.uriHash = keccak256(bytes(r.uri));
        r.schemaId = keccak256("STREAM_ROYALTY_CONTINUITY_MANIFEST_V1");
        r.canonicalizationId = keccak256("STREAM_ROYALTY_CONTINUITY_ABI_V1");
        r.contentHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_CONTINUITY_MANIFEST_V1"),
                block.chainid,
                address(old),
                address(old).codehash,
                address(next),
                address(coreFacts),
                address(factory),
                h,
                r.uri,
                r.uriHash,
                r.schemaId,
                r.canonicalizationId
            )
        );
    }

    function _prepare(
        StreamRoyaltyResolver old,
        StreamRoyaltyResolver next,
        RC.ManifestRef memory r,
        uint8 cls
    ) private {
        (bytes32 manifest, bytes32 scope, bytes32 prior, bytes32 after_) =
            next.previewEconomicContinuity(address(old), r);
        require(manifest == r.contentHash, "independent canonical manifest preimage");
        revenueAuthority.setCurrentAction(true, bytes32(++nextAction), cls, scope, prior, after_);
    }

    function _begin(StreamRoyaltyResolver old, StreamRoyaltyResolver next)
        private
        returns (bytes32 manifest)
    {
        RC.ManifestRef memory r = _reference(old, next);
        _prepare(old, next, r, 1);
        _owner(next, abi.encodeCall(next.beginEconomicContinuity, (address(old), r)));
        return r.contentHash;
    }

    function _complete(StreamRoyaltyResolver next) private {
        next.importEconomicContinuity(16, 64);
        next.completeEconomicContinuity();
    }

    function testCompleteProducerInventoryPreservesAllFrozenKeysAndOriginalHashes() public {
        _state();
        bytes32 manifest = _begin(source, target);
        RC.Header memory h = source.continuityHeader();
        require(
            h.protectedCount == 3 && h.electionCount == 2 && h.frozenStateHash != 0,
            "complete producer counts"
        );
        target.importEconomicContinuity(1, 1);
        require(
            !target.economicContinuityReady()
                && target.economicContinuityState().importedRoutes == 0,
            "all elections precede routes; no partially selected successor"
        );
        target.importEconomicContinuity(1, 1);
        require(target.economicContinuityState().importedRoutes == 1, "bounded next actual row");
        target.importEconomicContinuity(2, 0);
        target.completeEconomicContinuity();
        require(
            target.economicContinuityReady()
                && target.supportsEconomicContinuity(address(source), h.frozenStateHash, manifest),
            "only complete exact source supports cutover"
        );
        require(
            keccak256(abi.encode(target.continuityHeader())) == keccak256(abi.encode(h)),
            "complete roots equality"
        );
        for (uint256 i; i < 3; ++i) {
            RC.Route memory before_ = source.protectedEconomicRouteAt(i);
            RC.Route memory after_ = target.protectedEconomicRouteAt(i);
            require(
                keccak256(abi.encode(before_)) == keccak256(abi.encode(after_))
                    && after_.hashOrigin == address(source),
                "original config/revision/freeze and immutable origin bytes"
            );
            require(
                source.economicRouteHash(
                        address(coreFacts), ROYALTY, before_.scope, before_.scopeId
                    )
                    == target.economicRouteHash(
                            address(coreFacts), ROYALTY, before_.scope, before_.scopeId
                        ),
                "each exact protected route"
            );
        }
        (StreamArtistOnboardingTypes.AssignmentFact memory a,, bytes32 pa) =
            source.resolveRoyaltyAssignment(1, 41);
        (StreamArtistOnboardingTypes.AssignmentFact memory b,, bytes32 pb) =
            target.resolveRoyaltyAssignment(1, 41);
        require(
            a.assignmentHash == b.assignmentHash && pa == pb && a.resolver != b.resolver,
            "real new resolver returns original economic preimages"
        );
        require(
            target.collectionRoyalty(1).configured
                && target.collectionRoyalty(1).wallet == address(0)
                && target.collectionRoyalty(1).royaltyBps == 0
                && target.defaultRoyalty().royaltyBps == 500,
            "configured zero is copied, never treated as missing"
        );
        (address receiver, uint16 bps) =
            target.royaltyReceiverAndBps(address(coreFacts), 41, 41, 1, true);
        require(
            receiver == wallet && bps == 700,
            "retained burned-token identity keeps original royalty"
        );
    }

    function testOldElectionIsImmutableEvenBeforeAnySnapshot() public {
        require(
            source.frozenEconomicStateHash(address(coreFacts)) == 0, "no freeze or election yet"
        );
        _owner(source, abi.encodeCall(source.electCollectionRoyaltyMode, (uint256(2), uint8(2))));
        RC.Header memory h = source.continuityHeader();
        require(
            h.protectedCount == 0 && h.electionCount == 1 && h.frozenStateHash != 0,
            "explicit mode election is protected"
        );
        bytes32 manifest = _begin(source, target);
        _complete(target);
        require(
            target.supportsEconomicContinuity(address(source), h.frozenStateHash, manifest),
            "mode-only exact handoff"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltySnapshot.RoyaltyModeAlreadyElected.selector, uint256(2)
            )
        );
        this.ownerCall(
            target, abi.encodeCall(target.electCollectionRoyaltyMode, (uint256(2), uint8(1)))
        );
    }

    function testPartialImportBlocksEveryOriginalEconomicMutationAndPrematureCompletion() public {
        _state();
        _begin(source, target);
        target.importEconomicContinuity(1, 64);
        vm.expectRevert(abi.encodeWithSelector(RC.EconomicContinuityInProgress.selector));
        this.ownerCall(
            target, abi.encodeCall(target.configureDefaultRoyalty, (profile, uint16(900)))
        );
        vm.expectRevert(abi.encodeWithSelector(RC.EconomicContinuityInProgress.selector));
        this.ownerCall(
            target, abi.encodeCall(target.electCollectionRoyaltyMode, (uint256(4), uint8(2)))
        );
        vm.expectRevert(abi.encodeWithSelector(RC.InvalidEconomicContinuity.selector));
        target.completeEconomicContinuity();
        require(
            target.economicContinuityState().importedRoutes == 1,
            "failed mutation leaves exact cursor"
        );
        _complete(target);
        vm.expectRevert();
        this.ownerCall(
            target,
            abi.encodeCall(target.configureTokenRoyalty, (uint256(41), bytes32(0), uint16(0)))
        );
        require(target.tokenRoyalty(41).royaltyBps == 700, "import is not an unfreeze");
    }

    function testPristineUnselectedDestinationAndExactSourceFactoryAreMandatory() public {
        _state();
        RC.ManifestRef memory r = _reference(source, target);
        _owner(target, abi.encodeCall(target.configureDefaultRoyalty, (bytes32(0), uint16(0))));
        vm.expectRevert(abi.encodeWithSelector(RC.InvalidEconomicContinuity.selector));
        target.previewEconomicContinuity(address(source), r);
        StreamRoyaltyResolver fresh = _resolver();
        r = _reference(source, fresh);
        coreFacts.select(address(artistFacts), address(fresh));
        vm.expectRevert();
        fresh.previewEconomicContinuity(address(source), r);
        coreFacts.select(address(artistFacts), address(source));
        StreamSplitFactory other = new StreamSplitFactory(
            factory.assetPolicyRegistry(), address(revenueAuthority), _walletGasConfigs()
        );
        StreamRoyaltyResolver mismatch = new StreamRoyaltyResolver(
            IStreamCore(address(coreFacts)),
            other,
            address(revenueAuthority),
            IStreamArtistAttribution(address(artistFacts))
        );
        r = _reference(source, mismatch);
        vm.expectRevert();
        mismatch.previewEconomicContinuity(address(source), r);
    }

    function testExactManifestGovernanceClassAndActorCannotBeSubstituted() public {
        _state();
        RC.ManifestRef memory r = _reference(source, target);
        _prepare(source, target, r, 0);
        vm.expectRevert(abi.encodeWithSelector(RC.InvalidEconomicContinuity.selector));
        this.ownerCall(target, abi.encodeCall(target.beginEconomicContinuity, (address(source), r)));
        _prepare(source, target, r, 1);
        vm.expectRevert(abi.encodeWithSelector(RC.InvalidEconomicContinuity.selector));
        target.beginEconomicContinuity(address(source), r);
        r.uri = "ipfs://different-uncommitted-reference";
        vm.expectRevert();
        target.previewEconomicContinuity(address(source), r);
        require(
            target.economicContinuityState().status == 0,
            "invalid attempts never reserve destination"
        );
    }

    function testTransferredSharedOwnerCannotManufactureContinuityGovernance() public {
        _state();
        MockGovernedParameterAuthority impostor = new MockGovernedParameterAuthority(true);
        _owner(source, abi.encodeCall(source.transferOwnership, (address(impostor))));
        _owner(target, abi.encodeCall(target.transferOwnership, (address(impostor))));
        RC.ManifestRef memory r = _reference(source, target);
        (, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.previewEconomicContinuity(address(source), r);
        impostor.setCurrentAction(true, bytes32(uint256(9901)), 1, scope, oldHash, newHash);
        vm.expectRevert(abi.encodeWithSelector(RC.InvalidEconomicContinuity.selector));
        vm.prank(address(impostor));
        target.beginEconomicContinuity(address(source), r);
        require(target.economicContinuityState().status == 0, "impostor cannot reserve import");
        // Original Ownable authority remains intact, including restoration for the exact manifest.
        vm.prank(address(impostor));
        source.transferOwnership(address(revenueAuthority));
        vm.prank(address(impostor));
        target.transferOwnership(address(revenueAuthority));
        _prepare(source, target, r, 1);
        revenueAuthority.setMarkerResponseMode(
            MockGovernedParameterAuthority.MarkerResponseMode.NonCanonical
        );
        vm.expectRevert();
        this.ownerCall(target, abi.encodeCall(target.beginEconomicContinuity, (address(source), r)));
        require(
            target.economicContinuityState().status == 0, "malformed marker cannot reserve import"
        );
        revenueAuthority.setMarkerResponseMode(
            MockGovernedParameterAuthority.MarkerResponseMode.Canonical
        );
        this.ownerCall(target, abi.encodeCall(target.beginEconomicContinuity, (address(source), r)));
        require(
            target.economicContinuityState().status == 1,
            "original manifest succeeds with actual pinned authority"
        );
    }

    function testRecordedManifestEventEmitsItsExactCanonicalPreimage() public {
        _state();
        vm.recordLogs();
        bytes32 manifest = _begin(source, target);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(target)
                    && logs[i].topics[0]
                        == keccak256(
                            "EconomicContinuityBegun(uint16,address,bytes32,bytes32,bytes)"
                        )
            ) {
                (uint16 version, bytes memory canonical) = abi.decode(logs[i].data, (uint16, bytes));
                require(
                    version == 1 && logs[i].topics[1] == bytes32(uint256(uint160(address(source))))
                        && logs[i].topics[2] == manifest && keccak256(canonical) == manifest,
                    "full canonical manifest carrier"
                );
                ++count;
            }
        }
        require(count == 1, "one immutable begin receipt");
    }

    function testSourceTipChangeCannotCompleteOrRetargetPendingImport() public {
        _state();
        _begin(source, target);
        target.importEconomicContinuity(1, 64);
        _owner(source, abi.encodeCall(source.freezeCollectionRoyalty, (uint256(4))));
        vm.expectRevert(abi.encodeWithSelector(RC.EconomicContinuitySourceChanged.selector));
        target.importEconomicContinuity(16, 64);
        require(
            target.economicContinuityState().importedRoutes == 1
                && !target.economicContinuityReady(),
            "saved source commitment never silently advances"
        );
        vm.expectRevert();
        target.completeEconomicContinuity();
        require(
            !target.supportsEconomicContinuity(
                address(source),
                source.frozenEconomicStateHash(address(coreFacts)),
                target.continuityManifestHash()
            ),
            "incomplete candidate never qualifies"
        );
    }

    function testFullSignedSafeCopyRetryRestoresEveryOriginalCursorAndElection() public {
        _state();
        _begin(source, target);
        bytes memory data =
            abi.encodeCall(target.importEconomicContinuity, (uint256(16), uint256(64)));
        uint256 nonce = runner.nonce();
        bytes32 digest = runner.getTransactionHash(
            address(target), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signed = abi.encodeCall(
            runner.execTransaction,
            (
                address(target),
                uint256(0),
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(signingKeys, digest)
            )
        );
        ContinuityTestCalls(address(vm)).expectCall(address(target), data, 2);
        coreFacts.select(address(artistFacts), address(target));
        (bool ok, bytes memory why) = address(runner).call(signed);
        require(
            !ok && keccak256(why) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && runner.nonce() == nonce && target.continuityHeader().protectedCount == 0
                && target.continuityHeader().electionCount == 0,
            "actual failed Safe leaves whole copy and nonce untouched"
        );
        coreFacts.select(address(artistFacts), address(source));
        (ok, why) = address(runner).call(signed);
        require(
            ok && abi.decode(why, (bool)) && runner.nonce() == nonce + 1
                && target.continuityHeader().protectedCount == 3,
            "byte-identical original signed transaction copies original inventory exactly once"
        );
        target.completeEconomicContinuity();
    }

    function testChainedSuccessorKeepsFirstOriginAndFutureWritesHaveNewOrigin() public {
        _state();
        _begin(source, target);
        _complete(target);
        coreFacts.select(address(artistFacts), address(target));
        _owner(
            target,
            abi.encodeCall(target.configureCollectionRoyalty, (uint256(4), profile, uint16(800)))
        );
        _owner(target, abi.encodeCall(target.freezeCollectionRoyalty, (uint256(4))));
        StreamRoyaltyResolver next = _resolver();
        bytes32 manifest = _begin(target, next);
        _complete(next);
        require(
            next.protectedEconomicRouteAt(0).hashOrigin == address(source)
                && next.protectedEconomicRouteAt(3).hashOrigin == address(target),
            "per-route original domain persists across multiple real Resolver copies"
        );
        require(
            next.supportsEconomicContinuity(
                address(target), target.frozenEconomicStateHash(address(coreFacts)), manifest
            ),
            "current complete predecessor only"
        );
    }

    function testDedicatedGasInventoryExactDelayedRaiseAndMalformedAuthorityRefusal() public {
        bytes32[] memory ids = target.gasParameterIds();
        require(ids.length == 1 && ids[0] == READ_GAS, "fixed one-parameter inventory");
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
            target.gasParameterInfo(READ_GAS);
        require(
            value == 500000 && floor == 500000 && failure == 1 && revision == 1,
            "explicit constructor gas profile"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.gasParameterTransition(READ_GAS, 750000);
        revenueAuthority.setCurrentAction(true, bytes32(++nextAction), 1, scope, oldHash, newHash);
        vm.expectRevert();
        target.raiseGasParameter(READ_GAS, 750000);
        this.ownerCall(
            target, abi.encodeCall(target.raiseGasParameter, (READ_GAS, uint256(750000)))
        );
        require(target.gasParameter(READ_GAS) == 750000, "exact canonical delayed monotonic raise");
        vm.expectRevert();
        target.gasParameterTransition(READ_GAS, 1600000);
        (scope, oldHash, newHash) = target.gasParameterTransition(READ_GAS, 1000000);
        revenueAuthority.setCurrentAction(true, bytes32(++nextAction), 1, scope, oldHash, newHash);
        revenueAuthority.setResponseMode(MockGovernedParameterAuthority.ResponseMode.Oversized);
        vm.expectRevert();
        this.ownerCall(
            target, abi.encodeCall(target.raiseGasParameter, (READ_GAS, uint256(1000000)))
        );
        require(
            target.gasParameter(READ_GAS) == 750000,
            "malformed authority cannot consume or alter gas state"
        );
    }
}
