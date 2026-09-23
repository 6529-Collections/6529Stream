// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistUnavailabilityTypes as U
} from "../../interfaces/stream/artist/StreamArtistUnavailabilityTypes.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";
import {
    IStreamGovernanceActionFacts as G
} from "../../interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    GovernanceActionStatus as Status
} from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    IStreamArtworkFinalityRecovery as F
} from "../../interfaces/stream/finality/IStreamArtworkFinalityRecovery.sol";
import {
    IStreamFinalityRecoveryGovernanceBinding as FB
} from "../../interfaces/stream/finality/IStreamFinalityRecoveryGovernanceBinding.sol";
import {
    StreamFinalityRecoveryRecord
} from "../../interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";
import {
    IStreamEntropyArtistUnavailability as EUHost
} from "../../interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";
import {
    IStreamEntropyFreshRecovery as EHost
} from "../../interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistRecoveryHashes as RecoveryHashes } from "./StreamArtistRecoveryHashes.sol";

import { StreamArtistRecoveredExternalGuards as X } from "./StreamArtistRecoveredExternalGuards.sol";

/// @notice Fixed original entropy guard reads; no state or authority changes.
library StreamArtistRecoveredEntropyGuards {
    uint256 private constant MAX_RECORD_BYTES = 32_768;

    function collect(IH.FindingRow memory row, RH.OriginEnvironment memory origin)
        public
        view
        returns (X.EntropyGuard memory e)
    {
        U.Admission memory emptyFinality;
        EU.Admission memory a = row.entropyAdmission;
        if (
            keccak256(abi.encode(row.admission)) != keccak256(abi.encode(emptyFinality))
                || row.entropyOrigin != origin.registry || a.target.intentHash == 0
                || a.target.unavailableEvidenceHash == 0 || a.governanceWitnessHash == 0
                || a.intent.oldRequestKey == 0 || a.intent.newRequestKey == 0
                || a.intent.oldRequestKey != a.target.recovery.oldRequestKey
                || a.intent.collectionId != row.record.terms.collectionId
                || a.target.intentHash != EU.intentHash(a.target.coordinator, origin.core, a.intent)
                || row.record.terms.evidenceHash
                    != EU.evidenceHash(
                        origin.registry, origin.core, a.target, a.intent, a.coordinatorCodeHash
                    )
        ) {
            revert X.InvalidRecoveredExternalGuard(row.record.recordHash);
        }
        e.findingRecordHash = row.record.recordHash;
        e.origin = row.position;
        e.core = origin.core;
        e.coordinator = a.target.coordinator;
        e.coordinatorCodeHash = a.coordinatorCodeHash;
        e.oldRequestKey = a.intent.oldRequestKey;
        e.newRequestKey = a.intent.newRequestKey;
        return requireCurrent(e);
    }

    function requireCurrent(X.EntropyGuard memory e) public view returns (X.EntropyGuard memory) {
        _pin(e.coordinator, e.coordinatorCodeHash);
        if (_address(e.coordinator, abi.encodeCall(FB.core, ())) != e.core) {
            revert X.RecoveredExternalDependencyChanged(e.coordinator);
        }
        e.terminal = abi.decode(
            _read(
                e.coordinator,
                abi.encodeCall(EUHost.entropyRecoveryIntentTerminal, (e.oldRequestKey)),
                32
            ),
            (bool)
        );
        e.receipt = abi.decode(
            _read(
                e.coordinator, abi.encodeCall(EHost.freshRecoveryReceipt, (e.newRequestKey)), 288
            ),
            (EHost.RecoveryReceipt)
        );
        e.evidence = abi.decode(
            _read(
                e.coordinator,
                abi.encodeCall(EUHost.entropyUnavailabilityEvidence, (e.newRequestKey)),
                96
            ),
            (X.EntropyEvidence)
        );
        // A later finding may consume the same intent. Capture the actual receipt/evidence,
        // not a fabricated boolean saying this particular old finding was unused or consumed.
        return e;
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert X.RecoveredExternalDependencyChanged(target);
        }
    }

    function _address(address target, bytes memory input) private view returns (address) {
        return abi.decode(_read(target, input, 32), (address));
    }

    function _same(bytes memory expected, bytes memory actual, bytes32 key) private pure {
        if (keccak256(expected) != keccak256(actual)) revert X.InvalidRecoveredExternalGuard(key);
    }

    function _read(address target, bytes memory input, uint256 exact)
        private
        view
        returns (bytes memory out)
    {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size == 0 || size > MAX_RECORD_BYTES || (exact != 0 && size != exact)) {
            revert X.RecoveredExternalReadFailed(target);
        }
        out = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(out, 32), 0, size) }
    }
}
