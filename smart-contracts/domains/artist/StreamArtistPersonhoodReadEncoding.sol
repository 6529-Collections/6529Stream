// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPersonhoodReads.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    IStreamArtistPersonhoodEvidence as I,
    IStreamArtistPersonhoodReadFrame as Frame,
    StreamArtistPersonhoodTypes as P
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";

/// @notice Compiler-typed outer encoding of the original six personhood views.
/// @dev The owner retains its self-only resolution guard. No proof, selection, or mutation changes.
library StreamArtistPersonhoodReadEncoding {
    function readEncoded(
        AS.State storage s,
        StreamArtistHashes.Environment memory e,
        address coordinator,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        if (
            selector == I.personhoodEvidence.selector
                || selector == I.personhoodEvidenceStatus.selector
        ) {
            (uint256 collectionId, bytes32 artist) = abi.decode(data[4:], (uint256, bytes32));
            P.Selection memory selection = StreamArtistPersonhoodReads.read(s, collectionId, artist);
            if (selector == I.personhoodEvidenceStatus.selector) {
                return abi.encode(selection.nativeRecord.recordHash, selection.status);
            }
            return abi.encode(selection);
        }
        if (selector == I.personhoodProofSummary.selector) {
            return abi.encode(StreamArtistPersonhoodSummary.get(abi.decode(data[4:], (bytes32))));
        }
        if (selector == I.personhoodProofSummaryHash.selector) {
            return abi.encode(StreamArtistPersonhoodSummary.hashOf(abi.decode(data[4:], (bytes32))));
        }
        if (selector == I.auditPersonhoodEvidence.selector) {
            (bytes32 hash, P.NotarizationFacts memory facts) =
                StreamArtistPersonhoodSummary.audit(abi.decode(data[4:], (bytes32)));
            return abi.encode(hash, facts);
        }
        if (selector == Frame.personhoodResolution.selector) {
            (
                uint256 collectionId,
                bytes32 artist,
                T.AttestationRecord memory record,
                bool checkEvidence
            ) = abi.decode(data[4:], (uint256, bytes32, T.AttestationRecord, bool));
            (bool current, P.NotarizationFacts memory facts) = StreamArtistPersonhoodReads.resolve(
                e, coordinator, collectionId, artist, record, checkEvidence
            );
            return abi.encode(current, facts);
        }
        revert T.InvalidRecord();
    }
}
