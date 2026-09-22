// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PreservationOutputBoundary } from "../../helpers/scoped-preservation-boundaries/StreamPreservationPolicyContentCheckpointV1Boundaries.sol";

import "./StreamScopedPolicyContentCheckpointV2.t.sol";
import {
    StreamPreservationPolicyContentCheckpointV1 as PreservationCollection
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamScopedPreservationPolicyContentCheckpointV1 as PreservationScoped
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Preservation
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as PreservationTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2 as CollectionFactory
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamRendererCalls as PreservationCalls
} from "../../../smart-contracts/domains/metadata/StreamRendererCalls.sol";

import {
    IERC165 as PreservationERC165
} from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import {
    StreamScopeMembershipFacts as PreservationMembership
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";

/// @notice Real complete membership/selection, original entropy policy and factory/current route,
/// Renderer/Router/Metadata/Schema/Store and terminal readiness; typed inherited Core/Artist/module
/// admission boundaries plus the explicit new preservation producer and Registry admission boundary.
/// No actual new preservation implementation, governed admission, full finality or runtime claim.
abstract contract PreservationPolicyContentFixtureV1 is ScopedPolicyContentFixtureV2 {
    struct Capture {
        Preservation host;
        PreservationOutputBoundary producer;
        PreservationOutputBoundary[] producers;
        bytes32 selection;
        bytes32 id;
        StreamFinalityScope scope;
    }

    function _preservationFixture(uint8 terminalStatus) internal {
        require(terminalStatus == 1 || terminalStatus == 2);
        scopedModules = ScopedPolicyOutputModulesBoundary(
            _artistArtifactCreate(
                "test/helpers/scoped-preservation-boundaries/StreamScopedPolicyContentCheckpointV2Boundaries.sol:ScopedPolicyOutputModulesBoundary",
                abi.encode(address(metadata))
            )
        );
        core.setPointer(keccak256("MODULE_REGISTRY"), address(scopedModules));
        MockEntropyRoleRegistry roles = MockEntropyRoleRegistry(
            _artistArtifactCreate(
                "test/mocks/MockEntropyRoleRegistry.sol:MockEntropyRoleRegistry",
                abi.encode(address(this))
            )
        );
        terminalCoordinator = _preservationNative(roles);
        EntropyCollectionPolicyArtistFixture policyArtist = EntropyCollectionPolicyArtistFixture(
            _artistArtifactCreate(
                "test/unit/entropy/EntropyCollectionPolicyFixtures.sol:EntropyCollectionPolicyArtistFixture",
                abi.encode(address(core))
            )
        );
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(policyArtist));
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(terminalCoordinator));
        EP.PolicyInput memory policy;
        policy.renderRequirement = EP.RenderRequirement.NOT_REQUIRED;
        if (terminalStatus == 2) {
            (,, address provider,,) = terminalCoordinator.entropyPolicyFrozen(1);
            policy.mode = EP.Mode.ASYNC;
            policy.provider = provider;
            policy.collectionSalt = keccak256("scoped native salt");
            policy.publicRequests = true;
            policy.timeoutBlocks = 10;
            policy.reveal = IStreamRevealFeeEscrow.CollectionRevealPolicy(
                true, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0
            );
        }
        (bytes32 scope, bytes32 old, bytes32 next, bytes32 content) =
            EP(address(terminalCoordinator)).collectionEntropyPolicyTransition(1, policy);
        policyArtist.approve(
            1,
            address(terminalCoordinator),
            keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"),
            content,
            keccak256("original scoped entropy op17")
        );
        this.setCurrentAction(true, keccak256("original scoped policy action"), 1, scope, old, next);
        EP(address(terminalCoordinator)).configureCollectionEntropyPolicy(1, policy);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        core.setEntropy(address(terminalCoordinator));
        (renderer, terminalVersions) = _preservationRenderer(address(terminalCoordinator));
        versions = terminalVersions;
        _scopedPointer(
            keccak256("COLLECTION_METADATA"),
            address(metadata),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        _scopedPointer(
            keccak256("METADATA_ROUTER"), address(router), type(IStreamMetadataRouter).interfaceId
        );
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata,
                (
                    1,
                    "Scoped policy output",
                    "Two original terminal tokens under one selected renderer",
                    "data:image/png;base64,iVBORw0KGgo=",
                    ""
                )
            )
        );
        _activate();
        _scopedToken(91, 1, 2, address(terminalCoordinator));
        _scopedToken(92, 2, 2, address(terminalCoordinator));
        core.setMinted(2);
        vm.prank(address(core));
        terminalCoordinator.onTokenMinted(1, 91, address(this), keccak256("original terminal mint"));
        vm.prank(address(core));
        terminalCoordinator.onTokenMinted(
            1, 92, address(this), keccak256("second original terminal mint")
        );
        S.ConfigInput memory input = _input(R.MetadataMode.ONCHAIN, true);
        _approve(0, input, keccak256("original scoped collection config consent"));
        router.setCollectionMetadataConfig(1, input);
        StreamCollectionTokenInventory indexedTokens = StreamCollectionTokenInventory(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamCollectionTokenInventory.sol:StreamCollectionTokenInventory",
                abi.encode(
                    address(core),
                    address(executor),
                    _scopedGas("TOKEN_INVENTORY_CORE_READ_GAS", 100000, 1)
                )
            )
        );
        uint256[] memory ids = _preservationIds();
        indexedTokens.appendCollectionTokens(1, ids);
        _scopedDocument("RAW_BYTES", true, bytes(schemas.RAW_BYTES_DEFINITION()));
        _scopedDocument(
            "STREAM_SCOPE_MEMBERSHIP_V1",
            false,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-v1.schema.json"))
        );
        _scopedDocument(
            "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
            true,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-abi-v1.json"))
        );
        (scope, old, next) = metadata.recordTypeTransition(
            keccak256("SCOPE_MEMBERSHIP"),
            keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"),
            384
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.admitRecordType,
                (
                    keccak256("SCOPE_MEMBERSHIP"),
                    keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"),
                    uint16(384)
                )
            ),
            scope,
            old,
            next
        );
        scopedMembership = StreamFinalityScopeMembership(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamFinalityScopeMembership.sol:StreamFinalityScopeMembership",
                abi.encode(
                    address(core),
                    address(metadata),
                    address(indexedTokens),
                    address(executor),
                    _scopedGas("SCOPE_MEMBERSHIP_READ_GAS", 500000, 1)
                )
            )
        );
        scopedSelections = StreamStaticSelectionCheckpoint(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint",
                abi.encode(
                    address(core),
                    address(router),
                    address(scopedMembership),
                    address(executor),
                    _scopedGas("STATIC_CHECKPOINT_READ_GAS", 2000000, 1)
                )
            )
        );
        scopedSources = StreamFinalityCoordinatorInventory(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol:StreamFinalityCoordinatorInventory",
                abi.encode(address(core), address(scopedMembership), 100000, 2000000)
            )
        );
        scopedFactory = Factory(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol:StreamFinalityScopedEntropyPolicySourceFactoryV2",
                abi.encode(_scopedDependencies())
            )
        );
    }

    function _preservationNative(MockEntropyRoleRegistry roles)
        internal
        returns (StreamEntropyCoordinator n)
    {
        n = StreamEntropyCoordinator(
            _artistArtifactCreate(
                "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator",
                abi.encode(
                    StreamEntropyCoordinator.DeploymentConfig(
                        address(core),
                        address(this),
                        address(roles),
                        EntropyTimeTestConfigs.parameters(),
                        keccak256("deployment"),
                        "ipfs://scoped-native-policy",
                        keccak256("native policy manifest")
                    )
                )
            )
        );
        MockStreamEntropyProvider provider = MockStreamEntropyProvider(
            _artistArtifactCreate(
                "test/mocks/MockStreamEntropyProvider.sol:MockStreamEntropyProvider",
                abi.encode(address(n))
            )
        );
        _admitEntropyProvider(address(n), address(provider));
        n.configureCollection(1, address(provider), keccak256("scoped native salt"), true, 10);
        n.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
    }

    function _preservationRenderer(address nativeEntropy)
        internal
        returns (StreamRendererV1 r, ScopedPolicyOutputVersionsBoundary v)
    {
        StreamRendererV1.Deployment memory d;
        (d.sources,) = renderer.sourceBindings();
        d.sources.entropy = nativeEntropy;
        d.executor = address(executor);
        d.manifest = renderer.rendererManifest();
        d.readGas = _scopedGas("METADATA_DEPENDENCY_READ_GAS", 2000000, 2);
        d.attributionGas = _scopedGas("STATIC_ATTRIBUTION_GAS", 8000000, 1);
        r = StreamRendererV1(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamRendererV1.sol:StreamRendererV1",
                abi.encode(d)
            )
        );
        v = ScopedPolicyOutputVersionsBoundary(
            _artistArtifactCreate(
                "test/helpers/scoped-preservation-boundaries/StreamScopedPolicyContentCheckpointV2Boundaries.sol:ScopedPolicyOutputVersionsBoundary",
                abi.encode(address(executor), address(schemas), address(r))
            )
        );
        v.setAdmitted(true);
        scopedModules.admit(address(v));
    }

    function _preservationIds() internal pure returns (uint256[] memory ids) {
        ids = new uint256[](2);
        ids[0] = 91;
        ids[1] = 92;
    }

    function _scope(uint8 kind) internal returns (StreamFinalityScope memory) {
        return kind == 0
            ? StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
            : _scopedScope(kind);
    }

    function _capture(StreamFinalityScope memory scope, bool admitted)
        internal
        returns (Capture memory c)
    {
        c.scope = scope;
        bytes32 plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        address source;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            CollectionFactory factory = CollectionFactory(
                _artistArtifactCreate(
                    "smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol:StreamFinalityEntropyPolicySourceFactoryV2",
                    abi.encode(_scopedDependencies())
                )
            );
            source = factory.prepareSourceSet(scope);
        } else {
            source = scopedFactory.prepareSourceSet(scope);
        }
        c.selection = scopedSelections.begin(scope);
        scopedSelections.append(c.selection, 16);
        uint256 count = scopedSelections.checkpoint(c.selection).tokenCount;
        c.producers = new PreservationOutputBoundary[](count);
        for (uint256 i; i < count; ++i) {
            Selection.TokenSelection memory row = scopedSelections.selectionAt(c.selection, i);
            c.producers[i] = PreservationOutputBoundary(
                _artistArtifactCreate(
                    "test/helpers/scoped-preservation-boundaries/StreamPreservationPolicyContentCheckpointV1Boundaries.sol:PreservationOutputBoundary",
                    abi.encode(
                        address(core), address(router), row.selection.renderer, address(attribution)
                    )
                )
            );
            c.producers[i].setBytes(
                row.tokenId,
                string(abi.encodePacked(" ", router.tokenJSON(row.tokenId))),
                router.tokenHTML(row.tokenId)
            );
        }
        c.producer = c.producers[0];
        StreamTerminalEntropyReadiness ready = StreamTerminalEntropyReadiness(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol:StreamTerminalEntropyReadiness",
                abi.encode(address(core), address(router), source, 2000000, 6000000)
            )
        );
        c.host = _deploy(
            scope.scopeType == StreamFinalityScopeType.COLLECTION, source, address(ready)
        );
        if (admitted) _admitAll(c);
        c.id = c.host.begin(c.selection, keccak256("preservation candidate"));
    }

    function _deploy(bool collection, address source, address ready)
        internal
        returns (Preservation)
    {
        if (collection) {
            return Preservation(
                address(
                    PreservationCollection(
                        _artistArtifactCreate(
                            "smart-contracts/domains/finality/StreamPreservationPolicyContentCheckpointV1.sol:StreamPreservationPolicyContentCheckpointV1",
                            abi.encode(
                                address(scopedSelections),
                                source,
                                ready,
                                address(executor),
                                _scopedGas("STATIC_CONTENT_READ_GAS", 8000000, 2),
                                _scopedGas("STATIC_CONTENT_RENDER_GAS", 16000000, 2)
                            )
                        )
                    )
                )
            );
        }
        return Preservation(
            address(
                PreservationScoped(
                    _artistArtifactCreate(
                        "smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV1.sol:StreamScopedPreservationPolicyContentCheckpointV1",
                        abi.encode(
                            address(scopedSelections),
                            source,
                            ready,
                            address(executor),
                            _scopedGas("STATIC_CONTENT_READ_GAS", 8000000, 2),
                            _scopedGas("STATIC_CONTENT_RENDER_GAS", 16000000, 2)
                        )
                    )
                )
            )
        );
    }

    function _admission(Capture memory c, uint256 index)
        internal
        view
        returns (PreservationTypes.Admission memory a)
    {
        Selection.TokenSelection memory row = scopedSelections.selectionAt(c.selection, index);
        a = PreservationTypes.Admission(
            row.selection.registry,
            row.selection.registryCodeHash,
            row.selection.versionKey,
            keccak256(abi.encode("typed preservation registration", row.selection.versionKey)),
            keccak256("typed complete read roster"),
            keccak256("typed source analysis"),
            keccak256("typed golden vectors")
        );
    }

    function _admissionInput(Capture memory c, uint256 index) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            "requirePreservation(bytes32,address,bytes32)",
            scopedSelections.selectionAt(c.selection, index).selection.versionKey,
            address(c.producers[index]),
            keccak256("6529STREAM_PRESERVATION_RENDER_V1")
        );
    }

    function _setAdmission(Capture memory c, uint256 index, bytes memory encoded) internal {
        StaticRouteVm(address(vm))
            .mockCall(
                scopedSelections.selectionAt(c.selection, index).selection.registry,
                _admissionInput(c, index),
                encoded
            );
    }

    function _admitAll(Capture memory c) internal {
        uint256 count = scopedSelections.checkpoint(c.selection).tokenCount;
        for (uint256 i; i < count; ++i) {
            _setAdmission(c, i, abi.encode(_binding(c, i), _admission(c, i)));
        }
    }

    function _payload(Capture memory c)
        internal
        view
        returns (Preservation.Payload[] memory values)
    {
        uint256 count = scopedSelections.checkpoint(c.selection).tokenCount;
        values = new Preservation.Payload[](count);
        for (uint256 i; i < count; ++i) {
            uint256 token = scopedSelections.selectionAt(c.selection, i).tokenId;
            values[i] = Preservation.Payload(
                token,
                address(c.producers[i]),
                hex"89504e470d0a1a0a",
                bytes(c.producers[i].preservationTokenHTML(token))
            );
        }
    }

    function _history(Capture memory c) internal view returns (bytes32 h) {
        Preservation.Plan memory p = c.host.checkpoint(c.id);
        h = keccak256(abi.encode(p));
        for (uint256 i; i < p.nextIndex; ++i) {
            h = keccak256(abi.encode(h, c.host.outputAt(c.id, i)));
        }
    }

    function _binding(Capture memory c, uint256 index)
        internal
        view
        returns (PreservationTypes.Binding memory b)
    {
        Selection.TokenSelection memory row = scopedSelections.selectionAt(c.selection, index);
        b = PreservationTypes.Binding(
            address(c.producers[index]),
            address(c.producers[index]).codehash,
            keccak256("6529STREAM_PRESERVATION_RENDER_V1"),
            address(core),
            address(router),
            row.selection.renderer,
            row.selection.rendererCodeHash,
            address(attribution),
            address(attribution).codehash
        );
    }

    function _assertComplete(Capture memory c) internal view {
        Preservation.Plan memory p = c.host.requireCurrentCheckpoint(c.id);
        require(p.nextIndex == p.tokenCount && p.tokenCount != 0);
        require(abi.encode(p).length == 448, "new complete plan tuple");
        require(keccak256(abi.encode(p.scope)) == keccak256(abi.encode(c.scope)));
        require(p.preservationProfile == keccak256("6529STREAM_PRESERVATION_RENDER_V1"));
        require(c.host.preservationOutputProfile() == p.preservationProfile);
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](p.tokenCount);
        bytes32 outputs;
        bytes32 chain;
        for (uint256 i; i < p.tokenCount; ++i) {
            Preservation.Output memory o = c.host.outputAt(c.id, i);
            require(abi.encode(o).length == 1152, "new output tuple includes original admission");
            require(
                keccak256(abi.encode(o.preservationAdmission))
                    == keccak256(abi.encode(_admission(c, i)))
            );
            require(o.leaf.tokenId == scopedMembership.scopeTokenAt(c.scope, i));
            require(
                o.leaf.metadataHash
                    == keccak256(bytes(c.producers[i].preservationTokenJSON(o.leaf.tokenId)))
            );
            require(
                o.leaf.metadataHash != keccak256(bytes(router.tokenJSON(o.leaf.tokenId))),
                "distinct output path"
            );
            require(
                o.leaf.animationHash
                    == keccak256(bytes(c.producers[i].preservationTokenHTML(o.leaf.tokenId)))
            );
            require(keccak256(abi.encode(o.preservation)) == keccak256(abi.encode(_binding(c, i))));
            leaves[i] = o.leaf;
            chain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_LEAVES_V1"),
                    chain,
                    i,
                    Tree.leafHash(block.chainid, address(core), o.leaf)
                )
            );
            outputs = keccak256(
                abi.encode(keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUTS_V1"), outputs, i, o)
            );
            _assertSourceFacts(c, p, o, i);
        }
        require(p.contentRoot == Tree.root(block.chainid, address(core), leaves));
        require(p.leafChainHash == chain && p.outputRoot == outputs);
    }

    function _assertSourceFacts(
        Capture memory c,
        Preservation.Plan memory p,
        Preservation.Output memory o,
        uint256 index
    ) internal view {
        Selection.TokenSelection memory row = scopedSelections.selectionAt(c.selection, index);
        // The original source facts field is dynamic bytes, not a static TokenReadiness tuple.
        bytes memory facts = abi.encode(o.entropy);
        bytes32 expected = keccak256(
            abi.encode(
                c.host.preservationPolicyProfile(),
                p.preservationProfile,
                o.preservation,
                o.preservationAdmission,
                row.configHash,
                row.rawSourceHash,
                o.entropy.coordinator,
                facts,
                c.host.entropySourceSet(),
                c.host.entropySourceSet().codehash,
                p.inventoryHash,
                p.policyChainHash,
                c.host.terminalReadiness(),
                c.host.terminalReadiness().codehash,
                o.terminalAdmissionHash
            )
        );
        require(o.sourceFactsHash == expected, "literal preservation facts preimage");
        require(
            o.selectionRowHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                        block.chainid,
                        address(core),
                        address(router),
                        row
                    )
                )
        );
    }
}

