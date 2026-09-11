// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/StreamCurrentAssetPolicy.sol";
import "../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../mocks/MockStreamPaymentToken.sol";

contract CurrentERC20Receiver is IERC721Receiver {
    StreamERC20FixedPriceSaleAdapter public sale;
    MockStreamPaymentToken public token;
    address public wallet;
    bytes public reentryData;
    bool public reject;
    bool public reentered;
    uint256 public observedPayment;
    uint256 public observedProceeds;

    function configure(
        StreamERC20FixedPriceSaleAdapter sale_,
        MockStreamPaymentToken token_,
        address wallet_,
        bytes calldata data,
        bool reject_
    ) external {
        sale = sale_;
        token = token_;
        wallet = wallet_;
        reentryData = data;
        reject = reject_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(!reject, "recipient rejects");
        observedPayment = token.rawBalance(wallet);
        observedProceeds = sale.totalProceeds(address(token));
        (reentered,) = address(sale).call(reentryData);
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice ERC-20 payment reaches the actual sealed Executor/Core/manager/entropy/split topology.
/// @dev Only the ERC-20 and external randomness service are controllable test assets/services.
contract StreamCurrentStackERC20Test is StreamCurrentStackFixture {
    uint256 private constant PAYER_KEY = 0xE2C20;
    bytes32 private constant ERC20_PHASE = keccak256("current ERC20 phase");
    bytes32 private constant REVENUE = PRIMARY_REVENUE_CLASS;
    StreamERC20FixedPriceSaleAdapter private erc20Sale;
    MockStreamPaymentToken private paymentToken;
    address private payer;
    bytes32 private erc20SaleId;

    function setUp() public {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        (bool ok, bytes memory state) =
            address(executor).staticcall(abi.encodeCall(executor.systemManifestBootstrapState, ()));
        (bool bound, bool sealed_) = abi.decode(state, (bool, bool));
        require(ok && executor.genesisInitialized() && bound && sealed_, "real sealed genesis");
    }

    function _deployAdditionalProducts() internal override {
        payer = vm.addr(PAYER_KEY);
        paymentToken = new MockStreamPaymentToken();
        paymentToken.mint(payer, 10_000);
        erc20Sale = new StreamERC20FixedPriceSaleAdapter(
            manager,
            primaryResolver,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists))
        );
        _assertDeployableProductionInstance(address(erc20Sale));
    }

    function _configureAdditionalProducts() internal override {
        GovernanceActionRequest memory activation = StreamCurrentAssetPolicy.activationRequest(
            assetPolicy, address(paymentToken), keccak256("standard test ERC20"), DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (activation))
        );
        vm.warp(activation.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), activation.callData);
        _configureMintPhase(ERC20_PHASE, address(erc20Sale));
        (bytes32 policy,,) = erc20Sale.primaryPolicy(1, REVENUE);
        erc20SaleId = erc20Sale.registerSale(
            IStreamERC20FixedPriceSaleAdapter.SaleConfig(
                1,
                ERC20_PHASE,
                address(paymentToken),
                REVENUE,
                100,
                manager.phasePolicyHash(1, ERC20_PHASE),
                policy,
                0,
                uint64(block.timestamp + 30 days)
            )
        );
        vm.prank(payer);
        paymentToken.approve(address(erc20Sale), 10_000);
        erc20Sale.transferOwnership(address(executor));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](6);
        rows[0] = _policy(address(erc20Sale), erc20Sale.raiseSignatureGasLimit.selector);
        rows[1] = _policy(address(erc20Sale), erc20Sale.registerSale.selector);
        rows[2] = _policy(address(erc20Sale), erc20Sale.cancelSale.selector);
        rows[3] = _policy(address(erc20Sale), erc20Sale.setPaused.selector);
        rows[4] = _policy(address(erc20Sale), erc20Sale.setPlatformSigner.selector);
        rows[5] =
            _policy(address(primaryResolver), primaryResolver.setPrimaryProfileAssignment.selector);
    }

    function testRelayedERC20MintRealEntropyMetadataAndSplitWithdrawals() public {
        (uint256 tokenId, bytes32 root) = _buy(_authorization(1, BUYER), true);
        require(
            core.ownerOf(tokenId) == BUYER && core.totalSupply() == 1
                && core.collectionMintedEver(1) == 1,
            "real Core NFT"
        );
        require(
            manager.isOperationRootUsed(root) && manager.nextOperationNonce() == 1,
            "real accounting"
        );
        require(
            erc20Sale.isPaymentIntentNonceUsed(payer, bytes32(uint256(1))), "payer consent consumed"
        );
        require(
            paymentToken.rawBalance(wallet) == 100
                && paymentToken.rawBalance(address(erc20Sale)) == 0,
            "exact ERC20 settlement"
        );
        require(
            core.coordinatorAtMint(tokenId) == address(entropy)
                && entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.REGISTERED,
            "actual entropy registration"
        );
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("ERC20 paid mint randomness"));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(tokenId);
        require(
            finalized && seed != bytes32(0) && bytes(core.tokenURI(tokenId)).length > 0,
            "actual finalized metadata"
        );
        IStreamSplitWallet(wallet).release(address(paymentToken), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(paymentToken), PROTOCOL, payable(PROTOCOL));
        require(
            paymentToken.rawBalance(artist) == 90 && paymentToken.rawBalance(PROTOCOL) == 10,
            "real token withdrawals"
        );
    }

    function testDirectPayerAndRepeatedPurchasesShareSaleWithoutReplayCollision() public {
        _buy(_authorization(1, BUYER), false);
        _buy(_authorization(2, SECOND_OWNER), true);
        require(
            core.totalSupply() == 2 && manager.nextOperationNonce() == 2
                && paymentToken.rawBalance(wallet) == 200,
            "two distinct purchases"
        );
        require(
            erc20Sale.nextSaleNonce() == 2
                && !erc20Sale.isPaymentIntentNonceUsed(payer, bytes32(uint256(1)))
                && erc20Sale.isPaymentIntentNonceUsed(payer, bytes32(uint256(2))),
            "caller exemption distinct from relayed nonce"
        );
    }

    function testRecipientSeesPaidStateAndCannotReenterAdapter() public {
        CurrentERC20Receiver receiver = new CurrentERC20Receiver();
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory authorization =
            _authorization(1, address(receiver));
        receiver.configure(erc20Sale, paymentToken, wallet, _buyData(authorization, true), false);
        _buy(authorization, true);
        require(
            receiver.observedPayment() == 100 && receiver.observedProceeds() == 100
                && !receiver.reentered(),
            "paid before recipient callback"
        );
    }

    function testRejectedRecipientRollsBackTokenConsentCoreLedgerAndEntropy() public {
        CurrentERC20Receiver receiver = new CurrentERC20Receiver();
        receiver.configure(erc20Sale, paymentToken, wallet, "", true);
        bytes memory data = _buyData(_authorization(1, address(receiver)), true);
        (bool ok, bytes memory reason) = address(erc20Sale).call(data);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "recipient rejects")),
            "wrong recipient rejection"
        );
        _assertUntouched();
    }

    function testSecondTransferFailureLeavesEveryCurrentSatelliteUntouched() public {
        paymentToken.configure(3, 2);
        bytes memory data = _buyData(_authorization(1, BUYER), true);
        (bool ok,) = address(erc20Sale).call(data);
        require(!ok, "taxed deposit accepted");
        _assertUntouched();
    }

    function testTokenCallbackIntoAnotherSaleCannotChangeCommittedMintIdentity() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory nested =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(paymentToken),
                recipient: BUYER,
                artist: artist,
                profileId: profile,
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("nested native mint"),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0,
                nonce: keccak256("nested authorization"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(nested);
        paymentToken.configureCallback(
            address(sale),
            abi.encodeCall(
                sale.buy,
                (nested, TOKEN_DATA, _sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest))
            ),
            1
        );
        bytes memory data = _buyData(_authorization(1, BUYER), true);
        (bool ok, bytes memory result) = address(erc20Sale).call(data);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamERC20FixedPriceSaleAdapter.SaleMintResultInvalid.selector
                        )
                    ),
            "changed manager nonce accepted"
        );
        _assertUntouched();
        require(!sale.authorizationUsed(artist, nested.nonce), "nested sale also rolled back");
    }

    function testSignatureGasRaiseUsesRealPostSealGovernanceDelay() public {
        bytes memory data = abi.encodeCall(erc20Sale.raiseSignatureGasLimit, (500_000));
        vm.expectRevert();
        erc20Sale.raiseSignatureGasLimit(500_000);
        GovernanceActionRequest memory request = GovernanceActionRequest({
            actionClass: 1,
            target: address(erc20Sale),
            value: 0,
            selector: erc20Sale.raiseSignatureGasLimit.selector,
            callData: data,
            scopeHash: keccak256("ERC20 signature gas"),
            oldValueHash: keccak256(abi.encode(uint256(400_000))),
            newValueHash: keccak256(abi.encode(uint256(500_000))),
            notBefore: uint64(block.timestamp + 48 hours),
            expiresAfter: uint64(block.timestamp + 9 days),
            reasonHash: keccak256("heavier supported verifier"),
            reasonURI: "urn:6529stream:test:erc20-gas",
            manifestHash: DEPLOYMENT_HASH
        });
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        bytes32 actionId = abi.decode(result, (bytes32));
        vm.expectRevert();
        executor.executeGovernanceAction(actionId, data);
        require(erc20Sale.signatureGasLimit() == 400_000, "not raised early");
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(actionId, data);
        require(
            erc20Sale.signatureGasLimit() == 500_000 && erc20Sale.owner() == address(executor),
            "governed raise"
        );
    }

    function _authorization(uint256 nonce, address recipient)
        private
        view
        returns (IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory)
    {
        return IStreamERC20FixedPriceSaleAdapter.SaleAuthorization(
            erc20SaleId,
            erc20Sale.saleRecord(erc20SaleId).configHash,
            payer,
            recipient,
            artist,
            keccak256(TOKEN_DATA),
            keccak256(abi.encode("ERC20 token", nonce)),
            bytes32(nonce),
            uint64(block.timestamp + 1 days),
            erc20Sale.signerEpoch()
        );
    }

    function _buy(
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory authorization,
        bool relayed
    ) private returns (uint256 tokenId, bytes32 operationRoot) {
        bytes memory data = _buyData(authorization, relayed);
        if (!relayed) vm.prank(payer);
        (bool ok, bytes memory result) = address(erc20Sale).call(data);
        if (!ok) assembly { revert(add(result, 32), mload(result)) }
        return abi.decode(result, (uint256, bytes32));
    }

    function _buyData(
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory authorization,
        bool relayed
    ) private returns (bytes memory) {
        bytes32 digest = erc20Sale.authorizationDigest(authorization);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent =
            IStreamPaymentIntentVerifier.PaymentIntent(
                payer,
                address(paymentToken),
                100,
                erc20SaleId,
                erc20Sale.saleRecord(erc20SaleId).config.expectedPrimaryPolicyHash,
                authorization.nonce,
                authorization.deadline
            );
        bytes memory payerSignature =
            relayed ? _sign(PAYER_KEY, erc20Sale.paymentIntentDigest(intent)) : bytes("");
        return abi.encodeCall(
            erc20Sale.buy,
            (
                authorization,
                TOKEN_DATA,
                _sign(PLATFORM_KEY, digest),
                _sign(ARTIST_KEY, digest),
                intent,
                payerSignature
            )
        );
    }

    function _assertUntouched() private view {
        require(
            core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
                && manager.nextOperationNonce() == 0,
            "Core and ledger rollback"
        );
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE, "entropy rollback");
        require(
            paymentToken.rawBalance(wallet) == 0 && paymentToken.rawBalance(payer) == 10_000
                && paymentToken.rawBalance(address(erc20Sale)) == 0
                && paymentToken.transferCalls() == 0,
            "token rollback"
        );
        require(
            erc20Sale.totalProceeds(address(paymentToken)) == 0
                && !erc20Sale.isPaymentIntentNonceUsed(payer, bytes32(uint256(1)))
                && !erc20Sale.authorizationUsed(artist, bytes32(uint256(1))),
            "consent and proceeds rollback"
        );
    }

    function _policy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
