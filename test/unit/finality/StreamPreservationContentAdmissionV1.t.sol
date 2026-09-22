// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationContentAdmissionV1 as Admission
} from "../../../smart-contracts/domains/finality/StreamPreservationContentAdmissionV1.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    IStreamStaticSelectionCheckpoint as S
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as C
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationRegistryV1 as Registry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamGasParameterHost
} from "../../../smart-contracts/domains/parameters/StreamGasParameterHost.sol";
import {
    StreamRendererCalls as Calls
} from "../../../smart-contracts/domains/metadata/StreamRendererCalls.sol";
import {
    IStreamStaticMetadataRouter as M
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";

interface AdmissionVm {
    function etch(address target, bytes calldata code) external;
}

contract AdmissionIdentityBoundary {
    function marker() external pure returns (uint256) {
        return 315;
    }
}

/// @dev Explicit synthetic producer/registry data. Outbound reads must originate at the host.
contract AdmissionReadBoundary {
    address private immutable host;
    mapping(bytes4 => bytes) private responses;
    mapping(bytes4 => bytes) private requiredInputs;

    constructor(address host_) {
        host = host_;
    }

    function set(bytes4 selector, bytes calldata response) external {
        responses[selector] = response;
    }

    function requireInput(bytes calldata input) external {
        requiredInputs[bytes4(input)] = input;
    }

    fallback() external {
        require(msg.sender == host, "checkpoint caller lost");
        bytes memory requiredInput = requiredInputs[msg.sig];
        if (requiredInput.length != 0) {
            require(keccak256(msg.data) == keccak256(requiredInput), "registry key changed");
        }
        bytes memory response = responses[msg.sig];
        assembly ("memory-safe") { return(add(response, 32), mload(response)) }
    }
}

/// @dev Only the production fixed admission worker is under test; gas writes are test setup.
contract AdmissionHostProbe {
    bytes32 private constant READ = keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS");
    mapping(bytes32 => StreamGasParameterHost.GasParameterData) private parameters;
    C.Plan private plan;

    constructor() {
        parameters[READ].value = 150000;
        parameters[READ].revision = 1;
        plan.scope.collectionId = 7;
    }

    function cap(uint256 value, uint64 revision) external {
        parameters[READ].value = value;
        parameters[READ].revision = revision;
    }

    function observe(
        Admission.Context memory context,
        S.TokenSelection memory row,
        address producer
    ) external view returns (P.Binding memory, P.Admission memory) {
        return Admission.observe(parameters, context, row, producer);
    }

    function sourceImage(S.TokenSelection memory row, address router)
        external
        view
        returns (string memory)
    {
        return Admission.sourceImage(parameters, plan, row, router);
    }
}

contract StreamPreservationSourceImageV1Test {
    AdmissionHostProbe private host;
    AdmissionReadBoundary private router;
    S.TokenSelection private row;
    M.ConfigRecord private config;
    M.RawSource private source;

    function setUp() public {
        host = new AdmissionHostProbe();
        router = new AdmissionReadBoundary(address(host));
        row.tokenId = 711;
        config.recordHash = keccak256("retained config record");
        config.config.mode = R.MetadataMode.ONCHAIN;
        config.config.frozen = true;
        config.selection.rendererId = keccak256("6529STREAM_RENDERER_V1");
        config.selection.rendererVersion = keccak256("6529STREAM_STATIC_RENDERER_V1");
        row.configRecordHash = config.recordHash;
        source.configured = true;
        source.chainId = block.chainid;
        source.name = "Complete original artwork";
        source.description = "Retained alongside the image and script";
        source.imageURI = "data:image/svg+xml;base64,PHN2Zy8+";
        source.script = "<script>original()</script>";
        _configure();
    }

    function testFullCanonicalSourceAndCallerPreserved() public view {
        _ok();
    }

    function testWrongConfigFailsBeforeFailedRawSourceRead() public {
        router.set(M.resolvedMetadataConfig.selector, bytes.concat(abi.encode(config), hex"00"));
        router.set(M.staticRenderSourceForConfig.selector, hex"");
        _error(abi.encodeWithSelector(C.StaticContentPayload.selector, row.tokenId));
        _configure();
        _ok();
    }

    function testAllConfigIdentityAndModePredicatesRetained() public {
        for (uint256 i; i < 5; ++i) {
            M.ConfigRecord memory changed = config;
            if (i == 0) changed.recordHash = bytes32(0);
            if (i == 1) changed.config.mode = R.MetadataMode.OFFCHAIN;
            if (i == 2) changed.config.frozen = false;
            if (i == 3) changed.selection.rendererId = bytes32(0);
            if (i == 4) changed.selection.rendererVersion = bytes32(0);
            row.configHash = keccak256(abi.encode(changed));
            router.set(M.resolvedMetadataConfig.selector, abi.encode(changed));
            _error(abi.encodeWithSelector(C.StaticContentPayload.selector, row.tokenId));
        }
        _configure();
        _ok();
    }

    function testNonImageSourceChangesStillInvalidateWholeHash() public {
        M.RawSource memory changed = source;
        changed.description = "substituted while image is unchanged";
        router.set(M.staticRenderSourceForConfig.selector, abi.encode(changed, config.config));
        _error(abi.encodeWithSelector(C.StaticContentPayload.selector, row.tokenId));
        _configure();
        _ok();
    }

    function testSourceConfigAndCanonicalPaddingCannotBeSubstituted() public {
        R.MetadataConfig memory changed = config.config;
        changed.baseURI = "unexpected source config";
        router.set(M.staticRenderSourceForConfig.selector, abi.encode(source, changed));
        _error(abi.encodeWithSelector(C.StaticContentPayload.selector, row.tokenId));
        router.set(
            M.staticRenderSourceForConfig.selector,
            bytes.concat(abi.encode(source, config.config), hex"00")
        );
        _error(abi.encodeWithSelector(C.StaticContentPayload.selector, row.tokenId));
        _configure();
        _ok();
    }

    function testFuzzCompleteImageBytesAreRetained(bytes32 arbitrary) public {
        source.imageURI = string(abi.encodePacked("data:", arbitrary));
        _configure();
        _ok();
    }

    function testReadBoundsAndCurrentCapRemainEnforced() public {
        // Allow the boundary to return the entire oversized payload; refusal must be the
        // reader's byte bound, not an incidental out-of-gas failure in the boundary.
        host.cap(3000000, 2);
        router.set(M.resolvedMetadataConfig.selector, new bytes(8193));
        _error(
            abi.encodeWithSelector(
                Calls.RendererReadFailed.selector,
                address(router),
                M.resolvedMetadataConfig.selector
            )
        );
        _configure();
        router.set(M.staticRenderSourceForConfig.selector, new bytes(24001));
        _error(
            abi.encodeWithSelector(
                Calls.RendererReadFailed.selector,
                address(router),
                M.staticRenderSourceForConfig.selector
            )
        );
        _configure();
        host.cap(150000, 0);
        _error(
            abi.encodeWithSelector(
                Gas.GasParameterUnknown.selector,
                keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS")
            )
        );
        host.cap(150000, 2);
        _ok();
    }

    function _configure() private {
        row.configHash = keccak256(abi.encode(config));
        row.rawSourceHash = keccak256(abi.encode(source));
        router.requireInput(abi.encodeCall(M.resolvedMetadataConfig, (row.tokenId)));
        router.requireInput(
            abi.encodeCall(M.staticRenderSourceForConfig, (uint256(7), row.configRecordHash))
        );
        router.set(M.resolvedMetadataConfig.selector, abi.encode(config));
        router.set(M.staticRenderSourceForConfig.selector, abi.encode(source, config.config));
    }

    function _ok() private view {
        string memory image = host.sourceImage(row, address(router));
        require(
            keccak256(bytes(image)) == keccak256(bytes(source.imageURI)), "exact complete image URI"
        );
    }

    function _error(bytes memory expected) private view {
        (bool ok, bytes memory reason) =
            address(host).staticcall(abi.encodeCall(host.sourceImage, (row, address(router))));
        require(!ok && keccak256(reason) == keccak256(expected), "exact source refusal");
    }
}

/// @notice Actual fixed library execution with strict, deliberately synthetic dependency boundaries.
/// @dev Does not establish full checkpoint rendering, governance, all-call Safe or full-flow gas.
contract StreamPreservationContentAdmissionV1Test {
    AdmissionVm private constant vm =
        AdmissionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ORIGINAL = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    bytes32 private constant CURRENT =
        keccak256("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1");
    bytes32 private constant FAMILY = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
    bytes32 private constant READ = keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS");
    bytes4 private constant PROFILE = bytes4(keccak256("preservationProfile()"));
    bytes4 private constant BINDING = bytes4(keccak256("preservationBinding()"));
    AdmissionHostProbe private host;
    AdmissionReadBoundary private producer;
    AdmissionReadBoundary private registry;
    Admission.Context private context;
    S.TokenSelection private row;
    P.Binding private binding;
    P.Admission private admission;

    function setUp() public {
        host = new AdmissionHostProbe();
        producer = new AdmissionReadBoundary(address(host));
        registry = new AdmissionReadBoundary(address(host));
        binding.producer = address(producer);
        binding.producerCodeHash = address(producer).codehash;
        binding.profile = ORIGINAL;
        binding.core = address(new AdmissionIdentityBoundary());
        binding.metadataRouter = address(new AdmissionIdentityBoundary());
        binding.liveRenderer = address(new AdmissionIdentityBoundary());
        binding.liveRendererCodeHash = binding.liveRenderer.codehash;
        binding.attribution = address(new AdmissionIdentityBoundary());
        binding.attributionCodeHash = binding.attribution.codehash;
        context = Admission.Context(binding.core, binding.metadataRouter, ORIGINAL);
        row.tokenId = 315;
        row.selection.renderer = binding.liveRenderer;
        row.selection.rendererCodeHash = binding.liveRendererCodeHash;
        row.selection.registry = address(registry);
        row.selection.registryCodeHash = address(registry).codehash;
        row.selection.versionKey = keccak256("selected original version");
        row.sources[0] = binding.core;
        row.sources[1] = binding.metadataRouter;
        row.sourceCodeHashes[0] = binding.core.codehash;
        row.sourceCodeHashes[1] = binding.metadataRouter.codehash;
        admission = P.Admission(
            address(registry),
            address(registry).codehash,
            row.selection.versionKey,
            keccak256("registration"),
            keccak256("complete read roster"),
            keccak256("source analysis"),
            keccak256("executed vectors")
        );
        _configure();
    }

    function testExactFullBindingAdmissionAndCheckpointCaller() public view {
        _ok();
    }

    function testFamilyRetainsBothActualProducerProfiles() public {
        context.profile = FAMILY;
        _ok();
        binding.profile = CURRENT;
        _configure();
        _ok();
    }

    function testUnknownAndViewProfilesAreRefused() public {
        context.profile = FAMILY;
        producer.set(PROFILE, abi.encode(keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1")));
        _error(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        producer.set(PROFILE, abi.encode(bytes32(0)));
        _error(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
    }

    function testOriginalConsumerCannotAdmitCurrentFamilyProducer() public {
        binding.profile = CURRENT;
        _configure();
        _error(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
    }

    function testEveryAdmissionFieldIsRequired() public {
        bytes memory exact = abi.encode(admission);
        for (uint256 i; i < 7; ++i) {
            bytes memory changed = abi.encode(admission);
            assembly ("memory-safe") { mstore(add(add(changed, 32), mul(i, 32)), 0) }
            registry.set(
                Registry.requirePreservation.selector,
                abi.encode(binding, abi.decode(changed, (P.Admission)))
            );
            _error(abi.encodeWithSelector(C.StaticContentPayload.selector, row.tokenId));
        }
        require(keccak256(abi.encode(admission)) == keccak256(exact), "fixture retained");
        _configure();
        _ok();
    }

    function testRegistryCannotReplaceObservedProducerBinding() public {
        P.Binding memory changed = binding;
        changed.attribution = binding.core;
        registry.set(Registry.requirePreservation.selector, abi.encode(changed, admission));
        _error(abi.encodeWithSelector(C.StaticContentPayload.selector, row.tokenId));
        _configure();
        _ok();
    }

    function testFuzzExactAdmissionReturnSize(uint8 extra) public {
        bytes memory raw = abi.encode(binding, admission);
        bytes memory malformed =
            extra == 0 ? new bytes(511) : bytes.concat(raw, new bytes(uint256(extra)));
        registry.set(Registry.requirePreservation.selector, malformed);
        _error(
            abi.encodeWithSelector(
                Calls.RendererReadFailed.selector,
                address(registry),
                Registry.requirePreservation.selector
            )
        );
        _configure();
        _ok();
    }

    function testLiveGasRevisionAndProfileFailureOrder() public {
        host.cap(150000, 0);
        _error(abi.encodeWithSelector(Gas.GasParameterUnknown.selector, READ));
        context.profile = bytes32(0);
        _error(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        context.profile = FAMILY;
        _error(abi.encodeWithSelector(Gas.GasParameterUnknown.selector, READ));
        host.cap(150000, 2);
        _ok();
    }

    function testConfiguredZeroBudgetIsNotClampedOrReused() public {
        host.cap(0, 2);
        _error(
            abi.encodeWithSelector(P.PreservationReadFailed.selector, address(producer), PROFILE)
        );
        host.cap(150000, 3);
        _ok();
    }

    function testMissingProducerPreservesReadFailurePrecedence() public {
        bytes memory saved = address(producer).code;
        vm.etch(address(producer), hex"");
        _error(
            abi.encodeWithSelector(P.PreservationReadFailed.selector, address(producer), PROFILE)
        );
        context.profile = FAMILY;
        _error(
            abi.encodeWithSelector(Calls.RendererReadFailed.selector, address(producer), PROFILE)
        );
        vm.etch(address(producer), saved);
        _ok();
    }

    function testChangedSourcePinFailsThenExactRetrySucceeds() public {
        bytes memory saved = binding.core.code;
        vm.etch(binding.core, hex"60006000fd");
        _error(abi.encodeWithSelector(P.PreservationDependencyChanged.selector, binding.core));
        vm.etch(binding.core, saved);
        _ok();
    }

    function testGovernedBudgetParentHeadroomIsEnforced() public {
        context.profile = FAMILY;
        host.cap(type(uint256).max, 2);
        (bool ok, bytes memory reason) = address(host)
            .staticcall(abi.encodeCall(host.observe, (context, row, address(producer))));
        require(
            !ok && bytes4(reason) == C.StaticContentParentGas.selector, "parent reserve refusal"
        );
        uint256 cap = 250000;
        host.cap(cap, 3);
        (ok, reason) = address(host).staticcall{ gas: 300000 }(
            abi.encodeCall(host.observe, (context, row, address(producer)))
        );
        require(
            !ok && reason.length == 68 && bytes4(reason) == C.StaticContentParentGas.selector,
            "finite parent reserve refusal"
        );
        uint256 available;
        uint256 required;
        assembly ("memory-safe") {
            available := mload(add(reason, 36))
            required := mload(add(reason, 68))
        }
        require(
            available > 0 && available <= required && required == cap + cap / 63 + 100000,
            "original finite reserve formula"
        );
        host.cap(150000, 3);
        _ok();
    }

    function _configure() private {
        producer.set(PROFILE, abi.encode(binding.profile));
        producer.set(
            BINDING,
            abi.encode(
                binding.core,
                binding.metadataRouter,
                binding.liveRenderer,
                binding.liveRendererCodeHash,
                binding.attribution,
                binding.attributionCodeHash
            )
        );
        registry.set(Registry.requirePreservation.selector, abi.encode(binding, admission));
        registry.requireInput(
            abi.encodeCall(
                Registry.requirePreservation,
                (row.selection.versionKey, address(producer), binding.profile)
            )
        );
    }

    function _ok() private view {
        (P.Binding memory b, P.Admission memory a) = host.observe(context, row, address(producer));
        require(
            keccak256(abi.encode(b, a)) == keccak256(abi.encode(binding, admission)),
            "complete 16-word result"
        );
    }

    function _error(bytes memory expected) private view {
        (bool ok, bytes memory reason) = address(host)
            .staticcall(abi.encodeCall(host.observe, (context, row, address(producer))));
        require(!ok && keccak256(reason) == keccak256(expected), "exact refusal");
    }
}
