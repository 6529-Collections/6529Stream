// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamViewPreservationEvidenceBindingV1 as Snapshot
} from "../../interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../preservation/StreamPreservationInventoryIO.sol";

/// @notice Four closed same-provider identity getters under the original upper source ceiling.
/// @dev This does not weaken any nested dependency read cap or establish current evidence.
library StreamFinalityViewSameHostReadsV1 {
    function read(bytes4 selector, uint256 ceiling) internal view returns (bytes memory result) {
        uint256 size;
        if (selector == Sources.viewFinalitySources.selector) {
            size = 192;
        } else if (
            selector == Snapshot.viewPreservationSnapshotHost.selector
                || selector == Snapshot.viewPreservationSnapshotCodeHash.selector
                || selector == Snapshot.viewPreservationSnapshotValidationGas.selector
        ) {
            size = 32;
        } else {
            revert T.InventoryRead(address(this));
        }
        if (ceiling < 50000 || ceiling > type(uint64).max) revert T.InventoryRead(address(this));
        uint256 available = gasleft();
        // Account conservatively for the EIP-150 retained fraction before reserving 100k
        // for the fixed-size return and local epilogue. IO independently retains its strict
        // cap + cap/63 + 10k check after input encoding and before the actual STATICCALL.
        uint256 retained = available / 64 + 100000;
        if (available <= retained + 50000) revert T.InventoryRead(address(this));
        uint256 forwarded = available - retained;
        if (forwarded > ceiling) forwarded = ceiling;
        return IO.fixedRead(address(this), abi.encodeWithSelector(selector), size, forwarded);
    }
}
