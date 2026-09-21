// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredPlatformOrdering as Ordering
} from "./StreamArtistRecoveredPlatformOrdering.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";

import {
    StreamArtistRecoveredPlatformNativeRows as Native
} from "./StreamArtistRecoveredPlatformNativeRows.sol";
import {
    StreamArtistRecoveredPlatformDisputeRows as Rows
} from "./StreamArtistRecoveredPlatformDisputeRows.sol";
import {
    StreamArtistRecoveredPlatformGuards as Guards
} from "./StreamArtistRecoveredPlatformGuards.sol";
import {
    StreamArtistRecoveredPlatformTimeline as PlatformTimeline
} from "./StreamArtistRecoveredPlatformTimeline.sol";
import {
    StreamArtistRecoveredPlatformBindingSource as BindingSource
} from "./StreamArtistRecoveredPlatformBindingSource.sol";
import {
    StreamArtistRecoveredDisputeHistoryChains as Chains
} from "./StreamArtistRecoveredDisputeHistoryChains.sol";
import {
    StreamArtistRecoveredSanctionTimeline as Timeline
} from "./StreamArtistRecoveredSanctionTimeline.sol";
import {
    StreamArtistRecoveredSanctionLocalProof as Local
} from "./StreamArtistRecoveredSanctionLocalProof.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import {
    StreamArtistRecoveredAttestationHydration as Attest
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredHistoryRecordAttestations as Records
} from "./StreamArtistRecoveredHistoryRecordAttestations.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHistoryRecordParts as Parts
} from "./StreamArtistRecoveredHistoryRecordParts.sol";
import {
    StreamArtistRecoveredHistoryRecordBindingProof as BindingProof
} from "./StreamArtistRecoveredHistoryRecordBindingProof.sol";
import {
    StreamArtistRecoveredHistoryRecordTimeline as RecordTimeline
} from "./StreamArtistRecoveredHistoryRecordTimeline.sol";

library StreamArtistRecoveredHistoryRecordValidation {
    function validateEncoded(bytes memory raw, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
        returns (RH.Point[] memory recordPoints)
    {
        bytes[5] memory members = Parts.members(raw);
        P.Bundle memory b;
        b.original = abi.decode(members[0], (D.Bundle));
        b.sanctions = abi.decode(members[1], (H.Inventory));
        b.platform = abi.decode(members[2], (P.Platform));
        if (
            keccak256(members[0]) != keccak256(abi.encode(b.original))
                || keccak256(members[1]) != keccak256(abi.encode(b.sanctions))
                || keccak256(members[2]) != keccak256(abi.encode(b.platform))
        ) _invalid();
        BindingProof.validate(raw, q, p);
        if (b.sanctions.sanctions.length != 0) {
            Local.validate(p, 4, q, b.sanctions);
        } else if (
            b.sanctions.catalogues.length != 0 || b.sanctions.operations.length != 0
                || b.sanctions.confirmations.length != 0
        ) {
            _invalid();
        }
        Rows.validateWithRecords(b.original, q, p, b.platform);
        D.Guard[] memory nativeGuards = Native.validateWithRecords(b.platform, p);
        Chains.validateSanctioned(b.original, p);
        RH.Point[] memory confirmations = new RH.Point[](b.sanctions.confirmations.length);
        for (uint256 i; i < confirmations.length; ++i) {
            confirmations[i] = b.sanctions.confirmations[i].attributionPoint;
        }
        Guards.validateWithRecords(b.original, p, confirmations, nativeGuards);
        Timeline.validate(H.AttributionBundle(b.original, b.sanctions), p);
        (RH.Point[] memory proposals, RH.Point[] memory completions) =
            RecordTimeline.validate(raw, p);
        recordPoints = Records.validateEncoded(raw, q, p, proposals, completions);
        // The original ordering check includes all non-record mutations. Add every op24 clock
        // as an additional native point only for its disjointness check, never as a replay cell.
        D.Guard[] memory allNative = new D.Guard[](nativeGuards.length + recordPoints.length);
        for (uint256 i; i < nativeGuards.length; ++i) {
            allNative[i] = nativeGuards[i];
        }
        for (uint256 i; i < recordPoints.length; ++i) {
            allNative[nativeGuards.length + i].point = recordPoints[i];
        }
        Ordering.distinct(b.original, confirmations, allNative, proposals, completions);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
