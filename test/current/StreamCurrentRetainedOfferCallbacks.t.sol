// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CurrentDelegatedNativeOfferContinuityFixture
} from "../helpers/CurrentDelegatedNativeOfferContinuityFixture.sol";
import {
    CurrentDelegatedERC20OfferContinuityFixture
} from "../helpers/CurrentDelegatedOfferContinuityFixture.sol";
import {
    CurrentDelegatedCustodyOfferContinuityFixture
} from "../helpers/CurrentDelegatedCustodyOfferContinuityFixture.sol";
import {
    CurrentOfferSafeCallbackFixture,
    CurrentOfferSafeCallback
} from "../helpers/CurrentOfferSafeCallbackFixture.sol";
import {
    ModuleRegistryStatus as CallbackModuleStatus
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    ReentrancyGuard as CallbackReentrancyGuard
} from "../../smart-contracts/vendor/openzeppelin/ReentrancyGuard.sol";
import {
    StreamERC20PrimarySettlementAdapter as CallbackPayment
} from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";

/// @dev Actual current Artist/Governor/Core/Manager/gate/Recorder/floor/Coordinator and upstream
/// Safes/NFTDelegation. External entropy service, ERC20 asset and this explicit receiver/module
/// are fixtures. GS013 alone does not identify its inner error: exact callback, real revocation
/// and post-revocation selector call expectations establish late reachability. The eventual
/// native trace must still confirm the carrier's post-callback DelegationReadFailed reason.
/// Existing callback gas caps are unchanged; authored source does not prove cap acceptance.
contract StreamCurrentRetainedNativeOfferCallbacksTest is
    CurrentDelegatedNativeOfferContinuityFixture,
    CurrentOfferSafeCallbackFixture
{
    function testCurrentSelectedNativeCallbackRevokesLiveGrantRollsBackAndExactSafeRetryRejectsReentry()
        public
    {
        _deployDelegatedNativeOffers();
        CurrentOfferSafeCallback callback = _installOfferCallback(
            joinedBuyer,
            joinedArtist,
            joinedKeys,
            CurrentOfferSafeCallback.Binding(
                address(core),
                address(nativeOfferDelegates),
                address(joinedCollaborator),
                address(artistNativeOffers),
                address(artistNativeOffers),
                address(artistNativeOffers)
            )
        );
        DelegatedNativePlan memory p = _armDelegatedNativeOffer(true, true, true);
        _delegatedNativeStatus(address(artistNativeOffers), CallbackModuleStatus.DEPRECATED);
        _armOfferCallback(
            callback,
            joinedArtist,
            joinedKeys,
            p.input,
            NATIVE_CONTINUITY_VALUE,
            CallbackReentrancyGuard.ReentrancyGuardReentrantCall.selector
        );
        bytes32 envelopeHash = keccak256(p.envelope);
        bytes32 inputHash = keccak256(p.input);
        uint256 buyerNonce = joinedBuyer.nonce();
        uint256 controllerNonce = joinedArtist.nonce();
        (bool ok, bytes memory reason) = address(p.executorSafe).call(p.envelope);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && p.executorSafe.nonce() == p.executorNonce
                && address(p.executorSafe).balance == p.executorBalance
                && address(joinedBuyer).balance == p.buyerBalance
                && joinedBuyer.nonce() == buyerNonce,
            "actual failed executor Safe restores both principals, native value and transaction nonce"
        );
        _delegatedNativeUnused(p);
        _assertOfferCallbackRolledBack(callback);
        _disableOfferCallbackMutation(callback, joinedArtist, joinedKeys);
        require(
            joinedArtist.nonce() == controllerNonce + 1 && joinedBuyer.nonce() == buyerNonce
                && p.executorSafe.nonce() == p.executorNonce
                && keccak256(p.envelope) == envelopeHash && keccak256(p.input) == inputHash,
            "independent controller preserves original buyer/seller proofs and executor envelope"
        );
        _completeDelegatedNativeOffer(p);
        _assertOfferCallbackCompleted(callback);
        _assertOfferCallbackSignature(joinedBuyer, joinedKeys);
        require(joinedBuyer.nonce() == buyerNonce, "buyer module never spends a threshold nonce");
    }
}

