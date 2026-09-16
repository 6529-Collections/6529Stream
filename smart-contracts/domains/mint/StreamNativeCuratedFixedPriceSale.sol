// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleBase } from "./StreamNativeCuratedSaleBase.sol";
import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import {
    IStreamNativeCuratedFixedPriceSale
} from "../../interfaces/stream/mint/IStreamNativeCuratedFixedPriceSale.sol";
import {
    IStreamNativeCuratedCommitments as Commitments
} from "../../interfaces/stream/mint/IStreamNativeCuratedCommitments.sol";
import { StreamNativeCuratedCommitments } from "./StreamNativeCuratedCommitments.sol";
import { StreamNativeCuratedClock } from "./StreamNativeCuratedClock.sol";
import { StreamNativeCuratedSaleHash } from "./StreamNativeCuratedSaleHash.sol";
import { StreamNativeCuratedSaleSupport } from "./StreamNativeCuratedSaleSupport.sol";
import { StreamNativeCuratedUnlock } from "./StreamNativeCuratedUnlock.sol";

/// @notice Published selected works under one immutable sale, with PUBLIC or funded COMMIT_REVEAL.
/// @dev Only the saved positive price is escrowed at commit. Reveal funds the live entropy fee.
contract StreamNativeCuratedFixedPriceSale is
    StreamNativeCuratedSaleBase,
    IStreamNativeCuratedFixedPriceSale
{
    mapping(bytes32 => Curated.FixedConfiguration) private _fixed;
    StreamNativeCuratedCommitments.State private _commitments;
    mapping(bytes32 => mapping(address => mapping(bytes32 => uint256))) private _commitNonces;

    error CuratedSelectionModeInvalid();
    error CuratedCommitPurchaseMismatch();
    error CuratedRefundTransferFailed();
    error CuratedRefundReasonUnavailable(uint8 reason);
    event CuratedSelectionTerms(
        bytes32 indexed saleId, bytes32 indexed configHash, Curated.FixedConfiguration config
    );
    event SelectionPurchaseBound(
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed buyer,
        bytes32 commitment,
        uint256 purchaseNonce,
        uint64 nominalFinalizeBy,
        uint64 absoluteEscape
    );
    event SelectionWindowObserved(
        bytes32 indexed saleId,
        uint64 commitClose,
        uint64 revealOpen,
        uint64 revealClose,
        uint64 commitToll,
        uint64 revealToll
    );
    event SelectionRefundClaimed(
        bytes32 indexed saleId, address indexed buyer, address indexed recipient, uint256 amount
    );
    event SelectionRefundReason(
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 indexed commitment,
        bytes32 reasonHash
    );

    constructor(DeploymentConfig memory deployment) StreamNativeCuratedSaleBase(deployment) { }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return
            id == type(IStreamNativeCuratedFixedPriceSale).interfaceId
                || super.supportsInterface(id);
    }

    function fixedConfigurationHash(Curated.FixedConfiguration calldata config)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativeCuratedSaleHash.fixedConfig(config);
    }

    function registerCuratedFixedSale(Curated.FixedConfiguration calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 id)
    {
        if (config.mode == Curated.SelectionMode.COMMIT_REVEAL) {
            if (
                config.sale.primaryPolicyMode != 1 || config.publicSelectionDisclosure
                    || config.windows.commitOpen != config.sale.startsAt
                    || config.windows.revealClose != config.sale.endsAt
            ) revert CuratedSelectionModeInvalid();
            StreamNativeCuratedClock.validateSchedule(_schedule(config.windows));
        } else {
            Curated.SelectionWindows memory empty;
            if (
                config.sale.primaryPolicyMode != 0 || config.differentiatedContent
                    || !config.publicSelectionDisclosure
                    || keccak256(abi.encode(config.windows)) != keccak256(abi.encode(empty))
            ) revert CuratedSelectionModeInvalid();
        }
        bytes32 hash = StreamNativeCuratedSaleHash.fixedConfig(config);
        id = _registerCommon(config.sale, 0, hash);
        _fixed[id] = config;
        emit CuratedSelectionTerms(id, hash, config);
    }

    function fixedSaleConfiguration(bytes32 id)
        external
        view
        override
        returns (Curated.FixedConfiguration memory)
    {
        return _fixed[id];
    }

    function selectionWindows(bytes32 id)
        public
        view
        returns (StreamNativeCuratedClock.View memory)
    {
        Curated.FixedConfiguration storage config = _fixed[id];
        if (config.sale.collectionId == 0 || config.mode != Curated.SelectionMode.COMMIT_REVEAL) {
            revert CuratedSelectionModeInvalid();
        }
        return StreamNativeCuratedClock.snapshot(
            _state.clocks, id, config.sale.collectionId, _schedule(config.windows)
        );
    }

    function purchaseSelectedContent(bytes32 id, Curated.Selection calldata chosen)
        external
        payable
        override
        nonReentrant
        returns (Curated.ExecutionRecord memory result)
    {
        Curated.SaleRecord storage sale = _requireSale(id);
        if (
            _fixed[id].mode != Curated.SelectionMode.PUBLIC
                || block.timestamp < sale.config.startsAt || block.timestamp >= sale.config.endsAt
        ) revert CuratedSelectionModeInvalid();
        _reservePurchaseNonce(id, msg.sender, chosen.purchaseNonce);
        StreamNativeCuratedSaleState.Request memory request;
        request.saleId = id;
        request.buyer = msg.sender;
        request.selection = chosen;
        request.authorityMode = 2;
        result = _execute(request);
    }

    function commitSelection(bytes32 id, bytes32 commitment, uint256 nonce)
        external
        payable
        override
        nonReentrant
        returns (bytes32 purchase)
    {
        Curated.SaleRecord storage sale = _requireSale(id);
        Commitments.Admission memory admission = _admission(id);
        _reservePurchaseNonce(id, msg.sender, nonce);
        StreamNativeCuratedCommitments.commit(
            _commitments, id, msg.sender, commitment, sale.config.price, admission
        );
        _commitNonces[id][msg.sender][commitment] = nonce;
        purchase = StreamNativeCuratedSaleHash.purchaseId(id, msg.sender, nonce);
        Curated.SelectionWindows storage windows = _fixed[id].windows;
        emit SelectionPurchaseBound(
            id, purchase, msg.sender, commitment, nonce, windows.revealClose, windows.absoluteEscape
        );
        _observeWindows(id);
        _requireSolvent();
    }

    function revealSelection(bytes32 id, Curated.Selection calldata chosen, bytes32 salt)
        external
        payable
        override
        nonReentrant
        returns (Curated.ExecutionRecord memory result)
    {
        Curated.SaleRecord storage sale = _requireSale(id);
        (bytes32 leaf,) = StreamNativeCuratedSaleSupport.selection(id, sale, chosen);
        bytes32 commitment =
            StreamNativeCuratedCommitments.commitmentHash(id, msg.sender, leaf, salt);
        if (_commitNonces[id][msg.sender][commitment] != chosen.purchaseNonce) {
            revert CuratedCommitPurchaseMismatch();
        }
        uint256 saved = StreamNativeCuratedCommitments.consumeForReveal(
            _commitments, id, msg.sender, commitment, leaf, salt, _admission(id)
        );
        if (saved != sale.config.price) revert CuratedCommitPurchaseMismatch();
        StreamNativeCuratedSaleState.Request memory request;
        request.saleId = id;
        request.buyer = msg.sender;
        request.selection = chosen;
        request.authorityMode = 2;
        request.priceEscrowed = true;
        result = _execute(request);
        _observeWindows(id);
        _requireSolvent();
    }

    function selectionCommitment(bytes32 id, address buyer, bytes32 leaf, bytes32 salt)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativeCuratedCommitments.commitmentHash(id, buyer, leaf, salt);
    }

    function selectionDeposit(bytes32 id, address buyer, bytes32 commitment)
        external
        view
        override
        returns (Commitments.CommitRecord memory record, bytes32 purchaseId, uint256 nonce)
    {
        record = StreamNativeCuratedCommitments.record(_commitments, id, buyer, commitment);
        nonce = _commitNonces[id][buyer][commitment];
        if (nonce != 0) purchaseId = StreamNativeCuratedSaleHash.purchaseId(id, buyer, nonce);
    }

    function unlockSelectionRefund(bytes32 id, address buyer, bytes32 commitment)
        external
        override
        nonReentrant
        returns (uint256 amount)
    {
        (, amount) = StreamNativeCuratedCommitments.unlockRefund(
            _commitments, id, buyer, commitment, _admission(id)
        );
        _requireSolvent();
    }

    function unlockSelectionRefundForReason(
        bytes32 id,
        address buyer,
        bytes32 commitment,
        Curated.Selection calldata chosen,
        bytes32 salt,
        uint8 reason
    ) external override nonReentrant returns (uint256 amount) {
        Commitments.CommitRecord memory deposit =
            StreamNativeCuratedCommitments.record(_commitments, id, buyer, commitment);
        if (deposit.status == Commitments.Status.REFUND_CREDITED) return 0;
        if (deposit.status != Commitments.Status.PENDING) revert CuratedCommitPurchaseMismatch();
        Commitments.Admission memory admission = _admission(id);
        bytes32 reasonHash;
        if (!admission.refundMatured) {
            reasonHash = StreamNativeCuratedUnlock.verifiedReason(
                StreamNativeCuratedUnlock.Context(
                    _support(), coreCodeHash, mintManagerCodeHash, moduleRegistryCodeHash
                ),
                id,
                _state.sales[id],
                buyer,
                commitment,
                chosen,
                salt,
                reason
            );
            if (reasonHash == 0) revert CuratedRefundReasonUnavailable(reason);
            admission.refundMatured = true;
        } else {
            reasonHash = keccak256("CURATED_SELECTION_REFUND_MATURED");
        }
        (, amount) = StreamNativeCuratedCommitments.unlockRefund(
            _commitments, id, buyer, commitment, admission
        );
        _requireSolvent();
        emit SelectionRefundReason(id, buyer, commitment, reasonHash);
    }

    function claimSelectionRefund(bytes32 id, address payable recipient)
        external
        override
        nonReentrant
        returns (uint256 amount)
    {
        amount = StreamNativeCuratedCommitments.debitRefund(_commitments, id, msg.sender, recipient);
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert CuratedRefundTransferFailed();
        _requireSolvent();
        emit SelectionRefundClaimed(id, msg.sender, recipient, amount);
    }

    function claimSelectionRefundDelegated(
        bytes32 id,
        address buyer,
        DelegationWitness calldata witness
    ) external override nonReentrant returns (uint256 amount) {
        _requireBuyer(buyer, witness);
        amount = StreamNativeCuratedCommitments.debitDelegatedRefund(_commitments, id, buyer);
        (bool ok,) = payable(buyer).call{ value: amount }("");
        if (!ok) revert CuratedRefundTransferFailed();
        _requireBuyer(buyer, witness);
        _requireSolvent();
        emit SelectionRefundClaimed(id, buyer, buyer, amount);
    }

    function selectionRefundCredit(bytes32 id, address buyer)
        external
        view
        override
        returns (uint256)
    {
        return StreamNativeCuratedCommitments.refundableBalance(_commitments, id, buyer);
    }

    function selectionLiabilities()
        external
        view
        override
        returns (uint256 pending, uint256 refunds, uint256 total)
    {
        return StreamNativeCuratedCommitments.liabilities(_commitments);
    }

    function _additionalLiability() internal view override returns (uint256 total) {
        (,, total) = StreamNativeCuratedCommitments.liabilities(_commitments);
    }

    function _admission(bytes32 id) private view returns (Commitments.Admission memory a) {
        StreamNativeCuratedClock.View memory clock = selectionWindows(id);
        a.windows = Commitments.Windows(
            clock.commitOpen, clock.commitClose, clock.revealOpen, clock.revealClose
        );
        a.stopped = clock.globalPaused || clock.localPaused || clock.collectionStopped;
        a.refundMatured = clock.matured || clock.escapeReached || _state.sales[id].status != 1;
    }

    function _observeWindows(bytes32 id) private {
        StreamNativeCuratedClock.View memory clock = selectionWindows(id);
        emit SelectionWindowObserved(
            id,
            clock.commitClose,
            clock.revealOpen,
            clock.revealClose,
            clock.commitToll,
            clock.revealToll
        );
    }

    function _schedule(Curated.SelectionWindows memory windows)
        private
        pure
        returns (StreamNativeCuratedClock.Schedule memory)
    {
        return StreamNativeCuratedClock.Schedule(
            windows.commitOpen,
            windows.commitClose,
            windows.revealOpen,
            windows.revealClose,
            windows.absoluteEscape
        );
    }
}
