// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamStaticC2PAAttribution
} from "../../interfaces/stream/metadata/IStreamStaticC2PAAttribution.sol";
import {
    IStreamC2PAReconciliation as C
} from "../../interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import "./StreamMetadataSubjects.sol";
import {
    IStreamC2PAConflicts as Conflicts,
    IStreamStaticC2PAConflicts
} from "../../interfaces/stream/metadata/IStreamC2PAConflicts.sol";

interface IStreamC2PAOriginalAttribution {
    function core() external view returns (address);
    function router() external view returns (address);
    function artist() external view returns (address);
    function attribution(uint256 collection, uint256 token) external view returns (bytes memory);
}

interface IStreamC2PARouterBinding {
    function router() external view returns (address);
}

/// @notice Explicitly configured STATIC source; original Artist facts and verifier reports stay separate.
/// @dev Both targets, their runtimes and every transitive target/selector must enter the renderer
/// read roster. No delegatecall, timestamp, crypto verification or authority mutation serves reads.
contract StreamStaticC2PAAttributionCompanion is
    IStreamStaticC2PAAttribution,
    IStreamStaticC2PAConflicts,
    StreamGasParameterHost
{
    bytes32 public constant ARTIST_GAS = keccak256("6529STREAM_GGP_C2PA_STATIC_ARTIST_GAS");
    bytes32 public constant REPORT_GAS = keccak256("6529STREAM_GGP_C2PA_STATIC_REPORT_GAS");
    address public immutable core;
    address public immutable router;
    address public immutable original;
    address public immutable reconciliation;
    bytes32 public immutable originalCodeHash;
    bytes32 public immutable reconciliationCodeHash;
    uint256 public immutable sourceChainId;
    error C2PAStaticReadUnavailable();

    constructor(
        address original_,
        address reconciliation_,
        address executor,
        GasParameterConfig memory artistGas,
        GasParameterConfig memory reportGas
    ) StreamGasParameterHost(executor) {
        if (
            original_.code.length == 0 || reconciliation_.code.length == 0
                || artistGas.failureClass != 2 || reportGas.failureClass != 2
                || _registerGasParameter(artistGas) != ARTIST_GAS
                || _registerGasParameter(reportGas) != REPORT_GAS
        ) revert C2PAStaticReadUnavailable();
        original = original_;
        reconciliation = reconciliation_;
        core = IStreamC2PAOriginalAttribution(original_).core();
        router = IStreamC2PAOriginalAttribution(original_).router();
        if (
            C(reconciliation_).core() != core
                || IStreamC2PARouterBinding(reconciliation_).router() != router
                || C(reconciliation_).artist() != IStreamC2PAOriginalAttribution(original_).artist()
        ) revert C2PAStaticReadUnavailable();
        originalCodeHash = original_.codehash;
        reconciliationCodeHash = reconciliation_.codehash;
        sourceChainId = block.chainid;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamStaticC2PAAttribution).interfaceId
            || id == type(IStreamStaticC2PAConflicts).interfaceId || id == 0x01ffc9a7;
    }

    function attributionC2PAConflicts(uint256 collection, uint256 token)
        external
        view
        returns (
            Conflicts.Standing memory tokenConflict,
            Conflicts.Standing memory collectionConflict
        )
    {
        _pins();
        if (token != 0) {
            tokenConflict = _conflict(
                collection,
                StreamMetadataSubjects.scopeSubject(
                    sourceChainId,
                    core,
                    StreamFinalityScope(StreamFinalityScopeType.TOKEN, collection, token, 0)
                )
            );
        }
        collectionConflict = _conflict(
            collection,
            StreamMetadataSubjects.scopeSubject(
                sourceChainId,
                core,
                StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collection, 0, 0)
            )
        );
    }

    function _conflict(uint256 collection, bytes32 subject)
        private
        view
        returns (Conflicts.Standing memory v)
    {
        bytes memory raw = _read(
            reconciliation,
            abi.encodeCall(Conflicts.standingConflict, (collection, subject)),
            192,
            REPORT_GAS
        );
        v = abi.decode(raw, (Conflicts.Standing));
        if (raw.length != 192 || keccak256(raw) != keccak256(abi.encode(v))) {
            revert C2PAStaticReadUnavailable();
        }
    }

    function attribution(uint256 collection, uint256 token) external view returns (bytes memory) {
        return _artist(collection, token);
    }

    function attributionWithC2PA(uint256 collection, uint256 token)
        external
        view
        override
        returns (bytes memory value, C.Display memory display_, bytes32 subject)
    {
        value = _artist(collection, token);
        if (token != 0) {
            subject = StreamMetadataSubjects.scopeSubject(
                sourceChainId,
                core,
                StreamFinalityScope(StreamFinalityScopeType.TOKEN, collection, token, 0)
            );
            display_ = _report(collection, subject);
            // A stale token result remains explicit; never replace it with a collection report.
            if (display_.recordHash != 0) return (value, display_, subject);
        }
        subject = StreamMetadataSubjects.scopeSubject(
            sourceChainId,
            core,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collection, 0, 0)
        );
        display_ = _report(collection, subject);
    }

    function _artist(uint256 collection, uint256 token) private view returns (bytes memory value) {
        _pins();
        bytes memory raw = _read(
            original,
            abi.encodeCall(IStreamC2PAOriginalAttribution.attribution, (collection, token)),
            32832,
            ARTIST_GAS
        );
        value = abi.decode(raw, (bytes));
        if (value.length > 32768 || keccak256(raw) != keccak256(abi.encode(value))) {
            revert C2PAStaticReadUnavailable();
        }
    }

    function _report(uint256 collection, bytes32 subject)
        private
        view
        returns (C.Display memory value)
    {
        bytes memory raw = _read(
            reconciliation, abi.encodeCall(C.display, (collection, subject)), 192, REPORT_GAS
        );
        value = abi.decode(raw, (C.Display));
        if (raw.length != 192 || keccak256(raw) != keccak256(abi.encode(value))) {
            revert C2PAStaticReadUnavailable();
        }
    }

    function _pins() private view {
        if (
            block.chainid != sourceChainId || original.codehash != originalCodeHash
                || reconciliation.codehash != reconciliationCodeHash
        ) revert C2PAStaticReadUnavailable();
    }

    function _read(address target, bytes memory input, uint256 maximum, bytes32 parameter)
        private
        view
        returns (bytes memory output)
    {
        uint256 cap = _gasParameterValue(parameter);
        output = new bytes(maximum);
        if (gasleft() <= cap + cap / 63 + 10000) revert C2PAStaticReadUnavailable();
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size == 0 || size > maximum) revert C2PAStaticReadUnavailable();
        assembly ("memory-safe") { mstore(output, size) }
    }
}
