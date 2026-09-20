// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPayoutEvidenceReads as Reads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayoutEvidenceReads.sol";
import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistRecoveryRewindEvidence,
    IStreamArtistRecoveryRewindEvidenceBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";

/// @dev Explicit typed Evidence/Identity boundary; no actual recovery-source authority claim.
contract RecoveredPayoutEvidenceFixture {
    W.EnvironmentV3 private _environment;
    W.PayoutOriginalV3 private _original;
    bytes32 private _hash;
    bytes32 private _identityPin;
    bytes32 private _payoutPin;
    address private immutable _caller;

    constructor() {
        _caller = msg.sender;
    }

    function configure(
        W.EnvironmentV3 memory e,
        W.PayoutOriginalV3 memory original,
        bytes32 hash,
        bytes32 identityPin,
        bytes32 payoutPin
    ) external {
        _environment = e;
        _original = original;
        _hash = hash;
        _identityPin = identityPin;
        _payoutPin = payoutPin;
    }

    function owner() external view returns (address) {
        return _environment.identityOwner;
    }

    function payoutOwner() external view returns (address) {
        return _environment.payoutOwner;
    }

    function artistRegistry() external view returns (address) {
        return _environment.registry;
    }

    function deploymentChainId() external view returns (uint256) {
        return _environment.chainId;
    }

    function coordinator() external view returns (address) {
        return _environment.coordinator;
    }

    function archive() external view returns (address) {
        return _environment.archive;
    }

    function core() external view returns (address) {
        return _environment.core;
    }

    function mintManager() external view returns (address) {
        return _environment.manager;
    }

    function payoutOriginalV3(bytes32)
        external
        view
        returns (W.PayoutOriginalV3 memory, bytes32, bytes32, bytes32)
    {
        require(msg.sender == _caller, "original caller changed");
        return (_original, _hash, _identityPin, _payoutPin);
    }
}

