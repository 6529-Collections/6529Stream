// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";

interface ReferenceEnvironmentVm {
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonBytes(string calldata json, string calldata key)
        external
        pure
        returns (bytes memory);
    function writeFile(string calldata path, string calldata content) external;
    function parseJsonString(string calldata json, string calldata key)
        external
        pure
        returns (string memory);
}

/// @dev Literal preserved pre-optimization files implementation; qualified helper dependencies unchanged.
library ReferenceEnvironmentPrior {
    uint256 private constant MAX = 524288;

    function files(StreamReferenceRenderTypes.PackageFile[] memory rows, bool relative)
        public
        pure
        returns (string memory out)
    {
        out = "[";
        for (uint256 i; i < rows.length; ++i) {
            if (
                rows[i].sha256Digest == 0
                    || (i != 0 && !_less(bytes(rows[i - 1].path), bytes(rows[i].path)))
            ) {
                revert StreamReferenceRenderTypes.InvalidReferenceRender();
            }
            if (relative) _relative(bytes(rows[i].path));
            out = string.concat(
                out,
                i == 0 ? "" : ",",
                '{"byteSize":',
                u(rows[i].byteSize),
                ',"path":',
                q(rows[i].path, relative ? 1024 : 2048),
                ',"sha256Digest":',
                h(rows[i].sha256Digest),
                "}"
            );
            if (bytes(out).length > MAX) {
                revert StreamReferenceRenderTypes.InvalidReferenceRender();
            }
        }
        return string.concat(out, "]");
    }

    function _member(
        StreamReferenceRenderTypes.PackageFile[] memory rows,
        string memory path,
        bytes32 digest
    ) private pure {
        bytes32 name = keccak256(bytes(path));
        bool found;
        for (uint256 i; i < rows.length; ++i) {
            if (keccak256(bytes(rows[i].path)) == name) {
                if (found || rows[i].byteSize == 0 || rows[i].sha256Digest != digest) {
                    revert StreamReferenceRenderTypes.InvalidReferenceRender();
                }
                found = true;
            }
        }
        if (!found) revert StreamReferenceRenderTypes.InvalidReferenceRender();
    }

    function _less(bytes memory a, bytes memory b) private pure returns (bool) {
        uint256 n = a.length < b.length ? a.length : b.length;
        for (uint256 i; i < n; ++i) {
            if (a[i] != b[i]) return a[i] < b[i];
        }
        return a.length < b.length;
    }

    function _relative(bytes memory path) private pure {
        if (path.length == 0 || path.length > 1024) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        uint256 start;
        for (uint256 i; i <= path.length; ++i) {
            if (i == path.length || path[i] == "/") {
                if (
                    i == start || (i - start == 1 && path[start] == ".")
                        || (i - start == 2 && path[start] == "." && path[start + 1] == ".")
                        || path[i - 1] == "." || path[i - 1] == " "
                ) revert StreamReferenceRenderTypes.InvalidReferenceRender();
                start = i + 1;
                continue;
            }
            bytes1 c = path[i];
            if (
                c < 0x20 || c >= 0x7f || c == 0x5c || c == ":" || c == "<" || c == ">" || c == 0x22
                    || c == "|" || c == "?" || c == "*"
            ) {
                revert StreamReferenceRenderTypes.InvalidReferenceRender();
            }
        }
    }

    function q(string memory s, uint256 bound) private pure returns (string memory) {
        return StreamRecordJson.quote(s, bound, false);
    }

    function h(bytes32 v) private pure returns (string memory) {
        return StreamSnapshotManifestJson.hashJSON(v);
    }

    function u(uint256 v) private pure returns (string memory) {
        return StreamRecordJson.unsigned(v);
    }
}

