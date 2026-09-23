// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../script/current/StreamFullV1Candidate.sol";

interface StreamFullV1ArtifactEngineVm {
    function getDeployedCode(string calldata artifact) external returns (bytes memory);
    function etch(address target, bytes calldata code) external;
}

interface IStreamFullV1ArtifactProductEngine {
    function deployGenesis(StreamFullV1GenesisProducts.Configuration memory c)
        external
        returns (StreamFullV1GenesisProducts.Products memory);
    function deployCommerce(StreamFullV1CommerceProducts.Configuration memory c)
        external
        returns (StreamFullV1CommerceProducts.Products memory);
    function deployRecords(StreamFullV1RecordProducts.Configuration memory c)
        external
        returns (StreamFullV1RecordProducts.Products memory);
    function deployContinuity(StreamFullV1ContinuityProducts.Configuration memory c)
        external
        returns (StreamFullV1ContinuityProducts.Products memory);
    function deployProviders(
        StreamFullV1Candidate.Foundation memory f,
        StreamFullV1Candidate.ProviderConfiguration memory c
    ) external returns (StreamEntropyProviderVRF, StreamEntropyProviderARRNG);
    function deployRenderer(StreamFullV1StaticRendererPlan.Configuration memory c)
        external
        returns (StreamFullV1StaticRendererPlan.Products memory);
    function deployRendererRegistry(
        StreamFullV1StaticRendererPlan.Configuration memory c,
        StreamFullV1StaticRendererPlan.Products memory p,
        V.Target[] memory targets
    ) external returns (StreamFullV1StaticRendererPlan.Products memory);
}

/// @notice Thin test-only dispatch. Product CREATE runs by delegatecall in the original host.
/// @dev Seeding the genuine helper runtime with vm.etch performs no CREATE and does not
/// change the host's nonce, msg.sender, or product construction order.
library StreamFullV1ArtifactProducts {
    address private constant ENGINE = address(0x000000000000000000000000000000006529F011);
    string private constant ARTIFACT =
        "test/helpers/StreamFullV1ArtifactProductEngine.sol:StreamFullV1ArtifactProductEngine";

    function deployGenesis(StreamFullV1GenesisProducts.Configuration memory c)
        internal
        returns (StreamFullV1GenesisProducts.Products memory)
    {
        return abi.decode(
            _delegate(abi.encodeCall(IStreamFullV1ArtifactProductEngine.deployGenesis, (c))),
            (StreamFullV1GenesisProducts.Products)
        );
    }

    function deployCommerce(StreamFullV1CommerceProducts.Configuration memory c)
        internal
        returns (StreamFullV1CommerceProducts.Products memory)
    {
        return abi.decode(
            _delegate(abi.encodeCall(IStreamFullV1ArtifactProductEngine.deployCommerce, (c))),
            (StreamFullV1CommerceProducts.Products)
        );
    }

    function deployRecords(StreamFullV1RecordProducts.Configuration memory c)
        internal
        returns (StreamFullV1RecordProducts.Products memory)
    {
        return abi.decode(
            _delegate(abi.encodeCall(IStreamFullV1ArtifactProductEngine.deployRecords, (c))),
            (StreamFullV1RecordProducts.Products)
        );
    }

    function deployContinuity(StreamFullV1ContinuityProducts.Configuration memory c)
        internal
        returns (StreamFullV1ContinuityProducts.Products memory)
    {
        return abi.decode(
            _delegate(abi.encodeCall(IStreamFullV1ArtifactProductEngine.deployContinuity, (c))),
            (StreamFullV1ContinuityProducts.Products)
        );
    }

    function deployProviders(
        StreamFullV1Candidate.Foundation memory f,
        StreamFullV1Candidate.ProviderConfiguration memory c
    ) internal returns (StreamEntropyProviderVRF, StreamEntropyProviderARRNG) {
        return abi.decode(
            _delegate(abi.encodeCall(IStreamFullV1ArtifactProductEngine.deployProviders, (f, c))),
            (StreamEntropyProviderVRF, StreamEntropyProviderARRNG)
        );
    }

    function deployRenderer(StreamFullV1StaticRendererPlan.Configuration memory c)
        internal
        returns (StreamFullV1StaticRendererPlan.Products memory)
    {
        return abi.decode(
            _delegate(abi.encodeCall(IStreamFullV1ArtifactProductEngine.deployRenderer, (c))),
            (StreamFullV1StaticRendererPlan.Products)
        );
    }

    function deployRendererRegistry(
        StreamFullV1StaticRendererPlan.Configuration memory c,
        StreamFullV1StaticRendererPlan.Products memory p,
        V.Target[] memory targets
    ) internal returns (StreamFullV1StaticRendererPlan.Products memory) {
        return abi.decode(
            _delegate(
                abi.encodeCall(
                    IStreamFullV1ArtifactProductEngine.deployRendererRegistry, (c, p, targets)
                )
            ),
            (StreamFullV1StaticRendererPlan.Products)
        );
    }

    function _delegate(bytes memory callData) private returns (bytes memory result) {
        StreamFullV1ArtifactEngineVm cheat =
            StreamFullV1ArtifactEngineVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes memory runtime = cheat.getDeployedCode(ARTIFACT);
        require(runtime.length != 0, "missing full-v1 test engine artifact");
        bytes32 runtimeHash = keccak256(runtime);
        require(
            ENGINE.code.length == 0 || ENGINE.codehash == runtimeHash,
            "test engine address occupied"
        );
        if (ENGINE.code.length == 0) cheat.etch(ENGINE, runtime);
        require(ENGINE.codehash == runtimeHash, "test engine runtime differs");
        (bool ok, bytes memory returned) = ENGINE.delegatecall(callData);
        if (!ok) {
            assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        }
        return returned;
    }
}
