// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2 as PolicyState
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalStageGuardV2 as PolicyGuard
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalStageGuardV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2 as PolicySources
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Policy
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as PreservationState
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStageGuardV1 as PreservationGuard
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStageGuardV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1 as PreservationSources
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Preservation
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalState as ScopedState
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalState.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalStageGuard as ScopedGuard
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalStageGuard.sol";
import {
    StreamMultiOriginScopedRenderCriticalSourceReads as ScopedSources
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedRenderCriticalSourceReads.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamCurrentAuthorityInventoryTypes as Current
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as Artist
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamArtistArchiveOriginTypes as Origin
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as Source
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface CurrentFamilyStageVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function mockCallRevert(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @dev Synthetic boundary tests only: Authority.requireCurrent and the precise typed
/// Sources.current library call are mocked. No real current authority, publication,
/// Archive, completed inventory stage, or deployment/gas acceptance is claimed.
/// Each child owns its actual compiler-typed State at a nonzero storage root.
abstract contract CurrentFamilyStageHarness {
    uint256[3] internal prefix = [uint256(0xA001), uint256(0xA002), uint256(0xA003)];
    bytes32 public id;
    bytes32 internal constant LINEAGE = keccak256("stage guard original lineage");
    bytes32 internal constant CAPTURE = keccak256("stage guard captured authority selection");
    bytes32 internal constant DEPENDENCY = keccak256("stage guard immutable dependency hash");

    function configure(uint16 stage) external virtual returns (bytes32);
    function sourceLibrary() external pure virtual returns (address);
    function sourceCall() external view virtual returns (bytes memory);
    function sourceResult(uint8 mutation) external view virtual returns (bytes memory);
    function corrupt(uint8 mutation) external virtual;
    function fingerprint() public view virtual returns (bytes32);
    function _stage(bool linked, bytes32 plan, uint16 expected) internal view virtual;

    function probe(bool linked, bytes32 plan, uint16 expected, bytes calldata input)
        external
        view
        returns (bytes32 leftHash, bytes32 rightHash, bytes32 stateHash)
    {
        bytes memory left = abi.encode(bytes32(uint256(0xA11CE)), input, plan);
        bytes memory right = abi.encode(input, uint256(0xB0B), expected, address(this));
        leftHash = keccak256(left);
        rightHash = keccak256(right);
        stateHash = fingerprint();
        _stage(linked, plan, expected);
        require(keccak256(left) == leftHash && keccak256(right) == rightHash, "memory canaries");
        require(fingerprint() == stateHash, "typed storage and adjacent canaries unchanged");
    }

    function expectedResult(bytes32 plan, uint16 expected, bytes calldata input)
        external
        view
        returns (bytes memory)
    {
        return abi.encode(
            keccak256(abi.encode(bytes32(uint256(0xA11CE)), input, plan)),
            keccak256(abi.encode(input, uint256(0xB0B), expected, address(this))),
            fingerprint()
        );
    }

    function _dependencies() internal view returns (Source.Dependencies memory d) {
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(uint160(0x1000 + i));
            d.codeHashes[i] = keccak256(abi.encode("fixed source", i));
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = address(uint160(0x2000 + i));
            d.artistCodeHashes[i] = keccak256(abi.encode("fixed artist source", i));
        }
        d.artistContentOwner = address(0x3000);
        d.artistContentOwnerCodeHash = keccak256("content owner runtime");
        d.chainId = block.chainid;
        d.readGas = 100000;
        d.sourceGas = 200000;
        d.selectionGas = 300000;
        d.snapshotGas = 400000;
        d.referenceGas = 500000;
    }

    function _origins() internal pure returns (Origin.Dependencies memory) {
        return Origin.Dependencies(
            address(0x4000), keccak256("origin worker runtime"), 600000, Origin.PROFILE
        );
    }

    function _origin(bool presented) internal view returns (Origin.Origin memory o) {
        o.environment.chainId = block.chainid;
        o.environment.registry = presented ? address(0x5100) : address(0x5200);
        o.environment.coordinator = address(0x5300);
        o.environment.archive = address(0x5400);
        o.environment.core = address(0x1000);
        o.environment.manager = address(0x5500);
        o.environment.suiteConfigurationHash = keccak256(abi.encode("suite", presented));
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = address(uint160(0x6000 + i));
            o.environment.ownerCodeHashes[i] = keccak256(abi.encode("owner", i, presented));
        }
        o.registryCodeHash = keccak256("registry runtime");
        o.coordinatorCodeHash = keccak256("coordinator runtime");
        o.archiveCodeHash = keccak256("archive runtime");
    }

    function _capture(Source.Dependencies memory d)
        internal
        view
        returns (Current.Capture memory c)
    {
        c.dependencies = d;
        c.selection.origin = _origin(false);
        c.selection.completion = keccak256("current completion");
        c.selection.selectionHash = CAPTURE;
    }

    function _contextHash(Current.Capture memory c, bytes32 typedHash)
        internal
        pure
        returns (bytes32)
    {
        // Literal independent oracle, not State.idFor or Current.contextHash.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_AUTHORITY_INVENTORY_CONTEXT_V1"),
                c.selection.selectionHash,
                keccak256(abi.encode(c.dependencies)),
                typedHash,
                LINEAGE
            )
        );
    }
}

