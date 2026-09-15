// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";

import "./StreamEntropyCoordinator.sol";
import "./StreamEntropyRequestPlan.sol";
import "./StreamEntropyCollectionRecovery.sol";
import "./StreamEntropyIncidentEvidence.sol";
import "../../interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";

/// @notice Fixed recovery worker. Original request, subject and custody storage remain in the host.
library StreamEntropyFreshRecovery {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STORAGE_V1");
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_RECOVERY_V1");
    bytes32 private constant ARTIST_GAS = keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS");

    struct Store {
        mapping(uint256 => bytes32) heads;
        mapping(bytes32 => IStreamEntropyFreshRecovery.RecoveryReceipt) receipts;
        mapping(bytes32 => bytes32) successor;
        mapping(bytes32 => bool) consumedArtistEvidence;
    }

    struct Environment {
        IStreamCore core;
        uint256 liveDelay;
        uint256 probeGas;
    }

    struct Preview {
        StreamEntropyRequestPlan.Plan plan;
        bytes32 head;
        bytes32 contentState;
        bytes32 incidentEvidence;
        bool acceptLate;
    }
    event EntropyRecoveryRequested(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        address indexed oldProvider,
        address newProvider,
        bytes32 oldRequestKey,
        bytes32 newRequestKey,
        uint32 oldProviderEpoch,
        uint32 newProviderEpoch,
        string reasonURI,
        bytes32 evidenceHash
    );
    event EntropyRecoveryEvidence(
        uint16 schemaVersion,
        bytes32 indexed newRequestKey,
        bytes32 indexed scopeId,
        bytes32 artistRecordHash,
        bytes32 providerEvidenceHash,
        bytes32 incidentEvidenceHash,
        bytes32 contentStateHash,
        bytes32 journalHead
    );

    function store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function receipt(bytes32 key)
        public
        view
        returns (IStreamEntropyFreshRecovery.RecoveryReceipt memory)
    {
        return store().receipts[key];
    }

    function familyState(IStreamCore core, uint256 collectionId, bytes32 family)
        public
        view
        returns (bool, bytes32)
    {
        if (family != FAMILY || !core.collectionExists(collectionId)) return (false, 0);
        return (true, _state(core, collectionId, store().heads[collectionId]));
    }

    function _state(IStreamCore core, uint256 id, bytes32 head) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RECOVERY_CONTENT_STATE_V1"),
                block.chainid,
                address(this),
                address(core),
                id,
                StreamEntropyCollectionRecovery.record(id),
                head
            )
        );
    }

    function mayFulfill(bytes32 key, bytes32 active) public view returns (bool) {
        if (key == active) return true;
        for (uint256 i; i < 32; ++i) {
            bytes32 next = store().successor[key];
            if (next == 0 || !store().receipts[next].acceptLateOriginalFulfillment) return false;
            if (next == active) return true;
            key = next;
        }
        return false;
    }

    function wasSuperseded(bytes32 key) public view returns (bool) {
        return store().successor[key] != 0;
    }

    function preview(
        Environment memory env,
        mapping(bytes32 => StreamEntropyCoordinator.Subject) storage subjects,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage requests,
        mapping(bytes32 => IStreamEntropyEpochs.RequestPolicySnapshot) storage policies,
        IStreamEntropyFreshRecovery.RecoveryInput memory input
    ) public view returns (Preview memory p) {
        StreamEntropyCoordinator.Request storage old = requests[input.oldRequestKey];
        StreamEntropyCoordinator.Subject storage subject = subjects[old.subjectKey];
        IStreamEntropyEpochs.RequestPolicySnapshot storage saved = policies[input.oldRequestKey];
        if (
            old.provider == address(0) || subject.status != StreamEntropyStatus.FAILED
                || subject.requestKey != input.oldRequestKey || subject.seed != 0
                || old.rawRandomness != 0 || saved.requestAttempt == 0
                || store().successor[input.oldRequestKey] != 0 || input.providerEvidenceHash == 0
                || bytes(input.reasonURI).length == 0 || bytes(input.reasonURI).length > 2048
        ) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryUnavailable(input.oldRequestKey);
        }
        if (
            old.tokenId != 0
                && (env.core.tokenLifecycle(old.tokenId) != uint8(StreamTokenLifecycle.MINTED)
                    || env.core.coordinatorAtMint(old.tokenId) != address(this))
        ) {
            revert StreamEntropyCoordinator.InvalidToken(old.tokenId);
        }
        IStreamEntropyCollectionRecovery.CollectionRecovery memory binding =
            StreamEntropyCollectionRecovery.record(subject.collectionId);
        (IStreamEntropyRecoveryPolicies.FreshRecoveryPolicy memory policy, bytes32 hash,,) =
            StreamEntropyRecoveryPolicies.record(binding.policyId);
        if (
            binding.maxFreshRecoveryAttempts == 0
                || saved.requestAttempt > binding.maxFreshRecoveryAttempts || !policy.frozen
                || !policy.exists || hash != binding.policyHash
                || saved.requestAttempt > policy.steps.length
        ) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryUnavailable(input.oldRequestKey);
        }
        IStreamEntropyRecoveryPolicies.FreshRecoveryStep memory step =
            policy.steps[saved.requestAttempt - 1];
        if (step.providerEpoch <= saved.providerEpoch) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryUnavailable(input.oldRequestKey);
        }
        IStreamEntropyIncidents.Incident memory incident =
            StreamEntropyIncidentEvidence.incident(input.oldRequestKey);
        if (incident.declarer == address(0) || incident.evidenceHash == 0) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryUnavailable(input.oldRequestKey);
        }
        uint256 delay = env.liveDelay > step.notBeforeBlocks ? env.liveDelay : step.notBeforeBlocks;
        if (
            block.number <= incident.declaredAtBlock
                || block.number - incident.declaredAtBlock <= delay
        ) {
            // Saturation is informational only; the eligibility comparison above never adds.
            uint256 end = delay > type(uint256).max - incident.declaredAtBlock
                ? type(uint256).max
                : delay + incident.declaredAtBlock;
            revert IStreamEntropyFreshRecovery.FreshRecoveryTooEarly(end);
        }
        _negative(input.oldRequestKey, old, saved, env.probeGas);
        bytes32 previous = store().receipts[input.oldRequestKey].previousRequestKey;
        for (uint256 i; previous != 0 && i < 32; ++i) {
            if (!mayFulfill(previous, input.oldRequestKey)) break;
            _negative(previous, requests[previous], policies[previous], env.probeGas);
            previous = store().receipts[previous].previousRequestKey;
        }
        IStreamEntropyProviderLifecycle.ProviderRecord memory provider =
            StreamEntropyProviderLifecycle.record(step.provider);
        p.plan = StreamEntropyRequestPlan.build(
            env.core,
            subject.collectionId,
            old.tokenId,
            old.scopeId,
            IStreamEntropyEpochs.RequestPolicySnapshot(
                step.provider,
                provider.runtimeCodeHash,
                step.providerEpoch,
                step.providerConfigHash,
                saved.collectionSalt,
                saved.inputsHash,
                saved.requestAttempt + 1
            )
        );
        if (requests[p.plan.key].provider != address(0)) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryUnavailable(p.plan.key);
        }
        p.incidentEvidence = incident.evidenceHash;
        p.acceptLate = step.acceptLateOriginalFulfillment;
        p.head = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RECOVERY_JOURNAL_V1"),
                store().heads[subject.collectionId],
                input.oldRequestKey,
                p.plan.key,
                p.plan.policy,
                input.providerEvidenceHash,
                incident.evidenceHash,
                keccak256(bytes(input.reasonURI))
            )
        );
        p.contentState = _state(env.core, subject.collectionId, p.head);
    }

    /// @notice Encode the small public quote in the worker rather than decoding its internal plan in the host.
    function transition(
        Environment memory env,
        mapping(bytes32 => StreamEntropyCoordinator.Subject) storage subjects,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage requests,
        mapping(bytes32 => IStreamEntropyEpochs.RequestPolicySnapshot) storage policies,
        IStreamEntropyFreshRecovery.RecoveryInput memory input
    ) public view returns (bytes32, bytes32, uint256) {
        Preview memory p = preview(env, subjects, requests, policies, input);
        return (p.plan.key, p.contentState, p.plan.fee);
    }

    function _negative(
        bytes32 key,
        StreamEntropyCoordinator.Request storage request,
        IStreamEntropyEpochs.RequestPolicySnapshot storage policy,
        uint256 gasCap
    ) private view {
        if (request.rawRandomness != 0) {
            revert StreamEntropyCoordinator.ProviderOutputAlreadyReceived();
        }
        StreamEntropyIncidentEvidence.requireNegative(
            key, request.provider, policy.providerCodeHash, request.providerRequestId, gasCap
        );
    }

    function admit(
        Environment memory env,
        mapping(bytes32 => StreamEntropyCoordinator.Subject) storage subjects,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage requests,
        mapping(bytes32 => IStreamEntropyEpochs.RequestPolicySnapshot) storage policies,
        IStreamEntropyFreshRecovery.RecoveryInput memory input
    ) public returns (StreamEntropyRequestPlan.Plan memory) {
        Preview memory p = preview(env, subjects, requests, policies, input);
        StreamEntropyCoordinator.Request storage old = requests[input.oldRequestKey];
        uint256 id = subjects[old.subjectKey].collectionId;
        bytes32 artist = _artistEvidence(env.core, id, p.contentState);
        Store storage s = store();
        if (artist != 0) {
            if (s.consumedArtistEvidence[artist]) {
                revert IStreamEntropyFreshRecovery.FreshRecoveryEvidenceConsumed(artist);
            }
            s.consumedArtistEvidence[artist] = true;
        }
        bytes32 evidence = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RECOVERY_EVIDENCE_V1"),
                input.providerEvidenceHash,
                p.incidentEvidence,
                artist,
                input.oldRequestKey,
                p.plan.key,
                p.contentState,
                keccak256(bytes(input.reasonURI))
            )
        );
        s.heads[id] = p.head;
        s.successor[input.oldRequestKey] = p.plan.key;
        s.receipts[p.plan.key] = IStreamEntropyFreshRecovery.RecoveryReceipt(
            input.oldRequestKey,
            artist,
            input.providerEvidenceHash,
            p.incidentEvidence,
            evidence,
            p.contentState,
            p.head,
            uint64(block.number),
            p.acceptLate
        );
        emit EntropyRecoveryRequested(
            1,
            id,
            old.tokenId,
            old.provider,
            p.plan.policy.provider,
            input.oldRequestKey,
            p.plan.key,
            policies[input.oldRequestKey].providerEpoch,
            p.plan.policy.providerEpoch,
            input.reasonURI,
            evidence
        );
        emit EntropyRecoveryEvidence(
            1,
            p.plan.key,
            old.scopeId,
            artist,
            input.providerEvidenceHash,
            p.incidentEvidence,
            p.contentState,
            p.head
        );
        return p.plan;
    }

    function _artistEvidence(IStreamCore core, uint256 id, bytes32 next)
        private
        view
        returns (bytes32)
    {
        (address registry, bytes32 hash,,,,,,,,) =
            core.getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (registry.code.length == 0 || registry.codehash != hash) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        bytes memory raw = _read(registry, abi.encodeWithSignature("core()"), 32, 100000);
        if (abi.decode(raw, (uint256)) != uint256(uint160(address(core)))) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        raw = _read(
            registry, abi.encodeWithSignature("gasParameterInfo(bytes32)", ARTIST_GAS), 128, 100000
        );
        (uint256 cap, uint256 floor, uint256 direction, uint256 revision) =
            abi.decode(raw, (uint256, uint256, uint256, uint256));
        if (
            cap == 0 || cap == type(uint256).max || floor == 0 || cap < floor || direction != 2
                || revision == 0
        ) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        raw = _read(
            registry,
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (id)),
            160,
            cap
        );
        (
            uint256 state,
            uint256 generation,
            bytes32 artistId,
            uint256 authorityStatus,
            bytes32 bindingHash
        ) = abi.decode(raw, (uint256, uint256, bytes32, uint256, bytes32));
        if (state > 5 || generation > type(uint64).max || authorityStatus > type(uint8).max) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        if (
            state == 0 && generation == 0 && artistId == 0 && authorityStatus == 0
                && bindingHash == 0
        ) {
            return 0;
        }
        raw = _read(
            registry,
            abi.encodeCall(
                IStreamArtistContentHostEvidence.contentConsentEvidenceForHost,
                (id, address(this), FAMILY, next)
            ),
            32,
            cap
        );
        bytes32 record = abi.decode(raw, (bytes32));
        if (record == 0) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        return record;
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(size);
        uint256 available = gasleft();
        if (available <= 105000) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        if (cap > available - 105000) cap = available - 105000;
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
    }
}
