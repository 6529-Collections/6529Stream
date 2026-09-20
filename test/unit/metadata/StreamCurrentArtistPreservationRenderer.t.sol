// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StaticMetadataRoutingFixture } from "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    StreamCurrentArtistPreservationRendererV1 as Producer
} from "../../../smart-contracts/domains/metadata/StreamCurrentArtistPreservationRendererV1.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";

import {
    StreamPreservationRendererV1 as OriginalProducer
} from "../../../smart-contracts/domains/metadata/StreamPreservationRendererV1.sol";
import { PreservationArtistBoundary as OriginalArtist } from "./StreamPreservationRenderer.t.sol";
import {
    StreamPreservationAdmission as Admission
} from "../../../smart-contracts/domains/metadata/StreamPreservationAdmission.sol";
import {
    IStreamPreservationRegistryV1 as AP
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";

contract CurrentArtistPreservationBindingProbe {
    function check(AP.ProducerBinding calldata b, V.Version calldata v) external view {
        Admission.requireBindings(b, v, 2000000);
    }
}

interface CurrentArtistPreservationRendererVm {
    function etch(address, bytes calldata) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @dev Explicit attribution boundary for renderer-only output/source tests, not genuine Artist admission.
contract CurrentArtistPreservationArtistBoundary {
    address public core;
    address public router;
    address public liveAttribution;
    bytes32 public liveAttributionCodeHash;
    bool public fail;
    error Unavailable();

    constructor(address c, address r, address live_) {
        core = c;
        router = r;
        liveAttribution = live_;
        liveAttributionCodeHash = live_.codehash;
    }

    function preservationAttributionProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_CURRENT_ARTIST_NON_SANCTION_ATTRIBUTION_V1");
    }

    function preservationAttribution(uint256, uint256) external view returns (bytes memory) {
        if (fail) revert Unavailable();
        return bytes('{"state":"disputed"}');
    }

    function setFail(bool value) external {
        fail = value;
    }
}

contract StreamCurrentArtistPreservationRendererTest is StaticMetadataRoutingFixture {
    CurrentArtistPreservationRendererVm private constant pvm = CurrentArtistPreservationRendererVm(
        address(uint160(uint256(keccak256("hevm cheat code"))))
    );
    CurrentArtistPreservationArtistBoundary private projection;
    Producer private producer;

    function setUp() public override {
        super.setUp();
        _activate();
        _mint();
        _optInCurrentCitationAdmissionBoundary();
        projection = new CurrentArtistPreservationArtistBoundary(
            address(core), address(router), address(attribution)
        );
        producer = new Producer(
            address(renderer),
            address(projection),
            address(executor),
            G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2),
            G.GasParameterConfig("STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1)
        );
    }

    function testActualFullCurrentJSONAndHTMLRemainByteExactWithoutSanction() public view {
        require(
            keccak256(bytes(producer.preservationTokenJSON(91)))
                == keccak256(bytes(router.tokenJSON(91))),
            "full current JSON"
        );
        require(
            keccak256(bytes(producer.preservationTokenHTML(91)))
                == keccak256(bytes(router.tokenHTML(91))),
            "full current HTML"
        );
    }

    function testUnknownTokenAndNonfinalizedEntropyCannotBecomePreservationSuccess() public {
        vm.expectRevert(abi.encodeWithSelector(Producer.InvalidStaticRender.selector));
        producer.preservationTokenJSON(99);
        entropy.setFinalized(false);
        vm.expectRevert(abi.encodeWithSelector(Producer.InvalidStaticRender.selector));
        producer.preservationTokenJSON(91);
        entropy.setFinalized(true);
        require(bytes(producer.preservationTokenJSON(91)).length != 0, "exact restored token");
    }

    function testBurnedRetainedTokenUsesCurrentFullRequestNotCompactHistoricalOutput() public {
        core.setToken(91, address(0), 3);
        require(
            keccak256(bytes(producer.preservationTokenJSON(91)))
                == keccak256(bytes(router.tokenJSON(91))),
            "retained burned full JSON"
        );
        require(
            keccak256(bytes(producer.preservationTokenHTML(91)))
                == keccak256(bytes(router.tokenHTML(91))),
            "retained burned HTML"
        );
    }

    function testMissingAttributionFailsAndExactSourceRestoreRetries() public {
        bytes32 expected = keccak256(bytes(producer.preservationTokenJSON(91)));
        projection.setFail(true);
        vm.expectRevert();
        producer.preservationTokenJSON(91);
        projection.setFail(false);
        require(
            keccak256(bytes(producer.preservationTokenJSON(91))) == expected,
            "no fallback and same source retry"
        );
    }

    function testChangedOriginalRendererRuntimeFailsClosed() public {
        bytes memory code = address(renderer).code;
        bytes32 expected = keccak256(bytes(producer.preservationTokenJSON(91)));
        pvm.etch(address(renderer), hex"00");
        vm.expectRevert(abi.encodeWithSelector(Producer.InvalidStaticRender.selector));
        producer.preservationTokenJSON(91);
        pvm.etch(address(renderer), code);
        require(
            keccak256(bytes(producer.preservationTokenJSON(91))) == expected,
            "restored pinned renderer"
        );
    }

    function testCurrentOriginalCoordinatorCannotBeSubstituted() public {
        address original = address(entropy);
        core.setEntropy(address(this));
        vm.expectRevert(abi.encodeWithSelector(Producer.InvalidStaticRender.selector));
        producer.preservationTokenJSON(91);
        core.setEntropy(original);
        require(bytes(producer.preservationTokenJSON(91)).length != 0, "original-at-mint relation");
    }

    function testNoAdmissionClaimIsInferredFromSuccessfulProducer() public view {
        // This fixture intentionally has only the named old admission boundary. A finality
        // consumer still needs the separate governed requirePreservation tuple.
        require(
            producer.preservationProfile()
                == keccak256("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1"),
            "distinct profile"
        );
        (address c, address r, address live_, bytes32 pin, address a, bytes32 aPin) =
            producer.preservationBinding();
        require(
            c == address(core) && r == address(router) && live_ == address(renderer)
                && pin == address(renderer).codehash && a == address(projection)
                && aPin == address(projection).codehash,
            "literal six fields"
        );
    }

    function testClosedCurrentAndOriginalProfilesRequireTheirExactAttribution() public {
        G.GasParameterConfig memory read =
            G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2);
        G.GasParameterConfig memory artistGas =
            G.GasParameterConfig("STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1);
        vm.expectRevert(abi.encodeWithSelector(OriginalProducer.InvalidStaticRender.selector));
        new OriginalProducer(
            address(renderer), address(projection), address(executor), read, artistGas
        );
        OriginalArtist old = new OriginalArtist(
            address(core), address(router), address(attribution)
        );
        vm.expectRevert(abi.encodeWithSelector(Producer.InvalidStaticRender.selector));
        new Producer(address(renderer), address(old), address(executor), read, artistGas);
        OriginalProducer oldProducer =
            new OriginalProducer(
            address(renderer), address(old), address(executor), read, artistGas
        );
        CurrentArtistPreservationBindingProbe probe = new CurrentArtistPreservationBindingProbe();
        V.Version memory v;
        v.exists = true;
        v.renderer = address(renderer);
        v.runtimeHash = address(renderer).codehash;
        AP.ProducerBinding memory b = AP.ProducerBinding(
            address(producer),
            address(producer).codehash,
            keccak256("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1"),
            address(core),
            address(router),
            address(renderer),
            address(renderer).codehash,
            address(projection),
            address(projection).codehash
        );
        probe.check(b, v);
        b.profile = keccak256("unknown profile");
        vm.expectRevert(abi.encodeWithSelector(AP.InvalidPreservationAdmission.selector));
        probe.check(b, v);
        b.profile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        vm.expectRevert(abi.encodeWithSelector(AP.InvalidPreservationAdmission.selector));
        probe.check(b, v);
        b.producer = address(oldProducer);
        b.producerCodeHash = address(oldProducer).codehash;
        b.attribution = address(old);
        b.attributionCodeHash = address(old).codehash;
        probe.check(b, v);
        b.profile = keccak256("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1");
        vm.expectRevert(abi.encodeWithSelector(AP.InvalidPreservationAdmission.selector));
        probe.check(b, v);
    }
}
