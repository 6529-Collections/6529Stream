// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistAuthorityPreimages as Original } from "./StreamArtistAuthorityPreimages.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";

/// @notice Original request preimages captured when a retained pending request executes.
/// @dev Only the request hash uses its admission domain. The calling original writer retains
/// its authorization, mutation order, destination execution replay and destination vesting.
library StreamArtistRecoveredAuthorityPreimages {
    function rotation(Hashes.Environment memory current, R.RotationRecord memory record) public {
        Hashes.Environment memory original =
            _request(current, 29, record.terms.artistId, record.recordHash);
        Original.rotation(original.chainId, original.registry, record);
    }

    function estate(Hashes.Environment memory current, E.RequestRecord memory record) public {
        Hashes.Environment memory original =
            _request(current, 38, record.terms.artistId, record.recordHash);
        Original.estate(original.chainId, original.registry, record);
    }

    function _request(
        Hashes.Environment memory current,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) private view returns (Hashes.Environment memory) {
        if (Imported.commitment() == 0) return current;
        Runtime.Context memory clock =
            Recovered.load(address(this), current.registry, current.chainId);
        Runtime.ReceiptFact memory row = Recovered.nativeFact(clock, operation, artistId, record);
        Runtime.OriginFact memory saved =
            Runtime.auxiliary(clock, Runtime.nativeKind(operation), record);
        if (!Recovered.samePoint(row.position.point, saved.point)) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        return Recovered.hashes(row.environment);
    }
}
