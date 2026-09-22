// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    PreservationOutputBoundary
} from "./scoped-preservation-boundaries/StreamPreservationPolicyContentCheckpointV1Boundaries.sol";

import "./ScopedPolicyContentFixtureV2.sol";
import {
    StreamPreservationPolicyContentCheckpointV1 as PreservationCollection
} from "../../smart-contracts/domains/finality/StreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamScopedPreservationPolicyContentCheckpointV1 as PreservationScoped
} from "../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Preservation
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as PreservationTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2 as CollectionFactory
} from "../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamRendererCalls as PreservationCalls
} from "../../smart-contracts/domains/metadata/StreamRendererCalls.sol";

import {
    IERC165 as PreservationERC165
} from "../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import {
    StreamScopeMembershipFacts as PreservationMembership
} from "../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";

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