contract CurrentPolicyStageHarness is CurrentFamilyStageHarness {
    PolicyState.State private state;
    uint256 private suffix = 0xB004;

    function configure(uint16 expected) external override returns (bytes32) {
        Source.Dependencies memory d = _dependencies();
        Current.Capture memory captured = _capture(d);
        Policy.Context memory c = _context();
        state.authority.config.originalAnchor = d;
        state.authority.config.authority =
            Current.Dependencies(address(0x7000), keccak256("resolver runtime"), 800000);
        state.authority.capture = captured;
        state.origins.dependencies = _origins();
        state.dependencies = d;
        state.dependencyHash = DEPENDENCY;
        bytes32 contextHash = _contextHash(captured, keccak256(abi.encode(c)));
        id = keccak256(
            abi.encode(
                Current.SCOPED_POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                DEPENDENCY,
                contextHash
            )
        );
        require(
            PolicyState.idFor(DEPENDENCY, captured, c, LINEAGE) == id,
            "literal host-specific plan identity"
        );
        Policy.Plan memory p;
        p.scope = c.scope;
        p.progress = Inventory.Plan(
            c.scope.collectionId,
            c.subject,
            c.artistId,
            contextHash,
            c.tokenCount,
            1,
            3,
            17,
            keccak256("existing segment chain"),
            expected,
            bytes32(0)
        );
        p.nativeCount = 11;
        p.referenceCount = 13;
        state.plans[id] = p;
        state.contexts[id] = c;
        state.origins.lineage[id] = LINEAGE;
        return id;
    }

    function _context() private pure returns (Policy.Context memory c) {
        c.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 9, 91, bytes32(0));
        c.subject = keccak256("exact scope subject");
        c.artistId = keccak256("historical artist");
        c.snapshot.scopeSubject = c.subject;
        c.snapshot.recordHash = keccak256("original snapshot record");
        c.snapshot.revision = 3;
        c.referenceRender.scopeSubject = c.subject;
        c.referenceRender.observation.recordHash = keccak256("original reference record");
        c.referenceRender.observation.revision = 5;
        c.descriptions.scopeSubject = c.subject;
        c.interviewEvidenceHash = keccak256("interview evidence");
        c.nativeHash = keccak256("native source");
        c.rootRecordHash = keccak256("original content root");
        c.tokenInventoryHash = keccak256("membership");
        c.checkpointHash = keccak256("checkpoint");
        c.outputManifestRecord = keccak256("original output manifest");
        c.selectionId = keccak256("content selection id");
        c.selectionHash = keccak256("content selection hash");
        c.tokenCount = 1;
        c.snapshotSource.scope = c.scope;
    }

    function sourceLibrary() external pure override returns (address) {
        return address(PolicySources);
    }

    function sourceCall() external view override returns (bytes memory) {
        return abi.encodeWithSelector(
            PolicySources.current.selector,
            state.dependencies,
            state.origins.dependencies,
            state.plans[id].scope
        );
    }

    function sourceResult(uint8 mutation) external view override returns (bytes memory) {
        Policy.Context memory c = _context();
        bytes32 lineage = LINEAGE;
        if (mutation == 1) {
            c.rootRecordHash = keccak256("changed root");
        } else if (mutation == 2) {
            c.snapshot.recordHash = keccak256("changed snapshot");
        } else if (mutation == 3) {
            ++c.scope.collectionId;
        } else if (mutation == 4) {
            c.selectionHash = keccak256("changed selection");
        } else if (mutation == 5) {
            c.referenceRender.observation.recordHash = keccak256("changed reference");
        } else if (mutation == 6) {
            lineage = keccak256("changed lineage");
        } else if (mutation == 7) {
            ++c.tokenCount;
        } else if (mutation == 8) {
            c.subject = keccak256("changed subject");
        } else {
            require(mutation == 0, "known source mutation");
        }
        // Full canonical four-value return of THIS family. No cross-family decode.
        return abi.encode(c, _origin(false), _origin(true), lineage);
    }

    function corrupt(uint8 mutation) external override {
        if (mutation == 1) {
            state.plans[id].progress.collectionId = 0;
        } else if (mutation == 2) {
            ++state.plans[id].progress.completedStages;
        } else if (mutation == 3) {
            state.plans[id].progress.renderCriticalEvidenceHash = keccak256("sealed");
        } else if (mutation == 4) {
            state.origins.lineage[id] = keccak256("stored lineage corruption");
        } else if (mutation == 5) {
            state.plans[id].progress.sourceContextHash = keccak256("stored context corruption");
        } else if (mutation == 6) {
            state.authority.capture.selection.selectionHash =
                keccak256("captured selection corruption");
        } else if (mutation == 7) {
            ++state.authority.capture.dependencies.sourceGas;
        } else if (mutation == 8) {
            state.dependencyHash = keccak256("dependency corruption");
        } else {
            revert("known storage mutation");
        }
    }

    function fingerprint() public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                prefix,
                id,
                suffix,
                state.authority.config,
                state.authority.capture,
                state.origins.dependencies,
                state.dependencies,
                state.dependencyHash,
                state.plans[id],
                state.contexts[id],
                state.origins.lineage[id]
            )
        );
    }

    function _stage(bool linked, bytes32 plan, uint16 expected) internal view override {
        if (linked) PolicyGuard.stage(state, plan, expected);
        else PolicyState.stage(state, plan, expected);
    }
}

