// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import "./StreamArtistMultipleDelegationCodec.sol";
import "./StreamArtistEconomicsHydration.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";

/// @notice New tagged imports over the original compiler-declared maps; no new authority path.
library StreamArtistMultipleRecordsConsentImport {
    function rows(bytes memory raw) private pure returns (MR.ConsentRow[] memory b) {
        bytes32 tag;
        (tag, b) = abi.decode(raw, (bytes32, MR.ConsentRow[]));
        if (tag != MR.CONSENT || b.length == 0 || b.length > 128) revert T.InvalidRecord();
        for (uint256 i; i < b.length; ++i) {
            if (
                b[i].query.collectionId == 0
                    || (i != 0 && b[i].query.collectionId <= b[i - 1].query.collectionId)
            ) revert T.InvalidRecord();
        }
    }

    function economics(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => bytes32) storage associated,
        mapping(
            bytes32 => IStreamArtistEconomicsEvidence.Association
        ) storage associations,
        bytes memory raw
    ) public returns (bytes memory delegation) {
        MR.ConsentRow[] memory b = rows(raw);
        MD.ConsentRow[] memory ds = new MD.ConsentRow[](b.length);
        for (uint256 c; c < b.length; ++c) {
            AH.Query memory q = b[c].query;
            ds[c] = MD.ConsentRow(q.collectionId, q.policies, b[c].delegation);
            if (b[c].economics.length != 0) {
                q.policies = new AH.PolicyKey[](0);
                StreamArtistEconomicsHydration.importState(
                    policies,
                    records,
                    associated,
                    associations,
                    q,
                    abi.encode(
                        StreamArtistEconomicsHydration.SCHEMA, new bytes32[](0), b[c].economics
                    )
                );
            }
        }
        return abi.encode(MD.CONSENT, ds);
    }

    function content(
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage ratifications,
        mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) storage records,
        mapping(bytes32 => bytes32) storage latest,
        bytes memory raw
    ) public {
        MR.ConsentRow[] memory b = rows(raw);
        for (uint256 c; c < b.length; ++c) {
            MR.ConsentRow memory row = b[c];
            AH.Query memory q = row.query;
            if (
                current[q.collectionId].recordHash != 0
                    || row.content.length + row.ratifications.length > 128
            ) revert T.InvalidRecord();
            for (uint256 j; j < row.ratifications.length; ++j) {
                T.RatificationRecord memory rr = row.ratifications[j];
                if (
                    rr.recordHash == 0 || rr.metadataContract == address(0)
                        || rr.contentStateHash == 0 || ratifications[rr.recordHash].recordHash != 0
                ) revert T.InvalidRecord();
                ratifications[rr.recordHash] = rr;
                current[q.collectionId] = rr;
            }
            for (uint256 j; j < row.content.length; ++j) {
                IStreamArtistContentRecordsOwner.ConsentRecord memory r = row.content[j];
                if (
                    r.recordHash == 0 || records[r.recordHash].recordHash != 0
                        || r.artistId != q.artistId || r.bindingGeneration != 1
                        || r.authorityClass != 1 || r.terms.collectionId != q.collectionId
                        || r.terms.metadataContract == address(0) || r.terms.familyId == 0
                        || r.terms.newStateHash == 0
                ) revert T.InvalidRecord();
                records[r.recordHash] = r;
                latest[keccak256(abi.encode(r.terms, uint64(1)))] = r.recordHash;
            }
        }
    }
}
