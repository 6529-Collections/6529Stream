// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPreservationPolicyViewFinalityFixture
} from "./StreamCurrentFullPreservationPolicyViewFinalityFixture.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as ExportBasic
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as ExportComplete
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamViewAdoptionRouter as ExportAdoption
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as ExportCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";
import {
    StreamViewCeremonyInputEncoding as ViewInputWire
} from "./StreamViewCeremonyInputEncoding.sol";
import {
    IStreamViewPreservationContentRootV1 as ExportRootBinding
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    IStreamScopedContentRootPublication as ExportRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

interface ViewCeremonyFileVm {
    function exists(string calldata path) external view returns (bool);
    function isFile(string calldata path) external view returns (bool);
    function isDir(string calldata path) external view returns (bool);
    function readFile(string calldata path) external view returns (string memory);
    function readFileBinary(string calldata path) external view returns (bytes memory);
    function writeFileBinary(string calldata path, bytes calldata data) external;
    function createDir(string calldata path, bool recursive) external;
}

/// @notice Local exact-byte export and supplied-file transport over the same actual VIEW recipe.
/// @dev sourceRevision is caller provenance; actual host/runtime and complete source bytes are
/// separately checked. Replaying in a fresh Foundry invocation requires the same compiled host,
/// linked artifacts, host CREATE coordinates, chain, initial block/time and fixture configuration.
/// It is not an RPC export, browser observation, conformance proof or gas acceptance result.
abstract contract StreamCurrentFullPreservationPolicyViewInputFixture is
    StreamCurrentFullPreservationPolicyViewFinalityFixture
{
    ViewCeremonyFileVm private constant viewFiles =
        ViewCeremonyFileVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bool private viewInputSourcePrepared;
    uint256 private viewInputInitialBlock;
    uint256 private viewInputInitialTimestamp;
    uint256 private viewInputInitialChain;

    function _viewPrepareInputSource() internal {
        if (!viewInputSourcePrepared) {
            require(
                address(assemblyCore) == address(0),
                "fresh actual recipe or retained export source required"
            );
            // Capture before any original delayed governance warp or CREATE.
            viewInputInitialBlock = block.number;
            viewInputInitialTimestamp = block.timestamp;
            viewInputInitialChain = block.chainid;
            _constructFullPolicyPublication();
            _prepareFullPolicyArtwork();
            viewInputSourcePrepared = true;
        }
        require(
            block.chainid == viewInputInitialChain
                && fullPolicyViewScope.scopeType == StreamFinalityScopeType.VIEW
                && assemblyViewReferenceRecord == 0 && viewSanctionRecord == 0
                && viewFinalityRecord == 0,
            "same prepared pre-observation VIEW recipe"
        );
        _viewRequireCurrentPublication();
        _viewRequireCompleteBinding();
    }

    function _viewExportSource(string memory directory, bytes20 sourceRevision)
        internal
        returns (bytes32 sourceHash, bytes32 exportSHA256)
    {
        _viewRequireInputPath(directory);
        require(sourceRevision != bytes20(0), "explicit source revision provenance");
        require(!viewFiles.exists(directory), "fresh export directory required; no overwrite");
        _viewPrepareInputSource();
        viewFiles.createDir(directory, true);
        uint256 count =
            assemblyViewPreservationCheckpoint.checkpoint(viewPublicationCheckpoint).tokenCount;
        for (uint256 i; i < count; ++i) {
            (bytes memory output, bytes memory tokenData, bytes memory json, bytes memory html) =
                _viewExportMember(i);
            string memory prefix = string.concat(directory, "/member-", _viewMemberIndex(i));
            _viewWriteReadback(string.concat(prefix, ".output.abi"), output);
            _viewWriteReadback(string.concat(prefix, ".token-data.bin"), tokenData);
            _viewWriteReadback(string.concat(prefix, ".json"), json);
            _viewWriteReadback(string.concat(prefix, ".html"), html);
        }
        bytes memory manifest;
        (manifest, sourceHash) = _viewSourceJSON(sourceRevision);
        exportSHA256 = sha256(manifest);
        _viewRequireCurrentPublication();
        _viewRequireCompleteBinding();
        // Written last: a failed earlier export leaves no apparent complete source manifest.
        _viewWriteReadback(string.concat(directory, "/source.json"), manifest);
    }

    function _viewLoadSuppliedFiles(
        string memory sourceExportFile,
        bytes32 expectedExportSHA256,
        bytes20 expectedSourceRevision,
        string memory environmentFile,
        string memory browserFile,
        string memory capturesFile,
        string memory packageMembersDirectory
    )
        internal
        returns (
            string memory environmentJSON,
            string memory browserJSON,
            string memory capturesJSON
        )
    {
        require(
            expectedExportSHA256 != 0 && expectedSourceRevision != bytes20(0),
            "explicit pinned source export required"
        );
        string memory sourceJSON = _viewReadRequiredJSON(sourceExportFile);
        require(
            sha256(bytes(sourceJSON)) == expectedExportSHA256,
            "exact caller-pinned source.json SHA256"
        );
        environmentJSON = _viewReadRequiredJSON(environmentFile);
        browserJSON = _viewReadRequiredJSON(browserFile);
        capturesJSON = _viewReadRequiredJSON(capturesFile);
        require(
            assemblyVm.keyExistsJson(environmentJSON, ".environmentABI"),
            "required literal environmentABI"
        );
        require(
            assemblyVm.keyExistsJson(browserJSON, ".contentHash")
                && assemblyVm.keyExistsJson(browserJSON, ".firstChunkRaw")
                && assemblyVm.keyExistsJson(browserJSON, ".lastChunkRaw"),
            "required browser complete-object observations"
        );
        require(
            assemblyVm.keyExistsJson(capturesJSON, ".capture1")
                && assemblyVm.keyExistsJson(capturesJSON, ".capture2"),
            "required first and last VIEW captures"
        );
        _viewRequireInputPath(packageMembersDirectory);
        require(
            viewFiles.isDir(packageMembersDirectory), "actual supplied package member directory"
        );
        _viewPrepareInputSource();
        (bytes memory actual,) = _viewSourceJSON(expectedSourceRevision);
        // Every field, ABI byte, runtime, member identity and source hash is reconstructed.
        // No selected untrusted JSON fields are used to stand in for current producer facts.
        require(
            bytes(sourceJSON).length == actual.length
                && keccak256(bytes(sourceJSON)) == keccak256(actual),
            "export exactly matches this actual current prepared source"
        );
        _viewReadbackExportMembers(_viewSourceDirectory(sourceExportFile));
    }

    function _viewSourceJSON(bytes20 revision)
        private
        view
        returns (bytes memory out, bytes32 sourceHash)
    {
        bytes memory body = bytes.concat(
            bytes('{"schema":"STREAM_VIEW_CEREMONY_SOURCE_EXPORT_V1","schemaVersion":1,"fixture":'),
            _viewFixtureJSON(revision),
            bytes(',"scope":'),
            _viewScopeJSON(),
            bytes(',"graph":'),
            _viewGraphJSON(),
            bytes(',"publication":'),
            _viewPublicationJSON(),
            bytes(',"members":'),
            _viewMembersJSON(),
            bytes("}")
        );
        // Exact preimage: compact UTF-8 JSON in the emitted order, with the final sourceHash
        // property omitted (including its comma). This is not RFC8785 and is not a self-hash.
        sourceHash = keccak256(body);
        body[body.length - 1] = bytes1(",");
        out = bytes.concat(body, bytes('"sourceHash":"'), bytes(_viewHash(sourceHash)), bytes('"}'));
    }

    function _viewFixtureJSON(bytes20 revision) private view returns (bytes memory) {
        return abi.encodePacked(
            '{"host":"',
            Strings.toHexString(address(this)),
            '","runtimeHash":"',
            _viewHash(address(this).codehash),
            '","sourceRevision":"',
            Strings.toHexString(uint160(revision), 20),
            '","chainId":"',
            Strings.toString(viewInputInitialChain),
            '","initialBlockNumber":"',
            Strings.toString(viewInputInitialBlock),
            '","initialTimestamp":"',
            Strings.toString(viewInputInitialTimestamp),
            '","deploymentHash":"',
            _viewHash(ASSEMBLY_DEPLOYMENT),
            '"}'
        );
    }

    function _viewScopeJSON() private view returns (bytes memory) {
        return abi.encodePacked(
            '{"scopeType":4,"collectionId":"',
            Strings.toString(fullPolicyViewScope.collectionId),
            '","tokenId":"',
            Strings.toString(fullPolicyViewScope.tokenId),
            '","scopeId":"',
            _viewHash(fullPolicyViewScope.scopeId),
            '"}'
        );
    }

    function _viewGraphJSON() private view returns (bytes memory raw) {
        string[29] memory roles = [
            "CORE",
            "METADATA",
            "ROUTER",
            "FINALITY",
            "PROVIDER",
            "DISCOVERY",
            "ARTIST_REGISTRY",
            "SCHEMAS",
            "STORE",
            "DECLARATIONS",
            "VIEW_REGISTRY",
            "VIEW_RENDERER",
            "VIEW_SOURCE_SET",
            "PRESERVATION_RENDERER",
            "CHECKPOINT",
            "OUTPUT_MANIFEST",
            "SNAPSHOT",
            "REFERENCE",
            "INVENTORY",
            "BUNDLE",
            "ARTIFACT_COVERAGE",
            "EXTERNAL_COVERAGE",
            "SCOPE_MEMBERSHIP",
            "GOVERNANCE_EXECUTOR",
            "ROLE_REGISTRY",
            "ARCHIVE",
            "SNAPSHOT_AUTHORITY",
            "ROOT_SAFE",
            "ARTIST_SAFE"
        ];
        address[29] memory targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyRouter),
            address(assemblyFinality),
            address(assemblyProvider),
            address(assemblyDiscovery),
            address(assemblyArtists),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyViewDeclarations),
            address(fullPolicyViewRegistry),
            address(fullPolicyViewRenderer),
            fullPolicyViewSourceSet,
            address(assemblyViewPreservationRenderer),
            address(assemblyViewPreservationCheckpoint),
            address(assemblyViewPreservationManifest),
            address(assemblyViewPreservationSnapshot),
            address(viewReference),
            address(viewInventory),
            address(viewBundle),
            address(assemblyArtifact),
            address(assemblyExternal),
            address(assemblyMembership),
            address(assemblyExecutor),
            address(assemblyRoles),
            address(assemblyArchive),
            assemblyViewPreservationSnapshot.dependencies().targets[9],
            address(assemblyRoot),
            address(assemblyArtist)
        ];
        raw = bytes("[");
        for (uint256 i; i < targets.length; ++i) {
            require(targets[i].code.length != 0, "actual exported graph target exists");
            raw = bytes.concat(
                raw,
                i == 0 ? bytes("") : bytes(","),
                abi.encodePacked(
                    '{"role":"',
                    roles[i],
                    '","target":"',
                    Strings.toHexString(targets[i]),
                    '","runtimeHash":"',
                    _viewHash(targets[i].codehash),
                    '"}'
                )
            );
        }
        return bytes.concat(raw, bytes("]"));
    }

    function _viewPublicationJSON() private view returns (bytes memory raw) {
        raw = abi.encodePacked(
            '{"viewId":"',
            _viewHash(fullPolicyViewId),
            '","adoptionRecord":"',
            _viewHash(fullPolicyViewAdoption),
            '","checkpoint":"',
            _viewHash(viewPublicationCheckpoint),
            '","outputManifest":"',
            _viewHash(viewPublicationOutputManifest),
            '","snapshotRecord":"',
            _viewHash(assemblyViewSnapshotRecord),
            '","rootRecord":"',
            _viewHash(assemblyViewOriginalContentRoot),
            '","basicBindingRecord":"',
            _viewHash(
                ExportBasic(address(assemblyProvider)).viewPreservationBindingReceipt().recordHash
            ),
            '","completeBindingRecord":"',
            _viewHash(
                ExportComplete(address(assemblyProvider)).viewFinalitySourcesReceipt().recordHash
            ),
            '"'
        );
        raw = bytes.concat(
            raw,
            _viewABIField(
                "adoptionABI",
                ExportAdoption(address(assemblyRouter)).viewAdoptionEncoded(fullPolicyViewAdoption)
            )
        );
        raw = bytes.concat(
            raw,
            _viewABIField(
                "checkpointABI",
                abi.encode(
                    assemblyViewPreservationCheckpoint.requireCurrentCheckpoint(
                        viewPublicationCheckpoint
                    )
                )
            )
        );
        raw = bytes.concat(
            raw,
            _viewABIField(
                "outputManifestABI",
                abi.encode(
                    assemblyViewPreservationManifest.requireCurrentManifest(
                        viewPublicationOutputManifest, assemblyArtistId
                    )
                )
            )
        );
        raw = bytes.concat(
            raw,
            _viewABIField(
                "snapshotReceiptABI",
                abi.encode(
                    assemblyViewPreservationSnapshot.requireCurrent(
                        fullPolicyViewScope, assemblyViewSnapshotRecord, 1
                    )
                )
            )
        );
        raw = bytes.concat(
            raw,
            _viewABIField(
                "basicBindingABI",
                abi.encode(ExportBasic(address(assemblyProvider)).viewPreservationBindingReceipt())
            )
        );
        raw = bytes.concat(
            raw,
            _viewABIField(
                "completeBindingABI",
                abi.encode(ExportComplete(address(assemblyProvider)).viewFinalitySourcesReceipt())
            )
        );
        raw = bytes.concat(
            raw, _viewABIField("referenceDependenciesABI", abi.encode(viewReference.dependencies()))
        );
        raw = bytes.concat(
            raw, _viewABIField("inventoryDependenciesABI", abi.encode(viewInventory.dependencies()))
        );
        raw = bytes.concat(
            raw, _viewABIField("bundleDependenciesABI", abi.encode(viewBundle.dependencies()))
        );
        raw = bytes.concat(
            raw,
            _viewABIField(
                "rootRecordABI",
                abi.encode(
                    ExportRoot(address(assemblyRouter))
                        .scopedContentRootRecord(assemblyViewOriginalContentRoot)
                )
            )
        );
        raw = bytes.concat(
            raw,
            _viewABIField(
                "rootBindingABI",
                abi.encode(
                    ExportRootBinding(address(assemblyRouter))
                        .viewPreservationContentRootBinding(assemblyViewOriginalContentRoot)
                )
            ),
            bytes("}")
        );
    }

    function _viewMembersJSON() private view returns (bytes memory raw) {
        uint256 count =
            assemblyViewPreservationCheckpoint.checkpoint(viewPublicationCheckpoint).tokenCount;
        require(count != 0 && count == fullPolicyTokens.length, "all actual ordered VIEW members");
        raw = bytes("[");
        for (uint256 i; i < count; ++i) {
            (bytes memory output, bytes memory tokenData, bytes memory json, bytes memory html) =
                _viewExportMember(i);
            ExportCheckpoint.Output memory row = abi.decode(output, (ExportCheckpoint.Output));
            string memory prefix = string.concat("member-", _viewMemberIndex(i));
            bytes memory member = abi.encodePacked(
                '{"index":"',
                Strings.toString(i),
                '","tokenId":"',
                Strings.toString(row.tokenId),
                '","collectionSerial":"',
                Strings.toString(row.collectionSerial),
                '","json":'
            );
            member = bytes.concat(
                member,
                _viewFileJSON(string.concat(prefix, ".json"), json),
                bytes(',"html":'),
                _viewFileJSON(string.concat(prefix, ".html"), html)
            );
            member = bytes.concat(
                member,
                bytes(',"outputReturn":'),
                _viewFileJSON(string.concat(prefix, ".output.abi"), output),
                bytes(',"tokenData":'),
                _viewFileJSON(string.concat(prefix, ".token-data.bin"), tokenData),
                bytes("}")
            );
            raw = bytes.concat(raw, i == 0 ? bytes("") : bytes(","), member);
        }
        return bytes.concat(raw, bytes("]"));
    }

    function _viewExportMember(uint256 index)
        private
        view
        returns (bytes memory output, bytes memory tokenData, bytes memory json, bytes memory html)
    {
        ExportCheckpoint.Output memory row =
            assemblyViewPreservationCheckpoint.outputAt(viewPublicationCheckpoint, index);
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            assemblyCore.tokenCollectionIdentity(row.tokenId);
        output = abi.encode(row);
        tokenData = assemblyCore.tokenData(row.tokenId);
        json = _viewCurrentPreservationBytes(row.tokenId, false);
        html = _viewCurrentPreservationBytes(row.tokenId, true);
        require(
            row.index == index && output.length == 992 && exists
                && collection == fullPolicyViewScope.collectionId && serial == row.collectionSerial
                && serial != 0 && burned == row.burned && index < fullPolicyTokens.length
                && row.tokenId == fullPolicyTokens[index]
                && keccak256(tokenData) == row.tokenDataHash && json.length == row.jsonBytes
                && html.length == row.htmlBytes && keccak256(json) == row.jsonHash
                && keccak256(html) == row.htmlHash
                && keccak256(json) == keccak256(viewPublicationJSON[row.tokenId])
                && keccak256(html) == keccak256(viewPublicationHTML[row.tokenId]),
            "exact actual outputReturn, Core token data and complete current preservation bytes"
        );
    }

    function _viewReadbackExportMembers(string memory directory) private view {
        uint256 count =
            assemblyViewPreservationCheckpoint.checkpoint(viewPublicationCheckpoint).tokenCount;
        for (uint256 i; i < count; ++i) {
            (bytes memory output, bytes memory tokenData, bytes memory json, bytes memory html) =
                _viewExportMember(i);
            string memory prefix = string.concat(directory, "/member-", _viewMemberIndex(i));
            _viewRequireFileBytes(string.concat(prefix, ".output.abi"), output);
            _viewRequireFileBytes(string.concat(prefix, ".token-data.bin"), tokenData);
            _viewRequireFileBytes(string.concat(prefix, ".json"), json);
            _viewRequireFileBytes(string.concat(prefix, ".html"), html);
        }
    }

    function _viewWriteReadback(string memory path, bytes memory data) private {
        require(!viewFiles.exists(path), "export never overwrites files");
        viewFiles.writeFileBinary(path, data);
        _viewRequireFileBytes(path, data);
    }

    function _viewRequireFileBytes(string memory path, bytes memory expected) private view {
        require(viewFiles.isFile(path), "required exact export file");
        bytes memory raw = viewFiles.readFileBinary(path);
        require(
            raw.length == expected.length && keccak256(raw) == keccak256(expected),
            "complete exported file readback"
        );
    }

    function _viewReadRequiredJSON(string memory path) internal view returns (string memory raw) {
        _viewRequireInputPath(path);
        require(viewFiles.isFile(path), "required supplied JSON file");
        raw = viewFiles.readFile(path);
        require(
            bytes(raw).length != 0 && assemblyVm.parseJsonKeys(raw, ".").length != 0,
            "nonempty supplied JSON object"
        );
    }

    function _viewRequireInputPath(string memory path) internal pure {
        bytes memory raw = bytes(path);
        require(raw.length != 0 && raw.length <= 4096, "explicit bounded input path");
        for (uint256 i; i < raw.length; ++i) {
            require(uint8(raw[i]) >= 32, "no control bytes in input path");
            if (raw[i] == "." && (i == 0 || raw[i - 1] == "/" || raw[i - 1] == "\\")) {
                require(
                    !(i + 1 == raw.length || raw[i + 1] == "/" || raw[i + 1] == "\\"
                            || (raw[i + 1] == "."
                                && (i + 2 == raw.length
                                    || raw[i + 2] == "/"
                                    || raw[i + 2] == "\\"))),
                    "no relative traversal path segments"
                );
            }
        }
    }

    function _viewSourceDirectory(string memory path) private pure returns (string memory) {
        bytes memory raw = bytes(path);
        uint256 slash;
        for (uint256 i; i < raw.length; ++i) {
            if (raw[i] == "/" || raw[i] == "\\") slash = i + 1;
        }
        require(slash != 0, "source.json must have an explicit directory");
        bytes memory leaf = new bytes(raw.length - slash);
        for (uint256 i; i < leaf.length; ++i) {
            leaf[i] = raw[slash + i];
        }
        require(keccak256(leaf) == keccak256("source.json"), "exact source.json manifest path");
        bytes memory directory = new bytes(slash - 1);
        for (uint256 i; i < directory.length; ++i) {
            directory[i] = raw[i];
        }
        return string(directory);
    }

    function _viewMemberIndex(uint256 index) internal pure returns (string memory) {
        return ViewInputWire.memberIndex(index);
    }

    function _viewFileJSON(string memory path, bytes memory data)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '{"path":"',
            path,
            '","keccak256":"',
            _viewHash(keccak256(data)),
            '","sha256":"',
            _viewHash(sha256(data)),
            '","byteLength":"',
            Strings.toString(data.length),
            '"}'
        );
    }

    function _viewABIField(string memory key, bytes memory raw)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(',"', key, '":"', _viewHex(raw), '"');
    }

    function _viewHash(bytes32 value) private pure returns (string memory) {
        return Strings.toHexString(uint256(value), 32);
    }

    function _viewHex(bytes memory raw) private pure returns (string memory) {
        bytes memory out = new bytes(2 + raw.length * 2);
        bytes memory alphabet = "0123456789abcdef";
        out[0] = "0";
        out[1] = "x";
        for (uint256 i; i < raw.length; ++i) {
            out[2 + i * 2] = alphabet[uint8(raw[i]) >> 4];
            out[3 + i * 2] = alphabet[uint8(raw[i]) & 15];
        }
        return string(out);
    }
}
