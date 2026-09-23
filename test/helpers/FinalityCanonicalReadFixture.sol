// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol";
import "../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import "./FinalityMocks.sol";
import "./FinalityReadProviderBoundary.sol";

interface FinalityReadFixtureVm {
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
}

/// @dev Constructor-only test boundary; no executing governance context or coverage success.
contract FinalityReadAuthorityBoundary {
    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        pure
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }

    function roleRegistry() external view returns (address) {
        return address(this);
    }

    function owner() external view returns (address) {
        return address(this);
    }
}

contract FinalityReadDiscoveryBoundary is MockFinalityDiscovery {
    address public immutable scopeEvidenceProvider;

    constructor(address provider) {
        scopeEvidenceProvider = provider;
    }
}

contract FinalityReadArtifactBoundary {
    address public immutable core;
    address public immutable finalityRegistry;
    address public immutable governanceAuthority;

    constructor(address core_, address registry_, address authority_) {
        core = core_;
        finalityRegistry = registry_;
        governanceAuthority = authority_;
    }
}

/// @dev Deploys the actual current Registry and Adapter for permanent read/hash vectors.
///      The explicit provider, governance and artifact boundaries cannot finalize artwork.
contract FinalityCanonicalReadFixture {
    function deploy() external returns (StreamArtworkFinalityRegistry registry) {
        MockFinalityCore core = new MockFinalityCore();
        MockFinalityMetadata metadata = new MockFinalityMetadata();
        MockFinalitySanction sanction = new MockFinalitySanction();
        FinalityReadAuthorityBoundary authority = new FinalityReadAuthorityBoundary();
        FinalityReadProviderBoundary provider =
            new FinalityReadProviderBoundary(address(core), address(metadata));
        FinalityReadDiscoveryBoundary discovery =
            new FinalityReadDiscoveryBoundary(address(provider));
        StreamCoreFinalityAdapter adapter =
            new StreamCoreFinalityAdapter(address(core), address(metadata), address(provider));
        FinalityReadFixtureVm cheat =
            FinalityReadFixtureVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        address predicted =
            cheat.computeCreateAddress(address(this), cheat.getNonce(address(this)) + 1);
        FinalityReadArtifactBoundary artifact =
            new FinalityReadArtifactBoundary(address(core), predicted, address(authority));
        registry = new StreamArtworkFinalityRegistry(
            address(core),
            address(metadata),
            address(adapter),
            address(sanction),
            address(authority),
            address(discovery),
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_COMPONENT_READ_GAS", 500000, 50000, 2
            ),
            StreamFinalityDeploymentConfiguration(
                address(artifact),
                keccak256("read fixture deployment"),
                "urn:read-fixture",
                keccak256("read fixture manifest")
            )
        );
        require(address(registry) == predicted, "actual constructor identity");
    }
}
