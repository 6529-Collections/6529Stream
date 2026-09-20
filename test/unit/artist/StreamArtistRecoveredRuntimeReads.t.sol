// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredRuntimeReads as Reads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationGuards as Keys
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

interface RecoveredRuntimeVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata output) external;
}

contract RecoveredRuntimeBoundary { }

contract RecoveredRuntimeHarness {
    function load(W.EnvironmentV3 memory e, uint8 index)
        external
        view
        returns (Reads.Context memory)
    {
        return Reads.load(e, index);
    }

    function receipt(Reads.Context memory c, uint256 index)
        external
        view
        returns (Reads.ReceiptFact memory)
    {
        return Reads.receiptAt(c, index);
    }

    function auxiliary(Reads.Context memory c, bytes32 kind, bytes32 key)
        external
        view
        returns (Reads.OriginFact memory)
    {
        return Reads.auxiliary(c, kind, key);
    }

    function replay(Reads.Context memory c, bytes32 origin, bytes32 surface, bytes32 scope)
        external
        view
        returns (Reads.ReplayFact memory)
    {
        return Reads.replay(c, origin, surface, scope);
    }

    function before(Reads.Context memory c, RH.Point memory a, RH.Point memory b)
        external
        pure
        returns (bool)
    {
        return Reads.before(c, a, b);
    }
}

