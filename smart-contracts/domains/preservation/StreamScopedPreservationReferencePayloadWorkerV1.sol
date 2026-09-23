// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

/// @notice Fixed canonical retained-payload decoder for the scoped reference facade.
library StreamScopedPreservationReferencePayloadWorkerV1 {
    function source(Bytes.Manifest storage payload, bytes32 family)
        public
        view
        returns (bytes memory)
    {
        bytes memory raw = Bytes.read(payload);
        (
            bytes32 domain,
            uint256 chain,
            address host,
            T.Publication memory p,
            T.Receipt memory r,
            T.SourceFacts memory f,
            bytes memory environment
        ) = abi.decode(
            raw, (bytes32, uint256, address, T.Publication, T.Receipt, T.SourceFacts, bytes)
        );
        if (
            domain != F.payloadDomain(family, true)
                || keccak256(raw)
                    != keccak256(abi.encode(domain, chain, host, p, r, f, environment))
        ) revert T.InvalidScopedPolicyReference();
        return abi.encode(f);
    }
}
