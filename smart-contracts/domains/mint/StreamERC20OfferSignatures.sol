// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamPrimaryOfferDelegationManifest } from "./StreamPrimaryOfferDelegationManifest.sol";

import { StreamERC20OfferHash } from "./StreamERC20OfferHash.sol";
import { StreamPrivateSaleSupport } from "./StreamPrivateSaleSupport.sol";
import {
    StreamNativeAuctionDelegation as Delegation
} from "../auctions/StreamNativeAuctionDelegation.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { IStreamMintReads } from "../../interfaces/stream/mint/IStreamMintReads.sol";
import { IStreamERC20OfferSale } from "../../interfaces/stream/mint/IStreamERC20OfferMint.sol";
import {
    StreamERC20OfferMintTypes as Offer
} from "../../interfaces/stream/mint/StreamERC20OfferMintTypes.sol";
import {
    IStreamNativeRefundDelegatedClaims as Refund
} from "../../interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Exact original signatures and live NFTDelegation for an ERC20 offer mint.
/// @dev Signer kinds are explicit. Historical seller membership is retained authority evidence,
/// while delegation always uses the current pinned provider configuration and house manifest.
library StreamERC20OfferSignatures {
    error InvalidERC20OfferSignatures();

    function validate(
        address manager,
        address house,
        IStreamMintManager.MintBatch calldata batch,
        Offer.GateData memory d
    ) public view returns (bytes32 sellerDigest, bytes32 offerDigest) {
        (sellerDigest, offerDigest) = StreamERC20OfferHash.validate(manager, house, batch, d);
        bytes memory raw = _read(
            house,
            abi.encodeCall(
                IStreamERC20OfferSale.primaryOfferAuthorizationBinding, (d.authorization.saleId)
            ),
            160
        );
        (uint256 collection, bytes32 phase, address seller, uint8 sellerKind, bytes32 configHash) =
            abi.decode(raw, (uint256, bytes32, address, uint8, bytes32));
        if (
            keccak256(raw)
                    != keccak256(abi.encode(collection, phase, seller, sellerKind, configHash))
                || collection != d.authorization.collectionId || phase != d.authorization.phaseId
                || seller == address(0) || (sellerKind != 1 && sellerKind != 2) || configHash == 0
                || d.sellerSignature.authorizer != seller || d.sellerSignature.kind != sellerKind
        ) revert InvalidERC20OfferSignatures();
        uint256 signatureGas = _gas(house, keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT"));
        if (
            !StreamPrivateSaleSupport.validSignature(
                    seller, sellerKind, sellerDigest, d.sellerSignature.signature, signatureGas
                )
                || !StreamPrivateSaleSupport.validSignature(
                    d.buyerSignature.authorizer,
                    d.buyerSignature.kind,
                    offerDigest,
                    d.buyerSignature.signature,
                    signatureGas
                )
        ) revert InvalidERC20OfferSignatures();
        if (d.buyerSignature.authorizer != d.offer.buyer || d.executor != d.offer.buyer) {
            _delegates(manager, house, d);
        }
    }

    function _delegates(address manager, address house, Offer.GateData memory d) private view {
        bytes memory raw = _read(
            house, abi.encodeCall(IStreamERC20OfferSale.offerDelegationConfiguration, ()), 256
        );
        Refund.DelegationConfiguration memory c = abi.decode(raw, (Refund.DelegationConfiguration));
        address core = address(IStreamMintReads(manager).core());
        address moduleRegistry = address(IStreamMintReads(manager).moduleRegistry());
        if (
            keccak256(raw) != keccak256(abi.encode(c)) || c.core != core
                || c.moduleRegistry != moduleRegistry
                || c.moduleRegistryCodeHash != moduleRegistry.codehash
        ) revert InvalidERC20OfferSignatures();
        Delegation.Configuration memory config = Delegation.Configuration(
            c.chainId,
            c.core,
            c.registry,
            c.registryCodeHash,
            c.usecase,
            c.baseManifestHash,
            c.moduleRegistry,
            c.moduleRegistryCodeHash
        );
        Delegation.validateConfiguration(config);
        uint256 readGas = _gas(house, Delegation.GAS_PARAMETER);
        StreamPrimaryOfferDelegationManifest.requireERC20(
            config, house, d.authorization.saleId, readGas
        );
        if (d.buyerSignature.authorizer != d.offer.buyer) {
            Delegation.requireDelegated(
                config,
                d.offer.buyer,
                d.buyerSignature.authorizer,
                Delegation.Witness(d.buyerDelegation.walletWide, d.buyerDelegation.index),
                readGas
            );
        }
        if (d.executor != d.offer.buyer) {
            Delegation.requireDelegated(
                config,
                d.offer.buyer,
                d.executor,
                Delegation.Witness(d.executorDelegation.walletWide, d.executorDelegation.index),
                readGas
            );
        }
    }

    function _gas(address house, bytes32 id) private view returns (uint256 cap) {
        cap = abi.decode(
            _read(house, abi.encodeCall(IStreamGasParameterHost.gasParameter, (id)), 32), (uint256)
        );
        if (cap == 0 || cap > type(uint64).max) revert InvalidERC20OfferSignatures();
    }

    function _read(address target, bytes memory input, uint256 expected)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(expected);
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), add(raw, 32), expected)
            actual := returndatasize()
        }
        if (!ok || actual != expected) revert InvalidERC20OfferSignatures();
    }
}
