// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRecordPublicationRules.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationHost.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationBindings.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Current admission of detached op24 metadata evidence, independent of historical publication.
library StreamArtistRecordPublicationReads {
    error PublicationReadFailed(address target, bytes4 selector);
    error PublicationParentGas(uint256 available, uint256 required);

    function binding(T.SuiteConfiguration memory suite, uint256 collectionId)
        public
        view
        returns (T.Binding memory b)
    {
        if (block.chainid != IStreamArtistOwner(suite.owners[2]).deploymentChainId()) {
            revert T.InvalidBinding();
        }
        _selected(suite.core, keccak256("ARTIST_REGISTRY"), suite.registry, _cap(suite));
        b = IStreamArtistBindingOwner(suite.owners[0]).binding(collectionId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(collectionId);
        // These values are Attribution states, not Identity status or authority classes.
        if (
            collectionId == 0 || !b.accepted || b.bindingHash == 0 || b.artistId == 0
                || (state != 2 && state != 3) || generation != b.generation || b.consentMode != 1
        ) {
            revert T.InvalidAttribution(collectionId);
        }
        StreamArtistCurrentAuthorityFacts.read(suite.owners[2], b.artistId, false);
        C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(suite.owners[0])
            .bindingTerms(collectionId, generation);
        if (terms.mode != 0 || terms.threshold != 0 || terms.count > 32) {
            revert T.UnsupportedProfile();
        }
        if (
            IStreamArtistCollaboratorRecordsOwner(suite.owners[1]).acceptedCount(b.bindingHash)
                != terms.count
        ) revert T.InvalidAttribution(collectionId);
    }

    function candidate(T.SuiteConfiguration memory suite, P.Publication memory publication)
        public
        view
        returns (bytes32 hostCodeHash)
    {
        uint256 cap = _cap(suite);
        _selected(suite.core, keccak256("ARTIST_REGISTRY"), suite.registry, cap);
        address host =
            _selected(suite.core, keccak256("COLLECTION_METADATA"), publication.metadataHost, cap);
        if (
            abi.decode(
                    _read(
                        host,
                        abi.encodeCall(IStreamArtistRecordPublicationBindings.core, ()),
                        32,
                        cap
                    ),
                    (address)
                ) != suite.core
        ) revert T.ComponentChanged(host);
        bytes32 kind = abi.decode(
            _read(host, abi.encodeCall(IStreamModule.streamModuleType, ()), 32, cap), (bytes32)
        );
        bytes4 interfaceId = abi.decode(
            _read(host, abi.encodeCall(IStreamModule.streamModuleInterfaceId, ()), 32, cap),
            (bytes4)
        );
        address modules = _selected(suite.core, keccak256("MODULE_REGISTRY"), address(0), cap);
        if (
            kind != keccak256("COLLECTION_METADATA") || interfaceId == 0
                || interfaceId == 0xffffffff
                || !abi.decode(
                    _read(
                        modules,
                        abi.encodeCall(
                            IStreamModuleRegistry.isModuleEligible, (host, kind, interfaceId)
                        ),
                        32,
                        cap
                    ),
                    (bool)
                )
                || !abi.decode(
                    _read(
                        host,
                        abi.encodeCall(
                            IERC165.supportsInterface,
                            (type(IStreamArtistRecordPublicationHost).interfaceId)
                        ),
                        32,
                        cap
                    ),
                    (bool)
                )
        ) {
            revert T.ComponentChanged(host);
        }
        (bytes32 actual, uint8 kind_) = abi.decode(
            _read(
                host,
                abi.encodeCall(
                    IStreamArtistRecordPublicationHost.requireArtistRecordCandidate, (publication)
                ),
                64,
                cap
            ),
            (bytes32, uint8)
        );
        (uint8 expected,) =
            StreamArtistRecordPublicationRules.family(publication.recordType, publication.schemaId);
        if (actual == 0 || actual != publication.candidateRecordHash || kind_ != expected) {
            revert T.InvalidRecord();
        }
        return host.codehash;
    }

    function requirePublication(
        T.SuiteConfiguration memory suite,
        bytes32 record,
        P.Publication memory publication
    ) public view returns (P.Evidence memory e) {
        T.Binding memory b = binding(suite, publication.collectionId);
        IStreamArtistRecordPublicationOwner.Record memory saved =
            IStreamArtistRecordPublicationOwner(suite.owners[4]).publicationAttestation(record);
        e = saved.evidence;
        (, uint32 capability) =
            StreamArtistRecordPublicationRules.family(publication.recordType, publication.schemaId);
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(suite.owners[2], b.artistId, false);
        bytes32 publicationHash = keccak256(abi.encode(publication));
        if (
            record == 0 || e.attestationRecordHash != record || e.artistId != b.artistId
                || e.bindingHash != b.bindingHash || e.bindingGeneration != b.generation
                || e.signer != publication.recorder || e.signer != authority.authorityAddress
                || e.authorityClass != authority.authorityClass
                || e.requiredCapability != capability || e.publicationHash != publicationHash
                || keccak256(abi.encode(saved.publication)) != publicationHash
        ) revert T.InvalidRecord();
        if (authority.authorityClass == 3) {
            Estate.AuthorityCapabilities memory caps =
                IStreamArtistEstateOwner(suite.owners[2]).currentAuthorityCapabilities(b.artistId);
            if (
                caps.authorityAddress != authority.authorityAddress || caps.authorityClass != 3
                    || caps.status != 3 || caps.activationRecordHash == 0
                    || (caps.effectiveCapabilities & capability) != capability
            ) {
                revert Estate.EstateCapabilityUnavailable(b.artistId, capability);
            }
        }
        if (candidate(suite, publication) != saved.metadataHostCodeHash) {
            revert T.ComponentChanged(publication.metadataHost);
        }
    }

    function _cap(T.SuiteConfiguration memory suite) private view returns (uint256 cap) {
        uint8 failure;
        uint64 revision;
        (cap,, failure, revision) = IStreamGasParameterHost(suite.registry)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_RECORD_PUBLICATION_READ_GAS"));
        if (cap == 0 || failure != 2 || revision == 0) revert T.InvalidBinding();
    }

    function _selected(address core_, bytes32 kind, address expected, uint256 cap)
        private
        view
        returns (address target)
    {
        bytes memory raw = _read(
            core_, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, cap
        );
        bytes32 word;
        bytes32 codeHash;
        assembly ("memory-safe") {
            word := mload(add(raw, 32))
            codeHash := mload(add(raw, 64))
        }
        target = address(uint160(uint256(word)));
        if (
            uint256(word) >> 160 != 0 || target.code.length == 0 || target.codehash != codeHash
                || (expected != address(0) && target != expected)
        ) revert T.ComponentChanged(target);
    }

    function _read(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory result)
    {
        uint256 available = gasleft();
        if (cap > type(uint256).max / 2) revert PublicationParentGas(available, cap);
        uint256 required = cap + cap / 63 + 20_000;
        if (available < required) revert PublicationParentGas(available, required);
        result = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(result, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert PublicationReadFailed(target, bytes4(data));
    }
}
