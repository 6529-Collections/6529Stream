// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryConsentWrites as Writes
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryConsentWrites.sol";
import {
    StreamArtistCompleteHistoryConsentSupplementImport as Supplement
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryConsentSupplementImport.sol";
import {
    StreamArtistRecoveredAggregateSanctionStorage as SanctionStorage
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionStorage.sol";
import {
    StreamArtistRecoveredHistoryContentWrites as RatificationStorage
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryContentWrites.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistSanctionState as Sanctions
} from "../../../smart-contracts/domains/artist/StreamArtistSanctionState.sol";
import {
    StreamArtistEconomicsAssociation as Association
} from "../../../smart-contracts/domains/artist/StreamArtistEconomicsAssociation.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    IStreamArtistEconomicsEvidence as Evidence
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistSanctionArchiveFacts as Facts
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";

interface CompleteHistoryConsentStorageVm {
    function expectRevert(bytes4) external;
}

/// @dev Typed storage boundary only; no source, signature, binding chronology or op60 claim.
contract CompleteHistoryConsentStorageHarness {
    mapping(bytes32 => bytes32) public policies;
    mapping(bytes32 => bytes32) public economics;
    mapping(bytes32 => bytes32) public associated;
    mapping(bytes32 => Evidence.Association) private associations;
    mapping(bytes32 => bytes32) public delegations;
    mapping(bytes32 => Sale.Record) private sales;
    mapping(bytes32 => bytes32) private latest;
    mapping(bytes32 => ContentOwner.ConsentRecord) private content;
    mapping(bytes32 => bytes32) public latestContent;
    mapping(bytes32 => T.RoyaltyFreezeRecord) private royalties;
    mapping(bytes32 => Content.FreezeRecord) private freezes;
    mapping(bytes32 => bytes32) public latestFreezes;
    Sanctions.State private sanctions;
    mapping(uint256 => T.RatificationRecord) private current;
    mapping(bytes32 => T.RatificationRecord) private ratifications;

    function applyRows(AH.Query[] memory queries, ContentH.Bundle[] memory rows) external {
        for (uint256 k; k < rows.length; ++k) {
            Writes.checkBase(
                policies,
                economics,
                associated,
                associations,
                delegations,
                sales,
                latest,
                queries[k],
                rows[k].original
            );
            Writes.checkContent(
                content, latestContent, royalties, freezes, latestFreezes, delegations, rows[k]
            );
        }
        for (uint256 k; k < rows.length; ++k) {
            Writes.installBase(
                policies,
                economics,
                associated,
                associations,
                delegations,
                sales,
                latest,
                queries[k],
                rows[k].original
            );
            Writes.installContent(
                content, latestContent, royalties, freezes, latestFreezes, delegations, rows[k]
            );
        }
    }

    function applySupplement(
        AH.Query[] memory queries,
        T.RatificationRecord[][] memory rows,
        H.Inventory memory history
    ) external {
        Supplement.checkRatifications(current, ratifications, queries, rows);
        SanctionStorage.install(sanctions, history);
        for (uint256 k; k < queries.length; ++k) {
            RatificationStorage.importRecords(
                current, ratifications, queries[k].collectionId, rows[k]
            );
        }
    }

    function dirtyAssociation(bytes32 key) external {
        associated[key] = bytes32(uint256(999));
    }

    function dirtyRoyalty(bytes32 key) external {
        royalties[key].recordHash = bytes32(uint256(999));
    }

    function dirtyContent(bytes32 key) external {
        content[key].recordHash = bytes32(uint256(999));
    }

    function dirtyCurrent(uint256 id) external {
        current[id].recordHash = bytes32(uint256(999));
    }

    function dirtySanction(bytes32 hash) external {
        sanctions.archives[hash] = hex"01";
    }

    function royalty(bytes32 key) external view returns (T.RoyaltyFreezeRecord memory) {
        return royalties[key];
    }

    function ratification(uint256 id) external view returns (T.RatificationRecord memory) {
        return current[id];
    }

    function sanction(bytes32 hash) external view returns (bytes32, bytes memory) {
        return (sanctions.records[hash].recordHash, sanctions.archives[hash]);
    }
}

/// @notice Synthetic exact-key and all-target storage vectors, independent of full admission.
contract StreamArtistCompleteHistoryConsentStorageTest {
    CompleteHistoryConsentStorageVm private constant vm =
        CompleteHistoryConsentStorageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FIRST = bytes32(uint256(101));
    bytes32 private constant SECOND = bytes32(uint256(102));

    function testCompleteConsentKeepsHistoricalEconomicsAndRoyaltyKeys() external {
        (AH.Query[] memory queries, ContentH.Bundle[] memory rows) = _rows();
        CompleteHistoryConsentStorageHarness target = new CompleteHistoryConsentStorageHarness();
        target.applyRows(queries, rows);
        for (uint256 i; i < 2; ++i) {
            EH.Row memory e = rows[0].original.economics[i].item;
            bytes32 key = Association.key(
                e.terms, i == 0 ? FIRST : SECOND, uint64(i + 1), e.association.bindingHash
            );
            require(target.associated(key) == e.recordHash, "historical economics association");
            ContentH.Royalty memory r = rows[0].royalties[i];
            key = keccak256(abi.encode(r.terms, i == 0 ? FIRST : SECOND, uint64(i + 1)));
            require(target.royalty(key).recordHash == r.item.recordHash, "historical royalty key");
            require(
                target.delegations(e.recordHash) == rows[0].original.economics[i].grant,
                "retained economics grant"
            );
            require(target.delegations(r.item.recordHash) == r.grant, "retained royalty grant");
        }
        EH.Row memory first = rows[0].original.economics[0].item;
        require(
            target.economics(first.association.payloadHash) == first.recordHash,
            "original payload record retained"
        );
        require(
            target.associated(
                    Association.key(first.terms, SECOND, 1, first.association.bindingHash)
                ) == 0,
            "relabelled historical economics"
        );
        ContentH.Royalty memory old = rows[0].royalties[0];
        require(
            target.royalty(keccak256(abi.encode(old.terms, SECOND, uint64(1)))).recordHash == 0,
            "relabelled historical royalty"
        );
    }

    function testCompleteConsentRepeatedContentAndOverlappingFreezeHeadsKeepLastOriginal()
        external
    {
        (AH.Query[] memory queries, ContentH.Bundle[] memory rows) = _rows();
        CompleteHistoryConsentStorageHarness target = new CompleteHistoryConsentStorageHarness();
        target.applyRows(queries, rows);
        ContentOwner.ConsentRecord memory r = rows[1].consents[1];
        require(
            target.latestContent(keccak256(abi.encode(r.terms, r.bindingGeneration)))
                == r.recordHash,
            "last content head"
        );
        Content.FreezeRecord memory f = rows[1].freezes[1];
        require(
            target.latestFreezes(
                keccak256(
                    abi.encode(
                        uint256(30), f.bindingGeneration, f.metadataContract, f.lockClasses[0]
                    )
                )
            ) == f.recordHash,
            "last freeze head"
        );
    }

    function testCompleteConsentOccupiedFormerEconomicsKeyRejectsBeforeFirstPolicyWrite() external {
        (AH.Query[] memory queries, ContentH.Bundle[] memory rows) = _rows();
        CompleteHistoryConsentStorageHarness target = new CompleteHistoryConsentStorageHarness();
        EH.Row memory e = rows[0].original.economics[0].item;
        target.dirtyAssociation(Association.key(e.terms, FIRST, 1, e.association.bindingHash));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applyRows(queries, rows);
        _emptyPolicy(target, rows);
    }

    function testCompleteConsentOccupiedFormerRoyaltyKeyRejectsBeforeAnyBaseWrite() external {
        (AH.Query[] memory queries, ContentH.Bundle[] memory rows) = _rows();
        CompleteHistoryConsentStorageHarness target = new CompleteHistoryConsentStorageHarness();
        ContentH.Royalty memory r = rows[0].royalties[0];
        target.dirtyRoyalty(keccak256(abi.encode(r.terms, FIRST, uint64(1))));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applyRows(queries, rows);
        _emptyPolicy(target, rows);
        require(
            target.economics(rows[0].original.economics[0].item.association.payloadHash) == 0,
            "partial economics"
        );
    }

    function testCompleteConsentLastCollectionContentTargetCheckedBeforeFirstCollectionWrites()
        external
    {
        (AH.Query[] memory queries, ContentH.Bundle[] memory rows) = _rows();
        CompleteHistoryConsentStorageHarness target = new CompleteHistoryConsentStorageHarness();
        target.dirtyContent(rows[1].consents[1].recordHash);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applyRows(queries, rows);
        _emptyPolicy(target, rows);
        require(target.delegations(rows[0].royalties[0].item.recordHash) == 0, "partial royalty");
    }

    function testCompleteConsentSupplementPreservesOriginalSanctionAndRatificationMaps() external {
        (AH.Query[] memory q,) = _rows();
        T.RatificationRecord[][] memory r = _ratifications();
        H.Inventory memory h = _sanctions();
        CompleteHistoryConsentStorageHarness target = new CompleteHistoryConsentStorageHarness();
        target.applySupplement(q, r, h);
        require(
            target.ratification(20).recordHash == r[0][1].recordHash
                && target.ratification(30).recordHash == 0,
            "original ratification head"
        );
        (bytes32 record, bytes memory archive) = target.sanction(h.sanctions[0].record.recordHash);
        require(
            record == h.sanctions[0].record.recordHash
                && keccak256(archive) == keccak256(h.sanctions[0].archiveBytes),
            "original sanction bytes"
        );
    }

    function testCompleteConsentEmptyLastRatificationHeadCheckedBeforeSanctionWrites() external {
        (AH.Query[] memory q,) = _rows();
        H.Inventory memory h = _sanctions();
        CompleteHistoryConsentStorageHarness target = new CompleteHistoryConsentStorageHarness();
        target.dirtyCurrent(30);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applySupplement(q, _ratifications(), h);
        (bytes32 record, bytes memory archive) = target.sanction(h.sanctions[0].record.recordHash);
        require(
            record == 0 && archive.length == 0 && target.ratification(20).recordHash == 0,
            "partial supplement"
        );
    }

    function testCompleteConsentOccupiedSanctionRefusesBeforeRatificationWrites() external {
        (AH.Query[] memory q,) = _rows();
        H.Inventory memory h = _sanctions();
        CompleteHistoryConsentStorageHarness target = new CompleteHistoryConsentStorageHarness();
        target.dirtySanction(h.sanctions[0].record.recordHash);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applySupplement(q, _ratifications(), h);
        require(target.ratification(20).recordHash == 0, "partial ratification");
    }

    function _emptyPolicy(
        CompleteHistoryConsentStorageHarness target,
        ContentH.Bundle[] memory rows
    ) private view {
        AH.PolicyKey memory key = rows[0].original.keys[0];
        require(
            target.policies(keccak256(abi.encode(uint256(20), key.phaseId, key.policyHash))) == 0,
            "partial policy"
        );
    }

    function _rows() private pure returns (AH.Query[] memory q, ContentH.Bundle[] memory rows) {
        q = new AH.Query[](2);
        rows = new ContentH.Bundle[](2);
        q[0].collectionId = 20;
        q[0].artistId = SECOND;
        q[1].collectionId = 30;
        q[1].artistId = FIRST;
        for (uint256 k; k < 2; ++k) {
            rows[k].original.collectionId = q[k].collectionId;
            rows[k].original.artistId = q[k].artistId;
        }
        rows[0].original.keys = new AH.PolicyKey[](1);
        rows[0].original.keys[0] = AH.PolicyKey(bytes32(uint256(1)), bytes32(uint256(2)));
        rows[0].original.policies = new DH.Policy[](1);
        rows[0].original.policies[0] = DH.Policy(bytes32(uint256(100)), bytes32(uint256(900)));
        rows[0].original.economics = new Base.Economics[](2);
        rows[0].royalties = new ContentH.Royalty[](2);
        T.EconomicsConsent memory terms =
            T.EconomicsConsent(20, address(0xD1), bytes32(uint256(3)), 0, 0, bytes32(uint256(4)));
        for (uint256 i; i < 2; ++i) {
            Evidence.Association memory a = Evidence.Association(
                i == 0 ? FIRST : SECOND,
                uint64(i + 1),
                bytes32(uint256(701 + i)),
                keccak256(abi.encode(terms)),
                bytes32(uint256(201))
            );
            rows[0].original.economics[i] = Base.Economics(
                EH.Row(bytes32(uint256(201 + i)), terms, a), bytes32(uint256(901 + i))
            );
            rows[0].royalties[i] = ContentH.Royalty(
                T.RoyaltyFreeze(address(0xD1), 20, bytes32(uint256(3)), bytes32(uint256(4))),
                T.RoyaltyFreezeRecord(
                    bytes32(uint256(301 + i)), i == 0 ? FIRST : SECOND, uint64(i + 1)
                ),
                bytes32(uint256(903 + i))
            );
        }
        rows[1].consents = new ContentOwner.ConsentRecord[](2);
        rows[1].freezes = new Content.FreezeRecord[](2);
        for (uint256 i; i < 2; ++i) {
            rows[1].consents[i] = ContentOwner.ConsentRecord(
                bytes32(uint256(501 + i)),
                FIRST,
                1,
                Content.Consent(30, address(0xD2), bytes32(uint256(1)), bytes32(uint256(2))),
                1
            );
            rows[1].freezes[i].recordHash = bytes32(uint256(601 + i));
            rows[1].freezes[i].artistId = FIRST;
            rows[1].freezes[i].bindingGeneration = 1;
            rows[1].freezes[i].metadataContract = address(0xD2);
            rows[1].freezes[i].lockClasses = new bytes32[](1);
            rows[1].freezes[i].lockClasses[0] = bytes32(uint256(1));
        }
    }

    function _ratifications() private pure returns (T.RatificationRecord[][] memory r) {
        r = new T.RatificationRecord[][](2);
        r[0] = new T.RatificationRecord[](2);
        r[0][0] = T.RatificationRecord(bytes32(uint256(401)), bytes32(uint256(1)), address(0xD2));
        r[0][1] = T.RatificationRecord(bytes32(uint256(402)), bytes32(uint256(2)), address(0xD2));
    }

    function _sanctions() private pure returns (H.Inventory memory h) {
        h.sanctions = new H.SanctionRow[](1);
        H.SanctionRow memory row;
        row.record.recordHash = bytes32(uint256(801));
        row.record.artistId = FIRST;
        row.record.bindingGeneration = 1;
        row.record.bindingHash = bytes32(uint256(701));
        row.record.terms.collectionId = 20;
        row.archiveBytes = bytes("original synthetic sanction archive");
        row.archiveFacts = Facts.Facts(
            row.record.recordHash,
            FIRST,
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1"),
            keccak256(row.archiveBytes),
            uint64(row.archiveBytes.length)
        );
        h.sanctions[0] = row;
    }
}