contract StreamPreservationPolicyContentCheckpointV1Test is PreservationPolicyContentFixtureV1 {
    function testPreservationAllFourScopesKeepCompleteMembershipAndLiteralNewHashes() public {
        _preservationFixture(1);
        for (uint8 kind; kind < 4; ++kind) {
            Capture memory c = _capture(_scope(kind), true);
            require(
                PreservationERC165(address(c.host))
                    .supportsInterface(type(Preservation).interfaceId)
            );
            require(!PreservationERC165(address(c.host)).supportsInterface(type(O).interfaceId));
            require(
                !PreservationERC165(address(c.host))
                    .supportsInterface(type(CollectionO).interfaceId)
            );
            bytes32 profile = kind == 0
                ? keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1")
                : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1");
            require(c.host.preservationPolicyProfile() == profile);
            require(c.host.checkpoint(c.id).tokenCount == (kind == 1 ? 1 : 2));
            require(c.host.sourceFactory() == (kind == 0 ? address(0) : address(scopedFactory)));
            require(
                c.host.factoryDependenciesHash()
                    == (kind == 0 ? bytes32(0) : keccak256(abi.encode(_scopedDependencies())))
            );
            Preservation.Plan memory p = c.host.checkpoint(c.id);
            require(
                c.id
                    == keccak256(
                        abi.encode(
                            profile,
                            block.chainid,
                            address(c.host),
                            address(scopedSelections),
                            c.selection,
                            p.selectionHash,
                            c.host.entropySourceSet(),
                            c.host.entropySourceSet().codehash,
                            c.host.terminalReadiness(),
                            c.host.terminalReadiness().codehash,
                            p.inventoryHash,
                            p.policyChainHash,
                            p.preservationProfile,
                            keccak256("preservation candidate")
                        )
                    )
            );
            c.host.append(c.id, _payload(c));
            _assertComplete(c);
            require(c.host.begin(c.selection, keccak256("preservation candidate")) == c.id);
        }
    }

    function testPreservationOriginalNotRequiredAndFinalizedEvidenceStayDistinct() public {
        _scopedFixture(2, true);
        Capture memory terminal = _capture(_scopedScope(1), true);
        terminal.host.append(terminal.id, _payload(terminal));
        Preservation.Output memory first = terminal.host.outputAt(terminal.id, 0);
        require(
            first.entropy.terminal && first.entropy.status == 2 && !first.entropy.finalized
                && first.entropy.seed == 0 && first.terminalAdmissionHash != 0
        );
        Capture memory finalized =
            _capture(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 92, 0), true);
        finalized.host.append(finalized.id, _payload(finalized));
        Preservation.Output memory second = finalized.host.outputAt(finalized.id, 0);
        require(
            !second.entropy.terminal && second.entropy.status == 5 && second.entropy.finalized
                && second.entropy.seed == scopedFinalizedSeed && second.terminalAdmissionHash == 0
        );
        _assertComplete(terminal);
        _assertComplete(finalized);
    }

    function testPreservationBurnedRetainedMembersDoNotRequireLiveOwnership() public {
        _preservationFixture(1);
        _scopedToken(91, 1, 3, address(terminalCoordinator));
        _scopedToken(92, 2, 3, address(terminalCoordinator));
        Capture memory c = _capture(_scope(3), true);
        require(_has(router.tokenJSON(91), '"metadata_state":"burned"'));
        c.host.append(c.id, _payload(c));
        _assertComplete(c);
        bytes32 saved = _history(c);
        _scopedToken(92, 2, 1, address(terminalCoordinator));
        vm.expectRevert();
        c.host.requireCurrentCheckpoint(c.id);
        require(_history(c) == saved);
        _scopedToken(92, 2, 3, address(terminalCoordinator));
        _assertComplete(c);
    }

    function testPreservationMissingAndFailedAdmissionLeaveExactAppendRetry() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), false);
        bytes32 before = _history(c);
        Preservation.Payload[] memory values = _payload(c);
        address registry = scopedSelections.selectionAt(c.selection, 0).selection.registry;
        bytes4 selector = bytes4(keccak256("requirePreservation(bytes32,address,bytes32)"));
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector, registry, selector
            )
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        StaticRouteVm(address(vm))
            .mockCallRevert(
                registry,
                _admissionInput(c, 0),
                abi.encodeWithSignature("Error(string)", "separate governed admission unavailable")
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector, registry, selector
            )
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        _admitAll(c);
        c.host.append(c.id, values);
        _assertComplete(c);
    }

    function testPreservationIncompleteAdmissionBindingAndWrongTupleLengthFailClosed() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), true);
        Preservation.Payload[] memory values = _payload(c);
        bytes32 before = _history(c);
        for (uint256 field; field < 7; ++field) {
            PreservationTypes.Admission memory a = _admission(c, 0);
            if (field == 0) a.registry = address(0);
            else if (field == 1) a.registryCodeHash = 0;
            else if (field == 2) a.versionKey = 0;
            else if (field == 3) a.registrationHash = 0;
            else if (field == 4) a.readSetHash = 0;
            else if (field == 5) a.analysisHash = 0;
            else a.goldenHash = 0;
            _setAdmission(c, 0, abi.encode(_binding(c, 0), a));
            vm.expectRevert(
                abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(91))
            );
            c.host.append(c.id, values);
            require(_history(c) == before);
        }
        PreservationTypes.Binding memory b = _binding(c, 0);
        b.profile = keccak256("wrong preservation profile");
        _setAdmission(c, 0, abi.encode(b, _admission(c, 0)));
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(91))
        );
        c.host.append(c.id, values);
        _setAdmission(
            c, 0, abi.encodePacked(abi.encode(_binding(c, 0), _admission(c, 0)), bytes32(0))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector,
                scopedSelections.selectionAt(c.selection, 0).selection.registry,
                bytes4(keccak256("requirePreservation(bytes32,address,bytes32)"))
            )
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        _admitAll(c);
        c.host.append(c.id, values);
        _assertComplete(c);
    }

    function testPreservationSecondPayloadFailureRollsBackRowsFrontierAndRoots() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(2), true);
        bytes32 before = _history(c);
        for (uint256 defect; defect < 3; ++defect) {
            Preservation.Payload[] memory values = _payload(c);
            if (defect == 0) values[1].tokenId = 91;
            else if (defect == 1) values[1].image = hex"01";
            else values[1].animation = bytes("substituted preservation HTML");
            vm.expectRevert(
                abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(92))
            );
            c.host.append(c.id, values);
            require(_history(c) == before);
            vm.expectRevert(
                abi.encodeWithSelector(Preservation.StaticContentIndex.selector, uint256(0))
            );
            c.host.outputAt(c.id, 0);
        }
        c.host.append(c.id, _payload(c));
        _assertComplete(c); // Literal root also proves no failed frontier residue survived.
    }

    function testPreservationSecondProducerFailureAndEmptyBytesKeepExactBatchRetry() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(2), true);
        Preservation.Payload[] memory values = _payload(c);
        bytes32 before = _history(c);
        string memory json = c.producers[1].preservationTokenJSON(92);
        string memory html = c.producers[1].preservationTokenHTML(92);
        c.producers[1].setFail(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector,
                address(c.producers[1]),
                bytes4(keccak256("preservationTokenJSON(uint256)"))
            )
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        c.producers[1].setFail(false);
        c.producers[1].setBytes(92, "", html);
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(92))
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        c.producers[1].setBytes(92, json, "");
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(92))
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        c.producers[1].setBytes(92, json, html);
        c.host.append(c.id, values);
        _assertComplete(c);
    }

    function testPreservationProducerProfileAndBindingDriftPreserveHistoricalOutput() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), true);
        c.host.append(c.id, _payload(c));
        bytes32 before = _history(c);
        PreservationTypes.Binding memory b = _binding(c, 0);
        c.producer.setProfile(keccak256("wrong profile"));
        vm.expectRevert(
            abi.encodeWithSelector(PreservationTypes.InvalidPreservationBinding.selector)
        );
        c.host.requireCurrentCheckpoint(c.id);
        c.producer.setProfile(b.profile);
        c.producer
            .setBinding(
                address(metadata),
                b.metadataRouter,
                b.liveRenderer,
                b.liveRendererCodeHash,
                b.attribution,
                b.attributionCodeHash
            );
        vm.expectRevert(
            abi.encodeWithSelector(PreservationTypes.InvalidPreservationBinding.selector)
        );
        c.host.requireCurrentCheckpoint(c.id);
        c.producer
            .setBinding(
                b.core,
                b.metadataRouter,
                b.liveRenderer,
                b.liveRendererCodeHash,
                b.attribution,
                bytes32(uint256(1))
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationTypes.PreservationDependencyChanged.selector, b.attribution
            )
        );
        c.host.requireCurrentCheckpoint(c.id);
        c.producer
            .setBinding(
                b.core,
                b.metadataRouter,
                b.liveRenderer,
                b.liveRendererCodeHash,
                b.attribution,
                b.attributionCodeHash
            );
        require(_history(c) == before);
        _assertComplete(c);
    }

    function testPreservationRuntimeAndLiveAdmissionFailuresCannotRewriteSavedRows() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), true);
        c.host.append(c.id, _payload(c));
        bytes32 before = _history(c);
        address[5] memory targets = [
            address(c.producer),
            address(attribution),
            c.host.entropySourceSet(),
            c.host.terminalReadiness(),
            address(scopedFactory)
        ];
        for (uint256 i; i < targets.length; ++i) {
            bytes memory code = targets[i].code;
            vm.etch(targets[i], hex"00");
            vm.expectRevert();
            c.host.requireCurrentCheckpoint(c.id);
            require(_history(c) == before);
            vm.etch(targets[i], code);
            _assertComplete(c);
        }
        terminalVersions.setAdmitted(false);
        vm.expectRevert();
        c.host.requireCurrentCheckpoint(c.id);
        terminalVersions.setAdmitted(true);
        _assertComplete(c);
    }

    function testPreservationCurrentFullBytesAndAdmissionRerenderKeepIndependentLiveHistory()
        public
    {
        _preservationFixture(1);
        StreamFinalityScope memory scope = _scope(1);
        Capture memory c = _capture(scope, true);
        c.host.append(c.id, _payload(c));
        (Checkpoint live, bytes32 selected) = _scopedCapture(scope);
        bytes32 liveId = live.begin(selected, 0);
        live.append(liveId, _scopedPayload(scope));
        live.requireCurrentCheckpoint(liveId);
        bytes32 before = _history(c);
        bytes32 oldLive = keccak256(abi.encode(live.outputAt(liveId, 0)));
        string memory liveJSON = router.tokenJSON(91);
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(router.tokenJSON, (uint256(91))),
                abi.encode(string(abi.encodePacked(" ", liveJSON)))
            );
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentChanged.selector, liveId));
        live.requireCurrentCheckpoint(liveId);
        c.host.requireCurrentCheckpoint(c.id); // New path never reads live tokenJSON as its output.
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(router.tokenJSON, (uint256(91))),
                abi.encode(liveJSON)
            );
        string memory preserved = c.producer.preservationTokenJSON(91);
        string memory html = c.producer.preservationTokenHTML(91);
        c.producer.setBytes(91, string(abi.encodePacked(" ", preserved)), html);
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentChanged.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        live.requireCurrentCheckpoint(liveId);
        c.producer.setBytes(91, preserved, html);
        PreservationTypes.Admission memory a = _admission(c, 0);
        a.analysisHash = keccak256("changed governed evidence");
        _setAdmission(c, 0, abi.encode(_binding(c, 0), a));
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentChanged.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        _admitAll(c);
        require(_history(c) == before && keccak256(abi.encode(live.outputAt(liveId, 0))) == oldLive);
        _assertComplete(c);
    }

    function testPreservationSourceMembershipAndOriginalConfigDriftFailClosed() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(2), true);
        c.host.append(c.id, _payload(c));
        bytes32 before = _history(c);
        address source = c.host.entropySourceSet();
        PreservationMembership memory membership = E(source).scopeMembershipFacts();
        PreservationMembership memory changed =
            abi.decode(abi.encode(membership), (PreservationMembership));
        changed.tokenCount = 1;
        StaticRouteVm(address(vm))
            .mockCall(source, abi.encodeCall(E.scopeMembershipFacts, ()), abi.encode(changed));
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.InvalidStaticContentConfiguration.selector)
        );
        c.host.requireCurrentCheckpoint(c.id);
        StaticRouteVm(address(vm))
            .mockCall(source, abi.encodeCall(E.scopeMembershipFacts, ()), abi.encode(membership));
        bytes32 original = E(source).originalInventoryHash();
        StaticRouteVm(address(vm))
            .mockCall(
                source,
                abi.encodeCall(E.originalInventoryHash, ()),
                abi.encode(keccak256("different inventory"))
            );
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentChanged.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        StaticRouteVm(address(vm))
            .mockCall(source, abi.encodeCall(E.originalInventoryHash, ()), abi.encode(original));
        S.ConfigRecord memory config = router.resolvedMetadataConfig(91);
        bytes memory exact = abi.encode(config);
        config.config.frozen = false;
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(router.resolvedMetadataConfig, (uint256(91))),
                abi.encode(config)
            );
        vm.expectRevert();
        c.host.requireCurrentCheckpoint(c.id);
        StaticRouteVm(address(vm))
            .mockCall(
                address(router), abi.encodeCall(router.resolvedMetadataConfig, (uint256(91))), exact
            );
        require(_history(c) == before);
        _assertComplete(c);
    }

    function testPreservationIncompleteSelectionAndOutputAreNotCompleteCandidates() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(2), true);
        Selection.Plan memory saved = scopedSelections.checkpoint(c.selection);
        Selection.Plan memory changed = abi.decode(abi.encode(saved), (Selection.Plan));
        changed.nextIndex = 1;
        StaticRouteVm(address(vm))
            .mockCall(
                address(scopedSelections),
                abi.encodeCall(Selection.requireCurrentCheckpoint, (c.selection)),
                abi.encode(changed)
            );
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.InvalidStaticContentConfiguration.selector)
        );
        c.host.begin(c.selection, bytes32(uint256(1)));
        StaticRouteVm(address(vm))
            .mockCall(
                address(scopedSelections),
                abi.encodeCall(Selection.requireCurrentCheckpoint, (c.selection)),
                abi.encode(saved)
            );
        Preservation.Payload[] memory all = _payload(c);
        Preservation.Payload[] memory part = new Preservation.Payload[](1);
        part[0] = all[0];
        c.host.append(c.id, part);
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentIncomplete.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        require(c.host.checkpoint(c.id).nextIndex == 1 && c.host.checkpoint(c.id).contentRoot == 0);
        part[0] = all[1];
        c.host.append(c.id, part);
        _assertComplete(c);
    }

    function testPreservationMixedRenderersKeepEveryMemberAndRejectCrossRowProducer() public {
        _scopedFixture(1, true);
        for (uint8 kind = 2; kind <= 3; ++kind) {
            Capture memory c = _capture(_scope(kind), true);
            require(scopedSelections.checkpoint(c.selection).tokenCount == 2);
            Selection.TokenSelection memory first = scopedSelections.selectionAt(c.selection, 0);
            Selection.TokenSelection memory second = scopedSelections.selectionAt(c.selection, 1);
            require(
                first.selection.renderer != second.selection.renderer
                    && first.selection.registry != second.selection.registry
                    && first.selection.versionKey == second.selection.versionKey
            );
            require(address(c.producers[0]) != address(c.producers[1]));
            bytes32 before = _history(c);
            Preservation.Payload[] memory values = _payload(c);
            values[1].producer = address(c.producers[0]);
            vm.expectRevert(
                abi.encodeWithSelector(PreservationTypes.InvalidPreservationBinding.selector)
            );
            c.host.append(c.id, values);
            require(_history(c) == before && c.host.checkpoint(c.id).nextIndex == 0);
            vm.expectRevert(
                abi.encodeWithSelector(Preservation.StaticContentIndex.selector, uint256(0))
            );
            c.host.outputAt(c.id, 0);
            c.host.append(c.id, _payload(c));
            _assertComplete(c);
            require(
                c.host.outputAt(c.id, 0).entropy.terminal
                    && c.host.outputAt(c.id, 1).entropy.finalized
            );
        }
    }
}
