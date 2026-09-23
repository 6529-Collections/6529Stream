// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "./StreamArtistRecoveredPayloadHydration.sol";

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistOwnerHydration as Original } from "./StreamArtistOwnerHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHydrationApplyGuards as Guards
} from "./StreamArtistRecoveredHydrationApplyGuards.sol";
import { StreamArtistRecoveredOwnerReads as Reads } from "./StreamArtistRecoveredOwnerReads.sol";

/// @notice Fixed operation60 decoder for the recovered profile's owner-local certificate.
/// @dev The host retains its original caller/snapshot check, typed domain importer and final
/// +1 commit. This worker does not invent native receipts or replace the original owner prefix.
library StreamArtistRecoveredOwnerHydration {
    function applyEncoded(
        mapping(bytes32 => T.ReplayCell) storage replay,
        Original.Binding memory binding,
        uint8 ownerIndex,
        bytes calldata encoded
    ) public returns (bytes32 delta, bytes32 nextState) {
        (T.ActionContext memory c, AH.Query memory q, AH.OwnerData memory data, bytes32 value) =
            abi.decode(encoded[4:], (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        if (
            msg.sender != binding.coordinator || c.operationId != 60 || c.actor == address(0)
                || c.expected.domainId != binding.domain
                || binding.domain != RH.ownerDomain(ownerIndex)
                || c.expected.revision == type(uint64).max || data.nonces.length != 0
        ) revert RH.InvalidRecoveredHydrationProfile();
        (RH.OwnerProvenance memory provenance, Publications.Row[] memory publications) =
            Payload.decodeForApply(data.typedState, ownerIndex);
        RH.OriginEnvironment memory destination = Reads.environment(binding, ownerIndex);
        RH.OriginEnvironment memory source = provenance.origins[provenance.origins.length - 1];
        if (
            source.chainId != destination.chainId || source.core != destination.core
                || source.manager != destination.manager || source.registry == destination.registry
                || source.coordinator == destination.coordinator
                || source.owners[ownerIndex] == address(this)
        ) revert RH.InvalidRecoveredHydrationProvenance();
        Imported.installOwnerPrefix(provenance, ownerIndex, value, c.expected.revision + 1);
        delta = Guards.applyGuards(replay, destination, ownerIndex, data, value);
        // Register originals before the typed importer stores documents or signatures, so
        // duplicate content retains the original carrier and catalog provenance.
        Publications.applyCatalog(ownerIndex, publications);
        nextState = keccak256(abi.encode(q, data, value));
    }
}
