// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistSanctionCandidate.sol";

/// @notice Fixed original sanction-preview codec; the coordinator retains its live pin checks.
library StreamArtistCoordinatorSanctionRead {
    function prepareEncoded(
        StreamArtistHashes.Environment memory environment,
        StreamArtistSanctionCandidate.Pins memory pins,
        bytes calldata data
    ) public view returns (bytes memory) {
        Q.Request memory p = abi.decode(data[4:], (Q.Request));
        return abi.encode(StreamArtistSanctionCandidate.prepare(environment, pins, p));
    }
}
