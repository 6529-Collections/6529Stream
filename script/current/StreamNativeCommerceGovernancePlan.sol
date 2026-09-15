// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCommerceDeployment.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamNativeCustodyPrimarySettlement.sol";

interface NativeCommerceOwner {
    function owner() external view returns (address);
}

/// @notice Exact delayed-governance plans for the deployed native commerce pair.
/// @dev Saved products are operator-verified deployment coordinates, not independent code provenance.
///      Catalog history comes from the original genesis and executed extension receipts.
library StreamNativeCommerceGovernancePlan {
    error IncompatibleNativeCommercePolicy();
    error NativeCommerceExecutorMustOwnManager();

    function custodyBinding(StreamNativeCommerceDeployment.Products memory products)
        internal
        view
        returns (GenesisBatch memory batch)
    {
        StreamNativeCommerceDeployment.validate(products);
        IStreamNativeCustodyPrimarySettlement recorder =
            IStreamNativeCustodyPrimarySettlement(address(products.recorder));
        if (recorder.canonicalCustodyHouse().house != address(0)) {
            revert IStreamNativeCustodyPrimarySettlement.NativeCustodyHouseAlreadyBound();
        }
        // The original recorder validates both ACTIVE registrations, current Core/Registry,
        // original house reciprocals and the complete schedulable pin preimage.
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            recorder.custodyHouseTransition(address(products.house));
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] =
            abi.encodeCall(recorder.bindCanonicalCustodyHouse, (address(products.house)));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(recorder), batch.callDatas[0], scope, oldState, newState
        );
    }

    /// @notice Governed owner route; an actual Safe owner uses the separate direct binding calldata.
    function managerBinding(StreamNativeCommerceDeployment.Products memory products)
        internal
        view
        returns (GenesisBatch memory batch)
    {
        (address target, bytes memory data) =
            StreamNativeCommerceDeployment.managerBinding(products);
        if (NativeCommerceOwner(target).owner() != products.house.governanceAuthority()) {
            revert NativeCommerceExecutorMustOwnManager();
        }
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] = StreamCurrentStackPlan.call(
            target, data, keccak256(abi.encode(target, data)), bytes32(0), keccak256(data)
        );
    }

    /// @notice Five exact intents, including class-one/zero-value custody-house admission.
    function policies(StreamNativeCommerceDeployment.Products memory products)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        GovernanceActionPolicyEntry[] memory basic =
            StreamNativeCommerceDeployment.policies(products);
        rows = new GovernanceActionPolicyEntry[](basic.length + 1);
        for (uint256 i; i < basic.length; ++i) {
            rows[i] = basic[i];
        }
        address target = address(products.recorder);
        rows[basic.length] = GovernanceActionPolicyEntry(
            1,
            target,
            IStreamNativeCustodyPrimarySettlement.bindCanonicalCustodyHouse.selector,
            products.recorderCodeHash,
            keccak256(abi.encode(products.deploymentManifestHash, target)),
            1,
            0,
            0,
            bytes32(0)
        );
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
    }

    /// @notice Exclude existing compatible keys without rewriting their original profile hashes.
    /// @dev knownEntries must be the operator's verified current catalog inventory. This helper
    ///      does not authenticate that offchain history. Normal Executor extension/scheduling
    ///      checks remain authoritative; a missing or conflicting live entry cannot gain authority.
    function catalogAdditions(
        StreamNativeCommerceDeployment.Products memory products,
        GovernanceActionPolicyEntry[] memory knownEntries
    ) internal view returns (GovernanceActionPolicyEntry[] memory additions) {
        GovernanceActionPolicyEntry[] memory wanted = policies(products);
        uint256 count;
        for (uint256 i; i < wanted.length; ++i) {
            bool found;
            for (uint256 j; j < knownEntries.length; ++j) {
                GovernanceActionPolicyEntry memory prior = knownEntries[j];
                if (_key(prior) != _key(wanted[i])) continue;
                if (
                    found || prior.targetCodeHash != wanted[i].targetCodeHash
                        || prior.targetProfileHash == bytes32(0) || prior.callType != 1
                        || prior.valuePolicy != 0 || prior.valueLimit != 0
                        || prior.valueSemanticsHash != bytes32(0)
                ) revert IncompatibleNativeCommercePolicy();
                found = true;
            }
            if (!found) wanted[count++] = wanted[i];
        }
        additions = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            additions[i] = wanted[i];
        }
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }
}