contract CurrentPreservationStageHarness is CurrentFamilyStageHarness {
    PreservationState.State private state;
    uint256 private suffix = 0xB004;

    function configure(uint16 expected) external override returns (bytes32) {
        Source.Dependencies memory d = _dependencies();
        Current.Capture memory captured = _capture(d);
        Preservation.Context memory c = _context();
        state.authority.config.originalAnchor = d;
        state.authority.config.authority =
            Current.Dependencies(address(0x7000), keccak256("resolver runtime"), 800000);
        state.authority.capture = captured;
        state.origins.dependencies = _origins();
        state.dependencies = d;
        state.dependencyHash = DEPENDENCY;
        bytes32 contextHash = _contextHash(captured, keccak256(abi.encode(c)));
        id = keccak256(
            abi.encode(
                Current.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                DEPENDENCY,
                contextHash
            )
        );
        require(
            PreservationState.idFor(DEPENDENCY, captured, c, LINEAGE) == id,
            "literal host-specific plan identity"
        );
        Preservation.Plan memory p;
        p.scope = c.scope;
        p.progress = Inventory.Plan(
            c.scope.collectionId,
            c.subject,
            c.artistId,
            contextHash,
            c.tokenCount,
            1,
            3,
            17,
            keccak256("existing segment chain"),
            expected,
            bytes32(0)
        );
        p.nativeCount = 11;
        p.referenceCount = 13;
        state.plans[id] = p;
        state.contexts[id] = c;
        state.origins.lineage[id] = LINEAGE;
        return id;
    }

    function _context() private pure returns (Preservation.Context memory c) {
        c.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 9, 91, bytes32(0));
        c.subject = keccak256("exact scope subject");
        c.artistId = keccak256("historical artist");
        c.snapshot.scopeSubject = c.subject;
        c.snapshot.recordHash = keccak256("original snapshot record");
        c.snapshot.revision = 3;
        c.referenceRender.scopeSubject = c.subject;
        c.referenceRender.observation.recordHash = keccak256("original reference record");
        c.referenceRender.observation.revision = 5;
        c.descriptions.scopeSubject = c.subject;
        c.interviewEvidenceHash = keccak256("interview evidence");
        c.nativeHash = keccak256("native source");
        c.rootRecordHash = keccak256("original content root");
        c.tokenInventoryHash = keccak256("membership");
        c.checkpointHash = keccak256("checkpoint");
        c.outputManifestRecord = keccak256("original output manifest");
        c.selectionId = keccak256("content selection id");
        c.selectionHash = keccak256("content selection hash");
        c.tokenCount = 1;
        c.snapshotSource.scope = c.scope;
    }

    function sourceLibrary() external pure override returns (address) {
        return address(PreservationSources);
    }

    function sourceCall() external view override returns (bytes memory) {
        return abi.encodeWithSelector(
            PreservationSources.current.selector,
            state.dependencies,
            state.origins.dependencies,
            state.plans[id].scope
        );
    }

    function sourceResult(uint8 mutation) external view override returns (bytes memory) {
        Preservation.Context memory c = _context();
        bytes32 lineage = LINEAGE;
        if (mutation == 1) {
            c.rootRecordHash = keccak256("changed root");
        } else if (mutation == 2) {
            c.snapshot.recordHash = keccak256("changed snapshot");
        } else if (mutation == 3) {
            ++c.scope.collectionId;
        } else if (mutation == 4) {
            c.selectionHash = keccak256("changed selection");
        } else if (mutation == 5) {
            c.referenceRender.observation.recordHash = keccak256("changed reference");
        } else if (mutation == 6) {
            lineage = keccak256("changed lineage");
        } else if (mutation == 7) {
            ++c.tokenCount;
        } else if (mutation == 8) {
            c.subject = keccak256("changed subject");
        } else {
            require(mutation == 0, "known source mutation");
        }
        // Full canonical four-value return of THIS family. No cross-family decode.
        return abi.encode(c, _origin(false), _origin(true), lineage);
    }

    function corrupt(uint8 mutation) external override {
        if (mutation == 1) {
            state.plans[id].progress.collectionId = 0;
        } else if (mutation == 2) {
            ++state.plans[id].progress.completedStages;
        } else if (mutation == 3) {
            state.plans[id].progress.renderCriticalEvidenceHash = keccak256("sealed");
        } else if (mutation == 4) {
            state.origins.lineage[id] = keccak256("stored lineage corruption");
        } else if (mutation == 5) {
            state.plans[id].progress.sourceContextHash = keccak256("stored context corruption");
        } else if (mutation == 6) {
            state.authority.capture.selection.selectionHash =
                keccak256("captured selection corruption");
        } else if (mutation == 7) {
            ++state.authority.capture.dependencies.sourceGas;
        } else if (mutation == 8) {
            state.dependencyHash = keccak256("dependency corruption");
        } else {
            revert("known storage mutation");
        }
    }

    function fingerprint() public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                prefix,
                id,
                suffix,
                state.authority.config,
                state.authority.capture,
                state.origins.dependencies,
                state.dependencies,
                state.dependencyHash,
                state.plans[id],
                state.contexts[id],
                state.origins.lineage[id]
            )
        );
    }

    function _stage(bool linked, bytes32 plan, uint16 expected) internal view override {
        if (linked) PreservationGuard.stage(state, plan, expected);
        else PreservationState.stage(state, plan, expected);
    }
}

