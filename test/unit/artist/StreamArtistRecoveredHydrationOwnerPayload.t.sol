// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";

/// @notice Synthetic transport vectors, not an actual recovered-state admission or import host.
contract StreamArtistRecoveredHydrationOwnerPayloadTest {
    function checkCapability(RH.Capability memory capability, uint8 index, uint256 features)
        external
        pure
    {
        Codec.requireCapability(capability, index, features);
    }

    function testOwnerCapabilityRequiresExplicitEconomicsSupportOnEveryOwner() external view {
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory capability = RH.Capability(
                RH.PROFILE,
                RH.VERSION,
                index,
                RH.ownerDomain(index),
                RH.CHECKPOINT,
                RH.ownerTag(index),
                RH.FIRST_GRAPH_FEATURES
            );
            // The frozen first graph remains sufficient for its original histories.
            Codec.requireCapability(capability, index, RH.FIRST_GRAPH_FEATURES);
            (bool ok, bytes memory reason) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.checkCapability, (capability, index, RH.ECONOMICS_GRAPH_FEATURES)
                    )
                );
            assert(!ok);
            assert(
                keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    )
            );
            capability.supportedFeatures = RH.ECONOMICS_GRAPH_FEATURES;
            Codec.requireCapability(capability, index, RH.ECONOMICS_GRAPH_FEATURES);
        }
    }

    function testOwnerCapabilityRequiresExplicitDelegationSupportOnEveryOwner() external view {
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory capability = RH.Capability(
                RH.PROFILE,
                RH.VERSION,
                index,
                RH.ownerDomain(index),
                RH.CHECKPOINT,
                RH.ownerTag(index),
                RH.ECONOMICS_GRAPH_FEATURES
            );
            Codec.requireCapability(capability, index, RH.ECONOMICS_GRAPH_FEATURES);
            (bool ok, bytes memory reason) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.checkCapability, (capability, index, RH.DELEGATION_GRAPH_FEATURES)
                    )
                );
            assert(!ok);
            assert(
                keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    )
            );
            capability.supportedFeatures = RH.DELEGATION_GRAPH_FEATURES;
            Codec.requireCapability(capability, index, RH.DELEGATION_GRAPH_FEATURES);
        }
    }

    function check(uint8 index, RH.ExportHeader memory header, Payload.Payload memory p)
        external
        pure
        returns (bytes32)
    {
        return Payload.validate(index, header, p);
    }

    function testOwnerCapabilityRequiresExplicitAttestationsOnEveryOwner() external view {
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory capability = RH.Capability(
                RH.PROFILE,
                RH.VERSION,
                index,
                RH.ownerDomain(index),
                RH.CHECKPOINT,
                RH.ownerTag(index),
                RH.DELEGATION_GRAPH_FEATURES
            );
            Codec.requireCapability(capability, index, RH.DELEGATION_GRAPH_FEATURES);
            (bool ok, bytes memory reason) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.checkCapability, (capability, index, RH.ATTESTATION_GRAPH_FEATURES)
                    )
                );
            assert(!ok);
            assert(
                keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    )
            );
            capability.supportedFeatures = RH.ATTESTATION_GRAPH_FEATURES;
            Codec.requireCapability(capability, index, RH.ATTESTATION_GRAPH_FEATURES);
        }
    }

    function testOwnerCapabilityRequiresExplicitContentConsentsOnEveryOwner() external view {
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory capability = RH.Capability(
                RH.PROFILE,
                RH.VERSION,
                index,
                RH.ownerDomain(index),
                RH.CHECKPOINT,
                RH.ownerTag(index),
                RH.ATTESTATION_GRAPH_FEATURES
            );
            Codec.requireCapability(capability, index, RH.ATTESTATION_GRAPH_FEATURES);
            (bool ok, bytes memory reason) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.checkCapability, (capability, index, RH.CONTENT_GRAPH_FEATURES)
                    )
                );
            assert(!ok);
            assert(
                keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    )
            );
            capability.supportedFeatures = RH.CONTENT_GRAPH_FEATURES;
            Codec.requireCapability(capability, index, RH.CONTENT_GRAPH_FEATURES);
        }
    }

    function testOwnerCapabilityRequiresExplicitBindingGenerationsOnEveryOwner() external view {
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory capability = RH.Capability(
                RH.PROFILE,
                RH.VERSION,
                index,
                RH.ownerDomain(index),
                RH.CHECKPOINT,
                RH.ownerTag(index),
                RH.CONTENT_GRAPH_FEATURES
            );
            Codec.requireCapability(capability, index, RH.CONTENT_GRAPH_FEATURES);
            (bool ok, bytes memory reason) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.checkCapability, (capability, index, RH.BINDING_GRAPH_FEATURES)
                    )
                );
            assert(
                !ok
                    && keccak256(reason)
                        == keccak256(
                            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                        )
            );
            capability.supportedFeatures = RH.BINDING_GRAPH_FEATURES;
            Codec.requireCapability(capability, index, RH.BINDING_GRAPH_FEATURES);
        }
    }

    function decode(bytes memory raw, uint8 index)
        external
        pure
        returns (RH.ExportHeader memory, Payload.Payload memory)
    {
        return Payload.decode(raw, index);
    }

    function ownerCompare(
        RH.OwnerProvenance memory p,
        uint8 index,
        RH.Point memory a,
        RH.Point memory b
    ) external pure returns (int8) {
        return Chronology.compareOwner(p, index, a, b);
    }

    function testOwnerPayloadRoundTripPreservesOneOwnerAndBothOriginal35Occurrences()
        external
        pure
    {
        Payload.Payload memory p = _payload(2);
        RH.ExportHeader memory h = _header(2, p);
        bytes memory encoded = Payload.encode(2, h, p);
        (RH.ExportHeader memory saved, Payload.Payload memory out) = Payload.decode(encoded, 2);
        assert(keccak256(abi.encode(saved)) == keccak256(abi.encode(h)));
        assert(keccak256(abi.encode(out)) == keccak256(abi.encode(p)));
        assert(saved.semanticRecordCount == 2);
        assert(out.provenance.journal[0].position.nativeIndex == 0);
        assert(out.provenance.journal[1].position.nativeIndex == 1);
    }

    function testOwnerPayloadPreservesExistingTaggedPayoutInventoryHash() external pure {
        Payload.Payload memory p = _payload(5);
        p.provenance.journal = new RH.JournalEntry[](0);
        p.provenance.eras[0].nativeCount = 0;
        P.Bundle memory bundle;
        bundle.artistId = bytes32(uint256(42));
        bundle.sourceSnapshot = p.provenance.eras[0].checkpoint.ownerState;
        p.semanticState = abi.encode(P.SCHEMA, bundle);
        RH.ExportHeader memory h = _header(5, p);
        assert(h.semanticInventory == keccak256(abi.encode(P.SCHEMA, bundle)));
        (, Payload.Payload memory decoded) = Payload.decode(Payload.encode(5, h, p), 5);
        assert(keccak256(decoded.semanticState) == h.semanticInventory);
    }

    function testOwnerPayloadRejectsEveryIncorrectLocalHeaderJoin() external {
        Payload.Payload memory p = _payload(2);
        RH.ExportHeader memory h = _header(2, p);
        h.sourceOrigin = bytes32(uint256(1));
        _reject(h, p);
        h = _header(2, p);
        h.priorImportCommitment = bytes32(uint256(1));
        _reject(h, p);
        h = _header(2, p);
        h.provenanceCommitment = bytes32(uint256(1));
        _reject(h, p);
        h = _header(2, p);
        h.replayAliasesCommitment = bytes32(uint256(1));
        _reject(h, p);
        h = _header(2, p);
        h.replayAliasCount = 1;
        _reject(h, p);
        h = _header(2, p);
        h.eraCount = 2;
        _reject(h, p);
        h = _header(2, p);
        h.semanticRecordCount = 1;
        _reject(h, p);
    }

    function testOwnerPayloadRejectsChangedOrEmptySemanticBytes() external {
        Payload.Payload memory p = _payload(2);
        RH.ExportHeader memory h = _header(2, p);
        p.semanticState = abi.encode(bytes32(uint256(123)));
        _reject(h, p);
        p.semanticState = new bytes(0);
        h = _header(2, p);
        _reject(h, p);
    }

    function testOwnerPayloadRejectsWrongOwnerInnerSchemaVersionAndTrailingBytes() external {
        Payload.Payload memory p = _payload(2);
        RH.ExportHeader memory h = _header(2, p);
        bytes memory raw = Payload.encode(2, h, p);
        (bool ok,) = address(this).call(abi.encodeCall(this.decode, (raw, uint8(5))));
        assert(!ok);
        raw = Codec.encode(2, RH.Envelope(h, abi.encode(bytes32(uint256(1)), RH.VERSION, p)));
        _rejectDecode(raw);
        raw = Codec.encode(2, RH.Envelope(h, abi.encode(Payload.SCHEMA, uint16(2), p)));
        _rejectDecode(raw);
        raw = Codec.encode(
            2, RH.Envelope(h, bytes.concat(abi.encode(Payload.SCHEMA, RH.VERSION, p), bytes32(0)))
        );
        _rejectDecode(raw);
        raw = bytes.concat(Payload.encode(2, h, p), bytes32(0));
        _rejectDecode(raw);
    }

    function testOwnerPayloadPreservesAllFiveNonceKindsAndAllAncestorWords() external pure {
        Payload.Payload memory p = _payload(2);
        p.nonces = _nonces();
        p.provenance.eras[0].checkpoint.nonceIndexCount = 5;
        RH.ExportHeader memory h = _header(2, p);
        (, Payload.Payload memory out) = Payload.decode(Payload.encode(2, h, p), 2);
        assert(keccak256(abi.encode(out.nonces)) == keccak256(abi.encode(p.nonces)));
        assert(out.nonces[4].words[0].exhausted);
        assert(out.nonces[3].words[0].words[31] == 35);
    }

    function testOwnerPayloadRejectsMissingDuplicateAndUnknownNonceIndexes() external {
        Payload.Payload memory p = _payload(2);
        p.nonces = _nonces();
        p.provenance.eras[0].checkpoint.nonceIndexCount = 6;
        _reject(_header(2, p), p);
        p.provenance.eras[0].checkpoint.nonceIndexCount = 5;
        p.nonces[1].index.kind = p.nonces[0].index.kind;
        p.nonces[1].index.key = p.nonces[0].index.key;
        _reject(_header(2, p), p);
        p.nonces = _nonces();
        p.nonces[0].index.kind = 6;
        _reject(_header(2, p), p);
        p.nonces = _nonces();
        p.nonces[0].index.key = 0;
        _reject(_header(2, p), p);
    }

    function testOwnerPayloadRejectsDuplicatePrefixesAndConflictingTreeExhaustion() external {
        Payload.Payload memory p = _payload(2);
        p.nonces = _nonces();
        p.provenance.eras[0].checkpoint.nonceIndexCount = 5;
        p.nonces[0].index.prefixCount = 2;
        p.nonces[0].words = new AH.NonceWord[](2);
        _reject(_header(2, p), p);
        p.nonces[0].words[1].prefix = 1;
        p.nonces[0].words[1].exhausted = true;
        _reject(_header(2, p), p);
        p.nonces[0].words[1].exhausted = false;
        assert(Payload.validate(2, _header(2, p), p) != 0);
    }

    function testOwnerPayloadRequiresRepeatedFeatureForActualSecondEra() external {
        Payload.Payload memory p = _repeated();
        RH.ExportHeader memory h = _header(2, p);
        h.requiredFeatures = RH.CLASS_ONE;
        _reject(h, p);
        h.requiredFeatures |= RH.REPEATED_IMPORT;
        assert(Payload.validate(2, h, p) != 0);
        RH.Point memory old = p.provenance.journal[0].position.point;
        RH.Point memory fresh = p.provenance.journal[2].position.point;
        assert(old.ownerRevision == 10 && fresh.ownerRevision == 5);
        assert(Chronology.beforeOwner(p.provenance, 2, old, fresh));
        assert(Chronology.compareOwner(p.provenance, 2, fresh, old) == 1);
        Chronology.validateOwnerPoint(p.provenance, 2, old);
        (bool ok,) = address(this)
            .call(abi.encodeCall(this.ownerCompare, (p.provenance, uint8(5), old, fresh)));
        assert(!ok);
    }

    function testOwnerPayloadRejectsUnsupportedFeatureAndNativeBoundaryCorruption() external {
        Payload.Payload memory p = _payload(2);
        RH.ExportHeader memory h = _header(2, p);
        h.requiredFeatures |= 1024;
        _reject(h, p);
        p = _repeated();
        p.provenance.journal[2].position.point.ownerRevision = 3;
        _reject(_header(2, p), p);
    }

    function _reject(RH.ExportHeader memory h, Payload.Payload memory p) private {
        (bool ok,) = address(this).call(abi.encodeCall(this.check, (uint8(2), h, p)));
        assert(!ok);
    }

    function _rejectDecode(bytes memory raw) private {
        (bool ok,) = address(this).call(abi.encodeCall(this.decode, (raw, uint8(2))));
        assert(!ok);
    }

    function _payload(uint8 ownerIndex) private pure returns (Payload.Payload memory p) {
        p.provenance.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory origin;
        origin.chainId = 1;
        origin.registry = address(1);
        origin.coordinator = address(2);
        origin.archive = address(3);
        origin.core = address(4);
        origin.manager = address(5);
        origin.suiteConfigurationHash = bytes32(uint256(6));
        for (uint8 i; i < 7; ++i) {
            origin.owners[i] = address(uint160(100) + i);
            origin.ownerCodeHashes[i] = bytes32(uint256(200) + i);
        }
        p.provenance.origins[0] = origin;
        p.provenance.eras = new RH.OwnerEra[](1);
        p.provenance.eras[0].originHash = RH.originHash(origin);
        p.provenance.eras[0].checkpoint.schema = RH.CHECKPOINT;
        p.provenance.eras[0].checkpoint.ownerState = T.Snapshot(
            RH.ownerDomain(ownerIndex), 12, bytes32(uint256(300)), bytes32(uint256(301))
        );
        p.provenance.eras[0].nativeCount = 2;
        p.provenance.journal = new RH.JournalEntry[](2);
        for (uint256 i; i < 2; ++i) {
            p.provenance.journal[i] = RH.JournalEntry(
                RH.Position(RH.Point(RH.originHash(origin), ownerIndex, 10), i),
                H.Receipt(35, bytes32(uint256(42)), 0, bytes32(uint256(400) + i))
            );
        }
        p.semanticState = abi.encode(keccak256("SYNTHETIC_TYPED_SEMANTIC_STATE"), uint256(42));
    }

    function _header(uint8 ownerIndex, Payload.Payload memory p)
        private
        pure
        returns (RH.ExportHeader memory h)
    {
        uint256 last = p.provenance.eras.length - 1;
        h.profile = RH.PROFILE;
        h.version = RH.VERSION;
        h.ownerIndex = ownerIndex;
        h.sourceOrigin = p.provenance.eras[last].originHash;
        h.priorImportCommitment = p.provenance.eras[last].priorImportCommitment;
        h.semanticInventory = keccak256(p.semanticState);
        h.provenanceCommitment = RH.ownerProvenanceHash(p.provenance, ownerIndex);
        h.replayAliasesCommitment = RH.aliasesHash(ownerIndex, p.provenance.aliases);
        h.requiredFeatures = RH.CLASS_ONE;
        if (last != 0) h.requiredFeatures |= RH.REPEATED_IMPORT;
        h.semanticRecordCount = p.provenance.journal.length;
        h.replayAliasCount = p.provenance.aliases.length;
        h.eraCount = p.provenance.eras.length;
    }

    function _nonces() private pure returns (RH.NonceInventory[] memory n) {
        n = new RH.NonceInventory[](5);
        for (uint256 i; i < n.length; ++i) {
            n[i].index = CP.NonceIndex(uint8(i + 1), bytes32(i + 1), 1);
            n[i].words = new AH.NonceWord[](1);
            n[i].words[0].prefix = i;
            n[i].words[0].exhausted = i == 4;
            for (uint256 j; j < 32; ++j) {
                n[i].words[0].words[j] = i + j + 1;
            }
        }
    }

    function _repeated() private pure returns (Payload.Payload memory p) {
        Payload.Payload memory original = _payload(2);
        p.semanticState = original.semanticState;
        p.provenance.origins = new RH.OriginEnvironment[](2);
        p.provenance.origins[0] = original.provenance.origins[0];
        RH.OriginEnvironment memory next;
        next.chainId = 1;
        next.registry = address(1001);
        next.coordinator = address(1002);
        next.archive = address(1003);
        next.core = address(4);
        next.manager = address(5);
        next.suiteConfigurationHash = bytes32(uint256(1006));
        for (uint8 i; i < 7; ++i) {
            next.owners[i] = address(uint160(1100) + i);
            next.ownerCodeHashes[i] = bytes32(uint256(1200) + i);
        }
        p.provenance.origins[1] = next;
        p.provenance.eras = new RH.OwnerEra[](2);
        p.provenance.eras[0] = original.provenance.eras[0];
        p.provenance.eras[1].originHash = RH.originHash(next);
        p.provenance.eras[1].checkpoint.schema = RH.CHECKPOINT;
        p.provenance.eras[1].checkpoint.ownerState =
            T.Snapshot(RH.ownerDomain(2), 8, bytes32(uint256(1300)), bytes32(uint256(1301)));
        p.provenance.eras[1].nativeCount = 1;
        p.provenance.eras[1].lowerRevision = 3;
        p.provenance.eras[1].priorImportCommitment = bytes32(uint256(1400));
        p.provenance.journal = new RH.JournalEntry[](3);
        p.provenance.journal[0] = original.provenance.journal[0];
        p.provenance.journal[1] = original.provenance.journal[1];
        p.provenance.journal[2] = RH.JournalEntry(
            RH.Position(RH.Point(RH.originHash(next), 2, 5), 0),
            H.Receipt(35, bytes32(uint256(42)), 0, bytes32(uint256(1500)))
        );
    }
}
