// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCanonicalNativeSalesDeployment as D
} from "./StreamCanonicalNativeSalesDeployment.sol";
import {
    StreamCanonicalNativeSalesActivationPlan as A
} from "./StreamCanonicalNativeSalesActivationPlan.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    GovernanceActionPolicyEntry
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamModuleRegistration
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamNativeImmediateSales
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import {
    IStreamNativeClaimSales
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeClaimSales.sol";
import {
    IStreamNativeDutchSales
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeDutchSales.sol";

interface CanonicalNativeSalesDeploymentVm {
    function envAddress(string calldata key) external view returns (address);
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
}

/// @notice Runnable, typed Anvil/Sepolia entry for the three canonical native companions.
/// @dev Foundry supplies its signer independently; this script reads only a public sender address.
/// Each CREATE/ownership handoff is a separate broadcast transaction. Preserve the original
/// transaction journal and exact source/configuration for --resume; a fresh run is not a retry.
/// The prepare/verify functions are read-only and neither sign nor schedule governance actions.
contract DeployCanonicalNativeSales {
    CanonicalNativeSalesDeploymentVm private constant vm =
        CanonicalNativeSalesDeploymentVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run(D.Configuration calldata configuration)
        external
        returns (D.Products memory products)
    {
        _engineeringChain();
        address operator = vm.envAddress("STREAM_DEPLOYER");
        require(operator != address(0), "deployer required");
        vm.startBroadcast(operator);
        products = D.deploy(configuration);
        vm.stopBroadcast();
    }

    /// @notice Verify saved confirmed coordinates without constructing or replacing a product.
    /// @dev Inspect partial receipts and owner readbacks before resuming the original journal.
    function verifyConstruction(A.Context calldata context) external view returns (bytes32) {
        _engineeringChain();
        return D.constructionHash(context.configuration, context.products);
    }

    function pendingRegistrations(A.Context calldata context)
        external
        view
        returns (StreamModuleRegistration[] memory)
    {
        _engineeringChain();
        return A.pendingRegistrations(context);
    }

    function prepareAdmission(A.Context calldata context)
        external
        view
        returns (GenesisBatch memory, GovernanceActionPolicyEntry[] memory)
    {
        _engineeringChain();
        return (A.registrationBatch(context), A.policies(context));
    }

    function prepareCatalogAdditions(
        A.Context calldata context,
        GovernanceActionPolicyEntry[] calldata known
    ) external view returns (GovernanceActionPolicyEntry[] memory) {
        _engineeringChain();
        return A.catalogAdditions(context, known);
    }

    function prepareRecorderCredit(A.Context calldata context)
        external
        view
        returns (GenesisBatch memory)
    {
        _engineeringChain();
        return A.recorderCredit(context);
    }

    function verifySettlementReady(A.Context calldata context) external view {
        _engineeringChain();
        A.requireSettlementReady(context);
    }

    function preparePhase(A.Context calldata context, A.Phase calldata phase)
        external
        view
        returns (A.OwnerCall memory)
    {
        _engineeringChain();
        return A.configurePhase(context, phase);
    }

    function preparePhaseExecutor(
        A.Context calldata context,
        uint8 product,
        uint256 collection,
        bytes32 phase
    ) external view returns (A.OwnerCall memory) {
        _engineeringChain();
        return A.phaseExecutor(context, product, collection, phase);
    }

    function prepareSigner(
        A.Context calldata context,
        uint8 product,
        uint256 collection,
        address signer,
        uint8 kind,
        bytes32 evidence,
        bool enabled
    ) external view returns (A.OwnerCall memory) {
        _engineeringChain();
        return A.configureSigner(context, product, collection, signer, kind, evidence, enabled);
    }

    function prepareImmediate(
        A.Context calldata context,
        IStreamNativeImmediateSales.Configuration calldata sale
    ) external view returns (A.OwnerCall memory) {
        _engineeringChain();
        return A.registerImmediate(context, sale);
    }

    function prepareClaim(
        A.Context calldata context,
        IStreamNativeClaimSales.Configuration calldata sale
    ) external view returns (A.OwnerCall memory) {
        _engineeringChain();
        return A.registerClaim(context, sale);
    }

    function prepareDutch(
        A.Context calldata context,
        IStreamNativeDutchSales.Configuration calldata sale
    ) external view returns (A.OwnerCall memory) {
        _engineeringChain();
        return A.registerDutch(context, sale);
    }

    function verifyOwnerCall(A.Context calldata context, A.OwnerCall calldata saved) external view {
        _engineeringChain();
        A.validateOwnerCall(context, saved);
    }

    /// @notice Only an actually Executor-owned call receives a governed batch.
    /// @dev Safe-owned calls retain the direct Safe caller/target/value/data returned above.
    function prepareGoverned(A.Context calldata context, A.OwnerCall calldata saved)
        external
        view
        returns (GenesisBatch memory)
    {
        _engineeringChain();
        return A.governed(context, saved);
    }

    function _engineeringChain() private view {
        require(block.chainid == 31337 || block.chainid == 11155111, "Anvil or Sepolia only");
    }
}
