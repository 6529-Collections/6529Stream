// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewRetrievalConfigurationFixture.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamFinalityViewPreservationSourceSelectionV1 as Check
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationSourceSelectionV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Selection
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamViewPreservationReferencePublicationV1 as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationReferencePublicationV1.sol";
import {
    IStreamViewPreservationRenderCriticalInventoryV1 as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    IStreamViewPreservationBundleArchiveCoverageV1 as Bundle
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamViewPreservationReferenceTypesV1 as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1 as Definitions
} from "../../../smart-contracts/domains/records/StreamViewPreservationReferenceDefinitionsV1.sol";

/// @dev Explicit constructor/getter boundary; every unconfigured current-evidence selector refuses.
contract ViewSelectionBoundary {
    mapping(bytes32 => bytes) private responses;

    function set(bytes memory input, bytes memory output) external {
        responses[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory output = responses[keccak256(msg.data)];
        require(output.length != 0, "unconfigured current-evidence or selector");
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

contract ViewSelectionProbe {
    function check(Selection.Selection memory s, Check.Expected memory e, uint256 cap)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return Check.requireBindings(s, e, cap);
    }
}

/// @notice Typed identity/reciprocity tests only. No governed bind or current evidence is mocked as accepted.
contract StreamViewPreservationSourceSelectionV1Test is CharacterizationTestBase {
    Check.Expected private expected;
    Selection.Selection private selected;
    R.Dependencies private referenceDeps;
    I.Dependencies private inventory;
    B.Dependencies private bundle;
    ViewSelectionProbe private probe;
    uint256 private originalChain;
    address private retrievalWitness;

    function _word(address a, string memory selector, bytes32 word) private {
        ViewSelectionBoundary(a).set(abi.encodeWithSignature(selector), abi.encode(word));
    }

    function _address(address a, string memory selector, address value) private {
        _word(a, selector, bytes32(uint256(uint160(value))));
    }

    function _support(address a, bytes4 id, bool yes) private {
        ViewSelectionBoundary(a)
            .set(abi.encodeWithSignature("supportsInterface(bytes4)", id), abi.encode(yes));
    }

    function _reference() private {
        ViewSelectionBoundary(selected.referencePublication)
            .set(abi.encodeCall(Reference.dependencies, ()), abi.encode(referenceDeps));
    }

    function _inventory() private {
        ViewSelectionBoundary(selected.renderCriticalInventory)
            .set(abi.encodeCall(Inventory.dependencies, ()), abi.encode(inventory));
        _word(
            selected.renderCriticalInventory, "dependencyHash()", keccak256(abi.encode(inventory))
        );
    }

    function _bundle() private {
        ViewSelectionBoundary(selected.bundleArchiveCoverage)
            .set(abi.encodeWithSignature("dependencies()"), abi.encode(bundle));
        _word(selected.bundleArchiveCoverage, "dependencyHash()", keccak256(abi.encode(bundle)));
    }

    function setUp() public {
        originalChain = block.chainid;
        for (uint256 i; i < 12; ++i) {
            expected.targets[i] = address(new ViewSelectionBoundary());
            expected.codeHashes[i] = expected.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            expected.artistTargets[i] = address(new ViewSelectionBoundary());
            expected.artistCodeHashes[i] = expected.artistTargets[i].codehash;
        }
        expected.artistContentOwner = address(new ViewSelectionBoundary());
        expected.artistContentOwnerCodeHash = expected.artistContentOwner.codehash;
        expected.chainId = originalChain;
        selected = Selection.Selection(
            expected.targets[6],
            expected.codeHashes[6],
            address(new ViewSelectionBoundary()),
            0,
            address(new ViewSelectionBoundary()),
            0
        );
        selected.renderCriticalInventoryCodeHash = selected.renderCriticalInventory.codehash;
        selected.bundleArchiveCoverageCodeHash = selected.bundleArchiveCoverage.codehash;
        uint256[7] memory roles = [uint256(0), 1, 2, 3, 4, 5, 11];
        for (uint256 i; i < 7; ++i) {
            referenceDeps.targets[i] = expected.targets[roles[i]];
            referenceDeps.codeHashes[i] = expected.codeHashes[roles[i]];
        }
        referenceDeps.chainId = originalChain;
        referenceDeps.readGas = 2000000;
        referenceDeps.sourceGas = 12000000;
        referenceDeps.snapshotGas = 16000000;
        referenceDeps.archiveGas = 8000000;
        _reference();
        address ref = selected.referencePublication;
        _support(ref, type(Reference).interfaceId, true);
        _support(ref, type(IStreamArtworkScopedFinalityComponent).interfaceId, true);
        _address(ref, "core()", expected.targets[0]);
        _address(ref, "metadataHost()", expected.targets[1]);
        _address(ref, "metadataRouter()", expected.targets[4]);
        _address(ref, "snapshots()", expected.targets[5]);
        _address(ref, "archiveCoverage()", expected.targets[11]);
        _word(ref, "deploymentChainId()", bytes32(originalChain));
        _word(ref, "streamModuleType()", keccak256("REFERENCE_RENDER"));
        _word(
            ref,
            "streamModuleVersion()",
            keccak256("STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_IMPLEMENTATION_V1")
        );
        _word(ref, "streamModuleSchemaHash()", Definitions.SCHEMA_HASH);
        ViewSelectionBoundary(ref)
            .set(
                abi.encodeWithSignature("streamModuleManifest()"),
                abi.encode("typed configuration", Definitions.PROFILE_HASH)
            );
        inventory.targets = expected.targets;
        inventory.codeHashes = expected.codeHashes;
        inventory.artistTargets = expected.artistTargets;
        inventory.artistCodeHashes = expected.artistCodeHashes;
        inventory.artistContentOwner = expected.artistContentOwner;
        inventory.artistContentOwnerCodeHash = expected.artistContentOwnerCodeHash;
        inventory.chainId = originalChain;
        inventory.readGas = 2000000;
        inventory.sourceGas = 18000000;
        inventory.selectionGas = 8000000;
        inventory.snapshotGas = 18000000;
        inventory.referenceGas = 24000000;
        _inventory();
        address inv = selected.renderCriticalInventory;
        _support(inv, type(Inventory).interfaceId, true);
        _word(
            inv,
            "inventoryProfile()",
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1")
        );
        _address(inv, "core()", expected.targets[0]);
        _address(inv, "metadataHost()", expected.targets[1]);
        _address(inv, "metadataRouter()", expected.targets[4]);
        _address(inv, "snapshots()", expected.targets[5]);
        _address(inv, "referencePublisher()", expected.targets[6]);
        _address(inv, "artifactCoverage()", expected.targets[10]);
        _address(inv, "externalCoverage()", expected.targets[11]);
        bundle.targets = [
            expected.targets[0],
            expected.targets[1],
            inv,
            expected.targets[10],
            expected.targets[11],
            expected.artistTargets[4]
        ];
        bundle.codeHashes = [
            expected.codeHashes[0],
            expected.codeHashes[1],
            inv.codehash,
            expected.codeHashes[10],
            expected.codeHashes[11],
            expected.artistCodeHashes[4]
        ];
        bundle.chainId = originalChain;
        bundle.readGas = 2000000;
        bundle.archiveGas = 8000000;
        _bundle();
        address cov = selected.bundleArchiveCoverage;
        _support(cov, type(Bundle).interfaceId, true);
        _word(
            cov,
            "bundleProfile()",
            keccak256("6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1")
        );
        _word(cov, "deploymentChainId()", bytes32(originalChain));
        _word(cov, "coreCodeHash()", expected.codeHashes[0]);
        _word(cov, "metadataCodeHash()", expected.codeHashes[1]);
        _word(cov, "inventoryCodeHash()", inv.codehash);
        _address(cov, "core()", expected.targets[0]);
        _address(cov, "metadataHost()", expected.targets[1]);
        _address(cov, "renderCriticalInventory()", inv);
        _address(cov, "artifactCoverage()", expected.targets[10]);
        _address(cov, "externalCoverage()", expected.targets[11]);
        retrievalWitness = ViewRetrievalConfigurationFixture.configure(inventory, true);
        ViewRetrievalConfigurationFixture.bind(selected.renderCriticalInventory, retrievalWitness);
        probe = new ViewSelectionProbe();
    }

    function _positive() private view returns (bytes32 a, bytes32 b, bytes32 c) {
        (a, b, c) = probe.check(selected, expected, 500000);
        require(
            a == keccak256(abi.encode(referenceDeps)) && b == keccak256(abi.encode(inventory))
                && c == keccak256(abi.encode(bundle)),
            "literal complete canonical dependency hashes"
        );
    }

    function _fails(Selection.Selection memory s, Check.Expected memory e, uint256 cap)
        private
        view
    {
        (bool ok,) = address(probe).staticcall(abi.encodeCall(probe.check, (s, e, cap)));
        require(!ok, "must refuse");
    }

    function testLiteralCompleteHashesNeedNoCurrentRootOrPublication() public view {
        _positive();
        (bool ok,) = selected.referencePublication
            .staticcall(
                abi.encodeWithSignature(
                    "currentReference((uint8,uint256,uint256,bytes32))",
                    uint8(4),
                    uint256(1),
                    uint256(0),
                    keccak256("scope")
                )
            );
        require(!ok, "no pre-existing current referenceDeps fabricated");
    }

    function testEveryRoleAndArtistPinIsIndependentlyBound() public view {
        for (uint256 i; i < 18; ++i) {
            Check.Expected memory e = abi.decode(abi.encode(expected), (Check.Expected));
            if (i < 12) e.codeHashes[i] = keccak256(abi.encode("foreign runtime", i));
            else if (i < 17) e.artistCodeHashes[i - 12] = keccak256(abi.encode("foreign Artist", i));
            else e.artistContentOwnerCodeHash = keccak256("foreign Content owner");
            _fails(selected, e, 500000);
        }
        _positive();
    }

    function testAllReferenceReciprocalRolesAndArtistInventoryRowsRefuseExactRestore() public {
        for (uint256 i; i < 7; ++i) {
            address old = referenceDeps.targets[i];
            referenceDeps.targets[i] = address(probe);
            _reference();
            _fails(selected, expected, 500000);
            referenceDeps.targets[i] = old;
            _reference();
            _positive();
        }
        for (uint256 i; i < 5; ++i) {
            address old = inventory.artistTargets[i];
            inventory.artistTargets[i] = address(probe);
            _inventory();
            _fails(selected, expected, 500000);
            inventory.artistTargets[i] = old;
            _inventory();
            _positive();
        }
        address old = bundle.targets[2];
        bundle.targets[2] = expected.targets[6];
        _bundle();
        _fails(selected, expected, 500000);
        bundle.targets[2] = old;
        _bundle();
        _positive();
    }

    function testCapabilitiesProfileMalformedAndCrossChainFailClosed() public {
        _support(selected.referencePublication, type(Reference).interfaceId, false);
        _fails(selected, expected, 500000);
        _support(selected.referencePublication, type(Reference).interfaceId, true);
        _word(selected.renderCriticalInventory, "inventoryProfile()", keccak256("foreign profile"));
        _fails(selected, expected, 500000);
        _word(
            selected.renderCriticalInventory,
            "inventoryProfile()",
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1")
        );
        ViewSelectionBoundary(selected.referencePublication)
            .set(abi.encodeCall(Reference.dependencies, ()), hex"01");
        _fails(selected, expected, 500000);
        _reference();
        vm.chainId(originalChain + 1);
        _fails(selected, expected, 500000);
        vm.chainId(originalChain);
        _positive();
    }

    function testCurrentGovernedReferenceGasChangesHashNotIdentityAndInvalidRelationshipRefuses()
        public
    {
        (bytes32 beforeHash, bytes32 ih, bytes32 bh) = _positive();
        referenceDeps.archiveGas = 16000000;
        _reference();
        (bytes32 afterHash, bytes32 ih2, bytes32 bh2) = _positive();
        require(
            beforeHash != afterHash && ih == ih2 && bh == bh2,
            "initial receipt hash must remain historical; operative identity joins stay current"
        );
        referenceDeps.snapshotGas = referenceDeps.sourceGas - 1;
        _reference();
        _fails(selected, expected, 500000);
        referenceDeps.snapshotGas = 16000000;
        _reference();
        _positive();
    }

    function testSelectedForeignHostRuntimeAndReadBudgetBoundariesRefuse() public view {
        Selection.Selection memory s = selected;
        s.referencePublication = address(probe);
        _fails(s, expected, 500000);
        s = selected;
        s.renderCriticalInventoryCodeHash = bytes32(uint256(1));
        _fails(s, expected, 500000);
        _fails(selected, expected, 49999);
        _fails(selected, expected, 16777217);
        _positive();
    }

    function testRetrievalCompanionCannotBeAdvertisedByOldOrMalformedInventory() public {
        _positive();
        _word(
            selected.renderCriticalInventory,
            "inventoryProfile()",
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_V1")
        );
        _fails(selected, expected, 500000);
        _word(
            selected.renderCriticalInventory,
            "inventoryProfile()",
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1")
        );
        _positive();
        _support(
            selected.renderCriticalInventory, type(RetrievalCompanionInterface).interfaceId, false
        );
        _fails(selected, expected, 500000);
        _support(
            selected.renderCriticalInventory, type(RetrievalCompanionInterface).interfaceId, true
        );
        bytes memory input = abi.encodeCall(RetrievalCompanionInterface.retrievalWitnessBinding, ());
        ViewSelectionBoundary(selected.renderCriticalInventory)
            .set(input, abi.encode(retrievalWitness, bytes32(uint256(1))));
        _fails(selected, expected, 500000);
        ViewRetrievalConfigurationFixture.bind(selected.renderCriticalInventory, retrievalWitness);
        _positive();
        ViewSelectionBoundary(selected.renderCriticalInventory).set(input, hex"01");
        _fails(selected, expected, 500000);
        ViewRetrievalConfigurationFixture.bind(selected.renderCriticalInventory, retrievalWitness);
        _positive();
    }

    function testRetrievalConfigurationPinsAndSnapshotCheckpointNeedExactRestoredJoin() public {
        RetrievalWitnessTypes.Configuration memory c =
            RetrievalWitnessInterface(retrievalWitness).configuration();
        bytes memory request = abi.encodeCall(RetrievalWitnessInterface.configuration, ());
        bytes memory hashRequest = abi.encodeCall(RetrievalWitnessInterface.configurationHash, ());
        bytes memory originalHash = _get(retrievalWitness, hashRequest);
        // Reject an inconsistent hash separately from otherwise self-consistent foreign bindings.
        ViewRetrievalConfigurationFixture.set(retrievalWitness, hashRequest, abi.encode(bytes32(0)));
        _fails(selected, expected, 500000);
        ViewRetrievalConfigurationFixture.set(retrievalWitness, hashRequest, originalHash);
        _positive();
        for (uint256 i; i < 3; ++i) {
            RetrievalWitnessTypes.Configuration memory changed =
                abi.decode(abi.encode(c), (RetrievalWitnessTypes.Configuration));
            if (i == 0) changed.archive = address(probe);
            else if (i == 1) changed.routerCodeHash = keccak256("foreign Router runtime");
            else changed.checkpoint = address(probe);
            ViewRetrievalConfigurationFixture.set(retrievalWitness, request, abi.encode(changed));
            ViewRetrievalConfigurationFixture.set(
                retrievalWitness,
                hashRequest,
                abi.encode(keccak256(abi.encode(RetrievalWitnessTypes.PROFILE, changed)))
            );
            _fails(selected, expected, 500000);
            ViewRetrievalConfigurationFixture.set(retrievalWitness, request, abi.encode(c));
            ViewRetrievalConfigurationFixture.set(retrievalWitness, hashRequest, originalHash);
            _positive();
        }
        RetrievalSnapshotTypes.Dependencies memory snap = abi.decode(
            _get(expected.targets[5], abi.encodeWithSignature("dependencies()")),
            (RetrievalSnapshotTypes.Dependencies)
        );
        RetrievalSnapshotTypes.Dependencies memory wrong =
            abi.decode(abi.encode(snap), (RetrievalSnapshotTypes.Dependencies));
        wrong.targets[6] = address(probe);
        wrong.codeHashes[6] = address(probe).codehash;
        ViewRetrievalConfigurationFixture.set(
            expected.targets[5], abi.encodeWithSignature("dependencies()"), abi.encode(wrong)
        );
        _fails(selected, expected, 500000);
        ViewRetrievalConfigurationFixture.set(
            expected.targets[5], abi.encodeWithSignature("dependencies()"), abi.encode(snap)
        );
        _positive();
        (bool ok,) = retrievalWitness.staticcall(
            abi.encodeCall(RetrievalWitnessInterface.requireCurrent, (bytes32(uint256(1))))
        );
        require(!ok, "fixture has no operative retrieval evidence");
    }

    function _get(address target, bytes memory input) private view returns (bytes memory out) {
        (bool ok, bytes memory raw) = target.staticcall(input);
        require(ok);
        return raw;
    }
}
