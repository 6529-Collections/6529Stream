// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamPrimarySettlementBindings
} from "../revenue/IStreamPrimarySettlementBindings.sol";
import {
    IStreamMintManager
} from "./IStreamMintManager.sol";
import {
    IStreamArtistAttribution
} from "../artist/IStreamArtistAttribution.sol";

interface IStreamUniversalAllowlistPriceHost is IStreamPrimarySettlementBindings {
    function coreCodeHash() external view returns(bytes32);
    function moduleRegistryCodeHash() external view returns(bytes32);
    function resolverCodeHash() external view returns(bytes32);
    function factoryCodeHash() external view returns(bytes32);
    function assetRegistryCodeHash() external view returns(bytes32);
    function mintManager() external view returns(IStreamMintManager);
    function mintManagerCodeHash() external view returns(bytes32);
    function primarySaleSettlement() external view returns(address);
    function settlementCodeHash() external view returns(bytes32);
    function platformSigner() external view returns(address);
    function artistRegistry() external view returns(IStreamArtistAttribution);
    function artistRegistryCodeHash() external view returns(bytes32);
    function paused() external view returns(bool);
}
