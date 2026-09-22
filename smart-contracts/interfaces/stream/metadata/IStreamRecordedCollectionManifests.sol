// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCollectionManifestTypes as M
} from "./StreamCollectionManifestTypes.sol";

interface IStreamRecordedCollectionManifests {
    function recordedScriptManifest(bytes32 hash) external view returns (M.ScriptManifest memory);
    function recordedMediaManifest(bytes32 hash) external view returns (M.MediaManifest memory);
}