contract CurrentScopedStageHarness is CurrentFamilyStageHarness {
    ScopedState.State private state;
    uint256 private suffix = 0xB004;

    function configure(uint16 expected) external override returns (bytes32) {
        Source.Dependencies memory d = _dependencies();
        Current.Capture memory captured = _capture(d);
        Scoped.Context memory c = _context();
        state.authority.config.originalAnchor = d;
        state.authority.config.authority =
            Current.Dependencies(address(0x7000), keccak256("resolver runtime"), 800000);
        state.authority.capture = captured;
        state.origins.dependencies = _origins();
        state.dependencies = d;
        state.dependencyHash = DEPENDENCY;
        bytes32 contextHash = _contextHash(captured, keccak256(abi.encode(c)));
        id = keccak256(
            abi.encode(
                Current.SCOPED_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                DEPENDENCY,
                contextHash
            )
        );
        require(
            ScopedState.idFor(DEPENDENCY, captured, c, LINEAGE) == id,
            "literal host-specific plan identity"
        );
        Scoped.Plan memory p;
        p.scope = c.scope;
        p.progress = Inventory.Plan(
            c.scope.collectionId,
            c.subject,
            c.artistId,
            contextHash,
            c.tokenCount,
            1,
            3,
            17,
            keccak256("existing segment chain"),
            expected,
            bytes32(0)
        );
        p.nativeCount = 11;
        p.referenceCount = 13;
        state.plans[id] = p;
        state.contexts[id] = c;
        state.origins.lineage[id] = LINEAGE;
        return id;
    }

    function _context() private pure returns (Scoped.Context memory c) {
        c.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 9, 91, bytes32(0));
        c.subject = keccak256("exact scope subject");
        c.artistId = keccak256("historical artist");
        c.snapshot.scopeSubject = c.subject;
        c.snapshot.recordHash = keccak256("original snapshot record");
        c.snapshot.revision = 3;
        c.referenceRender.scopeSubject = c.subject;
        c.referenceRender.observation.recordHash = keccak256("original reference record");
        c.referenceRender.observation.revision = 5;
        c.descriptions.scopeSubject = c.subject;
        c.interviewEvidenceHash = keccak256("interview evidence");
        c.nativeHash = keccak256("native source");
        c.rootRecordHash = keccak256("original content root");
        c.tokenInventoryHash = keccak256("membership");
        c.checkpointHash = keccak256("checkpoint");
        c.outputManifestRecord = keccak256("original output manifest");
        c.selectionId = keccak256("content selection id");
        c.selectionHash = keccak256("content selection hash");
        c.tokenCount = 1;
    }

    function sourceLibrary() external pure override returns (address) {
        return address(ScopedSources);
    }

    function sourceCall() external view override returns (bytes memory) {
        return abi.encodeWithSelector(
            ScopedSources.current.selector,
            state.dependencies,
            state.origins.dependencies,
            state.plans[id].scope
        );
    }

    function sourceResult(uint8 mutation) external view override returns (bytes memory) {
        Scoped.Context memory c = _context();
        bytes32 lineage = LINEAGE;
        if (mutation == 1) {
            c.rootRecordHash = keccak256("changed root");
        } else if (mutation == 2) {
            c.snapshot.recordHash = keccak256("changed snapshot");
        } else if (mutation == 3) {
            ++c.scope.collectionId;
        } else if (mutation == 4) {
            c.selectionHash = keccak256("changed selection");
        } else if (mutation == 5) {
            c.referenceRender.observation.recordHash = keccak256("changed reference");
        } else if (mutation == 6) {
            lineage = keccak256("changed lineage");
        } else if (mutation == 7) {
            ++c.tokenCount;
        } else if (mutation == 8) {
            c.subject = keccak256("changed subject");
        } else {
            require(mutation == 0, "known source mutation");
        }
        // Full canonical four-value return of THIS family. No cross-family decode.
        return abi.encode(c, _origin(false), _origin(true), lineage);
    }

    function corrupt(uint8 mutation) external override {
        if (mutation == 1) {
            state.plans[id].progress.collectionId = 0;
        } else if (mutation == 2) {
            ++state.plans[id].progress.completedStages;
        } else if (mutation == 3) {
            state.plans[id].progress.renderCriticalEvidenceHash = keccak256("sealed");
        } else if (mutation == 4) {
            state.origins.lineage[id] = keccak256("stored lineage corruption");
        } else if (mutation == 5) {
            state.plans[id].progress.sourceContextHash = keccak256("stored context corruption");
        } else if (mutation == 6) {
            state.authority.capture.selection.selectionHash =
                keccak256("captured selection corruption");
        } else if (mutation == 7) {
            ++state.authority.capture.dependencies.sourceGas;
        } else if (mutation == 8) {
            state.dependencyHash = keccak256("dependency corruption");
        } else {
            revert("known storage mutation");
        }
    }

    function fingerprint() public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                prefix,
                id,
                suffix,
                state.authority.config,
                state.authority.capture,
                state.origins.dependencies,
                state.dependencies,
                state.dependencyHash,
                state.plans[id],
                state.contexts[id],
                state.origins.lineage[id]
            )
        );
    }

    function _stage(bool linked, bytes32 plan, uint16 expected) internal view override {
        if (linked) ScopedGuard.stage(state, plan, expected);
        else ScopedState.stage(state, plan, expected);
    }
}

