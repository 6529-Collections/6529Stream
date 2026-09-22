// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

/// @notice Fixed retained original publication decoder and publication/receipt tuple encoder.
library StreamScopedPreservationReferenceRecordsHistoryV1 {
    function recordBytes(Bytes.Manifest storage original, T.Receipt storage receipt)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(publication(original), receipt);
    }

    /// @dev Read and validate the entire retained publication before comparing its exact scope.
    function requireExactScope(Bytes.Manifest storage original, StreamFinalityScope memory scope)
        public
        view
    {
        T.Publication memory p = publication(original);
        if (keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))) {
            revert T.InvalidScopedPolicyReference();
        }
    }

    function publication(Bytes.Manifest storage original)
        public
        view
        returns (T.Publication memory p)
    {
        bytes memory raw = Bytes.read(original);
        p = abi.decode(raw, (T.Publication));
        if (keccak256(raw) != keccak256(abi.encode(p))) revert T.InvalidScopedPolicyReference();
    }
}
