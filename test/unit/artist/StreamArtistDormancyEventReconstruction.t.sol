// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistStewardCapabilities.t.sol";
import {
    IStreamArtistDormancyReconstructionEvents as ER
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancyReconstructionEvents.sol";

interface ArtistDormancyReplayVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Independent log-only reader. No state, payload-pointer or producer-hash-helper reads.
contract ArtistDormancyEventFold {
    bytes32 private constant NOTICE =
        keccak256("ArtistDormancyInitiated(uint16,bytes32,bytes32,uint64,bytes32,string,bytes32)");
    bytes32 private constant CANCEL =
        keccak256("ArtistDormancyCancelled(uint16,bytes32,bytes32,address,uint8,bytes32)");
    bytes32 private constant COMPLETE = keccak256(
        "ArtistDormancyCompleted(uint16,bytes32,bytes32,address,uint8,uint32,uint64,bytes32,bytes32)"
    );
    bytes32 private constant GRANT = keccak256(
        "StewardCapabilitiesGranted(uint16,bytes32,bytes32,bytes32,address,uint32,uint32,bytes32,bytes32)"
    );
    bytes32 private constant NOTICE_CONTEXT = keccak256(
        "ArtistDormancyNoticeContext(uint16,bytes32,bytes32,(uint256,address,address,address,uint8),(bytes32,(bytes32,bytes32,string),address,uint64,uint64,uint64,uint64,uint64,uint64,uint256,bytes32,bytes32))"
    );
    bytes32 private constant CANCEL_CONTEXT = keccak256(
        "ArtistDormancyCancellationContext(uint16,bytes32,bytes32,(uint256,address,address,address,uint8),(bytes32,bytes32,address,uint8,uint64,uint64,(address,uint8,uint32,bytes32,bytes32,bytes32,bytes32,uint64,uint64),bytes32,bytes32,bytes32,uint64),uint256)"
    );
    bytes32 private constant COMPLETE_CONTEXT = keccak256(
        "ArtistDormancyCompletionContext(uint16,bytes32,bytes32,(uint256,address,address,address,uint8),(bytes32,bytes32,address,uint8,uint64,uint64,(address,uint8,uint32,bytes32,bytes32,bytes32,bytes32,uint64,uint64),bytes32,bytes32,bytes32,uint64))"
    );
    bytes32 private constant GRANT_CONTEXT = keccak256(
        "ArtistStewardCapabilityContext(uint16,bytes32,bytes32,(uint256,address,address,address,uint8),(bytes32,(bytes32,bytes32,address,bytes32,bytes32,uint32,uint32,bytes32,string),(bytes32,address,address,uint64,uint64,bytes32,bytes32,uint64,bytes32,(bytes32,bytes32,bytes32)),address,uint32,uint64))"
    );

    struct Fold {
        Dorm.Notice[] notices;
        Dorm.Terminal[] terminals;
        uint8[] phases;
        SC.Record[] grants;
        uint256 noticeCount;
        uint256 grantCount;
        uint256 activityCount;
        bytes32 grantHead;
        uint32 addedCapabilities;
    }

    function fold(
        Vm.Log[] memory logs,
        uint256 chain,
        address registry,
        address owner,
        bytes32 artist
    ) external pure returns (Fold memory f) {
        require(
            logs.length <= 1024 && registry != address(0) && owner != address(0) && artist != 0,
            "pins"
        );
        f.notices = new Dorm.Notice[](logs.length);
        f.terminals = new Dorm.Terminal[](logs.length);
        f.phases = new uint8[](logs.length);
        f.grants = new SC.Record[](logs.length);
        uint8 pending;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (pending != 0) {
                require(
                    log.emitter == owner && log.topics.length == 3 && log.topics[1] == artist,
                    "missing owner context"
                );
                (uint16 schema, ER.Context memory c) = _context(log.data);
                require(
                    schema == 1 && c.chainId == chain && c.registry == registry
                        && c.identityOwner == owner && c.recorder != address(0),
                    "foreign context"
                );
                if (pending == 1) _notice(f, logs[i - 1], log, c, artist);
                else if (pending == 2) _cancel(f, logs[i - 1], log, c);
                else if (pending == 3) _complete(f, logs[i - 1], log, c);
                else _grant(f, logs[i - 1], log, c, artist);
                pending = 0;
                continue;
            }
            if (log.emitter != owner || log.topics.length == 0) continue;
            bytes32 topic = log.topics[0];
            require(
                topic != NOTICE_CONTEXT && topic != CANCEL_CONTEXT && topic != COMPLETE_CONTEXT
                    && topic != GRANT_CONTEXT,
                "orphan context"
            );
            if (topic == NOTICE) pending = 1;
            else if (topic == CANCEL) pending = 2;
            else if (topic == COMPLETE) pending = 3;
            else if (topic == GRANT) pending = 4;
            if (pending != 0) {
                require(
                    log.topics.length == (pending == 4 ? 4 : 3) && log.topics[1] == artist,
                    "legacy subject"
                );
            }
        }
        require(pending == 0, "missing final context");
    }

    function _context(bytes memory data) private pure returns (uint16 schema, ER.Context memory c) {
        // These fixed leading components precede the dynamic saved record in every companion.
        (schema, c) = abi.decode(data, (uint16, ER.Context));
    }

    function _equal(bytes memory a, bytes memory b) private pure {
        require(keccak256(a) == keccak256(b), "legacy/context disagreement");
    }

    function _notice(
        Fold memory f,
        Vm.Log memory old,
        Vm.Log memory log,
        ER.Context memory c,
        bytes32 artist
    ) private pure {
        require(log.topics[0] == NOTICE_CONTEXT && c.recorderAuthorityClass == 0, "notice context");
        (uint16 schema,, Dorm.Notice memory n) =
            abi.decode(log.data, (uint16, ER.Context, Dorm.Notice));
        _equal(log.data, abi.encode(schema, c, n));
        require(
            n.recordHash != 0 && n.recordHash == log.topics[2] && n.recordHash == old.topics[2]
                && n.terms.artistId == artist,
            "notice identity"
        );
        require(
            n.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                        c.chainId,
                        c.registry,
                        c.identityOwner,
                        n.terms,
                        n.incumbent,
                        n.initiatedAt,
                        n.noticeEndsAt,
                        n.inactivitySeconds,
                        n.noticeSeconds,
                        n.timingRevision,
                        n.priorLivenessAt,
                        n.priorActivity,
                        n.actionId,
                        n.witnessHash
                    )
                ),
            "notice preimage"
        );
        _equal(
            old.data,
            abi.encode(
                uint16(1), n.noticeEndsAt, n.terms.evidenceHash, n.terms.reasonURI, n.actionId
            )
        );
        for (uint256 i; i < f.noticeCount; ++i) {
            require(f.notices[i].recordHash != n.recordHash, "duplicate notice");
        }
        if (f.noticeCount != 0) {
            require(
                f.phases[f.noticeCount - 1] == 2
                    && n.initiatedAt >= f.terminals[f.noticeCount - 1].observedAt
                    && n.priorActivity == f.activityCount,
                "notice order"
            );
        } else {
            f.activityCount = n.priorActivity;
        }
        f.notices[f.noticeCount] = n;
        f.phases[f.noticeCount++] = 1;
    }

    function _terminalHead(
        Fold memory f,
        Vm.Log memory old,
        Vm.Log memory log,
        Dorm.Terminal memory t
    ) private pure returns (uint256 i) {
        require(f.noticeCount != 0, "terminal without notice");
        i = f.noticeCount - 1;
        require(
            f.phases[i] == 1 && t.recordHash != 0 && t.recordHash == log.topics[2]
                && t.noticeHash == f.notices[i].recordHash && old.topics[2] == t.noticeHash
                && t.observedAt >= f.notices[i].initiatedAt,
            "terminal order"
        );
    }

    function _cancel(Fold memory f, Vm.Log memory old, Vm.Log memory log, ER.Context memory c)
        private
        pure
    {
        require(log.topics[0] == CANCEL_CONTEXT, "cancel context");
        (uint16 schema,, Dorm.Terminal memory t, uint256 count) =
            abi.decode(log.data, (uint16, ER.Context, Dorm.Terminal, uint256));
        _equal(log.data, abi.encode(schema, c, t, count));
        uint256 i = _terminalHead(f, old, log, t);
        require(
            t.actor == c.recorder && t.authorityClass == c.recorderAuthorityClass
                && t.authorityClass >= 1 && t.authorityClass <= 3 && count == f.activityCount + 1,
            "cancel actor/activity"
        );
        bytes32 saved = t.recordHash;
        t.recordHash = 0;
        require(
            saved
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                        c.chainId,
                        c.registry,
                        c.identityOwner,
                        t,
                        count
                    )
                ),
            "cancel preimage"
        );
        t.recordHash = saved;
        _equal(old.data, abi.encode(uint16(1), t.actor, t.authorityClass, t.recordHash));
        f.terminals[i] = t;
        f.phases[i] = 2;
        f.activityCount = count;
    }

    function _complete(Fold memory f, Vm.Log memory old, Vm.Log memory log, ER.Context memory c)
        private
        pure
    {
        require(
            log.topics[0] == COMPLETE_CONTEXT && c.recorderAuthorityClass == 0, "completion context"
        );
        (uint16 schema,, Dorm.Terminal memory t) =
            abi.decode(log.data, (uint16, ER.Context, Dorm.Terminal));
        _equal(log.data, abi.encode(schema, c, t));
        uint256 i = _terminalHead(f, old, log, t);
        require(
            t.actor == c.recorder && (t.authorityClass == 3 || t.authorityClass == 4)
                && t.plan.authorityClass == t.authorityClass
                && t.observedAt >= f.notices[i].noticeEndsAt,
            "completion actor/time"
        );
        bytes32 saved = t.recordHash;
        t.recordHash = 0;
        require(
            saved
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                        c.chainId,
                        c.registry,
                        c.identityOwner,
                        t
                    )
                ),
            "completion preimage"
        );
        t.recordHash = saved;
        _equal(
            old.data,
            abi.encode(
                uint16(1),
                t.plan.authority,
                t.authorityClass,
                t.plan.capabilities,
                t.appointmentBlock,
                t.recordHash,
                t.actionId
            )
        );
        f.terminals[i] = t;
        f.phases[i] = 3;
    }

    function _grant(
        Fold memory f,
        Vm.Log memory old,
        Vm.Log memory log,
        ER.Context memory c,
        bytes32 artist
    ) private pure {
        require(
            log.topics[0] == GRANT_CONTEXT && c.recorderAuthorityClass == 0 && f.noticeCount != 0,
            "grant context"
        );
        (uint16 schema,, SC.Record memory r) = abi.decode(log.data, (uint16, ER.Context, SC.Record));
        _equal(log.data, abi.encode(schema, c, r));
        Dorm.Terminal memory t = f.terminals[f.noticeCount - 1];
        require(
            f.phases[f.noticeCount - 1] == 3 && t.authorityClass == 4 && r.executor == c.recorder
                && r.terms.artistId == artist && r.terms.expectedAppointmentHash == t.recordHash
                && r.terms.expectedSteward == t.plan.authority
                && r.terms.expectedGrantHead == f.grantHead && r.recordedAt >= t.observedAt,
            "grant order/appointment"
        );
        require(
            r.recordHash != 0 && r.recordHash == log.topics[2] && old.topics[2] == t.recordHash
                && old.topics[3] == r.recordHash,
            "grant identity"
        );
        require(
            r.terms.expectedCapabilities == (t.plan.capabilities | f.addedCapabilities)
                && r.terms.addedCapabilities != 0 && (r.terms.addedCapabilities & ~uint32(12)) == 0
                && (r.terms.addedCapabilities & r.terms.expectedCapabilities) == 0
                && r.effectiveCapabilities
                    == (r.terms.expectedCapabilities | r.terms.addedCapabilities),
            "grant masks"
        );
        bytes32 saved = r.recordHash;
        r.recordHash = 0;
        require(
            saved
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_STEWARD_CAPABILITY_GRANT_V1"),
                        c.chainId,
                        c.registry,
                        c.identityOwner,
                        r
                    )
                ),
            "grant preimage"
        );
        r.recordHash = saved;
        _equal(
            old.data,
            abi.encode(
                uint16(1),
                r.terms.expectedSteward,
                r.terms.addedCapabilities,
                r.effectiveCapabilities,
                r.witness.actionId,
                r.terms.expectedGrantHead
            )
        );
        f.grants[f.grantCount++] = r;
        f.grantHead = r.recordHash;
        f.addedCapabilities |= r.terms.addedCapabilities;
    }
}

