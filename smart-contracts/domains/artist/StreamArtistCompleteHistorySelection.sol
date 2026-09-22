// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H,
    IStreamArtistHistory as History,
    IStreamArtistNativeReceipts as Native
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistIngressBinding as Ingress
} from "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    IStreamArtistAuthorityHydrationCoordinator as Coordinator
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Owner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistPlatformOwner as Platform
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    IStreamArtistAttributionDisputesOwner as Disputes,
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";

/// @notice Observed exceptional source histories select the separate complete-history route.
/// @dev Selection is not admission, recovery eligibility or a fallback from a failed old proof.
/// All observations come from the actual predecessor's fixed getters. Caller masks, claimed
/// current Artists and omitted collection selectors cannot create or hide a selection trigger.
library StreamArtistCompleteHistorySelection {
    struct Scan {
        uint256[] collections;
        bytes32[] principals;
        bool[] platform;
        bool[] allegation;
        uint256 count;
        uint256 principalCount;
        uint256 nativeCount;
        bool collaborators;
        bool advanced;
        bool fullDispute;
    }

    function required(T.SuiteConfiguration memory destination, RH.Request memory)
        public
        view
        returns (bool)
    {
        History history = History(destination.owners[2]);
        if (history.importedHistoryBindingCount() != 1) return false;
        (address prior,,,) = history.importedHistoryBinding(0);
        T.SuiteConfiguration memory source =
            Coordinator(Ingress(prior).operationCoordinator()).authorityHydrationSuite();
        return requiredFromSource(source);
    }

    function requiredFromSource(T.SuiteConfiguration memory source) public view returns (bool) {
        Scan memory scan;
        scan.collections = new uint256[](128);
        scan.principals = new bytes32[](128);
        scan.platform = new bool[](128);
        scan.allegation = new bool[](128);
        for (uint8 owner; owner < 7; ++owner) {
            _owner(source, owner, scan);
        }
        bool unbound;
        bool retainedPlatform;
        for (uint256 k; k < scan.count; ++k) {
            uint256 id = scan.collections[k];
            T.Binding memory head = Binding(source.owners[0]).binding(id);
            if (head.generation == 0) {
                T.Binding memory empty;
                if (keccak256(abi.encode(head)) != keccak256(abi.encode(empty))) _invalid();
                if (scan.platform[k]) unbound = true;
                if (
                    scan.allegation[k]
                        && Platform(source.owners[4]).platformWorksState(id).declaration.recordHash
                            == 0
                ) {
                    return true;
                }
                continue;
            }
            if (head.generation > 128 || head.artistId == 0 || head.bindingHash == 0) _invalid();
            if (!head.accepted) return true;
            PW.State memory emptyPlatform;
            // A supported singleton Platform history retains its existing profile. The
            // complete route composes additional collections or authentic principals.
            if (
                scan.platform[k]
                    || keccak256(abi.encode(Platform(source.owners[4]).platformWorksState(id)))
                        != keccak256(abi.encode(emptyPlatform))
            ) retainedPlatform = true;
            if (head.generation != 1 || head.consentMode != 1) scan.advanced = true;
            (uint8 attribution, uint64 generation) =
                Attribution(source.owners[4]).attributionState(id);
            if (attribution != 2 || generation != head.generation) scan.advanced = true;
            for (uint64 g = 1; g <= head.generation; ++g) {
                T.Binding memory historical = Binding(source.owners[0]).bindingAt(id, g);
                if (
                    historical.artistId == 0 || historical.bindingHash == 0
                        || historical.generation != g
                ) {
                    _invalid();
                }
                if (historical.artistId != head.artistId) return true;
                if (Terms(source.owners[0]).bindingTerms(id, g).count != 0) {
                    scan.collaborators = true;
                    scan.advanced = true;
                }
            }
        }
        return (retainedPlatform
                && (scan.count > 1 || scan.principalCount > 1 || scan.collaborators))
            || (unbound && (scan.advanced || scan.collaborators))
            || (scan.collaborators && scan.fullDispute);
    }

    function _owner(T.SuiteConfiguration memory source, uint8 owner, Scan memory scan)
        private
        view
    {
        (RH.OwnerProvenance memory prefix,, uint64 importedAt) =
            Owner(source.owners[owner]).recoveredHydrationImportedPrefix();
        if (prefix.origins.length > RH.MAX_ERAS || prefix.eras.length > RH.MAX_ERAS) _invalid();
        if (owner == 1) {
            if (
                IStreamArtistOwner(source.owners[owner]).ownerStateSnapshotV2().revision
                    > importedAt
            ) {
                scan.collaborators = true;
            }
            for (uint256 i; i < prefix.eras.length; ++i) {
                if (prefix.eras[i].checkpoint.ownerState.revision > prefix.eras[i].lowerRevision) {
                    scan.collaborators = true;
                }
            }
        }
        uint256 count = Native(source.owners[owner]).artistNativeReceiptCount();
        scan.nativeCount += prefix.journal.length + count;
        if (scan.nativeCount > RH.MAX_JOURNAL_ENTRIES) _invalid();
        for (uint256 i; i < prefix.journal.length; ++i) {
            _receipt(source, owner, prefix.journal[i].receipt, scan);
        }
        for (uint256 i; i < count; ++i) {
            _receipt(source, owner, Native(source.owners[owner]).artistNativeReceiptAt(i), scan);
        }
    }

    function _receipt(
        T.SuiteConfiguration memory source,
        uint8 owner,
        H.Receipt memory r,
        Scan memory scan
    ) private view {
        if (owner == 2 && (r.operation == 1 || r.operation == 6)) {
            if (r.artistId == 0 || r.collectionId != 0 || r.recordHash != r.artistId) {
                _invalid();
            }
            _principal(scan, r.artistId);
        }
        if (r.collectionId != 0) {
            uint256 k = _collection(scan, r.collectionId);
            if (owner == 4 && P.nativeOperation(r.operation)) scan.platform[k] = true;
            if (owner == 4 && r.operation == 10) scan.allegation[k] = true;
        }
        if (owner == 2 && (r.operation == 26 || r.operation == 27)) scan.advanced = true;
        if (owner == 6 && r.operation != 14) scan.advanced = true;
        if (owner != 4 || P.nativeOperation(r.operation)) return;
        scan.advanced = true;
        if (r.operation == 45 || r.operation == 47 || r.operation == 61) {
            scan.fullDispute = true;
        } else if (r.operation == 44) {
            // This is the existing MD selection boundary. A lone governed opening of a
            // former accepted generation remains the old narrow correction profile.
            AD.Record memory dispute =
                Disputes(source.owners[4]).attributionDisputeRecord(r.recordHash);
            (, uint64 current) = Attribution(source.owners[4]).attributionState(r.collectionId);
            if (
                dispute.authorityClass != 0 || dispute.previousRecordHash != 0
                    || dispute.terms.bindingGeneration == current
                    || !Binding(source.owners[0])
                    .bindingAt(r.collectionId, dispute.terms.bindingGeneration)
                    .accepted
            ) {
                scan.fullDispute = true;
            }
        }
    }

    function _collection(Scan memory scan, uint256 id) private pure returns (uint256 index) {
        for (uint256 i; i < scan.count; ++i) {
            if (scan.collections[i] == id) return i;
        }
        if (scan.count == scan.collections.length) _invalid();
        index = scan.count++;
        scan.collections[index] = id;
    }

    function _principal(Scan memory scan, bytes32 id) private pure {
        for (uint256 i; i < scan.principalCount; ++i) {
            if (scan.principals[i] == id) return;
        }
        if (scan.principalCount == scan.principals.length) _invalid();
        scan.principals[scan.principalCount++] = id;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
