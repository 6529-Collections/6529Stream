// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/ERC165.sol";
import "../../interfaces/stream/access/IStreamAdmins.sol";
import "../../interfaces/stream/governance/IStreamGovernanceExecutor.sol";
import "../../interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadata.sol";
import "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
import "../../interfaces/stream/records/IStreamRecordFamilyRegistry.sol";
import "../access/StreamPauseDomains.sol";

/// @notice Current Executor compatibility for exactly two legacy metadata hosts.
/// @dev This is not a general StreamAdmins replacement. Only METADATA_MUTATION is
/// supported; all other pause domains return false. It grants no EOA, Safe, global,
/// collection, or emergency authority. The family registry initializes its stored
/// configuration authority from owner() during its original constructor.
contract StreamMetadataGovernanceAdapter is ERC165, IStreamAdmins {
    error InvalidMetadataGovernanceAuthority();
    error InvalidMetadataHosts();
    error MetadataHostsAlreadyBound();
    error MetadataGovernanceContextRequired();
    error MetadataPauseNoOp();

    address public immutable governanceExecutor;
    bytes32 public immutable governanceExecutorCodeHash;
    address public familyRegistry;
    address public preservationRecords;
    bytes32 public familyRegistryCodeHash;
    bytes32 public preservationRecordsCodeHash;
    bool public metadataPaused;
    uint64 public pauseRevision;

    event MetadataHostsBound(
        address indexed familyRegistry,
        address indexed preservationRecords,
        bytes32 familyCodeHash,
        bytes32 preservationCodeHash,
        bytes32 indexed actionId
    );
    event MetadataPauseUpdated(bool paused, uint64 revision, bytes32 indexed actionId);

    constructor(address executor) {
        if (
            executor.code.length == 0
                || !IStreamGovernedParameterAuthority(executor).isStreamGovernedParameterAuthority()
                || !IERC165(executor)
                    .supportsInterface(type(IStreamGovernanceActionFacts).interfaceId)
        ) revert InvalidMetadataGovernanceAuthority();
        governanceExecutor = executor;
        governanceExecutorCodeHash = executor.codehash;
    }

    /// @notice Permanently bind the two original hosts through a delayed Executor call.
    function bindMetadataHosts(address families, address preservation) external {
        if (familyRegistry != address(0)) revert MetadataHostsAlreadyBound();
        _validateHosts(families, preservation);
        bytes32 actionId =
            _requireContext(1, bindingScope(), bytes32(0), bindingHash(families, preservation));
        familyRegistry = families;
        preservationRecords = preservation;
        familyRegistryCodeHash = families.codehash;
        preservationRecordsCodeHash = preservation.codehash;
        emit MetadataHostsBound(
            families, preservation, families.codehash, preservation.codehash, actionId
        );
    }

    function bindingScope() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_METADATA_ADMIN_HOSTS_V1"), block.chainid, address(this)
            )
        );
    }

    function bindingHash(address families, address preservation) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                bindingScope(), families, families.codehash, preservation, preservation.codehash
            )
        );
    }

    function pauseScope() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_METADATA_ADMIN_PAUSE_V1"),
                block.chainid,
                address(this),
                StreamPauseDomains.METADATA_MUTATION
            )
        );
    }

    function pauseStateHash(bool paused, uint64 revision) public view returns (bytes32) {
        return keccak256(abi.encode(pauseScope(), paused, revision));
    }

    /// @dev Must also be installed as a codehash-pinned Executor tightening selector.
    function pauseMetadata() external {
        _setPaused(true, 0);
    }

    function resumeMetadata() external {
        _setPaused(false, 1);
    }

    function functionScope(address target, bytes4 selector) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_METADATA_ADMIN_FUNCTION_V1"),
                block.chainid,
                address(this),
                target,
                target.codehash,
                selector
            )
        );
    }

    /// @dev No global fallback can bypass the target/selector check below.
    function retrieveGlobalAdmin(address) external pure override returns (bool) {
        return false;
    }

    function retrieveFunctionAdmin(address actor, address target, bytes4 selector)
        external
        view
        override
        returns (bool)
    {
        if (
            actor != governanceExecutor || msg.sender != target || !_boundHost(target)
                || governanceExecutor.codehash != governanceExecutorCodeHash
        ) return false;
        uint8 requiredClass;
        if (selector == IStreamPreservationRecords.updateAdminContract.selector) {
            requiredClass = 3;
        } else if (
            target == familyRegistry
                && selector == IStreamCollectionMetadata.lockCollectionRecord.selector
        ) {
            requiredClass = 2;
        } else {
            return false;
        }
        (bool executing, bytes32 actionId, uint8 actionClass, bytes32 scope,,) =
            IStreamGovernanceExecutor(governanceExecutor).currentAction();
        return executing && actionId != bytes32(0) && actionClass == requiredClass
            && scope == functionScope(target, selector);
    }

    function retrieveCollectionAdmin(address, uint256) external pure override returns (bool) {
        return false;
    }

    function emergencyRecipient() external pure override returns (address) {
        return address(0);
    }

    function isAdminContract() external pure override returns (bool) {
        return true;
    }

    function owner() external view override returns (address) {
        return governanceExecutor;
    }

    function isPaused(bytes32 domain) external view override returns (bool) {
        return domain == StreamPauseDomains.METADATA_MUTATION && metadataPaused;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return
            interfaceId == type(IStreamAdmins).interfaceId || super.supportsInterface(interfaceId);
    }

    function _setPaused(bool paused, uint8 actionClass) private {
        if (familyRegistry == address(0)) revert InvalidMetadataHosts();
        if (metadataPaused == paused) revert MetadataPauseNoOp();
        uint64 nextRevision = pauseRevision + 1;
        bytes32 actionId = _requireContext(
            actionClass,
            pauseScope(),
            pauseStateHash(metadataPaused, pauseRevision),
            pauseStateHash(paused, nextRevision)
        );
        metadataPaused = paused;
        pauseRevision = nextRevision;
        emit MetadataPauseUpdated(paused, nextRevision, actionId);
    }

    function _requireContext(
        uint8 requiredClass,
        bytes32 expectedScope,
        bytes32 expectedOld,
        bytes32 expectedNew
    ) private view returns (bytes32 actionId) {
        if (
            msg.sender != governanceExecutor
                || governanceExecutor.codehash != governanceExecutorCodeHash
        ) {
            revert MetadataGovernanceContextRequired();
        }
        (
            bool executing,
            bytes32 currentId,
            uint8 actionClass,
            bytes32 scope,
            bytes32 oldHash,
            bytes32 newHash
        ) = IStreamGovernanceExecutor(governanceExecutor).currentAction();
        if (
            !executing || currentId == bytes32(0) || actionClass != requiredClass
                || scope != expectedScope || oldHash != expectedOld || newHash != expectedNew
        ) {
            revert MetadataGovernanceContextRequired();
        }
        return currentId;
    }

    function _boundHost(address target) private view returns (bool) {
        return target.code.length != 0
            && ((target == familyRegistry && target.codehash == familyRegistryCodeHash)
                || (target == preservationRecords
                    && target.codehash == preservationRecordsCodeHash));
    }

    function _validateHosts(address families, address preservation) private view {
        if (families == preservation || families.code.length == 0 || preservation.code.length == 0)
        {
            revert InvalidMetadataHosts();
        }
        IStreamCollectionMetadata metadata = IStreamCollectionMetadata(families);
        IStreamPreservationRecords records = IStreamPreservationRecords(preservation);
        IStreamRecordFamilyRegistry registry = IStreamRecordFamilyRegistry(families);
        if (
            !metadata.isStreamCollectionMetadata() || !registry.isStreamRecordFamilyRegistry()
                || !records.isStreamPreservationRecords()
                || metadata.adminsContract() != address(this)
                || records.adminsContract() != address(this)
                || metadata.recordFamilyRegistry() != families
                || records.recordFamilyRegistry() != families
                || metadata.streamCore().code.length == 0
                || records.streamCore() != metadata.streamCore()
                || registry.configurationAuthority() != governanceExecutor
                || registry.pendingConfigurationAuthority() != address(0)
        ) revert InvalidMetadataHosts();
    }
}