contract StreamCurrentRetainedERC20OfferCallbacksTest is
    CurrentDelegatedERC20OfferContinuityFixture,
    CurrentOfferSafeCallbackFixture
{
    function testCurrentSelectedERC20CallbackRevokesLiveGrantRollsBackAndExactSafeRetryRejectsReentry()
        public
    {
        _deployArtistERC20Offers();
        CurrentOfferSafeCallback callback = _installOfferCallback(
            joinedBuyer,
            joinedArtist,
            joinedKeys,
            CurrentOfferSafeCallback.Binding(
                address(core),
                address(offerDelegates),
                address(joinedCollaborator),
                address(offerPayment),
                address(manager),
                address(0)
            )
        );
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(true, true, true);
        _delegatedOfferStatus(address(artistOffers), CallbackModuleStatus.DEPRECATED);
        _delegatedOfferStatus(address(offerPayment), CallbackModuleStatus.DEPRECATED);
        _armOfferCallback(
            callback,
            joinedArtist,
            joinedKeys,
            p.paymentInput,
            0,
            CallbackPayment.PaymentOperationActive.selector
        );
        bytes32 envelopeHash = keccak256(p.envelope);
        bytes32 inputHash = keccak256(p.paymentInput);
        bytes32 intentHash = keccak256(abi.encode(p.intent));
        uint256 buyerNonce = joinedBuyer.nonce();
        uint256 controllerNonce = joinedArtist.nonce();
        uint256 buyerNative = address(joinedBuyer).balance;
        uint256 executorNative = address(p.executorSafe).balance;
        _delegatedERC20EnvelopeFailure(p);
        _assertOfferCallbackRolledBack(callback);
        require(
            joinedBuyer.nonce() == buyerNonce && address(joinedBuyer).balance == buyerNative
                && address(p.executorSafe).balance == executorNative,
            "actual token failure also restores both native principals"
        );
        _disableOfferCallbackMutation(callback, joinedArtist, joinedKeys);
        require(
            joinedArtist.nonce() == controllerNonce + 1 && joinedBuyer.nonce() == buyerNonce
                && p.executorSafe.nonce() == p.executorNonce
                && keccak256(p.envelope) == envelopeHash && keccak256(p.paymentInput) == inputHash
                && keccak256(abi.encode(p.intent)) == intentHash,
            "same original candidate, three proofs, payer intent and executor Safe envelope"
        );
        _completeDelegatedERC20Offer(p);
        _assertOfferCallbackCompleted(callback);
        _assertOfferCallbackSignature(joinedBuyer, joinedKeys);
        require(
            joinedBuyer.nonce() == buyerNonce && address(joinedBuyer).balance == buyerNative
                && address(p.executorSafe).balance == executorNative,
            "ERC20 selected flow consumes no native value or payer threshold nonce"
        );
    }
}

contract StreamCurrentRetainedCustodyOfferCallbacksTest is
    CurrentDelegatedCustodyOfferContinuityFixture,
    CurrentOfferSafeCallbackFixture
{
    function testCurrentCustodyCallbackRevokesLiveGrantRollsBackAndExactBuyerSafeRetryRejectsReentry()
        public
    {
        _deployDelegatedCustodyOffers();
        CurrentOfferSafeCallback callback = _installOfferCallback(
            joinedBuyer,
            joinedArtist,
            joinedKeys,
            CurrentOfferSafeCallback.Binding(
                address(core),
                address(custodyDelegates),
                address(custodyDelegate),
                address(custodyOffers),
                address(custodyOffers),
                address(custodyOffers)
            )
        );
        CustodyOfferPlan memory p = _armCustodyOffer(true);
        _custodyStatus(address(custodyOffers), CallbackModuleStatus.DEPRECATED);
        _armOfferCallback(
            callback,
            joinedArtist,
            joinedKeys,
            p.input,
            CUSTODY_OFFER_PRICE + CUSTODY_OFFER_EXCESS,
            CallbackReentrancyGuard.ReentrancyGuardReentrantCall.selector
        );
        bytes32 envelopeHash = keccak256(p.envelope);
        bytes32 inputHash = keccak256(p.input);
        uint256 controllerNonce = joinedArtist.nonce();
        _custodySafeFailure(joinedBuyer, p.envelope);
        _custodyUnused(p);
        _assertOfferCallbackRolledBack(callback);
        require(
            joinedBuyer.nonce() == p.buyerNonce, "buyer-owned original threshold nonce restored"
        );
        _disableOfferCallbackMutation(callback, joinedArtist, joinedKeys);
        require(
            joinedArtist.nonce() == controllerNonce + 1 && joinedBuyer.nonce() == p.buyerNonce
                && keccak256(p.envelope) == envelopeHash && keccak256(p.input) == inputHash,
            "module revocation and separate controller need no replacement buyer envelope or proofs"
        );
        _custodyComplete(p);
        _assertOfferCallbackCompleted(callback);
        _assertOfferCallbackSignature(joinedBuyer, joinedKeys);
        // _custodyUnused/_custodyComplete also pin the original paid token's primary receipt,
        // rights facts, royalty snapshot, floor receipt, collection total and Manager nonce.
        _custodyPrimaryUnchanged();
    }
}
