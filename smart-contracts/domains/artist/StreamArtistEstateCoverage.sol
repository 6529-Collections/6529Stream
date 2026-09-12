// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import "../../interfaces/stream/preservation/IStreamArchivalCoverage.sol";
import "../../interfaces/stream/preservation/IStreamArchivalCheckpointVerifier.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "./StreamArtistTimingState.sol";

/// @notice Fixed provider pin/admission for the estate recipe; no semantic state or mutable routing.
library StreamArtistEstateCoverage {
    function admit(address core, address manager, address executor, address provider)
        public
        view
        returns (bytes32 configuration)
    {
        if (
            StreamArtistTimingState.canonicalAuthority(core, manager) != executor
                || provider.code.length == 0
                || _address(provider, abi.encodeCall(IStreamArchivalCoverage.core, ())) != core
                || _address(provider, abi.encodeWithSignature("governanceAuthority()")) != executor
                || _word(
                        provider,
                        abi.encodeCall(
                            IStreamArchivalCoverage.supportsInterface,
                            (type(IStreamArchivalCoverage).interfaceId)
                        )
                    ) != bytes32(uint256(1))
                || _word(provider, abi.encodeCall(IStreamArchivalCoverage.profileHash, ()))
                    != keccak256("6529STREAM_PUBLIC_DUAL_FAMILY_ARCHIVAL_V1")
        ) {
            revert T.InvalidBinding();
        }
        address verifier =
            _address(provider, abi.encodeCall(IStreamArchivalCoverage.checkpointVerifier, ()));
        bytes32 observerConfig = _word(
            verifier, abi.encodeCall(IStreamArchivalCheckpointVerifier.configurationHash, ())
        );
        if (
            observerConfig == bytes32(0)
                || _address(verifier, abi.encodeWithSignature("governanceAuthority()")) != executor
                || _word(
                        verifier, abi.encodeCall(IStreamArchivalCheckpointVerifier.profileHash, ())
                    ) != keccak256("6529STREAM_ARWEAVE_SINGLE_CHUNK_QUORUM_V1")
        ) revert T.InvalidBinding();
        configuration = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ARCHIVAL_COVERAGE_BINDING_V1"),
                block.chainid,
                core,
                executor,
                provider,
                provider.codehash,
                verifier,
                verifier.codehash,
                observerConfig
            )
        );
    }

    function requireCoverage(
        address registry,
        address core,
        bytes32 record,
        bytes32 artistId,
        bytes32 evidenceHash
    ) public view returns (StreamArchivalTypes.CoverageFacts memory facts) {
        uint256 cap = IStreamGasParameterHost(registry)
            .gasParameter(keccak256("6529STREAM_GGP_ARTIST_ARCHIVAL_COVERAGE_READ_GAS"));
        bytes memory pointer = _fixed(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY"))),
            320,
            cap
        );
        uint256 word;
        bytes32 codeHash;
        assembly ("memory-safe") {
            word := mload(add(pointer, 32))
            codeHash := mload(add(pointer, 64))
        }
        if (
            word >> 160 != 0 || address(uint160(word)) != registry || registry.code.length == 0
                || codeHash != registry.codehash
        ) revert T.ComponentChanged(registry);
        address provider = IStreamArtistEstateBinding(registry).archivalCoverage();
        if (
            provider.code.length == 0
                || provider.codehash
                    != IStreamArtistEstateBinding(registry).archivalCoverageCodeHash()
        ) {
            revert T.ComponentChanged(provider);
        }
        facts = abi.decode(
            _fixed(
                provider,
                abi.encodeCall(
                    IStreamArchivalCoverage.requireCoverage, (record, artistId, evidenceHash)
                ),
                384,
                cap
            ),
            (StreamArchivalTypes.CoverageFacts)
        );
        if (
            facts.coverageRecordHash != record || record == bytes32(0) || facts.artistId != artistId
                || facts.evidenceHash != evidenceHash || facts.envelopeHash == bytes32(0)
        ) {
            revert Estate.InvalidEstateCoverage(record);
        }
    }

    function _address(address target, bytes memory data) private view returns (address result) {
        uint256 word = uint256(_word(target, data));
        if (word >> 160 != 0 || word == 0 || address(uint160(word)).code.length == 0) {
            revert T.InvalidBinding();
        }
        return address(uint160(word));
    }

    function _word(address target, bytes memory data) private view returns (bytes32) {
        return abi.decode(_fixed(target, data, 32, 150000), (bytes32));
    }

    function _fixed(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory result)
    {
        if (cap == 0 || gasleft() < 10000 || (gasleft() - 10000) / 64 * 63 < cap) {
            revert T.ComponentChanged(target);
        }
        result = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(result, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert T.ComponentChanged(target);
    }
}
