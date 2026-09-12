// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import "../../interfaces/stream/finality/IStreamArtistRecoveryIntent.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Current recovery-intent and canonical action observations for artist finding admission.
/// @dev Only the fixed Coordinator supplies the suite and original Finality deployment pin.
///      Saved recovery history does not call these current candidate predicates.
library StreamArtistRecoveryAdmission {
    error RecoveryReadFailed(address target, bytes4 selector);
    error RecoveryParentGas(uint256 available, uint256 required);

    struct Prepared {
        U.Input input;
        U.Context context_;
        IStreamArtistRecoveryIntent.Facts intent;
        address executor;
        uint256 readGas;
    }

    function prepare(
        T.SuiteConfiguration memory suite,
        address originalFinality,
        Recovery.FindingRequest memory request,
        U.Target memory target
    ) public view returns (Prepared memory p) {
        p.readGas = _cap(suite.registry);
        p.input.terms = request;
        p.input.target = target;
        p.input.binding_ = binding(suite, request.collectionId, p.readGas);
        if (p.input.binding_.artistId != request.artistId) revert T.InvalidBinding();
        p.intent = intent(suite, originalFinality, target, p.readGas);
        p.input.recoveryRegistryCodeHash = target.recoveryRegistry.codehash;
        p.input.recoveryIntentFactsHash = keccak256(abi.encode(p.intent));
        p.executor = _address(
            suite.owners[2],
            abi.encodeCall(IStreamArtistIdentityContestOwner.artistWindowAuthority, ()),
            p.readGas
        );
        _roles(suite, p.executor, p.readGas);
        bytes memory action = _action(p.executor, target.recoveryActionId, p.readGas);
        if (_word(action, 1) != uint256(GovernanceActionStatus.SCHEDULED) || _word(action, 2) != 2)
        {
            revert Recovery.InvalidUnavailabilityFinding();
        }
        p.input.recoveryNotBefore = uint64(_word(action, 10));
        p.input.recoveryExpiresAfter = uint64(_word(action, 11));
        // The target and selector in governanceAction index only the first batch call.
        // Actual use must match this action's executing per-call context in the companion.
        bytes32 head = IStreamArtistUnavailabilityOwner(suite.owners[2])
            .latestUnavailabilityFinding(request.artistId, request.collectionId);
        if (head != 0) {
            (, U.Admission memory previous) =
                IStreamArtistUnavailabilityOwner(suite.owners[2]).unavailabilityFindingRecord(head);
            bytes memory oldAction =
                _action(p.executor, previous.target.recoveryActionId, p.readGas);
            uint256 status = _word(oldAction, 1);
            p.input.priorRecoveryTerminal = status == uint256(GovernanceActionStatus.CANCELLED)
                || status == uint256(GovernanceActionStatus.EXECUTED)
                || status == uint256(GovernanceActionStatus.EXPIRED)
                || status == uint256(GovernanceActionStatus.VETOED);
        }
        p.context_ =
            IStreamArtistUnavailabilityOwner(suite.owners[2]).unavailabilityFindingContext(p.input);
        uint256 noticeEnd = block.timestamp + p.context_.noticeSeconds;
        if (
            noticeEnd > type(uint64).max || p.input.recoveryNotBefore < noticeEnd
                || p.input.recoveryExpiresAfter <= p.input.recoveryNotBefore
        ) revert Recovery.InvalidUnavailabilityFinding();
    }

    function governance(T.SuiteConfiguration memory suite, Prepared memory p)
        public
        view
        returns (Contest.GovernanceWitness memory g)
    {
        _roles(suite, p.executor, p.readGas);
        bytes memory current = _fixed(
            p.executor, abi.encodeCall(IStreamGovernanceReads.currentAction, ()), 192, p.readGas
        );
        if (
            _word(current, 0) != 1 || _word(current, 1) == 0 || _word(current, 2) != 2
                || bytes32(_word(current, 3)) != p.context_.scopeHash
                || bytes32(_word(current, 4)) != p.context_.oldValueHash
                || bytes32(_word(current, 5)) != p.context_.newValueHash
        ) revert Recovery.InvalidUnavailabilityFinding();
        g.actionId = bytes32(_word(current, 1));
        g.actionClass = 2;
        g.scopeHash = p.context_.scopeHash;
        g.oldValueHash = p.context_.oldValueHash;
        g.newValueHash = p.context_.newValueHash;
        bytes memory saved = _action(p.executor, g.actionId, p.readGas);
        if (
            _word(saved, 1) != uint256(GovernanceActionStatus.EXECUTED) || _word(saved, 2) != 2
                || bytes32(_word(saved, 16)) != p.input.terms.reasonHash
                || g.actionId == p.input.target.recoveryActionId
        ) revert Recovery.InvalidUnavailabilityFinding();
        g.proposer = address(uint160(_word(saved, 12)));
        bytes32 role = keccak256("ROLE_ATTRIBUTION_ARBITER");
        if (
            g.proposer == address(0)
                || _word(
                        _fixed(
                            suite.roleRegistry,
                            abi.encodeCall(IStreamRoleRegistry.hasRole, (role, g.proposer)),
                            32,
                            p.readGas
                        ),
                        0
                    ) != 1
        ) revert T.Unauthorized(g.proposer);
        bytes memory mutation = _fixed(
            suite.roleRegistry,
            abi.encodeCall(IStreamRoleRegistry.roleMutationState, (role)),
            64,
            p.readGas
        );
        if (
            _word(mutation, 0) == 0 || _word(mutation, 1) == 0
                || _word(mutation, 1) > type(uint64).max
        ) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
        g.roleMutationHash = bytes32(_word(mutation, 0));
        g.roleRevision = uint64(_word(mutation, 1));
    }

    function verify(
        T.SuiteConfiguration memory suite,
        address originalFinality,
        U.Target memory target
    ) public view returns (bool valid, bytes32 hash, bytes32 artistId, uint64 noticeEndsAt) {
        uint256 cap = _cap(suite.registry);
        T.Binding memory b = binding(suite, target.scope.collectionId, cap);
        IStreamArtistRecoveryIntent.Facts memory facts =
            intent(suite, originalFinality, target, cap);
        artistId = b.artistId;
        IStreamArtistUnavailabilityOwner owner = IStreamArtistUnavailabilityOwner(suite.owners[2]);
        hash = owner.latestUnavailabilityFinding(artistId, target.scope.collectionId);
        if (hash == 0) return (false, 0, artistId, 0);
        (Recovery.FindingRecord memory r, U.Admission memory a) =
            owner.unavailabilityFindingRecord(hash);
        noticeEndsAt = r.noticeEndsAt;
        valid = r.recordHash == hash
            && keccak256(abi.encode(a.target)) == keccak256(abi.encode(target))
            && a.recoveryRegistryCodeHash == target.recoveryRegistry.codehash
            && a.recoveryIntentFactsHash == keccak256(abi.encode(facts))
            && owner.unavailabilityFindingLive(hash, b);
    }

    function binding(T.SuiteConfiguration memory suite, uint256 collectionId, uint256 cap)
        public
        view
        returns (T.Binding memory b)
    {
        _selected(suite.core, keccak256("ARTIST_REGISTRY"), suite.registry, cap);
        if (
            collectionId == 0
                || _word(
                        _fixed(
                            suite.core,
                            abi.encodeCall(
                                IStreamCoreCollectionView.collectionExists, (collectionId)
                            ),
                            32,
                            cap
                        ),
                        0
                    ) != 1
        ) {
            revert T.InvalidAttribution(collectionId);
        }
        bytes memory raw = _fixed(
            suite.owners[0],
            abi.encodeCall(IStreamArtistBindingOwner.binding, (collectionId)),
            320,
            cap
        );
        if (
            _word(raw, 1) >> 160 != 0 || _word(raw, 4) >> 64 != 0 || _word(raw, 5) >> 8 != 0
                || _word(raw, 6) >> 8 != 0 || _word(raw, 7) >> 8 != 0 || _word(raw, 8) >> 160 != 0
                || _word(raw, 9) != 1
        ) revert T.InvalidBinding();
        b = abi.decode(raw, (T.Binding));
        raw = _fixed(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (collectionId)),
            64,
            cap
        );
        if (
            b.artistId == 0 || b.bindingHash == 0 || b.generation == 0
                || (_word(raw, 0) != 2 && _word(raw, 0) != 3) || _word(raw, 1) != b.generation
        ) {
            revert T.InvalidAttribution(collectionId);
        }
        // Attribution 2/3 is a collection predicate. Identity-contested status remains eligible
        // for governance to record inability; no current signer is fabricated from these facts.
    }

    function intent(
        T.SuiteConfiguration memory suite,
        address originalFinality,
        U.Target memory target,
        uint256 cap
    ) public view returns (IStreamArtistRecoveryIntent.Facts memory facts) {
        _selected(suite.core, keccak256("ARTWORK_FINALITY_RECOVERY"), target.recoveryRegistry, cap);
        if (
            target.recoveryRegistry == address(0) || target.recoveryActionId == 0
                || target.originalFinalityRecordHash == 0 || target.recoveryManifestHash == 0
                || _address(
                        target.recoveryRegistry,
                        abi.encodeCall(IStreamArtistRecoveryIntent.core, ()),
                        cap
                    ) != suite.core
                || _address(
                        target.recoveryRegistry,
                        abi.encodeCall(IStreamArtistRecoveryIntent.originalFinalityRegistry, ()),
                        cap
                    ) != originalFinality
        ) {
            revert T.InvalidBinding();
        }
        facts = abi.decode(
            _fixed(
                target.recoveryRegistry,
                abi.encodeCall(
                    IStreamArtistRecoveryIntent.requireArtistRecoveryIntent,
                    (target.scope, target.originalFinalityRecordHash, target.recoveryManifestHash)
                ),
                128,
                cap
            ),
            (IStreamArtistRecoveryIntent.Facts)
        );
        if (
            facts.scopeHash == 0 || facts.oldValueHash == 0 || facts.newValueHash == 0
                || facts.requestHash == 0
        ) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
    }

    function _roles(T.SuiteConfiguration memory suite, address executor, uint256 cap) private view {
        if (
            _address(executor, abi.encodeWithSignature("roleRegistry()"), cap) != suite.roleRegistry
                || _address(suite.roleRegistry, abi.encodeWithSignature("owner()"), cap) != executor
        ) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
    }

    /// @dev Bounded typed header only. URI bytes are not copied or claimed canonicalized.
    function _action(address executor, bytes32 id, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (id == 0) revert Recovery.InvalidUnavailabilityFinding();
        uint256 size;
        (raw, size) = _read(
            executor, abi.encodeCall(IStreamGovernanceReads.governanceAction, (id)), 640, cap
        );
        uint256 uriLength = _word(raw, 19);
        if (
            size < 640 || _word(raw, 0) != 32 || _word(raw, 17) != 576 || uriLength > size - 640
                || size % 32 != 0 || size - 640 - uriLength > 31 || _word(raw, 1) == 0
                || _word(raw, 1) > uint256(GovernanceActionStatus.VETOED) || _word(raw, 2) > 5
                || _word(raw, 3) >> 160 != 0 || _word(raw, 5) << 32 != 0
                || _word(raw, 10) > type(uint64).max || _word(raw, 11) > type(uint64).max
                || _word(raw, 12) >> 160 != 0 || _word(raw, 13) >> 160 != 0
                || _word(raw, 14) >> 160 != 0 || _word(raw, 15) >> 160 != 0
        ) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
    }

    function _selected(address core_, bytes32 key, address expected, uint256 cap) private view {
        bytes memory raw =
            _fixed(core_, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)), 320, cap);
        address target = address(uint160(_word(raw, 0)));
        if (
            _word(raw, 0) >> 160 != 0 || target == address(0) || target != expected
                || target.code.length == 0 || target.codehash != bytes32(_word(raw, 1))
                || _word(raw, 2) > 1 || _word(raw, 4) << 32 != 0 || _word(raw, 5) >> 160 != 0
                || (_word(raw, 6) != 1 && _word(raw, 6) != 2) || _word(raw, 9) == 0
                || _word(raw, 9) > type(uint64).max
        ) revert T.ComponentChanged(target);
        _module(core_, key, target, raw, cap);
    }

    function _module(address core_, bytes32 key, address target, bytes memory pointer, uint256 cap)
        private
        view
    {
        bytes32 kind = key == keccak256("ARTWORK_FINALITY_RECOVERY")
            ? keccak256("STREAM_ARTWORK_FINALITY_RECOVERY")
            : keccak256("ARTIST_REGISTRY");
        bytes4 interfaceId = key == keccak256("ARTWORK_FINALITY_RECOVERY")
            ? bytes4(0x83685f5c)
            : type(IStreamArtistMintConsent).interfaceId;
        if (
            bytes32(_word(pointer, 3)) != kind || bytes4(bytes32(_word(pointer, 4))) != interfaceId
                || bytes32(
                        _word(
                            _fixed(
                                target, abi.encodeCall(IStreamModule.streamModuleType, ()), 32, cap
                            ),
                            0
                        )
                    ) != kind
                || bytes32(
                        _word(
                            _fixed(
                                target,
                                abi.encodeCall(IStreamModule.streamModuleInterfaceId, ()),
                                32,
                                cap
                            ),
                            0
                        )
                    ) != bytes32(interfaceId)
        ) {
            revert T.ComponentChanged(target);
        }
        bytes memory selected = _fixed(
            core_,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))),
            320,
            cap
        );
        address modules = address(uint160(_word(selected, 0)));
        if (
            _word(selected, 0) >> 160 != 0 || modules.code.length == 0
                || modules != address(uint160(_word(pointer, 5)))
                || modules.codehash != bytes32(_word(selected, 1))
                || _word(
                        _fixed(
                            modules,
                            abi.encodeCall(
                                IStreamModuleRegistry.isModuleEligible, (target, kind, interfaceId)
                            ),
                            32,
                            cap
                        ),
                        0
                    ) != 1
                || _word(
                        _fixed(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (interfaceId)),
                            32,
                            cap
                        ),
                        0
                    ) != 1
                || _word(
                        _fixed(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                            32,
                            cap
                        ),
                        0
                    ) != 1
                || _word(
                        _fixed(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                            32,
                            cap
                        ),
                        0
                    ) != 0
        ) {
            revert T.ComponentChanged(target);
        }
    }

    function _cap(address registry) private view returns (uint256 cap) {
        uint8 failure;
        uint64 revision;
        (cap,, failure, revision) = IStreamGasParameterHost(registry)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"));
        if (cap == 0 || failure != 2 || revision == 0) revert T.InvalidBinding();
    }

    function _address(address target, bytes memory data, uint256 cap)
        private
        view
        returns (address)
    {
        uint256 word = _word(_fixed(target, data, 32, cap), 0);
        if (word == 0 || word >> 160 != 0) revert T.InvalidBinding();
        return address(uint160(word));
    }

    function _word(bytes memory raw, uint256 index) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(raw, 32), mul(index, 32))) }
    }

    function _fixed(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        uint256 size;
        (raw, size) = _read(target, data, length, cap);
        if (size != length) revert RecoveryReadFailed(target, bytes4(data));
    }

    function _read(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory raw, uint256 size)
    {
        uint256 available = gasleft();
        if (cap > type(uint256).max / 2) revert RecoveryParentGas(available, cap);
        uint256 required = cap + cap / 63 + 20_000;
        if (available < required) revert RecoveryParentGas(available, required);
        raw = new bytes(length);
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), length)
            size := returndatasize()
        }
        if (!ok || size < length) revert RecoveryReadFailed(target, bytes4(data));
    }
}
