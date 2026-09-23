// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./UniversalSettlementTestBase.sol";
import "../../smart-contracts/domains/mint/StreamMintSaleAllowlist.sol";
import "../../smart-contracts/domains/mint/StreamUniversalAllowlistPriceSale.sol";

/// @dev Core, Artist, Manager/counter, entropy and governance are explicit fixture boundaries.
/// Actual modules, recorder, wallets, payment intents, Permit2 and Safe are exercised.
/// Actual Manager/Ledger/Core and ERC721 receiver composition remains separately pending.
contract UniversalPriceManagerMock is UniversalManagerMock {
    address public immutable mintLedger;
    bytes32 internal _counterId;
    IStreamMintManager.MintCounterConfig internal _counter;
    IStreamMintCounterPolicy.Definition internal _definition;

    constructor(address c, address r) UniversalManagerMock(c, r) {
        mintLedger = address(this);
    }

    function setCounter(bytes32 id, IStreamMintManager.CounterKeyMode keyMode, bytes32 root)
        external
    {
        _counterId = id;
        _definition = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE, keyMode, root, keccak256("price fixture")
        );
        _counter = IStreamMintManager.MintCounterConfig(
            true,
            keyMode,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), _definition))
        );
    }

    function phaseCounterIds(uint256, bytes32) external view returns (bytes32[] memory ids) {
        ids = new bytes32[](1);
        ids[0] = _counterId;
    }

    function counterConfig(uint256, bytes32, bytes32 id)
        external
        view
        returns (IStreamMintManager.MintCounterConfig memory)
    {
        require(id == _counterId, "unknown fixture counter");
        return _counter;
    }

    function counterDefinitionForManager(address manager_, bytes32 hash)
        external
        view
        returns (bool, IStreamMintCounterPolicy.Definition memory)
    {
        require(manager_ == address(this), "definition must name Manager");
        return (hash == _counter.counterConfigHash, _definition);
    }
}


abstract contract UniversalAllowlistPriceFixture is UniversalSettlementTestBase {
    bytes32 internal constant COUNTER = keccak256("ERC20 exact price");
    bytes32 internal constant GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    UniversalPriceManagerMock internal priceManager;
    StreamUniversalAllowlistPriceSale internal priceSale;
    bytes32 internal originalSaleId;
    bytes internal proofData;

    function setUp() public override {
        super.setUp();
        originalSaleId=saleId;
        priceManager = new UniversalPriceManagerMock(address(core), address(registry));
        manager = priceManager;
        priceSale = new StreamUniversalAllowlistPriceSale(IStreamMintManager(address(manager)),recorder,vm.addr(PLATFORM_KEY),artists,_revealConfig());
        _register(address(priceSale),keccak256("FIXED_PRICE_SALE_ADAPTER"),type(IStreamERC20SaleExecution).interfaceId);
        _bind(payer,IStreamMintManager.CounterKeyMode.PAYER,true,375);
        _registerPrice(false);
    }
    function _revealConfig() internal pure returns (IStreamGasParameterHost.GasParameterConfig memory) {
        return IStreamGasParameterHost.GasParameterConfig("REVEAL_ATTEMPT_GAS_LIMIT",1000000,100000,2);
    }
    function _config() internal view returns (IStreamUniversalFixedPriceSaleAdapter.SaleConfig memory) {
        return IStreamUniversalFixedPriceSaleAdapter.SaleConfig(address(payment),1,PHASE,address(token),1000,0,10000,manager.POLICY(),_primaryPolicy());
    }
    function _registerPrice(bool free) internal {
        saleId=priceSale.registerAllowlistSale(_config(),IStreamUniversalAllowlistPriceSale.AllowlistPricePolicy(COUNTER,free));
    }
    function _bind(address subject,IStreamMintManager.CounterKeyMode mode,bool has,uint256 price) internal {
        IStreamMintCounterPolicy.AllowlistProof memory p=IStreamMintCounterPolicy.AllowlistProof(7,has,price,new bytes32[](0));
        bytes32 root=keccak256(bytes.concat(keccak256(abi.encode(keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),block.chainid,address(manager),uint256(1),PHASE,COUNTER,subject,p.maxCount,p.hasPriceOverride,p.priceOverride))));
        priceManager.setCounter(COUNTER,mode,root);
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups=new IStreamMintCounterPolicy.AllowlistProof[][](1);
        groups[0]=new IStreamMintCounterPolicy.AllowlistProof[](1);groups[0][0]=p;proofData=abi.encode(groups);
    }
    function _e(address who,address executor,address recipient,uint256 n) internal returns(IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e) {
        e.tokenData=abi.encode("ERC20 same leaf",n);
        e.authorization=IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization(saleId,priceSale.saleRecord(saleId).configHash,who,executor,recipient,artist,keccak256(e.tokenData),keccak256(abi.encode("mint",n)),n,bytes32(n),uint64(block.timestamp+1 hours));
        bytes32 d=priceSale.authorizationDigest(e.authorization);e.platformSignature=_sign(PLATFORM_KEY,d);e.artistSignature=_sign(ARTIST_KEY,d);
    }
    function _pay(IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e) internal returns(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) {
        bytes memory data;(c,data)=priceSale.previewAllowlistExecution(e,proofData);
        vm.prank(e.authorization.executor);payment.settleERC20PrimarySaleByPayer(c,data);
    }
    function _unused() internal view {
        require(token.balanceOf(payer)==10000 && token.balanceOf(wallet)==0 && recorder.totalOfficialSettled(address(token))==0,"payment rollback");
        require(!priceSale.authorizationUsed(artist,bytes32(uint256(1))) && priceSale.executionIdByNonce(saleId,1)==0 && manager.nonce()==0,"replay rollback");
    }
}
