// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleDelegationCodec.sol";
import "./StreamArtistDelegationIdentityHydration.sol";

library StreamArtistMultipleDelegationIdentityHydration {
    function importEncoded(
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage grants,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistUnavailabilityState.State storage findings,
        bytes calldata encoded
    ) public {
        (, AH.Query memory anchor, AH.OwnerData memory outer, bytes32 value) =
            abi.decode(encoded, (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        MD.Identities memory b = StreamArtistMultipleDelegationCodec.identity(outer.typedState);
        if (
            identity.nextRegistrationNonce != 0 || outer.nonces.length != 0 || b.rows.length == 0
                || b.rows.length > 128 || b.collectionIds.length == 0
                || b.collectionIds.length > 128 || anchor.collectionId != b.collectionIds[0]
        ) revert T.InvalidRecord();
        bytes32[] memory ids = new bytes32[](b.rows.length);
        for (uint256 i; i < b.rows.length; ++i) {
            MD.IdentityRow memory row = b.rows[i];
            ids[i] = row.artistId;
            DH.Identity memory state = StreamArtistDelegationHydrationCodec.identity(row.state);
            AH.Identity memory p = abi.decode(state.baseline, (AH.Identity));
            if (
                row.artistId == 0 || (i != 0 && row.artistId <= b.rows[i - 1].artistId)
                    || identity.identities[row.artistId].authorityAddress != address(0)
                    || identity.activeIdentity[p.item.authorityAddress] != 0
                    || p.item.authorityAddress == address(0) || p.item.authorityClass != 1
                    || p.item.status != 1 || p.nextRegistrationNonce != b.rows.length
                    || row.nonces.length == 0 || p.signatures.length != row.records.length
                    || p.document.length == 0 || keccak256(p.document) != p.item.identityRecordHash
            ) revert T.InvalidRecord();
            AH.Query memory q;
            q.artistId = row.artistId;
            q.records = row.records;
            StreamArtistMultipleIdentityHydration._import(
                identity, estate, dormancy, findings, q, p, row.nonces
            );
            StreamArtistDelegationIdentityHydration.importAdditional(
                identity, grants, revisions, estate, q, state
            );
        }
        identity.nextRegistrationNonce = b.rows.length;
        StreamArtistHistoryState.activateMultiple(ids, b.collectionIds, value);
    }
}
