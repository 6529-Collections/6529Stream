// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAttributionPolicy.sol";

import "./StreamArtistContentOperations.sol";
import "./StreamArtistSaleHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Typed sale consent over registered immutable adapter facts and actual artist owners.
/// @dev Caller-sensitive validation receives the original adapter from the facade explicitly.
library StreamArtistSaleOperations {
    bytes32 private constant _READ_GAS = keccak256("6529STREAM_GGP_ARTIST_SALE_FACTS_READ_GAS");

    function record(
        StreamArtistDelegationTypes.CoordinatorContext memory x,
        address actor,
        Sale.Consent memory p,
        T.Authorization memory a
    ) public returns (bytes32 result) {
        T.Snapshot[7] memory prior = _snapshots(x.suite);
        T.Binding memory b = _binding(x.suite, p.collectionId, true);
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        bytes memory facts = _adapter(x.suite, p);
        bytes32 digest = StreamArtistSaleHashes.digest(_environment(x.suite), p, a);
        bool direct = actor == authority.authorityAddress && a.signature.length == 0;
        if (actor == address(0)) revert T.InvalidSignature();
        if (!direct) {
            (uint256 cap,, uint8 failure, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failure != 2
                    || !StreamArtistRegistryValidatorBase(x.suite.validator)
                        .validateSignerProof(authority.authorityAddress, digest, a.signature, cap)
            ) {
                revert T.InvalidSignature();
            }
        }
        T.SignerApproval memory proof = T.SignerApproval(authority.authorityAddress, digest, direct);
        result = IStreamArtistSaleIdentityOwner(x.suite.owners[2])
            .consumeSaleConsent(T.ActionContext(16, actor, prior[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistSaleConsentOwner(x.suite.owners[6])
            .recordSaleConsent(
                T.ActionContext(16, actor, prior[6]), b, p, proof.signer, a.nonce, authority
            );
        if (actual != result) revert T.InvalidRecord();
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(16),
                actor,
                result
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1),
            x.configurationHash,
            uint16(16),
            actor,
            result,
            prior,
            _snapshots(x.suite),
            abi.encode(b, p, a, proof, authority, facts)
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }

    function scope(T.SuiteConfiguration memory suite, uint256 collectionId)
        public
        view
        returns (uint8)
    {
        return _binding(suite, collectionId, false).saleConsentScope;
    }

    /// @notice Historical/latest evidence only; current applicability is checked by requireConsent.
    function isConsented(
        T.SuiteConfiguration memory suite,
        uint256 collectionId,
        bytes32 saleId,
        bytes32 config
    ) public view returns (bool, bytes32) {
        bytes32 hash = IStreamArtistSaleConsentOwner(suite.owners[6])
            .saleConsentAt(collectionId, saleId, config);
        return (hash != bytes32(0), hash);
    }

    function requireConsent(
        T.SuiteConfiguration memory suite,
        address adapter,
        uint256 collectionId,
        bytes32 saleId,
        bytes32 config
    ) public view {
        T.Binding memory b = _binding(suite, collectionId, false);
        if (b.saleConsentScope == 0) return;
        b = _binding(suite, collectionId, true);
        Sale.Consent memory p = Sale.Consent(collectionId, adapter, saleId, config);
        IStreamArtistSaleConsentOwner owner = IStreamArtistSaleConsentOwner(suite.owners[6]);
        Sale.Record memory item =
            owner.saleConsentRecord(owner.saleConsentAt(collectionId, saleId, config));
        if (
            item.recordHash == bytes32(0) || item.artistId != b.artistId
                || (item.authorityClass != 1 && item.authorityClass != 3)
                || item.bindingGeneration != b.generation || item.bindingHash != b.bindingHash
                || keccak256(abi.encode(item.terms)) != keccak256(abi.encode(p))
        ) {
            revert Sale.SaleConsentUnavailable(collectionId, saleId, config);
        }
        _adapter(suite, p);
    }

    /// @notice Exact independent attribution and authority states, never inferred from missing acceptance.
    function attributionState(T.SuiteConfiguration memory suite, uint256 collectionId)
        public
        view
        returns (
            uint8 state,
            uint64 generation,
            bytes32 artistId,
            uint8 authorityStatus,
            bytes32 bindingHash
        )
    {
        _selected(suite.core, keccak256("ARTIST_REGISTRY"), suite.registry, _cap(suite));
        _chain(suite);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(collectionId);
        (state, generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(collectionId);
        if (generation != b.generation) revert T.InvalidAttribution(collectionId);
        artistId = b.artistId;
        bindingHash = b.bindingHash;
        if (artistId != bytes32(0)) {
            (,, authorityStatus,) =
                IStreamArtistIdentityOwner(suite.owners[2]).authorityState(artistId);
        }
    }

    function _binding(T.SuiteConfiguration memory suite, uint256 collectionId, bool accepted)
        private
        view
        returns (T.Binding memory b)
    {
        _chain(suite);
        _selected(suite.core, keccak256("ARTIST_REGISTRY"), suite.registry, _cap(suite));
        b = IStreamArtistBindingOwner(suite.owners[0]).binding(collectionId);
        if (collectionId == 0 || b.bindingHash == bytes32(0) || b.saleConsentScope > 1) {
            revert T.InvalidAttribution(collectionId);
        }
        if (!accepted) return b;
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(collectionId);
        (address authority, uint8 class_, uint8 status,) =
            IStreamArtistIdentityOwner(suite.owners[2]).authorityState(b.artistId);
        if (
            !b.accepted || !StreamArtistAttributionPolicy.acceptedOrSanctioned(state)
                || generation != b.generation
                || !StreamArtistAuthorityPolicy.ordinary(class_, status, false)
                || authority == address(0) || b.consentMode != 1
        ) revert T.InvalidAttribution(collectionId);
        C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(suite.owners[0])
            .bindingTerms(collectionId, generation);
        if (terms.mode != 0 || terms.threshold != 0 || terms.count > 32) {
            revert T.UnsupportedProfile();
        }
        if (
            IStreamArtistCollaboratorRecordsOwner(suite.owners[1]).acceptedCount(b.bindingHash)
                != terms.count
        ) {
            revert T.InvalidAttribution(collectionId);
        }
    }

    function _adapter(T.SuiteConfiguration memory suite, Sale.Consent memory p)
        private
        view
        returns (bytes memory evidence)
    {
        address adapter = p.saleAdapter;
        if (adapter.code.length == 0 || p.saleId == bytes32(0) || p.saleConfigHash == bytes32(0)) {
            revert Sale.InvalidSaleAdapter(adapter);
        }
        uint256 cap = _cap(suite);
        address registry = _selected(suite.core, keccak256("MODULE_REGISTRY"), address(0), cap);
        bytes32 kind = abi.decode(
            _read(
                adapter, abi.encodeWithSelector(IStreamModule.streamModuleType.selector), 32, cap
            ),
            (bytes32)
        );
        bytes4 interfaceId = abi.decode(
            _read(
                adapter,
                abi.encodeWithSelector(IStreamModule.streamModuleInterfaceId.selector),
                32,
                cap
            ),
            (bytes4)
        );
        if (
            kind == bytes32(0) || interfaceId == bytes4(0) || interfaceId == bytes4(0xffffffff)
                || !abi.decode(
                    _read(
                        registry,
                        abi.encodeCall(
                            IStreamModuleRegistry.isModuleEligible, (adapter, kind, interfaceId)
                        ),
                        32,
                        cap
                    ),
                    (bool)
                )
                || !abi.decode(
                    _read(
                        adapter,
                        abi.encodeCall(
                            IERC165.supportsInterface, (type(IStreamArtistSaleFacts).interfaceId)
                        ),
                        32,
                        cap
                    ),
                    (bool)
                )
                || abi.decode(_read(adapter, abi.encodeWithSignature("core()"), 32, cap), (address))
                    != suite.core
        ) {
            revert Sale.InvalidSaleAdapter(adapter);
        }
        (uint256 collectionId, bytes32 config) = abi.decode(
            _read(
                adapter,
                abi.encodeCall(IStreamArtistSaleFacts.saleConsentFacts, (p.saleId)),
                64,
                cap
            ),
            (uint256, bytes32)
        );
        if (collectionId != p.collectionId || config != p.saleConfigHash) {
            revert Sale.InvalidSaleAdapter(adapter);
        }
        return abi.encode(
            registry, registry.codehash, adapter.codehash, kind, interfaceId, collectionId, config
        );
    }

    function _cap(T.SuiteConfiguration memory suite) private view returns (uint256 cap) {
        uint8 failure;
        uint64 revision;
        (cap,, failure, revision) =
            IStreamGasParameterHost(suite.registry).gasParameterInfo(_READ_GAS);
        if (cap == 0 || failure != 2 || revision == 0) revert T.InvalidBinding();
    }

    function _selected(address core, bytes32 kind, address expected, uint256 cap)
        private
        view
        returns (address target)
    {
        bytes memory data = _read(
            core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, cap
        );
        bytes32 word;
        bytes32 hash;
        assembly ("memory-safe") {
            word := mload(add(data, 32))
            hash := mload(add(data, 64))
        }
        target = address(uint160(uint256(word)));
        if (
            uint256(word) >> 160 != 0 || target.code.length == 0 || hash != target.codehash
                || (expected != address(0) && expected != target)
        ) revert T.ComponentChanged(target);
    }

    /// @dev Allocate only the expected fixed result; neither return nor revert data is copied unboundedly.
    function _read(address target, bytes memory callData, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory result)
    {
        uint256 available = gasleft();
        // Includes a cold account access, fixed buffer and instructions before STATICCALL.
        if (cap > (type(uint256).max - 10_000) / 64 * 63) {
            revert Sale.SaleFactsParentGas(available, cap);
        }
        uint256 required = cap + cap / 63 + 10_000;
        if (available < required) revert Sale.SaleFactsParentGas(available, required);
        result = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(
                cap,
                target,
                add(callData, 32),
                mload(callData),
                add(result, 32),
                length
            )
            size := returndatasize()
        }
        if (!ok || size != length) revert Sale.SaleFactsReadFailed(target, bytes4(callData));
    }

    function _chain(T.SuiteConfiguration memory suite) private view {
        if (block.chainid != IStreamArtistOwner(suite.owners[2]).deploymentChainId()) {
            revert T.InvalidBinding();
        }
    }

    function _environment(T.SuiteConfiguration memory suite)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(
            block.chainid, suite.registry, suite.core, suite.mintManager
        );
    }

    function _snapshots(T.SuiteConfiguration memory suite)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        for (uint256 i; i < 7; ++i) {
            if ((0x57 & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }
}
