// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { OfficialSafe, OfficialSafeFixture } from "./OfficialSafeFixture.sol";
import {
    DelegationManagementContract as CallbackDelegations
} from "../../smart-contracts/integrations/delegation/NFTdelegation.sol";

interface CurrentOfferCallbackSafe {
    function setFallbackHandler(address handler) external;
    function enableModule(address module) external;
    function isModuleEnabled(address module) external view returns (bool);
    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success, bytes memory returnData);
}

interface CurrentOfferCallbackCore {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface CurrentOfferCallbackRegistry {
    function globalDelegationHashes(bytes32 key, uint256 index)
        external
        view
        returns (address, address, uint256, uint256, bool, uint256);
}

interface CurrentOfferCallbackCallsVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @dev Data only: STOP followed by the complete original commercial calldata. No production
/// response or state is supplied. The size ceiling leaves ordinary runtime/init-code headroom.
contract CurrentOfferCallbackPayload {
    constructor(bytes memory data) {
        require(data.length >= 4 && data.length <= 20_000, "bounded original callback payload");
        bytes memory runtime = bytes.concat(hex"00", data);
        assembly ("memory-safe") { return(add(runtime, 32), mload(runtime)) }
    }
}

/// @dev Installed by actual buyer Safe self-transactions as both fallback handler and module.
/// Only its bound Core's delivery of token 1 invokes the mutation path. Unrecognized calls
/// delegatecall the byte-pinned upstream 1.4.1 handler, preserving msg.sender == buyer Safe
/// for both ERC1271 overloads. Ordinary CALL forwarding would change that signature domain.
contract CurrentOfferSafeCallback {
    struct Binding {
        address core;
        address registry;
        address delegate;
        address carrier;
        address operator;
        address from;
    }

    address public immutable buyer;
    address public immutable controller;
    address public immutable officialHandler;
    bytes32 public immutable officialHandlerHash;
    address public immutable core;
    address public immutable registry;
    address public immutable delegate;
    address public immutable carrier;
    address public immutable expectedOperator;
    address public immutable expectedFrom;
    bytes32 public immutable grantKey;
    address public payload;
    uint256 public payloadLength;
    bytes32 public payloadHash;
    bytes32 public payloadRuntimeHash;
    uint256 public reentryValue;
    bytes4 public expectedGuard;
    bytes32 public originalGrantHash;
    bool public revokeOnReceive;
    uint256 public callbacks;
    bytes32 public observedGuardHash;

    constructor(
        address buyer_,
        address controller_,
        address handler_,
        bytes32 handlerHash_,
        Binding memory b
    ) {
        require(
            buyer_ != controller_ && buyer_.code.length != 0 && controller_.code.length != 0
                && handler_.codehash == handlerHash_ && handler_.code.length != 0
                && b.core.code.length != 0 && b.registry.code.length != 0
                && b.delegate.code.length != 0 && b.carrier.code.length != 0,
            "actual separate Safes, original handler and production targets"
        );
        buyer = buyer_;
        controller = controller_;
        officialHandler = handler_;
        officialHandlerHash = handlerHash_;
        core = b.core;
        registry = b.registry;
        delegate = b.delegate;
        carrier = b.carrier;
        expectedOperator = b.operator;
        expectedFrom = b.from;
        grantKey = keccak256(abi.encodePacked(buyer_, b.core, b.delegate, uint256(2)));
    }

    function arm(bytes calldata input, uint256 value, bytes4 guard) external {
        require(msg.sender == controller && payload == address(0), "controller arms once");
        require(guard != bytes4(0), "exact production guard required");
        require(
            type(CurrentOfferCallbackPayload).creationCode.length + abi.encode(input).length
                <= 49_152,
            "ordinary init-code bound"
        );
        payload = address(new CurrentOfferCallbackPayload(input));
        payloadLength = input.length;
        payloadHash = keccak256(input);
        payloadRuntimeHash = keccak256(bytes.concat(hex"00", input));
        require(
            payload.code.length == input.length + 1 && payload.codehash == payloadRuntimeHash,
            "exact immutable original input bytes"
        );
        reentryValue = value;
        expectedGuard = guard;
        originalGrantHash = liveGrantHash();
        revokeOnReceive = true;
    }

    function setRevokeOnReceive(bool enabled) external {
        require(msg.sender == controller && payload != address(0), "configuration Safe only");
        revokeOnReceive = enabled;
    }

    function liveGrantHash() public view returns (bytes32) {
        (address vault, address target, uint256 start, uint256 end, bool allTokens, uint256 token) =
            CallbackDelegations(registry).globalDelegationHashes(grantKey, 0);
        require(
            vault == buyer && target == delegate && start <= block.timestamp
                && end > block.timestamp && allTokens && token == 0,
            "original live Core-scoped buyer grant at witness zero"
        );
        return keccak256(abi.encode(vault, target, start, end, allTokens, token));
    }

    function originalInput() public view returns (bytes memory input) {
        address source = payload;
        require(
            source != address(0) && source.code.length == payloadLength + 1
                && source.codehash == payloadRuntimeHash,
            "immutable payload runtime intact"
        );
        input = new bytes(payloadLength);
        assembly ("memory-safe") { extcodecopy(source, add(input, 32), 1, mload(input)) }
        require(keccak256(input) == payloadHash, "original reentrant input intact");
    }

    function revokeInput() public view returns (bytes memory) {
        return
            abi.encodeCall(
                CallbackDelegations.revokeDelegationAddress, (core, delegate, uint256(2))
            );
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        address originalCaller;
        // Safe FallbackManager appends the original caller as an unpadded 20-byte trailer.
        assembly ("memory-safe") {
            originalCaller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
        require(
            msg.sender == buyer && originalCaller == core && tokenId == 1 && data.length == 0
                && operator == expectedOperator && from == expectedFrom
                && CurrentOfferCallbackCore(core).ownerOf(1) == buyer,
            "actual bound Core delivery and already-transferred buyer ownership"
        );
        require(liveGrantHash() == originalGrantHash, "grant remains live at delivery entry");
        uint256 nonce = OfficialSafe(buyer).nonce();
        ++callbacks;
        (bool ok, bytes memory reason) = CurrentOfferCallbackSafe(buyer)
            .execTransactionFromModuleReturnData(carrier, reentryValue, originalInput(), 0);
        require(
            !ok && reason.length == 4
                && keccak256(reason) == keccak256(abi.encodePacked(expectedGuard)),
            "actual same-input reentry reaches the exact production guard"
        );
        observedGuardHash = keccak256(reason);
        require(
            OfficialSafe(buyer).nonce() == nonce, "module reentry spends no Safe transaction nonce"
        );
        if (revokeOnReceive) {
            (ok, reason) = CurrentOfferCallbackSafe(buyer)
                .execTransactionFromModuleReturnData(registry, 0, revokeInput(), 0);
            require(ok && reason.length == 0, "actual buyer-owned provider revocation succeeds");
            (ok,) = registry.staticcall(
                abi.encodeCall(
                    CurrentOfferCallbackRegistry.globalDelegationHashes, (grantKey, uint256(0))
                )
            );
            require(!ok, "original witness row is actually absent before returning to production");
            require(
                OfficialSafe(buyer).nonce() == nonce, "module grant mutation spends no Safe nonce"
            );
            // Exact call expectation on this final selector distinguishes a completed revocation
            // from an earlier callback failure hidden by the outer Safe's GS013.
            return this.afterRevocationReceiverSelector();
        }
        return this.onERC721Received.selector;
    }

    function afterRevocationReceiverSelector() external view returns (bytes4) {
        require(msg.sender == address(this), "only the completed callback");
        return this.onERC721Received.selector;
    }

    fallback() external {
        require(msg.sender == buyer, "only installed buyer Safe forwarding");
        address handler = officialHandler;
        require(handler.codehash == officialHandlerHash, "original upstream handler runtime intact");
        assembly ("memory-safe") {
            let p := mload(0x40)
            calldatacopy(p, 0, calldatasize())
            let ok := delegatecall(gas(), handler, p, calldatasize(), 0, 0)
            returndatacopy(p, 0, returndatasize())
            switch ok
            case 0 { revert(p, returndatasize()) }
            default { return(p, returndatasize()) }
        }
    }
}

/// @dev Common test plumbing only. No public tests or substituted production callbacks/reads.
abstract contract CurrentOfferSafeCallbackFixture is OfficialSafeFixture {
    function _installOfferCallback(
        OfficialSafe buyer,
        OfficialSafe controller,
        uint256[] memory keys,
        CurrentOfferSafeCallback.Binding memory binding
    ) internal returns (CurrentOfferSafeCallback callback) {
        string memory fixture = safeVm.readFile("test/fixtures/safe/1.4.1.json");
        bytes memory creation = safeVm.parseJsonBytes(fixture, ".handler.creationCode");
        bytes memory runtime = safeVm.parseJsonBytes(fixture, ".handler.runtimeCode");
        address handler;
        assembly ("memory-safe") { handler := create(0, add(creation, 32), mload(creation)) }
        require(
            handler != address(0) && handler.codehash == keccak256(runtime),
            "exact upstream Safe 1.4.1 CompatibilityFallbackHandler bytes"
        );
        callback = new CurrentOfferSafeCallback(
            address(buyer), address(controller), handler, keccak256(runtime), binding
        );
        uint256 beforeNonce = buyer.nonce();
        require(
            executeSafe(
                buyer,
                keys,
                address(buyer),
                0,
                abi.encodeCall(CurrentOfferCallbackSafe.setFallbackHandler, (address(callback))),
                0
            )
            && executeSafe(
                buyer,
                keys,
                address(buyer),
                0,
                abi.encodeCall(CurrentOfferCallbackSafe.enableModule, (address(callback))),
                0
            ) && buyer.nonce() == beforeNonce + 2
            && CurrentOfferCallbackSafe(address(buyer)).isModuleEnabled(address(callback)),
            "actual buyer Safe self-transactions install handler and module before plan signing"
        );
        _assertOfferCallbackSignature(buyer, keys);
    }

    function _armOfferCallback(
        CurrentOfferSafeCallback callback,
        OfficialSafe controller,
        uint256[] memory keys,
        bytes memory input,
        uint256 value,
        bytes4 guard
    ) internal {
        require(
            executeSafe(
                controller,
                keys,
                address(callback),
                0,
                abi.encodeCall(callback.arm, (input, value, guard)),
                0
            ),
            "separate configuration Safe arms original callback bytes"
        );
        require(
            callback.payloadHash() == keccak256(input) && callback.payloadLength() == input.length
                && callback.payloadRuntimeHash() == keccak256(bytes.concat(hex"00", input)),
            "source hash, runtime and complete acceptance input pinned"
        );
        CurrentOfferCallbackCallsVm callsVm = CurrentOfferCallbackCallsVm(address(safeVm));
        bytes memory received = abi.encodeWithSelector(
            callback.onERC721Received.selector,
            callback.expectedOperator(),
            callback.expectedFrom(),
            uint256(1),
            bytes("")
        );
        // Once in the rejected threshold transaction, once in its exact successful retry.
        callsVm.expectCall(callback.buyer(), 0, received, 2);
        callsVm.expectCall(
            address(callback), 0, bytes.concat(received, bytes20(callback.core())), 2
        );
        callsVm.expectCall(
            callback.buyer(),
            0,
            abi.encodeCall(
                CurrentOfferCallbackSafe.execTransactionFromModuleReturnData,
                (callback.carrier(), value, input, uint8(0))
            ),
            2
        );
        bytes memory revoke = callback.revokeInput();
        callsVm.expectCall(
            callback.buyer(),
            0,
            abi.encodeCall(
                CurrentOfferCallbackSafe.execTransactionFromModuleReturnData,
                (callback.registry(), uint256(0), revoke, uint8(0))
            ),
            1
        );
        callsVm.expectCall(callback.registry(), 0, revoke, 1);
        callsVm.expectCall(
            address(callback), 0, abi.encodeCall(callback.afterRevocationReceiverSelector, ()), 1
        );
    }

    function _assertOfferCallbackRolledBack(CurrentOfferSafeCallback callback) internal view {
        require(
            callback.callbacks() == 0 && callback.observedGuardHash() == 0
                && callback.liveGrantHash() == callback.originalGrantHash()
                && callback.revokeOnReceive(),
            "real grant and callback observations roll back with the commercial attempt"
        );
    }

    function _disableOfferCallbackMutation(
        CurrentOfferSafeCallback callback,
        OfficialSafe controller,
        uint256[] memory keys
    ) internal {
        require(
            executeSafe(
                controller,
                keys,
                address(callback),
                0,
                abi.encodeCall(callback.setRevokeOnReceive, (false)),
                0
            ),
            "separate configuration Safe changes only recipient mutation behavior"
        );
    }

    function _assertOfferCallbackCompleted(CurrentOfferSafeCallback callback) internal view {
        require(
            callback.callbacks() == 1 && !callback.revokeOnReceive()
                && callback.observedGuardHash()
                    == keccak256(abi.encodePacked(callback.expectedGuard()))
                && callback.liveGrantHash() == callback.originalGrantHash(),
            "one delivered NFT, exact guard refusal, original real grant remains live"
        );
    }

    function _assertOfferCallbackSignature(OfficialSafe buyer, uint256[] memory keys) internal {
        bytes32 digest = keccak256("original Safe ERC1271 through callback handler");
        bytes memory proof =
            safeThresholdSignature(keys, safeMessageDigest(buyer, abi.encode(digest)));
        (bool ok, bytes memory result) = address(buyer)
            .staticcall(abi.encodeWithSignature("isValidSignature(bytes32,bytes)", digest, proof));
        require(
            ok && result.length == 32 && abi.decode(result, (bytes4)) == bytes4(0x1626ba7e),
            "unchanged official Safe domain and threshold verification through original handler"
        );
    }
}
