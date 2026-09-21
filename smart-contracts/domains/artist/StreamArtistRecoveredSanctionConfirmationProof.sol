// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionEvidenceCodec as Codec
} from "./StreamArtistRecoveredSanctionEvidenceCodec.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as C
} from "../../interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import { StreamArtistOwnerCommit as Commit } from "./StreamArtistOwnerCommit.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import { StreamArtistSanctionHashes as Hashes } from "./StreamArtistSanctionHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamFinalityComponentExpectation
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityDomains
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamArtworkFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

/// @notice Original op13 payload and exact independent owner4/owner6 transition preimages.
/// @dev This validates authenticated immutable Archive bytes. It never re-runs present Finality
/// admission or uses a Consent revision as the Attribution revision of the same operation.
library StreamArtistRecoveredSanctionConfirmationProof {
    function validate(RH.OriginEnvironment memory o, RH.Era memory era, H.Envelope memory e)
        public
        pure
        returns (
            H.ConfirmationPayload memory p,
            RH.Point memory attribution,
            RH.Point memory consent
        )
    {
        p = Codec.confirmation(e.payload);
        C.Transition memory t = p.transition;
        T.Binding memory b = p.binding_;
        if (
            e.operation != 13 || e.version != 1 || e.actor == address(0) || e.value != C.scope(t)
                || t.collectionId == 0 || !b.accepted || b.artistId == 0 || b.bindingHash == 0
                || b.generation == 0 || t.artistId != b.artistId
                || t.bindingGeneration != b.generation || t.priorAttributionState != 2
                || t.sanctionRecordHash == 0 || t.finalityRecordHash == 0
                || p.sanction.recordHash != t.sanctionRecordHash
                || p.sanction.artistId != b.artistId || p.sanction.bindingHash != b.bindingHash
                || p.sanction.bindingGeneration != b.generation || p.sanction.signer == address(0)
                || (p.sanction.authorityClass != 1 && p.sanction.authorityClass != 3)
                || p.sanction.terms.scopeType != 0
                || p.sanction.terms.collectionId != t.collectionId || p.sanction.terms.tokenId != 0
                || p.sanction.terms.scopeId != 0
                || Hashes.record(
                        StreamArtistHashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        p.sanction
                    ) != t.sanctionRecordHash || p.finalityRegistry == address(0)
                || p.finalityCodeHash == 0 || p.rawReadHash == 0
        ) _invalid();
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[6],
                RH.ownerDomain(6),
                H.CONFIRMATION,
                e.value
            )
        );
        if (key != p.replayKey) _invalid();
        _finality(o, p);
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            if (i != 0 && i != 4 && i != 6) {
                if (
                    keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(e.after_[i])) != keccak256(abi.encode(zero))
                ) _invalid();
                continue;
            }
            if (
                e.before_[i].domainId != RH.ownerDomain(i)
                    || e.after_[i].domainId != RH.ownerDomain(i) || e.before_[i].stateRoot == 0
                    || e.before_[i].recordChainTip == 0
                    || e.before_[i].revision < era.lowerRevisions[i]
                    || e.after_[i].revision > era.checkpoints[i].ownerState.revision
                    || e.after_[i].recordChainTip != e.before_[i].recordChainTip
            ) _invalid();
            if (i == 0) {
                if (keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(e.after_[i]))) {
                    _invalid();
                }
            } else if (e.after_[i].revision != e.before_[i].revision + 1) {
                _invalid();
            }
        }
        bytes32 action4 = keccak256(abi.encode(b, t, p.sanction.signer, p.sanction.authorityClass));
        bytes32 state4 = keccak256(abi.encode(t.collectionId, AS.Attribution(3, b.generation)));
        if (e.after_[4].stateRoot != root(o, 4, e.before_[4], e.actor, action4, state4, 0)) {
            _invalid();
        }
        bytes32 action6 = keccak256(abi.encode(b, t));
        bytes32 state6 = keccak256(abi.encode(t, key));
        bytes32 replay6 = keccak256(abi.encode(key, t.sanctionRecordHash));
        if (e.after_[6].stateRoot != root(o, 6, e.before_[6], e.actor, action6, state6, replay6)) {
            _invalid();
        }
        attribution = RH.Point(era.originHash, 4, e.after_[4].revision);
        consent = RH.Point(era.originHash, 6, e.after_[6].revision);
    }

    function root(
        RH.OriginEnvironment memory o,
        uint8 owner,
        T.Snapshot memory before_,
        address actor,
        bytes32 action,
        bytes32 nextState,
        bytes32 replay
    ) public pure returns (bytes32) {
        Commit.Preimage memory p = Commit.Preimage(
            keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"),
            o.chainId,
            o.registry,
            o.coordinator,
            o.archive,
            o.owners[owner],
            RH.ownerDomain(owner),
            before_.revision,
            before_.revision + 1,
            before_.stateRoot,
            keccak256(abi.encode(uint16(13), actor, action)),
            nextState,
            replay,
            keccak256(abi.encode(bytes32(0)))
        );
        return keccak256(abi.encode(p));
    }

    function _finality(RH.OriginEnvironment memory o, H.ConfirmationPayload memory p) private pure {
        C.FinalityRecordEvidence memory r = p.finalityRecord;
        if (
            r.finalityRecordHash != p.transition.finalityRecordHash || r.manifestContentHash == 0
                || r.componentsHash == 0 || r.manifestPointer != p.finalityRegistry
                || r.finalizedAt == 0 || r.fullRecordHash == 0 || p.components.length == 0
                || p.components.length > 32
                || keccak256(
                        abi.encode(
                            StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, p.components
                        )
                    ) != r.componentsHash || p.executionWitness.actionId == 0
                || p.executionWitness.proposer == address(0)
                || p.executionWitness.roleMutationHash == 0 || p.executionWitness.roleRevision == 0
                || p.archiveWitness.evidenceHash == 0
                || p.archiveWitness.proof.sanctionRecordHash != p.sanction.recordHash
                || p.archiveWitness.proof.artifactHash == 0
                || p.archiveWitness.proof.completionHash == 0
        ) _invalid();
        uint256 matched;
        for (uint256 i; i < p.components.length; ++i) {
            StreamFinalityComponentExpectation memory c = p.components[i];
            if (i != 0 && !_ascending(p.components[i - 1], c)) _invalid();
            if (c.componentType != keccak256("ARTIST_SANCTION")) continue;
            if (
                c.component != o.registry
                    || c.interfaceId != type(IStreamArtworkFinalityComponent).interfaceId
                    || c.codeHash == 0 || c.dataHash != p.sanction.recordHash
            ) _invalid();
            ++matched;
        }
        if (matched != 1) _invalid();
    }

    function _ascending(
        StreamFinalityComponentExpectation memory a,
        StreamFinalityComponentExpectation memory b
    ) private pure returns (bool) {
        bytes memory left = abi.encode(a);
        bytes memory right = abi.encode(b);
        for (uint256 i; i < 224; i += 32) {
            uint256 x;
            uint256 y;
            assembly ("memory-safe") {
                x := mload(add(add(left, 32), i))
                y := mload(add(add(right, 32), i))
            }
            if (x != y) return x < y;
        }
        return false;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
