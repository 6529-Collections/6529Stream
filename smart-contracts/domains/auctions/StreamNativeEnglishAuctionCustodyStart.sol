// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeEnglishAuctionRuntime.sol";
import "./StreamNativeEnglishAuctionCustodyState.sol";
import "../../interfaces/stream/revenue/IStreamNativeCustodyPrimarySettlement.sol";
import "../../vendor/openzeppelin/IERC721Receiver.sol";

/// @notice Unpaid singleton acquisition in the actual house; paid transfer happens later.
library StreamNativeEnglishAuctionCustodyStart {
    event NativeAuctionCreated(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        IStreamNativeEnglishAuction.Configuration config,
        bytes32 creationDigest
    );
    event NativeAuctionCustodyAcquired(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        IStreamNativeCustodyAuction.Acquisition authorization,
        StreamNativeCustodySettlementTypes.Origin origin
    );

    function digest(IStreamNativeCustodyAuction.Acquisition memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeCustodyAuction"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "NativeCustodyAcquisition(bytes32 configHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,address artist,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
    }

    function registerAuction(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        IStreamNativeEnglishAuction.Configuration calldata c,
        IStreamNativeCustodyAuction.Acquisition calldata auth,
        bytes calldata artwork,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) public returns (bytes32 id) {
        StreamNativeEnglishAuctionRuntime.requireNativeContext(x);
        IStreamNativeCustodyPrimarySettlement(x.recorder)
            .requireCanonicalCustodyHouse(address(this));
        if (
            s.globalPause.paused || custody.acquiring != 0
                || s.creationUsed[auth.artist][auth.nonce]
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        StreamRefundWindowSupport.Context memory support =
            StreamNativeEnglishAuctionRuntime.support(x);
        StreamRefundWindowSupport.ArtistAssociation memory association =
            validate(s, support, c, auth, artwork, platformSignature, artistSignature);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamPreparedNativeSettlementAdmission.capture(x.registry, address(this));
        uint256 nonce = ++s.nextNonce;
        bytes32 saleId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(2),
                c.collectionId,
                c.phaseId,
                nonce
            )
        );
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_AUCTION_V1"),
                block.chainid,
                address(this),
                c.collectionId,
                nonce,
                c.tokenId,
                false
            )
        );
        IStreamNativeEnglishAuction.Auction storage a = s.auctions[id];
        if (a.status != 0 || s.auctionBySale[saleId] != 0) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        a.config = c;
        a.configHash = auth.configHash;
        a.saleId = saleId;
        a.saleNonce = nonce;
        a.auctionNonce = nonce;
        // SETTLING is non-biddable while the scoped original mint callback runs.
        a.status = 2;
        a.clock = StreamEnglishAuctionClock.initialize(
            c.clock, c.reservePrice, StreamRefundClock.now64()
        );
        a.pauseBaseline = StreamRefundClock.unionTotal(s.globalPause, s.salePause[saleId]);
        a.artistId = association.artistId;
        a.bindingGeneration = association.generation;
        a.bindingHash = association.bindingHash;
        a.creationDigest = digest(auth);
        a.lifecycle = lifecycle;
        s.auctionBySale[saleId] = id;
        s.creationUsed[auth.artist][auth.nonce] = true;
        IStreamMintManager.MintBatch memory batch = mintBatch(c, auth, artwork, a.creationDigest);
        (bytes32 expectedRoot, bytes32[] memory expectedOperations) =
            x.base.manager.previewSingleStepMintOperation(batch, "");
        custody.acquiring = id;
        custody.expectedToken = auth.expectedTokenId;
        uint256 beforeBalance = address(this).balance;
        (uint256[] memory tokens, bytes32 root, bytes32[] memory operations) =
            x.base.manager.executeSingleStepMint(batch, "");
        if (
            !custody.received || tokens.length != 1 || operations.length != 1
                || expectedOperations.length != 1 || tokens[0] != auth.expectedTokenId || root == 0
                || root != expectedRoot || operations[0] == 0
                || operations[0] != expectedOperations[0]
                || x.base.manager.nextOperationNonce() != auth.expectedOperationNonce + 1
                || !x.base.manager.isOperationRootUsed(root)
                || !x.base.manager.isAuthorizationUsed(a.creationDigest)
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        StreamNativeCustodySettlementTypes.Origin storage o = custody.origins[id];
        o.manager = address(x.base.manager);
        o.managerCodeHash = x.managerHash;
        o.operationRoot = root;
        o.operationId = operations[0];
        o.authorizationId = a.creationDigest;
        o.tokenDataHash = auth.tokenDataHash;
        o.tokenId = tokens[0];
        o.collectionSerial = auth.expectedCollectionSerial;
        o.operationNonce = auth.expectedOperationNonce;
        o.fundingAccount = auth.executor;
        o.eligible = true;
        a.tokenId = tokens[0];
        requireToken(x.base.core, a, o);
        if (IStreamCore(x.base.core).coordinatorAtMint(tokens[0]) != address(x.base.entropy)) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        StreamNativeEnglishAuctionRuntime.requireNativeContext(x);
        StreamNativeEnglishAuctionRuntime.requireRetained(x, a);
        (uint256 forwarded, uint256 remainder) = StreamRefundWindowSupport.fundRevealAndAttempt(
            StreamNativeEnglishAuctionRuntime.support(x),
            c.collectionId,
            tokens[0],
            msg.value,
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.REVEAL_GAS
            )
        );
        if (address(this).balance != beforeBalance - forwarded) {
            revert IStreamNativeEnglishAuction.NativeAuctionAccountingMismatch();
        }
        requireToken(x.base.core, a, o);
        o.revealFeeForwarded = forwarded;
        if (remainder != 0) {
            s.liabilities += remainder;
            StreamNativeEnglishAuctionState.credit(s, id, a, auth.executor, remainder);
        }
        delete custody.acquiring;
        delete custody.expectedToken;
        delete custody.received;
        a.status = 1;
        StreamNativeEnglishAuctionState.solvent(s);
        emit NativeAuctionCreated(id, saleId, a.configHash, c, a.creationDigest);
        emit NativeAuctionCustodyAcquired(id, saleId, tokens[0], auth, o);
    }

    function validate(
        StreamNativeEnglishAuctionState.State storage s,
        StreamRefundWindowSupport.Context memory x,
        IStreamNativeEnglishAuction.Configuration memory c,
        IStreamNativeCustodyAuction.Acquisition memory a,
        bytes memory artwork,
        bytes memory platformSignature,
        bytes memory artistSignature
    ) private view returns (StreamRefundWindowSupport.ArtistAssociation memory association) {
        if (
            c.mintAtSettlement || c.tokenId == 0 || c.artworkCommitment != 0
                || c.contentManifestRoot != 0 || c.collectionId == 0 || c.phaseId == 0
                || c.poster == address(0) || c.poster == address(this) || c.mintCommitment == 0
                || c.primaryPolicyMode != 1 || c.expectedPrimaryPolicyHash == 0
                || c.settlementWindow < 86400 || c.settlementWindow > 7776000
                || c.mintPolicyHash == 0
                || a.configHash != StreamNativeEnglishAuctionSupport.configHash(c)
                || a.tokenDataHash != keccak256(artwork) || artwork.length > 8192
                || a.expectedSaleNonce != s.nextNonce + 1 || a.expectedTokenId != c.tokenId
                || a.expectedTokenId != IStreamCore(x.core).lastAllocatedTokenId() + 1
                || a.expectedCollectionSerial
                    != IStreamCore(x.core).collectionNextSerial(c.collectionId)
                || a.expectedOperationNonce != x.manager.nextOperationNonce() || a.contextHash == 0
                || a.executor != msg.sender || a.executor == address(this)
                || a.revealFeeDeposit != msg.value || a.artist == address(0) || a.nonce == 0
                || a.deadline < block.timestamp
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        StreamEnglishAuctionClock.initialize(c.clock, c.reservePrice, StreamRefundClock.now64());
        StreamEnglishAuctionClock.minimumBid(
            0, c.reservePrice, c.minIncrementBps, c.incrementFloorWaived
        );
        StreamNativeEnglishAuctionSupport.requirePhase(x, c, true);
        bytes32[] memory counters = x.manager.phaseCounterIds(c.collectionId, c.phaseId);
        for (uint256 j; j < counters.length; ++j) {
            IStreamMintManager.MintCounterConfig memory counter =
                x.manager.counterConfig(c.collectionId, c.phaseId, counters[j]);
            if (
                counter.enabled && counter.keyMode != IStreamMintManager.CounterKeyMode.CONSTANT
                    && counter.keyMode != IStreamMintManager.CounterKeyMode.EXECUTOR
                    && counter.keyMode != IStreamMintManager.CounterKeyMode.CONTEXT
            ) {
                revert IStreamNativeCustodyAuction.InvalidNativeCustody();
            }
        }
        if (
            StreamNativeEnglishAuctionSupport.profilePolicy(x.resolver, c.collectionId)
                    != c.expectedPrimaryPolicyHash
                || StreamRefundWindowSupport.revealPolicy(x, c.collectionId).revealFeePerTokenWei
                    > msg.value
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        StreamRefundWindowSupport.preflightReveal(
            x,
            c.collectionId,
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.REVEAL_GAS
            )
        );
        association = StreamRefundWindowSupport.artistAssociation(x, c.collectionId);
        if (
            association.state != 2 || association.authorityStatus != 1 || association.artistId == 0
                || association.generation == 0 || association.bindingHash == 0
                || acceptedArtist(x, c.collectionId) != a.artist
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        bytes32 hash = digest(a);
        StreamNativeEnglishAuctionSupport.requireSignature(
            x.platform, hash, platformSignature, x.signatureGas
        );
        StreamNativeEnglishAuctionSupport.requireSignature(
            a.artist, hash, artistSignature, x.signatureGas
        );
    }

    function mintBatch(
        IStreamNativeEnglishAuction.Configuration memory c,
        IStreamNativeCustodyAuction.Acquisition memory a,
        bytes memory artwork,
        bytes32 authorization
    ) private view returns (IStreamMintManager.MintBatch memory b) {
        b.collectionId = c.collectionId;
        b.phaseId = c.phaseId;
        b.payer = a.executor;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(this);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = address(this);
        b.tokenData = new bytes[](1);
        b.tokenData[0] = artwork;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = c.mintCommitment;
        b.expectedPolicyHash = c.mintPolicyHash;
        b.authorizationId = authorization;
        b.contextHash = a.contextHash;
    }

    function onReceived(
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        address operator,
        address from,
        uint256 token
    ) public returns (bytes4) {
        if (
            custody.acquiring == 0 || custody.received || msg.sender != x.base.core
                || operator != address(x.base.manager) || from != address(0)
                || token != custody.expectedToken
        ) revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        custody.received = true;
        return IERC721Receiver.onERC721Received.selector;
    }

    function requireToken(
        address core,
        IStreamNativeEnglishAuction.Auction memory a,
        StreamNativeCustodySettlementTypes.Origin memory o
    ) public view {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            IStreamCore(core).tokenCollectionIdentity(o.tokenId);
        if (
            !exists || burned || !o.eligible || o.tokenId == 0 || a.tokenId != o.tokenId
                || a.config.tokenId != o.tokenId || collection != a.config.collectionId
                || serial != o.collectionSerial
                || IStreamCore(core).ownerOf(o.tokenId) != address(this)
                || IStreamCore(core).tokenLifecycle(o.tokenId) != 2
                || keccak256(IStreamCore(core).tokenData(o.tokenId)) != o.tokenDataHash
        ) {
            revert IStreamNativeCustodyAuction.NativeCustodyOriginUnavailable(a.saleId);
        }
    }

    function acceptedArtist(StreamRefundWindowSupport.Context memory x, uint256 collection)
        private
        view
        returns (address)
    {
        uint256 cap = x.artistGas;
        StreamNativeEnglishAuctionRuntime.admitDelivery(cap);
        bytes memory data = abi.encodeCall(IStreamArtistAttribution.acceptedArtist, (collection));
        address target = address(x.artists);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32 || word > type(uint160).max) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        return address(uint160(word));
    }
}
