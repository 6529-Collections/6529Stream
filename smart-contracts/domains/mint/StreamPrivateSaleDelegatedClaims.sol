// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeInventorySale.sol";
import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";
import {
    IStreamPrivateSaleDelegatedClaims as DC
} from "../../interfaces/stream/mint/IStreamPrivateSaleDelegatedClaims.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed guarded-host claim worker using the retained original delegation profile.
/// @dev Core/registry pins and configuration come only from host immutables. No sale admission,
///      pause, current royalty, Artist or signing authority is repeated on an earned claim.
library StreamPrivateSaleDelegatedClaims {
    event SaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint8 saleKind,
        address asset,
        bytes32 saleConfigHash,
        bytes32 expectedPrimaryPolicyHash,
        uint8 primaryPolicyMode
    );

    /// @dev The host has completed all original admission/identity/ownership reads and consumed
    ///      its original sale nonce. This body makes no external call and retains original writes/events.
    function recordSale(
        P.Sale storage sale,
        bytes32 id,
        uint256 nonce,
        uint64 revision,
        address platformSigner,
        bytes calldata data
    ) public {
        P.SaleConfig memory config = abi.decode(data[4:], (P.SaleConfig));
        sale.config = config;
        sale.configHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CONSIGNMENT_CONFIG_V1"),
                block.chainid,
                address(this),
                nonce,
                platformSigner,
                config
            )
        );
        sale.saleNonce = nonce;
        sale.createdAt = uint64(block.timestamp);
        sale.registryRevision = revision;
        sale.status = 1;
        emit SaleConfigured(
            1, id, config.collectionId, 0, config.saleKind, address(0), sale.configHash, 0, 0
        );
    }

    /// @dev Fixed terminal views retain the original tuple shapes, source reads and host context.
    function read(
        mapping(bytes32 => P.Sale) storage sales,
        StreamNativeInventoryState.State storage inventory,
        StreamPrivateSaleSupport.Context memory context,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        if (selector == bytes4(keccak256("eip712Domain()"))) {
            return abi.encode(
                bytes1(0x0f),
                "6529Stream Sales",
                "1",
                block.chainid,
                address(this),
                bytes32(0),
                new uint256[](0)
            );
        }
        bytes32 id = abi.decode(data[4:], (bytes32));
        P.Sale storage sale = sales[id];
        if (selector == P.saleRecord.selector) {
            if (inventory.inventories[id].saleNonce != 0) {
                return abi.encode(
                    uint8(14),
                    inventory.inventories[id].config.collectionId,
                    bytes32(0),
                    address(0),
                    inventory.inventories[id].configHash,
                    bytes32(0),
                    uint8(0),
                    inventory.inventories[id].status
                );
            }
            return abi.encode(
                sale.config.saleKind,
                sale.config.collectionId,
                bytes32(0),
                address(0),
                sale.configHash,
                sale.config.expectedPrimaryPolicyHash,
                uint8(0),
                sale.status
            );
        }
        if (selector == P.custodySaleLifecycle.selector) {
            if (inventory.inventories[id].saleNonce != 0) {
                return abi.encode(
                    inventory.inventories[id].createdAt, inventory.inventories[id].registryRevision
                );
            }
            return abi.encode(sale.createdAt, sale.registryRevision);
        }
        if (selector == P.royaltyQuote.selector) {
            if (sale.saleNonce == 0) revert P.PrivateSaleUnavailable(id);
            if (sale.status == 3) {
                return abi.encode(sale.royaltyReceiver, sale.royaltyAmount, true, true);
            }
            (address receiver, uint256 amount) =
                StreamPrivateSaleSupport.royalty(context, sale.config.tokenId, sale.config.price);
            return abi.encode(receiver, amount, true, true);
        }
        revert P.PrivateSaleClaimUnavailable();
    }

    function claim(
        StreamPrivateSaleAccounting.State storage money,
        mapping(bytes32 => P.Sale) storage sales,
        StreamNativeInventoryState.State storage inventory,
        mapping(bytes32 => bool) storage revoked,
        StreamPrivateSaleSupport.Context memory context,
        D.Configuration memory configuration,
        bytes calldata data
    ) public returns (uint256 result) {
        bytes4 selector = bytes4(data[:4]);
        bytes32 id;
        address account;
        uint256 tokenId;
        DC.DelegationWitness memory w;
        if (selector == DC.claimInventoryNftFor.selector) {
            (id, tokenId, account, w) =
                abi.decode(data[4:], (bytes32, uint256, address, DC.DelegationWitness));
        } else if (selector == DC.claimRefundFor.selector || selector == DC.claimNftFor.selector) {
            (id, account, w) = abi.decode(data[4:], (bytes32, address, DC.DelegationWitness));
        } else {
            revert P.PrivateSaleClaimUnavailable();
        }
        if (configuration.delegateRegistry == address(0)) {
            revert D.DelegationConfigurationInvalid();
        }
        uint256 cap = IStreamGasParameterHost(address(this)).gasParameter(D.GAS_PARAMETER);
        D.claimRecipient(
            configuration, account, msg.sender, account, D.Witness(w.walletWide, w.index), cap
        );
        if (selector == DC.claimRefundFor.selector) {
            return StreamPrivateSaleAccounting.claimAccount(money, id, account, account);
        }
        P.Sale storage sale = selector == DC.claimInventoryNftFor.selector
            ? inventory.tokens[id][tokenId]
            : sales[id];
        if (sale.saleNonce == 0) revert P.PrivateSaleUnavailable(id);
        address beneficiary;
        if (sale.nftClaim == 1) beneficiary = sale.config.buyer;
        else if (sale.nftClaim == 2) beneficiary = sale.config.consignor;
        else revert P.PrivateSaleClaimUnavailable();
        if (account != beneficiary) revert P.PrivateSaleClaimUnavailable();
        uint256 nftGas = IStreamGasParameterHost(address(this))
            .gasParameter(keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT"));
        return
            StreamPrivateSaleCustody.deliverClaim(context, sale, revoked, id, account, nftGas)
                ? 1
                : 0;
    }
}
