// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredMultipleDisputeUses as Uses
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeUses.sol";
import {
    StreamArtistRecoveredMultipleDisputeGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeGuards.sol";
import {
    StreamArtistRecoveredDisputeHistoryGuards as Original
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryGuards.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Focused aggregate worker predicates after source authentication; not op60 execution evidence.
contract StreamArtistRecoveredMultipleDisputeWorkersTest {
    bytes32 constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");

    function checkUses(Uses.Context calldata x) external pure returns (uint256[][] memory) {
        return Uses.validate(x);
    }

    function checkGuards(
        D.Bundle[] memory rows,
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks
    ) external pure {
        Guards.validate(rows, p, clocks);
    }

    function testMultipleDisputeSameNumericNonceForDifferentArtists() external pure {
        Uses.Context memory x = _uses();
        require(x.histories[0].disputes[0].record.nonce == x.histories[1].disputes[0].record.nonce);
        uint256[][] memory result = Uses.validate(x);
        require(result.length == 2 && result[0].length == 0 && result[1].length == 0);
    }

    function testMultipleDisputeRejectForeignArtistNonceLane() external view {
        Uses.Context memory x = _uses();
        x.provenance.aliases[2][2].scope = x.provenance.aliases[2][0].scope;
        _badUses(x);
    }

    function testMultipleDisputeRejectMissingConsumedBit() external view {
        Uses.Context memory x = _uses();
        IH.Bundle memory identity = abi.decode(x.identities[1], (IH.Bundle));
        identity.nonces[0].words[0].words[0] = 0;
        x.identities[1] = abi.encode(identity);
        _badUses(x);
    }

    function testMultipleDisputeRejectMissingOriginalSignature() external view {
        Uses.Context memory x = _uses();
        IH.Bundle memory identity = abi.decode(x.identities[0], (IH.Bundle));
        identity.signatures = new IH.SignatureRow[](0);
        x.identities[0] = abi.encode(identity);
        _badUses(x);
    }

    function testMultipleDisputeRejectOrphanedIdentityVeto() external view {
        Uses.Context memory x = _uses();
        x.provenance.journals[2] = new RH.JournalEntry[](2);
        x.provenance.journals[2][0].receipt.operation = 48;
        x.provenance.journals[2][1].receipt.operation = 48;
        _badUses(x);
    }

    function testMultipleDisputeRejectInventedIdentityWithdrawalRecord() external view {
        Uses.Context memory x = _uses();
        x.provenance.journals[2] = new RH.JournalEntry[](1);
        x.provenance.journals[2][0].receipt.operation = 61;
        _badUses(x);
    }

    function testMultipleDisputeInterleavedResolutionUsesOriginalOwnerClock() external pure {
        (D.Bundle[] memory rows, RH.OwnerProvenance memory p, Clocks.Result memory clocks) =
            _guards();
        require(rows[0].resolutions[0].point.ownerRevision == 7);
        require(rows[0].disputes[0].point.ownerRevision == 5);
        Guards.validate(rows, p, clocks);
    }

    function testMultipleDisputeRejectOpeningPlusOneResolution() external view {
        (D.Bundle[] memory rows, RH.OwnerProvenance memory p, Clocks.Result memory clocks) =
            _guards();
        rows[0].resolutions[0].point.ownerRevision = 6; // Other collection's original opening.
        _reseal(rows, p);
        _badGuards(rows, p, clocks);
    }

    function testMultipleDisputeRejectMissingRetainedAlias() external view {
        (D.Bundle[] memory rows, RH.OwnerProvenance memory p, Clocks.Result memory clocks) =
            _guards();
        delete p.aliases[3];
        _badGuards(rows, p, clocks);
    }

    function testMultipleDisputeRejectForeignGovernanceAlias() external view {
        (D.Bundle[] memory rows, RH.OwnerProvenance memory p, Clocks.Result memory clocks) =
            _guards();
        p.aliases[3].scope = keccak256("foreign original action");
        _badGuards(rows, p, clocks);
    }

    function testMultipleDisputeRejectOmittedCollectionHistory() external view {
        (D.Bundle[] memory rows, RH.OwnerProvenance memory p, Clocks.Result memory clocks) =
            _guards();
        rows[1].disputes = new D.DisputeRow[](0);
        rows[1].resolutions = new D.ResolutionRow[](0);
        _badGuards(rows, p, clocks);
    }

    function testMultipleDisputeRejectCrossOwnerResolutionClock() external view {
        (D.Bundle[] memory rows, RH.OwnerProvenance memory p, Clocks.Result memory clocks) =
            _guards();
        rows[1].resolutions[0].point.ownerIndex = 2;
        _badGuards(rows, p, clocks);
    }

    function _uses() private pure returns (Uses.Context memory x) {
        x.provenance = _provenance();
        x.identities = new bytes[](2);
        x.scope.artists = new AH.Query[](2);
        x.scope.collections = new AH.Query[](2);
        x.histories = new D.Bundle[](2);
        x.provenance.aliases[2] = new RH.ReplayAlias[](4);
        for (uint256 a; a < 2; ++a) {
            bytes32 artist = bytes32(a + 1);
            bytes32 record = keccak256(abi.encode("original dispute", a));
            bytes32 digest = keccak256(abi.encode("original digest", a));
            bytes32 bindingHash = keccak256(abi.encode("binding", a));
            x.scope.artists[a].artistId = artist;
            x.scope.collections[a] =
                AH.Query(artist, a + 1, bindingHash, new AH.PolicyKey[](0), new bytes32[](0));
            IH.Bundle memory identity;
            identity.artistId = artist;
            identity.signatures = new IH.SignatureRow[](1);
            identity.signatures[0].recordHash = record;
            identity.signatures[0].signature = hex"1234";
            identity.nonces = new IH.NonceLane[](1);
            identity.nonces[0].kind = 1;
            identity.nonces[0].key = artist;
            identity.nonces[0].words = new AH.NonceWord[](1);
            identity.nonces[0].words[0].words[0] = 1 << 7;
            x.identities[a] = abi.encode(identity);
            D.Bundle memory history = x.histories[a];
            history.artistId = artist;
            history.collectionId = a + 1;
            history.bindingHash = bindingHash;
            history.disputes = new D.DisputeRow[](1);
            history.disputes[0].record.recordHash = record;
            history.disputes[0].record.nonce = 7;
            history.disputes[0].point = RH.Point(x.provenance.eras[0].originHash, 4, uint64(5 + a));
            RH.Point memory admitted = RH.Point(x.provenance.eras[0].originHash, 2, uint64(5 + a));
            x.provenance.aliases[2][2 * a] =
                _alias(admitted, NONCE, keccak256(abi.encode(artist, uint256(7))), digest);
            x.provenance.aliases[2][2 * a + 1] =
                _alias(admitted, OBSERVED, keccak256(abi.encode(artist, digest)), digest);
        }
    }

    function _guards()
        private
        pure
        returns (D.Bundle[] memory rows, RH.OwnerProvenance memory p, Clocks.Result memory clocks)
    {
        RH.Provenance memory full = _provenance();
        p = RH.ownerProvenance(full, 4);
        p.eras[0].nativeCount = 2;
        p.eras[0].checkpoint.replayCount = 8;
        p.eras[0].checkpoint.replayRoot = keccak256("nonempty original replay root");
        rows = new D.Bundle[](2);
        clocks.collections = new G.Timeline[](2);
        clocks.counts = new uint256[](1);
        clocks.counts[0] = 4;
        p.journal = new RH.JournalEntry[](2);
        for (uint256 k; k < 2; ++k) {
            rows[k].collectionId = k + 1;
            rows[k].disputes = new D.DisputeRow[](1);
            rows[k].resolutions = new D.ResolutionRow[](1);
            D.DisputeRow memory opening = rows[k].disputes[0];
            opening.point = RH.Point(full.eras[0].originHash, 4, uint64(5 + k));
            opening.record.recordHash = keccak256(abi.encode("opening", k));
            opening.record.terms.disputeAction = 1;
            opening.record.terms.bindingGeneration = 1;
            opening.record.signer = address(uint160(k + 1));
            opening.record.governanceActionId = keccak256(abi.encode("governed open", k));
            rows[k].resolutions[0].point = RH.Point(full.eras[0].originHash, 4, uint64(7 + k));
            rows[k].resolutions[0].record.actionId = keccak256(abi.encode("resolve", k));
            rows[k].resolutions[0].record.terms.disputeRecordHash = opening.record.recordHash;
            p.journal[k].position.point = opening.point;
            clocks.collections[k].attributionProposals = new RH.Point[](1);
            clocks.collections[k].attributionCompletions = new RH.Point[](1);
            clocks.collections[k].attributionProposals[0] =
                RH.Point(full.eras[0].originHash, 4, uint64(2 * k + 1));
            clocks.collections[k].attributionCompletions[0] =
                RH.Point(full.eras[0].originHash, 4, uint64(2 * k + 2));
        }
        _reseal(rows, p);
    }

    function _reseal(D.Bundle[] memory rows, RH.OwnerProvenance memory p) private pure {
        p.aliases = new RH.ReplayAlias[](8);
        uint256 cursor;
        for (uint256 k; k < rows.length; ++k) {
            D.Guard[] memory guards = Original.guards(rows[k]);
            for (uint256 i; i < guards.length; ++i) {
                D.Guard memory g = guards[i];
                p.aliases[cursor++] = _alias(g.point, g.surface, g.scope, g.commitment);
            }
        }
    }

    function _alias(RH.Point memory point, bytes32 surface, bytes32 scope, bytes32 commitment)
        private
        pure
        returns (RH.ReplayAlias memory a)
    {
        a.originHash = point.environmentHash;
        a.ownerIndex = point.ownerIndex;
        a.surface = surface;
        a.scope = scope;
        a.admittedAt = point;
        a.cell.kind = 1;
        a.cell.status = 2;
        a.cell.commitment = commitment;
    }

    function _provenance() private pure returns (RH.Provenance memory p) {
        p.origins = new RH.OriginEnvironment[](1);
        p.eras = new RH.Era[](1);
        for (uint8 i; i < 7; ++i) {
            p.origins[0].owners[i] = address(uint160(0x100 + i));
            p.origins[0].ownerCodeHashes[i] = keccak256(abi.encode("owner", i));
            p.eras[0].checkpoints[i].schema = RH.CHECKPOINT;
            p.eras[0].checkpoints[i].ownerState =
                T.Snapshot(RH.ownerDomain(i), 8, bytes32(uint256(1)), bytes32(uint256(2)));
        }
        p.eras[0].originHash = RH.originHash(p.origins[0]);
    }

    function _badUses(Uses.Context memory x) private view {
        try this.checkUses(x) {
            revert("invalid aggregate authorization accepted");
        } catch { }
    }

    function _badGuards(
        D.Bundle[] memory rows,
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks
    ) private view {
        try this.checkGuards(rows, p, clocks) {
            revert("invalid aggregate guards accepted");
        } catch { }
    }
}
