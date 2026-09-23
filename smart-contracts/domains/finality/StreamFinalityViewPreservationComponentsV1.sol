// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamFinalityConservationTypes.sol";
import "../../interfaces/stream/finality/StreamFinalityDescriptionTypes.sol";

import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";

import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as Configuration
} from "./StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamFinalityViewPreservationMetadataV1 as Metadata
} from "./StreamFinalityViewPreservationMetadataV1.sol";
import {
    StreamFinalityDescriptionReads as Descriptions
} from "./StreamFinalityDescriptionReads.sol";
import {
    StreamFinalityConservationReads as Conservation
} from "./StreamFinalityConservationReads.sol";
import {
    StreamViewPreservationRenderCriticalSourceReadsV1 as Sources
} from "../preservation/StreamViewPreservationRenderCriticalSourceReadsV1.sol";
import {
    IStreamRecordSelectionLock as Locks
} from "../../interfaces/stream/metadata/IStreamRecordSelectionLock.sol";
import {
    StreamRenderCriticalSourceReads as Original
} from "../preservation/StreamRenderCriticalSourceReads.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../preservation/StreamPreservationInventoryIO.sol";

/// @notice VIEW component commitments from complete current snapshot/root, never full inputs.
/// @dev Every family binds its closed domain, full scope/profile/membership and complete source.
/// This intentionally commits more source fields than each renderer subfamily uses, not fewer.
library StreamFinalityViewPreservationComponentsV1 {
    error InvalidViewFinalityComponent();

    function facts(Native.Config memory c, StreamFinalityScope memory scope, bytes32 family)
        public
        view
        returns (bool frozen, bytes32 dataHash)
    {
        bool metadata = family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA;
        if (
            !metadata && family != StreamFinalityDomains.COMPONENT_METADATA_ROUTER
                && family != StreamFinalityDomains.COMPONENT_RENDERER
                && family != StreamFinalityDomains.COMPONENT_RENDER_CONTEXT
                && family != StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST
                && family != StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
                && family != StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE
        ) {
            revert InvalidViewFinalityComponent();
        }
        Metadata.Evidence memory e = Metadata.current(c, scope, false);
        frozen = e.snapshot.locked;
        bytes32 local;
        if (metadata) {
            Configuration.Context memory x = Configuration.resolve(c);
            StreamFinalityDescriptionEvidence memory d =
                Descriptions.requireCurrent(Sources.descriptionDependencies(x.inventory), scope);
            StreamFinalityConservationEvidence memory v =
                Conservation.requireCurrent(Sources.conservationDependencies(x.inventory), scope);
            if (
                d.scopeSubject != e.snapshot.receipt.scopeSubject
                    || v.scopeSubject != d.scopeSubject
                    || v.selected.association.artistId != e.snapshot.source.artist.artistId
            ) revert InvalidViewFinalityComponent();
            Original.requireSameArtistAssociation(
                x.inventory.artistTargets[0],
                x.inventory.artistCodeHashes[0],
                e.snapshot.source.artist,
                v.selected.association
            );
            Locks.SelectionLock memory w = _seal(
                c.targets[15],
                c,
                scope,
                d.scopeSubject,
                d.workDescriptionRecordHash,
                d.workRevision,
                d.workSelectionHash
            );
            Locks.SelectionLock memory r = _seal(
                c.targets[16],
                c,
                scope,
                d.scopeSubject,
                d.rightsStatementRecordHash,
                d.rightsRevision,
                d.rightsSelectionHash
            );
            frozen = frozen && w.locked && r.locked && v.intentLock.locked;
            local = keccak256(abi.encode(d, v, w, r));
        }
        dataHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_COMPONENT_V1"),
                family,
                c.chainId,
                c.targets[0],
                c.targets[1],
                c.targets[2],
                scope,
                Configuration.PROFILE,
                e.snapshot.inputHash,
                e.root.contentRootRecordHash,
                e.root.contentBinding,
                local
            )
        );
    }

    function _seal(
        address host,
        Native.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 subject,
        bytes32 record,
        uint64 revision,
        bytes32 selection
    ) private view returns (Locks.SelectionLock memory l) {
        bytes memory raw = IO.fixedRead(
            host, abi.encodeCall(Locks.selectionLock, (scope.collectionId, subject)), 576, c.readGas
        );
        l = abi.decode(raw, (Locks.SelectionLock));
        IO.canonical(host, raw, abi.encode(l));
        if (!l.locked) {
            Locks.SelectionLock memory empty;
            if (keccak256(raw) != keccak256(abi.encode(empty))) {
                revert InvalidViewFinalityComponent();
            }
        } else if (
            l.recordHash != record || l.revision != revision || l.selectionHash != selection
                || l.actionId == 0 || l.lockHash == 0 || l.lockedAt == 0
                || l.lockedAt > block.timestamp
        ) {
            revert InvalidViewFinalityComponent();
        }
    }
}
