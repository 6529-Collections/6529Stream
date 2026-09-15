// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEconomicsAssociation.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";

/// @dev Fixed typed storage bridge; original record domains and historical binding facts are retained.
library StreamArtistEconomicsHydration {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_ECONOMICS_HYDRATION_STATE_V1");

    function isState(bytes calldata raw) internal pure returns (bool) {
        return raw.length >= 32 && bytes32(raw[:32]) == SCHEMA;
    }

    function exportState(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => IStreamArtistEconomicsEvidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage delegations,
        AH.Query memory q,
        T.EconomicsConsent[] memory terms
    ) public view returns (bytes memory) {
        EH.Bundle memory b;
        b.schema = SCHEMA;
        b.policies = new bytes32[](q.policies.length);
        b.records = new EH.Row[](terms.length);
        for (uint256 j; j < b.policies.length; ++j) {
            b.policies[j] = policies[
                keccak256(
                    abi.encode(q.collectionId, q.policies[j].phaseId, q.policies[j].policyHash)
                )
            ];
            if (b.policies[j] == 0) revert T.InvalidRecord();
        }
        for (uint256 j; j < terms.length; ++j) {
            bytes32 hash = keccak256(abi.encode(terms[j]));
            bytes32 record = economics[hash];
            b.records[j] = EH.Row(record, terms[j], associations[record]);
            _shape(q, b.records[j]);
            if (
                delegations[record] != 0
                    || associated[
                            StreamArtistEconomicsAssociation.key(
                                terms[j], q.artistId, 1, q.bindingHash
                            )
                        ] != record
            ) revert T.UnsupportedProfile();
        }
        return abi.encode(b.schema, b.policies, b.records);
    }

    function decode(bytes memory raw) public pure returns (EH.Bundle memory b) {
        (b.schema, b.policies, b.records) = abi.decode(raw, (bytes32, bytes32[], EH.Row[]));
        if (b.schema != SCHEMA || b.records.length == 0 || b.records.length > 128) {
            revert T.InvalidRecord();
        }
    }

    function importState(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => IStreamArtistEconomicsEvidence.Association) storage associations,
        AH.Query memory q,
        bytes memory raw
    ) public {
        EH.Bundle memory b = decode(raw);
        if (b.policies.length != q.policies.length) revert T.InvalidRecord();
        for (uint256 j; j < b.policies.length; ++j) {
            bytes32 key = keccak256(
                abi.encode(q.collectionId, q.policies[j].phaseId, q.policies[j].policyHash)
            );
            if (policies[key] != 0 || b.policies[j] == 0) revert T.InvalidRecord();
            policies[key] = b.policies[j];
        }
        for (uint256 j; j < b.records.length; ++j) {
            EH.Row memory r = b.records[j];
            _shape(q, r);
            bytes32 key = StreamArtistEconomicsAssociation.key(
                r.terms, q.artistId, 1, q.bindingHash
            );
            if (
                economics[r.association.payloadHash] != 0 || associated[key] != 0
                    || associations[r.recordHash].originalRecord != 0
            ) revert T.InvalidRecord();
            economics[r.association.payloadHash] = r.recordHash;
            associated[key] = r.recordHash;
            associations[r.recordHash] = r.association;
        }
    }

    function _shape(AH.Query memory q, EH.Row memory r) private pure {
        T.EconomicsConsent memory p = r.terms;
        IStreamArtistEconomicsEvidence.Association memory a = r.association;
        if (
            r.recordHash == 0 || p.collectionId != q.collectionId || p.resolver == address(0)
                || p.revenueClass == 0 || p.scope > 2
                || (p.scope == 0 && (p.scopeId != 0 || p.assignmentHash == 0))
                || (p.scope == 1 && p.scopeId != q.collectionId) || (p.scope == 2 && p.scopeId == 0)
                || a.artistId != q.artistId || a.bindingGeneration != 1
                || a.bindingHash != q.bindingHash || a.payloadHash != keccak256(abi.encode(p))
                || a.originalRecord != r.recordHash
        ) revert T.InvalidRecord();
    }
}