contract StreamReferenceEnvironmentJsonTest {
    ReferenceEnvironmentVm private constant vm =
        ReferenceEnvironmentVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event log_named_uint(string key, uint256 value);

    function _rows() private view returns (StreamReferenceRenderTypes.PackageFile[] memory rows) {
        string memory raw =
            vm.readFile("test/fixtures/preservation/reference-actual-native-v1.json");
        rows = abi.decode(
            vm.parseJsonBytes(raw, ".packageFilesABI"), (StreamReferenceRenderTypes.PackageFile[])
        );
    }

    function _differential(StreamReferenceRenderTypes.PackageFile[] memory rows, bool relative)
        private
        view
    {
        (bool a, bytes memory left) = address(StreamReferenceEnvironmentJson)
            .staticcall(
                abi.encodeWithSelector(
                    StreamReferenceEnvironmentJson.files.selector, rows, relative
                )
            );
        (bool b, bytes memory right) = address(ReferenceEnvironmentPrior)
            .staticcall(
                abi.encodeWithSelector(ReferenceEnvironmentPrior.files.selector, rows, relative)
            );
        require(a == b, "original acceptance");
        if (a) require(keccak256(left) == keccak256(right), "exact original bytes");
    }

    function testFuzzLiteralPriorArbitraryPaths(bytes calldata raw, bool relative) public view {
        StreamReferenceRenderTypes.PackageFile[] memory rows =
            new StreamReferenceRenderTypes.PackageFile[](1);
        rows[0] = StreamReferenceRenderTypes.PackageFile(string(raw), 13, keccak256("digest"));
        _differential(rows, relative);
    }

    function testCopyEveryWordResidueAndDeclaredAliasParity() public view {
        StreamReferenceRenderTypes.PackageFile[] memory rows =
            new StreamReferenceRenderTypes.PackageFile[](3);
        for (uint256 n = 1; n <= 64; ++n) {
            bytes memory path = new bytes(n);
            for (uint256 j; j < n; ++j) {
                path[j] = "z";
            }
            rows[0] = StreamReferenceRenderTypes.PackageFile("CON/file", 0, keccak256("a"));
            rows[1] = StreamReferenceRenderTypes.PackageFile("con/file", 9, keccak256("b"));
            rows[2] = StreamReferenceRenderTypes.PackageFile(
                string(path), type(uint64).max, keccak256("c")
            );
            _differential(rows, true);
        }
    }

    function testFuzzLiteralQuantityAndHash(uint64 size, bytes32 digest) public view {
        StreamReferenceRenderTypes.PackageFile[] memory rows =
            new StreamReferenceRenderTypes.PackageFile[](1);
        rows[0] = StreamReferenceRenderTypes.PackageFile("file.bin", size, digest);
        _differential(rows, true);
    }

    function testOrderedDuplicateMalformedAndEmptyRowAcceptanceParity() public view {
        StreamReferenceRenderTypes.PackageFile[] memory rows =
            new StreamReferenceRenderTypes.PackageFile[](0);
        _differential(rows, true);
        rows = new StreamReferenceRenderTypes.PackageFile[](2);
        rows[0] = StreamReferenceRenderTypes.PackageFile("a", 0, keccak256("a"));
        rows[1] = StreamReferenceRenderTypes.PackageFile("b", 1, keccak256("b"));
        _differential(rows, true);
        rows[1].path = "a";
        _differential(rows, true);
        rows[1].path = "A";
        _differential(rows, true);
        rows[1].path = "z/..";
        _differential(rows, true);
        rows[1].path = "z";
        rows[1].sha256Digest = 0;
        _differential(rows, true);
    }

    function testActualCompleteEnvironmentBoundedCall() public {
        string memory fixture =
            vm.readFile("test/fixtures/preservation/reference-actual-native-v1.json");
        StreamReferenceRenderTypes.Environment memory e;
        e.objectHash = bytes32(uint256(11));
        e.coverageHash = bytes32(uint256(12));
        e.engineName = "Google Chrome";
        e.engineVersion = "152.0.7977.83";
        e.engineExecutablePath = "engine/chrome.exe";
        e.engineExecutableSha256 =
            abi.decode(vm.parseJsonBytes(fixture, ".engineExecutableSha256"), (bytes32));
        e.toolchainName = "reference_capture.py; Python; websockets";
        e.toolchainVersion = "STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1; 3.12.10; 15.0.1";
        e.toolchainPath = "tool/reference_capture.py";
        e.toolchainSha256 = abi.decode(vm.parseJsonBytes(fixture, ".toolchainSha256"), (bytes32));
        e.packageFiles = _rows();
        e.platformPrerequisites = abi.decode(
            vm.parseJsonBytes(fixture, ".platformPrerequisitesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        e.operatingSystem = "Windows";
        e.operatingSystemVersion = vm.parseJsonString(fixture, ".operatingSystemVersion");
        e.architecture = "AMD64";
        e.colorSpace = "srgb";
        e.viewportWidth = 64;
        e.viewportHeight = 64;
        e.devicePixelRatio = 1;
        e.softwareRasterization = true;
        e.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        e.licenseNote = vm.parseJsonString(fixture, ".licenseNote");
        bytes memory input =
            abi.encodeWithSelector(StreamReferenceEnvironmentJson.manifest.selector, e);
        uint256 before = gasleft();
        (bool ok, bytes memory raw) =
            address(StreamReferenceEnvironmentJson).staticcall{ gas: 16000000 }(input);
        uint256 used = before - gasleft();
        require(ok, "actual complete environment within16M");
        bytes memory output = abi.decode(raw, (bytes));
        require(
            keccak256(output)
                == keccak256(
                    bytes(vm.readFile("test/fixtures/preservation/reference-environment.json"))
                ),
            "independent complete environment"
        );
        emit log_named_uint("actualEnvironmentJSONBytes", output.length);
        emit log_named_uint("actualEnvironmentCalleeGas", used);
    }

    function testActualCompleteFileInventoryBoundedCall() public {
        StreamReferenceRenderTypes.PackageFile[] memory rows = _rows();
        bytes memory input =
            abi.encodeWithSelector(StreamReferenceEnvironmentJson.files.selector, rows, true);
        uint256 before = gasleft();
        (bool ok, bytes memory raw) =
            address(StreamReferenceEnvironmentJson).staticcall{ gas: 16000000 }(input);
        uint256 used = before - gasleft();
        require(ok, "actual complete file array within16M");
        string memory json = abi.decode(raw, (string));
        emit log_named_uint("actualPackageRows", rows.length);
        emit log_named_uint("actualPackageJSONBytes", bytes(json).length);
        emit log_named_uint("actualPackageCalleeGas", used);
        vm.writeFile("reference-package-rows.json", json);
        require(
            keccak256(bytes(json))
                == keccak256(
                    bytes(vm.readFile("test/fixtures/preservation/reference-package-rows.json"))
                ),
            "independent full inventory JSON"
        );
    }
}
