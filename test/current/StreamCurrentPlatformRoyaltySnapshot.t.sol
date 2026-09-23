// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeEnglishAuctionFixture.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol";

interface PlatformSnapshotVm {
    function expectCall(address, bytes calldata, uint64) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @dev Explicit Artist state boundary. The separate Artist suite executes real declaration/correction.
contract PlatformSnapshotArtist is IStreamArtistAttribution {
    address public immutable override core;
    address public immutable mintManager;
    NativeAuctionArtist private immutable baseline;
    PW.State private _platform;
    uint8 private _mode = 3;
    address public royalty;
    bytes32 public approval;

    constructor(address c, address m) {
        core = c;
        mintManager = m;
        baseline = new NativeAuctionArtist(c, m);
    }

    function accept(address value) external {
        baseline.accept(value);
    }

    function setConsent(bool value) external {
        baseline.setConsent(value);
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return id == type(IStreamArtistPlatformWorks).interfaceId || baseline.supportsInterface(id);
    }

    function acceptedArtist(uint256 id) external view returns (address) {
        return id == 2 && _mode == 3 ? address(0) : baseline.acceptedArtist(id);
    }

    function attribution(uint256 id)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        if (id != 2 || _mode != 3) return baseline.attribution(id);
    }

    function collectionArtistState(uint256 id)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return baseline.collectionArtistState(id);
    }

    function consentMode(uint256 id) external view returns (uint8) {
        return id == 2 ? _mode : 1;
    }

    function isPolicyConsented(uint256 id, bytes32, bytes32 h)
        external
        view
        returns (bool, bytes32)
    {
        if (id == 2 && _mode == 3) {
            return (_allowed(), _platform.declaration.recordHash);
        }
        return (true, keccak256(abi.encode("fixture policy", h)));
    }

    function requireMintConsent(uint256 id, bytes32, bytes32) external view {
        if (id == 2) {
            require(_mode == 3 ? _allowed() : approval != 0, "typed current mint admission");
        }
    }
    function requireSaleConsent(uint256, bytes32, bytes32) external pure { }

    function requireEconomicsConsent(uint256 id, bytes32, uint8 scope, uint256 scopeId, bytes32 h)
        external
        view
    {
        if (id == 2) {
            require(
                _mode != 3 && msg.sender == royalty && scope == 1 && scopeId == 2 && h == approval
                    && h != 0,
                "exact corrected Artist approval; never platform op15"
            );
        }
    }

    function declare() external {
        require(
            _platform.declaration.recordHash == 0
                && !StreamMintManager(mintManager).hasRegisteredPhasePolicy(2),
            "pre-phase declaration"
        );
        bytes32 statement = keccak256("typed platform declaration");
        _platform.declaration = PW.Declaration(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),
                    block.chainid,
                    address(this),
                    core,
                    uint256(2),
                    statement,
                    uint64(block.timestamp)
                )
            ),
            statement,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function contest(uint8 state) external {
        _platform.contestState = state;
        _platform.contestClaim = state == 0 ? bytes32(0) : keccak256("typed claim");
        _platform.contestRecord =
            state == 0 ? bytes32(0) : keccak256(abi.encode("typed contest", state));
    }

    function correct(uint64 generation, bool accepted) external {
        _platform.correction.correctiveGeneration = generation;
        _platform.correction.accepted = accepted;
        _platform.correction.approvalActionId = keccak256("typed correction action");
        _platform.correction.recordHash = keccak256("typed correction");
        _mode = accepted ? 1 : 3;
    }

    function approve(address r, bytes32 h) external {
        royalty = r;
        approval = h;
    }

    function platformWorksState(uint256) external view returns (PW.State memory) {
        return _platform;
    }

    function platformWorksDeclaration(uint256) external view returns (bool, bytes32, uint64) {
        return (
            _platform.declaration.recordHash != 0,
            _platform.declaration.recordHash,
            _platform.declaration.declaredAt
        );
    }

    function platformWorksContest(uint256) external view returns (uint8, bytes32) {
        return (_platform.contestState, _platform.contestClaim);
    }

    function platformWorksCorrection(uint256) external view returns (uint64, bytes32) {
        return (_platform.correction.correctiveGeneration, _platform.correction.approvalActionId);
    }

    function _allowed() private view returns (bool) {
        return _platform.declaration.recordHash != 0
            && (_platform.contestState == 0 || _platform.contestState == 2)
            && _platform.correction.correctiveGeneration == 0;
    }
}

    contract PlatformSnapshotReceiver is IERC721Receiver {
        StreamRoyaltyResolver public immutable royalty;
        address public immutable core;
        uint256 public rejectToken;
        uint256 public observed;
        PlatformSnapshotArtist public contestTarget;

        constructor(StreamRoyaltyResolver r, address c) {
            royalty = r;
            core = c;
        }

        function reject(uint256 token) external {
            rejectToken = token;
        }

        function contestDuringDelivery(PlatformSnapshotArtist target) external {
            contestTarget = target;
        }

        function onERC721Received(address operator, address, uint256 token, bytes calldata)
            external
            returns (bytes4)
        {
            IStreamRoyaltySnapshot.Snapshot memory s = royalty.royaltySnapshot(token);
            require(
                msg.sender == core && s.exists && s.collectionId == 2 && s.manager == operator
                    && royalty.tokenRoyalty(token).frozen,
                "snapshot before actual token delivery"
            );
            require(token != rejectToken, "late receiver rejection");
            ++observed;
            if (address(contestTarget) != address(0)) contestTarget.contest(1);
            return IERC721Receiver.onERC721Received.selector;
        }
    }

    /// @dev Actual Core/Manager/Ledger/Resolver/Factory/Safe; typed Artist/entropy/governance.
    contract StreamCurrentPlatformRoyaltySnapshotTest is NativeEnglishAuctionFixture {
        PlatformSnapshotArtist private platform;
        StreamRoyaltyResolver private royalty;
        IStreamRoyaltySnapshot.Source private original;
        bytes32 private constant PLATFORM_PHASE = keccak256("platform snapshot prepared");
        PlatformSnapshotVm private constant check =
            PlatformSnapshotVm(address(uint160(uint256(keccak256("hevm cheat code")))));

        function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
            platform = new PlatformSnapshotArtist(address(core), address(manager));
            return NativeAuctionArtist(address(platform));
        }

        function setUp() public override {
            super.setUp();
            bytes32 scope = keccak256(
                abi.encode(
                    bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                    block.chainid,
                    address(core),
                    uint256(2)
                )
            );
            bytes32 domain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
            _context(
                scope,
                keccak256(abi.encode(domain, scope, false, uint8(0), uint8(0), false, uint256(0))),
                keccak256(abi.encode(domain, scope, true, uint8(2), uint8(0), false, uint256(0))),
                1
            );
            vm.prank(address(revenueAuthority));
            require(core.createCollection(2, false, 0, 0) == 2, "actual second collection");
            _clearContext();
            platform.declare();
            royalty = new StreamRoyaltyResolver(core, factory, address(revenueAuthority), artists);
            vm.prank(address(revenueAuthority));
            royalty.transferOwnership(address(this));
            _register(
                address(ledger),
                keccak256("MINT_LEDGER"),
                type(IStreamMintLedger).interfaceId,
                MANIFEST
            );
            _pointer(keccak256("MINT_LEDGER"), address(ledger));
            _register(
                address(royalty),
                keccak256("REVENUE_RESOLVER"),
                type(IStreamRoyaltyResolver).interfaceId,
                MANIFEST
            );
            _pointer(keccak256("ROYALTY_RESOLVER"), address(royalty));
            royalty.electCollectionRoyaltyMode(2, 2);
            royalty.configureCollectionRoyalty(2, profile, 350);
            original = royalty.currentRoyaltySnapshotSource(2);
            _phase(address(this));
        }

        function _phase(address executor) private {
            IStreamMintRoyaltyPolicy.Policy memory p = IStreamMintRoyaltyPolicy.Policy(
                true,
                MANIFEST,
                address(royalty),
                address(royalty).codehash,
                original.electionHash,
                original.modeAssignmentHash,
                original.sourceRoyaltyPolicyHash
            );
            bytes32 wrapped = manager.registerPhaseRoyaltyPolicy(2, PLATFORM_PHASE, p);
            IStreamMintManager.MintGateConfig memory gate;
            bytes32[] memory ids = new bytes32[](1);
            ids[0] = keccak256("platform supply");
            IStreamMintManager.MintCounterConfig[] memory counts =
                new IStreamMintManager.MintCounterConfig[](1);
            counts[0] = IStreamMintManager.MintCounterConfig(
                true,
                IStreamMintManager.CounterKeyMode.CONSTANT,
                IStreamMintLedger.CounterCapMode.STATIC,
                IStreamMintLedger.CounterDeltaMode.STATIC,
                20,
                1,
                keccak256("platform supply config")
            );
            manager.configurePhase(
                2,
                PLATFORM_PHASE,
                IStreamMintManager.MintPhaseConfig(false, 0, 0, 2, wrapped, MANIFEST),
                gate,
                ids,
                counts
            );
            manager.setPhaseExecutor(2, PLATFORM_PHASE, executor, true);
        }

        function _batch(address to, uint256 quantity, bytes32 authorization)
            private
            view
            returns (IStreamMintManager.MintBatch memory b)
        {
            b.collectionId = 2;
            b.phaseId = PLATFORM_PHASE;
            b.payer = payer;
            b.initialRecipients = new address[](quantity);
            b.beneficiaries = new address[](quantity);
            b.tokenData = new bytes[](quantity);
            b.mintCommitments = new bytes32[](quantity);
            for (uint256 i; i < quantity; ++i) {
                b.initialRecipients[i] = to;
                b.beneficiaries[i] = payer;
                b.tokenData[i] = abi.encode("platform snapshot", i);
                b.mintCommitments[i] = keccak256(abi.encode("platform", i));
            }
            b.expectedPolicyHash = manager.phasePolicyHash(2, PLATFORM_PHASE);
            b.authorizationId = authorization;
        }

        function testPlatformPreparedBatchPreservesOriginalHashesAndCanonicalReceipt() public {
            require(
                manager.hasRegisteredPhasePolicy(2) && platform.acceptedArtist(2) == address(0),
                "actual mode3 registration without Artist"
            );
            StreamArtistOnboardingTypes.AssignmentFact memory raw =
                royalty.previewArtistRoyaltyAssignmentForScope(2, 1, 2, profile, 350, false);
            require(
                raw.assignmentHash == original.sourceAssignmentHash
                    && original.sourceRoyaltyPolicyHash
                        == keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ROYALTY_POLICY_V1"),
                                block.chainid,
                                address(royalty),
                                uint256(2),
                                uint256(0),
                                profile,
                                wallet,
                                uint16(350),
                                raw.assignmentHash
                            )
                        ),
                "canonical scope1 policy unchanged"
            );
            require(
                original.modeAssignmentHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"),
                            block.chainid,
                            address(royalty),
                            address(core),
                            uint256(2),
                            original.electionHash,
                            raw.assignmentHash
                        )
                    ),
                "original mode preimage"
            );
            PlatformSnapshotReceiver receiver = new PlatformSnapshotReceiver(royalty, address(core));
            vm.recordLogs();
            (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) = manager.executePreparedMint(
                _batch(address(receiver), 2, keccak256("platform batch")), ""
            );
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 count;
            for (uint256 n; n < logs.length; ++n) {
                if (
                    logs[n].emitter != address(royalty)
                        || logs[n].topics[0]
                            != keccak256(
                                "TokenRoyaltySnapshotted(uint16,bytes32,uint256,bytes32,uint256,bytes32,bytes32)"
                            )
                ) continue;
                IStreamRoyaltySnapshot.Snapshot memory saved = royalty.royaltySnapshot(
                    tokens[count]
                );
                require(
                    saved.exists && saved.operationRoot == root && saved.operationId == ids[count]
                        && saved.sourceAssignmentHash == original.sourceAssignmentHash
                        && saved.modeAssignmentHash == original.modeAssignmentHash
                        && saved.manager == address(manager) && saved.collectionId == 2,
                    "full original provenance"
                );
                require(
                    logs[n].topics.length == 4 && logs[n].topics[1] == ids[count]
                        && uint256(logs[n].topics[2]) == tokens[count] && logs[n].topics[3] == root
                        && keccak256(logs[n].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    uint256(2),
                                    keccak256("ROYALTY_ERC2981"),
                                    saved.tokenRoyaltyPolicyHash
                                )
                            ),
                    "original indexed event and payload"
                );
                ++count;
            }
            require(
                count == 2 && receiver.observed() == 2 && core.collectionNextSerial(2) == 3
                    && ledger.isManagerOperationRootUsed(address(manager), root),
                "two real completed snapshots"
            );
        }

        function testPlatformSafeSecondDeliveryFailureRollsBackAndIdenticalCallRetries() public {
            uint256[] memory keys = new uint256[](2);
            keys[0] = 0x5121;
            keys[1] = 0x5122;
            OfficialSafe account =
                createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 5123);
            manager.setPhaseExecutor(2, PLATFORM_PHASE, address(account), true);
            PlatformSnapshotReceiver receiver = new PlatformSnapshotReceiver(royalty, address(core));
            receiver.reject(2);
            IStreamMintManager.MintBatch memory b =
                _batch(address(receiver), 2, keccak256("same platform Safe"));
            bytes memory input = abi.encodeCall(manager.executePreparedMint, (b, bytes("")));
            bytes32 digest = account.getTransactionHash(
                address(manager), 0, input, 0, 0, 0, 0, address(0), address(0), account.nonce()
            );
            bytes memory exact = abi.encodeCall(
                OfficialSafe.execTransaction,
                (
                    address(manager),
                    uint256(0),
                    input,
                    uint8(0),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    address(0),
                    payable(address(0)),
                    safeThresholdSignature(keys, digest)
                )
            );
            // One callback on each attempt proves that the first failure is the second delivery.
            check.expectCall(
                address(receiver),
                abi.encodePacked(
                    IERC721Receiver.onERC721Received.selector,
                    abi.encode(address(manager), address(0), uint256(2))
                ),
                uint64(2)
            );
            (bool ok,) = address(account).call(exact);
            require(
                !ok && account.nonce() == 0 && receiver.observed() == 0
                    && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(2) == 1
                    && manager.nextOperationNonce() == 0
                    && !manager.isAuthorizationUsed(b.authorizationId)
                    && !royalty.royaltySnapshot(1).exists && !royalty.royaltySnapshot(2).exists,
                "whole real graph and Safe rollback"
            );
            receiver.reject(0);
            (ok,) = address(account).call(exact);
            require(
                ok && account.nonce() == 1 && receiver.observed() == 2
                    && core.ownerOf(2) == address(receiver),
                "identical original Safe bytes retry"
            );
            (ok,) = address(account).call(exact);
            require(!ok && core.lastAllocatedTokenId() == 2, "original replay remains closed");
        }

        function testContestDismissalCorrectionAndHistoricalDisclosureStayDistinct() public {
            bytes memory exact = abi.encodeCall(
                manager.executePreparedMint,
                (_batch(payer, 1, keccak256("contested platform")), bytes(""))
            );
            platform.contest(1);
            (bool ok,) = address(manager).call(exact);
            require(
                !ok && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0,
                "open contest before effects"
            );
            platform.contest(2);
            (ok,) = address(manager).call(exact);
            require(ok && core.ownerOf(1) == payer, "dismissal restores original authorization");
            platform.contest(3);
            (ok,) = address(royalty)
                .staticcall(abi.encodeCall(royalty.currentRoyaltySnapshotSource, (uint256(2))));
            require(!ok, "sustained source blocked");
            platform.correct(1, false);
            (ok,) = address(royalty)
                .staticcall(abi.encodeCall(royalty.currentRoyaltySnapshotSource, (uint256(2))));
            require(!ok, "unaccepted correction blocked");
            platform.correct(1, true);
            (ok,) = address(royalty)
                .staticcall(abi.encodeCall(royalty.currentRoyaltySnapshotSource, (uint256(2))));
            require(!ok, "old declaration cannot replace corrected Artist consent");
            platform.approve(address(royalty), original.modeAssignmentHash);
            require(
                royalty.currentRoyaltySnapshotSource(2).modeAssignmentHash
                    == original.modeAssignmentHash,
                "exact corrected Artist path"
            );
            check.mockCallRevert(address(platform), bytes(""), bytes("authority unavailable"));
            (address receiver, uint16 bps) =
                royalty.royaltyReceiverAndBps(address(core), 1, 1000, 2, true);
            require(
                receiver == wallet && bps == 350 && royalty.tokenRoyalty(1).frozen,
                "historical snapshot remains storage-only"
            );
            check.clearMockedCalls();
        }

        function testDeliveryCallbackContestRollsBackMintAndIdenticalOriginalCallRetries() public {
            PlatformSnapshotReceiver receiver = new PlatformSnapshotReceiver(royalty, address(core));
            receiver.contestDuringDelivery(platform);
            bytes memory exact = abi.encodeCall(
                manager.executePreparedMint,
                (_batch(address(receiver), 1, keccak256("platform callback contest")), bytes(""))
            );
            check.expectCall(
                address(receiver),
                abi.encodePacked(
                    IERC721Receiver.onERC721Received.selector,
                    abi.encode(address(manager), address(0), uint256(1))
                ),
                uint64(2)
            );
            (bool ok,) = address(manager).call(exact);
            require(
                !ok && receiver.observed() == 0 && core.lastAllocatedTokenId() == 0
                    && manager.nextOperationNonce() == 0 && !royalty.royaltySnapshot(1).exists
                    && platform.platformWorksState(2).contestState == 0,
                "post-completion current admission rejects callback change atomically"
            );
            receiver.contestDuringDelivery(PlatformSnapshotArtist(address(0)));
            (ok,) = address(manager).call(exact);
            require(
                ok && receiver.observed() == 1 && core.ownerOf(1) == address(receiver)
                    && royalty.royaltySnapshot(1).exists,
                "original source and mint authorization retry unchanged"
            );
        }

        /// @dev Selected Manager impersonation retains an actual prepared Core/Ledger window;
        ///      this case exercises Resolver admission/idempotence, not another Manager transcript.
        function testPlatformPendingProofNoopStillRequiresCurrentDeclarationAdmission() public {
            bytes32 root = keccak256("controlled platform root");
            bytes32 operation = keccak256("controlled platform operation");
            bytes32 policy = manager.phasePolicyHash(2, PLATFORM_PHASE);
            IStreamMintLedger.CounterConsumption[] memory counters =
                new IStreamMintLedger.CounterConsumption[](0);
            bytes32[] memory nullifiers = new bytes32[](0);
            vm.prank(address(manager));
            ledger.consume(
                2,
                PLATFORM_PHASE,
                counters,
                keccak256("platform proof authorization"),
                nullifiers,
                policy,
                root
            );
            bytes memory data = bytes("controlled platform prepared window");
            vm.prank(address(manager));
            (uint256 token, uint256 serial) =
                core.prepareMintFromManager(2, data, keccak256(data), operation);
            require(token == 1 && serial == 1, "actual pending Core identity");
            bytes memory exact = abi.encodeCall(
                royalty.snapshotTokenRoyaltyAtMint,
                (
                    token,
                    uint256(2),
                    root,
                    operation,
                    keccak256("ROYALTY_ERC2981"),
                    original.sourceRoyaltyPolicyHash
                )
            );
            vm.prank(address(manager));
            (bool ok, bytes memory returned) = address(royalty).call(exact);
            require(ok, "first snapshot");
            bytes32 saved =
                keccak256(abi.encode(royalty.royaltySnapshot(token), royalty.tokenRoyalty(token)));
            platform.contest(1);
            vm.prank(address(manager));
            (ok,) = address(royalty).call(exact);
            require(
                !ok
                    && saved
                        == keccak256(
                            abi.encode(royalty.royaltySnapshot(token), royalty.tokenRoyalty(token))
                        ),
                "saved zero-delta snapshot cannot mask lost current admission"
            );
            platform.contest(2);
            vm.recordLogs();
            vm.prank(address(manager));
            (ok, data) = address(royalty).call(exact);
            require(
                ok && keccak256(data) == keccak256(returned) && vm.getRecordedLogs().length == 0
                    && saved
                        == keccak256(
                            abi.encode(royalty.royaltySnapshot(token), royalty.tokenRoyalty(token))
                        ),
                "same proof after dismissal is silent and identical"
            );
            vm.prank(address(manager));
            core.completePreparedMintFromManager(
                token, payer, operation, keccak256("platform proof commitment")
            );
            vm.prank(address(manager));
            (ok,) = address(royalty).call(exact);
            require(!ok && core.ownerOf(token) == payer, "completed proof never reopens snapshot");
        }

        function testMalformedAdvertisedPlatformFactsAndUnauthorizedMutationReject() public {
            vm.prank(address(0xBAD));
            (bool ok,) = address(royalty)
                .call(
                    abi.encodeCall(
                        royalty.configureCollectionRoyalty, (uint256(2), profile, uint16(400))
                    )
                );
            require(
                !ok && royalty.collectionRoyalty(2).royaltyBps == 350, "original owner authority"
            );
            PW.State memory p = platform.platformWorksState(2);
            p.declaration.statementHash = keccak256("substituted statement");
            check.mockCall(
                address(platform),
                abi.encodeCall(IStreamArtistPlatformWorks.platformWorksState, (uint256(2))),
                abi.encode(p)
            );
            (ok,) = address(royalty)
                .staticcall(abi.encodeCall(royalty.currentRoyaltySnapshotSource, (uint256(2))));
            require(!ok, "declaration preimage independently reconstructed");
            check.clearMockedCalls();
            check.mockCallRevert(
                address(platform),
                abi.encodeCall(IStreamArtistPlatformWorks.platformWorksDeclaration, (uint256(2))),
                bytes("advertised read unavailable")
            );
            (ok,) = address(royalty)
                .staticcall(abi.encodeCall(royalty.currentRoyaltySnapshotSource, (uint256(2))));
            require(!ok, "advertised failure never falls back to Artist");
            check.clearMockedCalls();
            require(
                royalty.currentRoyaltySnapshotSource(2).sourceAssignmentHash
                    == original.sourceAssignmentHash,
                "restored exact source"
            );
        }
    }
