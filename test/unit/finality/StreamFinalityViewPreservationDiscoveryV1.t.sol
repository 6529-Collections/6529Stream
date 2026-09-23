// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityViewPreservationDiscoveryV1 as Worker
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationDiscoveryV1.sol";
import {
    StreamFinalityDiscoveryTypes as D
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as Basic
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as Complete
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as BasicHost
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1 as CompleteHost
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamViewPreservationEvidenceBindingV1 as SnapshotBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    IStreamViewPolicySourceBindingV2 as FactoryBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    IStreamFinalityEntropySourceFactory as Factory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityCurrentEntropyRoute as EntropyRoute
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    IStreamArtworkScopedFinalityComponent as ScopedComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamPreservationInventoryTypes as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as Checkpoint
} from "../../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationCheckpointSourceV1 as CheckpointSource
} from "../../../smart-contracts/domains/finality/StreamViewPreservationCheckpointSourceV1.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface ViewDiscoveryVm {
    function warp(uint256) external;
    function etch(address, bytes calldata) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
}

/// @dev Explicit typed transport only. Unknown calls fail rather than inventing producer state.
contract ViewDiscoveryReadTable {
    struct Reply {
        bytes value;
        bytes failure;
        uint256 minimumGas;
        uint256 maximumGas;
        bool known;
    }
    mapping(bytes32 => Reply) private _replies;
    error UnexpectedRead(bytes4 selector);
    error WrongReadBudget(uint256 available);

    function set(bytes memory input, bytes memory value) external {
        _replies[keccak256(input)] = Reply(value, "", 0, 0, true);
    }

    function reject(bytes memory input, bytes memory failure) external {
        _replies[keccak256(input)] = Reply("", failure, 0, 0, true);
    }

    function budget(bytes memory input, uint256 minimum, uint256 maximum) external {
        Reply storage r = _replies[keccak256(input)];
        require(r.known, "configure reply first");
        r.minimumGas = minimum;
        r.maximumGas = maximum;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        uint256 available = gasleft();
        Reply storage r = _replies[keccak256(input)];
        if (!r.known) revert UnexpectedRead(msg.sig);
        if (available < r.minimumGas || (r.maximumGas != 0 && available > r.maximumGas)) {
            revert WrongReadBudget(available);
        }
        bytes memory failure = r.failure;
        if (failure.length != 0) {
            assembly ("memory-safe") { revert(add(failure, 32), mload(failure)) }
        }
        return r.value;
    }
}

contract ViewDiscoveryHarness {
    function profile(D.Configuration memory c, StreamFinalityScope memory scope)
        external
        view
        returns (Profiles.Profile memory)
    {
        return Worker.profile(c, scope);
    }

    function requireServing(D.Configuration memory c, StreamFinalityScope memory scope)
        external
        view
    {
        Worker.requireServing(c, scope);
    }
}

