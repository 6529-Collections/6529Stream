// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMetadataRecoveryRoutes.sol";
import { StreamMetadataDisplayParameters } from "./StreamMetadataDisplayParameters.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingEvidenceProvider.sol";
import "../../interfaces/stream/metadata/IStreamMetadataScopeMembership.sol";

/// @notice Router reads the same immutable scope universe as its original finality provider.
/// @dev No current provider selection, evidence-host liveness or content-authorization transition.
library StreamStaticScopeSource {
    error MetadataScopeBindingInvalid(address target);

    function host(
        address core,
        address router,
        StreamMetadataRecoveryRoutes.OriginalAnchor memory a
    ) internal view returns (address membership) {
        _pin(a.registry, a.codeHash);
        _equal(a.registry, abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()), core);
        address provider = _address(
            a.registry, abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ())
        );
        _pin(
            provider,
            _word(
                a.registry,
                abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ())
            )
        );
        _equal(provider, abi.encodeWithSignature("core()"), core);
        _pin(
            core,
            _word(provider, abi.encodeCall(IStreamFinalityRouterEvidenceBinding.coreCodeHash, ()))
        );
        _equal(
            provider,
            abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataRouter, ()),
            router
        );
        _pin(
            router,
            _word(
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataRouterCodeHash, ())
            )
        );
        address metadata = _address(
            a.registry, abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ())
        );
        _equal(
            provider,
            abi.encodeCall(IStreamFinalityServingEvidenceProvider.metadataHost, ()),
            metadata
        );
        _pin(
            metadata,
            _word(
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataHostCodeHash, ())
            )
        );
        membership = _address(
            provider, abi.encodeCall(IStreamFinalityRouterEvidenceBinding.scopeMembershipHost, ())
        );
        _pin(
            membership,
            _word(
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.scopeMembershipHostCodeHash, ())
            )
        );
        _equal(membership, abi.encodeCall(IStreamFinalityScopeMembership.core, ()), core);
        _equal(
            membership, abi.encodeCall(IStreamFinalityScopeMembership.metadataHost, ()), metadata
        );
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (
            target == address(0) || codeHash == 0 || target.code.length == 0
                || target.codehash != codeHash
        ) revert MetadataScopeBindingInvalid(target);
    }

    function _word(address target, bytes memory input) private view returns (bytes32) {
        return abi.decode(
            StreamMetadataRecoveryRoutes.read(
                target,
                input,
                32,
                StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.READ_GAS)
            ),
            (bytes32)
        );
    }

    function _address(address target, bytes memory input) private view returns (address value) {
        uint256 word = uint256(_word(target, input));
        if (word == 0 || word > type(uint160).max) revert MetadataScopeBindingInvalid(target);
        return address(uint160(word));
    }

    function _equal(address target, bytes memory input, address expected) private view {
        if (_address(target, input) != expected) revert MetadataScopeBindingInvalid(target);
    }
}
