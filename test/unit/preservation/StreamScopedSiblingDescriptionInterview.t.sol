// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamConservationRecordTypes as C
} from "../../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    StreamWorkRecordTypes as W
} from "../../../smart-contracts/interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamRightsRecordTypes as R
} from "../../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamPreservationTypedReferences as References
} from "../../../smart-contracts/domains/preservation/StreamPreservationTypedReferences.sol";

interface SiblingStageVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function expectRevert(bytes calldata) external;
}

interface SiblingStageHarness {
    function seed(uint8 kind) external returns (bytes32);
    function phase(uint16 value) external;
    function count(uint64 value) external;
    function source(uint8 drift) external view returns (address, bytes memory, bytes memory);
    function work(bytes calldata input) external;
    function rights(bytes calldata input) external;
    function interview(bytes calldata input) external;
    function waiver() external;
    function progress() external view returns (T.Plan memory);
    function segment(uint64 index) external view returns (T.Segment memory);
    function canary() external view returns (bytes32);
    function storedDrift(uint8 mode) external;
}
import {
    StreamScopedPreservationPolicyRenderCriticalStateV1 as State0
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalDescriptionStagesV1 as Description0
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalDescriptionStagesV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalSourceReadsV1 as Source0
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalInterviewStageV1 as Interview0
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalInterviewStageV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Context0
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2 as State1
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalDescriptionStagesV2 as Description1
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalDescriptionStagesV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2 as Source1
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalInterviewStageV2 as Interview1
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalInterviewStageV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Context1
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State2
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDescriptionStagesV1 as Description2
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDescriptionStagesV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1 as Source2
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInterviewStageV1 as Interview2
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInterviewStageV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Context2
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalState as State3
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalState.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalDescriptionStages as Description3
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalDescriptionStages.sol";
import {
    StreamMultiOriginScopedRenderCriticalSourceReads as Source3
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedRenderCriticalSourceReads.sol";
import {
    StreamScopedRenderCriticalTypes as Context3
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";

/// @dev Typed family 0: actual stage/state code; complete current/authority replies are mocked.
contract OriginalPreservationStageHarness is SiblingStageHarness {
    State0.State private state;
    bytes32 private id;
    bytes32 private constant LINEAGE = keccak256("original lineage");
    bytes32 public canary = keccak256("untouched sibling storage");

    function seed(uint8 kind) external returns (bytes32) {
        Context0.Context memory c;
        c.scope = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            17,
            kind == 1 ? 301 : 0,
            kind == 1 ? bytes32(0) : keccak256("scope")
        );
        c.subject = keccak256("subject");
        c.artistId = keccak256("artist");
        c.interviewEvidenceHash = keccak256("waiver evidence");
        c.conservation.interviewStatus = C.InterviewStatus.WAIVED;
        c.conservation.record.recordHash = keccak256("conservation record");
        state.dependencies.targets[1] = address(0x1234);
        state.dependencies.chainId = block.chainid;
        state.dependencyHash = keccak256("dependencies");

        id = State0.idFor(state.dependencyHash, c);
        state.contexts[id] = c;
        state.plans[id].scope = c.scope;
        state.plans[id].progress.collectionId = 17;
        state.plans[id].progress.completedStages = 5;

        return id;
    }

    function phase(uint16 value) external {
        state.plans[id].progress.completedStages = value;
    }

    function count(uint64 value) external {
        state.plans[id].progress.segmentCount = value;
    }

    function source(uint8 drift) external view returns (address, bytes memory, bytes memory) {
        Context0.Context memory c = state.contexts[id];
        if (drift == 1) c.subject = keccak256("foreign subject");
        O.Origin memory empty;
        return (
            address(Source0),
            abi.encodeWithSelector(Source0.current.selector, state.dependencies, c.scope),
            abi.encode(c)
        );
    }

    function work(bytes calldata input) external {
        Description0.appendWork(state, input);
    }

    function rights(bytes calldata input) external {
        Description0.appendRights(state, input);
    }

    function interview(bytes calldata input) external {
        Interview0.appendInterview(state, input);
    }

    function waiver() external {
        Interview0.appendInterviewWaiver(state, id);
    }

    function progress() external view returns (T.Plan memory) {
        return state.plans[id].progress;
    }

    function segment(uint64 index) external view returns (T.Segment memory) {
        return state.segments[id][index];
    }

    function storedDrift(uint8 mode) external {
        state.dependencyHash = mode == 0 ? keccak256("dependencies") : bytes32(uint256(44));
    }
}

/// @dev Typed family 1: actual stage/state code; complete current/authority replies are mocked.
contract CurrentPolicyStageHarness is SiblingStageHarness {
    State1.State private state;
    bytes32 private id;
    bytes32 private constant LINEAGE = keccak256("original lineage");
    bytes32 public canary = keccak256("untouched sibling storage");

    function seed(uint8 kind) external returns (bytes32) {
        Context1.Context memory c;
        c.scope = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            17,
            kind == 1 ? 301 : 0,
            kind == 1 ? bytes32(0) : keccak256("scope")
        );
        c.subject = keccak256("subject");
        c.artistId = keccak256("artist");
        c.interviewEvidenceHash = keccak256("waiver evidence");
        c.conservation.interviewStatus = C.InterviewStatus.WAIVED;
        c.conservation.record.recordHash = keccak256("conservation record");
        state.dependencies.targets[1] = address(0x1234);
        state.dependencies.chainId = block.chainid;
        state.dependencyHash = keccak256("dependencies");
        state.authority.capture.dependencies = state.dependencies;
        state.authority.capture.selection.selectionHash = keccak256("selected authority");

        id = State1.idFor(state.dependencyHash, state.authority.capture, c, LINEAGE);
        state.contexts[id] = c;
        state.plans[id].scope = c.scope;
        state.plans[id].progress.collectionId = 17;
        state.plans[id].progress.completedStages = 5;
        state.origins.lineage[id] = LINEAGE;
        state.plans[id].progress.sourceContextHash =
            D.contextHash(state.authority.capture, keccak256(abi.encode(c)), LINEAGE);
        return id;
    }

    function phase(uint16 value) external {
        state.plans[id].progress.completedStages = value;
    }

    function count(uint64 value) external {
        state.plans[id].progress.segmentCount = value;
    }

    function source(uint8 drift) external view returns (address, bytes memory, bytes memory) {
        Context1.Context memory c = state.contexts[id];
        if (drift == 1) c.subject = keccak256("foreign subject");
        O.Origin memory empty;
        return (
            address(Source1),
            abi.encodeWithSelector(
                Source1.current.selector, state.dependencies, state.origins.dependencies, c.scope
            ),
            abi.encode(c, empty, empty, drift == 2 ? bytes32(uint256(123)) : LINEAGE)
        );
    }

    function work(bytes calldata input) external {
        Description1.appendWork(state, input);
    }

    function rights(bytes calldata input) external {
        Description1.appendRights(state, input);
    }

    function interview(bytes calldata input) external {
        Interview1.appendInterview(state, input);
    }

    function waiver() external {
        Interview1.appendInterviewWaiver(state, id);
    }

    function progress() external view returns (T.Plan memory) {
        return state.plans[id].progress;
    }

    function segment(uint64 index) external view returns (T.Segment memory) {
        return state.segments[id][index];
    }

    function storedDrift(uint8 mode) external {
        if (mode == 1) {
            state.origins.lineage[id] = bytes32(uint256(44));
        } else if (mode == 2) {
            state.plans[id].progress.sourceContextHash = bytes32(uint256(55));
        } else {
            state.origins.lineage[id] = LINEAGE;
            state.plans[id].progress.sourceContextHash = D.contextHash(
                state.authority.capture, keccak256(abi.encode(state.contexts[id])), LINEAGE
            );
        }
    }
}

/// @dev Typed family 2: actual stage/state code; complete current/authority replies are mocked.
contract CurrentPreservationStageHarness is SiblingStageHarness {
    State2.State private state;
    bytes32 private id;
    bytes32 private constant LINEAGE = keccak256("original lineage");
    bytes32 public canary = keccak256("untouched sibling storage");

    function seed(uint8 kind) external returns (bytes32) {
        Context2.Context memory c;
        c.scope = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            17,
            kind == 1 ? 301 : 0,
            kind == 1 ? bytes32(0) : keccak256("scope")
        );
        c.subject = keccak256("subject");
        c.artistId = keccak256("artist");
        c.interviewEvidenceHash = keccak256("waiver evidence");
        c.conservation.interviewStatus = C.InterviewStatus.WAIVED;
        c.conservation.record.recordHash = keccak256("conservation record");
        state.dependencies.targets[1] = address(0x1234);
        state.dependencies.chainId = block.chainid;
        state.dependencyHash = keccak256("dependencies");
        state.authority.capture.dependencies = state.dependencies;
        state.authority.capture.selection.selectionHash = keccak256("selected authority");

        id = State2.idFor(state.dependencyHash, state.authority.capture, c, LINEAGE);
        state.contexts[id] = c;
        state.plans[id].scope = c.scope;
        state.plans[id].progress.collectionId = 17;
        state.plans[id].progress.completedStages = 5;
        state.origins.lineage[id] = LINEAGE;
        state.plans[id].progress.sourceContextHash =
            D.contextHash(state.authority.capture, keccak256(abi.encode(c)), LINEAGE);
        return id;
    }

    function phase(uint16 value) external {
        state.plans[id].progress.completedStages = value;
    }

    function count(uint64 value) external {
        state.plans[id].progress.segmentCount = value;
    }

    function source(uint8 drift) external view returns (address, bytes memory, bytes memory) {
        Context2.Context memory c = state.contexts[id];
        if (drift == 1) c.subject = keccak256("foreign subject");
        O.Origin memory empty;
        return (
            address(Source2),
            abi.encodeWithSelector(
                Source2.current.selector, state.dependencies, state.origins.dependencies, c.scope
            ),
            abi.encode(c, empty, empty, drift == 2 ? bytes32(uint256(123)) : LINEAGE)
        );
    }

    function work(bytes calldata input) external {
        Description2.appendWork(state, input);
    }

    function rights(bytes calldata input) external {
        Description2.appendRights(state, input);
    }

    function interview(bytes calldata input) external {
        Interview2.appendInterview(state, input);
    }

    function waiver() external {
        Interview2.appendInterviewWaiver(state, id);
    }

    function progress() external view returns (T.Plan memory) {
        return state.plans[id].progress;
    }

    function segment(uint64 index) external view returns (T.Segment memory) {
        return state.segments[id][index];
    }

    function storedDrift(uint8 mode) external {
        if (mode == 1) {
            state.origins.lineage[id] = bytes32(uint256(44));
        } else if (mode == 2) {
            state.plans[id].progress.sourceContextHash = bytes32(uint256(55));
        } else {
            state.origins.lineage[id] = LINEAGE;
            state.plans[id].progress.sourceContextHash = D.contextHash(
                state.authority.capture, keccak256(abi.encode(state.contexts[id])), LINEAGE
            );
        }
    }
}

