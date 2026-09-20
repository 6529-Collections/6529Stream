// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "./StreamSettlementAdmission.sol";
import "../../interfaces/stream/revenue/IStreamAssetPermitPolicy.sol";

/// @notice Fixed read/ABI worker for the payment host. No storage or authorization writer.
library StreamERC20PaymentRead {
    error PermitCapabilityUnavailable(address asset);
    error PaymentResultMismatch();
    error InsufficientSettlementCallGas(uint256 requiredCap);
    error SettlementReadFailed(address target, bytes4 selector);

    struct FixedPlan {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate candidate;
        bytes executionData;
        uint8 mode;
        bytes permitInput;
        StreamPrimarySettlementTypes.PaymentIntent intent;
        bytes signature;
        uint256 deadline;
    }

    function prepareFixed(bytes calldata raw) public pure returns (FixedPlan memory p) {
        bytes4 selector = bytes4(raw[:4]);
        if (selector == IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleByPayer.selector)
        {
            (p.candidate, p.executionData) =
                abi.decode(raw[4:], (StreamPrimarySettlementTypes.ERC20SettlementCandidate, bytes));
        } else if (
            selector
                == IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithIntent.selector
        ) {
            (p.candidate, p.intent, p.signature, p.executionData) = abi.decode(
                raw[4:],
                (
                    StreamPrimarySettlementTypes.ERC20SettlementCandidate,
                    StreamPrimarySettlementTypes.PaymentIntent,
                    bytes,
                    bytes
                )
            );
            p.mode = 1;
        } else if (
            selector
                == IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithEIP2612Permit
                .selector
        ) {
            StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory permit;
            (p.candidate, permit, p.executionData) = abi.decode(
                raw[4:],
                (
                    StreamPrimarySettlementTypes.ERC20SettlementCandidate,
                    StreamPrimarySettlementTypes.EIP2612PermitAuthorization,
                    bytes
                )
            );
            p.mode = 2;
            p.permitInput = abi.encode(permit);
            p.deadline = permit.deadline;
        } else if (
            selector
                == IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithPermit2.selector
        ) {
            StreamPrimarySettlementTypes.Permit2TransferAuthorization memory permit;
            (p.candidate, permit, p.executionData) = abi.decode(
                raw[4:],
                (
                    StreamPrimarySettlementTypes.ERC20SettlementCandidate,
                    StreamPrimarySettlementTypes.Permit2TransferAuthorization,
                    bytes
                )
            );
            p.mode = 3;
            p.permitInput = abi.encode(permit);
            p.deadline = permit.deadline;
        } else {
            revert PaymentResultMismatch();
        }
    }

    function requireAdmission(
        address registry,
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory candidate
    ) public view {
        StreamSettlementAdmission.requireAdmission(registry, paymentAdapter, candidate);
    }

    function permitPolicy(
        address registry,
        address asset,
        uint8 mode,
        address permit2,
        bytes32 permit2CodeHash,
        uint256 permit2ChainId,
        uint256 cap
    ) public view returns (IStreamAssetPermitPolicy.AssetPermitPolicy memory policy) {
        bytes memory data = abi.encodeCall(IStreamAssetPermitPolicy.assetPermitPolicy, (asset));
        bytes memory response = new bytes(256);
        _admitGas(cap);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, registry, add(data, 32), mload(data), add(response, 32), 256)
            size := returndatasize()
        }
        if (!ok || size != 256) revert PermitCapabilityUnavailable(asset);
        policy = abi.decode(response, (IStreamAssetPermitPolicy.AssetPermitPolicy));
        if (
            policy.capabilities == 0 || policy.capabilities > 3 || policy.revision == 0
                || policy.assetCodeHash != asset.codehash
                || policy.assetPolicyHash
                    != bytes32(
                        _tokenRead(
                            registry,
                            abi.encodeCall(IStreamAssetPolicyRegistry.assetPolicyHash, (asset)),
                            cap
                        )
                    )
                || policy.assetPolicyRevision
                    != _tokenRead(
                        registry,
                        abi.encodeCall(IStreamAssetPermitPolicy.assetPolicyRevision, (asset)),
                        cap
                    ) || ((mode == 2 || mode == 4) && policy.capabilities & 1 == 0)
                || ((mode == 3 || mode == 5)
                    && (policy.capabilities & 2 == 0
                        || policy.permit2 != permit2
                        || permit2 == address(0)
                        || policy.permit2CodeHash != permit2CodeHash
                        || permit2.codehash != permit2CodeHash
                        || block.chainid != permit2ChainId
                        || policy.permit2AllowanceMode == 0
                        || policy.permit2AllowanceMode > 2))
        ) revert PermitCapabilityUnavailable(asset);
    }

    function checkStoredResult(
        address target,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result
    ) public view {
        bytes memory data =
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (result.settlementKey));
        bytes memory response = new bytes(384);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384 || keccak256(response) != keccak256(abi.encode(result))) {
            revert PaymentResultMismatch();
        }
    }

    function _admitGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40_000) {
            revert InsufficientSettlementCallGas(cap);
        }
    }

    /// @dev Callers admit bounded gas first, or use the exact-code infrastructure exception.
    function _read(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert SettlementReadFailed(target, bytes4(data));
    }

    function _tokenRead(address asset, bytes memory data, uint256 cap)
        private
        view
        returns (uint256)
    {
        _admitGas(cap);
        return _read(asset, data, cap);
    }
}
