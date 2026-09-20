// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMetadataRecoveryRoutes.sol";
import { StreamMetadataDisplayParameters } from "./StreamMetadataDisplayParameters.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingEvidenceProvider.sol";
import "../../interfaces/stream/metadata/IStreamMetadataScopeMembership.sol";

/// @notice Same original scope proof with the fixed caller's authenticated read cap.
/// @dev Explicit cap transport avoids reading a parameter namespace at the STATIC worker address.
library StreamStaticArtistLineageScopeSource {
    error MetadataScopeBindingInvalid(address target);

    function host(
        address core,
        address router,
        StreamMetadataRecoveryRoutes.OriginalAnchor memory a,
        uint256 readGas
    ) internal view returns (address membership) {
        _pin(a.registry, a.codeHash);
        _equal(
            readGas,
            a.registry,
            abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()),
            core
        );
        address provider = _address(
            readGas,
            a.registry,
            abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ())
        );
        _pin(
            provider,
            _word(
                readGas,
                a.registry,
                abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ())
            )
        );
        _equal(readGas, provider, abi.encodeWithSignature("core()"), core);
        _pin(
            core,
            _word(
                readGas,
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.coreCodeHash, ())
            )
        );
        _equal(
            readGas,
            provider,
            abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataRouter, ()),
            router
        );
        _pin(
            router,
            _word(
                readGas,
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataRouterCodeHash, ())
            )
        );
        address metadata = _address(
            readGas, a.registry, abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ())
        );
        _equal(
            readGas,
            provider,
            abi.encodeCall(IStreamFinalityServingEvidenceProvider.metadataHost, ()),
            metadata
        );
        _pin(
            metadata,
            _word(
                readGas,
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataHostCodeHash, ())
            )
        );
        membership = _address(
            readGas,
            provider,
            abi.encodeCall(IStreamFinalityRouterEvidenceBinding.scopeMembershipHost, ())
        );
        _pin(
            membership,
            _word(
                readGas,
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.scopeMembershipHostCodeHash, ())
            )
        );
        _equal(readGas, membership, abi.encodeCall(IStreamFinalityScopeMembership.core, ()), core);
        _equal(
            readGas,
            membership,
            abi.encodeCall(IStreamFinalityScopeMembership.metadataHost, ()),
            metadata
        );
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (
            target == address(0) || codeHash == 0 || target.code.length == 0
                || target.codehash != codeHash
        ) revert MetadataScopeBindingInvalid(target);
    }

    function _word(uint256 readGas, address target, bytes memory input)
        private
        view
        returns (bytes32)
    {
        return abi.decode(StreamMetadataRecoveryRoutes.read(target, input, 32, readGas), (bytes32));
    }

    function _address(uint256 readGas, address target, bytes memory input)
        private
        view
        returns (address value)
    {
        uint256 word = uint256(_word(readGas, target, input));
        if (word == 0 || word > type(uint160).max) revert MetadataScopeBindingInvalid(target);
        return address(uint160(word));
    }

    function _equal(uint256 readGas, address target, bytes memory input, address expected)
        private
        view
    {
        if (_address(readGas, target, input) != expected) {
            revert MetadataScopeBindingInvalid(target);
        }
    }
}
