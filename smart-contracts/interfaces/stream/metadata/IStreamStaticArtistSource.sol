// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Proposed additive STATIC AA-DISPLAY transport. Original method ABIs and facts are unchanged.
/// @dev Implementations admit only the 13 original selectors listed in static-artist-source.md.
/// Every transitive read uses bounded STATICCALL; fixed delegatecall codecs are not conformant.
/// A missing/failed/malformed transport fails the optional display frame, never selecting old calls.
interface IStreamStaticArtistSource {
    function staticDisplayRead(bytes calldata originalCalldata)
        external
        view
        returns (bytes memory originalAbiResult);
}
