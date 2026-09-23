// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationPolicyReferenceSourceReadsV1 as Sources
} from "./StreamPreservationPolicyReferenceSourceReadsV1.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

/// @notice Fixed typed historical/current byte readers for the original collection reference host.
/// @dev The Records entry point validates definitions before requireCurrent. Storage pointers,
///      caller and host context remain in the original delegatecall context. No caller-owned
///      memory is mutated here; prepare retains its original in-memory normalization in Records.
library StreamPreservationPolicyReferenceRecordReadsV1 {
    function requireCurrent(
        Bytes.Manifest storage original,
        Bytes.Manifest storage payload,
        T.Receipt storage receipt,
        T.Dependencies memory d,
        bytes32 family
    ) public view {
        T.SourceFacts memory f = Sources.requireSource(d, publication(original), true, family);
        if (
            Sources.sourceHash(d, f, family) != receipt.observation.sourcesHash
                || Bytes.requireIntact(payload) != receipt.observation.payloadHash
        ) revert T.InvalidPolicyReference();
    }

    function recordBytes(Bytes.Manifest storage original, T.Receipt storage receipt)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(publication(original), receipt);
    }

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
            domain != F.payloadDomain(family, false)
                || keccak256(raw)
                    != keccak256(abi.encode(domain, chain, host, p, r, f, environment))
        ) revert T.InvalidPolicyReference();
        return abi.encode(f);
    }

    function publication(Bytes.Manifest storage original)
        internal
        view
        returns (T.Publication memory p)
    {
        bytes memory raw = Bytes.read(original);
        p = abi.decode(raw, (T.Publication));
        if (keccak256(raw) != keccak256(abi.encode(p))) revert T.InvalidPolicyReference();
    }
}
