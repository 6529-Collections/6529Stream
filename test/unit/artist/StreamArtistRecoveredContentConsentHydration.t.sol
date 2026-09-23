// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    RecoveredEconomicsCoordinatorFixture
} from "./StreamArtistRecoveredEconomicsHydration.t.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredEconomicsHydration as Economics
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredEconomicsHydration.sol";
import {
    StreamArtistEconomicsAssociation as Association
} from "../../../smart-contracts/domains/artist/StreamArtistEconomicsAssociation.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistSaleHashes as SaleHashes
} from "../../../smart-contracts/domains/artist/StreamArtistSaleHashes.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    IStreamArtistEconomicsEvidence as Evidence
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

import {
    RecoveredDelegatedConsentCoordinatorFixture
} from "./StreamArtistRecoveredDelegatedConsentHydration.t.sol";
import {
    StreamArtistRecoveredContentConsentHydration as Checked
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentReads as ContentReads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentReads.sol";
import {
    StreamArtistRecoveredContentConsentValidation as ContentValidation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentValidation.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentHashes as ContentHashes
} from "../../../smart-contracts/domains/artist/StreamArtistContentHashes.sol";

interface RecoveredContentVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @dev Actual Consent writers/commits. Binding, class and grant facts are supplied at the
/// trusted Coordinator boundary; this component is not Identity signature or full op60 evidence.
contract RecoveredContentConsentCoordinatorFixture is RecoveredDelegatedConsentCoordinatorFixture {
    mapping(bytes32 => AH.Origin) private _contentWitnesses;
    constructor(address registry) RecoveredDelegatedConsentCoordinatorFixture(registry) { }

    function content(Content.Consent memory p, uint8 class_, uint256 nonce)
        external
        returns (bytes32 record)
    {
        T.Binding memory b = binding(true);
        address signer = class_ == 1 ? b.artistAddress : address(1704);
        record = consent()
            .recordContentConsentWithAuthority(
                T.ActionContext(17, address(this), consent().ownerStateSnapshotV2()),
                b,
                p,
                signer,
                nonce,
                R.AuthorityFact(b.artistId, signer, class_, class_ == 1 ? 1 : 3)
            );
        _remember(
            keccak256("consent_finality.replay.content_consent_key"),
            keccak256(abi.encode(keccak256(abi.encode(p, b.generation)), record))
        );
    }

    function royalty(T.RoyaltyFreeze memory p, uint8 class_, uint256 nonce, bool delegated)
        external
        returns (bytes32 record)
    {
        T.Binding memory b = binding(true);
        T.ActionContext memory c =
            T.ActionContext(20, address(this), consent().ownerStateSnapshotV2());
        address signer = class_ == 1 ? b.artistAddress : address(1704);
        if (delegated) {
            record = consent()
                .authorizeDelegatedRoyaltyFreeze(
                    c, b, p, address(1705), nonce, keccak256("fixture admitted delegate grant")
                );
        } else {
            record = consent()
                .authorizeRoyaltyFreezeWithAuthority(
                    c,
                    b,
                    p,
                    signer,
                    nonce,
                    R.AuthorityFact(b.artistId, signer, class_, class_ == 1 ? 1 : 3)
                );
        }
        _remember(
            keccak256("consent_finality.replay.freeze_key"),
            keccak256(abi.encode(p, b.artistId, b.generation))
        );
    }

    function freeze(Content.Freeze memory p, uint8 class_, uint256 nonce)
        external
        returns (bytes32 record)
    {
        T.Binding memory b = binding(true);
        address signer = class_ == 1 ? b.artistAddress : address(1704);
        record = consent()
            .authorizeContentFreezeWithAuthority(
                T.ActionContext(21, address(this), consent().ownerStateSnapshotV2()),
                b,
                p,
                signer,
                nonce,
                R.AuthorityFact(b.artistId, signer, class_, class_ == 1 ? 1 : 3)
            );
        _remember(
            keccak256("consent_finality.replay.freeze_key"),
            keccak256(abi.encode(keccak256("CONTENT"), p.collectionId, b.generation, record))
        );
    }

    function contentWitness(bytes32 key) external view returns (AH.Origin memory) {
        return _contentWitnesses[key];
    }

    function _remember(bytes32 surface, bytes32 scope) private {
        T.SuiteConfiguration memory s = this.authorityHydrationSuite();
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                s.registry,
                address(this),
                s.archive,
                address(consent()),
                RH.ownerDomain(6),
                surface,
                scope
            )
        );
        _contentWitnesses[key] = AH.Origin(surface, scope);
    }
}

