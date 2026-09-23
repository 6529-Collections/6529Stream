// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryCodec as Codec } from "./StreamArtistCompleteHistoryCodec.sol";
import {
    StreamArtistCompleteHistoryConsentProof as Proof
} from "./StreamArtistCompleteHistoryConsentProof.sol";
import {
    StreamArtistRecoveredAggregateSanctionStorage as SanctionStorage
} from "./StreamArtistRecoveredAggregateSanctionStorage.sol";
import {
    StreamArtistRecoveredHistoryContentWrites as RatificationStorage
} from "./StreamArtistRecoveredHistoryContentWrites.sol";
import { StreamArtistSanctionState as Sanctions } from "./StreamArtistSanctionState.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Original three-map owner6 supplement hook; complete sanctions and ratifications.
/// @dev Both owner6 hooks validate the same whole canonical proof within one guarded op60.
/// This worker checks every ratification target before the sanction worker checks every
/// sanction target and starts writes. The following base/content hook remains mandatory.
library StreamArtistCompleteHistoryConsentSupplementImport {
    function applyState(
        Sanctions.State storage sanctions,
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(
            bytes32 => T.RatificationRecord
        ) storage records,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        if (!Codec.selected(outer, 6)) return false;
        Proof.Result memory r = Proof.collect(anchor, outer);
        checkRatifications(current, records, r.scope.collections, r.ratifications);
        // install performs all sanction target checks before its first write, even when
        // several authentic records update the same historical association head.
        SanctionStorage.install(sanctions, r.sanctions);
        for (uint256 k; k < r.scope.collections.length; ++k) {
            RatificationStorage.importRecords(
                current, records, r.scope.collections[k].collectionId, r.ratifications[k]
            );
        }
        return true;
    }

    function checkRatifications(
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        AH.Query[] memory collections,
        T.RatificationRecord[][] memory ratifications
    ) public view {
        if (collections.length != ratifications.length) _invalid();
        T.RatificationRecord memory empty;
        for (uint256 k; k < collections.length; ++k) {
            if (
                keccak256(abi.encode(current[collections[k].collectionId]))
                    != keccak256(abi.encode(empty))
            ) _invalid();
            for (uint256 i; i < ratifications[k].length; ++i) {
                if (
                    keccak256(abi.encode(records[ratifications[k][i].recordHash]))
                        != keccak256(abi.encode(empty))
                ) _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
