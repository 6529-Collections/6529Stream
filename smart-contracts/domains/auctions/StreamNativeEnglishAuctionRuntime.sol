// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionState.sol";
import "./StreamNativeEnglishAuctionSupport.sol";
import "./StreamNativeAuctionDelegation.sol";
import "../revenue/StreamPreparedNativeSettlementValidation.sol";
import "../revenue/StreamSettlementContext.sol";
import "../mint/StreamPlatformSaleTemplate.sol";
import {
    IStreamPlatformNativeRightsAuction
} from "../../interfaces/stream/auctions/IStreamPlatformNativeRightsAuction.sol";

/// @notice Immutable house context and original-phase current reads for fixed execution libraries.
library StreamNativeEnglishAuctionRuntime {
    bytes32 internal constant SIGNATURE_GAS = keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    bytes32 internal constant ARTIST_GAS =
        keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
    bytes32 internal constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    bytes32 internal constant DELIVERY_GAS =
        keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT");

    struct Context {
        StreamRefundWindowSupport.Context base;
        address registry;
        bytes32 registryHash;
        bytes32 coreHash;
        bytes32 resolverHash;
        IStreamSplitFactory factory;
        bytes32 factoryHash;
        IStreamAssetPolicyRegistry assets;
        bytes32 assetsHash;
        bytes32 managerHash;
        address recorder;
        bytes32 recorderHash;
        StreamNativeAuctionDelegation.Configuration delegation;
    }

    /// @dev Same order/physical slots as the original five private active fields.
    struct Active {
        bytes32 auction;
        bytes32 intentHash;
        StreamPreparedNativeSettlementTypes.Intent intent;
        uint256 token;
        bool callbackConsumed;
    }

    function gasParameter(bytes32 id) internal view returns (uint256) {
        return IStreamGasParameterHost(address(this)).gasParameter(id);
    }

    function support(Context memory x)
        internal
        view
        returns (StreamRefundWindowSupport.Context memory)
    {
        return StreamRefundWindowSupport.Context(
            x.base.core,
            x.base.manager,
            x.base.resolver,
            x.base.platform,
            x.base.artists,
            x.base.artistHash,
            x.base.entropy,
            x.base.entropyHash,
            gasParameter(SIGNATURE_GAS),
            gasParameter(ARTIST_GAS)
        );
    }

    function requireNativeContext(Context memory x) internal view {
        StreamSettlementAdmission.requireRegistry(
            x.base.core, x.coreHash, x.registry, x.registryHash
        );
        if (address(x.base.resolver).codehash != x.resolverHash) {
            revert StreamSettlementContext.InvalidSettlementContext(address(x.base.resolver));
        }
        if (address(x.factory).codehash != x.factoryHash) {
            revert StreamSettlementContext.InvalidSettlementContext(address(x.factory));
        }
        if (address(x.assets).codehash != x.assetsHash) {
            revert StreamSettlementContext.InvalidSettlementContext(address(x.assets));
        }
        if (
            address(x.base.manager).codehash != x.managerHash
                || x.recorder.codehash != x.recorderHash
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        StreamPreparedNativeSettlementValidation.requireBindings(
            x.base.core,
            x.registry,
            address(x.base.manager),
            address(this),
            x.recorder,
            x.recorderHash
        );
    }

    function requireRetained(Context memory x, IStreamNativeEnglishAuction.Auction storage a)
        internal
        view
    {
        StreamPreparedNativeSettlementAdmission.requireAdmission(
            x.registry, address(this), a.saleId
        );
        if (a.artistId == 0) {
            bytes32 declaration = IStreamPlatformNativeRightsAuction(address(this))
                .platformAuctionDeclaration(a.saleId);
            if (declaration != 0) {
                if (
                    a.bindingGeneration != 0 || a.bindingHash != 0
                        || StreamPlatformSaleTemplate.declaration(
                                x.base.resolver, a.config.collectionId
                            ) != declaration
                ) {
                    revert IStreamNativeEnglishAuction.InvalidNativeAuction();
                }
                return;
            }
        }
        StreamRefundWindowSupport.requireSaleConsent(
            support(x), a.config.collectionId, a.saleId, a.configHash
        );
        StreamRefundWindowSupport.requireArtistAssociation(
            support(x), a.config.collectionId, a.artistId, a.bindingGeneration, a.bindingHash
        );
    }

    function admitDelivery(uint256 cap) internal view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 60000) {
            revert IStreamNativeEnglishAuction.NativeAuctionDeliveryGas(available, cap);
        }
    }
}
