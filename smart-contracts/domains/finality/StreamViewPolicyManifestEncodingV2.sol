// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPolicyManifestTypesV2 as T
} from "../../interfaces/stream/finality/StreamViewPolicyManifestTypesV2.sol";
import {
    StreamViewPolicyCheckpointTypesV2 as C
} from "../../interfaces/stream/finality/StreamViewPolicyCheckpointTypesV2.sol";
import { StreamViewPolicyOutputSchemasV2 as S } from "./StreamViewPolicyOutputSchemasV2.sol";

/// @notice Literal canonical encoders; no supplied descriptor acquires authority here.
library StreamViewPolicyManifestEncodingV2 {
    function part(T.Configuration memory c, T.Header memory h, uint64 first, C.Output[] memory rows)
        public
        pure
        returns (bytes memory)
    {
        return
            abi.encode(
                S.PART,
                c.chainId,
                c.core,
                c.checkpoint,
                c.checkpointConfigurationHash,
                h,
                first,
                rows
            );
    }

    function index(
        T.Configuration memory c,
        T.Header memory h,
        bytes32 artistId,
        T.Descriptor[] memory parts
    ) public pure returns (bytes memory) {
        return abi.encode(
            S.INDEX,
            c.chainId,
            c.core,
            c.checkpoint,
            c.checkpointConfigurationHash,
            h,
            artistId,
            parts
        );
    }

    function descriptor(bytes32 key, T.Part memory p) internal pure returns (T.Descriptor memory) {
        return T.Descriptor(
            key,
            p.carrier.artifactHash,
            p.carrier.coverageHash,
            p.carrier.contentHash,
            p.carrier.byteLength,
            p.first,
            p.count,
            p.firstToken,
            p.lastToken
        );
    }
}
