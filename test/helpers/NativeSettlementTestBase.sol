// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UniversalSettlementTestBase.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";

/// @dev Explicit artist seam; actual facade consent is separately composed by the integration suite.
contract NativeTemplateArtistMock is SaleFundingArtistMock, IStreamArtistBeneficiaryFacts {
    address public payout;
    bytes32 public designation = keccak256("native initial designation");

    constructor(address c, address p) SaleFundingArtistMock(c) {
        payout = p;
    }

    function changePayout(address p) external {
        payout = p;
        designation = keccak256(abi.encode(p));
    }

    function collectionArtistBeneficiary(uint256)
        external
        view
        returns (bytes32, address, bytes32)
    {
        require(artist != address(0), "unaccepted");
        return (keccak256("native artist identity"), payout, designation);
    }
}

contract NativeSettlementReceiver is IERC721Receiver {
    bool public reject;
    address public callback;
    bytes public data;
    bool public callbackSucceeded;
    address public observedWallet;
    uint256 public observedBalance;

    function configure(bool r, address target, bytes calldata callData, address wallet) external {
        reject = r;
        callback = target;
        data = callData;
        observedWallet = wallet;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        observedBalance = observedWallet.balance;
        if (callback != address(0)) (callbackSucceeded,) = callback.call(data);
        require(!reject, "native recipient rejected");
        return IERC721Receiver.onERC721Received.selector;
    }
}

abstract contract NativeSettlementTestBase is UniversalSettlementTestBase {
    StreamNativeFixedPriceSaleAdapter internal nativeSale;
    bytes32 internal nativeId;
    bytes32 internal templateId;
    NativeTemplateArtistMock internal templateArtist;

    function setUp() public virtual override {
        super.setUp();
        _nativeSale();
        vm.deal(payer, 10 ether);
    }

    function _nativeSale() internal {
        nativeSale = new StreamNativeFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), recorder, vm.addr(PLATFORM_KEY), artists
        );
        _register(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        nativeId = nativeSale.registerSale(
            IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                1,
                PHASE,
                1000,
                0,
                10_000,
                manager.POLICY(),
                resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash
            )
        );
    }

    function _template(address payout) internal {
        core = new UniversalCoreMock();
        templateArtist = new NativeTemplateArtistMock(address(core), payout);
        artists = templateArtist;
        core.configure(address(artists), address(registry));
        manager = new UniversalManagerMock(address(core), address(registry));
        resolver = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 900_000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            vm.addr(PLATFORM_KEY), 0, 100_000, keccak256("protocol")
        );
        templateId = resolver.createPrimaryTemplate(entries, keccak256("native template terms"));
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, templateId, 0);
        artists.accept(artist);
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _producer(true);
        _nativeSale();
    }

    function _nativeExecution(address who, address recipient, uint256 number)
        internal
        returns (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        )
    {
        StreamSaleTemplate.Selection memory selected =
            StreamNativeSettlementSupport.rights(resolver, 1);
        e.tokenData = abi.encode("native artwork", number);
        e.authorization = IStreamNativeFixedPriceSaleAdapter.SaleAuthorization(
            nativeId,
            nativeSale.saleRecord(nativeId).configHash,
            who,
            who,
            recipient,
            artist,
            keccak256(e.tokenData),
            keccak256(abi.encode("native mint", number)),
            number,
            bytes32(number),
            uint64(block.timestamp + 1 hours),
            StreamSaleTemplate.policyHash(resolver, 1, selected)
        );
        _nativeSign(e);
        c = nativeSale.previewExecution(e);
    }

    function _nativeSign(IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e) internal {
        bytes32 digest = nativeSale.authorizationDigest(e.authorization);
        e.platformSignature = _sign(PLATFORM_KEY, digest);
        e.artistSignature = _sign(ARTIST_KEY, digest);
    }

    function _buy(IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e)
        internal
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory r, uint256 id)
    {
        vm.prank(e.authorization.payer);
        return nativeSale.purchase{ value: 1000 }(e);
    }

    function _unchanged(
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        uint256 balance
    ) internal view {
        bytes32 key = recorder.settlementKey(address(nativeSale), c.executionBinding.executionId);
        require(
            !recorder.settlementConsumed(key) && recorder.totalOfficialSettled(address(0)) == 0,
            "no official credit"
        );
        require(
            !nativeSale.authorizationUsed(artist, bytes32(c.executionBinding.executionNonce))
                && nativeSale.executionIdByNonce(nativeId, c.executionBinding.executionNonce) == 0,
            "no replay consumption"
        );
        require(
            manager.nonce() == 0 && payer.balance == balance && address(recorder).balance == 0
                && address(nativeSale).balance == 0,
            "no mint or retained funds"
        );
    }
}
