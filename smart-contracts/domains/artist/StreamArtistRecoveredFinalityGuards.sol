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

/// @notice Fixed original finality guard reads; no state or authority changes.
library StreamArtistRecoveredFinalityGuards {
    uint256 private constant MAX_RECORD_BYTES = 32_768;

    function collect(IH.FindingRow memory row, RH.OriginEnvironment memory origin)
        public
        view
        returns (X.FinalityGuard memory f)
    {
        EU.Admission memory emptyEntropy;
        U.Admission memory a = row.admission;
        if (
            keccak256(abi.encode(row.entropyAdmission)) != keccak256(abi.encode(emptyEntropy))
                || row.entropyOrigin != address(0) || a.target.recoveryRegistry == address(0)
                || a.target.recoveryActionId == 0 || a.target.originalFinalityRecordHash == 0
                || a.target.recoveryManifestHash == 0 || a.recoveryIntentFactsHash == 0
                || a.governanceWitnessHash == 0
                || a.target.scope.collectionId != row.record.terms.collectionId
        ) {
            revert X.InvalidRecoveredExternalGuard(row.record.recordHash);
        }
        f.findingRecordHash = row.record.recordHash;
        f.origin = row.position;
        f.core = origin.core;
        f.target = a.target;
        f.registryCodeHash = a.recoveryRegistryCodeHash;
        _pin(f.target.recoveryRegistry, f.registryCodeHash);
        f.executor = _address(f.target.recoveryRegistry, abi.encodeCall(FB.governanceAuthority, ()));
        f.executorCodeHash = f.executor.codehash;
        return requireCurrent(f);
    }

    function requireCurrent(X.FinalityGuard memory f) public view returns (X.FinalityGuard memory) {
        address target = f.target.recoveryRegistry;
        _pin(target, f.registryCodeHash);
        if (
            _address(target, abi.encodeCall(FB.core, ())) != f.core
                || _address(target, abi.encodeCall(FB.governanceAuthority, ())) != f.executor
        ) {
            revert X.RecoveredExternalDependencyChanged(target);
        }
        _pin(f.executor, f.executorCodeHash);
        f.action = _facts(f.executor, f.target.recoveryActionId);
        if (f.action.actionClass != 2) revert X.InvalidRecoveredExternalGuard(f.findingRecordHash);
        f.actionTerminal = _terminal(f.action.status);
        bytes memory raw =
            _read(target, abi.encodeCall(F.finalityRecoveryRecord, (f.target.recoveryActionId)), 0);
        f.record = abi.decode(raw, (StreamFinalityRecoveryRecord));
        if (keccak256(raw) != keccak256(abi.encode(f.record))) {
            revert X.RecoveredExternalReadFailed(target);
        }
        if (f.record.executed) {
            if (
                f.record.recoveryId != f.target.recoveryActionId
                    || f.record.originalFinalityRecordHash != f.target.originalFinalityRecordHash
                    || f.record.recoveryManifest.contentHash != f.target.recoveryManifestHash
                    || keccak256(abi.encode(f.record.scope))
                        != keccak256(abi.encode(f.target.scope))
            ) {
                revert X.InvalidRecoveredExternalGuard(f.findingRecordHash);
            }
        } else {
            StreamFinalityRecoveryRecord memory empty;
            _same(abi.encode(f.record), abi.encode(empty), f.findingRecordHash);
        }
        return f;
    }

    function _facts(address executor, bytes32 id) private view returns (G.ActionFacts memory f) {
        if (id == 0) revert X.InvalidRecoveredExternalGuard(id);
        f = abi.decode(
            _read(executor, abi.encodeCall(G.governanceActionFacts, (id)), 160), (G.ActionFacts)
        );
        if (f.status == Status.NONE || f.callHash == 0) revert X.InvalidRecoveredExternalGuard(id);
    }

    function _terminal(Status status) private pure returns (bool) {
        return status == Status.CANCELLED || status == Status.EXECUTED || status == Status.EXPIRED
            || status == Status.VETOED;
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