abstract contract CurrentFamilyStageGuardDifferentialTest {
    CurrentFamilyStageVm private constant vm =
        CurrentFamilyStageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CurrentFamilyStageHarness internal host;

    function _newHarness() internal virtual returns (CurrentFamilyStageHarness);

    function setUp() public {
        host = _newHarness();
    }

    function _authorityCall() private pure returns (bytes memory) {
        // Prefix match at the fixed public storage-library boundary: the compiler supplies
        // its storage argument. This fixture never forges, decodes or casts a storage slot.
        return abi.encodeWithSelector(Authority.requireCurrent.selector);
    }

    function _mocks(uint8 mutation) private {
        vm.clearMockedCalls();
        vm.mockCall(address(Authority), _authorityCall(), bytes(""));
        vm.mockCall(host.sourceLibrary(), host.sourceCall(), host.sourceResult(mutation));
    }

    function _canary() private pure returns (bytes memory out) {
        out = new bytes(1031);
        for (uint256 i; i < out.length; ++i) {
            out[i] = bytes1(uint8(i % 251));
        }
    }

    function _pair(bytes32 id, uint16 expected, bool success, bytes memory expectedBytes) private {
        bytes memory canary = _canary();
        bytes32 before_ = host.fingerprint();
        (bool inlineOk, bytes memory inlineBytes) = address(host)
            .staticcall(
                abi.encodeCall(CurrentFamilyStageHarness.probe, (false, id, expected, canary))
            );
        (bool linkedOk, bytes memory linkedBytes) = address(host)
            .staticcall(
                abi.encodeCall(CurrentFamilyStageHarness.probe, (true, id, expected, canary))
            );
        require(inlineOk == success && linkedOk == success, "both actual guard outcomes");
        require(
            inlineBytes.length == linkedBytes.length
                && keccak256(inlineBytes) == keccak256(linkedBytes),
            "exact differential return or revert bytes"
        );
        require(
            inlineBytes.length == expectedBytes.length
                && keccak256(inlineBytes) == keccak256(expectedBytes),
            "independent expected bytes"
        );
        require(host.fingerprint() == before_, "no guard storage mutation on either route");
    }

    function _success(bytes32 id, uint16 stage) private {
        _pair(id, stage, true, host.expectedResult(id, stage, _canary()));
    }

    function _failure(bytes32 id, uint16 stage, bytes memory error_) private {
        _pair(id, stage, false, error_);
    }

    function testStageFourAndEightMatchWithTypedStorageAndMemoryCanaries() public {
        for (uint16 stage = 4; stage <= 8; stage += 4) {
            bytes32 id = host.configure(stage);
            _mocks(0);
            _success(id, stage);
        }
    }

    function testIncompletePlanRefusesBeforeAuthorityOrTypedSource() public {
        for (uint8 mutation = 1; mutation <= 3; ++mutation) {
            bytes32 id = host.configure(4);
            _mocks(0);
            vm.mockCallRevert(
                address(Authority),
                _authorityCall(),
                abi.encodeWithSelector(Artist.CurrentAuthorityChanged.selector)
            );
            vm.mockCallRevert(
                host.sourceLibrary(),
                host.sourceCall(),
                abi.encodeWithSignature("SyntheticTypedSourceFailure(uint256)", uint256(991))
            );
            host.corrupt(mutation);
            _failure(id, 4, abi.encodeWithSelector(Inventory.InventoryIncomplete.selector));
            require(host.configure(4) == id, "restored same plan");
            _mocks(0);
            _success(id, 4);
        }
    }

    function testAuthorityFailurePrecedesTypedSourceAndExactSourceFailureThenRetries() public {
        bytes32 id = host.configure(8);
        bytes memory authorityError =
            abi.encodeWithSelector(Artist.CurrentAuthorityChanged.selector);
        bytes memory sourceError =
            abi.encodeWithSignature("SyntheticTypedSourceFailure(uint256)", uint256(991));
        _mocks(0);
        vm.mockCallRevert(address(Authority), _authorityCall(), authorityError);
        vm.mockCallRevert(host.sourceLibrary(), host.sourceCall(), sourceError);
        _failure(id, 8, authorityError);
        _mocks(0);
        vm.mockCallRevert(host.sourceLibrary(), host.sourceCall(), sourceError);
        _failure(id, 8, sourceError);
        _mocks(0);
        vm.expectCall(address(Authority), _authorityCall(), uint64(2));
        vm.expectCall(host.sourceLibrary(), host.sourceCall(), uint64(2));
        _success(id, 8);
    }

    function testFullTypedContextAndReturnedLineageDriftRefuseThenRestore() public {
        bytes32 id = host.configure(4);
        bytes32 original = host.fingerprint();
        for (uint8 mutation = 1; mutation <= 8; ++mutation) {
            _mocks(mutation);
            _failure(id, 4, abi.encodeWithSelector(Inventory.InventorySourceChanged.selector));
            _mocks(0);
            _success(id, 4);
            require(host.fingerprint() == original, "source drift never alters saved context");
        }
    }

    function testStoredLineageContextCaptureAndDependencyDriftRefuseThenRestore() public {
        bytes32 id = host.configure(8);
        bytes32 original = host.fingerprint();
        for (uint8 mutation = 4; mutation <= 8; ++mutation) {
            _mocks(0);
            host.corrupt(mutation);
            _failure(id, 8, abi.encodeWithSelector(Inventory.InventorySourceChanged.selector));
            require(
                host.configure(8) == id && host.fingerprint() == original, "exact typed restoration"
            );
            _mocks(0);
            _success(id, 8);
        }
    }

    function testPlanIdentityBindsHostAndUnknownPlanRefusesBeforeCurrentReads() public {
        bytes32 first = host.configure(4);
        CurrentFamilyStageHarness other = _newHarness();
        bytes32 second = other.configure(4);
        require(first != second, "same source context still binds the actual host");
        _mocks(0);
        vm.mockCallRevert(
            address(Authority),
            _authorityCall(),
            abi.encodeWithSelector(Artist.CurrentAuthorityChanged.selector)
        );
        _failure(second, 4, abi.encodeWithSelector(Inventory.InventoryIncomplete.selector));
        _mocks(0);
        _success(first, 4);
    }
}

contract CurrentAuthorityPolicyStageGuardDifferentialTest is
    CurrentFamilyStageGuardDifferentialTest
{
    function _newHarness() internal override returns (CurrentFamilyStageHarness) {
        return new CurrentPolicyStageHarness();
    }
}

contract CurrentAuthorityPreservationStageGuardDifferentialTest is
    CurrentFamilyStageGuardDifferentialTest
{
    function _newHarness() internal override returns (CurrentFamilyStageHarness) {
        return new CurrentPreservationStageHarness();
    }
}

contract CurrentAuthorityScopedStageGuardDifferentialTest is
    CurrentFamilyStageGuardDifferentialTest
{
    function _newHarness() internal override returns (CurrentFamilyStageHarness) {
        return new CurrentScopedStageHarness();
    }
}
