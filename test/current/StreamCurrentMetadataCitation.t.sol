// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/CurrentStaticTokenRenderingFixture.sol";
import {
    IStreamCurrentCitationRegistry as CitationRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as CitationRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    StreamRendererCalls
} from "../../smart-contracts/domains/metadata/StreamRendererCalls.sol";

/// @notice Actual current-token/Safe/Executor/Schema/Registry/Renderer routing, authored for native acceptance.
/// @dev The inherited external entropy service and synthetic analysis assertion remain explicit.
/// Golden outputs use the independently checked original literal context/HTML and a literal new field;
/// no expected output is obtained from renderCurrent. This is not a transitive opcode audit.
contract StreamCurrentMetadataCitationTest is CurrentStaticTokenRenderingFixture {
    bytes32 private seed;
    uint256 private catalogSerial;
    bytes32 private constant CITATION_PROFILE = keccak256("6529STREAM_CURRENT_BASE_CITATION_V1");

    function setUp() public {
        _constructStaticTokenRendering();
        _installCitationPolicy();
        _mintToken();
        seed = _revealToken();
    }

    function testOriginalGoldenCannotAuthorizeCurrentOutput() public {
        require(rendering.versions.version(versionKey).exists, "original version exists");
        Render.RenderRequest memory request = _request();
        string memory original = rendering.renderer.renderView(request, 0);
        require(
            _has(original, _literalContext(seed, initialRecord.recordHash, true)),
            "original literal context"
        );
        require(!_has(original, '"citation"'), "original entry retains original output");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRendererCalls.RendererReadFailed.selector,
                address(rendering.versions),
                CitationRegistry.requireCurrentCitation.selector
            )
        );
        router.tokenMetadataJSON(address(core), 1);
        // Core catches the original Router refusal and serves its explicit fallback work identity.
        string memory fallbackJSON = string.concat(
            '{"name":"6529 Stream #1","description":"Stream metadata is temporarily unavailable.","image":"","properties":{"stream":{"error":"ROUTER_REVERTED","citation":"',
            _work(),
            '"}}}'
        );
        require(
            keccak256(bytes(core.tokenURI(1)))
                == keccak256(
                    bytes(
                        string.concat(
                            "data:application/json;base64,", Base64.encode(bytes(fallbackJSON))
                        )
                    )
                ),
            "original Core fallback identity"
        );
    }

    function testActualGovernedAdmissionRoutesCurrentJSONURIAndFullWithoutChangingOldEntry()
        public
    {
        (CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_) = _recipe();
        bytes32 oldVersion = keccak256(abi.encode(rendering.versions.version(versionKey)));
        string memory old = rendering.renderer.renderView(_request(), 0);
        string memory historical = router.historicalTokenMetadataJSON(address(core), 1);
        string memory historicalFull = router.historicalFullTokenMetadataJSON(address(core), 1);
        uint256 nonce = governor.nonce();
        _admitCitation(r, reads_);
        require(governor.nonce() == nonce + 1, "original scheduling Safe consumed once");
        _assertCurrentReceipt(r, reads_);
        string memory current = router.tokenMetadataJSON(address(core), 1);
        require(
            keccak256(bytes(current)) == keccak256(bytes(_expectedJSON(0))),
            "entire current JSON matches independent delta"
        );
        require(
            keccak256(bytes(router.tokenJSON(1))) == keccak256(bytes(_expectedJSON(2))),
            "entire current full output"
        );
        require(
            keccak256(bytes(core.tokenURI(1)))
                == keccak256(
                    bytes(
                        string.concat(
                            "data:application/json;base64,", Base64.encode(bytes(current))
                        )
                    )
                ),
            "actual Core URI dispatch"
        );
        require(
            keccak256(bytes(router.tokenHTML(1)))
                == keccak256(bytes(_literalHTML(seed, initialRecord.recordHash))),
            "HTML byte-exact old context"
        );
        require(
            keccak256(bytes(rendering.renderer.renderView(_request(), 0))) == keccak256(bytes(old))
                && keccak256(abi.encode(rendering.versions.version(versionKey))) == oldVersion,
            "original entry and evidence unchanged"
        );
        require(
            keccak256(bytes(router.historicalTokenMetadataJSON(address(core), 1)))
                    == keccak256(bytes(historical))
                && keccak256(bytes(router.historicalFullTokenMetadataJSON(address(core), 1)))
                    == keccak256(bytes(historicalFull)),
            "original Router checkpoint output remains byte-exact across current admission"
        );
        require(
            keccak256(
                bytes(abi.decode(vm.parseJson(current, ".properties.stream.citation"), (string)))
            ) == keccak256(bytes(_work())),
            "actual original Core global token identity"
        );
    }

    function testMissingAnalysisWrongProfileAndMissingFullGoldenCannotPublish() public {
        (CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_) = _recipe();
        CitationRegistry.CurrentRegistration memory bad = _copy(r);
        bad.analysisDocument = 0;
        _refuse(bad, reads_);
        bad = _copy(r);
        bad.profile = keccak256("foreign citation profile");
        _refuse(bad, reads_);
        bad = _copy(r);
        CitationRegistry.CurrentGoldenVector[] memory two =
            new CitationRegistry.CurrentGoldenVector[](2);
        CitationRegistry.CurrentGoldenVector[] memory full = _vectors();
        two[0] = full[0];
        two[1] = full[1];
        bad.goldenDocument = _catalog(abi.encode(two));
        _refuse(bad, reads_);
        require(
            rendering.versions.currentCitationRecord(versionKey).registrationHash == 0,
            "no partial current admission"
        );
        _admitCitation(r, reads_);
        _assertCurrentReceipt(r, reads_);
    }

    function testWrongGoldenOutputAndOmittedOriginalReadFailAtomically() public {
        (CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_) = _recipe();
        CitationRegistry.CurrentGoldenVector[] memory vectors = _vectors();
        vectors[2].outputHash = bytes32(uint256(vectors[2].outputHash) ^ 1);
        CitationRegistry.CurrentRegistration memory bad = _copy(r);
        bad.goldenDocument = _catalog(abi.encode(vectors));
        _refuse(bad, reads_);
        Versions.Read[] memory missing = new Versions.Read[](reads_.length - 1);
        uint256 omit;
        while (reads_[omit].selector == StreamStaticRenderEncoding.renderCurrent.selector) ++omit;
        for (uint256 i; i < missing.length; ++i) {
            missing[i] = reads_[i < omit ? i : i + 1];
        }
        // Rebind the analysis to this smaller list: refusal must be the original-read inclusion rule.
        bad = _copy(r);
        bad.analysisDocument = _analysis(bad, missing);
        _refuse(bad, missing);
        require(
            rendering.versions.currentCitationReads(versionKey).length == 0,
            "failed list not published"
        );
    }

    function testDirectCallerCannotRegisterAndReplayCannotReplaceEvidence() public {
        (CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_) = _recipe();
        vm.expectRevert(abi.encodeWithSelector(Versions.RendererGovernanceRequired.selector));
        rendering.versions.registerCurrentCitation(r, reads_);
        _admitCitation(r, reads_);
        CitationRegistry.CurrentRecord memory saved =
            rendering.versions.currentCitationRecord(versionKey);
        _refuse(r, reads_);
        require(
            keccak256(abi.encode(saved))
                == keccak256(abi.encode(rendering.versions.currentCitationRecord(versionKey))),
            "immutable original admission"
        );
    }

    function testAdmittedLinkedRuntimeDriftRefusesInsteadOfOldGoldenFallback() public {
        (CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_) = _recipe();
        _admitCitation(r, reads_);
        bytes memory original = r.encoding.code;
        vm.etch(r.encoding, hex"00"); // Explicit simulated runtime fault, not an authority operation.
        vm.expectRevert(
            abi.encodeWithSelector(CitationRegistry.CurrentCitationUnavailable.selector, versionKey)
        );
        rendering.versions.requireCurrentCitation(versionKey);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRendererCalls.RendererReadFailed.selector,
                address(rendering.versions),
                CitationRegistry.requireCurrentCitation.selector
            )
        );
        router.tokenMetadataJSON(address(core), 1);
        vm.etch(r.encoding, original);
        require(
            keccak256(bytes(router.tokenMetadataJSON(address(core), 1)))
                == keccak256(bytes(_expectedJSON(0))),
            "same immutable admission after restored bytes"
        );
    }

    function testForeignChainCannotReuseCurrentAdmission() public {
        (CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_) = _recipe();
        _admitCitation(r, reads_);
        uint256 savedChain = block.chainid;
        vm.chainId(savedChain + 1);
        vm.expectRevert(
            abi.encodeWithSelector(CitationRegistry.CurrentCitationUnavailable.selector, versionKey)
        );
        rendering.versions.requireCurrentCitation(versionKey);
    }

    function _installCitationPolicy() private {
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](1);
        rows[0] =
            _policy(address(rendering.versions), CitationRegistry.registerCurrentCitation.selector);
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("current citation class-1 policy");
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        require(count == 1, "one additive exact selector policy");
        _executeStage(batch, keccak256("current citation policy"));
    }

    function _recipe()
        private
        returns (CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_)
    {
        (r.encoding, r.encodingRuntimeHash) = rendering.renderer.encodingBinding();
        r.versionKey = versionKey;
        r.profile = CITATION_PROFILE;
        r.selector = CitationRenderer.renderCurrent.selector;
        reads_ = new Versions.Read[](declaredReads.length + 1);
        for (uint256 i; i < declaredReads.length; ++i) {
            reads_[i] = declaredReads[i];
        }
        Versions.Target[] memory targets = _targets();
        uint16 encoder;
        for (uint16 i; i < targets.length; ++i) {
            if (targets[i].target == r.encoding) encoder = i;
        }
        reads_[declaredReads.length] = Versions.Read(
            encoder, StreamStaticRenderEncoding.renderCurrent.selector, 16777216, false
        );
        for (uint256 i = 1; i < reads_.length; ++i) {
            for (uint256 j = i; j > 0 && _readOrder(reads_[j - 1]) > _readOrder(reads_[j]); --j) {
                (reads_[j - 1], reads_[j]) = (reads_[j], reads_[j - 1]);
            }
        }
        r.analysisDocument = _analysis(r, reads_);
        r.goldenDocument = _catalog(abi.encode(_vectors()));
    }

    function _analysis(CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_)
        private
        returns (bytes32)
    {
        CitationRegistry.CurrentAnalysis memory a = CitationRegistry.CurrentAnalysis(
            keccak256("6529STREAM_CURRENT_BASE_CITATION_ANALYSIS_ABI_V1"),
            r.profile,
            r.selector,
            address(rendering.renderer),
            address(rendering.renderer).codehash,
            r.encoding,
            r.encodingRuntimeHash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                    rendering.versions.targetSetHash(),
                    reads_
                )
            ),
            rendering.versions.version(versionKey).registrationHash,
            keccak256("SYNTHETIC FIXTURE: authority/evidence joining only, no opcode tool run"),
            keccak256(
                "SYNTHETIC FIXTURE: inherited partial read roster plus exact current encoder"
            ),
            true
        );
        return _catalog(abi.encode(a));
    }

    function _vectors() private view returns (CitationRegistry.CurrentGoldenVector[] memory v) {
        v = new CitationRegistry.CurrentGoldenVector[](3);
        string memory json = _expectedJSON(0);
        v[0] = CitationRegistry.CurrentGoldenVector(_request(), 0, keccak256(bytes(json)));
        v[1] = CitationRegistry.CurrentGoldenVector(
            _request(),
            1,
            keccak256(
                bytes(string.concat("data:application/json;base64,", Base64.encode(bytes(json))))
            )
        );
        v[2] =
            CitationRegistry.CurrentGoldenVector(_request(), 2, keccak256(bytes(_expectedJSON(2))));
    }

    function _request() private view returns (Render.RenderRequest memory r) {
        r = Render.RenderRequest(
            address(core),
            1,
            2,
            1,
            seed,
            Render.TokenRenderState.ACTIVE,
            Render.MetadataMode.ONCHAIN,
            0,
            0,
            0,
            0,
            initialRecord.recordHash
        );
    }

    function _expectedJSON(uint8 mode) private view returns (string memory) {
        string memory original = rendering.renderer.renderView(_request(), mode);
        bytes memory needle = bytes(_literalContext(seed, initialRecord.recordHash, true));
        require(
            _has(original, string(needle)) && !_has(original, '"citation"'),
            "original context literal before current delta"
        );
        bytes memory source = bytes(original);
        bytes memory addition = bytes(string.concat(',"citation":"', _work(), '"'));
        bytes memory result = new bytes(source.length + addition.length);
        uint256 at;
        uint256 matches;
        for (uint256 i; i + needle.length <= source.length; ++i) {
            bool same = true;
            for (uint256 j; j < needle.length; ++j) {
                if (source[i + j] != needle[j]) {
                    same = false;
                    break;
                }
            }
            if (same) {
                at = i + needle.length - 1;
                ++matches;
            }
        }
        require(matches == 1, "one independent original context object");
        for (uint256 i; i < at; ++i) {
            result[i] = source[i];
        }
        for (uint256 i; i < addition.length; ++i) {
            result[at + i] = addition[i];
        }
        for (uint256 i = at; i < source.length; ++i) {
            result[i + addition.length] = source[i];
        }
        return string(result);
    }

    function _work() private view returns (string memory) {
        return string.concat(
            "eip155:",
            Strings.toString(block.chainid),
            "/erc721:",
            Strings.toHexString(uint256(uint160(address(core))), 20),
            "/1"
        );
    }

    function _copy(CitationRegistry.CurrentRegistration memory r)
        private
        pure
        returns (CitationRegistry.CurrentRegistration memory)
    {
        return abi.decode(abi.encode(r), (CitationRegistry.CurrentRegistration));
    }

    function _catalog(bytes memory bytes_) private returns (bytes32) {
        return _document(
            string.concat("CURRENT_CITATION_TEST_", Strings.toString(++catalogSerial)),
            Schema.DocumentKind.CATALOG,
            bytes_
        );
    }

    function _admitCitation(
        CitationRegistry.CurrentRegistration memory r,
        Versions.Read[] memory reads_
    ) private {
        (bytes32 scope, bytes32 previous, bytes32 next) =
            rendering.versions.currentCitationTransition(r, reads_);
        bytes memory data = abi.encodeCall(CitationRegistry.registerCurrentCitation, (r, reads_));
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(
                    address(rendering.versions), data, scope, previous, next
                ),
                data
            ),
            keccak256(abi.encode("current citation", r, reads_))
        );
    }

    function admitCitation(
        CitationRegistry.CurrentRegistration memory r,
        Versions.Read[] memory reads_
    ) external {
        _admitCitation(r, reads_);
    }

    function _refuse(CitationRegistry.CurrentRegistration memory r, Versions.Read[] memory reads_)
        private
    {
        uint256 nonce = governor.nonce();
        vm.expectRevert();
        this.admitCitation(r, reads_);
        require(governor.nonce() == nonce, "whole scheduled failure reverts in outer recipe");
    }

    function _assertCurrentReceipt(
        CitationRegistry.CurrentRegistration memory r,
        Versions.Read[] memory reads_
    ) private view {
        CitationRegistry.CurrentRecord memory saved =
            rendering.versions.currentCitationRecord(versionKey);
        require(
            saved.registrationHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"),
                        block.chainid,
                        address(rendering.versions),
                        address(assemblySchemas),
                        address(assemblySchemas).codehash,
                        rendering.versions.targetSetHash(),
                        rendering.versions.version(versionKey).registrationHash,
                        r,
                        reads_
                    )
                ),
            "literal original and current admission binding"
        );
        require(
            saved.actionId != 0
                && saved.analysisHash
                    == keccak256(assemblySchemas.documentBytes(r.analysisDocument))
                && saved.goldenHash == keccak256(assemblySchemas.documentBytes(r.goldenDocument)),
            "actual governance and retained complete evidence"
        );
        require(
            keccak256(abi.encode(rendering.versions.currentCitationReads(versionKey)))
                == keccak256(abi.encode(reads_)),
            "exact current read inventory"
        );
        (address renderer, bytes32 hash, bytes32 profile_, bytes4 selector) =
            rendering.versions.requireCurrentCitation(versionKey);
        require(
            renderer == address(rendering.renderer) && hash == renderer.codehash
                && profile_ == CITATION_PROFILE
                && selector == CitationRenderer.renderCurrent.selector,
            "exact selected current profile"
        );
    }
}
