// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityFullPreservationPolicyDiscoveryV1Test
} from "./StreamFinalityFullPreservationPolicyDiscoveryV1.t.sol";
import {
    ViewBindingVm,
    ViewBindingServingBoundary
} from "./StreamFinalityViewPreservationBindingV1.t.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as VB
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as Complete
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as Binding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1 as CompleteBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as CompleteSources
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
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
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamCollectionViews
} from "../../../smart-contracts/domains/metadata/StreamCollectionViews.sol";
import {
    StreamViewAdoptionTypes as Declaration
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamCollectionViews as Views
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamModuleRegistry as Modules
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

/// @dev Same real basic source constructors as the retained basic-binding host. Serving,
/// currentAction and Registry eligibility remain explicitly typed component boundaries.
/// No validator is mocked and no root, reference observation or finality evidence is fabricated.
abstract contract ViewPreservationCompleteBindingFixtureV1 is
    StreamFinalityFullPreservationPolicyDiscoveryV1Test
{
    ViewBindingVm internal constant bvm =
        ViewBindingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Checkpoint internal viewCheckpoint;
    Manifest internal viewManifest;
    Snapshot internal viewSnapshot;
    VB.Configuration internal binding;
    Declaration.Binding internal declaration;
    StreamCollectionViews internal declaredViews;
    address internal declaredModules;
    bytes32 internal oldSourceHash;
    bytes32 internal constant ACTION = keccak256("explicit component complete VIEW binding");

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

    function _complete() internal view returns (CompleteBinding) {
        return CompleteBinding(address(fullProvider));
    }

    function _sources() internal view returns (CompleteSources) {
        return CompleteSources(address(fullProvider));
    }

    function _action(
        bool executing,
        bytes32 id,
        uint8 cls,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) internal {
        bvm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(executing, id, cls, scope, oldHash, newHash)
        );
    }

    function _bindBasic() internal returns (VB.Receipt memory r) {
        VB.Transition memory t =
            fullProvider.viewPreservationBindingTransition(binding, declaration);
        _action(true, ACTION, 2, t.scopeHash, t.oldValueHash, t.newValueHash);
        executor.execute(
            address(fullProvider),
            abi.encodeCall(Binding.bindViewPreservation, (binding, declaration)),
            t.scopeHash,
            t.oldValueHash,
            t.newValueHash
        );
        r = fullProvider.viewPreservationBindingReceipt();
        require(r.recordHash != 0 && r.recordHash == VB.receiptHash(r));
        require(fullProvider.viewPreservationBindingStatus() == 1);
        require(fullProvider.finalitySourceConfigurationHash() == oldSourceHash);
    }

    function _requireNoCompleteSources() internal {
        // Cache typed receivers before expectRevert; the next external call must be the target.
        CompleteSources source = _sources();
        bvm.expectRevert(Complete.ViewPreservationCompleteBindingUnavailable.selector);
        source.viewFinalitySources();
        bvm.expectRevert(Complete.ViewPreservationCompleteBindingUnavailable.selector);
        source.viewFinalitySourcesReceipt();
    }

    function _requireAllClosed(CompleteSources.Selection memory selection) internal {
        CompleteBinding api = _complete();
        bvm.expectRevert(VB.ViewPreservationAlreadyBound.selector);
        fullProvider.viewPreservationBindingTransition(binding, declaration);
        bvm.expectRevert(VB.ViewPreservationAlreadyBound.selector);
        fullProvider.bindViewPreservation(binding, declaration);
        bvm.expectRevert(VB.ViewPreservationAlreadyBound.selector);
        api.completeViewPreservationBindingTransition(binding, declaration, selection);
        bvm.expectRevert(VB.ViewPreservationAlreadyBound.selector);
        api.bindCompleteViewPreservation(binding, declaration, selection);
    }
}

/// @dev These guard regressions use a valid original basic bind. Complete-source acceptance
/// is neither fabricated nor mocked; genuine complete construction has its own current host.
contract StreamFinalityViewPreservationCompleteBindingV1Test is
    ViewPreservationCompleteBindingFixtureV1
{
    function testCompletePendingGettersRejectWithoutChangingOriginalSources() public {
        require(fullProvider.viewPreservationBindingStatus() == 0);
        require(fullProvider.viewPreservationBindingReceipt().recordHash == 0);
        _requireNoCompleteSources();
        require(fullProvider.finalitySourceConfigurationHash() == oldSourceHash);
    }

    function testBasicBindingPermanentlyClosesBothCompleteEntryPoints() public {
        VB.Receipt memory basic = _bindBasic();
        CompleteSources.Selection memory empty;
        _requireAllClosed(empty); // One-use guard precedes malformed selection or caller checks.
        _requireNoCompleteSources();
        require(
            keccak256(abi.encode(fullProvider.viewPreservationBindingReceipt()))
                == keccak256(abi.encode(basic))
        );
        require(fullProvider.finalitySourceConfigurationHash() == oldSourceHash);
    }

    function testBasicOnlyPinDriftKeepsHistoryButNeverCreatesCompleteSelection() public {
        VB.Receipt memory basic = _bindBasic();
        bytes memory saved = address(viewSnapshot).code;
        bvm.etch(address(viewSnapshot), hex"00");
        require(
            keccak256(abi.encode(fullProvider.viewPreservationBindingReceipt()))
                == keccak256(abi.encode(basic))
        );
        _requireNoCompleteSources();
        CompleteSources.Selection memory empty;
        _requireAllClosed(empty);
        bvm.etch(address(viewSnapshot), saved);
        require(fullProvider.viewPreservationSnapshotHost() == address(viewSnapshot));
        _requireNoCompleteSources();
    }

    function testRejectedBasicActionLeavesGlobalGuardOpenForExactRetry() public {
        VB.Transition memory t =
            fullProvider.viewPreservationBindingTransition(binding, declaration);
        _action(true, ACTION, 1, t.scopeHash, t.oldValueHash, t.newValueHash);
        bvm.expectRevert(VB.ViewPreservationBindingGovernance.selector);
        executor.execute(
            address(fullProvider),
            abi.encodeCall(Binding.bindViewPreservation, (binding, declaration)),
            t.scopeHash,
            t.oldValueHash,
            t.newValueHash
        );
        require(fullProvider.viewPreservationBindingStatus() == 0);
        require(fullProvider.viewPreservationBindingReceipt().recordHash == 0);
        _requireNoCompleteSources();
        require(
            keccak256(
                abi.encode(fullProvider.viewPreservationBindingTransition(binding, declaration))
            ) == keccak256(abi.encode(t))
        );
        _bindBasic();
        _requireNoCompleteSources();
    }
}
