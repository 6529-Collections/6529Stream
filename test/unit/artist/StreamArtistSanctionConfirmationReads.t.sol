// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistSanctionConfirmationReads.sol";

interface ConfirmationReadsVm {
    function expectRevert(bytes calldata reason) external;
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
    function etch(address target, bytes calldata code) external;
}

/// @dev Historical reader boundaries, not a real governance execution or archived-artifact provider.
contract ConfirmationCoreBoundary {
    address public selectedFinality;

    function replacePointer(address value) external {
        selectedFinality = value;
    }
}

contract ConfirmationArtistBoundary {
    T.Binding private _binding;
    S.Record private _sanction;
    uint8 private _attribution;

    function configure(T.Binding memory b, S.Record memory s, uint8 attribution) external {
        _binding = b;
        _sanction = s;
        _attribution = attribution;
    }

    function binding(uint256) external view returns (T.Binding memory) {
        return _binding;
    }

    function attributionState(uint256) external view returns (uint8, uint64) {
        return (_attribution, _binding.generation);
    }

    function sanctionRecord(bytes32 hash) external view returns (S.Record memory r) {
        if (hash == _sanction.recordHash) return _sanction;
    }

    function finalityState(uint256) external view returns (StreamFinalityComponentState memory) {
        return StreamFinalityComponentState(
            true,
            keccak256("ARTIST_SANCTION"),
            address(this),
            type(IStreamArtworkFinalityComponent).interfaceId,
            address(this).codehash,
            keccak256("version1"),
            keccak256("manifest1"),
            _sanction.recordHash
        );
    }
}

contract ConfirmationFinalityBoundary {
    address public immutable coreReads;
    address public immutable sanctionReads;
    address public constant artifactCoverage = address(0xA47);
    StreamCollectionFinalityRecord private _record;
    StreamFinalityComponentExpectation[] private _components;
    StreamFinalityExecutionWitness private _execution;
    StreamFinalitySanctionArchiveWitness private _archive;

    constructor(address core, address artist) {
        coreReads = core;
        sanctionReads = artist;
    }

    function configure(
        StreamCollectionFinalityRecord memory r,
        StreamFinalityComponentExpectation[] memory c,
        StreamFinalityExecutionWitness memory e,
        StreamFinalitySanctionArchiveWitness memory a
    ) external {
        _record = r;
        delete _components;
        for (uint256 i; i < c.length; ++i) {
            _components.push(c[i]);
        }
        _execution = e;
        _archive = a;
    }

    function collectionFinalityRecord(uint256 collectionId)
        external
        view
        returns (StreamCollectionFinalityRecord memory r)
    {
        if (collectionId == 1) return _record;
    }

    function finalityComponentCount(uint256 collectionId) external view returns (uint256) {
        return collectionId == 1 ? _components.length : 0;
    }

    function finalityComponents(uint256 collectionId, uint256 start, uint256 count)
        external
        view
        returns (StreamFinalityComponentExpectation[] memory)
    {
        require(collectionId == 1 && start == 0 && count == _components.length, "exact read shape");
        return _components;
    }

    function finalityExecutionWitness(bytes32 hash)
        external
        view
        returns (StreamFinalityExecutionWitness memory r)
    {
        if (hash == _record.finalityRecordHash) return _execution;
    }

    function finalitySanctionArchiveWitness(bytes32 hash)
        external
        view
        returns (StreamFinalitySanctionArchiveWitness memory r)
    {
        if (hash == _record.finalityRecordHash) return _archive;
    }
}

contract ConfirmationReadHarness {
    T.SuiteConfiguration private _suite;
    StreamArtistSanctionConfirmationReads.Pins private _pins;

    constructor(
        T.SuiteConfiguration memory suite,
        StreamArtistSanctionConfirmationReads.Pins memory pins
    ) {
        _suite = suite;
        _pins = pins;
    }

    function observe() external view returns (Confirmation.Observation memory) {
        return StreamArtistSanctionConfirmationReads.observe(_suite, _pins, 1);
    }
}

