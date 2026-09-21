// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StaticArtistLineageFixture } from "./StreamStaticArtistLineage.t.sol";
import {
    StreamCurrentArtistPreservationAttributionV1 as P
} from "../../../smart-contracts/domains/metadata/StreamCurrentArtistPreservationAttributionV1.sol";
import {
    StreamStaticC2PAAttributionCompanion as C2PA
} from "../../../smart-contracts/domains/metadata/StreamStaticC2PAAttributionCompanion.sol";
import { PreservationReconciliationBoundary } from "./StreamPreservationAttribution.t.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

interface LineageColdVm {
    function cool(address) external;
    function coolSlot(address, bytes32) external;
}

/// @notice First-call cold catalogue budget checks, separate from warm parity and actual migration.
/// @dev Cooling accounts also cools their storage in the pinned Forge implementation. Every
/// reached suite target and the immutable catalogue carrier is cold before the first read.
contract StreamStaticArtistLineageColdTest is StaticArtistLineageFixture {
    LineageColdVm private constant cvm =
        LineageColdVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _cold() private {
        for (uint256 j; j < 3; ++j) {
            address finality = coordinators[j].finalityRegistry();
            address provider = coordinators[j].finalityEvidenceProvider();
            cvm.cool(finality);
            cvm.cool(provider);
            cvm.cool(address(coordinators[j]));
            cvm.cool(suites[j].registry);
            cvm.cool(suites[j].archive);
            cvm.cool(suites[j].mintManager);
            cvm.cool(suites[j].roleRegistry);
            cvm.cool(suites[j].primaryResolver);
            cvm.cool(suites[j].royaltyResolver);
            cvm.cool(suites[j].validator);
            for (uint256 i; i < 7; ++i) {
                cvm.cool(suites[j].owners[i]);
            }
        }
        cvm.cool(source.catalogueCarrier());
        cvm.cool(address(source));
        cvm.cool(address(core));
        cvm.cool(address(router));
    }

    function _firstRead() private {
        _cold();
        (bool ok, bytes memory raw) =
            address(source).staticcall{ gas: 250000 }(abi.encodeWithSignature("currentSuite()"));
        require(ok && raw.length == 544, "cold currentSuite exceeds original250k or fails");
    }

    function testColdOriginalCatalogueWithinOriginal250k() public {
        _firstRead();
    }

    function testColdImmediateCatalogueWithinOriginal250k() public {
        _prepare(1, 255, 255);
        _firstRead();
    }

    function testColdRepeatedCatalogueWithinOriginal250k() public {
        _prepare(1, 255, 255);
        _prepare(2, 255, 255);
        _firstRead();
    }
}

/// @notice Actual current-suite companion and fixed preservation wrapper; typed fact/authority graph.
contract StreamCurrentArtistPreservationAttributionTest is StaticArtistLineageFixture {
    function testCurrentPreservationMatchesFreshLineageAcrossAThenBAndC() public {
        P value = new P(address(companion), address(companion), address(0));
        require(
            value.preservationAttributionProfile()
                == keccak256("6529STREAM_CURRENT_ARTIST_NON_SANCTION_ATTRIBUTION_V1"),
            "explicit profile"
        );
        require(
            value.liveAttribution() == address(companion)
                && value.lineageSource() == address(source)
                && value.catalogueHash() == source.catalogueHash(),
            "exact immutable bindings"
        );
        for (uint256 i; i < 3; ++i) {
            if (i != 0) _prepare(i, 255, 255);
            require(
                keccak256(value.preservationAttribution(1, 0))
                    == keccak256(companion.preservationAttribution(1, 0)),
                "complete current projection"
            );
        }
    }

    function testCurrentPreservationRetainsC2PAReconciliationAndChainPins() public {
        PreservationReconciliationBoundary report = new PreservationReconciliationBoundary(
            address(core), address(router), suites[0].registry
        );
        C2PA live = new C2PA(
            address(companion),
            address(report),
            address(0),
            G.GasParameterConfig("C2PA_STATIC_ARTIST_GAS", 8000000, 100000, 2),
            G.GasParameterConfig("C2PA_STATIC_REPORT_GAS", 100000, 100000, 2)
        );
        P value = new P(address(companion), address(live), address(0));
        _prepare(1, 255, 255);
        _prepare(2, 255, 255);
        bytes32 expected = keccak256(value.preservationAttribution(1, 0));
        bytes memory saved = address(report).code;
        lvm.etch(address(report), hex"00");
        lvm.expectRevert(P.InvalidPreservationAttribution.selector);
        value.preservationAttribution(1, 0);
        lvm.etch(address(report), saved);
        require(keccak256(value.preservationAttribution(1, 0)) == expected, "same source restored");
        uint256 chain = source.sourceChainId();
        lvm.chainId(chain + 1);
        lvm.expectRevert(P.InvalidPreservationAttribution.selector);
        value.preservationAttribution(1, 0);
        lvm.chainId(chain);
        require(keccak256(value.preservationAttribution(1, 0)) == expected, "same chain restored");
    }

    function testCurrentPreservationCannotAcceptLegacyCompanionProfile() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("RendererReadFailed(address,bytes4)")),
                address(original),
                bytes4(keccak256("attributionProfile()"))
            )
        );
        new P(address(original), address(original), address(0));
    }
}
