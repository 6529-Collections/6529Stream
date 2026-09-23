// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../helpers/StreamCurrentAssetPolicy.sol";
import "../mocks/MockStreamPaymentToken.sol";
import "../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/metadata/StreamConservationFloor.sol";
import "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import "../../smart-contracts/interfaces/stream/core/IStreamCoreConservationFloor.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamConservationTier.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamConservationFloor.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamDirectPrimarySaleReceipt.sol";
import {
    StreamDirectPrimarySaleTypes as Direct
} from "../../smart-contracts/interfaces/stream/revenue/StreamDirectPrimarySaleTypes.sol";

interface CurrentDirectFaultVm {
    function mockCallRevert(address target, bytes calldata data, bytes calldata reason) external;
    function mockCallRevert(
        address target,
        uint256 value,
        bytes calldata data,
        bytes calldata reason
    ) external;
    function clearMockedCalls() external;
    function expectCall(address target, bytes calldata data) external;
}

/// @dev Exercises actual Core callbacks; the mint marker must keep rejecting burn during mint.
contract CurrentDirectLifecycleReceiver is IERC721Receiver {
    StreamCore private immutable _core;
    address private immutable _onward;
    bool private immutable _burnOnDelivery;
    uint256 public receivedToken;
    bool public mintBurnRejected;

    constructor(StreamCore core_, address onward_, bool burnOnDelivery_) {
        _core = core_;
        _onward = onward_;
        _burnOnDelivery = burnOnDelivery_;
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        require(msg.sender == address(_core), "actual Core callback");
        receivedToken = tokenId;
        if (_burnOnDelivery) {
            require(from != address(0), "auction transfer follows completed mint");
            _core.burn(tokenId);
        } else {
            require(from == address(0), "original mint callback");
            try _core.burn(tokenId) {
                revert("mint callback burn unexpectedly allowed");
            } catch (bytes memory reason) {
                require(
                    keccak256(reason)
                        == keccak256(
                            abi.encodeWithSelector(StreamCore.MintExecutionInProgress.selector)
                        ),
                    "exact active mint guard"
                );
                mintBurnRejected = true;
            }
            _core.transferFrom(address(this), _onward, tokenId);
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Original native/ERC20 buy APIs join the actual current mint graph and DIRECT floor.
/// @dev Real Core, Executor, Registry, Manager/Ledger, Artist, Metadata, split/escrow and Safe1.4.1.
/// The ERC20 and external randomness service are test doubles. Named failure cases inject only
/// the exact late floor call (and native wallet receive); no successful floor proof is mocked.
/// WAIVED is explicitly declared by a genuinely granted Metadata administrator before mint.
/// Manager replay and returned operation vectors plus Core identity do not imply a Core op receipt.
contract StreamCurrentDirectConservationTest is StreamCurrentSafeGovernanceFixture {
    uint256 private constant PAYER_KEY = 0xD1EC7;
    uint256 private constant NATIVE_PRICE = 0.1 ether;
    uint256 private constant TOKEN_PRICE = 100;
    bytes32 private constant ERC20_PHASE = keccak256("current DIRECT ERC20 phase");
    bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");
    bytes32 private constant NONCE = keccak256("current DIRECT original artist nonce");
    bytes32 private constant FAULT = keccak256("transient late DIRECT floor failure");

    StreamERC20FixedPriceSaleAdapter private erc20Sale;
    MockStreamPaymentToken private paymentToken;
    IStreamConservationFloor private floor;
    bytes32 private erc20SaleId;
    address private payer;
    SafeComponents private safeComponents;
    uint256[] private payerKeys;

    function setUp() public {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        safeComponents = deploySafeComponents("1.4.1");
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0xD1EC701;
        owners[1] = 0xD1EC702;
        owners[2] = 0xD1EC703;
        payerKeys.push(owners[0]);
        payerKeys.push(owners[1]);
        OfficialSafe governor =
            createOfficialSafe(safeComponents, safeOwnerAddresses(owners), 2, 701);
        _installGovernorSafe(governor, payerKeys);
        _registerDirectProducts();
        _declareWaivedThroughMetadata();
    }

    function _deployAdditionalProducts() internal override {
        payer = vm.addr(PAYER_KEY);
        vm.deal(payer, 1 ether);
        paymentToken = new MockStreamPaymentToken();
        paymentToken.mint(payer, 1000);
        erc20Sale = new StreamERC20FixedPriceSaleAdapter(
            manager,
            primaryResolver,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists)),
            revenueEscrow
        );
        // The separately compiled production artifact is the actual immutable receipt owner.
        floor = IStreamConservationFloor(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamConservationFloor.sol:StreamConservationFloor",
                abi.encode(
                    address(core),
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_READ_GAS", 300000, 300000, 2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_PRODUCER_GAS", 1000000, 1000000, 2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_CALL_GAS", 6000000, 6000000, 2
                    )
                )
            )
        );
        _assertDeployableProductionInstance(address(erc20Sale));
        _assertDeployableProductionInstance(address(floor));
    }

    function _additionalEscrowProducers() internal view override returns (address[] memory rows) {
        rows = new address[](1);
        rows[0] = address(erc20Sale);
    }

    function _configureAdditionalProducts() internal override {
        GovernanceActionRequest memory activation = StreamCurrentAssetPolicy.activationRequest(
            assetPolicy,
            address(paymentToken),
            keccak256("current DIRECT payment asset"),
            DEPLOYMENT_HASH
        );
        bytes memory scheduled = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (activation))
        );
        vm.warp(activation.notBefore);
        executor.executeGovernanceAction(abi.decode(scheduled, (bytes32)), activation.callData);
        _configureMintPhase(ERC20_PHASE, address(erc20Sale));
        (bytes32 primaryPolicy,,) = erc20Sale.primaryPolicy(1, PRIMARY_REVENUE_CLASS);
        erc20SaleId = erc20Sale.registerSale(
            IStreamERC20FixedPriceSaleAdapter.SaleConfig(
                1,
                ERC20_PHASE,
                address(paymentToken),
                PRIMARY_REVENUE_CLASS,
                TOKEN_PRICE,
                manager.phasePolicyHash(1, ERC20_PHASE),
                primaryPolicy,
                0,
                uint64(block.timestamp + 90 days)
            )
        );
        vm.prank(payer);
        paymentToken.approve(address(erc20Sale), 1000);
        erc20Sale.transferOwnership(address(executor));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = _directPolicy(
            address(core), IStreamCoreConservationFloor.bindConservationFloor.selector
        );
        rows[1] =
            _directPolicy(address(assemblyMetadata), assemblyMetadata.setFamilyWriter.selector);
    }

    function _directPolicy(address target, bytes4 selector)
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
            0
        );
    }

    function _registerDirectProducts() private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](3);
        records[0] = _directRegistration(address(sale));
        records[1] = _directRegistration(address(erc20Sale));
        records[2] = _directRegistration(address(auction));
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 id, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceBatch, (id, calls, data))
        );
        for (uint256 i; i < records.length; ++i) {
            require(
                registry.isModuleEligible(
                    records[i].module,
                    Direct.MODULE_TYPE,
                    type(IStreamDirectPrimarySaleReceipt).interfaceId
                ),
                "actual canonical DIRECT registration"
            );
        }
    }

    function _directRegistration(address adapter)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return StreamModuleRegistration(
            adapter,
            Direct.MODULE_TYPE,
            Direct.MODULE_VERSION,
            type(IStreamDirectPrimarySaleReceipt).interfaceId,
            500000,
            adapter.codehash,
            DEPLOYMENT_HASH,
            keccak256(abi.encode("current DIRECT module", adapter)),
            "urn:stream:test:current-direct"
        );
    }

    function _declareWaivedThroughMetadata() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = assemblyMetadata.familyWriterTransition(
            1, StreamRecordFamilies.CONSERVATION, 7, address(governorSafe), true
        );
        bytes memory data = abi.encodeCall(
            assemblyMetadata.setFamilyWriter,
            (1, StreamRecordFamilies.CONSERVATION, uint8(7), address(governorSafe), true)
        );
        _govern(_governanceRequest(1, address(assemblyMetadata), data, scope, oldHash, newHash));
        require(
            executeSafe(
                governorSafe,
                governorKeys,
                address(assemblyMetadata),
                0,
                abi.encodeCall(IStreamConservationTier.declareConservationTier, (1, WAIVED)),
                0
            ),
            "actual Metadata administrator declares waiver"
        );
        (bytes32 declared, bytes32 effective) = assemblyMetadata.conservationTier(1);
        require(
            declared == WAIVED && effective == WAIVED && core.collectionMintedEver(1) == 0,
            "premint explicit waiver"
        );
    }

    function _bindFloor() private {
        IStreamCoreConservationFloor anchor = IStreamCoreConservationFloor(address(core));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            anchor.conservationFloorTransition(address(floor));
        _govern(
            _governanceRequest(
                1,
                address(core),
                abi.encodeCall(anchor.bindConservationFloor, (address(floor))),
                scope,
                oldHash,
                newHash
            )
        );
        (address actual, bytes32 pin) = anchor.conservationFloor();
        require(
            actual == address(floor) && pin == address(floor).codehash,
            "governed original floor anchor"
        );
        require(
            floor.sourceCount() == 0 && floor.firstSale(1).receiptHash == 0,
            "no prepared or fabricated source evidence"
        );
    }

    function testOriginalNativeBuyRecordsExactDirectReceiptAndWaivedFloorWithoutPreparation()
        public
    {
        _bindFloor();
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            _nativeAuthorization(payer, BUYER, NATIVE_PRICE);
        (bytes memory data, bytes32 id, Direct.Receipt memory expected) = _nativeData(a, false);
        _assertNoReceipt(address(sale), id);
        vm.recordLogs();
        vm.prank(payer);
        (uint256 tokenId, bytes32 root) = _callBuy(address(sale), NATIVE_PRICE, data);
        _assertReceipt(address(sale), id, Direct.NATIVE_FIXED_PRICE, expected, vm.getRecordedLogs());
        require(
            tokenId == 1 && root == expected.operationRoot && wallet.balance == NATIVE_PRICE,
            "native exact paid mint"
        );
        require(
            sale.totalNativeProceeds() == NATIVE_PRICE && payer.balance == 1 ether - NATIVE_PRICE,
            "native payer and proceeds"
        );
    }

    function testOriginalRelayedERC20BuyRecordsExactDirectReceiptAndWaivedFloorWithoutPreparation()
        public
    {
        _bindFloor();
        (bytes memory data, bytes32 id, Direct.Receipt memory expected) =
            _erc20Data(payer, BUYER, false);
        _assertNoReceipt(address(erc20Sale), id);
        vm.recordLogs();
        (uint256 tokenId, bytes32 root) = _callBuy(address(erc20Sale), 0, data);
        _assertReceipt(
            address(erc20Sale), id, Direct.ERC20_FIXED_PRICE, expected, vm.getRecordedLogs()
        );
        require(
            tokenId == 1 && root == expected.operationRoot
                && paymentToken.rawBalance(wallet) == TOKEN_PRICE,
            "ERC20 exact paid mint"
        );
        require(
            paymentToken.rawBalance(payer) == 1000 - TOKEN_PRICE
                && erc20Sale.isPaymentIntentNonceUsed(payer, NONCE),
            "actual relayed payer consent"
        );
    }

    function testNativeSafeLateFloorFailureRollsBackEscrowAndIdenticalBuyRetries() public {
        _bindFloor();
        OfficialSafe buyerSafe = _newSafe(702);
        vm.deal(address(buyerSafe), 1 ether);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            _nativeAuthorization(address(buyerSafe), address(buyerSafe), NATIVE_PRICE);
        (bytes memory data, bytes32 id, Direct.Receipt memory expected) = _nativeData(a, true);
        _walletReceiveFault();
        _floorFault(id);
        uint256 nonceBefore = buyerSafe.nonce();
        _safeFailure(buyerSafe, address(sale), NATIVE_PRICE, data);
        require(
            buyerSafe.nonce() == nonceBefore + 1 && address(buyerSafe).balance == 1 ether,
            "Safe failure nonce distinct from reverted payment"
        );
        _assertMintRollback(address(sale), id, expected.operationRoot);
        require(
            !sale.authorizationUsed(artist, NONCE) && sale.totalNativeProceeds() == 0
                && wallet.balance == 0,
            "native artist nonce and proceeds rollback"
        );
        _assertEmptyEscrow(address(0));
        CurrentDirectFaultVm(address(vm)).clearMockedCalls();
        _walletReceiveFault();
        vm.recordLogs();
        require(
            executeSafe(buyerSafe, payerKeys, address(sale), NATIVE_PRICE, data, 0),
            "identical native buy retry"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertSafeOutcome(buyerSafe, true, logs);
        _assertReceipt(address(sale), id, Direct.NATIVE_FIXED_PRICE, expected, logs);
        require(
            buyerSafe.nonce() == nonceBefore + 2
                && address(buyerSafe).balance == 1 ether - NATIVE_PRICE,
            "successful Safe retry paid once"
        );
        require(
            wallet.balance == 0
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == NATIVE_PRICE && revenueEscrow.totalOwed(address(0)) == NATIVE_PRICE,
            "genuine escrow obligation after retry"
        );
        CurrentDirectFaultVm(address(vm)).clearMockedCalls();
    }

    function testERC20SafePayerAndRelayerLateFloorFailurePreservesIntentAndIdenticalBuyRetries()
        public
    {
        _bindFloor();
        OfficialSafe payerSafe = _newSafe(703);
        OfficialSafe relayerSafe = _newSafe(704);
        paymentToken.mint(address(payerSafe), 1000);
        require(
            executeSafe(
                payerSafe,
                payerKeys,
                address(paymentToken),
                0,
                abi.encodeCall(paymentToken.approve, (address(erc20Sale), 1000)),
                0
            ),
            "real payer Safe approval"
        );
        uint256 payerSafeNonce = payerSafe.nonce();
        (bytes memory data, bytes32 id, Direct.Receipt memory expected) =
            _erc20Data(address(payerSafe), address(payerSafe), true);
        _floorFault(id);
        uint256 relayerNonce = relayerSafe.nonce();
        _safeFailure(relayerSafe, address(erc20Sale), 0, data);
        require(
            relayerSafe.nonce() == relayerNonce + 1 && payerSafe.nonce() == payerSafeNonce,
            "only relayer failure receipt consumes Safe nonce"
        );
        _assertMintRollback(address(erc20Sale), id, expected.operationRoot);
        require(
            !erc20Sale.authorizationUsed(artist, NONCE)
                && !erc20Sale.isPaymentIntentNonceUsed(address(payerSafe), NONCE),
            "artist authorization and payer intent rollback"
        );
        require(
            paymentToken.rawBalance(address(payerSafe)) == 1000
                && paymentToken.allowance(address(payerSafe), address(erc20Sale)) == 1000
                && paymentToken.rawBalance(wallet) == 0 && paymentToken.transferCalls() == 0
                && erc20Sale.totalProceeds(address(paymentToken)) == 0,
            "ERC20 balances allowance and payment counters rollback"
        );
        _assertEmptyEscrow(address(paymentToken));
        CurrentDirectFaultVm(address(vm)).clearMockedCalls();
        vm.recordLogs();
        require(
            executeSafe(relayerSafe, payerKeys, address(erc20Sale), 0, data, 0),
            "identical ERC20 buy and payer proof retry"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertSafeOutcome(relayerSafe, true, logs);
        _assertReceipt(address(erc20Sale), id, Direct.ERC20_FIXED_PRICE, expected, logs);
        require(
            relayerSafe.nonce() == relayerNonce + 2 && payerSafe.nonce() == payerSafeNonce
                && erc20Sale.isPaymentIntentNonceUsed(address(payerSafe), NONCE),
            "successful relay and unchanged payer Safe nonce"
        );
        require(
            paymentToken.rawBalance(address(payerSafe)) == 1000 - TOKEN_PRICE
                && paymentToken.allowance(address(payerSafe), address(erc20Sale))
                    == 1000 - TOKEN_PRICE && paymentToken.rawBalance(wallet) == TOKEN_PRICE,
            "one actual ERC20 payment"
        );
    }

    function testZeroPriceOriginalNativeBuyWithoutFloorCreatesNoPaidReceipt() public {
        (address bound,) = IStreamCoreConservationFloor(address(core)).conservationFloor();
        require(bound == address(0), "floor remains unbound for free mint");
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            _nativeAuthorization(payer, BUYER, 0);
        (bytes memory data, bytes32 id, Direct.Receipt memory preview) = _nativeData(a, false);
        vm.prank(payer);
        (uint256 tokenId, bytes32 root) = _callBuy(address(sale), 0, data);
        _assertNoReceipt(address(sale), id);
        require(
            tokenId == 1 && root == preview.operationRoot && core.ownerOf(tokenId) == BUYER
                && manager.isAuthorizationUsed(id) && manager.isOperationRootUsed(root),
            "free original buy still mints once"
        );
        _assertCounter(address(sale), 1);
        require(
            sale.totalNativeProceeds() == 0 && wallet.balance == 0
                && floor.firstSale(1).receiptHash == 0,
            "no fabricated paid floor"
        );
    }

    function testNativeMintCallbackKeepsBurnGuardAllowsOnwardTransferAndRetainsHistoricalReceipt()
        public
    {
        _bindFloor();
        address onward = address(0xD1EC705);
        CurrentDirectLifecycleReceiver receiver =
            new CurrentDirectLifecycleReceiver(core, onward, false);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            _nativeAuthorization(payer, address(receiver), NATIVE_PRICE);
        (bytes memory data, bytes32 id, Direct.Receipt memory expected) = _nativeData(a, false);
        vm.recordLogs();
        vm.prank(payer);
        (uint256 tokenId,) = _callBuy(address(sale), NATIVE_PRICE, data);
        _assertReceiptAtOwner(
            address(sale), id, Direct.NATIVE_FIXED_PRICE, expected, vm.getRecordedLogs(), onward
        );
        require(
            receiver.mintBurnRejected() && receiver.receivedToken() == tokenId
                && expected.beneficiary == address(receiver),
            "original beneficiary remains distinct from onward owner"
        );
        bytes32 originalHash = sale.directPrimarySaleReceiptHash(id);
        bytes32 key = _directKey(address(sale), Direct.NATIVE_FIXED_PRICE, id);
        bytes32 floorEvidence = keccak256(
            abi.encode(
                IStreamDirectPrimaryConservationFloor(address(floor))
                    .directPrimarySaleFloorReceipt(key)
            )
        );
        vm.prank(onward);
        core.burn(tokenId);
        _assertCoreIdentity(tokenId, address(0));
        require(
            sale.directPrimarySaleReceiptHash(id) == originalHash
                && keccak256(abi.encode(sale.directPrimarySaleReceipt(id)))
                    == keccak256(abi.encode(expected))
                && keccak256(
                    abi.encode(
                        IStreamDirectPrimaryConservationFloor(address(floor))
                            .directPrimarySaleFloorReceipt(key)
                    )
                ) == floorEvidence,
            "completed sale and floor evidence survive later burn"
        );
    }

    function testOriginalAuctionPaidDeliveryCanBurnAndRetainsExactDirectReceipt() public {
        _bindFloor();
        CurrentDirectLifecycleReceiver receiver =
            new CurrentDirectLifecycleReceiver(core, address(0), true);
        (bytes32 primaryPolicy,,) = auction.primaryPolicy(1);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a =
            IStreamEnglishAuctionHouse.AuctionAuthorization(
                1,
                AUCTION_PHASE,
                artist,
                profile,
                primaryPolicy,
                keccak256(TOKEN_DATA),
                keccak256("current DIRECT auction mint"),
                manager.phasePolicyHash(1, AUCTION_PHASE),
                NATIVE_PRICE,
                uint64(block.timestamp),
                uint64(block.timestamp + 1 days),
                300,
                500,
                NONCE,
                uint64(block.timestamp + 1 days),
                auction.signerEpoch()
            );
        bytes32 digest = auction.authorizationDigest(a);
        bytes32 id = auction.authorizationId(artist, NONCE);
        Direct.Receipt memory expected = _expectedReceipt(
            address(auction),
            AUCTION_PHASE,
            id,
            digest,
            payer,
            address(receiver),
            a.mintCommitment,
            a.mintPolicyHash,
            primaryPolicy,
            address(0),
            NATIVE_PRICE,
            false
        );
        uint256 tokenId = auction.createAuction(
            a, TOKEN_DATA, _sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest)
        );
        require(core.ownerOf(tokenId) == address(auction), "original house holds completed mint");
        _assertNoReceipt(address(auction), id);
        vm.prank(payer);
        auction.bid{ value: NATIVE_PRICE }(tokenId, address(receiver));
        require(auction.totalBidEscrow() == NATIVE_PRICE, "genuine original auction bid custody");
        vm.warp(a.endTime + 1);
        vm.recordLogs();
        auction.settle(tokenId);
        _assertReceiptAtOwner(
            address(auction), id, Direct.ENGLISH_AUCTION, expected, vm.getRecordedLogs(), address(0)
        );
        require(
            receiver.receivedToken() == tokenId && !receiver.mintBurnRejected()
                && auction.auctionStatus(tokenId)
                    == IStreamEnglishAuctionHouse.AuctionStatus.SettledWithBid
                && auction.totalBidEscrow() == 0 && auction.totalNativeProceeds() == NATIVE_PRICE
                && wallet.balance == NATIVE_PRICE && payer.balance == 1 ether - NATIVE_PRICE,
            "paid auction delivery burn preserves settlement and conservation"
        );
        require(
            expected.createdAt < block.timestamp && expected.beneficiary == address(receiver)
                && expected.payer == payer,
            "creation admission and actual later paid recipient retained"
        );
    }

    function _nativeAuthorization(address who, address recipient, uint256 price)
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
    {
        a = IStreamFixedPriceSaleAdapter.SaleAuthorization(
            1,
            PHASE,
            who,
            recipient,
            artist,
            profile,
            _nativePrimaryPolicyHash(),
            keccak256(TOKEN_DATA),
            keccak256("current DIRECT native mint"),
            manager.phasePolicyHash(1, PHASE),
            price,
            NONCE,
            uint64(block.timestamp + 1 days),
            sale.signerEpoch()
        );
    }

    function _nativeData(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a, bool escrowed)
        private
        returns (bytes memory data, bytes32 id, Direct.Receipt memory expected)
    {
        bytes32 digest = sale.authorizationDigest(a);
        id = sale.authorizationId(a.artist, a.nonce);
        data = abi.encodeCall(
            sale.buy, (a, TOKEN_DATA, _sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest))
        );
        expected = _expectedReceipt(
            address(sale),
            PHASE,
            id,
            digest,
            a.payer,
            a.recipient,
            a.mintCommitment,
            a.mintPolicyHash,
            a.expectedPrimaryPolicyHash,
            address(0),
            a.price,
            escrowed
        );
    }

    function _erc20Data(address who, address recipient, bool safePayer)
        private
        returns (bytes memory data, bytes32 id, Direct.Receipt memory expected)
    {
        IStreamERC20FixedPriceSaleAdapter.SaleRecord memory record =
            erc20Sale.saleRecord(erc20SaleId);
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamERC20FixedPriceSaleAdapter.SaleAuthorization(
                erc20SaleId,
                record.configHash,
                who,
                recipient,
                artist,
                keccak256(TOKEN_DATA),
                keccak256("current DIRECT ERC20 mint"),
                NONCE,
                uint64(block.timestamp + 1 days),
                erc20Sale.signerEpoch()
            );
        bytes32 digest = erc20Sale.authorizationDigest(a);
        id = erc20Sale.authorizationId(artist, NONCE);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent =
            IStreamPaymentIntentVerifier.PaymentIntent(
                who,
                address(paymentToken),
                TOKEN_PRICE,
                erc20SaleId,
                record.config.expectedPrimaryPolicyHash,
                NONCE,
                a.deadline
            );
        bytes32 intentDigest = erc20Sale.paymentIntentDigest(intent);
        bytes memory proof = safePayer
            ? safeThresholdSignature(
                payerKeys, safeMessageDigest(OfficialSafe(payable(who)), abi.encode(intentDigest))
            )
            : _sign(PAYER_KEY, intentDigest);
        data = abi.encodeCall(
            erc20Sale.buy,
            (a, TOKEN_DATA, _sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest), intent, proof)
        );
        expected = _expectedReceipt(
            address(erc20Sale),
            ERC20_PHASE,
            id,
            digest,
            who,
            recipient,
            a.mintCommitment,
            record.config.mintPolicyHash,
            record.config.expectedPrimaryPolicyHash,
            address(paymentToken),
            TOKEN_PRICE,
            false
        );
    }

    function _expectedReceipt(
        address adapter,
        bytes32 phase,
        bytes32 id,
        bytes32 digest,
        address who,
        address recipient,
        bytes32 commitment,
        bytes32 mintPolicy,
        bytes32 primaryPolicy,
        address asset,
        uint256 amount,
        bool escrowed
    ) private returns (Direct.Receipt memory r) {
        IStreamMintManager.MintBatch memory batch;
        batch.collectionId = 1;
        batch.phaseId = phase;
        batch.payer = adapter == address(auction) ? address(0) : who;
        batch.initialRecipients = new address[](1);
        batch.beneficiaries = new address[](1);
        batch.tokenData = new bytes[](1);
        batch.mintCommitments = new bytes32[](1);
        batch.initialRecipients[0] = adapter == address(auction) ? adapter : recipient;
        batch.beneficiaries[0] = adapter == address(auction) ? artist : recipient;
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments[0] = commitment;
        batch.expectedPolicyHash = mintPolicy;
        batch.authorizationId = id;
        batch.contextHash = digest;
        vm.prank(adapter);
        (bytes32 root, bytes32[] memory operations) =
            manager.previewSingleStepMintOperation(batch, "");
        require(
            operations.length == 1 && root != 0 && operations[0] != 0,
            "real executor-scoped preview"
        );
        r = Direct.Receipt(
            digest,
            1,
            core.lastAllocatedTokenId() + 1,
            root,
            operations[0],
            mintPolicy,
            primaryPolicy,
            profile,
            wallet,
            uint64(block.timestamp),
            escrowed,
            who,
            registry.moduleRecord(adapter).revision,
            recipient,
            asset,
            amount
        );
    }

    function _assertReceipt(
        address adapter,
        bytes32 id,
        bytes32 kind,
        Direct.Receipt memory expected,
        Vm.Log[] memory logs
    ) private view {
        _assertReceiptAtOwner(adapter, id, kind, expected, logs, expected.beneficiary);
    }

    function _assertReceiptAtOwner(
        address adapter,
        bytes32 id,
        bytes32 kind,
        Direct.Receipt memory expected,
        Vm.Log[] memory logs,
        address currentOwner
    ) private view {
        IStreamDirectPrimarySaleReceipt product = IStreamDirectPrimarySaleReceipt(adapter);
        Direct.Bindings memory bindings = product.directPrimaryBindings();
        require(
            keccak256(abi.encode(bindings))
                == keccak256(
                    abi.encode(
                        Direct.Bindings(
                            address(core),
                            address(core).codehash,
                            address(manager),
                            address(manager).codehash,
                            block.chainid,
                            kind
                        )
                    )
                ),
            "exact immutable DIRECT bindings"
        );
        require(
            keccak256(abi.encode(product.directPrimarySaleReceipt(id)))
                == keccak256(abi.encode(expected)),
            "all sixteen original receipt words"
        );
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"),
                block.chainid,
                address(core),
                adapter,
                kind,
                id,
                expected
            )
        );
        require(
            product.directPrimarySaleReceiptHash(id) == hash, "independently derived DIRECT hash"
        );
        uint256 matched;
        bytes32 topic = keccak256(
            "DirectPrimarySaleRecorded(bytes32,bytes32,uint256,(bytes32,uint256,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,bool,address,uint64,address,address,uint256),uint16)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != adapter || logs[i].topics.length != 4
                    || logs[i].topics[0] != topic
            ) continue;
            (Direct.Receipt memory emitted, uint16 schema) =
                abi.decode(logs[i].data, (Direct.Receipt, uint16));
            require(
                logs[i].topics[1] == id && logs[i].topics[2] == hash
                    && uint256(logs[i].topics[3]) == expected.tokenId && schema == 1
                    && keccak256(abi.encode(emitted)) == keccak256(abi.encode(expected)),
                "exact original DIRECT event"
            );
            ++matched;
        }
        require(matched == 1, "one original DIRECT receipt event");
        require(
            manager.isAuthorizationUsed(id) && manager.isOperationRootUsed(expected.operationRoot)
                && manager.nextOperationNonce() == 1,
            "actual manager replay evidence"
        );
        _assertCounter(adapter, 1);
        _assertCoreIdentity(expected.tokenId, currentOwner);
        bytes32 key = _directKey(adapter, kind, id);
        StreamConservationFloorTypes.SettlementReceipt memory empty;
        require(
            keccak256(abi.encode(floor.settlementReceipt(key))) == keccak256(abi.encode(empty)),
            "DIRECT cannot masquerade as standard settlement"
        );
        StreamConservationFloorTypes.FirstSaleReceipt memory first = floor.firstSale(1);
        StreamConservationFloorTypes.CollectionFacts memory noDocumentaryFacts;
        require(
            first.receiptHash != 0 && first.effectiveTier == WAIVED && first.collectionId == 1
                && first.recorder == adapter && first.settlementKey == key && first.sourceId == 0
                && keccak256(abi.encode(first.facts)) == keccak256(abi.encode(noDocumentaryFacts)),
            "actual explicit waived floor with no invented documentary facts"
        );
        _assertFloorReceipt(adapter, id, key, hash, bindings, expected, first.receiptHash, logs);
    }

    function _assertCoreIdentity(uint256 tokenId, address currentOwner) private view {
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        require(
            exists && collectionId == 1 && serial == 1 && burned == (currentOwner == address(0))
                && core.tokenLifecycle(tokenId) == (burned ? 3 : 2)
                && core.totalSupply() == (burned ? 0 : 1) && core.collectionMintedEver(1) == 1
                && core.coordinatorAtMint(tokenId) == address(entropy)
                && entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.REGISTERED,
            "actual permanent Core and entropy identity"
        );
        if (burned) {
            (bool ok,) = address(core).staticcall(abi.encodeCall(core.ownerOf, (tokenId)));
            require(!ok, "burned token has no current owner");
        } else {
            require(core.ownerOf(tokenId) == currentOwner, "actual final custody");
        }
    }

    function _assertFloorReceipt(
        address adapter,
        bytes32 id,
        bytes32 key,
        bytes32 originalHash,
        Direct.Bindings memory bindings,
        Direct.Receipt memory saleReceipt,
        bytes32 firstSaleHash,
        Vm.Log[] memory logs
    ) private view {
        StreamDirectPrimaryConservationTypes.Receipt memory expected;
        expected.adapter = adapter;
        expected.adapterCodeHash = adapter.codehash;
        expected.directKey = key;
        expected.authorizationId = id;
        expected.originalReceiptHash = originalHash;
        expected.bindings = bindings;
        expected.sale = saleReceipt;
        expected.effectiveTier = WAIVED;
        expected.firstSaleReceiptHash = firstSaleHash;
        expected.recordedAt = uint64(block.timestamp);
        // Hash the independently assembled receipt with its own receiptHash initially zero.
        expected.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"),
                block.chainid,
                address(core),
                address(floor),
                expected
            )
        );
        require(
            keccak256(
                abi.encode(
                    IStreamDirectPrimaryConservationFloor(address(floor))
                        .directPrimarySaleFloorReceipt(key)
                )
            ) == keccak256(abi.encode(expected)),
            "complete distinct DIRECT floor receipt and independent hash"
        );
        bytes32 topic = keccak256(
            "ConservationDirectPrimarySaleRecorded(bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32,bytes32,(address,bytes32,address,bytes32,uint256,bytes32),(bytes32,uint256,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,bool,address,uint64,address,address,uint256),bytes32,bytes32,bytes32,uint64),uint16)"
        );
        uint256 matched;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(floor) || logs[i].topics.length != 3
                    || logs[i].topics[0] != topic
            ) continue;
            (StreamDirectPrimaryConservationTypes.Receipt memory emitted, uint16 schema) =
                abi.decode(logs[i].data, (StreamDirectPrimaryConservationTypes.Receipt, uint16));
            require(
                logs[i].topics[1] == key && logs[i].topics[2] == expected.receiptHash && schema == 1
                    && keccak256(abi.encode(emitted)) == keccak256(abi.encode(expected)),
                "exact distinct DIRECT floor event"
            );
            ++matched;
        }
        require(matched == 1, "one distinct DIRECT floor event");
    }

    function _assertNoReceipt(address adapter, bytes32 id) private view {
        Direct.Receipt memory empty;
        IStreamDirectPrimarySaleReceipt product = IStreamDirectPrimarySaleReceipt(adapter);
        require(
            product.directPrimarySaleReceiptHash(id) == 0
                && keccak256(abi.encode(product.directPrimarySaleReceipt(id)))
                    == keccak256(abi.encode(empty)),
            "no paid receipt before successful payment"
        );
        StreamDirectPrimaryConservationTypes.Receipt memory noFloorReceipt;
        bytes32 key = _directKey(adapter, product.directPrimaryBindings().productKind, id);
        require(
            keccak256(
                abi.encode(
                    IStreamDirectPrimaryConservationFloor(address(floor))
                        .directPrimarySaleFloorReceipt(key)
                )
            ) == keccak256(abi.encode(noFloorReceipt)),
            "no DIRECT floor evidence before successful payment"
        );
    }

    function _assertMintRollback(address adapter, bytes32 id, bytes32 root) private view {
        _assertNoReceipt(adapter, id);
        require(
            core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
                && core.collectionMintedEver(1) == 0 && manager.nextOperationNonce() == 0
                && !manager.isAuthorizationUsed(id) && !manager.isOperationRootUsed(root),
            "actual Core Manager and Ledger rollback"
        );
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE
                && floor.firstSale(1).receiptHash == 0,
            "entropy and floor rollback"
        );
        _assertCounter(adapter, 0);
    }

    function _assertCounter(address adapter, uint64 expected) private view {
        bytes32 phase = adapter == address(sale)
            ? PHASE
            : adapter == address(auction) ? AUCTION_PHASE : ERC20_PHASE;
        bytes32 counterId = keccak256("supply");
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                uint256(1),
                phase,
                counterId
            )
        );
        require(
            manager.counterValue(1, phase, counterId, subject) == expected,
            "actual Ledger supply counter"
        );
    }

    function _assertEmptyEscrow(address asset) private view {
        require(
            revenueEscrow.totalOwed(asset) == 0
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, asset) == 0,
            "escrow obligation rollback"
        );
        if (asset == address(0)) {
            require(
                address(revenueEscrow).balance == 0 && address(sale).balance == 0,
                "native escrow and adapter cash rollback"
            );
        } else {
            require(
                paymentToken.rawBalance(address(revenueEscrow)) == 0
                    && paymentToken.rawBalance(address(erc20Sale)) == 0,
                "token escrow and adapter cash rollback"
            );
        }
    }

    function _directKey(address adapter, bytes32 kind, bytes32 id) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"),
                block.chainid,
                address(core),
                adapter,
                kind,
                id
            )
        );
    }

    function _floorFault(bytes32 id) private {
        bytes memory callData =
            abi.encodeCall(IStreamDirectPrimaryConservationFloor.recordDirectPrimarySale, (id));
        CurrentDirectFaultVm(address(vm))
            .mockCallRevert(address(floor), callData, abi.encode(FAULT));
        CurrentDirectFaultVm(address(vm)).expectCall(address(floor), callData);
    }

    function _walletReceiveFault() private {
        // Value-specific fault leaves genuine factory/profile STATIC reads available to escrow.
        CurrentDirectFaultVm(address(vm))
            .mockCallRevert(
                wallet, NATIVE_PRICE, "", abi.encode(keccak256("transient wallet receive failure"))
            );
    }

    function _newSafe(uint256 salt) private returns (OfficialSafe) {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0xD1EC701;
        owners[1] = 0xD1EC702;
        owners[2] = 0xD1EC703;
        return createOfficialSafe(safeComponents, safeOwnerAddresses(owners), 2, salt);
    }

    function _safeFailure(OfficialSafe account, address target, uint256 value, bytes memory data)
        private
    {
        uint256 transactionGas = 30_000_000;
        bytes32 digest = account.getTransactionHash(
            target, value, data, 0, transactionGas, 0, 0, address(0), address(0), account.nonce()
        );
        bytes memory signatures = safeThresholdSignature(payerKeys, digest);
        vm.recordLogs();
        bool ok = account.execTransaction(
            target,
            value,
            data,
            0,
            transactionGas,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );
        require(!ok, "real Safe emits inner execution failure");
        _assertSafeOutcome(account, false, vm.getRecordedLogs());
    }

    function _assertSafeOutcome(OfficialSafe account, bool success, Vm.Log[] memory logs)
        private
        pure
    {
        bytes32 expected = success
            ? keccak256("ExecutionSuccess(bytes32,uint256)")
            : keccak256("ExecutionFailure(bytes32,uint256)");
        bytes32 opposite = success
            ? keccak256("ExecutionFailure(bytes32,uint256)")
            : keccak256("ExecutionSuccess(bytes32,uint256)");
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(account) || logs[i].topics.length == 0) continue;
            require(logs[i].topics[0] != opposite, "opposite Safe receipt absent");
            if (logs[i].topics[0] == expected) ++count;
        }
        require(count == 1, "exact Safe outcome event");
    }

    function _callBuy(address target, uint256 value, bytes memory data)
        private
        returns (uint256, bytes32)
    {
        (bool ok, bytes memory result) = target.call{ value: value }(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return abi.decode(result, (uint256, bytes32));
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
