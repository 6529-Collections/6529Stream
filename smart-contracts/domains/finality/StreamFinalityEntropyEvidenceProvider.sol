// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRouterEvidence.sol";
import "../metadata/StreamMetadataRecoveryRoutes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/entropy/IStreamEntropyFinalityPolicy.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityEntropyEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";

/// @notice Actual locked entropy policy for the fixed coordinator and authenticated finality scope.
/// @dev Individual token outputs are separate content-root evidence. This provider neither waits
///      for unrelated collection requests nor treats their aggregate count as scope completion.
contract StreamFinalityEntropyEvidenceProvider is
    IStreamFinalityServingEvidenceProvider,
    IStreamFinalityEntropyEvidenceBinding,
    IERC165
{
    address public immutable override core;
    bytes32 public immutable coreCodeHash;
    address public immutable override metadataHost;
    bytes32 public immutable metadataHostCodeHash;
    address public immutable override entropyCoordinator;
    bytes32 public immutable override entropyCoordinatorCodeHash;
    address public immutable override scopeMembershipHost;
    bytes32 public immutable override scopeMembershipHostCodeHash;
    uint256 public immutable deploymentChainId;
    uint32 public immutable readGas;
    uint32 public immutable sourceGas;
    bytes32 public immutable coordinatorModuleVersion;
    bytes32 public immutable coordinatorModuleManifestHash;

    error EntropyEvidenceConfiguration();
    error EntropyEvidenceDependency(address target);
    error EntropyEvidenceScope();
    error EntropyEvidenceUnavailable(uint256 collectionId);
    error EntropyEvidenceFamily(bytes32 family);

    constructor(
        address core_,
        address metadata_,
        address coordinator_,
        address membership_,
        uint32 readGas_,
        uint32 sourceGas_
    ) {
        if (
            core_.code.length == 0 || metadata_.code.length == 0 || coordinator_.code.length == 0
                || membership_.code.length == 0 || readGas_ < 50000 || sourceGas_ < readGas_
        ) revert EntropyEvidenceConfiguration();
        core = core_;
        coreCodeHash = core_.codehash;
        metadataHost = metadata_;
        metadataHostCodeHash = metadata_.codehash;
        entropyCoordinator = coordinator_;
        entropyCoordinatorCodeHash = coordinator_.codehash;
        scopeMembershipHost = membership_;
        scopeMembershipHostCodeHash = membership_.codehash;
        deploymentChainId = block.chainid;
        readGas = readGas_;
        sourceGas = sourceGas_;
        _address(metadata_, abi.encodeCall(IStreamCollectionMetadataV1.core, ()), core_);
        _address(coordinator_, abi.encodeWithSignature("core()"), core_);
        _address(membership_, abi.encodeCall(IStreamFinalityScopeMembership.core, ()), core_);
        _address(
            membership_, abi.encodeCall(IStreamFinalityScopeMembership.metadataHost, ()), metadata_
        );
        _supports(core_, 0x80ac58cd);
        _supports(metadata_, type(IStreamCollectionMetadataV1).interfaceId);
        _supports(coordinator_, type(IStreamEntropyCoordinator).interfaceId);
        _supports(coordinator_, type(IStreamEntropyFinalityPolicy).interfaceId);
        _supports(membership_, type(IStreamFinalityScopeMembership).interfaceId);
        (coordinatorModuleVersion, coordinatorModuleManifestHash) =
            StreamFinalityRouterEvidence.moduleIdentity(coordinator_, sourceGas_);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamFinalityServingEvidenceProvider).interfaceId
            || id == type(IStreamFinalityComponentFacts).interfaceId
            || id == type(IStreamFinalityEntropyEvidenceBinding).interfaceId;
    }

    function componentHost(bytes32 family) public view override returns (address) {
        if (family != StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR) {
            revert EntropyEvidenceFamily(family);
        }
        return entropyCoordinator;
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamFinalityHostComponentFacts memory result)
    {
        componentHost(family);
        _pins();
        _scope(scope);
        bytes32 policyHash;
        address provider;
        uint32 epoch;
        bytes32 salt;
        (result.frozen, policyHash, provider, epoch, salt) = abi.decode(
            _read(
                entropyCoordinator,
                abi.encodeCall(
                    IStreamEntropyFinalityPolicy.entropyPolicyFrozen, (scope.collectionId)
                ),
                160
            ),
            (bool, bytes32, address, uint32, bytes32)
        );
        if (policyHash == 0 || provider == address(0) || epoch == 0 || salt == 0) {
            revert EntropyEvidenceUnavailable(scope.collectionId);
        }
        result.moduleVersion = coordinatorModuleVersion;
        result.manifestHash = coordinatorModuleManifestHash;
        result.dataHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1"),
                deploymentChainId,
                core,
                entropyCoordinator,
                scope,
                policyHash,
                provider,
                epoch,
                salt
            )
        );
    }

    function requireCurrentEntropySelection() external view override {
        _pins();
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            core,
            keccak256("ENTROPY_COORDINATOR"),
            entropyCoordinator,
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId
        );
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            core,
            keccak256("COLLECTION_METADATA"),
            metadataHost,
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
    }

    function _scope(StreamFinalityScope memory scope) private view {
        // The subject helper rejects malformed tuples; the fixed host proves actual membership.
        bytes32 subject = StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope);
        StreamScopeMembershipFacts memory facts = abi.decode(
            StreamFinalityRouterEvidence.read(
                scopeMembershipHost,
                abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
                256,
                sourceGas
            ),
            (StreamScopeMembershipFacts)
        );
        if (facts.scopeSubject != subject || facts.membershipHash == 0) {
            revert EntropyEvidenceScope();
        }
    }

    function _pins() private view {
        if (block.chainid != deploymentChainId) revert EntropyEvidenceConfiguration();
        _pin(core, coreCodeHash);
        _pin(metadataHost, metadataHostCodeHash);
        _pin(entropyCoordinator, entropyCoordinatorCodeHash);
        _pin(scopeMembershipHost, scopeMembershipHostCodeHash);
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert EntropyEvidenceDependency(target);
        }
    }

    function _address(address target, bytes memory callData, address expected) private view {
        if (abi.decode(_read(target, callData, 32), (address)) != expected) {
            revert EntropyEvidenceDependency(target);
        }
    }

    function _supports(address target, bytes4 id) private view {
        if (
            abi.decode(
                        _read(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))),
                            32
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                            32
                        ),
                        (uint256)
                    ) != 0
        ) revert EntropyEvidenceDependency(target);
    }

    function _read(address target, bytes memory callData, uint256 size)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.read(target, callData, size, readGas);
    }
}
