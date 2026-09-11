// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StreamCurrentStackFixture.sol";
import "../../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";

contract RoyaltyFaultFixture {
    uint8 private _mode;
    bool public unsupported;

    function setUnsupported() external {
        unsupported = true;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return !unsupported
            && (id == type(IStreamRoyaltyResolver).interfaceId || id == type(IERC165).interfaceId);
    }

    function setMode(uint8 mode) external {
        _mode = mode;
    }

    function royaltyReceiverAndBps(address, uint256, uint256, uint256, bool)
        external
        view
        returns (address, uint16)
    {
        uint8 mode = _mode;
        if (mode == 1) revert("royalty fault");
        if (mode == 2) {
            assembly {
                mstore(0, 1)
                return(0, 32)
            }
        }
        if (mode == 3) return (address(0xCAFE), 1001);
        if (mode == 4) {
            assembly {
                mstore(0, shl(160, 1))
                mstore(32, 500)
                return(0, 64)
            }
        }
        if (mode == 5) {
            assembly {
                mstore(0, 0xCAFE)
                mstore(32, 65536)
                return(0, 64)
            }
        }
        if (mode == 6) assembly { for { } 1 { } { } }
        if (mode == 7) return (address(0), 500);
        return (address(0xCAFE), 500);
    }
}

