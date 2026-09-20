// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    MetadataRealReadOwner,
    MetadataImmutableReadCoordinator,
    MetadataReadCostVm
} from "../../helpers/MetadataRealOwnerReadFixture.sol";
import {
    StreamStaticArtistLineageSource as Source
} from "../../../smart-contracts/domains/metadata/StreamStaticArtistLineageSource.sol";
import {
    StreamStaticArtistLineageCompanion as Companion
} from "../../../smart-contracts/domains/metadata/StreamStaticArtistLineageCompanion.sol";
import {
    StreamStaticAttributionCompanion as Original
} from "../../../smart-contracts/domains/metadata/StreamStaticAttributionCompanion.sol";
import {
    StreamArtistStaticDisplay as OldDisplay
} from "../../../smart-contracts/domains/artist/StreamArtistStaticDisplay.sol";
import {
    StreamArtistStaticDisplayProjection as Display
} from "../../../smart-contracts/domains/artist/StreamArtistStaticDisplayProjection.sol";
import {
    StreamArtistHistoryState as History
} from "../../../smart-contracts/domains/artist/StreamArtistHistoryState.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistStaticFacts as SF
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStaticFacts.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistCollaboratorTypes as CT
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamMetadataRecoveryRoutes as Routes
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    DisplaySnapshotBoundary,
    DisplayScopeBoundary,
    DisplayOriginalBoundary
} from "./StreamArtistDisplay.t.sol";

import {
    IStreamStaticArtistLineageFacts as F
} from "../../../smart-contracts/interfaces/stream/artist/IStreamStaticArtistLineageFacts.sol";

interface LineageVm {
    function expectRevert(bytes4) external;
    function etch(address, bytes calldata) external;
    function chainId(uint256) external;
    function cool(address) external;
}

contract LineageCoreBoundary {
    mapping(bytes32 => Routes.Pointer) private _pointers;

    function pointer(bytes32 key, address target, uint8 status, uint64 revision) external {
        _pointers[key] = Routes.Pointer(
            target, target.codehash, false, 0, 0, address(0), status, 0, 0, revision
        );
    }

    function getSatellitePointer(bytes32 key) external view returns (Routes.Pointer memory) {
        return _pointers[key];
    }
}

contract LineageRouterBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }
}

contract LineageRegistryBoundary {
    address public immutable core;
    address public operationCoordinator;

    constructor(address c) {
        core = c;
    }

    function bind(address c) external {
        require(operationCoordinator == address(0));
        operationCoordinator = c;
    }

    function gasParameterInfo(bytes32) external pure returns (uint256, uint256, uint8, uint64) {
        return (100000, 100000, 2, 1);
    }

    function staticDisplayRead(bytes calldata input) external view returns (bytes memory) {
        (bool ok, bytes memory raw) = address(OldDisplay)
            .staticcall(abi.encodeWithSignature("read(address,bytes)", operationCoordinator, input));
        require(ok, "original STATIC display");
        return abi.decode(raw, (bytes));
    }
}

