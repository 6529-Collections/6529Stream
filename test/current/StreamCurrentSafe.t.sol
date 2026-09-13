// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";

/// @notice Official threshold Safes act as artist, buyer, NFT owner, beneficiary and governor.
/// @dev Uses the actual current protocol topology; only the external entropy service is a double.
contract StreamCurrentSafeTest is StreamCurrentStackFixture, OfficialSafeFixture {
    OfficialSafe private artistSafe;
    OfficialSafe private buyerSafe;
    uint256[] private keys;
    bool private _templateGenesis;
    bytes32 private _genesisTemplate;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 1);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 2);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(buyerSafe), 10 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function testSafeArtistBuyerCustodyApprovalTransferAndRevenueRelease() public {
        _buyRevealTransferAndClaim();
    }

    function _prepareArtistOnboarding() internal override {
        if (!_templateGenesis) return;
        _genesisTemplate = _createArtistTemplate();
        bytes memory data = abi.encodeCall(
            primaryResolver.setPrimaryTemplateAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), _genesisTemplate, bytes32(0))
        );
        GovernanceActionRequest memory request = _request(address(primaryResolver), data);
        bytes memory scheduled = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(scheduled, (bytes32)), data);
    }

    function testSafeArtistTemplateConsentAndPaidMintEscrowFlushAndClaim() public {
        _templateGenesis = true;
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        require(_genesisTemplate != 0, "actual prebinding template");
        artists.requireMintConsent(1, PHASE, manager.phasePolicyHash(1, PHASE));
        (, profile, wallet) = sale.primaryPolicy(1);
        require(
            !factory.profileExists(profile) && wallet.code.length == 0,
            "preview does not register or deploy"
        );
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization =
            _safeSaleAuthorization();
        bytes32 digest = sale.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(sale),
                authorization.price,
                abi.encodeCall(
                    sale.buy,
                    (authorization, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest))
                ),
                0
            ),
            "Safe template mint"
        );
        uint256 tokenId = core.lastAllocatedTokenId();
        require(
            core.ownerOf(tokenId) == address(buyerSafe) && core.collectionMintedEver(1) == 1,
            "actual Core Safe custody"
        );
        require(
            factory.profileExists(profile) && !factory.splitWalletExists(profile)
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == authorization.price && sale.totalNativeProceeds() == authorization.price,
            "exact template escrow funded before mint"
        );
        _assertTemplateRights(profile, address(artistSafe));
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(factory),
                0,
                abi.encodeCall(factory.deployWallet, (profile)),
                0
            ),
            "Safe deploys registered wallet"
        );
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(revenueEscrow),
                0,
                abi.encodeCall(
                    revenueEscrow.flushToVerifiedWalletBestEffort,
                    (PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                ),
                0
            ),
            "Safe flushes exact owed destination"
        );
        require(
            wallet.balance == authorization.price && revenueEscrow.totalOwed(address(0)) == 0,
            "escrow delivered exactly once"
        );
        require(
            executeSafe(
                artistSafe,
                keys,
                wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(artistSafe), payable(address(artistSafe)))
                ),
                0
            ),
            "Safe claims actual template share"
        );
        require(
            address(artistSafe).balance == 0.009 ether && wallet.balance == 0.001 ether,
            "template artist and protocol shares"
        );
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("Safe template mint entropy"));
        (, bool finalized) = entropy.tokenSeed(tokenId);
        require(
            finalized && bytes(core.tokenURI(tokenId)).length != 0,
            "actual entropy and metadata complete"
        );
    }

    function testSafeMaterializesActualArtistTemplateAndPayoutChangesPreserveOldRights() public {
        bytes32 templateId = _createArtistTemplate();
        (bytes32 entriesHash, bytes32 metadataHash, uint32 artistShare) =
            primaryResolver.primaryTemplateEconomicsFacts(templateId);
        require(
            entriesHash != 0 && metadataHash == keccak256("Safe artist template")
                && artistShare == 900_000,
            "actual immutable template facts"
        );

        (bytes32 originalProfile, address originalWallet) =
            _materializeTemplateAsSafe(templateId, false);
        _assertTemplateRights(originalProfile, address(artistSafe));
        (bytes32 deployedProfile, address deployedWallet) =
            _materializeTemplateAsSafe(templateId, true);
        require(
            deployedProfile == originalProfile && deployedWallet == originalWallet,
            "deployment preserves registered rights"
        );

        (, bytes32 previousRecord) =
            IStreamArtistPayoutOwner(artistSuite.owners[5]).artistPayoutAccount(fixtureArtistId);
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(fixtureArtistId, address(buyerSafe), previousRecord);
        T.Authorization memory authorization = _safeArtistAuthorization();
        authorization.time = 0; // Direct Safe call records the actual inclusion time.
        require(
            executeSafe(
                artistSafe,
                keys,
                address(artists),
                0,
                abi.encodeCall(artists.recordPayoutDesignation, (payout, authorization)),
                0
            ),
            "Safe changes explicit payout"
        );
        (bytes32 currentArtist, address currentPayout, bytes32 record) =
            artists.collectionArtistBeneficiary(1);
        require(
            currentArtist == fixtureArtistId && currentPayout == address(buyerSafe) && record != 0
                && record != previousRecord,
            "actual beneficiary read reflects designation"
        );

        (bytes32 nextProfile, address nextWallet) = _materializeTemplateAsSafe(templateId, false);
        require(
            nextProfile != originalProfile && nextWallet != originalWallet,
            "new recipient has new immutable rights"
        );
        _assertTemplateRights(nextProfile, address(buyerSafe));
        _assertTemplateRights(originalProfile, address(artistSafe));
        require(factory.splitWalletExists(originalProfile), "old wallet remains deployed");
    }

    function _createArtistTemplate() private returns (bytes32 templateId) {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 900_000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            PROTOCOL, bytes32(0), 100_000, keccak256("protocol")
        );
        bytes memory data = abi.encodeCall(
            primaryResolver.createPrimaryTemplate, (entries, keccak256("Safe artist template"))
        );
        GovernanceActionRequest memory request = _request(address(primaryResolver), data);
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        vm.recordLogs();
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("PrimaryTemplateCreated(bytes32,bytes32,bytes32,uint16,uint16)");
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(primaryResolver) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(templateId == 0, "one template created");
                templateId = logs[i].topics[1];
            }
        }
        require(templateId != 0, "governed template creation observed");
    }

    function _materializeTemplateAsSafe(bytes32 templateId, bool deployWallet)
        private
        returns (bytes32 profileId, address targetWallet)
    {
        bytes memory transactionData = abi.encodeCall(
            primaryResolver.materializeCollectionPrimaryProfile,
            (templateId, uint256(1), address(0), deployWallet)
        );
        bytes32 expectedSafeHash = buyerSafe.getTransactionHash(
            address(primaryResolver),
            0,
            transactionData,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            buyerSafe.nonce()
        );
        vm.recordLogs();
        require(
            executeSafe(buyerSafe, keys, address(primaryResolver), 0, transactionData, 0),
            "Safe materialization executes"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "CollectionTemplateMaterialized(bytes32,bytes32,uint256,uint16,bytes32,address,bytes32,address,bytes32,bool)"
        );
        bool safeSuccess;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(buyerSafe) && logs[i].topics.length == 2
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
                    && logs[i].topics[1] == expectedSafeHash && logs[i].data.length == 32
                    && abi.decode(logs[i].data, (uint256)) == 0
            ) {
                safeSuccess = true;
            }
            if (
                logs[i].emitter == address(primaryResolver) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(
                    profileId == 0 && logs[i].topics[1] == templateId
                        && uint256(logs[i].topics[3]) == 1,
                    "one exact collection materialization"
                );
                profileId = logs[i].topics[2];
            }
        }
        require(
            safeSuccess && profileId != 0 && factory.profileExists(profileId),
            "Safe event and protocol state agree"
        );
        targetWallet = factory.walletFor(profileId);
        require(
            factory.splitWalletExists(profileId) == deployWallet,
            "registration and actual deployment distinguished"
        );
    }

    function _assertTemplateRights(bytes32 profileId, address payee) private view {
        require(factory.profileEntryCount(profileId) == 2, "two explicit recipients");
        uint256 matched;
        for (uint256 i; i < 2; ++i) {
            (address account, uint32 shares, bytes32 label) = factory.profileEntry(profileId, i);
            if (account == payee && shares == 900_000 && label == keccak256("artist")) {
                matched |= 1;
            }
            if (account == PROTOCOL && shares == 100_000 && label == keccak256("protocol")) {
                matched |= 2;
            }
        }
        require(matched == 3, "canonical profile retains exact artist and protocol shares");
    }

    function _safeSaleAuthorization()
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory)
    {
        return IStreamFixedPriceSaleAdapter.SaleAuthorization({
            collectionId: 1,
            phaseId: PHASE,
            payer: address(buyerSafe),
            recipient: address(buyerSafe),
            artist: address(artistSafe),
            profileId: profile,
            expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
            tokenDataHash: keccak256(TOKEN_DATA),
            mintCommitment: keccak256("Safe current artwork"),
            mintPolicyHash: manager.phasePolicyHash(1, PHASE),
            price: 0.01 ether,
            nonce: keccak256("Safe current mint"),
            deadline: uint64(block.timestamp + 1 days),
            signerEpoch: sale.signerEpoch()
        });
    }

    function _buyRevealTransferAndClaim() private {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _safeSaleAuthorization();
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(sale),
                a.price,
                abi.encodeCall(
                    sale.buy, (a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest))
                ),
                0
            ),
            "Safe purchase execution"
        );
        uint256 tokenId = core.lastAllocatedTokenId();
        require(
            core.ownerOf(tokenId) == address(buyerSafe) && core.collectionMintedEver(1) == 1,
            "Safe NFT custody"
        );
        require(
            wallet.balance == a.price && sale.authorizationUsed(address(artistSafe), a.nonce),
            "Safe paid mint accounting"
        );
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("Safe mint entropy"));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(tokenId);
        require(finalized && seed != bytes32(0), "Safe token entropy finalized");
        require(
            keccak256(bytes(core.tokenURI(tokenId)))
                == keccak256(bytes(router.tokenURI(address(core), tokenId))),
            "Safe token uses actual metadata router"
        );
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(core),
                0,
                abi.encodeWithSignature("setApprovalForAll(address,bool)", SECOND_OWNER, true),
                0
            ),
            "Safe operator approval"
        );
        require(core.isApprovedForAll(address(buyerSafe), SECOND_OWNER), "Safe approval result");
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(core),
                0,
                abi.encodeWithSignature(
                    "safeTransferFrom(address,address,uint256,bytes)",
                    address(buyerSafe),
                    address(artistSafe),
                    tokenId,
                    bytes("Safe custody")
                ),
                0
            ),
            "Safe NFT transfer"
        );
        require(core.ownerOf(tokenId) == address(artistSafe), "recipient Safe received NFT");
        require(
            executeSafe(
                artistSafe,
                keys,
                wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(artistSafe), payable(address(artistSafe)))
                ),
                0
            ),
            "Safe release execution"
        );
        require(
            address(artistSafe).balance == 0.009 ether && wallet.balance == 0.001 ether,
            "Safe revenue balance"
        );
    }

    function testSafeArtistEconomicsGovernedReplacementAndDefensiveFreezeKeepMintEligible() public {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(PROTOCOL, 100_000, keccak256("protocol"));
        (bytes32 nextProfile, address nextWallet) =
            factory.createProfile(entries, keccak256("Safe replacement economics"));
        T.AssignmentFact memory primaryCandidate =
            primaryResolver.previewArtistPrimaryAssignment(1, nextProfile, bytes32(0), false);
        bytes32 oldPrimaryHash =
            primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash;
        bytes memory data = abi.encodeCall(
            primaryResolver.setPrimaryProfileAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), nextProfile, bytes32(0))
        );
        GovernanceActionRequest memory request = _request(address(primaryResolver), data);
        bytes memory scheduled = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        bytes32 actionId = abi.decode(scheduled, (bytes32));
        vm.warp(request.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        executor.executeGovernanceAction(actionId, data);
        require(
            primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash
                == oldPrimaryHash,
            "governance changed economics without artist consent"
        );
        _safeProspectiveConsent(
            primaryCandidate, T.FixedEconomicsCandidate(nextProfile, bytes32(0), 0, false)
        );
        executor.executeGovernanceAction(actionId, data);
        require(
            primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash
                == primaryCandidate.assignmentHash,
            "governed replacement differs from artist approval"
        );

        IStreamRoyaltyResolver.RoyaltyConfig memory priorRoyalty = royalties.collectionRoyalty(1);
        T.AssignmentFact memory frozenCandidate = royalties.previewArtistRoyaltyAssignment(
            1, priorRoyalty.profileId, priorRoyalty.royaltyBps, true
        );
        _safeProspectiveConsent(
            frozenCandidate,
            T.FixedEconomicsCandidate(
                priorRoyalty.profileId, bytes32(0), priorRoyalty.royaltyBps, true
            )
        );
        bytes32 liveRoyaltyHash = royalties.currentArtistRoyaltyAssignment(1).assignmentHash;
        T.RoyaltyFreeze memory freeze =
            T.RoyaltyFreeze(address(royalties), 1, keccak256("ROYALTY_ERC2981"), liveRoyaltyHash);
        require(
            executeSafe(
                artistSafe,
                keys,
                address(artists),
                0,
                abi.encodeCall(
                    IStreamArtistEconomicsAuthority.authorizeArtistRoyaltyFreeze,
                    (freeze, _safeArtistAuthorization())
                ),
                0
            ),
            "Safe artist freeze authorization"
        );
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(royalties),
                0,
                abi.encodeCall(royalties.applyArtistRoyaltyFreeze, (1, liveRoyaltyHash)),
                0
            ),
            "permissionless Safe royalty freeze application"
        );
        IStreamRoyaltyResolver.RoyaltyConfig memory frozen = royalties.collectionRoyalty(1);
        require(
            frozen.frozen && frozen.profileId == priorRoyalty.profileId
                && frozen.wallet == priorRoyalty.wallet
                && frozen.royaltyBps == priorRoyalty.royaltyBps
                && royalties.currentArtistRoyaltyAssignment(1).assignmentHash
                    == frozenCandidate.assignmentHash,
            "royalty freeze changed terms or commitment"
        );
        artists.requireMintConsent(1, PHASE, manager.phasePolicyHash(1, PHASE));
        profile = nextProfile;
        wallet = nextWallet;
        _buyRevealTransferAndClaim();
    }

    function _safeProspectiveConsent(
        T.AssignmentFact memory fact,
        T.FixedEconomicsCandidate memory candidate
    ) private {
        T.EconomicsConsent memory consent = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        require(
            executeSafe(
                artistSafe,
                keys,
                address(artists),
                0,
                abi.encodeCall(
                    IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent,
                    (consent, candidate, _safeArtistAuthorization())
                ),
                0
            ),
            "Safe prospective economics consent"
        );
    }

    function _safeArtistAuthorization() private view returns (T.Authorization memory) {
        uint256 nonce =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        return T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
    }

    function testSafeGovernorSchedulesAndExecutesActualFactoryGasRaise() public {
        (address previous, bytes32 previousHash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(buyerSafe), address(buyerSafe).codehash)
        );
        GovernanceActionRequest memory request = _request(address(executor), data);
        request.actionClass = 3;
        request.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"), block.chainid, address(executor)
            )
        );
        request.oldValueHash = _rootState(previous, previousHash, revision);
        request.newValueHash =
            _rootState(address(buyerSafe), address(buyerSafe).codehash, revision + 1);
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
        (address governor,,) = executor.governanceRootState();
        require(governor == address(buyerSafe), "actual Safe governor");
        bytes32 id = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
        (uint256 value, uint256 floor, uint8 failureClass, uint64 gasRevision) =
            factory.gasParameterInfo(id);
        require(value != 0, "registered verification budget");
        data = abi.encodeCall(factory.raiseGasParameter, (id, value * 2));
        // A Safe owner has no direct host authority; only the actual Executor may mutate the value.
        vm.prank(address(buyerSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(buyerSafe)
            )
        );
        factory.raiseGasParameter(id, value * 2);
        request = _request(address(factory), data);
        request.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(factory), id
            )
        );
        request.oldValueHash = _gasState(request.scopeHash, value, floor, failureClass, gasRevision);
        request.newValueHash =
            _gasState(request.scopeHash, value * 2, floor, failureClass, gasRevision + 1);
        vm.recordLogs();
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(executor),
                0,
                abi.encodeCall(executor.scheduleGovernanceAction, (request)),
                0
            ),
            "Safe governance schedule"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 actionId;
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) actionId = logs[i].topics[1];
        }
        require(actionId != bytes32(0), "scheduled action event");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                actionId,
                request.notBefore
            )
        );
        executor.executeGovernanceAction(actionId, data);
        require(factory.gasParameter(id) == value, "timelock preserved");
        vm.warp(request.notBefore);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(executor),
                0,
                abi.encodeCall(executor.executeGovernanceAction, (actionId, data)),
                0
            ),
            "Safe governance execution"
        );
        require(factory.gasParameter(id) == value * 2, "real governed host updated");
    }

    function _request(address target, bytes memory data)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        return GovernanceActionRequest(
            1,
            target,
            0,
            selector,
            data,
            bytes32(0),
            bytes32(0),
            bytes32(0),
            uint64(block.timestamp + 48 hours),
            uint64(block.timestamp + 9 days),
            keccak256("Safe governance test"),
            "urn:6529stream:fixture:safe-governance",
            DEPLOYMENT_HASH
        );
    }

    function _rootState(address root, bytes32 hash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                root,
                hash,
                revision
            )
        );
    }

    function _gasState(
        bytes32 scope,
        uint256 value,
        uint256 floor,
        uint8 failureClass,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_STATE_V2"),
                scope,
                value,
                floor,
                failureClass,
                revision
            )
        );
    }
}
