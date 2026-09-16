// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/FinalityCanonicalReadFixture.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Current Registry constructor inside its own bounded deployment CALL.
contract FinalityConstructorGasFactory {
    function deploy(
        address core,
        address metadata,
        address adapter,
        address sanction,
        address authority,
        address discovery,
        address artifact,
        uint256 budget
    ) external returns (StreamArtworkFinalityRegistry) {
        return new StreamArtworkFinalityRegistry(
            core,
            metadata,
            adapter,
            sanction,
            authority,
            discovery,
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_COMPONENT_READ_GAS", budget, 50_000, 2
            ),
            StreamFinalityDeploymentConfiguration(
                artifact,
                keccak256("constructor gas deployment"),
                "urn:constructor-gas",
                keccak256("constructor gas manifest")
            )
        );
    }
}

/// @dev Hostile constructor dependency. It supplies no finalization authority.
contract FinalityConstructorArtifactProbe {
    address private immutable _core;
    address public immutable finalityRegistry;
    address public immutable governanceAuthority;
    uint8 public mode;

    constructor(address core_, address registry_, address authority_) {
        _core = core_;
        finalityRegistry = registry_;
        governanceAuthority = authority_;
    }

    function setMode(uint8 value) external {
        mode = value;
    }

    function core() external view returns (address) {
        uint8 selected = mode;
        if (selected == 1) assembly ("memory-safe") { return(0, 0) }
        if (selected == 2) assembly ("memory-safe") { return(0, 31) }
        if (selected == 3) {
            // Registry must reject this without copying the oversized payload.
            assembly { return(0, 0x20000) }
        }
        if (selected == 4) {
            assembly ("memory-safe") {
                mstore(0, shl(160, 1))
                return(0, 32)
            }
        }
        if (selected == 5) assembly ("memory-safe") { for { } 1 { } { } }
        if (selected == 6) return address(0xBAD);
        return _core;
    }
}

contract StreamFinalityConstructorGasTest is CharacterizationTestBase {
    FinalityConstructorGasFactory private factory;
    MockFinalityCore private source;
    MockFinalityMetadata private metadata;
    MockFinalitySanction private sanction;
    FinalityReadAuthorityBoundary private authority;
    FinalityReadProviderBoundary private provider;
    FinalityReadDiscoveryBoundary private discovery;
    StreamCoreFinalityAdapter private adapter;
    FinalityConstructorArtifactProbe private artifact;
    address private predicted;

    event DeploymentGas(uint256 runtimeBudget, uint256 callEnvelope, uint256 used);

    function setUp() public {
        source = new MockFinalityCore();
        metadata = new MockFinalityMetadata();
        sanction = new MockFinalitySanction();
        authority = new FinalityReadAuthorityBoundary();
        provider = new FinalityReadProviderBoundary(address(source), address(metadata));
        discovery = new FinalityReadDiscoveryBoundary(address(provider));
        adapter =
            new StreamCoreFinalityAdapter(address(source), address(metadata), address(provider));
        factory = new FinalityConstructorGasFactory();
        FinalityReadFixtureVm cheat = FinalityReadFixtureVm(address(vm));
        predicted = cheat.computeCreateAddress(address(factory), cheat.getNonce(address(factory)));
        artifact =
            new FinalityConstructorArtifactProbe(address(source), predicted, address(authority));
    }

    function testDeploysWithThirtyMillionRuntimeBudgetInsideEightMillionEnvelope() public {
        _assertDeployment(30_000_000);
    }

    function testRetainsSmallConfiguredAdmissionCeiling() public {
        _assertDeployment(50_000);
    }

    function testRetainsOrdinaryConfiguredAdmissionCeiling() public {
        _assertDeployment(500_000);
    }

    function testFuzzRuntimeBudgetDoesNotBecomeMinimumDeploymentGas(uint64 extra) public {
        _assertDeployment(30_000_000 + uint256(extra));
    }

    function testRejectsEmptyReturnAndAllowsIdenticalRetryAfterRepair() public {
        _assertRejectedThenRetry(
            1, StreamArtworkFinalityRegistry.FinalityAdapterReturnShapeInvalid.selector
        );
    }

    function testRejectsTruncatedReturnAndAllowsIdenticalRetryAfterRepair() public {
        _assertRejectedThenRetry(
            2, StreamArtworkFinalityRegistry.FinalityAdapterReturnShapeInvalid.selector
        );
    }

    function testRejectsOversizedReturnWithoutCopyingIt() public {
        _assertRejectedThenRetry(
            3, StreamArtworkFinalityRegistry.FinalityAdapterReturnShapeInvalid.selector
        );
    }

    function testRejectsNoncanonicalAddressWord() public {
        _assertRejectedThenRetry(
            4, StreamArtworkFinalityRegistry.FinalityAdapterSemanticProbeInvalid.selector
        );
    }

    function testGasExhaustingDependencyLeavesRevertBudgetAndNoDeployedRegistry() public {
        _assertRejectedThenRetry(
            5, StreamArtworkFinalityRegistry.FinalityAdapterReturnShapeInvalid.selector
        );
    }

    function testRejectsDifferentArtifactCoreBinding() public {
        _assertRejectedThenRetry(
            6, IStreamCanonicalArtworkFinality.FinalityCurrentBindingInvalid.selector
        );
    }

    function testInsufficientCallerGasFailsWithoutPartialDeploymentThenCanRetry() public {
        (bool ok,) = address(factory).call{ gas: 100_000 }(_callData(30_000_000));
        require(
            !ok && predicted.code.length == 0, "insufficient constructor allowance fails closed"
        );
        _assertDeployment(30_000_000);
    }

    function _assertRejectedThenRetry(uint8 mode, bytes4 expectedError) private {
        artifact.setMode(mode);
        bytes memory data = _callData(30_000_000);
        (bool ok, bytes memory result) = address(factory).call{ gas: 8_000_000 }(data);
        require(!ok && predicted.code.length == 0, "invalid dependency cannot publish Registry");
        require(
            result.length >= 4 && bytes4(result) == expectedError,
            "bounded constructor error retained"
        );
        artifact.setMode(0);
        (ok, result) = address(factory).call{ gas: 8_000_000 }(data);
        require(
            ok && abi.decode(result, (address)) == predicted, "identical deployment retry succeeds"
        );
    }

    function _assertDeployment(uint256 budget) private {
        bytes memory data = _callData(budget);
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory result) = address(factory).call{ gas: 8_000_000 }(data);
        uint256 used = beforeGas - gasleft();
        require(
            ok && abi.decode(result, (address)) == predicted,
            "actual Registry deploys inside envelope"
        );
        StreamArtworkFinalityRegistry registry = StreamArtworkFinalityRegistry(predicted);
        require(
            registry.gasParameter(registry.GGP_FINALITY_COMPONENT_READ_GAS_KEY()) == budget,
            "runtime evidence budget unchanged"
        );
        require(
            predicted.code.length != 0 && predicted.code.length <= 24_576, "production runtime fits"
        );
        emit DeploymentGas(budget, 8_000_000, used);
    }

    function _callData(uint256 budget) private view returns (bytes memory) {
        return abi.encodeCall(
            factory.deploy,
            (
                address(source),
                address(metadata),
                address(adapter),
                address(sanction),
                address(authority),
                address(discovery),
                address(artifact),
                budget
            )
        );
    }
}
