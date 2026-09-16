// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintCounterPolicy.sol";

/// @notice Canonical counter extension commitments and inline Merkle verification.
library StreamMintCounterPolicy {
    bytes32 internal constant DEFINITION_DOMAIN =
        keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1");
    bytes32 internal constant ALLOWLIST_LEAF_DOMAIN =
        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1");

    function definitionHash(IStreamMintCounterPolicy.Definition memory d)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(DEFINITION_DOMAIN, d));
    }

    function validateDefinition(IStreamMintCounterPolicy.Definition memory d) internal pure {
        IStreamMintManager.CounterKeyMode key = d.keyMode;
        if (
            key == IStreamMintManager.CounterKeyMode.UNKNOWN
                || key == IStreamMintManager.CounterKeyMode.AUTHORIZER
                || (key == IStreamMintManager.CounterKeyMode.CONTEXT
                    && d.scope == IStreamMintCounterPolicy.CounterScope.GLOBAL)
                || (d.capRoot != bytes32(0)
                    && (d.scope == IStreamMintCounterPolicy.CounterScope.GLOBAL
                        || (key != IStreamMintManager.CounterKeyMode.PAYER
                            && key != IStreamMintManager.CounterKeyMode.RECIPIENT)))
        ) {
            revert IStreamMintCounterPolicy.InvalidCounterDefinition();
        }
    }

    function read(address ledger, bytes32 hash)
        internal
        view
        returns (bool exists, IStreamMintCounterPolicy.Definition memory d)
    {
        // Older ledgers remain usable for their original PHASE policies.
        (bool ok, bytes memory result) = ledger.staticcall{ gas: 30_000 }(
            abi.encodeWithSelector(
                IERC165.supportsInterface.selector, type(IStreamMintCounterPolicy).interfaceId
            )
        );
        if (!ok || result.length != 32 || abi.decode(result, (uint256)) != 1) {
            d.scope = IStreamMintCounterPolicy.CounterScope.PHASE;
            return (false, d);
        }
        (exists, d) =
            IStreamMintCounterPolicy(ledger).counterDefinitionForManager(address(this), hash);
        if (!exists) d.scope = IStreamMintCounterPolicy.CounterScope.PHASE;
    }

    function validateConfig(
        address ledger,
        bytes32 counterId,
        IStreamMintManager.MintCounterConfig memory config
    ) internal view {
        (bool exists, IStreamMintCounterPolicy.Definition memory d) =
            read(ledger, config.counterConfigHash);
        bool merkle = config.capMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC;
        if (
            (exists
                    && (d.keyMode != config.keyMode
                        || config.capMode == IStreamMintLedger.CounterCapMode.NONE
                        || (d.capRoot != bytes32(0)) != merkle))
                || (merkle && (!exists || config.staticCap == 0))
        ) {
            revert IStreamMintManager.InvalidMintCounter(counterId);
        }
    }

    function scopeIds(
        IStreamMintCounterPolicy.CounterScope scope,
        uint256 collectionId,
        bytes32 phaseId
    ) internal pure returns (uint256, bytes32) {
        if (scope == IStreamMintCounterPolicy.CounterScope.GLOBAL) {
            return (0, bytes32(0));
        }
        if (scope == IStreamMintCounterPolicy.CounterScope.COLLECTION) {
            return (collectionId, bytes32(0));
        }
        return (collectionId, phaseId);
    }

    function allowlistLeaf(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        address account,
        IStreamMintCounterPolicy.AllowlistProof memory p
    ) internal view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        ALLOWLIST_LEAF_DOMAIN,
                        block.chainid,
                        manager,
                        collectionId,
                        phaseId,
                        counterId,
                        account,
                        p.maxCount,
                        p.hasPriceOverride,
                        p.priceOverride
                    )
                )
            )
        );
    }

    /// @notice Fails closed until a standard mint sale path consumes authenticated leaf prices.
    function validateSupportedPrice(
        bytes32 counterId,
        address account,
        IStreamMintCounterPolicy.AllowlistProof memory proof
    ) internal pure {
        if (proof.hasPriceOverride || proof.priceOverride != 0) {
            revert IStreamMintCounterPolicy.MintAllowlistPriceOverrideUnsupported(
                counterId, account, proof.hasPriceOverride, proof.priceOverride
            );
        }
    }

    function verify(bytes32 root, bytes32 leaf, bytes32[] memory proof)
        internal
        pure
        returns (bool)
    {
        bytes32 computed = leaf;
        for (uint256 i; i < proof.length; ++i) {
            bytes32 sibling = proof[i];
            computed = computed < sibling
                ? keccak256(abi.encode(computed, sibling))
                : keccak256(abi.encode(sibling, computed));
        }
        return computed == root;
    }
}
