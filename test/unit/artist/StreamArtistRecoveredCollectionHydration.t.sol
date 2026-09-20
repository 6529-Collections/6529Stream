// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistAttributionLifecycle
} from "../../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";
import {
    StreamArtistConsentFinalityLifecycle
} from "../../../smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol";
import {
    StreamArtistRecoveredCollectionHydration as Collection
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
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

contract RecoveredCollectionPeer is StreamArtistOwner {
    constructor(address registry, uint8 index)
        StreamArtistOwner(
            registry, msg.sender, address(703), RH.ownerDomain(index), address(701), address(702)
        )
    { }
}

/// @dev Actual Attribution/Consent owners and original writers. The test fixture supplies the
/// immutable Coordinator's admitted Binding/authority facts; it does not prove signature,
/// class3 recovery/capability admission, collection binding, lane55/56, or full operation60.
contract RecoveredCollectionCoordinatorFixture {
    T.SuiteConfiguration private _suite;
    mapping(bytes32 => AH.Origin) private _witnesses;
    bool public lateFailure;
    error CollectionLateFailure();

    constructor(address registry) {
        _suite.registry = registry;
        _suite.archive = address(703);
        _suite.core = address(701);
        _suite.mintManager = address(702);
        _suite.owners[4] = address(
            new StreamArtistAttributionLifecycle(
                registry, address(this), address(703), address(701), address(702)
            )
        );
        _suite.owners[6] = address(
            new StreamArtistConsentFinalityLifecycle(
                registry, address(this), address(703), address(701), address(702)
            )
        );
        for (uint8 i; i < 7; ++i) {
            if (i != 4 && i != 6) {
                _suite.owners[i] = address(new RecoveredCollectionPeer(registry, i));
            }
        }
    }

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration memory) {
        return _suite;
    }

    function owner(uint8 index) external view returns (StreamArtistOwner) {
        return StreamArtistOwner(_suite.owners[index]);
    }

    function attribution() public view returns (StreamArtistAttributionLifecycle) {
        return StreamArtistAttributionLifecycle(_suite.owners[4]);
    }

    function consent() public view returns (StreamArtistConsentFinalityLifecycle) {
        return StreamArtistConsentFinalityLifecycle(_suite.owners[6]);
    }

    function replayWitness(bytes32 key) external view returns (AH.Origin memory) {
        return _witnesses[key];
    }

    function binding(bool accepted) public pure returns (T.Binding memory b) {
        b.artistId = bytes32(uint256(1701));
        b.artistAddress = address(1702);
        b.identityRecordHash = keccak256("fixture original genesis");
        b.bindingHash = keccak256("fixture admitted PRIMARY_ONLY generation1");
        b.generation = 1;
        b.consentMode = 1;
        b.proposer = address(1703);
        b.accepted = accepted;
    }

    function createAttribution(uint256 collection, bool complete) external {
        T.Binding memory b = binding(false);
        attribution().claim(_context(4, 1), collection, b, keccak256("original claim reason"), "");
        if (complete) {
            attribution()
                .accept(
                    _context(4, 2), collection, b, keccak256("fixture accepted binding receipt")
                );
        }
    }

    function policy(T.PolicyConsent calldata p, uint8 class_, uint256 nonce)
        external
        returns (bytes32 record)
    {
        T.Binding memory b = binding(true);
        address signer = class_ == 1 ? b.artistAddress : address(1704);
        record = consent()
            .recordPolicyWithAuthority(
                _context(6, 14),
                b,
                p,
                signer,
                nonce,
                R.AuthorityFact(b.artistId, signer, class_, class_ == 1 ? 1 : 3)
            );
        _witness(
            keccak256("consent_finality.replay.policy_consent_key"),
            keccak256(abi.encode(p.collectionId, p.phaseId, p.policyHash))
        );
    }

    function delegatedPolicy(T.PolicyConsent calldata p) external returns (bytes32 record) {
        T.Binding memory b = binding(true);
        b.consentMode = 2;
        record = consent()
            .recordDelegatedPolicyConsent(
                _context(6, 14),
                b,
                p,
                address(1705),
                99,
                keccak256("fixture admitted delegate grant")
            );
        _witness(
            keccak256("consent_finality.replay.policy_consent_key"),
            keccak256(abi.encode(p.collectionId, p.phaseId, p.policyHash))
        );
    }

    function ratify() external returns (bytes32 record) {
        T.Binding memory b = binding(true);
        T.Ratification memory p =
            T.Ratification(9, address(1706), keccak256("original ratified content"));
        record = consent().recordRatification(_context(6, 52), b, p, b.artistAddress, 100);
        _witness(
            keccak256("consent_finality.replay.ratification_key"),
            keccak256(abi.encode(p.collectionId, record))
        );
    }

    function setLateFailure(bool fail) external {
        lateFailure = fail;
    }

    function importBoth(AH.Query calldata q, AH.OwnerData[2] calldata data, bytes32 commitment)
        external
    {
        attribution().applyArtistAuthorityHydration(_context(4, 60), q, data[0], commitment);
        consent().applyArtistAuthorityHydration(_context(6, 60), q, data[1], commitment);
        if (lateFailure) revert CollectionLateFailure();
    }

    function _context(uint8 index, uint16 operation) private view returns (T.ActionContext memory) {
        return T.ActionContext(
            operation, address(this), StreamArtistOwner(_suite.owners[index]).ownerStateSnapshotV2()
        );
    }

    function _witness(bytes32 surface, bytes32 scope) private {
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                _suite.registry,
                address(this),
                _suite.archive,
                _suite.owners[6],
                RH.ownerDomain(6),
                surface,
                scope
            )
        );
        _witnesses[key] = AH.Origin(surface, scope);
    }
}

