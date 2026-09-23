// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import { StreamArtistDisputeState as State } from "./StreamArtistDisputeState.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Original dispute-map emptiness and writes after complete global revocation proof.
library StreamArtistRecoveredMultipleGenerationRevocationImport {
    function check(A.AttributionBundle[] memory all) public view {
        State.Store storage d = State.store();
        AD.Head memory emptyHead;
        AD.Record memory emptyRecord;
        AD.Resolution memory emptyResolution;
        for (uint256 k; k < all.length; ++k) {
            A.AttributionBundle memory b = all[k];
            for (uint256 g; g < b.generations.length; ++g) {
                if (
                    keccak256(abi.encode(d.heads[State.key(b.collectionId, uint64(g + 1))]))
                        != keccak256(abi.encode(emptyHead))
                ) _invalid();
            }
            for (uint256 i; i < b.revocations.length; ++i) {
                A.Revocation memory r = b.revocations[i];
                bytes32 evidence = keccak256(
                    abi.encode(
                        b.collectionId,
                        r.opening.terms.bindingGeneration,
                        r.opening.terms.evidenceHash
                    )
                );
                if (
                    keccak256(abi.encode(d.records[r.opening.recordHash]))
                            != keccak256(abi.encode(emptyRecord))
                        || keccak256(abi.encode(d.resolutions[r.resolution.actionId]))
                            != keccak256(abi.encode(emptyResolution)) || d.evidenceSeen[evidence]
                ) _invalid();
            }
        }
    }

    function install(A.AttributionBundle[] memory all) public {
        State.Store storage d = State.store();
        for (uint256 k; k < all.length; ++k) {
            for (uint256 i; i < all[k].revocations.length; ++i) {
                A.Revocation memory r = all[k].revocations[i];
                d.heads[State.key(all[k].collectionId, r.opening.terms.bindingGeneration)] = r.head;
                d.records[r.opening.recordHash] = r.opening;
                d.resolutions[r.resolution.actionId] = r.resolution;
                d.evidenceSeen[
                    keccak256(
                        abi.encode(
                            all[k].collectionId,
                            r.opening.terms.bindingGeneration,
                            r.opening.terms.evidenceHash
                        )
                    )
                ] = true;
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
