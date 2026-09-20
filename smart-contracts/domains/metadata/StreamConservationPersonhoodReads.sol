// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistPersonhoodEvidence,
    StreamArtistPersonhoodTypes as P
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistSuiteReads
} from "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    StreamArtistPersonhoodDefinitions as Definitions
} from "../artist/StreamArtistPersonhoodDefinitions.sol";
import { StreamRecordArtistIdentityReads } from "../records/StreamRecordArtistIdentityReads.sol";

/// @notice Current documentary personhood from the fixed Artist Attribution owner.
/// @dev The authenticated provider must first require its current conservation selection.
/// That selector checks its retained facade/Coordinator/Identity/Binding/Attribution runtime
/// pins. Resolution here rejoins that graph; sampling a current runtime is not a historical pin.
/// RESOLVED evidence returns its proof-summary hash; WAIVER returns its original native record hash.
library StreamConservationPersonhoodReads {
    struct Dependencies {
        // Core, Metadata, currently selected Artist facade.
        address[3] targets;
        bytes32[3] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
    }

    error InvalidConservationPersonhoodContext();
    error ConservationPersonhoodDependencyChanged(address target);
    error ConservationPersonhoodReadFailed(address target, bytes4 selector);
    error ConservationPersonhoodUnavailable(uint256 collectionId, bytes32 artistId);

    /// @notice Returns the original evidence commitment for the current native personhood head.
    /// @dev artistId comes from the preceding authenticated conservation association. Its
    /// registration identity is deliberately not an input: personhood follows operative identity.
    /// Imported evidence retains its original registry and summary; neither is relabelled here.
    function requireCurrent(Dependencies memory d, uint256 collectionId, bytes32 artistId)
        public
        view
        returns (bytes32 evidenceHash)
    {
        if (collectionId == 0 || artistId == 0) {
            revert InvalidConservationPersonhoodContext();
        }
        address attribution = _attribution(d);
        bytes memory raw = _read(
            attribution,
            abi.encodeCall(
                IStreamArtistPersonhoodEvidence.personhoodEvidence, (collectionId, artistId)
            ),
            704,
            d.sourceGas
        );
        P.Selection memory selected = abi.decode(raw, (P.Selection));
        if (keccak256(raw) != keccak256(abi.encode(selected))) {
            revert ConservationPersonhoodReadFailed(
                attribution, IStreamArtistPersonhoodEvidence.personhoodEvidence.selector
            );
        }
        if (
            selected.nativeRecord.recordHash == 0 || selected.nativeRecord.subjectStateHash == 0
                || selected.nativeRecord.statementHash == 0 || selected.nativeRecord.generation == 0
                || selected.nativeRecord.signer == address(0) || !selected.identityCurrent
        ) revert ConservationPersonhoodUnavailable(collectionId, artistId);
        if (
            selected.status == P.Status.WAIVER
                && selected.nativeRecord.schemaId == Definitions.WAIVER_SCHEMA
        ) {
            // This is the actual current op24 waiver, not an absent or stale proof fallback.
            // It has no documentary summary. Preserve its original native-record hash domain.
            return selected.nativeRecord.recordHash;
        }
        _requireEvidence(selected, collectionId, artistId);
        // The pinned original implementation's hashOf first authenticates the entire retained
        // summary. Its RESOLVED read has already joined that summary to this native head,
        // collection, artist, binding generation/hash, operative identity and original report head.
        // Do not reparse documentary payloads or re-evaluate the original signature at sale time.
        evidenceHash = _word(
            _read(
                attribution,
                abi.encodeCall(
                    IStreamArtistPersonhoodEvidence.personhoodProofSummaryHash,
                    (selected.nativeRecord.recordHash)
                ),
                32,
                d.readGas
            ),
            0
        );
        if (evidenceHash == 0) revert ConservationPersonhoodUnavailable(collectionId, artistId);
    }

    function _attribution(Dependencies memory d) private view returns (address attribution) {
        if (
            block.chainid != d.chainId || d.readGas == 0 || d.readGas > type(uint64).max
                || d.sourceGas == 0 || d.sourceGas > type(uint64).max
        ) revert InvalidConservationPersonhoodContext();
        for (uint256 i; i < 3; ++i) {
            _pin(d.targets[i], d.codeHashes[i]);
        }
        _selected(d, keccak256("COLLECTION_METADATA"), 1);
        _selected(d, keccak256("ARTIST_REGISTRY"), 2);
        StreamRecordArtistIdentityReads.Pins memory graph = StreamRecordArtistIdentityReads.resolve(
            d.targets[1], d.targets[0], d.chainId, d.readGas
        );
        if (graph.targets[0] != d.targets[2] || graph.codeHashes[0] != d.codeHashes[2]) {
            revert ConservationPersonhoodDependencyChanged(graph.targets[0]);
        }
        bytes memory raw = _read(
            graph.targets[1],
            abi.encodeCall(IStreamArtistSuiteReads.suiteConfiguration, ()),
            544,
            d.readGas
        );
        T.SuiteConfiguration memory suite = abi.decode(raw, (T.SuiteConfiguration));
        if (keccak256(raw) != keccak256(abi.encode(suite))) {
            revert ConservationPersonhoodReadFailed(
                graph.targets[1], IStreamArtistSuiteReads.suiteConfiguration.selector
            );
        }
        if (
            suite.registry != graph.targets[0] || suite.core != d.targets[0]
                || suite.owners[2] != graph.targets[2]
        ) revert InvalidConservationPersonhoodContext();
        attribution = suite.owners[4];
        if (attribution.code.length == 0) {
            revert ConservationPersonhoodDependencyChanged(attribution);
        }
        if (
            _address(attribution, IStreamArtistOwner.core.selector, d.readGas) != d.targets[0]
                || _address(attribution, IStreamArtistOwner.artistRegistry.selector, d.readGas)
                    != graph.targets[0]
                || _address(
                        attribution, IStreamArtistOwner.operationCoordinator.selector, d.readGas
                    ) != graph.targets[1]
                || _word(
                        _read(
                            attribution,
                            abi.encodeCall(IStreamArtistOwner.deploymentChainId, ()),
                            32,
                            d.readGas
                        ),
                        0
                    ) != bytes32(d.chainId)
        ) revert InvalidConservationPersonhoodContext();
    }

    function _requireEvidence(P.Selection memory s, uint256 collectionId, bytes32 artistId)
        private
        view
    {
        P.Reference memory r = s.evidenceReference;
        if (
            s.status != P.Status.RESOLVED || !s.notarizationCurrent
                || s.nativeRecord.schemaId != Definitions.EVIDENCE_SCHEMA
                || s.sourceRegistry == address(0) || r.version != 1
                || r.profileHash != Definitions.PROFILE_HASH || r.artistRegistry != s.sourceRegistry
                || r.artistId != artistId
                || r.operativeIdentityRecordHash != s.nativeRecord.subjectStateHash
                || r.notarizationHost == address(0) || r.notarizationRuntimeHash == 0
                || r.notarizationRecordHash == 0 || s.notarizationHead != r.notarizationRecordHash
                || s.recorder == address(0)
                || (s.notarizationType != keccak256("INSTITUTIONAL_VERIFICATION")
                    && s.notarizationType != keccak256("ESTATE_VERIFICATION"))
        ) revert ConservationPersonhoodUnavailable(collectionId, artistId);
        _pin(r.notarizationHost, r.notarizationRuntimeHash);
    }

    function _selected(Dependencies memory d, bytes32 role, uint256 index) private view {
        uint256[10] memory w = abi.decode(
            _read(
                d.targets[0],
                abi.encodeCall(IStreamCorePointers.getSatellitePointer, (role)),
                320,
                d.readGas
            ),
            (uint256[10])
        );
        address selected = address(uint160(w[0]));
        if (
            w[0] > type(uint160).max || w[2] > 1 || bytes32(w[3]) != role
                || (w[4] & type(uint224).max) != 0 || w[5] > type(uint160).max || w[6] != 1
                || w[7] == 0 || w[8] == 0 || w[9] == 0 || w[9] > type(uint64).max
                || selected != d.targets[index] || bytes32(w[1]) != d.codeHashes[index]
        ) revert ConservationPersonhoodDependencyChanged(selected);
    }

    function _pin(address target, bytes32 expected) private view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert ConservationPersonhoodDependencyChanged(target);
        }
    }

    function _address(address target, bytes4 selector, uint256 cap) private view returns (address) {
        uint256 value = uint256(_word(_read(target, abi.encodeWithSelector(selector), 32, cap), 0));
        if (value > type(uint160).max) revert ConservationPersonhoodReadFailed(target, selector);
        return address(uint160(value));
    }

    function _word(bytes memory raw, uint256 index) private pure returns (bytes32 value) {
        assembly ("memory-safe") { value := mload(add(add(raw, 32), mul(index, 32))) }
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (target.code.length == 0 || cap == 0 || cap > type(uint64).max) {
            revert ConservationPersonhoodReadFailed(target, bytes4(input));
        }
        raw = new bytes(size);
        // Allocate before admitting the call; retain EIP150 and local bookkeeping headroom.
        if (gasleft() <= cap + cap / 63 + 10000) {
            revert ConservationPersonhoodReadFailed(target, bytes4(input));
        }
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) {
            revert ConservationPersonhoodReadFailed(target, bytes4(input));
        }
    }
}