/// @notice Actual Core/artist/Manager royalty integration plus deliberately unbound collection mutation tests.
contract StreamRoyaltyResolverTest is StreamCurrentStackFixture {
    bytes32 private constant ROYALTY_PHASE = keccak256("royalty-test-mint");
    bytes32 private constant ROYALTY_POINTER =
        0xafcd60ac064e6f5b3428ca05e721b02c16a658af3989d079e29e38df5fab9c91;
    bytes32 private constant REVENUE_MODULE =
        0x217d16181cfb7c9bb7e1687d0b13ef4b864e9154dc37b60f75a88bec454b5467;
    uint256 private constant UNBOUND = 2;
    StreamRoyaltyResolver private resolver;

    function setUp() public {
        vm.deal(address(this), 100 ether);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        resolver = royalties;
        (GovernanceCall memory call_, bytes memory data) =
            StreamCurrentStackPlan.createCollectionCall(core, UNBOUND, 10);
        _executeTransition(1, call_, data);
        require(
            core.collectionExists(UNBOUND) && artists.acceptedArtist(UNBOUND) == address(0),
            "explicit unbound collection"
        );
    }

    function _configureAdditionalProducts() internal override {
        _configureMintPhase(ROYALTY_PHASE, address(this));
    }

    function testActualCoreInstallsTypedResolverAndDisclosesCollectionSplit() public {
        require(resolver.owner() == address(executor), "executor owns royalty mutations");
        require(
            resolver.supportsInterface(type(IStreamRoyaltyResolver).interfaceId)
                && resolver.supportsInterface(type(IERC165).interfaceId),
            "typed interface"
        );
        require(
            !resolver.supportsInterface(0xffffffff) && !resolver.supportsInterface(0x12345678),
            "strict ERC165"
        );
        require(
            StreamCurrentStackPlan.readPointer(core, ROYALTY_POINTER).target == address(resolver),
            "actual Core pointer"
        );
        uint256 tokenId = _mint();
        (address receiver, uint256 amount) = core.royaltyInfo(tokenId, 1 ether);
        require(receiver == wallet && amount == 0.069 ether, "actual ERC2981 split");
        (bool funded,) = payable(receiver).call{ value: amount }("");
        require(funded, "marketplace deposit");
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(0), PROTOCOL, payable(PROTOCOL));
        require(
            artist.balance == 0.0621 ether && PROTOCOL.balance == 0.0069 ether,
            "actual royalty withdrawals"
        );
    }

    function testBurnedTokenRetainsCollectionRoyaltyAndUnmappedUsesDefault() public {
        _configureDefault(profile, 500);
        uint256 tokenId = _mint();
        vm.prank(artist);
        core.burn(tokenId);
        (bool mapped, uint256 collectionId,, bool burned) = core.tokenCollectionIdentity(tokenId);
        require(mapped && collectionId == 1 && burned, "Core retained token mapping");
        (address receiver, uint256 amount) = core.royaltyInfo(tokenId, 10_000);
        require(receiver == wallet && amount == 690, "burned collection royalty");
        (receiver, amount) = core.royaltyInfo(type(uint256).max, 10_000);
        require(receiver == wallet && amount == 500, "unmapped default without token arithmetic");
    }

    function testExplicitZeroOverridesDefaultAndMaximumPriceNeverOverflows() public {
        _configureDefault(profile, 1000);
        (address receiver, uint256 amount) = core.royaltyInfo(type(uint256).max, type(uint256).max);
        require(receiver == wallet && amount == type(uint256).max / 10, "maximum-price safe math");
        _configureUnbound(bytes32(0), 0);
        uint16 bps;
        (receiver, bps) = resolver.royaltyReceiverAndBps(address(core), UNBOUND, 1, 1, true);
        require(
            receiver == address(0) && bps == 0,
            "explicit zero shadows default before artist binding"
        );
        _configureBoundWithConsent(profile, 1000);
        uint256 tokenId = _mint();
        (receiver, amount) = core.royaltyInfo(tokenId, 9);
        require(
            receiver == wallet && amount == 0, "actual Core floor rounding after artist consent"
        );
    }

    function testOnlyExecutorCanConfigureAndInvalidProfilesRatesOrCollectionsFail() public {
        vm.expectRevert();
        resolver.configureDefaultRoyalty(profile, 500);
        vm.expectRevert();
        this.configureForTest(0, profile, 1001);
        vm.expectRevert();
        this.configureForTest(0, keccak256("unknown"), 500);
        vm.expectRevert();
        this.configureForTest(999, profile, 500);
        vm.expectRevert();
        this.configureForTest(0, bytes32(0), 500);
        vm.expectRevert();
        this.configureForTest(0, profile, 0);
        require(
            !resolver.defaultRoyalty().configured
                && !resolver.collectionRoyalty(UNBOUND).configured,
            "invalid writes unchanged"
        );
        require(resolver.collectionRoyalty(1).royaltyBps == 690, "accepted collection unchanged");
    }

    function testCollectionFreezeSnapshotsInheritedTermsBeforeDefaultChanges() public {
        _configureDefault(profile, 500);
        vm.recordLogs();
        _freeze(UNBOUND);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 events;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(resolver)
                    && logs[i].topics[0]
                        == keccak256("RoyaltyFrozen(uint256,bytes32,address,uint16,uint64)")
            ) ++events;
        }
        require(events == 1, "one actual royalty freeze event");
        IStreamRoyaltyResolver.RoyaltyConfig memory item = resolver.collectionRoyalty(UNBOUND);
        require(
            item.frozen && item.configured && item.profileId == profile && item.wallet == wallet
                && item.royaltyBps == 500,
            "exact inherited snapshot"
        );
        _configureDefault(bytes32(0), 0);
        (address receiver, uint16 bps) =
            resolver.royaltyReceiverAndBps(address(core), UNBOUND, 1, 1, true);
        require(receiver == wallet && bps == 500, "frozen snapshot survives default change");
        vm.expectRevert();
        this.configureForTest(UNBOUND, profile, 690);
        vm.expectRevert();
        this.freezeForTest(UNBOUND);
    }

    function testFreezingUnconfiguredCollectionPermanentlyCapturesZero() public {
        _freeze(UNBOUND);
        _configureDefault(profile, 500);
        (address receiver, uint16 bps) =
            resolver.royaltyReceiverAndBps(address(core), UNBOUND, 1, 1, true);
        require(
            receiver == address(0) && bps == 0 && resolver.collectionRoyalty(UNBOUND).frozen,
            "zero snapshot cannot drift"
        );
        _freeze(0);
        vm.expectRevert();
        this.configureForTest(0, profile, 690);
    }

    function testReadUsesOnlyCachedStorageAndRejectsAnotherCore() public {
        _configureDefault(profile, 500);
        vm.etch(address(factory), hex"00");
        vm.etch(wallet, hex"00");
        (address receiver, uint16 bps) =
            resolver.royaltyReceiverAndBps{ gas: 25_000 }(address(core), 1, 10_000, 1, true);
        require(receiver == wallet && bps == 690, "cached read independent of wallet and factory");
        (receiver, bps) = resolver.royaltyReceiverAndBps(address(0xBAD), 1, 10_000, 1, true);
        require(receiver == address(0) && bps == 0, "foreign Core has no assignment");
        (receiver, bps) = resolver.royaltyReceiverAndBps(address(core), 1, 10_000, 1, false);
        require(receiver == wallet && bps == 500, "authoritative mapping required for collection");
    }

    function testChangedWalletCodeCannotBeAssigned() public {
        vm.etch(wallet, hex"00");
        vm.expectRevert();
        this.configureForTest(0, profile, 500);
        require(!resolver.defaultRoyalty().configured, "wrong wallet never assigned");
    }

    function testCoreFailsSoftForResolverFaultsAndMalformedResponses() public {
        RoyaltyFaultFixture fault = new RoyaltyFaultFixture();
        StreamModuleRegistration memory item = _registerResolver(address(fault));
        _installResolver(item);
        (address receiver, uint256 amount) = core.royaltyInfo(999, 10_000);
        require(receiver == address(0xCAFE) && amount == 500, "valid exact response");
        for (uint8 mode = 1; mode <= 7; ++mode) {
            fault.setMode(mode);
            (receiver, amount) = core.royaltyInfo(999, 10_000);
            require(receiver == address(0) && amount == 0, "actual Core fail-soft");
        }
    }

    function testCoreRequiresPublishedRoyaltyInterfaceBeforePointerInstall() public {
        RoyaltyFaultFixture wrong = new RoyaltyFaultFixture();
        StreamModuleRegistration memory item = _registerResolver(address(wrong));
        wrong.setUnsupported();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, ROYALTY_POINTER, address(wrong)
            )
        );
        this.installResolverForTest(item);
        require(
            StreamCurrentStackPlan.readPointer(core, ROYALTY_POINTER).target == address(resolver),
            "Core rejects changed interface"
        );
    }

    function testBoundRoyaltyCannotChangeWithoutActualProspectiveArtistConsent() public {
        vm.expectRevert();
        this.configureForTest(1, profile, 700);
        require(
            resolver.collectionRoyalty(1).royaltyBps == 690,
            "governance alone cannot overwrite consent"
        );
        _configureBoundWithConsent(profile, 700);
        uint256 tokenId = _mint();
        (address receiver, uint256 amount) = core.royaltyInfo(tokenId, 10_000);
        require(
            receiver == wallet && amount == 700, "actual consent and governance change then mint"
        );
    }

    function configureForTest(uint256 collectionId, bytes32 profileId, uint16 bps) external {
        _configure(collectionId, profileId, bps);
    }

    function freezeForTest(uint256 collectionId) external {
        _freeze(collectionId);
    }

    function installResolverForTest(StreamModuleRegistration calldata item) external {
        _installResolver(item);
    }

    function _configureDefault(bytes32 profileId, uint16 bps) private {
        _configure(0, profileId, bps);
    }

    function _configureUnbound(bytes32 profileId, uint16 bps) private {
        _configure(UNBOUND, profileId, bps);
    }

    function _configure(uint256 collectionId, bytes32 profileId, uint16 bps) private {
        bytes memory data = collectionId == 0
            ? abi.encodeCall(resolver.configureDefaultRoyalty, (profileId, bps))
            : abi.encodeCall(resolver.configureCollectionRoyalty, (collectionId, profileId, bps));
        _executeOwner(1, data);
    }

    function _freeze(uint256 collectionId) private {
        bytes memory data = collectionId == 0
            ? abi.encodeCall(resolver.freezeDefaultRoyalty, ())
            : abi.encodeCall(resolver.freezeCollectionRoyalty, (collectionId));
        _executeOwner(2, data);
    }

    function _configureBoundWithConsent(bytes32 profileId, uint16 bps) private {
        T.AssignmentFact memory fact =
            resolver.previewArtistRoyaltyAssignment(1, profileId, bps, false);
        T.EconomicsConsent memory consent = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        uint256 nonce =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        T.Authorization memory authorization =
            T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        authorization.signature =
            _artistProof(artists.economicsConsentDigest(consent, authorization));
        artists.recordProspectiveEconomicsConsent(
            consent, T.FixedEconomicsCandidate(profileId, bytes32(0), bps, false), authorization
        );
        _configure(1, profileId, bps);
    }

    function _executeOwner(uint8 actionClass, bytes memory data) private {
        GovernanceCall memory call_ = StreamCurrentStackPlan.call(
            address(resolver),
            data,
            keccak256(abi.encode(address(resolver), data)),
            bytes32(0),
            keccak256(data)
        );
        _executeTransition(actionClass, call_, data);
    }

    function _executeTransition(uint8 actionClass, GovernanceCall memory call_, bytes memory data)
        private
    {
        GovernanceActionRequest memory request = GovernanceActionRequest(
            actionClass,
            call_.target,
            call_.value,
            call_.selector,
            data,
            call_.scopeHash,
            call_.oldValueHash,
            call_.newValueHash,
            uint64(block.timestamp + 8 days),
            uint64(block.timestamp + 15 days),
            keccak256("current royalty integration"),
            "urn:6529stream:test:royalty",
            DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
    }

    function _registerResolver(address target)
        private
        returns (StreamModuleRegistration memory item)
    {
        item = StreamModuleRegistration(
            target,
            REVENUE_MODULE,
            keccak256("royalty test"),
            type(IStreamRoyaltyResolver).interfaceId,
            500_000,
            target.codehash,
            DEPLOYMENT_HASH,
            keccak256("royalty fault module"),
            "urn:6529stream:test:royalty-fault"
        );
        StreamModuleRegistration[] memory items = new StreamModuleRegistration[](1);
        items[0] = item;
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, items);
        _executeTransition(1, calls[0], data[0]);
    }

    function _installResolver(StreamModuleRegistration memory item) private {
        StreamCorePointerState memory previous =
            StreamCurrentStackPlan.readPointer(core, ROYALTY_POINTER);
        StreamCorePointerState memory next = StreamCurrentStackPlan.pointerState(
            address(registry), item, false, previous.revision + 1
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            StreamCurrentStackPlan.pointerTransitionHashes(core, ROYALTY_POINTER, previous, next);
        bytes memory data =
            abi.encodeCall(core.updateSatellitePointer, (ROYALTY_POINTER, item.module));
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory callData = new bytes[](2);
        calls[0] = StreamCurrentStackPlan.call(address(core), data, scope, oldState, newState);
        callData[0] = data;
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        current.modules.revenueResolver = item.module;
        (address payload, bytes32 payloadHash) = StreamGenesisManifestPlan.writePayload(
            abi.encode("royalty resolver replacement", item.module)
        );
        StreamSystemManifestUpdate memory discovery = StreamSystemManifestUpdate(
            payloadHash,
            "urn:6529stream:test:royalty-replacement",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (calls[1], callData[1]) = StreamGenesisManifestPlan.publicationCall(
            manifest, payload, discovery, current.modules
        );
        executor.publishGovernanceCallData(callData);
        bytes32 callsHash = StreamGovernanceBootstrap.governanceCallsHash(calls);
        (scope, oldState, newState) =
            StreamGovernanceBootstrap.deriveBatchTransitionHashes(calls, callsHash);
        uint64 notBefore = uint64(block.timestamp + 8 days);
        bytes memory request = abi.encodeCall(
            executor.scheduleGovernanceBatch,
            (
                uint8(3),
                calls,
                scope,
                oldState,
                newState,
                notBefore,
                notBefore + 7 days,
                keccak256("royalty pointer replacement"),
                "urn:6529stream:test:royalty-replacement",
                current.manifestHash
            )
        );
        bytes32 id = abi.decode(governanceRoot.execute(address(executor), 0, request), (bytes32));
        vm.warp(notBefore);
        executor.executeGovernanceBatch(id, calls, callData);
    }

    function _mint() private returns (uint256 tokenId) {
        IStreamMintManager.MintBatch memory batch;
        batch.collectionId = 1;
        batch.phaseId = ROYALTY_PHASE;
        batch.initialRecipients = new address[](1);
        batch.beneficiaries = new address[](1);
        batch.tokenData = new bytes[](1);
        batch.mintCommitments = new bytes32[](1);
        batch.initialRecipients[0] = artist;
        batch.beneficiaries[0] = artist;
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments[0] = keccak256("royalty commitment");
        batch.expectedPolicyHash = manager.phasePolicyHash(1, ROYALTY_PHASE);
        (uint256[] memory ids,,) = manager.executeSingleStepMint(batch, "");
        return ids[0];
    }
}
