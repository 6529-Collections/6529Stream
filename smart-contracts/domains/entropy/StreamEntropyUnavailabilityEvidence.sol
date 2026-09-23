// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";

/// @notice Bounded current Artist finding read; the existing Identity epoch owns cancellation.
library StreamEntropyUnavailabilityEvidence {
    function requireFinding(
        IStreamCore core,
        IStreamEntropyFreshRecovery.RecoveryInput memory input,
        bytes32 intentHash,
        bytes32 expected
    ) public view returns (uint64 noticeEndsAt) {
        if (expected == 0) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        (address registry, bytes32 hash,,,,,,,,) =
            core.getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (registry.code.length == 0 || registry.codehash != hash) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        if (
            abi.decode(_read(registry, abi.encodeWithSignature("core()"), 32, 100000), (uint256))
                != uint256(uint160(address(core)))
        ) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        bytes memory raw = _read(
            registry,
            abi.encodeWithSignature(
                "gasParameterInfo(bytes32)", keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS")
            ),
            128,
            100000
        );
        (uint256 cap, uint256 floor, uint256 direction, uint256 revision) =
            abi.decode(raw, (uint256, uint256, uint256, uint256));
        if (
            cap == 0 || cap == type(uint256).max || floor == 0 || cap < floor || direction != 2
                || revision == 0
        ) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        raw = _read(
            registry,
            abi.encodeCall(
                IStreamArtistEntropyUnavailability.verifyEntropyRecoveryUnavailability,
                (address(this), input, intentHash, expected)
            ),
            128,
            cap
        );
        (uint256 valid, bytes32 actual, bytes32 artistId, uint256 ends) =
            abi.decode(raw, (uint256, bytes32, bytes32, uint256));
        if (
            valid != 1 || actual != expected || artistId == 0 || ends == 0
                || ends > type(uint64).max || block.timestamp < ends
        ) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        return uint64(ends);
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory out)
    {
        out = new bytes(size);
        uint256 available = gasleft();
        if (available <= 105000) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
        if (cap > available - 105000) cap = available - 105000;
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) {
            revert IStreamEntropyFreshRecovery.FreshRecoveryArtistEvidenceUnavailable();
        }
    }
}
