// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistOwner.sol";
import "./StreamArtistIdentityData.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";

/// @notice Fixed third Identity child for the typed operation35 owner commit.
contract StreamArtistIdentityRecoveryExtension is
    StreamArtistOwner,
    StreamArtistIdentityData,
    IStreamArtistIdentityRecoveryEvents
{
    address private immutable _host;
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
    }
    modifier onlyHost() {
        if (address(this) != _host) revert ExtensionWrongHost(address(this));
        _;
    }

    function recoverIdentity(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata governance
    ) external onlyHost returns (bytes32 record) {
        _check(c, 35);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityRecoveryState.recover(
            _identityRecovery,
            _identity,
            _rotations,
            _resolutions,
            _estate,
            _replay,
            StreamArtistIdentityRecoveryState.Input(
                _ownerContext(),
                c,
                p,
                a,
                proof,
                governance,
                IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority()
            )
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
