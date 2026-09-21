// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
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
