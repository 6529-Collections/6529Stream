// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityHydration.sol";
import "./StreamArtistMultipleIdentityHydration.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "./StreamArtistDelegationHydrationCodec.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @notice Original typed Identity cells only; caller/snapshot/replay/commit remain in the owner.
library StreamArtistDelegationIdentityHydration {
    function exportEncoded(
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage grants,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistUnavailabilityState.State storage findings,
        bytes calldata encoded
    ) public view returns (bytes memory) {
        return exportState(
            identity, grants, revisions, estate, dormancy, findings, abi.decode(encoded, (AH.Query))
        );
    }

    function exportState(
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage grants,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistUnavailabilityState.State storage findings,
        AH.Query memory q
    ) public view returns (bytes memory) {
        DH.Identity memory b;
        b.baseline = StreamArtistMultipleIdentityHydration.exportState(
            identity, estate, dormancy, findings, q
        );
        b.epoch = estate.delegationEpoch[q.artistId];
        if (b.epoch != 0 || revisions.pendingRecord[q.artistId] != 0) {
            revert T.UnsupportedProfile();
        }
        uint256 count = IStreamArtistNativeReceipts(address(this)).artistNativeReceiptCount();
        if (count > 128) revert T.UnsupportedProfile();
        uint256 revisionCount;
        uint256 grantCount;
        for (uint256 i; i < count; ++i) {
            H.Receipt memory r = IStreamArtistNativeReceipts(address(this)).artistNativeReceiptAt(i);
            if (r.artistId != q.artistId) continue;
            if (r.operation == 25) ++revisionCount;
            if (r.operation == 26) ++grantCount;
        }
        b.revisions = new DH.Revision[](revisionCount);
        b.grants = new DH.Grant[](grantCount);
        revisionCount = 0;
        grantCount = 0;
        bytes32 latest;
        for (uint256 i; i < count; ++i) {
            H.Receipt memory r = IStreamArtistNativeReceipts(address(this)).artistNativeReceiptAt(i);
            if (r.artistId != q.artistId) continue;
            if (r.operation == 25) {
                R.ProvisionalAssociation memory a = revisions.associations[r.recordHash];
                R.ProvisionalAssociation memory empty;
                if (keccak256(abi.encode(a)) != keccak256(abi.encode(empty))) {
                    revert T.UnsupportedProfile();
                }
                DH.Revision memory row;
                row.item = revisions.records[r.recordHash];
                row.document = identity.documents[row.item.revisedRecordHash];
                b.revisions[revisionCount++] = row;
                latest = r.recordHash;
            }
            if (r.operation == 26) {
                D.Record memory item = grants.records[r.recordHash];
                b.grants[grantCount++] = DH.Grant(
                    r.recordHash,
                    item,
                    estate.grantEpoch[r.recordHash],
                    grants.current[keccak256(abi.encode(q.artistId, item.grant.delegate))]
                );
            }
        }
        if (revisions.latestRecord[q.artistId] != latest) revert T.InvalidRecord();
        uint256 n = CP(address(this)).authorityCheckpoint().nonceIndexCount;
        if (n == 0 || n > 128) revert T.UnsupportedProfile();
        uint256 lanes;
        for (uint256 i; i < n; ++i) {
            CP.NonceIndex memory index = CP(address(this)).authorityNonceIndexAt(i);
            if (index.kind == 2 && _belongs(b.grants, q.artistId, index.key)) ++lanes;
        }
        b.delegateNonces = new DH.NonceLane[](lanes);
        lanes = 0;
        for (uint256 i; i < n; ++i) {
            CP.NonceIndex memory index = CP(address(this)).authorityNonceIndexAt(i);
            if (index.kind != 2 || !_belongs(b.grants, q.artistId, index.key)) continue;
            if (index.prefixCount == 0 || index.prefixCount > 256) revert T.UnsupportedProfile();
            DH.NonceLane memory lane;
            lane.key = index.key;
            lane.hint = grants.hints[index.key];
            lane.words = new AH.NonceWord[](index.prefixCount);
            for (uint256 j; j < index.prefixCount; ++j) {
                (lane.words[j].prefix, lane.words[j].words, lane.words[j].exhausted) =
                    CP(address(this)).authorityNonceWordAt(2, index.key, j);
            }
            b.delegateNonces[lanes++] = lane;
        }
        return abi.encode(DH.IDENTITY, b);
    }

    function _belongs(DH.Grant[] memory rows, bytes32 artistId, bytes32 key)
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < rows.length; ++i) {
            if (
                key
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                            artistId,
                            rows[i].item.grant.delegate
                        )
                    )
            ) return true;
        }
        return false;
    }

    function importEncoded(
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage grants,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistUnavailabilityState.State storage findings,
        bytes calldata encoded
    ) public {
        (, AH.Query memory q, AH.OwnerData memory data,) =
            abi.decode(encoded, (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        DH.Identity memory b = StreamArtistDelegationHydrationCodec.identity(data.typedState);
        data.typedState = b.baseline;
        StreamArtistIdentityHydration.importState(identity, estate, dormancy, findings, q, data);
        importAdditional(identity, grants, revisions, estate, q, b);
    }

    function importAdditional(
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage grants,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistEstateState.State storage estate,
        AH.Query memory q,
        DH.Identity memory b
    ) internal {
        if (
            b.epoch != 0 || estate.delegationEpoch[q.artistId] != 0
                || revisions.latestRecord[q.artistId] != 0
                || revisions.pendingRecord[q.artistId] != 0
        ) revert T.InvalidRecord();
        for (uint256 i; i < b.revisions.length; ++i) {
            DH.Revision memory row = b.revisions[i];
            if (
                revisions.records[row.item.recordHash].recordHash != 0
                    || keccak256(row.document) != row.item.revisedRecordHash
            ) revert T.InvalidRecord();
            revisions.records[row.item.recordHash] = row.item;
            revisions.latestRecord[q.artistId] = row.item.recordHash;
            if (identity.documents[row.item.revisedRecordHash].length == 0) {
                identity.documents[row.item.revisedRecordHash] = row.document;
                StreamArtistPayloadStore.store(keccak256("ARTIST_IDENTITY_DOCUMENT"), row.document);
            }
        }
        for (uint256 i; i < b.grants.length; ++i) {
            DH.Grant memory row = b.grants[i];
            if (grants.records[row.recordHash].grantor != address(0) || row.epoch != b.epoch) {
                revert T.InvalidRecord();
            }
            grants.records[row.recordHash] = row.item;
            estate.grantEpoch[row.recordHash] = row.epoch;
            bytes32 scope = keccak256(abi.encode(q.artistId, row.item.grant.delegate));
            if (grants.current[scope] != 0 && grants.current[scope] != row.current) {
                revert T.InvalidRecord();
            }
            grants.current[scope] = row.current;
        }
        for (uint256 i; i < b.delegateNonces.length; ++i) {
            DH.NonceLane memory lane = b.delegateNonces[i];
            if (grants.hints[lane.key] != 0) revert T.InvalidRecord();
            for (uint256 j; j < lane.words.length; ++j) {
                AH.NonceWord memory word = lane.words[j];
                uint256 prefix = word.prefix;
                for (uint8 level; level < 32; ++level) {
                    uint256 old = grants.availability[lane.key].full[level][prefix];
                    if (old != 0 && old != word.words[level]) revert T.InvalidRecord();
                    grants.availability[lane.key].full[level][prefix] = word.words[level];
                    prefix >>= 8;
                }
                grants.availability[lane.key].exhausted = word.exhausted;
                StreamArtistAuthorityCheckpoint.noteNonce(
                    2, lane.key, word.prefix, keccak256(abi.encode(word))
                );
            }
            (, uint256 hint) =
                StreamArtistNonceAvailability.firstUnused(grants.availability[lane.key]);
            if (hint != lane.hint) revert T.InvalidRecord();
            grants.hints[lane.key] = lane.hint;
        }
    }
}
