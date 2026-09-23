// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityNativeProviderReads
} from "../../../domains/finality/StreamFinalityNativeProviderReads.sol";

// Selector projections of actual owner APIs. Absence/malformed replies fail; no fallback hash.
interface IStreamArtistSnapshotConfiguration {
    function nativeConfiguration()
        external
        view
        returns (StreamFinalityNativeProviderReads.Config memory);
}
