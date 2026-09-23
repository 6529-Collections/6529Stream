// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistUnavailabilityState.sol";
import "./StreamArtistNativeReceipts.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import {
    StreamArtistEntropyFindingHydrationTypes as FH
} from "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Fixed-owner typed import. Original governance admissions are immutable source facts,
/// not new governance authority; the enclosing op60 proves the complete sealed seven-owner source.
library StreamArtistEntropyFindingHydration {
    function isState(bytes memory raw) internal pure returns (bool yes) {
        if (raw.length < 32) return false;
        bytes32 tag;
        assembly ("memory-safe") { tag := mload(add(raw, 32)) }
        return tag == FH.PROFILE;
    }

    function decode(bytes memory raw) public pure returns (FH.Bundle memory b) {
        bytes32 tag;
        (tag, b) = abi.decode(raw, (bytes32, FH.Bundle));
        if (
            tag != FH.PROFILE || b.sourceRegistry == address(0) || b.records.length == 0
                || b.records.length > 128
        ) revert T.InvalidRecord();
    }

    function environment(address registry)
        public
        view
        returns (StreamArtistHashes.Environment memory)
    {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        return StreamArtistHashes.Environment(
            block.chainid, registry, owner.core(), owner.mintManager()
        );
    }

    function exportState(
        StreamArtistUnavailabilityState.State storage s,
        AH.Query memory q,
        bytes memory identityState
    ) public view returns (bytes memory) {
        // The existing profile excludes all governed timing changes; preserve that boundary.
        if (s.noticeSeconds != 0 || s.timingRevision != 0) revert T.UnsupportedProfile();
        FH.Bundle memory b;
        b.sourceRegistry = IStreamArtistOwner(address(this)).artistRegistry();
        b.identityState = identityState;
        uint256 count = StreamArtistNativeReceipts.count();
        uint256 found;
        for (uint256 j; j < count; ++j) {
            if (StreamArtistNativeReceipts.at(j).operation == 23) ++found;
        }
        if (found == 0 || found > 128) revert T.UnsupportedProfile();
        b.records = new FH.Row[](found);
        found = 0;
        StreamArtistHashes.Environment memory e = environment(b.sourceRegistry);
        for (uint256 j; j < count; ++j) {
            H.Receipt memory receipt = StreamArtistNativeReceipts.at(j);
            if (receipt.operation != 23) continue;
            if (receipt.artistId != q.artistId || receipt.collectionId != q.collectionId) {
                revert T.UnsupportedProfile();
            }
            bytes32 hash = receipt.recordHash;
            if (StreamArtistEntropyUnavailabilityStore.state().origins[hash] != address(0)) {
                revert T.UnsupportedProfile();
            }
            FH.Row memory row = FH.Row(
                s.records[hash], StreamArtistEntropyUnavailabilityStore.state().admissions[hash]
            );
            validate(e, q, row);
            if (
                row.record.recordHash != hash
                    || s.admissions[hash].target.recoveryRegistry != address(0)
            ) revert T.InvalidRecord();
            b.records[found++] = row;
        }
        b.latest =
            s.latest[StreamArtistUnavailabilityState.associationKey(q.artistId, q.collectionId)];
        b.activityEpoch = s.activityEpoch[q.artistId];
        b.hasUncancelledFindings = s.hasUncancelledFindings[q.artistId];
        validateHead(b);
        return abi.encode(FH.PROFILE, b);
    }

    function validateHead(FH.Bundle memory b) public pure {
        uint256 n = b.records.length;
        AH.Identity memory identity = abi.decode(b.identityState, (AH.Identity));
        if (
            n == 0 || b.latest != b.records[n - 1].record.recordHash
                || identity.findingActivity != b.activityEpoch
        ) revert T.InvalidRecord();
        uint256 lastEpoch = b.records[n - 1].admission.activityEpoch;
        if (
            b.activityEpoch < lastEpoch || b.activityEpoch - lastEpoch > 1
                || b.hasUncancelledFindings != (lastEpoch == b.activityEpoch)
        ) revert T.InvalidRecord();
        for (uint256 j; j < n; ++j) {
            if (b.records[j].admission.activityEpoch > b.activityEpoch) revert T.InvalidRecord();
            if (
                j != 0
                    && (b.records[j].record.recordedAt < b.records[j - 1].record.recordedAt
                        || b.records[j].admission.activityEpoch
                            < b.records[j - 1].admission.activityEpoch)
            ) revert T.InvalidRecord();
            for (uint256 k; k < j; ++k) {
                if (b.records[j].record.recordHash == b.records[k].record.recordHash) {
                    revert T.InvalidRecord();
                }
            }
        }
    }

    function validate(StreamArtistHashes.Environment memory e, AH.Query memory q, FH.Row memory row)
        public
        view
    {
        Recovery.FindingRecord memory r = row.record;
        EU.Admission memory a = row.admission;
        IStreamEntropyArtistUnavailability.Intent memory i = a.intent;
        if (
            r.recordHash == 0 || r.terms.artistId != q.artistId
                || r.terms.collectionId != q.collectionId || r.bindingHash != q.bindingHash
                || r.bindingGeneration != 1 || r.terms.reasonHash == 0 || r.governanceActionId == 0
                || r.recordedAt == 0 || r.noticeSeconds != 90 days || r.timingRevision != 1
                || uint256(r.noticeEndsAt) != uint256(r.recordedAt) + r.noticeSeconds
                || StreamArtistRecoveryHashes.findingRecord(e, r) != r.recordHash
                || a.target.coordinator == address(0) || a.coordinatorCodeHash == 0
                || a.governanceWitnessHash == 0 || a.target.unavailableEvidenceHash == 0
                || a.target.recovery.oldRequestKey == 0
                || a.target.recovery.providerEvidenceHash == 0
                || bytes(a.target.recovery.reasonURI).length == 0
                || bytes(a.target.recovery.reasonURI).length > 2048
                || i.collectionId != q.collectionId || (i.tokenId == 0) == (i.scopeId == 0)
                || i.oldRequestKey != a.target.recovery.oldRequestKey || i.newRequestKey == 0
                || i.newRequestKey == i.oldRequestKey || i.journalHead == 0
                || i.contentStateHash == 0 || i.currentContentStateHash == 0
                || i.contentStateHash == i.currentContentStateHash || i.requestPolicyHash == 0
                || i.incidentEvidenceHash == 0
                || i.providerEvidenceHash != a.target.recovery.providerEvidenceHash
                || i.reasonHash != keccak256(bytes(a.target.recovery.reasonURI))
                || a.target.intentHash != EU.intentHash(a.target.coordinator, e.core, i)
                || r.terms.evidenceHash
                    != EU.evidenceHash(e.registry, e.core, a.target, i, a.coordinatorCodeHash)
        ) revert T.InvalidRecord();
    }

    function importState(
        StreamArtistUnavailabilityState.State storage s,
        AH.Query memory q,
        FH.Bundle memory b
    ) public {
        if (
            s.noticeSeconds != 0 || s.timingRevision != 0
                || s.latest[
                        StreamArtistUnavailabilityState.associationKey(q.artistId, q.collectionId)
                    ] != 0 || s.hasUncancelledFindings[q.artistId]
        ) revert T.InvalidRecord();
        validateHead(b);
        StreamArtistHashes.Environment memory e = environment(b.sourceRegistry);
        for (uint256 j; j < b.records.length; ++j) {
            FH.Row memory row = b.records[j];
            validate(e, q, row);
            bytes32 hash = row.record.recordHash;
            if (
                s.records[hash].recordHash != 0
                    || StreamArtistEntropyUnavailabilityStore.state().admissions[hash].target
                        .coordinator != address(0)
            ) revert T.InvalidRecord();
            s.records[hash] = row.record;
            StreamArtistEntropyUnavailabilityStore.state().admissions[hash] = row.admission;
            StreamArtistEntropyUnavailabilityStore.state().origins[hash] = b.sourceRegistry;
        }
        s.latest[StreamArtistUnavailabilityState.associationKey(q.artistId, q.collectionId)] =
        b.latest;
        s.activityEpoch[q.artistId] = b.activityEpoch;
        s.hasUncancelledFindings[q.artistId] = b.hasUncancelledFindings;
    }
}
