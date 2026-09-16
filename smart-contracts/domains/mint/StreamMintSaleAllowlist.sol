// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "./StreamMintCounterPolicy.sol";

/// @notice Independently verifies the Manager's canonical proofs for a single-token sale.
/// @dev This library is linked into the sale consumer. Definition reads must therefore name
///      the Manager explicitly rather than use the library caller as the definition owner.
library StreamMintSaleAllowlist {
    // Matches StreamMintManager.MAX_PHASE_COUNTERS; keeps the complete policy read bounded.
    uint256 private constant MAX_COUNTERS = 16;

    struct Policy {
        bytes32[] ids;
        IStreamMintManager.MintCounterConfig[] configs;
        bytes32[] roots;
        uint256 merkleCount;
    }

    struct Request {
        address manager;
        uint256 collectionId;
        bytes32 phaseId;
        address payer;
        address recipient;
        bytes32 priceCounterId;
    }

    error InvalidSaleAllowlistPolicy(bytes32 counterId);
    error SaleAllowlistCounterLimitExceeded(uint256 supplied, uint256 maximum);
    error SaleAllowlistProofCountMismatch(uint256 supplied, uint256 required);
    error InvalidSaleAllowlistProof(bytes32 counterId, address account);
    error InvalidSaleAllowlistPrice(bytes32 counterId);
    error AmbiguousSaleAllowlistPrice(bytes32 configuredCounterId, bytes32 otherCounterId);

    function validatePolicy(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 priceCounterId
    ) public view {
        _policy(manager, collectionId, phaseId, priceCounterId);
    }

    /// @notice Returns the selected authenticated leaf price, or false for sale-policy fallback.
    /// @dev The sale must pass these same resolver bytes, payer and beneficiary to the Manager.
    ///      A true zero-price override is distinct from no override; free-sale policy is external.
    function price(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        address payer,
        address recipient,
        bytes memory resolverData,
        bytes32 priceCounterId
    ) public view returns (bool hasOverride, uint256 overridePrice) {
        Request memory request = Request(
            manager, collectionId, phaseId, payer, recipient, priceCounterId
        );
        return _price(request, resolverData);
    }

    function _price(Request memory request, bytes memory resolverData)
        private
        view
        returns (bool hasOverride, uint256 overridePrice)
    {
        Policy memory policy = _policy(
            request.manager, request.collectionId, request.phaseId, request.priceCounterId
        );
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            abi.decode(resolverData, (IStreamMintCounterPolicy.AllowlistProof[][]));
        if (proofs.length != policy.merkleCount) {
            revert SaleAllowlistProofCountMismatch(proofs.length, policy.merkleCount);
        }
        uint256 proofIndex;
        for (uint256 i; i < policy.ids.length; ++i) {
            IStreamMintManager.MintCounterConfig memory config = policy.configs[i];
            if (config.capMode != IStreamMintLedger.CounterCapMode.MERKLE_STATIC) continue;
            if (proofs[proofIndex].length != 1) {
                revert SaleAllowlistProofCountMismatch(proofs[proofIndex].length, 1);
            }
            IStreamMintCounterPolicy.AllowlistProof memory proof = proofs[proofIndex++][0];
            bytes32 id = policy.ids[i];
            address account = config.keyMode == IStreamMintManager.CounterKeyMode.PAYER
                ? request.payer
                : request.recipient;
            bytes32 leaf = StreamMintCounterPolicy.allowlistLeaf(
                request.manager, request.collectionId, request.phaseId, id, account, proof
            );
            if (
                proof.maxCount == 0 || proof.maxCount > config.staticCap
                    || !StreamMintCounterPolicy.verify(policy.roots[i], leaf, proof.proof)
            ) {
                revert InvalidSaleAllowlistProof(id, account);
            }
            if (!proof.hasPriceOverride && proof.priceOverride != 0) {
                revert InvalidSaleAllowlistPrice(id);
            }
            if (id == request.priceCounterId) {
                hasOverride = proof.hasPriceOverride;
                overridePrice = proof.priceOverride;
            } else if (proof.hasPriceOverride) {
                revert AmbiguousSaleAllowlistPrice(request.priceCounterId, id);
            }
        }
    }

    function _policy(address manager, uint256 collectionId, bytes32 phaseId, bytes32 priceCounterId)
        private
        view
        returns (Policy memory policy)
    {
        if (priceCounterId == bytes32(0)) revert InvalidSaleAllowlistPolicy(priceCounterId);
        IStreamMintReads reads = IStreamMintReads(manager);
        policy.ids = reads.phaseCounterIds(collectionId, phaseId);
        if (policy.ids.length > MAX_COUNTERS) {
            revert SaleAllowlistCounterLimitExceeded(policy.ids.length, MAX_COUNTERS);
        }
        IStreamMintCounterPolicy ledger = IStreamMintCounterPolicy(address(reads.mintLedger()));
        policy.configs = new IStreamMintManager.MintCounterConfig[](policy.ids.length);
        policy.roots = new bytes32[](policy.ids.length);
        bool found;
        for (uint256 i; i < policy.ids.length; ++i) {
            bytes32 id = policy.ids[i];
            IStreamMintManager.MintCounterConfig memory config =
                reads.counterConfig(collectionId, phaseId, id);
            policy.configs[i] = config;
            if (config.capMode != IStreamMintLedger.CounterCapMode.MERKLE_STATIC) continue;
            (bool exists, IStreamMintCounterPolicy.Definition memory definition) =
                ledger.counterDefinitionForManager(manager, config.counterConfigHash);
            if (
                !config.enabled || config.staticCap == 0
                    || (config.keyMode != IStreamMintManager.CounterKeyMode.PAYER
                        && config.keyMode != IStreamMintManager.CounterKeyMode.RECIPIENT) || !exists
                    || definition.keyMode != config.keyMode || definition.capRoot == bytes32(0)
                    || definition.scope == IStreamMintCounterPolicy.CounterScope.GLOBAL
                    || StreamMintCounterPolicy.definitionHash(definition)
                        != config.counterConfigHash
            ) {
                revert InvalidSaleAllowlistPolicy(id);
            }
            policy.roots[i] = definition.capRoot;
            ++policy.merkleCount;
            if (id == priceCounterId) found = true;
        }
        if (!found) revert InvalidSaleAllowlistPolicy(priceCounterId);
    }
}
