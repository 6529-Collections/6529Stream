// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeEnglishAuctionRuntime.sol";
import "./StreamNativeEnglishAuctionCustodyState.sol";
import "./StreamPlatformNativeAuctionRegistration.sol";
import "../revenue/StreamPlatformCustodyHash.sol";
import "../revenue/StreamPlatformCustodyValidation.sol";
import "../../interfaces/stream/revenue/IStreamPlatformCustodyPrimarySettlement.sol";
import "../../interfaces/stream/revenue/IStreamNativeCustodyPrimarySettlement.sol";
import "../../vendor/openzeppelin/IERC721Receiver.sol";
import {
    IStreamPreparedNativeCustodyAuction
} from "../../interfaces/stream/auctions/IStreamPreparedNativeCustodyAuction.sol";

/// @notice Declaration-bound platform acquisition; original prepared mint, reveal and custody proof.
/// @dev Delegatecall retains the original house, caller, storage and callback scope.
library StreamPlatformCustodyRegistration {
    event NativeAuctionCreated(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        IStreamNativeEnglishAuction.Configuration config,
        bytes32 creationDigest
    );
    event PlatformCustodyAcquired(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        IStreamPlatformCustodyAuction.PlatformCustodyAuthorization authorization,
        StreamNativeCustodySettlementTypes.Origin origin
    );
    event NativeAuctionPreparedCustodyBound(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        uint256 indexed tokenId,
        bytes32 indexed operationRoot,
        bytes32 operationId,
        bytes32 authorizationDigest
    );

    function registerCalldata(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage policies,
        mapping(bytes32 => bytes32) storage declarations,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes calldata input
    ) public returns (bytes32) {
        if (
            bytes4(input[:4])
                != IStreamPlatformCustodyAuction.registerPlatformCustodyAuction.selector
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        (
            IStreamNativeEnglishAuction.Configuration memory c,
            StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
            bytes memory artwork,
            IStreamPlatformCustodyAuction.PlatformCustodyAuthorization memory auth,
            bytes memory signature
        ) = abi.decode(
            input[4:],
            (
                IStreamNativeEnglishAuction.Configuration,
                StreamPreparedNativeRightsTypes.OriginalPolicy,
                bytes,
                IStreamPlatformCustodyAuction.PlatformCustodyAuthorization,
                bytes
            )
        );
        return
            _register(s, custody, x, c, auth, artwork, signature, original, policies, declarations);
    }

    function _register(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        IStreamNativeEnglishAuction.Configuration memory c,
        IStreamPlatformCustodyAuction.PlatformCustodyAuthorization memory auth,
        bytes memory artwork,
        bytes memory platformSignature,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage policies,
        mapping(bytes32 => bytes32) storage declarations
    ) private returns (bytes32 id) {
        StreamNativeEnglishAuctionRuntime.requireNativeContext(x);
        IStreamNativeCustodyPrimarySettlement(x.recorder)
            .requireCanonicalCustodyHouse(address(this));
        if (
            s.globalPause.paused || custody.acquiring != 0
                || s.creationUsed[x.base.platform][auth.nonce]
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        StreamRefundWindowSupport.Context memory support =
            StreamNativeEnglishAuctionRuntime.support(x);
        if (
            !IERC165(x.recorder)
                    .supportsInterface(type(IStreamPlatformCustodyPrimarySettlement).interfaceId)
                || !IStreamPlatformCustodyPrimarySettlement(x.recorder)
                    .isStreamPlatformCustodyPrimarySettlement()
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        validate(s, support, c, auth, artwork, platformSignature, original);
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
        // A platform declaration supplies authority; no Artist/binding fields are fabricated.
        a.creationDigest = StreamPlatformCustodyHash.acquisition(auth);
        policies[id] = original;
        declarations[saleId] = auth.declarationHash;
        a.lifecycle = lifecycle;
        s.auctionBySale[saleId] = id;
        s.creationUsed[x.base.platform][auth.nonce] = true;
        IStreamMintManager.MintBatch memory batch = mintBatch(c, auth, artwork, a.creationDigest);
        (bytes32 expectedRoot, bytes32[] memory expectedOperations) = IStreamPreparedNativeMint(
                address(x.base.manager)
            ).previewPreparedNativeMintOperation(batch, "");
        custody.acquiring = id;
        custody.expectedToken = auth.expectedTokenId;
        uint256 beforeBalance = address(this).balance;
        (uint256[] memory tokens, bytes32 root, bytes32[] memory operations) =
            x.base.manager.executePreparedMint(batch, "");
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
        _requireOriginal(x.base.resolver, c, auth, original);
        (StreamSaleTemplate.Selection memory current,) = StreamPlatformPrimaryProfile.resolve(
            x.base.resolver, c.collectionId, tokens[0], original.mode, c.poster
        );
        if (current.assignmentHash != original.assignmentHash) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
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
        _requireOriginal(x.base.resolver, c, auth, original);
        (StreamSaleTemplate.Selection memory afterReveal,) = StreamPlatformPrimaryProfile.resolve(
            x.base.resolver, c.collectionId, tokens[0], original.mode, c.poster
        );
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(afterReveal))) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
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
        emit PlatformCustodyAcquired(1, id, saleId, tokens[0], auth, o);
        emit NativeAuctionPreparedCustodyBound(
            1, id, tokens[0], root, operations[0], a.creationDigest
        );
    }

    function validate(
        StreamNativeEnglishAuctionState.State storage s,
        StreamRefundWindowSupport.Context memory x,
        IStreamNativeEnglishAuction.Configuration memory c,
        IStreamPlatformCustodyAuction.PlatformCustodyAuthorization memory a,
        bytes memory artwork,
        bytes memory platformSignature,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original
    ) private view {
        if (
            c.mintAtSettlement || c.tokenId == 0 || c.artworkCommitment != 0
                || c.contentManifestRoot != 0 || c.collectionId == 0 || c.phaseId == 0
                || c.poster == address(0) || c.poster == address(this) || c.mintCommitment == 0
                || c.primaryPolicyMode != 1 || c.expectedPrimaryPolicyHash == 0
                || c.settlementWindow < 86400 || c.settlementWindow > 7776000
                || c.mintPolicyHash == 0
                || a.configHash
                    != StreamPlatformNativeAuctionRegistration.configHash(
                        c, original, a.declarationHash
                    ) || a.tokenDataHash != keccak256(artwork) || artwork.length > 8192
                || a.expectedSaleNonce != s.nextNonce + 1 || a.expectedTokenId != c.tokenId
                || a.expectedTokenId != IStreamCore(x.core).lastAllocatedTokenId() + 1
                || a.expectedCollectionSerial
                    != IStreamCore(x.core).collectionNextSerial(c.collectionId)
                || a.expectedOperationNonce != x.manager.nextOperationNonce() || a.contextHash == 0
                || a.executor != msg.sender || a.executor == address(this)
                || a.revealFeeDeposit != msg.value || a.nonce == 0 || a.deadline < block.timestamp
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
            StreamRefundWindowSupport.revealPolicy(x, c.collectionId).revealFeePerTokenWei
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
        _requireOriginal(x.resolver, c, a, original);
        StreamNativeEnglishAuctionSupport.requireSignature(
            x.platform, StreamPlatformCustodyHash.acquisition(a), platformSignature, x.signatureGas
        );
        _requireOriginal(x.resolver, c, a, original);
    }

    function _requireOriginal(
        IStreamRevenueResolver resolver,
        IStreamNativeEnglishAuction.Configuration memory c,
        IStreamPlatformCustodyAuction.PlatformCustodyAuthorization memory a,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original
    ) private view {
        if (
            (original.mode != 10 && original.mode != 11) || original.templateId != 0
                || original.assignmentHash == 0 || a.declarationHash == 0
                || StreamPlatformSaleTemplate.declaration(resolver, c.collectionId)
                    != a.declarationHash
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        (StreamSaleTemplate.Selection memory selected,) = StreamPlatformPrimaryProfile.resolve(
            resolver, c.collectionId, 0, original.mode, c.poster
        );
        if (
            selected.assignmentHash != original.assignmentHash
                || StreamPreparedNativeRightsProjection.policyHash(
                        resolver, c.collectionId, 0, selected
                    ) != c.expectedPrimaryPolicyHash
        ) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
    }

    function mintBatch(
        IStreamNativeEnglishAuction.Configuration memory c,
        IStreamPlatformCustodyAuction.PlatformCustodyAuthorization memory a,
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

    function requireToken(
        address core,
        IStreamNativeEnglishAuction.Auction memory a,
        StreamNativeCustodySettlementTypes.Origin memory o
    ) private view {
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
}
