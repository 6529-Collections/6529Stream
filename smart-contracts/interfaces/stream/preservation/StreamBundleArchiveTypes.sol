// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamExternalArtifactTypes.sol";
import "./StreamFinalityArtifactTypes.sol";

library StreamBundleArchiveTypes {
    struct Dependencies {
        // Core, Metadata, exact inventory producer, whole-byte coverage, external coverage,
        // original Artist Archive. Late reciprocal pins live only in constructor storage.
        address[6] targets;
        bytes32[6] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 archiveGas;
    }

    struct Proof {
        // 0 is explicit intrinsic/absent/platform/state applicability; 1 external, 2 onchain.
        uint8 backend;
        bytes32 coverageHash;
        bytes32 objectHash;
    }

    struct Admission {
        Proof proof;
        bytes32 originalBundleHash;
        bytes32 immutablePartsHash;
        StreamExternalArtifactTypes.Coverage externalOriginal;
        StreamFinalityArtifactTypes.Coverage onchainOriginal;
    }

    struct Progress {
        uint64 segmentIndex;
        uint64 segmentItemIndex;
        uint64 itemCount;
        bytes32 nextLink;
        bytes32 segmentChainHash;
        bytes32 evidenceChainHash;
        bytes32 environmentHash;
        bool complete;
    }

    struct Refresh {
        bytes32 environmentHash;
        uint64 nextIndex;
        bytes32 currentObservationChain;
        bool complete;
    }
}
