// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPlatformCorrectionReads } from "../artist/StreamArtistPlatformCorrectionReads.sol";
import { StreamArtistPlatformCorrectionLineageTypes as PL, IStreamArtistPlatformCorrectionLineage as PlatformLineage } from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import "./StreamArtistDisplayJSON.sol";
import { IStreamStaticArtistSource } from "../../interfaces/stream/metadata/IStreamStaticArtistSource.sol";
import { StreamMetadataDisplayParameters } from "./StreamMetadataDisplayParameters.sol";
import {
    StreamFinalityNativeProviderReads
} from "../finality/StreamFinalityNativeProviderReads.sol";
import {
    IStreamFinalityDiscoverySources
} from "../../interfaces/stream/finality/IStreamFinalityDiscoverySources.sol";
import "./StreamMetadataScopeMembership.sol";
import "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";
import "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import "../../interfaces/stream/artist/IStreamArtistSanction.sol";
import "../../interfaces/stream/metadata/IStreamCollectionSnapshots.sol";
import "../../interfaces/stream/finality/IStreamFinalityTokenScopeInventory.sol";

/// @notice Bounded live facts only. The caller catches this whole frame for AA-DISPLAY fallback.
library StreamArtistDisplayReads {
    uint256 internal constant MAX_SCOPES = 64;

    struct State {
        uint8 attribution;
        uint64 generation;
        bytes32 artistId;
        uint8 authorityStatus;
        bytes32 bindingHash;
    }

    struct Attestation {
        uint8 status;
        bytes32 recordHash;
        bytes32 attestedHash;
        uint8 authorityClass;
        uint64 signedAt;
    }

    function object(
        address core,
        address artist,
        bytes32 artistCodeHash,
        address original,
        bytes32 originalCodeHash,
        uint256 collection,
        uint256 token
    ) public view returns (bytes memory) {
        _pin(artist, artistCodeHash);
        StreamMetadataRecoveryRoutes.Pointer memory p = abi.decode(
            _read(
                core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY"))
                ),
                320
            ),
            (StreamMetadataRecoveryRoutes.Pointer)
        );
        if (
            p.target != artist || p.codeHash != artistCodeHash || p.status != 1 || p.revision == 0
                || _address(artist, abi.encodeWithSignature("core()")) != core
        ) _fail();
        bytes memory stateRaw = _read(
            artist,
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (collection)),
            160
        );
        State memory s = abi.decode(stateRaw, (State));
        T.Binding memory b = abi.decode(
            _read(
                artist, abi.encodeCall(IStreamArtistDisplayFacts.displayBinding, (collection)), 320
            ),
            (T.Binding)
        );
        PW.State memory platform = abi.decode(
            _read(
                artist,
                abi.encodeCall(IStreamArtistPlatformWorks.platformWorksState, (collection)),
                640
            ),
            (PW.State)
        );
        StreamArtistDisplayTypes.Facts memory f;
        if (
            s.attribution > 5 || s.generation != b.generation || s.artistId != b.artistId
                || s.bindingHash != b.bindingHash || platform.contestState > 3
        ) _fail();
        bool corrected = platform.correction.accepted;
        if (StreamArtistPlatformCorrectionReads.needed(platform)) {
            corrected = StreamArtistPlatformCorrectionReads.effectiveEncoded(
                platform, _platformContinuation(artist, collection));
        }
        f.platform = platform.declaration.recordHash != 0 && !corrected;
        f.hasPlatformHistory = platform.declaration.recordHash != 0;
        f.corrected = corrected;
        f.contested = platform.contestState == 1 || platform.contestState == 3;
        f.contestRecord = platform.contestRecord;
        if (f.platform) {
            f.state = f.contested ? 4 : 1;
            f.consentMode = 3;
            f.claimCount = platform.claimCount;
            f.latestClaim = platform.latestClaim;
        } else {
            if (
                b.artistId == 0 || b.generation == 0 || b.bindingHash == 0 || s.attribution == 0
                    || (s.attribution >= 2 && s.attribution <= 3 && !b.accepted)
            ) _fail();
            f.state = s.attribution;
            // Sanction is resolved below for this exact token/scope, never globally inferred.
            if (f.state == 3) f.state = 2;
            f.consentMode = b.consentMode;
            f.artistId = b.artistId;
            f.generation = b.generation;
            IStreamCollectionArtistRegistry.Attribution memory a = abi.decode(
                _read(
                    artist, abi.encodeCall(IStreamArtistAttribution.attribution, (collection)), 224
                ),
                (IStreamCollectionArtistRegistry.Attribution)
            );
            if (
                a.nominationHash != b.bindingHash || a.nominationRevision != b.generation
                    || a.nominatedArtist != b.artistAddress
            ) _fail();
            f.artist = b.accepted ? a.artist : b.artistAddress;
            (f.name, f.identityRecord) = _name(artist, b.artistId);
            (f.claimCount, f.latestClaim) = abi.decode(
                _read(
                    artist,
                    abi.encodeCall(IStreamArtistDisplayFacts.attributionClaims, (collection)),
                    64
                ),
                (uint256, bytes32)
            );
            (f.deploymentRecord,,) = abi.decode(
                _read(
                    artist,
                    abi.encodeCall(IStreamArtistDisplayFacts.deploymentAttestation, (collection)),
                    96
                ),
                (bytes32, uint8, uint64)
            );
            f.collaborators = _collaborators(artist, collection, b.generation);
            _attestation(core, artist, original, originalCodeHash, collection, f);
            if (f.state == 2) {
                _sanctions(core, artist, original, originalCodeHash, collection, token, b, f);
            }
        }
        // Keep the complete raw binding and state stable across the selected source reads.
        if (
            keccak256(stateRaw)
                    != keccak256(
                        _read(
                            artist,
                            abi.encodeCall(
                                IStreamArtistAttributionState.collectionArtistState, (collection)
                            ),
                            160
                        )
                    )
                || keccak256(abi.encode(b))
                    != keccak256(
                        _read(
                            artist,
                            abi.encodeCall(IStreamArtistDisplayFacts.displayBinding, (collection)),
                            320
                        )
                    )
        ) _fail();
        return StreamArtistDisplayJSON.render(f);
    }

    function _name(address artist, bytes32 id)
        private
        view
        returns (string memory value, bytes32 record)
    {
        bytes memory raw = _bounded(
            artist,
            abi.encodeCall(IStreamArtistIdentityRevisionReads.artistDisplayName, (id)),
            352,
            StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.READ_GAS)
        );
        (value, record) = abi.decode(raw, (string, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(value, record)) || record == 0
                || record
                    != abi.decode(
                        _read(
                            artist,
                            abi.encodeCall(
                                IStreamArtistIdentityRevisionReads.operativeIdentityRecord, (id)
                            ),
                            32
                        ),
                        (bytes32)
                    )
        ) _fail();
    }

    function _collaborators(address artist, uint256 collection, uint64 generation)
        private
        view
        returns (StreamArtistDisplayTypes.Collaborator[] memory out)
    {
        uint256 n = abi.decode(
            _read(
                artist,
                abi.encodeCall(
                    IStreamArtistCollaboratorLifecycle.collaboratorCount, (collection, generation)
                ),
                32
            ),
            (uint256)
        );
        if (n > 32) _fail();
        out = new StreamArtistDisplayTypes.Collaborator[](n);
        uint256 count;
        for (uint256 i; i < n; ++i) {
            C.Row memory row = abi.decode(
                _read(
                    artist,
                    abi.encodeCall(
                        IStreamArtistCollaboratorLifecycle.collaboratorAt,
                        (collection, generation, i)
                    ),
                    192
                ),
                (C.Row)
            );
            if (!row.accepted) continue;
            if (
                row.account == address(0) || row.collaboratorArtistId == 0
                    || row.acceptanceRecordHash == 0
            ) _fail();
            (string memory label, bytes32 record) = _name(artist, row.collaboratorArtistId);
            out[count++] = StreamArtistDisplayTypes.Collaborator(
                row.account, row.collaboratorArtistId, row.role, label, record
            );
        }
        assembly ("memory-safe") { mstore(out, count) }
    }

    function _attestation(
        address core,
        address artist,
        address original,
        bytes32 originalHash,
        uint256 collection,
        StreamArtistDisplayTypes.Facts memory f
    ) private view {
        _pin(original, originalHash);
        if (
            _address(original, abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()))
                != core
        ) _fail();
        address provider = _address(
            original, abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ())
        );
        _pin(
            provider,
            abi.decode(
                _read(
                    original,
                    abi.encodeCall(
                        IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ()
                    ),
                    32
                ),
                (bytes32)
            )
        );
        StreamFinalityNativeProviderReads.Config memory c = abi.decode(
            _read(provider, abi.encodeWithSignature("nativeConfiguration()"), 1568),
            (StreamFinalityNativeProviderReads.Config)
        );
        address source =
            _address(provider, abi.encodeCall(IStreamFinalityDiscoverySources.snapshotHost, ()));
        if (
            c.chainId != block.chainid || c.targets[0] != core || c.targets[2] != address(this)
                || c.targets[8] != source || c.targets[12] != original
                || c.codeHashes[12] != originalHash
        ) _fail();
        _pin(core, c.codeHashes[0]);
        _pin(address(this), c.codeHashes[2]);
        _pin(source, c.codeHashes[8]);
        _pin(c.targets[1], c.codeHashes[1]);
        if (
            _address(original, abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ()))
                    != c.targets[1] || _address(provider, abi.encodeWithSignature("core()")) != core
                || _address(
                        provider,
                        abi.encodeCall(IStreamFinalityRouterEvidenceBinding.metadataRouter, ())
                    ) != address(this)
                || _address(source, abi.encodeCall(IStreamCollectionSnapshots.core, ())) != core
                || _address(source, abi.encodeCall(IStreamCollectionSnapshots.metadataRouter, ()))
                    != address(this)
                || _address(source, abi.encodeCall(IStreamCollectionSnapshots.metadataHost, ()))
                    != c.targets[1]
        ) _fail();
        StreamSnapshotTypes.Receipt memory receipt = abi.decode(
            _read(
                source,
                abi.encodeCall(IStreamCollectionSnapshots.currentSnapshot, (collection)),
                672
            ),
            (StreamSnapshotTypes.Receipt)
        );
        bytes32 manifest = abi.decode(
            _read(
                source,
                abi.encodeCall(IStreamCollectionSnapshots.latestSnapshotHash, (collection)),
                32
            ),
            (bytes32)
        );
        if (receipt.recordHash == 0) {
            StreamSnapshotTypes.Receipt memory empty;
            if (manifest != 0 || keccak256(abi.encode(receipt)) != keccak256(abi.encode(empty))) {
                _fail();
            }
            return;
        }
        if (
            receipt.collectionId != collection || receipt.snapshotId == 0 || manifest == 0
                || manifest != receipt.manifestHash
                || manifest
                    != abi.decode(
                        _read(
                            source,
                            abi.encodeCall(
                                IStreamCollectionSnapshots.snapshotHash,
                                (collection, receipt.snapshotId)
                            ),
                            32
                        ),
                        (bytes32)
                    )
        ) _fail();
        Attestation memory a = abi.decode(
            _read(
                artist,
                abi.encodeCall(
                    IStreamArtistDisplayFacts.artistAttestationStatus,
                    (collection, uint8(1), receipt.snapshotId, manifest)
                ),
                160
            ),
            (Attestation)
        );
        f.attestationStatus = a.status;
        f.attestationRecord = a.recordHash;
        f.attestedHash = a.attestedHash;
        f.attestationClass = a.authorityClass;
    }

    function _sanctions(
        address core,
        address artist,
        address original,
        bytes32 originalHash,
        uint256 collection,
        uint256 token,
        T.Binding memory b,
        StreamArtistDisplayTypes.Facts memory f
    ) private view {
        // Collection scope always covers its current tokens. Token scope is exact.
        _sanction(
            artist, StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collection, 0, 0), b, f
        );
        if (token == 0) return;
        _sanction(
            artist, StreamFinalityScope(StreamFinalityScopeType.TOKEN, collection, token, 0), b, f
        );
        address membership = StreamMetadataScopeMembership.host(
            core, address(this), StreamMetadataRecoveryRoutes.OriginalAnchor(original, originalHash)
        );
        uint256 n = abi.decode(
            _read(
                membership,
                abi.encodeCall(IStreamFinalityTokenScopeInventory.tokenScopeCount, (token)),
                32
            ),
            (uint256)
        );
        if (n > MAX_SCOPES) _fail();
        for (uint256 i; i < n; ++i) {
            (StreamFinalityScope memory scope, bool complete) = abi.decode(
                _bounded(
                    membership,
                    abi.encodeCall(IStreamFinalityTokenScopeInventory.tokenScopeAt, (token, i)),
                    160,
                    StreamMetadataDisplayParameters.value(
                        StreamMetadataDisplayParameters.MEMBERSHIP_GAS
                    )
                ),
                (StreamFinalityScope, bool)
            );
            if (!complete) continue;
            if (
                scope.collectionId != collection || uint8(scope.scopeType) < 2 || scope.tokenId != 0
                    || scope.scopeId == 0
                    || abi.decode(
                            _bounded(
                                membership,
                                abi.encodeCall(
                                    IStreamFinalityScopeMembership.scopeCoversToken, (scope, token)
                                ),
                                32,
                                StreamMetadataDisplayParameters.value(
                                    StreamMetadataDisplayParameters.MEMBERSHIP_GAS
                                )
                            ),
                            (uint256)
                        ) != 1
            ) _fail();
            _sanction(artist, scope, b, f);
        }
    }

    function _sanction(
        address artist,
        StreamFinalityScope memory scope,
        T.Binding memory b,
        StreamArtistDisplayTypes.Facts memory f
    ) private view {
        S.Record memory r = abi.decode(
            _read(artist, abi.encodeCall(IStreamArtistDisplayFacts.displaySanction, (scope)), 512),
            (S.Record)
        );
        if (r.recordHash == 0) {
            S.Record memory empty;
            if (keccak256(abi.encode(r)) != keccak256(abi.encode(empty))) _fail();
            return;
        }
        if (
            r.artistId != b.artistId || r.bindingGeneration != b.generation
                || r.bindingHash != b.bindingHash || r.signer == address(0)
                || r.terms.scopeType != uint8(scope.scopeType)
                || r.terms.collectionId != scope.collectionId || r.terms.tokenId != scope.tokenId
                || r.terms.scopeId != scope.scopeId
        ) _fail();
        (bool valid, bytes32 hash, address signer, uint8 authorityClass) = abi.decode(
            _read(
                artist,
                abi.encodeCall(
                    IStreamFinalitySanctionReads.verifySanctionForSubject,
                    (
                        r.terms.scopeType,
                        scope.collectionId,
                        scope.tokenId,
                        scope.scopeId,
                        r.terms.sanctionSubjectHash
                    )
                ),
                128
            ),
            (bool, bytes32, address, uint8)
        );
        if (
            !valid || hash != r.recordHash || signer != r.signer
                || authorityClass != r.authorityClass || authorityClass == 0 || authorityClass > 4
        ) _fail();
        f.state = 3;
        // All covering scopes are inspected. First deterministic scope supplies the linked record.
        if (f.sanctionRecord == 0) {
            f.sanctionRecord = hash;
            f.sanctionClass = authorityClass;
        }
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) _fail();
    }

    function _platformContinuation(address artist, uint256 collection) private view returns (bytes memory) {
        bytes memory raw = _read(artist, abi.encodeCall(IStreamStaticArtistSource.staticDisplayRead,
            (abi.encodeCall(PlatformLineage.platformCorrectionStatus, (collection)))), 256);
        bytes memory value = abi.decode(raw, (bytes));
        if (value.length != 192 || keccak256(raw) != keccak256(abi.encode(value))) _fail();
        return value;
    }

    function _address(address target, bytes memory input) private view returns (address) {
        return abi.decode(_read(target, input, 32), (address));
    }

    function _read(address target, bytes memory input, uint256 length)
        private
        view
        returns (bytes memory raw)
    {
        raw = _bounded(
            target,
            input,
            length,
            StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.READ_GAS)
        );
        if (raw.length != length) _fail();
    }

    function _bounded(address target, bytes memory input, uint256 maximum, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        uint256 available = gasleft();
        if (target.code.length == 0 || available <= 10000) _fail();
        available -= 10000;
        if (cap > available || available - cap < cap / 63) _fail();
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size > maximum) _fail();
        raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
    }

    function _fail() private pure {
        revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
    }
}
