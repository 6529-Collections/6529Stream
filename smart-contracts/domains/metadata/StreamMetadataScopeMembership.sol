// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMetadataRecoveryRoutes.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingEvidenceProvider.sol";
import "../../interfaces/stream/metadata/IStreamMetadataScopeMembership.sol";

/// @notice Router reads the same immutable scope universe as its original finality provider.
/// @dev No current provider selection, evidence-host liveness or content-authorization transition.
library StreamMetadataScopeMembership {
    uint256 private constant PIN_GAS = 150000;
    uint256 private constant MEMBERSHIP_GAS = 2000000;
    error MetadataScopeBindingInvalid(address target);

    function read(
        mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) storage presentation,
        mapping(uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor) storage anchors,
        StreamMetadataRecoveryRoutes.Environment memory e,
        bytes calldata callData
    ) public view returns (uint256 result) {
        if (callData.length != 164) {
            revert MetadataScopeBindingInvalid(address(this));
        }
        bool indexedRead = bytes4(callData) == IStreamMetadataScopeMembership.scopeTokenAt.selector;
        if (
            !indexedRead
                && bytes4(callData) != IStreamMetadataScopeMembership.scopeCoversToken.selector
        ) {
            revert MetadataScopeBindingInvalid(address(this));
        }
        (StreamFinalityScope memory scope, uint256 value) =
            abi.decode(callData[4:], (StreamFinalityScope, uint256));
        StreamMetadataRecoveryRoutes.OriginalAnchor memory a = anchors[scope.collectionId];
        if (presentation[scope.collectionId].locked) {
            _pin(a.registry, a.codeHash);
            _equal(
                a.registry, abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()), e.core
            );
        } else {
            if (a.registry != address(0) || a.codeHash != 0) {
                revert MetadataScopeBindingInvalid(a.registry);
            }
            a = StreamMetadataRecoveryRoutes.captureOriginal(e);
        }
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
        _equal(provider, abi.encodeWithSignature("core()"), e.core);
        _pin(
            e.core,
            _word(provider, abi.encodeCall(IStreamFinalityRouterEvidenceBinding.coreCodeHash, ()))
        );
        _equal(
            provider,
            abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataRouter, ()),
            address(this)
        );
        _pin(
            address(this),
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
        address membership = _address(
            provider, abi.encodeCall(IStreamFinalityRouterEvidenceBinding.scopeMembershipHost, ())
        );
        _pin(
            membership,
            _word(
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.scopeMembershipHostCodeHash, ())
            )
        );
        _equal(membership, abi.encodeCall(IStreamFinalityScopeMembership.core, ()), e.core);
        _equal(
            membership, abi.encodeCall(IStreamFinalityScopeMembership.metadataHost, ()), metadata
        );
        bytes memory input = indexedRead
            ? abi.encodeCall(IStreamFinalityScopeMembership.scopeTokenAt, (scope, value))
            : abi.encodeCall(IStreamFinalityScopeMembership.scopeCoversToken, (scope, value));
        result = abi.decode(
            StreamMetadataRecoveryRoutes.read(membership, input, 32, MEMBERSHIP_GAS), (uint256)
        );
        if (!indexedRead && result > 1) revert MetadataScopeBindingInvalid(membership);
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (
            target == address(0) || codeHash == 0 || target.code.length == 0
                || target.codehash != codeHash
        ) revert MetadataScopeBindingInvalid(target);
    }

    function _word(address target, bytes memory input) private view returns (bytes32) {
        return abi.decode(StreamMetadataRecoveryRoutes.read(target, input, 32, PIN_GAS), (bytes32));
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
