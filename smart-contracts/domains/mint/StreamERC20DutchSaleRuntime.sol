// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamERC20DutchSaleState.sol";
import "./StreamNativeImmediateSalesRuntime.sol";
import "./StreamDutchPricing.sol";
import "../revenue/StreamSettlementAdmission.sol";
import "../../interfaces/stream/revenue/IStreamERC20DutchPrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamERC20PublicDutchPrimarySaleSettlement.sol";

/// @notice Fixed checks and canonical candidate construction for the standard ERC20 Dutch host.
library StreamERC20DutchSaleRuntime {
    event ERC20DutchSaleRegistered(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        bytes32 priceScheduleHash,
        uint256 saleNonce,
        D.Configuration config
    );

    function saleId(uint256 collection, bytes32 phase, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ERC20_DUTCH_SALE_ID_V1"),
                block.chainid,
                address(this),
                collection,
                phase,
                nonce
            )
        );
    }

    function configurationHash(D.Configuration memory c) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ERC20_STANDARD_DUTCH_CONFIG_V1"),
                block.chainid,
                address(this),
                c
            )
        );
    }

    function register(
        StreamERC20DutchSaleState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        D.Configuration memory c
    ) public returns (bytes32 id) {
        S.Configuration memory s = c.sale;
        StreamDutchPricing.validate(c.schedule, c.declaredFree);
        if (
            s.collectionId == 0 || s.phaseId == 0 || s.saleKind != 3 || s.unitPrice != 0
                || s.saleSupplyLimit == 0 || s.mintPolicyHash == 0
                || s.expectedPrimaryPolicyHash == 0 || s.primaryPolicyMode != 0
                || s.startsAt != c.schedule.startTime
                || (s.manualClose ? s.endsAt != 0 : s.endsAt <= c.schedule.endTime)
                || c.asset == address(0) || c.asset.code.length == 0
                || c.paymentAdapter == address(0)
        ) revert S.InvalidImmediateSale();
        StreamNativeImmediateSalesRuntime.requireSigner(state.common, s);
        StreamNativeImmediateSalesRuntime.requirePhase(x, s);
        if (x.artist.manager.phasePolicyHash(s.collectionId, s.phaseId) != s.mintPolicyHash) {
            revert S.InvalidImmediateSale();
        }
        _pricePolicy(x, s);
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.artist.resolver, s.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.artist.resolver, s.collectionId, rights)
                != s.expectedPrimaryPolicyHash
        ) revert S.InvalidImmediateSale();
        StreamRefundWindowSupport.ArtistAssociation memory a =
            StreamNativeCuratedSaleSupport.association(x.artist, s.collectionId);
        id = saleId(s.collectionId, s.phaseId, state.common.nextSaleNonce);
        (bool globalPause,, bool stopped) =
            StreamNativeCuratedClock.stops(state.common.clocks, id, s.collectionId);
        uint8 contest = StreamNativeCuratedSaleSupport.contestState(x.artist, s.collectionId);
        if (globalPause || stopped || contest == 1 || contest == 3) {
            revert S.ImmediateSaleUnavailable(id);
        }
        S.Record storage r = state.common.sales[id];
        if (r.saleNonce != 0) revert S.InvalidImmediateSale();
        r.config = s;
        r.configHash = configurationHash(c);
        r.saleNonce = state.common.nextSaleNonce++;
        r.artistId = a.artistId;
        r.artistGeneration = a.generation;
        r.artistBindingHash = a.bindingHash;
        state.configurations[id] = c;
        state.lifecycle[id] = StreamSettlementAdmission.captureDutch(
            x.artist.registry, address(this), c.paymentAdapter
        );
        state.scheduleHashes[id] =
            StreamDutchPricing.scheduleHash(c.schedule, block.chainid, address(this), id);
        emit ERC20DutchSaleRegistered(id, r.configHash, state.scheduleHashes[id], r.saleNonce, c);
    }

    function price(StreamERC20DutchSaleState.State storage state, bytes32 id)
        public
        view
        returns (uint256)
    {
        if (state.common.sales[id].saleNonce == 0) revert S.ImmediateSaleUnavailable(id);
        return StreamDutchPricing.price(state.configurations[id].schedule, block.timestamp);
    }

    function amount(
        StreamERC20DutchSaleState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        S.Purchase memory p
    ) public view returns (uint256 value, bool override_) {
        D.Configuration storage c = state.configurations[p.saleId];
        value = price(state, p.saleId);
        if (c.sale.priceCounterId != 0) {
            uint256 leaf;
            (override_, leaf) = StreamMintSaleAllowlist.price(
                address(x.artist.manager),
                c.sale.collectionId,
                c.sale.phaseId,
                p.payer,
                p.beneficiary,
                p.resolverData,
                c.sale.priceCounterId
            );
            if (override_ && leaf < value) value = leaf;
        } else if (p.resolverData.length != 0) {
            revert S.InvalidImmediateSale();
        }
        if (value == 0 && !c.declaredFree) revert S.InvalidImmediateSale();
    }

    function prepare(
        StreamERC20DutchSaleState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        D.Execution memory e
    )
        public
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            IStreamMintManager.MintBatch memory b
        )
    {
        S.Purchase memory p = e.purchase;
        StreamNativeImmediateSalesRuntime.requireReady(state.common, x, p.saleId, true);
        S.Record memory r = state.common.sales[p.saleId];
        D.Configuration storage config = state.configurations[p.saleId];
        uint256 next = state.common.executionNonces[p.saleId][p.payer] + 1;
        if (p.executionNonce != next) revert S.ImmediateSaleNonceInvalid(next, p.executionNonce);
        if (
            p.payer == address(0) || p.executor == address(0) || p.payer == address(this)
                || p.executor == address(this) || p.payer == config.paymentAdapter
                || p.payer == x.recorder || p.initialRecipient == address(0)
                || p.initialRecipient == address(this) || p.beneficiary == address(0)
                || p.mintCommitment == 0 || p.tokenData.length > 8192
                || (r.config.authorityMode == 2 && p.payer != p.executor)
        ) revert S.InvalidImmediateSale();
        bytes32 request = keccak256(
            abi.encode(
                keccak256("6529STREAM_ERC20_DUTCH_REQUEST_V1"),
                block.chainid,
                address(this),
                r.configHash,
                p
            )
        );
        b = _batch(r.config, p, request);
        (uint256 charged, bool override_) = amount(state, x, p);
        bytes32 digest;
        if (r.config.authorityMode == 1) {
            digest = _signed(
                r.config,
                p,
                e.authorization,
                e.signature,
                b,
                address(x.artist.manager),
                x.signatureGas,
                config.asset,
                charged,
                override_
            );
            b.authorizationId = StreamMintTicketHash.authorizationId(digest);
        } else if (r.config.authorityMode == 2) {
            StreamPrivateSaleTypes.SaleAuthorization memory empty;
            if (
                keccak256(abi.encode(e.authorization)) != keccak256(abi.encode(empty))
                    || e.signature.authorizer != address(0) || e.signature.kind != 0
                    || e.signature.signature.length != 0
            ) revert S.InvalidImmediateSale();
            b.authorizationId = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ERC20_DUTCH_PUBLIC_AUTHORIZATION_V1"),
                    block.chainid,
                    address(this),
                    address(x.artist.manager),
                    r.configHash,
                    request
                )
            );
        } else {
            revert S.InvalidImmediateSale();
        }
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.artist.resolver, r.config.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.artist.resolver, r.config.collectionId, rights)
                != r.config.expectedPrimaryPolicyHash
        ) revert S.InvalidImmediateSale();
        c.saleAdapter = address(this);
        c.executor = p.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            p.saleId,
            keccak256("PRIMARY_SALE"),
            0,
            r.config.collectionId,
            0,
            r.saleNonce,
            p.payer,
            address(0),
            p.beneficiary,
            charged,
            r.config.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = state.lifecycle[p.saleId];
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            0, p.executionNonce, r.config.authorityMode, digest
        );
        c.asset = config.asset;
        c.orchestrationOrder = 1;
        c.mintManager = address(x.artist.manager);
        c.currentPolicyHash =
            x.artist.manager.phasePolicyHash(r.config.collectionId, r.config.phaseId);
        c.boundPolicyHash = r.config.mintPolicyHash;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
        c.saleExecutionHash = keccak256(abi.encode(e));
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.artist.manager)).previewSingleStepMintOperation(b, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert S.ImmediateSaleResultMismatch();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
        StreamSettlementAdmission.requireDutchAdmission(x.artist.registry, config.paymentAdapter, c);
    }

    function retained(
        StreamERC20DutchSaleState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        S.Purchase memory p
    ) public view {
        StreamNativeImmediateSalesRuntime.requireReady(state.common, x, p.saleId, false);
        StreamSettlementAdmission.requireDutchAdmission(
            x.artist.registry, state.configurations[p.saleId].paymentAdapter, c
        );
        (uint256 value,) = amount(state, x, p);
        if (
            value != c.sale.amount
                || x.artist.manager
                        .phasePolicyHash(
                            c.sale.collectionId, state.common.sales[p.saleId].config.phaseId
                        ) != c.currentPolicyHash
        ) revert S.InvalidImmediateSale();
        StreamNativeSettlementSupport.requireCurrent(
            x.artist.resolver,
            c.sale.collectionId,
            StreamSaleTemplate.Selection(
                c.rights.profileId,
                c.rights.wallet,
                c.rights.templateId,
                c.rights.assignmentHash,
                c.rights.entriesHash
            )
        );
    }

    function settle(
        StreamNativeImmediateSalesRuntime.Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory r) {
        bytes memory data = c.executionBinding.authorityMode == 1
            ? abi.encodeCall(
                IStreamERC20DutchPrimarySaleSettlement.settleERC20DutchPrimarySaleFromAdapter,
                (c.lifecycleBinding.paymentAdapter, c)
            )
            : abi.encodeCall(
                IStreamERC20PublicDutchPrimarySaleSettlement.settleERC20PublicDutchPrimarySaleFromAdapter,
                (c.lifecycleBinding.paymentAdapter, c)
            );
        bytes memory response = new bytes(384);
        address target = x.recorder;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), target, 0, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384) revert S.ImmediateSaleResultMismatch();
        r = abi.decode(response, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            r.candidateCommitment
                    != StreamPrimarySettlementHash.candidateCommitment(
                        c.lifecycleBinding.paymentAdapter, target, c
                    )
                || r.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        target, address(this), c.executionBinding.executionId
                    ) || r.profileId != c.rights.profileId || r.wallet != c.rights.wallet
                || r.asset != c.asset || r.amount != c.sale.amount || r.executor != c.executor
                || r.executionId != c.executionBinding.executionId
                || r.operationIdentityCommitment != c.operationIdentityCommitment
                || r.currentPolicyHash != c.currentPolicyHash
                || r.boundPolicyHash != c.boundPolicyHash
        ) revert S.ImmediateSaleResultMismatch();
        data = abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (r.settlementKey));
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384 || keccak256(response) != keccak256(abi.encode(r))) {
            revert S.ImmediateSaleResultMismatch();
        }
    }

    function _pricePolicy(
        StreamNativeImmediateSalesRuntime.Context memory x,
        S.Configuration memory config
    ) private view {
        if (config.priceCounterId != 0) {
            StreamMintSaleAllowlist.validatePolicy(
                address(x.artist.manager),
                config.collectionId,
                config.phaseId,
                config.priceCounterId
            );
        } else {
            bytes32[] memory ids =
                x.artist.manager.phaseCounterIds(config.collectionId, config.phaseId);
            if (ids.length > 16) revert S.InvalidImmediateSale();
            for (uint256 i; i < ids.length; ++i) {
                if (
                    x.artist
                        .manager
                        .counterConfig(config.collectionId, config.phaseId, ids[i])
                        .capMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC
                ) revert S.InvalidImmediateSale();
            }
        }
    }

    function _batch(S.Configuration memory config, S.Purchase memory p, bytes32 context)
        private
        pure
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = config.collectionId;
        b.phaseId = config.phaseId;
        b.payer = p.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = p.initialRecipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = p.beneficiary;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = p.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = p.mintCommitment;
        b.expectedPolicyHash = config.mintPolicyHash;
        b.contextHash = context;
        b.resolverData = p.resolverData;
        // Ungated Manager normalization is NONE/zero, independently of the sale signer.
    }

    function _signed(
        S.Configuration memory config,
        S.Purchase memory p,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        IStreamMintManager.MintBatch memory b,
        address manager,
        uint256 gasCap,
        address asset,
        uint256 charged,
        bool override_
    ) private view returns (bytes32 digest) {
        if (proof.authorizer != config.signer.authorizer || proof.kind != config.signer.kind) {
            revert S.ImmediateSaleSignerUnavailable(proof.authorizer, proof.kind);
        }
        if (
            a.chainId != block.chainid || a.saleAdapter != address(this) || a.mintManager != manager
                || a.collectionId != config.collectionId || a.phaseId != config.phaseId
                || a.saleId != p.saleId || a.saleKind != config.saleKind
                || a.revenueClass != keccak256("PRIMARY_SALE")
                || a.expectedPrimaryPolicyHash != config.expectedPrimaryPolicyHash
                || a.primaryPolicyMode != 0
                || a.initialRecipientsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients
                        )
                    )
                || a.beneficiariesHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries
                        )
                    )
                || a.tokenDataArrayHash
                    != keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData)
                    )
                || a.mintCommitmentsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments
                        )
                    ) || a.payer != p.payer || a.executor != p.executor || a.asset != asset
                || (!override_ && charged > a.unitPrice) || a.quantity != 1
                || a.contentSelectionHash != 0 || a.policyHash != config.mintPolicyHash
                || a.nonce == 0 || a.deadline < block.timestamp || a.finalizeBy != 0
        ) revert S.InvalidImmediateSale();
        digest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(a)
        );
        if (!StreamPrivateSaleSupport.validSignature(
                proof.authorizer, proof.kind, digest, proof.signature, gasCap
            )) revert S.ImmediateSaleSignatureInvalid(proof.authorizer);
    }
}
