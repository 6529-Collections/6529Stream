// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamNativeDutchSale.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../revenue/StreamNativeSettlementSupport.sol";
import "../revenue/StreamNativeSettlementHash.sol";
import "./StreamDutchPricing.sol";

/// @notice Linked reads and preparation for the standard native Dutch consumer.
/// @dev The consumer owns immutable records, replay, quantity, credits and its call guard.
library StreamDutchSaleSupport {
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

    error InsufficientDutchCallGas(uint256 cap, uint256 available);
    error SettlementReadFailed(address target, bytes4 selector);

    struct Capture {
        ArtistAssociation association;
        IStreamRevealFeeEscrow.CollectionRevealPolicy reveal;
        bytes32 consentEvidence;
    }

    function authorizationDigest(IStreamNativeDutchSale.DutchAuthorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeDutchSale"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        bytes32 typeHash = keccak256(
            "DutchAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice)"
        );
        return keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, a))));
    }

    function validateConfig(Context memory x, IStreamNativeDutchSale.DutchSaleConfig memory c)
        public
        view
        returns (bytes32 baseline, bytes32 assignment)
    {
        StreamDutchPricing.validate(c.schedule, c.declaredFree);
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.maxSaleQuantity == 0
                || c.closesAt < c.schedule.endTime || c.closesAt < block.timestamp
                || c.mintPolicyHash == 0
                || IStreamMintReads(address(x.manager)).phasePolicyHash(c.collectionId, c.phaseId)
                    != c.mintPolicyHash
        ) {
            revert IStreamNativeDutchSale.InvalidDutchSale();
        }
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            IStreamMintReads(address(x.manager)).phase(c.collectionId, c.phaseId);
        if (!exists || (phase.endTime != 0 && c.closesAt > phase.endTime)) {
            revert IStreamNativeDutchSale.InvalidDutchSale();
        }
        revealPolicy(x, c.collectionId);
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.resolver, c.collectionId);
        baseline = StreamSaleTemplate.policyHash(x.resolver, c.collectionId, rights);
        assignment = rights.assignmentHash;
    }

    /// @notice Canonical caller-bound consent plus historical evidence under one declared cap.
    /// @dev NONE is decided by the actual facade; REQUIRED must additionally report its record.
    function requireSaleConsent(Context memory x, uint256 collectionId, bytes32 id, bytes32 hash)
        public
        view
        returns (bytes32 evidence)
    {
        address facade = address(x.artists);
        _requireSelected(x.core, facade, x.artistHash, keccak256("ARTIST_REGISTRY"));
        uint256 capability = abi.decode(
            _read(
                facade,
                abi.encodeWithSelector(bytes4(0x01ffc9a7), bytes4(0x606af4b9)),
                32,
                x.artistGas
            ),
            (uint256)
        );
        if (capability != 1) revert IStreamNativeDutchSale.DutchDependencyInvalid(facade);
        _read(
            facade,
            abi.encodeWithSelector(bytes4(0x96ca91c5), collectionId, id, hash),
            0,
            x.artistGas
        );
        uint256 scope = abi.decode(
            _read(
                facade,
                abi.encodeWithSignature("saleConsentScope(uint256)", collectionId),
                32,
                x.artistGas
            ),
            (uint256)
        );
        if (scope > 1) revert IStreamNativeDutchSale.DutchDependencyInvalid(facade);
        if (scope == 1) {
            uint256[2] memory facts = abi.decode(
                _read(
                    facade,
                    abi.encodeWithSignature(
                        "isSaleConsented(uint256,bytes32,bytes32)", collectionId, id, hash
                    ),
                    64,
                    x.artistGas
                ),
                (uint256[2])
            );
            if (facts[0] != 1 || facts[1] == 0) {
                revert IStreamNativeDutchSale.DutchDependencyInvalid(facade);
            }
            evidence = bytes32(facts[1]);
        }
    }

    function prepare(
        Context memory x,
        IStreamNativeDutchSale.DutchSaleRecord memory record,
        IStreamNativeDutchSale.DutchPurchaseData memory d
    )
        public
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch,
            Capture memory capture
        )
    {
        IStreamNativeDutchSale.DutchAuthorization memory a = d.authorization;
        IStreamNativeDutchSale.DutchSaleConfig memory config = record.config;
        if (
            record.saleNonce == 0 || record.closed || record.paused
                || record.mintedQuantity >= config.maxSaleQuantity
                || block.timestamp < config.schedule.startTime || block.timestamp > config.closesAt
        ) {
            revert IStreamNativeDutchSale.DutchSaleUnavailable(a.saleId);
        }
        capture.consentEvidence =
            requireSaleConsent(x, config.collectionId, a.saleId, record.configHash);
        if (
            a.saleConfigHash != record.configHash || a.payer == address(0)
                || a.payer == address(this) || a.executor == address(0) || a.recipient == address(0)
                || a.artist == address(0) || a.executionNonce == 0 || a.mintCommitment == 0
                || block.timestamp > a.deadline || a.tokenDataHash != keccak256(d.tokenData)
        ) revert IStreamNativeDutchSale.InvalidDutchSale();
        uint256 charge = StreamDutchPricing.price(config.schedule, block.timestamp);
        if (a.unitPrice < charge) {
            revert IStreamNativeDutchSale.DutchPaymentBelowPrice(a.unitPrice, charge);
        }
        capture.reveal = revealPolicy(x, config.collectionId);
        capture.association = artistAssociation(x, config.collectionId);
        if (
            capture.association.state != 2 || capture.association.authorityStatus != 1
                || capture.association.artistId == 0 || capture.association.generation == 0
                || capture.association.bindingHash == 0
                || abi.decode(
                        _read(
                            address(x.artists),
                            abi.encodeCall(
                                IStreamArtistAttribution.acceptedArtist, (config.collectionId)
                            ),
                            32,
                            x.artistGas
                        ),
                        (address)
                    ) != a.artist
        ) {
            revert IStreamNativeDutchSale.InvalidDutchSale();
        }
        bytes32 digest = authorizationDigest(a);
        if (!StreamNativeSettlementSupport.validSignature(
                x.platform, digest, d.platformSignature, x.signatureGas
            )) {
            revert IStreamNativeDutchSale.DutchSignatureInvalid(x.platform);
        }
        if (!StreamNativeSettlementSupport.validSignature(
                a.artist, digest, d.artistSignature, x.signatureGas
            )) {
            revert IStreamNativeDutchSale.DutchSignatureInvalid(a.artist);
        }
        c.saleAdapter = address(this);
        c.executor = a.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            keccak256("PRIMARY_SALE"),
            0,
            config.collectionId,
            0,
            record.saleNonce,
            a.payer,
            address(0),
            a.recipient,
            charge,
            a.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = record.lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, a.executionNonce, 1, digest);
        c.orchestrationOrder = 1;
        c.mintManager = address(x.manager);
        c.currentPolicyHash = IStreamMintReads(address(x.manager))
            .phasePolicyHash(config.collectionId, config.phaseId);
        c.boundPolicyHash = config.mintPolicyHash;
        if (c.currentPolicyHash != c.boundPolicyHash) {
            revert IStreamNativeDutchSale.InvalidDutchSale();
        }
        if (charge != 0) {
            StreamSaleTemplate.Selection memory rights =
                StreamNativeSettlementSupport.rights(x.resolver, config.collectionId);
            if (
                a.expectedPrimaryPolicyHash == 0
                    || rights.assignmentHash != record.primaryAssignmentHash
                    || StreamSaleTemplate.policyHash(x.resolver, config.collectionId, rights)
                        != a.expectedPrimaryPolicyHash
            ) {
                revert IStreamNativeDutchSale.InvalidDutchSale();
            }
            c.rights = StreamPrimarySettlementTypes.PrimaryRights(
                rights.profileId,
                rights.wallet,
                rights.templateId,
                rights.assignmentHash,
                rights.entriesHash
            );
        }
        c.saleExecutionHash = keccak256(abi.encode(d));
        batch.collectionId = config.collectionId;
        batch.phaseId = config.phaseId;
        batch.payer = a.payer;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = a.recipient;
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = a.recipient;
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = d.tokenData;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = a.mintCommitment;
        batch.expectedPolicyHash = config.mintPolicyHash;
        batch.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        batch.contextHash = digest;
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.manager)).previewSingleStepMintOperation(batch, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert IStreamNativeDutchSale.DutchMintResultInvalid();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamNativeSettlementHash.executionId(c);
    }

    event DutchRevealAttempt(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bool success,
        bytes32 requestKey,
        uint256 providerRequestId,
        uint256 returnDataSize,
        bytes failurePrefix
    );

    function preflightReveal(uint8 capturedMode, uint256 cap) public view {
        if (capturedMode == 0) _requireGas(cap);
    }

    /// @notice Immediate sales fund their one captured fee quote exactly, without re-pricing.
    function fundCapturedReveal(
        Context memory x,
        uint256 collectionId,
        uint256 tokenId,
        IStreamRevealFeeEscrow.CollectionRevealPolicy memory captured,
        uint256 cap
    ) public {
        address target = address(x.entropy);
        _requireSelected(x.core, target, x.entropyHash, keccak256("ENTROPY_COORDINATOR"));
        uint256 fee = captured.revealFeePerTokenWei;
        if (fee != 0) {
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
                ok := call(gas(), target, fee, add(data, 32), mload(data), 0, 0)
                size := returndatasize()
            }
            if (!ok || size != 0) revert IStreamNativeDutchSale.DutchDependencyInvalid(target);
            uint256 afterEscrow = abi.decode(
                _read(
                    target,
                    abi.encodeCall(IStreamRevealFeeEscrow.revealFeeEscrow, (collectionId)),
                    32,
                    0
                ),
                (uint256)
            );
            if (afterEscrow != beforeEscrow + fee) {
                revert IStreamNativeDutchSale.DutchAccountingMismatch();
            }
        }
        if (captured.requestMode == 0) {
            _requireGas(cap);
            bytes memory data = abi.encodeCall(IStreamEntropyCoordinator.requestEntropy, (tokenId));
            uint256[2] memory result;
            bool ok;
            uint256 size;
            assembly ("memory-safe") {
                ok := call(cap, target, 0, add(data, 32), mload(data), result, 64)
                size := returndatasize()
            }
            if (ok && size == 64 && result[0] != 0) {
                emit DutchRevealAttempt(
                    1, collectionId, tokenId, true, bytes32(result[0]), result[1], size, ""
                );
            } else {
                bytes memory prefix = new bytes(size > 256 ? 256 : size);
                assembly ("memory-safe") { returndatacopy(add(prefix, 32), 0, mload(prefix)) }
                emit DutchRevealAttempt(1, collectionId, tokenId, false, 0, 0, size, prefix);
            }
        }
        _requireSelected(x.core, target, x.entropyHash, keccak256("ENTROPY_COORDINATOR"));
    }

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
        ) revert IStreamNativeDutchSale.DutchRoleNotAuthorized(role, msg.sender);
    }

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
            revert IStreamNativeDutchSale.DutchDependencyReadMalformed(address(x.artists), 160);
        }
        a = ArtistAssociation(
            uint8(words[0]), uint64(words[1]), bytes32(words[2]), uint8(words[3]), bytes32(words[4])
        );
    }

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
        ) revert IStreamNativeDutchSale.InvalidDutchSale();
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
            revert IStreamNativeDutchSale.DutchDependencyReadMalformed(address(x.entropy), 160);
        }
        p = IStreamRevealFeeEscrow.CollectionRevealPolicy(
            true, uint8(words[1]), bytes32(words[2]), uint64(words[3]), words[4]
        );
    }

    function _requireSelected(address core, address target, bytes32 hash, bytes32 kind)
        private
        view
    {
        if (target.codehash != hash || !StreamSettlementAdmission.isContract(target)) {
            revert IStreamNativeDutchSale.DutchDependencyInvalid(target);
        }
        bytes memory raw =
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, 0);
        uint256[10] memory words = abi.decode(raw, (uint256[10]));
        if (words[0] != uint256(uint160(target)) || bytes32(words[1]) != hash) {
            revert IStreamNativeDutchSale.DutchDependencyInvalid(target);
        }
    }

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
        if (!ok) revert IStreamNativeDutchSale.DutchDependencyInvalid(target);
        if (size != length) {
            revert IStreamNativeDutchSale.DutchDependencyReadMalformed(target, size);
        }
    }

    function _requireGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30000) {
            revert InsufficientDutchCallGas(cap, available);
        }
    }
}
