// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamEscrowRecoveryState as S } from "./StreamEscrowRecoveryState.sol";
import { StreamEscrowRecoveryProof as Proof } from "./StreamEscrowRecoveryProof.sol";
import {
    StreamEscrowRecoveryTypes as R
} from "../../interfaces/stream/revenue/StreamEscrowRecoveryTypes.sol";
import {
    IStreamRevenueEscrowRecoveryManifest as M
} from "../../interfaces/stream/revenue/IStreamRevenueEscrowRecoveryManifest.sol";
import {
    IStreamGovernedParameterAuthority as A
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

/// @notice Original recovery ID and distinct FUNDS_RECOVERY / TERMINAL_FREEZE authorization.
/// @dev Governance has already enforced its own delay/class/catalog; this worker additionally
///      starts the notice floors at actual retained publication and actual escrow scheduling.
library StreamEscrowRecoveryGovernance {
    uint256 private constant FUNDS_DELAY = 14 days;
    uint256 private constant TERMINAL_DELAY = 72 hours;

    struct Action {
        uint256 executing;
        bytes32 id;
        uint256 actionClass;
        bytes32 scope;
        bytes32 oldState;
        bytes32 newState;
    }
    event EscrowRecoveryScheduled(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        address wallet,
        address asset,
        address successorWallet,
        bytes32 successorProfileId,
        uint256 expectedAmount,
        bytes32 recoveryManifestContentHash,
        uint64 executeAfter,
        bytes32 reasonHash,
        string reasonURI
    );
    event EscrowRecoveryCancelled(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        bytes32 reasonHash,
        string reasonURI
    );
    event EscrowRecoveryTerminalAuthorized(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed actionId,
        bytes32 indexed manifestContentHash,
        uint64 authorizedAt
    );

    function identifier(R.EscrowRecoveryRecord memory p) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                R.RECOVERY_DOMAIN,
                block.chainid,
                address(this),
                p.creditKey.revenueClass,
                p.creditKey.profileId,
                p.creditKey.wallet,
                p.creditKey.asset,
                p.successorWallet,
                p.successorProfileId,
                p.successorRuntimeCodeHash,
                p.expectedAmount,
                p.recoveryManifest.contentHash,
                p.executeAfter,
                p.reasonHash
            )
        );
    }

    function transition(S.Context memory c, R.EscrowRecoveryRecord memory p)
        public
        view
        returns (bytes32 id, bytes32 scope, bytes32 oldState, bytes32 newState)
    {
        _reason(p.reasonHash, p.reasonURI);
        id = identifier(p);
        S.Recovery storage item = S.state().recoveries[id];
        if (item.record.status != R.EscrowRecoveryStatus.NONE) {
            revert S.InvalidEscrowRecoveryState(id);
        }
        S.Manifest storage manifest = S.state().manifests[p.recoveryManifest.contentHash];
        S.requireReference(p.recoveryManifest);
        if (manifest.publishedAt == 0) revert S.InvalidEscrowRecoveryManifest();
        M.ManifestDocument memory d = S.document(manifest);
        if (
            S.keyHash(d.creditKey) != S.keyHash(p.creditKey)
                || d.successorWallet != p.successorWallet
                || d.successorProfileId != p.successorProfileId
                || d.successorRuntimeCodeHash != p.successorRuntimeCodeHash
                || d.expectedAmount != p.expectedAmount || p.storedFactory != c.factory
                || p.status != R.EscrowRecoveryStatus.SCHEDULED
        ) revert S.InvalidEscrowRecoveryManifest();
        Proof.validate(c, d);
        uint256 earliest = uint256(manifest.publishedAt) + FUNDS_DELAY;
        if (d.route == 2) earliest += TERMINAL_DELAY;
        if (p.executeAfter < earliest) revert S.EscrowRecoveryDelayNotElapsed(earliest);
        if (d.route == 1) requireConsents(id, manifest);
        scope = keccak256(abi.encode(S.TRANSITION_DOMAIN, block.chainid, address(this), id));
        oldState = keccak256(abi.encode(scope, R.EscrowRecoveryStatus.NONE));
        newState = keccak256(abi.encode(scope, p, manifest.publishedAt));
    }

    function schedule(S.Context memory c, R.EscrowRecoveryRecord memory p)
        public
        returns (bytes32 id)
    {
        bytes32 scope;
        bytes32 oldState;
        bytes32 newState;
        (id, scope, oldState, newState) = transition(c, p);
        Action memory action = requireAction(c.authority, 4, scope, oldState, newState);
        S.Manifest storage manifest = S.state().manifests[p.recoveryManifest.contentHash];
        if (block.timestamp < uint256(manifest.publishedAt) + FUNDS_DELAY) {
            revert S.EscrowRecoveryDelayNotElapsed(uint256(manifest.publishedAt) + FUNDS_DELAY);
        }
        if (block.timestamp > type(uint64).max) revert S.InvalidEscrowRecoveryAction();
        S.Recovery storage item = S.state().recoveries[id];
        item.record = p;
        item.scheduledActionId = action.id;
        item.scheduledAt = uint64(block.timestamp);
        emit EscrowRecoveryScheduled(
            1,
            id,
            p.creditKey.revenueClass,
            p.creditKey.profileId,
            p.creditKey.wallet,
            p.creditKey.asset,
            p.successorWallet,
            p.successorProfileId,
            p.expectedAmount,
            p.recoveryManifest.contentHash,
            p.executeAfter,
            p.reasonHash,
            p.reasonURI
        );
    }

    function cancellation(bytes32 id, bytes32 reasonHash, string memory reasonURI)
        public
        view
        returns (bytes32 scope, bytes32 oldState, bytes32 newState)
    {
        _reason(reasonHash, reasonURI);
        S.Recovery storage item = S.state().recoveries[id];
        if (item.record.status != R.EscrowRecoveryStatus.SCHEDULED) {
            revert S.InvalidEscrowRecoveryState(id);
        }
        scope = keccak256(abi.encode(S.TRANSITION_DOMAIN, block.chainid, address(this), id));
        oldState = keccak256(
            abi.encode(scope, item.record, item.scheduledActionId, item.terminalActionId)
        );
        newState = keccak256(
            abi.encode(
                scope, R.EscrowRecoveryStatus.CANCELLED, reasonHash, keccak256(bytes(reasonURI))
            )
        );
    }

    function cancel(address authority, bytes32 id, bytes32 reasonHash, string memory reasonURI)
        public
    {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            cancellation(id, reasonHash, reasonURI);
        Action memory action = requireAction(authority, 0, scope, oldState, newState);
        S.Recovery storage item = S.state().recoveries[id];
        item.record.status = R.EscrowRecoveryStatus.CANCELLED;
        item.cancelledActionId = action.id;
        emit EscrowRecoveryCancelled(
            1,
            id,
            item.record.creditKey.revenueClass,
            item.record.creditKey.profileId,
            reasonHash,
            reasonURI
        );
    }

    function terminalHashes(bytes32 id)
        public
        view
        returns (bytes32 scope, bytes32 oldState, bytes32 newState)
    {
        S.Recovery storage item = S.state().recoveries[id];
        if (item.record.status != R.EscrowRecoveryStatus.SCHEDULED || item.terminalActionId != 0) {
            revert S.InvalidEscrowRecoveryState(id);
        }
        S.Manifest storage manifest = S.state().manifests[item.record.recoveryManifest.contentHash];
        if (S.document(manifest).route != 2) revert S.InvalidEscrowRecoveryManifest();
        scope =
            keccak256(abi.encode(S.TRANSITION_DOMAIN, block.chainid, address(this), id, uint8(2)));
        oldState = keccak256(
            abi.encode(scope, item.record, item.scheduledActionId, item.scheduledAt, bytes32(0))
        );
        newState = keccak256(
            abi.encode(scope, item.record.recoveryManifest.contentHash, manifest.publishedAt, true)
        );
    }

    function terminal(S.Context memory c, bytes32 id) public {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = terminalHashes(id);
        Action memory action = requireAction(c.authority, 2, scope, oldState, newState);
        S.Recovery storage item = S.state().recoveries[id];
        if (action.id == item.scheduledActionId) revert S.InvalidEscrowRecoveryAction();
        uint256 earliest = uint256(item.scheduledAt) + TERMINAL_DELAY;
        if (block.timestamp < earliest) revert S.EscrowRecoveryDelayNotElapsed(earliest);
        S.Manifest storage manifest = S.state().manifests[item.record.recoveryManifest.contentHash];
        Proof.validate(c, S.document(manifest));
        if (block.timestamp > type(uint64).max) revert S.InvalidEscrowRecoveryAction();
        item.terminalActionId = action.id;
        item.terminalAuthorizedAt = uint64(block.timestamp);
        emit EscrowRecoveryTerminalAuthorized(
            1, id, action.id, item.record.recoveryManifest.contentHash, uint64(block.timestamp)
        );
    }

    function requireExecution(S.Context memory c, bytes32 id)
        public
        view
        returns (M.ManifestDocument memory d)
    {
        S.Recovery storage item = S.state().recoveries[id];
        R.EscrowRecoveryRecord storage p = item.record;
        if (
            p.status != R.EscrowRecoveryStatus.SCHEDULED || item.scheduledActionId == 0
                || identifier(p) != id
        ) {
            revert S.InvalidEscrowRecoveryState(id);
        }
        if (block.timestamp < p.executeAfter) {
            revert S.EscrowRecoveryDelayNotElapsed(p.executeAfter);
        }
        S.Manifest storage manifest = S.state().manifests[p.recoveryManifest.contentHash];
        d = S.document(manifest);
        Proof.validate(c, d);
        if (d.route == 1) requireConsents(id, manifest);
        if (
            d.route == 2
                && (item.terminalActionId == 0
                    || item.terminalAuthorizedAt == 0
                    || item.terminalAuthorizedAt < uint256(item.scheduledAt) + TERMINAL_DELAY)
        ) revert S.InvalidEscrowRecoveryAction();
    }

    function requireConsents(bytes32 id, S.Manifest storage manifest) internal view {
        for (uint256 i; i < manifest.affectedAccounts.length; ++i) {
            address account = manifest.affectedAccounts[i];
            if (!S.state().consents[id][account]) {
                revert S.EscrowRecoveryConsentMissing(id, account);
            }
        }
    }

    function requireAction(
        address authority,
        uint8 cls,
        bytes32 scope,
        bytes32 oldState,
        bytes32 newState
    ) internal view returns (Action memory action) {
        if (msg.sender != authority || authority.codehash != S.state().origin.authorityCodeHash) {
            revert S.InvalidEscrowRecoveryAction();
        }
        action = abi.decode(
            Proof.read(authority, abi.encodeCall(A.currentAction, ()), 192, Proof.budget()),
            (Action)
        );
        if (
            action.executing != 1 || action.id == 0 || action.actionClass != cls
                || action.scope != scope || action.oldState != oldState
                || action.newState != newState
        ) {
            revert S.InvalidEscrowRecoveryAction();
        }
    }

    function _reason(bytes32 reasonHash, string memory reasonURI) private pure {
        if (reasonHash == 0 || bytes(reasonURI).length == 0 || bytes(reasonURI).length > 2048) {
            revert S.InvalidEscrowRecoveryManifest();
        }
    }
}
