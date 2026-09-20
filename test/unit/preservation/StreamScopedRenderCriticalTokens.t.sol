// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopedReferenceSnapshotFixture.sol";
import {
    StreamScopedRenderCriticalTokenReads as Tokens
} from "../../../smart-contracts/domains/preservation/StreamScopedRenderCriticalTokenReads.sol";
import {
    StreamScopedRenderCriticalScriptReads as Scripts
} from "../../../smart-contracts/domains/preservation/StreamScopedRenderCriticalScriptReads.sol";
import {
    StreamScopedRenderCriticalTypes as Context
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedReferenceTypes as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedReferenceTypes.sol";
import {
    StreamPreservationInventoryTypes as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as Renderer
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";

/// @dev Actual scoped membership, Metadata/Schema/Store; named typed Core/Router/output/entropy
/// boundaries. These finite source oracles do not demonstrate a sealed inventory/provider.
contract StreamScopedRenderCriticalTokensTest is ScopedReferenceSnapshotFixture {
    D.Dependencies private deps;
    Context.Context private context;
    Selection.TokenSelection private row;
    Content.Output private output;
    Content.Payload private payload;
    Router.ConfigRecord private config;
    Router.RawSource private rawSource;
    bytes private json;
    bytes private html;
    uint256 private token;

    function _prepare() private {
        _initialize(1);
        ScopedReferenceReadBoundary referenceBoundary = new ScopedReferenceReadBoundary();
        ScopedReferenceReadBoundary archive = new ScopedReferenceReadBoundary();
        _setAddress(archive, "core()", address(core));
        deps.chainId = block.chainid;
        deps.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(route),
            address(host),
            address(referenceBoundary),
            address(artist),
            address(artist),
            address(artist),
            address(coverage),
            address(archive)
        ];
        for (uint256 i; i < 12; ++i) {
            deps.codeHashes[i] = deps.targets[i].codehash;
        }
        deps.readGas = 500000;
        deps.sourceGas = 2000000;
        Reference.Dependencies memory rd;
        rd.chainId = block.chainid;
        rd.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(route),
            address(host),
            address(archive)
        ];
        for (uint256 i; i < 7; ++i) {
            rd.codeHashes[i] = rd.targets[i].codehash;
        }
        rd.readGas = 500000;
        rd.sourceGas = 2000000;
        rd.snapshotGas = 8000000;
        rd.archiveGas = 500000;
        referenceBoundary.set("dependencies()", abi.encode(rd));
        context.scope = publication.scope;
        context.tokenCount = 1;
        context.selectionId = keccak256("original selected inventory");
        context.checkpointHash = keccak256("original full output checkpoint");
        token = membership.scopeTokenAt(context.scope, 0);
        config.collectionId = 1;
        config.revision = 1;
        config.config.mode = Renderer.MetadataMode.ONCHAIN;
        config.config.renderer = address(selected);
        config.config.frozen = true;
        config.selection.renderer = address(selected);
        config.selection.rendererCodeHash = address(selected).codehash;
        rawSource.chainId = block.chainid;
        rawSource.configured = true;
        rawSource.name = "Original source";
        rawSource.script = "console.log('original')";
        config.sourceSnapshotHash =
            keccak256(abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), rawSource));
        config.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                address(core),
                address(route),
                config
            )
        );
        row.tokenId = token;
        row.configRecordHash = config.recordHash;
        row.configHash = keccak256(abi.encode(config));
        row.rawSourceHash = keccak256(abi.encode(rawSource));
        row.sourceSnapshotHash = config.sourceSnapshotHash;
        row.selection = config.selection;
        row.sources[3] = address(entropy);
        row.sourceCodeHashes[3] = address(entropy).codehash;
        route.set("metadataConfigRecord(bytes32)", abi.encode(config));
        route.set(
            "staticRenderSourceForConfig(uint256,bytes32)", abi.encode(rawSource, config.config)
        );
        selected.set("selectionAt(bytes32,uint256)", abi.encode(row));
        bytes memory entropyFacts = abi.encode(uint8(5), keccak256("seed"), address(0x123));
        entropy.set("staticTokenRenderFacts(uint256)", entropyFacts);
        svm.mockCall(
            address(core),
            abi.encodeWithSignature("tokenData(uint256)", token),
            abi.encode(bytes("native token data"))
        );
        output.selectionRowHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                block.chainid,
                address(core),
                address(route),
                row
            )
        );
        output.sourceFactsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_CURRENT_FULL_CONTENT_V1"),
                row.configHash,
                row.rawSourceHash,
                address(entropy),
                entropyFacts
            )
        );
        output.leaf.tokenId = token;
        output.leaf.tokenDataHash = keccak256("native token data");
        payload.tokenId = token;
        _outputs(bytes("{\"full\":true}"), bytes("<!doctype html><script>original</script>"));
    }

    function _outputs(bytes memory nextJSON, bytes memory nextHTML) private {
        json = nextJSON;
        html = nextHTML;
        payload.animation = nextHTML;
        output.leaf.metadataHash = keccak256(nextJSON);
        output.leaf.animationHash = keccak256(nextHTML);
        output.htmlHash = keccak256(nextHTML);
        content.set("outputAt(bytes32,uint256)", abi.encode(output));
        route.set("tokenJSON(uint256)", abi.encode(string(nextJSON)));
        route.set("tokenHTML(uint256)", abi.encode(string(nextHTML)));
        route.set("historicalTokenMetadataJSON(address,uint256)", abi.encode("compact historical"));
    }

    function testActualMembershipOrdinalKeepsOriginalSerialAndBurnedIdentity() public {
        _prepare();
        (uint256 actual, Tokens.Original memory original) = Tokens.sourceAt(deps, context, 0);
        (
            uint256 savedToken,
            uint256 cid,
            uint256 serial,
            bool burned,
            uint8 lifecycle,
            uint64 ordinal
        ) = abi.decode(original.identity, (uint256, uint256, uint256, bool, uint8, uint64));
        require(
            actual == token && savedToken == token && cid == 1 && serial == 2 && !burned
                && lifecycle == 2 && ordinal == 0,
            "permanent identity not ordinal"
        );
        Inventory.Item[] memory rows = Tokens.tokenItems(deps, context, 0, payload);
        require(
            rows.length == 10
                && keccak256(rows[1].digest) == keccak256(abi.encodePacked(keccak256(json))),
            "full JSON row"
        );
        core.setToken(token, 1, serial, 3);
        (, original) = Tokens.sourceAt(deps, context, 0);
        (,,, burned, lifecycle,) =
            abi.decode(original.identity, (uint256, uint256, uint256, bool, uint8, uint64));
        require(burned && lifecycle == 3, "retained burned identity");
    }

    function testFullOutputDriftCannotBorrowUnchangedCompactBytes() public {
        _prepare();
        Tokens.tokenItems(deps, context, 0, payload);
        route.set("tokenJSON(uint256)", abi.encode("changed full output"));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Tokens.tokenItems(deps, context, 0, payload);
        route.set("tokenJSON(uint256)", abi.encode(string(json)));
        Tokens.tokenItems(deps, context, 0, payload);
        payload.tokenId += 1;
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Tokens.tokenItems(deps, context, 0, payload);
    }

    function testExplicitProfileByteBoundsDoNotTrustMatchingOversizedLeaf() public {
        _prepare();
        _outputs(new bytes(65536), new bytes(40960));
        Tokens.tokenItems(deps, context, 0, payload);
        _outputs(new bytes(65537), bytes("html"));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventoryRead.selector, address(route)));
        Tokens.tokenItems(deps, context, 0, payload);
        _outputs(bytes("json"), new bytes(40961));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventoryRead.selector, address(route)));
        Tokens.tokenItems(deps, context, 0, payload);
        _outputs(bytes("json"), bytes("html"));
        payload.image = new bytes(2049);
        output.leaf.imageHash = keccak256(payload.image);
        content.set("outputAt(bytes32,uint256)", abi.encode(output));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Tokens.tokenItems(deps, context, 0, payload);
    }

    function testInlineScriptAndAbsentLibraryAreExactOriginalSourceRows() public {
        _prepare();
        Inventory.Item[] memory rows = Scripts.items(deps, context, 0, false);
        require(
            rows.length == 1 && rows[0].byteSize == bytes(rawSource.script).length
                && keccak256(rows[0].digest)
                    == keccak256(abi.encodePacked(keccak256(bytes(rawSource.script)))),
            "inline exact bytes"
        );
        rows = Scripts.items(deps, context, 0, true);
        require(rows.length == 1 && rows[0].kind == Inventory.Kind.ABSENT, "no invented library");
        rawSource.script = "substituted script";
        route.set(
            "staticRenderSourceForConfig(uint256,bytes32)", abi.encode(rawSource, config.config)
        );
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Scripts.items(deps, context, 0, false);
    }
}
