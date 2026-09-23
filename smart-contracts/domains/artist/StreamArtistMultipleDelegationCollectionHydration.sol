// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleDelegationCodec.sol";
import "./StreamArtistDelegationCollectionHydration.sol";
import "./StreamArtistAttributionStateTypes.sol";

library StreamArtistMultipleDelegationCollectionHydration {
    function bindings(
        mapping(uint256 => T.Binding) storage current,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        bytes memory raw
    ) public {
        MD.BindingRow[] memory rows = StreamArtistMultipleDelegationCodec.bindings(raw);
        if (rows.length == 0 || rows.length > 128) revert T.InvalidRecord();
        for (uint256 i; i < rows.length; ++i) {
            MD.BindingRow memory row = rows[i];
            if (row.collectionId == 0 || (i != 0 && row.collectionId <= rows[i - 1].collectionId)) {
                revert T.InvalidRecord();
            }
            AH.Query memory q;
            q.artistId = row.state.item.artistId;
            q.collectionId = row.collectionId;
            q.bindingHash = row.state.item.bindingHash;
            StreamArtistDelegationCollectionHydration.importBinding(
                current, history, terms, q, abi.encode(DH.BINDING, row.state)
            );
        }
    }

    function acceptances(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => uint64) storage times,
        bytes memory raw
    ) public {
        MD.AcceptanceRow[] memory rows = StreamArtistMultipleDelegationCodec.acceptances(raw);
        if (rows.length == 0 || rows.length > 128) revert T.InvalidRecord();
        for (uint256 i; i < rows.length; ++i) {
            MD.AcceptanceRow memory row = rows[i];
            if (
                row.bindingHash == 0 || records[row.bindingHash] != 0 || row.state.record == 0
                    || row.state.acceptedAt == 0
            ) revert T.InvalidRecord();
            records[row.bindingHash] = row.state.record;
            times[row.bindingHash] = row.state.acceptedAt;
        }
    }

    function attributions(StreamArtistAttributionStateTypes.State storage s, bytes memory raw)
        public
    {
        MD.AttributionRow[] memory rows = StreamArtistMultipleDelegationCodec.attributions(raw);
        if (rows.length == 0 || rows.length > 128) revert T.InvalidRecord();
        for (uint256 i; i < rows.length; ++i) {
            MD.AttributionRow memory row = rows[i];
            if (
                row.collectionId == 0 || (i != 0 && row.collectionId <= rows[i - 1].collectionId)
                    || s.attributions[row.collectionId].generation != 0 || row.generation != 1
                    || row.state != 2
            ) revert T.InvalidRecord();
            s.attributions[row.collectionId] =
                StreamArtistAttributionStateTypes.Attribution(row.state, row.generation);
        }
    }

    function consents(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => Sale.Record) storage records,
        mapping(bytes32 => bytes32) storage latest,
        bytes memory raw
    ) public {
        MD.ConsentRow[] memory rows = StreamArtistMultipleDelegationCodec.consents(raw);
        if (rows.length == 0 || rows.length > 128) revert T.InvalidRecord();
        for (uint256 i; i < rows.length; ++i) {
            MD.ConsentRow memory row = rows[i];
            if (row.collectionId == 0 || (i != 0 && row.collectionId <= rows[i - 1].collectionId)) {
                revert T.InvalidRecord();
            }
            AH.Query memory q;
            q.collectionId = row.collectionId;
            q.policies = row.policies;
            StreamArtistDelegationCollectionHydration.importConsent(
                policies, delegations, records, latest, q, abi.encode(DH.CONSENT, row.state)
            );
        }
    }
}
