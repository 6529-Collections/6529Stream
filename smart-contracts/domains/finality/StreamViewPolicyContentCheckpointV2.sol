// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewPolicyContentCheckpointV2 as I
} from "../../interfaces/stream/finality/IStreamViewPolicyContentCheckpointV2.sol";
import {
    StreamViewPolicyCheckpointTypesV2 as T
} from "../../interfaces/stream/finality/StreamViewPolicyCheckpointTypesV2.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamViewPolicyCheckpointSourceV2 as Sources
} from "./StreamViewPolicyCheckpointSourceV2.sol";
import {
    StreamViewPolicyCheckpointTokenV2 as Tokens
} from "./StreamViewPolicyCheckpointTokenV2.sol";
import { StreamViewAdoptionReads as Read } from "../metadata/StreamViewAdoptionReads.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Permissionless ordered exact-output VIEW checkpoint. It grants no publication authority.
/// @dev Every seal/current read rechecks complete source and all observed rows, including outputs.
/// Whole-scope capacity is finite and must be measured; append progress is never current evidence.
contract StreamViewPolicyContentCheckpointV2 is I, IERC165 {
    T.Configuration private _configuration;
    bytes32 public immutable override configurationHash;
    bytes32 public immutable sourceWorkerCodeHash;
    bytes32 public immutable tokenWorkerCodeHash;
    mapping(bytes32 => T.Plan) private _plans;
    mapping(bytes32 => mapping(uint256 => T.Output)) private _outputs;
    bytes32 private constant PLAN = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_CHECKPOINT_PLAN_V2");
    bytes32 private constant CHAIN = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_CHAIN_V2");
    bytes32 private constant ROOT = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_ROOT_V2");

    constructor(T.Configuration memory c) {
        Sources.validate(c);
        sourceWorkerCodeHash = address(Sources).codehash;
        tokenWorkerCodeHash = address(Tokens).codehash;
        Read.pin(address(Sources), sourceWorkerCodeHash);
        Read.pin(address(Tokens), tokenWorkerCodeHash);
        _configuration = c;
        configurationHash = keccak256(
            abi.encode(
                T.PROFILE,
                block.chainid,
                address(this),
                c,
                address(Sources),
                sourceWorkerCodeHash,
                address(Tokens),
                tokenWorkerCodeHash
            )
        );
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(I).interfaceId || id == type(IERC165).interfaceId;
    }

    function checkpointProfile() external pure returns (bytes32) {
        return T.PROFILE;
    }

    function configuration() external view returns (T.Configuration memory) {
        return _configuration;
    }

    function begin(StreamFinalityScope calldata scope, bytes32 salt) external returns (bytes32 id) {
        _workers();
        T.Source memory s = Sources.current(_configuration, scope);
        uint256 count = s.adoption.source.membership.tokenCount;
        if (count == 0 || count > type(uint64).max) revert T.InvalidViewCheckpoint();
        id = keccak256(
            abi.encode(
                PLAN,
                block.chainid,
                address(this),
                configurationHash,
                scope,
                s.contextHash,
                count,
                salt
            )
        );
        if (_plans[id].tokenCount == 0) {
            T.Plan storage p = _plans[id];
            p.scope = scope;
            p.adoptionRecord = s.adoption.recordHash;
            p.sourceContextHash = s.contextHash;
            p.membershipHash = s.adoption.source.membership.membershipHash;
            p.policyChainHash = s.policy.policyChainHash;
            p.tokenCount = uint64(count);
            p.rowChain = _initial(id, p);
            emit ViewCheckpointStarted(id, s.adoption.recordHash, salt);
        }
    }

    function append(bytes32 id, uint256 expectedTokenId, bytes calldata json, bytes calldata html)
        external
    {
        T.Plan storage p = _known(id);
        T.Source memory s = _currentSource(id, p);
        if (p.outputRoot != 0 || p.nextIndex >= p.tokenCount) {
            revert T.ViewCheckpointIndex(p.nextIndex);
        }
        (T.Output memory o, bytes memory actualJSON, bytes memory actualHTML) =
            Tokens.observe(_configuration, s, p.nextIndex);
        if (
            expectedTokenId != o.tokenId || json.length != actualJSON.length
                || html.length != actualHTML.length || keccak256(json) != o.jsonHash
                || keccak256(html) != o.htmlHash
                || (p.nextIndex != 0 && o.tokenId <= _outputs[id][p.nextIndex - 1].tokenId)
        ) revert T.ViewCheckpointToken(expectedTokenId);
        // All dependency work is STATIC/view; only a fully verified next row becomes preparation.
        _outputs[id][p.nextIndex] = o;
        bytes32 row = _row(id, o);
        p.rowChain = keccak256(abi.encode(CHAIN, p.rowChain, p.nextIndex, row));
        emit ViewCheckpointAppended(id, p.nextIndex, o.tokenId, row);
        ++p.nextIndex;
    }

    function seal(bytes32 id) external returns (bytes32 outputRoot) {
        T.Plan storage p = _known(id);
        outputRoot = _verify(id, p);
        if (p.outputRoot == 0) {
            p.outputRoot = outputRoot;
            emit ViewCheckpointSealed(id, outputRoot, p.tokenCount);
        } else if (p.outputRoot != outputRoot) {
            revert T.ViewCheckpointChanged(id);
        }
    }

    function checkpoint(bytes32 id) external view returns (T.Plan memory) {
        return _known(id);
    }

    function outputAt(bytes32 id, uint256 index) external view returns (T.Output memory) {
        T.Plan storage p = _known(id);
        if (index >= p.nextIndex) revert T.ViewCheckpointIndex(index);
        return _outputs[id][index];
    }

    function requireCurrentCheckpoint(bytes32 id) external view returns (T.Plan memory) {
        T.Plan storage p = _known(id);
        if (p.outputRoot == 0 || _verify(id, p) != p.outputRoot) revert T.ViewCheckpointChanged(id);
        return p;
    }

    function _verify(bytes32 id, T.Plan storage p) private view returns (bytes32) {
        T.Source memory s = _currentSource(id, p);
        if (p.nextIndex != p.tokenCount) revert T.ViewCheckpointIndex(p.nextIndex);
        bytes32 chain = _initial(id, p);
        uint256 previous;
        for (uint64 i; i < p.tokenCount; ++i) {
            (T.Output memory o,,) = Tokens.observe(_configuration, s, i);
            if (
                o.tokenId <= previous
                    || keccak256(abi.encode(o)) != keccak256(abi.encode(_outputs[id][i]))
            ) revert T.ViewCheckpointChanged(id);
            previous = o.tokenId;
            chain = keccak256(abi.encode(CHAIN, chain, i, _row(id, o)));
        }
        if (chain != p.rowChain) revert T.ViewCheckpointChanged(id);
        return keccak256(
            abi.encode(
                ROOT,
                block.chainid,
                address(this),
                configurationHash,
                id,
                p.scope,
                p.adoptionRecord,
                p.sourceContextHash,
                p.tokenCount,
                chain
            )
        );
    }

    function _currentSource(bytes32 id, T.Plan storage p) private view returns (T.Source memory s) {
        _workers();
        s = Sources.current(_configuration, p.scope);
        if (
            s.adoption.recordHash != p.adoptionRecord || s.contextHash != p.sourceContextHash
                || s.adoption.source.membership.membershipHash != p.membershipHash
                || s.adoption.source.membership.tokenCount != p.tokenCount
                || s.policy.policyChainHash != p.policyChainHash
        ) {
            revert T.ViewCheckpointChanged(id);
        }
    }

    function _workers() private view {
        Read.pin(address(Sources), sourceWorkerCodeHash);
        Read.pin(address(Tokens), tokenWorkerCodeHash);
    }

    function _known(bytes32 id) private view returns (T.Plan storage p) {
        p = _plans[id];
        if (p.tokenCount == 0) revert T.ViewCheckpointChanged(id);
    }

    function _initial(bytes32 id, T.Plan storage p) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(CHAIN, id, p.scope, p.sourceContextHash, p.membershipHash, p.tokenCount)
            );
    }

    function _row(bytes32 id, T.Output memory o) private view returns (bytes32) {
        return keccak256(abi.encode(T.ROW, block.chainid, address(this), id, o));
    }
}
