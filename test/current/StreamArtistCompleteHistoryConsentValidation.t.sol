// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryConsentValidation as Validation
} from "../../smart-contracts/domains/artist/StreamArtistCompleteHistoryConsentValidation.sol";
import {
    StreamArtistCompleteHistoryTypes as CT
} from "../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Old
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as BG
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    IStreamArtistEconomicsEvidence as Economics
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    StreamArtistHistoryTypes as History
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistSanctionConfirmationTypes as Confirmation
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import {
    StreamArtistEconomicsAssociation as Association
} from "../../smart-contracts/domains/artist/StreamArtistEconomicsAssociation.sol";
import {
    StreamArtistSaleHashes as SaleHashes
} from "../../smart-contracts/domains/artist/StreamArtistSaleHashes.sol";
import {
    StreamArtistHashes as Hashes
} from "../../smart-contracts/domains/artist/StreamArtistHashes.sol";

/// @dev Canonical synthetic owner6 certificates for pure family validation and typed source tests.
/// No original owners, signatures, binding chronology or Archive bytes are authenticated here.
/// Those remain explicit fixed-caller boundaries; no mocked validator or filtered certificate is used.
abstract contract CompleteHistoryConsentValidationFixture {
    bytes32 internal constant CH_A = bytes32(uint256(11));
    bytes32 internal constant CH_B = bytes32(uint256(22));
    bytes32 internal constant CH_C = bytes32(uint256(33));

    struct Fixture {
        G.Consents[] all;
        T.RatificationRecord[][] ratifications;
        M.State scope;
        CT.Inventory inventory;
        bytes sanctions;
    }

    function _chFixture(address consent, bool includeSanctions)
        internal
        pure
        returns (Fixture memory f)
    {
        f.all = new G.Consents[](2);
        f.ratifications = new T.RatificationRecord[][](2);
        f.scope.artists = new AH.Query[](3);
        f.scope.artists[0].artistId = CH_A;
        f.scope.artists[1].artistId = CH_B;
        f.scope.artists[2].artistId = CH_C;
        f.scope.collections = new AH.Query[](2);
        f.scope.collections[0].artistId = CH_C;
        f.scope.collections[0].collectionId = 1;
        f.scope.collections[0].bindingHash = bytes32(uint256(103));
        f.scope.collections[1].collectionId = 2; // True U, never a former bound Artist projected away.
        f.inventory.bindings.bindings = new CB.Bundle[](2);
        f.inventory.bindings.generations = new A.Generation[][](2);
        f.all[0].bindings = new T.Binding[](3);
        f.inventory.bindings.bindings[0].bindings.rows = new BG.Row[](3);
        f.inventory.bindings.generations[0] = new A.Generation[](3);
        for (uint256 i; i < 3; ++i) {
            T.Binding memory b;
            b.artistId = f.scope.artists[i].artistId;
            b.artistAddress = address(uint160(501 + i));
            b.bindingHash = bytes32(uint256(101 + i));
            b.generation = uint64(i + 1);
            b.consentMode = 1;
            b.accepted = i < 2;
            f.all[0].bindings[i] = b;
            // Copies prevent mutation of one purported certificate from silently rewriting another.
            f.inventory.bindings.bindings[0].bindings.rows[i].item =
                abi.decode(abi.encode(b), (T.Binding));
            f.inventory.bindings.generations[0][i] =
                A.Generation(b.bindingHash, b.generation, b.accepted, RH.Point(0, 0, 0));
        }
        f.inventory.bindings.bindings[0].bindings.current =
            abi.decode(abi.encode(f.all[0].bindings[2]), (T.Binding));
        for (uint256 k; k < 2; ++k) {
            f.all[k].rows.original.artistId = f.scope.collections[k].artistId;
            f.all[k].rows.original.collectionId = k + 1;
            f.all[k].rows.original.bindingHash = f.scope.collections[k].bindingHash;
        }
        f.scope.collections[0].policies = new AH.PolicyKey[](1);
        f.scope.collections[0].policies[0] =
            AH.PolicyKey(bytes32(uint256(81)), bytes32(uint256(82)));
        f.all[0].rows.original.keys =
            abi.decode(abi.encode(f.scope.collections[0].policies), (AH.PolicyKey[]));
        f.all[0].rows.original.policies = new DH.Policy[](1);
        f.all[0].rows.original.policies[0] = DH.Policy(bytes32(uint256(901)), 0);
        f.all[0].rows.original.economics = new Base.Economics[](2);
        T.EconomicsConsent memory terms =
            T.EconomicsConsent(1, address(700), bytes32(uint256(701)), 0, 0, bytes32(uint256(702)));
        for (uint256 i; i < 2; ++i) {
            T.Binding memory b = f.all[0].bindings[i];
            f.all[0].rows.original.economics[i].item = EH.Row(
                bytes32(uint256(902 + i)),
                terms,
                Economics.Association(
                    b.artistId,
                    b.generation,
                    b.bindingHash,
                    keccak256(abi.encode(terms)),
                    bytes32(uint256(902))
                )
            );
        }
        f.all[0].rows.original.sales = new DH.Sale[](1);
        Sale.Record memory sale;
        sale.terms = Sale.Consent(1, address(710), bytes32(uint256(711)), bytes32(uint256(712)));
        sale.artistId = CH_B;
        sale.signer = address(502);
        sale.authorityClass = 1;
        sale.nonce = 7;
        sale.signedAt = 8;
        sale.bindingGeneration = 2;
        sale.bindingHash = f.all[0].bindings[1].bindingHash;
        sale.recordHash = SaleHashes.record(
            Hashes.Environment(31337, address(101), address(104), address(105)),
            sale.terms,
            sale.artistId,
            sale.signer,
            sale.authorityClass,
            sale.nonce,
            sale.signedAt
        );
        f.all[0].rows.original.sales[0] = DH.Sale(sale, 0, sale.recordHash);
        f.all[0].rows.consents = new ContentOwner.ConsentRecord[](1);
        f.all[0].rows.consents[0] = ContentOwner.ConsentRecord(
            bytes32(uint256(905)),
            CH_A,
            1,
            Content.Consent(1, address(720), bytes32(uint256(721)), bytes32(uint256(722))),
            1
        );
        f.all[0].rows.royalties = new ContentH.Royalty[](1);
        f.all[0].rows.royalties[0] = ContentH.Royalty(
            T.RoyaltyFreeze(address(730), 1, keccak256("ROYALTY_ERC2981"), bytes32(uint256(731))),
            T.RoyaltyFreezeRecord(bytes32(uint256(906)), CH_B, 2),
            0
        );
        f.all[0].rows.freezes = new Content.FreezeRecord[](1);
        bytes32[] memory locks = new bytes32[](1);
        locks[0] = bytes32(uint256(741));
        f.all[0].rows.freezes[0] = Content.FreezeRecord(
            bytes32(uint256(907)), CH_A, 1, address(740), locks, bytes32(uint256(742)), 1
        );
        f.ratifications[0] = new T.RatificationRecord[](2);
        f.ratifications[0][0] =
            T.RatificationRecord(bytes32(uint256(908)), bytes32(uint256(751)), address(750));
        f.ratifications[0][1] =
            T.RatificationRecord(bytes32(uint256(909)), bytes32(uint256(752)), address(750));
        f.ratifications[1] = new T.RatificationRecord[](0);
        _chProvenance(f, consent, includeSanctions);
        _chCommit(f);
    }

    function _chProvenance(Fixture memory f, address consent, bool sanctioned) private pure {
        RH.OriginEnvironment memory o;
        o.chainId = 31337;
        o.registry = address(101);
        o.coordinator = address(102);
        o.archive = address(103);
        o.core = address(104);
        o.manager = address(105);
        o.suiteConfigurationHash = bytes32(uint256(106));
        for (uint8 i; i < 7; ++i) {
            o.owners[i] = address(uint160(200 + i));
            o.ownerCodeHashes[i] = bytes32(uint256(300 + i));
        }
        o.owners[6] = consent;
        f.inventory.provenance.origins = new RH.OriginEnvironment[](1);
        f.inventory.provenance.origins[0] = o;
        f.inventory.provenance.eras = new RH.Era[](1);
        RH.Era memory era;
        era.originHash = RH.originHash(o);
        uint256 count = sanctioned ? 10 : 9;
        uint256 mutations = sanctioned ? 11 : 9;
        era.checkpoints[6].schema = RH.CHECKPOINT;
        era.checkpoints[6].ownerState = T.Snapshot(
            RH.ownerDomain(6), uint64(mutations), bytes32(uint256(401)), bytes32(uint256(402))
        );
        era.checkpoints[6].replayCount = mutations;
        era.checkpoints[6].replayRoot = bytes32(uint256(403));
        era.nativeCounts[6] = count;
        f.inventory.provenance.eras[0] = era;
        f.inventory.provenance.journals[6] = new RH.JournalEntry[](count);
        f.inventory.provenance.aliases[6] = new RH.ReplayAlias[](mutations);
        uint16[9] memory operations = [uint16(14), 15, 15, 16, 17, 20, 21, 52, 52];
        bytes32[9] memory artists = [CH_A, CH_A, CH_B, CH_B, CH_A, CH_B, CH_A, CH_A, CH_B];
        for (uint256 i; i < 9; ++i) {
            bytes32 record = i == 3
                ? f.all[0].rows.original.sales[0].item.recordHash
                : bytes32(uint256(901 + i));
            RH.Point memory point = RH.Point(era.originHash, 6, uint64(i + 1));
            f.inventory.provenance.journals[6][i] = RH.JournalEntry(
                RH.Position(point, i), History.Receipt(operations[i], artists[i], 1, record)
            );
            (bytes32 surface, bytes32 scope_) = _chReplay(f, i);
            f.inventory.provenance.aliases[6][i] = _chAlias(o, point, surface, scope_, record);
        }
        if (sanctioned) {
            H.Inventory memory h;
            h.catalogues = new H.Catalogue[](1);
            h.operations = new H.OperationEvidence[](2);
            h.sanctions = new H.SanctionRow[](1);
            h.confirmations = new H.ConfirmationRow[](1);
            h.sanctions[0].point = RH.Point(era.originHash, 6, 10);
            h.sanctions[0].record.recordHash = bytes32(uint256(910));
            h.sanctions[0].record.artistId = CH_A;
            h.sanctions[0].record.signer = address(501);
            h.sanctions[0].record.authorityClass = 1;
            h.sanctions[0].record.terms.collectionId = 1;
            h.sanctions[0].record.signedAt = 8;
            h.sanctions[0].record.deadline = 9;
            h.sanctions[0].record.bindingGeneration = 1;
            h.sanctions[0].record.bindingHash = f.all[0].bindings[0].bindingHash;
            h.confirmations[0].consentPoint = RH.Point(era.originHash, 6, 11);
            h.confirmations[0].transition = Confirmation.Transition(
                1, CH_A, 1, bytes32(uint256(910)), bytes32(uint256(911)), 2
            );
            f.inventory.provenance.journals[6][9] = RH.JournalEntry(
                RH.Position(h.sanctions[0].point, 9),
                History.Receipt(12, CH_A, 1, bytes32(uint256(910)))
            );
            f.inventory.provenance.aliases[6][9] = _chAlias(
                o,
                h.sanctions[0].point,
                H.SANCTION,
                keccak256(abi.encode(bytes32(uint256(910)))),
                bytes32(uint256(910))
            );
            f.inventory.provenance.aliases[6][10] = _chAlias(
                o,
                h.confirmations[0].consentPoint,
                H.CONFIRMATION,
                Confirmation.scope(h.confirmations[0].transition),
                bytes32(uint256(910))
            );
            f.sanctions = abi.encode(h);
        }
        _chSort(f.inventory.provenance.aliases[6]);
    }

    function _chReplay(Fixture memory f, uint256 i)
        private
        pure
        returns (bytes32 surface, bytes32 scope_)
    {
        if (i == 0) {
            return (
                keccak256("consent_finality.replay.policy_consent_key"),
                keccak256(abi.encode(uint256(1), bytes32(uint256(81)), bytes32(uint256(82))))
            );
        }
        if (i == 1) {
            return (
                keccak256("consent_finality.replay.consent_key"),
                f.all[0].rows.original.economics[0].item.association.payloadHash
            );
        }
        if (i == 2) {
            return (
                keccak256("consent_finality.replay.consent_key"),
                Association.continuation(
                    bytes32(uint256(902)),
                    f.all[0].rows.original.economics[1].item.terms,
                    f.all[0].bindings[1]
                )
            );
        }
        if (i == 3) {
            Sale.Record memory r = f.all[0].rows.original.sales[0].item;
            return (
                keccak256("consent_finality.replay.sale_consent_key"),
                keccak256(abi.encode(r.terms, r.bindingGeneration, r.bindingHash))
            );
        }
        if (i == 4) {
            ContentOwner.ConsentRecord memory r = f.all[0].rows.consents[0];
            return (
                keccak256("consent_finality.replay.content_consent_key"),
                keccak256(
                    abi.encode(keccak256(abi.encode(r.terms, r.bindingGeneration)), r.recordHash)
                )
            );
        }
        if (i == 5) {
            ContentH.Royalty memory r = f.all[0].rows.royalties[0];
            return (
                keccak256("consent_finality.replay.freeze_key"),
                keccak256(abi.encode(r.terms, r.item.artistId, r.item.bindingGeneration))
            );
        }
        if (i == 6) {
            return (
                keccak256("consent_finality.replay.freeze_key"),
                keccak256(
                    abi.encode(keccak256("CONTENT"), uint256(1), uint64(1), bytes32(uint256(907)))
                )
            );
        }
        return (
            keccak256("consent_finality.replay.ratification_key"),
            keccak256(abi.encode(uint256(1), bytes32(uint256(901 + i))))
        );
    }

    function _chAlias(
        RH.OriginEnvironment memory o,
        RH.Point memory point,
        bytes32 surface,
        bytes32 scope_,
        bytes32 record
    ) internal pure returns (RH.ReplayAlias memory a) {
        a.originHash = RH.originHash(o);
        a.ownerIndex = 6;
        a.surface = surface;
        a.scope = scope_;
        a.admittedAt = point;
        a.cell = T.ReplayCell(record, point.ownerRevision, 1, 2);
        a.originalKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[6],
                RH.ownerDomain(6),
                surface,
                scope_
            )
        );
    }

    function _chSort(RH.ReplayAlias[] memory rows) internal pure {
        for (uint256 i; i < rows.length; ++i) {
            for (uint256 j = i + 1; j < rows.length; ++j) {
                if (rows[j].originalKey < rows[i].originalKey) {
                    RH.ReplayAlias memory saved = rows[i];
                    rows[i] = rows[j];
                    rows[j] = saved;
                }
            }
        }
    }

    function _chCommit(Fixture memory f) internal pure {
        bytes32 hash = RH.ownerProvenanceHash(RH.ownerProvenance(f.inventory.provenance, 6), 6);
        for (uint256 i; i < f.all.length; ++i) {
            f.all[i].rows.original.provenance = hash;
        }
    }

    function _chCopy(Fixture memory f) internal pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }
}

