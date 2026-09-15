// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianAppealAuthority } from "./StreamArtistGuardianAppealAuthority.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as R
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    IStreamGovernanceReads
} from "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import {
    GovernanceActionStatus
} from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @notice Exact operation35 active-call witness at the restricted root-admin APPEAL tier.
library StreamArtistGuardianAppealGovernance {
    function read(
        D.CoordinatorContext memory x,
        address authority,
        address actor,
        bytes32 reason,
        R.Context memory c
    ) public view returns (C.GovernanceWitness memory g) {
        if (actor != authority || authority == address(0) || reason == 0) {
            revert R.InvalidIdentityRecoveryGovernance();
        }
        bytes memory sealedState = _fixed(
            authority, abi.encodeCall(IStreamGovernanceReads.systemManifestBootstrapState, ()), 928
        );
        if (_word(sealedState, 0) != 1 || _word(sealedState, 1) != 1) {
            revert R.InvalidIdentityRecoveryGovernance();
        }
        bool executing;
        (executing, g.actionId, g.actionClass, g.scopeHash, g.oldValueHash, g.newValueHash) =
            abi.decode(
                _fixed(authority, abi.encodeCall(IStreamGovernanceReads.currentAction, ()), 192),
                (bool, bytes32, uint8, bytes32, bytes32, bytes32)
            );
        if (
            !executing || g.actionId == 0 || g.actionClass != 2 || g.scopeHash != c.scopeHash
                || g.oldValueHash != c.oldValueHash || g.newValueHash != c.newValueHash
        ) revert R.InvalidIdentityRecoveryGovernance();
        (bytes memory header, uint256 size) = _read(
            authority, abi.encodeCall(IStreamGovernanceReads.governanceAction, (g.actionId)), 640
        );
        uint256 uriLength = _word(header, 19);
        if (
            _word(header, 0) != 32 || _word(header, 17) != 576 || uriLength > size - 640
                || size % 32 != 0 || size - 640 - uriLength > 31
                || _word(header, 1) != uint256(GovernanceActionStatus.EXECUTED)
                || _word(header, 2) != 2 || _word(header, 3) >> 160 != 0
                || _word(header, 5) << 32 != 0 || _word(header, 10) > type(uint64).max
                || _word(header, 11) > type(uint64).max || _word(header, 12) >> 160 != 0
                || _word(header, 13) >> 160 != 0 || _word(header, 14) >> 160 != 0
                || _word(header, 15) >> 160 != 0 || bytes32(_word(header, 16)) != reason
        ) revert R.InvalidIdentityRecoveryGovernance();
        g.proposer = address(uint160(_word(header, 12)));
        (g.roleMutationHash, g.roleRevision) = StreamArtistGuardianAppealAuthority.requireProposer(
            authority, x.suite.roleRegistry, g.proposer
        );
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(data, 32), mul(index, 32))) }
    }

    function _fixed(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory result)
    {
        uint256 size;
        (result, size) = _read(target, data, length);
        if (size != length) revert R.InvalidIdentityRecoveryGovernance();
    }

    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory result, uint256 size)
    {
        result = new bytes(length);
        bool ok;
        if (gasleft() < 20_000) revert R.InvalidIdentityRecoveryGovernance();
        assembly ("memory-safe") {
            ok := staticcall(
                sub(gas(), 10000),
                target,
                add(data, 32),
                mload(data),
                add(result, 32),
                length
            )
            size := returndatasize()
        }
        if (!ok || size < length) revert R.InvalidIdentityRecoveryGovernance();
    }
}