/// @dev Actual original Owner/Guards/import namespace producers; typed source history/fact setup.
/// This harness does not claim real op55–60 admission or actual Identity deployment acceptance.
contract LineageReadOwner is MetadataRealReadOwner {
    uint256 public claims;
    uint8 public attributionState = 2;
    string private _name = "Original identity";
    S.Record private _sanction;
    bool private _overrideOrigin;
    F.Lineage private _originReply;
    constructor(T.SuiteConfiguration memory s, address coordinator, uint8 i)
        MetadataRealReadOwner(s, coordinator, i)
    { }

    function history(
        address predecessor,
        uint64 snapshot,
        bytes32 root,
        bytes32 manifest,
        uint256 count
    ) external {
        History.State storage s = History.state();
        delete s.bindings;
        if (count != 0) s.bindings.push(H.Binding(predecessor, snapshot, root, manifest));
        if (count > 1) s.bindings.push(H.Binding(predecessor, snapshot, root, manifest));
        s.predecessorCode[predecessor] = predecessor.codehash;
        s.predecessorCount[predecessor] = count;
    }

    function seal(address successor, bool sealed_, uint64 at) external {
        History.State storage s = History.state();
        s.cutover = sealed_;
        s.successor = successor;
        s.cutoverBlock = at;
    }

    function staticArtistLineage(bytes32 hash) external view returns (F.Lineage memory r) {
        History.State storage s = History.state();
        r.isSealed = s.cutover;
        r.successor = s.successor;
        r.sealedAt = s.cutoverBlock;
        r.bindingCount = s.bindings.length;
        if (r.bindingCount == 1) {
            H.Binding memory b = s.bindings[0];
            r.predecessor = b.predecessorRegistry;
            r.snapshotBlock = b.snapshotBlock;
            r.importRoot = b.importRoot;
            r.manifestHash = b.manifestHash;
            r.predecessorCodeHash = s.predecessorCode[r.predecessor];
            r.predecessorCount = s.predecessorCount[r.predecessor];
        }
        if (hash != 0) {
            (
                r.originHash,
                r.importCommitment,
                r.importedAtRevision,
                r.ownerIndex,
                r.originProfile
            ) = Imported.originFactsInline(hash, artistRegistry);
            if (_overrideOrigin) {
                r.originHash = _originReply.originHash;
                r.importCommitment = _originReply.importCommitment;
                r.importedAtRevision = _originReply.importedAtRevision;
                r.ownerIndex = _originReply.ownerIndex;
                r.originProfile = _originReply.originProfile;
            }
        }
    }

    /// @dev Explicit malformed fact boundary; actual imported namespace is never altered.
    function overrideOrigin(bool enabled, F.Lineage calldata value) external {
        _overrideOrigin = enabled;
        _originReply = value;
    }

    function changeFacts(uint256 count, uint8 state, string calldata name_) external {
        claims = count;
        attributionState = state;
        _name = name_;
    }

    function sanction(uint8 class_) external {
        T.Binding memory b = _binding();
        _sanction.recordHash = keccak256("sanction");
        _sanction.artistId = b.artistId;
        _sanction.bindingGeneration = b.generation;
        _sanction.bindingHash = b.bindingHash;
        _sanction.signer = address(0xa11ce);
        _sanction.authorityClass = class_;
        _sanction.terms = S.Terms(0, 1, 0, 0, keccak256("subject"), keccak256("statement"));
    }

    function _binding() private pure returns (T.Binding memory) {
        return T.Binding(
            keccak256("artist"),
            address(0xa11ce),
            keccak256("identity"),
            keccak256("binding"),
            1,
            1,
            1,
            1,
            address(0xbeef),
            true
        );
    }

    function binding(uint256) external pure returns (T.Binding memory) {
        return _binding();
    }

    function bindingAt(uint256, uint64) external pure returns (T.Binding memory) {
        return _binding();
    }

    function bindingTerms(uint256, uint64) external pure returns (CT.BindingTerms memory t) {
        return t;
    }

    function staticAuthorityState(bytes32) external pure returns (address, uint8, uint8, bytes32) {
        return (address(0xa11ce), 1, 1, keccak256("identity"));
    }

    function staticIdentityMetadata(bytes32) external view returns (string memory, bytes32) {
        return (_name, keccak256("identity"));
    }

    function staticAttributionState(uint256) external view returns (uint8, uint64) {
        return (attributionState, 1);
    }

    function staticPlatformWorksState(uint256) external pure returns (PW.State memory s) {
        return s;
    }

    function platformCorrectionStatus(uint256) external pure returns (PL.Status memory s) {
        return s;
    }

    function staticAttributionClaims(uint256) external view returns (uint256, bytes32) {
        return (claims, claims == 0 ? bytes32(0) : keccak256(abi.encode(claims)));
    }

    function staticAttestation(uint256, uint8, bytes32)
        external
        pure
        returns (SF.Attestation memory)
    {
        return SF.Attestation(keccak256("attest"), 1, keccak256("manifest"), 1, 1);
    }

    function acceptanceRecord(bytes32) external pure returns (bytes32) {
        return keccak256("acceptance");
    }

    function acceptedAt(bytes32) external pure returns (uint64) {
        return 1;
    }

    function staticSanctionRecord(bytes32) external view returns (bytes32, S.Record memory) {
        return (_sanction.recordHash, _sanction);
    }
}

