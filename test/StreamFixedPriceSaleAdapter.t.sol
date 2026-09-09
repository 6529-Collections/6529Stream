// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCorePermanentTarget.t.sol";
import "../smart-contracts/domains/mint/StreamMintManager.sol";
import "../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../smart-contracts/domains/revenue/StreamSplitFactory.sol";

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
contract StreamFixedPriceSaleAdapterTest is CharacterizationTestBase {
    uint256 private constant PLATFORM_KEY = 0xA11CE;
    uint256 private constant ARTIST_KEY = 0xB0B;
    bytes32 private constant PHASE = keccak256("native-fixed-price");
    bytes32 private constant MANAGER_POINTER =
        0x136326f089f522351128a5fb79275bd12b2d84fe5bb50d5e46c9f5508d6df7e2;
    bytes32 private constant ENTROPY_POINTER =
        0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb;

    PermanentTargetCoreHarness private core;
    PermanentTargetGovernanceExecutor private governance;
    PermanentTargetModuleRegistry private registry;
    PermanentTargetEntropyCoordinator private entropy;
    StreamMintManager private manager;
    StreamMintLedger private ledger;
    StreamFixedPriceSaleAdapter private sale;
    StreamSplitFactory private factory;
    bytes32 private profile;
    address private wallet;
    address private artist;
    address private platform;
    address private protocol = address(0xFEE);
    bytes private tokenData = bytes("ipfs://artist-token");

    function setUp() public {
        vm.deal(address(this), 100 ether);
        artist = vm.addr(ARTIST_KEY);
        platform = vm.addr(PLATFORM_KEY);
        governance = new PermanentTargetGovernanceExecutor();
        registry = new PermanentTargetModuleRegistry();
        _deployCore();
        entropy = new PermanentTargetEntropyCoordinator();
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(core, ledger, IERC165(address(registry)));
        ledger.setLedgerWriter(address(manager), true);
        _install(MANAGER_POINTER, address(manager), type(IStreamMintManager).interfaceId);
        _install(ENTROPY_POINTER, address(entropy), type(IStreamEntropyCoordinator).interfaceId);
        _createCollection();
        factory = new StreamSplitFactory(new StreamAssetPolicyRegistry());
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(protocol, 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("profile-metadata"));
        sale = new StreamFixedPriceSaleAdapter(manager, factory, platform);
        _configurePhase();
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
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization();
        authorization.artist = address(new NativeSale1271Signer(artist));
        sale.setPlatformSigner(address(new NativeSale1271Signer(platform)));
        authorization.signerEpoch = sale.signerEpoch();
        _buy(authorization);
        require(core.totalSupply() == 1 && wallet.balance == 1 ether, "ERC1271 paid mint");
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

    function _configurePhase() private {
        bytes32[] memory counters = new bytes32[](1);
        counters[0] = keccak256("supply");
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            PHASE,
            IStreamMintManager.MintPhaseConfig(
                false, 0, 0, 1, keccak256("phase"), keccak256("metadata")
            ),
            gate,
            counters,
            configs
        );
        manager.setPhaseExecutor(1, PHASE, address(sale), true);
    }

    function _deployCore() private {
        StreamCore.GasParameterGenesisConfig[] memory gas =
            new StreamCore.GasParameterGenesisConfig[](4);
        gas[0] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ROYALTY_RESOLVER_GAS_LIMIT"), 50_000, 25_000, 1
        );
        gas[1] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ROYALTY_RETURN_GAS_BUFFER"), 2_910_000, 1_460_000, 1
        );
        gas[2] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_METADATA_ROUTER_GAS_LIMIT"), 500_000, 250_000, 1
        );
        gas[3] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ENTROPY_REGISTRATION_GAS_LIMIT"), 120_000, 120_000, 2
        );
        core = new PermanentTargetCoreHarness(
            "Stream",
            "STREAM",
            address(governance),
            StreamCore.GenesisModuleRegistryConfig(
                address(registry),
                address(registry).codehash,
                keccak256("registry"),
                keccak256("deploy")
            ),
            gas
        );
    }

    function _install(bytes32 pointerType, address target, bytes4 interfaceId) private {
        registry.setRecord(
            target, pointerType, interfaceId, keccak256("module"), keccak256("deploy")
        );
        StreamCorePointerState memory previous = core.pointerState(pointerType);
        StreamCorePointerState memory candidate = StreamCorePointerState(
            target,
            target.codehash,
            false,
            pointerType,
            interfaceId,
            address(registry),
            1,
            keccak256("module"),
            keccak256("deploy"),
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            core.pointerTransitionHashes(pointerType, previous, candidate);
        governance.setAction(3, scope, oldHash, newHash);
        governance.execute(
            address(core), abi.encodeCall(core.updateSatellitePointer, (pointerType, target))
        );
    }

    function _createCollection() private {
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(core),
                uint256(1)
            )
        );
        bytes32 domain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        bytes32 oldHash =
            keccak256(abi.encode(domain, scope, false, uint8(0), uint8(0), false, uint256(0)));
        bytes32 newHash =
            keccak256(abi.encode(domain, scope, true, uint8(0), uint8(0), true, uint256(10)));
        governance.setAction(1, scope, oldHash, newHash);
        governance.execute(
            address(core),
            abi.encodeCall(core.createCollection, (uint8(0), true, uint256(10), uint8(0)))
        );
    }
}

