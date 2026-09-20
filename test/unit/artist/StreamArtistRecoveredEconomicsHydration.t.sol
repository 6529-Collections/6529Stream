// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    RecoveredCollectionCoordinatorFixture
} from "./StreamArtistRecoveredCollectionHydration.t.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
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
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
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
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

/// @dev Actual Consent original14/15 writers; the Coordinator fixture supplies admitted Binding,
/// payout and class1/3 facts. It does not prove signatures, recovery or full operation60 admission.
contract RecoveredEconomicsCoordinatorFixture is RecoveredCollectionCoordinatorFixture {
    mapping(bytes32 => AH.Origin) private _economicsWitnesses;

    constructor(address registry) RecoveredCollectionCoordinatorFixture(registry) { }

    function economics(T.EconomicsConsent calldata p, uint8 class_, uint256 nonce, bool delegated)
        external
        returns (bytes32 record)
    {
        T.Binding memory b = binding(true);
        address signer = class_ == 1 ? b.artistAddress : address(1704);
        T.ActionContext memory c =
            T.ActionContext(15, address(this), consent().ownerStateSnapshotV2());
        T.Payout memory payout = T.Payout(address(1801), keccak256("fixture admitted payout"));
        if (delegated) {
            b.consentMode = 2;
            record = consent()
                .recordDelegatedEconomics(
                    c, b, p, payout, signer, nonce, keccak256("fixture delegated economics")
                );
        } else {
            record = consent()
                .recordEconomicsWithAuthority(
                    c,
                    b,
                    p,
                    payout,
                    signer,
                    nonce,
                    R.AuthorityFact(b.artistId, signer, class_, class_ == 1 ? 1 : 3)
                );
        }
        T.SuiteConfiguration memory suite = this.authorityHydrationSuite();
        bytes32 surface = keccak256("consent_finality.replay.consent_key");
        bytes32 scope = keccak256(abi.encode(p));
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                suite.registry,
                address(this),
                suite.archive,
                address(consent()),
                RH.ownerDomain(6),
                surface,
                scope
            )
        );
        _economicsWitnesses[key] = AH.Origin(surface, scope);
    }

    function economicsWitness(bytes32 key) external view returns (AH.Origin memory) {
        return _economicsWitnesses[key];
    }
}

/// @dev Component importer only: fixed typed maps and canonical transport, no owner guard bypass claim.
contract RecoveredEconomicsHarness {
    mapping(bytes32 => bytes32) private _policies;
    mapping(bytes32 => bytes32) private _economics;
    mapping(bytes32 => bytes32) private _associated;
    mapping(bytes32 => Evidence.Association) private _associations;
    mapping(bytes32 => bytes32) private _delegations;
    error LateEconomicsFailure();

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms
    ) external view returns (Economics.Bundle memory) {
        return Economics.collect(source, q, p, terms);
    }

    function validate(Economics.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        external
        pure
    {
        Economics.validate(b, q, p);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Economics.decode(q, p, raw);
    }

    function hydrate(AH.Query memory q, bytes memory raw, bool lateFailure) external {
        Economics.importEither(
            _policies, _economics, _associated, _associations, _delegations, q, raw
        );
        if (lateFailure) revert LateEconomicsFailure();
    }

    function policy(uint256 collection, AH.PolicyKey memory key) external view returns (bytes32) {
        return _policies[keccak256(abi.encode(collection, key.phaseId, key.policyHash))];
    }

    function record(T.EconomicsConsent memory t, AH.Query memory q)
        external
        view
        returns (bytes32, bytes32, Evidence.Association memory)
    {
        bytes32 original = _economics[keccak256(abi.encode(t))];
        return (
            original,
            _associated[Association.key(t, q.artistId, 1, q.bindingHash)],
            _associations[original]
        );
    }
}

