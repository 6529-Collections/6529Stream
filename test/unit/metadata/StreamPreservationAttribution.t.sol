// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { PresentationCoreBoundary } from "./StreamMetadataServing.t.sol";
import {
    DisplayArtistBoundary,
    DisplaySnapshotBoundary,
    DisplayScopeBoundary,
    DisplayOriginalBoundary
} from "./StreamArtistDisplay.t.sol";
import {
    StreamStaticAttributionCompanion as Live
} from "../../../smart-contracts/domains/metadata/StreamStaticAttributionCompanion.sol";
import {
    StreamStaticC2PAAttributionCompanion as C2PA
} from "../../../smart-contracts/domains/metadata/StreamStaticC2PAAttributionCompanion.sol";
import {
    StreamPreservationAttributionCompanion as Preservation
} from "../../../smart-contracts/domains/metadata/StreamPreservationAttributionCompanion.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface PreservationVm {
    function etch(address, bytes calldata) external;
    function chainId(uint256) external;
}

contract PreservationRouterBoundary { }

contract PreservationReconciliationBoundary {
    address public core;
    address public router;
    address public artist;

    constructor(address c, address r, address a) {
        core = c;
        router = r;
        artist = a;
    }
}

/// @notice Actual old/new STATIC attribution producers; typed Core/Artist/snapshot/finality data.
/// @dev State controls model op12/op13 effects, not actual Artist authorization or finality ceremonies.
contract StreamPreservationAttributionTest is CharacterizationTestBase {
    PreservationVm private constant pvm =
        PreservationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    PresentationCoreBoundary private core;
    DisplayArtistBoundary private artist;
    DisplaySnapshotBoundary private snapshot;
    DisplayScopeBoundary private scopes;
    DisplayOriginalBoundary private original;
    PreservationRouterBoundary private router;
    Live private live;
    Preservation private saved;

    function setUp() public {
        core = new PresentationCoreBoundary();
        router = new PreservationRouterBoundary();
        artist = new DisplayArtistBoundary(address(core));
        core.configure(address(artist), address(0));
        scopes = new DisplayScopeBoundary(address(core), address(router));
        original = new DisplayOriginalBoundary(address(core), address(scopes));
        artist.bind(address(original));
        snapshot = new DisplaySnapshotBoundary(address(core), address(router), address(scopes));
        scopes.bindSources(address(snapshot), address(original));
        live = new Live(
            address(core), address(router), address(artist), address(original), address(0)
        );
        saved = new Preservation(address(live), address(live), address(0));
    }

    function testBaselineMatchesEveryOriginalAttributionByte() public view {
        require(
            keccak256(live.attribution(1, 91)) == keccak256(saved.preservationAttribution(1, 91)),
            "complete original projection"
        );
        require(
            saved.preservationAttributionProfile()
                == keccak256("6529STREAM_NON_SANCTION_ATTRIBUTION_V1"),
            "explicit profile"
        );
    }

    function testCollectionAndCoveringSanctionChangesOnlyLiveProjection() public {
        bytes memory baseline = saved.preservationAttribution(1, 91);
        artist.setSanction(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0), 1);
        require(keccak256(live.attribution(1, 91)) != keccak256(baseline), "live retains sanction");
        require(
            keccak256(saved.preservationAttribution(1, 91)) == keccak256(baseline),
            "sanction excluded explicitly"
        );
        artist.setSanction(
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, keccak256("release")), 4
        );
        scopes.configure(1, true);
        require(
            keccak256(saved.preservationAttribution(1, 91)) == keccak256(baseline),
            "covering-scope sanction excluded"
        );
        artist.configure(3, 0, 3);
        require(
            keccak256(saved.preservationAttribution(1, 91)) == keccak256(baseline),
            "confirmation 3->2 normalization"
        );
    }

    function testClaimsCollaboratorsAttestationAndAdverseStateRemainLive() public {
        bytes32 baseline = keccak256(saved.preservationAttribution(1, 91));
        artist.setCollaborator();
        require(
            keccak256(saved.preservationAttribution(1, 91)) != baseline, "collaborator retained"
        );
        bytes32 collaborators = keccak256(saved.preservationAttribution(1, 91));
        artist.setAttestation(2);
        require(
            keccak256(saved.preservationAttribution(1, 91)) != collaborators,
            "stale attestation retained"
        );
        artist.configure(5, 0, 3);
        require(
            keccak256(saved.preservationAttribution(1, 91)) == keccak256(live.attribution(1, 91)),
            "revocation unchanged"
        );
        artist.setPlatform(true);
        require(
            keccak256(saved.preservationAttribution(1, 91)) == keccak256(live.attribution(1, 91)),
            "claims and correction unchanged"
        );
    }

    function testMissingOriginalSourceRefusesThenSameReadRecovers() public {
        bytes32 expected = keccak256(saved.preservationAttribution(1, 91));
        snapshot.configure(false, true);
        vm.expectRevert();
        saved.preservationAttribution(1, 91);
        snapshot.configure(false, false);
        require(keccak256(saved.preservationAttribution(1, 91)) == expected, "exact retry");
    }

    function testC2PAWrapperPreservesReconciliationPinAndChainChecks() public {
        PreservationReconciliationBoundary report =
            new PreservationReconciliationBoundary(address(core), address(router), address(artist));
        C2PA wrapper = new C2PA(
            address(live),
            address(report),
            address(0),
            G.GasParameterConfig("C2PA_STATIC_ARTIST_GAS", 8000000, 100000, 2),
            G.GasParameterConfig("C2PA_STATIC_REPORT_GAS", 100000, 100000, 2)
        );
        Preservation value = new Preservation(address(live), address(wrapper), address(0));
        bytes32 expected = keccak256(value.preservationAttribution(1, 91));
        bytes memory code = address(report).code;
        pvm.etch(address(report), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.InvalidPreservationAttribution.selector)
        );
        value.preservationAttribution(1, 91);
        pvm.etch(address(report), code);
        require(
            keccak256(value.preservationAttribution(1, 91)) == expected,
            "restored immutable dependency"
        );
        uint256 chain = block.chainid;
        pvm.chainId(chain + 1);
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.InvalidPreservationAttribution.selector)
        );
        value.preservationAttribution(1, 91);
        pvm.chainId(chain);
        require(keccak256(value.preservationAttribution(1, 91)) == expected, "restored chain");
    }

    function testFuzzSanctionAuthorityNeverChangesPreservedFields(uint8 authority) public {
        authority = uint8(uint256(authority) % 4 + 1);
        bytes32 expected = keccak256(saved.preservationAttribution(1, 91));
        artist.setSanction(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, 0), authority);
        require(
            keccak256(saved.preservationAttribution(1, 91)) == expected,
            "all original authority classes"
        );
        require(keccak256(live.attribution(1, 91)) != expected, "original live object differs");
    }
}
