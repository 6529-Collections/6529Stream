// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/FrozenViewRendererEncodingV2.sol";
import {
    StreamViewRendererEncodingV2 as Encoding
} from "../../../smart-contracts/domains/metadata/StreamViewRendererEncodingV2.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

contract ViewEncodingOracleProbe {
    function html(
        bool original,
        R.RenderRequest memory r,
        bytes32 scopeId,
        bytes32 sourceHash,
        uint256 chainId,
        bytes memory data,
        T.Entropy memory entropy,
        bytes memory script
    ) external view returns (string memory) {
        if (original) {
            return FrozenViewRendererEncodingV2.html(
                r, scopeId, sourceHash, chainId, data, entropy, script
            );
        }
        return _read(
            abi.encodeWithSelector(
                Encoding.html.selector, r, scopeId, sourceHash, chainId, data, entropy, script
            )
        );
    }

    function output(
        bool original,
        R.RenderRequest memory r,
        string memory name,
        string memory description,
        string memory imageURI,
        string memory html_,
        bytes memory artist,
        uint8 mode
    ) external view returns (string memory) {
        if (original) {
            return FrozenViewRendererEncodingV2.output(
                r, name, description, imageURI, html_, artist, mode
            );
        }
        return _read(
            abi.encodeWithSelector(
                Encoding.output.selector, r, name, description, imageURI, html_, artist, mode
            )
        );
    }

    function _read(bytes memory input) private view returns (string memory) {
        (bool ok, bytes memory raw) = address(Encoding).staticcall(input);
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
        return abi.decode(raw, (string));
    }
}

/// @dev The frozen literal old formatter is independent of the new worker and policy formatter.
/// No token/source/admission authority or whole-transaction gas claim is made by these pure tests.
contract StreamViewPolicyEncodingV2Test is CharacterizationTestBase {
    ViewEncodingOracleProbe private probe;

    function setUp() public {
        probe = new ViewEncodingOracleProbe();
    }

    function _request() private pure returns (R.RenderRequest memory r) {
        r.core = address(0x123456);
        r.tokenId = 97;
        r.collectionId = 11;
        r.collectionSerial = 7;
        r.viewId = keccak256("view");
        r.viewManifestHash = keccak256("view record");
        r.metadataSnapshotHash = keccak256("adoption");
        r.tokenHash = keccak256("seed");
    }

    function _entropy(bool explicit_) private pure returns (T.Entropy memory e) {
        e.coordinator = address(0x987654);
        e.coordinatorCodeHash = keccak256("coordinator code");
        e.policyHash = keccak256("full original policy");
        e.explicitPolicy = explicit_;
        e.policy.configured = true;
        e.policy.explicitPolicy = true;
        e.policy.frozen = true;
        e.policy.revision = 12;
        e.policy.policyHash = keccak256("policy");
        e.policy.mode = 2;
        e.policy.securityClass = 3;
        e.policy.renderRequirement = 1;
        e.policy.providerEpoch = 9;
        e.policy.contentStateHash = keccak256("content");
        e.policy.lastActionId = keccak256("action");
        e.policy.artistConsentRecord = keccak256("consent");
        e.status = explicit_ ? 2 : 5;
        e.terminal = explicit_;
        e.finalized = !explicit_;
        e.seed = explicit_ ? bytes32(0) : keccak256("original seed");
    }

    function _html(
        R.RenderRequest memory r,
        T.Entropy memory e,
        bytes memory data,
        bytes memory script
    ) private view returns (string memory result) {
        result = probe.html(
            false, r, keccak256("scope"), keccak256("source"), 31337, data, e, script
        );
        require(
            keccak256(bytes(result))
                == keccak256(
                    bytes(
                        probe.html(
                            true, r, keccak256("scope"), keccak256("source"), 31337, data, e, script
                        )
                    )
                ),
            "literal html"
        );
    }

    function _output(R.RenderRequest memory r, string memory text, string memory html_, uint8 mode)
        private
        view
    {
        bytes memory artist = bytes('{"name":"live artist"}');
        require(
            keccak256(bytes(probe.output(false, r, text, text, text, html_, artist, mode)))
                == keccak256(bytes(probe.output(true, r, text, text, text, html_, artist, mode))),
            "literal output"
        );
    }

    function testLiteralExplicitLegacyEmptyAndEscapedFormattingAllModes() public view {
        R.RenderRequest memory r = _request();
        for (uint256 i; i < 2; ++i) {
            string memory h = _html(r, _entropy(i == 0), hex"00ff123400", bytes("</script>\n\"x\\"));
            _output(r, "quote\"\\\n\t", h, 0);
            _output(r, "quote\"\\\n\t", h, 1);
            _output(r, "quote\"\\\n\t", h, 2);
        }
        T.Entropy memory empty;
        _html(r, empty, bytes(""), bytes(""));
    }

    function testFuzzLiteralFormatterBytes(bytes memory arbitrary, bytes32 seed, bool explicit_)
        public
        view
    {
        if (arbitrary.length > 256) return;
        R.RenderRequest memory r = _request();
        r.tokenHash = seed;
        r.tokenId = uint256(seed);
        T.Entropy memory e = _entropy(explicit_);
        e.seed = seed;
        string memory h = _html(r, e, arbitrary, arbitrary);
        _output(r, string(arbitrary), h, 1);
    }

    function testHTMLAndJSONBoundsRetainExactOriginalError() public {
        R.RenderRequest memory r = _request();
        T.Entropy memory e = _entropy(true);
        bytes memory large = new bytes(262144);
        for (uint256 i; i < 2; ++i) {
            vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
            probe.html(i == 0, r, 0, 0, 1, bytes(""), e, large);
        }
        for (uint256 i; i < 2; ++i) {
            vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
            probe.output(i == 0, r, string(large), "", "", "", bytes("{}"), 2);
        }
    }

    function testURIOnlyBoundAndCanonicalJSONParity() public {
        R.RenderRequest memory r = _request();
        string memory h = string(new bytes(150000));
        _output(r, "", h, 2);
        for (uint256 i; i < 2; ++i) {
            vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
            probe.output(i == 0, r, "", "", "", h, bytes("{}"), 1);
        }
    }

    function testFixedWorkerUsesStaticcallAndRefusesAttemptedMutation() public {
        bytes memory prior = address(Encoding).code;
        // PUSH1 1 PUSH1 0 SSTORE STOP. The probe must not permit this write.
        vm.etch(address(Encoding), hex"600160005500");
        (bool ok,) = address(probe)
            .staticcall{ gas: 1000000 }(
                abi.encodeCall(
                    probe.output, (false, _request(), "", "", "", "", bytes("{}"), uint8(2))
                )
            );
        require(!ok, "STATIC forbids worker writes");
        vm.etch(address(Encoding), prior);
        _output(_request(), "restored", "", 2);
    }
}
