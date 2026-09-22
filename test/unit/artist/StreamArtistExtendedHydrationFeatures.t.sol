// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredOwnerReads as Reads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredOwnerReads.sol";
import {
    StreamArtistOwnerHydration as Original
} from "../../../smart-contracts/domains/artist/StreamArtistOwnerHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as API
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";

/// @notice Synthetic feature negotiation; does not establish actual owner admission or migration.
contract StreamArtistExtendedHydrationFeaturesTest {
    mapping(bytes32 => T.ReplayCell) private replay;

    function check(RH.Capability memory capability, uint8 index, uint256 required) external pure {
        Codec.requireCapability(capability, index, required);
    }

    function readCapability(uint8 index, uint256 features, bytes calldata data)
        external
        view
        returns (bytes memory)
    {
        Original.Binding memory binding;
        binding.domain = RH.ownerDomain(index);
        return Reads.read(replay, binding, features, data);
    }

    function testKnownExtensionsRequireExplicitAdvertisementFromEachOwner() external view {
        uint256[3] memory extension = [uint256(4194304), uint256(8388608), uint256(16777216)];
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory c = _capability(index, RH.FIRST_GRAPH_FEATURES);
            Codec.requireCapability(c, index, RH.FIRST_GRAPH_FEATURES);
            for (uint256 j; j < extension.length; ++j) {
                uint256 required = RH.FIRST_GRAPH_FEATURES | extension[j];
                _rejectCapability(c, index, required);
                c.supportedFeatures = required;
                Codec.requireCapability(c, index, required);
                c.supportedFeatures = RH.FIRST_GRAPH_FEATURES;
            }
        }
    }

    function testCombinedExtensionsAndAdvertisedExtrasUseOnlyTheRequestedMask() external pure {
        for (uint8 index; index < 7; ++index) {
            RH.Capability memory c = _capability(index, type(uint256).max);
            // Existing negotiation constrains the request, not unrelated advertised bits.
            Codec.requireCapability(c, index, RH.FIRST_GRAPH_FEATURES);
            Codec.requireCapability(c, index, RH.FIRST_GRAPH_FEATURES | 4194304 | 8388608 | 16777216);
        }
    }

    function testKnownExtensionDoesNotBypassOwnerIdentityOrSchema() external view {
        RH.Capability memory c = _capability(2, 4194304);
        _rejectCapability(c, 3, 4194304);
        c.checkpointSchema = bytes32(uint256(1));
        _rejectCapability(c, 2, 4194304);
    }

    function testOwnerReadsPreserveExactlyTheSuppliedCapabilities() external view {
        bytes memory data =
            abi.encodeWithSelector(API.recoveredAuthorityHydrationCapability.selector);
        for (uint8 index; index < 7; ++index) {
            uint256 features = RH.FIRST_GRAPH_FEATURES | 4194304 | 8388608 | 16777216;
            RH.Capability memory c =
                abi.decode(this.readCapability(index, features, data), (RH.Capability));
            assert(keccak256(abi.encode(c)) == keccak256(abi.encode(_capability(index, features))));
            c = abi.decode(
                this.readCapability(index, RH.FIRST_GRAPH_FEATURES, data), (RH.Capability)
            );
            assert(c.supportedFeatures == RH.FIRST_GRAPH_FEATURES);
            _rejectCapability(c, index, features);
        }
    }

    function testFuzzUnknownBitFailsEvenWhenAdvertised(uint8 indexSeed, uint8 offset)
        external
        view
    {
        uint8 index = indexSeed % 7;
        uint256 unknown = uint256(1) << (25 + uint256(offset) % 231);
        _rejectCapability(_capability(index, type(uint256).max), index, unknown);
        bytes memory data =
            abi.encodeWithSelector(API.recoveredAuthorityHydrationCapability.selector);
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.readCapability, (index, unknown, data)));
        _assertRejected(ok, reason);
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

    function _rejectCapability(RH.Capability memory c, uint8 index, uint256 required) private view {
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.check, (c, index, required)));
        _assertRejected(ok, reason);
    }

    function _assertRejected(bool ok, bytes memory reason) private pure {
        assert(!ok);
        assert(
            keccak256(reason)
                == keccak256(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector))
        );
    }
}
