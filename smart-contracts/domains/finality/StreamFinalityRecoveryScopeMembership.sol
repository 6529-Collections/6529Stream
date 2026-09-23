// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRecoveryBindings.sol";
import "./StreamScopeMembershipEncoding.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeEvidence.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";

/// @notice Inherited family membership in the original Registry's fixed Router/provider universe.
/// @dev The operative caller supplies its constructor-bound identities and governed read budget.
///      These facts prove scope identity only, not artist authority or VIEW content adoption.
library StreamFinalityRecoveryScopeMembership {
    error RecoveryScopeMembershipBindingInvalid(address target);
    error RecoveryScopeMembershipFactsInvalid();

    struct Environment {
        address core;
        address originalFinality;
        bytes32 originalFinalityCodeHash;
        address metadataRouter;
        uint256 readGas;
    }

    function read(Environment memory e, StreamFinalityScope memory scope)
        public
        view
        returns (StreamScopeMembershipFacts memory f)
    {
        if (
            e.readGas == 0 || e.readGas > type(uint256).max / 64
                || scope.scopeType < StreamFinalityScopeType.RELEASE
                || scope.scopeType > StreamFinalityScopeType.VIEW || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId == 0
        ) revert RecoveryScopeMembershipFactsInvalid();
        _pin(e.originalFinality, e.originalFinalityCodeHash);
        _equal(
            e.originalFinality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()),
            e.core,
            e.readGas
        );
        address provider = _address(
            e.originalFinality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ()),
            e.readGas
        );
        _pin(
            provider,
            _word(
                e.originalFinality,
                abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ()),
                e.readGas
            )
        );
        _equal(provider, abi.encodeCall(IStreamFinalityScopeEvidence.core, ()), e.core, e.readGas);
        _pin(
            e.core,
            _word(
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.coreCodeHash, ()),
                e.readGas
            )
        );
        _equal(
            provider,
            abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataRouter, ()),
            e.metadataRouter,
            e.readGas
        );
        _pin(
            e.metadataRouter,
            _word(
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataRouterCodeHash, ()),
                e.readGas
            )
        );
        address metadata = _address(
            e.originalFinality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ()),
            e.readGas
        );
        _equal(
            provider,
            abi.encodeCall(IStreamFinalityServingEvidenceProvider.metadataHost, ()),
            metadata,
            e.readGas
        );
        _pin(
            metadata,
            _word(
                provider,
                abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataHostCodeHash, ()),
                e.readGas
            )
        );
        address membership = _address(
            provider,
            abi.encodeCall(IStreamFinalityRouterEvidenceBinding.scopeMembershipHost, ()),
            e.readGas
        );
        _pin(
            membership,
            _word(
                provider,
                abi.encodeCall(
                    IStreamFinalityRouterEvidenceBinding.scopeMembershipHostCodeHash, ()
                ),
                e.readGas
            )
        );
        _equal(
            membership, abi.encodeCall(IStreamFinalityScopeMembership.core, ()), e.core, e.readGas
        );
        _equal(
            membership,
            abi.encodeCall(IStreamFinalityScopeMembership.metadataHost, ()),
            metadata,
            e.readGas
        );
        address inventory = _address(
            membership, abi.encodeCall(IStreamFinalityScopeMembership.tokenInventory, ()), e.readGas
        );
        f = abi.decode(
            StreamFinalityRecoveryBindings.fixedRead(
                membership,
                abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
                256,
                e.readGas
            ),
            (StreamScopeMembershipFacts)
        );
        if (
            f.scopeSubject != StreamMetadataSubjects.scopeSubject(block.chainid, e.core, scope)
                || f.scopeManifestHash == 0 || f.sourceRecordHash == 0 || f.tokenListHash == 0
                || f.membershipHash == 0 || f.inventoryCount != 0 || f.inventoryPrefixHash != 0
                || (f.tokenCount == 0 && f.tokenListHash != keccak256(""))
                || scope.scopeId
                    != StreamScopeMembershipEncoding.scopeId(
                        block.chainid,
                        e.core,
                        scope.collectionId,
                        uint8(scope.scopeType),
                        f.sourceRecordHash
                    )
                || f.membershipHash
                    != StreamScopeMembershipEncoding.membershipHash(
                        block.chainid, e.core, metadata, inventory, scope, f
                    )
        ) revert RecoveryScopeMembershipFactsInvalid();
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (
            target == address(0) || codeHash == 0 || target.code.length == 0
                || target.codehash != codeHash
        ) {
            revert RecoveryScopeMembershipBindingInvalid(target);
        }
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (bytes32) {
        return
            abi.decode(StreamFinalityRecoveryBindings.fixedRead(target, input, 32, cap), (bytes32));
    }

    function _address(address target, bytes memory input, uint256 cap)
        private
        view
        returns (address)
    {
        uint256 value = uint256(_word(target, input, cap));
        if (value == 0 || value > type(uint160).max) {
            revert RecoveryScopeMembershipBindingInvalid(target);
        }
        return address(uint160(value));
    }

    function _equal(address target, bytes memory input, address expected, uint256 cap)
        private
        view
    {
        if (_address(target, input, cap) != expected) {
            revert RecoveryScopeMembershipBindingInvalid(target);
        }
    }
}
