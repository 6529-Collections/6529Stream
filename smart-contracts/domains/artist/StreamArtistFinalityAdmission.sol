// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeEvidence.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed counterpart validation by the last-deployed Coordinator, before any operative use.
library StreamArtistFinalityAdmission {
    function admit(T.SuiteConfiguration memory suite, address finality)
        public
        view
        returns (address provider, bytes32 providerCodeHash)
    {
        if (finality.code.length == 0 || finality == address(this)) revert T.InvalidBinding();
        if (
            _address(finality, IStreamFinalityDeploymentBindings.coreReads.selector) != suite.core
                || _address(finality, IStreamFinalityDeploymentBindings.sanctionReads.selector)
                    != suite.registry
                || _address(
                        finality, IStreamFinalityDeploymentBindings.finalityRoleRegistry.selector
                    ) != suite.roleRegistry
                || _address(finality, IStreamGasParameterHost.governanceAuthority.selector)
                    != _address(
                        suite.registry, IStreamGasParameterHost.governanceAuthority.selector
                    )
                || _word(finality, IStreamModule.streamModuleType.selector)
                    != keccak256("ARTWORK_FINALITY_REGISTRY")
                || _word(finality, IStreamModule.streamModuleInterfaceId.selector)
                    != bytes32(type(IStreamArtworkFinalityRegistry).interfaceId)
        ) revert T.InvalidBinding();
        // Suite.metadata is the content Router. Finality separately pins the generic record host.
        address metadataHost =
            _address(finality, IStreamFinalityDeploymentBindings.metadataReads.selector);
        if (
            metadataHost.code.length == 0
                || _address(metadataHost, IStreamFinalityScopeEvidence.core.selector) != suite.core
        ) revert T.InvalidBinding();
        provider =
            _address(finality, IStreamFinalityDeploymentBindings.scopeEvidenceProvider.selector);
        if (
            provider.code.length == 0
                || _address(provider, IStreamFinalityScopeEvidence.core.selector) != suite.core
                || _address(provider, IStreamFinalityEvidenceProvider.metadataHost.selector)
                    != metadataHost
        ) revert T.InvalidBinding();
        address artifact =
            _address(finality, IStreamFinalityDeploymentBindings.artifactCoverage.selector);
        if (
            artifact.code.length == 0
                || _address(artifact, IStreamFinalityArtifactCoverage.core.selector) != suite.core
                || _address(artifact, IStreamFinalityArtifactCoverage.finalityRegistry.selector)
                    != finality
        ) revert T.InvalidBinding();
        return (provider, provider.codehash);
    }

    function _address(address target, bytes4 selector) private view returns (address result) {
        uint256 word = uint256(_word(target, selector));
        if (word >> 160 != 0) revert T.InvalidBinding();
        return address(uint160(word));
    }

    function _word(address target, bytes4 selector) private view returns (bytes32 value) {
        bytes memory input = abi.encodeWithSelector(selector);
        bool ok;
        uint256 length;
        assembly ("memory-safe") {
            let out := mload(0x40)
            ok := staticcall(150000, target, add(input, 32), mload(input), out, 32)
            length := returndatasize()
            value := mload(out)
        }
        if (!ok || length != 32) revert T.InvalidBinding();
    }
}
