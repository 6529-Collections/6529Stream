// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCodec.sol";
import {
    StreamArtistCompleteHistoryTypes as C
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryScope as Scope
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistBindingCorrectionState as CS
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistRecoveredPlatformTypes as P
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

interface CompleteHistoryCodecVm {
    function expectRevert(bytes4) external;
}

/// @notice Pure synthetic shape oracles, not original-producer or full admission evidence.
/// Opaque family bytes deliberately remain opaque until fixed family codecs are integrated.
contract StreamArtistCompleteHistoryCodecTest {
    CompleteHistoryCodecVm private constant vm =
        CompleteHistoryCodecVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = bytes32(uint256(101));
    bytes32 private constant BINDING = bytes32(uint256(202));
    bytes32 private constant DECLARATION = bytes32(uint256(303));

    function testCompleteCodecCanonicalInnerAcrossAllSevenOwnerTopologies() external pure {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        bytes memory auxiliary = abi.encode(proof);
        for (uint8 owner; owner < 7; ++owner) {
            _rows(s, owner);
            RH.OwnerProvenance memory local = RH.ownerProvenance(proof.provenance, owner);
            bytes memory raw = Codec.encode(owner, s, local, auxiliary);
            (M.State memory decoded, bytes memory recovered) =
                Codec.decodeAuxiliary(owner, raw, local);
            require(keccak256(abi.encode(decoded)) == keccak256(abi.encode(s)), "state changed");
            require(keccak256(recovered) == keccak256(auxiliary), "inventory changed");
            require(
                keccak256(raw) == keccak256(abi.encode(C.SCHEMA, C.VERSION, owner, s, auxiliary)),
                "tuple changed"
            );
        }
    }

    function testCompleteCodecAllUnboundIdentityHasNoFabricatedArtistRow() external pure {
        (M.State memory s, C.Inventory memory proof) = _fixture(false);
        _rows(s, 2);
        require(s.artists.length == 0 && s.rows.length == 0, "invented principal");
        M.State memory decoded = Codec.decode(
            2,
            Codec.encode(2, s, RH.ownerProvenance(proof.provenance, 2), abi.encode(proof)),
            RH.ownerProvenance(proof.provenance, 2)
        );
        require(decoded.artists.length == 0 && decoded.rows.length == 0, "invented Identity row");
    }

    function testCompleteCodecUnboundAnchorRetainsNativeRecordsAndDoesNotAliasQuery()
        external
        pure
    {
        (M.State memory s,) = _fixture(true);
        bytes32 before = keccak256(abi.encode(s));
        AH.Query memory anchor = Codec.anchorQuery(s);
        require(
            anchor.artistId == 0 && anchor.bindingHash == 0 && anchor.collectionId == 10,
            "wrong anchor"
        );
        require(
            anchor.records.length == 1 && anchor.records[0] == DECLARATION, "native Platform lost"
        );
        anchor.collectionId = 99;
        require(keccak256(abi.encode(s)) == before, "anchor rewrote collection");
    }

    function testCompleteCodecRejectsTrailingInnerAndAuxiliaryBytes() external {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        _rows(s, 0);
        RH.OwnerProvenance memory local = RH.ownerProvenance(proof.provenance, 0);
        bytes memory raw = Codec.encode(0, s, local, abi.encode(proof));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.decode(0, bytes.concat(raw, hex"00"), local);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.encode(0, s, local, bytes.concat(abi.encode(proof), hex"00"));
    }

    function testCompleteCodecRejectsOldTagWrongVersionAndWrongOwner() external {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        _rows(s, 0);
        RH.OwnerProvenance memory local = RH.ownerProvenance(proof.provenance, 0);
        bytes memory auxiliary = abi.encode(proof);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.decode(0, abi.encode(M.SCHEMA, C.VERSION, uint8(0), s, auxiliary), local);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.decode(0, abi.encode(C.SCHEMA, uint16(2), uint8(0), s, auxiliary), local);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.decode(0, abi.encode(C.SCHEMA, C.VERSION, uint8(1), s, auxiliary), local);
    }

    function testCompleteCodecJoinsEveryLocalOwnerToTheFullInventory() external {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        bytes memory auxiliary = abi.encode(proof);
        for (uint8 owner; owner < 7; ++owner) {
            _rows(s, owner);
            RH.OwnerProvenance memory local = RH.ownerProvenance(proof.provenance, owner);
            // Round-trip isolates this mutation from the complete inventory's memory.
            local = abi.decode(abi.encode(local), (RH.OwnerProvenance));
            local.eras[0].checkpoint.ownerState.stateRoot = bytes32(uint256(999));
            vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
            Codec.encode(owner, s, local, auxiliary);
        }
    }

    function testCompleteCodecRejectsMissingPrincipalAndNativeMembership() external {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        _rows(s, 0);
        RH.OwnerProvenance memory local = RH.ownerProvenance(proof.provenance, 0);
        s.artists[0].records = new bytes32[](0);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.encode(0, s, local, abi.encode(proof));
        s.artists = new AH.Query[](0);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.encode(0, s, local, abi.encode(proof));
    }

    function testCompleteCodecRejectsBoundHeadDisguisedAsUnbound() external {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        _rows(s, 0);
        s.collections[1].artistId = 0;
        s.collections[1].bindingHash = 0;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.encode(0, s, RH.ownerProvenance(proof.provenance, 0), abi.encode(proof));
    }

    function testCompleteCodecRejectsUnboundPlatformWithConsumedCorrection() external {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        _rows(s, 4);
        proof.platforms[0].state.correction.correctiveGeneration = 1;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.encode(4, s, RH.ownerProvenance(proof.provenance, 4), abi.encode(proof));
    }

    function testCompleteCodecRejectsMissingUnboundPlatformAndWrongRowTopology() external {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        _rows(s, 2);
        s.rows = new bytes[](2);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.encode(2, s, RH.ownerProvenance(proof.provenance, 2), abi.encode(proof));
        _rows(s, 2);
        proof.platforms[0].state.declaration.recordHash = 0;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.encode(2, s, RH.ownerProvenance(proof.provenance, 2), abi.encode(proof));
    }

    function testCompleteCodecRequiresItsOwnOuterFeatureAndKeepsOldEnvelopeShape() external {
        (M.State memory s, C.Inventory memory proof) = _fixture(true);
        _rows(s, 0);
        Payload.Payload memory payload;
        payload.provenance = RH.ownerProvenance(proof.provenance, 0);
        payload.semanticState = Codec.encode(0, s, payload.provenance, abi.encode(proof));
        RH.ExportHeader memory h;
        h.profile = RH.PROFILE;
        h.version = RH.VERSION;
        h.sourceOrigin = proof.provenance.eras[0].originHash;
        h.semanticInventory = keccak256(payload.semanticState);
        h.provenanceCommitment = RH.ownerProvenanceHash(payload.provenance, 0);
        h.replayAliasesCommitment = RH.aliasesHash(0, payload.provenance.aliases);
        h.semanticRecordCount = payload.provenance.journal.length;
        h.eraCount = 1;
        bytes memory raw = Payload.encode(0, h, payload);
        require(!Codec.selected(raw, 0), "old header selected new route");
        AH.Query memory anchor = Codec.anchorQuery(s);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Codec.outer(0, anchor, raw);
        // This stage reserves a tag but intentionally does not activate a known capability.
        h.requiredFeatures = C.FEATURE;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Payload.encode(0, h, payload);
    }

    function _rows(M.State memory s, uint8 owner) private pure {
        s.rows = new bytes[](
            owner == 1 ? 0 : (owner == 2 || owner == 5) ? s.artists.length : s.collections.length
        );
        for (uint256 i; i < s.rows.length; ++i) {
            s.rows[i] = abi.encode(owner, i);
        }
    }

    function _fixture(bool bound)
        private
        pure
        returns (M.State memory s, C.Inventory memory proof)
    {
        proof.provenance = _provenance(bound);
        uint256 count = bound ? 2 : 1;
        MH.Request memory request;
        request.artistIds = new bytes32[](bound ? 1 : 0);
        request.collections = new MH.Collection[](count);
        request.collections[0].collectionId = 10;
        T.Binding[] memory heads = new T.Binding[](count);
        if (bound) {
            request.artistIds[0] = ARTIST;
            request.collections[1].artistId = ARTIST;
            request.collections[1].collectionId = 20;
            heads[1].artistId = ARTIST;
            heads[1].artistAddress = address(0xA11);
            heads[1].bindingHash = BINDING;
            heads[1].generation = 1;
            heads[1].consentMode = 1;
        }
        s = Scope.partition(request, heads, proof.provenance);
        proof.bindings.bindings = new CB.Bundle[](count);
        proof.bindings.generations = new A.Generation[][](count);
        proof.bindings.collaborators = new T.CollaboratorRecord[][][](count);
        proof.platforms = new P.Platform[](count);
        proof.accepted = new A.AcceptanceBundle[](count);
        for (uint256 k; k < count; ++k) {
            uint256 generations = k == 0 ? 0 : 1;
            G.Bundle memory binding;
            binding.artistId = heads[k].artistId;
            binding.collectionId = s.collections[k].collectionId;
            binding.bindingHash = heads[k].bindingHash;
            binding.provenanceCommitment =
                RH.ownerProvenanceHash(RH.ownerProvenance(proof.provenance, 0), 0);
            binding.current = heads[k];
            binding.rows = new G.Row[](generations);
            proof.bindings.bindings[k].corrections = new CS.Correction[](generations);
            proof.bindings.generations[k] = new A.Generation[](generations);
            proof.bindings.collaborators[k] = new T.CollaboratorRecord[][](generations);
            proof.accepted[k].rows = new A.Acceptance[](generations);
            if (generations != 0) {
                binding.rows[0].item = heads[k];
                proof.bindings.generations[k][0] =
                    A.Generation(BINDING, 1, false, proof.provenance.journals[0][0].position.point);
                proof.accepted[k].rows[0] = A.Acceptance(BINDING, 1, 0, 0);
            }
            proof.bindings.bindings[k].bindings = binding;
            proof.platforms[k].collectionId = binding.collectionId;
            proof.platforms[k].provenance =
                RH.ownerProvenanceHash(RH.ownerProvenance(proof.provenance, 4), 4);
            proof.accepted[k].provenance =
                RH.ownerProvenanceHash(RH.ownerProvenance(proof.provenance, 3), 3);
            proof.accepted[k].artistId = binding.artistId;
            proof.accepted[k].collectionId = binding.collectionId;
            proof.accepted[k].bindingHash = binding.bindingHash;
        }
        proof.platforms[0].state.declaration.recordHash = DECLARATION;
    }

    function _provenance(bool bound) private pure returns (RH.Provenance memory p) {
        p.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory origin;
        origin.chainId = 1;
        origin.registry = address(1);
        origin.coordinator = address(2);
        origin.archive = address(3);
        origin.core = address(4);
        origin.manager = address(5);
        origin.suiteConfigurationHash = bytes32(uint256(6));
        for (uint8 owner; owner < 7; ++owner) {
            origin.owners[owner] = address(uint160(10 + owner));
            origin.ownerCodeHashes[owner] = bytes32(uint256(20 + owner));
        }
        p.origins[0] = origin;
        p.eras = new RH.Era[](1);
        bytes32 environment = RH.originHash(origin);
        p.eras[0].originHash = environment;
        for (uint8 owner; owner < 7; ++owner) {
            bool native = owner == 4 || (bound && (owner == 0 || owner == 2));
            p.eras[0].checkpoints[owner].schema = RH.CHECKPOINT;
            p.eras[0].checkpoints[owner].ownerState = T.Snapshot(
                RH.ownerDomain(owner), native ? 1 : 0, bytes32(uint256(1)), bytes32(uint256(2))
            );
            if (!native) continue;
            p.eras[0].nativeCounts[owner] = 1;
            p.journals[owner] = new RH.JournalEntry[](1);
            p.journals[owner][0].position = RH.Position(RH.Point(environment, owner, 1), 0);
            p.journals[owner][0].receipt = owner == 0
                ? H.Receipt(1, ARTIST, 20, BINDING)
                : owner == 2 ? H.Receipt(1, ARTIST, 0, ARTIST) : H.Receipt(8, 0, 10, DECLARATION);
        }
    }
}
