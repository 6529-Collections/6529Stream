// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./UniversalSettlementTestBase.sol";
import "./NativeSettlementTestBase.sol";
import "./NativeSupplementalTestMocks.sol";

abstract contract NativeSupplementalTestBase is UniversalSettlementTestBase {
    SupplementalCoreMock internal supplementalCore;
    SupplementalManagerMock internal supplementalManager;
    SupplementalProducerMock internal clearing;
    NativeTemplateArtistMock internal supplementalArtist;

    function setUp() public virtual override {
        vm.warp(1000);
        payer = vm.addr(PAYER_KEY);
        artist = vm.addr(ARTIST_KEY);
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        IStreamGasParameterHost.GasParameterConfig[3] memory cfg = _walletGasConfigs();
        cfg[2].genesisValue = 500_000;
        factory = new StreamSplitFactory(policy, address(revenueAuthority), cfg);
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(revenueAuthority)),
            keccak256("registry"),
            "ipfs://registry"
        );
        supplementalCore = new SupplementalCoreMock();
        core = supplementalCore;
        supplementalArtist = new NativeTemplateArtistMock(address(core), artist);
        artists = supplementalArtist;
        core.configure(address(artists), address(registry));
        supplementalManager = new SupplementalManagerMock(address(core), address(registry));
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
        (profile, wallet) = _newProfile(artist, keccak256("original"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        escrow = new StreamRevenueEscrow(
            factory,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _producer(true);
        clearing = new SupplementalProducerMock(recorder, supplementalManager);
        _register(
            address(clearing),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        clearing.capture();
        vm.deal(payer, 10 ether);
        vm.deal(address(this), 10 ether);
    }

    function _newProfile(address recipient, bytes32 tag) internal returns (bytes32, address) {
        IStreamSplitWallet.SplitEntry[] memory e = new IStreamSplitWallet.SplitEntry[](1);
        e[0] = IStreamSplitWallet.SplitEntry(recipient, 1_000_000, keccak256("artist"));
        return factory.createProfile(e, tag);
    }

    function _batch(uint256 number) internal view returns (IStreamMintManager.MintBatch memory b) {
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = payer;
        b.authorizer = artist;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = payer;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = payer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = abi.encode(number);
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = bytes32(number);
        b.expectedPolicyHash = supplementalManager.POLICY();
        b.authorizationId = keccak256(abi.encode("original signed digest", number));
    }

    function _rights(uint256 tokenId)
        internal
        view
        returns (StreamPrimarySettlementTypes.PrimaryRights memory r, bytes32 policyHash)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(1, tokenId, CLASS);
        r.assignmentHash = a.assignmentHash;
        r.templateId = a.templateId;
        if (a.assignmentType == 1) {
            r.profileId = a.profileId;
            r.wallet = factory.walletFor(a.profileId);
            r.entriesHash = factory.profileEntriesHash(a.profileId);
        } else {
            (r.profileId, r.wallet, r.entriesHash) =
                resolver.previewCollectionPrimaryProfile(a.templateId, 1, address(0));
        }
        policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                tokenId,
                r.templateId,
                r.profileId,
                r.wallet,
                r.assignmentHash
            )
        );
    }

    function _floor(uint256 number)
        internal
        returns (StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c)
    {
        IStreamMintManager.MintBatch memory b = _batch(number);
        (StreamPrimarySettlementTypes.PrimaryRights memory r, bytes32 p) = _rights(0);
        vm.prank(payer);
        bytes32 id = clearing.floorAndMint{ value: 1000 }(b, number, r, p);
        (r, p) = _rights(supplementalManager.nonce());
        c = clearing.candidate(id, r, p, address(this));
    }

    function _freshRights(StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c)
        internal
        view
    {
        (c.currentRights, c.currentPrimaryPolicyHash) = _rights(c.purchase.tokenId);
    }

    function _submit(StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c)
        internal
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory)
    {
        return clearing.supplement{ value: c.purchase.buyerUniformPrice - c.purchase.floorPrice }(c);
    }

    function _key(StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c)
        internal
        view
        returns (bytes32)
    {
        return recorder.settlementKey(
            address(clearing), StreamNativeSupplementalHash.executionId(address(recorder), c)
        );
    }

    function _unchanged(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        uint256 owed,
        uint256 balance
    ) internal view {
        require(
            !recorder.supplementalPurchaseConsumed(
                recorder.supplementalPurchaseKey(address(clearing), c.purchaseId)
            ),
            "purchase rolled back"
        );
        require(
            !recorder.supplementalFloorConsumed(
                recorder.supplementalFloorKey(c.purchase.floorSettlementKey)
            ),
            "floor lane rolled back"
        );
        require(!recorder.settlementConsumed(_key(c)), "official lane rolled back");
        require(
            recorder.totalOfficialSettled(address(0)) == 1000
                && c.currentRights.wallet.balance == balance,
            "official and wallet unchanged"
        );
        require(
            escrow.escrowOwed(CLASS, c.currentRights.profileId, c.currentRights.wallet, address(0))
                == owed,
            "owed unchanged"
        );
    }
}
