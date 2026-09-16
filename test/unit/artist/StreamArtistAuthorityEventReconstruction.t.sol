// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistAuthorityReconstructionEvents as AE
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityReconstructionEvents.sol";
import "./StreamArtistDormancyRecoveryActual.t.sol";
import {
    IStreamArtistDormancyReconstructionEvents as DE
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancyReconstructionEvents.sol";
import {
    StreamArtistIdentityRecoveryTypes as PR
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";

/// @notice Independent single-transition log reader. Deployment pins are inputs, never live reads.
contract ArtistAuthorityEventReader {
    struct Pins {
        uint256 chain;
        address registry;
        address owner;
        bytes32 artist;
    }

    struct Row {
        bytes32 recordHash;
        bytes preimage;
        address oldAddress;
        address newAddress;
        uint8 authorityClass;
        bool executed;
        bool cancelled;
        bytes32 evidenceOrReason;
        R.TransitionState transition;
        Estate.ExecutionFacts estateExecution;
    }
    bytes32 private constant STAGE = keccak256(
        "ArtistRotationStaged(uint16,bytes32,address,address,uint64,uint64,uint256,bytes32,bytes32)"
    );
    bytes32 private constant ROTATE =
        keccak256("ArtistAddressRotated(uint16,bytes32,address,address,uint8,bytes32,bytes32)");
    bytes32 private constant REQUEST = keccak256(
        "ArtistEstateActivationRequested(uint16,bytes32,address,uint64,uint64,uint256,bytes32,bytes32)"
    );
    bytes32 private constant ESTATE =
        keccak256("ArtistSuccessionActivated(uint16,bytes32,address,uint8,uint32,bytes32,bytes32)");
    bytes32 private constant RECOVERY = keccak256(
        "ArtistIdentityRecovered(uint16,bytes32,address,address,uint8,bytes32,bytes32,bytes32,uint64,bytes32,bytes32,bytes32[])"
    );
    bytes32 private constant ROTATE_CONTEXT = keccak256(
        "ArtistRotationExecutionContext(uint16,bytes32,bytes32,(uint256,address,address,address,uint8),(bytes32,bytes32,uint64,uint64,uint64,uint64,uint64,uint8),uint8)"
    );
    bytes32 private constant ESTATE_CONTEXT = keccak256(
        "ArtistEstateExecutionContext(uint16,bytes32,bytes32,(uint256,address,address,address,uint8),address,(bytes32,bytes32,uint64,uint64,uint64,uint64,uint64,uint8),(bytes32,bytes32,uint32,uint64,bytes32,bytes32,uint64))"
    );

    function _pins(Pins memory p, Vm.Log[] memory logs) private pure {
        require(
            p.registry != address(0) && p.owner != address(0) && p.artist != 0
                && logs.length <= 1024,
            "pins/bound"
        );
    }

    function _address(bytes32 word) private pure returns (address) {
        require(uint256(word) <= type(uint160).max, "address word");
        return address(uint160(uint256(word)));
    }

    function _same(bytes memory a, bytes memory b) private pure {
        require(keccak256(a) == keccak256(b), "event bytes");
    }

    function _context(DE.Context memory c, Pins memory p) private pure {
        require(
            c.chainId == p.chain && c.registry == p.registry && c.identityOwner == p.owner
                && c.recorder != address(0) && c.recorderAuthorityClass == 0,
            "execution context"
        );
    }

    function _transition(Row memory r, R.TransitionState memory t, Pins memory p) private pure {
        require(
            t.artistId == p.artist && t.recordHash == r.recordHash
                && t.stagedAt == r.transition.stagedAt
                && t.contestEndsAt == r.transition.contestEndsAt && t.executedAt >= t.stagedAt
                && t.postWindowEndsAt >= t.executedAt && t.contestedAt == 0 && t.phase == 2,
            "execution timeline"
        );
    }

    function rotation(Vm.Log[] memory logs, Pins memory p) external pure returns (Row memory r) {
        _pins(p, logs);
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter != p.owner || log.topics.length == 0) continue;
            bytes32 topic = log.topics[0];
            require(topic != ROTATE_CONTEXT, "orphan rotation context");
            if (topic == STAGE) {
                require(
                    r.recordHash == 0 && log.topics.length == 4 && log.topics[1] == p.artist,
                    "stage identity"
                );
                (
                    uint16 schema,
                    uint64 at,
                    uint64 end,
                    uint256 nonce,
                    bytes32 reason,
                    bytes32 hash
                ) = abi.decode(log.data, (uint16, uint64, uint64, uint256, bytes32, bytes32));
                _same(log.data, abi.encode(schema, at, end, nonce, reason, hash));
                require(schema == 1, "stage schema");
                r.oldAddress = _address(log.topics[2]);
                r.newAddress = _address(log.topics[3]);
                r.evidenceOrReason = reason;
                r.preimage = abi.encode(
                    bytes32(0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5),
                    p.chain,
                    p.registry,
                    p.artist,
                    r.oldAddress,
                    r.newAddress,
                    reason,
                    nonce,
                    at,
                    end
                );
                require(hash != 0 && keccak256(r.preimage) == hash, "stage preimage");
                r.recordHash = hash;
                r.transition = R.TransitionState(p.artist, hash, at, end, 0, 0, 0, 1);
            } else if (topic == ROTATE) {
                require(
                    r.recordHash != 0 && !r.executed && !r.cancelled && log.topics.length == 4
                        && log.topics[1] == p.artist && _address(log.topics[2]) == r.oldAddress
                        && _address(log.topics[3]) == r.newAddress,
                    "rotation identity/order"
                );
                (uint16 schema, uint8 class_, bytes32 reason, bytes32 hash) =
                    abi.decode(log.data, (uint16, uint8, bytes32, bytes32));
                _same(log.data, abi.encode(schema, class_, reason, hash));
                require(
                    schema == 1 && hash == r.recordHash && reason == r.evidenceOrReason
                        && (class_ == 1 || class_ == 3 || class_ == 4),
                    "rotation fields"
                );
                require(++i < logs.length, "missing rotation context");
                Vm.Log memory next = logs[i];
                require(
                    next.emitter == p.owner && next.topics.length == 3
                        && next.topics[0] == ROTATE_CONTEXT && next.topics[1] == p.artist
                        && next.topics[2] == hash,
                    "rotation context identity"
                );
                (
                    uint16 version,
                    DE.Context memory c,
                    R.TransitionState memory t,
                    uint8 actualClass
                ) = abi.decode(next.data, (uint16, DE.Context, R.TransitionState, uint8));
                _same(next.data, abi.encode(version, c, t, actualClass));
                require(version == 1 && actualClass == class_, "rotation context schema/class");
                _context(c, p);
                _transition(r, t, p);
                r.transition = t;
                r.authorityClass = class_;
                r.executed = true;
            } else if (
                topic == keccak256("ArtistRotationVetoed(uint16,bytes32,address,bytes32,bytes32)")
            ) {
                require(
                    r.recordHash != 0 && !r.executed && log.topics.length == 4
                        && log.topics[1] == p.artist && log.topics[3] == r.recordHash,
                    "rotation veto identity"
                );
                r.cancelled = true;
                r.transition.phase = 3;
            }
        }
        require(r.recordHash != 0, "no rotation stage");
    }

    function estate(Vm.Log[] memory logs, Pins memory p) external pure returns (Row memory r) {
        _pins(p, logs);
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter != p.owner || log.topics.length == 0) continue;
            bytes32 topic = log.topics[0];
            require(topic != ESTATE_CONTEXT, "orphan estate context");
            if (topic == REQUEST) {
                require(
                    r.recordHash == 0 && log.topics.length == 3 && log.topics[1] == p.artist,
                    "request identity"
                );
                (
                    uint16 schema,
                    uint64 at,
                    uint64 end,
                    uint256 nonce,
                    bytes32 evidence,
                    bytes32 hash
                ) = abi.decode(log.data, (uint16, uint64, uint64, uint256, bytes32, bytes32));
                _same(log.data, abi.encode(schema, at, end, nonce, evidence, hash));
                require(schema == 1, "request schema");
                r.newAddress = _address(log.topics[2]);
                r.evidenceOrReason = evidence;
                r.preimage = abi.encode(
                    keccak256("6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1"),
                    p.chain,
                    p.registry,
                    p.artist,
                    r.newAddress,
                    evidence,
                    nonce,
                    at,
                    end
                );
                require(hash != 0 && keccak256(r.preimage) == hash, "request preimage");
                r.recordHash = hash;
                r.transition = R.TransitionState(p.artist, hash, at, end, 0, 0, 0, 1);
            } else if (topic == ESTATE) {
                require(
                    r.recordHash != 0 && !r.executed && !r.cancelled && log.topics.length == 3
                        && log.topics[1] == p.artist && _address(log.topics[2]) == r.newAddress,
                    "estate identity/order"
                );
                (uint16 schema, uint8 class_, uint32 caps, bytes32 evidence, bytes32 action) =
                    abi.decode(log.data, (uint16, uint8, uint32, bytes32, bytes32));
                _same(log.data, abi.encode(schema, class_, caps, evidence, action));
                require(
                    schema == 1 && class_ == 3 && evidence == r.evidenceOrReason, "estate fields"
                );
                require(++i < logs.length, "missing estate context");
                Vm.Log memory next = logs[i];
                require(
                    next.emitter == p.owner && next.topics.length == 3
                        && next.topics[0] == ESTATE_CONTEXT && next.topics[1] == p.artist
                        && next.topics[2] == r.recordHash,
                    "estate context identity"
                );
                (
                    uint16 version,
                    DE.Context memory c,
                    address incumbent,
                    R.TransitionState memory t,
                    Estate.ExecutionFacts memory facts
                ) = abi.decode(
                    next.data,
                    (uint16, DE.Context, address, R.TransitionState, Estate.ExecutionFacts)
                );
                _same(next.data, abi.encode(version, c, incumbent, t, facts));
                require(
                    version == 1 && incumbent != address(0) && incumbent != r.newAddress,
                    "estate context schema/incumbent"
                );
                _context(c, p);
                _transition(r, t, p);
                require(
                    facts.activationRecordHash == r.recordHash
                        && facts.effectiveCapabilities == caps && facts.governanceActionId == action
                        && facts.executedAt == t.executedAt && facts.coverageRecordHash != 0
                        && facts.delegationEpoch != 0,
                    "execution facts"
                );
                if (t.executedAt < t.contestEndsAt) {
                    require(
                        facts.governanceActionId != 0 && facts.governanceWitnessHash != 0,
                        "accelerated facts"
                    );
                } else {
                    require(
                        facts.governanceActionId == 0 && facts.governanceWitnessHash == 0,
                        "ordinary facts"
                    );
                }
                r.oldAddress = incumbent;
                r.transition = t;
                r.estateExecution = facts;
                r.authorityClass = 3;
                r.executed = true;
            } else if (
                topic
                    == keccak256(
                        "ArtistEstateActivationCancelled(uint16,bytes32,address,uint8,bytes32)"
                    )
            ) {
                require(
                    r.recordHash != 0 && !r.executed && log.topics.length == 3
                        && log.topics[1] == p.artist,
                    "cancellation identity"
                );
                (uint16 schema, uint8 class_, bytes32 hash) =
                    abi.decode(log.data, (uint16, uint8, bytes32));
                require(schema == 1 && class_ != 0 && hash == r.recordHash, "cancellation fields");
                r.cancelled = true;
                r.transition.phase = 3;
            }
        }
        require(r.recordHash != 0, "no estate request");
    }

    function recovery(Vm.Log[] memory logs, Pins memory p)
        external
        pure
        returns (bytes32 hash, bytes memory preimage, PR.RecordFields memory fields)
    {
        _pins(p, logs);
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter != p.owner || log.topics.length == 0 || log.topics[0] != RECOVERY) {
                continue;
            }
            require(
                hash == 0 && log.topics.length == 4 && log.topics[1] == p.artist,
                "recovery identity/count"
            );
            uint16 schema;
            bytes32[] memory superseded;
            (
                schema,
                fields.vestedAuthorityClass,
                fields.evidenceHash,
                fields.reasonHash,
                fields.supersededRecordsHash,
                fields.recoveredAt,
                hash,
                fields.governanceActionId,
                superseded
            ) =
                abi.decode(
                    log.data,
                    (uint16, uint8, bytes32, bytes32, bytes32, uint64, bytes32, bytes32, bytes32[])
                );
            _same(
                log.data,
                abi.encode(
                    schema,
                    fields.vestedAuthorityClass,
                    fields.evidenceHash,
                    fields.reasonHash,
                    fields.supersededRecordsHash,
                    fields.recoveredAt,
                    hash,
                    fields.governanceActionId,
                    superseded
                )
            );
            require(
                schema == 2
                    && (fields.vestedAuthorityClass == 1 || fields.vestedAuthorityClass == 3),
                "original recovery schema/class"
            );
            fields.artistId = p.artist;
            fields.oldAddress = _address(log.topics[2]);
            fields.newAddress = _address(log.topics[3]);
            bytes32 previous;
            for (uint256 j; j < superseded.length; ++j) {
                require(superseded[j] > previous, "canonical supersession");
                previous = superseded[j];
            }
            require(
                fields.supersededRecordsHash
                    == keccak256(
                        abi.encode(
                            bytes32(
                                0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae
                            ),
                            superseded
                        )
                    ),
                "original supersession hash"
            );
            preimage = abi.encode(
                bytes32(0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff),
                p.chain,
                p.registry,
                fields
            );
            require(hash != 0 && keccak256(preimage) == hash, "original recovery preimage");
        }
        require(hash != 0, "no executed recovery");
    }
}

