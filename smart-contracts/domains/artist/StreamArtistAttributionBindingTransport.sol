// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAttributionBindingMutation.sol";

/// @notice Fixed decoding of the original binding mutation calls after owner checks.
library StreamArtistAttributionBindingTransport {
    function claimEncoded(AttrState.State storage s, bytes calldata encoded)
        public
        returns (AttrState.Mutation memory)
    {
        (
            T.ActionContext memory c,
            uint256 collectionId,
            T.Binding memory b,
            bytes32 reasonHash,
            string memory reasonURI
        ) = abi.decode(encoded[4:], (T.ActionContext, uint256, T.Binding, bytes32, string));
        return
            StreamArtistAttributionBindingMutation.claim(
                s, c, collectionId, b, reasonHash, reasonURI
            );
    }

    function terminateEncoded(
        AttrState.State storage s,
        bytes calldata encoded,
        address signer,
        uint8 authority,
        uint256 nonce,
        bytes32 recordReference
    ) public returns (AttrState.Mutation memory) {
        (T.ActionContext memory c, T.Binding memory b, L.Termination memory p) =
            abi.decode(encoded[4:], (T.ActionContext, T.Binding, L.Termination));
        return StreamArtistAttributionBindingMutation.terminate(
            s, c, b, p, signer, authority, nonce, recordReference
        );
    }

    function completeEncoded(
        AttrState.State storage s,
        bytes calldata encoded,
        address signer,
        uint8 authorityClass
    ) public returns (AttrState.Mutation memory) {
        (T.ActionContext memory c, uint256 collectionId, T.Binding memory b, bytes32 record) =
            abi.decode(encoded[4:], (T.ActionContext, uint256, T.Binding, bytes32));
        return StreamArtistAttributionBindingMutation.complete(
            s, c, collectionId, b, record, signer, authorityClass
        );
    }
}
