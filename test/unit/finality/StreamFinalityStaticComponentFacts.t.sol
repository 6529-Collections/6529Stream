// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    IStreamMetadataRouter
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    StreamStaticSelectionCheckpoint
} from "../../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticSelectionCheckpoint as C
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";

import {
    StreamFinalityStaticComponentFacts as F
} from "../../../smart-contracts/domains/finality/StreamFinalityStaticComponentFacts.sol";

contract StaticComponentProbe {
    function facts(F.Config memory c, F.AuthenticatedSelection memory a, bytes32 family)
        external
        view
        returns (bool, bytes32)
    {
        return F.facts(c, a, family);
    }
}

/// @notice Actual Router/Metadata/Renderer/Store/selection/membership; source-profile and locked
/// Artist projection are explicit typed boundaries. No root/snapshot or finality ceremony claim.
contract StreamFinalityStaticComponentFactsTest is StaticMetadataRoutingFixture {
    StreamCollectionTokenInventory private inventory;
    StreamFinalityScopeMembership private membership;
    StreamStaticSelectionCheckpoint private checkpoints;
    StaticComponentProbe private probe;
    F.Config private config;
    F.AuthenticatedSelection private selected;

    function setUp() public override {
        super.setUp();
        inventory = new StreamCollectionTokenInventory(
            address(core),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "TOKEN_INVENTORY_CORE_READ_GAS", 100000, 50000, 1
            )
        );
        membership = new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(inventory),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1
            )
        );
        checkpoints = new StreamStaticSelectionCheckpoint(
            address(core),
            address(router),
            address(membership),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_CHECKPOINT_READ_GAS", 2000000, 500000, 1
            )
        );
        // Exact Core pointer ABI boundary; other genuine hosts are not mocked.
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                abi.encode(
                    address(router),
                    address(router).codehash,
                    false,
                    keccak256("METADATA_ROUTER"),
                    type(IStreamMetadataRouter).interfaceId,
                    address(modules),
                    uint8(1),
                    keccak256("manifest"),
                    keccak256("deployment"),
                    uint64(1)
                )
            );
    }

    function _two() private {
        _activate();
        core.setToken(1, address(this), 2);
        core.setToken(2, address(this), 2);
        core.setMinted(2);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        inventory.appendCollectionTokens(1, ids);
    }

    function _freeze(uint256 token, R.MetadataMode mode) private {
        S.ConfigInput memory input = _input(mode, true);
        _approve(token, input, keccak256(abi.encode("freeze", token, mode)));
        router.setTokenMetadataConfig(token, input);
    }

    function _pointer() private {
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                abi.encode(
                    address(router),
                    address(router).codehash,
                    false,
                    keccak256("METADATA_ROUTER"),
                    type(IStreamMetadataRouter).interfaceId,
                    address(modules),
                    uint8(1),
                    keccak256("manifest"),
                    keccak256("deployment"),
                    uint64(1)
                )
            );
    }

    function _ready() private {
        _two();
        _freeze(1, R.MetadataMode.ONCHAIN);
        _freeze(2, R.MetadataMode.ONCHAIN);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 2, 0);
        bytes32 id = checkpoints.begin(scope);
        checkpoints.append(id, 1);
        C.Plan memory p = checkpoints.requireCurrentCheckpoint(id);
        config = F.Config(
            address(core),
            address(metadata),
            address(router),
            address(checkpoints),
            address(core).codehash,
            address(metadata).codehash,
            address(router).codehash,
            address(checkpoints).codehash,
            block.chainid,
            2000000,
            3000000
        );
        IStreamMetadataServingFacts.ArtistPresentation memory artist;
        artist.locked = true;
        artist.snapshotHash = keccak256("typed locked source association");
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (uint256(1))),
                abi.encode(artist)
            );
        selected = F.AuthenticatedSelection(
            scope,
            keccak256("explicit test source projection"),
            id,
            p.membershipHash,
            p.selectionRoot,
            p.tokenCount,
            artist.snapshotHash
        );
        probe = new StaticComponentProbe();
    }

    function testSixFamiliesUseExactFrozenTokenScope() public {
        _ready();
        bytes32[6] memory families = [
            StreamFinalityDomains.COMPONENT_RENDERER,
            StreamFinalityDomains.COMPONENT_RENDER_CONTEXT,
            StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE,
            StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST,
            StreamFinalityDomains.COMPONENT_METADATA_ROUTER
        ];
        bytes32[6] memory hashes;
        for (uint256 i; i < 6; ++i) {
            (bool frozen, bytes32 hash) = probe.facts(config, selected, families[i]);
            require(frozen && hash != 0);
            hashes[i] = hash;
            for (uint256 j; j < i; ++j) {
                require(hash != hashes[j]);
            }
        }
    }

    function testScriptCommitmentMatchesIndependentLiteralPreimage() public {
        _ready();
        F.Config memory c = config;
        F.AuthenticatedSelection memory a = selected;
        C.TokenSelection memory row = checkpoints.selectionAt(a.selectionId, 0);
        (S.RawSource memory source,) = router.staticRenderSourceForConfig(1, row.configRecordHash);
        bytes32 family = StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE;
        bytes32 domain = keccak256("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_V1");
        bytes32 identity = keccak256(
            abi.encode(
                domain,
                family,
                block.chainid,
                address(core),
                address(metadata),
                address(router),
                address(checkpoints),
                address(checkpoints).codehash,
                a
            )
        );
        bytes32 fields =
            keccak256(abi.encode(keccak256(bytes(source.script)), source.scriptManifest));
        bytes32 rowHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_ROW_V1"),
                identity,
                family,
                uint256(0),
                uint256(2),
                row.configRecordHash,
                row.configHash,
                row.sourceSnapshotHash,
                row.rawSourceHash,
                fields
            )
        );
        bytes32 folded = keccak256(
            abi.encode(
                keccak256("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_FOLD_V1"),
                identity,
                family,
                bytes32(0),
                uint256(0),
                uint256(2),
                rowHash
            )
        );
        (, bytes32 actual) = probe.facts(c, a, family);
        require(actual == keccak256(abi.encode(domain, identity, family, uint64(1), folded)));
        a.sourceProfile = keccak256("different fixed profile");
        (, bytes32 distinct) = probe.facts(c, a, family);
        require(distinct != actual);
    }

    function testForeignScopeCountAndRootCannotSubstituteSelection() public {
        _ready();
        F.AuthenticatedSelection memory a = selected;
        a.scope.tokenId = 1;
        _refuses(config, a);
        a = selected;
        a.tokenCount = 2;
        _refuses(config, a);
        a = selected;
        a.selectionRoot ^= bytes32(uint256(1));
        _refuses(config, a);
        a = selected;
        a.membershipHash ^= bytes32(uint256(1));
        _refuses(config, a);
        a = selected;
        a.scope.scopeType = StreamFinalityScopeType.RELEASE;
        a.scope.tokenId = 0;
        a.scope.scopeId = keccak256("same-looking id");
        _refuses(config, a);
        probe.facts(config, selected, StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
    }

    function testOutsideMintDoesNotReplaceInsideOriginalSource() public {
        _ready();
        (, bytes32 before_) =
            probe.facts(config, selected, StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        core.setToken(3, address(this), 2);
        core.setMinted(3);
        (, bytes32 after_) =
            probe.facts(config, selected, StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        require(before_ == after_);
        C.TokenSelection memory row = checkpoints.selectionAt(selected.selectionId, 0);
        S.ConfigRecord memory changed = router.metadataConfigRecord(row.configRecordHash);
        changed.config.baseURI = "https://changed.example/";
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(S.metadataConfigRecord, (row.configRecordHash)),
                abi.encode(changed)
            );
        _refuses(config, selected);
    }

    function testRawSourceMutationAndLockedArtistMismatchRefuse() public {
        _ready();
        C.TokenSelection memory row = checkpoints.selectionAt(selected.selectionId, 0);
        (S.RawSource memory source, R.MetadataConfig memory cfg) =
            router.staticRenderSourceForConfig(1, row.configRecordHash);
        source.script = "altered frozen bytes";
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(S.staticRenderSourceForConfig, (uint256(1), row.configRecordHash)),
                abi.encode(source, cfg)
            );
        _refuses(config, selected);
        StaticRouteVm(address(vm)).clearMockedCalls();
        _pointer();
        F.AuthenticatedSelection memory wrong = selected;
        wrong.lockedArtistSnapshotHash = bytes32(uint256(7));
        (bool ok,) = address(probe)
            .staticcall(
                abi.encodeCall(
                    probe.facts, (config, wrong, StreamFinalityDomains.COMPONENT_METADATA_ROUTER)
                )
            );
        require(!ok);
    }

    function testMissingRuntimeAndUnknownFamilyRefuse() public {
        _ready();
        F.Config memory bad = config;
        bad.selectionCodeHash ^= bytes32(uint256(1));
        _refuses(bad, selected);
        bad = config;
        bad.selection = address(0);
        _refuses(bad, selected);
        (bool ok,) = address(probe)
            .staticcall(abi.encodeCall(probe.facts, (config, selected, bytes32(uint256(1)))));
        require(!ok);
    }

    function _refuses(F.Config memory c, F.AuthenticatedSelection memory a) private view {
        (bool ok,) = address(probe)
            .staticcall(
                abi.encodeCall(probe.facts, (c, a, StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE))
            );
        require(!ok);
    }
}
