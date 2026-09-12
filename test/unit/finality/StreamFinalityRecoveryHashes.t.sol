// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityRecoveryHashes.sol";
import {
    StreamFinalityManifestRef
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityRecoveryArtistEvidenceKind
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";

contract StreamFinalityRecoveryHashesTest {
    function testRecoveryCompanionLiteralIntentAndDynamicNewState() public pure {
        (
            StreamFinalityRecoveryHashes.Environment memory e,
            StreamFinalityRecoveryRequest memory r
        ) = _fixture();
        bytes memory intent = StreamFinalityRecoveryHashes.intentBytes(e, r);
        require(intent.length == 704, "22 static words");
        require(
            keccak256(intent) == 0xf96b83616d8f70557e1ae56198dd5a46a8431a3ebd3f7ae0127bf40136f5c61d,
            "independent intent bytes"
        );
        require(
            StreamFinalityRecoveryHashes.newValueHash(e, 9, r)
                == 0x903237449b9ecfb7ce9dbe17abbfd99394f4f47180d7d661f493b02605bda73f,
            "independent dynamic offsets and utf8"
        );
    }

    function testRecoveryCompanionLiteralScopeOldAndComponent() public pure {
        (
            StreamFinalityRecoveryHashes.Environment memory e,
            StreamFinalityRecoveryRequest memory r
        ) = _fixture();
        require(
            StreamFinalityRecoveryHashes.scopeKey(r.scope)
                == 0x275aab3bbc209c75a44d35291a42e538ae90fe5326720157c9c69f316dc89591,
            "scope key"
        );
        require(
            StreamFinalityRecoveryHashes.scopeHash(e, r.scope)
                == 0x95ee6cfc703e5e2984f7d7b867448312c8f8343c9ac90b5d336a03ddf16d5abc,
            "namespaced scope"
        );
        require(
            StreamFinalityRecoveryHashes.oldValueHash(
                r.scope, bytes32(uint256(0x11)), bytes32(uint256(0x22)), 8, bytes32(uint256(0x33))
            ) == 0x836a1495df84ec500c26d3a03c1489cd3792798f55da55a4c856e92f67c10539,
            "old state"
        );
        require(
            StreamFinalityRecoveryHashes.componentRouteHash(r.replacementRoute)
                == 0x2f5a7e11bb61350b32be941053f7820d486e67eddac4819d24e22c65da223157,
            "component route"
        );
    }

    function testRecoveryCompanionLiteralExecutedRouteEvidence() public pure {
        (
            StreamFinalityRecoveryHashes.Environment memory e,
            StreamFinalityRecoveryRequest memory r
        ) = _fixture();
        StreamFinalityRecoveryHashes.Execution memory x = StreamFinalityRecoveryHashes.Execution(
            bytes32(uint256(0x123)), bytes32(uint256(0x11)), bytes32(uint256(0x22)), 9
        );
        StreamFinalityRecoveryEvidenceSnapshot memory evidence = _evidence();
        bytes32 expected = 0x08fc2d97673e94408baca37020532383868d1e9555ce29e44af7ac83c138d705;
        require(
            StreamFinalityRecoveryHashes.recoveredRouteHash(e, x, r, evidence) == expected,
            "31 literal words"
        );
        evidence.artistEvidenceHash = bytes32(uint256(0xde));
        require(
            StreamFinalityRecoveryHashes.recoveredRouteHash(e, x, r, evidence) != expected,
            "executed evidence bound"
        );
        require(
            StreamFinalityRecoveryHashes.componentRouteHash(r.replacementRoute) != expected,
            "component is not executed append"
        );
    }

    function testRecoveryCompanionIntentExcludesOnlySelfDependentContent() public pure {
        (
            StreamFinalityRecoveryHashes.Environment memory e,
            StreamFinalityRecoveryRequest memory r
        ) = _fixture();
        bytes32 intent = keccak256(StreamFinalityRecoveryHashes.intentBytes(e, r));
        bytes32 newState = StreamFinalityRecoveryHashes.newValueHash(e, 9, r);
        r.recoveryManifest.contentHash = intent;
        require(
            keccak256(StreamFinalityRecoveryHashes.intentBytes(e, r)) == intent,
            "no content fixed point"
        );
        require(
            StreamFinalityRecoveryHashes.newValueHash(e, 9, r) != newState,
            "execution still binds manifest content"
        );
        r.recoveryManifest.uriHash = bytes32(uint256(12));
        require(
            keccak256(StreamFinalityRecoveryHashes.intentBytes(e, r)) != intent,
            "uri hash in intent"
        );
    }

    function testFuzzRecoveryCompanionScopeAndOldState(
        uint8 kind,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId,
        uint64 generation
    ) public pure {
        StreamFinalityScope memory s = StreamFinalityScope(
            StreamFinalityScopeType(kind % 5), collectionId, tokenId, scopeId
        );
        bytes32 key = keccak256(abi.encode(uint8(s.scopeType), collectionId, tokenId, scopeId));
        require(StreamFinalityRecoveryHashes.scopeKey(s) == key, "four literal scope words");
        bytes32 expected = keccak256(
            abi.encode(
                bytes32(0xf0a4f7b55f872b0fff01a4b90874c9b55d64b23f668c5c12de5b6873bceee87b),
                key,
                bytes32(uint256(11)),
                bytes32(uint256(22)),
                generation,
                bytes32(uint256(33))
            )
        );
        require(
            StreamFinalityRecoveryHashes.oldValueHash(
                s, bytes32(uint256(11)), bytes32(uint256(22)), generation, bytes32(uint256(33))
            ) == expected,
            "six old-state words"
        );
    }

    function testFuzzRecoveryCompanionNamespace(
        uint256 chainId,
        address companion,
        bytes32 dataHash
    ) public pure {
        (, StreamFinalityRecoveryRequest memory r) = _fixture();
        StreamFinalityRecoveryHashes.Environment memory e =
            StreamFinalityRecoveryHashes.Environment(chainId, companion);
        r.replacementRoute.dataHash = dataHash;
        bytes32 scopeExpected = keccak256(
            abi.encode(
                bytes32(0x52a7e432a96f70f1eea1a0d69c9f1ab494af7898747ad6f19d9cc1be7ae73224),
                chainId,
                companion,
                uint8(1),
                uint256(7),
                uint256(701),
                bytes32(0)
            )
        );
        require(
            StreamFinalityRecoveryHashes.scopeHash(e, r.scope) == scopeExpected, "seven scope words"
        );
        bytes memory expectedBytes = bytes.concat(
            abi.encode(
                bytes32(0x570ae9ce4087aaa984ebbe2832d4ae780239512e44cfb784e4956c4eb6e5929a),
                chainId,
                companion,
                uint8(1),
                uint256(7),
                uint256(701),
                bytes32(0),
                bytes32(uint256(0x11))
            ),
            abi.encode(bytes32(uint256(0x22)), bytes32(uint256(0x33))),
            abi.encode(
                r.replacementRoute.componentType,
                r.replacementRoute.component,
                r.replacementRoute.interfaceId,
                r.replacementRoute.codeHash,
                r.replacementRoute.moduleVersion,
                r.replacementRoute.manifestHash,
                dataHash
            ),
            abi.encode(
                r.recoveryManifest.uriHash,
                r.recoveryManifest.schemaId,
                r.recoveryManifest.canonicalizationHash,
                r.reasonHash,
                keccak256(bytes(r.reasonURI))
            )
        );
        require(
            keccak256(StreamFinalityRecoveryHashes.intentBytes(e, r)) == keccak256(expectedBytes),
            "independent flattened intent"
        );
    }

    function _fixture()
        private
        pure
        returns (
            StreamFinalityRecoveryHashes.Environment memory e,
            StreamFinalityRecoveryRequest memory r
        )
    {
        e = StreamFinalityRecoveryHashes.Environment(
            31337, address(0x1234567890123456789012345678901234567890)
        );
        r.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 701, bytes32(0));
        r.expectedOriginalFinalityRecordHash = bytes32(uint256(0x11));
        r.expectedPredecessorRecoveryId = bytes32(uint256(0x22));
        r.expectedOldRouteHash = bytes32(uint256(0x33));
        r.replacementRoute = StreamFinalityComponentExpectation(
            bytes32(uint256(0x44)),
            address(0xBEEF),
            bytes4(0x12345678),
            bytes32(uint256(0x55)),
            bytes32(uint256(0x66)),
            bytes32(uint256(0x77)),
            bytes32(uint256(0x88))
        );
        r.recoveryManifest = StreamFinalityManifestRef(
            "ar://recovery-intent",
            keccak256("ar://recovery-intent"),
            bytes32(uint256(0x99)),
            bytes32(uint256(0xaa)),
            bytes32(uint256(0xbb))
        );
        r.reasonHash = bytes32(uint256(0xcc));
        r.reasonURI = unicode"ipfs://reason/λ";
    }

    function _evidence() private pure returns (StreamFinalityRecoveryEvidenceSnapshot memory e) {
        e = StreamFinalityRecoveryEvidenceSnapshot(
            StreamFinalityRecoveryArtistEvidenceKind.APPROVAL,
            bytes32(uint256(0xdd)),
            address(0xcafe),
            bytes32(uint256(0xee)),
            3,
            0,
            bytes32(uint256(0xff)),
            5,
            6,
            7,
            8
        );
    }
}
