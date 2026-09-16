// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import {
    StreamArtistStewardCapabilityTypes as SC
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";

/// @notice Stored original Executor admission, including its captured independent terminal veto commitment.
library StreamArtistStewardGrantWitness {
    function read(address executor, address registry, SC.Grant memory p, SC.Context memory x)
        public
        view
        returns (SC.Witness memory w)
    {
        bool executing;
        uint8 class_;
        (
            executing,
            w.actionId,
            class_,
            w.context.scopeHash,
            w.context.oldValueHash,
            w.context.newValueHash
        ) =
            abi.decode(
                _read(executor, abi.encodeCall(IStreamGovernanceReads.currentAction, ()), 192, 192),
                (bool, bytes32, uint8, bytes32, bytes32, bytes32)
            );
        if (
            !executing || w.actionId == 0 || class_ != 2
                || keccak256(abi.encode(w.context)) != keccak256(abi.encode(x))
        ) revert SC.InvalidStewardGrantGovernance();
        bytes memory raw = _read(
            executor,
            abi.encodeCall(IStreamGovernanceReads.governanceAction, (w.actionId)),
            640,
            2688
        );
        GovernanceAction memory action = abi.decode(raw, (GovernanceAction));
        if (
            keccak256(raw) != keccak256(abi.encode(action))
                || action.status != GovernanceActionStatus.EXECUTED || action.actionClass != 2
                || action.proposer == address(0) || action.executor == address(0)
                || action.canceller != address(0) || action.vetoer != address(0)
                || action.notBefore == 0 || block.timestamp < action.notBefore
                || block.timestamp > action.expiresAfter || action.reasonHash != p.reasonHash
                || keccak256(bytes(action.reasonURI)) != keccak256(bytes(p.reasonURI))
        ) revert SC.InvalidStewardGrantGovernance();
        w.proposer = action.proposer;
        w.executionCaller = action.executor;
        w.notBefore = action.notBefore;
        w.expiresAfter = action.expiresAfter;
        w.actionManifestHash = action.manifestHash;
        w.guardianCommitment = abi.decode(
            _read(
                executor,
                abi.encodeCall(
                    IStreamGovernanceReads.terminalFreezeGuardianConfigCommitment, (w.actionId)
                ),
                32,
                32
            ),
            (bytes32)
        );
        bool freeze;
        bytes32 codeHash;
        (freeze, codeHash, w.selectorRevision, w.selectorConfigHash) = abi.decode(
            _read(
                executor,
                abi.encodeCall(
                    IStreamGovernanceReads.freezeSelectorConfig,
                    (registry, IStreamArtistStewardCapabilities.grantStewardCapabilities.selector)
                ),
                128,
                128
            ),
            (bool, bytes32, uint64, bytes32)
        );
        if (
            !freeze || codeHash != registry.codehash || w.selectorRevision == 0
                || w.selectorConfigHash == 0 || w.guardianCommitment == 0
        ) revert SC.InvalidStewardGrantGovernance();
        // The actual Executor already checked minimum delay, captured guardian-set equality and all vetoes before entering this call.
        // Its first-call indexing fields are not a substitute for the exact current per-call context in a batch.
    }

    function _read(address target, bytes memory data, uint256 minimum, uint256 maximum)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(maximum);
        bool ok;
        uint256 size;
        if (gasleft() < 20000) revert SC.InvalidStewardGrantGovernance();
        assembly ("memory-safe") {
            ok := staticcall(
                sub(gas(), 10000),
                target,
                add(data, 32),
                mload(data),
                add(raw, 32),
                maximum
            )
            size := returndatasize()
        }
        if (!ok || size < minimum || size > maximum || size % 32 != 0) {
            revert SC.InvalidStewardGrantGovernance();
        }
        assembly ("memory-safe") { mstore(raw, size) }
    }
}
