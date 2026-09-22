// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CompleteHistoryConsentValidationFixture
} from "./StreamArtistCompleteHistoryConsentValidation.t.sol";
import {
    StreamArtistCompleteHistoryConsentSource as Source
} from "../../smart-contracts/domains/artist/StreamArtistCompleteHistoryConsentSource.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Rows
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistContentTypes as Content
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistDelegatedConsentOwner as Delegated
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import {
    IStreamArtistEconomicsEvidence as Evidence
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";

interface CompleteHistoryConsentSourceVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

/// @dev Any getter not explicitly bound to its original typed arguments fails closed.
contract CompleteHistoryConsentSourceBoundary {
    fallback() external {
        revert("unconfigured historical source getter");
    }
}

/// @notice Source adapter over complete synthetic owner6 evidence and exact typed getter responses.
/// @dev The admitted-owner boundary and getters are explicit mocks. Real Source, codec and complete
/// Validation execute. This is not Core, Safe, source-owner admission or seven-owner apply coverage.
contract StreamArtistCompleteHistoryConsentSourceTest is CompleteHistoryConsentValidationFixture {
    CompleteHistoryConsentSourceVm private constant sourceVm =
        CompleteHistoryConsentSourceVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function collectSource(Source.Context memory x) external view returns (bytes[] memory) {
        return Source.collect(x);
    }

    function testSourceRetainsFormerArtistsPendingHeadAndTrueUnboundCollection() external {
        (Fixture memory f, Source.Context memory x) = _sourceFixture();
        _assertSource(f, x);
    }

    function testSourceRejectsMissingHistoricalEconomicsLookupAndRestores() external {
        (Fixture memory f, Source.Context memory x) = _sourceFixture();
        Base.Economics memory r = f.all[0].rows.original.economics[0];
        bytes memory input = abi.encodeCall(
            Evidence.economicsRecordForBinding,
            (
                r.item.terms,
                r.item.association.artistId,
                r.item.association.bindingGeneration,
                r.item.association.bindingHash
            )
        );
        sourceVm.mockCall(x.source, input, abi.encode(bytes32(0)));
        _rejectSource(x);
        sourceVm.mockCall(x.source, input, abi.encode(r.item.recordHash));
        _assertSource(f, x);
    }

    function testSourceRejectsMissingFormerArtistRoyaltyRecordAndRestores() external {
        (Fixture memory f, Source.Context memory x) = _sourceFixture();
        ContentH.Royalty memory r = f.all[0].rows.royalties[0];
        bytes memory input = abi.encodeCall(
            Consent.royaltyFreezeRecord, (r.terms, r.item.artistId, r.item.bindingGeneration)
        );
        T.RoyaltyFreezeRecord memory empty;
        sourceVm.mockCall(x.source, input, abi.encode(empty));
        _rejectSource(x);
        sourceVm.mockCall(x.source, input, abi.encode(r.item));
        _assertSource(f, x);
    }

    function testSourceRejectsStaleRatificationHeadAndRestores() external {
        (Fixture memory f, Source.Context memory x) = _sourceFixture();
        uint256 collection = f.scope.collections[0].collectionId;
        bytes memory input = abi.encodeCall(Consent.firstReleaseRatification, (collection));
        T.RatificationRecord memory empty;
        sourceVm.mockCall(x.source, input, abi.encode(empty));
        _rejectSource(x);
        sourceVm.mockCall(
            x.source, input, abi.encode(f.ratifications[0][f.ratifications[0].length - 1])
        );
        _assertSource(f, x);
    }

    function testSourceRejectsDelegatedOriginalRatificationAndRestores() external {
        (Fixture memory f, Source.Context memory x) = _sourceFixture();
        bytes memory input =
            abi.encodeCall(Delegated.recordDelegation, (f.ratifications[0][0].recordHash));
        sourceVm.mockCall(x.source, input, abi.encode(bytes32(uint256(123))));
        _rejectSource(x);
        sourceVm.mockCall(x.source, input, abi.encode(bytes32(0)));
        _assertSource(f, x);
    }

    function testSourceRejectsGhostRatificationHeadOnUnboundCollectionAndRestores() external {
        (Fixture memory f, Source.Context memory x) = _sourceFixture();
        bytes memory input =
            abi.encodeCall(Consent.firstReleaseRatification, (f.scope.collections[1].collectionId));
        sourceVm.mockCall(x.source, input, abi.encode(f.ratifications[0][0]));
        _rejectSource(x);
        T.RatificationRecord memory empty;
        sourceVm.mockCall(x.source, input, abi.encode(empty));
        _assertSource(f, x);
    }

    function _sourceFixture() private returns (Fixture memory f, Source.Context memory x) {
        x.source = address(new CompleteHistoryConsentSourceBoundary());
        f = _chFixture(x.source, false);
        x.scope = f.scope;
        x.inventory = f.inventory;
        x.economics = new T.EconomicsConsent[][](f.all.length);
        x.royalties = new T.RoyaltyFreeze[][](f.all.length);
        RH.OwnerProvenance memory p = RH.ownerProvenance(f.inventory.provenance, 6);
        sourceVm.mockCall(
            address(Provenance),
            abi.encodeWithSelector(Provenance.validateOwnerSource.selector, p, uint8(6), x.source),
            abi.encode(RH.ownerProvenanceHash(p, 6))
        );
        for (uint256 k; k < f.all.length; ++k) {
            ContentH.Bundle memory b = f.all[k].rows;
            uint256 collection = f.scope.collections[k].collectionId;
            x.economics[k] = new T.EconomicsConsent[](b.original.economics.length);
            x.royalties[k] = new T.RoyaltyFreeze[](b.royalties.length);
            for (uint256 i; i < b.original.policies.length; ++i) {
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(
                        Consent.policyRecord,
                        (collection, b.original.keys[i].phaseId, b.original.keys[i].policyHash)
                    ),
                    abi.encode(b.original.policies[i].recordHash)
                );
                _grant(x.source, b.original.policies[i].recordHash, b.original.policies[i].grant);
            }
            for (uint256 i; i < b.original.economics.length; ++i) {
                Base.Economics memory r = b.original.economics[i];
                x.economics[k][i] = r.item.terms;
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(Evidence.economicsRecordAssociation, (r.item.recordHash)),
                    abi.encode(r.item.association)
                );
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(Consent.economicsRecord, (r.item.terms)),
                    abi.encode(r.item.association.originalRecord)
                );
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(
                        Evidence.economicsRecordForBinding,
                        (
                            r.item.terms,
                            r.item.association.artistId,
                            r.item.association.bindingGeneration,
                            r.item.association.bindingHash
                        )
                    ),
                    abi.encode(r.item.recordHash)
                );
                _grant(x.source, r.item.recordHash, r.grant);
            }
            for (uint256 i; i < b.original.sales.length; ++i) {
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(Sales.saleConsentRecord, (b.original.sales[i].item.recordHash)),
                    abi.encode(b.original.sales[i].item)
                );
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(
                        Sales.saleConsentAt,
                        (
                            collection,
                            b.original.sales[i].item.terms.saleId,
                            b.original.sales[i].item.terms.saleConfigHash
                        )
                    ),
                    abi.encode(b.original.sales[i].current)
                );
                _grant(x.source, b.original.sales[i].item.recordHash, b.original.sales[i].grant);
            }
            for (uint256 i; i < b.consents.length; ++i) {
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(ContentOwner.contentConsentRecord, (b.consents[i].recordHash)),
                    abi.encode(b.consents[i])
                );
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(
                        ContentOwner.contentConsentAt,
                        (b.consents[i].terms, b.consents[i].bindingGeneration)
                    ),
                    abi.encode(b.consents[i])
                );
                _grant(x.source, b.consents[i].recordHash, bytes32(0));
            }
            for (uint256 i; i < b.royalties.length; ++i) {
                ContentH.Royalty memory r = b.royalties[i];
                x.royalties[k][i] = r.terms;
                for (uint256 g; g < f.all[k].bindings.length; ++g) {
                    T.Binding memory binding_ = f.all[k].bindings[g];
                    if (!binding_.accepted || binding_.artistId != r.item.artistId) continue;
                    T.RoyaltyFreezeRecord memory item;
                    if (binding_.generation == r.item.bindingGeneration) item = r.item;
                    sourceVm.mockCall(
                        x.source,
                        abi.encodeCall(
                            Consent.royaltyFreezeRecord,
                            (r.terms, r.item.artistId, binding_.generation)
                        ),
                        abi.encode(item)
                    );
                }
                _grant(x.source, r.item.recordHash, r.grant);
            }
            for (uint256 i; i < b.freezes.length; ++i) {
                Content.FreezeRecord memory r = b.freezes[i];
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(ContentOwner.contentFreezeRecord, (r.recordHash)),
                    abi.encode(r)
                );
                for (uint256 l; l < r.lockClasses.length; ++l) {
                    sourceVm.mockCall(
                        x.source,
                        abi.encodeCall(
                            ContentOwner.contentFreezeAt,
                            (collection, r.bindingGeneration, r.metadataContract, r.lockClasses[l])
                        ),
                        abi.encode(r)
                    );
                }
                _grant(x.source, r.recordHash, bytes32(0));
            }
            T.RatificationRecord memory head;
            for (uint256 i; i < f.ratifications[k].length; ++i) {
                head = f.ratifications[k][i];
                sourceVm.mockCall(
                    x.source,
                    abi.encodeCall(Consent.ratificationRecord, (head.recordHash)),
                    abi.encode(head)
                );
                _grant(x.source, head.recordHash, bytes32(0));
            }
            sourceVm.mockCall(
                x.source,
                abi.encodeCall(Consent.firstReleaseRatification, (collection)),
                abi.encode(head)
            );
        }
    }

    function _grant(address source, bytes32 record, bytes32 grant) private {
        sourceVm.mockCall(
            source, abi.encodeCall(Delegated.recordDelegation, (record)), abi.encode(grant)
        );
    }

    function _assertSource(Fixture memory f, Source.Context memory x) private view {
        bytes[] memory encoded = Source.collect(x);
        assert(encoded.length == f.all.length);
        for (uint256 i; i < encoded.length; ++i) {
            (G.Consents memory all, T.RatificationRecord[] memory rats) = Rows.decode(encoded[i]);
            assert(keccak256(abi.encode(all)) == keccak256(abi.encode(f.all[i])));
            assert(keccak256(abi.encode(rats)) == keccak256(abi.encode(f.ratifications[i])));
        }
        Source.requireCurrent(x, encoded);
    }

    function _rejectSource(Source.Context memory x) private view {
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.collectSource, (x)));
        assert(!ok);
    }
}
