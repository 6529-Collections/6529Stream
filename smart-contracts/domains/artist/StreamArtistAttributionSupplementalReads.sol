// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeWithdrawalState.sol";
import "./StreamArtistAttestationHydration.sol";
import "./StreamArtistPublicationHydration.sol";
import "./StreamArtistPayloadStore.sol";
import "./StreamArtistRepudiationState.sol";
import {
    StreamArtistRecoveredCollectionHydration
} from "./StreamArtistRecoveredCollectionHydration.sol";
import {
    IStreamArtistRecoveredHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Exact outer ABI for ordinary supplemental views; direct STATIC facts do not use this path.
library StreamArtistAttributionSupplementalReads {
    function readEncoded(
        AS.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        if (
            selector
                == IStreamArtistRecoveredHydrationOwner.recoveredAuthorityHydrationState.selector
        ) {
            (AH.Query memory q, StreamArtistRecoveredHydrationTypes.OwnerProvenance memory p) = abi.decode(
                data[4:], (AH.Query, StreamArtistRecoveredHydrationTypes.OwnerProvenance)
            );
            return abi.encode(StreamArtistRecoveredCollectionHydration.exportAttribution(s, q, p));
        }
        if (
            selector == IStreamArtistAttributionDisputesOwner.attributionDispute.selector
                || selector
                    == IStreamArtistAttributionDisputesOwner.attributionDisputeRecord.selector
                || selector
                    == IStreamArtistAttributionDisputesOwner.attributionDisputeResolution.selector
        ) {
            return StreamArtistDisputeState.readEncoded(data);
        }
        if (
            selector == IStreamArtistRepudiationOwner.rawPendingRepudiation.selector
                || selector == IStreamArtistRepudiationOwner.attributionRepudiationRecord.selector
                || selector == IStreamArtistRepudiationOwner.attributionRepudiationTerminal.selector
                || selector == IStreamArtistRepudiationOwner.repudiationCount.selector
        ) {
            return StreamArtistRepudiationState.readEncoded(data);
        }
        if (selector == bytes4(keccak256("recordPreimageBytes(bytes32)"))) {
            return abi.encode(StreamArtistPayloadStore.recordBytes(abi.decode(data[4:], (bytes32))));
        }
        if (selector == bytes4(keccak256("storedPayloadCount()"))) {
            return abi.encode(StreamArtistPayloadStore.count());
        }
        if (selector == bytes4(keccak256("storedPayloadAt(uint256)"))) {
            (address pointer, bytes32 kind, bytes32 hash) =
                StreamArtistPayloadStore.at(abi.decode(data[4:], (uint256)));
            return abi.encode(pointer, kind, hash);
        }
        if (selector == IStreamArtistDisputeWithdrawalOwner.attributionDisputeWithdrawal.selector) {
            return abi.encode(
                StreamArtistDisputeWithdrawalState.outcome(abi.decode(data[4:], (bytes32)))
            );
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "authorityHydrationState((bytes32,uint256,bytes32,(bytes32,bytes32)[],bytes32[]))"
                    )
                )
        ) {
            AH.Query memory q = abi.decode(data[4:], (AH.Query));
            AS.Attribution memory a = s.attributions[q.collectionId];
            if (a.state != 2 || a.generation != 1) revert T.UnsupportedProfile();
            return abi.encode(abi.encode(a));
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "authorityAttestationHydrationState((bytes32,uint256,bytes32,(bytes32,bytes32)[],bytes32[]),((uint256,uint8,bytes32,bytes32,bytes32,bytes32,string),uint256)[])"
                    )
                )
        ) {
            return abi.encode(StreamArtistAttestationHydration.exportEncoded(s, e, data));
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "authorityPublicationHydrationState((bytes32,uint256,bytes32,(bytes32,bytes32)[],bytes32[]),((uint256,uint8,bytes32,bytes32,bytes32,bytes32,string),uint256)[])"
                    )
                )
        ) {
            return abi.encode(StreamArtistPublicationHydration.exportEncoded(s, e, data));
        }
        revert T.InvalidRecord();
    }
}
