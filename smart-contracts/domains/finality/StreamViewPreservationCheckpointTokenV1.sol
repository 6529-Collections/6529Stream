// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationCheckpointTypesV1 as T
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import { StreamViewAdoptionReads as Read } from "../metadata/StreamViewAdoptionReads.sol";
import { StreamViewPolicySourceV2 as PolicySource } from "../metadata/StreamViewPolicySourceV2.sol";
import {
    StreamFinalityCoordinatorPolicyV2 as Rule
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Set
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import { IStreamCoreIdentity as Core } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreMint as Mint } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamViewPreservationRendererV1 as Serving
} from "../../interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Closed row observation; the host must freshly authenticate Source before this call.
/// @dev This public fixed worker is transport, never an independently trusted source endpoint.
library StreamViewPreservationCheckpointTokenV1 {
    function observe(T.Configuration memory c, T.Source memory s, uint64 index)
        public
        view
        returns (T.Output memory o, bytes memory json, bytes memory html)
    {
        if (index >= s.adoption.source.membership.tokenCount) {
            revert T.ViewCheckpointIndex(index);
        }
        uint256 cap = s.adoption.source.route.binding.readGas;
        o.index = index;
        o.tokenId = Read.word(
            s.adoption.source.route.binding.membership,
            abi.encodeCall(Membership.scopeTokenAt, (s.adoption.input.scope, index)),
            cap
        );
        bytes memory raw = Read.read(
            c.core, abi.encodeCall(Core.tokenCollectionIdentity, (o.tokenId)), 128, c.readGas
        );
        bool exists;
        uint256 cid;
        (exists, cid, o.collectionSerial, o.burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        if (
            keccak256(raw) != keccak256(abi.encode(exists, cid, o.collectionSerial, o.burned))
                || !exists || o.tokenId == 0 || cid != s.adoption.input.scope.collectionId
                || o.collectionSerial == 0
        ) {
            revert T.ViewCheckpointToken(o.tokenId);
        }
        uint256 lifecycle =
            Read.word(c.core, abi.encodeCall(Core.tokenLifecycle, (o.tokenId)), c.readGas);
        if (lifecycle != (o.burned ? 3 : 2)) revert T.ViewCheckpointToken(o.tokenId);
        o.lifecycle = uint8(lifecycle);
        o.servingKind = o.burned ? T.RETAINED_BURNED : T.CURRENT;
        address coordinator =
            Read.addr(c.core, abi.encodeCall(Core.coordinatorAtMint, (o.tokenId)), c.readGas);
        Rule memory rule;
        bool found;
        // Complete current source has authenticated this exact nonempty roster and its count.
        for (uint256 i; i < s.policy.policyCount; ++i) {
            raw = Read.read(
                s.policy.sourceSet, abi.encodeCall(Set.sourcePolicyAt, (i)), 832, c.readGas
            );
            Rule memory candidate = abi.decode(raw, (Rule));
            if (keccak256(raw) != keccak256(abi.encode(candidate))) {
                revert T.InvalidViewCheckpoint();
            }
            if (candidate.coordinator == coordinator) {
                if (found) revert T.InvalidViewCheckpoint();
                found = true;
                rule = candidate;
            }
        }
        if (!found) revert T.ViewCheckpointToken(o.tokenId);
        o.entropy = PolicySource.token(c.core, o.tokenId, cid, rule, c.readGas);
        raw = Read.bounded(
            c.core, abi.encodeCall(Mint.tokenData, (o.tokenId)), 16480, c.readGas, false
        );
        bytes memory data = abi.decode(raw, (bytes));
        if (data.length > 16384 || keccak256(raw) != keccak256(abi.encode(data))) {
            revert T.ViewCheckpointToken(o.tokenId);
        }
        o.tokenDataHash = keccak256(data);
        json = _output(c, s, o, 2);
        html = _output(c, s, o, 3);
        o.jsonHash = keccak256(json);
        o.htmlHash = keccak256(html);
        o.jsonBytes = uint32(json.length);
        o.htmlBytes = uint32(html.length);
    }

    function _output(T.Configuration memory c, T.Source memory s, T.Output memory o, uint8 mode)
        private
        view
        returns (bytes memory out)
    {
        bytes memory raw;
        if (o.burned) {
            raw = Read.bounded(
                c.serving,
                mode == 2
                    ? abi.encodeCall(
                        Serving.historicalPreservationViewJSON, (s.adoption.recordHash, o.tokenId)
                    )
                    : abi.encodeCall(
                        Serving.historicalPreservationViewHTML, (s.adoption.recordHash, o.tokenId)
                    ),
                262336,
                c.servingGas,
                false
            );
            (StreamFinalityScope memory scope, string memory value) =
                abi.decode(raw, (StreamFinalityScope, string));
            if (
                keccak256(raw) != keccak256(abi.encode(scope, value))
                    || keccak256(abi.encode(scope)) != keccak256(abi.encode(s.adoption.input.scope))
            ) {
                revert T.ViewCheckpointToken(o.tokenId);
            }
            out = bytes(value);
        } else {
            raw = Read.bounded(
                c.serving,
                mode == 2
                    ? abi.encodeCall(
                        Serving.preservationViewJSON, (s.adoption.input.scope, o.tokenId)
                    )
                    : abi.encodeCall(
                        Serving.preservationViewHTML, (s.adoption.input.scope, o.tokenId)
                    ),
                262240,
                c.servingGas,
                false
            );
            (bytes32 key, string memory value) = abi.decode(raw, (bytes32, string));
            if (keccak256(raw) != keccak256(abi.encode(key, value)) || key != s.adoption.recordHash)
            {
                revert T.ViewCheckpointToken(o.tokenId);
            }
            out = bytes(value);
        }
        if (out.length == 0 || out.length > 262144) revert T.ViewCheckpointToken(o.tokenId);
    }
}
