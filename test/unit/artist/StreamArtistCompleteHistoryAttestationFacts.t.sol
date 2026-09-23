// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryAttestationValidation as Validation
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAttestationValidation.sol";
import {
    StreamArtistCompleteHistoryAttestationQueries as Queries
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAttestationQueries.sol";
import {
    StreamArtistCompleteHistoryAttestationHeads as Heads
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAttestationHeads.sol";
import {
    StreamArtistCompleteHistoryAttestationUses as Uses
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAttestationUses.sol";
import {
    StreamArtistCompleteHistoryTypes as CT
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as Timeline
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
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
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as Pub
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistC2PATypes as C2PA
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";

interface CompleteHistoryAttestationVm {
    function expectRevert(bytes4) external;
}

/// @dev Exact source-map boundary for Heads only; this contract does not emulate source admission.
contract CompleteHistoryAttestationHeadMaps {
    mapping(bytes32 => C2PA.Head) private records;
    mapping(bytes32 => C2PA.Head) private heads;
    mapping(bytes32 => T.AttestationRecord) private latest;
    mapping(bytes32 => T.AttestationRecord) private personhood;

    function set(C2PA.Head memory head, T.AttestationRecord memory record) external {
        records[record.recordHash] = head;
        heads[head.artistId] = head;
        latest[keccak256(abi.encode(head.collectionId, uint8(10), head.artistId))] = record;
    }

    function setPersonhood(uint256 id, bytes32 artist, T.AttestationRecord memory record) external {
        personhood[keccak256(abi.encode(id, artist))] = record;
    }

    function c2paCredentialRecord(bytes32 hash) external view returns (C2PA.Head memory) {
        return records[hash];
    }

    function c2paCredentialHead(bytes32 artist) external view returns (C2PA.Head memory) {
        return heads[artist];
    }

    function personhoodAttestation(uint256 id, bytes32 artist)
        external
        view
        returns (T.AttestationRecord memory)
    {
        return personhood[keccak256(abi.encode(id, artist))];
    }

    function attestation(uint256 id, uint8 kind, bytes32 subject)
        external
        view
        returns (T.AttestationRecord memory)
    {
        return latest[keccak256(abi.encode(id, kind, subject))];
    }
}

/// @notice Pure typed semantic vectors and explicit head-map boundaries, not full admission.
/// Global native order contains unbound Platform, former-Artist attestations and disputes;
/// the current binding is a different, pending principal. Original hashes are never relabeled.
contract StreamArtistCompleteHistoryAttestationFactsTest {
    CompleteHistoryAttestationVm private constant vm =
        CompleteHistoryAttestationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FIRST = bytes32(uint256(101));
    bytes32 private constant SECOND = bytes32(uint256(102));
    bytes32 private constant SCHEMA = keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");

    struct Fixture {
        M.State scope;
        CT.Inventory inventory;
        Clocks.Result clocks;
        Original.Bundle[] all;
    }

    function testCompleteAttestationFormerArtistAndGlobalCredentialChainSurvivePendingHead()
        external
        pure
    {
        Fixture memory f = _fixture();
        Original.Bundle[] memory decoded =
            Validation.validate(f.scope, f.inventory, f.clocks, _rows(f));
        require(decoded[1].artistId == SECOND && decoded[1].item.state == 1, "latest pending head");
        require(
            decoded[1].records[0].attestation.input.terms.subjectId == FIRST,
            "former Artist retained"
        );
        require(
            decoded[0].records.length == 0 && decoded[0].item.generation == 0, "genuine unbound row"
        );
    }

    function testCompleteAttestationHistoricalRecordsDoNotInventAcceptanceOfTerminalHead()
        external
        pure
    {
        Fixture memory f = _fixture();
        f.all[1].item.state = 5;
        f.inventory.bindings.bindings[1].bindings.rows[1].terminal.kind = 2;
        Validation.validate(f.scope, f.inventory, f.clocks, _rows(f));
        require(
            !f.inventory.bindings.bindings[1].bindings.current.accepted,
            "invented current acceptance"
        );
    }

    function testCompleteAttestationAllUnboundNeedsNoSyntheticArtistOrAttestation() external pure {
        Fixture memory f = _fixture();
        f.scope.artists = new AH.Query[](0);
        AH.Query[] memory selected = new AH.Query[](1);
        selected[0] = f.scope.collections[0];
        f.scope.collections = selected;
        CB.Bundle[] memory bindings = new CB.Bundle[](1);
        bindings[0] = f.inventory.bindings.bindings[0];
        f.inventory.bindings.bindings = bindings;
        f.inventory.bindings.generations = new A.Generation[][](1);
        f.inventory.bindings.collaborators = new T.CollaboratorRecord[][][](1);
        f.clocks.clocks.collections = new Timeline.Timeline[](1);
        Original.Bundle[] memory all = new Original.Bundle[](1);
        all[0] = f.all[0];
        f.all = all;
        RH.JournalEntry[] memory journal = new RH.JournalEntry[](1);
        journal[0] = f.inventory.provenance.journals[4][0];
        f.inventory.provenance.journals[4] = journal;
        f.inventory.provenance.eras[0].nativeCounts[4] = 1;
        _commit(f);
        Original.Bundle[] memory decoded =
            Validation.validate(f.scope, f.inventory, f.clocks, _rows(f));
        require(
            decoded.length == 1 && decoded[0].artistId == 0 && decoded[0].records.length == 0,
            "invented unbound Artist or attestation"
        );
    }

    function testCompleteAttestationRequiresAuthenticAcceptedGeneration() external {
        Fixture memory f = _fixture();
        f.inventory.bindings.bindings[1].bindings.rows[0].item.accepted = false;
        f.inventory.bindings.generations[1][0].accepted = false;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Validation.validate(f.scope, f.inventory, f.clocks, _rows(f));
    }

    function testCompleteAttestationRejectsRecordBeforeCompletionOrAfterNextProposal() external {
        Fixture memory f = _fixture();
        f.clocks.clocks.collections[1].attributionCompletions[0].ownerRevision = 4;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Validation.validate(f.scope, f.inventory, f.clocks, _rows(f));
        f.clocks.clocks.collections[1].attributionCompletions[0].ownerRevision = 3;
        f.clocks.clocks.collections[1].attributionProposals[1].ownerRevision = 4;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Validation.validate(f.scope, f.inventory, f.clocks, _rows(f));
    }

    function testCompleteAttestationRejectsRelabelingFormerReceiptAsCurrentArtist() external {
        Fixture memory f = _fixture();
        f.inventory.provenance.journals[4][1].receipt.artistId = SECOND;
        _commit(f);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Validation.validate(f.scope, f.inventory, f.clocks, _rows(f));
    }

    function testCompleteAttestationCredentialCannotRestartAcrossCollections() external {
        Fixture memory f = _fixture();
        Pub.Row memory replaced = _credential(f.inventory.provenance.origins[0], 30, 0, 1);
        f.all[2].records[0] = replaced;
        f.inventory.provenance.journals[4][2].receipt.recordHash =
        replaced.attestation.record.recordHash;
        _commit(f);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Validation.validate(f.scope, f.inventory, f.clocks, _rows(f));
    }

    function testCompleteAttestationProjectionPreservesFullScopeAndOriginalCoordinates()
        external
        pure
    {
        Fixture memory f = _fixture();
        bytes32 before = keccak256(abi.encode(f));
        M.State memory selected =
            Queries.project(f.scope, RH.ownerProvenance(f.inventory.provenance, 4));
        require(keccak256(abi.encode(f)) == before, "projection aliased original scope");
        require(
            selected.collections[0].records.length == 0
                && selected.collections[1].records.length == 1,
            "family projection differs"
        );
        require(selected.collections[1].artistId == SECOND, "current selector rewritten");
        require(selected.artists[0].records.length == 2, "complete Artist records discarded");
    }

    function testCompleteAttestationRejectsUnknownAndMistypedSkippedNative() external {
        Fixture memory f = _fixture();
        f.inventory.provenance.journals[4][0].receipt.operation = 4;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Queries.project(f.scope, RH.ownerProvenance(f.inventory.provenance, 4));
        f.inventory.provenance.journals[4][0].receipt.operation = 10;
        f.inventory.provenance.journals[4][0].receipt.artistId = FIRST;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Queries.project(f.scope, RH.ownerProvenance(f.inventory.provenance, 4));
    }

    function testCompleteAttestationOrdinaryIdentityKeepsRetainedSignaturesAndOriginalNonces()
        external
    {
        Fixture memory f = _fixture();
        bytes[] memory identities = _identity(f);
        uint256[][] memory uses =
            Uses.validate(Uses.Context(identities, f.scope, _rows(f), f.inventory));
        require(
            uses.length == 2 && uses[0].length == 0, "ordinary principal invented recovery/grant"
        );
        IH.Bundle memory broken = abi.decode(identities[0], (IH.Bundle));
        broken.signatures = new IH.SignatureRow[](0);
        identities[0] = abi.encode(broken);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Uses.validate(Uses.Context(identities, f.scope, _rows(f), f.inventory));
    }

    function testCompleteAttestationSourceHeadsUseFormerArtistAcrossCollections() external {
        Fixture memory f = _fixture();
        CompleteHistoryAttestationHeadMaps maps = _maps(f);
        Heads.requireMatches(address(maps), f.scope, f.inventory, f.all);
        // The historical Artist's personhood key must be checked even though its collection
        // now names SECOND. Credential records cannot stand in for missing personhood rows.
        maps.setPersonhood(20, FIRST, f.all[1].records[0].attestation.record);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Heads.requireMatches(address(maps), f.scope, f.inventory, f.all);
    }

    function _maps(Fixture memory f) private returns (CompleteHistoryAttestationHeadMaps maps) {
        maps = new CompleteHistoryAttestationHeadMaps();
        bytes32 previous;
        for (uint256 k = 1; k < 3; ++k) {
            T.AttestationRecord memory r = f.all[k].records[0].attestation.record;
            maps.set(
                C2PA.Head(
                    uint64(k),
                    r.recordHash,
                    previous,
                    FIRST,
                    f.all[k].collectionId,
                    f.inventory.bindings.bindings[k].bindings.rows[0].item.bindingHash,
                    1,
                    r.subjectStateHash,
                    r.statementHash,
                    f.inventory.provenance.origins[0].registry
                ),
                r
            );
            previous = r.recordHash;
        }
    }

    function _rows(Fixture memory f) private pure returns (bytes[] memory rows) {
        rows = new bytes[](f.all.length);
        for (uint256 k; k < rows.length; ++k) {
            rows[k] = abi.encode(f.all[k]);
        }
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.inventory.provenance = _provenance();
        f.scope.artists = new AH.Query[](2);
        f.scope.artists[0].artistId = FIRST;
        f.scope.artists[1].artistId = SECOND;
        f.scope.collections = new AH.Query[](3);
        f.inventory.bindings.bindings = new CB.Bundle[](3);
        f.inventory.bindings.generations = new A.Generation[][](3);
        f.inventory.bindings.collaborators = new T.CollaboratorRecord[][][](3);
        f.clocks.clocks.collections = new Timeline.Timeline[](3);
        f.all = new Original.Bundle[](3);
        for (uint256 k; k < 3; ++k) {
            uint256 generations = k == 0 ? 0 : k == 1 ? 2 : 1;
            G.Bundle memory binding;
            binding.collectionId = (k + 1) * 10;
            binding.provenanceCommitment =
                RH.ownerProvenanceHash(RH.ownerProvenance(f.inventory.provenance, 0), 0);
            binding.rows = new G.Row[](generations);
            f.inventory.bindings.bindings[k].corrections = new CS.Correction[](generations);
            f.inventory.bindings.generations[k] = new A.Generation[](generations);
            f.inventory.bindings.collaborators[k] = new T.CollaboratorRecord[][](generations);
            f.clocks.clocks.collections[k].attributionProposals = new RH.Point[](generations);
            f.clocks.clocks.collections[k].attributionCompletions = new RH.Point[](generations);
            for (uint256 g; g < generations; ++g) {
                T.Binding memory item;
                item.artistId = g == 0 ? FIRST : SECOND;
                item.artistAddress = address(uint160(101 + g));
                item.bindingHash = bytes32(k * 100 + g + 1);
                item.generation = uint64(g + 1);
                item.consentMode = 1;
                item.accepted = g == 0;
                binding.rows[g].item = item;
                f.inventory.bindings.generations[k][g] = A.Generation(
                    item.bindingHash, item.generation, item.accepted, RH.Point(0, 0, 0)
                );
                f.clocks.clocks.collections[k].attributionProposals[g] =
                    _point(f, 4, g == 1 ? 9 : k == 1 ? 2 : 5);
                if (item.accepted) {
                    f.clocks.clocks.collections[k].attributionCompletions[g] =
                        _point(f, 4, k == 1 ? 3 : 6);
                }
                binding.current = item;
            }
            binding.artistId = binding.current.artistId;
            binding.bindingHash = binding.current.bindingHash;
            f.inventory.bindings.bindings[k].bindings = binding;
            f.scope.collections[k].artistId = binding.artistId;
            f.scope.collections[k].collectionId = binding.collectionId;
            f.scope.collections[k].bindingHash = binding.bindingHash;
            f.all[k].artistId = binding.artistId;
            f.all[k].collectionId = binding.collectionId;
            f.all[k].bindingHash = binding.bindingHash;
            f.all[k].item.generation = uint64(generations);
            f.all[k].item.state = k == 0 ? 0 : k == 1 ? 1 : 2;
            f.all[k].records = new Pub.Row[](k == 0 ? 0 : 1);
        }
        f.all[1].records[0] = _credential(f.inventory.provenance.origins[0], 20, 0, 0);
        bytes32 first = f.all[1].records[0].attestation.record.recordHash;
        f.all[2].records[0] = _credential(f.inventory.provenance.origins[0], 30, first, 1);
        RH.JournalEntry[] memory journal = new RH.JournalEntry[](4);
        journal[0] = RH.JournalEntry(
            RH.Position(_point(f, 4, 1), 0), H.Receipt(10, 0, 10, bytes32(uint256(400)))
        );
        journal[1] =
            RH.JournalEntry(RH.Position(_point(f, 4, 4), 1), H.Receipt(24, FIRST, 20, first));
        journal[2] = RH.JournalEntry(
            RH.Position(_point(f, 4, 7), 2),
            H.Receipt(24, FIRST, 30, f.all[2].records[0].attestation.record.recordHash)
        );
        journal[3] = RH.JournalEntry(
            RH.Position(_point(f, 4, 8), 3), H.Receipt(44, FIRST, 20, bytes32(uint256(401)))
        );
        f.inventory.provenance.journals[4] = journal;
        f.inventory.provenance.eras[0].nativeCounts[4] = journal.length;
        f.scope.artists[0].records = new bytes32[](2);
        f.scope.artists[0].records[0] = first;
        f.scope.artists[0].records[1] = journal[2].receipt.recordHash;
        _commit(f);
    }

    function _commit(Fixture memory f) private pure {
        bytes32 commitment =
            RH.ownerProvenanceHash(RH.ownerProvenance(f.inventory.provenance, 4), 4);
        for (uint256 k; k < f.all.length; ++k) {
            f.all[k].provenance = commitment;
        }
    }

    function _credential(
        RH.OriginEnvironment memory o,
        uint256 collection,
        bytes32 previous,
        uint256 nonce
    ) private pure returns (Pub.Row memory r) {
        bytes32 identity = bytes32(uint256(501));
        r.attestation.statement =
            abi.encode(C2PA.Payload(1, FIRST, identity, previous, new C2PA.Credential[](0)));
        r.attestation.input.terms = T.Attestation(
            collection,
            10,
            FIRST,
            identity,
            SCHEMA,
            keccak256(r.attestation.statement),
            "urn:original:credential"
        );
        r.attestation.input.nonce = nonce;
        r.attestation.authorityClass = 1;
        T.AttestationRecord memory record;
        record.generation = 1;
        record.subjectStateHash = identity;
        record.schemaId = SCHEMA;
        record.statementHash = keccak256(r.attestation.statement);
        record.signer = address(0xA11);
        record.signedAt = 100;
        record.recordHash = Hashes.attestationRecordForAuthority(
            _environment(o),
            r.attestation.input.terms,
            FIRST,
            record.signer,
            1,
            nonce,
            record.signedAt
        );
        r.attestation.record = record;
    }

    function _identity(Fixture memory f) private pure returns (bytes[] memory identities) {
        identities = new bytes[](2);
        IH.Bundle memory primary;
        primary.artistId = FIRST;
        primary.signatures = new IH.SignatureRow[](2);
        f.inventory.provenance.aliases[2] = new RH.ReplayAlias[](6);
        for (uint256 k = 1; k < 3; ++k) {
            Pub.Row memory r = f.all[k].records[0];
            primary.signatures[k - 1].recordHash = r.attestation.record.recordHash;
            primary.signatures[k - 1].signature = hex"010203";
            bytes32 digest = Hashes.attestationDigest(
                _environment(f.inventory.provenance.origins[0]),
                r.attestation.input.terms,
                T.Authorization(r.attestation.input.nonce, 100, "")
            );
            _alias(
                f,
                (k - 1) * 3,
                uint64(k),
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(FIRST, r.attestation.input.nonce)),
                digest
            );
            _alias(
                f,
                (k - 1) * 3 + 1,
                uint64(k),
                keccak256("identity_authority.replay.attestation_key"),
                keccak256(abi.encode(r.attestation.record.recordHash)),
                r.attestation.record.recordHash
            );
            _alias(
                f,
                (k - 1) * 3 + 2,
                uint64(k),
                keccak256("identity_authority.replay.authorization_consumed_digest"),
                keccak256(abi.encode(FIRST, digest)),
                digest
            );
        }
        identities[0] = abi.encode(primary);
        IH.Bundle memory secondary;
        secondary.artistId = SECOND;
        identities[1] = abi.encode(secondary);
    }

    function _alias(
        Fixture memory f,
        uint256 index,
        uint64 revision,
        bytes32 surface,
        bytes32 scope,
        bytes32 value
    ) private pure {
        RH.ReplayAlias memory a;
        a.surface = surface;
        a.scope = scope;
        a.ownerIndex = 2;
        a.admittedAt = _point(f, 2, revision);
        a.cell.kind = 1;
        a.cell.status = 2;
        a.cell.commitment = value;
        a.cell.touchedRevision = revision;
        f.inventory.provenance.aliases[2][index] = a;
    }

    function _point(Fixture memory f, uint8 owner, uint64 revision)
        private
        pure
        returns (RH.Point memory)
    {
        return RH.Point(f.inventory.provenance.eras[0].originHash, owner, revision);
    }

    function _environment(RH.OriginEnvironment memory o)
        private
        pure
        returns (Hashes.Environment memory)
    {
        return Hashes.Environment(o.chainId, o.registry, o.core, o.manager);
    }

    function _provenance() private pure returns (RH.Provenance memory p) {
        p.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory o;
        o.chainId = 1;
        o.registry = address(1);
        o.coordinator = address(2);
        o.archive = address(3);
        o.core = address(4);
        o.manager = address(5);
        o.suiteConfigurationHash = bytes32(uint256(6));
        for (uint8 owner; owner < 7; ++owner) {
            o.owners[owner] = address(uint160(10 + owner));
            o.ownerCodeHashes[owner] = bytes32(uint256(20 + owner));
        }
        p.origins[0] = o;
        p.eras = new RH.Era[](1);
        p.eras[0].originHash = RH.originHash(o);
        for (uint8 owner; owner < 7; ++owner) {
            p.eras[0].checkpoints[owner].schema = RH.CHECKPOINT;
            p.eras[0].checkpoints[owner].ownerState =
                T.Snapshot(RH.ownerDomain(owner), 10, bytes32(uint256(1)), bytes32(uint256(2)));
        }
    }
}
