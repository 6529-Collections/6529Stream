// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";

import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportBase {
    function collect(
        uint256[17] memory roots,
        AH.Query memory query,
        RH.OwnerProvenance memory local
    ) public view returns (bytes[34] memory fields) {
        IH.Bundle memory b;
        Provenance.validateOwnerSource(local, 2, address(this));
        if (query.artistId == 0) revert IH.InvalidRecoveredIdentity(query.artistId);
        b.artistId = query.artistId;
        b.sourceSnapshot = IStreamArtistOwner(address(this)).ownerStateSnapshotV2();
        b.identity = X.identity(roots).identities[b.artistId];
        b.identityDocument = X.identity(roots).documents[b.identity.identityRecordHash];
        b.nextRegistrationNonce = X.identity(roots).nextRegistrationNonce;
        _heads(roots, b);
        b.signatures = new IH.SignatureRow[](query.records.length);
        for (uint256 i; i < query.records.length; ++i) {
            b.signatures[i] =
                IH.SignatureRow(query.records[i], X.identity(roots).signatures[query.records[i]]);
        }
        bytes memory empty = abi.encode(new uint256[](0));
        for (uint256 i; i < 34; ++i) {
            fields[i] = empty;
        }
        fields[0] = abi.encode(b.artistId);
        fields[1] = abi.encode(b.sourceSnapshot);
        fields[2] = abi.encode(b.nextRegistrationNonce);
        fields[3] = abi.encode(b.identity);
        fields[4] = abi.encode(b.identityDocument);
        fields[6] = abi.encode(b.heads);
        TM.Bundle memory timing;
        fields[7] = abi.encode(timing);
        fields[8] = abi.encode(b.signatures);
    }

    function _heads(uint256[17] memory r, IH.Bundle memory b) private view {
        bytes32 id = b.artistId;
        b.heads.latestTransition = X.rotations(r).latestTransition[id];
        b.heads.latestExecution = X.rotations(r).latestExecution[id];
        b.heads.pendingRotation = X.rotations(r).pending[id];
        b.heads.latestContest = X.contests(r).latest[id];
        b.heads.currentCause = X.resolutions(r).currentCause[id];
        b.heads.latestDismissal = X.resolutions(r).latestResolution[id];
        b.heads.originalRevisionContinuation = X.resolutions(r).continuationHead[id];
        b.heads.latestRecovery = X.recovery(r).latest[id];
        b.heads.pendingRecoveryAction = X.recovery(r).pendingAction[id];
        b.heads.latestVesting = X.recovery(r).vestingHistory.latest[id];
        b.heads.pendingEstate = X.estate(r).pending[id];
        b.heads.estateActivation = X.estate(r).authorityActivation[id];
        b.heads.dormancyActivation = X.dormancy(r).activation[id];
        b.heads.latestNotice = X.dormancy(r).latestNotice[id];
        b.heads.livingActivity = X.estate(r).livingActivity[id];
        b.heads.dormancyActivity = X.dormancy(r).activity[id];
        b.heads.findingActivity = X.findings(r).activityEpoch[id];
        b.heads.hasUncancelledFindings = X.findings(r).hasUncancelledFindings[id];
        b.heads.delegationEpoch = X.estate(r).delegationEpoch[id];
        b.heads.guardianRecordsSeen = X.recovery(r).guardianRecordsSeen[id];
        b.heads.guardianHistory = X.recovery(r).guardianHistory.heads[id];
        b.heads.guardianIndex = X.recovery(r).guardianSupersession.indexedHeads[id];
        b.heads.inventory =
            IStreamArtistIdentityRecoveryOwnerV3(address(this)).recoveryRewindInventoryV3(id);
        b.heads.capabilityContinuation = X.rewinds(r).capabilityHead[id];
    }
}
