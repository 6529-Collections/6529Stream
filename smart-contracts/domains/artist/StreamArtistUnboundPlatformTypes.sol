// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistExtendedHydrationFeatures as XF
} from "../../interfaces/stream/artist/StreamArtistExtendedHydrationFeatures.sol";

/// @notice Explicit collection-only Platform profile; ordinary profiles retain their old domains.
library StreamArtistUnboundPlatformTypes {
    bytes32 internal constant TAG = keccak256("6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1");
    uint16 internal constant VERSION = 1;
    uint256 internal constant FEATURE = XF.UNBOUND_PLATFORM;
}
