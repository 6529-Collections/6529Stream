// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";

/// @dev Typed entropy boundary only; actual entropy recovery/governance and one-use are separate.
contract ArtistEntropyContentHostBoundary {
    address public core;
    uint8 public mode;
    bytes32 public head = keccak256("actual unit empty recovery head");

    constructor(address c) {
        core = c;
    }

    function setCore(address c) external {
        core = c;
    }

    function setMode(uint8 m) external {
        mode = m;
    }

    function artistContentFamilyState(uint256 collectionId, bytes32 family)
        external
        view
        returns (bool, bytes32)
    {
        if (mode == 1) revert("typed entropy read failure");
        if (mode == 2) {
            assembly ("memory-safe") {
                mstore(0, 2)
                mstore(32, 1)
                return(0, 64)
            }
        }
        if (mode == 3) {
            assembly ("memory-safe") {
                mstore(0, 1)
                mstore(32, 1)
                mstore(64, 0)
                return(0, 96)
            }
        }
        if (mode == 4) return (false, head);
        if (mode == 5) return (true, 0);
        return (
            family == keccak256("6529STREAM_ENTROPY_RECOVERY_V1"),
            keccak256(abi.encode(block.chainid, address(this), core, collectionId, head))
        );
    }
}

/// @notice Actual Artist facade/Safe/seven owners/Archive with typed Core and entropy state.
contract StreamArtistEntropyContentConsentTest is ArtistOnboardingFixture {
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_RECOVERY_V1");
    bytes32 private constant POINTER = keccak256("ENTROPY_COORDINATOR");

    function _host() internal returns (ArtistEntropyContentHostBoundary h) {
        _accept();
        h = new ArtistEntropyContentHostBoundary(address(core));
        core.set(POINTER, address(h), false);
    }

    function _candidate(address h, uint8 kind, bytes32 subject)
        internal
        view
        returns (Content.Consent memory)
    {
        // Explicit typed test commitment, not a claim about the eventual entropy producer domain.
        return Content.Consent(
            1,
            h,
            FAMILY,
            keccak256(
                abi.encode(
                    keccak256("unit exact entropy resulting state"),
                    block.chainid,
                    h,
                    address(core),
                    uint256(1),
                    kind,
                    subject,
                    keccak256("original request"),
                    keccak256("new policy")
                )
            )
        );
    }

    function _auth(Content.Consent memory p) internal returns (T.Authorization memory a) {
        a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
    }

    function _read(Content.Consent memory p) internal view returns (bytes32) {
        return IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(
                p.collectionId, p.metadataContract, p.familyId, p.newStateHash
            );
    }

    function _entropyRoots() internal view returns (bytes32) {
        T.Snapshot[7] memory roots;
        for (uint256 i; i < 7; ++i) {
            roots[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(roots));
    }

    function _expected(Content.Consent memory p, T.Authorization memory a)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.metadataContract,
                address(core),
                p.collectionId,
                p.familyId,
                p.newStateHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(block.timestamp)
            )
        );
    }

    function testEntropyOriginalDigestRecordArchiveAndDistinctTokenScopeEvidence() external {
        ArtistEntropyContentHostBoundary h = _host();
        Content.Consent memory token = _candidate(address(h), 1, bytes32(uint256(41)));
        T.Authorization memory a = _auth(token);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(ingress)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)"
                ),
                address(core),
                address(h),
                token.collectionId,
                FAMILY,
                token.newStateHash,
                a.nonce,
                a.time
            )
        );
        require(
            ingress.contentConsentDigest(token, a)
                == keccak256(abi.encodePacked(hex"1901", domain, structHash)),
            "original independent op17 digest"
        );
        bytes32 expected = _expected(token, a);
        bytes32 record = ingress.recordContentConsent(token, a);
        require(record == expected && record != 0 && _read(token) == record, "exact host evidence");
        IStreamArtistContentRecordsOwner.ConsentRecord memory stored =
            IStreamArtistContentRecordsOwner(suite.owners[6]).contentConsentRecord(record);
        require(
            stored.artistId == artistId && stored.authorityClass == 1
                && keccak256(abi.encode(stored.terms)) == keccak256(abi.encode(token)),
            "original immutable terms"
        );
        (
            T.Binding memory b,
            Content.Consent memory archived,
            T.Authorization memory saved,
            T.SignerApproval memory proof,
            bytes32 current
        ) = abi.decode(
            _operationPayload(17, address(this), record),
            (T.Binding, Content.Consent, T.Authorization, T.SignerApproval, bytes32)
        );
        require(
            b.artistId == artistId
                && keccak256(abi.encode(archived)) == keccak256(abi.encode(token))
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(a))
                && proof.signer == address(artist) && current != 0,
            "original Archive proof with actual host state"
        );
        Content.Consent memory scope = _candidate(address(h), 2, keccak256("actual scope"));
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("content-consent"))
        );
        IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(1, address(h), FAMILY, scope.newStateHash);
        T.Authorization memory sa = _auth(scope);
        bytes32 sr = ingress.recordContentConsent(scope, sa);
        require(
            sr != record && _read(scope) == sr && _read(token) == record,
            "distinct retained targets"
        );
    }

    function testEntropySelectedPointerRuntimeAndCorePinRestoreExactEvidence() external {
        ArtistEntropyContentHostBoundary h = _host();
        Content.Consent memory p = _candidate(address(h), 1, bytes32(uint256(41)));
        T.Authorization memory a = _auth(p);
        h.setCore(address(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(h)));
        ingress.recordContentConsent(p, a);
        h.setCore(address(core));
        bytes32 record = ingress.recordContentConsent(p, a);
        ArtistEntropyContentHostBoundary replacement =
            new ArtistEntropyContentHostBoundary(address(core));
        core.set(POINTER, address(replacement), false);
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(replacement)));
        IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(1, address(h), FAMILY, p.newStateHash);
        core.set(POINTER, address(h), false);
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (POINTER)),
            abi.encode(
                address(h),
                bytes32(uint256(1)),
                false,
                POINTER,
                bytes4(0),
                address(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(h)));
        IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(1, address(h), FAMILY, p.newStateHash);
        avm.clearMockedCalls();
        require(_read(p) == record, "exact selected runtime restoration");
    }

    function testEntropyAdvertisedFailureMalformedUnsupportedNoopAndSignedRetry() external {
        ArtistEntropyContentHostBoundary h = _host();
        Content.Consent memory p = _candidate(address(h), 1, bytes32(uint256(41)));
        T.Authorization memory a = _auth(p);
        bytes32 before_ = _entropyRoots();
        for (uint8 mode = 1; mode <= 5; ++mode) {
            h.setMode(mode);
            if (mode <= 3) {
                vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(h)));
            } else {
                avm.expectRevert(T.InvalidRecord.selector);
            }
            ingress.recordContentConsent(p, a);
            require(_entropyRoots() == before_, "failed actual host read consumes no authority");
        }
        h.setMode(0);
        (, bytes32 current) = h.artistContentFamilyState(1, FAMILY);
        Content.Consent memory noop = Content.Consent(1, address(h), FAMILY, current);
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordContentConsent(noop, a);
        bytes32 record = ingress.recordContentConsent(p, a);
        h.setMode(1);
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(h)));
        IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(1, address(h), FAMILY, p.newStateHash);
        h.setMode(0);
        require(_read(p) == record, "no fallback; identical signature succeeds once healthy");
    }

    function testEntropyCannotBroadenMetadataReadsFamiliesOrDefensiveFreeze() external {
        ArtistEntropyContentHostBoundary h = _host();
        Content.Consent memory p = _candidate(address(h), 1, bytes32(uint256(41)));
        p.familyId = keccak256("SCRIPT");
        T.Authorization memory a = _auth(p);
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(h)));
        ingress.recordContentConsent(p, a);
        p.familyId = FAMILY;
        a = _auth(p);
        bytes32 record = ingress.recordContentConsent(p, a);
        avm.expectRevert(T.UnsupportedProfile.selector);
        ingress.contentConsentEvidence(1, FAMILY, p.newStateHash);
        Content.Freeze memory f = _contentFreezeProposal();
        f.metadataContract = address(h);
        T.Authorization memory fa = _authorization(false);
        fa.signature = _signature(ingress.contentFreezeDigest(f, fa));
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(h)));
        ingress.authorizeArtistContentFreeze(f, fa);
        bytes32 metadataRecord = _contentConsent(keccak256("retained metadata content"));
        Content.Consent memory mp = _contentProposal(keccak256("retained metadata content"));
        require(
            ingress.contentConsentEvidence(1, mp.familyId, mp.newStateHash) == metadataRecord
                && _read(mp) == metadataRecord && _read(p) == record,
            "separate original metadata route"
        );
        require(
            ingress.supportsInterface(type(IStreamArtistContentAuthority).interfaceId)
                && ingress.supportsInterface(type(IStreamArtistContentHostEvidence).interfaceId)
                && !ingress.supportsInterface(bytes4(0xffffffff)),
            "additive explicit capability"
        );
    }

    function testEntropyCurrentBindingGenerationAndSignedTargetRemainExact() external {
        ArtistEntropyContentHostBoundary h = _host();
        Content.Consent memory p = _candidate(address(h), 1, bytes32(uint256(41)));
        T.Authorization memory a = _auth(p);
        Content.Consent memory different = _candidate(address(h), 1, bytes32(uint256(42)));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordContentConsent(different, a);
        bytes32 record = ingress.recordContentConsent(p, a);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        b.generation += 1;
        b.bindingHash = keccak256("typed replacement generation");
        avm.mockCall(
            suite.owners[0],
            abi.encodeCall(IStreamArtistBindingOwner.binding, (uint256(1))),
            abi.encode(b)
        );
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (uint256(1))),
            abi.encode(uint8(2), b.generation)
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("content-consent"))
        );
        IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(1, address(h), FAMILY, p.newStateHash);
        avm.clearMockedCalls();
        require(_read(p) == record, "original binding restoration only");
    }

    function testEntropyLateArchiveSafeRollbackThenIdenticalOriginalNonceRetry() external {
        ArtistEntropyContentHostBoundary h = _host();
        Content.Consent memory p = _candidate(address(h), 1, bytes32(uint256(41)));
        T.Authorization memory a = _authorization(false); // Actual direct threshold Safe caller.
        bytes32 expected = _expected(p, a);
        bytes memory data =
            abi.encodeCall(IStreamArtistContentAuthority.recordContentConsent, (p, a));
        bytes32 before_ = _entropyRoots();
        uint256 safeNonce = artist.nonce();
        uint256 payloads = archive.storedPayloadCount();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "entropy Archive failure")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), data);
        require(
            _entropyRoots() == before_ && artist.nonce() == safeNonce
                && archive.storedPayloadCount() == payloads,
            "complete Safe authority and Archive rollback"
        );
        require(
            IStreamArtistContentRecordsOwner(suite.owners[6])
                .contentConsentRecord(expected)
                .recordHash == 0,
            "failed consent not retained"
        );
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(ingress), data), "byte-identical Safe retry");
        require(
            _read(p) == expected && artist.nonce() == safeNonce + 1
                && archive.storedPayloadCount() > payloads,
            "one retained original op17"
        );
        before_ = _entropyRoots();
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), data);
        require(
            _entropyRoots() == before_ && artist.nonce() == safeNonce + 1,
            "original nonce cannot replay"
        );
    }
}
