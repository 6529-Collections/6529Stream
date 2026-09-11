// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/ArtistTemplateTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../mocks/MockStreamPaymentToken.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";

contract StreamArtistTemplateMaterializationTest is RevenueV1TestBase, OfficialSafeFixture {
    bytes32 private constant ARTIST = keccak256("artist");
    bytes32 private constant SOURCE = keccak256("COLLECTION_ARTIST");
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant CAP = keccak256("6529STREAM_GGP_ARTIST_BENEFICIARY_READ_GAS");
    address private constant PAYEE = address(0xA11CE);
    address private constant PROTOCOL = address(0xB0B);
    StreamRevenueResolver private resolver;
    StreamSplitFactory private factory;
    StreamAssetPolicyRegistry private policy;
    RevenueResolverCoreMock private coreFixture;
    ArtistTemplateFactsMock private artists;
    TemplateGovernanceMock private authority;
    bytes32 private template;
    OfficialSafe private safe;
    uint256[] private keys;
    event SafeSelectorObserved(address target, bytes4 selector);
    event TemplateGasMeasured(
        uint256 entries, uint256 registrationGas, uint256 deploymentGas, uint256 reuseGas
    );

    function setUp() public {
        authority = new TemplateGovernanceMock();
        revenueAuthority = authority;
        policy = new StreamAssetPolicyRegistry(address(authority));
        factory = new StreamSplitFactory(policy, address(authority), _walletGasConfigs());
        coreFixture = new RevenueResolverCoreMock();
        artists = new ArtistTemplateFactsMock(address(coreFixture), PAYEE);
        coreFixture.selectArtist(address(artists), address(artists).codehash);
        artists.setBinding(1, keccak256("binding"), address(0xA0));
        resolver = new StreamRevenueResolver(
            IStreamCore(address(coreFixture)), factory, address(authority), artists, _config()
        );
        vm.prank(address(authority));
        resolver.transferOwnership(address(this));
        template = resolver.createPrimaryTemplate(_entries(), keccak256("template metadata"));
    }

    function testConstructorRejectsWrongNameFailureClassAndInvalidFloor() public {
        IStreamGasParameterHost.GasParameterConfig memory c = _config();
        c.name = "ASSET_POLICY_GAS_LIMIT";
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterInvalidConfig.selector, CAP)
        );
        new StreamRevenueResolver(
            IStreamCore(address(coreFixture)), factory, address(authority), artists, c
        );
        c = _config();
        c.failureClass = 1;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterInvalidConfig.selector, CAP)
        );
        new StreamRevenueResolver(
            IStreamCore(address(coreFixture)), factory, address(authority), artists, c
        );
        c = _config();
        c.floor = 0;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterInvalidConfig.selector, CAP)
        );
        new StreamRevenueResolver(
            IStreamCore(address(coreFixture)), factory, address(authority), artists, c
        );
        c = _config();
        c.genesisValue = c.floor - 1;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterInvalidConfig.selector, CAP)
        );
        new StreamRevenueResolver(
            IStreamCore(address(coreFixture)), factory, address(authority), artists, c
        );
    }

    function testGovernedReadBudgetIsImmutableFloorAndExactContextOnly() public {
        (uint256 value, uint256 floor, uint8 kind, uint64 revision) = resolver.gasParameterInfo(CAP);
        require(
            value == 200_000 && floor == 50_000 && kind == 2 && revision == 1,
            "explicit supplied config"
        );
        bytes32[] memory ids = resolver.gasParameterIds();
        require(ids.length == 1 && ids[0] == CAP, "closed one-row inventory");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(this)
            )
        );
        resolver.raiseGasParameter(CAP, 400_000);
        vm.prank(address(authority));
        (bool ok,) = address(resolver)
            .call(abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (CAP, 400_000)));
        require(
            !ok && resolver.gasParameter(CAP) == value,
            "authority without exact execution context fails"
        );
        _prepareRaise(400_000);
        vm.prank(address(authority));
        resolver.raiseGasParameter(CAP, 400_000);
        (value, floor, kind, revision) = resolver.gasParameterInfo(CAP);
        require(
            value == 400_000 && floor == 50_000 && kind == 2 && revision == 2,
            "only live value and revision increase"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotARaise.selector,
                CAP,
                uint256(400_000),
                uint256(399_999)
            )
        );
        vm.prank(address(authority));
        resolver.raiseGasParameter(CAP, 399_999);
    }

    function testChangedFacadeRuntimeAndUnknownTemplateFailBeforeFactoryWrites() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnknownPrimaryTemplate.selector, bytes32(uint256(999))
            )
        );
        resolver.materializeCollectionPrimaryProfile(bytes32(uint256(999)), 1, address(0), false);
        vm.etch(address(artists), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(artists)
            )
        );
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
        require(factory.profileCount() == 0, "unknown/mutated inputs cannot register");
    }

    function testCanonicalArtistProfileRegistrationAndExactWitnessEvent() public {
        vm.recordLogs();
        (bytes32 id, address wallet, bytes32 entriesHash) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0x99), false);
        require(
            factory.profileExists(id) && !factory.splitWalletExists(id) && wallet.code.length == 0,
            "registered is not deployed"
        );
        require(
            wallet == factory.walletFor(id) && factory.profileEntriesHash(id) == entriesHash,
            "factory source identity"
        );
        IStreamSplitWallet.SplitEntry[] memory entries = _concrete(PAYEE);
        bytes32 concrete = keccak256(abi.encode(entries));
        bytes32 metadata = keccak256(
            abi.encode(
                keccak256("6529STREAM_MATERIALIZED_PRIMARY_PROFILE_METADATA_V1"),
                block.chainid,
                address(resolver),
                template,
                concrete
            )
        );
        require(
            entriesHash == concrete && factory.profileMetadataURIHash(id) == metadata
                && factory.profileIdFor(entries, metadata) == id,
            "exact normative identity"
        );
        _witness(vm.getRecordedLogs(), id, wallet, entriesHash, false);
    }

    function testPublicMaterializationIsIdempotentAcrossContextsAndCallers() public {
        (bytes32 id, address wallet,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(1), false);
        vm.prank(address(0xCAFE));
        (bytes32 again, address same,) =
            resolver.materializeCollectionPrimaryProfile(template, 2, address(2), true);
        require(
            id == again && wallet == same && factory.profileCount() == 1
                && factory.splitWalletExists(id),
            "same recipients reuse wallet independent collection/poster/caller"
        );
        (bytes32 third, address reused,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(3), false);
        require(
            third == id && reused == wallet && factory.profileCount() == 1,
            "deployed deferred reuse"
        );
    }

    function testLaterDesignationChangesFutureProfileButNeverPriorPayouts() public {
        (bytes32 old, address oldWallet,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        artists.setFacts(artists.identity(), address(0xDAD), keccak256("designation two"));
        (bytes32 next, address nextWallet,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        require(
            next != old && nextWallet != oldWallet && factory.profileCount() == 2,
            "new recipients new immutable profile"
        );
        vm.deal(address(this), 2 ether);
        (bool ok,) = oldWallet.call{ value: 1 ether }("");
        require(ok);
        (ok,) = nextWallet.call{ value: 1 ether }("");
        require(ok);
        IStreamSplitWallet(oldWallet).release(address(0), PAYEE, payable(PAYEE));
        IStreamSplitWallet(nextWallet).release(address(0), address(0xDAD), payable(address(0xDAD)));
        require(
            PAYEE.balance == 0.9 ether && address(0xDAD).balance == 0.9 ether,
            "old and new entitlements remain separately payable"
        );
        require(
            IStreamSplitWallet(oldWallet).aggregateSharePpm(PAYEE) == 900_000, "old terms unchanged"
        );
    }

    function testSamePayoutNewDesignationSharesProfileWithNewWitness() public {
        (bytes32 old, address wallet,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        artists.setFacts(artists.identity(), PAYEE, keccak256("new record same address"));
        vm.recordLogs();
        (bytes32 next, address same, bytes32 hash) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        require(
            old == next && wallet == same && factory.profileCount() == 1,
            "record does not fragment fixed recipient identity"
        );
        _witness(vm.getRecordedLogs(), next, same, hash, true);
    }

    function testAggregatesSameAccountSameLabelButPreservesDifferentLabels() public {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](3);
        entries[0] =
            IStreamRevenueResolver.PrimaryTemplateEntry(address(0), SOURCE, 500_000, ARTIST);
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(PAYEE, bytes32(0), 400_000, ARTIST);
        entries[2] = IStreamRevenueResolver.PrimaryTemplateEntry(
            PAYEE, bytes32(0), 100_000, keccak256("other")
        );
        bytes32 t = resolver.createPrimaryTemplate(entries, bytes32(0));
        (bytes32 id,,) = resolver.materializeCollectionPrimaryProfile(t, 1, address(0), false);
        require(
            factory.profileEntryCount(id) == 2 && factory.profileUniqueAccountCount(id) == 1,
            "pair aggregation"
        );
        (address account, uint32 share) = factory.profileUniqueAccount(id, 0);
        require(account == PAYEE && share == 1_000_000, "account aggregate");
        for (uint256 i; i < 2; ++i) {
            (address a, uint32 s, bytes32 label) = factory.profileEntry(id, i);
            require(
                a == PAYEE && s == (label == ARTIST ? 900_000 : 100_000), "label shares preserved"
            );
        }
    }

    function testLegacyConvenienceWorksAndRejectsArtistContextTemplate() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.MissingArtistMaterializationContext.selector
            )
        );
        resolver.materializePrimaryProfile(template, PAYEE);
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("SALE_POSTER"), 1_000_000, keccak256("poster")
        );
        bytes32 t = resolver.createPrimaryTemplate(entries, bytes32(0));
        (bytes32 id, address wallet,) = resolver.materializePrimaryProfile(t, PAYEE);
        require(
            factory.splitWalletExists(id)
                && IStreamSplitWallet(wallet).aggregateSharePpm(PAYEE) == 1_000_000,
            "legacy poster behavior"
        );
    }

    function testArtistLabelAndUnsupportedSourcesRejectAtRegistration() public {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries = _entries();
        entries[0].labelId = keccak256("authority");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryTemplateEntry.selector, uint256(0)
            )
        );
        resolver.createPrimaryTemplate(entries, bytes32(0));
        entries[0].labelId = ARTIST;
        entries[0].accountSource = keccak256("COLLABORATOR");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnsupportedAccountSource.selector, entries[0].accountSource
            )
        );
        resolver.createPrimaryTemplate(entries, bytes32(0));
    }

    function testAbsentAndMalformedBeneficiaryFactsFailBeforeRegistration() public {
        for (uint8 m = 1; m <= 6; ++m) {
            artists.setMode(m);
            _unresolvable();
        }
        artists.setMode(0);
        artists.setFacts(bytes32(0), PAYEE, keccak256("record"));
        _unresolvable();
        artists.setFacts(keccak256("id"), address(0), keccak256("record"));
        _unresolvable();
        artists.setFacts(keccak256("id"), PAYEE, bytes32(0));
        _unresolvable();
        require(factory.profileCount() == 0, "all failures precede factory writes");
    }

    function testHeavyReadFailsAtCapAndGovernedRaiseEnablesSameFacts() public {
        artists.setGasWork(240_000);
        _unresolvable();
        _prepareRaise(400_000);
        vm.prank(address(authority));
        resolver.raiseGasParameter(CAP, 400_000);
        (bytes32 id,,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
        require(
            factory.profileExists(id) && resolver.gasParameter(CAP) == 400_000,
            "new budget forwards same facts"
        );
    }

    function testLowOuterGasRejectsBeforeSilentlyUnderforwardingCap() public {
        (bool ok, bytes memory reason) =
            address(resolver).call{ gas: 180_000 }(_materialize(template, 1, false));
        require(
            !ok && reason.length == 68
                && bytes4(reason)
                    == IStreamRevenueResolver.InsufficientArtistBeneficiaryGas.selector,
            "explicit admission failure"
        );
        require(factory.profileCount() == 0, "no registration");
    }

    function testWrongPointerCoreCodeAndInvalidCollectionReject() public {
        coreFixture.selectArtist(address(0), bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(0)
            )
        );
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
        coreFixture.selectArtist(address(artists), bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(artists)
            )
        );
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
        coreFixture.selectArtist(address(artists), address(artists).codehash);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryCollection.selector, 0)
        );
        resolver.materializeCollectionPrimaryProfile(template, 0, address(0), false);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryCollection.selector, 1001)
        );
        resolver.materializeCollectionPrimaryProfile(template, 1001, address(0), false);
        vm.etch(address(coreFixture), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryResolverConfiguration.selector
            )
        );
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
        require(factory.profileCount() == 0, "invalid authority no cache mutation");
    }

    function testFirstRegistrationRollsBackWhenPredictedAddressIsPoisoned() public {
        IStreamSplitWallet.SplitEntry[] memory entries = _concrete(PAYEE);
        bytes32 hash = keccak256(abi.encode(entries));
        bytes32 metadata = keccak256(
            abi.encode(
                keccak256("6529STREAM_MATERIALIZED_PRIMARY_PROFILE_METADATA_V1"),
                block.chainid,
                address(resolver),
                template,
                hash
            )
        );
        bytes32 id = factory.profileIdFor(entries, metadata);
        address wallet = factory.walletFor(id);
        vm.etch(wallet, hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.UnverifiedSplitProfile.selector, id)
        );
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
        require(
            !factory.profileExists(id) && factory.profileCount() == 0,
            "first registration and its index roll back"
        );
    }

    function testPoisonedPredictedWalletRejectsBothDeferredAndDeployment() public {
        (bytes32 id, address wallet,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
        vm.etch(wallet, hex"60006000fd");
        for (uint256 i; i < 2; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(IStreamRevenueResolver.UnverifiedSplitProfile.selector, id)
            );
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), i == 1);
        }
        require(
            factory.profileCount() == 1 && !factory.splitWalletExists(id),
            "prior registration preserved not promoted"
        );
    }

    function testRegisteredPredictionPrefundingIsNotOfficialSale() public {
        (bytes32 id, address wallet,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
        vm.deal(wallet, 1 ether);
        MockStreamPaymentToken token = new MockStreamPaymentToken();
        token.mint(wallet, 1000);
        _setAssetPolicy(policy, address(token), 1, keccak256("active"), 0);
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        require(factory.splitWalletExists(id), "late deploy");
        IStreamSplitWallet(wallet).release(address(0), PAYEE, payable(PAYEE));
        IStreamSplitWallet(wallet).syncAsset(address(token));
        IStreamSplitWallet(wallet).release(address(token), PAYEE, payable(PAYEE));
        require(
            PAYEE.balance == 0.9 ether && token.balanceOf(PAYEE) == 900,
            "prefunded receipts remain payee money"
        );
    }

    function testMaterializationDoesNotOpenBoundTemplateAssignment() public {
        (bytes32 id, address wallet,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        require(factory.splitWalletExists(id) && wallet != address(0), "cache exists");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1)
        );
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, template, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnsupportedArtistPrimaryAssignment.selector, 1
            )
        );
        resolver.resolvePrimaryAssignment(1, 0, CLASS);
    }

    function testActualSafeMaterializesAndReceivesNativeAndERC20WithoutAuthorityFallback() public {
        _makeSafe();
        artists.setFacts(artists.identity(), address(safe), artists.designation());
        _exec(address(resolver), _materialize(template, 1, true));
        (bytes32 id, address wallet,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        vm.deal(address(this), 1 ether);
        (bool ok,) = wallet.call{ value: 1 ether }("");
        require(ok);
        MockStreamPaymentToken token = new MockStreamPaymentToken();
        token.mint(wallet, 1000);
        _setAssetPolicy(policy, address(token), 1, keccak256("active"), 0);
        _exec(wallet, abi.encodeCall(IStreamSplitWallet.syncAsset, (address(token))));
        _exec(
            wallet,
            abi.encodeCall(
                IStreamSplitWallet.release, (address(0), address(safe), payable(address(safe)))
            )
        );
        _exec(
            wallet,
            abi.encodeCall(
                IStreamSplitWallet.release, (address(token), address(safe), payable(address(safe)))
            )
        );
        require(
            address(safe).balance == 0.9 ether && token.balanceOf(address(safe)) == 900,
            "actual Safe native and token recipient"
        );
        require(
            IStreamSplitWallet(wallet).aggregateSharePpm(address(0xA0)) == 0
                && factory.profileExists(id),
            "authority is not fallback or beneficiary"
        );
    }

    function testActualSafeOwnerAndGovernanceRoutesRemainDistinct() public {
        _makeSafe();
        resolver.transferOwnership(address(safe));
        _reject(
            abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (CAP, 400_000)),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(safe)
            )
        );
        authority.setController(address(safe));
        _prepareRaise(400_000);
        _exec(
            address(authority),
            abi.encodeCall(
                TemplateGovernanceMock.execute,
                (
                    address(resolver),
                    abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (CAP, 400_000))
                )
            )
        );
        require(
            resolver.gasParameter(CAP) == 400_000, "actual Safe enters authorized governance route"
        );
        _exec(
            address(resolver),
            abi.encodeCall(
                IStreamRevenueResolver.createPrimaryTemplate, (_entries(), bytes32(uint256(8)))
            )
        );
        (bytes32 id,,) = resolver.materializeCollectionPrimaryProfile(template, 2, address(0), true);
        _exec(
            address(resolver),
            abi.encodeCall(
                IStreamRevenueResolver.setPrimaryProfileAssignment,
                (CLASS, uint8(1), uint256(2), id, bytes32(0))
            )
        );
        _exec(
            address(resolver),
            abi.encodeCall(
                IStreamRevenueResolver.clearPrimaryAssignment, (CLASS, uint8(1), uint256(2))
            )
        );
        _exec(
            address(resolver),
            abi.encodeCall(
                IStreamRevenueResolver.setPrimaryTemplateAssignment,
                (CLASS, uint8(1), uint256(2), template, bytes32(0))
            )
        );
        _exec(
            address(resolver),
            abi.encodeCall(
                IStreamRevenueResolver.freezePrimaryAssignment, (CLASS, uint8(1), uint256(2))
            )
        );
        require(resolver.resolvePrimaryAssignment(2, 0, CLASS).frozen, "actual Safe owner writes");
        _exec(
            address(resolver), abi.encodeWithSignature("transferOwnership(address)", address(safe))
        );
        _exec(address(resolver), abi.encodeWithSignature("renounceOwnership()"));
        require(resolver.owner() == address(0), "actual Safe renounces only owner role");
    }

    function testActualSafeReadsAllPublicFactsAndLegacyMaterialization() public {
        _makeSafe();
        string[30] memory names = [
            "SCHEMA_VERSION()",
            "TEMPLATE_VERSION()",
            "MAX_TEMPLATE_ENTRIES()",
            "MAX_DYNAMIC_ACCOUNT_SOURCES()",
            "SHARE_DENOMINATOR_PPM()",
            "SCOPE_DEFAULT()",
            "SCOPE_COLLECTION()",
            "SCOPE_TOKEN()",
            "ASSIGNMENT_TYPE_PROFILE()",
            "ASSIGNMENT_TYPE_TEMPLATE()",
            "ACCOUNT_SOURCE_SALE_POSTER()",
            "ACCOUNT_SOURCE_COLLECTION_ARTIST()",
            "ARTIST_LABEL()",
            "ARTIST_BENEFICIARY_READ_GAS()",
            "splitFactoryContract()",
            "splitFactory()",
            "core()",
            "artistRegistry()",
            "coreCodeHash()",
            "artistRegistryCodeHash()",
            "owner()",
            "isStreamRevenueResolver()",
            "GAS_PARAMETER_SCHEMA_VERSION()",
            "FAILURE_CLASS_NONE()",
            "FAILURE_CLASS_FORWARDING_CAP()",
            "FAILURE_CLASS_FAIL_CLOSED_PRECHECK()",
            "FAILURE_CLASS_MIN_GAS_GATE()",
            "governanceAuthority()",
            "gasParameterIds()",
            "supportsInterface(bytes4)"
        ];
        for (uint256 i; i < 29; ++i) {
            _read(abi.encodeWithSignature(names[i]));
        }
        _read(abi.encodeWithSignature(names[29], type(IStreamGasParameterHost).interfaceId));
        _read(abi.encodeCall(IStreamGasParameterHost.gasParameter, (CAP)));
        _read(abi.encodeCall(IStreamGasParameterHost.gasParameterInfo, (CAP)));
        _read(abi.encodeCall(IStreamRevenueResolver.primaryTemplate, (template)));
        _read(abi.encodeCall(IStreamRevenueResolver.primaryTemplateEntryCount, (template)));
        _read(abi.encodeCall(IStreamRevenueResolver.primaryTemplateEntry, (template, 0)));
        (bytes32 id,,) = resolver.materializeCollectionPrimaryProfile(template, 2, address(0), true);
        _read(
            abi.encodeCall(
                IStreamArtistPrimaryFacts.previewArtistPrimaryAssignment, (2, id, bytes32(0), false)
            )
        );
        _read(
            abi.encodeCall(
                IStreamRevenueResolver.primaryAssignmentHash,
                (CLASS, uint8(1), uint256(2), uint8(1), id, bytes32(0), bytes32(0), false)
            )
        );
        _read(abi.encodeCall(IStreamRevenueResolver.resolvePrimaryAssignment, (2, 0, CLASS)));
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            PROTOCOL, bytes32(0), 1_000_000, keccak256("protocol")
        );
        bytes32 t = resolver.createPrimaryTemplate(entries, bytes32(0));
        _exec(
            address(resolver),
            abi.encodeCall(IStreamRevenueResolver.materializePrimaryProfile, (t, address(safe)))
        );
    }

    function testMax64MaterializationAndReuseMeasured() public {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](64);
        entries[0] =
            IStreamRevenueResolver.PrimaryTemplateEntry(address(0), SOURCE, 900_000, ARTIST);
        for (uint256 i = 1; i < 64; ++i) {
            entries[i] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(uint160(0x1000 + i)), bytes32(0), i == 63 ? 1668 : 1586, bytes32(i)
            );
        }
        bytes32 t = resolver.createPrimaryTemplate(entries, bytes32(0));
        uint256 beforeGas = gasleft();
        (bytes32 id, address wallet,) =
            resolver.materializeCollectionPrimaryProfile(t, 1, address(0), false);
        uint256 registration = beforeGas - gasleft();
        beforeGas = gasleft();
        resolver.materializeCollectionPrimaryProfile(t, 1, address(0), true);
        uint256 deployment = beforeGas - gasleft();
        beforeGas = gasleft();
        resolver.materializeCollectionPrimaryProfile(t, 1, address(0), false);
        uint256 reuse = beforeGas - gasleft();
        require(
            factory.profileEntryCount(id) == 64 && factory.splitWalletExists(id)
                && wallet == factory.walletFor(id),
            "max canonical wallet"
        );
        emit TemplateGasMeasured(64, registration, deployment, reuse);
    }

    function testFuzzCanonicalRecipientsSharesAndOrderReuseProfile(
        uint160 accountSeed,
        uint32 shareSeed,
        bool reverse
    ) public {
        address recipient = address(accountSeed == 0 ? uint160(1) : accountSeed);
        uint32 artistShare = 1 + shareSeed % 999_999;
        artists.setFacts(artists.identity(), recipient, artists.designation());
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries = _entries();
        entries[0].sharePpm = artistShare;
        entries[1].sharePpm = 1_000_000 - artistShare;
        bytes32 first = resolver.createPrimaryTemplate(entries, keccak256("fuzz terms"));
        if (reverse) (entries[0], entries[1]) = (entries[1], entries[0]);
        bytes32 second = resolver.createPrimaryTemplate(entries, keccak256("fuzz terms"));
        require(first == second, "canonical template order");
        (bytes32 id,, bytes32 hash) =
            resolver.materializeCollectionPrimaryProfile(first, 1, address(0), false);
        (bytes32 again,,) =
            resolver.materializeCollectionPrimaryProfile(second, 2, address(0), false);
        require(
            id == again && factory.profileCount() == 1 && hash == factory.profileEntriesHash(id),
            "same concrete rights reuse profile"
        );
        uint256 total;
        for (uint256 i; i < factory.profileEntryCount(id); ++i) {
            (address account, uint32 share, bytes32 label) = factory.profileEntry(id, i);
            if (label == ARTIST) {
                require(account == recipient && share == artistShare, "artist address and share");
            } else {
                require(
                    label == keccak256("protocol") && account == PROTOCOL
                        && share == 1_000_000 - artistShare,
                    "static address and share"
                );
            }
            total += share;
        }
        require(
            total == 1_000_000 && factory.profileEntryCount(id) == 2,
            "label-level conservation including same account"
        );
    }

    function _config() private pure returns (IStreamGasParameterHost.GasParameterConfig memory) {
        return IStreamGasParameterHost.GasParameterConfig(
            "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
        );
    }

    function _entries()
        private
        pure
        returns (IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries)
    {
        entries = new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] =
            IStreamRevenueResolver.PrimaryTemplateEntry(address(0), SOURCE, 900_000, ARTIST);
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            PROTOCOL, bytes32(0), 100_000, keccak256("protocol")
        );
    }

    function _concrete(address payee)
        private
        pure
        returns (IStreamSplitWallet.SplitEntry[] memory entries)
    {
        entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(PROTOCOL, 100_000, keccak256("protocol"));
        entries[1] = IStreamSplitWallet.SplitEntry(payee, 900_000, ARTIST);
        if (uint160(payee) < uint160(PROTOCOL)) {
            (entries[0], entries[1]) = (entries[1], entries[0]);
        }
    }

    function _materialize(bytes32 t, uint256 collection, bool deploy)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            IStreamRevenueResolver.materializeCollectionPrimaryProfile,
            (t, collection, address(0), deploy)
        );
    }

    function _unresolvable() private {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.UnresolvableArtistBeneficiary.selector, 1)
        );
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), false);
    }

    function _prepareRaise(uint256 next) private {
        (uint256 value, uint256 floor, uint8 kind, uint64 revision) = resolver.gasParameterInfo(CAP);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(resolver),
                CAP
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        authority.setCurrentAction(
            true,
            keccak256(abi.encode(next, revision)),
            1,
            scope,
            keccak256(abi.encode(domain, scope, value, floor, kind, revision)),
            keccak256(abi.encode(domain, scope, next, floor, kind, revision + 1))
        );
    }

    function _witness(Vm.Log[] memory logs, bytes32 id, address wallet, bytes32 hash, bool deployed)
        private
        view
    {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(resolver)
                    || logs[i].topics[0]
                        != keccak256(
                            "CollectionTemplateMaterialized(bytes32,bytes32,uint256,uint16,bytes32,address,bytes32,address,bytes32,bool)"
                        )
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == template
                    && logs[i].topics[2] == id && logs[i].topics[3] == bytes32(uint256(1)),
                "exact indexed identity"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(
                        abi.encode(
                            uint16(1),
                            artists.identity(),
                            artists.payout(),
                            artists.designation(),
                            wallet,
                            hash,
                            deployed
                        )
                    ),
                "exact payout witness"
            );
            ++found;
        }
        require(found == 1, "one complete witness event");
    }

    function _makeSafe() private {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x101;
        owners[1] = 0x102;
        owners[2] = 0x103;
        keys.push(owners[0]);
        keys.push(owners[1]);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 912);
    }

    function _read(bytes memory data) private {
        (bool ok, bytes memory expected) = address(resolver).staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = address(resolver).staticcall(data);
        require(
            ok && safeOk && expected.length != 0 && keccak256(actual) == keccak256(expected),
            "actual Safe view parity"
        );
        _exec(address(resolver), data);
    }

    function _exec(address target, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, keys, target, 0, data, 0), "Safe execution");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool success;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) success = true;
        }
        require(success && safe.nonce() == nonce + 1, "Safe event/nonce");
        emit SafeSelectorObserved(target, bytes4(data));
    }

    function _reject(bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = address(resolver).call(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact target error");
        uint256 nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(
            address(resolver), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signature = safeThresholdSignature(keys, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        safe.execTransaction(
            address(resolver), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(safe.nonce() == nonce, "failed Safe preserves nonce");
    }
}
