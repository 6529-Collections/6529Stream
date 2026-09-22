// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistUnboundPlatformCodec as UnboundCodec } from "./StreamArtistUnboundPlatformCodec.sol";
import { StreamArtistUnboundPlatformPayoutImport as UnboundImport } from "./StreamArtistUnboundPlatformPayoutImport.sol";
import { StreamArtistRecoveredMultipleGenerationPayoutImport as GenerationImport } from "./StreamArtistRecoveredMultipleGenerationPayoutImport.sol";
import { StreamArtistRecoveredMultipleGenerationCodec as GenerationAggregate } from "./StreamArtistRecoveredMultipleGenerationCodec.sol";
import { StreamArtistRecoveredMultipleAttestationCodec as AttestationAggregate } from "./StreamArtistRecoveredMultipleAttestationCodec.sol";
import { StreamArtistRecoveredMultipleAttestationPayoutImport as AttestationImport } from "./StreamArtistRecoveredMultipleAttestationPayoutImport.sol";
import { StreamArtistRecoveredMultipleConsentCodec as ConsentAggregate } from "./StreamArtistRecoveredMultipleConsentCodec.sol";
import { StreamArtistRecoveredMultipleConsentPayoutImport as ConsentImport } from "./StreamArtistRecoveredMultipleConsentPayoutImport.sol";
import { StreamArtistRecoveredMultipleCodec as Aggregate } from "./StreamArtistRecoveredMultipleCodec.sol";
import { StreamArtistRecoveredMultiplePayoutImport as MultipleImport } from "./StreamArtistRecoveredMultiplePayoutImport.sol";

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredPayoutHydration as Codec
} from "./StreamArtistRecoveredPayoutHydration.sol";
import {
    StreamArtistRecoveredPayoutImport as Import
} from "./StreamArtistRecoveredPayoutImport.sol";
import { StreamArtistPayoutRecoveryState as Recovery } from "./StreamArtistPayoutRecoveryState.sol";
import { StreamArtistNativeReceipts as Native } from "./StreamArtistNativeReceipts.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

/// @notice Fixed Payout transport. Its six roots are supplied only by the concrete owner.
library StreamArtistRecoveredPayoutTransport {
    bytes32 internal constant CONTINUATION =
        keccak256("payout_lifecycle.hydration.continuation_v3");

    function exportEncoded(bytes calldata data) public view returns (bytes memory) {
        (AH.Query memory query, RH.OwnerProvenance memory local) =
            abi.decode(data[4:], (AH.Query, RH.OwnerProvenance));
        Provenance.validateOwnerSource(local, 5, address(this));
        P.Bundle memory bundle = Codec.collectLocal(address(this), query.artistId, local);
        // Source-phase cross-owner validation remains the fixed Coordinator's responsibility.
        return abi.encode(P.SCHEMA, bundle);
    }

    function importEncoded(uint256[6] memory roots, bytes calldata data) public {
        (, AH.Query memory query, AH.OwnerData memory ownerData,) =
            abi.decode(data[4:], (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        if (UnboundCodec.selected(ownerData.typedState, 5)) {
            UnboundImport.importState(roots, query, ownerData.typedState);
            return;
        }
        if (GenerationAggregate.selected(ownerData.typedState, 5)) {
            GenerationImport.importState(roots, query, ownerData.typedState);
            return;
        }
        if (AttestationAggregate.selected(ownerData.typedState, 5)) {
            AttestationImport.importState(roots, query, ownerData.typedState);
            return;
        }
        if (ConsentAggregate.selected(ownerData.typedState, 5)) {
            ConsentImport.importState(roots, query, ownerData.typedState);
            return;
        }
        if (Aggregate.selected(ownerData.typedState, 5)) {
            MultipleImport.importState(roots, query, ownerData.typedState);
            return;
        }
        (, Payload.Payload memory payload) = Payload.decode(ownerData.typedState, 5);
        if (payload.nonces.length != 0) revert RH.InvalidRecoveredHydrationProvenance();
        P.Bundle memory bundle = Codec.decodeLocal(payload.semanticState, payload.provenance);
        Import.importState(
            _payouts(roots[0]),
            _records(roots[1]),
            _payouts(roots[2]),
            _associations(roots[3]),
            _hashes(roots[4]),
            _recovery(roots[5]),
            query.artistId,
            payload.semanticState,
            payload.provenance
        );
        bytes32 nativeKind = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_NATIVE_RECORD_V1"), uint16(18))
        );
        for (uint256 i; i < bundle.records.length; ++i) {
            Imported.installArtifact(
                nativeKind, bundle.records[i].original.recordHash, bundle.records[i].position.point
            );
        }
        for (uint256 i; i < bundle.continuations.length; ++i) {
            Imported.installArtifact(
                CONTINUATION,
                bundle.continuations[i].continuation.continuationHash,
                bundle.continuations[i].point
            );
        }
    }

    function auxiliaryPoint(
        Recovery.State storage recovery,
        bytes32 kind,
        bytes32 key,
        RH.OriginEnvironment memory current
    ) public view returns (RH.Point memory) {
        bytes32 currentOrigin = RH.originHash(current);
        uint64 revision;
        if (kind == CONTINUATION) {
            W.PayoutContinuationV3 memory c = recovery.continuations[key];
            if (key == 0 || c.continuationHash != key) revert P.InvalidRecoveredPayout(key);
            revision = c.payoutOwnerRevision;
            RH.Point memory point =
                Imported.artifactPoint(kind, key, revision, RH.Point(currentOrigin, 5, revision));
            // A raw retained revision can exceed this destination's import revision. A missing
            // imported override must not turn that old record into a local write as time passes.
            if (
                point.environmentHash == currentOrigin
                    && W.payoutContinuationHash(Runtime.rewindEnvironment(current), c) != key
            ) {
                revert P.InvalidRecoveredPayout(key);
            }
            return point;
        } else if (
            kind
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_NATIVE_RECORD_V1"), uint16(18)
                    )
                )
        ) {
            for (uint256 i; i < Native.count(); ++i) {
                if (Native.at(i).operation != 18 || Native.at(i).recordHash != key) continue;
                if (revision != 0) revert P.InvalidRecoveredPayout(key);
                revision = Native.revisionAt(i);
            }
            if (revision == 0) return Imported.artifact(kind, key);
        } else {
            revert P.InvalidRecoveredPayout(key);
        }
        return Imported.artifactPoint(kind, key, revision, RH.Point(currentOrigin, 5, revision));
    }

    function _payouts(uint256 root) private pure returns (mapping(bytes32 => T.Payout) storage s) {
        assembly ("memory-safe") { s.slot := root }
    }

    function _records(uint256 root)
        private
        pure
        returns (mapping(bytes32 => T.PayoutDesignation) storage s)
    {
        assembly ("memory-safe") { s.slot := root }
    }

    function _associations(uint256 root)
        private
        pure
        returns (mapping(bytes32 => R.ProvisionalAssociation) storage s)
    {
        assembly ("memory-safe") { s.slot := root }
    }

    function _hashes(uint256 root) private pure returns (mapping(bytes32 => bytes32) storage s) {
        assembly ("memory-safe") { s.slot := root }
    }

    function _recovery(uint256 root) private pure returns (Recovery.State storage s) {
        assembly ("memory-safe") { s.slot := root }
    }
}
