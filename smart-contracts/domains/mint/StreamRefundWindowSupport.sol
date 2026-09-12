// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamNativeRefundWindowSale.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../revenue/StreamNativeSettlementSupport.sol";
import "../revenue/StreamDeferredNativeSettlementHash.sol";
import "./StreamSaleConsent.sol";

/// @notice Typed reads, authentication and mint preparation for the deferred native consumer.
/// @dev The consumer owns purchase replay, liabilities, pauses and the one active settlement.
library StreamRefundWindowSupport {
    struct Context {
        address core;
        IStreamMintManager manager;
        IStreamRevenueResolver resolver;
        address platform;
        IStreamArtistAttribution artists;
        bytes32 artistHash;
        IStreamRevealFeeEscrow entropy;
        bytes32 entropyHash;
        uint256 signatureGas;
        uint256 artistGas;
    }

    struct ArtistAssociation {
        uint8 state;
        uint64 generation;
        bytes32 artistId;
        uint8 authorityStatus;
        bytes32 bindingHash;
    }

    bytes32 private constant AUTHORIZATION_TYPEHASH = keccak256(
        "RefundPurchaseAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,bytes32 nonce,uint256 price,uint64 deadline,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline,bytes32 expectedPrimaryPolicyHash)"
    );

    error InsufficientRefundCallGas(uint256 cap, uint256 available);
    error SettlementReadFailed(address target, bytes4 selector);

    /// @notice Reads the same pinned executor-owned role registry in the consumer's context.
    function requireRole(address registry, bytes32 registryHash, address authority, bytes32 role)
        public
        view
    {
        if (
            registry.codehash != registryHash
                || _roleRead(authority, abi.encodeWithSignature("roleRegistry()"))
                    != uint256(uint160(registry))
                || _roleRead(registry, abi.encodeWithSignature("owner()"))
                    != uint256(uint160(authority))
                || _roleRead(
                        registry, abi.encodeCall(IStreamRoleRegistry.hasRole, (role, msg.sender))
                    ) != 1
        ) revert IStreamNativeRefundWindowSale.RefundRoleNotAuthorized(role, msg.sender);
    }

    // Preserve the original context reader's exact32 predicate and error selector.
    function _roleRead(address target, bytes memory data) private view returns (uint256 word) {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert SettlementReadFailed(target, bytes4(data));
    }

    event RefundRevealAttempt(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bool success,
        bytes32 requestKey,
        uint256 providerRequestId,
        uint256 returnDataSize,
        bytes failurePrefix
    );

    function authorizationDigest(IStreamNativeRefundWindowSale.RefundPurchaseAuthorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeRefundWindowSale"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(hex"1901", domain, keccak256(abi.encode(AUTHORIZATION_TYPEHASH, a)))
        );
    }

    function windowPolicyHash(IStreamNativeRefundWindowSale.RefundSaleConfig memory c)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFUND_WINDOW_POLICY_V1"),
                c.refundWindowSeconds,
                c.finalizationWindowSeconds,
                keccak256("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION"),
                keccak256("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY")
            )
        );
    }

    function validateConfig(
        Context memory x,
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c
    ) public view returns (bytes32 baselinePolicyHash) {
        if (c.primaryPolicyMode != 1) {
            revert IStreamNativeRefundWindowSale.SaleEnvelopeModeInvalid();
        }
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.price == 0 || c.maxSaleQuantity == 0
                || c.endsAt <= c.startsAt || c.endsAt < block.timestamp
                || c.refundWindowSeconds < 3600 || c.refundWindowSeconds > 2592000
                || c.finalizationWindowSeconds < 86400 || c.finalizationWindowSeconds > 7776000
                || c.mintPolicyHash == 0
                || IStreamMintReads(address(x.manager)).phasePolicyHash(c.collectionId, c.phaseId)
                    != c.mintPolicyHash
        ) revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            IStreamMintReads(address(x.manager)).phase(c.collectionId, c.phaseId);
        if (
            !exists
                || (phase.endTime != 0
                    && uint256(c.endsAt) + c.refundWindowSeconds + c.finalizationWindowSeconds
                        > phase.endTime)
        ) {
            revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        }
        // Both dependencies must be explicitly configured; absent reveal policy is not zero fee.
        revealPolicy(x, c.collectionId);
        baselinePolicyHash = StreamSaleTemplate.policyHash(
            x.resolver,
            c.collectionId,
            StreamNativeSettlementSupport.rights(x.resolver, c.collectionId)
        );
    }

    /// @notice The refund profile applies its own declared artist budget to both facade calls.
    function requireSaleConsent(
        Context memory x,
        uint256 collectionId,
        bytes32 saleId,
        bytes32 configHash
    ) public view {
        address facade = address(x.artists);
        _requireSelected(x.core, facade, x.artistHash, keccak256("ARTIST_REGISTRY"));
        uint256 cap = x.artistGas;
        bytes memory data = abi.encodeWithSelector(bytes4(0x01ffc9a7), bytes4(0x606af4b9));
        bool ok;
        uint256 size;
        uint256 supported;
        _requireGas(cap);
        assembly ("memory-safe") {
            ok := staticcall(cap, facade, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            supported := mload(0)
        }
        if (!ok || size != 32 || supported != 1) {
            revert StreamSaleConsent.SaleConsentNotSatisfied(facade, collectionId, saleId);
        }
        data = abi.encodeWithSelector(bytes4(0x96ca91c5), collectionId, saleId, configHash);
        _requireGas(cap);
        assembly ("memory-safe") {
            ok := staticcall(cap, facade, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        if (!ok || size != 0) {
            revert StreamSaleConsent.SaleConsentNotSatisfied(facade, collectionId, saleId);
        }
    }

    function validatePurchase(
        Context memory x,
        IStreamNativeRefundWindowSale.RefundSaleRecord memory record,
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d
    ) public view returns (bytes32 digest, ArtistAssociation memory association, uint256 fee) {
        IStreamNativeRefundWindowSale.RefundPurchaseAuthorization memory a = d.authorization;
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c = record.config;
        if (
            record.saleNonce == 0 || record.purchasedQuantity >= c.maxSaleQuantity
                || block.timestamp < c.startsAt || block.timestamp > c.endsAt
                || a.saleConfigHash != record.configHash
                || a.windowPolicyHash != record.windowPolicyHash || a.payer != msg.sender
                || a.payer == address(this) || a.recipient == address(0) || a.artist == address(0)
                || a.purchaseNonce == 0 || a.mintCommitment == 0
                || a.tokenDataHash != keccak256(d.tokenData) || a.price != c.price
                || a.expectedPrimaryPolicyHash == 0 || block.timestamp > a.deadline
        ) revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        _requireSelected(x.core, address(x.artists), x.artistHash, keccak256("ARTIST_REGISTRY"));
        association = artistAssociation(x, c.collectionId);
        if (
            association.state != 2 || association.authorityStatus != 1 || association.artistId == 0
                || association.generation == 0 || association.bindingHash == 0
                || abi.decode(
                        _read(
                            address(x.artists),
                            abi.encodeCall(
                                IStreamArtistAttribution.acceptedArtist, (c.collectionId)
                            ),
                            32,
                            x.artistGas
                        ),
                        (address)
                    ) != a.artist
        ) revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        digest = authorizationDigest(a);
        if (!StreamNativeSettlementSupport.validSignature(
                x.platform, digest, d.platformSignature, x.signatureGas
            )) {
            revert IStreamNativeRefundWindowSale.RefundPurchaseSignatureInvalid(x.platform);
        }
        if (!StreamNativeSettlementSupport.validSignature(
                a.artist, digest, d.artistSignature, x.signatureGas
            )) {
            revert IStreamNativeRefundWindowSale.RefundPurchaseSignatureInvalid(a.artist);
        }
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.resolver, c.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.resolver, c.collectionId, rights)
                != a.expectedPrimaryPolicyHash
        ) {
            revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        }
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            IStreamMintReads(address(x.manager)).phase(c.collectionId, c.phaseId);
        if (
            !exists || phase.paused || block.timestamp < phase.startTime
                || (phase.endTime != 0 && block.timestamp > phase.endTime)
                || !IStreamMintReads(address(x.manager))
                    .phaseExecutor(c.collectionId, c.phaseId, address(this))
                || IStreamMintReads(address(x.manager)).phasePolicyHash(c.collectionId, c.phaseId)
                    != c.mintPolicyHash
        ) revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        fee = revealPolicy(x, c.collectionId).revealFeePerTokenWei;
    }

    function artistAssociation(Context memory x, uint256 collectionId)
        public
        view
        returns (ArtistAssociation memory a)
    {
        _requireSelected(x.core, address(x.artists), x.artistHash, keccak256("ARTIST_REGISTRY"));
        bytes memory raw = _read(
            address(x.artists),
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (collectionId)),
            160,
            x.artistGas
        );
        uint256[5] memory words = abi.decode(raw, (uint256[5]));
        if (words[0] > 5 || words[1] > type(uint64).max || words[3] > type(uint8).max) {
            revert IStreamNativeRefundWindowSale.RefundDependencyReadMalformed(
                address(x.artists), 160
            );
        }
        a = ArtistAssociation(
            uint8(words[0]), uint64(words[1]), bytes32(words[2]), uint8(words[3]), bytes32(words[4])
        );
    }

    /// @notice Keeps the purchased association exact while permitting authority-address rotation.
    function requireArtistAssociation(
        Context memory x,
        uint256 collectionId,
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash
    ) public view {
        ArtistAssociation memory actual = artistAssociation(x, collectionId);
        if (
            actual.state != 2 || actual.authorityStatus != 1 || actual.artistId != artistId
                || actual.generation != generation || actual.bindingHash != bindingHash
        ) revert IStreamNativeRefundWindowSale.InvalidRefundSale();
    }

    function revealPolicy(Context memory x, uint256 collectionId)
        public
        view
        returns (IStreamRevealFeeEscrow.CollectionRevealPolicy memory p)
    {
        _requireSelected(
            x.core, address(x.entropy), x.entropyHash, keccak256("ENTROPY_COORDINATOR")
        );
        bytes memory raw = _read(
            address(x.entropy),
            abi.encodeCall(IStreamRevealFeeEscrow.collectionRevealPolicy, (collectionId)),
            160,
            0
        );
        uint256[5] memory words = abi.decode(raw, (uint256[5]));
        if (words[0] != 1 || words[1] > 1 || words[3] > type(uint64).max) {
            revert IStreamNativeRefundWindowSale.RefundDependencyReadMalformed(
                address(x.entropy), 160
            );
        }
        p = IStreamRevealFeeEscrow.CollectionRevealPolicy(
            true, uint8(words[1]), bytes32(words[2]), uint64(words[3]), words[4]
        );
    }

    function prepareFinalization(
        Context memory x,
        bytes32 id,
        IStreamNativeRefundWindowSale.RefundSaleRecord memory sale,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p,
        uint64 refundDeadline,
        uint64 finalizeBy,
        uint64 toll
    )
        public
        view
        returns (
            StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d,
            IStreamMintManager.MintBatch memory b
        )
    {
        IStreamNativeRefundWindowSale.RefundPurchaseAuthorization memory a = p.authorization;
        requireArtistAssociation(
            x, sale.config.collectionId, p.artistId, p.bindingGeneration, p.bindingHash
        );
        b.collectionId = sale.config.collectionId;
        b.phaseId = sale.config.phaseId;
        b.payer = a.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = a.recipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = a.recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = p.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = a.mintCommitment;
        b.expectedPolicyHash = sale.config.mintPolicyHash;
        b.authorizationId = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), p.authorizationDigest)
        );
        b.contextHash = p.authorizationDigest;
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c;
        c.saleAdapter = address(this);
        c.executor = msg.sender;
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.resolver, b.collectionId);
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            keccak256("PRIMARY_SALE"),
            1,
            b.collectionId,
            0,
            sale.saleNonce,
            a.payer,
            address(0),
            a.recipient,
            a.price,
            StreamSaleTemplate.policyHash(x.resolver, b.collectionId, rights)
        );
        c.lifecycleBinding = sale.lifecycle;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            0, a.purchaseNonce, 1, p.authorizationDigest
        );
        c.orchestrationOrder = 1;
        c.mintManager = address(x.manager);
        c.currentPolicyHash =
            IStreamMintReads(address(x.manager)).phasePolicyHash(b.collectionId, b.phaseId);
        c.boundPolicyHash = b.expectedPolicyHash;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
        c.saleExecutionHash = p.purchaseRecordHash;
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.manager)).previewSingleStepMintOperation(b, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        }
        c.operationId = ids[0];
        d = StreamDeferredNativeSettlementTypes.DeferredNativeCandidate(
            c,
            id,
            p.purchaseRecordHash,
            a.expectedPrimaryPolicyHash,
            p.nominalRefundDeadline,
            p.nominalFinalizeBy,
            a.maximumNominalFinalizeBy,
            a.absoluteEscapeDeadline,
            refundDeadline,
            finalizeBy,
            toll
        );
        d.execution.executionBinding.executionId = StreamDeferredNativeSettlementHash.executionId(d);
    }

    function _requireSelected(address core, address target, bytes32 hash, bytes32 kind)
        private
        view
    {
        if (target.codehash != hash || !StreamSettlementAdmission.isContract(target)) {
            revert IStreamNativeRefundWindowSale.RefundDependencyInvalid(target);
        }
        bytes memory raw =
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, 0);
        uint256[10] memory words = abi.decode(raw, (uint256[10]));
        if (words[0] != uint256(uint160(target)) || bytes32(words[1]) != hash) {
            revert IStreamNativeRefundWindowSale.RefundDependencyInvalid(target);
        }
    }

    /// @notice Preflights the intended attempt cap before official effects.
    /// @dev The post-mint call still checks EIP150 admission because callbacks consume variable gas.
    function preflightReveal(Context memory x, uint256 collectionId, uint256 attemptGas)
        public
        view
    {
        if (revealPolicy(x, collectionId).requestMode == 0) _requireGas(attemptGas);
    }

    /// @notice Funds only the actual collection escrow; the independent AT_MINT attempt may fail.
    function fundRevealAndAttempt(
        Context memory x,
        uint256 collectionId,
        uint256 tokenId,
        uint256 savedFee,
        uint256 attemptGas
    ) public returns (uint256 forwarded, uint256 remainder) {
        IStreamRevealFeeEscrow.CollectionRevealPolicy memory policy = revealPolicy(x, collectionId);
        forwarded = savedFee < policy.revealFeePerTokenWei ? savedFee : policy.revealFeePerTokenWei;
        remainder = savedFee - forwarded;
        address target = address(x.entropy);
        if (forwarded != 0) {
            uint256 beforeEscrow = abi.decode(
                _read(
                    target,
                    abi.encodeCall(IStreamRevealFeeEscrow.revealFeeEscrow, (collectionId)),
                    32,
                    0
                ),
                (uint256)
            );
            bytes memory data =
                abi.encodeCall(IStreamRevealFeeEscrow.fundRevealFeeEscrow, (collectionId));
            bool ok;
            uint256 size;
            assembly ("memory-safe") {
                ok := call(gas(), target, forwarded, add(data, 32), mload(data), 0, 0)
                size := returndatasize()
            }
            if (!ok || size != 0) {
                revert IStreamNativeRefundWindowSale.RefundDependencyInvalid(target);
            }
            uint256 afterEscrow = abi.decode(
                _read(
                    target,
                    abi.encodeCall(IStreamRevealFeeEscrow.revealFeeEscrow, (collectionId)),
                    32,
                    0
                ),
                (uint256)
            );
            if (afterEscrow != beforeEscrow + forwarded) {
                revert IStreamNativeRefundWindowSale.RefundAccountingMismatch();
            }
        }
        // Funding and requesting are separate. The pinned coordinator owns permissionless
        // recovery/retry; an external provider failure never classifies the purchase refundable.
        if (policy.requestMode == 0) _attempt(target, collectionId, tokenId, attemptGas);
    }

    function _attempt(address target, uint256 collectionId, uint256 tokenId, uint256 cap) private {
        bytes memory data = abi.encodeCall(IStreamEntropyCoordinator.requestEntropy, (tokenId));
        uint256[2] memory result;
        _requireGas(cap);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(cap, target, 0, add(data, 32), mload(data), result, 64)
            size := returndatasize()
        }
        if (ok && size == 64 && result[0] != 0) {
            emit RefundRevealAttempt(
                1, collectionId, tokenId, true, bytes32(result[0]), result[1], size, ""
            );
        } else {
            uint256 length = size > 256 ? 256 : size;
            bytes memory prefix = new bytes(length);
            assembly ("memory-safe") { returndatacopy(add(prefix, 32), 0, length) }
            emit RefundRevealAttempt(1, collectionId, tokenId, false, 0, 0, size, prefix);
        }
    }

    /// @dev cap=0 is reserved for fixed-size reads of the immutable, Core-pinned coordinator/Core.
    function _read(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(length);
        if (cap != 0) _requireGas(cap);
        else cap = gasleft();
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), length)
            size := returndatasize()
        }
        if (!ok) revert IStreamNativeRefundWindowSale.RefundDependencyInvalid(target);
        if (size != length) {
            revert IStreamNativeRefundWindowSale.RefundDependencyReadMalformed(target, size);
        }
    }

    function _requireGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30000) {
            revert InsufficientRefundCallGas(cap, available);
        }
    }
}
