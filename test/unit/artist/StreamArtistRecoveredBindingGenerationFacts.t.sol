// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredBindingGenerationFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerationFacts.sol";
import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Synthetic pure vectors for the cross-owner join, not complete certificates or real
/// admissions. The generation codec separately authenticates original hashes/maps/replay and
/// full owner checkpoints. Actual-owner hosts cover signatures, nonce inventories and imports.
contract StreamArtistRecoveredBindingGenerationFactsTest {
    struct Fixture {
        IH.Bundle identity;
        Generations.Bundle bindings;
        AH.Query query;
        RH.Provenance provenance;
    }

    function check(Fixture memory f) external pure {
        Facts.validate(f.identity, f.bindings, f.query, f.provenance);
    }

    function testGenerationFactsMixedRefusalWithdrawalAndFinalAcceptance() external pure {
        Fixture memory f = _fixture(3, true);
        Facts.validate(f.identity, f.bindings, f.query, f.provenance);
        assert(f.bindings.rows[0].terminal.kind == 1);
        assert(f.bindings.rows[1].terminal.kind == 2);
        assert(f.provenance.journals[3][0].position.point.ownerRevision == 1);
        assert(f.provenance.journals[0][3].position.point.ownerRevision == 5);
        assert(f.identity.identity.authorityAddress != f.bindings.rows[0].item.artistAddress);
    }

    function testGenerationFactsWithdrawalsNeedOnlyFinalAcceptanceSignature() external pure {
        Fixture memory f = _fixture(3, false);
        Facts.validate(f.identity, f.bindings, f.query, f.provenance);
        assert(f.identity.signatures.length == 1);
        assert(f.provenance.journals[0].length == 3);
    }

    function testGenerationFactsRetainedDocumentsIgnoreCurrentPrincipalAndClass() external pure {
        Fixture memory f = _fixture(3, true);
        Facts.validate(f.identity, f.bindings, f.query, f.provenance);
        f.identity.identity.authorityClass = 3;
        f.identity.identity.authorityAddress = address(5555);
        f.identity.identity.identityRecordHash = keccak256("original registration, not operative");
        Facts.validate(f.identity, f.bindings, f.query, f.provenance);
    }

    function testGenerationFactsExactDocumentOmissionCorruptionAndDuplicates() external view {
        Fixture memory f = _fixture(3, true);
        this.check(f);
        f.identity.documents[0].documentHash = keccak256("unrelated");
        _reject(f);
        f = _fixture(3, true);
        f.identity.documents[0].document = bytes("changed original document");
        _reject(f);
        f = _fixture(3, true);
        IH.DocumentRow[] memory rows = new IH.DocumentRow[](4);
        for (uint256 i; i < 3; ++i) {
            rows[i] = f.identity.documents[i];
        }
        rows[3] = f.identity.documents[0];
        f.identity.documents = rows;
        _reject(f);
        this.check(_fixture(3, true));
    }

    function testGenerationFactsEmptyOpaqueAndOriginalMaximumSignature() external view {
        Fixture memory f = _fixture(3, true);
        assert(f.identity.signatures[0].signature.length == 0);
        assert(f.identity.signatures[1].signature.length == 2);
        this.check(f);
        f.identity.signatures[0].signature = new bytes(4096);
        this.check(f);
        f.identity.signatures[0].signature = new bytes(4097);
        _reject(f);
        f.identity.signatures[0].signature = bytes("");
        this.check(f);
    }

    function testGenerationFactsMissingRefusalOrAcceptanceSignatureRejects() external view {
        Fixture memory f = _fixture(3, true);
        this.check(f);
        f.identity.signatures[0].recordHash = keccak256("wrong refusal");
        _reject(f);
        f = _fixture(3, true);
        f.identity.signatures[1].recordHash = keccak256("wrong acceptance");
        _reject(f);
        this.check(_fixture(3, true));
    }

    function testGenerationFactsDuplicateSignatureCannotStandForAnotherRecord() external view {
        Fixture memory f = _fixture(3, true);
        this.check(f);
        IH.SignatureRow[] memory rows = new IH.SignatureRow[](3);
        rows[0] = f.identity.signatures[0];
        rows[1] = f.identity.signatures[1];
        rows[2] = rows[0];
        f.identity.signatures = rows;
        _reject(f);
    }

    function testGenerationFactsScopeGenerationAndCurrentHeadJoins() external view {
        Fixture memory f = _fixture(3, true);
        this.check(f);
        f.identity.artistId = keccak256("other Artist");
        _reject(f);
        f = _fixture(3, true);
        f.bindings.rows[1].item.generation = 7;
        _reject(f);
        f = _fixture(3, true);
        f.bindings.current.proposer = address(7777);
        _reject(f);
        f = _fixture(3, true);
        f.bindings.collectionId = 8;
        _reject(f);
    }

    function testGenerationFactsNativeScopeAndExactRefusalOccurrence() external view {
        Fixture memory f = _fixture(3, true);
        this.check(f);
        f.provenance.journals[0][1].receipt.recordHash = keccak256("missing original refusal");
        _reject(f);
        f = _fixture(3, true);
        f.provenance.journals[0][1].receipt.collectionId = 8;
        _reject(f);
        f = _fixture(3, true);
        f.provenance.journals[0][1].receipt.operation = 4;
        _reject(f);
        f = _fixture(3, true);
        f.provenance.journals[0][2].receipt.recordHash = f.bindings.rows[0].terminal.recordHash;
        _reject(f);
    }

    function testGenerationFactsRefusalMustFollowItsActualProposal() external view {
        Fixture memory f = _fixture(3, true);
        this.check(f);
        f.provenance.journals[0][1].position.point.ownerRevision = 1;
        _reject(f);
        f.provenance.journals[0][1].position.point.ownerRevision = 2;
        this.check(f);
    }

    function testGenerationFactsNoSyntheticIdentityOrAttributionNativeReceipts() external view {
        Fixture memory f = _fixture(3, true);
        this.check(f);
        for (uint16 op = 2; op <= 4; ++op) {
            f.provenance.journals[2] = new RH.JournalEntry[](1);
            f.provenance.journals[2][0] = _row(f, 2, 1, 0, op, bytes32(uint256(op)));
            _reject(f);
        }
        f.provenance.journals[2] = new RH.JournalEntry[](0);
        f.provenance.journals[4] = new RH.JournalEntry[](1);
        f.provenance.journals[4][0] = _row(f, 4, 1, 0, 3, f.bindings.rows[0].terminal.recordHash);
        _reject(f);
        this.check(_fixture(3, true));
    }

    function testGenerationFactsRepeatedImportKeepsOriginalAcceptanceEra() external view {
        Fixture memory f = _fixture(3, true);
        this.check(f);
        // A's proposal revision5 and acceptance revision1 retain their separate clocks even
        // after B/C imports. This is not a fabricated rebased destination acceptance receipt.
        f.provenance.journals[3][0].position.point.environmentHash = f.provenance.eras[1].originHash;
        _reject(f);
        f.provenance.journals[3][0].position.point.environmentHash = f.provenance.eras[0].originHash;
        this.check(f);
    }

    function testGenerationFactsSoleAcceptanceAndBounds() external view {
        Fixture memory f = _fixture(2, false);
        this.check(f);
        this.check(_fixture(128, false));
        _reject(_fixture(1, false));
        _reject(_fixture(129, false));
        f.provenance.journals[3] = new RH.JournalEntry[](0);
        _reject(f);
        f = _fixture(2, false);
        RH.JournalEntry[] memory rows = new RH.JournalEntry[](2);
        rows[0] = f.provenance.journals[3][0];
        rows[1] = rows[0];
        f.provenance.journals[3] = rows;
        _reject(f);
    }

    function _reject(Fixture memory f) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(abi.encodeCall(this.check, (f)));
        assert(!ok);
        assert(
            keccak256(reason)
                == keccak256(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector))
        );
    }

    function _fixture(uint256 count, bool refusal) private pure returns (Fixture memory f) {
        f.query.artistId = keccak256("same Artist");
        f.query.collectionId = 7;
        f.query.bindingHash = keccak256(abi.encode("proposal", count));
        f.identity.artistId = f.query.artistId;
        f.identity.identity.authorityAddress = address(9999);
        f.identity.identity.authorityClass = 1;
        f.bindings.artistId = f.query.artistId;
        f.bindings.collectionId = f.query.collectionId;
        f.bindings.bindingHash = f.query.bindingHash;
        f.bindings.rows = new Generations.Row[](count);
        f.identity.documents = new IH.DocumentRow[](count);
        f.provenance.origins = new RH.OriginEnvironment[](3);
        f.provenance.eras = new RH.Era[](3);
        for (uint256 i; i < 3; ++i) {
            RH.OriginEnvironment memory origin;
            origin.chainId = 1;
            origin.registry = address(uint160(100 + i));
            for (uint8 owner; owner < 7; ++owner) {
                origin.owners[owner] = address(uint160(200 + 10 * i + owner));
                origin.ownerCodeHashes[owner] = keccak256("synthetic owner runtime");
                f.provenance.eras[i].checkpoints[owner].schema = RH.CHECKPOINT;
                f.provenance.eras[i].checkpoints[owner].ownerState.domainId = RH.ownerDomain(owner);
                f.provenance.eras[i].checkpoints[owner].ownerState.revision = i == 0 ? 1000 : 1;
            }
            f.provenance.origins[i] = origin;
            f.provenance.eras[i].originHash = RH.originHash(origin);
        }
        uint256 extra = refusal ? 1 : 0;
        f.provenance.journals[0] = new RH.JournalEntry[](count + extra);
        uint256 at;
        for (uint256 i; i < count; ++i) {
            bytes memory document = abi.encode("original document", i);
            f.identity.documents[i] = IH.DocumentRow(keccak256(document), document);
            Generations.Row memory row;
            row.item.artistId = f.query.artistId;
            row.item.artistAddress = address(uint160(1000 + i));
            row.item.identityRecordHash = keccak256(document);
            row.item.bindingHash = keccak256(abi.encode("proposal", i + 1));
            row.item.generation = uint64(i + 1);
            row.item.consentMode = 1;
            row.item.proposer = address(8888);
            row.item.accepted = i + 1 == count;
            f.provenance.journals[0][at] =
                _row(f, 0, uint64(2 * i + 1), at, 1, row.item.bindingHash);
            ++at;
            if (i + 1 != count) {
                row.terminal.reasonHash = keccak256(abi.encode("reason", i));
                row.terminal.kind = i == 0 && refusal ? 1 : 2;
                if (row.terminal.kind == 1) {
                    row.terminal.recordHash = keccak256("original refusal");
                    f.provenance.journals[0][at] = _row(f, 0, 2, at, 3, row.terminal.recordHash);
                    ++at;
                }
            }
            f.bindings.rows[i] = row;
        }
        // ABI roundtrip prevents a mutable in-memory current-head alias to the last row.
        f.bindings.current = abi.decode(abi.encode(f.bindings.rows[count - 1].item), (T.Binding));
        bytes32 acceptance = keccak256("original final acceptance");
        f.provenance.journals[3] = new RH.JournalEntry[](1);
        f.provenance.journals[3][0] = _row(f, 3, 1, 0, 2, acceptance);
        f.identity.signatures = new IH.SignatureRow[](1 + extra);
        if (refusal) f.identity.signatures[0] = IH.SignatureRow(keccak256("original refusal"), "");
        f.identity.signatures[extra] = IH.SignatureRow(acceptance, hex"1234");
    }

    function _row(
        Fixture memory f,
        uint8 owner,
        uint64 revision,
        uint256 index,
        uint16 operation,
        bytes32 record
    ) private pure returns (RH.JournalEntry memory) {
        return RH.JournalEntry(
            RH.Position(RH.Point(f.provenance.eras[0].originHash, owner, revision), index),
            H.Receipt(operation, f.query.artistId, f.query.collectionId, record)
        );
    }
}
