// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryAdmission } from "./StreamArtistRecoveryAdmission.sol";
import "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";

/// @notice Original unavailability-preview codec; the host retains every live pin check.
library StreamArtistCoordinatorRecoveryRead {
    function prepareEncoded(
        T.SuiteConfiguration memory suite,
        address finality,
        bytes calldata data
    ) public view returns (bytes memory) {
        (Recovery.FindingRequest memory p, U.Target memory target) =
            abi.decode(data[4:], (Recovery.FindingRequest, U.Target));
        return
            abi.encode(StreamArtistRecoveryAdmission.prepare(suite, finality, p, target).context_);
    }
}
