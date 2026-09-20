// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Synthetic pure decoder parity; no source-owner, carrier, or import authority claim.
contract StreamArtistRecoveredApplyProjectionTest {
    function full(bytes memory raw, uint8 index) external pure returns (bytes32) {
        (, Payload.Payload memory p) = Payload.decode(raw, index);
        return keccak256(abi.encode(p.provenance, p.publications));
    }

    function projected(bytes memory raw, uint8 index) external pure returns (bytes32) {
        (RH.OwnerProvenance memory provenance, Publications.Row[] memory rows) =
            Payload.decodeForApply(raw, index);
        return keccak256(abi.encode(provenance, rows));
    }

    function _payload(bytes32 seed) private pure returns (Payload.Payload memory p) {
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
        p.provenance.eras[0].checkpoint.ownerState =
            T.Snapshot(RH.ownerDomain(2), 12, bytes32(uint256(300)), bytes32(uint256(301)));
        p.semanticState = abi.encode(seed, uint256(42));
        p.publications = new Publications.Row[](2);
        p.publications[0] =
            Publications.Row(address(1000), bytes32(uint256(1)), bytes32(uint256(seed) | 1));
        p.publications[1] =
            Publications.Row(address(1001), bytes32(uint256(2)), bytes32(uint256(seed) | 1));
    }

    function _header(Payload.Payload memory p) private pure returns (RH.ExportHeader memory h) {
        h.profile = RH.PROFILE;
        h.version = RH.VERSION;
        h.ownerIndex = 2;
        h.sourceOrigin = p.provenance.eras[0].originHash;
        h.semanticInventory = keccak256(p.semanticState);
        h.provenanceCommitment = RH.ownerProvenanceHash(p.provenance, 2);
        h.replayAliasesCommitment = RH.aliasesHash(2, p.provenance.aliases);
        h.requiredFeatures = RH.CLASS_ONE;
        h.eraCount = 1;
    }

    function _raw(RH.ExportHeader memory h, Payload.Payload memory p)
        private
        pure
        returns (bytes memory)
    {
        return Codec.encode(2, RH.Envelope(h, abi.encode(Payload.SCHEMA, RH.VERSION, p)));
    }

    function _same(Payload.Payload memory p) private view {
        bytes memory raw = Payload.encode(2, _header(p), p);
        bytes32 expected = keccak256(abi.encode(p.provenance, p.publications));
        require(
            this.full(raw, 2) == expected && this.projected(raw, 2) == expected, "exact projection"
        );
    }

    function _sameFailure(bytes memory raw, uint8 index) private view {
        (bool oldOk, bytes memory oldReason) =
            address(this).staticcall(abi.encodeCall(this.full, (raw, index)));
        (bool newOk, bytes memory newReason) =
            address(this).staticcall(abi.encodeCall(this.projected, (raw, index)));
        require(
            !oldOk && !newOk && oldReason.length == newReason.length
                && keccak256(oldReason) == keccak256(newReason),
            "same full validation failure"
        );
    }

    function testExactProvenanceAndPublicationRowsAfterFullDecode() public view {
        _same(_payload(bytes32(uint256(7))));
        Payload.Payload memory p = _payload(bytes32(uint256(8)));
        p.publications = new Publications.Row[](0);
        _same(p);
    }

    function testFuzzProjectionPreservesEveryReturnedByte(bytes32 seed) public view {
        _same(_payload(seed));
    }

    function testOmittedSemanticAndNonceFieldsStillCauseOriginalRefusal() public view {
        Payload.Payload memory p = _payload(bytes32(uint256(9)));
        RH.ExportHeader memory h = _header(p);
        p.semanticState = hex"99";
        _sameFailure(_raw(h, p), 2);
        p = _payload(bytes32(uint256(9)));
        p.provenance.eras[0].checkpoint.nonceIndexCount = 1;
        p.nonces = new RH.NonceInventory[](1);
        p.nonces[0].index.kind = 6;
        p.nonces[0].index.key = bytes32(uint256(1));
        p.nonces[0].index.prefixCount = 1;
        p.nonces[0].words = new AH.NonceWord[](1);
        _sameFailure(_raw(_header(p), p), 2);
    }

    function testWrongOwnerCanonicalEnvelopeAndCatalogRefusalsRemainExact() public view {
        Payload.Payload memory p = _payload(bytes32(uint256(10)));
        bytes memory raw = Payload.encode(2, _header(p), p);
        _sameFailure(raw, 5);
        _sameFailure(bytes.concat(raw, bytes32(0)), 2);
        p.publications[1].payloadType = p.publications[0].payloadType;
        _sameFailure(_raw(_header(p), p), 2);
        p = _payload(bytes32(uint256(10)));
        p.provenance.origins[0].registry = address(999);
        _sameFailure(_raw(_header(p), p), 2);
    }
}
