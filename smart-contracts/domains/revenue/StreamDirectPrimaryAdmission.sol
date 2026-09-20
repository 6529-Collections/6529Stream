// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementAdmission.sol";
import "../../interfaces/stream/revenue/IStreamDirectPrimarySaleReceipt.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";

/// @notice Live canonical admission for the original direct products, including retained auctions.
/// @dev Uses exact-code fixed-buffer infrastructure reads, as in the original settlement admission.
library StreamDirectPrimaryAdmission {
    error DirectPrimaryDependency(address target);
    error DirectPrimaryNotAdmitted(address adapter);
    error DirectPrimaryOriginInvalid(bytes32 authorizationId);

    function capture(
        StreamDirectPrimarySaleTypes.Bindings memory bindings,
        address registry,
        bytes32 registryCodeHash
    ) public view returns (uint64 createdAt, uint64 revision) {
        _bindings(bindings, registry, registryCodeHash);
        StreamSettlementAdmission.ModuleFacts memory facts = _record(registry);
        if (facts.status != 1 || block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert DirectPrimaryNotAdmitted(address(this));
        }
        return (uint64(block.timestamp), facts.revision);
    }

    function requireReceipt(
        StreamDirectPrimarySaleTypes.Bindings memory bindings,
        address registry,
        bytes32 registryCodeHash,
        bytes32 authorizationId,
        StreamDirectPrimarySaleTypes.Receipt memory receipt
    ) public view {
        _bindings(bindings, registry, registryCodeHash);
        StreamSettlementAdmission.ModuleFacts memory facts = _record(registry);
        bool auction = bindings.productKind == StreamDirectPrimarySaleTypes.ENGLISH_AUCTION;
        if (
            receipt.createdAt == 0 || receipt.createdAt > block.timestamp
                || receipt.createdAt < facts.registeredAt || receipt.registryRevision == 0
                || receipt.registryRevision > facts.revision
                || (!auction
                    && (facts.status != 1
                        || receipt.createdAt != block.timestamp
                        || receipt.registryRevision != facts.revision))
                || (facts.status == 2
                    && (!auction
                        || receipt.createdAt >= facts.statusUpdatedAt
                        || receipt.registryRevision >= facts.revision))
        ) revert DirectPrimaryNotAdmitted(address(this));
        if (
            authorizationId == 0 || receipt.authorizationDigest == 0 || receipt.collectionId == 0
                || receipt.tokenId == 0 || receipt.operationRoot == 0 || receipt.operationId == 0
                || receipt.boundMintPolicyHash == 0 || receipt.expectedPrimaryPolicyHash == 0
                || receipt.profileId == 0 || receipt.wallet == address(0)
                || receipt.payer == address(0) || receipt.beneficiary == address(0)
                || receipt.amount == 0
                || (bindings.productKind == StreamDirectPrimarySaleTypes.ERC20_FIXED_PRICE
                        ? receipt.asset == address(0)
                        : receipt.asset != address(0))
                || _word(
                        bindings.mintManager,
                        abi.encodeCall(
                            IStreamMintReads.isOperationRootUsed, (receipt.operationRoot)
                        )
                    ) != 1
                || _word(
                        bindings.mintManager,
                        abi.encodeCall(IStreamMintReads.isAuthorizationUsed, (authorizationId))
                    ) != 1
        ) revert DirectPrimaryOriginInvalid(authorizationId);
    }

    function _bindings(
        StreamDirectPrimarySaleTypes.Bindings memory bindings,
        address registry,
        bytes32 registryCodeHash
    ) private view {
        StreamSettlementAdmission.requireRegistry(
            bindings.core, bindings.coreCodeHash, registry, registryCodeHash
        );
        if (
            block.chainid != bindings.deploymentChainId
                || !StreamSettlementAdmission.isContract(bindings.mintManager)
                || bindings.mintManager.codehash != bindings.mintManagerCodeHash
                || _word(bindings.mintManager, abi.encodeCall(IStreamMintReads.core, ()))
                    != uint160(bindings.core)
                || _word(bindings.mintManager, abi.encodeCall(IStreamMintReads.moduleRegistry, ()))
                    != uint160(registry)
        ) revert DirectPrimaryDependency(bindings.mintManager);
    }

    function _record(address registry)
        private
        view
        returns (StreamSettlementAdmission.ModuleFacts memory facts)
    {
        bytes memory data = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (address(this)));
        uint256[14] memory w;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), registry, add(data, 32), mload(data), w, 448)
            size := returndatasize()
        }
        bytes4 id = type(IStreamDirectPrimarySaleReceipt).interfaceId;
        if (
            !ok || size < 448 || w[0] != 32 || (w[1] != 1 && w[1] != 2)
                || bytes32(w[2]) != StreamDirectPrimarySaleTypes.MODULE_TYPE
                || bytes32(w[3]) != StreamDirectPrimarySaleTypes.MODULE_VERSION
                || w[4] != uint256(uint32(id)) << 224 || w[5] > type(uint32).max
                || bytes32(w[6]) != address(this).codehash || w[7] == 0 || w[8] == 0 || w[9] != 384
                || w[10] == 0 || w[10] > block.timestamp || w[10] > type(uint64).max
                || w[11] < w[10] || w[11] > block.timestamp || w[11] > type(uint64).max
                || w[12] == 0 || w[12] > type(uint64).max || w[13] > size - 448
                || size - 448 != ((w[13] + 31) / 32) * 32
                || _word(address(this), abi.encodeCall(IERC165.supportsInterface, (id))) != 1
                || _word(
                        address(this),
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7)))
                    ) != 1
                || _word(
                        address(this),
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff)))
                    ) != 0
        ) revert DirectPrimaryNotAdmitted(address(this));
        facts = StreamSettlementAdmission.ModuleFacts(
            uint8(w[1]), uint64(w[10]), uint64(w[11]), uint64(w[12])
        );
    }

    function _word(address target, bytes memory data) private view returns (uint256 value) {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            value := mload(0)
        }
        if (!ok || size != 32) revert DirectPrimaryDependency(target);
    }
}
