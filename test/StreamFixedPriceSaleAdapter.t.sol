// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/StreamSaleTestBase.sol";
import "../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";

contract NativeSaleReceiver is IERC721Receiver {
    StreamFixedPriceSaleAdapter public sale;
    address public wallet;
    bool public reject;
    uint256 public observedPaid;
    uint256 public observedOfficialProceeds;
    bool public reentrySucceeded;
    bytes public reentryData;

    function configure(
        StreamFixedPriceSaleAdapter sale_,
        address wallet_,
        bool reject_,
        bytes memory data
    ) external {
        sale = sale_;
        wallet = wallet_;
        reject = reject_;
        reentryData = data;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (reject) revert("receiver rejects");
        observedPaid = wallet.balance;
        observedOfficialProceeds = sale.totalNativeProceeds();
        if (reentryData.length != 0) (reentrySucceeded,) = address(sale).call(reentryData);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract NativeSale1271Signer {
    address private immutable _signer;

    constructor(address signer) {
        _signer = signer;
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        if (signature.length != 65) return 0xffffffff;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        return ecrecover(digest, v, r, s) == _signer ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// @dev The sale, manager, ledger, Core and split wallet are actual implementations.
///      Governance context and entropy callbacks are fixtures; deployment integration owns those.
contract StreamFixedPriceSaleAdapterTest is StreamSaleTestBase {
    bytes32 private constant PHASE = keccak256("native-fixed-price");
    StreamFixedPriceSaleAdapter private sale;

    function setUp() public {
        _setUpSaleFixture();
        sale = new StreamFixedPriceSaleAdapter(manager, factory, platform, artistRegistry);
        _configureSalePhase(PHASE, address(sale));
    }

    function testActualPaidMintFundsSplitAndAllowsRecipientWithdrawals() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        (uint256 tokenId, bytes32 operationRoot) = _buy(authorization);
        require(core.ownerOf(tokenId) == authorization.recipient, "actual NFT minted");
        require(core.collectionMintedEver(1) == 1 && manager.nextOperationNonce() == 1, "accounted");
        require(manager.isOperationRootUsed(operationRoot), "ledger root");
        require(sale.authorizationUsed(artist, authorization.nonce), "sale replay consumed");
        require(wallet.balance == 1 ether && address(sale).balance == 0, "funded split only");
        require(sale.nativeProceeds(profile) == 1 ether, "official sale proceeds");
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(0), protocol, payable(protocol));
        require(artist.balance == 0.9 ether && protocol.balance == 0.1 ether, "withdrawn shares");
        require(wallet.balance == 0, "no owed remainder");
    }

    function testRecipientObservesPaidAccountedMintAndCannotReenterSale() public {
        NativeSaleReceiver receiver = new NativeSaleReceiver();
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        authorization.recipient = address(receiver);
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        bytes memory data =
            abi.encodeCall(sale.buy, (authorization, tokenData, platformSig, artistSig));
        receiver.configure(sale, wallet, false, data);
        _buy(authorization);
        require(receiver.observedPaid() == 1 ether, "payment before recipient callback");
        require(receiver.observedOfficialProceeds() == 1 ether, "receipt before callback");
        require(!receiver.reentrySucceeded(), "no reentrant sale");
    }

    function testReceiverFailureRollsBackPaymentReplayLedgerAndCore() public {
        NativeSaleReceiver receiver = new NativeSaleReceiver();
        receiver.configure(sale, wallet, true, "");
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        authorization.recipient = address(receiver);
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        _assertNothingConsumed(authorization);
    }

    function testEntropyFailureRollsBackPaidMint() public {
        entropy.setBehavior(true, false);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        _assertNothingConsumed(authorization);
    }

    function testReplayIsRejectedWithoutSecondPayment() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        _buy(authorization);
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        require(wallet.balance == 1 ether && core.totalSupply() == 1, "only first sale survives");
    }

    function testArtistAndPlatformMustBothAuthorizeExactSale() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        authorization.recipient = address(0xBAD);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        authorization = _authorization();
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, platformSig);
        _assertNothingConsumed(authorization);
    }

    function testPayerValueDeadlineAndPolicyAreEnforced() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        vm.expectRevert();
        sale.buy{ value: 2 ether }(authorization, tokenData, platformSig, artistSig);
        authorization.payer = address(0xBAD);
        (platformSig, artistSig) = _sign(authorization);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        authorization = _authorization();
        authorization.mintPolicyHash = keccak256("stale");
        (platformSig, artistSig) = _sign(authorization);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        authorization = _authorization();
        (platformSig, artistSig) = _sign(authorization);
        vm.warp(uint256(authorization.deadline) + 1);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        _assertNothingConsumed(authorization);
    }

    function testArtistRevocationAndSignerRotationInvalidateOutstandingAuthorization() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        vm.prank(artist);
        sale.cancelAuthorization(authorization.nonce);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        authorization.nonce = keccak256("another");
        (platformSig, artistSig) = _sign(authorization);
        sale.setPlatformSigner(platform);
        vm.expectRevert();
        sale.buy{ value: 1 ether }(authorization, tokenData, platformSig, artistSig);
        require(wallet.balance == 0 && core.totalSupply() == 0, "no revoked sale");
    }

    function testERC1271ArtistAndPlatformSignersCanBuy() public {
        address contractArtist = address(new NativeSale1271Signer(artist));
        _bindFixtureArtist(contractArtist);
        sale = new StreamFixedPriceSaleAdapter(manager, factory, platform, artistRegistry);
        manager.setPhaseExecutor(1, PHASE, address(sale), true);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        authorization.artist = contractArtist;
        sale.setPlatformSigner(address(new NativeSale1271Signer(platform)));
        authorization.signerEpoch = sale.signerEpoch();
        _buy(authorization);
        require(core.totalSupply() == 1 && wallet.balance == 1 ether, "ERC1271 paid mint");
    }

    function testFullySignedSaleCannotAttributeAnotherArtist() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        authorization.artist = vm.addr(999);
        bytes32 digest = sale.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory platformSignature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(999, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryArtistMismatch.selector,
                1,
                artist,
                authorization.artist
            )
        );
        sale.buy{ value: authorization.price }(
            authorization, tokenData, platformSignature, abi.encodePacked(r, s, v)
        );
        _assertNothingConsumed(authorization);
    }

    function _authorization()
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization)
    {
        authorization = IStreamFixedPriceSaleAdapter.SaleAuthorization({
            collectionId: 1,
            phaseId: PHASE,
            payer: address(this),
            recipient: address(0xCAFE),
            artist: artist,
            profileId: profile,
            tokenDataHash: keccak256(tokenData),
            mintCommitment: keccak256("mint commitment"),
            mintPolicyHash: manager.phasePolicyHash(1, PHASE),
            price: 1 ether,
            nonce: keccak256("one"),
            deadline: uint64(block.timestamp + 1 days),
            signerEpoch: sale.signerEpoch()
        });
    }

    function _sign(IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization)
        private
        returns (bytes memory platformSig, bytes memory artistSig)
    {
        bytes32 digest = sale.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        platformSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(ARTIST_KEY, digest);
        artistSig = abi.encodePacked(r, s, v);
    }

    function _buy(IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization)
        private
        returns (uint256 tokenId, bytes32 operationRoot)
    {
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        return
            sale.buy{ value: authorization.price }(authorization, tokenData, platformSig, artistSig);
    }

    function _assertNothingConsumed(
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization
    ) private view {
        require(wallet.balance == 0 && sale.totalNativeProceeds() == 0, "payment rollback");
        require(
            !sale.authorizationUsed(authorization.artist, authorization.nonce),
            "sale replay rollback"
        );
        require(
            !manager.isAuthorizationUsed(
                sale.authorizationId(authorization.artist, authorization.nonce)
            ),
            "ledger rollback"
        );
        require(core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0, "Core rollback");
        require(manager.nextOperationNonce() == 0, "nonce rollback");
    }
}
