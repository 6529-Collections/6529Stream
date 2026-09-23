// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamPrimaryOfferDelegationManifest } from "./StreamPrimaryOfferDelegationManifest.sol";

import { StreamPreparedNativeOfferHash } from "./StreamPreparedNativeOfferHash.sol";
import { StreamPrivateSaleSupport } from "./StreamPrivateSaleSupport.sol";
import {
    StreamNativeAuctionDelegation as Delegation
} from "../auctions/StreamNativeAuctionDelegation.sol";
import {
    StreamPreparedNativeOfferTypes as Offer
} from "../../interfaces/stream/mint/StreamPreparedNativeOfferTypes.sol";
import {
    StreamPreparedNativeSettlementTypes as Prepared
} from "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import {
    IStreamPreparedNativeOfferSale
} from "../../interfaces/stream/mint/IStreamPreparedNativeOfferMint.sol";
import { IStreamMintReads } from "../../interfaces/stream/mint/IStreamMintReads.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamNativeRefundDelegatedClaims as Refund
} from "../../interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";

/// @notice Both original signatures and genuine live buyer delegation for selected and open offers.
/// @dev No kind inference. A historical seller binding supplies membership, never live sale admission.
library StreamNativePrimaryOfferSignatures {
    error InvalidPrimaryOfferSignatures();

    function validate(
        address manager,
        address house,
        Offer.GateData memory d,
        Offer.Purchase memory p,
        Prepared.Intent memory i
    ) public view {
        StreamPreparedNativeOfferHash.requirePresentation(manager, house, d, p, i);
        bytes memory raw = _read(
            house,
            abi.encodeCall(
                IStreamPreparedNativeOfferSale.primaryOfferAuthorizationBinding, (p.saleId)
            ),
            160
        );
        (uint256 collection, bytes32 phase, address seller, uint8 kind, bytes32 configHash) =
            abi.decode(raw, (uint256, bytes32, address, uint8, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(collection, phase, seller, kind, configHash))
                || collection != i.collectionId || phase != i.phaseId || configHash == 0
                || configHash != p.saleConfigHash || seller == address(0)
                || (kind != 1 && kind != 2) || d.sellerSignature.authorizer != seller
                || d.sellerSignature.kind != kind || p.authorizer == address(0)
                || (p.authorizerKind != 1 && p.authorizerKind != 2)
        ) revert InvalidPrimaryOfferSignatures();
        uint256 cap = _gas(house, keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT"));
        if (
            !StreamPrivateSaleSupport.validSignature(
                    seller, kind, i.saleAuthorizationDigest, d.sellerSignature.signature, cap
                )
                || !StreamPrivateSaleSupport.validSignature(
                    p.authorizer, p.authorizerKind, p.offerDigest, d.buyerSignature.signature, cap
                )
        ) revert InvalidPrimaryOfferSignatures();
        if (p.authorizer != p.buyer) _delegate(manager, house, p, d.buyerDelegation);
    }

    function _delegate(
        address manager,
        address house,
        Offer.Purchase memory p,
        Refund.DelegationWitness memory witness
    ) private view {
        bytes memory raw = _read(
            house, abi.encodeCall(Refund.refundDelegationConfiguration, ()), 256
        );
        Refund.DelegationConfiguration memory c = abi.decode(raw, (Refund.DelegationConfiguration));
        address registry = address(IStreamMintReads(manager).moduleRegistry());
        if (
            keccak256(raw) != keccak256(abi.encode(c))
                || c.core != address(IStreamMintReads(manager).core())
                || c.moduleRegistry != registry || c.moduleRegistryCodeHash != registry.codehash
        ) revert InvalidPrimaryOfferSignatures();
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
        StreamPrimaryOfferDelegationManifest.requireNative(config, house, p.saleId, readGas);
        Delegation.requireDelegated(
            config,
            p.buyer,
            p.authorizer,
            Delegation.Witness(witness.walletWide, witness.index),
            readGas
        );
    }

    function _gas(address house, bytes32 id) private view returns (uint256 cap) {
        cap = abi.decode(
            _read(house, abi.encodeCall(IStreamGasParameterHost.gasParameter, (id)), 32), (uint256)
        );
        if (cap == 0 || cap > type(uint64).max) revert InvalidPrimaryOfferSignatures();
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
        if (!ok || actual != expected) revert InvalidPrimaryOfferSignatures();
    }
}
