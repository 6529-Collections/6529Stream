// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamEntropyCoordinator as H } from "./StreamEntropyCoordinator.sol";
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { IStreamRoleRegistry } from "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import { IStreamRevealFeeEscrow } from "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import { IStreamEntropyEpochs } from "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import {
    IStreamEntropyFreshRecovery
} from "../../interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import { StreamEntropyStatus } from "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import {
    IStreamTimeParameterHost
} from "../../interfaces/stream/parameters/IStreamTimeParameterHost.sol";
import { StreamTimeParameterHost } from "../parameters/StreamTimeParameterHost.sol";
import {
    StreamEntropyPolicyImportState as PolicyImportState
} from "./StreamEntropyPolicyImportState.sol";
import { StreamEntropyContinuity } from "./StreamEntropyContinuity.sol";
import { StreamEntropyOriginRelay as Relay } from "./StreamEntropyOriginRelay.sol";
import { StreamEntropyCoordinatorReads } from "./StreamEntropyCoordinatorReads.sol";
import { StreamEntropyIncidentParameters } from "./StreamEntropyIncidentParameters.sol";
import { StreamEntropyIncidentTransition } from "./StreamEntropyIncidentTransition.sol";
import { StreamEntropyFreshRecovery } from "./StreamEntropyFreshRecovery.sol";
import { StreamEntropyFulfillment } from "./StreamEntropyFulfillment.sol";
import { StreamEntropyRequestPlan } from "./StreamEntropyRequestPlan.sol";
import { StreamEntropyRequestSubmission } from "./StreamEntropyRequestSubmission.sol";
import { StreamEntropyTerminalAdmission } from "./StreamEntropyTerminalAdmission.sol";
import { StreamEntropyCollectionConfiguration } from "./StreamEntropyCollectionConfiguration.sol";
import { StreamEntropyScopeRegistration } from "./StreamEntropyScopeRegistration.sol";

