// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";

import {
    StreamArtistRecoveredIdentityExportEncoding as Encoding
} from "./StreamArtistRecoveredIdentityExportEncoding.sol";
import {
    StreamArtistRecoveredIdentityExportBase as BaseStage
} from "./StreamArtistRecoveredIdentityExportBase.sol";
import {
    StreamArtistRecoveredIdentityExportRecords as RecordsStage
} from "./StreamArtistRecoveredIdentityExportRecords.sol";
import {
    StreamArtistRecoveredIdentityExportVestings as VestingsStage
} from "./StreamArtistRecoveredIdentityExportVestings.sol";
import {
    StreamArtistRecoveredIdentityExportMembers as MembersStage
} from "./StreamArtistRecoveredIdentityExportMembers.sol";
import {
    StreamArtistRecoveredIdentityExportActions as ActionsStage
} from "./StreamArtistRecoveredIdentityExportActions.sol";
import {
    StreamArtistRecoveredIdentityExportClosures as ClosuresStage
} from "./StreamArtistRecoveredIdentityExportClosures.sol";
import {
    StreamArtistRecoveredIdentityExportStanding as StandingStage
} from "./StreamArtistRecoveredIdentityExportStanding.sol";
import {
    StreamArtistRecoveredIdentityExportDocuments as DocumentsStage
} from "./StreamArtistRecoveredIdentityExportDocuments.sol";
import {
    StreamArtistRecoveredIdentityExportNonces as NoncesStage
} from "./StreamArtistRecoveredIdentityExportNonces.sol";
import {
    StreamArtistRecoveredIdentityExportReads as ReadsStage
} from "./StreamArtistRecoveredIdentityExportReads.sol";
import {
    StreamArtistRecoveredIdentityContinuationRows as ContinuationRows
} from "./StreamArtistRecoveredIdentityContinuationRows.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportCollect {
    function collect(
        uint256[17] memory roots,
        AH.Query memory query,
        RH.OwnerProvenance memory local
    ) public view returns (bytes memory) {
        bytes[34] memory fields = BaseStage.collect(roots, query, local);
        bytes[15] memory records = RecordsStage.collect(roots, query.artistId, local);
        fields[10] = records[0];
        fields[11] = records[1];
        fields[12] = records[2];
        fields[14] = records[3];
        fields[15] = records[4];
        fields[16] = records[5];
        fields[17] = records[6];
        fields[20] = records[7];
        fields[21] = records[8];
        fields[24] = records[9];
        fields[25] = records[10];
        fields[26] = records[11];
        fields[27] = records[12];
        fields[28] = records[13];
        fields[29] = records[14];
        fields[22] = VestingsStage.collect(roots, Encoding.join(fields), local);
        fields[13] = MembersStage.collect(roots, Encoding.join(fields));
        fields[23] = ActionsStage.collect(roots, Encoding.join(fields), local);
        fields[18] = ClosuresStage.collect(roots, Encoding.join(fields));
        fields[19] = StandingStage.collect(roots, Encoding.join(fields));
        fields[5] = DocumentsStage.collect(roots, Encoding.join(fields));
        fields[9] = NoncesStage.collect(roots, Encoding.join(fields));
        fields[7] = abi.encode(Timing.collect(ReadsStage.configuration(roots)));
        bytes memory canonical = Encoding.join(fields);
        return Encoding.replaceContinuations(
            canonical, ContinuationRows.collect(roots, canonical, local)
        );
    }
}
