// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistReconstruction.sol";
import "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Catalogs newly written Identity, Attribution and Consent owner rows after the original atomic operation succeeds.
/// @dev Archive remains Coordinator-only. These pointers grant no authorization or replay rights.
library StreamArtistPayloadSync {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_PAYLOAD_SYNC_STORAGE_V1");

    struct State {
        mapping(address => uint256) observed;
    }

    function sync(StreamArtistOnboardingTypes.SuiteConfiguration storage suite) public {
        bytes32 slot = SLOT;
        State storage s;
        assembly ("memory-safe") { s.slot := slot }
        for (uint256 owner = 2; owner < 7; owner += 2) {
            address source = suite.owners[owner];
            uint256 next = IStreamArtistReconstruction(source).storedPayloadCount();
            uint256 prior = s.observed[source];
            if (next < prior) revert StreamArtistOnboardingTypes.InvalidRecord();
            for (uint256 index = prior; index < next; ++index) {
                (address pointer, bytes32 kind, bytes32 hash) =
                    IStreamArtistReconstruction(source).storedPayloadAt(index);
                IStreamArtistPayloadArchive(suite.archive)
                    .registerArtistStoredPayload(pointer, kind, hash);
            }
            s.observed[source] = next;
        }
    }
}
