// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyInventoryFamilyV2 as Families
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as C
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as O
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamPreservationPolicyRenderCriticalDefinitionStagesV1 as CollectionDefinitions
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalDefinitionStagesV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalDefinitionsV1 as ScopedDefinitions
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalDefinitionsV1.sol";

/// @dev Explicit checkpoint read boundary. It does not produce or authorize a real checkpoint.
contract PreservationInventoryFamilyCheckpointBoundary {
    C.Plan private saved;
    bytes32 private profile;
    bytes32 private family;

    function set(C.Plan memory p, bytes32 profile_, bytes32 family_) external {
        saved = p;
        profile = profile_;
        family = family_;
    }

    function checkpoint(bytes32) external view returns (C.Plan memory) {
        return saved;
    }

    function preservationPolicyProfile() external view returns (bytes32) {
        return profile;
    }

    function preservationOutputProfile() external view returns (bytes32) {
        return family;
    }
}

contract PreservationInventoryFamilyProbe {
    function requirePlan(
        S.Dependencies memory d,
        address checkpoint,
        bytes32 pin,
        bytes32 id,
        C.Plan memory p,
        O.Manifest memory m,
        bool scoped
    ) external view returns (bytes32) {
        return Families.requirePlan(d, checkpoint, pin, id, p, m, scoped);
    }

    function allows(bytes32 family, bytes32 producer) external pure returns (bool) {
        return Families.allows(family, producer);
    }
}

