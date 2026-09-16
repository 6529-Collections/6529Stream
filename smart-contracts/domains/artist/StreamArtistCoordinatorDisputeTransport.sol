// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeOperations.sol";
import "./StreamArtistRepudiationOperations.sol";

/// @notice Original operation recipes reached only after the Coordinator's unchanged operation guard.
library StreamArtistCoordinatorDisputeTransport {
    function applyEncoded(D.CoordinatorContext memory x, bytes calldata data, uint16 op)
        public
        returns (bytes32)
    {
        if (op == 44 || op == 45) {
            (
                address actor,
                AD.Filing memory p,
                AD.Standing memory standing,
                T.Authorization memory a
            ) = abi.decode(data[4:], (address, AD.Filing, AD.Standing, T.Authorization));
            return StreamArtistDisputeOperations.file(x, actor, p, standing, a, op);
        }
        if (op == 46) {
            (address actor, AD.ResolutionRequest memory p) =
                abi.decode(data[4:], (address, AD.ResolutionRequest));
            return StreamArtistDisputeOperations.resolve(x, actor, p);
        }
        if (op == 47) {
            (address actor, AD.Filing memory p, T.Authorization memory a) =
                abi.decode(data[4:], (address, AD.Filing, T.Authorization));
            return StreamArtistRepudiationOperations.stage(x, actor, p, a);
        }
        if (op == 48) {
            (address actor, uint256 id, bytes32 expected, bytes32 reason) =
                abi.decode(data[4:], (address, uint256, bytes32, bytes32));
            StreamArtistRepudiationOperations.veto(x, actor, id, expected, reason);
            return 0;
        }
        (address actor, uint256 id, bytes32 expected) =
            abi.decode(data[4:], (address, uint256, bytes32));
        if (op == 49) StreamArtistRepudiationOperations.cancel(x, actor, id, expected);
        else if (op == 50) StreamArtistRepudiationOperations.execute(x, actor, id, expected);
        else revert T.InvalidOperation(op);
        return 0;
    }
}
