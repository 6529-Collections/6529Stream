// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistReadinessHydrationFacts.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import "./StreamArtistEconomicsHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    StreamArtistRotationTypes as HydrationRotation
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import {
    StreamArtistPayoutHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import "./StreamArtistHistoryOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @notice Original current/head/record joins, separated from preparation and mutation.
library StreamArtistHydrationRecordFacts {
    function check(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source,
        bool includePayout,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory attestations
    ) public view {
        bool readiness = attestations.length != 0;
        bytes memory economicsRaw = readiness
            ? StreamArtistContentHydration.decode(data[6].typedState).economics
            : data[6].typedState;
        bytes32[] memory policyRecords = economics.length == 0
            ? abi.decode(data[6].typedState, (bytes32[]))
            : StreamArtistEconomicsHydration.decode(economicsRaw).policies;
        _facts(q, data, source, policyRecords);
        if (economics.length != 0) {
            _economicsFacts(q, data, source, economics, economicsRaw, readiness);
        }
        if (readiness) StreamArtistReadinessHydrationFacts.check(q, data, source, attestations);
        if (includePayout) _payoutFacts(q, data, source);
    }

    function _payoutFacts(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source
    ) private view {
        PH.Bundle memory p = abi.decode(data[5].typedState, (PH.Bundle));
        if (
            p.records.length
                    != IStreamArtistNativeReceipts(source.owners[5]).artistNativeReceiptCount()
                || data[5].cells.length != 1
                || data[5].origins[0].surface
                    != keccak256("payout_lifecycle.replay.designation_chain")
                || data[5].origins[0].scope != keccak256(abi.encode(q.artistId))
                || data[5].cells[0].commitment != p.current.recordHash || data[5].cells[0].kind != 3
                || data[5].cells[0].status != 1
        ) revert T.InvalidRecord();
        (
            T.Payout memory stable,
            T.Payout memory candidate,
            HydrationRotation.ProvisionalAssociation memory association
        ) = IStreamArtistPayoutTransitionOwner(source.owners[5]).payoutCandidates(q.artistId);
        if (
            keccak256(abi.encode(stable)) != keccak256(abi.encode(p.current))
                || candidate.recordHash != 0 || candidate.account != address(0)
                || association.transitionRecordHash != 0 || association.windowEndsAt != 0
        ) revert T.InvalidRecord();
        for (uint256 j; j < p.records.length; ++j) {
            bytes32 record = p.records[j].recordHash;
            if (
                record
                        != IStreamArtistNativeReceipts(source.owners[5])
                        .artistNativeReceiptAt(j)
                        .recordHash
                    || keccak256(abi.encode(p.records[j].terms))
                        != keccak256(
                            abi.encode(
                                IStreamArtistPayoutOwner(source.owners[5]).designationRecord(record)
                            )
                        )
            ) revert T.InvalidRecord();
            HydrationRotation.ProvisionalAssociation memory a =
                IStreamArtistPayoutTransitionOwner(source.owners[5])
                    .payoutDesignationProvisionalAssociation(record);
            if (a.transitionRecordHash != 0 || a.windowEndsAt != 0) revert T.UnsupportedProfile();
        }
    }

    function _facts(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source,
        bytes32[] memory records
    ) private view {
        AH.Binding memory b = abi.decode(data[0].typedState, (AH.Binding));
        AH.Identity memory identity = abi.decode(data[2].typedState, (AH.Identity));
        AH.Acceptance memory acceptance = abi.decode(data[3].typedState, (AH.Acceptance));
        if (
            b.item.artistAddress != identity.item.authorityAddress
                || b.item.identityRecordHash != identity.item.identityRecordHash
                || b.item.artistId != q.artistId || b.item.bindingHash != q.bindingHash
                || acceptance.record
                    != IStreamArtistNativeReceipts(source.owners[3])
                    .artistNativeReceiptAt(0)
                    .recordHash
        ) revert T.InvalidRecord();
        if (records.length != q.policies.length) revert T.InvalidRecord();
        uint256 receiptIndex;
        for (uint256 j; j < records.length; ++j) {
            uint256 receiptCount =
                IStreamArtistNativeReceipts(source.owners[6]).artistNativeReceiptCount();
            while (
                receiptIndex < receiptCount
                    && IStreamArtistNativeReceipts(source.owners[6])
                        .artistNativeReceiptAt(receiptIndex)
                        .operation != 14
            ) ++receiptIndex;
            if (receiptIndex == receiptCount) revert T.InvalidRecord();
            if (
                q.policies[j].phaseId == 0 || q.policies[j].policyHash == 0
                    || records[j]
                        != IStreamArtistNativeReceipts(source.owners[6])
                        .artistNativeReceiptAt(receiptIndex++)
                        .recordHash
            ) revert T.InvalidRecord();
            for (uint256 k; k < j; ++k) {
                if (
                    q.policies[k].phaseId == q.policies[j].phaseId
                        && q.policies[k].policyHash == q.policies[j].policyHash
                ) revert T.InvalidRecord();
            }
        }
    }

    function _economicsFacts(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source,
        T.EconomicsConsent[] memory terms,
        bytes memory economicsRaw,
        bool readiness
    ) private view {
        EH.Bundle memory b = StreamArtistEconomicsHydration.decode(economicsRaw);
        if (b.records.length != terms.length) revert T.InvalidRecord();
        uint256 index;
        uint256 policyCount;
        uint256 count = IStreamArtistNativeReceipts(source.owners[6]).artistNativeReceiptCount();
        for (uint256 j; j < count; ++j) {
            H.Receipt memory native_ =
                IStreamArtistNativeReceipts(source.owners[6]).artistNativeReceiptAt(j);
            if (native_.operation == 14) {
                ++policyCount;
                continue;
            }
            if (readiness && (native_.operation == 52 || native_.operation == 17)) continue;
            if (native_.operation != 15 || index >= terms.length) revert T.InvalidRecord();
            EH.Row memory r = b.records[index];
            T.EconomicsConsent memory p = terms[index++];
            if (
                keccak256(abi.encode(r.terms)) != keccak256(abi.encode(p))
                    || r.recordHash != native_.recordHash
                    || IStreamArtistConsentOwner(source.owners[6]).economicsRecord(p)
                        != r.recordHash
                    || IStreamArtistEconomicsEvidence(source.owners[6])
                            .economicsRecordForBinding(p, q.artistId, 1, q.bindingHash)
                        != r.recordHash
                    || keccak256(
                            abi.encode(
                                IStreamArtistEconomicsEvidence(source.owners[6])
                                    .economicsRecordAssociation(r.recordHash)
                            )
                        ) != keccak256(abi.encode(r.association))
            ) revert T.InvalidRecord();
            if (p.resolver != source.primaryResolver && p.resolver != source.royaltyResolver) {
                revert T.UnsupportedProfile();
            }
            bytes32 scope = keccak256(abi.encode(p));
            bool found;
            for (uint256 k; k < data[6].origins.length; ++k) {
                if (
                    data[6].origins[k].surface == keccak256("consent_finality.replay.consent_key")
                        && data[6].origins[k].scope == scope
                ) {
                    T.ReplayCell memory cell = data[6].cells[k];
                    if (cell.kind != 1 || cell.status != 2 || cell.commitment != r.recordHash) {
                        revert T.InvalidRecord();
                    }
                    found = true;
                }
            }
            if (!found) revert T.InvalidRecord();
        }
        if (index != terms.length || policyCount != q.policies.length) revert T.InvalidRecord();
    }
}
