// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationCommitEncoding as Encoding
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommitEncoding.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationEvidence as Evidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationEvidence.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Readiness
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveryActionTypes as Action
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamGovernanceActionFacts as Governance
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityComponentExpectation,
    StreamFinalityManifestRef
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityRecoveryArtistEvidenceKind,
    StreamFinalityRecoveryEvidenceSnapshot
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";

/// @notice Pure encoding differential against Commit at b4d07ed0138931cfbaa66e205feb5e9ba630c5eb.
/// @dev Synthetic, deliberately distinct tuple values prove bytes, not admission or hydration.
/// The only execution cases call the real Commit's initial guard; no owner or Archive is mocked.
contract StreamArtistRecoveredHydrationCommitEncodingTest {
    bytes32 private constant PROFILE =
        keccak256("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1");
    bytes32 private constant PAGE_SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_EVIDENCE_V1");
    bytes32 private constant OPERATION_DOMAIN =
        keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1");
    uint256 private constant PAGE_BYTES = 20_480;

    struct Context {
        uint256 chainId;
        address registry;
        address coordinator;
        bytes32 configurationHash;
        address actor;
    }

    struct Encoded {
        bytes32 value;
        bytes profileBytes;
        Evidence.Descriptor descriptor;
        bytes carrier;
        bytes probe;
    }

    function testPrepareMatchesFrozenNestedPreimagesAndIndependentPages() public pure {
        (RH.Request memory r, Encoding.Inputs memory p) = _fixture(7);
        p.data[6].typedState = _bytes(71, PAGE_BYTES + 1);
        Encoded memory e = _parity(_context(11), r, p);
        assert(e.descriptor.schema == PAGE_SCHEMA);
        assert(e.descriptor.pageHashes.length > 1);
        assert(e.descriptor.payloadLength == e.profileBytes.length);
        assert(e.descriptor.payloadHash == keccak256(e.profileBytes));
        assert(keccak256(e.carrier) == keccak256(abi.encode(PROFILE, e.descriptor)));
    }

    function testEvidenceMatchesFrozenDomainAndDistinctBeforeAfterBytes() public pure {
        (RH.Request memory r, Encoding.Inputs memory p) = _fixture(19);
        Context memory c = _context(23);
        Encoded memory e = _actual(c, r, p);
        T.Snapshot[7] memory after_ = _after(p.before_);
        assert(keccak256(abi.encode(after_)) != keccak256(abi.encode(p.before_)));
        (bytes32 baselineId, bytes memory baselineBytes) = _evidenceParity(c, e, p.before_, after_);
        assert(keccak256(baselineBytes) != keccak256(e.probe));
        for (uint8 field; field < 5; ++field) {
            Context memory changed = _changedContext(23, field);
            (bytes32 id, bytes memory raw) = _evidenceParity(changed, e, p.before_, after_);
            // The original id excludes configuration. The evidence body excludes chain/hosts.
            assert((id == baselineId) == (field == 3));
            assert((keccak256(raw) == keccak256(baselineBytes)) == (field < 3));
        }
        T.Snapshot[7] memory changedAfter = _after(p.before_);
        changedAfter[6].stateRoot = _h(23, 900);
        (bytes32 unchangedId, bytes memory changedBytes) =
            _evidenceParity(c, e, p.before_, changedAfter);
        assert(unchangedId == baselineId && keccak256(changedBytes) != keccak256(baselineBytes));
    }

    function testPrepareSeparatesChainHostsConfigurationAndActor() public pure {
        (RH.Request memory r, Encoding.Inputs memory p) = _fixture(29);
        Encoded memory baseline = _actual(_context(31), r, p);
        for (uint8 field; field < 5; ++field) {
            Encoded memory e = _parity(_changedContext(31, field), r, p);
            assert((e.value == baseline.value) == (field >= 3));
            assert(keccak256(e.profileBytes) == keccak256(baseline.profileBytes));
            assert(
                keccak256(abi.encode(e.descriptor)) == keccak256(abi.encode(baseline.descriptor))
            );
            assert(keccak256(e.carrier) == keccak256(baseline.carrier));
            assert(keccak256(e.probe) != keccak256(baseline.probe));
        }
    }

    function testNestedTailMutationsCannotReuseOriginalCommitment() public pure {
        (RH.Request memory r, Encoding.Inputs memory p) = _fixture(37);
        Encoded memory baseline = _actual(_context(41), r, p);
        for (uint8 field; field < 10; ++field) {
            (r, p) = _fixture(37);
            if (field == 0) r.expectedCapabilities[6].checkpointSchema = _h(41, 900);
            if (field == 1) ++r.records.witnesses[1].attestations[1].nonce;
            if (field == 2) {
                r.records.authority.expectedSource[6].ownerState.recordChainTip = _h(41, 901);
            }
            if (field == 3) r.records.authority.replayOrigins[6][1].scope = _h(41, 902);
            if (field == 4) p.data[6].nonces[1].words[31] ^= 1;
            if (field == 5) {
                p.externalGuards.finality[0].record.recoveryManifest.uri = "changed:last:uri";
            }
            if (field == 6) p.timing.configurationHash = _h(41, 903);
            if (field == 7) p.before_[6].stateRoot = _h(41, 904);
            if (field == 8) p.collections[1].policies[1].policyHash = _h(41, 905);
            if (field == 9) p.query.records[1] = _h(41, 906);
            Encoded memory e = _parity(_context(41), r, p);
            assert(e.value != baseline.value && keccak256(e.probe) != keccak256(baseline.probe));
            // The frozen profile excludes destination pre-state, unlike the commitment/probe.
            assert((keccak256(e.profileBytes) == keccak256(baseline.profileBytes)) == (field == 7));
        }
    }

    /// @dev A bounded fixture for the combined runner's 256 fuzz cases; no unbounded arrays.
    function testFuzzFrozenPrepareAndEvidenceParity(uint256 seed, uint16 payloadLength)
        public
        pure
    {
        seed %= 1_000_000_000_000;
        (RH.Request memory r, Encoding.Inputs memory p) = _fixture(seed);
        p.data[6].typedState = _bytes(seed + 17, uint256(payloadLength) % 257);
        Context memory c = _context(seed + 23);
        Encoded memory e = _parity(c, r, p);
        _evidenceParity(c, e, p.before_, _after(p.before_));
    }

    function testExecuteRejectsZeroActorAndConfigurationBeforeEncoding() public {
        _guardRejected(bytes32(uint256(1)), address(0));
        _guardRejected(bytes32(0), address(0x1234));
        _guardRejected(bytes32(0), address(0));
    }

    function executeGuard(bytes32 configurationHash, address actor) external returns (bytes32) {
        T.SuiteConfiguration memory destination;
        RH.Request memory request;
        Commit.Prepared memory prepared;
        return Commit.execute(destination, configurationHash, actor, request, prepared);
    }

    function _guardRejected(bytes32 configurationHash, address actor) private {
        (bool ok, bytes memory result) =
            address(this).call(abi.encodeCall(this.executeGuard, (configurationHash, actor)));
        assert(
            !ok && keccak256(result) == keccak256(abi.encodeWithSelector(T.InvalidBinding.selector))
        );
    }

    function _parity(Context memory c, RH.Request memory r, Encoding.Inputs memory p)
        private
        pure
        returns (Encoded memory actual)
    {
        actual = _actual(c, r, p);
        Encoded memory expected = _frozen(c, r, p);
        assert(keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)));
    }

    function _actual(Context memory c, RH.Request memory r, Encoding.Inputs memory p)
        private
        pure
        returns (Encoded memory e)
    {
        (e.value, e.profileBytes, e.descriptor, e.carrier, e.probe) = Encoding.prepare(
            c.chainId, c.registry, c.coordinator, c.configurationHash, c.actor, r, p
        );
    }

    // Frozen original Commit.execute preimages. Constants are literal, not imported from the
    // worker; the page oracle hashes raw ranges independently of Evidence.describe/_page.
    function _frozen(Context memory c, RH.Request memory r, Encoding.Inputs memory p)
        private
        pure
        returns (Encoded memory e)
    {
        e.value = keccak256(
            abi.encode(
                PROFILE,
                uint16(1),
                c.chainId,
                c.registry,
                c.coordinator,
                p.prior,
                p.sourceCoordinator,
                r,
                p.artists,
                p.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.before_
            )
        );
        e.profileBytes = abi.encode(
            PROFILE,
            uint16(1),
            p.prior,
            p.sourceCoordinator,
            r,
            p.artists,
            p.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
        e.descriptor = _frozenDescriptor(e.profileBytes);
        e.carrier = abi.encode(PROFILE, e.descriptor);
        e.probe = abi.encode(
            uint16(1),
            c.configurationHash,
            uint16(60),
            c.actor,
            e.value,
            p.before_,
            p.before_,
            e.carrier
        );
    }

    function _frozenDescriptor(bytes memory raw)
        private
        pure
        returns (Evidence.Descriptor memory d)
    {
        assert(raw.length > 0 && raw.length <= PAGE_BYTES * 128);
        d.schema = PAGE_SCHEMA;
        d.payloadHash = keccak256(raw);
        d.payloadLength = raw.length;
        d.pageHashes = new bytes32[]((raw.length + PAGE_BYTES - 1) / PAGE_BYTES);
        for (uint256 page; page < d.pageHashes.length; ++page) {
            uint256 start = page * PAGE_BYTES;
            uint256 length = raw.length - start;
            if (length > PAGE_BYTES) length = PAGE_BYTES;
            bytes32 hash;
            assembly ("memory-safe") { hash := keccak256(add(add(raw, 32), start), length) }
            d.pageHashes[page] = hash;
        }
    }

    function _evidenceParity(
        Context memory c,
        Encoded memory e,
        T.Snapshot[7] memory before_,
        T.Snapshot[7] memory after_
    ) private pure returns (bytes32 id, bytes memory raw) {
        (id, raw) = Encoding.evidence(
            c.chainId,
            c.registry,
            c.coordinator,
            c.configurationHash,
            c.actor,
            e.value,
            before_,
            after_,
            e.carrier
        );
        bytes32 expectedId = keccak256(
            abi.encode(
                OPERATION_DOMAIN, c.chainId, c.registry, c.coordinator, uint16(60), c.actor, e.value
            )
        );
        bytes memory expected = abi.encode(
            uint16(1), c.configurationHash, uint16(60), c.actor, e.value, before_, after_, e.carrier
        );
        assert(id == expectedId && keccak256(raw) == keccak256(expected));
    }

    function _context(uint256 seed) private pure returns (Context memory c) {
        c = Context(seed + 1, _a(seed, 2), _a(seed, 3), _h(seed, 4), _a(seed, 5));
    }

    function _changedContext(uint256 seed, uint8 field) private pure returns (Context memory c) {
        c = _context(seed);
        if (field == 0) ++c.chainId;
        if (field == 1) c.registry = _a(seed, 102);
        if (field == 2) c.coordinator = _a(seed, 103);
        if (field == 3) c.configurationHash = _h(seed, 104);
        if (field == 4) c.actor = _a(seed, 105);
    }

    function _after(T.Snapshot[7] memory before_)
        private
        pure
        returns (T.Snapshot[7] memory result)
    {
        for (uint256 i; i < 7; ++i) {
            result[i] = T.Snapshot(
                before_[i].domainId,
                before_[i].revision + 1,
                keccak256(abi.encode("after", i, before_[i].stateRoot)),
                before_[i].recordChainTip
            );
        }
    }

    function _fixture(uint256 seed)
        private
        pure
        returns (RH.Request memory r, Encoding.Inputs memory p)
    {
        r.expectedSourceImportCommitment = _h(seed, 1);
        r.expectedSemanticInventory = _h(seed, 2);
        r.records.authority.bindingIndex = seed + 3;
        r.records.authority.artistIds = new bytes32[](2);
        r.records.authority.collections = new MH.Collection[](2);
        r.records.witnesses = new MR.CollectionWitness[](2);
        p.prior = _a(seed, 4);
        p.sourceCoordinator = _a(seed, 5);
        p.artists = new AH.Query[](2);
        p.collections = new AH.Query[](2);
        p.query = _query(seed + 100);
        p.timing = TM.Checkpoint(_h(seed, 6), 7, seed + 8, _h(seed, 9), _h(seed, 10));
        p.externalGuards = _external(seed + 200);
        for (uint256 i; i < 2; ++i) {
            uint256 s = seed + 300 + i * 100;
            r.records.authority.artistIds[i] = _h(s, 1);
            r.records.authority.collections[i] = MH.Collection(_h(s, 2), s + 3, _policies(s + 10));
            r.records.witnesses[i] = _witness(s + 20);
            p.artists[i] = _query(s + 40);
            p.collections[i] = _query(s + 60);
        }
        for (uint256 i; i < 7; ++i) {
            uint256 s = seed + 1_000 + i * 1_000;
            r.expectedCapabilities[i] = RH.Capability(
                _h(s, 1), uint16(i + 2), uint8(i), _h(s, 3), _h(s, 4), _h(s, 5), s + 6
            );
            r.records.authority.expectedSource[i] =
                CP.Checkpoint(_h(s, 7), _snapshot(s + 10), _h(s, 15), s + 16, _h(s, 17), s + 18);
            r.records.authority.replayOrigins[i] = _origins(s + 20);
            p.before_[i] = _snapshot(s + 30);
            p.data[i] = _ownerData(s + 40);
        }
    }

    function _query(uint256 seed) private pure returns (AH.Query memory q) {
        q.artistId = _h(seed, 1);
        q.collectionId = seed + 2;
        q.bindingHash = _h(seed, 3);
        q.policies = _policies(seed + 10);
        q.records = new bytes32[](2);
        q.records[0] = _h(seed, 4);
        q.records[1] = _h(seed, 5);
    }

    function _policies(uint256 seed) private pure returns (AH.PolicyKey[] memory rows) {
        rows = new AH.PolicyKey[](2);
        rows[0] = AH.PolicyKey(_h(seed, 1), _h(seed, 2));
        rows[1] = AH.PolicyKey(_h(seed, 3), _h(seed, 4));
    }

    function _origins(uint256 seed) private pure returns (AH.Origin[] memory rows) {
        rows = new AH.Origin[](2);
        rows[0] = AH.Origin(_h(seed, 1), _h(seed, 2));
        rows[1] = AH.Origin(_h(seed, 3), _h(seed, 4));
    }

    function _witness(uint256 seed) private pure returns (MR.CollectionWitness memory w) {
        w.collectionId = seed + 1;
        w.economics = new T.EconomicsConsent[](2);
        w.attestations = new Readiness.AttestationInput[](2);
        for (uint256 i; i < 2; ++i) {
            uint256 s = seed + 10 + i * 20;
            w.economics[i] =
                T.EconomicsConsent(s + 1, _a(s, 2), _h(s, 3), uint8(i + 1), s + 4, _h(s, 5));
            w.attestations[i] = Readiness.AttestationInput(
                T.Attestation(
                    s + 6, uint8(i + 2), _h(s, 7), _h(s, 8), _h(s, 9), _h(s, 10), _uri(s)
                ),
                s + 11
            );
        }
    }

    function _ownerData(uint256 seed) private pure returns (AH.OwnerData memory d) {
        d.typedState = _bytes(seed, 65);
        d.origins = _origins(seed + 10);
        d.sourceKeys = new bytes32[](2);
        d.cells = new T.ReplayCell[](2);
        d.nonces = new AH.NonceWord[](2);
        for (uint256 i; i < 2; ++i) {
            uint256 s = seed + 20 + i * 40;
            d.sourceKeys[i] = _h(s, 1);
            d.cells[i] = T.ReplayCell(_h(s, 2), uint64(s + 3), uint8(i + 1), uint8(i + 2));
            d.nonces[i].prefix = s + 4;
            d.nonces[i].exhausted = i != 0;
            for (uint256 word; word < 32; ++word) {
                d.nonces[i].words[word] = uint256(_h(s, 10 + word));
            }
        }
    }

    function _external(uint256 seed) private pure returns (External.Snapshot memory s) {
        s.schema = _h(seed, 1);
        s.provenanceCommitment = _h(seed, 2);
        s.artistId = _h(seed, 3);
        s.actions = new External.ActionGuard[](1);
        s.actions[0].associationHash = _h(seed, 4);
        s.actions[0].origin = RH.Point(_h(seed, 5), 2, uint64(seed + 6));
        s.actions[0].witness = Action.Witness(
            _h(seed, 7),
            _h(seed, 8),
            seed + 9,
            _h(seed, 10),
            _a(seed, 11),
            _h(seed, 12),
            _a(seed, 13),
            _h(seed, 14),
            uint64(seed + 15),
            uint64(seed + 16),
            uint64(seed + 17),
            uint64(seed + 18),
            _h(seed, 19)
        );
        s.actions[0].facts = _facts(seed + 20);
        s.finality = new External.FinalityGuard[](1);
        s.finality[0] = _finality(seed + 30);
        s.entropy = new External.EntropyGuard[](1);
        s.entropy[0] = _entropy(seed + 130);
    }

    function _finality(uint256 seed) private pure returns (External.FinalityGuard memory f) {
        f.findingRecordHash = _h(seed, 1);
        f.origin = RH.Position(RH.Point(_h(seed, 2), 2, uint64(seed + 3)), seed + 4);
        f.core = _a(seed, 5);
        f.target.recoveryRegistry = _a(seed, 6);
        f.target.recoveryActionId = _h(seed, 7);
        f.target.scope = _scope(seed + 10);
        f.target.originalFinalityRecordHash = _h(seed, 8);
        f.target.recoveryManifestHash = _h(seed, 9);
        f.registryCodeHash = _h(seed, 15);
        f.executor = _a(seed, 16);
        f.executorCodeHash = _h(seed, 17);
        f.action = _facts(seed + 20);
        f.actionTerminal = true;
        f.record.executed = true;
        f.record.recoveryId = _h(seed, 25);
        f.record.scope = _scope(seed + 30);
        f.record.originalFinalityRecordHash = _h(seed, 26);
        f.record.predecessorRecoveryId = _h(seed, 27);
        f.record.generation = uint64(seed + 28);
        f.record.oldRouteHash = _h(seed, 35);
        f.record.recoveryRouteHash = _h(seed, 36);
        f.record.artworkBytesChanged = true;
        f.record.replacementRoute = StreamFinalityComponentExpectation(
            _h(seed, 37),
            _a(seed, 38),
            bytes4(_h(seed, 39)),
            _h(seed, 40),
            _h(seed, 41),
            _h(seed, 42),
            _h(seed, 43)
        );
        f.record.recoveryManifest = StreamFinalityManifestRef(
            _uri(seed + 44), _h(seed, 45), _h(seed, 46), _h(seed, 47), _h(seed, 48)
        );
        f.record.evidence = StreamFinalityRecoveryEvidenceSnapshot(
            StreamFinalityRecoveryArtistEvidenceKind.UNAVAILABILITY,
            _h(seed, 49),
            _a(seed, 50),
            _h(seed, 51),
            3,
            uint64(seed + 52),
            _h(seed, 53),
            uint64(seed + 54),
            uint64(seed + 55),
            56,
            57
        );
        f.record.reasonHash = _h(seed, 58);
        f.record.reasonURI = _uri(seed + 59);
        f.record.executedAt = uint64(seed + 60);
    }

    function _entropy(uint256 seed) private pure returns (External.EntropyGuard memory e) {
        e.findingRecordHash = _h(seed, 1);
        e.origin = RH.Position(RH.Point(_h(seed, 2), 2, uint64(seed + 3)), seed + 4);
        e.core = _a(seed, 5);
        e.coordinator = _a(seed, 6);
        e.coordinatorCodeHash = _h(seed, 7);
        e.oldRequestKey = _h(seed, 8);
        e.newRequestKey = _h(seed, 9);
        e.terminal = true;
        e.receipt.previousRequestKey = _h(seed, 10);
        e.receipt.artistRecordHash = _h(seed, 11);
        e.receipt.providerEvidenceHash = _h(seed, 12);
        e.receipt.incidentEvidenceHash = _h(seed, 13);
        e.receipt.evidenceHash = _h(seed, 14);
        e.receipt.contentStateHash = _h(seed, 15);
        e.receipt.journalHead = _h(seed, 16);
        e.receipt.requestedAtBlock = uint64(seed + 17);
        e.receipt.acceptLateOriginalFulfillment = true;
        e.evidence = External.EntropyEvidence(_h(seed, 18), _h(seed, 19), uint64(seed + 20));
    }

    function _facts(uint256 seed) private pure returns (Governance.ActionFacts memory) {
        return Governance.ActionFacts(
            GovernanceActionStatus.EXECUTED, 2, _h(seed, 1), uint64(seed + 2), uint64(seed + 3)
        );
    }

    function _scope(uint256 seed) private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.RELEASE, seed + 1, seed + 2, _h(seed, 3));
    }

    function _snapshot(uint256 seed) private pure returns (T.Snapshot memory) {
        return T.Snapshot(_h(seed, 1), uint64(seed + 2), _h(seed, 3), _h(seed, 4));
    }

    function _h(uint256 seed, uint256 tag) private pure returns (bytes32) {
        return keccak256(abi.encode("frozen Commit encoding sentinel", seed, tag));
    }

    function _a(uint256 seed, uint256 tag) private pure returns (address) {
        return address(uint160(seed + tag + 1));
    }

    function _uri(uint256 seed) private pure returns (string memory) {
        return string(abi.encodePacked("ipfs://distinct/", _h(seed, 999)));
    }

    function _bytes(uint256 seed, uint256 length) private pure returns (bytes memory raw) {
        raw = new bytes(length);
        for (uint256 offset; offset < length; offset += 32) {
            bytes32 word = _h(seed, offset);
            assembly ("memory-safe") { mstore(add(add(raw, 32), offset), word) }
        }
    }
}
