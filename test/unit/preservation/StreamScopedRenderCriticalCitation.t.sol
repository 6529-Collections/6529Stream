// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopedRenderCriticalTokenFixture.sol";
import {
    StreamScopedRenderCriticalCitationReads as Citations
} from "../../../smart-contracts/domains/preservation/StreamScopedRenderCriticalCitationReads.sol";
import {
    IStreamCurrentCitationRegistry as C
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as CR
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

/// @dev Actual scope membership, Metadata/Schema/Store and original token/source workers.
/// Current Registry/Renderer admissions are explicit typed boundaries, not a governed admission proof.
contract StreamScopedRenderCriticalCitationTest is ScopedRenderCriticalTokenFixture {
    ScopedReferenceReadBoundary private registry;
    ScopedReferenceReadBoundary private encoder;
    C.CurrentRecord private citation;
    V.Read[] private original;
    bytes private analysis;
    bytes private golden;
    bytes32 private targetsHash;

    function _citation() private {
        _prepare();
        registry = new ScopedReferenceReadBoundary();
        encoder = new ScopedReferenceReadBoundary();
        targetsHash = keccak256("exact original complete roster, separately inventoried");
        config.recordHash = 0;
        config.selection.registry = address(registry);
        config.selection.registryCodeHash = address(registry).codehash;
        config.selection.versionKey = keccak256("selected immutable version");
        config.selection.registrationHash = keccak256("original immutable registration");
        config.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                address(core),
                address(route),
                config
            )
        );
        row.configRecordHash = config.recordHash;
        row.configHash = keccak256(abi.encode(config));
        row.selection = config.selection;
        output.selectionRowHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                block.chainid,
                address(core),
                address(route),
                row
            )
        );
        bytes memory entropyFacts = abi.encode(uint8(5), keccak256("seed"), address(0x123));
        output.sourceFactsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_CURRENT_FULL_CONTENT_V1"),
                row.configHash,
                row.rawSourceHash,
                address(entropy),
                entropyFacts
            )
        );
        route.set("metadataConfigRecord(bytes32)", abi.encode(config));
        route.set(
            "staticRenderSourceForConfig(uint256,bytes32)", abi.encode(rawSource, config.config)
        );
        selected.set("selectionAt(bytes32,uint256)", abi.encode(row));
        content.set("outputAt(bytes32,uint256)", abi.encode(output));
        registry.set("schemaRegistry()", abi.encode(address(schemas)));
        registry.set("schemaRegistryCodeHash()", abi.encode(address(schemas).codehash));
        registry.set("deploymentChainId()", abi.encode(block.chainid));
        registry.set("targetSetHash()", abi.encode(targetsHash));
        registry.set("targetCount()", abi.encode(uint256(1)));
        selected.set("encodingBinding()", abi.encode(address(encoder), address(encoder).codehash));
        citation.registration.versionKey = config.selection.versionKey;
        citation.registration.profile = keccak256("6529STREAM_CURRENT_BASE_CITATION_V1");
        citation.registration.selector = CR.renderCurrent.selector;
        citation.registration.encoding = address(encoder);
        citation.registration.encodingRuntimeHash = address(encoder).codehash;
        analysis = abi.encode("retained typed analysis boundary", uint256(1));
        golden = abi.encode("retained typed three-mode golden boundary", uint256(3));
        citation.registration.analysisDocument = _register(
            "SCOPED_CITATION_TEST_ANALYSIS", IStreamSchemaRegistry.DocumentKind.CATALOG, analysis
        );
        citation.registration.goldenDocument = _register(
            "SCOPED_CITATION_TEST_GOLDEN", IStreamSchemaRegistry.DocumentKind.CATALOG, golden
        );
        citation.analysisHash = keccak256(analysis);
        citation.goldenHash = keccak256(golden);
        citation.actionId = keccak256("original class-zero registry admission action");
        original.push(V.Read(0, bytes4(uint32(100)), 32, true));
        original.push(V.Read(0, bytes4(uint32(300)), 64, true));
        registry.set("reads(bytes32)", abi.encode(original));
        V.Read[] memory expanded = new V.Read[](3);
        expanded[0] = original[0];
        expanded[1] = V.Read(0, bytes4(uint32(200)), 96, true);
        expanded[2] = original[1];
        _readset(expanded);
    }

    function _readset(V.Read[] memory reads) private {
        citation.readSetHash =
            keccak256(abi.encode(keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetsHash, reads));
        citation.registrationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"),
                block.chainid,
                address(registry),
                address(schemas),
                address(schemas).codehash,
                targetsHash,
                config.selection.registrationHash,
                citation.registration,
                reads
            )
        );
        registry.set("currentCitationReads(bytes32)", abi.encode(reads));
        _saved();
    }

    function _saved() private {
        registry.set("currentCitationRecord(bytes32)", abi.encode(citation));
        registry.set(
            "requireCurrentCitation(bytes32)",
            abi.encode(
                address(selected),
                address(selected).codehash,
                citation.registration.profile,
                citation.registration.selector
            )
        );
    }

    function testCompleteCitationAdmissionAndExactActualDocumentRows() public {
        _citation();
        for (uint64 i; i < 5; ++i) {
            (Inventory.Item memory item, uint64 count) = Citations.item(deps, context, 0, i);
            require(count == 5, "complete derived count");
            if (i == 2 || i == 3) {
                bytes memory expected = i == 2 ? analysis : golden;
                require(
                    item.kind == Inventory.Kind.REGISTERED_DOCUMENT
                        && item.source == address(schemas) && item.byteSize == expected.length
                        && keccak256(item.digest)
                            == keccak256(abi.encodePacked(keccak256(expected)))
                        && item.provenanceHash != 0,
                    "exact registered bytes"
                );
            }
        }
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Citations.item(deps, context, 0, 5);
    }

    function testAuthenticatedReadsetCannotOmitOrReorderOriginalRead() public {
        _citation();
        V.Read[] memory missing = new V.Read[](2);
        missing[0] = original[0];
        missing[1] = V.Read(0, bytes4(uint32(200)), 96, true);
        _readset(missing);
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventorySourceChanged.selector));
        Citations.item(deps, context, 0, 0);
        missing[0] = original[1];
        missing[1] = original[0];
        _readset(missing);
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Citations.item(deps, context, 0, 0);
    }

    function testSameHostWrongChainAndAdmittedProfileRefused() public {
        _citation();
        registry.set("deploymentChainId()", abi.encode(block.chainid + 1));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventorySourceChanged.selector));
        Citations.item(deps, context, 0, 0);
        registry.set("deploymentChainId()", abi.encode(block.chainid));
        registry.set(
            "requireCurrentCitation(bytes32)",
            abi.encode(
                address(selected),
                address(selected).codehash,
                keccak256("foreign profile"),
                CR.renderCurrent.selector
            )
        );
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventorySourceChanged.selector));
        Citations.item(deps, context, 0, 0);
    }

    function testAnalysisSubstitutionAndLostActiveAdmissionRefused() public {
        _citation();
        citation.analysisHash = keccak256("substituted analysis");
        _saved();
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Citations.item(deps, context, 0, 2);
        citation.analysisHash = keccak256(analysis);
        _saved();
        bytes32 id = citation.registration.analysisDocument;
        (bytes32 scope, bytes32 oldState, bytes32 nextState) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            oldState,
            nextState
        );
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Citations.item(deps, context, 0, 2);
    }

    function testMalformedRecordAndChangedEncoderRuntimeRefused() public {
        _citation();
        registry.set(
            "currentCitationRecord(bytes32)", bytes.concat(abi.encode(citation), bytes32(0))
        );
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventoryRead.selector, address(registry)));
        Citations.item(deps, context, 0, 0);
        _saved();
        vm.etch(address(encoder), hex"60006000fd");
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventoryRead.selector, address(encoder)));
        Citations.item(deps, context, 0, 0);
    }

    function testAbsentCapabilityIsExplicitSingleOccurrence() public {
        _citation();
        svm.mockCall(
            address(selected),
            abi.encodeCall(IERC165.supportsInterface, (type(CR).interfaceId)),
            abi.encode(false)
        );
        (Inventory.Item memory item, uint64 count) = Citations.item(deps, context, 0, 0);
        require(
            count == 1 && item.kind == Inventory.Kind.ABSENT && item.source == address(registry)
                && item.sourceRecord == config.selection.versionKey && item.sourceIndex == token,
            "explicit absence"
        );
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Citations.item(deps, context, 0, 1);
    }
}