interface AuthorityEventCallVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Actual original Artist/Safe/Archive paths; Core/governance remain typed unit boundaries.
contract StreamArtistAuthorityEventReconstructionTest is StreamArtistDormancyRecoveryActualTest {
    function _pins() internal view returns (ArtistAuthorityEventReader.Pins memory) {
        return ArtistAuthorityEventReader.Pins(
            block.chainid, address(ingress), suite.owners[2], artistId
        );
    }

    function _concat(Vm.Log[] memory a, Vm.Log[] memory b)
        internal
        pure
        returns (Vm.Log[] memory out)
    {
        out = new Vm.Log[](a.length + b.length);
        for (uint256 i; i < a.length; ++i) {
            out[i] = a[i];
        }
        for (uint256 i; i < b.length; ++i) {
            out[a.length + i] = b[i];
        }
    }

    function _carrier(bytes32 hash, bytes memory value) internal view {
        require(
            keccak256(value) == hash
                && keccak256(
                        IStreamArtistReconstruction(address(ingress)).recordPreimageBytes(hash)
                    ) == keccak256(value),
            "event preimage equals immutable carrier"
        );
    }

    function testAuthorityEventsRotationStageIsNotExecutionThenExactOriginalCarrier() public {
        _newRotationSafe(17001);
        vm.recordLogs();
        bytes32 hash = _stageRotation(0);
        Vm.Log[] memory stage = vm.getRecordedLogs();
        ArtistAuthorityEventReader reader = new ArtistAuthorityEventReader();
        ArtistAuthorityEventReader.Row memory row = reader.rotation(stage, _pins());
        require(!row.executed && row.transition.phase == 1, "staged only");
        vm.recordLogs();
        _executeTimedRotation(hash);
        Vm.Log[] memory logs = _concat(stage, vm.getRecordedLogs());
        row = reader.rotation(logs, _pins());
        require(
            row.executed && row.recordHash == hash && row.authorityClass == 1
                && row.newAddress == address(rotationSafe),
            "actual executed rotation"
        );
        require(
            keccak256(abi.encode(row.transition))
                == keccak256(abi.encode(ingress.rotationRecord(hash).transition)),
            "exact execution timing"
        );
        _carrier(hash, row.preimage);
        require(
            _identity().identity(artistId).authorityAddress == row.newAddress,
            "current authority reconstructed"
        );
    }

    function testAuthorityEventsEstateRequestIsNotVestingThenExactExecutionFacts() public {
        vm.recordLogs();
        Estate.Execution memory p = _estatePendingFixture(256);
        Vm.Log[] memory request = vm.getRecordedLogs();
        ArtistAuthorityEventReader reader = new ArtistAuthorityEventReader();
        ArtistAuthorityEventReader.Row memory row = reader.estate(request, _pins());
        require(!row.executed && row.transition.phase == 1, "request only");
        (Estate.RequestRecord memory saved,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        vm.warp(saved.noticeEndsAt);
        vm.recordLogs();
        ingress.executeEstateActivation(p);
        row = reader.estate(_concat(request, vm.getRecordedLogs()), _pins());
        (,, Estate.ExecutionFacts memory facts) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        require(
            row.executed && row.oldAddress == saved.incumbent && row.authorityClass == 3
                && keccak256(abi.encode(row.estateExecution)) == keccak256(abi.encode(facts)),
            "actual saved estate execution"
        );
        _carrier(row.recordHash, row.preimage);
        require(
            keccak256(abi.encode(row.transition))
                == keccak256(abi.encode(ingress.artistTransitionState(row.recordHash))),
            "actual estate window"
        );
    }

    function _refuse(ArtistAuthorityEventReader reader, bytes memory input) internal {
        (bool ok,) = address(reader).staticcall(input);
        require(!ok, "invalid log history accepted");
    }

    function testAuthorityEventsRotationRejectsMissingDuplicateAndForeignExecutionContext() public {
        _newRotationSafe(17002);
        vm.recordLogs();
        bytes32 hash = _stageRotation(0);
        Vm.Log[] memory stage = vm.getRecordedLogs();
        vm.recordLogs();
        _executeTimedRotation(hash);
        Vm.Log[] memory execution = vm.getRecordedLogs();
        ArtistAuthorityEventReader reader = new ArtistAuthorityEventReader();
        Vm.Log[] memory logs = _concat(stage, execution);
        _refuse(reader, abi.encodeCall(reader.rotation, (execution, _pins())));
        _refuse(reader, abi.encodeCall(reader.rotation, (_concat(logs, execution), _pins())));
        uint256 index = _contextIndex(
            logs,
            keccak256(
                "ArtistRotationExecutionContext(uint16,bytes32,bytes32,(uint256,address,address,address,uint8),(bytes32,bytes32,uint64,uint64,uint64,uint64,uint64,uint8),uint8)"
            )
        );
        bytes memory original = logs[index].data;
        address emitter = logs[index].emitter;
        logs[index].emitter = address(0xBAD);
        _refuse(reader, abi.encodeCall(reader.rotation, (logs, _pins())));
        logs[index].emitter = emitter;
        logs[index].data = original;
        (uint16 schema, DE.Context memory c, R.TransitionState memory t, uint8 class_) =
            abi.decode(original, (uint16, DE.Context, R.TransitionState, uint8));
        c.chainId += 1;
        logs[index].data = abi.encode(schema, c, t, class_);
        _refuse(reader, abi.encodeCall(reader.rotation, (logs, _pins())));
        logs[index].emitter = emitter;
        logs[index].data = original;
        require(reader.rotation(logs, _pins()).executed, "exact restored event pair");
    }

    function testAuthorityEventsEstateRejectsMissingRequestAndWrongActivationBacklink() public {
        vm.recordLogs();
        Estate.Execution memory p = _estatePendingFixture(256);
        Vm.Log[] memory request = vm.getRecordedLogs();
        (Estate.RequestRecord memory n,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        vm.warp(n.noticeEndsAt);
        vm.recordLogs();
        ingress.executeEstateActivation(p);
        Vm.Log[] memory execution = vm.getRecordedLogs();
        ArtistAuthorityEventReader reader = new ArtistAuthorityEventReader();
        _refuse(reader, abi.encodeCall(reader.estate, (execution, _pins())));
        Vm.Log[] memory logs = _concat(request, execution);
        uint256 index = _contextIndex(
            logs,
            keccak256(
                "ArtistEstateExecutionContext(uint16,bytes32,bytes32,(uint256,address,address,address,uint8),address,(bytes32,bytes32,uint64,uint64,uint64,uint64,uint64,uint8),(bytes32,bytes32,uint32,uint64,bytes32,bytes32,uint64))"
            )
        );
        bytes memory original = logs[index].data;
        (
            uint16 schema,
            DE.Context memory c,
            address incumbent,
            R.TransitionState memory t,
            Estate.ExecutionFacts memory facts
        ) = abi.decode(
            original, (uint16, DE.Context, address, R.TransitionState, Estate.ExecutionFacts)
        );
        facts.activationRecordHash = keccak256("foreign activation");
        logs[index].data = abi.encode(schema, c, incumbent, t, facts);
        _refuse(reader, abi.encodeCall(reader.estate, (logs, _pins())));
        logs[index].data = original;
        require(reader.estate(logs, _pins()).executed, "exact restored original estate proof");
    }

    function _contextIndex(Vm.Log[] memory logs, bytes32 topic) internal view returns (uint256) {
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2] && logs[i].topics.length != 0
                    && logs[i].topics[0] == topic
            ) return i;
        }
        revert("context absent");
    }

    function testAuthorityEventsExistingRecoveryIsCompleteWithLateArchiveIdenticalRetry() public {
        this.prepareDormancyOrigin(false);
        this.completeDormancyOrigin();
        this.fileDormancyRecoveryCause(false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.prepareDormancyRecovery(keccak256("event-only existing class3 recovery"));
        this.enterDormancyExecution();
        bytes32 roots = _roots();
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateRecoveryArchive.selector)
        );
        // First attempt reaches Archive; retry cannot alone satisfy the exact two-call witness.
        AuthorityEventCallVm(address(vm))
            .expectCall(
                suite.archive,
                abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
                uint64(2)
            );
        vm.recordLogs();
        (bool ok, bytes memory why) =
            address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        require(
            !ok
                && keccak256(why)
                    == keccak256(abi.encodeWithSelector(LateRecoveryArchive.selector)),
            "exact late Archive failure"
        );
        vm.getRecordedLogs();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0,
            "all original state rolls back"
        );
        avm.clearMockedCalls();
        _publish();
        vm.recordLogs();
        bytes32 hash = this.executeRegistered(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        ArtistAuthorityEventReader reader = new ArtistAuthorityEventReader();
        (bytes32 rebuilt, bytes memory preimage, PR.RecordFields memory fields) =
            reader.recovery(logs, _pins());
        require(
            rebuilt == hash
                && keccak256(abi.encode(fields))
                    == keccak256(abi.encode(ingress.identityRecoveryRecord(hash).fields)),
            "all nine original event fields"
        );
        _carrier(hash, preimage);
        _refuse(reader, abi.encodeCall(reader.recovery, (_concat(logs, logs), _pins())));
        ArtistAuthorityEventReader.Pins memory foreign = _pins();
        foreign.registry = address(0xBAD);
        _refuse(reader, abi.encodeCall(reader.recovery, (logs, foreign)));
    }
}
