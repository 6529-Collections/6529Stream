// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    RecoveredEconomicsCoordinatorFixture
} from "./StreamArtistRecoveredEconomicsHydration.t.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Checked
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

/// @dev Actual Consent14/15/16 producers behind their fixed Coordinator. Admitted binding,
/// payout, authority and grant facts are fixture inputs, not proof of signatures/Identity uses.
contract RecoveredDelegatedConsentCoordinatorFixture is RecoveredEconomicsCoordinatorFixture {
    mapping(bytes32 => AH.Origin) private _saleWitnesses;

    constructor(address registry) RecoveredEconomicsCoordinatorFixture(registry) { }

    function sale(Sale.Consent memory p, uint8 class_, uint256 nonce, bool delegated)
        external
        returns (bytes32 record)
    {
        T.Binding memory b = binding(true);
        T.ActionContext memory c =
            T.ActionContext(16, address(this), consent().ownerStateSnapshotV2());
        address signer = class_ == 1 ? b.artistAddress : address(1704);
        if (delegated) {
            b.consentMode = 2;
            record = consent()
                .recordDelegatedSaleConsent(
                    c, b, p, address(1705), nonce, keccak256("fixture admitted delegate grant")
                );
        } else {
            record = consent()
                .recordSaleConsent(
                    c,
                    b,
                    p,
                    signer,
                    nonce,
                    R.AuthorityFact(b.artistId, signer, class_, class_ == 1 ? 1 : 3)
                );
        }
        T.SuiteConfiguration memory s = this.authorityHydrationSuite();
        bytes32 surface = keccak256("consent_finality.replay.sale_consent_key");
        bytes32 scope = keccak256(abi.encode(p, b.generation, b.bindingHash));
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
        _saleWitnesses[key] = AH.Origin(surface, scope);
    }

    function saleWitness(bytes32 key) external view returns (AH.Origin memory) {
        return _saleWitnesses[key];
    }
}

