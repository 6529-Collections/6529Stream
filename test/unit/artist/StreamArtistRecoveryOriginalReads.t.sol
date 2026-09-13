// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistRecoveryOriginalReads.sol";

interface RecoveryOriginalVm {
    function mockCall(address target, bytes calldata callData, bytes calldata result) external;
    function clearMockedCalls() external;
    function etch(address target, bytes calldata code) external;
}

/// @dev Exact historical-return boundary. These contracts perform no finality ceremony or governance.
contract RecoveryOriginalBoundary {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

contract RecoveryOriginalHarness {
    T.SuiteConfiguration private _suite;
    StreamArtistRecoveryOriginalReads.Pins private _pins;

    constructor(T.SuiteConfiguration memory s, StreamArtistRecoveryOriginalReads.Pins memory p) {
        _suite = s;
        _pins = p;
    }

    function observe(bytes32 hash)
        external
        view
        returns (StreamArtistRecoveryOriginalReads.Observation memory)
    {
        return StreamArtistRecoveryOriginalReads.observe(_suite, _pins, hash);
    }
}

contract StreamArtistRecoveryOriginalReadsTest {
    RecoveryOriginalVm private constant vm =
        RecoveryOriginalVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private core;
    address private artist;
    address private consent;
    address private finality;
    RecoveryOriginalHarness private reader;
    StreamFinalityScope private scope_;
    S.Record private sanction;
    bytes32 private finalityHash;
    bytes private recordRaw;
    bytes private recordCall;
    bytes private componentsCall;
    StreamFinalityComponentExpectation[] private components;

    function setUp() public {
        core = address(new RecoveryOriginalBoundary());
        artist = address(new RecoveryOriginalBoundary());
        consent = address(new RecoveryOriginalBoundary());
        finality = address(new RecoveryOriginalBoundary());
        T.SuiteConfiguration memory s;
        s.core = core;
        s.registry = artist;
        s.owners[6] = consent;
        s.mintManager = address(0x44);
        reader = new RecoveryOriginalHarness(
            s,
            StreamArtistRecoveryOriginalReads.Pins(
                finality, finality.codehash, core.codehash, artist.codehash, 2000000
            )
        );
        _fixture(0, 1, "ipfs://original");
    }

    function _fixture(uint8 kind, uint256 count, string memory uri) private {
        vm.clearMockedCalls();
        scope_ = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            7,
            kind == 1 ? 99 : 0,
            kind > 1 ? bytes32(uint256(88)) : bytes32(0)
        );
        sanction = S.Record(
            0,
            keccak256("original artist"),
            address(0xA11CE),
            1,
            S.Terms(
                kind, 7, scope_.tokenId, scope_.scopeId, keccak256("subject"), keccak256("ceremony")
            ),
            1,
            1000,
            2000,
            3,
            keccak256("original binding"),
            keccak256("original digest")
        );
        sanction.recordHash = StreamArtistSanctionHashes.record(
            StreamArtistHashes.Environment(block.chainid, artist, core, address(0x44)), sanction
        );
        finalityHash = keccak256(abi.encode("executed original", kind));
        delete components;
        // All ordinary component types sort below the single sanction type in these vectors.
        for (uint256 i = 1; i < count; ++i) {
            components.push(
                StreamFinalityComponentExpectation(
                    bytes32(i),
                    address(uint160(0x100 + i)),
                    bytes4(uint32(i)),
                    bytes32(uint256(1)),
                    bytes32(uint256(2)),
                    bytes32(uint256(3)),
                    bytes32(uint256(4))
                )
            );
        }
        components.push(
            StreamFinalityComponentExpectation(
                keccak256("ARTIST_SANCTION"),
                artist,
                kind == 0
                    ? type(IStreamArtworkFinalityComponent).interfaceId
                    : type(IStreamArtworkScopedFinalityComponent).interfaceId,
                artist.codehash,
                keccak256("version"),
                keccak256("manifest"),
                sanction.recordHash
            )
        );
        bytes32 componentHash =
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components));
        if (kind == 0) {
            recordCall =
                abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (7));
            recordRaw = abi.encode(
                StreamCollectionFinalityRecord(
                    true,
                    finalityHash,
                    keccak256("content"),
                    keccak256(bytes(uri)),
                    uri,
                    componentHash,
                    finality,
                    3000
                )
            );
            componentsCall =
                abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponents, (7, 0, count));
            vm.mockCall(
                finality,
                abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponentCount, (7)),
                abi.encode(count)
            );
        } else {
            recordCall =
                abi.encodeCall(IStreamArtworkFinalityRegistry.artworkScopeFinalityRecord, (scope_));
            recordRaw = abi.encode(
                StreamScopedFinalityRecord(
                    true,
                    scope_,
                    finalityHash,
                    keccak256("content"),
                    keccak256(bytes(uri)),
                    componentHash,
                    uri,
                    finality,
                    3000
                )
            );
            componentsCall = abi.encodeCall(
                IStreamArtworkFinalityRegistry.finalityComponentsForScope, (scope_, 0, count)
            );
            vm.mockCall(
                finality,
                abi.encodeCall(
                    IStreamArtworkFinalityRegistry.finalityComponentCountForScope, (scope_)
                ),
                abi.encode(count)
            );
        }
        vm.mockCall(finality, recordCall, recordRaw);
        vm.mockCall(finality, componentsCall, abi.encode(components));
        vm.mockCall(
            finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()),
            abi.encode(core)
        );
        vm.mockCall(
            finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.sanctionReads, ()),
            abi.encode(artist)
        );
        vm.mockCall(
            finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.artifactCoverage, ()),
            abi.encode(address(0xA47))
        );
        vm.mockCall(
            consent,
            abi.encodeCall(IStreamArtistSanctionOwner.sanctionRecord, (sanction.recordHash)),
            abi.encode(sanction)
        );
        vm.mockCall(
            finality,
            abi.encodeCall(
                IStreamCanonicalArtworkFinality.finalityExecutionWitness, (finalityHash)
            ),
            abi.encode(
                StreamFinalityExecutionWitness(
                    keccak256("executed action"),
                    address(0xB0B),
                    keccak256("reason"),
                    keccak256("role mutation"),
                    1
                )
            )
        );
        StreamFinalitySanctionArchiveProof memory proof = StreamFinalitySanctionArchiveProof(
            sanction.recordHash, keccak256("artifact"), keccak256("completion")
        );
        bytes32 evidence = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                block.chainid,
                core,
                finality,
                address(0xA47),
                proof
            )
        );
        vm.mockCall(
            finality,
            abi.encodeCall(
                IStreamFinalitySanctionArchive.finalitySanctionArchiveWitness, (finalityHash)
            ),
            abi.encode(StreamFinalitySanctionArchiveWitness(evidence, proof))
        );
    }

    function _read() private view returns (StreamArtistRecoveryOriginalReads.Observation memory) {
        return reader.observe(finalityHash);
    }

    function _reject() private view {
        (bool ok,) = address(reader).staticcall(abi.encodeCall(reader.observe, (finalityHash)));
        require(!ok, "invalid original accepted");
    }

    function _word(bytes memory raw, uint256 offset, uint256 value) private pure {
        assembly ("memory-safe") { mstore(add(add(raw, 32), offset), value) }
    }

    function testAllFiveScopesUseExactOriginalRecordAndSanctionAssociation() public {
        for (uint8 kind; kind < 5; ++kind) {
            _fixture(kind, 2, "ipfs://original scoped");
            StreamArtistRecoveryOriginalReads.Observation memory o = _read();
            require(keccak256(abi.encode(o.scope)) == keccak256(abi.encode(scope_)), "actual scope");
            require(
                keccak256(abi.encode(o.sanction)) == keccak256(abi.encode(sanction)),
                "saved association"
            );
            require(
                o.fullRecordHash == keccak256(recordRaw) && o.rawReadHash != 0,
                "exact record and transcript"
            );
            require(
                keccak256(abi.encode(o.components)) == keccak256(abi.encode(components)),
                "canonical components"
            );
        }
    }

    function testHistoricalReadDoesNotQueryCurrentAuthorityOrSelection() public view {
        // Every unconfigured Core/Binding/Attribution/Identity selector reverts on these boundaries.
        // An accidental current-read dependency therefore prevents this successful observation.
        require(_read().sanction.artistId == sanction.artistId, "historical only");
    }

    function testMalformedCollectionAndScopedHeadersPaddingAndTrailingBytesReject() public {
        for (uint8 kind; kind < 2; ++kind) {
            _fixture(kind, 1, "x");
            bytes memory malformed = recordRaw;
            _word(malformed, kind == 0 ? 160 : 320, 32);
            vm.mockCall(finality, recordCall, malformed);
            _reject();
            vm.mockCall(finality, recordCall, recordRaw); // storage source remains unchanged
            malformed = recordRaw;
            malformed[malformed.length - 1] = bytes1(uint8(1));
            vm.mockCall(finality, recordCall, malformed);
            _reject();
            vm.mockCall(finality, recordCall, bytes.concat(recordRaw, bytes32(0)));
            _reject();
            vm.mockCall(finality, recordCall, recordRaw);
            require(_read().fullRecordHash == keccak256(recordRaw), "healthy restore");
        }
    }

    function testWrongOriginalScopeRecordWitnessAndSanctionReject() public {
        _fixture(2, 1, "original");
        bytes memory raw = recordRaw;
        _word(raw, 160, 99);
        vm.mockCall(finality, recordCall, raw);
        _reject();
        vm.mockCall(finality, recordCall, recordRaw);
        S.Record memory changed = sanction;
        changed.bindingHash = keccak256("different association");
        // Binding hash is intentionally outside the permanent sanction record preimage, but its
        // exact saved Consent record is the authority for the original association. Hash-changing
        // artist substitution must fail; actual owner code pins protect stored supplemental fields.
        changed.artistId = keccak256("different artist");
        vm.mockCall(
            consent,
            abi.encodeCall(IStreamArtistSanctionOwner.sanctionRecord, (sanction.recordHash)),
            abi.encode(changed)
        );
        _reject();
        vm.mockCall(
            consent,
            abi.encodeCall(IStreamArtistSanctionOwner.sanctionRecord, (sanction.recordHash)),
            abi.encode(sanction)
        );
        vm.mockCall(
            finality,
            abi.encodeCall(
                IStreamCanonicalArtworkFinality.finalityExecutionWitness, (finalityHash)
            ),
            abi.encode(StreamFinalityExecutionWitness(0, address(1), 0, bytes32(uint256(1)), 1))
        );
        _reject();
    }

    function testDuplicateSanctionWrongInterfaceAndUnsortedComponentsReject() public {
        _fixture(1, 2, "original");
        StreamFinalityComponentExpectation[] memory items = components;
        items[0] = items[1];
        vm.mockCall(finality, componentsCall, abi.encode(items));
        _reject();
        items = components;
        items[1].interfaceId = type(IStreamArtworkFinalityComponent).interfaceId;
        vm.mockCall(finality, componentsCall, abi.encode(items));
        _reject();
        items = components;
        StreamFinalityComponentExpectation memory first = items[0];
        items[0] = items[1];
        items[1] = first;
        vm.mockCall(finality, componentsCall, abi.encode(items));
        _reject();
        vm.mockCall(finality, componentsCall, abi.encode(components));
        require(_read().components.length == 2, "healthy components");
    }

    function testPinnedRuntimeDriftRejectsAndExactRestorePreservesObservation() public {
        bytes32 before_ = keccak256(abi.encode(_read()));
        bytes memory code = finality.code;
        vm.etch(finality, hex"00");
        _reject();
        vm.etch(finality, code);
        require(keccak256(abi.encode(_read())) == before_, "restored exact history");
    }

    function testScopedInterfacePredicateRejectsInternallyRehashedSubstitution() public {
        _fixture(1, 1, "original");
        StreamFinalityComponentExpectation[] memory items = components;
        items[0].interfaceId = type(IStreamArtworkFinalityComponent).interfaceId;
        bytes32 alteredHash =
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, items));
        bytes memory raw = recordRaw;
        _word(raw, 288, uint256(alteredHash));
        vm.mockCall(finality, recordCall, raw);
        vm.mockCall(finality, componentsCall, abi.encode(items));
        _reject();
        vm.mockCall(finality, recordCall, recordRaw);
        vm.mockCall(finality, componentsCall, abi.encode(components));
        require(
            _read().components[0].interfaceId
                == type(IStreamArtworkScopedFinalityComponent).interfaceId,
            "matching scoped interface restored"
        );
    }

    function testLowParentGasFailsExplicitlyBeforeReadAndHealthyRetryMatches() public view {
        bytes32 expected = keccak256(abi.encode(_read()));
        (bool ok, bytes memory reason) = address(reader).staticcall{ gas: 2000000 }(
            abi.encodeCall(reader.observe, (finalityHash))
        );
        require(
            !ok && reason.length == 68
                && bytes4(reason)
                    == StreamArtistRecoveryOriginalReads.RecoveryOriginalParentGas.selector,
            "explicit parent gas error"
        );
        require(keccak256(abi.encode(_read())) == expected, "unchanged healthy retry");
    }

    function testMaximumComponentAndUriBoundsBothRecordShapes() public {
        bytes memory uri = new bytes(32768);
        for (uint256 i; i < uri.length; ++i) {
            uri[i] = "a";
        }
        for (uint8 kind; kind < 2; ++kind) {
            _fixture(kind, 32, string(uri));
            StreamArtistRecoveryOriginalReads.Observation memory o = _read();
            require(
                o.components.length == 32 && o.fullRecordHash == keccak256(recordRaw),
                "bounded complete read"
            );
        }
    }
}
