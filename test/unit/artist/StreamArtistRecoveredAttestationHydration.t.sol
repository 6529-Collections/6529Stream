// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    RecoveredCollectionCoordinatorFixture
} from "./StreamArtistRecoveredCollectionHydration.t.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistRecoveredAttestationHydration as Checked
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistAttributionRecoveredImport as Dispatch
} from "../../../smart-contracts/domains/artist/StreamArtistAttributionRecoveredImport.sol";
import {
    StreamArtistRecoveredCollectionHydration as Base
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredCollectionHydration.sol";
import {
    StreamArtistAttributionStateTypes as AS
} from "../../../smart-contracts/domains/artist/StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistHydrationGuards.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistC2PACredentials as Credentials
} from "../../../smart-contracts/domains/artist/StreamArtistC2PACredentials.sol";
import {
    StreamArtistPersonhoodSummary as Summary
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodSummary.sol";
import {
    StreamArtistPersonhoodJSON as PersonhoodJSON
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodJSON.sol";
import {
    StreamArtistPersonhoodDefinitions as Definitions
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecordPublicationTypes as Publication
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    IStreamArtistRecordPublicationOwner as PublicationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistC2PATypes as C2PA
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistPersonhoodTypes as Personhood
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

interface RecoveredAttestationVm {
    function warp(uint256) external;
    function etch(address, bytes calldata) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract RecoveredAttestationRegistryFixture {
    address public operationCoordinator;

    function bind(address coordinator) external {
        require(operationCoordinator == address(0));
        operationCoordinator = coordinator;
    }

    function gasParameterInfo(bytes32) external pure returns (uint256, uint256, uint8, uint64) {
        return (20_000_000, 1, 2, 1);
    }
}

/// @dev Original Attribution op24 writers and native commits. The fixed Coordinator supplies
/// admitted authority, grant and subject facts; this component does not prove Identity signatures.
contract RecoveredAttestationCoordinatorFixture is RecoveredCollectionCoordinatorFixture {
    constructor(address registry) RecoveredCollectionCoordinatorFixture(registry) { }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return this.authorityHydrationSuite();
    }

    function attest(
        T.Attestation calldata p,
        bytes calldata statement,
        uint8 class_,
        uint256 nonce,
        bool legacy
    ) external returns (bytes32) {
        T.Binding memory b = binding(true);
        T.ActionContext memory c =
            T.ActionContext(24, address(this), attribution().ownerStateSnapshotV2());
        if (legacy) {
            return attribution()
                .recordAttestation(
                    c, b, p, b.artistAddress, nonce, uint64(block.timestamp), statement
                );
        }
        T.SuiteConfiguration memory suite = this.authorityHydrationSuite();
        address authority = class_ == 3 ? address(1704) : b.artistAddress;
        address signer = class_ == 2 ? address(1705) : authority;
        address factOwner = p.subjectKind == 10 ? suite.owners[2] : address(this);
        Attest.Admission memory a;
        a.authority =
            R.AuthorityFact(b.artistId, authority, class_ == 2 ? 1 : class_, class_ == 3 ? 3 : 1);
        a.signer = signer;
        a.nonce = nonce;
        a.signedAt = uint64(block.timestamp);
        a.delegation = class_ == 2 ? keccak256("component admitted original grant") : bytes32(0);
        a.operativeIdentity = p.subjectKind == 10 ? p.subjectStateHash : bytes32(0);
        a.fact = Attest.Fact(factOwner, factOwner.codehash, p.subjectId, p.subjectStateHash);
        return attribution().recordAuthenticatedAttestation(c, b, p, a, statement);
    }
}

/// @dev Isolated typed owner4 importer. Original Summary.note(false), fixed Coordinator context,
/// suite bindings and original hydration guard execute; seven-owner admission/Archive do not.
contract RecoveredAttestationImportHarness {
    AS.State private _s;
    mapping(bytes32 => T.ReplayCell) private _guardCells;
    address public immutable artistRegistry;
    address public immutable operationCoordinator;
    address public immutable core;
    address public immutable mintManager;
    address public constant archiveV2 = address(703);
    bytes32 public immutable domainId = RH.ownerDomain(4);

    constructor(address registry, address coordinator, address core_, address manager) {
        artistRegistry = registry;
        operationCoordinator = coordinator;
        core = core_;
        mintManager = manager;
    }

    function ownerStateSnapshotV2() external view returns (T.Snapshot memory) {
        return T.Snapshot(
            domainId, 0, keccak256("component empty owner"), keccak256("component empty records")
        );
    }

    function applyArtistAuthorityHydration(
        T.ActionContext calldata,
        AH.Query calldata,
        AH.OwnerData calldata,
        bytes32 commitment
    ) external {
        require(msg.sender == operationCoordinator);
        if (RecoveredAttestationTargetCoordinator(msg.sender).withGuard()) {
            AH.OwnerData memory empty;
            Guards.applyGuards(
                _guardCells,
                empty,
                artistRegistry,
                operationCoordinator,
                archiveV2,
                domainId,
                commitment
            );
        }
        Dispatch.importEncoded(_s, msg.data);
    }

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        ReadinessH.AttestationInput[] memory inputs
    ) external view returns (Checked.Bundle memory) {
        return Checked.collect(source, q, p, inputs);
    }

    function validate(Checked.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        external
        pure
    {
        Checked.validate(b, q, p);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Checked.decode(q, p, raw);
    }

    function attribution(uint256 collection) external view returns (AS.Attribution memory) {
        return _s.attributions[collection];
    }

    function row(bytes32 hash)
        external
        view
        returns (
            T.AttestationRecord memory,
            uint8,
            Attest.Association memory,
            PublicationOwner.Record memory
        )
    {
        return (
            _s.records[hash],
            _s.attestationClasses[hash],
            _s.attestationAssociations[hash],
            _s.publications[hash]
        );
    }

    function latest(T.Attestation memory p) external view returns (T.AttestationRecord memory) {
        return _s.attestations[keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId))];
    }

    function statement(bytes32 hash) external view returns (bytes memory) {
        return _s.statements[hash];
    }

    function summary(bytes32 hash)
        external
        view
        returns (address, bytes32, Personhood.Summary memory)
    {
        return (Summary.origin(hash), Summary.hashOf(hash), Summary.get(hash));
    }

    function credential(bytes32 hash) external view returns (C2PA.Head memory) {
        return Credentials.state().records[hash];
    }

    function head(bytes32 artist) external view returns (C2PA.Head memory) {
        return Credentials.head(artist);
    }

    function personhood(uint256 collection, bytes32 artist) external view returns (bytes32) {
        return Credentials.personhoodKey(collection, artist);
    }

    function importGuard() external view returns (bytes32) {
        return Guards.commitment();
    }

    function seedOrphanHead(bytes32 artist) external {
        Credentials.state().latest[artist] = keccak256("component malformed occupied head");
    }
}

contract RecoveredAttestationTargetCoordinator {
    T.SuiteConfiguration private _suite;
    RecoveredAttestationImportHarness public target;
    bool public withGuard;
    error LateAttestationFailure();

    constructor(address registry, T.SuiteConfiguration memory original) {
        _suite = original;
        _suite.registry = registry;
        target = new RecoveredAttestationImportHarness(
            registry, address(this), original.core, original.mintManager
        );
        _suite.owners[4] = address(target);
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return _suite;
    }

    function hydrate(AH.Query memory q, bytes memory raw, bool guard_, bool lateFailure) external {
        withGuard = guard_;
        AH.OwnerData memory data;
        data.typedState = raw;
        target.applyArtistAuthorityHydration(
            T.ActionContext(60, address(this), target.ownerStateSnapshotV2()),
            q,
            data,
            keccak256("component authenticated import")
        );
        if (lateFailure) revert LateAttestationFailure();
    }
}

contract StreamArtistRecoveredAttestationHydrationTest {
    RecoveredAttestationVm private constant vm =
        RecoveredAttestationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant IDENTITY =
        keccak256("retained operative identity distinct from registration");

    struct Fixture {
        RecoveredAttestationCoordinatorFixture source;
        RecoveredAttestationTargetCoordinator destination;
        RecoveredAttestationImportHarness target;
        AH.Query query;
        RH.OwnerProvenance provenance;
        ReadinessH.AttestationInput[] inputs;
        Checked.Bundle bundle;
    }

    function testRecoveredAttestationsActualMixedClassesAndAllMapsRoundTrip() external {
        Fixture memory f = _fixture(true);
        assert(f.bundle.records[0].attestation.association.artistId == 0);
        assert(f.bundle.records[1].attestation.authorityClass == 2);
        assert(f.bundle.records[3].attestation.authorityClass == 3);
        bytes32 before_ = _sourceHash(f);
        f.destination.hydrate(f.query, _encoded(f), true, false);
        _same(f);
        assert(_sourceHash(f) == before_);
    }

    function testRecoveredAttestationsWaiverOpaqueAndCredentialWithdrawalRemainDistinct() external {
        Fixture memory f = _fixture(true);
        assert(f.bundle.personhood.length == 2);
        assert(f.bundle.personhood[0].summaryHash == 0 && f.bundle.personhood[1].summaryHash == 0);
        f.destination.hydrate(f.query, _encoded(f), true, false);
        assert(
            f.target.personhood(9, f.query.artistId)
                == f.bundle.records[5].attestation.record.recordHash
        );
        C2PA.Head memory h = f.target.head(f.query.artistId);
        assert(h.revision == 2 && h.recordHash == f.bundle.records[6].attestation.record.recordHash);
        assert(h.previousRecordHash == f.bundle.records[3].attestation.record.recordHash);
        C2PA.Payload memory withdrawal =
            abi.decode(f.target.statement(h.statementHash), (C2PA.Payload));
        assert(withdrawal.credentials.length == 0);
        _same(f);
    }

    function testRecoveredAttestationsPersonhoodOnlyStillChecksBothFinalHeads() external {
        Fixture memory f = _fixture(false);
        f.destination.hydrate(f.query, _encoded(f), true, false);
        assert(f.target.head(f.query.artistId).recordHash == 0);
        assert(f.target.personhood(9, f.query.artistId) != 0);
        T.AttestationRecord memory empty;
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature("personhoodAttestation(uint256,bytes32)", 9, f.query.artistId),
            abi.encode(empty)
        );
        _collectFails(f, f.inputs, RH.InvalidRecoveredHydrationProfile.selector);
        vm.clearMockedCalls();
        C2PA.Head memory wrong;
        wrong.recordHash = keccak256("unexpected credential head");
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature("c2paCredentialHead(bytes32)", f.query.artistId),
            abi.encode(wrong)
        );
        _collectFails(f, f.inputs, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsCompleteWitnessOrderOmissionAndExtraRefuse() external {
        Fixture memory f = _fixture(true);
        ReadinessH.AttestationInput[] memory short_ = new ReadinessH.AttestationInput[](7);
        for (uint256 i; i < 7; ++i) {
            short_[i] = f.inputs[i];
        }
        _collectFails(f, short_, T.UnsupportedProfile.selector);
        ReadinessH.AttestationInput[] memory long_ = new ReadinessH.AttestationInput[](9);
        for (uint256 i; i < 8; ++i) {
            long_[i] = f.inputs[i];
        }
        long_[8] = f.inputs[0];
        _collectFails(f, long_, T.UnsupportedProfile.selector);
        (f.inputs[0], f.inputs[1]) = (f.inputs[1], f.inputs[0]);
        _collectFails(f, f.inputs, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsOriginalClassGrantAndSubjectOwnerJoinsRefuse() external {
        Fixture memory f = _fixture(true);
        Fixture memory bad = _copy(f);
        bad.bundle.records[1].attestation.association.delegation = 0;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.records[3].attestation.authorityClass = 1;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.records[2].attestation.association.fact.owner = address(f.source);
        bad.bundle.records[2].attestation.association.fact.ownerCodeHash =
        address(f.source).codehash;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.records[7].attestation.record.signer = address(0xdead);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsPublicationFullEvidenceAndEmptyNonpublicationRefuse()
        external
    {
        Fixture memory f = _fixture(true);
        Fixture memory bad = _copy(f);
        bad.bundle.records[4].publication.evidence.requiredCapability = 1;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.records[4].publication.metadataHostCodeHash = bytes32(uint256(77));
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.records[0].publication = f.bundle.records[4].publication;
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsSparsePersonhoodExactOrderAndZeroSummaryRequired() external {
        Fixture memory f = _fixture(true);
        Fixture memory bad = _copy(f);
        (bad.bundle.personhood[0], bad.bundle.personhood[1]) =
        (bad.bundle.personhood[1], bad.bundle.personhood[0]);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.personhood = new Checked.PersonhoodRow[](0);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.personhood[0].summary.documentaryHash =
            keccak256("waiver cannot be resolved evidence");
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.personhood[1].originalRegistry = address(f.destination);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsEverySourceHeadAndLatestMapMustMatch() external {
        Fixture memory f = _fixture(true);
        C2PA.Head memory empty;
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature(
                "c2paCredentialRecord(bytes32)", f.bundle.records[3].attestation.record.recordHash
            ),
            abi.encode(empty)
        );
        _collectFails(f, f.inputs, RH.InvalidRecoveredHydrationProfile.selector);
        vm.clearMockedCalls();
        T.AttestationRecord memory wrong;
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature(
                "attestation(uint256,uint8,bytes32)", 9, 1, f.inputs[1].terms.subjectId
            ),
            abi.encode(wrong)
        );
        _collectFails(f, f.inputs, RH.InvalidRecoveredHydrationProfile.selector);
        vm.clearMockedCalls();
        Personhood.Summary memory unexpected;
        unexpected.version = 1;
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature(
                "personhoodProofSummary(bytes32)", f.bundle.records[0].attestation.record.recordHash
            ),
            abi.encode(unexpected)
        );
        _collectFails(f, f.inputs, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsUnsupportedNativeAndHiddenMutationRefuse() external {
        Fixture memory f = _fixture(true);
        Fixture memory bad = _copy(f);
        bad.provenance.journal[0].receipt.operation = 23;
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

    function testRecoveredAttestationsUnorderedPointAndDuplicateNativeRefuse() external {
        Fixture memory f = _fixture(true);
        Fixture memory bad = _copy(f);
        bad.provenance.journal[1].position.point.ownerRevision = 2;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProvenance.selector);
        bad = _copy(f);
        bad.bundle.records[1] = bad.bundle.records[0];
        bad.provenance.journal[1].receipt.recordHash = bad.provenance.journal[0].receipt.recordHash;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsEvenWellFormedOwner4ReplayAliasIsUnsupported() external {
        Fixture memory f = _fixture(true);
        RH.OriginEnvironment memory o = f.provenance.origins[0];
        RH.ReplayAlias memory a;
        a.ownerIndex = 4;
        a.originHash = f.provenance.eras[0].originHash;
        a.surface = keccak256("synthetic unknown owner4 replay surface");
        a.scope = keccak256("synthetic scope");
        a.cell = T.ReplayCell(keccak256("synthetic consumed cell"), 3, 1, 2);
        a.admittedAt = RH.Point(a.originHash, 4, 3);
        a.originalKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[4],
                RH.ownerDomain(4),
                a.surface,
                a.scope
            )
        );
        f.provenance.aliases = new RH.ReplayAlias[](1);
        f.provenance.aliases[0] = a;
        f.provenance.eras[0].checkpoint.replayCount = 1;
        f.provenance.eras[0].checkpoint.replayRoot = keccak256("synthetic replay root");
        _refresh(f);
        _invalid(f, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsCredentialBranchAndClass4CannotBeRelabeled() external {
        Fixture memory f = _fixture(true);
        Fixture memory bad = _copy(f);
        ReadinessH.AttestationRow memory r = bad.bundle.records[6].attestation;
        r.statement = _credentials(f.query.artistId, 0, true);
        r.input.terms.statementHash = keccak256(r.statement);
        r.record.statementHash = r.input.terms.statementHash;
        r.record.recordHash = _recordHash(bad.provenance.origins[0], bad.query.artistId, r);
        bad.bundle.records[6].attestation = r;
        bad.provenance.journal[6].receipt.recordHash = r.record.recordHash;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bad = _copy(f);
        bad.bundle.records[3].attestation.authorityClass = 4;
        bad.bundle.records[3].attestation.record.recordHash = _recordHash(
            bad.provenance.origins[0], bad.query.artistId, bad.bundle.records[3].attestation
        );
        bad.provenance.journal[3].receipt.recordHash =
        bad.bundle.records[3].attestation.record.recordHash;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testRecoveredAttestationsCanonicalEnvelopeRejectsTrailingSemanticBytes() external {
        Fixture memory f = _fixture(true);
        bytes memory valid = Checked.encode(f.bundle, f.query, f.provenance);
        _fail(
            address(f.target),
            abi.encodeCall(f.target.decode, (f.query, f.provenance, bytes.concat(valid, hex"00"))),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        assert(Checked.selected(_encoded(f)));
        bytes memory wrongFeature = _outer(
            f,
            abi.encode(
                Base.ATTRIBUTION,
                Base.AttributionBundle(
                    RH.ownerProvenanceHash(f.provenance, 4),
                    f.query.artistId,
                    9,
                    f.query.bindingHash,
                    AS.Attribution(2, 1)
                )
            ),
            0
        );
        assert(!Checked.selected(wrongFeature));
        _fail(
            address(f.destination),
            abi.encodeCall(f.destination.hydrate, (f.query, wrongFeature, true, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        assert(f.target.importGuard() == 0);
    }

    function testRecoveredAttestationsMissingGuardAndOccupiedHeadRejectAtomically() external {
        Fixture memory f = _fixture(true);
        bytes memory raw = _encoded(f);
        _fail(
            address(f.destination),
            abi.encodeCall(f.destination.hydrate, (f.query, raw, false, false)),
            Personhood.InvalidPersonhoodReference.selector
        );
        _empty(f);
        f.target.seedOrphanHead(f.query.artistId);
        _fail(
            address(f.destination),
            abi.encodeCall(f.destination.hydrate, (f.query, raw, true, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        assert(f.target.importGuard() == 0 && f.target.attribution(9).state == 0);
    }

    function testRecoveredAttestationsLateFailureRollsBackAllMapsOriginsAndExactRetry() external {
        Fixture memory f = _fixture(true);
        bytes memory raw = _encoded(f);
        bytes32 before_ = _sourceHash(f);
        _fail(
            address(f.destination),
            abi.encodeCall(f.destination.hydrate, (f.query, raw, true, true)),
            RecoveredAttestationTargetCoordinator.LateAttestationFailure.selector
        );
        _empty(f);
        assert(_sourceHash(f) == before_);
        f.destination.hydrate(f.query, raw, true, false);
        _same(f);
        assert(_sourceHash(f) == before_);
        _fail(
            address(f.destination),
            abi.encodeCall(f.destination.hydrate, (f.query, raw, true, false)),
            T.InvalidRecord.selector
        );
        _same(f);
    }

    function testRecoveredAttestationsSyntheticSecondEraKeepsUltimateRowOrigins() external {
        Fixture memory f = _fixture(true);
        _secondEra(f);
        // Pure/copy boundary only: the retained A records are actual; B's suffix/certificate
        // are explicitly synthetic, not a claimed seven-owner repeated import.
        f.target.validate(f.bundle, f.query, f.provenance);
        assert(
            f.provenance.journal[7].position.point.ownerRevision
                > f.provenance.journal[8].position.point.ownerRevision
        );
        f.destination.hydrate(f.query, _encoded(f), true, false);
        assert(
            f.target.credential(f.bundle.records[3].attestation.record.recordHash).sourceRegistry
                == f.provenance.origins[0].registry
        );
        assert(f.target.head(f.query.artistId).sourceRegistry == f.provenance.origins[1].registry);
        Fixture memory bad = _copy(f);
        bad.provenance.journal[0].position.point.environmentHash = bad.provenance.eras[1].originHash;
        _refresh(bad);
        _invalid(bad, RH.InvalidRecoveredHydrationProvenance.selector);
    }

    function testRecoveredAttestationsSyntheticCanonicalSummaryCopiesOriginalWithoutCurrentProof()
        external
    {
        Fixture memory f = _fixture(true);
        _canonicalSummary(f);
        // This controlled immutable source response tests Summary.note(false), not notarization
        // admission. No live notarization/Proof.verify dependency is installed or mocked.
        f.destination.hydrate(f.query, _encoded(f), true, false);
        Checked.PersonhoodRow memory r = f.bundle.personhood[1];
        (address origin, bytes32 hash, Personhood.Summary memory summary_) =
            f.target.summary(r.recordHash);
        assert(origin == r.originalRegistry && hash == r.summaryHash);
        assert(keccak256(abi.encode(summary_)) == keccak256(abi.encode(r.summary)));
    }

    function testRecoveredAttestationsSyntheticCanonicalSummaryWrongHashAndSourceRefuse() external {
        Fixture memory f = _fixture(true);
        _canonicalSummary(f);
        Fixture memory bad = _copy(f);
        bad.bundle.personhood[1].summary.evidenceReference.operativeIdentityRecordHash =
            bytes32(uint256(77));
        bad.bundle.personhood[1].summaryHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"),
                bad.bundle.personhood[1].summary
            )
        );
        _invalid(bad, RH.InvalidRecoveredHydrationProfile.selector);
        bytes memory raw = _encoded(f);
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature(
                "personhoodProofSummaryHash(bytes32)", f.bundle.personhood[1].recordHash
            ),
            abi.encode(bytes32(0))
        );
        _fail(
            address(f.destination),
            abi.encodeCall(f.destination.hydrate, (f.query, raw, true, false)),
            Personhood.InvalidPersonhoodReference.selector
        );
        _empty(f);
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature(
                "personhoodProofSummaryHash(bytes32)", f.bundle.personhood[1].recordHash
            ),
            abi.encode(f.bundle.personhood[1].summaryHash)
        );
        f.destination.hydrate(f.query, raw, true, false);
        (, bytes32 hash,) = f.target.summary(f.bundle.personhood[1].recordHash);
        assert(hash == f.bundle.personhood[1].summaryHash);
    }

    function testRecoveredAttestationsAbsentFeatureKeepsOriginalBaseCodecDispatch() external {
        Fixture memory f = _start();
        f.source.createAttribution(9, true);
        f.provenance = _local(f.source);
        bytes memory original =
            f.source.attribution().recoveredAuthorityHydrationState(f.query, f.provenance);
        (bytes32 tag, Base.AttributionBundle memory b) =
            abi.decode(original, (bytes32, Base.AttributionBundle));
        assert(tag == Base.ATTRIBUTION && keccak256(original) == keccak256(abi.encode(tag, b)));
        bytes memory raw = _outer(f, original, 0);
        assert(!Checked.selected(raw));
        f.destination.hydrate(f.query, raw, true, false);
        assert(f.target.attribution(9).state == 2 && f.target.attribution(9).generation == 1);
        assert(
            f.target.personhood(9, f.query.artistId) == 0
                && f.target.head(f.query.artistId).recordHash == 0
        );
    }

    function _start() private returns (Fixture memory f) {
        vm.warp(1000);
        RecoveredAttestationRegistryFixture registry = new RecoveredAttestationRegistryFixture();
        f.source = new RecoveredAttestationCoordinatorFixture(address(registry));
        registry.bind(address(f.source));
        T.Binding memory b = f.source.binding(true);
        f.query.artistId = b.artistId;
        f.query.collectionId = 9;
        f.query.bindingHash = b.bindingHash;
        RecoveredAttestationRegistryFixture next = new RecoveredAttestationRegistryFixture();
        f.destination = new RecoveredAttestationTargetCoordinator(
            address(next), f.source.authorityHydrationSuite()
        );
        next.bind(address(f.destination));
        f.target = f.destination.target();
    }

    function _fixture(bool mixed) private returns (Fixture memory f) {
        f = _start();
        f.source.createAttribution(9, true);
        f.inputs = new ReadinessH.AttestationInput[](mixed ? 8 : 2);
        if (!mixed) {
            _admit(
                f,
                0,
                _identity(keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")),
                bytes("explicit waiver"),
                1,
                false
            );
            _admit(
                f,
                1,
                _identity(Definitions.EVIDENCE_SCHEMA),
                bytes("original opaque evidence"),
                3,
                false
            );
        } else {
            T.SuiteConfiguration memory s = f.source.authorityHydrationSuite();
            T.Attestation memory p;
            p.collectionId = 9;
            p.subjectKind = 9;
            p.subjectId = bytes32(uint256(uint160(s.core)));
            p.subjectStateHash = Hashes.deploymentFacts(
                Hashes.Environment(block.chainid, s.registry, s.core, s.mintManager),
                9,
                f.source.binding(true)
            );
            p.schemaId = keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1");
            _admit(f, 0, p, bytes("original deployment"), 1, true);
            p = T.Attestation(
                9,
                1,
                keccak256("one routed subject"),
                keccak256("state at delegated admission"),
                keccak256("routed statement schema"),
                0,
                ""
            );
            _admit(f, 1, p, bytes("delegated scoped fact"), 2, false);
            _admit(
                f,
                2,
                _identity(keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")),
                bytes("waiver"),
                1,
                false
            );
            bytes32 first = _admit(
                f,
                3,
                _identity(Credentials.SCHEMA),
                _credentials(f.query.artistId, 0, false),
                3,
                false
            );
            Publication.Publication memory pub = Publication.Publication(
                address(f.source),
                address(1705),
                9,
                keccak256("original intent subject"),
                keccak256("ARTIST_INTENT"),
                keccak256("STREAM_ARTIST_INTENT_V1"),
                keccak256("canonical document"),
                1,
                keccak256("payload"),
                keccak256(bytes("original uri")),
                1000,
                keccak256("original immutable candidate")
            );
            p = T.Attestation(
                9,
                7,
                pub.subjectId,
                pub.candidateRecordHash,
                keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
                0,
                "original uri"
            );
            _admit(f, 4, p, abi.encode(uint16(1), pub), 2, false);
            _admit(
                f,
                5,
                _identity(Definitions.EVIDENCE_SCHEMA),
                bytes("opaque retained evidence"),
                3,
                false
            );
            _admit(
                f,
                6,
                _identity(Credentials.SCHEMA),
                _credentials(f.query.artistId, first, true),
                1,
                false
            );
            p = abi.decode(abi.encode(f.inputs[1].terms), (T.Attestation));
            p.subjectStateHash = keccak256("later scoped state after recovery");
            _admit(f, 7, p, bytes("class3 replacement at same subject key"), 3, false);
        }
        f.provenance = _local(f.source);
        f.bundle =
            f.target.collect(address(f.source.attribution()), f.query, f.provenance, f.inputs);
    }

    function _admit(
        Fixture memory f,
        uint256 i,
        T.Attestation memory p,
        bytes memory statement_,
        uint8 class_,
        bool legacy
    ) private returns (bytes32) {
        p.statementHash = keccak256(statement_);
        f.inputs[i] = ReadinessH.AttestationInput(p, i + 100);
        return f.source.attest(p, statement_, class_, i + 100, legacy);
    }

    function _identity(bytes32 schema) private pure returns (T.Attestation memory) {
        return T.Attestation(9, 10, bytes32(uint256(1701)), IDENTITY, schema, 0, "");
    }

    function _credentials(bytes32 artist, bytes32 previous, bool empty)
        private
        pure
        returns (bytes memory)
    {
        C2PA.Payload memory p;
        p.schemaVersion = 1;
        p.artistId = artist;
        p.identityRecordHash = IDENTITY;
        p.previousRecordHash = previous;
        p.credentials = new C2PA.Credential[](empty ? 0 : 1);
        if (!empty) {
            p.credentials[0] =
                C2PA.Credential(1, keccak256("fingerprint"), keccak256("public key id"), 1, 0);
        }
        return abi.encode(p);
    }

    function _local(RecoveredAttestationCoordinatorFixture source)
        private
        view
        returns (RH.OwnerProvenance memory p)
    {
        T.SuiteConfiguration memory s = source.authorityHydrationSuite();
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
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0] = o;
        StreamArtistOwner owner = source.owner(4);
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(o);
        p.eras[0].checkpoint = owner.authorityCheckpoint();
        p.eras[0].nativeCount = owner.artistNativeReceiptCount();
        p.journal = new RH.JournalEntry[](p.eras[0].nativeCount);
        for (uint256 i; i < p.journal.length; ++i) {
            p.journal[i] = RH.JournalEntry(
                RH.Position(
                    RH.Point(p.eras[0].originHash, 4, owner.artistNativeReceiptRevisionAt(i)), i
                ),
                owner.artistNativeReceiptAt(i)
            );
        }
        p.aliases = new RH.ReplayAlias[](0);
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
            4,
            era.originHash,
            era.priorImportCommitment,
            keccak256(semantic),
            RH.ownerProvenanceHash(p, 4),
            RH.aliasesHash(4, p.aliases),
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
        return Payload.encode(4, h, payload);
    }

    function _encoded(Fixture memory f) private pure returns (bytes memory) {
        return _outer(f, Checked.encode(f.bundle, f.query, f.provenance), RH.ATTESTATIONS);
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function _refresh(Fixture memory f) private pure {
        f.bundle.provenance = RH.ownerProvenanceHash(f.provenance, 4);
    }

    function _invalid(Fixture memory f, bytes4 error_) private {
        _fail(
            address(f.target),
            abi.encodeCall(f.target.validate, (f.bundle, f.query, f.provenance)),
            error_
        );
    }

    function _collectFails(
        Fixture memory f,
        ReadinessH.AttestationInput[] memory inputs,
        bytes4 error_
    ) private {
        _fail(
            address(f.target),
            abi.encodeCall(
                f.target.collect, (address(f.source.attribution()), f.query, f.provenance, inputs)
            ),
            error_
        );
    }

    function _fail(address target, bytes memory input, bytes4 error_) private {
        (bool ok, bytes memory out) = target.call(input);
        assert(!ok && out.length >= 4 && bytes4(out) == error_);
    }

    function _same(Fixture memory f) private view {
        assert(f.target.attribution(9).state == 2 && f.target.attribution(9).generation == 1);
        for (uint256 i; i < f.bundle.records.length; ++i) {
            PubH.Row memory r = f.bundle.records[i];
            (
                T.AttestationRecord memory record,
                uint8 class_,
                Attest.Association memory association,
                PublicationOwner.Record memory publication
            ) = f.target.row(r.attestation.record.recordHash);
            assert(
                keccak256(abi.encode(record, class_, association, publication))
                    == keccak256(
                        abi.encode(
                            r.attestation.record,
                            r.attestation.authorityClass,
                            r.attestation.association,
                            r.publication
                        )
                    )
            );
            assert(keccak256(f.target.statement(record.statementHash)) == record.statementHash);
            assert(
                keccak256(abi.encode(f.target.latest(r.attestation.input.terms)))
                    == keccak256(
                        abi.encode(
                            f.source.attribution()
                                .attestation(
                                    9,
                                    r.attestation.input.terms.subjectKind,
                                    r.attestation.input.terms.subjectId
                                )
                        )
                    )
            );
            assert(
                keccak256(abi.encode(f.target.credential(record.recordHash)))
                    == keccak256(
                        abi.encode(f.source.attribution().c2paCredentialRecord(record.recordHash))
                    )
            );
        }
        for (uint256 i; i < f.bundle.personhood.length; ++i) {
            Checked.PersonhoodRow memory p = f.bundle.personhood[i];
            (address origin, bytes32 hash, Personhood.Summary memory s) =
                f.target.summary(p.recordHash);
            assert(
                origin == p.originalRegistry && hash == p.summaryHash
                    && keccak256(abi.encode(s)) == keccak256(abi.encode(p.summary))
            );
        }
        assert(
            keccak256(abi.encode(f.target.head(f.query.artistId)))
                == keccak256(
                    abi.encode(f.source.attribution().c2paCredentialHead(f.query.artistId))
                )
        );
    }

    function _empty(Fixture memory f) private view {
        assert(
            f.target.importGuard() == 0 && f.target.attribution(9).state == 0
                && f.target.attribution(9).generation == 0
        );
        assert(
            f.target.head(f.query.artistId).recordHash == 0
                && f.target.personhood(9, f.query.artistId) == 0
        );
        T.AttestationRecord memory emptyRecord;
        Attest.Association memory emptyAssociation;
        PublicationOwner.Record memory emptyPublication;
        Personhood.Summary memory emptySummary;
        for (uint256 i; i < f.bundle.records.length; ++i) {
            ReadinessH.AttestationRow memory r = f.bundle.records[i].attestation;
            (
                T.AttestationRecord memory record,
                uint8 class_,
                Attest.Association memory association,
                PublicationOwner.Record memory publication
            ) = f.target.row(r.record.recordHash);
            assert(
                keccak256(abi.encode(record, class_, association, publication))
                    == keccak256(
                        abi.encode(emptyRecord, uint8(0), emptyAssociation, emptyPublication)
                    )
            );
            assert(
                f.target.statement(r.record.statementHash).length == 0
                    && f.target.latest(r.input.terms).recordHash == 0
                    && f.target.credential(r.record.recordHash).recordHash == 0
            );
            (address origin, bytes32 hash, Personhood.Summary memory s) =
                f.target.summary(r.record.recordHash);
            assert(
                origin == address(0) && hash == 0
                    && keccak256(abi.encode(s)) == keccak256(abi.encode(emptySummary))
            );
        }
    }

    function _sourceHash(Fixture memory f) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                f.source.attribution().authorityCheckpoint(),
                f.target.collect(address(f.source.attribution()), f.query, f.provenance, f.inputs)
            )
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
        p.origins[1].owners[4] = address(9503);
        p.origins[1].suiteConfigurationHash = keccak256("synthetic B era");
        bytes32 origin = RH.originHash(p.origins[1]);
        p.eras = new RH.OwnerEra[](2);
        p.eras[0] = old.eras[0];
        p.eras[1] = abi.decode(abi.encode(old.eras[0]), (RH.OwnerEra));
        p.eras[1].originHash = origin;
        p.eras[1].nativeCount = 1;
        p.eras[1].lowerRevision = 1;
        p.eras[1].priorImportCommitment = keccak256("synthetic authenticated import");
        p.eras[1].checkpoint.ownerState.revision = 2;
        p.journal = new RH.JournalEntry[](9);
        for (uint256 i; i < 8; ++i) {
            p.journal[i] = old.journal[i];
        }
        PubH.Row[] memory rows = new PubH.Row[](9);
        for (uint256 i; i < 8; ++i) {
            rows[i] = f.bundle.records[i];
        }
        rows[8] = abi.decode(abi.encode(rows[6]), (PubH.Row));
        ReadinessH.AttestationRow memory r = rows[8].attestation;
        r.input.nonce = 999;
        r.statement = _credentials(f.query.artistId, rows[6].attestation.record.recordHash, true);
        r.input.terms.statementHash = keccak256(r.statement);
        r.record.statementHash = r.input.terms.statementHash;
        ++r.record.signedAt;
        r.association.fact.owner = p.origins[1].owners[2];
        r.association.fact.ownerCodeHash = p.origins[1].ownerCodeHashes[2];
        r.record.recordHash = _recordHash(p.origins[1], f.query.artistId, r);
        rows[8].attestation = r;
        p.journal[8] = RH.JournalEntry(
            RH.Position(RH.Point(origin, 4, 2), 0),
            H.Receipt(24, f.query.artistId, 9, r.record.recordHash)
        );
        p.aliases = new RH.ReplayAlias[](0);
        f.provenance = p;
        f.bundle.records = rows;
        _refresh(f);
    }

    function _recordHash(
        RH.OriginEnvironment memory o,
        bytes32 artist,
        ReadinessH.AttestationRow memory r
    ) private pure returns (bytes32) {
        return Hashes.attestationRecordForAuthority(
            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
            r.input.terms,
            artist,
            r.record.signer,
            r.authorityClass,
            r.input.nonce,
            r.record.signedAt
        );
    }

    function _canonicalSummary(Fixture memory f) private {
        // Synthetic canonical documentary input at the already-authenticated typed component
        // boundary. The original eight actual source records are not rewritten or reauthorized.
        vm.etch(f.provenance.origins[0].core, hex"00");
        ReadinessH.AttestationRow memory r = f.bundle.records[5].attestation;
        Personhood.Reference memory ref_ = Personhood.Reference(
            1,
            Definitions.PROFILE_HASH,
            f.provenance.origins[0].registry,
            f.query.artistId,
            IDENTITY,
            address(0x1234),
            keccak256("unavailable historical notary runtime"),
            keccak256("retained documentary record")
        );
        r.statement = PersonhoodJSON.encode(ref_);
        r.input.terms.statementHash = keccak256(r.statement);
        r.record.statementHash = r.input.terms.statementHash;
        r.record.recordHash = _recordHash(f.provenance.origins[0], f.query.artistId, r);
        f.bundle.records[5].attestation = r;
        f.provenance.journal[5].receipt.recordHash = r.record.recordHash;
        Personhood.Summary memory s;
        s.version = 1;
        s.chainId = block.chainid;
        s.nativeRecordHash = r.record.recordHash;
        s.statementHash = r.record.statementHash;
        s.artistId = f.query.artistId;
        s.bindingHash = f.query.bindingHash;
        s.generation = 1;
        s.collectionId = 9;
        s.identityRecordHash = IDENTITY;
        s.evidenceReference = ref_;
        s.originalRegistryCodeHash = f.provenance.origins[0].registry.codehash;
        s.core = f.provenance.origins[0].core;
        s.coreCodeHash = s.core.codehash;
        s.documentaryHash = keccak256("synthetic admitted immutable documentary summary");
        bytes32 hash =
            keccak256(abi.encode(keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), s));
        f.bundle.personhood[1] =
            Checked.PersonhoodRow(r.record.recordHash, f.provenance.origins[0].registry, s, hash);
        _refresh(f);
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature("personhoodProofSummary(bytes32)", r.record.recordHash),
            abi.encode(s)
        );
        vm.mockCall(
            address(f.source.attribution()),
            abi.encodeWithSignature("personhoodProofSummaryHash(bytes32)", r.record.recordHash),
            abi.encode(hash)
        );
        f.target.validate(f.bundle, f.query, f.provenance);
    }
}
