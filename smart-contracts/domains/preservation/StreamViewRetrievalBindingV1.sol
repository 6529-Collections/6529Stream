// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewRetrievalInventoryBindingV1 as Binding
} from "../../interfaces/stream/preservation/IStreamViewRetrievalInventoryBindingV1.sol";
import {
    IStreamViewRetrievalWitnessV1 as Witness
} from "../../interfaces/stream/preservation/IStreamViewRetrievalWitnessV1.sol";
import {
    StreamViewRetrievalWitnessTypesV1 as W
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamViewRetrievalSourceV1 as Source } from "./StreamViewRetrievalSourceV1.sol";

/// @notice Constructor-owned companion validation only. No current root/output/reference call.
library StreamViewRetrievalBindingV1 {
    function requireInventory(address inventory, S.Dependencies memory d, uint256 cap)
        public
        view
        returns (address witness, bytes32 codeHash, W.Configuration memory c)
    {
        if (
            IO.word(
                    inventory,
                    abi.encodeWithSignature("supportsInterface(bytes4)", type(Binding).interfaceId),
                    cap
                ) != bytes32(uint256(1))
        ) revert W.InvalidViewRetrieval();
        bytes memory raw =
            IO.fixedRead(inventory, abi.encodeCall(Binding.retrievalWitnessBinding, ()), 64, cap);
        (witness, codeHash) = abi.decode(raw, (address, bytes32));
        IO.canonical(inventory, raw, abi.encode(witness, codeHash));
        c = requireConfiguration(d, witness, codeHash, cap);
    }

    function requireConfiguration(
        S.Dependencies memory d,
        address witness,
        bytes32 codeHash,
        uint256 cap
    ) public view returns (W.Configuration memory c) {
        IO.pin(witness, codeHash);
        bytes memory raw = IO.fixedRead(
            witness, abi.encodeCall(Witness.configuration, ()), 416, cap
        );
        c = abi.decode(raw, (W.Configuration));
        IO.canonical(witness, raw, abi.encode(c));
        if (
            c.core != d.targets[0] || c.coreCodeHash != d.codeHashes[0] || c.router != d.targets[4]
                || c.routerCodeHash != d.codeHashes[4] || c.archive != d.targets[11]
                || c.archiveCodeHash != d.codeHashes[11] || c.chainId != d.chainId
                || IO.word(witness, abi.encodeCall(Witness.configurationHash, ()), cap)
                    != keccak256(abi.encode(W.PROFILE, c))
                || IO.word(witness, abi.encodeCall(Witness.retrievalProfile, ()), cap) != W.PROFILE
                || IO.word(
                        witness,
                        abi.encodeWithSignature(
                            "supportsInterface(bytes4)", type(Witness).interfaceId
                        ),
                        cap
                    ) != bytes32(uint256(1))
        ) revert W.InvalidViewRetrieval();
        IO.pin(d.targets[5], d.codeHashes[5]);
        raw = IO.fixedRead(d.targets[5], abi.encodeWithSignature("dependencies()"), 768, cap);
        Snapshot.Dependencies memory snap = abi.decode(raw, (Snapshot.Dependencies));
        IO.canonical(d.targets[5], raw, abi.encode(snap));
        if (
            snap.targets[0] != d.targets[0] || snap.codeHashes[0] != d.codeHashes[0]
                || snap.targets[4] != d.targets[4] || snap.codeHashes[4] != d.codeHashes[4]
                || snap.targets[6] != c.checkpoint || snap.codeHashes[6] != c.checkpointCodeHash
                || snap.chainId != d.chainId
        ) revert W.InvalidViewRetrieval();
        Source.validate(c);
    }
}
