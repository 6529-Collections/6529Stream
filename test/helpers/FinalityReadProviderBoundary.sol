// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Test-only fixed identity adapter. Forwards actual mock metadata reads verbatim;
///      it supplies no successful scope evidence, archival or finalization authorization.
contract FinalityReadProviderBoundary {
    address public immutable core;
    address public immutable metadataHost;

    constructor(address core_, address metadataHost_) {
        core = core_;
        metadataHost = metadataHost_;
    }

    fallback() external {
        (bool ok, bytes memory data) = metadataHost.staticcall(msg.data);
        assembly ("memory-safe") {
            switch ok
            case 0 { revert(add(data, 32), mload(data)) }
            default { return(add(data, 32), mload(data)) }
        }
    }
}