contract StreamArtistRecoveredPayoutEvidenceReadsTest {
    address private _target;
    bytes32 private _pin;

    function recoveryRewindEvidenceBinding() external view returns (address, bytes32) {
        return (_target, _pin);
    }

    function moved(W.EnvironmentV3 memory e, bytes32 record)
        external
        view
        returns (W.PayoutOriginalV3 memory, bytes32)
    {
        return Reads.original(e, record);
    }

    // Frozen original private body, exposed solely as an independent transport/error oracle.
    function frozen(W.EnvironmentV3 memory e, bytes32 record)
        external
        view
        returns (W.PayoutOriginalV3 memory original, bytes32 evidenceHash)
    {
        (address target, bytes32 pin) = IStreamArtistRecoveryRewindEvidenceBinding(e.identityOwner)
            .recoveryRewindEvidenceBinding();
        if (pin == 0 || target.code.length == 0 || target.codehash != pin) {
            revert P.InvalidRecoveredPayout(record);
        }
        IStreamArtistRecoveryRewindEvidence publisher = IStreamArtistRecoveryRewindEvidence(target);
        if (
            publisher.owner() != e.identityOwner || publisher.payoutOwner() != e.payoutOwner
                || publisher.artistRegistry() != e.registry
                || publisher.deploymentChainId() != e.chainId
                || publisher.coordinator() != e.coordinator || publisher.archive() != e.archive
                || publisher.core() != e.core || publisher.mintManager() != e.manager
        ) {
            revert P.InvalidRecoveredPayout(record);
        }
        bytes32 identityPin;
        bytes32 payoutPin;
        (original, evidenceHash, identityPin, payoutPin) = publisher.payoutOriginalV3(record);
        if (
            identityPin != e.identityCodeHash || payoutPin != e.payoutCodeHash
                || original.recordHash != record
                || evidenceHash != W.payoutOriginalHash(e, original)
        ) {
            revert P.InvalidRecoveredPayout(record);
        }
    }

    function _setup()
        private
        returns (
            RecoveredPayoutEvidenceFixture source,
            W.EnvironmentV3 memory e,
            W.PayoutOriginalV3 memory original,
            bytes32 hash
        )
    {
        source = new RecoveredPayoutEvidenceFixture();
        _target = address(source);
        _pin = address(source).codehash;
        e = W.EnvironmentV3(
            1,
            address(2),
            address(this),
            bytes32(uint256(3)),
            address(4),
            bytes32(uint256(5)),
            address(6),
            address(7),
            address(8),
            address(9)
        );
        original = W.PayoutOriginalV3(
            bytes32(uint256(11)),
            T.PayoutDesignation(bytes32(uint256(12)), address(13), bytes32(uint256(14))),
            address(15),
            3,
            16,
            17
        );
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_ORIGINAL_V3"), uint16(3), e, original
            )
        );
        source.configure(e, original, hash, e.identityCodeHash, e.payoutCodeHash);
    }

    function _same(W.EnvironmentV3 memory e, bytes32 record, bytes memory expected, bool success)
        private
        view
    {
        (bool a, bytes memory x) =
            address(this).staticcall(abi.encodeCall(this.frozen, (e, record)));
        (bool b, bytes memory y) = address(this).staticcall(abi.encodeCall(this.moved, (e, record)));
        require(a == success && b == success, "status");
        require(
            keccak256(x) == keccak256(expected) && keccak256(y) == keccak256(expected),
            "exact return/error"
        );
    }

    function testLiteralOriginalTupleAndDelegateHostCaller() public {
        (, W.EnvironmentV3 memory e, W.PayoutOriginalV3 memory original, bytes32 hash) = _setup();
        _same(e, original.recordHash, abi.encode(original, hash), true);
    }

    function testBindingZeroMissingCodeAndWrongPinRestore() public {
        (
            RecoveredPayoutEvidenceFixture source,
            W.EnvironmentV3 memory e,
            W.PayoutOriginalV3 memory original,
            bytes32 hash
        ) = _setup();
        bytes memory failure =
            abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, original.recordHash);
        _pin = 0;
        _same(e, original.recordHash, failure, false);
        _pin = address(source).codehash;
        _target = address(0x1234);
        _same(e, original.recordHash, failure, false);
        _target = address(source);
        _pin = bytes32(uint256(1));
        _same(e, original.recordHash, failure, false);
        _pin = address(source).codehash;
        _same(e, original.recordHash, abi.encode(original, hash), true);
    }

    function testEveryPublisherEnvironmentFieldAndExactRestore() public {
        (
            RecoveredPayoutEvidenceFixture source,
            W.EnvironmentV3 memory e,
            W.PayoutOriginalV3 memory original,
            bytes32 hash
        ) = _setup();
        uint8[8] memory words = [uint8(2), 4, 1, 0, 6, 7, 8, 9];
        for (uint256 i; i < words.length; ++i) {
            // Independent deep copy avoids aliasing the expected environment.
            W.EnvironmentV3 memory changed = abi.decode(abi.encode(e), (W.EnvironmentV3));
            uint256 index = words[i];
            assembly ("memory-safe") {
                let at := add(changed, mul(index, 32))
                mstore(at, xor(mload(at), 1))
            }
            source.configure(changed, original, hash, e.identityCodeHash, e.payoutCodeHash);
            _same(
                e,
                original.recordHash,
                abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, original.recordHash),
                false
            );
            source.configure(e, original, hash, e.identityCodeHash, e.payoutCodeHash);
            _same(e, original.recordHash, abi.encode(original, hash), true);
        }
    }

    function testReturnedPinsRecordAndDigestFailuresRestore() public {
        (
            RecoveredPayoutEvidenceFixture source,
            W.EnvironmentV3 memory e,
            W.PayoutOriginalV3 memory original,
            bytes32 hash
        ) = _setup();
        for (uint256 i; i < 4; ++i) {
            W.PayoutOriginalV3 memory changed =
                abi.decode(abi.encode(original), (W.PayoutOriginalV3));
            if (i == 2) changed.recordHash = bytes32(uint256(99));
            source.configure(
                e,
                changed,
                i == 3 ? bytes32(uint256(99)) : hash,
                i == 0 ? bytes32(uint256(99)) : e.identityCodeHash,
                i == 1 ? bytes32(uint256(99)) : e.payoutCodeHash
            );
            _same(
                e,
                original.recordHash,
                abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, original.recordHash),
                false
            );
            source.configure(e, original, hash, e.identityCodeHash, e.payoutCodeHash);
            _same(e, original.recordHash, abi.encode(original, hash), true);
        }
    }
}
