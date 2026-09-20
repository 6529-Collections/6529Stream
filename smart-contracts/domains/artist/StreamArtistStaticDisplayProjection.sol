// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistPlatformCorrectionLineage as PlatformLineage
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import { StreamArtistStaticCalls as Calls } from "./StreamArtistStaticCalls.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistStaticFacts as SF
} from "../../interfaces/stream/artist/IStreamArtistStaticFacts.sol";
import {
    IStreamArtistDisplayFacts
} from "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import {
    IStreamArtistPlatformWorks
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    IStreamArtistBindingOwner
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistCollaboratorRecordsOwner
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    IStreamArtistAcceptanceOwner
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamCollectionArtistRegistry
} from "../../interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

/// @notice Fixed STATIC projection over an independently authenticated complete suite.
/// @dev All original fact predicates and direct owner reads are retained.
library StreamArtistStaticDisplayProjection {
    uint256 private constant CAP = 100000;
    error InvalidStaticArtistSelector(bytes4 selector);
    error NonCanonicalStaticArtistCall();

    /// @dev Projection only. The fixed companion authenticates this complete suite first.
    /// Direct callers cannot use a supplied suite as proof of current authority or admission.
    function read(bytes calldata encodedSuite, bytes calldata data)
        external
        view
        returns (bytes memory)
    {
        if (data.length < 4 || encodedSuite.length != 544) {
            revert NonCanonicalStaticArtistCall();
        }
        T.SuiteConfiguration memory s = abi.decode(encodedSuite, (T.SuiteConfiguration));
        if (keccak256(encodedSuite) != keccak256(abi.encode(s))) {
            revert NonCanonicalStaticArtistCall();
        }
        bytes4 sel = bytes4(data[:4]);
        if (sel == IStreamArtistDisplayFacts.displayBinding.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            _canonical(data, abi.encodeWithSelector(sel, id));
            return abi.encode(_binding(s, id));
        }
        if (sel == bytes4(keccak256("collectionArtistState(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            _canonical(data, abi.encodeWithSelector(sel, id));
            _selected(s);
            T.Binding memory b = _binding(s, id);
            (uint8 state, uint64 gen) = _attr(s, id);
            if (gen != b.generation) revert T.InvalidAttribution(id);
            uint8 status;
            if (b.artistId != 0) (,, status,) = _authority(s, b.artistId);
            return abi.encode(state, gen, b.artistId, status, b.bindingHash);
        }
        if (sel == bytes4(keccak256("attribution(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            _canonical(data, abi.encodeWithSelector(sel, id));
            T.Binding memory b = _binding(s, id);
            (address authority,,,) = _authority(s, b.artistId);
            bytes32 accepted = abi.decode(
                _read(
                    s.owners[3],
                    abi.encodeCall(IStreamArtistAcceptanceOwner.acceptanceRecord, (b.bindingHash)),
                    32
                ),
                (bytes32)
            );
            uint64 time = abi.decode(
                _read(
                    s.owners[3],
                    abi.encodeCall(IStreamArtistAcceptanceOwner.acceptedAt, (b.bindingHash)),
                    32
                ),
                (uint64)
            );
            return abi.encode(
                IStreamCollectionArtistRegistry.Attribution(
                    b.artistAddress,
                    b.accepted ? authority : address(0),
                    b.identityRecordHash,
                    b.bindingHash,
                    accepted,
                    b.generation,
                    time
                )
            );
        }
        if (sel == PlatformLineage.platformCorrectionStatus.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            _canonical(data, abi.encodeWithSelector(sel, id));
            return
                _read(
                    s.owners[4], abi.encodeCall(PlatformLineage.platformCorrectionStatus, (id)), 192
                );
        }
        if (sel == IStreamArtistPlatformWorks.platformWorksState.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            _canonical(data, abi.encodeWithSelector(sel, id));
            return _read(s.owners[4], abi.encodeCall(SF.staticPlatformWorksState, (id)), 640);
        }
        if (sel == IStreamArtistDisplayFacts.attributionClaims.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            _canonical(data, abi.encodeWithSelector(sel, id));
            return _read(s.owners[4], abi.encodeCall(SF.staticAttributionClaims, (id)), 64);
        }
        if (sel == IStreamArtistDisplayFacts.deploymentAttestation.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            _canonical(data, abi.encodeWithSelector(sel, id));
            SF.Attestation memory a = _attest(s, id, 9, bytes32(uint256(uint160(s.core))));
            return abi.encode(a.recordHash, a.authorityClass, a.signedAt);
        }
        if (sel == IStreamArtistDisplayFacts.artistAttestationStatus.selector) {
            (uint256 id, uint8 kind, bytes32 subject, bytes32 current) =
                abi.decode(data[4:], (uint256, uint8, bytes32, bytes32));
            _canonical(data, abi.encodeWithSelector(sel, id, kind, subject, current));
            SF.Attestation memory a = _attest(s, id, kind, subject);
            if (a.recordHash == 0) {
                return abi.encode(uint8(0), bytes32(0), bytes32(0), uint8(0), uint64(0));
            }
            (uint8 state, uint64 gen) = _attr(s, id);
            uint8 status = state == 4
                ? 3
                : gen != a.generation || !_accepted(state)
                    || (kind != 8 && a.subjectStateHash != current)
                    ? 2
                    : 1;
            return
                abi.encode(status, a.recordHash, a.subjectStateHash, a.authorityClass, a.signedAt);
        }
        if (
            sel == bytes4(keccak256("artistDisplayName(bytes32)"))
                || sel == bytes4(keccak256("operativeIdentityRecord(bytes32)"))
        ) {
            bytes32 id = abi.decode(data[4:], (bytes32));
            _canonical(data, abi.encodeWithSelector(sel, id));
            bytes memory result = Calls.bounded(
                s.owners[2], abi.encodeCall(SF.staticIdentityMetadata, (id)), 352, CAP
            );
            (string memory name, bytes32 hash) = abi.decode(result, (string, bytes32));
            if (keccak256(result) != keccak256(abi.encode(name, hash))) revert T.InvalidRecord();
            return
                sel == bytes4(keccak256("artistDisplayName(bytes32)")) ? result : abi.encode(hash);
        }
        if (sel == bytes4(keccak256("collaboratorCount(uint256,uint64)"))) {
            (uint256 id, uint64 gen) = abi.decode(data[4:], (uint256, uint64));
            _canonical(data, abi.encodeWithSelector(sel, id, gen));
            C.BindingTerms memory terms = abi.decode(
                _read(
                    s.owners[0],
                    abi.encodeCall(IStreamArtistCollaboratorBindingOwner.bindingTerms, (id, gen)),
                    160
                ),
                (C.BindingTerms)
            );
            return abi.encode(uint256(terms.count));
        }
        if (sel == bytes4(keccak256("collaboratorAt(uint256,uint64,uint256)"))) {
            (uint256 id, uint64 gen, uint256 index) =
                abi.decode(data[4:], (uint256, uint64, uint256));
            _canonical(data, abi.encodeWithSelector(sel, id, gen, index));
            T.Binding memory b = abi.decode(
                _read(
                    s.owners[0], abi.encodeCall(IStreamArtistBindingOwner.bindingAt, (id, gen)), 320
                ),
                (T.Binding)
            );
            T.CollaboratorRecord memory p = abi.decode(
                _read(
                    s.owners[0],
                    abi.encodeCall(
                        IStreamArtistCollaboratorBindingOwner.collaboratorTerm, (id, gen, index)
                    ),
                    96
                ),
                (T.CollaboratorRecord)
            );
            C.Join memory j = abi.decode(
                _read(
                    s.owners[1],
                    abi.encodeCall(
                        IStreamArtistCollaboratorRecordsOwner.acceptedRow,
                        (b.bindingHash, p.account, p.role, p.shareLabelId)
                    ),
                    64
                ),
                (C.Join)
            );
            return abi.encode(
                C.Row(
                    p.account,
                    p.role,
                    p.shareLabelId,
                    j.artistId,
                    j.acceptanceRecordHash,
                    j.artistId != 0
                )
            );
        }
        if (sel == IStreamArtistDisplayFacts.displaySanction.selector) {
            StreamFinalityScope memory scope = abi.decode(data[4:], (StreamFinalityScope));
            _canonical(data, abi.encodeWithSelector(sel, scope));
            return abi.encode(
                _sanction(
                    s, uint8(scope.scopeType), scope.collectionId, scope.tokenId, scope.scopeId
                )
            );
        }
        if (
            sel
                == bytes4(
                    keccak256("verifySanctionForSubject(uint8,uint256,uint256,bytes32,bytes32)")
                )
        ) {
            (uint8 kind, uint256 id, uint256 token, bytes32 scope, bytes32 subject) =
                abi.decode(data[4:], (uint8, uint256, uint256, bytes32, bytes32));
            _canonical(data, abi.encodeWithSelector(sel, kind, id, token, scope, subject));
            if (kind > 4 || subject == 0) {
                return abi.encode(false, bytes32(0), address(0), uint8(0));
            }
            S.Record memory r = _sanction(s, kind, id, token, scope);
            return abi.encode(
                r.recordHash != 0 && r.terms.sanctionSubjectHash == subject,
                r.recordHash,
                r.signer,
                r.authorityClass
            );
        }
        revert InvalidStaticArtistSelector(sel);
    }

    function _binding(T.SuiteConfiguration memory s, uint256 id)
        private
        view
        returns (T.Binding memory)
    {
        return abi.decode(
            _read(s.owners[0], abi.encodeCall(IStreamArtistBindingOwner.binding, (id)), 320),
            (T.Binding)
        );
    }

    function _attr(T.SuiteConfiguration memory s, uint256 id) private view returns (uint8, uint64) {
        return abi.decode(
            _read(s.owners[4], abi.encodeCall(SF.staticAttributionState, (id)), 64), (uint8, uint64)
        );
    }

    function _authority(T.SuiteConfiguration memory s, bytes32 id)
        private
        view
        returns (address, uint8, uint8, bytes32)
    {
        return abi.decode(
            _read(s.owners[2], abi.encodeCall(SF.staticAuthorityState, (id)), 128),
            (address, uint8, uint8, bytes32)
        );
    }

    function _attest(T.SuiteConfiguration memory s, uint256 id, uint8 kind, bytes32 subject)
        private
        view
        returns (SF.Attestation memory)
    {
        return abi.decode(
            _read(s.owners[4], abi.encodeCall(SF.staticAttestation, (id, kind, subject)), 160),
            (SF.Attestation)
        );
    }

    function _accepted(uint8 state) private pure returns (bool) {
        return state == 2 || state == 3;
    }

    function _sanction(
        T.SuiteConfiguration memory s,
        uint8 kind,
        uint256 id,
        uint256 token,
        bytes32 scope
    ) private view returns (S.Record memory r) {
        T.Binding memory b = _binding(s, id);
        (uint8 state, uint64 gen) = _attr(s, id);
        if (
            !b.accepted || b.artistId == 0 || b.bindingHash == 0 || gen != b.generation
                || !_accepted(state)
        ) return r;
        bytes32 key = keccak256(abi.encode(b.artistId, gen, b.bindingHash, kind, id, token, scope));
        bytes32 hash;
        (hash, r) = abi.decode(
            _read(s.owners[6], abi.encodeCall(SF.staticSanctionRecord, (key)), 544),
            (bytes32, S.Record)
        );
        if (hash == 0) {
            S.Record memory empty;
            return empty;
        }
        if (
            r.recordHash != hash || r.artistId != b.artistId || r.bindingGeneration != gen
                || r.bindingHash != b.bindingHash || r.terms.scopeType != kind
                || r.terms.collectionId != id || r.terms.tokenId != token
                || r.terms.scopeId != scope
        ) revert S.InvalidSanction();
    }

    function _selected(T.SuiteConfiguration memory s) private view {
        (uint256 cap,, uint8 failure, uint64 revision) = abi.decode(
            _read(
                s.registry,
                abi.encodeCall(
                    IStreamGasParameterHost.gasParameterInfo,
                    (keccak256("6529STREAM_GGP_ARTIST_SALE_FACTS_READ_GAS"))
                ),
                128
            ),
            (uint256, uint256, uint8, uint64)
        );
        if (cap == 0 || failure != 2 || revision == 0) revert T.InvalidBinding();
        bytes memory data = Calls.fixedRead(
            s.core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY"))),
            320,
            cap
        );
        uint256 word;
        bytes32 hash;
        assembly ("memory-safe") {
            word := mload(add(data, 32))
            hash := mload(add(data, 64))
        }
        address target = address(uint160(word));
        if (
            word >> 160 != 0 || target.code.length == 0 || hash != target.codehash
                || target != s.registry
        ) {
            revert T.ComponentChanged(target);
        }
        if (
            block.chainid
                != abi.decode(
                    _read(
                        s.owners[2], abi.encodeCall(IStreamArtistOwner.deploymentChainId, ()), 32
                    ),
                    (uint256)
                )
        ) revert T.InvalidBinding();
    }

    function _canonical(bytes calldata actual, bytes memory expected) private pure {
        if (keccak256(actual) != keccak256(expected)) revert NonCanonicalStaticArtistCall();
    }

    function _read(address target, bytes memory data, uint256 size)
        private
        view
        returns (bytes memory)
    {
        return Calls.fixedRead(target, data, size, CAP);
    }
}
