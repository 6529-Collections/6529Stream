// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "../preservation/StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

import {
    StreamPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamPreservationPolicyReferencePublicationV1 as P
} from "../../interfaces/stream/preservation/IStreamPreservationPolicyReferencePublicationV1.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV1 as D
} from "../records/StreamPreservationPolicyReferenceDefinitionsV1.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains,
    StreamFinalityComponentState,
    IStreamArtworkScopedFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

import {
    StreamFinalityPreservationPolicyReferenceReadsV1 as Host
} from "./StreamFinalityPreservationPolicyReferenceReadsV1.sol";

/// @notice Fixed original-record reads and validation for preservation reference consumers.
/// @dev Library delegation preserves the caller context; targets remain constructor-pinned inputs.
library StreamFinalityPreservationPolicyReferenceOriginalV1 {
    error InvalidPolicyReferenceEvidence();
    error PolicyReferenceDependency(address source);

    function requireBindings(Host.Dependencies memory d, bytes32 family) public view {
        F.isV2(family);
        if (d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas) {
            revert InvalidPolicyReferenceEvidence();
        }
        for (uint256 i; i < 5; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert PolicyReferenceDependency(d.targets[i]);
            }
        }
        if (
            abi.decode(
                        Reads.read(
                            d.targets[4],
                            abi.encodeWithSignature(
                                "supportsInterface(bytes4)", type(P).interfaceId
                            ),
                            32,
                            d.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            d.targets[4],
                            abi.encodeCall(P.preservationPolicyReferenceProfile, ()),
                            32,
                            d.readGas
                        ),
                        (bytes32)
                    ) != F.profile(family, false)
        ) revert InvalidPolicyReferenceEvidence();
        bytes memory raw =
            Reads.read(d.targets[4], abi.encodeCall(P.dependencies, ()), 608, d.readGas);
        T.Dependencies memory source = abi.decode(raw, (T.Dependencies));
        _canonical(d.targets[4], raw, abi.encode(source));
        if (source.chainId != d.chainId) revert InvalidPolicyReferenceEvidence();
        uint256[4] memory indexes = [uint256(0), 1, 4, 5];
        // Publisher runtime is already pinned above; its first four shared roles match exactly.
        for (uint256 i; i < 4; ++i) {
            if (
                source.targets[indexes[i]] != d.targets[i]
                    || source.codeHashes[indexes[i]] != d.codeHashes[i]
            ) {
                revert PolicyReferenceDependency(d.targets[4]);
            }
        }
    }

    function original(
        Host.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision,
        bytes32 family
    ) public view returns (T.Publication memory p, T.Receipt memory receipt) {
        F.Definition memory definition = F.definition(family, false);
        requireBindings(d, family);
        bytes32 subject = _subject(d, scope);
        (p, receipt) = _readOriginal(d, hash);
        R.Receipt memory r = receipt.observation;
        R.Publication memory o = p.observation;
        if (
            hash == 0 || revision == 0 || receipt.scopeSubject != subject
                || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))
                || o.collectionId != scope.collectionId || r.collectionId != scope.collectionId
                || r.recordHash != hash || r.revision != revision || o.referenceId != r.referenceId
                || r.referenceId == 0 || o.expectedHead != r.predecessor
                || o.expectedRevision == type(uint64).max || o.expectedRevision + 1 != revision
                || o.expectedSourcesHash != r.sourcesHash || r.sourcesHash == 0
                || o.snapshotRecordHash != r.snapshotRecordHash || r.snapshotRecordHash == 0
                || o.snapshotRevision != r.snapshotRevision || r.snapshotRevision == 0
                || r.payloadHash == 0 || r.payloadBytes == 0 || r.payloadBytes > 524288
                || r.recordChainHash == 0 || r.recorder == address(0)
                || (r.authorizationClass != 3 && r.authorizationClass != 8) || r.grantRevision == 0
                || o.effectiveAt != r.effectiveAt || r.effectiveAt == 0
                || o.reasonHash != r.reasonHash || r.reasonHash == 0 || r.recordedAt == 0
                || r.effectiveAt > r.recordedAt || r.recordedAt > block.timestamp
                || r.schemaHash != definition.schemaHash || r.profileHash != definition.profileHash
                || r.canonicalizationHash != definition.canonHash
        ) revert InvalidPolicyReferenceEvidence();
        // Original producer hashes the complete receipt before assigning these two final fields.
        T.Receipt memory fields = abi.decode(abi.encode(receipt), (T.Receipt));
        fields.observation.recordHash = 0;
        fields.observation.recordChainHash = 0;
        if (
            keccak256(
                    abi.encode(
                        F.recordDomain(family, false),
                        d.chainId,
                        d.targets[4],
                        d.targets[0],
                        d.targets[1],
                        p,
                        fields
                    )
                ) != hash
        ) {
            revert InvalidPolicyReferenceEvidence();
        }
    }

    function _readOriginal(Host.Dependencies memory d, bytes32 hash)
        private
        view
        returns (T.Publication memory p, T.Receipt memory receipt)
    {
        bytes memory raw = Reads.dynamicRead(
            d.targets[4], abi.encodeCall(P.referenceRecord, (hash)), 524960, d.sourceGas
        );
        (p, receipt) = abi.decode(raw, (T.Publication, T.Receipt));
        _canonical(d.targets[4], raw, abi.encode(p, receipt));
    }

    function _subject(Host.Dependencies memory d, StreamFinalityScope memory scope)
        private
        pure
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert InvalidPolicyReferenceEvidence();
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    function _canonical(address source, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert PolicyReferenceDependency(source);
    }
}
