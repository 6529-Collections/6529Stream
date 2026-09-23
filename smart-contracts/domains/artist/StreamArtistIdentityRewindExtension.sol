// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryRewindVeto } from "./StreamArtistRecoveryRewindVeto.sol";
import { StreamArtistRecoveryRewindMutation } from "./StreamArtistRecoveryRewindMutation.sol";
import {
    StreamArtistRecoveryRewindEvidenceDeployment
} from "./StreamArtistRecoveryRewindEvidenceDeployment.sol";
import {
    StreamArtistRecoveryRewindSelectionDeployment
} from "./StreamArtistRecoveryRewindSelectionDeployment.sol";

import {
    IStreamArtistRecoveryActionEvents
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    StreamArtistRecoveryActionTypes as RecoveryAction
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import { StreamArtistTimingState } from "./StreamArtistTimingState.sol";
import "./StreamArtistOwner.sol";
import {
    StreamArtistRecoveryRewindTypes as RewindTypes
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import "./StreamArtistIdentityData.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";

/// @notice Fixed V3 Identity child; original35 receipt fields and physical owner prefix stay unchanged.
contract StreamArtistIdentityRewindExtension is
    StreamArtistOwner,
    StreamArtistIdentityData,
    IStreamArtistIdentityRecoveryEvents,
    IStreamArtistRecoveryActionEvents
{
    address private immutable _host;
    address private immutable _recoveryExecutor;
    bytes32 private immutable _recoveryExecutorCodeHash;
    address private immutable _recoveryRewindSelection;
    bytes32 private immutable _recoveryRewindSelectionCodeHash;
    address private immutable _recoveryRewindEvidence;
    bytes32 private immutable _recoveryRewindEvidenceCodeHash;
    error ExtensionWrongHost(address actual);

    constructor(
        address host_,
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_,
            coordinator_,
            archive_,
            keccak256("domain:identity_authority"),
            core_,
            manager_
        )
    {
        if (host_ == address(0) || host_ == address(this)) revert T.InvalidBinding();
        _host = host_;
        address executor = StreamArtistTimingState.canonicalAuthority(core_, manager_);
        _recoveryExecutor = executor;
        _recoveryExecutorCodeHash = executor.codehash;
        address selection = StreamArtistRecoveryRewindSelectionDeployment.deploy(
            host_, registry_, coordinator_, archive_, core_, manager_
        );
        _recoveryRewindSelection = selection;
        _recoveryRewindSelectionCodeHash = selection.codehash;
        address evidence = StreamArtistRecoveryRewindEvidenceDeployment.deploy(
            host_, registry_, coordinator_, archive_, core_, manager_
        );
        _recoveryRewindEvidence = evidence;
        _recoveryRewindEvidenceCodeHash = evidence.codehash;
    }
    modifier onlyHost() {
        if (address(this) != _host) revert ExtensionWrongHost(address(this));
        _;
    }

    function recoveryExecutorBinding() external view returns (address, bytes32) {
        return (_recoveryExecutor, _recoveryExecutorCodeHash);
    }

    function recoveryRewindSelectionBinding() external view returns (address, bytes32) {
        return (_recoveryRewindSelection, _recoveryRewindSelectionCodeHash);
    }

    function recoveryRewindEvidenceBinding() external view returns (address, bytes32) {
        return (_recoveryRewindEvidence, _recoveryRewindEvidenceCodeHash);
    }

    function prepareIdentityRecoveryActionV3(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        RecoveryAction.Witness calldata witness,
        bytes32 previousAssociation,
        bool previousTerminal,
        bytes32 manifestHash,
        RewindTypes.CrossOwnerFactsV3 calldata facts
    ) external onlyHost returns (bytes32 association) {
        _check(c, RecoveryAction.PREPARE_OPERATION);
        if (
            witness.executor != _recoveryExecutor
                || witness.executorCodeHash != _recoveryExecutorCodeHash
        ) revert T.InvalidBinding();
        StreamArtistIdentityState.Mutation memory m;
        (m, association) = StreamArtistRecoveryRewindMutation.prepare(
            _identityRecovery,
            _recoveryRewinds,
            _identity,
            _rotations,
            _resolutions,
            _estate,
            _dormancy,
            _replay,
            StreamArtistIdentityRecoveryState.PrepareInput(
                _ownerContext(), c, p, a, witness, previousAssociation, previousTerminal
            ),
            manifestHash,
            facts
        );
        _commit(c, m.action, m.state, m.replay, bytes32(0));
        RecoveryAction.Association storage item = _identityRecovery.actions[witness.actionId];
        emit ArtistIdentityRecoveryPrepared(
            1,
            p.artistId,
            witness.actionId,
            association,
            item.guardian.recordHash,
            c.actor,
            item.preparedAt
        );
    }

    function vetoPreparedIdentityRecovery(
        T.ActionContext calldata c,
        bytes32 artistId,
        bytes32 actionId,
        bytes32 reasonHash,
        bool scheduled
    ) external onlyHost {
        _check(c, 34);
        bool retained = StreamArtistRecoveryRewindVeto.member(
            _identityRecovery, _recoveryRewinds, _ownerContext(), artistId, actionId, c.actor
        );
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistIdentityRecoveryState.vetoWithRetainedMembership(
                _identityRecovery,
                _replay,
                _ownerContext(),
                c,
                artistId,
                actionId,
                reasonHash,
                scheduled,
                retained
            );
        _commit(c, m.action, m.state, m.replay, bytes32(0));
        emit ArtistIdentityRecoveryVetoed(2, artistId, c.actor, reasonHash, actionId);
    }

    function recoverIdentityV3(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata governance,
        bytes32 manifestHash,
        RewindTypes.CrossOwnerFactsV3 calldata facts
    ) external onlyHost returns (bytes32 record) {
        _check(c, 35);
        bytes32 previousVesting = _rotations.latestExecution[p.artistId];
        StreamArtistIdentityState.Mutation memory m = StreamArtistRecoveryRewindMutation.recover(
            _identityRecovery,
            _recoveryRewinds,
            _identity,
            _rotations,
            _resolutions,
            _estate,
            _dormancy,
            _identityRevisions,
            _succession,
            _stewardGrants,
            _replay,
            StreamArtistIdentityRecoveryState.Input(
                _ownerContext(),
                c,
                p,
                a,
                proof,
                governance,
                IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority()
            ),
            manifestHash,
            facts
        );
        _noteGuardianVesting(
            _environment(), V.Input(p.artistId, m.record, previousVesting, _revision + 1, 35), m
        );
        IdentityRecovery.Record memory item = _identityRecovery.records[m.record];
        RecoveryReceipts.Pair memory pair = _commitIdentityRecovery(
            _identityRecovery.receipts,
            c,
            m.action,
            m.state,
            m.replay,
            item.fields,
            p.supersededRecordHashes
        );
        if (pair.primaryHash != m.record) revert T.InvalidRecord();
        record = m.record;
        emit ArtistIdentityRecovered(
            2,
            p.artistId,
            item.fields.oldAddress,
            p.newAddress,
            item.fields.vestedAuthorityClass,
            p.evidenceHash,
            p.reasonHash,
            item.fields.supersededRecordsHash,
            item.fields.recoveredAt,
            record,
            item.fields.governanceActionId,
            p.supersededRecordHashes
        );
    }

    function _ownerContext() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            StreamArtistHashes.Environment(deploymentChainId, artistRegistry, core, mintManager),
            operationCoordinator,
            archiveV2,
            domainId,
            _revision
        );
    }
}
