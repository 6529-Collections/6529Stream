// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamConditionSources.sol";
import "../../interfaces/stream/metadata/IStreamOwnerRecords.sol";
import "../../interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamMetadataGovernance.sol";

/// @notice Permanent source membership, independent of present module-registry eligibility.
/// @dev Admission includes the source's complete history, including pre-admission records.
///      No source may be removed, disabled or replaced in place. A changed/unreadable source
///      makes a complete capture unavailable; it never authorizes omitting that source.
contract StreamConditionSources is StreamGasParameterHost, IStreamConditionSources {
    address public immutable override core;
    bytes32 public immutable override coreCodeHash;
    bytes32 public immutable override executorCodeHash;
    uint256 public immutable override deploymentChainId;
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_CONDITION_SOURCE_READ_GAS");
    bytes32 private constant _DOMAIN = keccak256("6529STREAM_CONDITION_SOURCE_SET_V1");
    bytes32 private constant _CONFIGURATION = keccak256("CONDITION_SOURCE_SET");

    Source[] private _sources;
    bytes32[] private _heads;
    mapping(address => mapping(Lane => uint64)) private _ids;

    constructor(address core_, address executor_) StreamGasParameterHost(executor_) {
        if (core_.code.length == 0 || executor_.code.length == 0) {
            revert InvalidConditionSourcesConfiguration();
        }
        core = core_;
        coreCodeHash = core_.codehash;
        executorCodeHash = executor_.codehash;
        deploymentChainId = block.chainid;
        _registerGasParameter(GasParameterConfig("CONDITION_SOURCE_READ_GAS", 300000, 50000, 2));
        // The Executor marker/context is checked by the base constructor. Its live root
        // is checked on every transition, allowing deployment before genesis is sealed.
        _heads.push(keccak256(abi.encode(_DOMAIN, block.chainid, core_, address(this))));
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IStreamConditionSources).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || id == 0x01ffc9a7;
    }

    function sourceCount() public view override returns (uint64) {
        return uint64(_sources.length);
    }

    function sourceAt(uint64 id) external view override returns (Source memory) {
        if (id == 0 || id > _sources.length) revert UnknownConditionSource(id);
        return _sources[id - 1];
    }

    function sourceId(address host, Lane lane) external view override returns (uint64) {
        return _ids[host][lane];
    }

    function sourceSetHashAt(uint64 count) external view override returns (bytes32) {
        if (count > _sources.length) revert UnknownConditionSource(count);
        return _heads[count];
    }

    function sourceSetHead() public view override returns (uint64 count, bytes32 head) {
        count = sourceCount();
        head = _heads[count];
    }

    function requireSourceSet(uint64 expectedCount, bytes32 expectedHead) external view override {
        (uint64 count, bytes32 head) = sourceSetHead();
        if (count != expectedCount || head != expectedHead) {
            revert ConditionSourceSetChanged(count, head);
        }
    }

    function sourceTransition(address host, Lane lane, uint64 replacesSourceId)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        _validateSource(host, lane, replacesSourceId);
        scope = _scope();
        (uint64 count, bytes32 head) = sourceSetHead();
        oldHash = _state(count, head);
        newHash = _state(count + 1, _next(head, count + 1, host, lane, replacesSourceId));
    }

    function appendSource(address host, Lane lane, uint64 replacesSourceId) external override {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            sourceTransition(host, lane, replacesSourceId);
        bytes32 actionId = StreamMetadataGovernance.requireTransition(
            governanceAuthority,
            executorCodeHash,
            _gasParameterValue(DEPENDENCY_READ_GAS),
            scope,
            oldHash,
            newHash
        );
        uint64 id = sourceCount() + 1;
        bytes32 previousHead = _heads[id - 1];
        bytes32 nextHead = _next(previousHead, id, host, lane, replacesSourceId);
        _sources.push(
            Source(host, host.codehash, lane, replacesSourceId, uint64(block.timestamp), actionId)
        );
        _ids[host][lane] = id;
        _heads.push(nextHead);
        emit ConditionSourceAdded(
            id, host, lane, host.codehash, replacesSourceId, previousHead, nextHead, actionId, 1
        );
    }

    function _scope() private view returns (bytes32) {
        return StreamMetadataGovernance.configurationScope(
            governanceAuthority,
            executorCodeHash,
            _gasParameterValue(DEPENDENCY_READ_GAS),
            _CONFIGURATION
        );
    }

    function _state(uint64 count, bytes32 head) private view returns (bytes32) {
        return keccak256(abi.encode(_DOMAIN, block.chainid, core, address(this), count, head));
    }

    function _next(bytes32 head, uint64 id, address host, Lane lane, uint64 predecessor)
        private
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(_DOMAIN, head, id, host, host.codehash, lane, predecessor));
    }

    function _validateSource(address host, Lane lane, uint64 predecessor) private view {
        if (block.chainid != deploymentChainId) {
            revert ConditionSourceChainChanged(deploymentChainId, block.chainid);
        }
        if (core.codehash != coreCodeHash) revert ConditionSourceDependencyChanged(core);
        if (
            _sources.length == type(uint64).max || block.timestamp > type(uint64).max
                || host.code.length == 0
        ) revert InvalidConditionSource(host);
        if (_ids[host][lane] != 0) revert ConditionSourceAlreadyAdmitted(host, lane);
        if (
            predecessor != 0
                && (predecessor > _sources.length || _sources[predecessor - 1].lane != lane)
        ) {
            revert InvalidConditionSourcePredecessor(predecessor);
        }
        bytes4 interfaceId = lane == Lane.OWNER
            ? type(IStreamOwnerRecords).interfaceId
            : type(IStreamCollectionAttestations).interfaceId;
        if (
            _word(host, abi.encodeCall(IERC165.supportsInterface, (interfaceId))) != 1
                || _word(host, abi.encodeCall(IStreamOwnerRecords.core, ())) != uint160(core)
        ) {
            revert InvalidConditionSource(host);
        }
    }

    function _word(address target, bytes memory input) private view returns (uint256 word) {
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        if (gasleft() <= cap + cap / 63 + 10000) revert ConditionSourceReadFailed(target);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(cap, target, add(input, 32), mload(input), ptr, 32)
            size := returndatasize()
            word := mload(ptr)
        }
        if (!ok || size != 32) revert ConditionSourceReadFailed(target);
    }
}
