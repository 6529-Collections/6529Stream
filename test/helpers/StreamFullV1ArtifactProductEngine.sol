// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamFullV1ArtifactProductEngine } from "./StreamFullV1ArtifactProducts.sol";
import "../../script/current/StreamFullV1Candidate.sol";
import { StreamFullV1ArtifactProductStages } from "./StreamFullV1ArtifactProductStages.sol";

/// @notice Test-only artifact-backed construction, executed in the fixture by delegatecall.
contract StreamFullV1ArtifactProductEngine is IStreamFullV1ArtifactProductEngine {
    function deployGenesis(StreamFullV1GenesisProducts.Configuration memory c)
        external
        returns (StreamFullV1GenesisProducts.Products memory)
    {
        return StreamFullV1ArtifactProductStages.deployGenesis(c);
    }

    function deployCommerce(StreamFullV1CommerceProducts.Configuration memory c)
        external
        returns (StreamFullV1CommerceProducts.Products memory)
    {
        return StreamFullV1ArtifactProductStages.deployCommerce(c);
    }

    function deployRecords(StreamFullV1RecordProducts.Configuration memory c)
        external
        returns (StreamFullV1RecordProducts.Products memory)
    {
        return StreamFullV1ArtifactProductStages.deployRecords(c);
    }

    function deployContinuity(StreamFullV1ContinuityProducts.Configuration memory c)
        external
        returns (StreamFullV1ContinuityProducts.Products memory)
    {
        return StreamFullV1ArtifactProductStages.deployContinuity(c);
    }

    function deployProviders(
        StreamFullV1Candidate.Foundation memory f,
        StreamFullV1Candidate.ProviderConfiguration memory c
    ) external returns (StreamEntropyProviderVRF, StreamEntropyProviderARRNG) {
        return StreamFullV1ArtifactProductStages.deployProviders(f, c);
    }

    function deployRenderer(StreamFullV1StaticRendererPlan.Configuration memory c)
        external
        returns (StreamFullV1StaticRendererPlan.Products memory)
    {
        return StreamFullV1ArtifactProductStages.deployRenderer(c);
    }

    function deployRendererRegistry(
        StreamFullV1StaticRendererPlan.Configuration memory c,
        StreamFullV1StaticRendererPlan.Products memory p,
        V.Target[] memory targets
    ) external returns (StreamFullV1StaticRendererPlan.Products memory) {
        return StreamFullV1ArtifactProductStages.deployRendererRegistry(c, p, targets);
    }
}
