// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionEvidenceCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionEvidenceCodec.sol";
import {
    StreamArtistRecoveredSanctionConfirmationProof as Proof
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionConfirmationProof.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import {
    StreamFinalityComponentExpectation
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamArtworkFinalityComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

/// @notice Independent original flat encodings and two separate owner clocks.
/// @dev Pure synthetic proof vectors only: actual Archive/Safe/op60 acceptance is a separate suite.
contract StreamArtistRecoveredSanctionProofTest {
    function decode(bytes calldata raw) external pure returns (H.Envelope memory) {
        return Codec.envelope(raw);
    }

    function check(RH.OriginEnvironment calldata o, RH.Era calldata era, H.Envelope calldata e)
        external
        pure
    {
        Proof.validate(o, era, e);
    }

    function testOriginalFlatEnvelopeHasNoStructOffset() public pure {
        H.Envelope memory e;
        e.version = 1;
        e.configurationHash = bytes32(uint256(31));
        e.operation = 13;
        e.actor = address(0x1234);
        e.value = bytes32(uint256(32));
        e.before_[4] =
            T.Snapshot(bytes32(uint256(41)), 17, bytes32(uint256(42)), bytes32(uint256(43)));
        e.after_[6] =
            T.Snapshot(bytes32(uint256(61)), 104, bytes32(uint256(62)), bytes32(uint256(63)));
        e.payload = hex"001122334455";
        bytes memory flat = abi.encode(
            uint16(1),
            e.configurationHash,
            uint16(13),
            e.actor,
            e.value,
            e.before_,
            e.after_,
            e.payload
        );
        H.Envelope memory decoded = Codec.envelope(flat);
        require(keccak256(abi.encode(decoded)) == keccak256(abi.encode(e)), "all original fields");
        require(keccak256(flat) != keccak256(abi.encode(e)), "flat producer identity");
    }

    function testFlatEnvelopeRejectsTrailingBytesAndDirtyUint16() public {
        H.Envelope memory e;
        e.version = 1;
        e.operation = 13;
        e.payload = hex"1234";
        bytes memory flat = abi.encode(
            e.version,
            e.configurationHash,
            e.operation,
            e.actor,
            e.value,
            e.before_,
            e.after_,
            e.payload
        );
        try this.decode(bytes.concat(flat, bytes32(0))) {
            revert("trailing accepted");
        }
            catch { }
        assembly ("memory-safe") { mstore(add(flat, 32), shl(240, 1)) }
        try this.decode(flat) {
            revert("dirty uint16 accepted");
        }
            catch { }
    }

    function testConfirmationUsesIndependentOriginalAttributionAndConsentClocks() public pure {
        (RH.OriginEnvironment memory o, RH.Era memory era, H.Envelope memory e) = _fixture();
        (H.ConfirmationPayload memory p, RH.Point memory a, RH.Point memory c) =
            Proof.validate(o, era, e);
        require(a.ownerIndex == 4 && a.ownerRevision == 18, "own Attribution clock");
        require(c.ownerIndex == 6 && c.ownerRevision == 104, "own Consent clock");
        require(
            a.environmentHash == RH.originHash(o) && c.environmentHash == a.environmentHash,
            "same original operation"
        );
        require(
            p.transition.bindingGeneration == 2 && p.binding_.accepted,
            "literal accepted generation"
        );
    }

    function testActorMutationCannotReuseOriginalTransitionRoots() public {
        (RH.OriginEnvironment memory o, RH.Era memory era, H.Envelope memory e) = _fixture();
        e.actor = address(0x9876);
        _refuse(o, era, e);
    }

    function testConsentClockCannotStandInForAttributionClock() public {
        (RH.OriginEnvironment memory o, RH.Era memory era, H.Envelope memory e) = _fixture();
        e.after_[4].revision = e.after_[6].revision;
        era.checkpoints[4].ownerState.revision = e.after_[6].revision;
        _refuse(o, era, e);
    }

    function testZeroRecordConfirmationMustPreserveBothRecordTips() public {
        (RH.OriginEnvironment memory o, RH.Era memory era, H.Envelope memory e) = _fixture();
        e.after_[4].recordChainTip = bytes32(uint256(0xbad));
        _refuse(o, era, e);
        (o, era, e) = _fixture();
        e.after_[6].recordChainTip = bytes32(uint256(0xbad));
        _refuse(o, era, e);
    }

    function testWrongSanctionComponentAndReplayCannotHideBehindValidSnapshots() public {
        (RH.OriginEnvironment memory o, RH.Era memory era, H.Envelope memory e) = _fixture();
        H.ConfirmationPayload memory p = Codec.confirmation(e.payload);
        p.components[0].dataHash = bytes32(uint256(0xbad));
        p.finalityRecord.componentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), p.components));
        e.payload = _payload(p);
        _refuse(o, era, e);
        (o, era, e) = _fixture();
        p = Codec.confirmation(e.payload);
        p.replayKey = bytes32(uint256(0xbad));
        e.payload = _payload(p);
        _refuse(o, era, e);
    }

    function testFuzzOriginalFourteenWordRoot(
        bytes32 action,
        bytes32 state,
        bytes32 replay,
        address actor
    ) public pure {
        (RH.OriginEnvironment memory o,, H.Envelope memory e) = _fixture();
        require(
            Proof.root(o, 4, e.before_[4], actor, action, state, replay)
                == _root(o, 4, e.before_[4], actor, action, state, replay),
            "literal14 root"
        );
        require(
            Proof.root(o, 6, e.before_[6], actor, action, state, replay)
                == _root(o, 6, e.before_[6], actor, action, state, replay),
            "literal14 other owner"
        );
    }

    function _refuse(RH.OriginEnvironment memory o, RH.Era memory era, H.Envelope memory e)
        private
    {
        try this.check(o, era, e) {
            revert("invalid original proof accepted");
        }
            catch { }
    }

    function _fixture()
        private
        pure
        returns (RH.OriginEnvironment memory o, RH.Era memory era, H.Envelope memory e)
    {
        o.chainId = 31337;
        o.registry = address(0x1001);
        o.coordinator = address(0x1002);
        o.archive = address(0x1003);
        o.core = address(0x1004);
        o.manager = address(0x1005);
        for (uint8 i; i < 7; ++i) {
            o.owners[i] = address(uint160(0x2000 + i));
            o.ownerCodeHashes[i] = bytes32(uint256(i + 1));
        }
        o.suiteConfigurationHash = bytes32(uint256(0x3010));
        era.originHash = RH.originHash(o);
        H.ConfirmationPayload memory p;
        p.binding_.artistId = bytes32(uint256(0x4010));
        p.binding_.artistAddress = address(0x4011);
        p.binding_.bindingHash = bytes32(uint256(0x4012));
        p.binding_.generation = 2;
        p.binding_.consentMode = 1;
        p.binding_.accepted = true;
        p.sanction.artistId = p.binding_.artistId;
        p.sanction.signer = address(0x4011);
        p.sanction.authorityClass = 1;
        p.sanction.terms.collectionId = 7;
        p.sanction.terms.sanctionSubjectHash = bytes32(uint256(0x5010));
        p.sanction.terms.statementHash = bytes32(uint256(0x5011));
        p.sanction.nonce = 13;
        p.sanction.signedAt = 500;
        p.sanction.deadline = 900;
        p.sanction.bindingGeneration = 2;
        p.sanction.bindingHash = p.binding_.bindingHash;
        p.sanction.recordHash = _record(o, p.sanction);
        p.transition = C.Transition(
            7, p.binding_.artistId, 2, p.sanction.recordHash, bytes32(uint256(0x6001)), 2
        );
        p.finalityRegistry = address(0x6002);
        p.finalityCodeHash = bytes32(uint256(0x6003));
        p.finalityRecord = C.FinalityRecordEvidence(
            p.transition.finalityRecordHash,
            bytes32(uint256(0x6004)),
            bytes32(uint256(0x6005)),
            bytes32(0),
            p.finalityRegistry,
            501,
            bytes32(uint256(0x6006))
        );
        p.components = new StreamFinalityComponentExpectation[](1);
        p.components[0] = StreamFinalityComponentExpectation(
            keccak256("ARTIST_SANCTION"),
            o.registry,
            type(IStreamArtworkFinalityComponent).interfaceId,
            bytes32(uint256(0x7001)),
            bytes32(uint256(0x7002)),
            bytes32(uint256(0x7003)),
            p.sanction.recordHash
        );
        p.finalityRecord.componentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), p.components));
        p.executionWitness.actionId = bytes32(uint256(0x8001));
        p.executionWitness.proposer = address(0x8002);
        p.executionWitness.roleMutationHash = bytes32(uint256(0x8003));
        p.executionWitness.roleRevision = 1;
        p.archiveWitness.evidenceHash = bytes32(uint256(0x9001));
        p.archiveWitness.proof.sanctionRecordHash = p.sanction.recordHash;
        p.archiveWitness.proof.artifactHash = bytes32(uint256(0x9002));
        p.archiveWitness.proof.completionHash = bytes32(uint256(0x9003));
        p.rawReadHash = bytes32(uint256(0xa001));
        e.version = 1;
        e.configurationHash = bytes32(uint256(0xa002));
        e.operation = 13;
        e.actor = address(0xa003);
        e.value = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_SANCTION_FINALIZATION_TRANSITION_V1"), p.transition
            )
        );
        p.replayKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[6],
                keccak256("domain:consent_finality"),
                keccak256("consent_finality.replay.sanction_finalization_transition_key"),
                e.value
            )
        );
        e.before_[0] = T.Snapshot(
            keccak256("domain:binding_lifecycle"), 7, bytes32(uint256(11)), bytes32(uint256(12))
        );
        e.before_[4] = T.Snapshot(
            keccak256("domain:attribution_lifecycle"),
            17,
            bytes32(uint256(41)),
            bytes32(uint256(42))
        );
        e.before_[6] = T.Snapshot(
            keccak256("domain:consent_finality"), 103, bytes32(uint256(61)), bytes32(uint256(62))
        );
        e.after_[0] = e.before_[0];
        e.after_[4] = T.Snapshot(
            e.before_[4].domainId,
            18,
            _root(
                o,
                4,
                e.before_[4],
                e.actor,
                keccak256(
                    abi.encode(
                        p.binding_, p.transition, p.sanction.signer, p.sanction.authorityClass
                    )
                ),
                keccak256(abi.encode(uint256(7), uint8(3), uint64(2))),
                0
            ),
            e.before_[4].recordChainTip
        );
        e.after_[6] = T.Snapshot(
            e.before_[6].domainId,
            104,
            _root(
                o,
                6,
                e.before_[6],
                e.actor,
                keccak256(abi.encode(p.binding_, p.transition)),
                keccak256(abi.encode(p.transition, p.replayKey)),
                keccak256(abi.encode(p.replayKey, p.sanction.recordHash))
            ),
            e.before_[6].recordChainTip
        );
        era.checkpoints[0].ownerState.revision = 7;
        era.checkpoints[4].ownerState.revision = 18;
        era.checkpoints[6].ownerState.revision = 104;
        e.payload = _payload(p);
    }

    function _payload(H.ConfirmationPayload memory p) private pure returns (bytes memory) {
        return abi.encode(
            p.binding_,
            p.transition,
            p.sanction,
            p.finalityRegistry,
            p.finalityCodeHash,
            p.finalityRecord,
            p.components,
            p.executionWitness,
            p.archiveWitness,
            p.rawReadHash,
            p.replayKey
        );
    }

    function _record(RH.OriginEnvironment memory o, S.Record memory r)
        private
        pure
        returns (bytes32)
    {
        bytes32[14] memory words = [
            keccak256("6529STREAM_ARTIST_SANCTION_RECORD_V1"),
            bytes32(o.chainId),
            bytes32(uint256(uint160(o.registry))),
            r.artistId,
            bytes32(uint256(uint160(r.signer))),
            bytes32(uint256(r.authorityClass)),
            bytes32(uint256(r.terms.scopeType)),
            bytes32(r.terms.collectionId),
            bytes32(r.terms.tokenId),
            r.terms.scopeId,
            r.terms.sanctionSubjectHash,
            r.terms.statementHash,
            bytes32(r.nonce),
            bytes32(uint256(r.signedAt))
        ];
        return keccak256(abi.encode(words));
    }

    function _root(
        RH.OriginEnvironment memory o,
        uint8 owner,
        T.Snapshot memory before_,
        address actor,
        bytes32 action,
        bytes32 state,
        bytes32 replay
    ) private pure returns (bytes32) {
        bytes32[14] memory words = [
            keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"),
            bytes32(o.chainId),
            bytes32(uint256(uint160(o.registry))),
            bytes32(uint256(uint160(o.coordinator))),
            bytes32(uint256(uint160(o.archive))),
            bytes32(uint256(uint160(o.owners[owner]))),
            owner == 4
                ? keccak256("domain:attribution_lifecycle")
                : keccak256("domain:consent_finality"),
            bytes32(uint256(before_.revision)),
            bytes32(uint256(before_.revision) + 1),
            before_.stateRoot,
            keccak256(abi.encode(uint16(13), actor, action)),
            state,
            replay,
            keccak256(abi.encode(bytes32(0)))
        ];
        return keccak256(abi.encode(words));
    }
}
