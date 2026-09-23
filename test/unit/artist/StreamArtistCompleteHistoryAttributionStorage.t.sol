// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryAttributionRecords as Records
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAttributionRecords.sol";
import {
    StreamArtistCompleteHistoryDisputeStorage as Disputes
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryDisputeStorage.sol";
import {
    StreamArtistRecoveredPlatformWrites as Platform
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformWrites.sol";
import {
    StreamArtistRecoveredPlatformTypes as P
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRepudiationState as Repudiations
} from "../../../smart-contracts/domains/artist/StreamArtistRepudiationState.sol";
import {
    StreamArtistAttributionStateTypes as AS
} from "../../../smart-contracts/domains/artist/StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistC2PACredentials as Credentials
} from "../../../smart-contracts/domains/artist/StreamArtistC2PACredentials.sol";
import {
    StreamArtistPersonhoodSummary as Summary
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodSummary.sol";
import {
    StreamArtistPayloadStore as Payloads
} from "../../../smart-contracts/domains/artist/StreamArtistPayloadStore.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistC2PATypes as C2PA
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistPublicationHydrationTypes as Pub
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

interface CompleteHistoryAttributionStorageVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function expectRevert(bytes4) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract CompleteHistoryAttributionStorageGas {
    function gasParameterInfo(bytes32) external pure returns (uint256, uint256, uint8, uint64) {
        return (1_000_000, 1, 2, 1);
    }
}

/// @dev Deliberate storage boundary harness. It does not emulate source admission, signatures
/// or op60. Its preinstalled marker permits the original personhood derived-map leaf only.
contract CompleteHistoryAttributionStorageHarness {
    AS.State private state;
    address public immutable artistRegistry;
    address public immutable operationCoordinator;
    address public constant core = address(0xC0);

    constructor(address registry) {
        artistRegistry = registry;
        operationCoordinator = msg.sender;
        bytes32 slot = keccak256("6529STREAM_ARTIST_AUTHORITY_HYDRATION_STORAGE_V1");
        assembly ("memory-safe") { sstore(slot, 1) }
    }

    function applyFamilies(Records.Context memory c, D.Bundle[] memory histories) external {
        Disputes.check(histories);
        Records.check(state, c);
        for (uint256 k; k < c.inventory.platforms.length; ++k) {
            Platform.requireEmpty(state, c.inventory.platforms[k]);
        }
        Disputes.install(histories);
        for (uint256 k; k < c.inventory.platforms.length; ++k) {
            Platform.applyState(state, c.inventory.platforms[k]);
        }
        Records.install(state, c);
    }

    function dirtyPersonhood(uint256 id, bytes32 artist, bytes32 record) external {
        Credentials.state().personhood[keccak256(abi.encode(id, artist))] = record;
    }

    function dirtyCredential(bytes32 artist, bytes32 record) external {
        Credentials.state().latest[artist] = record;
    }

    function dirtyCohort(bytes32 artist, bytes32 cohort) external {
        Repudiations.state().counts[artist][cohort] = 1;
    }

    function dirtyPlatform(uint256 id) external {
        state.latestDisplayClaim[id] = bytes32(uint256(1));
    }

    function head(bytes32 artist) external view returns (C2PA.Head memory) {
        return Credentials.head(artist);
    }

    function personhood(uint256 id, bytes32 artist) external view returns (bytes32) {
        return Credentials.personhoodKey(id, artist);
    }

    function summaryOrigin(bytes32 hash) external view returns (address) {
        return Summary.origin(hash);
    }

    function cohort(bytes32 artist, bytes32 hash) external view returns (uint256) {
        return Repudiations.state().counts[artist][hash];
    }

    function pending(uint256 id) external view returns (bytes32) {
        return Repudiations.state().pending[id];
    }

    function record(bytes32 hash) external view returns (T.AttestationRecord memory) {
        return state.records[hash];
    }

    function item(uint256 id) external view returns (AS.Attribution memory) {
        return state.attributions[id];
    }

    function statement(bytes32 hash) external view returns (bytes memory) {
        return state.statements[hash];
    }

    function payloadCount() external view returns (uint256) {
        return Payloads.count();
    }

    function payloadAt(uint256 i) external view returns (address, bytes32, bytes32) {
        return Payloads.at(i);
    }

    function allegationCount(uint256 id) external view returns (uint256) {
        return state.attributionClaims.counts[id];
    }
}

/// @notice Synthetic storage vectors exercise original map workers, not a full import proof.
contract StreamArtistCompleteHistoryAttributionStorageTest {
    CompleteHistoryAttributionStorageVm private constant vm = CompleteHistoryAttributionStorageVm(
        address(uint160(uint256(keccak256("hevm cheat code"))))
    );
    bytes32 private constant FIRST = bytes32(uint256(101));
    bytes32 private constant SECOND = bytes32(uint256(102));
    bytes32 private constant SCHEMA = keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");
    bytes32 private constant WAIVER = keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1");
    T.SuiteConfiguration private suite;

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }

    function testCompleteStorageKeepsGlobalCredentialOrderAndFormerArtistPersonhood() external {
        Records.Context memory c = _fixture();
        CompleteHistoryAttributionStorageHarness target = _target();
        vm.recordLogs();
        target.applyFamilies(c, _histories());
        C2PA.Head memory head = target.head(FIRST);
        require(
            head.recordHash == bytes32(uint256(302))
                && head.previousRecordHash == bytes32(uint256(201)),
            "global order"
        );
        require(
            head.revision == 3 && head.artistId == FIRST && head.collectionId == 30
                && head.generation == 1,
            "original principal generation"
        );
        require(
            head.bindingHash == bytes32(uint256(301)) && head.sourceRegistry == address(1),
            "original domain"
        );
        require(target.head(SECOND).recordHash == 0, "invented replacement credential");
        require(
            target.personhood(20, FIRST) == bytes32(uint256(202))
                && target.personhood(20, SECOND) == 0,
            "historical personhood"
        );
        require(
            target.summaryOrigin(bytes32(uint256(202))) == address(1),
            "personhood original registry"
        );
        require(
            target.item(20).state == 1 && target.item(20).generation == 2
                && target.item(10).generation == 0,
            "pending and unbound preserved"
        );
        require(target.allegationCount(10) == 1, "unbound Platform retained");
        require(
            target.record(bytes32(uint256(201))).statementHash
                == c.all[1].records[0].attestation.record.statementHash,
            "original record"
        );
        require(
            keccak256(target.statement(c.all[1].records[0].attestation.record.statementHash))
                == keccak256(c.all[1].records[0].attestation.statement),
            "statement retained"
        );
        require(target.payloadCount() == 4, "original artifact catalog");
        for (uint256 i; i < 4; ++i) {
            (address pointer, bytes32 kind, bytes32 hash) = target.payloadAt(i);
            require(
                pointer.code.length != 0 && kind == keccak256("ARTIST_PUBLICATION_STATEMENT")
                    && hash != 0,
                "artifact pointer"
            );
        }
        CompleteHistoryAttributionStorageVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 4, "unexpected native or credential event");
        for (uint256 i; i < logs.length; ++i) {
            require(
                logs[i].topics[0]
                    == keccak256("ArtistStoredPayload(uint16,uint256,bytes32,bytes32,address)"),
                "fabricated native event"
            );
        }
    }

    function testCompleteStorageFormerArtistCredentialCollisionRejectsBeforeAnyFamilyWrites()
        external
    {
        Records.Context memory c = _fixture();
        CompleteHistoryAttributionStorageHarness target = _target();
        target.dirtyCredential(FIRST, bytes32(uint256(999)));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applyFamilies(c, _histories());
        _requireUnwritten(target);
    }

    function testCompleteStorageFormerArtistPersonhoodCollisionRejects() external {
        Records.Context memory c = _fixture();
        CompleteHistoryAttributionStorageHarness target = _target();
        target.dirtyPersonhood(20, FIRST, bytes32(uint256(999)));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applyFamilies(c, _histories());
        _requireUnwritten(target);
    }

    function testCompleteStorageLatestPendingArtistEmptyPersonhoodTargetIsStillChecked() external {
        Records.Context memory c = _fixture();
        CompleteHistoryAttributionStorageHarness target = _target();
        target.dirtyPersonhood(20, SECOND, bytes32(uint256(999)));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applyFamilies(c, _histories());
        _requireUnwritten(target);
    }

    function testCompleteStorageLastPlatformTargetCheckedBeforeDisputesOrRecords() external {
        Records.Context memory c = _fixture();
        CompleteHistoryAttributionStorageHarness target = _target();
        target.dirtyPlatform(30);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applyFamilies(c, _histories());
        _requireUnwritten(target);
    }

    function testCompleteStorageRepudiationSharedCohortUsesOriginalArtistAcrossCollections()
        external
    {
        Records.Context memory c = _fixture();
        D.Bundle[] memory histories = _histories();
        CompleteHistoryAttributionStorageHarness target = _target();
        target.applyFamilies(c, histories);
        bytes32 cohort = keccak256(abi.encode(histories[1].repudiations[0].record.authorityHead));
        require(
            target.cohort(FIRST, cohort) == 2 && target.cohort(SECOND, cohort) == 0,
            "cohort relabeled"
        );
        require(
            target.pending(20) == histories[1].pending
                && target.pending(30) == histories[2].pending,
            "pending records"
        );
    }

    function testCompleteStorageOccupiedHistoricalCohortRejectsWholeBatch() external {
        Records.Context memory c = _fixture();
        D.Bundle[] memory histories = _histories();
        CompleteHistoryAttributionStorageHarness target = _target();
        target.dirtyCohort(
            FIRST, keccak256(abi.encode(histories[1].repudiations[0].record.authorityHead))
        );
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        target.applyFamilies(c, histories);
        _requireUnwritten(target);
    }

    function _target() private returns (CompleteHistoryAttributionStorageHarness target) {
        address registry = address(new CompleteHistoryAttributionStorageGas());
        target = new CompleteHistoryAttributionStorageHarness(registry);
        suite.registry = registry;
        suite.core = address(0xC0);
        suite.owners[4] = address(target);
    }

    function _requireUnwritten(CompleteHistoryAttributionStorageHarness target) private view {
        require(
            target.item(20).generation == 0 && target.pending(20) == 0, "partial family install"
        );
        require(
            target.record(bytes32(uint256(201))).recordHash == 0 && target.payloadCount() == 0,
            "partial record install"
        );
        require(target.allegationCount(10) == 0, "partial Platform install");
    }

    function _fixture() private pure returns (Records.Context memory c) {
        c.scope.artists = new AH.Query[](2);
        c.scope.artists[0].artistId = FIRST;
        c.scope.artists[1].artistId = SECOND;
        c.scope.collections = new AH.Query[](3);
        c.all = new Original.Bundle[](3);
        c.inventory.bindings.bindings = new CB.Bundle[](3);
        c.inventory.platforms = new P.Platform[](3);
        for (uint256 k; k < 3; ++k) {
            uint256 count = k == 0 ? 0 : k == 1 ? 2 : 1;
            uint256 id = (k + 1) * 10;
            c.scope.collections[k].collectionId = id;
            c.scope.collections[k].artistId = k == 0 ? bytes32(0) : k == 1 ? SECOND : FIRST;
            c.inventory.bindings.bindings[k].bindings.rows = new G.Row[](count);
            c.inventory.platforms[k].collectionId = id;
            for (uint256 g; g < count; ++g) {
                T.Binding memory b;
                b.artistId = g == 0 ? FIRST : SECOND;
                b.generation = uint64(g + 1);
                b.bindingHash = bytes32(id * 10 + g + 1);
                b.accepted = g == 0;
                c.inventory.bindings.bindings[k].bindings.rows[g].item = b;
            }
            c.all[k].collectionId = id;
            c.all[k].artistId = c.scope.collections[k].artistId;
            c.all[k].item = AS.Attribution(k == 0 ? 0 : k == 1 ? 1 : 2, uint64(count));
            c.all[k].records = new Pub.Row[](k == 0 ? 0 : 2);
        }
        c.all[2].records[0] = _credential(30, 301, 0);
        c.all[1].records[0] = _credential(20, 201, 301);
        c.all[1].records[1] = _waiver();
        c.all[2].records[1] = _credential(30, 302, 201);
        c.all[1].personhood = new Original.PersonhoodRow[](1);
        c.all[1].personhood[0].recordHash = bytes32(uint256(202));
        c.all[1].personhood[0].originalRegistry = address(1);
        c.inventory.provenance.origins = new RH.OriginEnvironment[](1);
        c.inventory.provenance.origins[0].registry = address(1);
        c.inventory.provenance.eras = new RH.Era[](1);
        bytes32 origin = RH.originHash(c.inventory.provenance.origins[0]);
        c.inventory.provenance.eras[0].originHash = origin;
        RH.JournalEntry[] memory journal = new RH.JournalEntry[](6);
        journal[0].receipt = H.Receipt(10, 0, 10, bytes32(uint256(100)));
        journal[1].receipt = H.Receipt(24, FIRST, 30, bytes32(uint256(301)));
        journal[2].receipt = H.Receipt(24, FIRST, 20, bytes32(uint256(201)));
        journal[3].receipt = H.Receipt(24, FIRST, 20, bytes32(uint256(202)));
        journal[4].receipt = H.Receipt(44, FIRST, 20, bytes32(uint256(200)));
        journal[5].receipt = H.Receipt(24, FIRST, 30, bytes32(uint256(302)));
        for (uint256 i; i < journal.length; ++i) {
            journal[i].position.point = RH.Point(origin, 4, uint64(i + 1));
        }
        c.inventory.provenance.journals[4] = journal;
        c.inventory.platforms[0].allegations = new P.AttributionClaimRow[](1);
        c.inventory.platforms[0].allegations[0].record.collectionId = 10;
        c.inventory.platforms[0].allegations[0].record.recordHash = bytes32(uint256(100));
        c.inventory.platforms[0].allegationCount = 1;
        c.inventory.platforms[0].latestAllegation = bytes32(uint256(100));
        c.inventory.platforms[0].latestDisplayClaim = bytes32(uint256(100));
    }

    function _credential(uint256 id, uint256 record, uint256 previous)
        private
        pure
        returns (Pub.Row memory r)
    {
        r.attestation.statement = abi.encode(
            C2PA.Payload(
                1, FIRST, bytes32(uint256(501)), bytes32(previous), new C2PA.Credential[](0)
            )
        );
        r.attestation.input.terms = T.Attestation(
            id,
            10,
            FIRST,
            bytes32(uint256(501)),
            SCHEMA,
            keccak256(r.attestation.statement),
            "urn:original:credential"
        );
        r.attestation.record.recordHash = bytes32(record);
        r.attestation.record.generation = 1;
        r.attestation.record.schemaId = SCHEMA;
        r.attestation.record.subjectStateHash = bytes32(uint256(501));
        r.attestation.record.statementHash = keccak256(r.attestation.statement);
        r.attestation.authorityClass = 1;
    }

    function _waiver() private pure returns (Pub.Row memory r) {
        r.attestation.statement = bytes("original explicit waiver");
        r.attestation.input.terms = T.Attestation(
            20,
            10,
            FIRST,
            bytes32(uint256(501)),
            WAIVER,
            keccak256(r.attestation.statement),
            "urn:original:waiver"
        );
        r.attestation.record.recordHash = bytes32(uint256(202));
        r.attestation.record.generation = 1;
        r.attestation.record.schemaId = WAIVER;
        r.attestation.record.subjectStateHash = bytes32(uint256(501));
        r.attestation.record.statementHash = keccak256(r.attestation.statement);
        r.attestation.authorityClass = 1;
    }

    function _histories() private pure returns (D.Bundle[] memory histories) {
        histories = new D.Bundle[](3);
        for (uint256 k; k < 3; ++k) {
            histories[k].collectionId = (k + 1) * 10;
            if (k == 0) continue;
            histories[k].artistId = k == 1 ? SECOND : FIRST;
            histories[k].repudiations = new D.RepudiationRow[](1);
            histories[k].repudiations[0].record.recordHash = bytes32(uint256(800 + k));
            histories[k].repudiations[0].record.artistId = FIRST;
            histories[k].repudiations[0].record.authorityHead.principal = address(0xA11);
            histories[k].repudiations[0].terminal.phase = 1;
            histories[k].pending = histories[k].repudiations[0].record.recordHash;
        }
    }
}
