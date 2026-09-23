// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistExtendedHydrationFeatures as XF
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistExtendedHydrationFeatures.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";

/// @notice Constant and transport negotiation controls, separate from actual owner import.
contract StreamArtistRecoveredMultipleGenerationFeatureIsolationTest {
    function check(RH.Capability memory c, uint8 index, uint256 required) external pure {
        Codec.requireCapability(c, index, required);
    }

    function testGenerationAndRecognitionMasksKeepTheirOriginalNumericalValues() external pure {
        assert(RH.KNOWN_FEATURES == 2097151);
        assert(RH.MULTIPLE_ATTESTATIONS_GRAPH_FEATURES == 2097151);
        assert(XF.MULTIPLE_GENERATIONS == 2097152);
        assert(XF.MULTIPLE_GENERATIONS_GRAPH_FEATURES == 4194303);
        assert(XF.KNOWN_FEATURES == 33554431);
        assert(G.FEATURE == XF.MULTIPLE_GENERATIONS);
        assert(G.ALLOWED == 2276351);
        assert((G.ALLOWED & ~XF.MULTIPLE_GENERATIONS_GRAPH_FEATURES) == 0);
    }

    function testEveryOwnerStillRequiresGenerationAdvertisement() external view {
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory c = _capability(index, 2097151);
            _reject(c, index, 2097152);
            c.supportedFeatures = 4194303;
            Codec.requireCapability(c, index, 2276351);
            Codec.requireCapability(c, index, 4194303);
            c.supportedFeatures = 2097151;
            Codec.requireCapability(c, index, 2097151);
        }
    }

    function testKnownFutureProfilesAreNotAdvertisedByTheGenerationGraph() external view {
        uint256[3] memory extensions = [uint256(4194304), uint256(8388608), uint256(16777216)];
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory c = _capability(index, XF.MULTIPLE_GENERATIONS_GRAPH_FEATURES);
            for (uint256 j; j < extensions.length; ++j) {
                assert((c.supportedFeatures & extensions[j]) == 0);
                _reject(c, index, G.ALLOWED | extensions[j]);
            }
        }
    }

    function _capability(uint8 index, uint256 features)
        private
        pure
        returns (RH.Capability memory)
    {
        return RH.Capability(
            RH.PROFILE,
            RH.VERSION,
            index,
            RH.ownerDomain(index),
            RH.CHECKPOINT,
            RH.ownerTag(index),
            features
        );
    }

    function _reject(RH.Capability memory c, uint8 index, uint256 required) private view {
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.check, (c, index, required)));
        assert(!ok);
        assert(
            keccak256(reason)
                == keccak256(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector))
        );
    }
}
