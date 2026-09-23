// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewPreservationBindingTypesV1 as V
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationValidationV1 as Validation
} from "./StreamFinalityViewPreservationValidationV1.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";
import {
    IStreamGovernedParameterAuthority as Authority
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

import {
    StreamViewAdoptionTypes as D
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamFinalityViewDeclarationBindingV1 as Declaration
} from "./StreamFinalityViewDeclarationBindingV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as Complete
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    StreamFinalityViewPreservationCompleteValidationV1 as CompleteValidation
} from "./StreamFinalityViewPreservationCompleteValidationV1.sol";

/// @notice Exact original Governance class2 one-use source admission. No replacement or unbind.
library StreamFinalityViewPreservationBindingV1 {
    struct State {
        V.Capability capability;
        V.Receipt receipt;
        Sources.Receipt completeReceipt;
    }

    function initialize(State storage s, Native.Config memory original) public {
        if (
            s.capability.capabilityHash != 0 || original.chainId != block.chainid
                || original.readGas < 50000
        ) revert V.InvalidViewPreservationBinding();
        Validation.pin(original.targets[1], original.codeHashes[1]);
        bytes memory raw = Reads.read(
            original.targets[1],
            abi.encodeWithSignature("governanceAuthority()"),
            32,
            original.readGas
        );
        V.Capability memory c;
        c.authority = abi.decode(raw, (address));
        if (keccak256(raw) != keccak256(abi.encode(c.authority))) {
            revert V.InvalidViewPreservationBinding();
        }
        c.authorityCodeHash = abi.decode(
            Reads.read(
                original.targets[1],
                abi.encodeWithSignature("executorCodeHash()"),
                32,
                original.readGas
            ),
            (bytes32)
        );
        Validation.pin(c.authority, c.authorityCodeHash);
        c.originalHash = keccak256(abi.encode(original));
        c.capabilityHash = V.hashCapability(original.chainId, address(this), c);
        s.capability = c;
    }

    function transition(
        State storage s,
        Native.Config memory original,
        V.Configuration memory configuration,
        D.Binding memory declaration
    ) public view returns (V.Transition memory) {
        if (s.receipt.recordHash != 0) {
            revert V.ViewPreservationAlreadyBound();
        }
        _capability(s.capability, original);
        return V.transition(
            original.chainId,
            address(this),
            Validation.read(original, s.capability, configuration, declaration)
        );
    }

    function bind(
        State storage s,
        Native.Config memory original,
        V.Configuration memory configuration,
        D.Binding memory declaration
    ) public returns (V.Receipt memory r) {
        if (s.receipt.recordHash != 0) {
            revert V.ViewPreservationAlreadyBound();
        }
        _capability(s.capability, original);
        if (msg.sender != s.capability.authority) revert V.ViewPreservationBindingGovernance();
        r = Validation.read(original, s.capability, configuration, declaration);
        V.Transition memory expected = V.transition(original.chainId, address(this), r);
        return _record(s, r, _authorize(original.readGas, expected));
    }

    function completeTransition(
        State storage s,
        Native.Config memory original,
        V.Configuration memory configuration,
        D.Binding memory declaration,
        Sources.Selection memory selected
    ) public view returns (V.Transition memory) {
        if (s.receipt.recordHash != 0) {
            revert V.ViewPreservationAlreadyBound();
        }
        _capability(s.capability, original);
        V.Receipt memory basic = Validation.read(original, s.capability, configuration, declaration);
        Sources.Receipt memory complete = CompleteValidation.read(original, basic, selected);
        return Complete.transition(original.chainId, address(this), basic, complete);
    }

    function bindComplete(
        State storage s,
        Native.Config memory original,
        V.Configuration memory configuration,
        D.Binding memory declaration,
        Sources.Selection memory selected
    ) public returns (V.Receipt memory basic, Sources.Receipt memory complete) {
        if (s.receipt.recordHash != 0) revert V.ViewPreservationAlreadyBound();
        _capability(s.capability, original);
        if (msg.sender != s.capability.authority) revert V.ViewPreservationBindingGovernance();
        basic = Validation.read(original, s.capability, configuration, declaration);
        complete = CompleteValidation.read(original, basic, selected);
        V.Transition memory expected =
            Complete.transition(original.chainId, address(this), basic, complete);
        // Only the complete transition is authorized. Both receipts consume the same action and
        // the existing one-use guard; the original basic proposal is not executed separately.
        bytes32 id = _authorize(original.readGas, expected);
        basic = _record(s, basic, id);
        complete.basicBindingRecordHash = basic.recordHash;
        complete.actionId = id;
        complete.boundAt = basic.boundAt;
        complete.recordHash = Complete.receiptHash(original.chainId, address(this), complete);
        s.completeReceipt = complete;
    }

    function completeHistory(State storage s, Native.Config memory original)
        public
        view
        returns (Sources.Receipt memory r)
    {
        return _completeHistory(s, original);
    }

    function _completeHistory(State storage s, Native.Config memory original)
        private
        view
        returns (Sources.Receipt memory r)
    {
        r = s.completeReceipt;
        if (r.recordHash == 0) revert Complete.ViewPreservationCompleteBindingUnavailable();
        V.Receipt memory basic = s.receipt;
        if (
            basic.recordHash == 0 || basic.recordHash != V.receiptHash(basic)
                || r.basicBindingRecordHash != basic.recordHash || r.actionId == 0
                || r.actionId != basic.actionId || r.boundAt != basic.boundAt
                || r.recordHash != Complete.receiptHash(original.chainId, address(this), r)
        ) revert Complete.InvalidViewPreservationCompleteBinding();
        // Historical admission remains readable after runtime or dependency drift.
    }

    function completeSelection(State storage s, Native.Config memory original)
        public
        view
        returns (Sources.Selection memory)
    {
        Sources.Receipt memory r = _completeHistory(s, original);
        _capability(s.capability, original);
        CompleteValidation.requireBindings(original, s.receipt, r.selection);
        return r.selection;
    }

    /// @dev Both entrypoints authenticate their own complete expected transition. The complete
    /// route never asks Governance to authorize the inner basic proposal.
    function _authorize(uint256 readGas, V.Transition memory expected)
        private
        view
        returns (bytes32)
    {
        if (
            abi.decode(
                    Reads.read(
                        msg.sender,
                        abi.encodeCall(Authority.isStreamGovernedParameterAuthority, ()),
                        32,
                        readGas
                    ),
                    (uint256)
                ) != 1
        ) revert V.ViewPreservationBindingGovernance();
        bytes memory raw =
            Reads.read(msg.sender, abi.encodeCall(Authority.currentAction, ()), 192, readGas);
        (
            bool executing,
            bytes32 id,
            uint8 actionClass,
            bytes32 scopeHash,
            bytes32 oldValueHash,
            bytes32 newValueHash
        ) = abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id == 0 || actionClass != V.ACTION_CLASS
                || scopeHash != expected.scopeHash || oldValueHash != expected.oldValueHash
                || newValueHash != expected.newValueHash
                || keccak256(raw)
                    != keccak256(
                        abi.encode(
                            true,
                            id,
                            V.ACTION_CLASS,
                            expected.scopeHash,
                            expected.oldValueHash,
                            expected.newValueHash
                        )
                    )
        ) revert V.ViewPreservationBindingGovernance();
        return id;
    }

    function _record(State storage s, V.Receipt memory r, bytes32 id)
        private
        returns (V.Receipt memory)
    {
        if (block.timestamp > type(uint64).max) revert V.InvalidViewPreservationBinding();
        r.actionId = id;
        r.boundAt = uint64(block.timestamp);
        r.recordHash = V.receiptHash(r);
        s.receipt = r;
        return r;
    }

    function current(State storage s, Native.Config memory original)
        public
        view
        returns (V.Configuration memory)
    {
        if (s.receipt.recordHash == 0) revert V.ViewPreservationPending();
        _capability(s.capability, original);
        Validation.requireCurrent(original, s.capability, s.receipt);
        return s.receipt.configuration;
    }

    function declaration(State storage s, Native.Config memory original)
        public
        view
        returns (D.Binding memory)
    {
        if (s.receipt.recordHash == 0) revert V.ViewPreservationPending();
        _capability(s.capability, original);
        if (s.receipt.recordHash != V.receiptHash(s.receipt) || s.receipt.actionId == 0) {
            revert V.InvalidViewPreservationBinding();
        }
        Declaration.pins(original, s.capability, s.receipt.declaration);
        return s.receipt.declaration;
    }

    function _capability(V.Capability memory c, Native.Config memory original) private view {
        Validation.pin(c.authority, c.authorityCodeHash);
        if (
            original.chainId != block.chainid || c.originalHash != keccak256(abi.encode(original))
                || c.capabilityHash == 0
                || c.capabilityHash != V.hashCapability(original.chainId, address(this), c)
        ) revert V.InvalidViewPreservationBinding();
    }
}
