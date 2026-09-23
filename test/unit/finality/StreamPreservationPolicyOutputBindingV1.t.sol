// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    StreamPreservationPolicyOutputBindingV1 as Binding
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputBindingV1.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";

interface PreservationBindingVm {
    function etch(address target, bytes calldata code) external;
}

contract PreservationBindingIdentityBoundary {
    function marker() external pure returns (uint256) {
        return 54;
    }
}

/// @dev Deliberate identity-only producer boundary. It neither renders nor claims admission.
/// Raw responses permit malformed ABI and revert tests against the real bounded reader.
contract PreservationBindingProducerBoundary {
    bytes private profileResponse;
    bytes private bindingResponse;
    mapping(bytes4 => bool) private failing;
    bytes4 private constant PROFILE = bytes4(keccak256("preservationProfile()"));
    bytes4 private constant BINDING = bytes4(keccak256("preservationBinding()"));

    function configure(P.Binding calldata b) external {
        profileResponse = abi.encode(b.profile);
        bindingResponse = abi.encode(
            b.core,
            b.metadataRouter,
            b.liveRenderer,
            b.liveRendererCodeHash,
            b.attribution,
            b.attributionCodeHash
        );
    }

    function rawResponse(bytes4 selector, bytes calldata response) external {
        require(selector == PROFILE || selector == BINDING);
        if (selector == PROFILE) profileResponse = response;
        else bindingResponse = response;
    }

    function fail(bytes4 selector, bool value) external {
        failing[selector] = value;
    }

    fallback() external {
        require(!failing[msg.sig], "explicit producer failure");
        require(msg.sig == PROFILE || msg.sig == BINDING, "unknown boundary selector");
        bytes memory raw = msg.sig == PROFILE ? profileResponse : bindingResponse;
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

contract PreservationBindingProbe {
    function current(address producer, bytes32 profile, address core, address router, uint256 cap)
        external
        view
        returns (P.Binding memory)
    {
        return Binding.current(producer, profile, core, router, cap);
    }

    function check(P.Binding calldata expected, Selection.TokenSelection calldata row, uint256 cap)
        external
        view
        returns (bytes32)
    {
        Binding.requireCurrent(expected, row, cap);
        return Binding.hash(expected);
    }

    function bindingHash(P.Binding calldata b) external pure returns (bytes32) {
        return Binding.hash(b);
    }
}

/// @notice Focused production binding-reader tests with explicit typed source boundaries.
/// @dev No genuine preservation output, governed admission, publication or finality is claimed.
contract StreamPreservationPolicyOutputBindingV1Test {
    PreservationBindingVm private constant vm =
        PreservationBindingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant CAP = 100000;
    bytes32 private constant PROFILE = keccak256("typed preservation identity boundary");
    bytes4 private constant PROFILE_SELECTOR = bytes4(keccak256("preservationProfile()"));
    bytes4 private constant BINDING_SELECTOR = bytes4(keccak256("preservationBinding()"));
    PreservationBindingProbe private probe;
    PreservationBindingProducerBoundary private producer;
    P.Binding private expected;
    Selection.TokenSelection private selected;

    function setUp() public {
        probe = new PreservationBindingProbe();
        producer = new PreservationBindingProducerBoundary();
        expected = P.Binding(
            address(producer),
            address(producer).codehash,
            PROFILE,
            address(new PreservationBindingIdentityBoundary()),
            address(new PreservationBindingIdentityBoundary()),
            address(new PreservationBindingIdentityBoundary()),
            bytes32(0),
            address(new PreservationBindingIdentityBoundary()),
            bytes32(0)
        );
        expected.liveRendererCodeHash = expected.liveRenderer.codehash;
        expected.attributionCodeHash = expected.attribution.codehash;
        producer.configure(expected);
        selected.tokenId = 91;
        selected.selection.renderer = expected.liveRenderer;
        selected.selection.rendererCodeHash = expected.liveRendererCodeHash;
        selected.sources[0] = expected.core;
        selected.sources[1] = expected.metadataRouter;
        selected.sourceCodeHashes[0] = expected.core.codehash;
        selected.sourceCodeHashes[1] = expected.metadataRouter.codehash;
    }

    function testExactNineWordBindingAndIndependentDomainPreimage() public view {
        P.Binding memory observed = _current();
        require(abi.encode(observed).length == 288, "nine exact ABI words");
        require(
            keccak256(abi.encode(observed)) == keccak256(abi.encode(expected)),
            "exact six-field producer join"
        );
        bytes32 oracle =
            keccak256(abi.encode(keccak256("6529STREAM_PRESERVATION_OUTPUT_BINDING_V1"), observed));
        require(
            probe.bindingHash(observed) == oracle && probe.check(expected, selected, CAP) == oracle,
            "independent original binding preimage"
        );
    }

    function testHashCommitsEveryIdentityWord() public view {
        P.Binding memory b = expected;
        bytes32 original = probe.bindingHash(b);
        for (uint256 i; i < 9; ++i) {
            bytes memory raw = abi.encode(b);
            assembly ("memory-safe") {
                let word := add(add(raw, 32), mul(i, 32))
                mstore(word, xor(mload(word), 1))
            }
            P.Binding memory changed = abi.decode(raw, (P.Binding));
            require(probe.bindingHash(changed) != original, "each word enters commitment");
        }
    }

    function testSubstitutedCoreAndRouterAreRejected() public {
        address other = address(new PreservationBindingIdentityBoundary());
        P.Binding memory changed = expected;
        changed.core = other;
        producer.configure(changed);
        _currentError(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        changed = expected;
        changed.metadataRouter = other;
        producer.configure(changed);
        _currentError(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        producer.configure(expected);
        _current();
    }

    function testSubstitutedLiveRendererAndAttributionCannotReplaceRetainedBinding() public {
        address other = address(new PreservationBindingIdentityBoundary());
        P.Binding memory changed = expected;
        changed.liveRenderer = other;
        changed.liveRendererCodeHash = other.codehash;
        producer.configure(changed);
        _checkError(selected, abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        changed = expected;
        changed.attribution = other;
        changed.attributionCodeHash = other.codehash;
        producer.configure(changed);
        _checkError(selected, abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        producer.configure(expected);
        probe.check(expected, selected, CAP);
    }

    function testWrongAndZeroProfilesCannotBeAdopted() public {
        P.Binding memory changed = expected;
        changed.profile = keccak256("other preservation semantics");
        producer.configure(changed);
        _currentError(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        producer.configure(expected);
        bytes memory input = abi.encodeCall(
            probe.current,
            (address(producer), bytes32(0), expected.core, expected.metadataRouter, CAP)
        );
        _error(input, abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
    }

    function testClaimedRendererAndAttributionRuntimeMustMatchActualCode() public {
        P.Binding memory changed = expected;
        changed.liveRendererCodeHash = keccak256("wrong renderer runtime");
        producer.configure(changed);
        _currentError(
            abi.encodeWithSelector(P.PreservationDependencyChanged.selector, expected.liveRenderer)
        );
        changed = expected;
        changed.attributionCodeHash = keccak256("wrong attribution runtime");
        producer.configure(changed);
        _currentError(
            abi.encodeWithSelector(P.PreservationDependencyChanged.selector, expected.attribution)
        );
        changed.attributionCodeHash = 0;
        producer.configure(changed);
        _currentError(
            abi.encodeWithSelector(P.PreservationDependencyChanged.selector, expected.attribution)
        );
    }

    function testMissingProducerAndMissingBoundCodeAreRejected() public {
        bytes memory input = abi.encodeCall(
            probe.current, (address(0xBEEF), PROFILE, expected.core, expected.metadataRouter, CAP)
        );
        _error(
            input,
            abi.encodeWithSelector(
                P.PreservationReadFailed.selector, address(0xBEEF), PROFILE_SELECTOR
            )
        );
        P.Binding memory changed = expected;
        changed.attribution = address(0xBEEF);
        changed.attributionCodeHash = keccak256("");
        producer.configure(changed);
        _currentError(
            abi.encodeWithSelector(P.PreservationDependencyChanged.selector, address(0xBEEF))
        );
        input = abi.encodeCall(
            probe.current,
            (address(producer), PROFILE, address(0xBEEF), expected.metadataRouter, CAP)
        );
        _error(input, abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
    }

    function testSelectedRowMustMatchCoreRouterRendererAndRuntime() public view {
        for (uint256 i; i < 4; ++i) {
            Selection.TokenSelection memory row = selected;
            if (i == 0) row.sources[0] = address(0x1234);
            if (i == 1) row.sources[1] = address(0x1234);
            if (i == 2) row.selection.renderer = address(0x1234);
            if (i == 3) row.selection.rendererCodeHash = keccak256("other selected runtime");
            _checkError(row, abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        }
    }

    function testSelectedCoreAndRouterRuntimePinsAreRequired() public view {
        for (uint256 i; i < 2; ++i) {
            Selection.TokenSelection memory row = selected;
            row.sourceCodeHashes[i] = keccak256("stale selected source runtime");
            _checkError(
                row,
                abi.encodeWithSelector(P.PreservationDependencyChanged.selector, row.sources[i])
            );
        }
    }

    function testProducerRendererAttributionCoreAndRouterRuntimeDriftThenExactRetry() public {
        address[5] memory targets = [
            expected.producer,
            expected.liveRenderer,
            expected.attribution,
            expected.core,
            expected.metadataRouter
        ];
        bytes memory input = abi.encodeCall(probe.check, (expected, selected, CAP));
        bytes32 originalHash = probe.bindingHash(expected);
        for (uint256 i; i < targets.length; ++i) {
            bytes memory originalCode = targets[i].code;
            vm.etch(targets[i], hex"600160005260206000f3");
            _error(
                input, abi.encodeWithSelector(P.PreservationDependencyChanged.selector, targets[i])
            );
            vm.etch(targets[i], originalCode);
            (bool ok, bytes memory returned) = address(probe).staticcall(input);
            require(
                ok && abi.decode(returned, (bytes32)) == originalHash,
                "identical retained request succeeds after exact repair"
            );
        }
    }

    function testProducerFailureAndMalformedProfileLengthHaveExactReadErrors() public {
        producer.fail(PROFILE_SELECTOR, true);
        _currentError(
            abi.encodeWithSelector(
                P.PreservationReadFailed.selector, address(producer), PROFILE_SELECTOR
            )
        );
        producer.fail(PROFILE_SELECTOR, false);
        uint256[3] memory lengths = [uint256(0), 31, 33];
        for (uint256 i; i < lengths.length; ++i) {
            producer.rawResponse(PROFILE_SELECTOR, new bytes(lengths[i]));
            _currentError(
                abi.encodeWithSelector(
                    P.PreservationReadFailed.selector, address(producer), PROFILE_SELECTOR
                )
            );
        }
        producer.configure(expected);
        _current();
    }

    function testBindingFailureAndShortOrTrailingBytesHaveExactReadErrors() public {
        producer.fail(BINDING_SELECTOR, true);
        _currentError(
            abi.encodeWithSelector(
                P.PreservationReadFailed.selector, address(producer), BINDING_SELECTOR
            )
        );
        producer.fail(BINDING_SELECTOR, false);
        uint256[3] memory lengths = [uint256(0), 191, 193];
        for (uint256 i; i < lengths.length; ++i) {
            producer.rawResponse(BINDING_SELECTOR, new bytes(lengths[i]));
            _currentError(
                abi.encodeWithSelector(
                    P.PreservationReadFailed.selector, address(producer), BINDING_SELECTOR
                )
            );
        }
        producer.configure(expected);
        _current();
    }

    function testNoncanonicalAddressPaddingIsNotAccepted() public {
        P.Binding memory b = expected;
        bytes memory raw = abi.encode(
            b.core,
            b.metadataRouter,
            b.liveRenderer,
            b.liveRendererCodeHash,
            b.attribution,
            b.attributionCodeHash
        );
        raw[0] = 0x01;
        producer.rawResponse(BINDING_SELECTOR, raw);
        (bool ok,) = address(probe).staticcall(_currentInput(CAP));
        require(!ok, "dirty address word rejected by ABI decoder");
        producer.configure(expected);
        _current();
    }

    function testParentStarvationFailsBeforeReadAndIdenticalInputRetries() public view {
        bytes memory input = _currentInput(CAP);
        (bool ok, bytes memory rejected) = address(probe).staticcall{ gas: 150000 }(input);
        require(
            !ok && rejected.length == 68 && _selector(rejected) == P.PreservationParentGas.selector,
            "explicit parent starvation, not successful shortened read"
        );
        uint256 available;
        uint256 required;
        assembly ("memory-safe") {
            available := mload(add(rejected, 36))
            required := mload(add(rejected, 68))
        }
        require(
            required == CAP + CAP / 63 + 100000 && available <= required,
            "literal parent reserve preflight"
        );
        (ok, rejected) = address(probe).staticcall{ gas: 600000 }(input);
        require(
            ok && rejected.length == 288 && keccak256(rejected) == keccak256(abi.encode(expected)),
            "unchanged request retries with sufficient parent gas"
        );
    }

    function testZeroAndOverflowingReadBudgetsFailClosed() public view {
        _error(
            _currentInput(0),
            abi.encodeWithSelector(
                P.PreservationReadFailed.selector, address(producer), PROFILE_SELECTOR
            )
        );
        (bool ok, bytes memory raw) = address(probe).staticcall(_currentInput(type(uint256).max));
        require(
            !ok && raw.length == 68 && _selector(raw) == P.PreservationParentGas.selector,
            "overflow guard returns explicit budget failure"
        );
        uint256 required;
        assembly ("memory-safe") { required := mload(add(raw, 68)) }
        require(required == type(uint256).max, "overflow branch retains sentinel bound");
    }

    function _current() private view returns (P.Binding memory) {
        return
            probe.current(address(producer), PROFILE, expected.core, expected.metadataRouter, CAP);
    }

    function _currentInput(uint256 cap) private view returns (bytes memory) {
        return abi.encodeCall(
            probe.current, (address(producer), PROFILE, expected.core, expected.metadataRouter, cap)
        );
    }

    function _currentError(bytes memory reason) private view {
        _error(_currentInput(CAP), reason);
    }

    function _checkError(Selection.TokenSelection memory row, bytes memory reason) private view {
        _error(abi.encodeCall(probe.check, (expected, row, CAP)), reason);
    }

    function _error(bytes memory input, bytes memory reason) private view {
        (bool ok, bytes memory actual) = address(probe).staticcall(input);
        require(!ok && keccak256(actual) == keccak256(reason), "exact production error");
    }

    function _selector(bytes memory raw) private pure returns (bytes4 result) {
        require(raw.length >= 4);
        assembly ("memory-safe") { result := mload(add(raw, 32)) }
    }
}