/// @dev Isolated map importer, deliberately without the seven-owner op60 admission boundary.
/// The dispatch is the concrete Consent host's branch; late failure models atomic caller rollback.
contract RecoveredDelegatedConsentHarness {
    mapping(bytes32 => bytes32) private _policies;
    mapping(bytes32 => bytes32) private _economics;
    mapping(bytes32 => bytes32) private _associated;
    mapping(bytes32 => Evidence.Association) private _associations;
    mapping(bytes32 => bytes32) private _delegations;
    mapping(bytes32 => Sale.Record) private _sales;
    mapping(bytes32 => bytes32) private _latest;
    error LateConsentFailure();

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms
    ) external view returns (Checked.Bundle memory) {
        return Checked.collect(source, q, p, terms);
    }

    function validate(Checked.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        external
        pure
    {
        Checked.validate(b, q, p);
    }

    function hydrate(AH.Query memory q, bytes memory raw, bool lateFailure) external {
        if (Checked.selected(raw)) {
            Checked.importState(
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
}

contract StreamArtistRecoveredDelegatedConsentHydrationTest {
    struct Fixture {
        RecoveredDelegatedConsentCoordinatorFixture source;
        RecoveredDelegatedConsentHarness target;
        AH.Query query;
        RH.OwnerProvenance provenance;
        T.EconomicsConsent[] terms;
        Checked.Bundle bundle;
    }

    function testDelegatedConsentActualMixedWritersPreserveEveryMapAndGrant() external {
        Fixture memory f = _fixture();
        bytes32 before_ = _sourceDigest(f);
        assert(f.provenance.journal.length == 7 && f.bundle.sales.length == 3);
        assert(f.bundle.policies[0].grant == 0 && f.bundle.policies[1].grant != 0);
        assert(f.bundle.economics[0].grant == 0 && f.bundle.economics[1].grant != 0);
        assert(f.bundle.sales[0].item.authorityClass == 1);
        assert(f.bundle.sales[1].item.authorityClass == 2 && f.bundle.sales[1].grant != 0);
        assert(f.bundle.sales[2].item.authorityClass == 3 && f.bundle.sales[2].grant == 0);
        bytes memory raw = _encoded(f);
        assert(Checked.selected(raw));
        f.target.hydrate(f.query, raw, false);
        _same(f);
        assert(_sourceDigest(f) == before_);
    }

    function testDelegatedConsentSameLookupRetainsOriginalVersionsAndExactFinalHead() external {
        Fixture memory f = _fixture();
        bytes32 finalHead = f.bundle.sales[2].item.recordHash;
        for (uint256 i; i < 3; ++i) {
            assert(f.bundle.sales[i].current == finalHead);
            assert(f.bundle.sales[i].item.terms.saleAdapter == address(uint160(2100 + i)));
            assert(
                _saleHash(f.provenance.origins[0], f.bundle.sales[i].item)
                    == f.bundle.sales[i].item.recordHash
            );
        }
        f.target.hydrate(f.query, _encoded(f), false);
        _same(f);
        Fixture memory bad = _copy(f);
        bad.bundle.sales[0].current = bad.bundle.sales[0].item.recordHash;
        _invalid(bad);
    }

    function testDelegatedConsentPolicySelectorsMayReorderButEconomicsMustFollowJournal() external {
        Fixture memory f = _fixture();
        AH.PolicyKey memory key = f.query.policies[0];
        f.query.policies[0] = f.query.policies[1];
        f.query.policies[1] = key;
        f.bundle = f.target.collect(address(f.source.consent()), f.query, f.provenance, f.terms);
        assert(f.bundle.policies[0].grant != 0);
        f.target.validate(f.bundle, f.query, f.provenance);
        T.EconomicsConsent memory first = f.terms[0];
        f.terms[0] = f.terms[1];
        f.terms[1] = first;
        _collectReject(f, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testDelegatedConsentRejectsMissingDuplicateExtraAndWrongWitnesses() external {
        Fixture memory original = _fixture();
        for (uint256 i; i < 7; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.terms = new T.EconomicsConsent[](0);
            if (i == 1) {
                f.terms = new T.EconomicsConsent[](1);
                f.terms[0] = original.terms[0];
            }
            if (i == 2) f.terms[1] = f.terms[0];
            if (i == 3) {
                f.terms = new T.EconomicsConsent[](3);
                f.terms[0] = original.terms[0];
                f.terms[1] = original.terms[1];
                f.terms[2] = _terms(9);
            }
            if (i == 4) f.query.policies = new AH.PolicyKey[](0);
            if (i == 5) f.query.policies[1] = f.query.policies[0];
            if (i == 6) f.query.policies[1].policyHash = keccak256("unadmitted policy");
            _collectReject(f, RH.InvalidRecoveredHydrationProfile.selector);
        }
    }

    function testDelegatedConsentRejectsOmittedReorderedAndExtraSaleRows() external {
        Fixture memory original = _fixture();
        for (uint256 i; i < 3; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) {
                f.bundle.sales = new DH.Sale[](2);
                f.bundle.sales[0] = original.bundle.sales[0];
                f.bundle.sales[1] = original.bundle.sales[1];
            }
            if (i == 1) {
                DH.Sale memory a = f.bundle.sales[0];
                f.bundle.sales[0] = f.bundle.sales[1];
                f.bundle.sales[1] = a;
            }
            if (i == 2) {
                f.bundle.sales = new DH.Sale[](4);
                for (uint256 j; j < 4; ++j) {
                    f.bundle.sales[j] = original.bundle.sales[j % 3];
                }
            }
            _invalid(f);
        }
    }

    function testDelegatedConsentOriginalSalePreimageAndAuthorityClassAreExact() external {
        Fixture memory original = _fixture();
        for (uint256 i; i < 9; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.bundle.sales[0].item.signer = address(99);
            if (i == 1) ++f.bundle.sales[0].item.nonce;
            if (i == 2) ++f.bundle.sales[0].item.signedAt;
            if (i == 3) f.bundle.sales[0].item.terms.saleAdapter = address(99);
            if (i == 4) f.bundle.sales[0].item.bindingGeneration = 2;
            if (i == 5) f.bundle.sales[0].item.bindingHash = keccak256("wrong binding");
            if (i == 6) f.bundle.sales[0].grant = keccak256("false delegate");
            if (i == 7) f.bundle.sales[1].grant = 0;
            if (i == 8) f.bundle.sales[2].item.authorityClass = 4;
            _invalid(f);
        }
        original.target.validate(original.bundle, original.query, original.provenance);
    }

    function testDelegatedConsentOriginalEconomicsAssociationCannotBeRebound() external {
        Fixture memory original = _fixture();
        for (uint256 i; i < 6; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.bundle.economics[0].item.association.artistId = bytes32(uint256(99));
            if (i == 1) f.bundle.economics[0].item.association.bindingGeneration = 2;
            if (i == 2) {
                f.bundle.economics[0].item.association.originalRecord = bytes32(uint256(99));
            }
            if (i == 3) f.bundle.economics[0].item.association.payloadHash = bytes32(uint256(99));
            if (i == 4) f.bundle.economics[0].item.terms.assignmentHash = bytes32(uint256(99));
            if (i == 5) f.bundle.economics[1] = f.bundle.economics[0];
            _invalid(f);
        }
    }

    function testDelegatedConsentUnsupportedActualRatificationAndBoundsRejectSeparately() external {
        Fixture memory f = _fixture();
        f.source.ratify();
        f.provenance = _local(f.source);
        _collectReject(f, T.UnsupportedProfile.selector);
        f = _fixture();
        f.bundle.sales = new DH.Sale[](129);
        _reject(
            address(f.target),
            abi.encodeCall(f.target.validate, (f.bundle, f.query, f.provenance)),
            T.UnsupportedProfile.selector
        );
    }

    function testDelegatedConsentCompletenessRejectsHiddenRevisionsNoncesAndDuplicates() external {
        Fixture memory original = _fixture();
        for (uint256 i; i < 4; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) ++f.provenance.eras[0].checkpoint.ownerState.revision;
            if (i == 1) f.provenance.eras[0].checkpoint.nonceIndexCount = 1;
            if (i == 2) f.provenance.eras[0].checkpoint.nonceRoot = bytes32(uint256(1));
            if (i == 3) f.provenance.journal[1].receipt = f.provenance.journal[0].receipt;
            _refresh(f);
            _invalid(f);
        }
    }

    function testDelegatedConsentRequiresExactReplayScopeStatusPointAndCompleteAliases() external {
        Fixture memory original = _fixture();
        for (uint256 i; i < 7; ++i) {
            Fixture memory f = _copy(original);
            RH.ReplayAlias memory a = f.provenance.aliases[0];
            if (i == 0) a.scope = bytes32(uint256(999));
            if (i == 1) a.surface = keccak256("wrong replay surface");
            if (i == 2) a.cell.commitment = bytes32(uint256(999));
            if (i == 3) a.cell.kind = 2;
            if (i == 4) a.cell.status = 1;
            if (i == 5) {
                a.cell.touchedRevision = a.cell.touchedRevision == 1 ? 2 : 1;
                a.admittedAt.ownerRevision = a.cell.touchedRevision;
            }
            a.originalKey = _key(f.provenance.origins[0], a);
            f.provenance.aliases[0] = a;
            if (i == 6) {
                RH.ReplayAlias[] memory shortened =
                    new RH.ReplayAlias[](f.provenance.aliases.length - 1);
                for (uint256 j; j < shortened.length; ++j) {
                    shortened[j] = f.provenance.aliases[j];
                }
                f.provenance.aliases = shortened;
                --f.provenance.eras[0].checkpoint.replayCount;
            }
            _sort(f.provenance.aliases);
            _refresh(f);
            _invalid(f);
        }
    }

    function testDelegatedConsentNewCodecRequiresExactFeatureBitsAndCanonicalEncoding() external {
        Fixture memory f = _fixture();
        bytes memory semantic = Checked.encode(f.bundle, f.query, f.provenance);
        for (uint256 i; i < 4; ++i) {
            bytes memory raw = abi.decode(abi.encode(semantic), (bytes));
            uint256 flags = RH.DELEGATED_CONSENT | RH.DIRECT_ECONOMICS;
            if (i == 0) assembly ("memory-safe") { mstore(add(raw, 32), 1) }
            if (i == 1) raw = bytes.concat(raw, bytes32(uint256(1)));
            if (i == 2) flags = RH.DIRECT_ECONOMICS;
            if (i == 3) flags = RH.DELEGATED_CONSENT;
            _reject(
                address(f.target),
                abi.encodeCall(f.target.hydrate, (f.query, _outer(f, raw, flags), false)),
                i == 2 ? bytes4(0) : RH.InvalidRecoveredHydrationProfile.selector
            );
            _empty(f);
        }
        f.target
            .hydrate(
                f.query, _outer(f, semantic, RH.DELEGATED_CONSENT | RH.DIRECT_ECONOMICS), false
            );
        _same(f);
    }

    function testDelegatedConsentOldPoliciesAndDirectEconomicsKeepTheirOriginalDispatch() external {
        for (uint256 withEconomics; withEconomics < 2; ++withEconomics) {
            Fixture memory f;
            f.source = new RecoveredDelegatedConsentCoordinatorFixture(
                address(uint160(8800 + withEconomics))
            );
            f.target = new RecoveredDelegatedConsentHarness();
            f.query = _query(f.source);
            for (uint256 i; i < 2; ++i) {
                f.source
                    .policy(
                        T.PolicyConsent(
                            9, f.query.policies[i].phaseId, f.query.policies[i].policyHash
                        ),
                        1,
                        i
                    );
            }
            f.terms = new T.EconomicsConsent[](withEconomics);
            if (withEconomics != 0) {
                f.terms[0] = _terms(0);
                f.source.economics(f.terms[0], 1, 5, false);
            }
            f.provenance = _local(f.source);
            bytes memory semantic;
            uint256 feature;
            if (withEconomics == 0) {
                semantic =
                    f.source.consent().recoveredAuthorityHydrationState(f.query, f.provenance);
            } else {
                feature = RH.DIRECT_ECONOMICS;
                semantic = Economics.encode(
                    Economics.collect(address(f.source.consent()), f.query, f.provenance, f.terms),
                    f.query,
                    f.provenance
                );
            }
            bytes32 original = keccak256(semantic);
            bytes memory raw = _outer(f, semantic, feature);
            assert(!Checked.selected(raw));
            _reject(
                address(f.target),
                abi.encodeCall(
                    f.target.hydrate,
                    (f.query, _outer(f, semantic, feature | RH.DELEGATED_CONSENT), false)
                ),
                bytes4(0)
            );
            f.target.hydrate(f.query, raw, false);
            assert(keccak256(semantic) == original);
            for (uint256 i; i < 2; ++i) {
                assert(
                    f.target.policy(9, f.query.policies[i])
                        == f.source.consent()
                            .policyRecord(
                                9, f.query.policies[i].phaseId, f.query.policies[i].policyHash
                            )
                );
            }
            if (withEconomics != 0) {
                (bytes32 a, bytes32 b,) = f.target.record(f.terms[0], f.query);
                assert(a != 0 && a == b && f.target.delegation(a) == 0);
            }
        }
    }

    function testDelegatedConsentLateFailureRollsBackAllMapsAndIdenticalRetrySucceeds() external {
        Fixture memory f = _fixture();
        bytes memory raw = _encoded(f);
        bytes32 sourceBefore = _sourceDigest(f);
        _reject(
            address(f.target),
            abi.encodeCall(f.target.hydrate, (f.query, raw, true)),
            RecoveredDelegatedConsentHarness.LateConsentFailure.selector
        );
        _empty(f);
        assert(_sourceDigest(f) == sourceBefore);
        f.target.hydrate(f.query, raw, false);
        _same(f);
        _reject(
            address(f.target),
            abi.encodeCall(f.target.hydrate, (f.query, raw, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        _same(f);
        assert(_sourceDigest(f) == sourceBefore);
    }

    function testDelegatedConsentStaleSourceAndForeignCollectionCannotHideSuffix() external {
        Fixture memory f = _fixture();
        f.source.sale(_saleTerms(8), 1, 80, false);
        _collectReject(f, RH.InvalidRecoveredHydrationProvenance.selector);
        f.provenance = _local(f.source);
        f.bundle = f.target.collect(address(f.source.consent()), f.query, f.provenance, f.terms);
        assert(f.bundle.sales.length == 4);
        Sale.Consent memory foreign = _saleTerms(9);
        foreign.collectionId = 10;
        f.source.sale(foreign, 1, 81, false);
        f.provenance = _local(f.source);
        _collectReject(f, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testDelegatedConsentWithoutEconomicsRejectsFalseEconomicsFeature() external {
        Fixture memory f;
        f.source = new RecoveredDelegatedConsentCoordinatorFixture(address(8802));
        f.target = new RecoveredDelegatedConsentHarness();
        f.query = _query(f.source);
        for (uint256 i; i < f.query.policies.length; ++i) {
            f.source
                .delegatedPolicy(
                    T.PolicyConsent(9, f.query.policies[i].phaseId, f.query.policies[i].policyHash)
                );
        }
        f.source.sale(_saleTerms(0), 1, 8, true);
        f.terms = new T.EconomicsConsent[](0);
        f.provenance = _local(f.source);
        f.bundle = f.target.collect(address(f.source.consent()), f.query, f.provenance, f.terms);
        bytes memory semantic = Checked.encode(f.bundle, f.query, f.provenance);
        _reject(
            address(f.target),
            abi.encodeCall(
                f.target.hydrate,
                (f.query, _outer(f, semantic, RH.DELEGATED_CONSENT | RH.DIRECT_ECONOMICS), false)
            ),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        _empty(f);
        f.target.hydrate(f.query, _outer(f, semantic, RH.DELEGATED_CONSENT), false);
        _same(f);
    }

    function testDelegatedConsentFlattenedSaleKeepsUltimateHashAndEveryRekeyedAlias() external {
        Fixture memory f = _fixture();
        _secondEra(f);
        // Explicit pure synthetic destination era. Original A rows were actually produced;
        // the B suffix and import certificate are component inputs, not a Safe/import claim.
        f.target.validate(f.bundle, f.query, f.provenance);
        assert(
            f.provenance.journal[0].position.point.ownerRevision
                < f.provenance.journal[7].position.point.ownerRevision
        );
        assert(
            f.provenance.journal[6].position.point.ownerRevision
                > f.provenance.journal[7].position.point.ownerRevision
        );
        Fixture memory bad = _copy(f);
        bad.bundle.sales[0].item.recordHash =
            _saleHash(bad.provenance.origins[1], bad.bundle.sales[0].item);
        _invalid(bad);
        bad = _copy(f);
        for (uint256 i; i < bad.provenance.aliases.length; ++i) {
            if (
                bad.provenance.aliases[i].originHash != bad.provenance.eras[1].originHash
                    || bad.provenance.aliases[i].admittedAt.environmentHash
                        != bad.provenance.eras[0].originHash
            ) continue;
            bad.provenance.aliases[i].admittedAt = RH.Point(bad.provenance.eras[1].originHash, 6, 2);
            bad.provenance.aliases[i].cell.touchedRevision = 2;
            break;
        }
        _refresh(bad);
        _invalid(bad);
        f.target.hydrate(f.query, _encoded(f), false);
        _same(f);
    }

    function _fixture() private returns (Fixture memory f) {
        f.source = new RecoveredDelegatedConsentCoordinatorFixture(address(8700));
        f.target = new RecoveredDelegatedConsentHarness();
        f.query = _query(f.source);
        f.terms = new T.EconomicsConsent[](2);
        f.terms[0] = _terms(0);
        f.terms[1] = _terms(1);
        f.source.economics(f.terms[0], 1, 10, false);
        f.source
            .policy(
                T.PolicyConsent(9, f.query.policies[0].phaseId, f.query.policies[0].policyHash),
                1,
                11
            );
        f.source.sale(_saleTerms(0), 1, 12, false);
        f.source.economics(f.terms[1], 1, 13, true);
        f.source
            .delegatedPolicy(
                T.PolicyConsent(9, f.query.policies[1].phaseId, f.query.policies[1].policyHash)
            );
        f.source.sale(_saleTerms(1), 1, 14, true);
        f.source.sale(_saleTerms(2), 3, 15, false);
        f.provenance = _local(f.source);
        f.bundle = f.target.collect(address(f.source.consent()), f.query, f.provenance, f.terms);
    }

    function _query(RecoveredDelegatedConsentCoordinatorFixture source)
        private
        view
        returns (AH.Query memory q)
    {
        T.Binding memory b = source.binding(true);
        q.artistId = b.artistId;
        q.collectionId = 9;
        q.bindingHash = b.bindingHash;
        q.policies = new AH.PolicyKey[](2);
        q.policies[0] = AH.PolicyKey(bytes32(uint256(1)), bytes32(uint256(101)));
        q.policies[1] = AH.PolicyKey(bytes32(uint256(2)), bytes32(uint256(102)));
    }

    function _terms(uint256 i) private pure returns (T.EconomicsConsent memory) {
        return T.EconomicsConsent(9, address(1901), bytes32(uint256(1902)), 0, 0, bytes32(i + 1903));
    }

    function _saleTerms(uint256 i) private pure returns (Sale.Consent memory) {
        return Sale.Consent(
            9,
            address(uint160(2100 + i)),
            keccak256("shared sale id"),
            keccak256("shared sale config")
        );
    }

    function _local(RecoveredDelegatedConsentCoordinatorFixture source)
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
            a.surface = witness.surface;
            a.scope = witness.scope;
            a.admittedAt = RH.Point(a.originHash, 6, a.cell.touchedRevision);
            p.aliases[i] = a;
        }
        _sort(p.aliases);
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

    function _encoded(Fixture memory f) private pure returns (bytes memory) {
        return _outer(
            f,
            Checked.encode(f.bundle, f.query, f.provenance),
            RH.DELEGATED_CONSENT | RH.DIRECT_ECONOMICS
        );
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
        p.origins[1].suiteConfigurationHash = keccak256("synthetic Consent successor era");
        bytes32 origin = RH.originHash(p.origins[1]);
        p.eras = new RH.OwnerEra[](2);
        p.eras[0] = old.eras[0];
        p.eras[1] = abi.decode(abi.encode(old.eras[0]), (RH.OwnerEra));
        p.eras[1].originHash = origin;
        p.eras[1].nativeCount = 1;
        p.eras[1].lowerRevision = 1;
        p.eras[1].priorImportCommitment = keccak256("synthetic prior complete import");
        p.eras[1].checkpoint.ownerState.revision = 2;
        p.eras[1].checkpoint.replayCount = old.journal.length + 1;
        Sale.Record memory r = abi.decode(abi.encode(f.bundle.sales[2].item), (Sale.Record));
        r.terms = _saleTerms(3);
        r.nonce = 20;
        ++r.signedAt;
        r.recordHash = _saleHash(p.origins[1], r);
        DH.Sale[] memory sales = new DH.Sale[](4);
        for (uint256 i; i < 3; ++i) {
            sales[i] = f.bundle.sales[i];
            sales[i].current = r.recordHash;
        }
        sales[3] = DH.Sale(r, 0, r.recordHash);
        f.bundle.sales = sales;
        p.journal = new RH.JournalEntry[](old.journal.length + 1);
        for (uint256 i; i < old.journal.length; ++i) {
            p.journal[i] = old.journal[i];
        }
        p.journal[old.journal.length] = RH.JournalEntry(
            RH.Position(RH.Point(origin, 6, 2), 0), H.Receipt(16, f.query.artistId, 9, r.recordHash)
        );
        p.aliases = new RH.ReplayAlias[](old.aliases.length * 2 + 1);
        for (uint256 i; i < old.aliases.length; ++i) {
            p.aliases[i] = old.aliases[i];
            RH.ReplayAlias memory a = abi.decode(abi.encode(old.aliases[i]), (RH.ReplayAlias));
            a.originHash = origin;
            a.originalKey = _key(p.origins[1], a);
            p.aliases[old.aliases.length + i] = a;
        }
        RH.ReplayAlias memory fresh;
        fresh.originHash = origin;
        fresh.ownerIndex = 6;
        fresh.surface = keccak256("consent_finality.replay.sale_consent_key");
        fresh.scope = keccak256(abi.encode(r.terms, r.bindingGeneration, r.bindingHash));
        fresh.cell = T.ReplayCell(r.recordHash, 2, 1, 2);
        fresh.admittedAt = RH.Point(origin, 6, 2);
        fresh.originalKey = _key(p.origins[1], fresh);
        p.aliases[p.aliases.length - 1] = fresh;
        _sort(p.aliases);
        f.provenance = p;
        _refresh(f);
    }

    function _saleHash(RH.OriginEnvironment memory o, Sale.Record memory r)
        private
        pure
        returns (bytes32)
    {
        return SaleHashes.record(
            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
            r.terms,
            r.artistId,
            r.signer,
            r.authorityClass,
            r.nonce,
            r.signedAt
        );
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
        for (uint256 i; i < f.bundle.policies.length; ++i) {
            DH.Policy memory p = f.bundle.policies[i];
            assert(
                f.target.policy(9, f.query.policies[i]) == p.recordHash
                    && f.target.delegation(p.recordHash) == p.grant
            );
        }
        for (uint256 i; i < f.bundle.economics.length; ++i) {
            Checked.Economics memory e = f.bundle.economics[i];
            (bytes32 r, bytes32 associated, Evidence.Association memory a) =
                f.target.record(e.item.terms, f.query);
            assert(r == e.item.recordHash && associated == r && f.target.delegation(r) == e.grant);
            assert(keccak256(abi.encode(a)) == keccak256(abi.encode(e.item.association)));
        }
        for (uint256 i; i < f.bundle.sales.length; ++i) {
            DH.Sale memory s = f.bundle.sales[i];
            assert(
                keccak256(abi.encode(f.target.sale(s.item.recordHash)))
                    == keccak256(abi.encode(s.item))
            );
            assert(
                f.target.delegation(s.item.recordHash) == s.grant
                    && f.target.latest(s.item.terms) == s.current
            );
        }
    }

    function _empty(Fixture memory f) private view {
        Evidence.Association memory emptyAssociation;
        Sale.Record memory emptySale;
        for (uint256 i; i < f.bundle.policies.length; ++i) {
            assert(
                f.target.policy(9, f.query.policies[i]) == 0
                    && f.target.delegation(f.bundle.policies[i].recordHash) == 0
            );
        }
        for (uint256 i; i < f.bundle.economics.length; ++i) {
            assert(
                keccak256(abi.encode(f.target.association(f.bundle.economics[i].item.recordHash)))
                    == keccak256(abi.encode(emptyAssociation))
            );
            (bytes32 r, bytes32 a, Evidence.Association memory association) =
                f.target.record(f.bundle.economics[i].item.terms, f.query);
            assert(
                r == 0 && a == 0
                    && keccak256(abi.encode(association)) == keccak256(abi.encode(emptyAssociation))
                    && f.target.delegation(f.bundle.economics[i].item.recordHash) == 0
            );
        }
        for (uint256 i; i < f.bundle.sales.length; ++i) {
            DH.Sale memory s = f.bundle.sales[i];
            assert(
                keccak256(abi.encode(f.target.sale(s.item.recordHash)))
                        == keccak256(abi.encode(emptySale)) && f.target.latest(s.item.terms) == 0
                    && f.target.delegation(s.item.recordHash) == 0
            );
        }
    }

    function _sourceDigest(Fixture memory f) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                f.source.owner(6).authorityCheckpoint(),
                f.source.owner(6).artistNativeReceiptCount(),
                f.target.collect(address(f.source.consent()), f.query, f.provenance, f.terms)
            )
        );
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function _refresh(Fixture memory f) private pure {
        f.bundle.provenance = RH.ownerProvenanceHash(f.provenance, 6);
    }

    function _invalid(Fixture memory f) private {
        _reject(
            address(f.target),
            abi.encodeCall(f.target.validate, (f.bundle, f.query, f.provenance)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
    }

    function _collectReject(Fixture memory f, bytes4 error_) private {
        _reject(
            address(f.target),
            abi.encodeCall(
                f.target.collect, (address(f.source.consent()), f.query, f.provenance, f.terms)
            ),
            error_
        );
    }

    function _reject(address target, bytes memory input, bytes4 expected) private {
        (bool ok, bytes memory result) = target.call(input);
        assert(!ok);
        if (expected != bytes4(0)) {
            assert(result.length >= 4);
            bytes4 actual;
            assembly ("memory-safe") { actual := mload(add(result, 32)) }
            assert(actual == expected);
        }
    }
}