contract StreamArtistRecoveredEconomicsHydrationTest {
    struct Fixture {
        RecoveredEconomicsCoordinatorFixture source;
        RecoveredEconomicsHarness target;
        AH.Query query;
        RH.OwnerProvenance provenance;
        T.EconomicsConsent[] terms;
        Economics.Bundle bundle;
    }

    function testRecoveredEconomicsActualMixed14And15ClassesRetainAllOriginalMaps() external {
        Fixture memory f = _fixture();
        assert(f.provenance.journal[0].receipt.operation == 15);
        assert(f.provenance.journal[1].receipt.operation == 14);
        assert(f.provenance.journal[2].receipt.operation == 15);
        assert(f.provenance.journal[3].receipt.operation == 14);
        assert(f.bundle.original.records[0].recordHash != f.bundle.original.records[1].recordHash);
        bytes memory raw = Economics.encode(f.bundle, f.query, f.provenance);
        assert(Economics.isState(raw));
        f.target.hydrate(f.query, _outer(f, raw, RH.DIRECT_ECONOMICS), false);
        _same(f);
        for (uint256 i; i < f.terms.length; ++i) {
            assert(
                keccak256(abi.encode(f.bundle.original.records[i].association))
                    == keccak256(
                        abi.encode(
                            f.source.consent()
                                .economicsRecordAssociation(f.bundle.original.records[i].recordHash)
                        )
                    )
            );
        }
    }

    function testRecoveredEconomicsPolicyOrderRemainsFreeButEconomicsFollowOriginalOrder()
        external
    {
        Fixture memory f = _fixture();
        AH.PolicyKey memory saved = f.query.policies[0];
        f.query.policies[0] = f.query.policies[1];
        f.query.policies[1] = saved;
        f.bundle = f.target.collect(address(f.source.consent()), f.query, f.provenance, f.terms);
        assert(f.bundle.original.policies[0] == f.provenance.journal[3].receipt.recordHash);
        T.EconomicsConsent memory first = f.terms[0];
        f.terms[0] = f.terms[1];
        f.terms[1] = first;
        _collectFails(f);
    }

    function testRecoveredEconomicsRejectsOmittedDuplicateEmptyAndUnusedWitnesses() external {
        Fixture memory original = _fixture();
        for (uint256 i; i < 6; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.terms = new T.EconomicsConsent[](0);
            if (i == 1) {
                f.terms = new T.EconomicsConsent[](1);
                f.terms[0] = original.terms[0];
            }
            if (i == 2) f.terms[1] = f.terms[0];
            if (i == 3) f.terms[1].assignmentHash = keccak256("unadmitted payload");
            if (i == 4) f.query.policies = new AH.PolicyKey[](0);
            if (i == 5) f.query.policies[1] = f.query.policies[0];
            _collectFails(f);
        }
    }

    function testRecoveredEconomicsRejectsActualDelegatedEconomicsAndPolicy() external {
        for (uint256 i; i < 2; ++i) {
            Fixture memory f;
            f.source = new RecoveredEconomicsCoordinatorFixture(address(uint160(820 + i)));
            f.target = new RecoveredEconomicsHarness();
            f.query = _query(f.source);
            f.query.policies = new AH.PolicyKey[](i);
            f.terms = new T.EconomicsConsent[](1);
            f.terms[0] = _terms(0);
            bytes32 record = f.source.economics(f.terms[0], 1, 1, i == 0);
            if (i == 1) {
                f.query.policies[0] = AH.PolicyKey(bytes32(uint256(1)), bytes32(uint256(101)));
                record = f.source
                    .delegatedPolicy(
                        T.PolicyConsent(
                            9, f.query.policies[0].phaseId, f.query.policies[0].policyHash
                        )
                    );
            }
            assert(f.source.consent().recordDelegation(record) != 0);
            f.provenance = _local(f.source);
            _collectFails(f);
        }
    }

    function testRecoveredEconomicsRejectsUnselectedRatificationAndForeignCollection() external {
        Fixture memory f = _fixture();
        f.source.ratify();
        f.provenance = _local(f.source);
        _collectFails(f);
        f = _fixture();
        T.EconomicsConsent memory foreign = _terms(2);
        foreign.collectionId = 10;
        f.source.economics(foreign, 1, 30, false);
        f.provenance = _local(f.source);
        _collectFails(f);
    }

    function testRecoveredEconomicsExactAssociationAndPayloadRejectSubstitutionAndRestore()
        external
    {
        Fixture memory original = _fixture();
        for (uint256 i; i < 7; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) f.bundle.original.records[0].association.bindingGeneration = 2;
            if (i == 1) f.bundle.original.records[0].association.bindingHash = bytes32(uint256(2));
            if (i == 2) {
                f.bundle.original.records[0].association.originalRecord = bytes32(uint256(2));
            }
            if (i == 3) f.bundle.original.records[0].association.payloadHash = bytes32(uint256(2));
            if (i == 4) f.bundle.original.records[0].terms.collectionId = 10;
            if (i == 5) f.bundle.original.records[1] = f.bundle.original.records[0];
            if (i == 6) f.bundle.original.records[0].terms.scope = 3;
            _validateFails(f);
        }
        original.target.validate(original.bundle, original.query, original.provenance);
    }

    function testRecoveredEconomicsOriginalReplayScopeCellAndAdmissionPointAreExact() external {
        Fixture memory original = _fixture();
        for (uint256 i; i < 7; ++i) {
            Fixture memory f = _copy(original);
            RH.ReplayAlias memory a = f.provenance.aliases[0];
            if (i == 0) a.scope = bytes32(uint256(987));
            if (i == 1) a.surface = keccak256("consent_finality.replay.ratification_key");
            if (i == 2) a.cell.commitment = bytes32(uint256(987));
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
            f.bundle.provenance = RH.ownerProvenanceHash(f.provenance, 6);
            _validateFails(f);
        }
    }

    function testRecoveredEconomicsCompletenessRejectsHiddenRevisionNonceAndDuplicateOccurrence()
        external
    {
        Fixture memory original = _fixture();
        for (uint256 i; i < 5; ++i) {
            Fixture memory f = _copy(original);
            if (i == 0) ++f.provenance.eras[0].checkpoint.ownerState.revision;
            if (i == 1) f.provenance.eras[0].checkpoint.nonceIndexCount = 1;
            if (i == 2) f.provenance.eras[0].checkpoint.nonceRoot = bytes32(uint256(1));
            if (i == 3) f.provenance.journal[1].receipt = f.provenance.journal[0].receipt;
            if (i == 4) f.provenance.journal[1].position.point.ownerRevision = 1;
            f.bundle.provenance = RH.ownerProvenanceHash(f.provenance, 6);
            _validateFails(f);
        }
    }

    function testRecoveredEconomicsRejectsWrongTagTrailingBytesAndMissingFeatureBeforeMapWrites()
        external
    {
        Fixture memory f = _fixture();
        bytes memory correct = Economics.encode(f.bundle, f.query, f.provenance);
        for (uint256 i; i < 3; ++i) {
            bytes memory raw = abi.decode(abi.encode(correct), (bytes));
            if (i == 0) assembly ("memory-safe") { mstore(add(raw, 32), 1) }
            if (i == 1) raw = bytes.concat(raw, bytes32(uint256(1)));
            _fails(
                address(f.target),
                abi.encodeCall(
                    f.target.hydrate,
                    (f.query, _outer(f, raw, i == 2 ? 0 : RH.DIRECT_ECONOMICS), false)
                )
            );
            (bytes32 saved,,) = f.target.record(f.terms[0], f.query);
            assert(saved == 0);
        }
        f.target.hydrate(f.query, _outer(f, correct, RH.DIRECT_ECONOMICS), false);
        _same(f);
    }

    function testRecoveredEconomicsLateFailureRollsBackAllMapsThenIdenticalRetrySucceeds()
        external
    {
        Fixture memory f = _fixture();
        bytes memory raw =
            _outer(f, Economics.encode(f.bundle, f.query, f.provenance), RH.DIRECT_ECONOMICS);
        _fails(address(f.target), abi.encodeCall(f.target.hydrate, (f.query, raw, true)));
        assert(f.target.policy(f.query.collectionId, f.query.policies[0]) == 0);
        (bytes32 saved, bytes32 associated, Evidence.Association memory a) =
            f.target.record(f.terms[0], f.query);
        assert(saved == 0 && associated == 0 && a.originalRecord == 0);
        f.target.hydrate(f.query, raw, false);
        _same(f);
        _fails(address(f.target), abi.encodeCall(f.target.hydrate, (f.query, raw, false)));
        _same(f);
    }

    function testRecoveredEconomicsStaleSourceCheckpointRejectsFreshActualSuffix() external {
        Fixture memory f = _fixture();
        f.source.economics(_terms(2), 3, 50, false);
        _collectFails(f);
    }

    function testRecoveredEconomicsFlattenedOriginalEraAndCurrentSuffixNeedEveryRekeyedAlias()
        external
    {
        Fixture memory f = _fixture();
        _secondEra(f);
        // This is a pure flattened-certificate component test, not a synthetic source export.
        f.target.validate(f.bundle, f.query, f.provenance);
        Fixture memory invalid = _copy(f);
        for (uint256 i; i < invalid.provenance.aliases.length; ++i) {
            if (
                invalid.provenance.aliases[i].admittedAt.environmentHash
                    != invalid.provenance.eras[0].originHash
            ) continue;
            invalid.provenance.aliases[i].admittedAt.environmentHash =
            invalid.provenance.eras[1].originHash;
            break;
        }
        invalid.bundle.provenance = RH.ownerProvenanceHash(invalid.provenance, 6);
        _validateFails(invalid);
        invalid = _copy(f);
        invalid.provenance.eras[1].lowerRevision = 2;
        invalid.bundle.provenance = RH.ownerProvenanceHash(invalid.provenance, 6);
        _validateFails(invalid);
        f.target.validate(f.bundle, f.query, f.provenance);
    }

    function testRecoveredEconomicsDispatchPreservesPoliciesOnlyBytesAndRejectsFalseFeature()
        external
    {
        Fixture memory f;
        f.source = new RecoveredEconomicsCoordinatorFixture(address(811));
        f.target = new RecoveredEconomicsHarness();
        f.query = _query(f.source);
        for (uint256 i; i < f.query.policies.length; ++i) {
            f.source
                .policy(
                    T.PolicyConsent(9, f.query.policies[i].phaseId, f.query.policies[i].policyHash),
                    1,
                    i + 1
                );
        }
        f.provenance = _local(f.source);
        bytes memory unchanged =
            f.source.consent().recoveredAuthorityHydrationState(f.query, f.provenance);
        assert(!Economics.isState(unchanged));
        _fails(
            address(f.target),
            abi.encodeCall(
                f.target.hydrate, (f.query, _outer(f, unchanged, RH.DIRECT_ECONOMICS), false)
            )
        );
        f.target.hydrate(f.query, _outer(f, unchanged, 0), false);
        for (uint256 i; i < f.query.policies.length; ++i) {
            assert(
                f.target.policy(9, f.query.policies[i])
                    == f.source.consent()
                        .policyRecord(
                            9, f.query.policies[i].phaseId, f.query.policies[i].policyHash
                        )
            );
        }
        assert(
            keccak256(unchanged)
                == keccak256(
                    f.source.consent().recoveredAuthorityHydrationState(f.query, f.provenance)
                )
        );
    }

    function _fixture() private returns (Fixture memory f) {
        f.source = new RecoveredEconomicsCoordinatorFixture(address(810));
        f.target = new RecoveredEconomicsHarness();
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
        f.source.economics(f.terms[1], 3, 12, false);
        f.source
            .policy(
                T.PolicyConsent(9, f.query.policies[1].phaseId, f.query.policies[1].policyHash),
                3,
                13
            );
        f.provenance = _local(f.source);
        f.bundle = f.target.collect(address(f.source.consent()), f.query, f.provenance, f.terms);
    }

    function _query(RecoveredEconomicsCoordinatorFixture source)
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

    function _local(RecoveredEconomicsCoordinatorFixture source)
        private
        view
        returns (RH.OwnerProvenance memory p)
    {
        T.SuiteConfiguration memory suite = source.authorityHydrationSuite();
        p.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory o;
        o.chainId = block.chainid;
        o.registry = suite.registry;
        o.coordinator = address(source);
        o.archive = suite.archive;
        o.owners = suite.owners;
        o.core = suite.core;
        o.manager = suite.mintManager;
        for (uint8 i; i < 7; ++i) {
            o.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        o.suiteConfigurationHash = keccak256(abi.encode(suite));
        p.origins[0] = o;
        StreamArtistOwner owner = source.owner(6);
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(o);
        p.eras[0].checkpoint = owner.authorityCheckpoint();
        p.eras[0].nativeCount = owner.artistNativeReceiptCount();
        p.journal = new RH.JournalEntry[](p.eras[0].nativeCount);
        for (uint256 i; i < p.journal.length; ++i) {
            p.journal[i].receipt = owner.artistNativeReceiptAt(i);
            p.journal[i].position = RH.Position(
                RH.Point(p.eras[0].originHash, 6, owner.artistNativeReceiptRevisionAt(i)), i
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

    function _secondEra(Fixture memory f) private pure {
        RH.OwnerProvenance memory old = f.provenance;
        RH.OwnerProvenance memory p;
        p.origins = new RH.OriginEnvironment[](2);
        p.origins[0] = old.origins[0];
        p.origins[1] = abi.decode(abi.encode(old.origins[0]), (RH.OriginEnvironment));
        p.origins[1].registry = address(9501);
        p.origins[1].coordinator = address(9502);
        p.origins[1].owners[6] = address(9503);
        p.origins[1].suiteConfigurationHash = keccak256("synthetic current economics era");
        bytes32 origin = RH.originHash(p.origins[1]);
        p.eras = new RH.OwnerEra[](2);
        p.eras[0] = old.eras[0];
        p.eras[1] = abi.decode(abi.encode(old.eras[0]), (RH.OwnerEra));
        p.eras[1].originHash = origin;
        p.eras[1].nativeCount = 1;
        p.eras[1].lowerRevision = 1;
        p.eras[1].priorImportCommitment = keccak256("synthetic prior economics import");
        p.eras[1].checkpoint.ownerState.revision = 2;
        p.eras[1].checkpoint.replayCount = old.journal.length + 1;
        p.journal = new RH.JournalEntry[](old.journal.length + 1);
        for (uint256 i; i < old.journal.length; ++i) {
            p.journal[i] = old.journal[i];
        }
        bytes32 record = keccak256("synthetic current original15 record");
        p.journal[old.journal.length] = RH.JournalEntry(
            RH.Position(RH.Point(origin, 6, 2), 0), H.Receipt(15, f.query.artistId, 9, record)
        );
        EH.Row[] memory rows = new EH.Row[](3);
        rows[0] = f.bundle.original.records[0];
        rows[1] = f.bundle.original.records[1];
        T.EconomicsConsent memory term = _terms(2);
        bytes32 payloadHash = keccak256(abi.encode(term));
        rows[2] = EH.Row(
            record,
            term,
            Evidence.Association(f.query.artistId, 1, f.query.bindingHash, payloadHash, record)
        );
        f.bundle.original.records = rows;
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
        fresh.surface = keccak256("consent_finality.replay.consent_key");
        fresh.scope = payloadHash;
        fresh.cell = T.ReplayCell(record, 2, 1, 2);
        fresh.admittedAt = RH.Point(origin, 6, 2);
        fresh.originalKey = _key(p.origins[1], fresh);
        p.aliases[p.aliases.length - 1] = fresh;
        _sort(p.aliases);
        f.provenance = p;
        f.bundle.provenance = RH.ownerProvenanceHash(p, 6);
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
        for (uint256 i; i < f.query.policies.length; ++i) {
            assert(
                f.target.policy(f.query.collectionId, f.query.policies[i])
                    == f.bundle.original.policies[i]
            );
        }
        for (uint256 i; i < f.terms.length; ++i) {
            (bytes32 record, bytes32 associated, Evidence.Association memory a) =
                f.target.record(f.terms[i], f.query);
            assert(record == f.bundle.original.records[i].recordHash && associated == record);
            assert(
                keccak256(abi.encode(a))
                    == keccak256(abi.encode(f.bundle.original.records[i].association))
            );
        }
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function _collectFails(Fixture memory f) private {
        _fails(
            address(f.target),
            abi.encodeCall(
                f.target.collect, (address(f.source.consent()), f.query, f.provenance, f.terms)
            )
        );
    }

    function _validateFails(Fixture memory f) private {
        _fails(
            address(f.target), abi.encodeCall(f.target.validate, (f.bundle, f.query, f.provenance))
        );
    }

    function _fails(address target, bytes memory input) private {
        (bool ok,) = target.call(input);
        assert(!ok);
    }
}
