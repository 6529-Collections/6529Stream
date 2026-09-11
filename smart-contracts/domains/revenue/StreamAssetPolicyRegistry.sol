// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamAssetPolicyRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

/// @notice Governed standard-token acceptance and nonstranding deprecated-asset exits.
/// @dev Every mutation requires a class-1 Governance-V2 action. There is no owner bypass or
/// emergency writer. Grace is monotonic across status changes; observation lives in each wallet.
contract StreamAssetPolicyRegistry is IStreamAssetPolicyRegistry {
    uint8 public constant override ASSET_STATUS_UNKNOWN = 0;
    uint8 public constant override ASSET_STATUS_ACTIVE = 1;
    uint8 public constant override ASSET_STATUS_INACTIVE = 2;
    uint8 public constant override ASSET_STATUS_DEPRECATED = 3;
    uint8 public constant override ASSET_STATUS_UNSUPPORTED = 4;
    bytes32 private constant _SCOPE_DOMAIN = keccak256("6529STREAM_ASSET_POLICY_SCOPE_V1");
    bytes32 private constant _STATE_DOMAIN = keccak256("6529STREAM_ASSET_POLICY_STATE_V1");

    address public immutable override governanceAuthority;
    mapping(address => uint8) public override assetStatus;
    mapping(address => bytes32) public override assetPolicyHash;
    mapping(address => uint64) public override assetPolicyEffectiveAt;
    mapping(address => uint64) public override assetReleaseGraceUntil;
    mapping(address => uint64) public assetPolicyRevision;
    mapping(address => bytes32) private _lastActionId;

    constructor(address authority) {
        bool delegated;
        if (authority.code.length == 23) {
            bytes3 prefix;
            assembly ("memory-safe") {
                extcodecopy(authority, 0, 0, 3)
                prefix := mload(0)
            }
            delegated = prefix == 0xef0100;
        }
        if (authority.code.length == 0 || delegated) revert InvalidAssetPolicyAuthority(authority);
        uint256 selector =
            uint32(IStreamGovernedParameterAuthority.isStreamGovernedParameterAuthority.selector);
        bool success;
        uint256 marker;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(224, selector))
            success := staticcall(gas(), authority, ptr, 4, ptr, 32)
            success := and(success, eq(returndatasize(), 32))
            marker := mload(ptr)
        }
        if (!success || marker != 1) revert InvalidAssetPolicyAuthority(authority);
        governanceAuthority = authority;
        _readAction(authority);
    }

    function isStreamAssetPolicyRegistry() external pure override returns (bool) {
        return true;
    }

    function isAssetActive(address asset) external view override returns (bool) {
        return assetStatus[asset] == ASSET_STATUS_ACTIVE;
    }

    function assetPolicy(address asset)
        external
        view
        override
        returns (uint8 status, bytes32 policyHash, uint64 effectiveAt, uint64 releaseGraceUntil)
    {
        return (
            assetStatus[asset],
            assetPolicyHash[asset],
            assetPolicyEffectiveAt[asset],
            assetReleaseGraceUntil[asset]
        );
    }

    /// @notice Exact semantic commitments for scheduling one asset-policy action.
    /// @dev Effective time is execution-derived, not caller supplied; revision prevents ABA replay.
    function assetPolicyTransitionHashes(
        address asset,
        uint8 status,
        bytes32 policyHash,
        uint64 grace
    ) public view override returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) {
        scopeHash = keccak256(abi.encode(_SCOPE_DOMAIN, block.chainid, address(this), asset));
        oldStateHash = _stateHash(
            scopeHash,
            assetStatus[asset],
            assetPolicyHash[asset],
            assetReleaseGraceUntil[asset],
            assetPolicyRevision[asset]
        );
        newStateHash =
            _stateHash(scopeHash, status, policyHash, grace, assetPolicyRevision[asset] + 1);
    }

    function setAssetStatus(address asset, uint8 status, bytes32 policyHash, uint64 grace)
        external
        override
    {
        if (msg.sender != governanceAuthority) revert AssetPolicyNotAuthority(msg.sender);
        if (asset == address(0)) revert InvalidAsset(asset);
        if (status > ASSET_STATUS_UNSUPPORTED) revert InvalidAssetStatus(status);
        if (status == ASSET_STATUS_UNKNOWN && policyHash != bytes32(0)) {
            revert InvalidAssetPolicyHash(asset, status, policyHash);
        }
        if (status != ASSET_STATUS_UNKNOWN && asset.code.length == 0) revert InvalidAsset(asset);
        if (status != ASSET_STATUS_UNKNOWN && policyHash == bytes32(0)) {
            revert InvalidAssetPolicyHash(asset, status, policyHash);
        }
        uint8 previousStatus = assetStatus[asset];
        bytes32 previousPolicyHash = assetPolicyHash[asset];
        uint64 previousGrace = assetReleaseGraceUntil[asset];
        if (
            grace < previousGrace || (status != ASSET_STATUS_DEPRECATED && grace != previousGrace)
                || (status == ASSET_STATUS_DEPRECATED
                    && uint256(grace) < block.timestamp + 180 days)
        ) {
            revert InvalidAssetReleaseGrace(previousGrace, grace);
        }
        if (previousStatus == status && previousPolicyHash == policyHash && previousGrace == grace)
        {
            revert AssetPolicyUnchanged(asset, status, policyHash);
        }
        bytes32 actionId = _requirePolicyAction(asset, status, policyHash, grace);
        if (_lastActionId[asset] == actionId) {
            revert AssetPolicyActionAlreadyApplied(asset, actionId);
        }
        if (block.timestamp > type(uint64).max) revert InvalidAssetPolicyAction();
        assetStatus[asset] = status;
        assetPolicyHash[asset] = policyHash;
        assetPolicyEffectiveAt[asset] = uint64(block.timestamp);
        assetReleaseGraceUntil[asset] = grace;
        ++assetPolicyRevision[asset];
        _lastActionId[asset] = actionId;
        emit AssetPolicyUpdated(
            asset,
            previousStatus,
            status,
            1,
            previousPolicyHash,
            policyHash,
            uint64(block.timestamp),
            grace,
            actionId,
            msg.sender
        );
    }

    function _requirePolicyAction(address asset, uint8 status, bytes32 policyHash, uint64 grace)
        private
        view
        returns (bytes32 actionId)
    {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            assetPolicyTransitionHashes(asset, status, policyHash, grace);
        (
            bool executing,
            bytes32 actualId,
            uint8 actionClass,
            bytes32 actualScope,
            bytes32 actualOld,
            bytes32 actualNew
        ) = _readAction(governanceAuthority);
        if (
            !executing || actualId == bytes32(0) || actionClass != 1 || actualScope != scope
                || actualOld != oldState || actualNew != newState
        ) revert InvalidAssetPolicyAction();
        return actualId;
    }

    function _stateHash(
        bytes32 scope,
        uint8 status,
        bytes32 policyHash,
        uint64 grace,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(_STATE_DOMAIN, scope, status, policyHash, grace, revision));
    }

    function _readAction(address authority)
        private
        view
        returns (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scope,
            bytes32 oldState,
            bytes32 newState
        )
    {
        uint256 selector = uint32(IStreamGovernedParameterAuthority.currentAction.selector);
        bool success;
        uint256 executingWord;
        uint256 classWord;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(224, selector))
            success := staticcall(gas(), authority, ptr, 4, ptr, 192)
            success := and(success, eq(returndatasize(), 192))
            executingWord := mload(ptr)
            actionId := mload(add(ptr, 32))
            classWord := mload(add(ptr, 64))
            scope := mload(add(ptr, 96))
            oldState := mload(add(ptr, 128))
            newState := mload(add(ptr, 160))
        }
        if (!success || executingWord > 1 || classWord > 255) revert InvalidAssetPolicyAction();
        executing = executingWord == 1;
        actionClass = uint8(classWord);
    }
}
