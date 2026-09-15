// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import {
    IStreamArtistHistory as History,
    IStreamArtistHistoryOwner as HistoryOwner,
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import "../../../smart-contracts/core/StreamCoreExternalReads.sol";
import "../../../smart-contracts/domains/artist/StreamArtistHistoryState.sol";

/// @notice Actual two-registry/owner/Archive/Safe round-trip; Core and governance remain typed unit boundaries.
/// @dev This deliberately proves history admission, not hydration of imported authority or paid commerce.
contract StreamArtistHistoryImportTest is ArtistOnboardingFixture {
    bytes32 private constant CHAIN =
        0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e;
    bytes32 private constant LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;
    bytes32 private constant POINTER = keccak256("ARTIST_REGISTRY");

    struct Next {
        StreamArtistOnboardingRegistry registry;
        StreamArtistArchiveV2 archive;
        StreamArtistOnboardingCoordinator coordinator;
        address identity;
    }

    function testNativeHistoryUsesOriginalRecordsAndIndependentLaneFold() external {
        History h = History(address(ingress));
        (bytes32 tip, uint64 count) = h.artistHistoryLane(1, artistId);
        require(count == 2, "proposal creates exactly binding and identity records");
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        (bytes32 first,) = h.artistHistoryRecordAt(1, artistId, 0);
        (bytes32 second,) = h.artistHistoryRecordAt(1, artistId, 1);
        require(
            first == binding_.bindingHash && second == artistId,
            "fixed owner order, original hashes"
        );
        require(
            tip
                == keccak256(
                    abi.encode(CHAIN, keccak256(abi.encode(CHAIN, bytes32(0), first)), second)
                ),
            "independent original accumulator"
        );
        (bytes32 ct, uint64 cc) = h.artistHistoryLane(2, bytes32(uint256(1)));
        require(
            cc == 1 && ct == keccak256(abi.encode(CHAIN, bytes32(0), first)),
            "one collection binding, no envelope"
        );
        _accept();
        _payout();
        _policy();
        _foldNative(h, 1, artistId);
        _foldNative(h, 2, bytes32(uint256(1)));
        (, count) = h.artistHistoryLane(1, artistId);
        (, cc) = h.artistHistoryLane(2, bytes32(uint256(1)));
        require(count == 5 && cc == 3, "acceptance once, artist-only payout, two-lane policy");
        require(h.artistHistoryContinuityCommitment() != 0, "separate continuity state");
    }

    function testHistoryReadBoundsRejectEmptyAndOutOfRangeNativeLanes() external {
        History h = History(address(ingress));
        bytes32 roots = _historyRoots(coordinator);
        uint256 safeNonce = artist.nonce();
        bytes32 emptyArtist = keccak256("absent history artist");
        (bytes32 tip, uint64 count) = h.artistHistoryLane(1, emptyArtist);
        require(tip == 0 && count == 0, "empty artist lane");
        (tip, count) = h.artistHistoryLane(2, bytes32(uint256(2)));
        require(tip == 0 && count == 0, "empty collection lane");
        _assertHistoryReadBounds(h, 1, emptyArtist);
        _assertHistoryReadBounds(h, 2, bytes32(uint256(2)));
        _assertHistoryReadBounds(h, 1, artistId);
        _assertHistoryReadBounds(h, 2, bytes32(uint256(1)));
        require(
            _historyRoots(coordinator) == roots && artist.nonce() == safeNonce,
            "failed and valid reads preserve owner roots and Safe nonce"
        );
    }

    function _assertHistoryReadBounds(History h, uint8 kind, bytes32 laneKey) private {
        (bytes32 tip, uint64 count) = h.artistHistoryLane(kind, laneKey);
        avm.expectRevert(StreamArtistHistoryState.InvalidArtistHistory.selector);
        h.artistHistoryRecordAt(kind, laneKey, count);
        avm.expectRevert(StreamArtistHistoryState.InvalidArtistHistory.selector);
        h.artistHistoryRecordAt(kind, laneKey, type(uint64).max);
        if (count != 0) {
            (bytes32 record, bytes32 chain) = h.artistHistoryRecordAt(kind, laneKey, count - 1);
            require(record != 0 && chain == tip, "last admitted record stays readable");
        }
        (bytes32 afterTip, uint64 afterCount) = h.artistHistoryLane(kind, laneKey);
        require(afterTip == tip && afterCount == count, "history bounds do not change the lane");
    }

    function testNativeLaneAndSafeNonceRollbackThenIdenticalArchiveRetry() external {
        History h = History(address(ingress));
        bytes32 before_ = h.artistRecordChainHash(artistId);
        bytes32 collectionBefore = h.collectionRecordChainHash(1);
        bytes32 snapshots = _historyRoots(coordinator);
        uint256 receipts = Native(suite.owners[3]).artistNativeReceiptCount();
        uint256 safeNonce = artist.nonce();
        T.Authorization memory a = _authorization(false);
        bytes memory data =
            abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (uint256(1), a));
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "history archive failure")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), data);
        require(
            artist.nonce() == safeNonce && h.artistRecordChainHash(artistId) == before_
                && h.collectionRecordChainHash(1) == collectionBefore,
            "whole Safe/lane rollback"
        );
        require(
            Native(suite.owners[3]).artistNativeReceiptCount() == receipts
                && _historyRoots(coordinator) == snapshots,
            "receipt and original roots rollback"
        );
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(ingress), data), "identical Safe calldata retry");
        require(artist.nonce() == safeNonce + 1, "one actual successful Safe transaction");
        (, uint64 count) = h.artistHistoryLane(1, artistId);
        require(count == 3, "one accepted record after retry");
        _foldNative(h, 1, artistId);
    }

    function testTwoRegistriesFollowupRootCutoverAndImmutableHistoricalReads() external {
        History previous = History(address(ingress));
        Next memory n = _next();
        History next = History(address(n.registry));
        avm.expectRevert(StreamArtistHistoryState.InvalidArtistHistory.selector);
        next.observeRegistryCutover();
        (bool prematurelyObserved,,) = next.artistRegistryCutover();
        require(
            !prematurelyObserved,
            "permissionless observation cannot kill a never-selected successor"
        );
        HT.Leaf[] memory first = _leaves(previous);
        (bytes32 root, bytes32[] memory proof) = _proof(address(ingress), first, first.length - 1);
        require(
            !StreamCoreExternalReads.artistSuccessorAdmitted(
                address(ingress), address(ingress).codehash, address(n.registry)
            ),
            "replacement cannot precede commitment"
        );
        _commit(n, root, keccak256("first complete exported native lanes"));
        require(
            StreamCoreExternalReads.artistSuccessorAdmitted(
                address(ingress), address(ingress).codehash, address(n.registry)
            ),
            "exact committed predecessor permits Core admission"
        );
        avm.expectRevert(StreamArtistHistoryState.ArtistRegistryNoLongerCurrent.selector);
        next.verifyImportedLaneTip(0, first[first.length - 1], proof);
        _accept(); // Real authenticated predecessor write after the first snapshot.
        core.set(POINTER, address(n.registry), false);
        avm.expectRevert(StreamArtistHistoryState.InvalidArtistHistory.selector);
        next.verifyImportedLaneTip(0, first[first.length - 1], proof);
        HT.Leaf[] memory latest = _leaves(previous);
        (root, proof) = _proof(address(ingress), latest, latest.length - 1);
        _commit(n, root, keccak256("followup includes final acceptance"));
        require(next.importedHistoryBindingCount() == 2, "append-only root union");
        vm.recordLogs();
        next.verifyImportedLaneTip(1, latest[latest.length - 1], proof);
        _historyEvent(
            vm.getRecordedLogs(),
            n.identity,
            keccak256("ArtistHistoryLaneVerified(uint16,uint8,bytes32,uint256,bytes32,uint64)"),
            bytes32(uint256(2)),
            bytes32(uint256(1)),
            abi.encode(
                uint16(1),
                uint256(1),
                latest[latest.length - 1].recordChainHash,
                latest[latest.length - 1].sequence + 1
            )
        );
        (, uint64 count) = previous.artistHistoryLane(1, artistId);
        (, proof) = _proof(address(ingress), latest, count - 1);
        next.verifyImportedLaneTip(1, latest[count - 1], proof);
        require(
            next.artistRecordChainHash(artistId) == previous.artistRecordChainHash(artistId)
                && next.collectionRecordChainHash(1) == previous.collectionRecordChainHash(1),
            "verified tips preserved under original IDs"
        );
        for (uint64 i; i < count; ++i) {
            (bytes32 a, bytes32 b) = previous.artistHistoryRecordAt(1, artistId, i);
            (bytes32 c, bytes32 d) = next.artistHistoryRecordAt(1, artistId, i);
            require(a == c && b == d, "exact read-through history, no rederived identity");
        }
        _assertHistoryReadBounds(next, 1, artistId);
        _assertHistoryReadBounds(next, 2, bytes32(uint256(1)));
        bytes32 oldTip = previous.artistRecordChainHash(artistId);
        T.PolicyConsent memory write = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory auth = T.Authorization(55, uint64(block.timestamp + 1 days), "");
        avm.expectRevert(T.InvalidBinding.selector);
        ingress.recordPolicyConsent(write, auth);
        vm.recordLogs();
        previous.observeRegistryCutover();
        _historyEvent(
            vm.getRecordedLogs(),
            suite.owners[2],
            keccak256("ArtistRegistryCutoverObserved(uint16,address,uint64)"),
            bytes32(uint256(uint160(address(n.registry)))),
            bytes32(0),
            abi.encode(uint16(1), uint64(block.timestamp))
        );
        (bool observed, address successor,) = previous.artistRegistryCutover();
        require(
            observed && successor == address(n.registry)
                && previous.artistRecordChainHash(artistId) == oldTip,
            "one-way terminal and readable permanent tip"
        );
        avm.expectPartialRevert(T.Replay.selector);
        previous.observeRegistryCutover();
        core.set(POINTER, address(ingress), false);
        avm.expectRevert(T.InvalidBinding.selector);
        ingress.recordPolicyConsent(write, auth);
        require(
            next.artistRecordChainHash(artistId) == oldTip,
            "historical reads never require current pointer"
        );
    }

    function testForgedTipRecordCannotServeEvenWithCommittedRootAndMatchingAccumulator() external {
        Next memory n = _next();
        History next = History(address(n.registry));
        History previous = History(address(ingress));
        HT.Leaf[] memory rows = _leaves(previous);
        HT.Leaf memory p = rows[rows.length - 1];
        p.recordHash = keccak256("governance fabricated authority record");
        bytes32 root = _leaf(address(ingress), p);
        bytes32[] memory empty = new bytes32[](0);
        _commit(n, root, keccak256("malformed snapshot"));
        core.set(POINTER, address(n.registry), false);
        require(
            next.verifyImportedRecord(root, p, empty),
            "membership alone can describe bad exporter data"
        );
        avm.expectRevert(StreamArtistHistoryState.InvalidArtistHistory.selector);
        next.verifyImportedLaneTip(0, p, empty);
        (bool verified,,) = next.importedLaneVerified(2, bytes32(uint256(1)));
        require(!verified, "actual predecessor terminal record rejects forgery");
        avm.expectRevert(StreamArtistHistoryState.InvalidArtistHistory.selector);
        next.artistHistoryRecordAt(2, bytes32(uint256(1)), 0);
        require(n.registry.acceptedArtist(1) == address(0), "proof does not install acceptance");
    }

    function testImportGovernanceContextAndArchiveAtomicity() external {
        Next memory n = _next();
        History next = History(address(n.registry));
        (bytes32 root,) = _proof(address(ingress), _leaves(History(address(ingress))), 0);
        bytes32 manifest = keccak256("governed snapshot");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        bytes memory data = _commitData(n, root, manifest, 0, false);
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(authority), data);
        data = _commitData(n, root, manifest, 1, true);
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(authority), data);
        data = _commitData(n, root, manifest, 1, false);
        bytes32 snapshots = _historyRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "history archive failure")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(authority), data);
        require(
            next.importedHistoryBindingCount() == 0 && next.artistHistoryContinuityCommitment() == 0
                && artist.nonce() == nonce,
            "commitment, replay and Safe rollback"
        );
        require(_historyRoots(n.coordinator) == snapshots, "original Identity state rollback");
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(address(authority), data),
            "same saved action and Safe bytes succeed"
        );
        require(
            next.importedHistoryBindingCount() == 1 && n.archive.storedPayloadCount() == 1,
            "one original operation55 Archive evidence"
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(authority), data);
        require(next.importedHistoryBindingCount() == 1, "old context/replay cannot append twice");
    }

    function testVerifiedHistoryCannotGrantAuthorityOrOverwriteUnhydratedCollection() external {
        Next memory n = _next();
        History next = History(address(n.registry));
        History previous = History(address(ingress));
        HT.Leaf[] memory rows = _leaves(previous);
        (bytes32 root, bytes32[] memory proof) = _proof(address(ingress), rows, rows.length - 1);
        _commit(n, root, keccak256("unhydrated historical lane"));
        core.set(POINTER, address(n.registry), false);
        next.verifyImportedLaneTip(0, rows[rows.length - 1], proof);
        T.BindingProposal memory p = _proposal(bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistHistoryState.ArtistHistoryImportedAuthorityUnavailable.selector,
                uint8(2),
                bytes32(uint256(1))
            )
        );
        n.registry.proposeArtistBinding(1, p, bytes("unit identity document"), "Artist Safe");
        require(
            IStreamArtistBindingOwner(n.coordinator.suiteConfiguration().owners[0])
            .binding(1)
            .generation == 0,
            "late lane guard rolls back every semantic producer"
        );
        require(
            next.artistRecordChainHash(artistId) == 0 && n.registry.acceptedArtist(1) == address(0),
            "no fabricated imported identity or acceptance"
        );
        HT.Receipt[] memory empty = new HT.Receipt[](0);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        HistoryOwner(n.identity).syncArtistNativeHistory(suite.owners[0], 0, empty);
    }

    function _historyRoots(StreamArtistOnboardingCoordinator source)
        private
        view
        returns (bytes32 hash)
    {
        T.SuiteConfiguration memory s = source.suiteConfiguration();
        T.Snapshot[7] memory rows;
        for (uint256 i; i < 7; ++i) {
            rows[i] = IStreamArtistOwner(s.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(rows));
    }

    function _foldNative(History h, uint8 kind, bytes32 id) private view {
        (bytes32 tip, uint64 count) = h.artistHistoryLane(kind, id);
        bytes32 running;
        for (uint64 i; i < count; ++i) {
            (bytes32 r, bytes32 chain) = h.artistHistoryRecordAt(kind, id, i);
            running = keccak256(abi.encode(CHAIN, running, r));
            require(r != 0 && running == chain, "independent every-prefix fold");
        }
        require(running == tip, "complete canonical tip");
    }

    function _leaves(History h) private view returns (HT.Leaf[] memory rows) {
        (, uint64 a) = h.artistHistoryLane(1, artistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, artistId, i);
            rows[i] = HT.Leaf(1, artistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _leaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        LEAF,
                        block.chainid,
                        predecessor,
                        p.laneKind,
                        p.laneKey,
                        p.sequence,
                        p.recordHash,
                        p.recordChainHash
                    )
                )
            )
        );
    }

    function _proof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _leaf(predecessor, leaves[i]);
        }
        while (n > 1) {
            if ((index ^ 1) < n) proof[used++] = layer[index ^ 1];
            uint256 nextN = (n + 1) / 2;
            for (uint256 i; i < nextN; ++i) {
                uint256 j = i * 2;
                if (j + 1 == n) {
                    layer[i] = layer[j];
                } else {
                    bytes32 a = layer[j];
                    bytes32 b = layer[j + 1];
                    layer[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
                }
            }
            index /= 2;
            n = nextN;
        }
        root = layer[0];
        assembly ("memory-safe") { mstore(proof, used) }
    }

    function _commitData(Next memory n, bytes32 root, bytes32 manifest, uint8 cls, bool wrong)
        private
        view
        returns (bytes memory)
    {
        HT.Context memory x = History(address(n.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        return abi.encodeCall(
            ArtistUnitGovernance.executeModuleContext,
            (
                address(n.registry),
                abi.encodeCall(
                    History.commitArtistHistoryImportRoot,
                    (address(ingress), uint64(block.number), root, manifest)
                ),
                cls,
                x.scopeHash,
                wrong ? keccak256("wrong import state") : x.oldValueHash,
                x.newValueHash
            )
        );
    }

    function _commit(Next memory n, bytes32 root, bytes32 manifest) private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        bytes memory data = _commitData(n, root, manifest, 1, false);
        vm.recordLogs();
        require(
            this.executeTargetSafe(address(authority), data),
            "actual threshold Safe executes typed governance context"
        );
        _historyEvent(
            vm.getRecordedLogs(),
            n.identity,
            keccak256(
                "ArtistHistoryImportRootCommitted(uint16,address,bytes32,uint64,bytes32,bytes32)"
            ),
            bytes32(uint256(uint160(address(ingress)))),
            root,
            abi.encode(
                uint16(1), uint64(block.number), manifest, keccak256("unit authority gas raise")
            )
        );
    }

    function _historyEvent(
        Vm.Log[] memory logs,
        address emitter,
        bytes32 topic,
        bytes32 first,
        bytes32 second,
        bytes memory expected
    ) private pure {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory entry = logs[i];
            if (entry.emitter != emitter || entry.topics.length == 0 || entry.topics[0] != topic) {
                continue;
            }
            ++found;
            require(
                entry.topics.length == (second == 0 ? 2 : 3) && entry.topics[1] == first,
                "exact original event emitter/topics"
            );
            if (second != 0) require(entry.topics[2] == second, "exact second indexed word");
            require(
                keccak256(entry.data) == keccak256(expected),
                "independent complete normative event data"
            );
        }
        require(found == 1, "one original normative import event");
    }

    function _next() private returns (Next memory n) {
        T.SuiteConfiguration memory s = suite;
        address governance = manager.governanceAuthority();
        ArtistSanctionFinalityFixture finalityFixture = new ArtistSanctionFinalityFixture();
        uint256 nonce = avm.getNonce(address(this));
        address registry_ = avm.computeCreateAddress(address(this), nonce);
        address archive_ = avm.computeCreateAddress(address(this), nonce + 1);
        address coordinator_ = avm.computeCreateAddress(address(this), nonce + 9);
        address identity_ = avm.computeCreateAddress(address(this), nonce + 4);
        address[3] memory facade;
        address[3] memory identity;
        for (uint8 i; i < 3; ++i) {
            facade[i] = artistExtensionFactory.deployRegistry(i + 4, registry_, coordinator_);
        }
        for (uint8 i; i < 3; ++i) {
            identity[i] = artistExtensionFactory.deployIdentity(
                i + 1, [identity_, registry_, coordinator_, archive_, s.core, s.mintManager]
            );
        }
        n.registry = StreamArtistOnboardingRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry",
                    abi.encode(
                        s.core,
                        s.mintManager,
                        coordinator_,
                        governance,
                        address(estateCoverageProvider),
                        keccak256("successor deployment"),
                        "urn:successor",
                        keccak256("successor manifest"),
                        address(artistExtensionFactory),
                        facade
                    )
                ))
        );
        n.archive = StreamArtistArchiveV2(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2",
                    abi.encode(registry_, coordinator_)
                ))
        );
        s.registry = registry_;
        s.archive = archive_;
        s.owners[0] = address(
            StreamArtistBindingLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[1] = address(
            StreamArtistCollaboratorLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[2] = address(
            StreamArtistIdentityAuthority(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority",
                        abi.encode(
                            registry_,
                            coordinator_,
                            archive_,
                            s.core,
                            s.mintManager,
                            address(artistExtensionFactory),
                            identity
                        )
                    ))
            )
        );
        s.owners[3] = address(
            StreamArtistAcceptanceLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[4] = address(
            StreamArtistAttributionLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[5] = address(
            StreamArtistPayoutLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[6] = address(
            StreamArtistConsentFinalityLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        ArtistUnitGovernance(governance)
            .configureContestReads(
                s.roleRegistry, address(artist), keccak256("successor finality"), "urn:successor"
            );
        address finality = finalityFixture.deploy(s.core, s.metadata, registry_, governance);
        n.coordinator = StreamArtistOnboardingCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator",
                    abi.encode(s, finality)
                ))
        );
        n.identity = s.owners[2];
        require(
            address(n.registry) == registry_ && address(n.archive) == archive_
                && address(n.coordinator) == coordinator_ && n.identity == identity_,
            "actual successor pins"
        );
    }
}
