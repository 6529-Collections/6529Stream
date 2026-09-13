// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryActionOperations } from "./StreamArtistRecoveryActionOperations.sol";

import {
    StreamArtistIdentityRecoveryGovernance
} from "./StreamArtistIdentityRecoveryGovernance.sol";
import { StreamArtistRegistryValidatorBase } from "./StreamArtistRegistryValidatorBase.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import { IStreamArtistArchiveV2 } from "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Exact operation35 recipe in the locked, constructor-pinned Coordinator.
library StreamArtistIdentityRecoveryOperations {
    function recover(
        D.CoordinatorContext memory x,
        address actor,
        IdentityRecovery.Request memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        address identity = x.suite.owners[2];
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(identity).ownerStateSnapshotV2();
        IStreamArtistIdentityRecoveryOwner owner = IStreamArtistIdentityRecoveryOwner(identity);
        IdentityRecovery.Context memory c = owner.identityRecoveryContext(p, a);
        Contest.GovernanceWitness memory g = StreamArtistIdentityRecoveryGovernance.read(
            x,
            IStreamArtistIdentityContestOwner(identity).artistWindowAuthority(),
            actor,
            p.reasonHash,
            c
        );
        StreamArtistRecoveryActionOperations.requireExecution(identity, p.artistId, g.actionId);
        T.SignerApproval memory proof = _verify(x, actor, p, a, c.incumbent);
        record = owner.recoverIdentity(T.ActionContext(35, actor, before_[2]), p, a, proof, g);
        IdentityRecovery.Record memory item = owner.identityRecoveryRecord(record);
        if (item.recordHash != record || owner.latestIdentityRecovery(p.artistId) != record) {
            revert T.InvalidRecord();
        }
        _archive(x, actor, record, before_, abi.encode(p, a, proof, g, c, item));
    }

    function _verify(
        D.CoordinatorContext memory x,
        address actor,
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        address incumbent
    ) private view returns (T.SignerApproval memory) {
        if (a.signature.length > 4096) {
            revert T.BoundExceeded(a.signature.length, 4096);
        }
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        bytes32 digest = StreamArtistRotationHashes.acceptanceDigest(
            StreamArtistHashes.Environment(
                block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
            ),
            R.Rotation(p.artistId, incumbent, p.newAddress, p.reasonHash, bytes32(0)),
            a
        );
        bool direct = actor == p.newAddress && a.signature.length == 0;
        if (!direct) {
            (uint256 cap,, uint8 failureClass, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failureClass != 2
                    || !StreamArtistRegistryValidatorBase(x.suite.validator)
                        .validateSignerProof(p.newAddress, digest, a.signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(p.newAddress, digest, direct);
    }

    function _archive(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory before_,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_;
        after_[2] = IStreamArtistOwner(x.suite.owners[2]).ownerStateSnapshotV2();
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(35),
                actor,
                record
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(35), actor, record, before_, after_, payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
