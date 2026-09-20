// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintPhaseState.sol";
import "./StreamMintManagerAccounting.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Original consent-gated policy refresh through a fixed linked boundary.
/// @dev Manager retains owner/reentrancy admission and the executor-set mutation.
/// Delegatecall keeps its storage, identity and event emitter; the artist cap is
/// read from the actual Manager at the original post-hash consent phase.
library StreamMintManagerPolicy {
    struct Context {
        StreamMintOperationIdentity.PolicyContext policy;
        address core;
    }

    uint16 private constant SCHEMA_VERSION = 1;
    bytes32 private constant GGP_ARTIST_AUTHORITY_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT");

    event MintPhaseConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed policyHash,
        uint8 consentMode,
        bytes32 consentEvidenceHash
    );

    function refresh(
        StreamMintPhaseState.PhaseState storage phaseState,
        IStreamMintManager.MintGateConfig storage gate,
        bytes32[] storage counterIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage counters,
        address[] storage executors,
        mapping(bytes32 => bytes32) storage policyHashes,
        Context memory x,
        uint64 graceUntil
    ) external returns (bytes32 policyHash) {
        uint256 collectionId = x.policy.collectionId;
        bytes32 phaseId = x.policy.phaseId;
        (bytes32[] memory ids, IStreamMintLedger.LedgerCounterPolicy[] memory ledgerPolicies) =
            StreamMintManagerAccounting.ledgerPolicies(counterIds, counters);
        policyHash = _computePolicyHash(phaseState, gate, counterIds, counters, executors, x);
        _recordArtistConsent(collectionId, phaseId, policyHash, x);
        policyHashes[phaseId] = policyHash;
        IStreamMintLedger(x.policy.ledger)
            .registerPhasePolicy(
                address(this), collectionId, phaseId, policyHash, ids, ledgerPolicies, graceUntil
            );
    }

    function _recordArtistConsent(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash,
        Context memory x
    ) private {
        (uint8 mode, bytes32 evidence) = StreamMintArtistConsent.registration(
            x.core,
            collectionId,
            phaseId,
            policyHash,
            IStreamGasParameterHost(address(this)).gasParameter(GGP_ARTIST_AUTHORITY_GAS_LIMIT)
        );
        emit MintPhaseConsentRecorded(
            SCHEMA_VERSION, collectionId, phaseId, policyHash, mode, evidence
        );
    }

    function _computePolicyHash(
        StreamMintPhaseState.PhaseState storage phaseState,
        IStreamMintManager.MintGateConfig storage gate,
        bytes32[] storage counterIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage counters,
        address[] storage executors,
        Context memory x
    ) private view returns (bytes32) {
        return StreamMintPhaseState.computeStoredPolicyHash(
            phaseState, gate, counterIds, counters, executors, x.policy
        );
    }
}
