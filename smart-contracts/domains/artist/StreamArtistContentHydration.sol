// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistNativeReceipts.sol";
import "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";

library StreamArtistContentHydration {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_CONTENT_HYDRATION_STATE_V1");

    function isState(bytes calldata raw) internal pure returns (bool) {
        return raw.length >= 32 && bytes32(raw[:32]) == SCHEMA;
    }

    function decode(bytes memory raw) public pure returns (RH.ConsentBundle memory b) {
        (b.schema, b.economics, b.ratifications, b.consents) = abi.decode(
            raw,
            (
                bytes32,
                bytes,
                T.RatificationRecord[],
                IStreamArtistContentRecordsOwner.ConsentRecord[]
            )
        );
        if (
            b.schema != SCHEMA || b.ratifications.length == 0
                || b.ratifications.length + b.consents.length > 128
        ) revert T.InvalidRecord();
    }

    function exportState(
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) storage content,
        mapping(bytes32 => bytes32) storage latest,
        AH.Query memory q,
        bytes memory economics
    ) public view returns (bytes memory) {
        uint256 count = StreamArtistNativeReceipts.count();
        uint256 rc;
        uint256 cc;
        for (uint256 j; j < count; ++j) {
            uint16 op = StreamArtistNativeReceipts.at(j).operation;
            if (op == 52) ++rc;
            else if (op == 17) ++cc;
        }
        if (rc == 0 || rc + cc > 128) revert T.UnsupportedProfile();
        T.RatificationRecord[] memory rr = new T.RatificationRecord[](rc);
        IStreamArtistContentRecordsOwner.ConsentRecord[] memory cr =
            new IStreamArtistContentRecordsOwner.ConsentRecord[](cc);
        rc = 0;
        cc = 0;
        for (uint256 j; j < count; ++j) {
            H.Receipt memory n = StreamArtistNativeReceipts.at(j);
            if (n.operation == 52) {
                T.RatificationRecord memory r = records[n.recordHash];
                if (
                    r.recordHash != n.recordHash || r.metadataContract == address(0)
                        || r.contentStateHash == 0
                ) revert T.InvalidRecord();
                rr[rc++] = r;
            } else if (n.operation == 17) {
                IStreamArtistContentRecordsOwner.ConsentRecord memory r = content[n.recordHash];
                _shape(q, r);
                if (r.recordHash != n.recordHash) revert T.InvalidRecord();
                cr[cc++] = r;
            }
        }
        if (keccak256(abi.encode(current[q.collectionId])) != keccak256(abi.encode(rr[rc - 1]))) {
            revert T.InvalidRecord();
        }
        for (uint256 j; j < cc; ++j) {
            bytes32 key = keccak256(abi.encode(cr[j].terms, uint64(1)));
            bool last = true;
            for (uint256 k = j + 1; k < cc; ++k) {
                if (keccak256(abi.encode(cr[k].terms, uint64(1))) == key) last = false;
            }
            if (last && latest[key] != cr[j].recordHash) revert T.InvalidRecord();
        }
        return abi.encode(SCHEMA, economics, rr, cr);
    }

    function importState(
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) storage content,
        mapping(bytes32 => bytes32) storage latest,
        AH.Query memory q,
        bytes memory raw
    ) public returns (bytes memory economics) {
        RH.ConsentBundle memory b = decode(raw);
        if (current[q.collectionId].recordHash != 0) revert T.InvalidRecord();
        for (uint256 j; j < b.ratifications.length; ++j) {
            T.RatificationRecord memory r = b.ratifications[j];
            if (
                r.recordHash == 0 || r.metadataContract == address(0) || r.contentStateHash == 0
                    || records[r.recordHash].recordHash != 0
            ) revert T.InvalidRecord();
            records[r.recordHash] = r;
            current[q.collectionId] = r;
        }
        for (uint256 j; j < b.consents.length; ++j) {
            IStreamArtistContentRecordsOwner.ConsentRecord memory r = b.consents[j];
            _shape(q, r);
            if (content[r.recordHash].recordHash != 0) revert T.InvalidRecord();
            content[r.recordHash] = r;
            latest[keccak256(abi.encode(r.terms, uint64(1)))] = r.recordHash;
        }
        return b.economics;
    }

    function _shape(AH.Query memory q, IStreamArtistContentRecordsOwner.ConsentRecord memory r)
        private
        pure
    {
        if (
            r.recordHash == 0 || r.artistId != q.artistId || r.bindingGeneration != 1
                || r.authorityClass != 1 || r.terms.collectionId != q.collectionId
                || r.terms.metadataContract == address(0) || r.terms.familyId == 0
                || r.terms.newStateHash == 0
        ) revert T.InvalidRecord();
    }
}