/// @notice Real Artist/Safe/Archive; typed Core and governance boundaries. Authored, not native acceptance.
contract StreamArtistDormancyEventReconstructionTest is StreamArtistStewardCapabilitiesTest {
    function _fold(Vm.Log[] memory logs) internal returns (ArtistDormancyEventFold.Fold memory) {
        return (new ArtistDormancyEventFold())
        .fold(logs, block.chainid, address(ingress), suite.owners[2], artistId);
    }

    function _compare(ArtistDormancyEventFold.Fold memory f) internal view {
        for (uint256 i; i < f.noticeCount; ++i) {
            (Dorm.Notice memory n, uint8 phase, Dorm.Terminal memory t) =
                _dorm().dormancyRecord(f.notices[i].recordHash);
            require(
                keccak256(abi.encode(n)) == keccak256(abi.encode(f.notices[i]))
                    && phase == f.phases[i]
                    && keccak256(abi.encode(t)) == keccak256(abi.encode(f.terminals[i])),
                "log-only timeline equals saved records"
            );
        }
        for (uint256 i; i < f.grantCount; ++i) {
            require(
                keccak256(abi.encode(ingress.stewardCapabilityGrantRecord(f.grants[i].recordHash)))
                    == keccak256(abi.encode(f.grants[i])),
                "log-only grant history"
            );
        }
        if (f.noticeCount != 0 && f.phases[f.noticeCount - 1] == 3) {
            T.Identity memory principal = _identity().identity(artistId);
            Dorm.Terminal memory vested = f.terminals[f.noticeCount - 1];
            require(
                principal.authorityAddress == vested.plan.authority
                    && principal.authorityClass == vested.authorityClass && principal.status == 3,
                "log-only vested authority equals current principal"
            );
        }
        (bytes32 latest, uint8 phase, bytes32 terminal) = _dorm().dormancyNotice(artistId);
        require(
            f.noticeCount != 0 && latest == f.notices[f.noticeCount - 1].recordHash
                && phase == f.phases[f.noticeCount - 1]
                && terminal == f.terminals[f.noticeCount - 1].recordHash,
            "final timeline head"
        );
    }

    function testEventFoldLivingSafeCancellationThenClass4CompletionAndGrant() public {
        _accept();
        _payout();
        _newRotationSafe(16001);
        vm.recordLogs();
        bytes32 first = this.beginDormancyNotice();
        _safeCancel(artist, keys, first, 0);
        bytes32 next = this.beginDormancyNotice();
        this.completeDormancyNotice(next);
        artist = rotationSafe;
        keys = rotationKeys;
        _healthyGrant(_terms(4));
        _healthyGrant(_terms(8));
        ArtistDormancyEventFold.Fold memory f = _fold(vm.getRecordedLogs());
        require(
            f.noticeCount == 2 && f.grantCount == 2 && f.phases[0] == 2
                && f.terminals[1].authorityClass == 4 && f.activityCount == 1
                && f.addedCapabilities == 12,
            "complete authored timeline"
        );
        _compare(f);
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities
                == f.grants[1].effectiveCapabilities,
            "operative class4 mask reconstructed"
        );
    }

    function testEventFoldDesignatedClass3CompletionRetainsActualPlan() public {
        _accept();
        _newRotationSafe(16002);
        bytes32 designation = _successionRecord(_successorTerms(address(rotationSafe), 1));
        vm.recordLogs();
        bytes32 notice = this.beginDormancyNotice();
        this.completeDormancyNotice(notice);
        ArtistDormancyEventFold.Fold memory f = _fold(vm.getRecordedLogs());
        require(
            f.noticeCount == 1 && f.grantCount == 0 && f.terminals[0].authorityClass == 3
                && f.terminals[0].plan.designation == designation
                && f.terminals[0].appointmentBlock == 0,
            "class3 is not steward"
        );
        _compare(f);
    }

    function _onlyContext(Vm.Log[] memory logs) internal view returns (Vm.Log[] memory pairs) {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2] && logs[i].topics.length != 0
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistDormancyInitiated(uint16,bytes32,bytes32,uint64,bytes32,string,bytes32)"
                        )
            ) ++count;
        }
        require(count == 1, "single notice pair");
        pairs = new Vm.Log[](2);
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2] && logs[i].topics.length != 0
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistDormancyInitiated(uint16,bytes32,bytes32,uint64,bytes32,string,bytes32)"
                        )
            ) {
                pairs[0] = logs[i];
                pairs[1] = logs[i + 1];
                return pairs;
            }
        }
    }

    function _refuse(Vm.Log[] memory logs) internal {
        ArtistDormancyEventFold reader = new ArtistDormancyEventFold();
        (bool ok,) = address(reader)
            .staticcall(
                abi.encodeCall(
                    reader.fold, (logs, block.chainid, address(ingress), suite.owners[2], artistId)
                )
            );
        require(!ok, "malformed history accepted");
    }

    function testEventFoldRejectsMissingDuplicateAndReorderedCompanions() public {
        _accept();
        vm.recordLogs();
        this.beginDormancyNotice();
        Vm.Log[] memory pair = _onlyContext(vm.getRecordedLogs());
        Vm.Log[] memory missing = new Vm.Log[](1);
        missing[0] = pair[0];
        _refuse(missing);
        Vm.Log[] memory reordered = new Vm.Log[](2);
        reordered[0] = pair[1];
        reordered[1] = pair[0];
        _refuse(reordered);
        Vm.Log[] memory duplicate = new Vm.Log[](4);
        duplicate[0] = pair[0];
        duplicate[1] = pair[1];
        duplicate[2] = pair[0];
        duplicate[3] = pair[1];
        _refuse(duplicate);
        _compare(_fold(pair));
    }

    function testEventFoldRejectsForeignChainRegistryOwnerAndChangedPreimage() public {
        _accept();
        vm.recordLogs();
        this.beginDormancyNotice();
        Vm.Log[] memory pair = _onlyContext(vm.getRecordedLogs());
        bytes memory original = pair[1].data;
        (uint16 schema, ER.Context memory c, Dorm.Notice memory n) =
            abi.decode(original, (uint16, ER.Context, Dorm.Notice));
        pair[1].data = abi.encode(uint16(2), c, n);
        _refuse(pair);
        c.recorderAuthorityClass = 1;
        pair[1].data = abi.encode(schema, c, n);
        _refuse(pair);
        c.recorderAuthorityClass = 0;
        c.chainId += 1;
        pair[1].data = abi.encode(schema, c, n);
        _refuse(pair);
        c.chainId -= 1;
        c.registry = address(0xBAD);
        pair[1].data = abi.encode(schema, c, n);
        _refuse(pair);
        c.registry = address(ingress);
        c.identityOwner = address(0xBAD);
        pair[1].data = abi.encode(schema, c, n);
        _refuse(pair);
        c.identityOwner = suite.owners[2];
        n.priorActivity += 1;
        pair[1].data = abi.encode(schema, c, n);
        _refuse(pair);
        pair[1].data = original;
        pair[1].emitter = address(0xBAD);
        _refuse(pair);
        pair[1].emitter = suite.owners[2];
        _compare(_fold(pair));
    }

    function testEventFoldSignedLivenessLateArchiveRollbackAndIdenticalSafeRetry() public {
        _accept();
        vm.recordLogs();
        bytes32 notice = this.beginDormancyNotice();
        Vm.Log[] memory beforeLogs = vm.getRecordedLogs();
        this.reconstructionSafeRetry(notice, beforeLogs);
    }

    function reconstructionSafeRetry(bytes32 notice, Vm.Log[] memory beforeLogs) external {
        require(msg.sender == address(this), "self only");
        bytes memory call_ = abi.encodeCall(
            IStreamArtistDormancy.cancelArtistDormancy, (artistId, notice, bytes32(0))
        );
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateDormancyArchive.selector)
        );
        ArtistDormancyReplayVm(address(vm))
            .expectCall(
                suite.archive,
                abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
                uint64(2)
            );
        vm.recordLogs();
        // Existing Safe execution signs the same nonce/data on each invocation. GS013 rolls nonce back.
        (bool ok, bytes memory reason) =
            address(this).call(abi.encodeCall(this.reconstructionSafeAttempt, (call_)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual failed Safe execution"
        );
        // The inspector may retain LOGs from reverted frames. They are not transaction receipts.
        vm.getRecordedLogs();
        require(
            artist.nonce() == safeNonce && _roots() == roots,
            "failed Safe nonce and roots roll back"
        );
        (, uint8 originalPhase,) = _dorm().dormancyRecord(notice);
        require(originalPhase == 1, "failed cancellation is not durable history");
        avm.clearMockedCalls();
        vm.recordLogs();
        this.reconstructionSafeAttempt(call_);
        Vm.Log[] memory afterLogs = vm.getRecordedLogs();
        require(artist.nonce() == safeNonce + 1, "same Safe nonce consumed once");
        Vm.Log[] memory combined = new Vm.Log[](beforeLogs.length + afterLogs.length);
        for (uint256 i; i < beforeLogs.length; ++i) {
            combined[i] = beforeLogs[i];
        }
        for (uint256 i; i < afterLogs.length; ++i) {
            combined[beforeLogs.length + i] = afterLogs[i];
        }
        ArtistDormancyEventFold.Fold memory f = _fold(combined);
        require(f.noticeCount == 1 && f.phases[0] == 2, "one durable cancellation");
        _compare(f);
    }

    function reconstructionSafeAttempt(bytes calldata call_) external {
        require(msg.sender == address(this), "self only");
        require(executeSafe(artist, keys, address(ingress), 0, call_, 0), "Safe execution");
    }
}