/// @dev Real fixed Discovery worker with explicit provider/producer transport tables. Only
/// CheckpointSource.current is mocked for serving-route isolation. These tests do not prove
/// actual VIEW admission, producer currentness, nine-component evidence or a Finality ceremony.
contract StreamFinalityViewPreservationDiscoveryV1Test {
    ViewDiscoveryVm private constant vm =
        ViewDiscoveryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant BASIC_PROFILE =
        keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_BINDING_V1");
    bytes32 private constant COMPLETE_PROFILE =
        keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1");
    bytes32 private constant VIEW_PROFILE = keccak256("6529STREAM_VIEW_PRESERVATION_FINALITY_V1");
    bytes32 private constant ACTION = keccak256("synthetic same binding action");
    bytes32 private constant ORIGINAL_HASH =
        keccak256("synthetic original constructor configuration");
    address[20] private nodes;
    D.Configuration private config;
    StreamFinalityScope private scope;
    Basic.Capability private capability;
    Basic.Receipt private basic;
    Sources.Receipt private complete;
    Checkpoint.Configuration private checkpoint;
    ViewDiscoveryHarness private harness;
    error ForbiddenRecursiveSurface();
    error WrongCheckpointArguments();

    function setUp() public {
        vm.warp(1000);
        for (uint256 i; i < nodes.length; ++i) {
            nodes[i] = address(new ViewDiscoveryReadTable());
        }
        harness = new ViewDiscoveryHarness();
        config.core = nodes[0];
        config.metadata = nodes[1];
        config.router = nodes[2];
        config.provider = nodes[3];
        config.membership = nodes[4];
        // Original catalogue targets differ from the selected VIEW profile.
        config.entropyFactory = nodes[18];
        config.artist = nodes[6];
        config.finalityRegistry = nodes[7];
        config.finalityRegistryCodeHash = nodes[7].codehash;
        config.referenceRender = nodes[19];
        config.readGas = 500000;
        config.componentGas = 3000000;
        config.entropyGas = 3000000;
        scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 7, 0, keccak256("declared view"));
        capability = Basic.Capability(nodes[14], nodes[14].codehash, ORIGINAL_HASH, bytes32(0));
        capability.capabilityHash = keccak256(
            abi.encode(
                BASIC_PROFILE,
                block.chainid,
                nodes[3],
                capability.authority,
                capability.authorityCodeHash,
                capability.originalHash
            )
        );
        basic.capabilityHash = capability.capabilityHash;
        basic.configuration = Basic.Configuration(
            nodes[8],
            nodes[8].codehash,
            2000000,
            nodes[9],
            nodes[9].codehash,
            nodes[10],
            nodes[10].codehash
        );
        basic.declaration.views = nodes[15];
        basic.declaration.viewsCodeHash = nodes[15].codehash;
        basic.declaration.membership = nodes[4];
        basic.declaration.membershipCodeHash = nodes[4].codehash;
        basic.declaration.readGas = 500000;
        basic.declaration.sourceGas = 2000000;
        basic.dependencies.targets = [
            nodes[0],
            nodes[1],
            nodes[17],
            nodes[18],
            nodes[2],
            nodes[4],
            nodes[9],
            nodes[10],
            nodes[19],
            nodes[14]
        ];
        for (uint256 i; i < 10; ++i) {
            basic.dependencies.codeHashes[i] = basic.dependencies.targets[i].codehash;
        }
        basic.dependencies.chainId = block.chainid;
        basic.dependencies.readGas = 500000;
        basic.dependencies.sourceGas = 2000000;
        basic.dependencies.inventoryGas = 1000000;
        basic.dependenciesHash = keccak256(abi.encode(basic.dependencies));
        basic.workersHash = keccak256("synthetic initial worker pins");
        basic.actionId = ACTION;
        basic.boundAt = 900;
        complete.selection = Sources.Selection(
            nodes[11],
            nodes[11].codehash,
            nodes[12],
            nodes[12].codehash,
            nodes[13],
            nodes[13].codehash
        );
        complete.referenceDependenciesHash = keccak256("initial reference dependencies");
        complete.inventoryDependenciesHash = keccak256("initial inventory dependencies");
        complete.bundleDependenciesHash = keccak256("initial bundle dependencies");
        complete.actionId = ACTION;
        complete.boundAt = 900;
        _reseal();
        checkpoint = Checkpoint.Configuration(
            nodes[0],
            nodes[0].codehash,
            nodes[2],
            nodes[2].codehash,
            nodes[14],
            nodes[14].codehash,
            nodes[16],
            nodes[16].codehash,
            keccak256("synthetic serving configuration"),
            block.chainid,
            500000,
            2000000
        );
        _set(nodes[9], "configuration()", abi.encode(checkpoint));
        _set(nodes[9], "configurationHash()", abi.encode(keccak256(abi.encode(checkpoint))));
        _support(type(IERC165).interfaceId, true);
        _support(type(BasicHost).interfaceId, true);
        _support(type(CompleteHost).interfaceId, true);
        _support(type(Sources).interfaceId, true);
        _support(type(SnapshotBinding).interfaceId, true);
        _support(type(FactoryBinding).interfaceId, true);
        _support(0xffffffff, false);
        _supports(nodes[5], type(Factory).interfaceId, true);
        _supports(nodes[5], type(EntropyRoute).interfaceId, true);
        _supports(nodes[11], type(ScopedComponent).interfaceId, true);
        _supports(nodes[5], type(IERC165).interfaceId, true);
        _supports(nodes[5], 0xffffffff, false);
        _supports(nodes[11], type(IERC165).interfaceId, true);
        _supports(nodes[11], 0xffffffff, false);
        _set(nodes[8], "core()", abi.encode(nodes[0]));
        _set(nodes[8], "metadataHost()", abi.encode(nodes[1]));
        _set(nodes[11], "core()", abi.encode(nodes[0]));
        _set(nodes[11], "metadataHost()", abi.encode(nodes[1]));
        _set(nodes[11], "metadataRouter()", abi.encode(nodes[2]));
        _set(nodes[11], "snapshots()", abi.encode(nodes[8]));
        _set(nodes[5], "core()", abi.encode(nodes[0]));
        _set(nodes[5], "metadataHost()", abi.encode(nodes[1]));
        _set(nodes[5], "scopeMembershipHost()", abi.encode(nodes[4]));
        _set(nodes[3], "viewPreservationBindingProfile()", abi.encode(BASIC_PROFILE));
        _set(nodes[3], "completeViewPreservationBindingProfile()", abi.encode(COMPLETE_PROFILE));
        _set(nodes[3], "viewPreservationBindingStatus()", abi.encode(uint8(1)));
        _set(nodes[3], "viewPreservationSnapshotHost()", abi.encode(nodes[8]));
        _set(nodes[3], "viewPreservationSnapshotCodeHash()", abi.encode(nodes[8].codehash));
        _set(nodes[3], "viewPreservationSnapshotValidationGas()", abi.encode(uint256(2000000)));
        _set(nodes[3], "viewPolicySourceFactoryV2()", abi.encode(nodes[5]));
        _set(nodes[3], "viewPolicySourceFactoryV2CodeHash()", abi.encode(nodes[5].codehash));
        _publish();
        _poisonRecursive();
    }

    function testLiteralProfileReconstructionDoesNotCallCatalogueOrEvidence() public view {
        _valid();
    }

    function testOperativeReadsUseComponentBudgetAndScalarReadsStayBounded() public {
        ViewDiscoveryReadTable p = ViewDiscoveryReadTable(nodes[3]);
        p.budget(
            abi.encodeWithSignature("viewFinalitySources()"),
            config.readGas + 1,
            config.componentGas
        );
        p.budget(
            abi.encodeWithSignature("viewPreservationSnapshotHost()"),
            config.readGas + 1,
            config.componentGas
        );
        p.budget(abi.encodeWithSignature("viewPreservationBindingReceipt()"), 0, config.readGas);
        p.budget(abi.encodeWithSignature("viewFinalitySourcesReceipt()"), 0, config.readGas);
        p.budget(abi.encodeWithSignature("viewPolicySourceFactoryV2()"), 0, config.readGas);
        _valid();
    }

    function testPendingAndBasicOnlySelectionRejectThenSameInputRecovers() public {
        bytes memory input = abi.encodeWithSignature("viewFinalitySources()");
        _set(nodes[3], "viewPreservationBindingStatus()", abi.encode(uint8(0)));
        _invalidProfile(nodes[3]);
        _set(nodes[3], "viewPreservationBindingStatus()", abi.encode(uint8(1)));
        ViewDiscoveryReadTable(nodes[3])
            .reject(input, abi.encodeWithSelector(Basic.ViewPreservationPending.selector));
        _profileReject(abi.encodeWithSelector(Inventory.InventoryRead.selector, nodes[3]));
        ViewDiscoveryReadTable(nodes[3])
            .reject(
                input,
                abi.encodeWithSelector(Complete.ViewPreservationCompleteBindingUnavailable.selector)
            );
        _profileReject(abi.encodeWithSelector(Inventory.InventoryRead.selector, nodes[3]));
        ViewDiscoveryReadTable(nodes[3])
            .set(input, abi.encode(Sources.Selection(address(0), 0, address(0), 0, address(0), 0)));
        _invalidProfile(nodes[3]);
        ViewDiscoveryReadTable(nodes[3]).set(input, abi.encode(complete.selection));
        _valid();
    }

    function testOnlyCanonicalViewScopeIsAdmitted() public {
        StreamFinalityScope memory original = scope;
        scope.scopeType = StreamFinalityScopeType.COLLECTION;
        _profileReject();
        scope = original;
        scope.collectionId = 0;
        _profileReject();
        scope = original;
        scope.tokenId = 1;
        _profileReject();
        scope = original;
        scope.scopeId = 0;
        _profileReject();
        scope = original;
        _valid();
    }

    function testWrongProfilesAndIncompleteERC165AreRejected() public {
        _set(nodes[3], "viewPreservationBindingProfile()", abi.encode(COMPLETE_PROFILE));
        _invalidProfile(nodes[3]);
        _set(nodes[3], "viewPreservationBindingProfile()", abi.encode(BASIC_PROFILE));
        _set(nodes[3], "completeViewPreservationBindingProfile()", abi.encode(BASIC_PROFILE));
        _invalidProfile(nodes[3]);
        _set(nodes[3], "completeViewPreservationBindingProfile()", abi.encode(COMPLETE_PROFILE));
        bytes4[6] memory ids = [
            type(IERC165).interfaceId,
            type(BasicHost).interfaceId,
            type(CompleteHost).interfaceId,
            type(Sources).interfaceId,
            type(SnapshotBinding).interfaceId,
            type(FactoryBinding).interfaceId
        ];
        for (uint256 i; i < ids.length; ++i) {
            _support(ids[i], false);
            _invalidProfile(nodes[3]);
            _support(ids[i], true);
        }
        _support(0xffffffff, true);
        _invalidProfile(nodes[3]);
        _support(0xffffffff, false);
        _valid();
    }

    function testMalformedAndNoncanonicalSelectionAndReceiptRepliesReject() public {
        bytes memory good = abi.encode(complete.selection);
        _set(nodes[3], "viewFinalitySources()", abi.encodePacked(good, bytes32(0)));
        _profileReject();
        _set(nodes[3], "viewFinalitySources()", new bytes(160));
        _profileReject();
        bytes memory dirty = abi.encode(complete.selection);
        _word(dirty, 0, bytes32(uint256(uint160(nodes[11])) | (uint256(1) << 200)));
        _set(nodes[3], "viewFinalitySources()", dirty);
        _profileReject();
        _set(nodes[3], "viewFinalitySources()", good);
        _set(nodes[3], "viewFinalitySourcesReceipt()", new bytes(384));
        _profileReject();
        dirty = abi.encode(complete);
        _word(dirty, 11, bytes32(uint256(1) << 80));
        _set(nodes[3], "viewFinalitySourcesReceipt()", dirty);
        _profileReject();
        _set(nodes[3], "viewFinalitySourcesReceipt()", abi.encode(complete));
        _set(
            nodes[3],
            "viewPreservationBindingReceipt()",
            abi.encodePacked(abi.encode(basic), bytes32(0))
        );
        _profileReject();
        _publish();
        _valid();
    }

    function testReceiptCommitmentsAndCrossJoinsCannotBeRepairedByOneHash() public {
        Sources.Receipt memory saved = complete;
        complete.recordHash ^= bytes32(uint256(1));
        _publish();
        _invalidProfile(nodes[3]);
        complete = saved;
        complete.actionId = keccak256("different action");
        complete.recordHash = _completeHash(complete);
        _publish();
        _invalidProfile(nodes[3]);
        complete = saved;
        complete.boundAt -= 1;
        complete.recordHash = _completeHash(complete);
        _publish();
        _invalidProfile(nodes[3]);
        complete = saved;
        complete.basicBindingRecordHash = keccak256("other basic record");
        complete.recordHash = _completeHash(complete);
        _publish();
        _invalidProfile(nodes[3]);
        complete = saved;
        complete.inventoryDependenciesHash = 0;
        complete.recordHash = _completeHash(complete);
        _publish();
        _invalidProfile(nodes[3]);
        complete = saved;
        _publish();
        Basic.Receipt memory savedBasic = basic;
        basic.recordHash ^= bytes32(uint256(1));
        complete.basicBindingRecordHash = basic.recordHash;
        complete.recordHash = _completeHash(complete);
        _publish();
        _invalidProfile(nodes[3]);
        basic = savedBasic;
        complete = saved;
        _publish();
        _valid();
    }

    function testChangedOperativeSelectionAndSnapshotRefuseHistoricalReceipt() public {
        Sources.Selection memory changed = complete.selection;
        changed.referencePublication = nodes[10];
        _set(nodes[3], "viewFinalitySources()", abi.encode(changed));
        _invalidProfile(nodes[3]);
        _set(nodes[3], "viewFinalitySources()", abi.encode(complete.selection));
        _set(nodes[3], "viewPreservationSnapshotHost()", abi.encode(nodes[10]));
        _invalidProfile(nodes[3]);
        _set(nodes[3], "viewPreservationSnapshotHost()", abi.encode(nodes[8]));
        _valid();
    }

    function testRehashedBasicReceiptStillRequiresOriginalDependenciesAndCapability() public {
        Basic.Receipt memory savedBasic = basic;
        Sources.Receipt memory savedComplete = complete;
        for (uint256 i; i < 13; ++i) {
            basic = savedBasic;
            complete = savedComplete;
            if (i == 0) basic.capabilityHash ^= bytes32(uint256(1));
            if (i == 1) basic.dependencies.chainId += 1;
            if (i == 2) basic.dependencies.targets[0] = nodes[10];
            if (i == 3) basic.dependencies.targets[1] = nodes[10];
            if (i == 4) basic.dependencies.targets[4] = nodes[10];
            if (i == 5) basic.dependencies.targets[5] = nodes[10];
            if (i == 6) basic.dependencies.targets[6] = nodes[10];
            if (i == 7) basic.dependencies.targets[7] = nodes[9];
            if (i == 8) basic.dependencies.targets[9] = nodes[10];
            if (i == 9) basic.declaration.membership = nodes[10];
            if (i == 10) basic.workersHash = 0;
            if (i == 11) basic.actionId = 0;
            if (i == 12) basic.boundAt = uint64(block.timestamp + 1);
            basic.dependenciesHash = keccak256(abi.encode(basic.dependencies));
            complete.actionId = basic.actionId;
            complete.boundAt = basic.boundAt;
            _reseal();
            _publish();
            _invalidProfile(nodes[3]);
        }
        basic = savedBasic;
        complete = savedComplete;
        bytes32 savedCapability = capability.capabilityHash;
        // All receipt hashes are repaired, but the capability was made for another provider.
        capability.capabilityHash = keccak256(
            abi.encode(
                BASIC_PROFILE,
                block.chainid,
                nodes[10],
                capability.authority,
                capability.authorityCodeHash,
                capability.originalHash
            )
        );
        basic.capabilityHash = capability.capabilityHash;
        _reseal();
        _publish();
        _invalidProfile(nodes[3]);
        capability.capabilityHash = savedCapability;
        basic = savedBasic;
        complete = savedComplete;
        _publish();
        _valid();
    }

    function testSelectedFactoryAndReferenceRequireExactReciprocityAndInterfaces() public {
        address[9] memory targets = [
            nodes[8],
            nodes[8],
            nodes[11],
            nodes[11],
            nodes[11],
            nodes[11],
            nodes[5],
            nodes[5],
            nodes[5]
        ];
        string[9] memory selectors = [
            "core()",
            "metadataHost()",
            "core()",
            "metadataHost()",
            "metadataRouter()",
            "snapshots()",
            "core()",
            "metadataHost()",
            "scopeMembershipHost()"
        ];
        address[9] memory expected = [
            nodes[0], nodes[1], nodes[0], nodes[1], nodes[2], nodes[8], nodes[0], nodes[1], nodes[4]
        ];
        for (uint256 i; i < targets.length; ++i) {
            _set(targets[i], selectors[i], abi.encode(nodes[10]));
            _invalidProfile(targets[i]);
            _set(targets[i], selectors[i], abi.encode(expected[i]));
        }
        _supports(nodes[5], type(Factory).interfaceId, false);
        _invalidProfile(nodes[5]);
        _supports(nodes[5], type(Factory).interfaceId, true);
        _supports(nodes[5], type(EntropyRoute).interfaceId, false);
        _invalidProfile(nodes[5]);
        _supports(nodes[5], type(EntropyRoute).interfaceId, true);
        _supports(nodes[5], 0xffffffff, true);
        _invalidProfile(nodes[5]);
        _supports(nodes[5], 0xffffffff, false);
        _supports(nodes[11], type(IERC165).interfaceId, false);
        _invalidProfile(nodes[11]);
        _supports(nodes[11], type(IERC165).interfaceId, true);
        _supports(nodes[11], type(ScopedComponent).interfaceId, false);
        _invalidProfile(nodes[11]);
        _supports(nodes[11], type(ScopedComponent).interfaceId, true);
        _set(nodes[3], "viewPolicySourceFactoryV2()", abi.encode(uint256(1) << 200));
        _invalidProfile(nodes[3]);
        _set(nodes[3], "viewPolicySourceFactoryV2()", abi.encode(nodes[5]));
        _valid();
    }

    function testActualSelectedRuntimeChangeFailsThenExactRestorationRecovers() public {
        uint256[8] memory roles = [uint256(8), 9, 10, 11, 12, 13, 14, 5];
        for (uint256 i; i < roles.length; ++i) {
            address target = nodes[roles[i]];
            bytes memory code = target.code;
            vm.etch(target, hex"00");
            _profileReject(abi.encodeWithSelector(Inventory.InventoryRead.selector, target));
            vm.etch(target, code);
            _valid();
        }
    }

    function testServingUsesExactBoundCheckpointAndDoesNotConsumeContextHash() public {
        Checkpoint.Source memory source = _currentSource();
        _allowCurrent(source);
        (bool ok, bytes memory output) =
            address(harness).staticcall(abi.encodeCall(harness.requireServing, (config, scope)));
        require(
            !ok
                && keccak256(output)
                    == keccak256(
                        abi.encodeWithSelector(Worker.InvalidViewDiscovery.selector, nodes[3])
                    ),
            "unprojected catalogue is not selected VIEW"
        );
        harness.requireServing(_projected(), scope);
        source.contextHash = keccak256("different consumer-local context");
        _allowCurrent(source);
        harness.requireServing(_projected(), scope);
    }

    function testServingRejectsOriginalRouteScopeAndDeclarationMismatches() public {
        Checkpoint.Source memory source = _currentSource();
        bytes memory baseline = abi.encode(source);
        for (uint256 i; i < 12; ++i) {
            source = abi.decode(baseline, (Checkpoint.Source));
            if (i == 0) source.adoption.source.route.artist = nodes[10];
            if (i == 1) source.adoption.source.route.finality = nodes[10];
            if (i == 2) source.adoption.source.route.provider = nodes[10];
            if (i == 3) source.adoption.source.route.metadata = nodes[10];
            if (i == 4) source.adoption.source.route.binding.views = nodes[10];
            if (i == 5) source.adoption.source.route.binding.membership = nodes[10];
            if (i == 6) source.adoption.source.route.binding.sourceGas += 1;
            if (i == 7) source.adoption.source.route.finalityCodeHash ^= bytes32(uint256(1));
            if (i == 8) source.adoption.source.route.schemas = nodes[10];
            if (i == 9) source.adoption.source.route.store = nodes[10];
            if (i == 10) source.adoption.source.route.binding.viewsCodeHash ^= bytes32(uint256(1));
            if (i == 11) source.adoption.input.scope.scopeId ^= bytes32(uint256(1));
            _allowCurrent(source);
            _servingReject(
                abi.encodeWithSelector(Worker.InvalidViewDiscovery.selector, config.router)
            );
        }
        source = abi.decode(baseline, (Checkpoint.Source));
        _allowCurrent(source);
        harness.requireServing(_projected(), scope);
    }

    function testServingAuthenticatesCheckpointConfigurationBeforeFixedCurrentWorker() public {
        _allowCurrent(_currentSource());
        bytes memory saved = abi.encode(checkpoint);
        bytes memory rejection =
            abi.encodeWithSelector(Worker.InvalidViewDiscovery.selector, nodes[9]);
        checkpoint.core = nodes[10];
        _set(nodes[9], "configuration()", abi.encode(checkpoint));
        _servingReject(rejection);
        checkpoint = abi.decode(saved, (Checkpoint.Configuration));
        checkpoint.router = nodes[10];
        _set(nodes[9], "configuration()", abi.encode(checkpoint));
        _servingReject(rejection);
        checkpoint = abi.decode(saved, (Checkpoint.Configuration));
        checkpoint.authority = nodes[10];
        _set(nodes[9], "configuration()", abi.encode(checkpoint));
        _servingReject(rejection);
        checkpoint = abi.decode(saved, (Checkpoint.Configuration));
        _set(nodes[9], "configuration()", abi.encode(checkpoint));
        harness.requireServing(_projected(), scope);
    }

    function _valid() private view {
        Profiles.Profile memory actual = harness.profile(config, scope);
        Profiles.Profile memory expected = Profiles.Profile(
            VIEW_PROFILE,
            nodes[11],
            nodes[11].codehash,
            nodes[8],
            nodes[8].codehash,
            nodes[5],
            nodes[5].codehash,
            keccak256(
                abi.encode(
                    VIEW_PROFILE, block.chainid, nodes[3], ORIGINAL_HASH, complete.recordHash
                )
            )
        );
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)),
            "independent exact eight-word profile"
        );
    }

    function _profileReject() private view {
        (bool ok,) = address(harness).staticcall(abi.encodeCall(harness.profile, (config, scope)));
        require(!ok, "invalid profile accepted");
    }

    function _profileReject(bytes memory expected) private view {
        (bool ok, bytes memory output) =
            address(harness).staticcall(abi.encodeCall(harness.profile, (config, scope)));
        require(!ok && keccak256(output) == keccak256(expected), "exact profile rejection");
    }

    function _servingReject(bytes memory expected) private view {
        (bool ok, bytes memory output) = address(harness)
            .staticcall(abi.encodeCall(harness.requireServing, (_projected(), scope)));
        require(!ok && keccak256(output) == keccak256(expected), "exact serving rejection");
    }

    function _invalidProfile(address target) private view {
        _profileReject(abi.encodeWithSelector(Worker.InvalidViewDiscovery.selector, target));
    }

    function _projected() private view returns (D.Configuration memory c) {
        c = config;
        c.referenceRender = nodes[11];
        c.entropyFactory = nodes[5];
    }

    function _publish() private {
        _set(nodes[3], "viewPreservationBindingCapability()", abi.encode(capability));
        _set(nodes[3], "viewPreservationBindingReceipt()", abi.encode(basic));
        _set(nodes[3], "viewFinalitySourcesReceipt()", abi.encode(complete));
        _set(nodes[3], "viewFinalitySources()", abi.encode(complete.selection));
    }

    function _reseal() private {
        bytes32 proposal = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1"),
                basic.capabilityHash,
                basic.configuration,
                basic.declaration,
                basic.dependencies,
                basic.dependenciesHash,
                basic.workersHash
            )
        );
        basic.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_RECEIPT_V1"),
                proposal,
                basic.actionId,
                basic.boundAt
            )
        );
        complete.basicBindingRecordHash = basic.recordHash;
        complete.recordHash = _completeHash(complete);
    }

    function _completeHash(Sources.Receipt memory r) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                block.chainid,
                nodes[3],
                r.selection,
                r.referenceDependenciesHash,
                r.inventoryDependenciesHash,
                r.bundleDependenciesHash,
                r.basicBindingRecordHash,
                r.actionId,
                r.boundAt
            )
        );
    }

    function _currentSource() private view returns (Checkpoint.Source memory s) {
        s.adoption.input.scope = scope;
        s.adoption.recordHash = keccak256("synthetic current adoption");
        s.adoption.source.route.core = config.core;
        s.adoption.source.route.coreCodeHash = config.core.codehash;
        s.adoption.source.route.router = config.router;
        s.adoption.source.route.routerCodeHash = config.router.codehash;
        s.adoption.source.route.artist = config.artist;
        s.adoption.source.route.artistCodeHash = config.artist.codehash;
        s.adoption.source.route.finality = config.finalityRegistry;
        s.adoption.source.route.finalityCodeHash = config.finalityRegistryCodeHash;
        s.adoption.source.route.provider = config.provider;
        s.adoption.source.route.providerCodeHash = config.provider.codehash;
        s.adoption.source.route.metadata = config.metadata;
        s.adoption.source.route.metadataCodeHash = config.metadata.codehash;
        s.adoption.source.route.schemas = nodes[17];
        s.adoption.source.route.schemasCodeHash = nodes[17].codehash;
        s.adoption.source.route.store = nodes[18];
        s.adoption.source.route.storeCodeHash = nodes[18].codehash;
        s.adoption.source.route.binding = basic.declaration;
        s.contextHash = keccak256("synthetic consumer-local context");
    }

    function _allowCurrent(Checkpoint.Source memory s) private {
        vm.mockCallRevert(
            address(CheckpointSource),
            abi.encodePacked(CheckpointSource.current.selector),
            abi.encodeWithSelector(WrongCheckpointArguments.selector)
        );
        vm.mockCall(
            address(CheckpointSource),
            abi.encodeWithSelector(CheckpointSource.current.selector, checkpoint, scope),
            abi.encode(s)
        );
    }

    function _poisonRecursive() private {
        bytes memory reason = abi.encodeWithSelector(ForbiddenRecursiveSurface.selector);
        ViewDiscoveryReadTable p = ViewDiscoveryReadTable(nodes[3]);
        p.reject(
            abi.encodeWithSignature(
                "finalitySourcesForScope((uint8,uint256,uint256,bytes32))", scope
            ),
            reason
        );
        p.reject(
            abi.encodeWithSignature(
                "requireFinalityScopeInputs((uint8,uint256,uint256,bytes32),bytes32)",
                scope,
                bytes32(0)
            ),
            reason
        );
        p.reject(
            abi.encodeWithSignature(
                "finalityComponentFacts(bytes32,(uint8,uint256,uint256,bytes32))", bytes32(0), scope
            ),
            reason
        );
        // Every unlisted tuple also fails in the table; no catalogue/evidence call can succeed.
    }

    function _set(address target, string memory signature, bytes memory result) private {
        ViewDiscoveryReadTable(target).set(abi.encodeWithSignature(signature), result);
    }

    function _support(bytes4 id, bool supported) private {
        _supports(nodes[3], id, supported);
    }

    function _supports(address target, bytes4 id, bool supported) private {
        ViewDiscoveryReadTable(target)
            .set(abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(supported));
    }

    function _word(bytes memory raw, uint256 index, bytes32 value) private pure {
        assembly ("memory-safe") { mstore(add(add(raw, 32), mul(index, 32)), value) }
    }
}