/// @dev Isolated fixed-map import; final failure models rollback of the enclosing owner transaction.
contract RecoveredContentConsentHarness {
    mapping(bytes32 => bytes32) private _policies;
    mapping(bytes32 => bytes32) private _economics;
    mapping(bytes32 => bytes32) private _associated;
    mapping(bytes32 => Evidence.Association) private _associations;
    mapping(bytes32 => bytes32) private _delegations;
    mapping(bytes32 => Sale.Record) private _sales;
    mapping(bytes32 => bytes32) private _latest;
    mapping(bytes32 => ContentOwner.ConsentRecord) private _content;
    mapping(bytes32 => bytes32) private _latestContent;
    mapping(bytes32 => T.RoyaltyFreezeRecord) private _royalties;
    mapping(bytes32 => Content.FreezeRecord) private _freezes;
    mapping(bytes32 => bytes32) private _latestFreezes;
    error LateConsentFailure();

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms,
        T.RoyaltyFreeze[] memory royalties
    ) external view returns (Checked.Bundle memory) {
        return Checked.collect(source, q, p, terms, royalties);
    }

    function validate(Checked.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        external
        pure
    {
        Checked.validate(b, q, p);
    }

    function hydrate(AH.Query memory q, bytes memory raw, bool lateFailure) external {
        if (Checked.selected(raw)) {
            Checked.Bundle memory bundle = Checked.importState(
                _policies,
                _economics,
                _associated,
                _associations,
                _delegations,
                _sales,
                _latest,
                q,
                raw
            );
            Checked.importContent(
                _content, _latestContent, _royalties, _freezes, _latestFreezes, _delegations, bundle
            );
        } else if (Base.selected(raw)) {
            Base.importState(
                _policies,
                _economics,
                _associated,
                _associations,
                _delegations,
                _sales,
                _latest,
                q,
                raw
            );
        } else {
            Economics.importEither(
                _policies, _economics, _associated, _associations, _delegations, q, raw
            );
        }
        if (lateFailure) revert LateConsentFailure();
    }

    function policy(uint256 collection, AH.PolicyKey memory key) external view returns (bytes32) {
        return _policies[keccak256(abi.encode(collection, key.phaseId, key.policyHash))];
    }

    function record(T.EconomicsConsent memory t, AH.Query memory q)
        external
        view
        returns (bytes32, bytes32, Evidence.Association memory)
    {
        bytes32 r = _economics[keccak256(abi.encode(t))];
        return (r, _associated[Association.key(t, q.artistId, 1, q.bindingHash)], _associations[r]);
    }

    function delegation(bytes32 r) external view returns (bytes32) {
        return _delegations[r];
    }

    function association(bytes32 r) external view returns (Evidence.Association memory) {
        return _associations[r];
    }

    function sale(bytes32 r) external view returns (Sale.Record memory) {
        return _sales[r];
    }

    function latest(Sale.Consent memory p) external view returns (bytes32) {
        return _latest[SaleHashes.lookup(p.collectionId, p.saleId, p.saleConfigHash)];
    }

    function content(bytes32 hash) external view returns (ContentOwner.ConsentRecord memory) {
        return _content[hash];
    }

    function currentContent(Content.Consent memory p) external view returns (bytes32) {
        return _latestContent[keccak256(abi.encode(p, uint64(1)))];
    }

    function royalty(T.RoyaltyFreeze memory p, bytes32 artist)
        external
        view
        returns (T.RoyaltyFreezeRecord memory)
    {
        return _royalties[keccak256(abi.encode(p, artist, uint64(1)))];
    }

    function freeze(bytes32 hash) external view returns (Content.FreezeRecord memory) {
        return _freezes[hash];
    }

    function currentFreeze(address metadata, bytes32 lockClass) external view returns (bytes32) {
        return _latestFreezes[keccak256(abi.encode(uint256(9), uint64(1), metadata, lockClass))];
    }

    function seedOccupied(Content.Consent memory p) external {
        _latestContent[keccak256(abi.encode(p, uint64(1)))] = keccak256("occupied original scope");
    }

    function clearOccupied(Content.Consent memory p) external {
        delete _latestContent[keccak256(abi.encode(p, uint64(1)))];
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Checked.decode(q, p, raw);
    }
}