/// @notice Focused provenance-reader controls at an explicitly mocked fixed-owner boundary.
/// @dev These tests do not claim original Artist, Safe, source-certificate, or op60 admission.
/// StateGuards and History56 hosts separately exercise original replay and history mutations.
contract StreamArtistRecoveredRuntimeReadsTest {
    RecoveredRuntimeVm internal constant vm =
        RecoveredRuntimeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 internal constant ARTIST = bytes32(uint256(111));
    bytes32 internal constant IMPORT = keccak256("runtime imported prefix");
    bytes32 internal constant SURFACE = keccak256("payout_lifecycle.replay.recovery_rewind");
    bytes32 internal constant SCOPE = keccak256("actual typed recovery scope fixture");
    bytes32 internal constant AUX = keccak256("payout_lifecycle.hydration.continuation_v3");
    RecoveredRuntimeHarness internal harness;
    T.SuiteConfiguration internal suite;
    W.EnvironmentV3 internal e;

    function setUp() public {
        harness = new RecoveredRuntimeHarness();
        suite.registry = address(new RecoveredRuntimeBoundary());
        suite.archive = address(new RecoveredRuntimeBoundary());
        suite.core = address(new RecoveredRuntimeBoundary());
        suite.mintManager = address(new RecoveredRuntimeBoundary());
        for (uint256 i; i < 7; ++i) {
            suite.owners[i] = address(new RecoveredRuntimeBoundary());
        }
        address coordinator = address(new RecoveredRuntimeBoundary());
        e = W.EnvironmentV3(
            block.chainid,
            suite.registry,
            suite.owners[2],
            suite.owners[2].codehash,
            suite.owners[5],
            suite.owners[5].codehash,
            coordinator,
            suite.archive,
            suite.core,
            suite.mintManager
        );
        vm.mockCall(coordinator, abi.encodeWithSignature("suiteConfiguration()"), abi.encode(suite));
        vm.mockCall(
            coordinator, abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid)
        );
    }

    function testRecoveredRuntimeSeparatesOriginalAndCurrent18Occurrences() public {
        RH.OwnerProvenance memory old = _fixture(5);
        Reads.Context memory c = harness.load(e, 5);
        require(Reads.logicalCount(c) == 3, "complete imported prefix plus actual native suffix");
        Reads.ReceiptFact memory first = harness.receipt(c, 1);
        Reads.ReceiptFact memory latest = harness.receipt(c, 2);
        require(
            first.position.point.environmentHash == old.eras[0].originHash
                && first.position.nativeIndex == 1,
            "original occurrence retained"
        );
        require(
            latest.position.point.environmentHash == RH.originHash(c.current)
                && latest.position.nativeIndex == 0 && latest.logicalIndex == 2,
            "current local index is not logical index"
        );
        require(
            first.environment.registry != latest.environment.registry,
            "original hash domains remain distinct"
        );
        require(
            harness.before(c, first.position.point, latest.position.point),
            "old raw50 precedes current raw2"
        );
    }

    function testRecoveredRuntimeRetainsEveryRepeatedSecondary35Occurrence() public {
        _fixture(2);
        Reads.Context memory c = harness.load(e, 2);
        Reads.ReceiptFact memory first = harness.receipt(c, 0);
        Reads.ReceiptFact memory second = harness.receipt(c, 1);
        require(
            first.receipt.recordHash == second.receipt.recordHash && first.receipt.operation == 35,
            "intentional duplicate content hash"
        );
        require(
            first.position.nativeIndex == 0 && second.position.nativeIndex == 1,
            "no semantic hash deduplication"
        );
    }

    function testRecoveredRuntimeMissingAuxiliaryNeverFallsBackToCurrentOwner() public {
        _fixture(5);
        Reads.Context memory c = harness.load(e, 5);
        bytes memory expected =
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
        vm.mockCallRevert(
            e.payoutOwner,
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)", AUX, SCOPE
            ),
            expected
        );
        _reject(abi.encodeCall(harness.auxiliary, (c, AUX, SCOPE)), expected);
    }

    function testRecoveredRuntimeAuxiliaryNeedsExactPositiveOwnerAndEraPoint() public {
        RH.OwnerProvenance memory old = _fixture(5);
        Reads.Context memory c = harness.load(e, 5);
        RH.Point memory point = RH.Point(old.eras[0].originHash, 5, 90);
        _aux(point);
        require(
            harness.auxiliary(c, AUX, SCOPE).environment.registry == old.origins[0].registry,
            "original auxiliary domain"
        );
        point = RH.Point(RH.originHash(c.current), 5, 4);
        _aux(point);
        require(
            harness.auxiliary(c, AUX, SCOPE).point.ownerRevision == 4, "positive local typed point"
        );
        point.ownerIndex = 2;
        _aux(point);
        _reject(abi.encodeCall(harness.auxiliary, (c, AUX, SCOPE)), _pointError(point));
        point = RH.Point(bytes32(uint256(999)), 5, 4);
        _aux(point);
        _reject(abi.encodeCall(harness.auxiliary, (c, AUX, SCOPE)), _pointError(point));
        point = RH.Point(old.eras[0].originHash, 5, 91);
        _aux(point);
        _reject(abi.encodeCall(harness.auxiliary, (c, AUX, SCOPE)), _pointError(point));
    }

    function testRecoveredRuntimeHistoricalAliasAndProjectedCurrentCellKeepHighOriginalRevision()
        public
    {
        RH.OwnerProvenance memory old = _fixture(5);
        Reads.Context memory c = harness.load(e, 5);
        Reads.ReplayFact memory original = harness.replay(c, old.eras[0].originHash, SURFACE, SCOPE);
        bytes32 currentKey = Keys.replayKey(c.current, 5, AH.Origin(SURFACE, SCOPE));
        _replay(currentKey, original.cell, original.admission.point);
        Reads.ReplayFact memory current =
            harness.replay(c, RH.originHash(c.current), SURFACE, SCOPE);
        require(
            current.originalKey != original.originalKey && current.cell.touchedRevision == 90,
            "new key preserves original cell"
        );
        require(
            current.admission.point.environmentHash == old.eras[0].originHash
                && c.checkpoint.ownerState.revision == 8,
            "no revision floor or relabeling"
        );
        RH.Point memory local = RH.Point(RH.originHash(c.current), 5, 8);
        _replay(currentKey, T.ReplayCell(bytes32(uint256(444)), 8, 1, 2), local);
        current = harness.replay(c, RH.originHash(c.current), SURFACE, SCOPE);
        require(
            current.admission.point.environmentHash == local.environmentHash
                && current.cell.touchedRevision == 8,
            "positive producer local point"
        );
        original = harness.replay(c, old.eras[0].originHash, SURFACE, SCOPE);
        require(original.cell.touchedRevision == 90, "historical alias remains immutable");
    }

    function testRecoveredRuntimeHistoricalReplayRequiresExactSavedKey() public {
        RH.OwnerProvenance memory old = _fixture(5);
        Reads.Context memory c = harness.load(e, 5);
        _reject(
            abi.encodeCall(
                harness.replay, (c, old.eras[0].originHash, SURFACE, bytes32(uint256(22)))
            ),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        bytes32 currentKey = Keys.replayKey(c.current, 5, AH.Origin(SURFACE, SCOPE));
        _replay(
            currentKey,
            T.ReplayCell(bytes32(uint256(44)), 90, 1, 2),
            RH.Point(old.eras[0].originHash, 5, 89)
        );
        _reject(
            abi.encodeCall(harness.replay, (c, RH.originHash(c.current), SURFACE, SCOPE)),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
    }

    function testRecoveredRuntimeCannotOrderDifferentSemanticOwners() public {
        RH.OwnerProvenance memory old = _fixture(5);
        Reads.Context memory c = harness.load(e, 5);
        RH.Point memory wrong = RH.Point(RH.originHash(c.current), 2, 2);
        _reject(
            abi.encodeCall(harness.before, (c, RH.Point(old.eras[0].originHash, 5, 90), wrong)),
            _pointError(wrong)
        );
    }

    function testRecoveredRuntimeReadsOnlyOwnMutableCheckpoint() public {
        _fixture(5);
        bytes memory denied =
            abi.encodeWithSignature("Error(string)", "peer mutable checkpoint forbidden");
        vm.mockCallRevert(
            e.identityOwner, abi.encodeWithSignature("ownerStateSnapshotV2()"), denied
        );
        vm.mockCallRevert(e.identityOwner, abi.encodeWithSignature("authorityCheckpoint()"), denied);
        require(harness.load(e, 5).owner == e.payoutOwner, "only immutable peer code identity");
    }

    function testRecoveredRuntimeRejectsWrongSuiteBindingOwnerAndMarker() public {
        _fixture(5);
        W.EnvironmentV3 memory wrong = e;
        wrong.identityCodeHash = bytes32(uint256(33));
        _reject(
            abi.encodeCall(harness.load, (wrong, uint8(5))),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        _reject(
            abi.encodeCall(harness.load, (e, uint8(1))),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature("authorityHydrationCommitment()"),
            abi.encode(bytes32(uint256(55)))
        );
        _reject(
            abi.encodeCall(harness.load, (e, uint8(5))),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
    }

    function testRecoveredRuntimeRejectsLocalNativeAtImportBoundaryAndStaleContext() public {
        _fixture(5);
        Reads.Context memory c = harness.load(e, 5);
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature("artistNativeReceiptRevisionAt(uint256)", uint256(0)),
            abi.encode(uint64(1))
        );
        _reject(
            abi.encodeCall(harness.receipt, (c, uint256(2))),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        CP.Checkpoint memory cp = c.checkpoint;
        cp.ownerState.revision = 9;
        _checkpoint(5, cp);
        _reject(
            abi.encodeCall(harness.receipt, (c, uint256(0))),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
    }

    function testRecoveredRuntimeFreshOwnerHasNoInventedImportedOrigin() public {
        _fixture(5);
        RH.OwnerProvenance memory empty;
        _prefix(5, empty, 0, 0);
        Reads.Context memory c = harness.load(e, 5);
        require(
            Reads.logicalCount(c) == 1 && c.imported.origins.length == 0, "genuine empty prefix"
        );
        require(
            harness.receipt(c, 0).position.point.environmentHash == RH.originHash(c.current),
            "actual current receipt"
        );
    }

    function testRecoveredRuntimeMaxImportedPrefixStillHasActualCurrentClock() public {
        RH.OwnerProvenance memory old = _fixture(5);
        RH.OwnerProvenance memory full;
        full.origins = new RH.OriginEnvironment[](16);
        full.eras = new RH.OwnerEra[](16);
        for (uint256 i; i < 16; ++i) {
            RH.OriginEnvironment memory origin =
                abi.decode(abi.encode(old.origins[0]), (RH.OriginEnvironment));
            origin.registry = address(uint160(1000 + i));
            origin.coordinator = address(uint160(2000 + i));
            bytes32 hash = RH.originHash(origin);
            full.origins[i] = origin;
            CP.Checkpoint memory cp = old.eras[0].checkpoint;
            cp.replayCount = 0;
            full.eras[i] = RH.OwnerEra(hash, cp, 0, i == 0 ? 0 : 1, i == 0 ? bytes32(0) : IMPORT);
        }
        _prefix(5, full, IMPORT, 1);
        Reads.Context memory c = harness.load(e, 5);
        require(
            harness.before(
                c,
                RH.Point(full.eras[15].originHash, 5, 90),
                RH.Point(RH.originHash(c.current), 5, 2)
            ),
            "16 retained eras plus real current era"
        );
    }

    function _fixture(uint8 ownerIndex) internal returns (RH.OwnerProvenance memory old) {
        address owner = suite.owners[ownerIndex];
        vm.mockCall(owner, abi.encodeWithSignature("artistRegistry()"), abi.encode(e.registry));
        vm.mockCall(
            owner, abi.encodeWithSignature("operationCoordinator()"), abi.encode(e.coordinator)
        );
        vm.mockCall(owner, abi.encodeWithSignature("archiveV2()"), abi.encode(e.archive));
        vm.mockCall(owner, abi.encodeWithSignature("core()"), abi.encode(e.core));
        vm.mockCall(owner, abi.encodeWithSignature("mintManager()"), abi.encode(e.manager));
        vm.mockCall(owner, abi.encodeWithSignature("deploymentChainId()"), abi.encode(e.chainId));
        vm.mockCall(
            owner, abi.encodeWithSignature("domainId()"), abi.encode(RH.ownerDomain(ownerIndex))
        );
        CP.Checkpoint memory cp = CP.Checkpoint(
            RH.CHECKPOINT,
            T.Snapshot(RH.ownerDomain(ownerIndex), 8, bytes32(uint256(1)), bytes32(uint256(2))),
            0,
            0,
            0,
            0
        );
        _checkpoint(ownerIndex, cp);
        RH.OriginEnvironment memory origin;
        origin.chainId = block.chainid;
        origin.registry = address(1000);
        origin.coordinator = address(2000);
        origin.archive = address(3000);
        origin.core = e.core;
        origin.manager = e.manager;
        origin.suiteConfigurationHash = bytes32(uint256(4000));
        for (uint8 i; i < 7; ++i) {
            origin.owners[i] = address(uint160(uint256(5000) + i));
            origin.ownerCodeHashes[i] = bytes32(uint256(uint256(6000) + i));
        }
        bytes32 hash = RH.originHash(origin);
        old.origins = new RH.OriginEnvironment[](1);
        old.origins[0] = origin;
        old.eras = new RH.OwnerEra[](1);
        cp.ownerState.revision = 90;
        cp.replayCount = 1;
        old.eras[0] = RH.OwnerEra(hash, cp, 2, 0, 0);
        old.journal = new RH.JournalEntry[](2);
        for (uint256 i; i < 2; ++i) {
            old.journal[i] = RH.JournalEntry(
                RH.Position(RH.Point(hash, ownerIndex, uint64(40 + i * 10)), i),
                H.Receipt(
                    ownerIndex == 5 ? 18 : 35,
                    ARTIST,
                    0,
                    ownerIndex == 5 ? bytes32(uint256(7000 + i)) : bytes32(uint256(7000))
                )
            );
        }
        old.aliases = new RH.ReplayAlias[](1);
        old.aliases[0] = RH.ReplayAlias(
            hash,
            ownerIndex,
            SURFACE,
            SCOPE,
            Keys.replayKey(origin, ownerIndex, AH.Origin(SURFACE, SCOPE)),
            T.ReplayCell(bytes32(uint256(8000)), 90, 1, 2),
            RH.Point(hash, ownerIndex, 90)
        );
        _prefix(ownerIndex, old, IMPORT, 1);
        vm.mockCall(
            owner, abi.encodeWithSignature("artistNativeReceiptCount()"), abi.encode(uint256(1))
        );
        vm.mockCall(
            owner,
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
            abi.encode(H.Receipt(ownerIndex == 5 ? 18 : 35, ARTIST, 0, bytes32(uint256(9000))))
        );
        vm.mockCall(
            owner,
            abi.encodeWithSignature("artistNativeReceiptRevisionAt(uint256)", uint256(0)),
            abi.encode(uint64(2))
        );
    }

    function _checkpoint(uint8 index, CP.Checkpoint memory cp) internal {
        vm.mockCall(
            suite.owners[index], abi.encodeWithSignature("authorityCheckpoint()"), abi.encode(cp)
        );
        vm.mockCall(
            suite.owners[index],
            abi.encodeWithSignature("ownerStateSnapshotV2()"),
            abi.encode(cp.ownerState)
        );
    }

    function _prefix(uint8 index, RH.OwnerProvenance memory p, bytes32 commitment, uint64 revision)
        internal
    {
        vm.mockCall(
            suite.owners[index],
            abi.encodeWithSignature("recoveredHydrationImportedPrefix()"),
            abi.encode(p, commitment, revision)
        );
        vm.mockCall(
            suite.owners[index],
            abi.encodeWithSignature("authorityHydrationCommitment()"),
            abi.encode(commitment)
        );
    }

    function _aux(RH.Point memory point) internal {
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)", AUX, SCOPE
            ),
            abi.encode(point)
        );
    }

    function _replay(bytes32 key, T.ReplayCell memory cell, RH.Point memory point) internal {
        vm.mockCall(
            e.payoutOwner, abi.encodeWithSignature("replayCell(bytes32)", key), abi.encode(cell)
        );
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature("recoveredHydrationReplayPoint(bytes32)", key),
            abi.encode(point)
        );
    }

    function _pointError(RH.Point memory point) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            RH.InvalidRecoveredHydrationPoint.selector,
            point.environmentHash,
            point.ownerIndex,
            point.ownerRevision
        );
    }

    function _reject(bytes memory call_, bytes memory expected) internal {
        (bool ok, bytes memory error) = address(harness).call(call_);
        require(!ok && keccak256(error) == keccak256(expected), "exact recovered runtime rejection");
    }
}
