// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import "../../interfaces/stream/finality/IStreamArtistRecoveryIntent.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRecovery.sol";
import "../../interfaces/stream/finality/IStreamFinalityRecoveryGovernanceBinding.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";

/// @notice Complete scheduled recovery-call witnesses for the fixed OwnerRecords host.
/// @dev No notice, owner standing, objection or execution authority is created here. The host
///      retains the admitted binding; callers cannot supply replacement deployment pins.
library StreamOwnerRecoveryActionReads {
    error OwnerRecoveryContextInvalid();
    error OwnerRecoveryActionInvalid();
    error OwnerRecoveryWitnessInvalid();
    error OwnerRecoveryDependencyChanged(address target);
    error OwnerRecoveryReadFailed(address target, bytes4 selector);
    error OwnerRecoveryParentGas(uint256 available, uint256 required);

    struct Config {
        address core;
        bytes32 coreCodeHash;
        address executor;
        bytes32 executorCodeHash;
        address ownerEvidence;
        uint256 readGas;
        uint256 intentReadGas;
    }

    struct Binding {
        address target;
        bytes32 targetCodeHash;
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        bytes32 requestHash;
        bytes32 manifestHash;
        bytes32 callHash;
        uint64 expiresAfter;
        bytes32 originalFinalityRecordHash;
    }

    // [GOV-ACTION-ID], identical to the existing Executor's full ordered calls preimage.
    bytes32 private constant CALLS =
        0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70;
    bytes32 private constant SCOPE = keccak256("6529STREAM_FINALITY_RECOVERY_SCOPE_V1");
    bytes4 private constant OWNER = bytes4(keccak256("ownerEvidence()"));

    function admit(
        Config memory c,
        bytes32 actionId,
        GovernanceCall[] memory completePublishedCalls,
        StreamFinalityRecoveryRequest memory request
    ) public view returns (Binding memory b) {
        _context(c);
        IStreamGovernanceActionFacts.ActionFacts memory a = _action(c, actionId);
        if (a.status != GovernanceActionStatus.SCHEDULED || !_live(a)) {
            revert OwnerRecoveryActionInvalid();
        }
        if (keccak256(abi.encode(CALLS, completePublishedCalls)) != a.callHash) {
            revert OwnerRecoveryWitnessInvalid();
        }
        uint256 selected = type(uint256).max;
        for (uint256 i; i < completePublishedCalls.length; ++i) {
            if (
                completePublishedCalls[i].selector
                    == IStreamArtworkFinalityRecovery.executeFinalityRecovery.selector
            ) {
                if (selected != type(uint256).max) revert OwnerRecoveryWitnessInvalid();
                selected = i;
            }
        }
        if (selected == type(uint256).max) revert OwnerRecoveryWitnessInvalid();
        GovernanceCall memory call_ = completePublishedCalls[selected];
        if (
            call_.value != 0
                || call_.callDataHash
                    != keccak256(
                        abi.encodeCall(
                            IStreamArtworkFinalityRecovery.executeFinalityRecovery, (request)
                        )
                    )
        ) revert OwnerRecoveryWitnessInvalid();
        b.target = call_.target;
        b.targetCodeHash = _code(b.target);
        b.scopeHash = call_.scopeHash;
        b.oldValueHash = call_.oldValueHash;
        b.newValueHash = call_.newValueHash;
        b.requestHash = keccak256(abi.encode(request));
        b.manifestHash = request.recoveryManifest.contentHash;
        b.callHash = a.callHash;
        b.expiresAfter = a.expiresAfter;
        b.originalFinalityRecordHash = request.expectedOriginalFinalityRecordHash;
        _binding(c, b, request.scope, b.manifestHash);
        _intent(c, b, request.scope);
    }

    /// @notice Owner-notice action liveness only, never full recovery readiness. An executed
    ///         action ceases to qualify when its exact
    ///         per-call Executor context closes; the saved historical binding is never rewritten.
    /// @dev Ordinary inactive status/context returns false; malformed or changed dependencies
    ///      revert. The owning evidence endpoint may convert those failures into invalid evidence.
    function eligibility(
        Config memory c,
        Binding memory b,
        bytes32 actionId,
        StreamFinalityScope memory scope,
        bytes32 manifestHash
    ) public view returns (bool) {
        _context(c);
        IStreamGovernanceActionFacts.ActionFacts memory a = _action(c, actionId);
        if (!_live(a) || a.callHash != b.callHash || a.expiresAfter != b.expiresAfter) {
            return false;
        }
        if (a.status == GovernanceActionStatus.EXECUTED) {
            if (block.timestamp < a.notBefore || !_executing(c, b, actionId)) return false;
        } else if (a.status != GovernanceActionStatus.SCHEDULED) {
            return false;
        }
        _binding(c, b, scope, manifestHash);
        return true;
    }

    function _context(Config memory c) private view {
        if (
            c.ownerEvidence == address(0) || address(this) != c.ownerEvidence || c.readGas == 0
                || c.readGas > type(uint64).max || c.intentReadGas == 0
                || c.intentReadGas > type(uint64).max
        ) revert OwnerRecoveryContextInvalid();
        _pin(c.core, c.coreCodeHash);
        _pin(c.executor, c.executorCodeHash);
    }

    function _live(IStreamGovernanceActionFacts.ActionFacts memory a) private view returns (bool) {
        return a.actionClass == 2 && a.callHash != 0 && a.expiresAfter != 0
            && a.notBefore <= a.expiresAfter && block.timestamp <= a.expiresAfter;
    }

    function _action(Config memory c, bytes32 id)
        private
        view
        returns (IStreamGovernanceActionFacts.ActionFacts memory a)
    {
        if (id == 0) revert OwnerRecoveryActionInvalid();
        bytes memory data = _read(
            c.executor,
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (id)),
            160,
            c.readGas
        );
        if (
            _word(data, 0) > uint256(GovernanceActionStatus.VETOED) || _word(data, 1) > 255
                || _word(data, 3) > type(uint64).max || _word(data, 4) > type(uint64).max
        ) {
            revert OwnerRecoveryReadFailed(
                c.executor, IStreamGovernanceActionFacts.governanceActionFacts.selector
            );
        }
        a = abi.decode(data, (IStreamGovernanceActionFacts.ActionFacts));
    }

    function _binding(
        Config memory c,
        Binding memory b,
        StreamFinalityScope memory s,
        bytes32 manifest
    ) private view {
        _shape(s);
        if (
            manifest == 0 || manifest != b.manifestHash || b.originalFinalityRecordHash == 0
                || b.requestHash == 0 || b.oldValueHash == 0 || b.newValueHash == 0
                || b.scopeHash != keccak256(abi.encode(SCOPE, block.chainid, b.target, s))
        ) revert OwnerRecoveryWitnessInvalid();
        _pin(b.target, b.targetCodeHash);
        _selected(c, b);
        if (
            _address(b.target, IStreamFinalityRecoveryGovernanceBinding.core.selector, c.readGas)
                    != c.core
                || _address(
                        b.target,
                        IStreamFinalityRecoveryGovernanceBinding.governanceAuthority.selector,
                        c.readGas
                    ) != c.executor || _address(b.target, OWNER, c.readGas) != c.ownerEvidence
        ) revert OwnerRecoveryContextInvalid();
    }

    function _intent(Config memory c, Binding memory b, StreamFinalityScope memory s) private view {
        bytes memory data = _read(
            b.target,
            abi.encodeCall(
                IStreamArtistRecoveryIntent.requireArtistRecoveryIntent,
                (s, b.originalFinalityRecordHash, b.manifestHash)
            ),
            128,
            c.intentReadGas
        );
        // The actual companion validates its registered full request, staged704-byte intent,
        // selected deployment and original/current route before returning these four commitments.
        if (
            keccak256(data)
                != keccak256(abi.encode(b.scopeHash, b.oldValueHash, b.newValueHash, b.requestHash))
        ) {
            revert OwnerRecoveryWitnessInvalid();
        }
    }

    function _selected(Config memory c, Binding memory b) private view {
        bytes memory data = _read(
            c.core,
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_RECOVERY"))
            ),
            320,
            c.readGas
        );
        if (
            _word(data, 0) > type(uint160).max || _word(data, 2) > 1
                || (_word(data, 4) & type(uint224).max) != 0 || _word(data, 5) > type(uint160).max
                || _word(data, 6) > 3 || _word(data, 9) > type(uint64).max
        ) revert OwnerRecoveryReadFailed(c.core, IStreamCorePointers.getSatellitePointer.selector);
        if (
            _word(data, 0) != uint256(uint160(b.target))
                || bytes32(_word(data, 1)) != b.targetCodeHash
                || bytes32(_word(data, 3)) != keccak256("STREAM_ARTWORK_FINALITY_RECOVERY")
                || bytes32(_word(data, 4))
                    != bytes32(type(IStreamArtworkFinalityRecovery).interfaceId)
        ) revert OwnerRecoveryWitnessInvalid();
    }

    function _shape(StreamFinalityScope memory s) private pure {
        if (s.collectionId == 0) revert OwnerRecoveryWitnessInvalid();
        if (s.scopeType == StreamFinalityScopeType.COLLECTION) {
            if (s.tokenId != 0 || s.scopeId != 0) revert OwnerRecoveryWitnessInvalid();
        } else if (s.scopeType == StreamFinalityScopeType.TOKEN) {
            if (s.tokenId == 0 || s.scopeId != 0) revert OwnerRecoveryWitnessInvalid();
        } else if (s.tokenId != 0 || s.scopeId == 0) {
            revert OwnerRecoveryWitnessInvalid();
        }
    }

    function _executing(Config memory c, Binding memory b, bytes32 id) private view returns (bool) {
        bytes memory data = _read(
            c.executor,
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            192,
            c.readGas
        );
        if (_word(data, 0) > 1 || _word(data, 2) > 255) {
            revert OwnerRecoveryReadFailed(
                c.executor, IStreamGovernedParameterAuthority.currentAction.selector
            );
        }
        return keccak256(data)
            == keccak256(
            abi.encode(true, id, uint8(2), b.scopeHash, b.oldValueHash, b.newValueHash)
        );
    }

    function _address(address target, bytes4 selector, uint256 cap) private view returns (address) {
        uint256 word = _word(_read(target, abi.encodeWithSelector(selector), 32, cap), 0);
        if (word > type(uint160).max) revert OwnerRecoveryReadFailed(target, selector);
        return address(uint160(word));
    }

    function _pin(address target, bytes32 expected) private view {
        if (_code(target) != expected) revert OwnerRecoveryDependencyChanged(target);
    }

    function _code(address target) private view returns (bytes32) {
        if (target.code.length == 0) revert OwnerRecoveryDependencyChanged(target);
        return target.codehash;
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(data, 32), mul(index, 32))) }
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(size);
        uint256 required = cap + cap / 63 + 10000;
        uint256 available = gasleft();
        if (available < required) revert OwnerRecoveryParentGas(available, required);
        bool ok;
        uint256 length;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), size)
            length := returndatasize()
        }
        if (!ok || length != size) {
            bytes4 selector;
            assembly ("memory-safe") { selector := mload(add(input, 32)) }
            revert OwnerRecoveryReadFailed(target, selector);
        }
    }
}
