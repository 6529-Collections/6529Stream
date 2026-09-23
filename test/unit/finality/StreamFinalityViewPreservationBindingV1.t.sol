// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityFullPreservationPolicyDiscoveryV1Test
} from "./StreamFinalityFullPreservationPolicyDiscoveryV1.t.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as VB
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as Binding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamViewPreservationEvidenceBindingV1 as Evidence
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    StreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../../smart-contracts/domains/finality/StreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewPreservationOutputManifestV1 as Manifest
} from "../../../smart-contracts/domains/finality/StreamViewPreservationOutputManifestV1.sol";
import {
    StreamViewPreservationSnapshotPublicationV1 as Snapshot
} from "../../../smart-contracts/domains/metadata/StreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as M
} from "../../../smart-contracts/interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    IStreamViewPreservationRendererV1 as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamViewPreservationSnapshotSourceReadsV1 as Sources
} from "../../../smart-contracts/domains/records/StreamViewPreservationSnapshotSourceReadsV1.sol";
import {
    StreamViewPreservationCheckpointSourceV1 as CheckpointSource
} from "../../../smart-contracts/domains/finality/StreamViewPreservationCheckpointSourceV1.sol";
import {
    StreamViewPreservationCheckpointTokenV1 as CheckpointToken
} from "../../../smart-contracts/domains/finality/StreamViewPreservationCheckpointTokenV1.sol";
import {
    StreamViewPreservationManifestReadsV1 as ManifestReads
} from "../../../smart-contracts/domains/finality/StreamViewPreservationManifestReadsV1.sol";
import {
    StreamViewPreservationManifestEncodingV1 as ManifestEncoding
} from "../../../smart-contracts/domains/finality/StreamViewPreservationManifestEncodingV1.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