contract StreamArtistRecoveredContentConsentHydrationTest {
    RecoveredContentVm private constant vm =
        RecoveredContentVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Fixture {
        RecoveredContentConsentCoordinatorFixture source;
        RecoveredContentConsentHarness target;
        AH.Query query;
        RH.OwnerProvenance provenance;
        T.EconomicsConsent[] terms;
        T.RoyaltyFreeze[] royaltyTerms;
        Checked.Bundle bundle;
    }

    function testRecoveredContentLinkedWorkersPreserveLiteralEncodingAndHeads() external {
        Fixture memory f = _fixture();
        bytes32 sourceBefore = _sourceDigest(f);
        Checked.Bundle memory rows = ContentReads.collectRows(
            address(f.source.consent()), f.query, f.provenance, f.terms, f.royaltyTerms
        );
        ContentValidation.validate(rows, f.query, f.provenance);
        ContentReads.requireHeads(address(f.source.consent()), rows);
        bytes memory literal = abi.encode(
            keccak256("6529STREAM_ARTIST_RECOVERED_CONTENT_CONSENTS_V1"), uint16(1), rows
        );
        assert(keccak256(abi.encode(rows)) == keccak256(abi.encode(f.bundle)));
        assert(keccak256(literal) == keccak256(Checked.encode(f.bundle, f.query, f.provenance)));
        Checked.Bundle memory decoded = Checked.decode(f.query, f.provenance, literal);
        assert(keccak256(abi.encode(decoded)) == keccak256(abi.encode(rows)));
        bytes memory envelope =
            _outer(f, literal, RH.CONTENT_CONSENTS | RH.DELEGATED_CONSENT | RH.DIRECT_ECONOMICS);
        assert(keccak256(envelope) == keccak256(_encoded(f)));
        f.target.hydrate(f.query, envelope, false);
        _same(f);
        assert(_sourceDigest(f) == sourceBefore);
    }

    function testRecoveredContentActualSixMixedFamiliesRoundTripAllMaps() external {
        Fixture memory f = _fixture();
        assert(
            f.provenance.journal.length == 12 && f.provenance.eras[0].checkpoint.replayCount == 12
        );
        bytes32 sourceBefore = _sourceDigest(f);
        f.target.hydrate(f.query, _encoded(f), false);
        _same(f);
        assert(_sourceDigest(f) == sourceBefore);
    }

    function testRecoveredContentRepeatedExactConsentTermsKeepHistoryAndLastHead() external {
        Fixture memory f = _fixture();
        assert(
            keccak256(abi.encode(f.bundle.consents[0].terms))
                == keccak256(abi.encode(f.bundle.consents[1].terms))
        );
        assert(f.bundle.consents[0].authorityClass == 1 && f.bundle.consents[1].authorityClass == 3);
        assert(f.bundle.consents[0].recordHash != f.bundle.consents[1].recordHash);
        f.target.hydrate(f.query, _encoded(f), false);
        assert(f.target.content(f.bundle.consents[0].recordHash).recordHash != 0);
        assert(f.target.currentContent(_contentTerms()) == f.bundle.consents[1].recordHash);
        _same(f);
    }

    function testRecoveredContentOverlappingFreezeLocksKeepIndependentFinalHeads() external {
        Fixture memory f = _fixture();
        f.target.hydrate(f.query, _encoded(f), false);
        assert(
            f.target.currentFreeze(address(3401), bytes32(uint256(10)))
                == f.bundle.freezes[0].recordHash
        );
        assert(
            f.target.currentFreeze(address(3401), bytes32(uint256(20)))
                == f.bundle.freezes[1].recordHash
        );
        assert(
            f.target.currentFreeze(address(3401), bytes32(uint256(30)))
                == f.bundle.freezes[1].recordHash
        );
        assert(f.target.freeze(f.bundle.freezes[0].recordHash).lockClasses.length == 2);
        _same(f);
    }

    function testRecoveredContentDelegatedRoyaltyRemainsAnOriginalGrantAssociation() external {
        Fixture memory f = _fixture();
        assert(f.bundle.royalties[0].grant == 0 && f.bundle.royalties[1].grant != 0);
        f.target.hydrate(f.query, _encoded(f), false);
        for (uint256 i; i < 2; ++i) {
            assert(
                f.target.royalty(f.royaltyTerms[i], f.query.artistId).recordHash
                    == f.bundle.royalties[i].item.recordHash
            );
            assert(
                f.target.delegation(f.bundle.royalties[i].item.recordHash)
                    == f.bundle.royalties[i].grant
            );
        }
    }

    function testRecoveredContentRoyaltyWitnessOmissionExtraAndReorderingReject() external {
        Fixture memory f = _fixture();
        T.RoyaltyFreeze[] memory missing = new T.RoyaltyFreeze[](1);
        missing[0] = f.royaltyTerms[0];
        _collectReject(f, missing, T.UnsupportedProfile.selector);
        T.RoyaltyFreeze[] memory extra = new T.RoyaltyFreeze[](3);
        extra[0] = f.royaltyTerms[0];
        extra[1] = f.royaltyTerms[1];
        extra[2] = f.royaltyTerms[0];
        _collectReject(f, extra, T.UnsupportedProfile.selector);
        (f.royaltyTerms[0], f.royaltyTerms[1]) = (f.royaltyTerms[1], f.royaltyTerms[0]);
        _collectReject(f, f.royaltyTerms, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentReorderedAndOmittedRecordArraysReject() external {
        Fixture memory f = _fixture();
        Fixture memory bad = _copy(f);
        (bad.bundle.consents[0], bad.bundle.consents[1]) =
        (bad.bundle.consents[1], bad.bundle.consents[0]);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.freezes = new Content.FreezeRecord[](0);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        (bad.bundle.freezes[0], bad.bundle.freezes[1]) =
        (bad.bundle.freezes[1], bad.bundle.freezes[0]);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentSavedConsentAndEveryLockHeadMustMatchSource() external {
        Fixture memory f = _fixture();
        vm.mockCall(
            address(f.source.consent()),
            abi.encodeWithSignature(
                "contentConsentAt((uint256,address,bytes32,bytes32),uint64)",
                _contentTerms(),
                uint64(1)
            ),
            abi.encode(f.bundle.consents[0])
        );
        _collectReject(f, f.royaltyTerms, RH.InvalidRecoveredHydrationProfile.selector);
        vm.clearMockedCalls();
        vm.mockCall(
            address(f.source.consent()),
            abi.encodeWithSignature(
                "contentFreezeAt(uint256,uint64,address,bytes32)",
                uint256(9),
                uint64(1),
                address(3401),
                bytes32(uint256(10))
            ),
            abi.encode(f.bundle.freezes[1])
        );
        _collectReject(f, f.royaltyTerms, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentNoDelegationForOriginal17Or21AndNoHeldClass() external {
        Fixture memory f = _fixture();
        vm.mockCall(
            address(f.source.consent()),
            abi.encodeWithSignature("recordDelegation(bytes32)", f.bundle.consents[0].recordHash),
            abi.encode(keccak256("fabricated17grant"))
        );
        _collectReject(f, f.royaltyTerms, RH.InvalidRecoveredHydrationProfile.selector);
        vm.clearMockedCalls();
        vm.mockCall(
            address(f.source.consent()),
            abi.encodeWithSignature("recordDelegation(bytes32)", f.bundle.freezes[0].recordHash),
            abi.encode(keccak256("fabricated21grant"))
        );
        _collectReject(f, f.royaltyTerms, RH.InvalidRecoveredHydrationProfile.selector);
        vm.clearMockedCalls();
        Fixture memory bad = _copy(f);
        bad.bundle.consents[0].authorityClass = 2;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.freezes[1].authorityClass = 4;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentFreezeLockOrderAndRoyaltyScopeShapesReject() external {
        Fixture memory f = _fixture();
        Fixture memory bad = _copy(f);
        bad.bundle.freezes[0].lockClasses[1] = bad.bundle.freezes[0].lockClasses[0];
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.freezes[0].expectedStateHash = 0;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.royalties[0].terms.revenueClass = keccak256("PRIMARY");
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.royalties[1].terms = bad.bundle.royalties[0].terms;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentCompleteNativeKindsRevisionsAndNonceInventoryReject() external {
        Fixture memory f = _fixture();
        Fixture memory bad = _copy(f);
        bad.provenance.journal[1].receipt.operation = 52;
        _refresh(bad);
        _invalid(bad, T.UnsupportedProfile.selector);
        bad = _copy(f);
        ++bad.provenance.eras[0].checkpoint.ownerState.revision;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.provenance.eras[0].checkpoint.nonceIndexCount = 1;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentWrongReplaySurfaceCommitmentAndPointReject() external {
        Fixture memory f = _fixture();
        Fixture memory bad = _copy(f);
        uint256 index = _alias(bad, bad.bundle.consents[0].recordHash);
        bad.provenance.aliases[index].surface = keccak256("consent_finality.replay.freeze_key");
        bad.provenance.aliases[index].originalKey =
            _key(bad.provenance.origins[0], bad.provenance.aliases[index]);
        _sort(bad.provenance.aliases);
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        index = _alias(bad, bad.bundle.royalties[0].item.recordHash);
        bad.provenance.aliases[index].cell.commitment = keccak256("unmatched freeze");
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        index = _alias(bad, bad.bundle.freezes[1].recordHash);
        bad.provenance.aliases[index].admittedAt.ownerRevision = 1;
        bad.provenance.aliases[index].cell.touchedRevision = 1;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentAliasOmissionAndDuplicateNativeCannotProjectHistory() external {
        Fixture memory f = _fixture();
        Fixture memory bad = _copy(f);
        RH.ReplayAlias[] memory short_ = new RH.ReplayAlias[](11);
        for (uint256 i; i < 11; ++i) {
            short_[i] = bad.provenance.aliases[i];
        }
        bad.provenance.aliases = short_;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProvenance.selector);
        bad = _copy(f);
        bad.bundle.consents[1] = bad.bundle.consents[0];
        bad.provenance.journal[6].receipt.recordHash = bad.provenance.journal[1].receipt.recordHash;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentLateFailureRestoresBothImportHalvesAndExactRetry() external {
        Fixture memory f = _fixture();
        bytes memory raw = _encoded(f);
        bytes32 original = _sourceDigest(f);
        _reject(
            address(f.target),
            abi.encodeCall(f.target.hydrate, (f.query, raw, true)),
            RecoveredContentConsentHarness.LateConsentFailure.selector
        );
        _empty(f);
        assert(_sourceDigest(f) == original);
        f.target.hydrate(f.query, raw, false);
        _same(f);
        assert(_sourceDigest(f) == original);
        _reject(
            address(f.target),
            abi.encodeCall(f.target.hydrate, (f.query, raw, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        _same(f);
    }

    function testRecoveredContentOccupiedSecondHalfRollsBackEarlierBaseMaps() external {
        Fixture memory f = _fixture();
        bytes memory raw = _encoded(f);
        f.target.seedOccupied(_contentTerms());
        _reject(
            address(f.target),
            abi.encodeCall(f.target.hydrate, (f.query, raw, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        assert(
            f.target.policy(9, f.query.policies[0]) == 0
                && f.target.sale(f.bundle.original.sales[0].item.recordHash).recordHash == 0
        );
        assert(f.target.currentContent(_contentTerms()) == keccak256("occupied original scope"));
        f.target.clearOccupied(_contentTerms());
        _empty(f);
        f.target.hydrate(f.query, raw, false);
        _same(f);
    }

    function testRecoveredContentNoNewRowsKeepsOriginalDelegatedCodecBytes() external {
        Fixture memory f = _start();
        f.source
            .policy(
                T.PolicyConsent(9, f.query.policies[0].phaseId, f.query.policies[0].policyHash),
                1,
                10
            );
        f.source
            .delegatedPolicy(
                T.PolicyConsent(9, f.query.policies[1].phaseId, f.query.policies[1].policyHash)
            );
        f.provenance = _local(f.source);
        Base.Bundle memory b = Base.collect(
            address(f.source.consent()), f.query, f.provenance, new T.EconomicsConsent[](0)
        );
        bytes memory semantic = Base.encode(b, f.query, f.provenance);
        bytes memory raw = _outer(f, semantic, RH.DELEGATED_CONSENT);
        assert(!Checked.selected(raw) && Base.selected(raw));
        f.target.hydrate(f.query, raw, false);
        assert(f.target.policy(9, f.query.policies[0]) == b.policies[0].recordHash);
        assert(f.target.delegation(b.policies[1].recordHash) == b.policies[1].grant);
        assert(keccak256(semantic) == keccak256(Base.encode(b, f.query, f.provenance)));
    }

    function testRecoveredContentCanonicalEncodingAndFeatureCannotBeOmitted() external {
        Fixture memory f = _fixture();
        bytes memory semantic = Checked.encode(f.bundle, f.query, f.provenance);
        _reject(
            address(f.target),
            abi.encodeCall(
                f.target.decode, (f.query, f.provenance, bytes.concat(semantic, hex"00"))
            ),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        bytes memory old = _outer(
            f,
            abi.encode(Base.SCHEMA, RH.VERSION, f.bundle.original),
            RH.DELEGATED_CONSENT | RH.DIRECT_ECONOMICS
        );
        assert(!Checked.selected(old));
        _reject(
            address(f.target),
            abi.encodeCall(f.target.hydrate, (f.query, old, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        _empty(f);
    }

    function testRecoveredContentOnly17NeedsNoInventedRatificationOrRoyaltyWitness() external {
        Fixture memory f = _start();
        f.query.policies = new AH.PolicyKey[](0);
        f.terms = new T.EconomicsConsent[](0);
        f.royaltyTerms = new T.RoyaltyFreeze[](0);
        f.source.content(_contentTerms(), 3, 77);
        f.provenance = _local(f.source);
        f.bundle = f.target
            .collect(address(f.source.consent()), f.query, f.provenance, f.terms, f.royaltyTerms);
        assert(
            f.bundle.original.policies.length == 0 && f.bundle.original.economics.length == 0
                && f.bundle.royalties.length == 0 && f.bundle.freezes.length == 0
        );
        bytes memory raw =
            _outer(f, Checked.encode(f.bundle, f.query, f.provenance), RH.CONTENT_CONSENTS);
        f.target.hydrate(f.query, raw, false);
        assert(f.target.currentContent(_contentTerms()) == f.bundle.consents[0].recordHash);
        _same(f);
    }

    function testRecoveredContentActualForeignCollectionSuffixCannotBeDropped() external {
        Fixture memory f = _fixture();
        Content.Consent memory p = _contentTerms();
        p.collectionId = 10;
        // Genuine producer at this trusted Coordinator component boundary. Upstream Binding
        // resolution is supplied by the fixture and is not claimed as a complete registry flow.
        f.source.content(p, 1, 777);
        f.provenance = _local(f.source);
        _collectReject(f, f.royaltyTerms, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredContentSyntheticRepeatedEraRetainsAClocksAndBLowerRevision() external {
        Fixture memory f = _fixture();
        _secondEra(f);
        // A records are original writer results; B is a pure transport component certificate,
        // not evidence that a seven-owner repeated import or fresh B authorization executed.
        f.target.validate(f.bundle, f.query, f.provenance);
        assert(
            f.provenance.journal[11].position.point.ownerRevision
                > f.provenance.journal[12].position.point.ownerRevision
        );
        f.target.hydrate(f.query, _encoded(f), false);
        assert(f.target.currentContent(_contentTerms()) == f.bundle.consents[2].recordHash);
        assert(
            f.target.content(f.bundle.consents[0].recordHash).recordHash
                == f.bundle.consents[0].recordHash
        );
        assert(
            f.target.currentFreeze(address(3401), bytes32(uint256(10)))
                == f.bundle.freezes[0].recordHash
        );
        Fixture memory bad = _copy(f);
        for (uint256 i; i < bad.provenance.aliases.length; ++i) {
            RH.ReplayAlias memory a = bad.provenance.aliases[i];
            if (
                a.originHash == bad.provenance.eras[1].originHash
                    && a.admittedAt.environmentHash == bad.provenance.eras[0].originHash
            ) {
                bad.provenance.aliases[i].admittedAt =
                    RH.Point(bad.provenance.eras[1].originHash, 6, 2);
                bad.provenance.aliases[i].cell.touchedRevision = 2;
                break;
            }
        }
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function _start() private returns (Fixture memory f) {
        f.source = new RecoveredContentConsentCoordinatorFixture(address(8700));
        f.target = new RecoveredContentConsentHarness();
        T.Binding memory b = f.source.binding(true);
        f.query.artistId = b.artistId;
        f.query.collectionId = 9;
        f.query.bindingHash = b.bindingHash;
        f.query.policies = new AH.PolicyKey[](2);
        f.query.policies[0] = AH.PolicyKey(bytes32(uint256(1)), bytes32(uint256(101)));
        f.query.policies[1] = AH.PolicyKey(bytes32(uint256(2)), bytes32(uint256(102)));
    }

    function _fixture() private returns (Fixture memory f) {
        f = _start();
        f.terms = new T.EconomicsConsent[](2);
        f.terms[0] = _terms(0);
        f.terms[1] = _terms(1);
        f.royaltyTerms = new T.RoyaltyFreeze[](2);
        f.royaltyTerms[0] = _royaltyTerms(0);
        f.royaltyTerms[1] = _royaltyTerms(1);
        f.source
            .policy(
                T.PolicyConsent(9, f.query.policies[0].phaseId, f.query.policies[0].policyHash),
                1,
                10
            );
        f.source.content(_contentTerms(), 1, 11);
        f.source.economics(f.terms[0], 1, 12, false);
        f.source.royalty(f.royaltyTerms[0], 3, 13, false);
        f.source.freeze(_freezeTerms(false), 1, 14);
        f.source.sale(_saleTerms(0), 3, 15, false);
        f.source.content(_contentTerms(), 3, 16);
        f.source.royalty(f.royaltyTerms[1], 1, 17, true);
        f.source.freeze(_freezeTerms(true), 3, 18);
        f.source
            .delegatedPolicy(
                T.PolicyConsent(9, f.query.policies[1].phaseId, f.query.policies[1].policyHash)
            );
        f.source.economics(f.terms[1], 1, 19, true);
        f.source.sale(_saleTerms(1), 1, 20, true);
        f.provenance = _local(f.source);
        f.bundle = f.target
            .collect(address(f.source.consent()), f.query, f.provenance, f.terms, f.royaltyTerms);
    }

    function _terms(uint256 i) private pure returns (T.EconomicsConsent memory) {
        return T.EconomicsConsent(9, address(1901), bytes32(uint256(1902)), 0, 0, bytes32(i + 1903));
    }

    function _royaltyTerms(uint256 i) private pure returns (T.RoyaltyFreeze memory) {
        return T.RoyaltyFreeze(address(3301), 9, keccak256("ROYALTY_ERC2981"), bytes32(i + 3302));
    }

    function _contentTerms() private pure returns (Content.Consent memory) {
        return Content.Consent(
            9,
            address(3401),
            keccak256("actual metadata family"),
            keccak256("exact new content state")
        );
    }

    function _freezeTerms(bool later) private pure returns (Content.Freeze memory p) {
        p.collectionId = 9;
        p.metadataContract = address(3401);
        p.expectedStateHash = keccak256(abi.encode("original freeze state", later));
        p.lockClasses = new bytes32[](2);
        p.lockClasses[0] = bytes32(uint256(later ? 20 : 10));
        p.lockClasses[1] = bytes32(uint256(later ? 30 : 20));
    }

    function _saleTerms(uint256 i) private pure returns (Sale.Consent memory) {
        return Sale.Consent(
            9,
            address(uint160(2100 + i)),
            keccak256("shared sale id"),
            keccak256("shared sale config")
        );
    }

    function _local(RecoveredContentConsentCoordinatorFixture source)
        private
        view
        returns (RH.OwnerProvenance memory p)
    {
        T.SuiteConfiguration memory s = source.authorityHydrationSuite();
        p.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory o;
        o.chainId = block.chainid;
        o.registry = s.registry;
        o.coordinator = address(source);
        o.archive = s.archive;
        o.owners = s.owners;
        o.core = s.core;
        o.manager = s.mintManager;
        for (uint8 i; i < 7; ++i) {
            o.ownerCodeHashes[i] = s.owners[i].codehash;
        }
        o.suiteConfigurationHash = keccak256(abi.encode(s));
        p.origins[0] = o;
        StreamArtistOwner owner = source.owner(6);
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(o);
        p.eras[0].checkpoint = owner.authorityCheckpoint();
        p.eras[0].nativeCount = owner.artistNativeReceiptCount();
        p.journal = new RH.JournalEntry[](p.eras[0].nativeCount);
        for (uint256 i; i < p.journal.length; ++i) {
            p.journal[i] = RH.JournalEntry(
                RH.Position(
                    RH.Point(p.eras[0].originHash, 6, owner.artistNativeReceiptRevisionAt(i)), i
                ),
                owner.artistNativeReceiptAt(i)
            );
        }
        p.aliases = new RH.ReplayAlias[](p.eras[0].checkpoint.replayCount);
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a;
            a.ownerIndex = 6;
            a.originHash = p.eras[0].originHash;
            (a.originalKey, a.cell) = owner.authorityReplayAt(i);
            AH.Origin memory witness = source.replayWitness(a.originalKey);
            if (witness.surface == 0) witness = source.economicsWitness(a.originalKey);
            if (witness.surface == 0) witness = source.saleWitness(a.originalKey);
            if (witness.surface == 0) witness = source.contentWitness(a.originalKey);
            a.surface = witness.surface;
            a.scope = witness.scope;
            a.admittedAt = RH.Point(a.originHash, 6, a.cell.touchedRevision);
            p.aliases[i] = a;
        }
        _sort(p.aliases);
    }

    function _secondEra(Fixture memory f) private pure {
        RH.OwnerProvenance memory old = f.provenance;
        RH.OwnerProvenance memory p;
        p.origins = new RH.OriginEnvironment[](2);
        p.origins[0] = old.origins[0];
        p.origins[1] = abi.decode(abi.encode(old.origins[0]), (RH.OriginEnvironment));
        p.origins[1].registry = address(9501);
        p.origins[1].coordinator = address(9502);
        p.origins[1].owners[6] = address(9503);
        p.origins[1].suiteConfigurationHash = keccak256("synthetic Consent B suite");
        bytes32 origin = RH.originHash(p.origins[1]);
        p.eras = new RH.OwnerEra[](2);
        p.eras[0] = old.eras[0];
        p.eras[1] = abi.decode(abi.encode(old.eras[0]), (RH.OwnerEra));
        p.eras[1].originHash = origin;
        p.eras[1].lowerRevision = 1;
        p.eras[1].nativeCount = 1;
        p.eras[1].priorImportCommitment = keccak256("synthetic prior complete import");
        p.eras[1].checkpoint.ownerState.revision = 2;
        p.eras[1].checkpoint.replayCount = 13;
        ContentOwner.ConsentRecord memory r =
            abi.decode(abi.encode(f.bundle.consents[1]), (ContentOwner.ConsentRecord));
        RH.OriginEnvironment memory o = p.origins[1];
        r.recordHash = ContentHashes.consentRecord(
            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
            r.terms,
            r.artistId,
            address(1704),
            3,
            999,
            2000
        );
        ContentOwner.ConsentRecord[] memory content_ = new ContentOwner.ConsentRecord[](3);
        content_[0] = f.bundle.consents[0];
        content_[1] = f.bundle.consents[1];
        content_[2] = r;
        f.bundle.consents = content_;
        p.journal = new RH.JournalEntry[](13);
        for (uint256 i; i < 12; ++i) {
            p.journal[i] = old.journal[i];
        }
        p.journal[12] = RH.JournalEntry(
            RH.Position(RH.Point(origin, 6, 2), 0), H.Receipt(17, f.query.artistId, 9, r.recordHash)
        );
        p.aliases = new RH.ReplayAlias[](25);
        for (uint256 i; i < 12; ++i) {
            p.aliases[i] = old.aliases[i];
            RH.ReplayAlias memory a = abi.decode(abi.encode(old.aliases[i]), (RH.ReplayAlias));
            a.originHash = origin;
            a.originalKey = _key(o, a);
            p.aliases[12 + i] = a;
        }
        RH.ReplayAlias memory fresh;
        fresh.ownerIndex = 6;
        fresh.originHash = origin;
        fresh.surface = keccak256("consent_finality.replay.content_consent_key");
        fresh.scope = keccak256(abi.encode(keccak256(abi.encode(r.terms, uint64(1))), r.recordHash));
        fresh.cell = T.ReplayCell(r.recordHash, 2, 1, 2);
        fresh.admittedAt = RH.Point(origin, 6, 2);
        fresh.originalKey = _key(o, fresh);
        p.aliases[24] = fresh;
        _sort(p.aliases);
        f.provenance = p;
        _refresh(f);
    }

    function _outer(Fixture memory f, bytes memory semantic, uint256 features)
        private
        pure
        returns (bytes memory)
    {
        RH.OwnerProvenance memory p = f.provenance;
        RH.OwnerEra memory era = p.eras[p.eras.length - 1];
        if (p.eras.length > 1) features |= RH.REPEATED_IMPORT;
        RH.ExportHeader memory h = RH.ExportHeader(
            RH.PROFILE,
            RH.VERSION,
            6,
            era.originHash,
            era.priorImportCommitment,
            keccak256(semantic),
            RH.ownerProvenanceHash(p, 6),
            RH.aliasesHash(6, p.aliases),
            features,
            p.journal.length,
            p.aliases.length,
            p.eras.length
        );
        Payload.Payload memory payload;
        payload.provenance = p;
        payload.semanticState = semantic;
        payload.nonces = new RH.NonceInventory[](0);
        payload.publications = new Publications.Row[](0);
        return Payload.encode(6, h, payload);
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
                o.owners[6],
                RH.ownerDomain(6),
                a.surface,
                a.scope
            )
        );
    }

    function _sort(RH.ReplayAlias[] memory aliases) private pure {
        for (uint256 i = 1; i < aliases.length; ++i) {
            RH.ReplayAlias memory a = aliases[i];
            uint256 j = i;
            while (j != 0 && aliases[j - 1].originalKey > a.originalKey) {
                aliases[j] = aliases[j - 1];
                --j;
            }
            aliases[j] = a;
        }
    }

    function _same(Fixture memory f) private view {
        for (uint256 i; i < f.bundle.original.policies.length; ++i) {
            DH.Policy memory p = f.bundle.original.policies[i];
            assert(
                f.target.policy(9, f.query.policies[i]) == p.recordHash
                    && f.target.delegation(p.recordHash) == p.grant
            );
        }
        for (uint256 i; i < f.bundle.original.economics.length; ++i) {
            Base.Economics memory e = f.bundle.original.economics[i];
            (bytes32 r, bytes32 associated, Evidence.Association memory a) =
                f.target.record(e.item.terms, f.query);
            assert(r == e.item.recordHash && associated == r && f.target.delegation(r) == e.grant);
            assert(keccak256(abi.encode(a)) == keccak256(abi.encode(e.item.association)));
        }
        for (uint256 i; i < f.bundle.original.sales.length; ++i) {
            DH.Sale memory s = f.bundle.original.sales[i];
            assert(
                keccak256(abi.encode(f.target.sale(s.item.recordHash)))
                    == keccak256(abi.encode(s.item))
            );
            assert(
                f.target.delegation(s.item.recordHash) == s.grant
                    && f.target.latest(s.item.terms) == s.current
            );
        }
        for (uint256 i; i < f.bundle.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = f.bundle.consents[i];
            assert(
                keccak256(abi.encode(f.target.content(r.recordHash))) == keccak256(abi.encode(r))
            );
            assert(f.target.delegation(r.recordHash) == 0);
            assert(
                f.target.currentContent(r.terms)
                    == f.source.consent().contentConsentAt(r.terms, 1).recordHash
            );
        }
        for (uint256 i; i < f.bundle.royalties.length; ++i) {
            Checked.Royalty memory r = f.bundle.royalties[i];
            assert(
                keccak256(abi.encode(f.target.royalty(r.terms, f.query.artistId)))
                    == keccak256(abi.encode(r.item))
            );
            assert(f.target.delegation(r.item.recordHash) == r.grant);
        }
        for (uint256 i; i < f.bundle.freezes.length; ++i) {
            Content.FreezeRecord memory r = f.bundle.freezes[i];
            assert(
                keccak256(abi.encode(f.target.freeze(r.recordHash))) == keccak256(abi.encode(r))
                    && f.target.delegation(r.recordHash) == 0
            );
            for (uint256 j; j < r.lockClasses.length; ++j) {
                assert(
                    f.target.currentFreeze(r.metadataContract, r.lockClasses[j])
                        == f.source
                        .consent()
                        .contentFreezeAt(9, 1, r.metadataContract, r.lockClasses[j])
                        .recordHash
                );
            }
        }
    }

    function _empty(Fixture memory f) private view {
        Evidence.Association memory emptyAssociation;
        Sale.Record memory emptySale;
        for (uint256 i; i < f.bundle.original.policies.length; ++i) {
            assert(
                f.target.policy(9, f.query.policies[i]) == 0
                    && f.target.delegation(f.bundle.original.policies[i].recordHash) == 0
            );
        }
        for (uint256 i; i < f.bundle.original.economics.length; ++i) {
            assert(
                keccak256(
                    abi.encode(f.target.association(f.bundle.original.economics[i].item.recordHash))
                ) == keccak256(abi.encode(emptyAssociation))
            );
            (bytes32 r, bytes32 a, Evidence.Association memory association) =
                f.target.record(f.bundle.original.economics[i].item.terms, f.query);
            assert(
                r == 0 && a == 0
                    && keccak256(abi.encode(association)) == keccak256(abi.encode(emptyAssociation))
                    && f.target.delegation(f.bundle.original.economics[i].item.recordHash) == 0
            );
        }
        for (uint256 i; i < f.bundle.original.sales.length; ++i) {
            DH.Sale memory s = f.bundle.original.sales[i];
            assert(
                keccak256(abi.encode(f.target.sale(s.item.recordHash)))
                        == keccak256(abi.encode(emptySale)) && f.target.latest(s.item.terms) == 0
                    && f.target.delegation(s.item.recordHash) == 0
            );
        }
        ContentOwner.ConsentRecord memory emptyContent;
        Content.FreezeRecord memory emptyFreeze;
        T.RoyaltyFreezeRecord memory emptyRoyalty;
        for (uint256 i; i < f.bundle.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = f.bundle.consents[i];
            assert(
                keccak256(abi.encode(f.target.content(r.recordHash)))
                        == keccak256(abi.encode(emptyContent))
                    && f.target.currentContent(r.terms) == 0
                    && f.target.delegation(r.recordHash) == 0
            );
        }
        for (uint256 i; i < f.bundle.royalties.length; ++i) {
            Checked.Royalty memory r = f.bundle.royalties[i];
            assert(
                keccak256(abi.encode(f.target.royalty(r.terms, f.query.artistId)))
                        == keccak256(abi.encode(emptyRoyalty))
                    && f.target.delegation(r.item.recordHash) == 0
            );
        }
        for (uint256 i; i < f.bundle.freezes.length; ++i) {
            Content.FreezeRecord memory r = f.bundle.freezes[i];
            assert(
                keccak256(abi.encode(f.target.freeze(r.recordHash)))
                        == keccak256(abi.encode(emptyFreeze))
                    && f.target.delegation(r.recordHash) == 0
            );
            for (uint256 j; j < r.lockClasses.length; ++j) {
                assert(f.target.currentFreeze(r.metadataContract, r.lockClasses[j]) == 0);
            }
        }
    }

    function _encoded(Fixture memory f) private pure returns (bytes memory) {
        return _outer(
            f,
            Checked.encode(f.bundle, f.query, f.provenance),
            RH.CONTENT_CONSENTS | RH.DELEGATED_CONSENT | RH.DIRECT_ECONOMICS
        );
    }

    function _sourceDigest(Fixture memory f) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                f.source.owner(6).authorityCheckpoint(),
                f.target
                    .collect(
                        address(f.source.consent()), f.query, f.provenance, f.terms, f.royaltyTerms
                    )
            )
        );
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function _refresh(Fixture memory f) private pure {
        f.bundle.original.provenance = RH.ownerProvenanceHash(f.provenance, 6);
    }

    function _invalid(Fixture memory f, bytes4 expected) private {
        _reject(
            address(f.target),
            abi.encodeCall(f.target.validate, (f.bundle, f.query, f.provenance)),
            expected
        );
    }

    function _collectReject(Fixture memory f, T.RoyaltyFreeze[] memory royalties, bytes4 expected)
        private
    {
        _reject(
            address(f.target),
            abi.encodeCall(
                f.target.collect,
                (address(f.source.consent()), f.query, f.provenance, f.terms, royalties)
            ),
            expected
        );
    }

    function _reject(address target, bytes memory input, bytes4 expected) private {
        (bool ok, bytes memory result) = target.call(input);
        assert(!ok && result.length >= 4 && bytes4(result) == expected);
    }

    function _alias(Fixture memory f, bytes32 record) private pure returns (uint256) {
        for (uint256 i; i < f.provenance.aliases.length; ++i) {
            if (f.provenance.aliases[i].cell.commitment == record) return i;
        }
        revert("fixture missing alias");
    }
}
