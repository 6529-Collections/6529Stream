// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamGasParameterHost as G
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamGovernedParameterAuthority as A
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

/// @notice Coordinator-owned incident GGP in appended namespaced storage; no provider parameter borrowing.
/// @dev Uses the original GGP V2 commitments and delayed, monotonic, at-most-2x transition.
library StreamEntropyIncidentParameters {
    bytes32 internal constant PROBE_GAS =
        keccak256("6529STREAM_GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT");
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_INCIDENT_PARAMETERS_STORAGE_V1");
    bytes32 private constant SCOPE =
        0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71;
    bytes32 private constant STATE =
        0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;

    struct Row {
        uint256 value;
        uint256 floor;
        uint8 failureClass;
        uint64 revision;
        bytes32 lastActionId;
    }

    struct Store {
        mapping(bytes32 => Row) rows;
        bytes32 authorityCodeHash;
    }
    event GasParameterRegistered(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        string name,
        uint256 genesisValue,
        uint256 floor,
        uint8 failureClass
    );
    event GasParameterUpdated(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        address indexed host,
        bytes32 indexed actionId,
        uint256 oldValue,
        uint256 newValue,
        uint256 floor
    );

    function _store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function initialize(address authority) internal {
        Store storage s = _store();
        s.authorityCodeHash = authority.codehash;
        _register(s, PROBE_GAS, "ENTROPY_RESULT_PROBE_GAS_LIMIT", 100000, 1);
    }

    function _register(
        Store storage s,
        bytes32 id,
        string memory name,
        uint256 amount,
        uint8 failureClass
    ) private {
        if (s.rows[id].revision != 0) revert G.GasParameterAlreadyRegistered(id);
        s.rows[id] = Row(amount, amount, failureClass, 1, 0);
        emit GasParameterRegistered(2, id, name, amount, amount, failureClass);
    }

    function ids() internal pure returns (bytes32[] memory result) {
        result = new bytes32[](1);
        result[0] = PROBE_GAS;
    }

    function info(bytes32 id) internal view returns (uint256, uint256, uint8, uint64) {
        Row storage r = _store().rows[id];
        return (r.value, r.floor, r.failureClass, r.revision);
    }

    function value(bytes32 id) internal view returns (uint256) {
        Row storage r = _row(id);
        return r.value;
    }

    function _row(bytes32 id) private view returns (Row storage r) {
        r = _store().rows[id];
        if (r.revision == 0) revert G.GasParameterUnknown(id);
    }

    function transition(bytes32 id, uint256 next)
        public
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        Row storage r = _row(id);
        if (next <= r.value) revert G.GasParameterNotARaise(id, r.value, next);
        if (next - r.value > r.value) revert G.GasParameterRaiseBoundExceeded(id, r.value, next);
        if (r.revision == type(uint64).max) revert G.GasParameterRevisionOverflow(id);
        scope = keccak256(abi.encode(SCOPE, block.chainid, address(this), id));
        oldHash = _state(scope, r, r.value, r.revision);
        newHash = _state(scope, r, next, r.revision + 1);
    }

    function _state(bytes32 scope, Row storage r, uint256 amount, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(STATE, scope, amount, r.floor, r.failureClass, revision));
    }

    function raise(address authority, bytes32 id, uint256 next) public {
        if (msg.sender != authority || authority == address(0)) {
            revert G.GasParameterNotAuthority(msg.sender);
        }
        if (authority.code.length == 0 || authority.codehash != _store().authorityCodeHash) {
            revert G.GasParameterInvalidAuthority(authority);
        }
        if (authority.code.length == 23) {
            bytes3 prefix;
            assembly ("memory-safe") {
                extcodecopy(authority, 0, 0, 3)
                prefix := mload(0)
            }
            if (prefix == 0xef0100) revert G.GasParameterInvalidAuthority(authority);
        }
        bytes memory marker =
            _read(authority, abi.encodeCall(A.isStreamGovernedParameterAuthority, ()), 32);
        if (abi.decode(marker, (uint256)) != 1) revert G.GasParameterInvalidAuthority(authority);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = transition(id, next);
        bytes memory context = _read(authority, abi.encodeCall(A.currentAction, ()), 192);
        uint256 executingWord;
        uint256 classWord;
        assembly ("memory-safe") {
            executingWord := mload(add(context, 32))
            classWord := mload(add(context, 96))
        }
        if (executingWord > 1 || classWord > 255) revert G.GasParameterActionContextInvalid();
        (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 actualScope,
            bytes32 actualOld,
            bytes32 actualNew
        ) = abi.decode(context, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (!executing) revert G.GasParameterActionNotExecuting();
        if (actionId == 0) revert G.GasParameterActionIdZero();
        if (actionClass != 1) revert G.GasParameterActionClassMismatch(1, actionClass);
        if (actualScope != scope) revert G.GasParameterScopeHashMismatch(scope, actualScope);
        if (actualOld != oldHash) revert G.GasParameterOldStateHashMismatch(oldHash, actualOld);
        if (actualNew != newHash) revert G.GasParameterNewStateHashMismatch(newHash, actualNew);
        Row storage r = _row(id);
        if (r.lastActionId == actionId) revert G.GasParameterActionAlreadyApplied(id, actionId);
        uint256 old = r.value;
        r.value = next;
        ++r.revision;
        r.lastActionId = actionId;
        emit GasParameterUpdated(2, id, address(this), actionId, old, next, r.floor);
    }

    // The original canonical authority read uses gas() with fixed-size returndata copying.
    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory result)
    {
        result = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(result, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert G.GasParameterActionContextInvalid();
    }
}