/// @dev Typed family 3: actual stage/state code; complete current/authority replies are mocked.
contract CurrentScopedStageHarness is SiblingStageHarness {
    State3.State private state;
    bytes32 private id;
    bytes32 private constant LINEAGE = keccak256("original lineage");
    bytes32 public canary = keccak256("untouched sibling storage");

    function seed(uint8 kind) external returns (bytes32) {
        Context3.Context memory c;
        c.scope = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            17,
            kind == 1 ? 301 : 0,
            kind == 1 ? bytes32(0) : keccak256("scope")
        );
        c.subject = keccak256("subject");
        c.artistId = keccak256("artist");
        c.interviewEvidenceHash = keccak256("waiver evidence");
        c.conservation.interviewStatus = C.InterviewStatus.WAIVED;
        c.conservation.record.recordHash = keccak256("conservation record");
        state.dependencies.targets[1] = address(0x1234);
        state.dependencies.chainId = block.chainid;
        state.dependencyHash = keccak256("dependencies");
        state.authority.capture.dependencies = state.dependencies;
        state.authority.capture.selection.selectionHash = keccak256("selected authority");

        id = State3.idFor(state.dependencyHash, state.authority.capture, c, LINEAGE);
        state.contexts[id] = c;
        state.plans[id].scope = c.scope;
        state.plans[id].progress.collectionId = 17;
        state.plans[id].progress.completedStages = 5;
        state.origins.lineage[id] = LINEAGE;
        state.plans[id].progress.sourceContextHash =
            D.contextHash(state.authority.capture, keccak256(abi.encode(c)), LINEAGE);
        return id;
    }

    function phase(uint16 value) external {
        state.plans[id].progress.completedStages = value;
    }

    function count(uint64 value) external {
        state.plans[id].progress.segmentCount = value;
    }

    function source(uint8 drift) external view returns (address, bytes memory, bytes memory) {
        Context3.Context memory c = state.contexts[id];
        if (drift == 1) c.subject = keccak256("foreign subject");
        O.Origin memory empty;
        return (
            address(Source3),
            abi.encodeWithSelector(
                Source3.current.selector, state.dependencies, state.origins.dependencies, c.scope
            ),
            abi.encode(c, empty, empty, drift == 2 ? bytes32(uint256(123)) : LINEAGE)
        );
    }

    function work(bytes calldata input) external {
        Description3.appendWork(state, input);
    }

    function rights(bytes calldata input) external {
        Description3.appendRights(state, input);
    }

    function interview(bytes calldata input) external {
        revert("no interview in owned legacy subset");
    }

    function waiver() external {
        revert("no interview in owned legacy subset");
    }

    function progress() external view returns (T.Plan memory) {
        return state.plans[id].progress;
    }

    function segment(uint64 index) external view returns (T.Segment memory) {
        return state.segments[id][index];
    }

    function storedDrift(uint8 mode) external {
        if (mode == 1) {
            state.origins.lineage[id] = bytes32(uint256(44));
        } else if (mode == 2) {
            state.plans[id].progress.sourceContextHash = bytes32(uint256(55));
        } else {
            state.origins.lineage[id] = LINEAGE;
            state.plans[id].progress.sourceContextHash = D.contextHash(
                state.authority.capture, keccak256(abi.encode(state.contexts[id])), LINEAGE
            );
        }
    }
}