import {
    StreamCollectionViews
} from "../../../smart-contracts/domains/metadata/StreamCollectionViews.sol";
import {
    StreamViewAdoptionTypes as Declaration
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamViewSourceBinding as DeclarationAPI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    IStreamViewPolicySourceBindingV2 as PolicyAPI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    IStreamCollectionViews as Views
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamModuleRegistry as Modules
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamViewRouteReadBudgetV1 as RouteBudget
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewRouteReadBudgetV1.sol";
import {
    StreamViewAdoptionReads as OriginalViewReads
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionReads.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as PolicyReads
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as PolicyFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityBoundedReads as BoundReads
} from "../../../smart-contracts/domains/finality/StreamFinalityBoundedReads.sol";

interface ViewBindingVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function mockCall(address, bytes calldata, bytes calldata) external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function etch(address, bytes calldata) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Only serving configuration is a named boundary: these tests do not adopt a VIEW,
/// produce render bytes or prove complete VIEW finality. Checkpoint/manifest/snapshot constructors
/// and the provider are real. The inherited Core/Registry/Artist and executor boundaries remain.
contract ViewBindingServingBoundary {
    Serving.Configuration private _configuration;
    bytes32 public immutable configurationHash;

    constructor(Serving.Configuration memory c) {
        _configuration = c;
        configurationHash = keccak256(abi.encode(c));
    }

    function configuration() external view returns (Serving.Configuration memory) {
        return _configuration;
    }

    function preservationProfile() external pure returns (bytes32) {
        return C.OUTPUT_PROFILE;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(Serving).interfaceId;
    }
}

/// @dev Guard-level probe for the unchanged original Current._route eligibility check.
/// This does not fabricate an adopted record or execute the composed current VIEW route.
contract ViewBindingOriginalEligibilityProbe {
    function requireEligible(address modules, address views, uint256 cap) external view {
        OriginalViewReads.eligible(
            modules, views, keccak256("COLLECTION_VIEWS"), type(Views).interfaceId, cap
        );
    }
}

contract StreamFinalityViewPreservationBindingV1Test is
    StreamFinalityFullPreservationPolicyDiscoveryV1Test
{
    ViewBindingVm private constant bvm =
        ViewBindingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Checkpoint private viewCheckpoint;
    Manifest private viewManifest;
    Snapshot private viewSnapshot;
    VB.Configuration private binding;
    Declaration.Binding private declaration;
    StreamCollectionViews private declaredViews;
    address private declaredModules;
    bytes32 private oldSourceHash;
    bytes32 private constant ACTION = keccak256("explicit component class2 VIEW binding");

    function setUp() public override {
        super.setUp();
        oldSourceHash = fullProvider.finalitySourceConfigurationHash();
        declaredViews = new StreamCollectionViews(
            StreamCollectionViews.Configuration(
                address(core),
                address(metadata),
                address(executor),
                keccak256("declaration deployment"),
                "ipfs://view-declaration-component",
                keccak256("declaration manifest"),
                Gas.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 2000000, 50000, 2)
            )
        );
        declaration = Declaration.Binding(
            address(declaredViews),
            address(declaredViews).codehash,
            address(scopedMembership),
            address(scopedMembership).codehash,
            2000000,
            4000000
        );
        (declaredModules,,,,,,,,,) = core.getSatellitePointer(keccak256("MODULE_REGISTRY"));
        // Actual original CollectionViews constructor; module admission is the inherited typed
        // Registry boundary. There is deliberately no invented COLLECTION_VIEWS Core pointer.
        bvm.mockCall(
            declaredModules,
            abi.encodeCall(
                Modules.isModuleEligible,
                (address(declaredViews), keccak256("COLLECTION_VIEWS"), type(Views).interfaceId)
            ),
            abi.encode(true)
        );

        Serving.Configuration memory serving = Serving.Configuration(
            address(core),
            address(core).codehash,
            address(router),
            address(router).codehash,
            address(this),
            address(this).codehash,
            block.chainid,
            1000000,
            1000000
        );
        ViewBindingServingBoundary route = new ViewBindingServingBoundary(serving);
        viewCheckpoint = new Checkpoint(
            C.Configuration(
                address(core),
                address(core).codehash,
                address(router),
                address(router).codehash,
                address(executor),
                address(executor).codehash,
                address(route),
                address(route).codehash,
                route.configurationHash(),
                block.chainid,
                2000000,
                4000000
            )
        );
        viewManifest = new Manifest(
            M.Configuration(
                address(core),
                address(core).codehash,
                address(viewCheckpoint),
                address(viewCheckpoint).codehash,
                viewCheckpoint.configurationHash(),
                address(snapshotCoverage),
                address(snapshotCoverage).codehash,
                address(schemas),
                address(schemas).codehash,
                block.chainid,
                2000000,
                6000000
            )
        );
        S.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(scopedMembership),
            address(viewCheckpoint),
            address(viewManifest),
            address(snapshotCoverage),
            address(executor)
        ];
        for (uint256 i; i < 10; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 2000000;
        d.sourceGas = 8000000;
        d.inventoryGas = 4000000;
        Gas.GasParameterConfig[3] memory gasConfig;
        gasConfig[0] =
            Gas.GasParameterConfig("VIEW_PRESERVATION_SNAPSHOT_READ_GAS", d.readGas, 50000, 2);
        gasConfig[1] =
            Gas.GasParameterConfig("VIEW_PRESERVATION_SNAPSHOT_SOURCE_GAS", d.sourceGas, 50000, 2);
        gasConfig[2] = Gas.GasParameterConfig(
            "VIEW_PRESERVATION_SNAPSHOT_INVENTORY_GAS", d.inventoryGas, 50000, 2
        );
        viewSnapshot = new Snapshot(d, address(executor), gasConfig);
        binding = VB.Configuration(
            address(viewSnapshot),
            address(viewSnapshot).codehash,
            16000000,
            address(viewCheckpoint),
            address(viewCheckpoint).codehash,
            address(viewManifest),
            address(viewManifest).codehash
        );
    }

    function testViewBindingPendingCapabilityNeverAdvertisesReadySource() public {
        require(
            fullProvider.supportsInterface(type(Evidence).interfaceId)
                && fullProvider.supportsInterface(type(Binding).interfaceId)
        );
        require(fullProvider.viewPreservationBindingStatus() == 0);
        require(
            fullProvider.supportsInterface(type(DeclarationAPI).interfaceId)
                && fullProvider.supportsInterface(type(PolicyAPI).interfaceId)
        );
        require(fullProvider.supportsInterface(type(RouteBudget).interfaceId));
        bvm.expectRevert(VB.ViewPreservationPending.selector);
        fullProvider.viewRouteReadBudget();
        bvm.expectRevert(VB.ViewPreservationPending.selector);
        fullProvider.viewSourceBinding();
        bvm.expectRevert(VB.ViewPreservationPending.selector);
        fullProvider.viewPolicySourceFactoryV2();
        bvm.expectRevert(VB.ViewPreservationPending.selector);
        fullProvider.viewPolicySourceFactoryV2CodeHash();
        require(fullProvider.viewPreservationBindingReceipt().recordHash == 0);
        bvm.expectRevert(VB.ViewPreservationPending.selector);
        fullProvider.viewPreservationSnapshotHost();
        bvm.expectRevert(VB.ViewPreservationPending.selector);
        fullProvider.viewPreservationSnapshotCodeHash();
        bvm.expectRevert(VB.ViewPreservationPending.selector);
        fullProvider.viewPreservationSnapshotValidationGas();
        _unsupported();
    }

    function testViewBindingExactClassTwoReceiptEventAndFixedOldSources() public {
        VB.Transition memory t =
            fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.recordLogs();
        _bind(t);
        VB.Receipt memory r = fullProvider.viewPreservationBindingReceipt();
        require(
            r.actionId == ACTION && r.boundAt == uint64(block.timestamp)
                && r.recordHash == VB.receiptHash(r)
        );
        require(keccak256(abi.encode(r.declaration)) == keccak256(abi.encode(declaration)));
        require(r.dependenciesHash == keccak256(abi.encode(viewSnapshot.dependencies())));
        require(t.newValueHash == VB.proposalHash(r));
        require(
            t.scopeHash
                == keccak256(
                    abi.encode(VB.PROFILE, block.chainid, address(fullProvider), r.capabilityHash)
                )
        );
        require(t.oldValueHash == keccak256(abi.encode(VB.PROFILE, r.capabilityHash, false)));
        ViewBindingVm.Log[] memory logs = bvm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(fullProvider));
        require(
            logs[0].topics[0]
                == keccak256("ViewPreservationBound(bytes32,bytes32,address,bytes32,bytes32)")
        );
        require(
            logs[0].topics[1] == r.recordHash && logs[0].topics[2] == ACTION
                && logs[0].topics[3] == bytes32(uint256(uint160(address(viewSnapshot))))
        );
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(VB.proposalHash(r), r.dependenciesHash))
        );
        _ready();
        _unsupported();
    }

    function testViewBindingUnauthorizedCallerAndNoSecondBind() public {
        bvm.expectRevert(VB.ViewPreservationBindingGovernance.selector);
        fullProvider.bindViewPreservation(binding, declaration);
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        bytes32 record = fullProvider.viewPreservationBindingReceipt().recordHash;
        bvm.expectRevert(VB.ViewPreservationAlreadyBound.selector);
        fullProvider.bindViewPreservation(binding, declaration);
        bvm.expectRevert(VB.ViewPreservationAlreadyBound.selector);
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        require(fullProvider.viewPreservationBindingReceipt().recordHash == record);
    }

    function testViewBindingRejectsWrongClassScopeOldNewAndUnusedAction() public {
        VB.Transition memory t =
            fullProvider.viewPreservationBindingTransition(binding, declaration);
        for (uint256 i; i < 6; ++i) {
            _action(
                i != 5,
                i == 4 ? bytes32(0) : ACTION,
                i == 0 ? uint8(1) : uint8(2),
                i == 1 ? bytes32(0) : t.scopeHash,
                i == 2 ? bytes32(0) : t.oldValueHash,
                i == 3 ? bytes32(0) : t.newValueHash
            );
            bvm.expectRevert(VB.ViewPreservationBindingGovernance.selector);
            executor.execute(
                address(fullProvider),
                abi.encodeCall(Binding.bindViewPreservation, (binding, declaration)),
                t.scopeHash,
                t.oldValueHash,
                t.newValueHash
            );
            require(fullProvider.viewPreservationBindingStatus() == 0);
        }
        _bind(t);
        _ready();
    }

    function testViewBindingRejectsChangedRuntimeAndWrongExplicitSources() public {
        VB.Configuration memory c = binding;
        c.snapshotCodeHash = bytes32(uint256(1));
        bvm.expectRevert(
            abi.encodeWithSelector(VB.ViewPreservationBindingDependency.selector, c.snapshotHost)
        );
        fullProvider.viewPreservationBindingTransition(c, declaration);
        c = binding;
        c.checkpointHost = address(viewManifest);
        c.checkpointCodeHash = address(viewManifest).codehash;
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(c, declaration);
        c = binding;
        c.manifestHost = address(viewCheckpoint);
        c.manifestCodeHash = address(viewCheckpoint).codehash;
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(c, declaration);
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        _ready();
    }

    function testViewBindingRequiresExplicitSnapshotCapability() public {
        bytes memory input =
            abi.encodeCall(IERC165.supportsInterface, (type(SnapshotInterface).interfaceId));
        bvm.mockCall(address(viewSnapshot), input, abi.encode(false));
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.mockCall(address(viewSnapshot), input, abi.encode(true));
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
    }

    function testViewBindingRejectsEveryForeignDependencyAndChain() public {
        S.Dependencies memory saved = viewSnapshot.dependencies();
        bytes memory input = abi.encodeCall(SnapshotInterface.dependencies, ());
        for (uint256 i; i < 10; ++i) {
            S.Dependencies memory d = abi.decode(abi.encode(saved), (S.Dependencies));
            d.targets[i] = address(this);
            d.codeHashes[i] = address(this).codehash;
            bvm.mockCall(address(viewSnapshot), input, abi.encode(d));
            bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
            fullProvider.viewPreservationBindingTransition(binding, declaration);
        }
        S.Dependencies memory wrongChain = abi.decode(abi.encode(saved), (S.Dependencies));
        ++wrongChain.chainId;
        bvm.mockCall(address(viewSnapshot), input, abi.encode(wrongChain));
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.mockCall(address(viewSnapshot), input, abi.encode(saved));
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
    }

    function testViewBindingInitialBudgetCapAndMissingTupleReject() public {
        VB.Configuration memory c = binding;
        c.validationGas = 16777217;
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(c, declaration);
        c = binding;
        c.validationGas = originalProviderConfig.readGas - 1;
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(c, declaration);
        bvm.mockCall(
            address(viewSnapshot),
            abi.encodeCall(SnapshotInterface.dependencies, ()),
            abi.encode(bytes32(0))
        );
        (bool ok,) = address(fullProvider)
            .staticcall(
                abi.encodeCall(Binding.viewPreservationBindingTransition, (binding, declaration))
            );
        require(!ok && fullProvider.viewPreservationBindingStatus() == 0);
    }

    function testViewBindingMonotonicBudgetsKeepOriginalReceiptWithinCap() public {
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        VB.Receipt memory r = fullProvider.viewPreservationBindingReceipt();
        S.Dependencies memory grown = abi.decode(abi.encode(r.dependencies), (S.Dependencies));
        grown.readGas *= 2;
        grown.sourceGas = 12000000;
        grown.inventoryGas *= 2;
        // Explicit returned-parameter boundary; genuine governed gas raises are tested separately.
        bvm.mockCall(
            address(viewSnapshot),
            abi.encodeCall(SnapshotInterface.dependencies, ()),
            abi.encode(grown)
        );
        _ready();
        require(
            keccak256(abi.encode(fullProvider.viewPreservationBindingReceipt()))
                == keccak256(abi.encode(r))
        );
    }

    function testViewBindingRejectsImpossibleNestedForwardingCaps() public {
        S.Dependencies memory d = viewSnapshot.dependencies();
        VB.Configuration memory c = binding;
        c.validationGas = d.sourceGas;
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(c, declaration);
        c.validationGas = d.sourceGas + d.sourceGas / 63 + 10000;
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(c, declaration);
        // Outer cap is adequate, but Snapshot cannot forward its whole source cap to a
        // Manifest that itself must forward the identical cap to Checkpoint.
        S.Dependencies memory impossible = abi.decode(abi.encode(d), (S.Dependencies));
        impossible.sourceGas = viewManifest.configuration().checkpointGas;
        bvm.mockCall(
            address(viewSnapshot),
            abi.encodeCall(SnapshotInterface.dependencies, ()),
            abi.encode(impossible)
        );
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.mockCall(
            address(viewSnapshot), abi.encodeCall(SnapshotInterface.dependencies, ()), abi.encode(d)
        );
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        _ready();
    }

    function testViewBindingBudgetReductionAndOverCapFailClosedWithHistory() public {
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        VB.Receipt memory r = fullProvider.viewPreservationBindingReceipt();
        for (uint256 i; i < 3; ++i) {
            S.Dependencies memory d = abi.decode(abi.encode(r.dependencies), (S.Dependencies));
            if (i == 0) --d.readGas;
            else if (i == 1) --d.sourceGas;
            else --d.inventoryGas;
            bvm.mockCall(
                address(viewSnapshot),
                abi.encodeCall(SnapshotInterface.dependencies, ()),
                abi.encode(d)
            );
            bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
            fullProvider.viewPreservationSnapshotHost();
        }
        S.Dependencies memory over = abi.decode(abi.encode(r.dependencies), (S.Dependencies));
        over.sourceGas = binding.validationGas + 1;
        bvm.mockCall(
            address(viewSnapshot),
            abi.encodeCall(SnapshotInterface.dependencies, ()),
            abi.encode(over)
        );
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationSnapshotValidationGas();
        require(fullProvider.viewPreservationBindingReceipt().recordHash == r.recordHash);
        bvm.mockCall(
            address(viewSnapshot),
            abi.encodeCall(SnapshotInterface.dependencies, ()),
            abi.encode(r.dependencies)
        );
        _ready();
    }

    function testViewBindingAllFiveWorkerRuntimePinsAreOperative() public {
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        bytes32 saved = fullProvider.viewPreservationBindingReceipt().recordHash;
        address[5] memory workers = [
            address(Sources),
            address(CheckpointSource),
            address(CheckpointToken),
            address(ManifestReads),
            address(ManifestEncoding)
        ];
        for (uint256 i; i < workers.length; ++i) {
            bytes memory originalCode = workers[i].code;
            bvm.etch(workers[i], hex"00");
            (bool ok,) = address(fullProvider)
                .staticcall(abi.encodeCall(Evidence.viewPreservationSnapshotHost, ()));
            require(!ok && fullProvider.viewPreservationBindingReceipt().recordHash == saved);
            bvm.etch(workers[i], originalCode);
            _ready();
        }
    }

    function testViewBindingSnapshotRuntimeDriftPreservesHistoricalReceipt() public {
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        bytes32 saved = fullProvider.viewPreservationBindingReceipt().recordHash;
        bytes memory originalCode = address(viewSnapshot).code;
        bvm.etch(address(viewSnapshot), hex"00");
        bvm.expectRevert(
            abi.encodeWithSelector(
                VB.ViewPreservationBindingDependency.selector, address(viewSnapshot)
            )
        );
        fullProvider.viewPreservationSnapshotCodeHash();
        require(
            fullProvider.viewPreservationBindingStatus() == 1
                && fullProvider.viewPreservationBindingReceipt().recordHash == saved
        );
        // Original declaration resolution is deliberately independent of snapshot currentness.
        require(
            keccak256(abi.encode(fullProvider.viewSourceBinding()))
                == keccak256(abi.encode(declaration))
        );
        bvm.etch(address(viewSnapshot), originalCode);
        _ready();
    }

    function testViewBindingGovernedRouteBudgetUsesOnlySavedScalarAtBootstrapCap() public {
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        (bool ok, bytes memory raw) = address(fullProvider).staticcall{ gas: 100000 }(
            abi.encodeCall(RouteBudget.viewRouteReadBudget, ())
        );
        require(ok && raw.length == 64);
        (bytes32 profile, uint32 readGas) = abi.decode(raw, (bytes32, uint32));
        require(profile == keccak256("6529STREAM_GOVERNED_VIEW_ROUTE_READ_BUDGET_V1"));
        require(
            readGas == declaration.readGas
                && readGas == fullProvider.viewPreservationBindingReceipt().declaration.readGas
        );
        // Bootstrap identifies a saved governed cap, not current snapshot validity.
        bvm.etch(address(viewSnapshot), hex"00");
        (ok, raw) = address(fullProvider).staticcall{ gas: 100000 }(
            abi.encodeCall(RouteBudget.viewRouteReadBudget, ())
        );
        require(ok && keccak256(raw) == keccak256(abi.encode(profile, readGas)));
    }

    function testViewBindingDeclarationPinsMembershipAndBudgetsRejectBeforeAdmission() public {
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        Declaration.Binding memory d = declaration;
        d.viewsCodeHash = bytes32(uint256(1));
        bvm.expectRevert(
            abi.encodeWithSelector(VB.ViewPreservationBindingDependency.selector, d.views)
        );
        fullProvider.viewPreservationBindingTransition(binding, d);
        for (uint256 i; i < 6; ++i) {
            d = declaration;
            if (i == 0) d.membership = address(this);
            else if (i == 1) d.membershipCodeHash = bytes32(uint256(1));
            else if (i == 2) d.readGas = 49999;
            else if (i == 3) d.readGas = 16777217;
            else if (i == 4) d.sourceGas = d.readGas - 1;
            // Actual adoption documents are forwarded from the checkpoint; equality
            // cannot fit the original strict EIP-150 forwarding requirement.
            else d.sourceGas = uint32(viewManifest.configuration().checkpointGas);
            bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
            fullProvider.viewPreservationBindingTransition(binding, d);
            require(fullProvider.viewPreservationBindingStatus() == 0);
        }
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        _ready();
    }

    function testViewBindingProposalCommitsCompleteDeclarationAndRejectsChangedAction() public {
        VB.Transition memory initial =
            fullProvider.viewPreservationBindingTransition(binding, declaration);
        Declaration.Binding memory changed = declaration;
        changed.sourceGas += 100000;
        VB.Transition memory alternative =
            fullProvider.viewPreservationBindingTransition(binding, changed);
        require(
            initial.scopeHash == alternative.scopeHash
                && initial.oldValueHash == alternative.oldValueHash
        );
        require(initial.newValueHash != alternative.newValueHash);
        _action(true, ACTION, 2, initial.scopeHash, initial.oldValueHash, initial.newValueHash);
        bvm.expectRevert(VB.ViewPreservationBindingGovernance.selector);
        executor.execute(
            address(fullProvider),
            abi.encodeCall(Binding.bindViewPreservation, (binding, changed)),
            initial.scopeHash,
            initial.oldValueHash,
            initial.newValueHash
        );
        require(fullProvider.viewPreservationBindingStatus() == 0);
        _bind(initial);
        VB.Receipt memory r = fullProvider.viewPreservationBindingReceipt();
        bytes32 literal = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1"),
                r.capabilityHash,
                r.configuration,
                declaration,
                r.dependencies,
                r.dependenciesHash,
                r.workersHash
            )
        );
        require(initial.newValueHash == literal);
        for (uint256 i; i < 6; ++i) {
            VB.Receipt memory mutation = abi.decode(abi.encode(r), (VB.Receipt));
            if (i == 0) mutation.declaration.views = address(this);
            else if (i == 1) mutation.declaration.viewsCodeHash = bytes32(uint256(1));
            else if (i == 2) mutation.declaration.membership = address(this);
            else if (i == 3) mutation.declaration.membershipCodeHash = bytes32(uint256(1));
            else if (i == 4) ++mutation.declaration.readGas;
            else ++mutation.declaration.sourceGas;
            require(VB.proposalHash(mutation) != literal);
        }
    }

    function testViewBindingDeclarationDriftRejectsAtBindAndOriginalEligibilityGuard() public {
        ViewBindingOriginalEligibilityProbe guard = new ViewBindingOriginalEligibilityProbe();
        guard.requireEligible(declaredModules, address(declaredViews), declaration.readGas);
        VB.Transition memory t =
            fullProvider.viewPreservationBindingTransition(binding, declaration);
        bytes memory key = abi.encodeCall(
            Modules.isModuleEligible,
            (address(declaredViews), keccak256("COLLECTION_VIEWS"), type(Views).interfaceId)
        );
        bvm.mockCall(declaredModules, key, abi.encode(false));
        bvm.expectRevert(
            abi.encodeWithSelector(
                Declaration.ViewAdoptionDependency.selector, address(declaredViews)
            )
        );
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        _action(true, ACTION, 2, t.scopeHash, t.oldValueHash, t.newValueHash);
        bvm.expectRevert(
            abi.encodeWithSelector(
                Declaration.ViewAdoptionDependency.selector, address(declaredViews)
            )
        );
        executor.execute(
            address(fullProvider),
            abi.encodeCall(Binding.bindViewPreservation, (binding, declaration)),
            t.scopeHash,
            t.oldValueHash,
            t.newValueHash
        );
        require(fullProvider.viewPreservationBindingStatus() == 0);
        bvm.mockCall(declaredModules, key, abi.encode(true));
        _bind(t);
        bvm.mockCall(declaredModules, key, abi.encode(false));
        _ready();
        // The exact original internal guard used by Current._route rejects the same drift.
        // Coverage stops at this guard; composed Current/root execution remains separate.
        bvm.expectRevert(
            abi.encodeWithSelector(
                Declaration.ViewAdoptionDependency.selector, address(declaredViews)
            )
        );
        guard.requireEligible(declaredModules, address(declaredViews), declaration.readGas);
        bvm.mockCall(declaredModules, key, abi.encode(true));
        guard.requireEligible(declaredModules, address(declaredViews), declaration.readGas);
        _ready();
    }

    function testViewBindingDeferredReciprocityStillRejectsAtBothOriginalValidators() public {
        S.Dependencies memory d = viewSnapshot.dependencies();
        M.Configuration memory m = viewManifest.configuration();
        Sources.bindings(d);
        ManifestReads.pins(m);
        VB.Transition memory t =
            fullProvider.viewPreservationBindingTransition(binding, declaration);
        bytes memory key = abi.encodeWithSignature("core()");
        bvm.mockCall(address(snapshotCoverage), key, abi.encode(address(this)));
        bvm.expectRevert(
            abi.encodeWithSelector(
                S.ViewPreservationSnapshotDependency.selector, address(snapshotCoverage)
            )
        );
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        _action(true, ACTION, 2, t.scopeHash, t.oldValueHash, t.newValueHash);
        bvm.expectRevert(
            abi.encodeWithSelector(
                S.ViewPreservationSnapshotDependency.selector, address(snapshotCoverage)
            )
        );
        executor.execute(
            address(fullProvider),
            abi.encodeCall(Binding.bindViewPreservation, (binding, declaration)),
            t.scopeHash,
            t.oldValueHash,
            t.newValueHash
        );
        require(fullProvider.viewPreservationBindingStatus() == 0);
        bvm.mockCall(address(snapshotCoverage), key, abi.encode(address(core)));
        _bind(t);
        bvm.mockCall(address(snapshotCoverage), key, abi.encode(address(this)));
        _ready();
        // Genuine fixed validator calls pass before drift, reject the extracted mutable fact,
        // and pass after restoration. This is not a synthetic unknown-record current() probe.
        bvm.expectRevert(
            abi.encodeWithSelector(
                S.ViewPreservationSnapshotDependency.selector, address(snapshotCoverage)
            )
        );
        Sources.bindings(d);
        bvm.expectRevert(M.InvalidViewManifest.selector);
        ManifestReads.pins(m);
        bvm.mockCall(address(snapshotCoverage), key, abi.encode(address(core)));
        Sources.bindings(d);
        ManifestReads.pins(m);
        _ready();
    }

    function testViewBindingOriginalFactoryCapabilityProfileAndExactDependencies() public {
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bytes memory capability =
            abi.encodeCall(IERC165.supportsInterface, (type(PolicyFactory).interfaceId));
        bvm.mockCall(address(scopedFactory), capability, abi.encode(false));
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.mockCall(address(scopedFactory), capability, abi.encode(true));
        bytes memory profile = abi.encodeCall(PolicyFactory.scopedPolicyFactoryProfile, ());
        bvm.mockCall(address(scopedFactory), profile, abi.encode(bytes32(0)));
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.mockCall(
            address(scopedFactory),
            profile,
            abi.encode(keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"))
        );
        PolicyReads.Dependencies memory d = scopedFactory.dependencies();
        PolicyReads.Dependencies memory changed =
            abi.decode(abi.encode(d), (PolicyReads.Dependencies));
        ++changed.chainId;
        bytes memory input = abi.encodeCall(PolicyFactory.dependencies, ());
        bvm.mockCall(address(scopedFactory), input, abi.encode(changed));
        bvm.expectRevert(VB.InvalidViewPreservationBinding.selector);
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.mockCall(address(scopedFactory), input, abi.encode(bytes32(0)));
        bvm.expectRevert(
            abi.encodeWithSelector(BoundReads.FinalityReadFailed.selector, address(scopedFactory))
        );
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.mockCall(address(scopedFactory), input, abi.encode(d));
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        _ready();
    }

    function testViewBindingExtractedValidatorsDoNotRemoveDependencyRuntimePins() public {
        _bind(fullProvider.viewPreservationBindingTransition(binding, declaration));
        bytes32 saved = fullProvider.viewPreservationBindingReceipt().recordHash;
        C.Configuration memory c = viewCheckpoint.configuration();
        address[2] memory targets = [address(snapshotCoverage), c.serving];
        for (uint256 i; i < targets.length; ++i) {
            bytes memory originalCode = targets[i].code;
            bvm.etch(targets[i], hex"00");
            bvm.expectRevert(
                abi.encodeWithSelector(VB.ViewPreservationBindingDependency.selector, targets[i])
            );
            fullProvider.viewPreservationSnapshotHost();
            require(fullProvider.viewPreservationBindingReceipt().recordHash == saved);
            bvm.etch(targets[i], originalCode);
            _ready();
        }
    }

    function _bind(VB.Transition memory t) private {
        _action(true, ACTION, 2, t.scopeHash, t.oldValueHash, t.newValueHash);
        executor.execute(
            address(fullProvider),
            abi.encodeCall(Binding.bindViewPreservation, (binding, declaration)),
            t.scopeHash,
            t.oldValueHash,
            t.newValueHash
        );
    }

    function _action(
        bool executing,
        bytes32 id,
        uint8 cls,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private {
        bvm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(executing, id, cls, scope, oldHash, newHash)
        );
    }

    function _ready() private view {
        require(fullProvider.viewPreservationBindingStatus() == 1);
        require(fullProvider.viewPreservationSnapshotHost() == address(viewSnapshot));
        require(fullProvider.viewPreservationSnapshotCodeHash() == address(viewSnapshot).codehash);
        require(fullProvider.viewPreservationSnapshotValidationGas() == binding.validationGas);
        require(fullProvider.finalitySourceConfigurationHash() == oldSourceHash);
        require(
            keccak256(abi.encode(fullProvider.viewSourceBinding()))
                == keccak256(abi.encode(declaration))
        );
        require(fullProvider.viewPolicySourceFactoryV2() == address(scopedFactory));
        require(fullProvider.viewPolicySourceFactoryV2CodeHash() == address(scopedFactory).codehash);
    }

    function _unsupported() private view {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("unadopted view"));
        (bool ok,) = address(fullProvider)
            .staticcall(
                abi.encodeWithSignature(
                    "finalitySourcesForScope((uint8,uint256,uint256,bytes32))", scope
                )
            );
        require(!ok, "snapshot source is not complete VIEW profile");
        (ok,) = address(fullProvider)
            .staticcall(
                abi.encodeWithSignature(
                    "inputManifestBytes((uint8,uint256,uint256,bytes32))", scope
                )
            );
        require(!ok, "VIEW finality remains unsupported");
    }
}