/// @notice Fixed execution worker for the Coordinator's original request and custody entrypoints.
/// @dev The host retains its exact modifiers and passes its original typed storage references.
///      No new storage is allocated. All calls retain host address, original sender and value.
library StreamEntropyExecution {
    struct Word {
        uint256 value;
    }

    struct Environment {
        IStreamCore core;
        address authority;
        IStreamRoleRegistry roleRegistry;
        bytes32 roleRegistryCodeHash;
    }

    // Local slot descriptors are derived solely from the explicit typed parameters to write.
    // They are not protocol state, absolute slot constants, or an external selector capability.
    struct Bindings {
        uint256 configs;
        uint256 requesters;
        uint256 revoked;
        uint256 subjects;
        uint256 requests;
        uint256 providerKeys;
        uint256 credits;
        uint256 creditTotal;
        uint256 pending;
        uint256 notifications;
        uint256 scopes;
        uint256 revealPolicies;
        uint256 escrows;
        uint256 escrowTotal;
        uint256 registered;
        uint256 nonterminal;
        uint256 epochs;
        uint256 policies;
        uint256 times;
    }

    bytes32 private constant GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS =
        keccak256("6529STREAM_GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS");
    bytes32 private constant GTP_ENTROPY_REVEAL_SLO_BLOCKS =
        keccak256("6529STREAM_GTP_ENTROPY_REVEAL_SLO_BLOCKS");
    bytes32 private constant GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS =
        keccak256("6529STREAM_GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS");
    bytes32 private constant GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT");
    bytes32 private constant _ENTROPY_ADMIN = keccak256("ROLE_ENTROPY_ADMIN");
    bytes32 private constant _TREASURY = keccak256("ROLE_TREASURY");

    error UnsupportedExecutionSelector(bytes4 selector);

    event EntropyFinalized(
        bytes32 indexed requestKey,
        uint256 indexed tokenId,
        bytes32 indexed scopeId,
        bytes32 seed,
        bytes32 rawRandomness
    );
    event EntropyRequestTerminal(bytes32 indexed requestKey, StreamEntropyStatus status);
    event EntropyFulfillmentRejected(bytes32 indexed requestKey, uint8 outcome);
    event EntropyFeeCredited(address indexed payer, uint256 amount);
    event EntropyRequesterUpdated(address indexed requester, bool allowed);
    event EntropyFeeCreditClaimed(
        address indexed payer, address indexed destination, uint256 amount
    );
    event RevealFeeEscrowFunded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed funder,
        uint256 amountWei,
        uint256 escrowWei
    );
    event RevealFeeEscrowSpent(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        uint256 amountWei,
        uint256 escrowWei
    );
    event RevealFeeEscrowWithdrawn(
        uint16 schemaVersion, uint256 indexed collectionId, address indexed to, uint256 amountWei
    );

    function write(
        Environment memory e,
        mapping(uint256 => H.CollectionConfig) storage configs,
        mapping(address => bool) storage requesters,
        mapping(address => bool) storage revoked,
        mapping(bytes32 => H.Subject) storage subjects,
        mapping(bytes32 => H.Request) storage requests,
        mapping(address => mapping(uint256 => bytes32)) storage providerKeys,
        mapping(address => uint256) storage credits,
        Word storage creditTotal,
        Word storage pending,
        mapping(uint256 => bool) storage notifications,
        mapping(bytes32 => bool) storage scopes,
        mapping(
            uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy
        ) storage revealPolicies,
        mapping(uint256 => uint256) storage escrows,
        Word storage escrowTotal,
        mapping(uint256 => uint64) storage registered,
        mapping(uint256 => uint256) storage nonterminal,
        mapping(uint256 => uint32) storage epochs,
        mapping(
            bytes32 => IStreamEntropyEpochs.RequestPolicySnapshot
        ) storage policies,
        mapping(bytes32 => StreamTimeParameterHost.TimeParameterData) storage times,
        bytes calldata input
    ) public returns (bytes memory) {
        Bindings memory s;
        assembly ("memory-safe") { mstore(add(s, 0), configs.slot) }
        assembly ("memory-safe") { mstore(add(s, 32), requesters.slot) }
        assembly ("memory-safe") { mstore(add(s, 64), revoked.slot) }
        assembly ("memory-safe") { mstore(add(s, 96), subjects.slot) }
        assembly ("memory-safe") { mstore(add(s, 128), requests.slot) }
        assembly ("memory-safe") { mstore(add(s, 160), providerKeys.slot) }
        assembly ("memory-safe") { mstore(add(s, 192), credits.slot) }
        assembly ("memory-safe") { mstore(add(s, 224), creditTotal.slot) }
        assembly ("memory-safe") { mstore(add(s, 256), pending.slot) }
        assembly ("memory-safe") { mstore(add(s, 288), notifications.slot) }
        assembly ("memory-safe") { mstore(add(s, 320), scopes.slot) }
        assembly ("memory-safe") { mstore(add(s, 352), revealPolicies.slot) }
        assembly ("memory-safe") { mstore(add(s, 384), escrows.slot) }
        assembly ("memory-safe") { mstore(add(s, 416), escrowTotal.slot) }
        assembly ("memory-safe") { mstore(add(s, 448), registered.slot) }
        assembly ("memory-safe") { mstore(add(s, 480), nonterminal.slot) }
        assembly ("memory-safe") { mstore(add(s, 512), epochs.slot) }
        assembly ("memory-safe") { mstore(add(s, 544), policies.slot) }
        assembly ("memory-safe") { mstore(add(s, 576), times.slot) }
        return _dispatch(s, e, input);
    }

    function _dispatch(Bindings memory s, Environment memory e, bytes calldata input)
        private
        returns (bytes memory)
    {
        bytes4 selector = bytes4(input[:4]);
        if (selector == H.requestEntropy.selector) {
            (uint256 tokenId) = abi.decode(input[4:], (uint256));
            (bytes32 key, uint256 id) = _requestEntropy(s, e, tokenId);
            return abi.encode(key, id);
        }
        if (selector == H.requestScopeEntropy.selector) {
            (bytes32 scopeId, bytes32 inputsHash) = abi.decode(input[4:], (bytes32, bytes32));
            (bytes32 key, uint256 id) = _requestScopeEntropy(s, e, scopeId, inputsHash);
            return abi.encode(key, id);
        }
        if (selector == H.requestFreshEntropy.selector) {
            (IStreamEntropyFreshRecovery.RecoveryInput memory recovery) =
                abi.decode(input[4:], (IStreamEntropyFreshRecovery.RecoveryInput));
            (bytes32 key, uint256 id) = _requestFreshEntropy(s, e, recovery);
            return abi.encode(key, id);
        }
        if (selector == H.requestFreshEntropyWithUnavailability.selector) {
            (IStreamEntropyFreshRecovery.RecoveryInput memory recovery, bytes32 finding) =
                abi.decode(input[4:], (IStreamEntropyFreshRecovery.RecoveryInput, bytes32));
            (bytes32 key, uint256 id) =
                _requestFreshEntropyWithUnavailability(s, e, recovery, finding);
            return abi.encode(key, id);
        }
        if (selector == H.fulfillEntropy.selector) {
            (bytes32 key, bytes32 raw) = abi.decode(input[4:], (bytes32, bytes32));
            return abi.encode(_fulfillEntropy(s, e, key, raw));
        }
        if (selector == H.fulfillRelayedEntropy.selector) {
            (bytes32 key, bytes32 relayId, bytes32 raw) =
                abi.decode(input[4:], (bytes32, bytes32, bytes32));
            return abi.encode(_fulfillRelayedEntropy(s, e, key, relayId, raw));
        }
        if (selector == H.retryMetadataNotification.selector) {
            (uint256 tokenId) = abi.decode(input[4:], (uint256));
            _retryMetadataNotification(s, e, tokenId);
            return bytes("");
        }
        if (selector == H.fundRevealFeeEscrow.selector) {
            (uint256 collectionId) = abi.decode(input[4:], (uint256));
            _fundRevealFeeEscrow(s, e, collectionId);
            return bytes("");
        }
        if (selector == H.withdrawRevealFeeEscrow.selector) {
            (uint256 collectionId, uint256 amount) = abi.decode(input[4:], (uint256, uint256));
            _withdrawRevealFeeEscrow(s, e, collectionId, amount);
            return bytes("");
        }
        if (selector == H.claimEntropyFeeCredit.selector) {
            (address destination) = abi.decode(input[4:], (address));
            _claimEntropyFeeCredit(s, e, payable(destination));
            return bytes("");
        }
        if (selector == H.markEntropyRequestUnrecoverable.selector) {
            (uint256 tokenId, string memory reason, bytes32 evidence) =
                abi.decode(input[4:], (uint256, string, bytes32));
            _markEntropyRequestUnrecoverable(s, e, tokenId, reason, evidence);
            return bytes("");
        }
        if (selector == H.markEntropyScopeRequestUnrecoverable.selector) {
            (bytes32 scopeId, string memory reason, bytes32 evidence) =
                abi.decode(input[4:], (bytes32, string, bytes32));
            _markEntropyScopeRequestUnrecoverable(s, e, scopeId, reason, evidence);
            return bytes("");
        }
        if (selector == H.markRequestStale.selector) {
            (bytes32 key) = abi.decode(input[4:], (bytes32));
            _markRequestStale(s, e, key);
            return bytes("");
        }
        if (selector == H.markRequestFailed.selector) {
            (bytes32 key) = abi.decode(input[4:], (bytes32));
            _markRequestFailed(s, e, key);
            return bytes("");
        }
        if (selector == H.configureCollection.selector) {
            (
                uint256 collectionId,
                address provider,
                bytes32 collectionSalt,
                bool publicRequests,
                uint64 timeoutBlocks
            ) = abi.decode(input[4:], (uint256, address, bytes32, bool, uint64));
            PolicyImportState.requireOperationalAndMarkUsed();
            StreamEntropyCollectionConfiguration.configure(
                e.core,
                _configs(s),
                _epochs(s),
                _revealPolicies(s),
                collectionId,
                provider,
                collectionSalt,
                publicRequests,
                timeoutBlocks
            );
            return bytes("");
        }
        if (selector == H.configureCollectionRevealPolicy.selector) {
            _requireEntropyAdmin(s, e);
            PolicyImportState.requireOperationalAndMarkUsed();
            StreamEntropyCollectionConfiguration.configureReveal(
                e.core, _configs(s), _revealPolicies(s), input[4:]
            );
            return bytes("");
        }
        if (selector == H.updateRevealFeePerToken.selector) {
            (uint256 collectionId, uint256 next) = abi.decode(input[4:], (uint256, uint256));
            _requireEntropyAdmin(s, e);
            PolicyImportState.requireOperationalAndMarkUsed();
            StreamEntropyCollectionConfiguration.updateFee(
                _configs(s), _revealPolicies(s), collectionId, next
            );
            return bytes("");
        }
        if (selector == H.setRequester.selector) {
            (address requester, bool allowed) = abi.decode(input[4:], (address, bool));
            if (requester == address(0)) revert H.InvalidDependency(requester);
            _requesters(s)[requester] = allowed;
            emit EntropyRequesterUpdated(requester, allowed);
            return bytes("");
        }
        if (selector == H.onTokenMinted.selector) {
            PolicyImportState.requireOperationalAndMarkUsed();
            StreamEntropyScopeRegistration.token(
                e.core,
                _subjects(s),
                _configs(s),
                _revealPolicies(s),
                _registered(s),
                _nonterminal(s),
                input[4:]
            );
            return bytes("");
        }
        revert UnsupportedExecutionSelector(selector);
    }

    function _requestEntropy(Bindings memory s, Environment memory e, uint256 tokenId)
        private
        returns (bytes32 requestKey, uint256 providerRequestId)
    {
        H.Subject storage subject = _subjects(s)[_tokenKey(tokenId)];
        StreamEntropyRequestPlan.authorizeToken(
            StreamEntropyRequestPlan.Authorization(
                e.core,
                e.authority,
                e.roleRegistry,
                e.roleRegistryCodeHash,
                _requesters(s)[msg.sender],
                _timeParameterValue(s, GTP_ENTROPY_REVEAL_SLO_BLOCKS)
            ),
            subject,
            _configs(s)[subject.collectionId],
            _revealPolicies(s)[subject.collectionId],
            _registered(s)[tokenId],
            tokenId
        );
        return _request(s, e, _tokenKey(tokenId), tokenId, bytes32(0));
    }

    function _requestScopeEntropy(
        Bindings memory s,
        Environment memory e,
        bytes32 scopeId,
        bytes32 scopeInputsHash
    ) private returns (bytes32 requestKey, uint256 providerRequestId) {
        if (msg.sender != e.authority && !_requesters(s)[msg.sender]) {
            revert H.Unauthorized(msg.sender);
        }
        // Token keys share _subjects(s) storage but must never enter the mutable scope-input path.
        if (!_scopes(s)[scopeId] || scopeInputsHash == 0) revert H.InvalidSubject(scopeId);
        _subjects(s)[scopeId].inputsHash = scopeInputsHash;
        return _request(s, e, scopeId, 0, scopeId);
    }

    function _requestFreshEntropy(
        Bindings memory s,
        Environment memory e,
        IStreamEntropyFreshRecovery.RecoveryInput memory input
    ) private returns (bytes32 requestKey, uint256 providerRequestId) {
        return _requestFreshWithEvidence(s, e, input, bytes32(0));
    }

    function _requestFreshEntropyWithUnavailability(
        Bindings memory s,
        Environment memory e,
        IStreamEntropyFreshRecovery.RecoveryInput memory input,
        bytes32 findingRecordHash
    ) private returns (bytes32 requestKey, uint256 providerRequestId) {
        if (findingRecordHash == 0) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        return _requestFreshWithEvidence(s, e, input, findingRecordHash);
    }

    function _fulfillEntropy(
        Bindings memory s,
        Environment memory e,
        bytes32 requestKey,
        bytes32 rawRandomness
    ) private returns (uint8 outcome) {
        (bool relayed, uint8 relayOutcome) = Relay.capture(
            e.core, _requests(s), _providerKeys(s), requestKey, rawRandomness
        );
        if (relayed) return relayOutcome;
        H.Request storage request = _requests(s)[requestKey];
        H.Subject storage subject = _subjects(s)[request.subjectKey];
        bytes32 activeRequestKey = subject.requestKey;
        outcome = StreamEntropyFulfillment.finalize(
            e.core, request, subject, _policies(s)[requestKey], requestKey, rawRandomness
        );
        if (outcome != 0) return _reject(s, e, requestKey, outcome);
        StreamEntropyContinuity.close(activeRequestKey);
        _completeRequest(s, e, requestKey, request, subject);
        return 0;
    }

    function _fulfillRelayedEntropy(
        Bindings memory s,
        Environment memory e,
        bytes32 requestKey,
        bytes32 relayId,
        bytes32 rawRandomness
    ) private returns (uint8 outcome) {
        H.Request storage request = _requests(s)[requestKey];
        H.Subject storage subject = _subjects(s)[request.subjectKey];
        bytes32 activeRequestKey = subject.requestKey;
        outcome = StreamEntropyFulfillment.finalizeRelayed(
            e.core,
            request,
            subject,
            _policies(s)[requestKey],
            _providerKeys(s),
            requestKey,
            relayId,
            rawRandomness
        );
        if (outcome != 0) return _reject(s, e, requestKey, outcome);
        StreamEntropyContinuity.close(activeRequestKey);
        _completeRequest(s, e, requestKey, request, subject);
        return 0;
    }

    function _retryMetadataNotification(Bindings memory s, Environment memory e, uint256 tokenId)
        private
    {
        StreamEntropyFulfillment.retryNotification(e.core, _subjects(s), _notifications(s), tokenId);
    }

    function _fundRevealFeeEscrow(Bindings memory s, Environment memory e, uint256 collectionId)
        private
    {
        PolicyImportState.requireOperationalAndMarkUsed();
        if (!e.core.collectionExists(collectionId)) revert H.InvalidCollection(collectionId);
        if (!_revealPolicies(s)[collectionId].declared) {
            revert H.RevealPolicyUndeclared(collectionId);
        }
        _escrows(s)[collectionId] += msg.value;
        _escrowTotal(s).value += msg.value;
        emit RevealFeeEscrowFunded(
            1, collectionId, msg.sender, msg.value, _escrows(s)[collectionId]
        );
    }

    function _withdrawRevealFeeEscrow(
        Bindings memory s,
        Environment memory e,
        uint256 collectionId,
        uint256 amount
    ) private {
        _requireEntropyAdmin(s, e);
        if (!_revealPolicies(s)[collectionId].declared) {
            revert H.RevealPolicyUndeclared(collectionId);
        }
        if (_nonterminal(s)[collectionId] != 0 || amount == 0 || amount > _escrows(s)[collectionId])
        {
            revert H.RevealEscrowUnavailable(collectionId);
        }
        address treasury = e.roleRegistry.resolveRole(_TREASURY);
        if (treasury.code.length == 0) revert H.InvalidDestination();
        _escrows(s)[collectionId] -= amount;
        _escrowTotal(s).value -= amount;
        (bool success,) = treasury.call{ value: amount }("");
        if (!success) revert H.CreditTransferFailed();
        emit RevealFeeEscrowWithdrawn(1, collectionId, treasury, amount);
    }

    function _claimEntropyFeeCredit(Bindings memory s, Environment memory e, address destination)
        private
    {
        if (destination == address(0)) revert H.InvalidDestination();
        uint256 amount = _credits(s)[msg.sender];
        _credits(s)[msg.sender] = 0;
        _creditTotal(s).value -= amount;
        (bool success,) = destination.call{ value: amount }("");
        if (!success) revert H.CreditTransferFailed();
        emit EntropyFeeCreditClaimed(msg.sender, destination, amount);
    }

    function _markEntropyRequestUnrecoverable(
        Bindings memory s,
        Environment memory e,
        uint256 tokenId,
        string memory reasonURI,
        bytes32 evidenceHash
    ) private {
        if (tokenId == 0) revert H.InvalidToken(tokenId);
        _markUnrecoverable(s, e, _tokenKey(tokenId), tokenId, bytes32(0), reasonURI, evidenceHash);
    }

    function _markEntropyScopeRequestUnrecoverable(
        Bindings memory s,
        Environment memory e,
        bytes32 scopeId,
        string memory reasonURI,
        bytes32 evidenceHash
    ) private {
        if (!_scopes(s)[scopeId]) revert H.InvalidSubject(scopeId);
        _markUnrecoverable(s, e, scopeId, 0, scopeId, reasonURI, evidenceHash);
    }

    function _markRequestStale(Bindings memory s, Environment memory e, bytes32 requestKey)
        private
    {
        H.Request storage request = _requests(s)[requestKey];
        H.Subject storage subject = _subjects(s)[request.subjectKey];
        StreamEntropyTerminalAdmission.stale(request, subject, requestKey);
        _terminal(s, e, requestKey, subject, StreamEntropyStatus.STALE);
    }

    function _markRequestFailed(Bindings memory s, Environment memory e, bytes32 requestKey)
        private
    {
        H.Request storage request = _requests(s)[requestKey];
        H.Subject storage subject = _subjects(s)[request.subjectKey];
        StreamEntropyTerminalAdmission.failed(request, subject, requestKey);
        _terminal(s, e, requestKey, subject, StreamEntropyStatus.FAILED);
    }

    function _request(
        Bindings memory s,
        Environment memory e,
        bytes32 subjectKey,
        uint256 tokenId,
        bytes32 scopeId
    ) private returns (bytes32 requestKey, uint256 providerRequestId) {
        H.Subject storage subject = _subjects(s)[subjectKey];
        StreamEntropyRequestPlan.Plan memory p = StreamEntropyRequestPlan.initial(
            e.core,
            subject,
            _configs(s)[subject.collectionId],
            _epochs(s)[subject.collectionId],
            tokenId,
            scopeId
        );
        return _submitRequest(s, e, subjectKey, tokenId, scopeId, p);
    }

    function _submitRequest(
        Bindings memory s,
        Environment memory e,
        bytes32 subjectKey,
        uint256 tokenId,
        bytes32 scopeId,
        StreamEntropyRequestPlan.Plan memory p
    ) private returns (bytes32 requestKey, uint256 providerRequestId) {
        PolicyImportState.requireOperational();
        H.Subject storage subject = _subjects(s)[subjectKey];
        _fundRequest(s, e, subject.collectionId, tokenId, p.fee);
        requestKey = p.key;
        ++_pending(s).value;
        providerRequestId = StreamEntropyRequestSubmission.submit(
            e.core,
            subject,
            _requests(s),
            _policies(s),
            _providerKeys(s),
            StreamEntropyRequestSubmission.Input(subjectKey, tokenId, scopeId, p)
        );
        if (p.instant) {
            _completeRequest(s, e, requestKey, _requests(s)[requestKey], subject);
        }
    }

    function _requestFreshWithEvidence(
        Bindings memory s,
        Environment memory e,
        IStreamEntropyFreshRecovery.RecoveryInput memory input,
        bytes32 findingRecordHash
    ) private returns (bytes32 requestKey, uint256 providerRequestId) {
        if (!_hasRole(s, e, keccak256("ROLE_ENTROPY_INCIDENT_DECLARER"), msg.sender)) {
            revert H.Unauthorized(msg.sender);
        }
        StreamEntropyRequestPlan.Plan memory p = StreamEntropyFreshRecovery.admitSelected(
            _recoveryEnvironment(s, e),
            _subjects(s),
            _requests(s),
            _policies(s),
            input,
            findingRecordHash
        );
        H.Request storage old = _requests(s)[input.oldRequestKey];
        if (old.tokenId != 0) ++_nonterminal(s)[_subjects(s)[old.subjectKey].collectionId];
        return _submitRequest(s, e, old.subjectKey, old.tokenId, old.scopeId, p);
    }

    function _fundRequest(
        Bindings memory s,
        Environment memory e,
        uint256 collectionId,
        uint256 tokenId,
        uint256 fee
    ) private {
        uint256 draw;
        if (tokenId != 0) {
            uint256 escrow = _escrows(s)[collectionId];
            draw = escrow < fee ? escrow : fee;
        }
        uint256 callerCost = fee - draw;
        if (msg.value < callerCost) {
            if (tokenId == 0) revert H.InsufficientEntropyFee(fee, msg.value);
            revert H.InsufficientRevealFee(fee, draw, msg.value);
        }
        if (draw != 0) {
            _escrows(s)[collectionId] -= draw;
            _escrowTotal(s).value -= draw;
            emit RevealFeeEscrowSpent(1, collectionId, tokenId, draw, _escrows(s)[collectionId]);
        }
        uint256 excess = msg.value - callerCost;
        if (excess != 0) {
            _credits(s)[msg.sender] += excess;
            _creditTotal(s).value += excess;
            emit EntropyFeeCredited(msg.sender, excess);
        }
    }

    function _completeRequest(
        Bindings memory s,
        Environment memory e,
        bytes32 requestKey,
        H.Request storage request,
        H.Subject storage subject
    ) private {
        --_pending(s).value;
        if (request.tokenId != 0) --_nonterminal(s)[subject.collectionId];
        emit EntropyFinalized(
            requestKey, request.tokenId, request.scopeId, subject.seed, request.rawRandomness
        );
        if (request.tokenId != 0) _notify(s, e, request.tokenId, requestKey);
    }

    function _reject(Bindings memory s, Environment memory e, bytes32 requestKey, uint8 outcome)
        private
        returns (uint8)
    {
        emit EntropyFulfillmentRejected(requestKey, outcome);
        return outcome;
    }

    function _notify(Bindings memory s, Environment memory e, uint256 tokenId, bytes32 requestKey)
        private
    {
        StreamEntropyFulfillment.notify(e.core, _notifications(s), tokenId, requestKey);
    }

    function _markUnrecoverable(
        Bindings memory s,
        Environment memory e,
        bytes32 subjectKey,
        uint256 tokenId,
        bytes32 scopeId,
        string memory reasonURI,
        bytes32 evidenceHash
    ) private {
        if (!_hasRole(s, e, keccak256("ROLE_ENTROPY_INCIDENT_DECLARER"), msg.sender)) {
            revert H.Unauthorized(msg.sender);
        }
        H.Subject storage subject = _subjects(s)[subjectKey];
        bytes32 key = subject.requestKey;
        H.Request storage request = _requests(s)[key];
        IStreamEntropyEpochs.RequestPolicySnapshot storage policy = _policies(s)[key];
        StreamEntropyIncidentTransition.record(
            subject,
            request,
            policy,
            subjectKey,
            tokenId,
            scopeId,
            _revoked(s)[request.provider],
            _configs(s)[subject.collectionId],
            _timeParameterValue(s, GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS),
            StreamEntropyIncidentParameters.value(GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT),
            reasonURI,
            evidenceHash
        );
        _terminal(s, e, key, subject, StreamEntropyStatus.FAILED);
        StreamEntropyIncidentTransition.emitFailure(
            subject, request, policy, tokenId, scopeId, reasonURI, evidenceHash
        );
    }

    function _terminal(
        Bindings memory s,
        Environment memory e,
        bytes32 requestKey,
        H.Subject storage subject,
        StreamEntropyStatus status
    ) private {
        subject.status = status;
        StreamEntropyContinuity.close(requestKey);
        --_pending(s).value;
        emit EntropyRequestTerminal(requestKey, status);
        uint256 tokenId = _requests(s)[requestKey].tokenId;
        if (tokenId != 0) {
            --_nonterminal(s)[subject.collectionId];
            _notify(s, e, tokenId, requestKey);
        }
    }

    function _recoveryEnvironment(Bindings memory s, Environment memory e)
        private
        view
        returns (StreamEntropyFreshRecovery.Environment memory)
    {
        return StreamEntropyFreshRecovery.Environment(
            e.core,
            _timeParameterValue(s, GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS),
            StreamEntropyIncidentParameters.value(GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT)
        );
    }

    function _requireEntropyAdmin(Bindings memory s, Environment memory e) private view {
        PolicyImportState.requireOperational();
        if (!_hasRole(s, e, _ENTROPY_ADMIN, msg.sender)) revert H.Unauthorized(msg.sender);
    }

    function _hasRole(Bindings memory s, Environment memory e, bytes32 role, address account)
        private
        view
        returns (bool)
    {
        return StreamEntropyCoordinatorReads.hasRole(
            e.core, e.authority, e.roleRegistry, e.roleRegistryCodeHash, role, account
        );
    }

    function _timeParameterValue(Bindings memory s, bytes32 parameterId)
        private
        view
        returns (uint256)
    {
        StreamTimeParameterHost.TimeParameterData storage parameter = _times(s)[parameterId];
        if (parameter.revision == 0) {
            revert IStreamTimeParameterHost.TimeParameterUnknown(parameterId);
        }
        return parameter.value;
    }

    function _tokenKey(uint256 tokenId) private pure returns (bytes32) {
        return keccak256(abi.encode("TOKEN", tokenId));
    }

    function _configs(Bindings memory s)
        private
        pure
        returns (mapping(uint256 => H.CollectionConfig) storage ref)
    {
        uint256 slot = s.configs;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _requesters(Bindings memory s)
        private
        pure
        returns (mapping(address => bool) storage ref)
    {
        uint256 slot = s.requesters;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _revoked(Bindings memory s)
        private
        pure
        returns (mapping(address => bool) storage ref)
    {
        uint256 slot = s.revoked;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _subjects(Bindings memory s)
        private
        pure
        returns (mapping(bytes32 => H.Subject) storage ref)
    {
        uint256 slot = s.subjects;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _requests(Bindings memory s)
        private
        pure
        returns (mapping(bytes32 => H.Request) storage ref)
    {
        uint256 slot = s.requests;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _providerKeys(Bindings memory s)
        private
        pure
        returns (mapping(address => mapping(uint256 => bytes32)) storage ref)
    {
        uint256 slot = s.providerKeys;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _credits(Bindings memory s)
        private
        pure
        returns (mapping(address => uint256) storage ref)
    {
        uint256 slot = s.credits;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _creditTotal(Bindings memory s) private pure returns (Word storage ref) {
        uint256 slot = s.creditTotal;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _pending(Bindings memory s) private pure returns (Word storage ref) {
        uint256 slot = s.pending;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _notifications(Bindings memory s)
        private
        pure
        returns (mapping(uint256 => bool) storage ref)
    {
        uint256 slot = s.notifications;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _scopes(Bindings memory s)
        private
        pure
        returns (mapping(bytes32 => bool) storage ref)
    {
        uint256 slot = s.scopes;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _revealPolicies(Bindings memory s)
        private
        pure
        returns (mapping(uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy) storage ref)
    {
        uint256 slot = s.revealPolicies;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _escrows(Bindings memory s)
        private
        pure
        returns (mapping(uint256 => uint256) storage ref)
    {
        uint256 slot = s.escrows;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _escrowTotal(Bindings memory s) private pure returns (Word storage ref) {
        uint256 slot = s.escrowTotal;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _registered(Bindings memory s)
        private
        pure
        returns (mapping(uint256 => uint64) storage ref)
    {
        uint256 slot = s.registered;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _nonterminal(Bindings memory s)
        private
        pure
        returns (mapping(uint256 => uint256) storage ref)
    {
        uint256 slot = s.nonterminal;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _epochs(Bindings memory s)
        private
        pure
        returns (mapping(uint256 => uint32) storage ref)
    {
        uint256 slot = s.epochs;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _policies(Bindings memory s)
        private
        pure
        returns (mapping(bytes32 => IStreamEntropyEpochs.RequestPolicySnapshot) storage ref)
    {
        uint256 slot = s.policies;
        assembly ("memory-safe") { ref.slot := slot }
    }

    function _times(Bindings memory s)
        private
        pure
        returns (mapping(bytes32 => StreamTimeParameterHost.TimeParameterData) storage ref)
    {
        uint256 slot = s.times;
        assembly ("memory-safe") { ref.slot := slot }
    }
}
