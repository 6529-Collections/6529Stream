// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Validation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentUses as Uses
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationConsentUses.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationProvenance.sol";
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
    StreamArtistDelegationHydrationTypes as DH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";

/// @notice Pure worker oracles over complete, explicit owner-6 journals and replay inventories.
/// @dev These fixtures exercise row predicates after source authentication. They do not claim
/// actual source getter admission, original authorization execution, or operation60 import.
contract StreamArtistRecoveredMultipleGenerationConsentWorkersTest {
    bytes32 private constant ARTIST = keccak256("generation worker artist");
    bytes32 private constant GRANT = keccak256("retained original grant");
    address private constant DELEGATE = address(0xD311);

    struct Fixture {
        G.Consents[] all;
        AH.Query[] queries;
        RH.Provenance provenance;
    }

    function check(G.Consents[] memory all, AH.Query[] memory q, RH.OwnerProvenance memory p)
        external
        pure
    {
        Validation.validate(all, q, p);
    }

    function checkUses(Uses.Context calldata x) external pure returns (uint256[][] memory) {
        return Uses.validate(x);
    }

    function testGenerationConsentAllSixFamiliesRetainOldRowsUnderNewAcceptedTip() external pure {
        Fixture memory f = _fixture(3);
        _valid(f);
        require(f.all[0].rows.consents[0].bindingGeneration == 1, "old original generation");
        require(f.all[1].rows.consents[0].bindingGeneration == 2, "second collection generation");
        require(f.all[0].bindings[2].generation == 3, "current tip remains distinct");
    }

    function testFuzzGenerationConsentEveryCompleteTipRetainsGenerationOne(uint8 value)
        external
        pure
    {
        uint64 tip = uint64(uint256(value) % 127 + 2);
        Fixture memory f = _fixture(tip);
        _valid(f);
        require(f.all[0].rows.original.economics[0].item.association.bindingGeneration == 1);
        require(f.all[0].rows.original.sales[0].item.bindingGeneration == 1);
    }

    function testGenerationConsentAllowsGenerationOneCollectionBesideLongerHistory() external view {
        Fixture memory f = _fixture(3);
        T.Binding memory original = f.all[0].bindings[0];
        f.all[0].bindings = new T.Binding[](1);
        f.all[0].bindings[0] = original;
        f.all[0].rows.original.bindingHash = original.bindingHash;
        f.queries[0].bindingHash = original.bindingHash;
        _valid(f);
        require(f.all[0].bindings.length == 1 && f.all[1].bindings.length == 3);
        uint256[][] memory totals = this.checkUses(_context(f, false));
        require(totals.length == 1 && totals[0][0] == 0);
    }

    function testGenerationConsentRejectsMissingRejectedAndWrongArtistBindings() external view {
        Fixture memory f = _fixture(3);
        bytes memory saved = abi.encode(f);
        f.all[0].bindings[0].accepted = false;
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].bindings[1].generation = 3;
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].bindings[0].artistId = keccak256("different artist");
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].bindings[2].accepted = false;
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].bindings = new T.Binding[](0);
        _bad(f);
    }

    function testGenerationConsentSavedEconomicsAndSaleHashesCannotUseCurrentTip() external view {
        Fixture memory f = _fixture(3);
        bytes memory saved = abi.encode(f);
        f.all[0].rows.original.economics[0].item.association.bindingHash = f.queries[0].bindingHash;
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].rows.original.sales[0].item.bindingHash = f.queries[0].bindingHash;
        _seal(f);
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].rows.original.economics[0].item.association.bindingGeneration = 0;
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].rows.original.sales[0].item.bindingGeneration = 4;
        _seal(f);
        _bad(f);
    }

    function testGenerationConsentSameEconomicsTermsRetainFirstRecordAndContinuation()
        external
        pure
    {
        Fixture memory f = _economicsContinuationFixture(false);
        _valid(f);
        Base.Economics[] memory rows = f.all[0].rows.original.economics;
        require(rows.length == 2 && rows[0].item.recordHash != rows[1].item.recordHash);
        require(
            keccak256(abi.encode(rows[0].item.terms)) == keccak256(abi.encode(rows[1].item.terms))
        );
        require(rows[0].item.association.originalRecord == rows[0].item.recordHash);
        require(rows[1].item.association.originalRecord == rows[0].item.recordHash);
        require(
            rows[0].item.association.bindingGeneration == 1
                && rows[1].item.association.bindingGeneration == 2
        );
        uint256 occurrences;
        for (uint256 i; i < f.provenance.journals[6].length; ++i) {
            H.Receipt memory receipt = f.provenance.journals[6][i].receipt;
            if (receipt.operation == 15 && receipt.collectionId == 1) ++occurrences;
        }
        require(
            f.provenance.journals[6].length == 13 && occurrences == 2,
            "original op15 occurrences are not deduplicated by terms"
        );
    }

    function testGenerationConsentEconomicsPredicateComparesContinuationToFirstGeneration()
        external
        pure
    {
        Fixture memory f = _economicsContinuationFixture(false);
        Base.Economics[] memory rows = new Base.Economics[](3);
        rows[0] = f.all[0].rows.original.economics[0];
        rows[1] = f.all[0].rows.original.economics[1];
        rows[1].item.association.bindingGeneration = 3;
        rows[1].item.association.bindingHash = f.all[0].bindings[2].bindingHash;
        rows[2] = abi.decode(abi.encode(rows[1]), (Base.Economics));
        rows[2].item.recordHash = _economicsRecord(f, rows[2], 103);
        rows[2].item.association.bindingGeneration = 2;
        rows[2].item.association.bindingHash = f.all[0].bindings[1].bindingHash;
        f.all[0].rows.original.economics = rows;
        _seal(f);
        // The low-level producer predicate compares each continuation to the FIRST row.
        // This does not establish admission of 1->3->2 by the enclosing binding/Archive
        // chronology, which is independently authenticated outside these pure workers.
        _valid(f);
    }

    function testGenerationConsentDelegatedEconomicsContinuationAddsOneOriginalUse() external view {
        Fixture memory f = _economicsContinuationFixture(true);
        _valid(f);
        Uses.Context memory x = _context(f, true);
        uint256[][] memory totals = this.checkUses(x);
        require(totals.length == 1 && totals[0].length == 2);
        require(totals[0][0] == 9 && totals[0][1] == 0, "eight original uses plus one continuation");
        require(x.provenance.journals[6].length == 13, "complete global journal is retained");
    }

    function testGenerationConsentEconomicsContinuationRejectsMissingOrWrongOriginalRecord()
        external
        view
    {
        Fixture memory f = _economicsContinuationFixture(false);
        bytes memory saved = abi.encode(f);
        for (uint256 mutation; mutation < 4; ++mutation) {
            f = abi.decode(saved, (Fixture));
            if (mutation == 0) {
                f.all[0].rows.original.economics[0].item.association.originalRecord = 0;
            }
            if (mutation == 1) {
                f.all[0].rows.original.economics[1].item.association.originalRecord = 0;
            }
            if (mutation == 2) {
                f.all[0].rows.original.economics[1].item.association.originalRecord =
                f.all[1].rows.original.economics[0].item.recordHash;
            }
            if (mutation == 3) {
                Base.Economics memory continuation = f.all[0].rows.original.economics[1];
                f.all[0].rows.original.economics = new Base.Economics[](1);
                f.all[0].rows.original.economics[0] = continuation;
            }
            _seal(f);
            // Rehashed, complete transport remains well formed; the first-record link fails.
            Provenance.validateOwner(RH.ownerProvenance(f.provenance, 6), 6);
            _bad(f);
        }
    }

    function testGenerationConsentEconomicsContinuationRejectsDuplicateAndRejectedBinding()
        external
        view
    {
        Fixture memory f = _economicsContinuationFixture(false);
        bytes memory saved = abi.encode(f);
        f.all[0].rows.original.economics[1].item.association.bindingGeneration = 1;
        f.all[0].rows.original.economics[1].item.association.bindingHash =
        f.all[0].bindings[0].bindingHash;
        _seal(f);
        Provenance.validateOwner(RH.ownerProvenance(f.provenance, 6), 6);
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].bindings[1].accepted = false;
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.all[0].rows.original.economics[1].item.association.bindingHash =
        f.all[0].bindings[2].bindingHash;
        _seal(f);
        Provenance.validateOwner(RH.ownerProvenance(f.provenance, 6), 6);
        _bad(f);
        f = abi.decode(saved, (Fixture));
        Base.Economics[] memory rows = new Base.Economics[](3);
        rows[0] = f.all[0].rows.original.economics[0];
        rows[1] = f.all[0].rows.original.economics[1];
        rows[2] = abi.decode(abi.encode(rows[1]), (Base.Economics));
        rows[2].item.recordHash = _economicsRecord(f, rows[2], 103);
        f.all[0].rows.original.economics = rows;
        _seal(f);
        _bad(f);
    }

    function testGenerationConsentEconomicsContinuationRejectsRehashedLegacyPayloadAlias()
        external
        view
    {
        Fixture memory f = _economicsContinuationFixture(false);
        _valid(f);
        Base.Economics[] memory rows = f.all[0].rows.original.economics;
        bytes32 payload = rows[0].item.association.payloadHash;
        bytes32 continuation = _economicsScope(rows[1]);
        require(payload != continuation);
        uint256 changed;
        for (uint256 i; i < f.provenance.aliases[6].length; ++i) {
            RH.ReplayAlias memory a = f.provenance.aliases[6][i];
            if (a.cell.commitment == rows[0].item.recordHash) {
                a.scope = continuation;
            } else if (a.cell.commitment == rows[1].item.recordHash) {
                a.scope = payload;
            } else {
                continue;
            }
            a.originalKey = _key(f.provenance.origins[0], a);
            ++changed;
        }
        require(changed == 2, "swap preserves unique original keys");
        _sort(f.provenance.aliases[6]);
        _header(f);
        // Both aliases retain their own exact receipt and admission point. Exchanging scopes
        // avoids an earlier duplicate-key failure and reaches the economics row/scope join.
        Provenance.validateOwner(RH.ownerProvenance(f.provenance, 6), 6);
        _bad(f);
    }

    function testGenerationConsentSavedContentRoyaltyAndFreezeRequireAcceptedGeneration()
        external
        view
    {
        Fixture memory f = _fixture(3);
        bytes memory saved = abi.encode(f);
        for (uint256 family; family < 3; ++family) {
            f = abi.decode(saved, (Fixture));
            if (family == 0) f.all[0].rows.consents[0].bindingGeneration = 4;
            if (family == 1) f.all[0].rows.royalties[0].item.bindingGeneration = 4;
            if (family == 2) f.all[0].rows.freezes[0].bindingGeneration = 4;
            // Rebuild the original key and provenance hash, so generation range is decisive.
            _seal(f);
            _bad(f);
        }
    }

    function testGenerationConsentReplayScopesUseSavedGenerationEvenAfterKeyRehash() external view {
        Fixture memory f = _fixture(3);
        bytes memory saved = abi.encode(f);
        for (uint256 family; family < 3; ++family) {
            f = abi.decode(saved, (Fixture));
            ContentH.Bundle memory b = f.all[0].rows;
            bytes32 record = family == 0
                ? b.consents[0].recordHash
                : family == 1 ? b.royalties[0].item.recordHash : b.freezes[0].recordHash;
            for (uint256 a; a < f.provenance.aliases[6].length; ++a) {
                RH.ReplayAlias memory cell = f.provenance.aliases[6][a];
                if (cell.cell.commitment != record) continue;
                if (family == 0) {
                    cell.scope = keccak256(
                        abi.encode(keccak256(abi.encode(b.consents[0].terms, uint64(3))), record)
                    );
                } else if (family == 1) {
                    cell.scope = keccak256(abi.encode(b.royalties[0].terms, ARTIST, uint64(3)));
                } else {
                    cell.scope =
                        keccak256(abi.encode(keccak256("CONTENT"), uint256(1), uint64(3), record));
                }
                cell.originalKey = _key(f.provenance.origins[0], cell);
            }
            _sort(f.provenance.aliases[6]);
            _header(f);
            // The common provenance layer accepts the rehashed transport; row scope must fail.
            Provenance.validateOwner(RH.ownerProvenance(f.provenance, 6), 6);
            _bad(f);
        }
    }

    function testGenerationConsentJournalRejectsOmittedCollectionAndReorderedOccurrences()
        external
        view
    {
        Fixture memory f = _fixture(3);
        bytes memory saved = abi.encode(f);
        Fixture memory pristine = abi.decode(saved, (Fixture));
        f.all = new G.Consents[](1);
        f.all[0] = pristine.all[0];
        f.queries = new AH.Query[](1);
        f.queries[0] = pristine.queries[0];
        _bad(f);
        f = abi.decode(saved, (Fixture));
        RH.JournalEntry memory first = f.provenance.journals[6][0];
        f.provenance.journals[6][0] = f.provenance.journals[6][1];
        f.provenance.journals[6][1] = first;
        _header(f);
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.provenance.journals[6][1].receipt.collectionId = 1;
        _header(f);
        _bad(f);
    }

    function testGenerationConsentPerCollectionSubsequenceCannotReverseContentRows() external view {
        Fixture memory f = _fixture(3);
        ContentOwner.ConsentRecord[] memory rows = new ContentOwner.ConsentRecord[](2);
        rows[0] = f.all[0].rows.consents[0];
        rows[1] = rows[0];
        // Decode to avoid Solidity memory aliases when changing only the second row.
        rows[1] = abi.decode(abi.encode(rows[0]), (ContentOwner.ConsentRecord));
        rows[1].recordHash = keccak256("second original content record");
        rows[1].bindingGeneration = 2;
        f.all[0].rows.consents = rows;
        _seal(f);
        _valid(f);
        ContentOwner.ConsentRecord memory first = f.all[0].rows.consents[0];
        f.all[0].rows.consents[0] = f.all[0].rows.consents[1];
        f.all[0].rows.consents[1] = first;
        _bad(f);
    }

    function testGenerationConsentRejectsAliasOmissionDuplicateAndFalseAdmissionPoint()
        external
        view
    {
        Fixture memory f = _fixture(3);
        bytes memory saved = abi.encode(f);
        f.provenance.aliases[6] = new RH.ReplayAlias[](0);
        _header(f);
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.provenance.aliases[6][1] = f.provenance.aliases[6][0];
        _header(f);
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.provenance.aliases[6][0].admittedAt.ownerRevision = 1;
        f.provenance.aliases[6][0].cell.touchedRevision = 1;
        // Choose another valid revision even if the sorted first alias originally used 1.
        if (
            f.provenance.aliases[6][0].cell.commitment
                == f.provenance.journals[6][0].receipt.recordHash
        ) {
            f.provenance.aliases[6][0].admittedAt.ownerRevision = 2;
            f.provenance.aliases[6][0].cell.touchedRevision = 2;
        }
        _header(f);
        Provenance.validateOwner(RH.ownerProvenance(f.provenance, 6), 6);
        _bad(f);
    }

    function testGenerationConsentRepeatedEraRetainsOriginalRowsAndEveryRekeyedAlias()
        external
        view
    {
        Fixture memory f = _fixture(3);
        bytes32 originalJournal = keccak256(abi.encode(f.provenance.journals[6]));
        _repeat(f);
        _valid(f);
        require(keccak256(abi.encode(f.provenance.journals[6])) == originalJournal);
        require(f.provenance.journals[6][11].position.point.ownerRevision == 12);
        require(f.provenance.eras[1].checkpoints[6].ownerState.revision == 1);
        bytes memory saved = abi.encode(f);
        // Removing a rekeyed alias must fail even though the old admission is retained.
        RH.ReplayAlias[] memory omitted = new RH.ReplayAlias[](f.provenance.aliases[6].length - 1);
        for (uint256 i; i < omitted.length; ++i) {
            omitted[i] = f.provenance.aliases[6][i];
        }
        f.provenance.aliases[6] = omitted;
        _header(f);
        _bad(f);
        f = abi.decode(saved, (Fixture));
        f.provenance.eras[1].checkpoints[6].ownerState.revision = 2;
        _header(f);
        // Common provenance permits this upper bound; Consent's exact era accounting does not.
        Provenance.validateOwner(RH.ownerProvenance(f.provenance, 6), 6);
        _bad(f);
    }

    function testGenerationConsentSameRoyaltyTermsHaveDistinctSavedGenerationScopes()
        external
        view
    {
        Fixture memory f = _fixture(3);
        ContentH.Royalty[] memory rows = new ContentH.Royalty[](2);
        rows[0] = f.all[0].rows.royalties[0];
        rows[1] = abi.decode(abi.encode(rows[0]), (ContentH.Royalty));
        rows[1].item.recordHash = keccak256("same royalty terms next generation");
        rows[1].item.bindingGeneration = 2;
        f.all[0].rows.royalties = rows;
        _seal(f);
        _valid(f);
        rows[1].item.bindingGeneration = 1;
        _seal(f);
        _bad(f);
    }

    function testGenerationConsentDirectClassThreePreservesEmptySignatureEvidence() external view {
        Fixture memory f = _fixture(3);
        for (uint256 c; c < f.all.length; ++c) {
            f.all[c].rows.consents[0].authorityClass = 3;
            f.all[c].rows.freezes[0].authorityClass = 3;
            f.all[c].rows.original.sales[0].item.authorityClass = 3;
        }
        _seal(f);
        _valid(f);
        Uses.Context memory x = _context(f, false);
        uint256[][] memory totals = this.checkUses(x);
        require(totals.length == 1 && totals[0].length == 2 && totals[0][0] == 0);
    }

    function testGenerationConsentUsesAccumulateAcrossCollectionsWithoutFinalEquality()
        external
        view
    {
        Uses.Context memory x = _usageFixture();
        uint256[][] memory totals = this.checkUses(x);
        require(totals.length == 1 && totals[0].length == 2, "retained grant shape");
        require(totals[0][0] == 8 && totals[0][1] == 0, "four families in two collections");
        IH.Bundle memory identity = abi.decode(x.identities[0], (IH.Bundle));
        require(identity.delegations[0].record.uses != totals[0][0], "equality belongs to caller");
        identity.delegations[0].record.uses = 0;
        x.identities[0] = abi.encode(identity);
        totals = this.checkUses(x);
        require(totals[0][0] == 8, "increments do not use captured final count");
    }

    function testGenerationConsentUsesReturnSeparateArtistAndRetainedGrantDimensions()
        external
        view
    {
        Uses.Context memory x = _twoArtists();
        uint256[][] memory totals = this.checkUses(x);
        require(totals.length == 2, "complete Artist ordering");
        require(totals[0].length == 1 && totals[0][0] == 4, "second collection Artist first");
        require(
            totals[1].length == 2 && totals[1][0] == 4 && totals[1][1] == 0,
            "first collection Artist second"
        );
        x.scope.artists[1] = x.scope.artists[0];
        x.identities[1] = x.identities[0];
        _badUses(x);
    }

    function testGenerationConsentOldPolicyDoesNotInventCurrentGeneration() external view {
        Uses.Context memory x = _usageFixture();
        require(x.consents[0].bindings[0].consentMode == 2);
        require(x.consents[0].bindings[2].consentMode == 1);
        uint256[][] memory totals = this.checkUses(x);
        require(totals[0][0] == 8, "old14 has no saved generation");
        // No historical mode2 can have admitted this delegated policy.
        for (uint256 g; g < x.consents[0].bindings.length; ++g) {
            x.consents[0].bindings[g].consentMode = 1;
        }
        _badUses(x);
    }

    function testGenerationConsentDelegatedSaleRequiresOriginalModeTwoAndExactSigner()
        external
        view
    {
        Uses.Context memory x = _usageFixture();
        bytes memory saved = abi.encode(x);
        x.consents[0].bindings[0].consentMode = 1;
        // Exact saved sale binding/mode is the Validation layer's responsibility.
        _bad(Fixture(x.consents, x.scope.collections, x.provenance));
        x = abi.decode(saved, (Uses.Context));
        x.consents[0].rows.original.sales[0].item.signer = address(0xBADD);
        _badUses(x);
        x = abi.decode(saved, (Uses.Context));
        x.consents[0].rows.original.sales[0].item.authorityClass = 1;
        _badUses(x);
    }

    function testGenerationConsentUsesRejectMissingCapabilityGrantAndCollectionScope()
        external
        view
    {
        Uses.Context memory x = _usageFixture();
        bytes memory saved = abi.encode(x);
        uint32[4] memory caps = [D.POLICY_CONSENT, D.ECONOMICS, D.SALE_CONSENT, D.ROYALTY_FREEZE];
        for (uint256 i; i < caps.length; ++i) {
            x = abi.decode(saved, (Uses.Context));
            IH.Bundle memory identity = abi.decode(x.identities[0], (IH.Bundle));
            identity.delegations[0].record.grant.capabilities &= ~caps[i];
            x.identities[0] = abi.encode(identity);
            _badUses(x);
        }
        x = abi.decode(saved, (Uses.Context));
        IH.Bundle memory identity = abi.decode(x.identities[0], (IH.Bundle));
        identity.delegations[0].record.grant.collectionId = 1;
        x.identities[0] = abi.encode(identity);
        _badUses(x);
        x = abi.decode(saved, (Uses.Context));
        x.consents[0].rows.original.policies[0].grant = keccak256("absent grant");
        _badUses(x);
    }

    function testGenerationConsentUsesSaleNonceRequiresOriginalLaneAndAfterGrant() external view {
        Uses.Context memory x = _usageFixture();
        bytes memory saved = abi.encode(x);
        x.provenance.aliases[2] = new RH.ReplayAlias[](0);
        _badUses(x);
        x = abi.decode(saved, (Uses.Context));
        x.consents[0].rows.original.sales[0].item.nonce = 999;
        _badUses(x);
        x = abi.decode(saved, (Uses.Context));
        for (uint256 i; i < x.provenance.aliases[2].length; ++i) {
            x.provenance.aliases[2][i].admittedAt.ownerRevision = 1;
            x.provenance.aliases[2][i].cell.touchedRevision = 1;
        }
        _badUses(x);
    }

    function testGenerationConsentUsesRejectMissingDuplicateAndOversizedSignature() external view {
        Uses.Context memory x = _usageFixture();
        bytes memory saved = abi.encode(x);
        IH.Bundle memory identity = abi.decode(x.identities[0], (IH.Bundle));
        identity.signatures = new IH.SignatureRow[](0);
        x.identities[0] = abi.encode(identity);
        _badUses(x);
        x = abi.decode(saved, (Uses.Context));
        identity = abi.decode(x.identities[0], (IH.Bundle));
        identity.signatures[0] = identity.signatures[6];
        x.identities[0] = abi.encode(identity);
        _badUses(x);
        x = abi.decode(saved, (Uses.Context));
        identity = abi.decode(x.identities[0], (IH.Bundle));
        identity.signatures[6].signature = new bytes(4097);
        x.identities[0] = abi.encode(identity);
        _badUses(x);
    }

    function testGenerationConsentUsesRejectWrongArtistMissingCollectionAndMalformedIdentity()
        external
        view
    {
        Uses.Context memory x = _usageFixture();
        bytes memory saved = abi.encode(x);
        x.scope.artists[0].artistId = keccak256("unjoined artist");
        _badUses(x);
        x = abi.decode(saved, (Uses.Context));
        x.scope.collections = new AH.Query[](0);
        _badUses(x);
        x = abi.decode(saved, (Uses.Context));
        x.identities[0] = hex"1234";
        _badUses(x);
    }

    function testGenerationConsentSameSaleTermsAcrossGenerationsRetainLatestLookup() external view {
        Fixture memory f = _sameSaleTermsFixture();
        _valid(f);
        DH.Sale[] memory rows = f.all[0].rows.original.sales;
        require(rows.length == 2 && rows[0].item.recordHash != rows[1].item.recordHash);
        require(
            keccak256(abi.encode(rows[0].item.terms)) == keccak256(abi.encode(rows[1].item.terms))
        );
        require(rows[0].item.bindingGeneration == 1 && rows[1].item.bindingGeneration == 2);
        require(
            rows[0].current == rows[1].item.recordHash && rows[1].current == rows[1].item.recordHash
        );
        require(f.provenance.journals[6].length == 13, "both original sale occurrences retained");
        // Every row for the global lookup reports the last original record, including old generations.
        rows[0].current = rows[0].item.recordHash;
        _bad(f);
    }

    function testGenerationConsentSameBindingCannotRepeatSaleTerms() external view {
        Fixture memory f = _sameSaleTermsFixture();
        _valid(f);
        DH.Sale[] memory rows = f.all[0].rows.original.sales;
        rows[1].item.bindingGeneration = rows[0].item.bindingGeneration;
        rows[1].item.bindingHash = rows[0].item.bindingHash;
        _seal(f);
        rows[0].current = rows[1].item.recordHash;
        require(
            rows[0].item.recordHash != rows[1].item.recordHash,
            "distinct signatures do not permit replay"
        );
        // Resealing gives the two occurrences the same replay key; that history is invalid.
        _bad(f);

        f = _sameSaleTermsFixture();
        rows = f.all[0].rows.original.sales;
        rows[1].item.nonce = rows[0].item.nonce;
        _seal(f);
        require(
            rows[0].item.recordHash == rows[1].item.recordHash,
            "original record preimage is unchanged"
        );
        // Distinct accepted generations do not permit reusing the same original signed record.
        _bad(f);
    }

    function _sameSaleTermsFixture() private pure returns (Fixture memory f) {
        f = _fixture(3);
        DH.Sale[] memory rows = new DH.Sale[](2);
        rows[0] = f.all[0].rows.original.sales[0];
        rows[1] = abi.decode(abi.encode(rows[0]), (DH.Sale));
        ++rows[1].item.nonce;
        rows[1].item.bindingGeneration = 2;
        rows[1].item.bindingHash = f.all[0].bindings[1].bindingHash;
        f.all[0].rows.original.sales = rows;
        _seal(f);
        rows[0].current = rows[1].item.recordHash;
    }

    function _fixture(uint64 tip) private pure returns (Fixture memory f) {
        f.all = new G.Consents[](2);
        f.queries = new AH.Query[](2);
        f.provenance.origins = new RH.OriginEnvironment[](1);
        f.provenance.origins[0] = _origin();
        f.provenance.eras = new RH.Era[](1);
        f.provenance.eras[0].originHash = RH.originHash(f.provenance.origins[0]);
        for (uint8 o; o < 7; ++o) {
            f.provenance.eras[0].checkpoints[o].schema = RH.CHECKPOINT;
            f.provenance.eras[0].checkpoints[o].ownerState = T.Snapshot(
                RH.ownerDomain(o),
                4,
                keccak256(abi.encode("state", o)),
                keccak256(abi.encode("tip", o))
            );
        }
        for (uint256 c; c < 2; ++c) {
            G.Consents memory b = f.all[c];
            b.bindings = new T.Binding[](tip);
            for (uint64 g = 1; g <= tip; ++g) {
                b.bindings[g - 1].artistId = ARTIST;
                b.bindings[g - 1].bindingHash = keccak256(abi.encode("binding", c + 1, g));
                b.bindings[g - 1].generation = g;
                b.bindings[g - 1].consentMode = g == tip ? 1 : 2;
                b.bindings[g - 1].accepted = true;
            }
            uint64 generation = uint64(c + 1);
            bytes32 bindingHash = b.bindings[generation - 1].bindingHash;
            b.rows.original.artistId = ARTIST;
            b.rows.original.collectionId = c + 1;
            b.rows.original.bindingHash = b.bindings[tip - 1].bindingHash;
            b.rows.original.keys = new AH.PolicyKey[](1);
            b.rows.original.keys[0] = AH.PolicyKey(_hash(c, 140), _hash(c, 141));
            b.rows.original.policies = new DH.Policy[](1);
            b.rows.original.policies[0].recordHash = _hash(c, 14);
            b.rows.original.economics = new Base.Economics[](1);
            b.rows.original.economics[0].item.terms = T.EconomicsConsent(
                c + 1, address(0xE1), keccak256("PRIMARY"), 1, c + 1, _hash(c, 150)
            );
            b.rows.original.economics[0].item.recordHash = _hash(c, 15);
            b.rows.original.economics[0].item.association.artistId = ARTIST;
            b.rows.original.economics[0].item.association.bindingGeneration = generation;
            b.rows.original.economics[0].item.association.bindingHash = bindingHash;
            b.rows.original.economics[0].item.association.payloadHash =
                keccak256(abi.encode(b.rows.original.economics[0].item.terms));
            b.rows.original.economics[0].item.association.originalRecord = _hash(c, 15);
            b.rows.original.sales = new DH.Sale[](1);
            Sale.Record memory sale = b.rows.original.sales[0].item;
            sale.terms = Sale.Consent(c + 1, address(0x5A1E), _hash(c, 160), _hash(c, 161));
            sale.artistId = ARTIST;
            sale.signer = address(0xA1);
            sale.authorityClass = 1;
            sale.nonce = c + 7;
            sale.signedAt = 10;
            sale.bindingGeneration = generation;
            sale.bindingHash = bindingHash;
            b.rows.consents = new ContentOwner.ConsentRecord[](1);
            b.rows.consents[0] = ContentOwner.ConsentRecord(
                _hash(c, 17),
                ARTIST,
                generation,
                Content.Consent(c + 1, address(0xC017), _hash(c, 170), _hash(c, 171)),
                1
            );
            b.rows.royalties = new ContentH.Royalty[](1);
            b.rows.royalties[0].terms =
                T.RoyaltyFreeze(address(0xE2), c + 1, keccak256("ROYALTY_ERC2981"), _hash(c, 200));
            b.rows.royalties[0].item = T.RoyaltyFreezeRecord(_hash(c, 20), ARTIST, generation);
            b.rows.freezes = new Content.FreezeRecord[](1);
            b.rows.freezes[0] = Content.FreezeRecord(
                _hash(c, 21),
                ARTIST,
                generation,
                address(0xC017),
                new bytes32[](1),
                _hash(c, 210),
                1
            );
            b.rows.freezes[0].lockClasses[0] = keccak256("SCRIPT");
            f.queries[c].artistId = ARTIST;
            f.queries[c].collectionId = c + 1;
            f.queries[c].bindingHash = b.rows.original.bindingHash;
            f.queries[c].policies = b.rows.original.keys;
        }
        _seal(f);
    }

    function _usageFixture() private pure returns (Uses.Context memory x) {
        Fixture memory f = _fixture(3);
        for (uint256 c; c < f.all.length; ++c) {
            ContentH.Bundle memory b = f.all[c].rows;
            b.original.policies[0].grant = GRANT;
            b.original.economics[0].grant = GRANT;
            b.original.sales[0].grant = GRANT;
            b.original.sales[0].item.authorityClass = 2;
            b.original.sales[0].item.signer = DELEGATE;
            b.royalties[0].grant = GRANT;
        }
        _seal(f);
        _valid(f);
        x = _context(f, true);
    }

    function _economicsContinuationFixture(bool delegated) private pure returns (Fixture memory f) {
        if (delegated) {
            Uses.Context memory x = _usageFixture();
            f = Fixture(x.consents, x.scope.collections, x.provenance);
        } else {
            f = _fixture(3);
        }
        Base.Economics[] memory rows = new Base.Economics[](2);
        rows[0] = f.all[0].rows.original.economics[0];
        rows[0].item.recordHash = _economicsRecord(f, rows[0], 101);
        rows[0].item.association.originalRecord = rows[0].item.recordHash;
        rows[1] = abi.decode(abi.encode(rows[0]), (Base.Economics));
        rows[1].item.recordHash = _economicsRecord(f, rows[1], 102);
        rows[1].item.association.bindingGeneration = 2;
        rows[1].item.association.bindingHash = f.all[0].bindings[1].bindingHash;
        f.all[0].rows.original.economics = rows;
        _seal(f);
    }

    function _economicsRecord(Fixture memory f, Base.Economics memory row, uint256 nonce)
        private
        pure
        returns (bytes32)
    {
        T.EconomicsConsent memory terms = row.item.terms;
        // Independent original V1 record preimage; the saved generation association and
        // first-record pointer remain separately authenticated producer facts.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1"),
                f.provenance.origins[0].chainId,
                f.provenance.origins[0].registry,
                terms.resolver,
                terms.revenueClass,
                terms.scope,
                terms.scopeId,
                terms.assignmentHash,
                keccak256("original payout designation"),
                row.item.association.artistId,
                row.grant == 0 ? address(0xA1) : DELEGATE,
                row.grant == 0 ? uint8(1) : uint8(2),
                nonce,
                uint64(10)
            )
        );
    }

    function _economicsScope(Base.Economics memory row) private pure returns (bytes32) {
        if (row.item.association.originalRecord == row.item.recordHash) {
            return row.item.association.payloadHash;
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ECONOMICS_BINDING_CONTINUATION_V1"),
                row.item.association.originalRecord,
                row.item.terms,
                row.item.association.artistId,
                row.item.association.bindingGeneration,
                row.item.association.bindingHash
            )
        );
    }

    function _context(Fixture memory f, bool delegated)
        private
        pure
        returns (Uses.Context memory x)
    {
        x.consents = f.all;
        x.scope.collections = f.queries;
        x.scope.artists = new AH.Query[](1);
        x.scope.artists[0].artistId = ARTIST;
        x.provenance = f.provenance;
        IH.Bundle memory identity;
        identity.artistId = ARTIST;
        identity.delegations = new IH.DelegationRow[](2);
        for (uint256 g; g < 2; ++g) {
            IH.DelegationRow memory row = identity.delegations[g];
            row.recordHash = g == 0 ? GRANT : keccak256("unused retained grant");
            row.position.point =
                RH.Point(f.provenance.eras[0].originHash, 2, uint64(g == 0 ? 1 : 4));
            row.position.nativeIndex = g;
            row.record.grant.artistId = ARTIST;
            row.record.grant.delegate = g == 0 ? DELEGATE : address(0xD312);
            row.record.grant.capabilities =
                D.POLICY_CONSENT | D.ECONOMICS | D.SALE_CONSENT | D.ROYALTY_FREEZE;
            row.record.grant.expiresAt = type(uint64).max;
            row.record.grant.maxUses = 100;
            row.record.uses = g == 0 ? 29 : 0;
            row.current = row.recordHash;
            row.epoch = 1;
        }
        identity.signatures = _signatures(f.provenance, ARTIST);
        x.provenance.journals[2] = new RH.JournalEntry[](2);
        x.provenance.eras[0].nativeCounts[2] = 2;
        for (uint256 i; i < 2; ++i) {
            x.provenance.journals[2][i].position = identity.delegations[i].position;
            x.provenance.journals[2][i].receipt =
                H.Receipt(26, ARTIST, 0, identity.delegations[i].recordHash);
        }
        if (delegated) {
            x.provenance.aliases[2] = new RH.ReplayAlias[](2);
            bytes32 lane = keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), ARTIST, DELEGATE)
            );
            for (uint256 c; c < 2; ++c) {
                RH.ReplayAlias memory a = x.provenance.aliases[2][c];
                a.originHash = f.provenance.eras[0].originHash;
                a.ownerIndex = 2;
                a.surface = keccak256("identity_authority.replay.delegated_nonce");
                a.scope = keccak256(abi.encode(lane, f.all[c].rows.original.sales[0].item.nonce));
                a.admittedAt = RH.Point(a.originHash, 2, uint64(c + 2));
                a.cell = T.ReplayCell(_hash(c, 900), uint64(c + 2), 1, 2);
                a.originalKey = _key(f.provenance.origins[0], a);
            }
            _sort(x.provenance.aliases[2]);
            x.provenance.eras[0].checkpoints[2].replayCount = 2;
        }
        x.identities = new bytes[](1);
        x.identities[0] = abi.encode(identity);
    }

    function _twoArtists() private pure returns (Uses.Context memory x) {
        x = _usageFixture();
        Fixture memory f = Fixture(x.consents, x.scope.collections, x.provenance);
        bytes32 other = keccak256("second generation worker artist");
        bytes32 otherGrant = keccak256("second Artist retained grant");
        G.Consents memory row = f.all[1];
        row.rows.original.artistId = other;
        f.queries[1].artistId = other;
        for (uint256 i; i < row.bindings.length; ++i) {
            row.bindings[i].artistId = other;
        }
        row.rows.original.policies[0].grant = otherGrant;
        row.rows.original.economics[0].grant = otherGrant;
        row.rows.original.economics[0].item.association.artistId = other;
        row.rows.original.sales[0].grant = otherGrant;
        row.rows.original.sales[0].item.artistId = other;
        row.rows.consents[0].artistId = other;
        row.rows.royalties[0].item.artistId = other;
        row.rows.royalties[0].grant = otherGrant;
        row.rows.freezes[0].artistId = other;
        _seal(f);
        _valid(f);
        x = _context(f, true);
        IH.Bundle memory first = abi.decode(x.identities[0], (IH.Bundle));
        first.delegations[1].position.nativeIndex = 2;
        bytes memory firstBytes = abi.encode(first);
        IH.Bundle memory second = abi.decode(firstBytes, (IH.Bundle));
        second.artistId = other;
        second.signatures = _signatures(f.provenance, other);
        IH.DelegationRow memory grant = second.delegations[0];
        grant.recordHash = otherGrant;
        grant.current = otherGrant;
        grant.position.point.ownerRevision = 2;
        grant.position.nativeIndex = 1;
        grant.record.grant.artistId = other;
        second.delegations = new IH.DelegationRow[](1);
        second.delegations[0] = grant;
        x.identities = new bytes[](2);
        x.identities[0] = abi.encode(second);
        x.identities[1] = firstBytes;
        x.scope.artists = new AH.Query[](2);
        x.scope.artists[0].artistId = other;
        x.scope.artists[1].artistId = ARTIST;
        RH.JournalEntry[] memory journal = new RH.JournalEntry[](3);
        journal[0] = x.provenance.journals[2][0];
        journal[1] = RH.JournalEntry(grant.position, H.Receipt(26, other, 0, otherGrant));
        journal[2] = x.provenance.journals[2][1];
        journal[2].position.nativeIndex = 2;
        x.provenance.journals[2] = journal;
        x.provenance.eras[0].nativeCounts[2] = 3;
        bytes32 oldLane = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), ARTIST, DELEGATE)
        );
        bytes32 newLane = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), other, DELEGATE)
        );
        for (uint256 i; i < x.provenance.aliases[2].length; ++i) {
            RH.ReplayAlias memory a = x.provenance.aliases[2][i];
            if (a.scope != keccak256(abi.encode(oldLane, uint256(8)))) continue;
            a.scope = keccak256(abi.encode(newLane, uint256(8)));
            a.originalKey = _key(x.provenance.origins[0], a);
        }
        _sort(x.provenance.aliases[2]);
    }

    function _signatures(RH.Provenance memory p, bytes32 artist)
        private
        pure
        returns (IH.SignatureRow[] memory signatures)
    {
        uint256 count;
        for (uint256 i; i < p.journals[6].length; ++i) {
            if (p.journals[6][i].receipt.artistId == artist) ++count;
        }
        signatures = new IH.SignatureRow[](count);
        uint256 cursor;
        for (uint256 i; i < p.journals[6].length; ++i) {
            if (p.journals[6][i].receipt.artistId != artist) continue;
            signatures[cursor++] = IH.SignatureRow(p.journals[6][i].receipt.recordHash, "");
        }
    }

    function _seal(Fixture memory f) private pure {
        uint256 count;
        for (uint256 c; c < f.all.length; ++c) {
            ContentH.Bundle memory b = f.all[c].rows;
            for (uint256 s; s < b.original.sales.length; ++s) {
                Sale.Record memory sale = b.original.sales[s].item;
                // Independent original V1 preimage; generation and binding are deliberately
                // outside this hash and must be checked through the saved association.
                sale.recordHash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"),
                        f.provenance.origins[0].chainId,
                        f.provenance.origins[0].registry,
                        sale.terms.saleAdapter,
                        f.provenance.origins[0].core,
                        sale.terms.collectionId,
                        sale.terms.saleId,
                        sale.terms.saleConfigHash,
                        sale.artistId,
                        sale.signer,
                        sale.authorityClass,
                        sale.nonce,
                        sale.signedAt
                    )
                );
                b.original.sales[s].current = sale.recordHash;
            }
            count += b.original.policies.length + b.original.economics.length
            + b.original.sales.length + b.consents.length + b.royalties.length + b.freezes.length;
        }
        f.provenance.journals[6] = new RH.JournalEntry[](count);
        f.provenance.aliases[6] = new RH.ReplayAlias[](count);
        uint256 cursor;
        // Families interleave collections; each collection retains its own original order.
        for (uint256 family; family < 6; ++family) {
            for (uint256 c; c < f.all.length; ++c) {
                ContentH.Bundle memory b = f.all[c].rows;
                uint256 length = family == 0
                    ? b.original.policies.length
                    : family == 1
                        ? b.original.economics.length
                        : family == 2
                            ? b.original.sales.length
                            : family == 3
                                ? b.consents.length
                                : family == 4 ? b.royalties.length : b.freezes.length;
                for (uint256 r; r < length; ++r) {
                    (uint16 op, bytes32 record, bytes32 surface, bytes32 scope) = _row(b, family, r);
                    RH.Point memory point =
                        RH.Point(f.provenance.eras[0].originHash, 6, uint64(cursor + 1));
                    f.provenance.journals[6][cursor] = RH.JournalEntry(
                        RH.Position(point, cursor),
                        H.Receipt(op, b.original.artistId, b.original.collectionId, record)
                    );
                    RH.ReplayAlias memory a = f.provenance.aliases[6][cursor];
                    a.originHash = point.environmentHash;
                    a.ownerIndex = 6;
                    a.surface = surface;
                    a.scope = scope;
                    a.cell = T.ReplayCell(record, point.ownerRevision, 1, 2);
                    a.admittedAt = point;
                    a.originalKey = _key(f.provenance.origins[0], a);
                    ++cursor;
                }
            }
        }
        _sort(f.provenance.aliases[6]);
        f.provenance.eras[0].nativeCounts[6] = count;
        f.provenance.eras[0].checkpoints[6].ownerState.revision = uint64(count);
        f.provenance.eras[0].checkpoints[6].replayCount = count;
        f.provenance.eras[0].checkpoints[6].replayRoot =
            keccak256("opaque authenticated replay root");
        _header(f);
    }

    function _row(ContentH.Bundle memory b, uint256 family, uint256 r)
        private
        pure
        returns (uint16 op, bytes32 record, bytes32 surface, bytes32 scope)
    {
        if (family == 0) {
            return (
                14,
                b.original.policies[r].recordHash,
                keccak256("consent_finality.replay.policy_consent_key"),
                keccak256(
                    abi.encode(
                        b.original.collectionId,
                        b.original.keys[r].phaseId,
                        b.original.keys[r].policyHash
                    )
                )
            );
        }
        if (family == 1) {
            return (
                15,
                b.original.economics[r].item.recordHash,
                keccak256("consent_finality.replay.consent_key"),
                _economicsScope(b.original.economics[r])
            );
        }
        if (family == 2) {
            Sale.Record memory sale = b.original.sales[r].item;
            return (
                16,
                sale.recordHash,
                keccak256("consent_finality.replay.sale_consent_key"),
                keccak256(abi.encode(sale.terms, sale.bindingGeneration, sale.bindingHash))
            );
        }
        if (family == 3) {
            ContentOwner.ConsentRecord memory row = b.consents[r];
            return (
                17,
                row.recordHash,
                keccak256("consent_finality.replay.content_consent_key"),
                keccak256(
                    abi.encode(
                        keccak256(abi.encode(row.terms, row.bindingGeneration)), row.recordHash
                    )
                )
            );
        }
        if (family == 4) {
            ContentH.Royalty memory row = b.royalties[r];
            return (
                20,
                row.item.recordHash,
                keccak256("consent_finality.replay.freeze_key"),
                keccak256(abi.encode(row.terms, row.item.artistId, row.item.bindingGeneration))
            );
        }
        Content.FreezeRecord memory freeze = b.freezes[r];
        return (
            21,
            freeze.recordHash,
            keccak256("consent_finality.replay.freeze_key"),
            keccak256(
                abi.encode(
                    keccak256("CONTENT"),
                    b.original.collectionId,
                    freeze.bindingGeneration,
                    freeze.recordHash
                )
            )
        );
    }

    function _origin() private pure returns (RH.OriginEnvironment memory o) {
        o.chainId = 1;
        o.registry = address(0x101);
        o.coordinator = address(0x102);
        o.archive = address(0x103);
        o.core = address(0x104);
        o.manager = address(0x105);
        o.suiteConfigurationHash = keccak256("complete original suite");
        for (uint256 i; i < 7; ++i) {
            o.owners[i] = address(uint160(0x200 + i));
            o.ownerCodeHashes[i] = keccak256(abi.encode("original owner code", i));
        }
    }

    function _repeat(Fixture memory f) private pure {
        RH.OriginEnvironment[] memory origins = new RH.OriginEnvironment[](2);
        origins[0] = f.provenance.origins[0];
        origins[1] = abi.decode(abi.encode(origins[0]), (RH.OriginEnvironment));
        origins[1].registry = address(0x301);
        origins[1].coordinator = address(0x302);
        origins[1].archive = address(0x303);
        for (uint256 i; i < 7; ++i) {
            origins[1].owners[i] = address(uint160(0x400 + i));
        }
        RH.Era[] memory eras = new RH.Era[](2);
        eras[0] = f.provenance.eras[0];
        eras[1].originHash = RH.originHash(origins[1]);
        eras[1].priorImportCommitment = keccak256("original operation60 import");
        for (uint8 i; i < 7; ++i) {
            eras[1].checkpoints[i].schema = RH.CHECKPOINT;
            eras[1].checkpoints[i].ownerState =
                T.Snapshot(RH.ownerDomain(i), 1, _hash(i, 700), _hash(i, 701));
            eras[1].lowerRevisions[i] = 1;
        }
        uint256 count = f.provenance.aliases[6].length;
        eras[1].checkpoints[6].replayCount = count;
        eras[1].checkpoints[6].replayRoot = keccak256("rekeyed original replay inventory");
        RH.ReplayAlias[] memory aliases = new RH.ReplayAlias[](count * 2);
        for (uint256 i; i < count; ++i) {
            aliases[i] = f.provenance.aliases[6][i];
            aliases[count + i] = abi.decode(abi.encode(aliases[i]), (RH.ReplayAlias));
            aliases[count + i].originHash = eras[1].originHash;
            aliases[count + i].originalKey = _key(origins[1], aliases[count + i]);
        }
        _sort(aliases);
        f.provenance.origins = origins;
        f.provenance.eras = eras;
        f.provenance.aliases[6] = aliases;
        _header(f);
    }

    function _key(RH.OriginEnvironment memory o, RH.ReplayAlias memory a)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[a.ownerIndex],
                RH.ownerDomain(a.ownerIndex),
                a.surface,
                a.scope
            )
        );
    }

    function _sort(RH.ReplayAlias[] memory aliases) private pure {
        for (uint256 i = 1; i < aliases.length; ++i) {
            uint256 j = i;
            while (j > 0 && aliases[j].originalKey < aliases[j - 1].originalKey) {
                RH.ReplayAlias memory prior = aliases[j - 1];
                aliases[j - 1] = aliases[j];
                aliases[j] = prior;
                --j;
            }
        }
    }

    function _header(Fixture memory f) private pure {
        bytes32 commitment = RH.ownerProvenanceHash(f.provenance, 6);
        for (uint256 c; c < f.all.length; ++c) {
            f.all[c].rows.original.provenance = commitment;
        }
    }

    function _hash(uint256 collectionIndex, uint256 kind) private pure returns (bytes32) {
        return keccak256(abi.encode("original fixture record", collectionIndex, kind));
    }

    function _valid(Fixture memory f) private pure {
        Validation.validate(f.all, f.queries, RH.ownerProvenance(f.provenance, 6));
    }

    function _bad(Fixture memory f) private view {
        (bool ok,) = address(this)
            .staticcall(
                abi.encodeCall(this.check, (f.all, f.queries, RH.ownerProvenance(f.provenance, 6)))
            );
        require(!ok, "invalid generation/journal/replay data accepted");
    }

    function _badUses(Uses.Context memory x) private view {
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.checkUses, (x)));
        require(!ok, "invalid original grant/signature/nonce evidence accepted");
    }
}
