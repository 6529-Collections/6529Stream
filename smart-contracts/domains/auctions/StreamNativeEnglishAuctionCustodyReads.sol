// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionCustodyStart.sol";
import "../revenue/StreamNativeCustodyPrimaryValidation.sol";

/// @notice Current transfer predicates deliberately do not replay the original mint phase.
library StreamNativeEnglishAuctionCustodyReads {
    function requireCurrent(
        StreamNativeEnglishAuctionRuntime.Context memory x,
        IStreamNativeEnglishAuction.Auction storage a,
        StreamNativeCustodySettlementTypes.Origin memory o
    ) public view {
        StreamSettlementAdmission.requireRegistry(
            x.base.core, x.coreHash, x.registry, x.registryHash
        );
        if (
            address(x.base.resolver).codehash != x.resolverHash
                || address(x.factory).codehash != x.factoryHash
                || address(x.assets).codehash != x.assetsHash
                || x.recorder.codehash != x.recorderHash
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        IStreamNativeCustodyPrimarySettlement(x.recorder)
            .requireCanonicalCustodyHouse(address(this));
        StreamNativeEnglishAuctionRuntime.requireRetained(x, a);
        StreamNativeEnglishAuctionCustodyStart.requireToken(x.base.core, a, o);
        StreamNativeCustodySettlementTypes.Facts memory f;
        f.auction = a;
        f.origin = o;
        StreamNativeCustodyPrimaryValidation.derive(
            StreamPrimarySettlementRights.Context(
                x.base.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
            ),
            f,
            address(this),
            x.recorder
        );
    }
}