contract StreamArtistCompleteHistoryConsentValidationTest is
    CompleteHistoryConsentValidationFixture
{
    function check(Fixture memory f) external pure {
        Validation.validate(f.all, f.ratifications, f.scope, f.inventory, f.sanctions);
    }

    function oldCheck(Fixture memory f) external pure {
        Old.validate(
            f.all,
            f.ratifications,
            f.scope.collections,
            RH.ownerProvenance(f.inventory.provenance, 6)
        );
    }

    function testHistoricalArtistsAllConsentFamiliesAllowPendingCurrentHeadAndTrueUnbound()
        external
        view
    {
        Fixture memory f = _chFixture(address(206), false);
        this.check(f);
        _reject(abi.encodeCall(this.oldCheck, (f)));
        assert(f.all[0].rows.original.artistId == CH_C && !f.all[0].bindings[2].accepted);
        assert(f.all[1].bindings.length == 0 && f.scope.collections[1].artistId == 0);
    }

    function testCompletelyUnboundEmptyConsentOwnerNeedsNoInventedPrincipal() external view {
        Fixture memory f = _chFixture(address(206), false);
        f.scope.artists = new AH.Query[](0);
        f.scope.collections = new AH.Query[](1);
        f.scope.collections[0].collectionId = 2;
        f.all = new G.Consents[](1);
        f.all[0].rows.original.collectionId = 2;
        f.ratifications = new T.RatificationRecord[][](1);
        f.inventory.bindings.bindings = new CB.Bundle[](1);
        f.inventory.bindings.generations = new A.Generation[][](1);
        f.inventory.provenance.journals[6] = new RH.JournalEntry[](0);
        f.inventory.provenance.aliases[6] = new RH.ReplayAlias[](0);
        f.inventory.provenance.eras[0].nativeCounts[6] = 0;
        f.inventory.provenance.eras[0].checkpoints[6].ownerState.revision = 0;
        f.inventory.provenance.eras[0].checkpoints[6].replayCount = 0;
        f.inventory.provenance.eras[0].checkpoints[6].replayRoot = 0;
        _chCommit(f);
        this.check(f);
        f.ratifications[0] = new T.RatificationRecord[](1);
        f.ratifications[0][0] =
            T.RatificationRecord(bytes32(uint256(1)), bytes32(uint256(2)), address(3));
        _reject(abi.encodeCall(this.check, (f)));
    }

    function testCurrentWrapperCannotBeRelabeledToHistoricalArtist() external view {
        Fixture memory f = _chFixture(address(206), false);
        Fixture memory changed = _chCopy(f);
        changed.all[0].rows.original.artistId = CH_A;
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        changed.all[0].bindings[0].artistId = CH_B;
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testSavedContentGenerationMustOwnItsOriginalArtist() external view {
        Fixture memory f = _chFixture(address(206), false);
        Fixture memory changed = _chCopy(f);
        changed.all[0].rows.consents[0].artistId = CH_B;
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        changed.all[0].rows.royalties[0].item.bindingGeneration = 1;
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        changed.all[0].rows.freezes[0].artistId = CH_C;
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testEconomicsContinuationKeepsFirstOriginalAcrossChangedArtist() external view {
        Fixture memory f = _chFixture(address(206), false);
        this.check(f);
        Fixture memory changed = _chCopy(f);
        changed.all[0].rows.original.economics[1].item.association.originalRecord =
            bytes32(uint256(903));
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        changed.all[0].rows.original.economics[1].item.association.artistId = CH_A;
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        changed.inventory.provenance.journals[6][2].receipt.artistId = CH_A;
        _chCommit(changed);
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testSaleSavedBindingAndReceiptArtistCannotFollowCurrentHead() external view {
        Fixture memory f = _chFixture(address(206), false);
        Fixture memory changed = _chCopy(f);
        changed.all[0].rows.original.sales[0].item.bindingGeneration = 1;
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        changed.inventory.provenance.journals[6][3].receipt.artistId = CH_C;
        _chCommit(changed);
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testGenerationlessPolicyAndRatificationRequireActualHistoricalPrincipal()
        external
        view
    {
        Fixture memory f = _chFixture(address(206), false);
        for (uint256 i; i < 2; ++i) {
            Fixture memory changed = _chCopy(f);
            changed.inventory.provenance.journals[6][i == 0 ? 0 : 7].receipt.artistId = CH_C;
            _chCommit(changed);
            _reject(abi.encodeCall(this.check, (changed)));
        }
        this.check(f);
    }

    function testCompleteCensusRejectsOmittedRowsBadAliasesAndExtraMutations() external view {
        Fixture memory f = _chFixture(address(206), false);
        Fixture memory changed = _chCopy(f);
        changed.ratifications[0] = new T.RatificationRecord[](1);
        changed.ratifications[0][0] = f.ratifications[0][0];
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        changed.inventory.provenance.aliases[6][0].cell.commitment = bytes32(uint256(9999));
        _chCommit(changed);
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        ++changed.inventory.provenance.eras[0].checkpoints[6].ownerState.revision;
        _chCommit(changed);
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testZeroNativeConfirmationSharesOneGlobalSanctionAndConsentCensus() external view {
        Fixture memory f = _chFixture(address(206), true);
        this.check(f);
        assert(f.inventory.provenance.journals[6].length == 10);
        assert(f.inventory.provenance.eras[0].checkpoints[6].ownerState.revision == 11);
        Fixture memory changed = _chCopy(f);
        changed.sanctions = "";
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testSanctionInventoryIsCanonicalAndCannotBorrowCurrentPrincipal() external view {
        Fixture memory f = _chFixture(address(206), true);
        Fixture memory changed = _chCopy(f);
        changed.sanctions = bytes.concat(f.sanctions, hex"00");
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        H.Inventory memory h = abi.decode(changed.sanctions, (H.Inventory));
        h.sanctions[0].record.artistId = CH_C;
        changed.sanctions = abi.encode(h);
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testConfirmationCannotDisappearReuseNativeClockOrChangeSanctionSubject()
        external
        view
    {
        Fixture memory f = _chFixture(address(206), true);
        Fixture memory changed = _chCopy(f);
        H.Inventory memory h = abi.decode(changed.sanctions, (H.Inventory));
        h.confirmations = new H.ConfirmationRow[](0);
        changed.sanctions = abi.encode(h);
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        h = abi.decode(changed.sanctions, (H.Inventory));
        h.confirmations[0].consentPoint.ownerRevision = 10;
        changed.sanctions = abi.encode(h);
        _reject(abi.encodeCall(this.check, (changed)));
        changed = _chCopy(f);
        h = abi.decode(changed.sanctions, (H.Inventory));
        h.confirmations[0].transition.artistId = CH_B;
        changed.sanctions = abi.encode(h);
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testUnknownNativeOperationNeverFallsBackAndExactInputCanRetry() external view {
        Fixture memory f = _chFixture(address(206), false);
        Fixture memory changed = _chCopy(f);
        changed.inventory.provenance.journals[6][0].receipt.operation = 13;
        _chCommit(changed);
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function testRepeatedEraRetainsEveryAliasAtItsOriginalAdmissionPoint() external view {
        Fixture memory f = _chFixture(address(206), false);
        RH.Provenance memory p = f.inventory.provenance;
        RH.OriginEnvironment memory original = p.origins[0];
        RH.Era memory first = p.eras[0];
        RH.ReplayAlias[] memory originalAliases = p.aliases[6];
        RH.OriginEnvironment memory next = abi.decode(abi.encode(original), (RH.OriginEnvironment));
        next.registry = address(1001);
        next.coordinator = address(1002);
        next.archive = address(1003);
        for (uint8 i; i < 7; ++i) {
            next.owners[i] = address(uint160(1200 + i));
        }
        p.origins = new RH.OriginEnvironment[](2);
        p.origins[0] = original;
        p.origins[1] = next;
        p.eras = new RH.Era[](2);
        p.eras[0] = first;
        p.eras[1].originHash = RH.originHash(next);
        p.eras[1].priorImportCommitment = bytes32(uint256(9001));
        p.eras[1].lowerRevisions[6] = 1;
        p.eras[1].checkpoints[6] = abi.decode(abi.encode(first.checkpoints[6]), (CP.Checkpoint));
        p.eras[1].checkpoints[6].ownerState.revision = 1;
        p.aliases[6] = new RH.ReplayAlias[](18);
        for (uint256 i; i < 9; ++i) {
            RH.ReplayAlias memory a = originalAliases[i];
            p.aliases[6][i] = a;
            p.aliases[6][i + 9] =
                _chAlias(next, a.admittedAt, a.surface, a.scope, a.cell.commitment);
        }
        _chSort(p.aliases[6]);
        f.inventory.provenance = p;
        _chCommit(f);
        this.check(f);
        Fixture memory changed = _chCopy(f);
        // Keep structurally valid era membership, key and cell/point agreement. Only the
        // claimed original admission moves: the shared whole-history replay proof rejects it.
        bool moved;
        for (uint256 i; i < changed.inventory.provenance.aliases[6].length; ++i) {
            RH.ReplayAlias memory a = changed.inventory.provenance.aliases[6][i];
            if (a.originHash != p.eras[1].originHash || a.admittedAt.ownerRevision != 1) continue;
            changed.inventory.provenance.aliases[6][i].admittedAt.ownerRevision = 2;
            changed.inventory.provenance.aliases[6][i].cell.touchedRevision = 2;
            moved = true;
        }
        require(moved, "actual retained alias selected");
        _chCommit(changed);
        _reject(abi.encodeCall(this.check, (changed)));
        this.check(f);
    }

    function _reject(bytes memory input) private view {
        (bool ok,) = address(this).staticcall(input);
        require(!ok, "invalid complete-history consent accepted");
    }
}
