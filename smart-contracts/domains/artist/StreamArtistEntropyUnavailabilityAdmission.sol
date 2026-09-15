// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";
import "./StreamArtistRecoveryAdmission.sol";
import "./StreamArtistRecoveryHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU,
    IStreamArtistEntropyUnavailabilityOwner
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";

/// @notice Current selected entropy intent, original Artist association/activity and Arbiter witness.
library StreamArtistEntropyUnavailabilityAdmission {
    struct Prepared {
        EU.Input input;
        U.Context context_;
        address executor;
        uint256 readGas;
    }

    function prepare(
        T.SuiteConfiguration memory suite,
        Recovery.FindingRequest memory request,
        EU.Target memory target
    ) public view returns (Prepared memory p) {
        p.readGas = StreamArtistRecoveryAdmission.readCap(suite.registry);
        p.input.terms = request;
        p.input.target = target;
        p.input.binding_ =
            StreamArtistRecoveryAdmission.binding(suite, request.collectionId, p.readGas);
        if (p.input.binding_.artistId != request.artistId) revert T.InvalidBinding();
        p.input.intent = intent(suite, target.coordinator, target.recovery, p.readGas);
        p.input.coordinatorCodeHash = target.coordinator.codehash;
        p.executor = _address(
            suite.owners[2],
            abi.encodeCall(IStreamArtistIdentityContestOwner.artistWindowAuthority, ()),
            p.readGas
        );
        p.input.priorRecoveryTerminal = StreamArtistRecoveryAdmission.priorTerminal(
            suite, p.input.binding_, request.collectionId, p.executor, p.readGas
        );
        p.context_ = IStreamArtistEntropyUnavailabilityOwner(suite.owners[2])
            .entropyUnavailabilityFindingContext(p.input);
    }

    function governance(T.SuiteConfiguration memory suite, Prepared memory p)
        public
        view
        returns (Contest.GovernanceWitness memory)
    {
        return StreamArtistRecoveryAdmission.findingGovernance(
            suite, p.executor, p.readGas, p.input.terms.reasonHash, p.context_, bytes32(0)
        );
    }

    function verify(
        T.SuiteConfiguration memory suite,
        address coordinator,
        IStreamEntropyFreshRecovery.RecoveryInput memory input,
        bytes32 expectedIntent,
        bytes32 expectedFinding
    ) public view returns (bool valid, bytes32 hash, bytes32 artistId, uint64 noticeEndsAt) {
        uint256 cap = StreamArtistRecoveryAdmission.readCap(suite.registry);
        IStreamEntropyArtistUnavailability.Intent memory current =
            intent(suite, coordinator, input, cap);
        T.Binding memory binding_ =
            StreamArtistRecoveryAdmission.binding(suite, current.collectionId, _nestedCap(cap));
        artistId = binding_.artistId;
        IStreamArtistUnavailabilityOwner owner = IStreamArtistUnavailabilityOwner(suite.owners[2]);
        hash = owner.latestUnavailabilityFinding(artistId, current.collectionId);
        if (hash == 0 || hash != expectedFinding) return (false, hash, artistId, 0);
        (Recovery.FindingRecord memory record, EU.Admission memory a) = IStreamArtistEntropyUnavailabilityOwner(
                suite.owners[2]
            ).entropyUnavailabilityFindingRecord(hash);
        noticeEndsAt = record.noticeEndsAt;
        // The fixed owner installs a nonlocal origin only through the complete atomic op60
        // profile. Current binding/activity and the actual live entropy host are still checked.
        address origin = IStreamArtistEntropyFindingHydrationOwner(suite.owners[2])
            .entropyUnavailabilityFindingOrigin(hash);
        if (origin == address(0)) return (false, hash, artistId, noticeEndsAt);
        StreamArtistHashes.Environment memory env =
            StreamArtistHashes.Environment(block.chainid, origin, suite.core, suite.mintManager);
        valid = a.target.coordinator == coordinator && a.coordinatorCodeHash == coordinator.codehash
            && a.target.intentHash == expectedIntent
            && expectedIntent == EU.intentHash(coordinator, suite.core, current)
            && keccak256(abi.encode(a.target.recovery)) == keccak256(abi.encode(input))
            && keccak256(abi.encode(a.intent)) == keccak256(abi.encode(current))
            && a.target.unavailableEvidenceHash != 0 && a.governanceWitnessHash != 0
            && record.recordHash == hash && record.terms.artistId == artistId
            && record.terms.collectionId == current.collectionId && record.terms.reasonHash != 0
            && record.recordedAt != 0 && record.noticeSeconds >= 30 days
            && record.timingRevision != 0
            && uint256(record.noticeEndsAt) == uint256(record.recordedAt) + record.noticeSeconds
            && StreamArtistRecoveryHashes.findingRecord(env, record) == hash
            && record.terms.evidenceHash
                == EU.evidenceHash(origin, suite.core, a.target, a.intent, a.coordinatorCodeHash)
            && owner.unavailabilityFindingLive(hash, binding_);
    }

    function intent(
        T.SuiteConfiguration memory suite,
        address coordinator,
        IStreamEntropyFreshRecovery.RecoveryInput memory input,
        uint256 cap
    ) public view returns (IStreamEntropyArtistUnavailability.Intent memory) {
        bytes memory pointer = _read(
            suite.core,
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ENTROPY_COORDINATOR"))
            ),
            320,
            cap
        );
        uint256 target;
        bytes32 hash;
        assembly ("memory-safe") {
            target := mload(add(pointer, 32))
            hash := mload(add(pointer, 64))
        }
        if (
            target >> 160 != 0 || coordinator == address(0)
                || target != uint256(uint160(coordinator)) || coordinator.code.length == 0
                || coordinator.codehash != hash
                || _address(coordinator, abi.encodeWithSignature("core()"), cap) != suite.core
        ) {
            revert T.ComponentChanged(coordinator);
        }
        bytes memory supported = _read(
            coordinator,
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamEntropyArtistUnavailability).interfaceId)
            ),
            32,
            cap
        );
        if (abi.decode(supported, (uint256)) != 1) revert T.ComponentChanged(coordinator);
        // The actual host owns token/scope identity, policy/journal/provider/probe and elapsed block-delay checks.
        return abi.decode(
            _read(
                coordinator,
                abi.encodeCall(
                    IStreamEntropyArtistUnavailability.artistEntropyRecoveryIntent, (input)
                ),
                416,
                cap
            ),
            (IStreamEntropyArtistUnavailability.Intent)
        );
    }

    // A bounded external Artist callback cannot promise its own entire cap to every nested
    // dependency. The original binding reader still receives an explicit maximum and keeps
    // its original full-call reserve; reserve half the remaining frame for its complete proof.
    function _nestedCap(uint256 maximum) private view returns (uint256) {
        uint256 available = gasleft();
        if (available <= 200000) revert T.InvalidBinding();
        uint256 budget = (available - 200000) / 2;
        return maximum < budget ? maximum : budget;
    }

    function _address(address target, bytes memory data, uint256 cap)
        private
        view
        returns (address)
    {
        uint256 value = abi.decode(_read(target, data, 32, cap), (uint256));
        if (value == 0 || value >> 160 != 0) revert T.InvalidBinding();
        return address(uint160(value));
    }

    function _read(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        uint256 available = gasleft();
        if (available <= 100000 || cap == 0) revert T.InvalidBinding();
        if (cap > available - 100000) cap = available - 100000;
        raw = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert T.ComponentChanged(target);
    }
}
