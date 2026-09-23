// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPlatformCorrectionLineageTypes as PL, IStreamArtistPlatformCorrectionLineage as PlatformLineage } from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import { IStreamStaticArtistSource } from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticArtistSource.sol";

import {
    StreamFinalityNativeProviderReads
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    StreamArtistDisplayJSON
} from "../../../smart-contracts/domains/metadata/StreamArtistDisplayJSON.sol";
import {
    StreamArtistDisplayTypes as D
} from "../../../smart-contracts/interfaces/stream/metadata/StreamArtistDisplayTypes.sol";
import {
    StreamMetadataRecoveryRoutes
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    T,
    S,
    IStreamArtistDisplayFacts
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import {
    IStreamArtistAttribution,
    IStreamCollectionArtistRegistry
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    PW, IStreamArtistPlatformWorks
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    C
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamSnapshotTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamSnapshotTypes.sol";
import {
    PresentationCoreBoundary,
    PresentationEntropyBoundary
} from "./StreamMetadataServing.t.sol";
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { OfficialSafeFixture, OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";

/// @dev Typed read boundaries only; none of these fixtures claims actual Artist admission.
contract DisplayArtistBoundary {
    address public core;
    address public finalityRegistry;
    bytes32 public finalityRegistryCodeHash;
    T.Binding public binding;
    uint8 public state = 2;
    PW.State private platform;
    uint256 public claims;
    bytes32 public latestClaim;
    uint8 public attestation = 1;
    uint8 public attestationClass = 3;
    uint8 public failure;
    bool public collaborator;
    mapping(bytes32 => S.Record) private sanctions;

    constructor(address c) {
        core = c;
        binding = T.Binding(
            keccak256("artist"),
            address(0xA11CE),
            keccak256("original identity"),
            keccak256("binding"),
            4,
            1,
            1,
            1,
            address(0xBEEF),
            true
        );
    }

    function bind(address f) external {
        finalityRegistry = f;
        finalityRegistryCodeHash = f.codehash;
    }

    function configure(uint8 s, uint8 fail, uint8 a) external {
        state = s;
        failure = fail;
        attestationClass = a;
        binding.accepted = s != 1;
    }

    function setAttestation(uint8 status) external {
        attestation = status;
    }

    function setCollaborator() external {
        collaborator = true;
    }

    function setPlatform(bool corrected) external {
        platform.declaration =
            PW.Declaration(keccak256("declaration"), keccak256("statement"), address(0xBEEF), 1);
        platform.contestState = 3;
        platform.contestRecord = keccak256("contest");
        platform.claimCount = 1;
        platform.latestClaim = keccak256("old claim");
        platform.correction.accepted = corrected;
        claims = 2;
        latestClaim = keccak256("new claim");
    }

    function setSanction(StreamFinalityScope calldata scope, uint8 authorityClass) external {
        S.Record memory s;
        s.recordHash = keccak256(abi.encode(scope));
        s.artistId = binding.artistId;
        s.signer = address(0xA11CE);
        s.authorityClass = authorityClass;
        s.terms = S.Terms(
            uint8(scope.scopeType),
            scope.collectionId,
            scope.tokenId,
            scope.scopeId,
            keccak256("admitted subject"),
            keccak256("statement")
        );
        s.bindingGeneration = binding.generation;
        s.bindingHash = binding.bindingHash;
        sanctions[keccak256(abi.encode(scope))] = s;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id != 0xffffffff;
    }

    function firstReleaseRatification(uint256) external pure returns (bool, bytes32, bytes32) {
        return (false, 0, 0);
    }

    function displayBinding(uint256) external view returns (T.Binding memory) {
        return binding;
    }

    function collectionArtistState(uint256)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return (state, binding.generation, binding.artistId, 1, binding.bindingHash);
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory)
    {
        return IStreamCollectionArtistRegistry.Attribution(
            binding.artistAddress,
            binding.artistAddress,
            binding.identityRecordHash,
            binding.bindingHash,
            keccak256("acceptance"),
            binding.generation,
            1
        );
    }

    function platformWorksState(uint256) external view returns (PW.State memory) {
        return platform;
    }

    function attributionClaims(uint256) external view returns (uint256, bytes32) {
        return (claims, latestClaim);
    }

    function deploymentAttestation(uint256) external pure returns (bytes32, uint8, uint64) {
        return (keccak256("deployment"), 1, 1);
    }

    function artistDisplayName(bytes32) external view returns (string memory, bytes32) {
        if (failure == 1) revert("read failure");
        if (failure == 2) assembly ("memory-safe") { return(0, 0) }
        if (failure == 3) {
            assembly ("memory-safe") {
                let p := mload(0x40)
                return(p, 4096)
            }
        }
        if (failure == 4) assembly ("memory-safe") { for { } 1 { } { } }
        return ("A \"B\"\n", keccak256("operative identity"));
    }

    function operativeIdentityRecord(bytes32) external pure returns (bytes32) {
        return keccak256("operative identity");
    }

    function collaboratorCount(uint256, uint64) external view returns (uint256) {
        return collaborator ? 1 : 0;
    }

    function collaboratorAt(uint256, uint64, uint256) external pure returns (C.Row memory) {
        return C.Row(
            address(0xC011AB),
            keccak256("ANIMATOR"),
            0,
            keccak256("collaborator"),
            keccak256("accepted collaborator"),
            true
        );
    }

    function artistAttestationStatus(uint256, uint8 kind, bytes32 id, bytes32 live)
        external
        view
        returns (uint8, bytes32, bytes32, uint8, uint64)
    {
        require(
            kind == 1 && id == keccak256("snapshot id") && live == keccak256("manifest"),
            "actual selected snapshot identity"
        );
        return (attestation, keccak256("attestation"), live, attestationClass, 1);
    }

    function displaySanction(StreamFinalityScope calldata scope)
        external
        view
        returns (S.Record memory)
    {
        return sanctions[keccak256(abi.encode(scope))];
    }

    function verifySanctionForSubject(
        uint8 t,
        uint256 c,
        uint256 token,
        bytes32 id,
        bytes32 subject
    ) external view returns (bool, bytes32, address, uint8) {
        S.Record memory s = sanctions[
            keccak256(abi.encode(StreamFinalityScope(StreamFinalityScopeType(t), c, token, id)))
        ];
        return (
            s.recordHash != 0 && s.terms.sanctionSubjectHash == subject,
            s.recordHash,
            s.signer,
            s.authorityClass
        );
    }
}

contract DisplaySnapshotBoundary {
    address public core;
    address public metadataRouter;
    address public metadataHost;
    bool public missing;
    bool public drift;

    constructor(address c, address r, address metadata) {
        core = c;
        metadataRouter = r;
        metadataHost = metadata;
    }

    function configure(bool absent, bool changed) external {
        missing = absent;
        drift = changed;
    }

    function currentSnapshot(uint256 c)
        external
        view
        returns (StreamSnapshotTypes.Receipt memory r)
    {
        if (missing) return r;
        r.recordHash = keccak256("snapshot record distinct from manifest");
        r.collectionId = c;
        r.snapshotId = keccak256("snapshot id");
        r.manifestHash = keccak256("manifest");
    }

    function latestSnapshotHash(uint256) external view returns (bytes32) {
        return missing ? bytes32(0) : drift ? keccak256("other manifest") : keccak256("manifest");
    }

    function snapshotHash(uint256, bytes32) external pure returns (bytes32) {
        return keccak256("manifest");
    }
}

contract DisplayScopeBoundary {
    address public core;
    address public metadataRouter;
    address public snapshotHost;
    address private original;
    StreamFinalityScope private scope;
    uint256 public count;
    bool public covers = true;

    constructor(address c, address r) {
        core = c;
        metadataRouter = r;
    }

    function bindSources(address s, address o) external {
        snapshotHost = s;
        original = o;
    }

    function nativeConfiguration()
        external
        view
        returns (StreamFinalityNativeProviderReads.Config memory c)
    {
        c.chainId = block.chainid;
        c.targets[0] = core;
        c.targets[1] = address(this);
        c.targets[2] = metadataRouter;
        c.targets[8] = snapshotHost;
        c.targets[12] = original;
        for (uint256 i; i < 22; ++i) {
            c.codeHashes[i] = c.targets[i].codehash;
        }
    }

    function configure(uint256 n, bool covered) external {
        count = n;
        covers = covered;
        scope = StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, keccak256("release"));
    }

    function metadataHost() external view returns (address) {
        return address(this);
    }

    function scopeMembershipHost() external view returns (address) {
        return address(this);
    }

    function coreCodeHash() external view returns (bytes32) {
        return core.codehash;
    }

    function metadataRouterCodeHash() external view returns (bytes32) {
        return metadataRouter.codehash;
    }

    function metadataHostCodeHash() external view returns (bytes32) {
        return address(this).codehash;
    }

    function scopeMembershipHostCodeHash() external view returns (bytes32) {
        return address(this).codehash;
    }

    function tokenScopeCount(uint256) external view returns (uint256) {
        return count;
    }

    function tokenScopeAt(uint256, uint256)
        external
        view
        returns (StreamFinalityScope memory, bool)
    {
        return (scope, true);
    }

    function scopeCoversToken(StreamFinalityScope calldata, uint256) external view returns (bool) {
        return covers;
    }
}

contract DisplayOriginalBoundary {
    address public coreReads;
    address public scopeEvidenceProvider;
    address public metadataReads;

    constructor(address c, address provider) {
        coreReads = c;
        scopeEvidenceProvider = provider;
        metadataReads = provider;
    }

    function scopeEvidenceProviderCodeHash() external view returns (bytes32) {
        return scopeEvidenceProvider.codehash;
    }

    function finalityComponentCount(uint256) external pure returns (uint256) {
        return 0;
    }

    function finalityComponentCountForScope(StreamFinalityScope calldata)
        external
        pure
        returns (uint256)
    {
        return 0;
    }
}

/// @notice Actual Router/JSON and threshold Safe with explicitly typed source-read boundaries.
interface PlatformDisplayVm { function mockCall(address,bytes calldata,bytes calldata) external; }

contract StreamArtistDisplayTest is CharacterizationTestBase, OfficialSafeFixture {
    PlatformDisplayVm private constant pdvm = PlatformDisplayVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    PresentationCoreBoundary private core;
    PresentationEntropyBoundary private entropy;
    DisplayArtistBoundary private artist;
    DisplaySnapshotBoundary private snapshot;
    DisplayScopeBoundary private scopes;
    DisplayOriginalBoundary private original;
    StreamMetadataRouter private router;

    function setUp() public {
        core = new PresentationCoreBoundary();
        entropy = new PresentationEntropyBoundary();
        artist = new DisplayArtistBoundary(address(core));
        core.configure(address(artist), address(entropy));
        router = new StreamMetadataRouter(
            address(core),
            address(this),
            keccak256("deployment"),
            "urn:display",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
        scopes = new DisplayScopeBoundary(address(core), address(router));
        original = new DisplayOriginalBoundary(address(core), address(scopes));
        artist.bind(address(original));
        router.initializeOriginalFinalityAnchor();
        snapshot = new DisplaySnapshotBoundary(address(core), address(router), address(scopes));
        scopes.bindSources(address(snapshot), address(original));
        router.setCollectionMetadata(1, "Name", "Description", "ipfs://image", "");
    }

    function _json() private view returns (string memory) {
        return router.tokenMetadataJSON(address(core), 91);
    }

    function _string(string memory json, string memory path) private view returns (string memory) {
        return abi.decode(vm.parseJson(json, path), (string));
    }

    function _state(string memory wanted) private view {
        require(
            keccak256(bytes(_string(_json(), ".properties.provenance.attribution.state")))
                == keccak256(bytes(wanted)),
            "exact state"
        );
    }

    function testLiveNestedIdentitySnapshotManifestAndCollaboratorName() public {
        artist.setCollaborator();
        string memory json = _json();
        _state("artist_accepted");
        require(
            keccak256(
                    bytes(_string(json, ".properties.provenance.attribution.artist_display_name"))
                ) == keccak256(bytes("A \"B\"\n")),
            "operative escaped name"
        );
        require(
            abi.decode(
                vm.parseJson(json, ".properties.provenance.attribution.identity_record_hash"),
                (bytes32)
            ) == keccak256("operative identity"),
            "operative identity"
        );
        require(
            keccak256(
                bytes(
                    _string(json, ".properties.provenance.attribution.attestation_authority_class")
                )
            ) == keccak256("successor"),
            "record class"
        );
        require(
            abi.decode(
                vm.parseJson(json, ".properties.provenance.attribution.attested_state_hash"),
                (bytes32)
            ) == keccak256("manifest"),
            "manifest not snapshot record"
        );
        require(
            keccak256(
                bytes(
                    _string(
                        json,
                        ".properties.provenance.attribution.collaborators[0].verification_state"
                    )
                )
            ) == keccak256("artist_accepted"),
            "individual acceptance"
        );
        string memory uri = router.contractURIForCollection(address(core), 1);
        require(bytes(uri).length > 29, "live collection URI");
    }

    function testClaimedRevokedDisputedAndScopeSanctionPrecedence() public {
        artist.configure(1, 0, 1);
        _state("claimed");
        artist.configure(2, 0, 1);
        StreamFinalityScope memory s =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, keccak256("release"));
        artist.setSanction(s, 4);
        scopes.configure(1, true);
        _state("artist_sanctioned");
        require(
            keccak256(
                bytes(
                    _string(_json(), ".properties.provenance.attribution.sanction_authority_class")
                )
            ) == keccak256("steward"),
            "stored sanction authority"
        );
        artist.configure(4, 0, 1);
        _state("disputed");
        artist.configure(5, 0, 1);
        _state("revoked");
        artist.configure(2, 0, 1);
        scopes.configure(1, false);
        _state("attribution_unavailable");
        scopes.configure(65, true);
        _state("attribution_unavailable");
    }

    function testAllStoredSanctionClassesAndStaleAttestationKeepExactVocabulary() public {
        string[4] memory names = [string("artist"), "delegate", "successor", "steward"];
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        for (uint8 i = 1; i <= 4; ++i) {
            artist.setSanction(scope, i);
            require(
                keccak256(
                    bytes(
                        _string(
                            _json(), ".properties.provenance.attribution.sanction_authority_class"
                        )
                    )
                ) == keccak256(bytes(names[i - 1])),
                "exact stored authority class"
            );
        }
        artist.setAttestation(2);
        require(
            keccak256(
                bytes(_string(_json(), ".properties.provenance.attribution.attestation_status"))
            ) == keccak256("attested_stale"),
            "stale remains visible"
        );
        artist.setAttestation(3);
        require(
            keccak256(
                bytes(_string(_json(), ".properties.provenance.attribution.attestation_status"))
            ) == keccak256("disputed"),
            "attestation dispute"
        );
    }

    function testDisplayLockDoesNotHideLiveRevocationOrReplaceHistoricalBytes() public {
        router.lockArtistIdentity(1);
        bytes32 old = keccak256(bytes(router.historicalTokenMetadataJSON(address(core), 91)));
        artist.configure(5, 0, 1);
        _state("revoked");
        require(
            keccak256(bytes(router.historicalTokenMetadataJSON(address(core), 91))) == old,
            "original selected display bytes retained"
        );
    }

    function testPlatformAndCorrectedClaimsKeepCurrentCombinedHistory() public {
        artist.setPlatform(false);
        _state("disputed");
        string memory json = _json();
        require(
            abi.decode(
                vm.parseJson(json, ".properties.provenance.attribution.claim_count"), (uint256)
            ) == 1,
            "platform claims"
        );
        require(
            abi.decode(vm.parseJson(json, ".properties.provenance.attribution.contested"), (bool)),
            "standing or sustained contest"
        );
        artist.setPlatform(true);
        json = _json();
        require(
            abi.decode(
                vm.parseJson(json, ".properties.provenance.attribution.claim_count"), (uint256)
            ) == 2,
            "combined corrected claims"
        );
        require(
            abi.decode(
                vm.parseJson(json, ".properties.provenance.attribution.corrected_attribution"),
                (bool)
            ),
            "actual correction"
        );
    }

    function testSupplementalPlatformAcceptancePreservesOriginalCorrectedJSON() public {
        artist.setPlatform(true);
        string memory expected = _json();
        PW.State memory p = artist.platformWorksState(1);
        p.correction.accepted = false;
        p.correction.correctiveGeneration = 1;
        p.correction.recordHash = keccak256("unchanged original op53");
        pdvm.mockCall(address(artist), abi.encodeCall(IStreamArtistPlatformWorks.platformWorksState,(uint256(1))),abi.encode(p));
        bytes memory query = abi.encodeCall(IStreamStaticArtistSource.staticDisplayRead,
            (abi.encodeCall(PlatformLineage.platformCorrectionStatus,(uint256(1)))));
        PL.Status memory status = PL.Status(p.correction.recordHash,keccak256("later lineage"),2,1,true,keccak256("original op2 receipt"));
        pdvm.mockCall(address(artist),query,abi.encode(abi.encode(status)));
        require(keccak256(bytes(_json()))==keccak256(bytes(expected)),"effective accepted path has exact original corrected JSON");
        require(abi.decode(vm.parseJson(_json(),".properties.provenance.attribution.contested"),(bool)),"sustained disclosure remains");
        status.effectiveAccepted=false;status.latestAcceptanceRecord=0;
        pdvm.mockCall(address(artist),query,abi.encode(abi.encode(status)));
        _state("disputed");
    }

    function testSupplementalPlatformFailureIsUnavailableNeverInferredAcceptance() public {
        artist.setPlatform(true);
        PW.State memory p=artist.platformWorksState(1);
        p.correction.accepted=false;p.correction.correctiveGeneration=1;p.correction.recordHash=keccak256("original");
        pdvm.mockCall(address(artist),abi.encodeCall(IStreamArtistPlatformWorks.platformWorksState,(uint256(1))),abi.encode(p));
        bytes memory query=abi.encodeCall(IStreamStaticArtistSource.staticDisplayRead,
            (abi.encodeCall(PlatformLineage.platformCorrectionStatus,(uint256(1)))));
        PL.Status memory status=PL.Status(keccak256("foreign"),keccak256("lineage"),2,1,true,keccak256("accepted"));
        pdvm.mockCall(address(artist),query,abi.encode(abi.encode(status)));_state("attribution_unavailable");
        status.originalCorrectionRecord=p.correction.recordHash;
        pdvm.mockCall(address(artist),query,abi.encode(new bytes(191)));_state("attribution_unavailable");
        status.count=2;
        pdvm.mockCall(address(artist),query,abi.encode(abi.encode(status)));_state("attribution_unavailable");
        status.count=1;
        pdvm.mockCall(address(artist),query,abi.encode(abi.encode(status)));_state("artist_accepted");
    }

    function testReadFailuresMissingSnapshotAndUnknownClassUseOnlyUnavailableObject() public {
        for (uint8 i = 1; i <= 4; ++i) {
            artist.configure(2, i, 1);
            _state("attribution_unavailable");
        }
        artist.configure(2, 0, 0);
        _state("attribution_unavailable");
        artist.configure(2, 0, 1);
        snapshot.configure(false, true);
        _state("attribution_unavailable");
        snapshot.configure(true, false);
        require(
            keccak256(
                bytes(_string(_json(), ".properties.provenance.attribution.attestation_status"))
            ) == keccak256("none"),
            "actual no selected snapshot"
        );
        vm.etch(address(artist), hex"00");
        _state("attribution_unavailable");
        string memory json = _json();
        require(
            _contains(bytes(json), bytes('"attribution":{"state":"attribution_unavailable"}')),
            "sole degraded object"
        );
    }

    function testSavedAnchorCannotBeReinitializedAfterCorruption() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.OriginalFinalityAnchorAlreadyInitialized.selector
            )
        );
        router.initializeOriginalFinalityAnchor();
        // Appended global anchor follows the original mapping at slot12. Verify both words first.
        require(
            vm.load(address(router), bytes32(uint256(13)))
                    == bytes32(uint256(uint160(address(original))))
                && vm.load(address(router), bytes32(uint256(14))) == address(original).codehash,
            "actual saved anchor slots"
        );
        vm.store(address(router), bytes32(uint256(13)), 0);
        vm.store(address(router), bytes32(uint256(14)), 0);
        vm.expectRevert();
        router.tokenMetadataJSON(address(core), 91);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.OriginalFinalityAnchorAlreadyInitialized.selector
            )
        );
        router.initializeOriginalFinalityAnchor();
        vm.store(
            address(router), bytes32(uint256(13)), bytes32(uint256(uint160(address(original))))
        );
        vm.store(address(router), bytes32(uint256(14)), address(original).codehash);
        _state("artist_accepted");
    }

    function testActualSafeInitializesAnchorAndOwnerCannotBypassIt() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xD151;
        keys[1] = 0xD152;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 815);
        StreamMetadataRouter other = new StreamMetadataRouter(
            address(core),
            address(safe),
            keccak256("deployment"),
            "urn:display",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
        address owner = vm.addr(keys[0]);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.Unauthorized.selector, owner));
        other.initializeOriginalFinalityAnchor();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.OriginalFinalityAnchorUninitialized.selector
            )
        );
        other.tokenMetadataJSON(address(core), 91);
        require(
            executeSafe(
                safe,
                keys,
                address(other),
                0,
                abi.encodeCall(other.initializeOriginalFinalityAnchor, ()),
                0
            ),
            "actual threshold Safe initialization"
        );
        (address selected, bytes32 hash) = other.servingOriginalFinalityAnchor();
        require(
            selected == address(original) && hash == address(original).codehash,
            "actual original binding"
        );
    }

    function testPureNestedFormatterRetainsFullWidthCountsAndRejectsUnknownAuthority() public {
        D.Facts memory f;
        f.state = 1;
        f.platform = true;
        f.consentMode = 3;
        f.claimCount = type(uint256).max;
        f.latestClaim = keccak256("claim");
        f.hasPlatformHistory = true;
        bytes memory json = StreamArtistDisplayJSON.render(f);
        require(
            _contains(
                json,
                bytes(
                    "115792089237316195423570985008687907853269984665640564039457584007913129639935"
                )
            ),
            "full uint256"
        );
        f.sanctionRecord = keccak256("sanction");
        f.sanctionClass = 0;
        vm.expectRevert(abi.encodeWithSelector(D.DisplayFactsUnavailable.selector));
        StreamArtistDisplayJSON.render(f);
    }

    function _contains(bytes memory all, bytes memory sub) private pure returns (bool) {
        for (uint256 i; i + sub.length <= all.length; ++i) {
            bool same = true;
            for (uint256 j; j < sub.length; ++j) {
                if (all[i + j] != sub[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }
}