/// @notice Actual new source/companion and original display algorithms with explicit typed suites.
/// @dev Constructor hash comes from the independent original-literal Coordinator fixture.
contract StreamStaticArtistLineageTest is CharacterizationTestBase {
    LineageVm private constant lvm =
        LineageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant COMPLETE = keccak256("all seven current owners complete");
    LineageCoreBoundary private core;
    LineageRouterBoundary private router;
    T.SuiteConfiguration[3] private suites;
    MetadataImmutableReadCoordinator[3] private coordinators;
    Source private source;
    Companion private companion;
    Original private original;
    DisplaySnapshotBoundary private snapshot;

    function setUp() public {
        core = new LineageCoreBoundary();
        router = new LineageRouterBoundary(address(core));
        T.SuiteConfiguration memory s;
        s.core = address(core);
        s.metadata = address(router);
        s.mintManager = address(new LineageRouterBoundary(address(core)));
        s.roleRegistry = address(new LineageRouterBoundary(address(core)));
        s.primaryResolver = address(new LineageRouterBoundary(address(core)));
        s.royaltyResolver = address(new LineageRouterBoundary(address(core)));
        s.validator = address(new LineageRouterBoundary(address(core)));
        s.primaryRevenueClass = keccak256("PRIMARY");
        for (uint256 j; j < 3; ++j) {
            s.registry = address(new LineageRegistryBoundary(address(core)));
            s.archive = address(new LineageRouterBoundary(address(core)));
            uint256 nonce = uint256(MetadataReadCostVm(address(vm)).getNonce(address(this))) + 7;
            require(nonce < 128, "literal CREATE fixture range");
            address predicted = address(
                uint160(
                    uint256(keccak256(abi.encodePacked(hex"d694", address(this), uint8(nonce))))
                )
            );
            for (uint8 i; i < 7; ++i) {
                s.owners[i] = address(new LineageReadOwner(s, predicted, i));
            }
            coordinators[j] = new MetadataImmutableReadCoordinator(s);
            require(address(coordinators[j]) == predicted, "actual coordinator CREATE");
            LineageRegistryBoundary(s.registry).bind(predicted);
            suites[j] = s;
        }
        address[] memory list = new address[](3);
        for (uint256 i; i < 3; ++i) {
            list[i] = address(coordinators[i]);
        }
        source = new Source(address(core), address(router), list);
        core.pointer(keccak256("METADATA_ROUTER"), address(router), 1, 1);
        _select(0);
        DisplayScopeBoundary scopes = new DisplayScopeBoundary(address(core), address(router));
        DisplayOriginalBoundary finality =
            new DisplayOriginalBoundary(address(core), address(scopes));
        snapshot = new DisplaySnapshotBoundary(address(core), address(router), address(scopes));
        scopes.bindSources(address(snapshot), address(finality));
        original = new Original(
            address(core), address(router), suites[0].registry, address(finality), address(0)
        );
        companion = new Companion(address(original), address(source), address(0));
    }

    function _owner(uint256 j, uint256 i) private view returns (LineageReadOwner) {
        return LineageReadOwner(suites[j].owners[i]);
    }

    function _select(uint256 j) private {
        core.pointer(keccak256("ARTIST_REGISTRY"), suites[j].registry, 1, 1);
    }

    function _origin(uint256 j) private view returns (RH.OriginEnvironment memory o) {
        T.SuiteConfiguration memory s = suites[j];
        o.chainId = block.chainid;
        o.registry = s.registry;
        o.coordinator = address(coordinators[j]);
        o.archive = s.archive;
        o.owners = s.owners;
        for (uint256 i; i < 7; ++i) {
            o.ownerCodeHashes[i] = s.owners[i].codehash;
        }
        o.core = s.core;
        o.manager = s.mintManager;
        o.suiteConfigurationHash = keccak256(abi.encode(s));
    }

    function _prepare(uint256 j, uint8 omit, uint8 wrong) private {
        coordinators[j].installFixturePrefix(_origin(0), COMPLETE, omit, wrong);
        _owner(j, 2).history(suites[j - 1].registry, 1, keccak256("root"), keccak256("manifest"), 1);
        _owner(j - 1, 2).seal(suites[j].registry, true, 2);
        _select(j);
    }

    function testOriginalSuiteAndEveryFullAttributionByteMatch() public view {
        (bool coreOK, bytes memory actualCore) =
            suites[0].registry.staticcall(abi.encodeWithSignature("core()"));
        require(
            coreOK && keccak256(actualCore) == keccak256(abi.encode(address(core))),
            "literal original core getter"
        );
        (bool badSelector,) = suites[0].registry.staticcall(abi.encodeWithSignature("x.core()"));
        require(!badSelector, "typed registry has no fallback for malformed selector");
        require(
            keccak256(abi.encode(source.currentSuite())) == keccak256(abi.encode(suites[0])),
            "complete original suite"
        );
        require(
            keccak256(original.attribution(1, 0)) == keccak256(companion.attribution(1, 0)),
            "full original AA-DISPLAY bytes"
        );
        require(
            keccak256(companion.attribution(1, 0))
                == keccak256(companion.preservationAttribution(1, 0)),
            "baseline projections"
        );
        require(
            keccak256(original.attribution(1, 91)) == keccak256(companion.attribution(1, 91)),
            "complete token/covering-scope path"
        );
    }

    function testActualNamespaceCompletionSelectsBAndRepeatedOriginalPrefixSelectsC() public {
        bytes32 baseline = keccak256(companion.preservationAttribution(1, 0));
        _prepare(1, 255, 255);
        require(source.currentSuite().registry == suites[1].registry, "B current");
        require(keccak256(companion.preservationAttribution(1, 0)) == baseline, "equal facts only");
        _prepare(2, 255, 255);
        require(source.currentSuite().registry == suites[2].registry, "C current");
        require(
            keccak256(companion.preservationAttribution(1, 0)) == baseline,
            "preserved original facts"
        );
        vm.expectRevert();
        original.attribution(1, 0);
    }

    function testCurrentClaimsNameAndAdverseStateRemainLiveAfterC() public {
        _prepare(1, 255, 255);
        _prepare(2, 255, 255);
        bytes32 baseline = keccak256(companion.preservationAttribution(1, 0));
        _owner(2, 4).changeFacts(2, 4, "Original identity");
        _owner(2, 2).changeFacts(0, 2, "Current identity");
        bytes32 changed = keccak256(companion.preservationAttribution(1, 0));
        require(
            changed != baseline && changed == keccak256(companion.attribution(1, 0)),
            "current adverse facts retained"
        );
        require(_owner(0, 4).claims() == 0, "old A not read or mutated");
    }

    function testCurrentSanctionAndConfirmationOnlyChangeLiveProjection() public {
        _prepare(1, 255, 255);
        _prepare(2, 255, 255);
        bytes32 before_ = keccak256(companion.preservationAttribution(1, 0));
        _owner(2, 6).sanction(3);
        require(
            keccak256(companion.attribution(1, 0)) != before_, "actual current sanction retained"
        );
        require(
            keccak256(companion.preservationAttribution(1, 0)) == before_, "declared omission only"
        );
        _owner(2, 4).changeFacts(0, 3, "Original identity");
        require(
            keccak256(companion.preservationAttribution(1, 0)) == before_,
            "original confirmation normalization"
        );
    }

    function testUnlistedSuccessorRefusesAndOriginalSelectionRestores() public {
        core.pointer(
            keccak256("ARTIST_REGISTRY"), address(new LineageRegistryBoundary(address(core))), 1, 1
        );
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        _select(0);
        require(source.currentSuite().registry == suites[0].registry, "restore");
    }

    function testEveryOwnerCompletionMarkerIsRequired() public {
        _prepare(1, 255, 6);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
    }

    function testRepeatedImportedOnlyCertificateCannotUseMissingPrefix() public {
        _prepare(1, 255, 255);
        _prepare(2, 2, 255);
        vm.expectRevert();
        source.currentSuite();
        for (uint256 i; i < 7; ++i) {
            require(
                _owner(2, i).authorityHydrationCommitment() == COMPLETE,
                "all genuine markers present"
            );
        }
    }

    function testForeignOriginalCertificateCannotSatisfyAAncestry() public {
        _prepare(1, 255, 255);
        coordinators[2].installFixturePrefix(_origin(1), COMPLETE, 255, 255);
        _owner(2, 2).history(suites[1].registry, 1, keccak256("root"), keccak256("manifest"), 1);
        _owner(1, 2).seal(suites[2].registry, true, 2);
        _select(2);
        vm.expectRevert();
        source.currentSuite();
    }

    function testImmediateSealSnapshotAndSingleBindingAreAllRequired() public {
        _prepare(1, 255, 255);
        _owner(0, 2).seal(suites[2].registry, true, 2);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        _owner(0, 2).seal(suites[1].registry, true, 2);
        _owner(1, 2).history(suites[0].registry, 3, keccak256("root"), keccak256("manifest"), 1);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        _owner(1, 2).history(suites[0].registry, 1, keccak256("root"), keccak256("manifest"), 2);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        _owner(1, 2).history(suites[0].registry, 1, keccak256("root"), keccak256("manifest"), 1);
        require(source.currentSuite().registry == suites[1].registry, "exact source restore");
    }

    function testPinnedSuccessorRuntimeAndChainFailClosedThenRestore() public {
        _prepare(1, 255, 255);
        bytes memory saved = suites[1].owners[2].code;
        lvm.etch(suites[1].owners[2], hex"00");
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        lvm.etch(suites[1].owners[2], saved);
        uint256 chain = block.chainid;
        lvm.chainId(chain + 1);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        lvm.chainId(chain);
        require(source.currentSuite().registry == suites[1].registry, "full restore");
    }

    function testCurrentRouterAndActivePointerRemainRequired() public {
        _prepare(1, 255, 255);
        core.pointer(keccak256("ARTIST_REGISTRY"), suites[1].registry, 2, 1);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        _select(1);
        core.pointer(keccak256("METADATA_ROUTER"), suites[1].archive, 1, 1);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        core.pointer(keccak256("METADATA_ROUTER"), address(router), 1, 1);
        require(source.currentSuite().registry == suites[1].registry, "current root restored");
    }

    function testMissingSnapshotNeverManufacturesPreservationSuccess() public {
        _prepare(1, 255, 255);
        snapshot.configure(false, true);
        vm.expectRevert();
        companion.preservationAttribution(1, 0);
        snapshot.configure(false, false);
        require(companion.preservationAttribution(1, 0).length != 0, "restore");
    }

    function testEveryImportedOriginPredicateRefusesThenExactCertificateRestores() public {
        _prepare(1, 255, 255);
        _prepare(2, 255, 255);
        F.Lineage memory saved = _owner(2, 2).staticArtistLineage(source.originalOriginHash());
        require(
            saved.originHash == source.originalOriginHash() && saved.importCommitment == COMPLETE
                && saved.importedAtRevision != 0 && saved.ownerIndex == 2
                && saved.originProfile == RH.PROFILE,
            "actual original namespace facts"
        );
        bytes32 baseline = keccak256(abi.encode(source.currentSuite()));
        for (uint256 i; i < 5; ++i) {
            F.Lineage memory wrong = abi.decode(abi.encode(saved), (F.Lineage));
            if (i == 0) wrong.originHash = bytes32(uint256(saved.originHash) ^ 1);
            else if (i == 1) wrong.importCommitment = bytes32(uint256(COMPLETE) ^ 1);
            else if (i == 2) wrong.importedAtRevision = 0;
            else if (i == 3) wrong.ownerIndex = 3;
            else wrong.originProfile = bytes32(uint256(RH.PROFILE) ^ 1);
            _owner(2, 2).overrideOrigin(true, wrong);
            lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
            source.currentSuite();
            _owner(2, 2).overrideOrigin(false, saved);
            require(
                keccak256(abi.encode(source.currentSuite())) == baseline,
                "same original certificate restore"
            );
        }
    }

    function testFuzzCurrentClaimsRemainObservable(uint32 count) public {
        _prepare(1, 255, 255);
        bytes32 before_ = keccak256(companion.preservationAttribution(1, 0));
        uint256 n = uint256(count) + 1;
        _owner(1, 4).changeFacts(n, 2, "Original identity");
        require(
            keccak256(companion.preservationAttribution(1, 0)) != before_,
            "current claim count not frozen"
        );
    }
}