/// @notice Real family/Plan comparison and definition selection, with a typed checkpoint boundary.
/// @dev No source admission, current resolver, governed producer registration or op60 is claimed.
contract StreamPreservationPolicyInventoryFamilyV2Test {
    PreservationInventoryFamilyProbe private probe;
    PreservationInventoryFamilyCheckpointBoundary private checkpoint;
    S.Dependencies private d;
    C.Plan private p;
    O.Manifest private m;
    bytes32 private constant ID = keccak256("actual pinned plan coordinate");

    function setUp() public {
        probe = new PreservationInventoryFamilyProbe();
        checkpoint = new PreservationInventoryFamilyCheckpointBoundary();
        d.chainId = block.chainid;
        d.readGas = 200000;
        d.targets[4] = address(0x1234);
        p.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 77, 0, 0);
        p.selectionId = keccak256("selection id");
        p.selectionHash = keccak256("complete selection");
        p.inventoryHash = keccak256("inventory");
        p.policyChainHash = keccak256("policy");
        p.tokenCount = 1;
        p.nextIndex = 1;
        p.leafChainHash = keccak256("leaf chain");
        p.contentRoot = keccak256("content");
        p.outputRoot = keccak256("outputs");
        p.preservationProfile = Profiles.FAMILY_PROFILE;
        m.checkpointHash = ID;
        m.metadataRouter = d.targets[4];
        m.preservationProfile = Profiles.FAMILY_PROFILE;
        _manifest();
        _checkpoint(false);
    }

    function _manifest() private {
        m.checkpointStateHash = keccak256(abi.encode(p));
        m.scope = p.scope;
        m.tokenCount = p.tokenCount;
        m.contentRoot = p.contentRoot;
        m.outputRoot = p.outputRoot;
        m.inventoryHash = p.inventoryHash;
        m.policyChainHash = p.policyChainHash;
    }

    function _checkpoint(bool scoped) private {
        checkpoint.set(
            p,
            scoped ? Profiles.SCOPED_CHECKPOINT_PROFILE : Profiles.COLLECTION_CHECKPOINT_PROFILE,
            Profiles.FAMILY_PROFILE
        );
    }

    function _read(bool scoped) private view returns (bytes32) {
        return
            probe.requirePlan(
                d, address(checkpoint), address(checkpoint).codehash, ID, p, m, scoped
            );
    }

    function _reject(bool scoped, bytes4 expected) private view {
        (bool ok, bytes memory reason) = address(probe)
            .staticcall(
                abi.encodeCall(
                    probe.requirePlan,
                    (d, address(checkpoint), address(checkpoint).codehash, ID, p, m, scoped)
                )
            );
        require(!ok && reason.length >= 4 && bytes4(reason) == expected, "exact family rejection");
    }

    function testCollectionRebindsExactCompleteSavedPlan() public view {
        require(_read(false) == Profiles.FAMILY_PROFILE);
    }

    function testAllThreeScopedKindsRebindExactCompleteSavedPlan() public {
        for (uint8 i = 1; i <= 3; ++i) {
            p.scope.scopeType = StreamFinalityScopeType(i);
            p.scope.tokenId = i == 1 ? 91 : 0;
            p.scope.scopeId = i == 1 ? bytes32(0) : bytes32(uint256(i));
            _manifest();
            _checkpoint(true);
            require(_read(true) == Profiles.FAMILY_PROFILE);
        }
    }

    function testV1DefaultDoesNotAcquireCheckpointReads() public view {
        C.Plan memory old;
        old.preservationProfile = Profiles.ORIGINAL_PROFILE;
        O.Manifest memory empty;
        require(
            probe.requirePlan(d, address(0), 0, 0, old, empty, false) == Profiles.ORIGINAL_PROFILE
        );
    }

    function testFamilyIsClosedAndViewCannotBecomeTokenProducer() public view {
        require(probe.allows(Profiles.ORIGINAL_PROFILE, Profiles.ORIGINAL_PROFILE));
        require(!probe.allows(Profiles.ORIGINAL_PROFILE, Profiles.CURRENT_ARTIST_PROFILE));
        require(probe.allows(Profiles.FAMILY_PROFILE, Profiles.ORIGINAL_PROFILE));
        require(probe.allows(Profiles.FAMILY_PROFILE, Profiles.CURRENT_ARTIST_PROFILE));
        require(
            !probe.allows(
                Profiles.FAMILY_PROFILE, keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1")
            )
        );
        require(!probe.allows(keccak256("unknown family"), Profiles.ORIGINAL_PROFILE));
        require(!probe.allows(Profiles.FAMILY_PROFILE, Profiles.FAMILY_PROFILE));
    }

    function testSavedPlanDriftCannotBeHiddenByMatchingManifest() public {
        p.selectionHash = keccak256("substituted selected state");
        _manifest();
        _reject(false, T.InventorySourceChanged.selector);
    }

    function testManifestMustBindEveryPlanJoin() public {
        bytes memory canonical = abi.encode(m);
        uint256[10] memory positions = [uint256(0), 1, 3, 4, 5, 6, 10, 11, 14, 17];
        for (uint256 i; i < positions.length; ++i) {
            bytes memory changed = bytes.concat(canonical);
            uint256 offset = positions[i] * 32;
            assembly ("memory-safe") {
                let a := add(add(changed, 32), offset)
                mstore(a, xor(mload(a), 1))
            }
            m = abi.decode(changed, (O.Manifest));
            _reject(false, T.InventorySourceChanged.selector);
        }
        m = abi.decode(canonical, (O.Manifest));
        require(_read(false) == Profiles.FAMILY_PROFILE);
    }

    function testIncompleteCheckpointCannotPassMatchingSavedBytes() public {
        p.nextIndex = 0;
        _manifest();
        _checkpoint(false);
        _reject(false, T.InventorySourceChanged.selector);
    }

    function testCollectionAndScopedCapabilitiesAreNotInterchangeable() public {
        p.scope.scopeType = StreamFinalityScopeType.TOKEN;
        p.scope.tokenId = 91;
        _manifest();
        _checkpoint(true);
        _reject(false, T.InventorySourceChanged.selector);
        require(_read(true) == Profiles.FAMILY_PROFILE);
    }

    function testCheckpointFamilyGetterMustMatchSavedFamily() public {
        checkpoint.set(p, Profiles.COLLECTION_CHECKPOINT_PROFILE, Profiles.ORIGINAL_PROFILE);
        _reject(false, T.InventorySourceChanged.selector);
    }

    function testUnknownAndCrossFamilyManifestFail() public {
        m.preservationProfile = Profiles.ORIGINAL_PROFILE;
        _reject(false, T.InventorySourceChanged.selector);
        m.preservationProfile = Profiles.FAMILY_PROFILE;
        p.preservationProfile = keccak256("unknown");
        _reject(false, T.InventorySourceChanged.selector);
    }

    function testDefinitionDispatchRetainsCommonAndLeafAndSeparatesBothV2Domains() public pure {
        for (uint64 i; i < 31; ++i) {
            _definition(i, false);
            _definition(i, true);
        }
    }

    function _definition(uint64 i, bool scoped) private pure {
        bytes32 a;
        bytes32 ah;
        bytes32 old;
        bytes32 oldh;
        bytes32 b;
        bytes32 bh;
        if (scoped) {
            (a, ah) = ScopedDefinitions.definition(i);
            (old, oldh) = ScopedDefinitions.definition(i, Profiles.ORIGINAL_PROFILE);
            (b, bh) = ScopedDefinitions.definition(i, Profiles.FAMILY_PROFILE);
        } else {
            (a, ah) = CollectionDefinitions.definition(i);
            (old, oldh) = CollectionDefinitions.definition(i, Profiles.ORIGINAL_PROFILE);
            (b, bh) = CollectionDefinitions.definition(i, Profiles.FAMILY_PROFILE);
        }
        require(a == old && ah == oldh);
        if (i < 20 || i == 28) require(a == b && ah == bh);
        else require(a != b && ah != bh);
    }
}