/// @notice Focused seven-host routing regression; no actual resolver/source admission claim.
contract StreamScopedSiblingDescriptionInterviewTest {
    SiblingStageVm private constant vm =
        SiblingStageVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _host(uint256 family, uint8 kind) private returns (SiblingStageHarness h, bytes32 id) {
        if (family == 0) h = new OriginalPreservationStageHarness();
        else if (family == 1) h = new CurrentPolicyStageHarness();
        else if (family == 2) h = new CurrentPreservationStageHarness();
        else h = new CurrentScopedStageHarness();
        id = h.seed(kind);
        _reply(h, 0);
        vm.mockCall(
            address(Authority), abi.encodeWithSelector(Authority.requireCurrent.selector), hex""
        );
    }

    function _reply(SiblingStageHarness h, uint8 drift) private {
        (address target, bytes memory input, bytes memory output) = h.source(drift);
        vm.mockCall(target, input, output);
    }

    function _input(bytes32 id, uint256 family, uint8 kind) private pure returns (bytes memory) {
        if (kind == 1) {
            R.Statement memory w;
            return abi.encodePacked(bytes4(0x01020304), abi.encode(id, w));
        }
        O.ReceiptWitness memory receipt;
        if (kind == 0) {
            W.Description memory w;
            return abi.encodePacked(
                bytes4(0x01020304),
                family == 0 ? abi.encode(id, w, address(0)) : abi.encode(id, w, address(0), receipt)
            );
        }
        C.Interview memory w;
        return abi.encodePacked(
            bytes4(0x01020304),
            family == 0 ? abi.encode(id, w, address(0)) : abi.encode(id, w, address(0), receipt)
        );
    }

    function testSevenHostsKeepDecoderBeforeGuard() external {
        for (uint256 f; f < 4; ++f) {
            (SiblingStageHarness h,) = _host(f, 1);
            h.phase(0);
            (bool ok, bytes memory reason) =
                address(h).call(abi.encodeCall(h.work, (hex"01020304")));
            require(!ok && reason.length == 0, "work decoder");
            (ok, reason) = address(h).call(abi.encodeCall(h.rights, (hex"01020304")));
            require(!ok && reason.length == 0, "rights decoder");
            if (f < 3) {
                (ok, reason) = address(h).call(abi.encodeCall(h.interview, (hex"01020304")));
                require(!ok && reason.length == 0, "interview decoder");
            }
        }
    }

    function testAllOwnedEntriesKeepStageBeforeSourceOrAuthority() external {
        for (uint256 f; f < 4; ++f) {
            (SiblingStageHarness h, bytes32 id) = _host(f, 1);
            h.phase(0);
            bytes memory w = _input(id, f, 0);
            bytes memory r = _input(id, f, 1);
            bytes memory i = _input(id, f, 2);
            vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
            h.work(w);
            vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
            h.rights(r);
            if (f < 3) {
                vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
                h.interview(i);
                vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
                h.waiver();
            }
            require(
                h.progress().segmentCount == 0
                    && h.canary() == keccak256("untouched sibling storage"),
                "guard wrote"
            );
        }
    }

    function testAllSevenHostsRejectFullContextDriftAndRestore() external {
        for (uint256 f; f < 4; ++f) {
            (SiblingStageHarness h, bytes32 id) = _host(f, 2);
            _reply(h, 1);
            bytes memory w = _input(id, f, 0);
            bytes memory r = _input(id, f, 1);
            bytes memory i = _input(id, f, 2);
            h.phase(2);
            vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
            h.work(w);
            h.phase(3);
            vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
            h.rights(r);
            if (f < 3) {
                h.phase(5);
                vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
                h.interview(i);
                vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
                h.waiver();
            }
            _reply(h, 0);
            if (f < 3) {
                vm.expectRevert(abi.encodeWithSelector(T.InvalidInventoryItem.selector));
                h.interview(i);
                _waiver(h, id, f);
            } else {
                _postGuard(h, id, f);
            }
        }
    }

    function testCurrentAuthorityFailurePrecedesSourceAndSurvivesRestoration() external {
        for (uint256 f = 1; f < 4; ++f) {
            (SiblingStageHarness h, bytes32 id) = _host(f, 3);
            h.phase(3);
            (address target, bytes memory input,) = h.source(0);
            bytes memory authorityFailure =
                abi.encodeWithSignature("OriginalAuthorityFailure(uint256)", f);
            bytes memory sourceFailure =
                abi.encodeWithSignature("OriginalSourceFailure(uint256)", f);
            vm.mockCallRevert(target, input, sourceFailure);
            vm.mockCallRevert(
                address(Authority),
                abi.encodeWithSelector(Authority.requireCurrent.selector),
                authorityFailure
            );
            bytes memory r = _input(id, f, 1);
            vm.expectRevert(authorityFailure);
            h.rights(r);
            vm.clearMockedCalls();
            vm.mockCallRevert(target, input, sourceFailure);
            vm.mockCall(
                address(Authority), abi.encodeWithSelector(Authority.requireCurrent.selector), hex""
            );
            vm.expectRevert(sourceFailure);
            h.rights(r);
            vm.clearMockedCalls();
            _reply(h, 0);
            vm.mockCall(
                address(Authority), abi.encodeWithSelector(Authority.requireCurrent.selector), hex""
            );
            require(h.progress().segmentCount == 0, "failure wrote");
            _postGuard(h, id, f);
        }
    }

    function testCurrentStoredLineageAndContextCommitmentsStayRequired() external {
        for (uint256 f = 1; f < 4; ++f) {
            (SiblingStageHarness h, bytes32 id) = _host(f, 1);
            h.phase(3);
            bytes memory r = _input(id, f, 1);
            for (uint8 mode = 1; mode <= 2; ++mode) {
                h.storedDrift(mode);
                vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
                h.rights(r);
                h.storedDrift(0);
            }
            _reply(h, 2);
            vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
            h.rights(r);
            _reply(h, 0);
            if (f < 3) {
                h.phase(5);
                _waiver(h, id, f);
            } else {
                _postGuard(h, id, f);
            }
        }
    }

    function testThreeWaiversRollBackLateWriteAndRetryExactRequest() external {
        for (uint256 f; f < 3; ++f) {
            (SiblingStageHarness h, bytes32 id) = _host(f, 1);
            h.count(type(uint64).max);
            vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
            h.waiver();
            T.Plan memory p = h.progress();
            require(
                p.segmentCount == type(uint64).max && p.itemCount == 0 && p.segmentChainHash == 0
                    && p.completedStages == 5,
                "rollback plan"
            );
            require(h.segment(type(uint64).max).key == 0, "rollback row");
            h.count(0);
            _waiver(h, id, f);
        }
    }

    function testFuzzThreeFamilyLiteralWaiver(uint8 kind) external {
        for (uint256 f; f < 3; ++f) {
            (SiblingStageHarness h, bytes32 id) = _host(f, 1 + kind % 3);
            _waiver(h, id, f);
        }
    }

    function _postGuard(SiblingStageHarness h, bytes32 id, uint256 family) private {
        h.phase(3);
        bytes memory r = _input(id, family, 1);
        bytes memory stop =
            abi.encodeWithSignature("AuthenticatedCurrentReachedReference(uint256)", family);
        vm.mockCallRevert(
            address(References), abi.encodeWithSelector(References.rights.selector), stop
        );
        vm.expectRevert(stop);
        h.rights(r);
    }

    function _waiver(SiblingStageHarness h, bytes32 id, uint256 family) private {
        T.Item memory item;
        item.kind = T.Kind.ABSENT;
        item.role = keccak256("INTERVIEW_ORIGINAL_EXPLICITLY_WAIVED");
        item.source = address(0x1234);
        item.sourceRecord = keccak256("conservation record");
        item.provenanceHash = keccak256("waiver evidence");
        bytes32 domain = family == 1
            ? keccak256("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_SEGMENT_V2")
            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_RENDER_CRITICAL_SEGMENT_V1");
        bytes32 key = keccak256(abi.encode(domain, id, uint64(0)));
        bytes32 itemHash = keccak256(abi.encode(keccak256("6529STREAM_PRESERVATION_ITEM_V1"), item));
        bytes32 link = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_ITEM_LINK_V1"),
                key,
                uint64(1),
                uint64(0),
                itemHash,
                bytes32(0)
            )
        );
        T.Segment memory expected = T.Segment(key, 1, link, keccak256("waiver evidence"));
        bytes32 chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_SEGMENT_V1"), bytes32(0), uint64(0), expected
            )
        );
        h.waiver();
        T.Plan memory p = h.progress();
        require(
            p.completedStages == 6 && p.segmentCount == 1 && p.itemCount == 1
                && p.segmentChainHash == chain,
            "literal waiver chain"
        );
        require(
            keccak256(abi.encode(h.segment(0))) == keccak256(abi.encode(expected)), "full segment"
        );
        require(h.canary() == keccak256("untouched sibling storage"), "storage canary");
    }
}