/// @dev Pure malformed-certificate tests are deliberately separate from actual source exports.
contract RecoveredCollectionValidator {
    function attribution(
        Collection.AttributionBundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) external pure {
        Collection.validateAttribution(b, q, p);
    }

    function policies(
        Collection.PolicyBundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) external pure {
        Collection.validatePolicies(b, q, p);
    }
}

contract StreamArtistRecoveredCollectionHydrationTest {
    function testCollectionActualAttributionAndMixedPrincipalPolicyHashesRoundTrip() external {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 2);
        for (uint256 i; i < 2; ++i) {
            T.PolicyConsent memory p =
                T.PolicyConsent(9, q.policies[i].phaseId, q.policies[i].policyHash);
            uint8 class_ = i == 0 ? 1 : 3;
            bytes32 actual = source.policy(p, class_, i + 5);
            assert(actual == _policyHash(source, p, class_, i + 5));
            assert(source.consent().artistNativeReceiptAt(i).recordHash == actual);
            assert(source.consent().artistNativeReceiptRevisionAt(i) == i + 1);
            assert(source.consent().recordDelegation(actual) == 0);
        }
        RH.OwnerProvenance memory attr = _local(source, 4);
        (, Collection.AttributionBundle memory ab) = abi.decode(
            source.attribution().recoveredAuthorityHydrationState(q, attr),
            (bytes32, Collection.AttributionBundle)
        );
        assert(ab.item.state == 2 && ab.item.generation == 1 && attr.journal.length == 0);
        assert(attr.eras[0].checkpoint.ownerState.revision == 2);
        assert(
            keccak256(source.attribution().authorityHydrationState(q))
                == keccak256(abi.encode(AS.Attribution(2, 1)))
        );
        RH.OwnerProvenance memory policy = _local(source, 6);
        (, Collection.PolicyBundle memory pb) = abi.decode(
            source.consent().recoveredAuthorityHydrationState(q, policy),
            (bytes32, Collection.PolicyBundle)
        );
        assert(pb.records.length == 2 && pb.records[0] != pb.records[1]);
        assert(Publications.collect(address(source.consent()), 6).length != 0);
        RecoveredCollectionCoordinatorFixture target =
            new RecoveredCollectionCoordinatorFixture(address(802));
        target.importBoth(q, _data(source, q), keccak256("collection admission boundary"));
        _same(source, target, q);
        assert(
            target.attribution().artistNativeReceiptCount() == 0
                && target.consent().artistNativeReceiptCount() == 0
        );
        assert(
            target.attribution().ownerStateSnapshotV2().revision == 1
                && target.consent().ownerStateSnapshotV2().revision == 1
        );
        for (uint256 i; i < policy.aliases.length; ++i) {
            RH.ReplayAlias memory a = policy.aliases[i];
            bytes32 key = _key(_origin(target), a);
            assert(
                keccak256(abi.encode(target.consent().replayCell(key)))
                    == keccak256(abi.encode(a.cell))
            );
            assert(
                keccak256(abi.encode(target.consent().recoveredHydrationReplayPoint(key)))
                    == keccak256(abi.encode(a.admittedAt))
            );
        }
    }

    function testCollectionExplicitEmptyPolicyCertificateIsNonemptyAndImports() external {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 0);
        RH.OwnerProvenance memory p = _local(source, 6);
        bytes memory raw = source.consent().recoveredAuthorityHydrationState(q, p);
        assert(raw.length != 0 && p.journal.length == 0 && p.aliases.length == 0);
        (bytes32 tag, Collection.PolicyBundle memory b) =
            abi.decode(raw, (bytes32, Collection.PolicyBundle));
        assert(tag == Collection.POLICIES && b.records.length == 0);
        RecoveredCollectionCoordinatorFixture target =
            new RecoveredCollectionCoordinatorFixture(address(803));
        target.importBoth(q, _data(source, q), keccak256("empty policy admission"));
        assert(target.consent().authorityCheckpoint().replayCount == 0);
        assert(target.consent().ownerStateSnapshotV2().revision == 1);
    }

    function testCollectionRealPolicyReplayRejectsDuplicateScopeAndCompleteSelectionRequiresEveryScope()
        external
    {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 2);
        T.PolicyConsent memory first =
            T.PolicyConsent(9, q.policies[0].phaseId, q.policies[0].policyHash);
        source.policy(first, 1, 5);
        RH.OwnerProvenance memory old = _local(source, 6);
        bytes32 before_ = _snapshot(source);
        _revert(
            address(source),
            abi.encodeCall(source.policy, (first, uint8(1), uint256(99))),
            abi.encodeWithSelector(T.Replay.selector, old.aliases[0].originalKey)
        );
        assert(_snapshot(source) == before_);
        source.policy(T.PolicyConsent(9, q.policies[1].phaseId, q.policies[1].policyHash), 1, 6);
        RH.OwnerProvenance memory p = _local(source, 6);
        AH.Query memory omitted = _query(source, 1);
        _exportFail(source, omitted, p, 6);
        q.policies[1] = q.policies[0];
        _exportFail(source, q, p, 6);
    }

    function testCollectionRejectsRealDelegatedPolicyEvenWithOnlyOperation14History() external {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 1);
        bytes32 record = source.delegatedPolicy(
            T.PolicyConsent(9, q.policies[0].phaseId, q.policies[0].policyHash)
        );
        assert(source.consent().artistNativeReceiptAt(0).operation == 14);
        assert(
            source.consent().recordDelegation(record)
                == keccak256("fixture admitted delegate grant")
        );
        _exportFail(source, q, _local(source, 6), 6);
    }

    function testCollectionRejectsRealUnselectedRatificationNativeHistory() external {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 1);
        source.policy(T.PolicyConsent(9, q.policies[0].phaseId, q.policies[0].policyHash), 1, 5);
        bytes32 record = source.ratify();
        assert(source.consent().artistNativeReceiptAt(1).operation == 52);
        assert(source.consent().artistNativeReceiptAt(1).recordHash == record);
        _exportFail(source, q, _local(source, 6), 6);
    }

    function testCollectionRejectsRealPendingAndExtraNonnativeAttributionCollections() external {
        RecoveredCollectionCoordinatorFixture source =
            new RecoveredCollectionCoordinatorFixture(address(804));
        AH.Query memory q = _query(source, 0);
        source.createAttribution(9, false);
        _exportFail(source, q, _local(source, 4), 4);
        source = _source();
        q = _query(source, 0);
        source.createAttribution(10, false);
        assert(source.attribution().artistNativeReceiptCount() == 0);
        assert(source.attribution().authorityCheckpoint().replayCount == 0);
        assert(source.attribution().ownerStateSnapshotV2().revision == 3);
        _exportFail(source, q, _local(source, 4), 4);
    }

    function testCollectionPolicyCertificateRejectsCrossScopeAndWrongOriginalRecordJoins()
        external
    {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 2);
        source.policy(T.PolicyConsent(9, q.policies[0].phaseId, q.policies[0].policyHash), 1, 5);
        source.policy(T.PolicyConsent(9, q.policies[1].phaseId, q.policies[1].policyHash), 1, 6);
        RH.OwnerProvenance memory p = _local(source, 6);
        bytes memory raw = source.consent().recoveredAuthorityHydrationState(q, p);
        RecoveredCollectionValidator validator = new RecoveredCollectionValidator();
        for (uint256 i; i < 4; ++i) {
            (, Collection.PolicyBundle memory b) =
                abi.decode(raw, (bytes32, Collection.PolicyBundle));
            if (i == 0) {
                bytes32 first = b.records[0];
                b.records[0] = b.records[1];
                b.records[1] = first;
            }
            if (i == 1) b.records[1] = b.records[0];
            if (i == 2) b.records[0] = keccak256("not original policy record");
            if (i == 3) b.collectionId = 10;
            _profileFail(address(validator), abi.encodeCall(validator.policies, (b, q, p)));
        }
    }

    function testCollectionCanonicalPayloadRejectsWrongTagsAndTrailingSemanticBytesAtomically()
        external
    {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 0);
        AH.OwnerData[2] memory original = _data(source, q);
        for (uint256 i; i < 4; ++i) {
            RecoveredCollectionCoordinatorFixture target =
                new RecoveredCollectionCoordinatorFixture(address(uint160(805 + i)));
            AH.OwnerData[2] memory data = abi.decode(abi.encode(original), (AH.OwnerData[2]));
            uint256 selected = i / 2;
            uint8 index = selected == 0 ? 4 : 6;
            (RH.ExportHeader memory header, Payload.Payload memory payload) =
                Payload.decode(data[selected].typedState, index);
            if (i % 2 == 0) {
                bytes memory semantic = payload.semanticState;
                assembly ("memory-safe") { mstore(add(semantic, 32), 1) }
            } else {
                payload.semanticState = bytes.concat(payload.semanticState, bytes32(uint256(1)));
            }
            header.semanticInventory = keccak256(payload.semanticState);
            data[selected].typedState = Payload.encode(index, header, payload);
            bytes32 before_ = _snapshot(target);
            _profileFail(
                address(target),
                abi.encodeCall(target.importBoth, (q, data, keccak256("canonical negative")))
            );
            assert(_snapshot(target) == before_);
        }
    }

    function testCollectionLateRevertRestoresBothOwnersAndIdenticalRetryKeepsOriginals() external {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 1);
        source.policy(T.PolicyConsent(9, q.policies[0].phaseId, q.policies[0].policyHash), 1, 5);
        RecoveredCollectionCoordinatorFixture target =
            new RecoveredCollectionCoordinatorFixture(address(810));
        AH.OwnerData[2] memory data = _data(source, q);
        bytes memory call_ =
            abi.encodeCall(target.importBoth, (q, data, keccak256("late collection admission")));
        bytes32 before_ = _snapshot(target);
        target.setLateFailure(true);
        _revert(
            address(target),
            call_,
            abi.encodeWithSelector(
                RecoveredCollectionCoordinatorFixture.CollectionLateFailure.selector
            )
        );
        assert(_snapshot(target) == before_);
        (uint8 state, uint64 generation) = target.attribution().staticAttributionState(9);
        assert(state == 0 && generation == 0);
        assert(
            target.consent().policyRecord(9, q.policies[0].phaseId, q.policies[0].policyHash) == 0
        );
        target.setLateFailure(false);
        (bool ok,) = address(target).call(call_);
        assert(ok);
        _same(source, target, q);
    }

    function testCollectionImportRejectsHiddenDestinationAttributionClaimAndRestoresPrefix()
        external
    {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 0);
        RecoveredCollectionCoordinatorFixture target =
            new RecoveredCollectionCoordinatorFixture(address(811));
        target.createAttribution(10, false);
        assert(target.attribution().artistNativeReceiptCount() == 0);
        bytes32 before_ = _snapshot(target);
        _revert(
            address(target),
            abi.encodeCall(
                target.importBoth, (q, _data(source, q), keccak256("occupied attribution"))
            ),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        assert(_snapshot(target) == before_);
        (uint8 state, uint64 generation) = target.attribution().staticAttributionState(10);
        assert(state == 1 && generation == 1);
        (state, generation) = target.attribution().staticAttributionState(9);
        assert(state == 0 && generation == 0);
        (RH.OwnerProvenance memory prefix, bytes32 commitment, uint64 importedAt) =
            target.attribution().recoveredHydrationImportedPrefix();
        assert(prefix.origins.length == 0 && commitment == 0 && importedAt == 0);
    }

    function testCollectionEmptyInventoriesRejectNonceReplayAndUnaccountedRevisionCertificates()
        external
    {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 0);
        RecoveredCollectionValidator validator = new RecoveredCollectionValidator();
        for (uint256 index_; index_ < 2; ++index_) {
            uint8 index = index_ == 0 ? 4 : 6;
            RH.OwnerProvenance memory original = _local(source, index);
            bytes memory raw = source.owner(index).recoveredAuthorityHydrationState(q, original);
            for (uint256 i; i < 4; ++i) {
                RH.OwnerProvenance memory p = abi.decode(abi.encode(original), (RH.OwnerProvenance));
                if (i == 0) p.eras[0].checkpoint.nonceIndexCount = 1;
                if (i == 1) p.eras[0].checkpoint.nonceRoot = keccak256("hidden nonce history");
                if (i == 2) p.eras[0].checkpoint.replayRoot = keccak256("hidden replay history");
                if (i == 3) ++p.eras[0].checkpoint.ownerState.revision;
                _profileFail(address(validator), _validationCall(validator, raw, q, p, index));
            }
        }
    }

    function testCollectionRejectsAdditionalAuthenticatedShapeReplayAndUnsupportedNativeOccurrence()
        external
    {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 0);
        RH.OwnerProvenance memory original = _local(source, 6);
        bytes memory raw = source.consent().recoveredAuthorityHydrationState(q, original);
        RecoveredCollectionValidator validator = new RecoveredCollectionValidator();
        // Shape-consistent synthetic certificates isolate the semantic omission boundary.
        RH.OwnerProvenance memory p = abi.decode(abi.encode(original), (RH.OwnerProvenance));
        p.eras[0].checkpoint.ownerState.revision = 1;
        p.eras[0].checkpoint.replayCount = 1;
        p.aliases = new RH.ReplayAlias[](1);
        RH.ReplayAlias memory a;
        a.ownerIndex = 6;
        a.originHash = p.eras[0].originHash;
        a.surface = keccak256("consent_finality.replay.ratification_key");
        a.scope = keccak256("synthetic omitted original scope");
        a.cell = T.ReplayCell(keccak256("synthetic omitted original record"), 1, 1, 2);
        a.admittedAt = RH.Point(a.originHash, 6, 1);
        a.originalKey = _key(p.origins[0], a);
        p.aliases[0] = a;
        _profileFail(address(validator), _validationCall(validator, raw, q, p, 6));
        p = abi.decode(abi.encode(original), (RH.OwnerProvenance));
        p.eras[0].checkpoint.ownerState.revision = 1;
        p.eras[0].nativeCount = 1;
        p.journal = new RH.JournalEntry[](1);
        p.journal[0].position = RH.Position(RH.Point(p.eras[0].originHash, 6, 1), 0);
        p.journal[0].receipt.operation = 52;
        p.journal[0].receipt.artistId = q.artistId;
        p.journal[0].receipt.collectionId = q.collectionId;
        p.journal[0].receipt.recordHash = keccak256("synthetic omitted native52");
        _profileFail(address(validator), _validationCall(validator, raw, q, p, 6));
    }

    function testCollectionRepeatedEraRequiresExactImportBoundaryAndNoHiddenAttributionMutation()
        external
    {
        RecoveredCollectionCoordinatorFixture source = _source();
        AH.Query memory q = _query(source, 0);
        RecoveredCollectionValidator validator = new RecoveredCollectionValidator();
        for (uint256 i; i < 2; ++i) {
            uint8 index = i == 0 ? 4 : 6;
            RH.OwnerProvenance memory p = _local(source, index);
            bytes memory raw = source.owner(index).recoveredAuthorityHydrationState(q, p);
            RH.OwnerProvenance memory repeated = _secondEra(p, index);
            (bool ok,) =
                address(validator).call(_validationCall(validator, raw, q, repeated, index));
            assert(ok);
            repeated.eras[1].lowerRevision = 2;
            repeated.eras[1].checkpoint.ownerState.revision = 2;
            _profileFail(address(validator), _validationCall(validator, raw, q, repeated, index));
        }
    }

    function _source() private returns (RecoveredCollectionCoordinatorFixture source) {
        source = new RecoveredCollectionCoordinatorFixture(address(801));
        source.createAttribution(9, true);
    }

    function _query(RecoveredCollectionCoordinatorFixture source, uint256 count)
        private
        view
        returns (AH.Query memory q)
    {
        T.Binding memory b = source.binding(true);
        q.artistId = b.artistId;
        q.collectionId = 9;
        q.bindingHash = b.bindingHash;
        q.policies = new AH.PolicyKey[](count);
        for (uint256 i; i < count; ++i) {
            q.policies[i] = AH.PolicyKey(bytes32(i + 1), bytes32(i + 101));
        }
    }

    function _origin(RecoveredCollectionCoordinatorFixture source)
        private
        view
        returns (RH.OriginEnvironment memory o)
    {
        T.SuiteConfiguration memory suite = source.authorityHydrationSuite();
        o.chainId = block.chainid;
        o.registry = suite.registry;
        o.coordinator = address(source);
        o.archive = suite.archive;
        o.owners = suite.owners;
        for (uint8 i; i < 7; ++i) {
            o.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        o.core = suite.core;
        o.manager = suite.mintManager;
        o.suiteConfigurationHash = keccak256(abi.encode(suite));
    }

    function _local(RecoveredCollectionCoordinatorFixture source, uint8 index)
        private
        view
        returns (RH.OwnerProvenance memory p)
    {
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0] = _origin(source);
        StreamArtistOwner owner = source.owner(index);
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(p.origins[0]);
        p.eras[0].checkpoint = owner.authorityCheckpoint();
        p.eras[0].nativeCount = owner.artistNativeReceiptCount();
        p.journal = new RH.JournalEntry[](p.eras[0].nativeCount);
        for (uint256 i; i < p.journal.length; ++i) {
            p.journal[i].receipt = owner.artistNativeReceiptAt(i);
            p.journal[i].position = RH.Position(
                RH.Point(p.eras[0].originHash, index, owner.artistNativeReceiptRevisionAt(i)), i
            );
        }
        p.aliases = new RH.ReplayAlias[](p.eras[0].checkpoint.replayCount);
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a;
            a.ownerIndex = index;
            a.originHash = p.eras[0].originHash;
            (a.originalKey, a.cell) = owner.authorityReplayAt(i);
            AH.Origin memory witness = source.replayWitness(a.originalKey);
            a.surface = witness.surface;
            a.scope = witness.scope;
            a.admittedAt = RH.Point(a.originHash, index, a.cell.touchedRevision);
            p.aliases[i] = a;
        }
        for (uint256 i = 1; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            uint256 j = i;
            while (j != 0 && p.aliases[j - 1].originalKey > a.originalKey) {
                p.aliases[j] = p.aliases[j - 1];
                --j;
            }
            p.aliases[j] = a;
        }
    }

    function _data(RecoveredCollectionCoordinatorFixture source, AH.Query memory q)
        private
        view
        returns (AH.OwnerData[2] memory data)
    {
        for (uint256 i; i < 2; ++i) {
            uint8 index = i == 0 ? 4 : 6;
            RH.OwnerProvenance memory p = _local(source, index);
            bytes memory semantic = source.owner(index).recoveredAuthorityHydrationState(q, p);
            RH.ExportHeader memory header;
            header.profile = RH.PROFILE;
            header.version = RH.VERSION;
            header.ownerIndex = index;
            header.sourceOrigin = p.eras[0].originHash;
            header.semanticInventory = keccak256(semantic);
            header.provenanceCommitment = RH.ownerProvenanceHash(p, index);
            header.replayAliasesCommitment = RH.aliasesHash(index, p.aliases);
            header.semanticRecordCount = p.journal.length;
            header.replayAliasCount = p.aliases.length;
            header.eraCount = 1;
            Payload.Payload memory payload;
            payload.provenance = p;
            payload.nonces = new RH.NonceInventory[](0);
            payload.semanticState = semantic;
            payload.publications = Publications.collect(address(source.owner(index)), index);
            data[i].typedState = Payload.encode(index, header, payload);
            data[i].origins = new AH.Origin[](p.aliases.length);
            data[i].sourceKeys = new bytes32[](p.aliases.length);
            data[i].cells = new T.ReplayCell[](p.aliases.length);
            for (uint256 j; j < p.aliases.length; ++j) {
                RH.ReplayAlias memory a = p.aliases[j];
                data[i].origins[j] = AH.Origin(a.surface, a.scope);
                data[i].sourceKeys[j] = a.originalKey;
                data[i].cells[j] = a.cell;
            }
        }
    }

    function _secondEra(RH.OwnerProvenance memory p, uint8 index)
        private
        pure
        returns (RH.OwnerProvenance memory next)
    {
        next.origins = new RH.OriginEnvironment[](2);
        next.origins[0] = p.origins[0];
        next.origins[1] = abi.decode(abi.encode(p.origins[0]), (RH.OriginEnvironment));
        next.origins[1].registry = address(9501);
        next.origins[1].coordinator = address(9502);
        next.origins[1].owners[index] = address(9503);
        next.origins[1].suiteConfigurationHash =
            keccak256("synthetic repeated collection environment");
        next.eras = new RH.OwnerEra[](2);
        next.eras[0] = p.eras[0];
        CP.Checkpoint memory cp = abi.decode(abi.encode(p.eras[0].checkpoint), (CP.Checkpoint));
        cp.ownerState.revision = 1;
        next.eras[1] = RH.OwnerEra(
            RH.originHash(next.origins[1]), cp, 0, 1, keccak256("synthetic prior import")
        );
        next.journal = p.journal;
        next.aliases = p.aliases;
    }

    function _validationCall(
        RecoveredCollectionValidator validator,
        bytes memory raw,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint8 index
    ) private pure returns (bytes memory) {
        if (index == 4) {
            (, Collection.AttributionBundle memory b) =
                abi.decode(raw, (bytes32, Collection.AttributionBundle));
            b.provenance = RH.ownerProvenanceHash(p, index);
            return abi.encodeCall(validator.attribution, (b, q, p));
        }
        (, Collection.PolicyBundle memory b) = abi.decode(raw, (bytes32, Collection.PolicyBundle));
        b.provenance = RH.ownerProvenanceHash(p, index);
        return abi.encodeCall(validator.policies, (b, q, p));
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

    function _policyHash(
        RecoveredCollectionCoordinatorFixture source,
        T.PolicyConsent memory p,
        uint8 class_,
        uint256 nonce
    ) private view returns (bytes32) {
        T.Binding memory b = source.binding(true);
        address signer = class_ == 1 ? b.artistAddress : address(1704);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1"),
                block.chainid,
                source.authorityHydrationSuite().registry,
                address(702),
                p.collectionId,
                p.phaseId,
                p.policyHash,
                b.artistId,
                signer,
                class_,
                nonce,
                uint64(block.timestamp)
            )
        );
    }

    function _same(
        RecoveredCollectionCoordinatorFixture source,
        RecoveredCollectionCoordinatorFixture target,
        AH.Query memory q
    ) private view {
        (uint8 state, uint64 generation) =
            target.attribution().staticAttributionState(q.collectionId);
        assert(state == 2 && generation == 1);
        for (uint8 index = 4; index <= 6; index += 2) {
            assert(
                keccak256(abi.encode(Publications.collect(address(source.owner(index)), index)))
                    == keccak256(
                        abi.encode(Publications.collect(address(target.owner(index)), index))
                    )
            );
        }
        for (uint256 i; i < q.policies.length; ++i) {
            AH.PolicyKey memory p = q.policies[i];
            bytes32 record = source.consent().policyRecord(q.collectionId, p.phaseId, p.policyHash);
            assert(
                record != 0
                    && target.consent().policyRecord(q.collectionId, p.phaseId, p.policyHash)
                        == record
            );
            assert(target.consent().recordDelegation(record) == 0);
        }
    }

    function _snapshot(RecoveredCollectionCoordinatorFixture target)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                target.attribution().authorityCheckpoint(),
                target.consent().authorityCheckpoint(),
                target.attribution().authorityHydrationCommitment(),
                target.consent().authorityHydrationCommitment(),
                Publications.collect(address(target.attribution()), 4),
                Publications.collect(address(target.consent()), 6)
            )
        );
    }

    function _exportFail(
        RecoveredCollectionCoordinatorFixture source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint8 index
    ) private {
        _profileFail(
            address(source.owner(index)),
            abi.encodeCall(source.owner(index).recoveredAuthorityHydrationState, (q, p))
        );
    }

    function _profileFail(address target, bytes memory call_) private {
        _revert(target, call_, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
    }

    function _revert(address target, bytes memory call_, bytes memory expected) private {
        (bool ok, bytes memory reason) = target.call(call_);
        assert(!ok && keccak256(reason) == keccak256(expected));
    }
}
