// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamReferenceMetricStorage as Storage } from "./StreamReferenceMetricStorage.sol";
import {
    StreamReferenceModePreparation as Preparation
} from "./StreamReferenceModePreparation.sol";
import { StreamReferenceModeStateReads as StateReads } from "./StreamReferenceModeStateReads.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceMetricTypes as T
} from "../../interfaces/stream/preservation/StreamReferenceMetricTypes.sol";

import { StreamReferenceMetricCurrent as Current } from "./StreamReferenceMetricCurrent.sol";
import { StreamReferenceMetricProof as Proof } from "./StreamReferenceMetricProof.sol";

/// @notice Fixed same-call metric read. The actual host authenticates known/head/revision first.
/// @dev No checked object is accepted from a caller or survives a call. Complete original
/// source/runtime/schema/currentness and payload checks precede original supplement proof.
library StreamReferenceMetricReadExecution {
    function requireEncoded(
        Storage.State storage state,
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage evidence,
        M.Facts storage facts,
        Bytes.Manifest storage payload,
        R.Receipt storage receipt
    ) public view returns (bytes memory) {
        Proof.CompactInput memory input = Current.requireInput(
            d, bindings, publication, evidence, facts, payload, receipt
        );
        return abi.encode(Storage.requireCompact(state, d, receipt.recordHash, input));
    }
}
