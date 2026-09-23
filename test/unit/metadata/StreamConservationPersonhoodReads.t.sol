// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamConservationPersonhoodReads as Reads
} from "../../../smart-contracts/domains/metadata/StreamConservationPersonhoodReads.sol";
import {
    StreamArtistPersonhoodTypes as Personhood,
    IStreamArtistPersonhoodEvidence
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistPersonhoodDefinitions as Definitions
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";

interface ConservationPersonhoodVm {
    function expectRevert() external;
    function expectRevert(bytes calldata reason) external;
    function etch(address target, bytes calldata code) external;
    function chainId(uint256 chain) external;
}

/// @dev Exact-calldata response boundary. This is not an actual Artist owner or verified op24.
contract ConservationPersonhoodResponseBoundary {
    mapping(bytes32 => bytes) private answers;
    mapping(bytes32 => bool) private failures;

    function set(bytes memory input, bytes memory output) external {
        answers[keccak256(input)] = output;
    }

    function setFailure(bytes memory input, bool fail) external {
        failures[keccak256(input)] = fail;
    }

    fallback() external {
        require(!failures[keccak256(msg.data)], "typed personhood source unavailable");
        bytes memory result = answers[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

/// @notice Real fixed consumer and metadata-pinned graph resolver against explicit typed replies.
/// @dev Original summary verification/op24 and provider's preceding retained graph-pin proof are
/// separate boundaries. Coherent owner replacement is tested through the actual provider suite.
contract StreamConservationPersonhoodReadsTest {
    ConservationPersonhoodVm private constant vm =
        ConservationPersonhoodVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ConservationPersonhoodResponseBoundary private core;
    ConservationPersonhoodResponseBoundary private metadata;
    ConservationPersonhoodResponseBoundary private facade;
    ConservationPersonhoodResponseBoundary private coordinator;
    ConservationPersonhoodResponseBoundary private identity;
    ConservationPersonhoodResponseBoundary private attribution;
    ConservationPersonhoodResponseBoundary private notary;
    Reads.Dependencies private dependencies;
    bytes32 private constant ARTIST = keccak256("typed registered Artist");
    bytes32 private constant REGISTRATION = keccak256("immutable registration identity");
    bytes32 private constant OPERATIVE = keccak256("later operative identity document");
    bytes32 private constant NATIVE_RECORD = keccak256("original personhood op24 record");
    bytes32 private constant SUMMARY = keccak256("typed original verified retained summary");

    function setUp() public {
        core = new ConservationPersonhoodResponseBoundary();
        metadata = new ConservationPersonhoodResponseBoundary();
        facade = new ConservationPersonhoodResponseBoundary();
        coordinator = new ConservationPersonhoodResponseBoundary();
        identity = new ConservationPersonhoodResponseBoundary();
        attribution = new ConservationPersonhoodResponseBoundary();
        notary = new ConservationPersonhoodResponseBoundary();
        metadata.set(abi.encodeWithSignature("artistRegistry()"), abi.encode(address(facade)));
        metadata.set(
            abi.encodeWithSignature("artistRegistryCodeHash()"),
            abi.encode(address(facade).codehash)
        );
        facade.set(abi.encodeWithSignature("core()"), abi.encode(address(core)));
        facade.set(
            abi.encodeWithSignature("operationCoordinator()"), abi.encode(address(coordinator))
        );
        coordinator.set(abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid));
        coordinator.set(abi.encodeWithSignature("suiteConfiguration()"), _suite());
        _owner(identity);
        _owner(attribution);
        identity.set(
            abi.encodeWithSignature("authorityState(bytes32)", ARTIST),
            abi.encode(address(0xA47157), uint8(1), uint8(1), REGISTRATION)
        );
        _selected(keccak256("ARTIST_REGISTRY"), address(facade));
        _selected(keccak256("COLLECTION_METADATA"), address(metadata));
        dependencies.targets = [address(core), address(metadata), address(facade)];
        for (uint256 i; i < 3; ++i) {
            dependencies.codeHashes[i] = dependencies.targets[i].codehash;
        }
        dependencies.chainId = block.chainid;
        dependencies.readGas = 300000;
        dependencies.sourceGas = 2000000;
        _wire(_resolved());
        attribution.set(_summaryCall(NATIVE_RECORD), abi.encode(SUMMARY));
    }

    function _owner(ConservationPersonhoodResponseBoundary owner) private {
        owner.set(abi.encodeWithSignature("core()"), abi.encode(address(core)));
        owner.set(abi.encodeWithSignature("artistRegistry()"), abi.encode(address(facade)));
        owner.set(
            abi.encodeWithSignature("operationCoordinator()"), abi.encode(address(coordinator))
        );
        owner.set(abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid));
    }

    function _suite() private view returns (bytes memory) {
        // Literal original 17-word order, independent of the consumer's suite decoder.
        uint256[17] memory words;
        words[0] = uint160(address(facade));
        words[1] = 0xA1;
        words[2] = 0xA2;
        words[3] = 0xA3;
        words[4] = uint160(address(identity));
        words[5] = 0xA5;
        words[6] = uint160(address(attribution));
        words[7] = 0xA7;
        words[8] = 0xA8;
        words[9] = uint160(address(core));
        words[10] = 0xAA;
        words[11] = 0xAB;
        words[12] = uint160(address(metadata));
        words[13] = 0xAD;
        words[14] = 0xAE;
        words[15] = type(uint256).max;
        words[16] = 0xAF;
        return abi.encode(words);
    }

    function _selected(bytes32 role, address target) private {
        core.set(
            abi.encodeWithSignature("getSatellitePointer(bytes32)", role), _pointer(role, target)
        );
    }

    function _pointer(bytes32 role, address target) private view returns (bytes memory) {
        uint256[10] memory words;
        words[0] = uint160(target);
        words[1] = uint256(target.codehash);
        words[3] = uint256(role);
        words[5] = uint160(address(core));
        words[6] = 1;
        words[7] = 1;
        words[8] = 2;
        words[9] = 1;
        return abi.encode(words);
    }

    function _resolved() private view returns (Personhood.Selection memory p) {
        p.nativeRecord.recordHash = NATIVE_RECORD;
        p.nativeRecord.subjectStateHash = OPERATIVE;
        p.nativeRecord.schemaId = Definitions.EVIDENCE_SCHEMA;
        p.nativeRecord.statementHash = keccak256("original canonical personhood statement");
        p.nativeRecord.generation = 1;
        p.nativeRecord.signedAt = 1;
        p.nativeRecord.signer = address(0xA47157);
        p.sourceRegistry = address(facade);
        p.evidenceReference = Personhood.Reference(
            1,
            Definitions.PROFILE_HASH,
            address(facade),
            ARTIST,
            OPERATIVE,
            address(notary),
            address(notary).codehash,
            keccak256("original notarization record")
        );
        p.notarizationType = keccak256("INSTITUTIONAL_VERIFICATION");
        p.recorder = address(0x6529);
        p.notarizationHead = p.evidenceReference.notarizationRecordHash;
        p.identityCurrent = true;
        p.notarizationCurrent = true;
        p.status = Personhood.Status.RESOLVED;
    }

    function _waiver() private view returns (Personhood.Selection memory p) {
        p.nativeRecord = _resolved().nativeRecord;
        p.nativeRecord.recordHash = keccak256("original current personhood waiver");
        p.nativeRecord.schemaId = Definitions.WAIVER_SCHEMA;
        p.nativeRecord.statementHash = keccak256("original explicit waiver statement");
        p.sourceRegistry = address(facade);
        p.identityCurrent = true;
        p.status = Personhood.Status.WAIVER;
    }

    function _selectionCall(uint256 collectionId, bytes32 artist)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            IStreamArtistPersonhoodEvidence.personhoodEvidence, (collectionId, artist)
        );
    }

    function _summaryCall(bytes32 record) private pure returns (bytes memory) {
        return abi.encodeCall(IStreamArtistPersonhoodEvidence.personhoodProofSummaryHash, (record));
    }

    function _wire(Personhood.Selection memory p) private {
        attribution.set(_selectionCall(1, ARTIST), abi.encode(p));
    }

    function read(uint256 collectionId, bytes32 artist) external view returns (bytes32) {
        return Reads.requireCurrent(dependencies, collectionId, artist);
    }

    function _word(bytes memory raw, uint256 index, uint256 value) private pure {
        assembly ("memory-safe") { mstore(add(add(raw, 32), mul(index, 32)), value) }
    }

    function _reject() private {
        vm.expectRevert();
        this.read(1, ARTIST);
    }

    function testResolvedReturnsExactOriginalSummaryForOperativeIdentity() public view {
        require(REGISTRATION != OPERATIVE, "registration and operative facts deliberately differ");
        require(this.read(1, ARTIST) == SUMMARY, "exact native summary hash returned unchanged");
    }

    function testImportedOriginalRegistryRemainsValid() public {
        Personhood.Selection memory p = _resolved();
        p.sourceRegistry = address(0x011d);
        p.evidenceReference.artistRegistry = p.sourceRegistry;
        _wire(p);
        require(
            this.read(1, ARTIST) == SUMMARY,
            "authenticated imported origin need not be current facade"
        );
    }

    function testExplicitCurrentWaiverReturnsOriginalRecordWithoutSummary() public {
        Personhood.Selection memory p = _waiver();
        p.sourceRegistry = address(0); // Original explicit waivers can predate origin summaries.
        _wire(p);
        attribution.setFailure(_summaryCall(p.nativeRecord.recordHash), true);
        require(
            this.read(1, ARTIST) == p.nativeRecord.recordHash,
            "original current waiver, no summary read"
        );
    }

    function testCurrentWaiverSupersedesResolvedHeadWithoutFallingBack() public {
        require(this.read(1, ARTIST) == SUMMARY, "initial documentary selection");
        Personhood.Selection memory p = _waiver();
        _wire(p);
        require(
            this.read(1, ARTIST) == p.nativeRecord.recordHash,
            "selected waiver replaces documentary floor"
        );
        p.identityCurrent = false;
        p.status = Personhood.Status.STALE;
        _wire(p);
        _reject(); // The old valid documentary summary still exists but is no longer selected.
        _wire(_resolved());
        attribution.set(_summaryCall(NATIVE_RECORD), abi.encode(bytes32(0)));
        _reject(); // A failed documentary proof never synthesizes a waiver.
    }

    function testUnavailableStatusesAndEitherCurrentFlagReject() public {
        uint8[3] memory statuses = [
            uint8(Personhood.Status.NONE),
            uint8(Personhood.Status.STALE),
            uint8(Personhood.Status.UNRESOLVED)
        ];
        for (uint256 i; i < statuses.length; ++i) {
            Personhood.Selection memory p = _resolved();
            p.status = Personhood.Status(statuses[i]);
            _wire(p);
            _reject();
        }
        Personhood.Selection memory p = _resolved();
        p.identityCurrent = false;
        _wire(p);
        _reject();
        p = _resolved();
        p.notarizationCurrent = false;
        _wire(p);
        _reject();
        p = _waiver();
        p.identityCurrent = false;
        _wire(p);
        _reject();
    }

    function testWaiverAndEvidenceSchemasCannotBeInterchanged() public {
        Personhood.Selection memory p = _waiver();
        p.nativeRecord.schemaId = Definitions.EVIDENCE_SCHEMA;
        _wire(p);
        _reject();
        p = _resolved();
        p.nativeRecord.schemaId = Definitions.WAIVER_SCHEMA;
        _wire(p);
        _reject();
        p = _resolved();
        p.nativeRecord.schemaId = keccak256("opaque historical personhood schema");
        _wire(p);
        _reject();
    }

    function testMissingNativeFactsNeverBecomeEvidenceOrWaiver() public {
        uint256[6] memory indices = [uint256(0), 1, 2, 3, 4, 6];
        for (uint256 profile; profile < 2; ++profile) {
            for (uint256 i; i < indices.length; ++i) {
                bytes memory raw = abi.encode(profile == 0 ? _resolved() : _waiver());
                _word(raw, indices[i], 0);
                attribution.set(_selectionCall(1, ARTIST), raw);
                _reject();
            }
        }
    }

    function testExactReferenceVersionProfileOriginArtistIdentityAndHeadRequired() public {
        // Selection words: native[0..6], origin7, Reference[8..15], notarization[16..18], flags/status.
        uint256[8] memory indices = [uint256(8), 9, 10, 11, 12, 13, 14, 15];
        for (uint256 i; i < indices.length; ++i) {
            bytes memory raw = abi.encode(_resolved());
            _word(raw, indices[i], indices[i] == 8 ? 2 : 0);
            attribution.set(_selectionCall(1, ARTIST), raw);
            _reject();
        }
        Personhood.Selection memory p = _resolved();
        p.evidenceReference.artistId = keccak256("different Artist");
        _wire(p);
        _reject();
        p = _resolved();
        p.evidenceReference.operativeIdentityRecordHash = REGISTRATION;
        _wire(p);
        _reject();
        p = _resolved();
        p.evidenceReference.artistRegistry = address(0x011d);
        _wire(p);
        _reject();
        p = _resolved();
        p.notarizationHead = keccak256("new superseding notarization");
        _wire(p);
        _reject();
    }

    function testOnlyNativeNotarizationTypesAndOriginalRuntimeAccepted() public {
        Personhood.Selection memory p = _resolved();
        p.notarizationType = keccak256("ESTATE_VERIFICATION");
        _wire(p);
        require(this.read(1, ARTIST) == SUMMARY, "original estate verification profile");
        p.notarizationType = keccak256("unrelated notarization type");
        _wire(p);
        _reject();
        p = _resolved();
        p.recorder = address(0);
        _wire(p);
        _reject();
        _wire(_resolved());
        bytes memory original = address(notary).code;
        vm.etch(address(notary), hex"00");
        _reject();
        vm.etch(address(notary), original);
        require(this.read(1, ARTIST) == SUMMARY, "original notarization runtime restored");
    }

    function testCanonicalSelectionSizeAndNarrowWordsRequired() public {
        bytes memory canonical = abi.encode(_resolved());
        require(canonical.length == 704, "literal 22-word Selection ABI");
        attribution.set(_selectionCall(1, ARTIST), bytes.concat(canonical, abi.encode(uint256(0))));
        _reject();
        attribution.set(_selectionCall(1, ARTIST), new bytes(703));
        _reject();
        uint256[11] memory indices = [uint256(4), 5, 6, 7, 8, 10, 13, 17, 19, 20, 21];
        for (uint256 i; i < indices.length; ++i) {
            bytes memory raw = abi.encode(_resolved());
            _word(raw, indices[i], type(uint256).max);
            attribution.set(_selectionCall(1, ARTIST), raw);
            _reject();
        }
    }

    function testMissingMalformedAndRevertingSummaryRejectWithoutFallback() public {
        attribution.set(_summaryCall(NATIVE_RECORD), abi.encode(bytes32(0)));
        _reject();
        attribution.set(_summaryCall(NATIVE_RECORD), new bytes(31));
        _reject();
        attribution.set(_summaryCall(NATIVE_RECORD), abi.encode(SUMMARY, bytes32(0)));
        _reject();
        attribution.setFailure(_summaryCall(NATIVE_RECORD), true);
        _reject();
        attribution.setFailure(_summaryCall(NATIVE_RECORD), false);
        attribution.set(_summaryCall(NATIVE_RECORD), abi.encode(SUMMARY));
        require(this.read(1, ARTIST) == SUMMARY, "same original summary retry");
    }

    function testExactCollectionArtistAndChainScopeRequired() public {
        vm.expectRevert();
        this.read(0, ARTIST);
        vm.expectRevert();
        this.read(1, bytes32(0));
        vm.expectRevert();
        this.read(2, ARTIST); // Exact-calldata boundary has no record for this collection.
        vm.expectRevert();
        this.read(1, keccak256("different requested Artist"));
        // Restore the retained fixture value; the optimizer may rematerialize block.chainid
        // across a cheatcode call because a real transaction cannot change its chain ID.
        uint256 originalChain = dependencies.chainId;
        vm.chainId(originalChain + 1);
        _reject();
        vm.chainId(originalChain);
        require(this.read(1, ARTIST) == SUMMARY, "same chain retry");
    }

    function testSelectedPointersAndOriginalMetadataFacadePinRequired() public {
        _selected(keccak256("ARTIST_REGISTRY"), address(notary));
        _reject();
        _selected(keccak256("ARTIST_REGISTRY"), address(facade));
        _selected(keccak256("COLLECTION_METADATA"), address(notary));
        _reject();
        _selected(keccak256("COLLECTION_METADATA"), address(metadata));
        metadata.set(
            abi.encodeWithSignature("artistRegistryCodeHash()"), abi.encode(bytes32(uint256(7)))
        );
        _reject();
        metadata.set(
            abi.encodeWithSignature("artistRegistryCodeHash()"),
            abi.encode(address(facade).codehash)
        );
        require(this.read(1, ARTIST) == SUMMARY, "original selected pins retry");
    }

    function testMalformedOrInactiveSelectedPointerCannotAuthorizePersonhood() public {
        bytes32 role = keccak256("ARTIST_REGISTRY");
        uint256[8] memory indices = [uint256(0), 2, 3, 4, 5, 6, 7, 9];
        for (uint256 i; i < indices.length; ++i) {
            bytes memory raw = _pointer(role, address(facade));
            uint256 value = indices[i] == 6 ? 2 : type(uint256).max;
            if (indices[i] == 7) value = 0;
            _word(raw, indices[i], value);
            core.set(abi.encodeWithSignature("getSatellitePointer(bytes32)", role), raw);
            _reject();
        }
        core.set(
            abi.encodeWithSignature("getSatellitePointer(bytes32)", role),
            bytes.concat(_pointer(role, address(facade)), abi.encode(uint256(0)))
        );
        _reject();
        _selected(role, address(facade));
        require(this.read(1, ARTIST) == SUMMARY, "original canonical active pointer retry");
    }

    function testAttributionOwnerBindingsAndCanonicalSuiteRequired() public {
        bytes4[4] memory selectors = [
            bytes4(keccak256("core()")),
            bytes4(keccak256("artistRegistry()")),
            bytes4(keccak256("operationCoordinator()")),
            bytes4(keccak256("deploymentChainId()"))
        ];
        for (uint256 i; i < selectors.length; ++i) {
            attribution.set(abi.encodeWithSelector(selectors[i]), abi.encode(uint256(0)));
            _reject();
            _owner(attribution);
        }
        bytes memory suite = _suite();
        _word(suite, 6, uint160(address(0xA)));
        coordinator.set(abi.encodeWithSignature("suiteConfiguration()"), suite);
        _reject();
        suite = _suite();
        _word(suite, 16, type(uint256).max);
        coordinator.set(abi.encodeWithSignature("suiteConfiguration()"), suite);
        _reject();
        coordinator.set(abi.encodeWithSignature("suiteConfiguration()"), _suite());
        require(this.read(1, ARTIST) == SUMMARY, "exact actual owner graph retry");
    }

    function testPinnedMetadataAndFacadeRuntimeMutationReject() public {
        bytes memory original = address(metadata).code;
        vm.etch(address(metadata), hex"00");
        _reject();
        vm.etch(address(metadata), original);
        original = address(facade).code;
        vm.etch(address(facade), hex"00");
        _reject();
        vm.etch(address(facade), original);
        require(this.read(1, ARTIST) == SUMMARY, "restored immutable runtime pins");
    }
}
