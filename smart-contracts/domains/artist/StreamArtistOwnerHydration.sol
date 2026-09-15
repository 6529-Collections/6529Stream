// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistHydrationGuards } from "./StreamArtistHydrationGuards.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed decoder for the owner's original operation60 guard and state preimages.
/// @dev Delegate execution retains the actual owner address/storage. The host retains
///      its caller/snapshot check, domain-specific writes and original final commit.
library StreamArtistOwnerHydration {
    struct Binding {
        address registry;
        address coordinator;
        address archive;
        bytes32 domain;
    }

    function applyEncoded(
        mapping(bytes32 => T.ReplayCell) storage replay,
        Binding memory b,
        bytes calldata encoded
    ) public returns (bytes32 delta, bytes32 nextState) {
        (, AH.Query memory q, AH.OwnerData memory p, bytes32 value) =
            abi.decode(encoded[4:], (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        delta = StreamArtistHydrationGuards.applyGuards(
            replay, p, b.registry, b.coordinator, b.archive, b.domain, value
        );
        nextState = keccak256(abi.encode(q, p, value));
    }
}