contract StreamArtistSanctionConfirmationReadsTest {
    ConfirmationReadsVm private constant vm =
        ConfirmationReadsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ConfirmationCoreBoundary private core;
    ConfirmationArtistBoundary private artist;
    ConfirmationFinalityBoundary private finality;
    ConfirmationReadHarness private reader;
    T.Binding private binding_;
    S.Record private sanction;
    StreamCollectionFinalityRecord private record_;
    StreamFinalityComponentExpectation[] private components;
    StreamFinalityExecutionWitness private execution;
    StreamFinalitySanctionArchiveWitness private archive;

    function setUp() public {
        core = new ConfirmationCoreBoundary();
        artist = new ConfirmationArtistBoundary();
        finality = new ConfirmationFinalityBoundary(address(core), address(artist));
        binding_ = T.Binding(
            keccak256("artist"),
            address(0xA11CE),
            keccak256("identity"),
            keccak256("binding"),
            1,
            1,
            0,
            0,
            address(0xB0B),
            true
        );
        sanction = S.Record(
            0,
            binding_.artistId,
            address(0xA11CE),
            1,
            S.Terms(0, 1, 0, 0, keccak256("subject"), keccak256("statement")),
            7,
            1000,
            1100,
            1,
            binding_.bindingHash,
            keccak256("digest")
        );
        sanction.recordHash = _literalRecord(sanction);
        artist.configure(binding_, sanction, 2);
        components.push(
            StreamFinalityComponentExpectation(
                keccak256("ARTIST_SANCTION"),
                address(artist),
                type(IStreamArtworkFinalityComponent).interfaceId,
                address(artist).codehash,
                keccak256("version1"),
                keccak256("manifest1"),
                sanction.recordHash
            )
        );
        record_ = StreamCollectionFinalityRecord(
            true,
            keccak256("immutable executed finality"),
            keccak256("finality manifest"),
            keccak256("urn:executed"),
            "urn:executed",
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components)),
            address(finality),
            1200
        );
        execution = StreamFinalityExecutionWitness(
            keccak256("executed action"),
            address(0x123),
            keccak256("reason"),
            keccak256("role mutation"),
            2
        );
        archive.proof = StreamFinalitySanctionArchiveProof(
            sanction.recordHash, keccak256("whole artifact"), keccak256("original completion")
        );
        archive.evidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                block.chainid,
                address(core),
                address(finality),
                address(0xA47),
                archive.proof
            )
        );
        _configure();
        T.SuiteConfiguration memory suite;
        suite.core = address(core);
        suite.registry = address(artist);
        suite.mintManager = address(0x654);
        suite.owners[0] = address(artist);
        suite.owners[4] = address(artist);
        suite.owners[6] = address(artist);
        // Identity and current coverage are deliberately absent: this is stored evidence observation.
        reader = new ConfirmationReadHarness(
            suite,
            StreamArtistSanctionConfirmationReads.Pins(
                address(finality),
                address(finality).codehash,
                address(core).codehash,
                address(artist).codehash,
                300000
            )
        );
    }

    function _literalRecord(S.Record memory r) private view returns (bytes32) {
        bytes32[14] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_SANCTION_RECORD_V1");
        w[1] = bytes32(block.chainid);
        w[2] = bytes32(uint256(uint160(address(artist))));
        w[3] = r.artistId;
        w[4] = bytes32(uint256(uint160(r.signer)));
        w[5] = bytes32(uint256(r.authorityClass));
        w[6] = bytes32(uint256(r.terms.scopeType));
        w[7] = bytes32(r.terms.collectionId);
        w[8] = bytes32(r.terms.tokenId);
        w[9] = r.terms.scopeId;
        w[10] = r.terms.sanctionSubjectHash;
        w[11] = r.terms.statementHash;
        w[12] = bytes32(r.nonce);
        w[13] = bytes32(uint256(r.signedAt));
        return keccak256(abi.encode(w));
    }

    function _configure() private {
        finality.configure(record_, components, execution, archive);
    }

    function _invalid() private {
        vm.expectRevert(abi.encodeWithSelector(Confirmation.InvalidSanctionConfirmation.selector));
        reader.observe();
    }

    function _healthy() private view returns (bytes32) {
        Confirmation.Observation memory o = reader.observe();
        require(
            o.sanction.recordHash == sanction.recordHash && o.sanction.signer == sanction.signer,
            "saved sanction"
        );
        require(
            o.priorAttributionState == 2 && o.binding_.generation == binding_.generation,
            "current association"
        );
        require(
            keccak256(abi.encode(o.finalityRecord)) == keccak256(abi.encode(record_)),
            "exact stored record"
        );
        require(
            keccak256(abi.encode(o.components)) == keccak256(abi.encode(components)),
            "exact stored components"
        );
        require(
            keccak256(abi.encode(o.executionWitness)) == keccak256(abi.encode(execution)),
            "executed witness"
        );
        require(
            keccak256(abi.encode(o.archiveWitness)) == keccak256(abi.encode(archive)),
            "archive witness"
        );
        require(o.rawReadHash != 0, "raw transcript");
        return keccak256(abi.encode(o));
    }

    function testConfirmationHistoryIgnoresNewCorePointerAndAbsentIdentityOrCoverage() external {
        bytes32 before_ = _healthy();
        core.replacePointer(address(0xDEAD));
        require(_healthy() == before_, "immutable observation changed with current pointer");
        core.replacePointer(address(finality));
        require(_healthy() == before_, "restored pointer changed history");
    }

    function testConfirmationCurrentAssociationAndAttributionRejectSavedUnrelatedHistory()
        external
    {
        T.Binding memory b = binding_;
        b.generation = 2;
        artist.configure(b, sanction, 2);
        _invalid();
        b = binding_;
        b.artistId = keccak256("corrected artist");
        artist.configure(b, sanction, 2);
        _invalid();
        b = binding_;
        b.bindingHash = keccak256("new binding");
        artist.configure(b, sanction, 2);
        _invalid();
        for (uint8 state = 3; state <= 5; ++state) {
            artist.configure(binding_, sanction, state);
            _invalid();
        }
        artist.configure(binding_, sanction, 2);
        _healthy();
    }

    function testConfirmationMissingExecutedWitnessAndWrongArchiveJoinReject() external {
        StreamFinalityExecutionWitness memory saved = execution;
        execution.actionId = 0;
        _configure();
        _invalid();
        execution = saved;
        bytes32 original = archive.proof.sanctionRecordHash;
        archive.proof.sanctionRecordHash = keccak256("foreign sanction");
        _configure();
        _invalid();
        archive.proof.sanctionRecordHash = original;
        bytes32 evidence = archive.evidenceHash;
        archive.evidenceHash = keccak256("wrong evidence domain");
        _configure();
        _invalid();
        archive.evidenceHash = evidence;
        _configure();
        _healthy();
    }

    function testConfirmationAlteredRecordComponentAndRuntimeRejectWithExactRestore() external {
        bytes32 expected = record_.componentsHash;
        record_.componentsHash = keccak256("altered stored hash");
        _configure();
        _invalid();
        record_.componentsHash = expected;
        bytes32 manifest = components[0].manifestHash;
        components[0].manifestHash = keccak256("wrong artist module manifest");
        record_.componentsHash =
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components));
        _configure();
        _invalid();
        components[0].manifestHash = manifest;
        record_.componentsHash = expected;
        _configure();
        bytes memory code = address(finality).code;
        vm.etch(address(finality), hex"00");
        vm.expectRevert(abi.encodeWithSelector(T.InvalidBinding.selector));
        reader.observe();
        vm.etch(address(finality), code);
        _healthy();
    }

    function _setWord(bytes memory data, uint256 offset, uint256 value) private pure {
        assembly ("memory-safe") { mstore(add(add(data, 32), offset), value) }
    }

    function testConfirmationMalformedDynamicRecordAndPaddingReject() external {
        bytes memory callData =
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (uint256(1)));
        bytes memory raw = abi.encode(record_);
        _setWord(raw, 0, 64);
        vm.mockCall(address(finality), callData, raw);
        _invalid();
        vm.clearMockedCalls();
        raw = abi.encode(record_);
        _setWord(raw, 32, 2);
        vm.mockCall(address(finality), callData, raw);
        _invalid();
        vm.clearMockedCalls();
        raw = abi.encode(record_);
        _setWord(raw, 256, uint256(1) << 64);
        vm.mockCall(address(finality), callData, raw);
        _invalid();
        vm.clearMockedCalls();
        raw = abi.encode(record_);
        raw[raw.length - 1] = bytes1(uint8(1));
        vm.mockCall(address(finality), callData, raw);
        _invalid();
        vm.clearMockedCalls();
        _healthy();
    }

    function testConfirmationMalformedComponentWidthsCountsAndMissingSanctionReject() external {
        bytes memory callData = abi.encodeCall(
            IStreamArtworkFinalityRegistry.finalityComponents, (uint256(1), uint256(0), uint256(1))
        );
        bytes memory raw = abi.encode(components);
        _setWord(raw, 96, uint256(1) << 160);
        vm.mockCall(address(finality), callData, raw);
        _invalid();
        vm.clearMockedCalls();
        raw = abi.encode(components);
        _setWord(raw, 128, uint256(1));
        vm.mockCall(address(finality), callData, raw);
        _invalid();
        vm.clearMockedCalls();
        bytes memory countCall =
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponentCount, (uint256(1)));
        vm.mockCall(address(finality), countCall, abi.encode(uint256(33)));
        _invalid();
        vm.clearMockedCalls();
        bytes32 kind = components[0].componentType;
        components[0].componentType = keccak256("OTHER_COMPONENT");
        record_.componentsHash =
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components));
        _configure();
        _invalid();
        components[0].componentType = kind;
        record_.componentsHash =
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components));
        _configure();
        _healthy();
    }

    function testConfirmationParentGasFailureAndSameHostHealthyRetry() external {
        (bool ok, bytes memory reason) = address(reader).staticcall{ gas: 150000 }(
            abi.encodeCall(ConfirmationReadHarness.observe, ())
        );
        require(
            !ok && reason.length == 68
                && bytes4(reason) == Confirmation.SanctionConfirmationParentGas.selector,
            "parent reserve error"
        );
        _healthy();
    }
}
